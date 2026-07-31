# MoonBit → Kotlin/Swift FFI 調査ノート

調査日: 2026-07-31

## 問い

MoonBitで書いたコードをKotlin/SwiftからFFI経由で呼び出すライブラリを作る場合、MoonBit言語コア（構文・型システム・意味論）に手を入れる必要があるか、それとも3rd-partyライブラリとして完結できるか。

### 問いの立て方に対する批判

「言語コアに手を入れるか／3rd-partyライブラリで済むか」という二分法は、判断軸を1つに絞り込みすぎている。実際には以下の独立した軸で評価すべき問題である。

1. どのMoonBitバックエンドを境界に選ぶか（native/C ABI か、wasm-gc + Component Model か）
2. GCをまたぐオブジェクトの所有権をどう扱うか（自動統合か、明示的handle管理か）
3. 選んだバックエンドの実装がオープンソースで検証・拡張可能か、非公開のブラックボックスか

3番目の軸は調査の過程で最も重要な発見となった（後述）。

---

## 経路A: nativeバックエンド（C ABI）を境界にする

### 確認できたこと

- MoonBitのnativeバックエンドは内部IRの最終層がCのサブセットであり、 `extern "C" fn moonbit_name(...) -> T = "c_symbol_name"` でMoonBit側からC関数を呼ぶ経路（**import方向**）は公式ドキュメント・[C-FFIガイド](https://www.moonbitlang.com/pearls/moonbit-cffi)に明記されている。
- 逆方向（**export方向**）について、当初「公式ドキュメントに記載がない」としていたのは**誤り**（2026-07-31 追記で訂正）。実際には [FFIドキュメント](https://docs.moonbitlang.com/en/latest/language/ffi.html) に `#export_name` 属性が明記されている。

  ```moonbit
  #export_name("add")
  pub fn add_one(value : Int) -> Int {
    value + 1
  }
  ```

  ただし同じ節に次の限定が明記されている。

  > The native backend does not currently support exporting a `foreign_library` package as a library artifact.

  この限定は「非公開だから検証できない」という推論より**強く、かつ性質が異なる主張**である。前者は観測不能性に基づく不確実性（非公開ABIが無告知で変わりうる）だが、後者はMoonBitチームが公式にアナウンスした既知の未対応（ロードマップ項目としてIssue等で進捗を追える）。帰結（現時点でexport方向は使えない）は近いが、リスクの種類は異なるため、後述の結論部分もこの区別を反映するよう修正した。

#### 実測検証（2026-07-31、 `spike-native-export/` ）

上記の制約が実機（ローカルにインストール済みの `moon 0.1.20260729` / `moonc v0.10.5+5e7afb0c0`）でも再現するかを、ドキュメントの例をそのまま最小構成で再現して確認した。

```moonbit
// export_spike.mbt
#export_name("add")
pub fn add_one(value : Int) -> Int {
  value + 1
}
```

```moonbit
// moon.pkg
pkgtype(kind: "foreign_library")
```

| ターゲット | 結果 |
| --- | --- |
| `moon build --target native` | **失敗**（exit 255） |
| `moon build --target wasm-gc` | 成功（exit 0）。生成された `.wasm` に `add` という文字列が実際に含まれることをバイナリレベルで確認済み |
| `moon build --target js` | 成功（exit 0） |

nativeターゲットの実際のエラーは次の通り。

```console
Undefined symbols for architecture arm64:
  "_main", referenced from:
      <initial-undefines>
ld: symbol(s) not found for architecture arm64
clang: error: linker command failed with exit code 1 (use -v to see invocation)
```

**この失敗モードは重要な情報を含む。** `pkgtype(kind: "foreign_library")` を明示的に指定したにもかかわらず、native ターゲットのリンク処理は無条件に実行可能ファイルとして `main` シンボルを要求している。つまり「exportには対応していないが、ライブラリ成果物としてリンクだけは通る」という中間状態ではなく、**foreign_libraryというpkgtype自体がnativeターゲットのビルドパイプラインに正しく伝播していない**ように見える。エラーメッセージも「foreign_libraryは未対応です」という趣旨の専用メッセージではなく、汎用的なリンカエラーとして現れる。ドキュメントの限定（L37）は実機で再現し、かつ失敗の形は「機能制限による明示的エラー」ではなく「そもそも想定された経路として実装されていない」ことを示唆する。

→ **経路A（native）で「Kotlin/SwiftからMoonBitの `pub fn` を呼ぶネイティブライブラリ」を今すぐ作ることは、公式にサポートされた手段では不可能であることが実測で確定した。**

この実測結果は、 `moonbitlang/moon` のソースコード上のドキュメントコメントとも完全に一致する。 `crates/moonutil/src/package.rs` の `PackageKind` 定義：

```rust
/// - `foreign_library`: a non-main library force-linked into a standalone,
///   foreign-consumable artifact (equivalent to the deprecated `link: true`).
///   Not yet supported on the native/LLVM backends.
```

さらに `NativeLinkConfig` 構造体には、moonチーム自身によるFIXMEコメントが残っている。

```rust
// FIXME: We have no way to force link a native library when not `is_main`
```

→ これは「ドキュメントに書き忘れているだけの未確認事項」ではなく、**開発チーム自身が課題として認識し、コード上に明示的に残している既知の未解決問題**である。pkgtype `foreign_library` はnative向けの `link.native.exports` という設定項目自体はスキーマ上存在する（＝将来サポートする設計上の置き場所は用意されている）が、実際のビルドパイプラインには配線されていない。

#### 重要な追加発見（2026-07-31）: `moon` の未配線 ≠ `moonc` の未対応。手動リンクで実際に動作した

上記の失敗の切り分けをさらに進め、「リンクに失敗した `export_spike.o` の中身自体は正しいのか」を実測した。結果、**moonc（非公開コンパイラ）の側は `#export_name` を正しくコード生成に反映しており、問題は `moon` （オープンソース）のリンクオーケストレーションだけに閉じている**ことが判明した。

```console
$ nm _build/native/debug/build/__moonbit_link_core__/export_spike.o | grep add
0000000000000000 T __M0FP211connect045913export__spike8add__one
0000000000000008 T _add
```

`_add` という、まさに `#export_name("add")` で指定した通りのクリーンなCシンボルが、オブジェクトファイルに正しく生成されている。「非公開だから命名規則が安定しているか分からない」という懸念は、少なくともこの1点（ `#export_name` で指定した名前がそのまま使われる）については実測で解消された。

そこで、moonのビルド成果物（ `_build/native/debug/build/` 配下の `.o` ファイル群、および `~/.moon/lib` にバンドルされているランタイム補助オブジェクト）を使い、 `moon` が行っていないリンクを手動で代行できるか検証した。

```bash
cc -shared -o libexportspike.dylib \
  _build/native/debug/build/__moonbit_link_core__/export_spike.o \
  _build/native/debug/build/runtime.o \
  ~/.moon/lib/moonbit_simdutf.o \
  ~/.moon/lib/simdutf.o \
  ~/.moon/lib/libbacktrace.a
# => リンク成功（exit 0）
```

さらに、実際にC側から呼び出して正しい値が返ることまで確認した。

```c
// test_call.c
extern int add(int);
int main() {
  printf("add(41) = %d\n", add(41));   // => 42
  return 0;
}
```

```console
$ ./test_call
add(41) = 42
```

**MoonBitのコードをネイティブ共有ライブラリとして、Cから正しく呼び出すところまで、2026-07-31時点で実際に動作させることができた。**

##### この発見が結論に与える影響（要更新）

これまでの結論（「経路Aは公式手段では不可能」）は依然として真だが、その含意はかなり緩和される。

- 欠けているのは `moonc` の非公開コード生成部分ではなく、 `moon` （AGPLv3、オープンソース）のリンクオーケストレーション層に限定された、狭く・原因の分かっている1つのギャップ（FIXMEコメント通り）である。
- この手動リンクは**現時点では非公式・無保証**である。 `~/.moon/lib` 配下のファイル構成・命名（ `runtime.o` , `moonbit_simdutf.o` 等）はmoonの内部実装詳細であり、正式な「native向けライブラリ作成手順」として文書化・契約化されたものではない。したがってツールチェーンのバージョンが変わればファイル名・要求されるオブジェクトの組み合わせが無告知で変わりうる。**「moonチームが約束していない手順に依存している」というリスクは残る。**
- ただし、このリスクの性質は「非公開の内部実装への依存」ではなく「**公開されているが未文書化の内部レイアウトへの依存**」である。 `moon` のソース（オープンソース）を読めばこの手順がなぜ必要かを追跡でき、moonのアップデートで壊れても差分から原因を追える。完全なブラックボックスに対する依存より扱いやすい。
- 実務上の選択肢が2つ増えた。(1) この手動リンクをラップする自前のビルドスクリプトを保守し、moonのアップデート時に追随する。(2) `moon` はオープンソースであり、この欠落（FIXMEコメント）はmoonチーム自身が認識している既知の課題であるため、上位（ `moonbitlang/moon` ）へのコントリビュートを検討する余地がある。2026-07-31時点で `moonbitlang/moon` のIssueにはこの件を明示的に追跡しているものは見当たらなかった。

#### JNI経由でのKotlin/JVM実呼び出し検証（2026-07-31、 `spike-native-export/jni-test/` ）

「Kotlin(JVM)から実際に呼べるか」を検証するため、JNI境界まで含めたエンドツーエンドのスパイクを行った。ローカルにKotlinコンパイラ（kotlinc）が未導入だったため、**素のJavaをJNI境界の検証代理として使用した**。この代替は妥当と判断している。KotlinのJVMターゲットにおける `external fun` は、JavaのJNI `native`メソッドとバイトコード・JNIシンボル規約のレベルで完全に同一のものへコンパイルされる（JNIの `Java_<class>_<method>` 命名規則やメソッド登録の仕組みはJVMバイトコードレベルの概念であり、ソース言語がKotlinかJavaかを区別しない）。したがってこの検証はKotlinから呼んだ場合と技術的に同一の境界を通る。**ただし実際のkotlinc出力そのものでの確認ではない**ことは明記しておく。

構成:

```java
// ExportSpikeTest.java
public class ExportSpikeTest {
    static {
        System.loadLibrary("exportspike_jni");
    }
    public static native int add(int value);
    public static void main(String[] args) {
        System.out.println("add(41) = " + add(41));
    }
}
```

```c
// jni_shim.c — moonbit-tree-sitterの薄いCスタブと同型のパターン
#include <jni.h>
extern int add(int);
JNIEXPORT jint JNICALL Java_ExportSpikeTest_add(JNIEnv *env, jclass clazz, jint value) {
    return add(value);
}
```

このJNIシムをコンパイルし、既出のMoonBitオブジェクト（ `export_spike.o` , `runtime.o` , simdutf/backtrace補助オブジェクト）と一緒に1つの `.dylib` にリンクした。

```console
$ java -Djava.library.path=. ExportSpikeTest
add(41) = 42
```

**MoonBitで書いた関数を、JNI経由でJVM（Kotlinと同一のバイトコード境界）から呼び出し、正しい実行結果を得るところまでエンドツーエンドで確認できた。** シム自体は `moonbit-tree-sitter` が採用していた「薄い手書きCスタブ」パターンと同型であり、経路A全体を通じて一貫した設計（MoonBit本体を変更せず、境界にプラットフォーム固有の薄いCグルーコードを置く）が成立することも合わせて確認された。

残る未検証事項（当時）: 実際のkotlinc出力での確認、Android実機/NDKクロスコンパイルでの再現、複合型（文字列・構造体等）を跨いだ場合のJNI境界でのマーシャリング・ライフタイム管理（本ノート冒頭で確認した `#borrow` 属性や明示的close/deinitパターンとの整合）。

#### 実際のkotlinc出力での再検証（2026-08-01、 `spike-native-export/kotlin-test/` ）

上記のJava代理検証を、実機の `kotlinc`（2.4.10、Homebrew経由でインストール）でも確認した。

```kotlin
// ExportSpikeKotlinTest.kt
external fun add(value: Int): Int

fun main() {
    System.loadLibrary("exportspike_jni_kotlin")
    val result = add(41)
    println("add(41) = $result")
    check(result == 42) { "unexpected result: $result" }
}
```

コンパイル後のクラスファイルを `javap` で確認すると、トップレベルの `external fun` は次の通り静的native methodとして出力されることが分かった。

```console
$ javap -p ExportSpikeKotlinTestKt.class
public final class ExportSpikeKotlinTestKt {
  public static final native int add(int);
  ...
}
```

これはJavaの `public static native int add(int)` と完全に同一のシグネチャであり、事前の推測（KotlinのJNI境界はJavaと同一）を裏付けている。JNIシンボル名も推測通り `Java_ExportSpikeKotlinTestKt_add` （ファイル名 + `Kt` サフィックスというKotlinのトップレベル関数コンパイル規則通り）であり、同じCスタブパターンでリンクできた。

```console
$ java -Djava.library.path=. -cp app.jar ExportSpikeKotlinTestKt
add(41) = 42
```

**実際のkotlinc出力を使い、Kotlin(JVM)からMoonBit native関数を呼び出すところまで確認できた。** これにより「Javaを代理にした検証」という留保は解消された。MoonBit側のオブジェクトファイル（ `export_spike.o` , `runtime.o` 等）は前回のJava検証時と完全に同一のものを再利用しており、**1つのnative成果物を複数のJVM言語（Java/Kotlin）から共用できる**ことも合わせて確認された。

#### Swift（Cモジュールマップ経由）実呼び出し検証（2026-08-01、 `spike-native-export/swift-test/` ）

残っていたSwift側の検証を行った。JNIの薄いCスタブと対をなす、Swift Package Managerの `systemLibrary` ターゲット（モジュールマップ＋ヘッダのみ、実体は事前ビルド済みの `.dylib` にリンク）という、Swiftのエコシステムで最も標準的なCライブラリ取り込み方式を採用した。

```modulemap
// Sources/CMoonBitExport/module.modulemap
module CMoonBitExport {
    header "shim.h"
    export *
}
```

```c
// Sources/CMoonBitExport/shim.h
int add(int value);
```

```swift
// Sources/ExportSpikeSwiftTest/main.swift
import CMoonBitExport

let result = add(41)
print("add(41) = \(result)")
precondition(result == 42, "unexpected result: \(result)")
```

リンク対象のライブラリは、Java/Kotlin検証時と全く同じ手順（ `export_spike.o` + `runtime.o` + moonバンドルのsimdutf/backtrace補助オブジェクト）で `libexportspike_swift.dylib` として再構築した。`Package.swift` の `executableTarget` にリンカフラグ（ `-L`, `-lexportspike_swift`, `-rpath` ）を設定し、`swift build` / `swift run` した。

```console
$ swift run
Building for debugging...
Build of product 'ExportSpikeSwiftTest' complete!
add(41) = 42
```

**Swift(Cモジュールマップ経由)からもMoonBit native関数を正しく呼び出せることを確認した。** これで経路Aの主要3ターゲット（プレーンC、JNI経由のJava/Kotlin、Cモジュールマップ経由のSwift）すべてで、同一のMoonBitオブジェクトファイル群を土台に、各プラットフォームの標準的なFFI機構（JNI / Cモジュールマップ）を使った呼び出しが実測で確認できたことになる。MoonBit本体・moonc側には一切手を入れておらず、境界に置いた薄いプラットフォーム固有グルーコード（JNIシムまたはモジュールマップ）だけで完結している。これは本ノート冒頭で確認した `moonbit-tree-sitter` の設計（薄い手書きCスタブ）およびUniFFI型のアーキテクチャと構造的に一致する。

残る留保: 今回はmacOSホスト上のarm64向けビルド・SwiftPM CLI（`swift build`/`swift run`）での確認であり、実際のiOS実機/シミュレータ向けクロスコンパイルやXcodeプロジェクト経由でのテストではない。ビルド時に「macOS-11.0向けだが実際はより新しいOSでビルドされたdylibとリンクしている」という警告が出ており、iOS向けにはデプロイメントターゲット・アーキテクチャの整合を別途取る必要がある。

#### 複合型（文字列・構造体）のマーシャリング検証（2026-08-01、 `spike-native-export/complex-types-test/` ）

ここまではInt一つの単純なケースのみだった。文字列とレコード型（struct）がFFI境界をどう越えるかを実測した。使用したのは、ツールチェーンに同梱されている公式ヘッダ `~/.moon/include/moonbit.h`（ `moonbit-tree-sitter` が `#include <moonbit.h>` で使っているのと同じもの）。

対象のMoonBitコード（ `complex_types.mbt` 、既存の `spike-native-export` パッケージに追加）:

```moonbit
#export_name("make_greeting")
pub fn make_greeting() -> String {
  "Hello from MoonBit!"
}

#export_name("string_length")
pub fn string_length(s : String) -> Int {
  s.length()
}

pub struct Point {
  x : Int
  y : Int
}

#export_name("make_point")
pub fn make_point(x : Int, y : Int) -> Point {
  { x, y }
}

#export_name("point_x")
pub fn point_x(p : Point) -> Int {
  p.x
}

#export_name("point_y")
pub fn point_y(p : Point) -> Int {
  p.y
}
```

**文字列（String）:** MoonBitの `String` はUTF-16表現であり、C側からは `moonbit.h` が定義する `typedef uint16_t *moonbit_string_t;` として見える。長さは通常の配列と同じ `Moonbit_array_length(obj)` マクロ（オブジェクトヘッダの `meta` フィールドを読む）で取得する。

- MoonBit→C（戻り値）: `make_greeting()` の戻り値をそのまま `moonbit_string_t` として受け取り、 `Moonbit_array_length` で長さ19、各 `uint16_t` 要素をASCII文字として読んで `"Hello from MoonBit!"` を正しく復元できた。
- C→MoonBit（引数）: `moonbit_make_string_raw(len)` でC側からMoonBit管理下の文字列バッファを確保し、ASCII文字を1コード単位ずつ書き込んで（UTF-16のASCII範囲は1文字1コード単位）`"Kotlin"` を構築、 `string_length()` に渡したところ正しく6が返った。

**構造体（struct、非newtype）:** 本ノート冒頭で確認した「newtypeラッパー構造体はABI上透過」という知見に対し、複数フィールドを持つ通常の `struct` がどう扱われるかを検証した。C側では `Point` を中身の分からない**不透明ハンドル（`void*`）**として扱い、フィールドへのアクセスはMoonBit側でexportしたアクセサ関数（`point_x`/`point_y`）経由のみで行った（内部レイアウトを直接読みには行っていない）。これは `moonbit-tree-sitter` の `Language` ハンドルパターンと同じ設計であり、`Point` が実際に参照カウント付きのヒープオブジェクトなのか、レジスタに収まる値型として扱われているのかを問わず、常に正しく動作する頑健な利用法である（今回はこの問いの決着自体は目的としていない）。

```console
$ ./test_complex
length=19, chars="Hello from MoonBit!"
string_length("Kotlin") = 6
point = (3, 4)
OK
```

**ライフタイム・参照カウントの簡易検証:** 上記はいずれも単発呼び出しのみだったため、繰り返し呼び出しでのクラッシュ・リークの有無を200万回のループで確認した。C側からは `moonbit_incref` / `moonbit_decref` を一切呼んでいない。

```c
for (int i = 0; i < 2000000; i++) {
    moonbit_string_t g = make_greeting();
    sum += Moonbit_array_length(g);
    void *p = make_point(i, i + 1);
    sum += point_x(p) + point_y(p);
}
```

```console
$ /usr/bin/time -l ./stress_test
iterations=2000000 sum=4000038000000
        0.36 real         0.04 user         0.00 sys
            33554432  maximum resident set size
```

200万回の反復で `sum` の値は理論値（`N^2 + 19N` = 4,000,038,000,000）と完全に一致し、クラッシュも発生せず、ピークメモリも約33MBで安定していた（2M件のオブジェクトを無管理のまま保持し続けていたら数百MB規模になっているはずである）。**C側で明示的なincref/decrefを一切行わなくても、「MoonBit関数から受け取った値をすぐに別のMoonBit exported関数に渡して使い切る」というこの利用パターンでは、リークも破損も発生しないことを実測で確認した。**

ただし、これは限定的な確認である。**「C側がMoonBitオブジェクトを複数回の別々の呼び出しをまたいで長期保持する」というパターン（JNIでKotlin側がMoonBitオブジェクトをラップしたハンドルとして保持し続けるような、より実務的なケース）は今回検証していない。** この場合に明示的な `moonbit_incref` / `moonbit_decref` の呼び出しが必要になるのか、その責任がどちらの側にあるのかは未確認であり、本ノート冒頭の結論4（opaqueハンドル＋明示的close/deinit方式を採用すべき）の妥当性を実務的なコード規模で検証する際の次の課題として残る。

### `moonbitlang/moonbit-native-runtime` の実装確認

`include/moonbit.h` （コンパイラのランタイム実装のミラー、生成Cコードとユーザー側Cスタブが共にリンクする対象）より。

- **非移動（non-moving）・参照カウント方式のGCである。**

  ```c
  #define Moonbit_rc_count(header) (((int32_t)(header)->rc) >> MOONBIT_RC_COUNT_SHIFT)
  MOONBIT_EXPORT void moonbit_incref(void *obj);
  MOONBIT_EXPORT void moonbit_decref(void *obj);
  ```

  トレーシング／コピーGCではないため、オブジェクトへの生ポインタはヒープ内で安定しており、正しく参照カウントを操作する限りFFI境界の外へ持ち出せる（トレーシングGC言語より制約が緩い）。

- **ホスト所有オブジェクトをMoonBitのRC管理下に置く仕組みが既にある。**

  ```c
  MOONBIT_EXPORT void *moonbit_make_external_object(
    void (*finalize)(void *self),
    uint32_t payload_size
  );
  ```

  ただし、後述の `moonbit-tree-sitter` の実例では、この機構は実際には**使われていない**（後述）。

- ランタイムのアロケーション・文字列/配列生成・incref/decrefなどはすべて `MOONBIT_EXPORT` でCリンケージとして公開されている。

### `moonbitlang/moonbit-tree-sitter` の実例確認（import方向の実運用例）

tree-sitter（C製の構文解析ライブラリ）へのMoonBitバインディング。export方向の直接証拠ではないが、実際に運用されている境界設計として参考になる。

- **薄い手書きCスタブファイル**（ `src/tree-sitter.c` ）が境界を構成する。自動生成ではない。

  ```c
  MOONBIT_FFI_EXPORT
  const TSLanguage *
  moonbit_ts_language_copy(const TSLanguage *self) {
    return ts_language_copy(self);
  }
  ```

  `#include <moonbit.h>` し、 `Moonbit_array_length(name)` 等のマクロでMoonBitのBytes等を直接読む。

- **newtypeラッパー構造体はABI上完全に透過**（ボクシングのオーバーヘッドなし）。

  ```moonbit
  pub(all) struct Language(@tree_sitter_language.Language)
  ```

  C側では素の `const TSLanguage *` として渡される。

- **`#borrow(name)` 属性が実運用で使われている**（所有権注釈。引数がFFI境界を越える際にMoonBit側のRCを「借用」するか「消費」するかを制御する）。

  ```moonbit
  #borrow(name)
  extern "c" fn ts_language_symbol_for_name_(language : Language, name : Bytes) -> UInt16 = "..."
  ```

- **重要な修正点：ライフタイム管理は「自動GC統合」ではなく「明示的な取得・解放メソッド対」だった。**
  - `moonbit_make_external_object` によるMoonBit GCへの自動組み込みは使われておらず、tree-sitter自身のC APIが持つ手動参照カウント（ `ts_language_copy` / `ts_language_delete` ）を、MoonBit側でも `Language::copy()` / `Language::delete()` という明示的メソッド対としてそのまま公開している。
  - 2つの独立したメモリ管理システムを自動的に相互接続する設計（ファイナライザ順序の非決定性、二重解放のリスク）を、MoonBitチーム自身が実務上回避したと解釈するのが妥当。これはUniFFIが生成するKotlinの `Closeable` やSwiftの明示的破棄パターンと構造的に同型。

### `moonbitlang/moonbit-compiler` のシンボル命名規則調査

- `src/basic_qual_ident.ml` に `to_wasm_name` という関数があり、 `pkg.name` の完全修飾名から `$pkg.name` 形式（特殊文字はBase64エンコード、 `mangle_wasm_name` ）で決定的に名前を導出する規則がソースから確認できた。**ただしこれはWasmバックエンド専用**（関数名が明示的に `to_wasm_name` ）。

- **`src/` 配下265ファイルを全数確認したが、native backend向けのCコード生成（Clam→Cに相当する変換）ファイルは1つも存在しない。**
  - `wasm_of_clam_gc.ml` （Clam→Wasm-GC）に相当する native 版が無い。

- README.mdに明記されている決定的事実：
  > So far, we have open-sourced the core library and most tools...
  > **Open-sourcing the Wasm backend is another major step**, and it is on our roadmap
  > to open source more (moonfmt, moondoc) in the future.

  → **現時点でオープンソース化されているのはWasm/Wasm-GCバックエンドのみ。nativeバックエンドのCコード生成部分は非公開（クローズドソース）。**

  この事実により、「nativeバックエンド経由でexport方向のシンボル命名規則が安定しているか」という問いは、ソースを読んで検証することが原理的にできないと判明した。技術的成熟度の問題ではなく、
  可観測性・ガバナンスの問題である。

#### 追記（2026-07-31）: 「C backend」という別名の実体を `moonbitlang/moon` で確認

公式ブログ・リリースノートに「release buildはC backend、debug buildは新しいnative backend」という記述があり、native backendとは別に検証可能な「C backend」が存在するのではという仮説を立てて検証した。ビルドオーケストレータ本体である [`moonbitlang/moon`](https://github.com/moonbitlang/moon)（Rust製、オープンソース）を確認した結果、**この仮説は棄却された**。

- `crates/moonutil/src/target.rs` に `TargetBackend` enumが定義されている。

  ```rust
  pub enum TargetBackend {
      Wasm, WasmGC, Js, Native, LLVM
  }
  ```

  選択可能なターゲットは `wasm` / `wasm-gc` / `js` / `native` / `llvm` の5つのみで、**独立した `c` ターゲットは存在しない**。

- 決定的な行は `to_artifact()` メソッド：

  ```rust
  pub fn to_artifact(self) -> &'static str {
      match self {
          ...
          Self::Native => "c",
          ...
      }
  }
  ```

  「native」ターゲットの中間成果物形式が文字通り `c` である。つまりブログの言う「C backend」「new native backend」は、**単一の `Native` ターゲットが内部で持つ2種類のコード生成戦略**（ `MOONBIT_NEW_NATIVE` 環境変数で切替。旧: Clam→C source→システムcc/tccでコンパイル、新: Clamから直接ネイティブコードへ、debug buildの高速化が目的）を指しているに過ぎない。両戦略とも実装は `moon`（オープン、単なるビルドオーケストレーション）ではなく非公開の `moonc` バイナリの内部にあり、 `moonbit-compiler` リポジトリにも実体は存在しない。

  → **「C backendなら経路Aの検証不能性を回避できるのでは」という迂回路は存在しない。** native/C backendの別名混同はこのノートの誤りであり、対象は一貫して単一の `Native` ターゲット（内部戦略が2つあるだけ）として扱うべきである。

### ライセンス上の留意点

MoonBit Public Source License（relaxed SSPL）:

- コンパイラの改変は**非商用目的に限り**許可される。
- 生成物（ユーザーのMoonBitコード・成果物）は任意のライセンスを選べる。
- 商用でのフォーク配布には制限がかかる可能性がある。

---

## 経路B: wasm-gcバックエンド + Component Modelを境界にする

### 確認できたこと

- `wasm-gc` ターゲットでは `pub fn` による明示的exportと `moon.pkg.json` での制御が可能。非数値の戻り値は `externref` （ホスト側からは不透明な参照）としてラップされる設計がコンパイラの標準機能として既に存在する。GC境界をまたいでオブジェクトの内部を共有しない、という正しい設計方針が最初から組み込まれている。

- MoonBitはBytecode AllianceのWasm Component Model（言語非依存のインターフェース定義=WITから各言語バインディングを生成する標準規格）に対応した実装ページを持つ
  （[component-model.bytecodealliance.org](https://component-model.bytecodealliance.org/language-support/building-a-simple-component/moonbit.html)）。

- 命名規則・export機構ともに**オープンソースのWasmバックエンド内で完結しており、ソースコードで検証可能**。

### ホスト側ランタイムの実態調査（2026-07-31）

MoonBitの `wasm-gc` バックエンドは、その名の通りWebAssembly GC提案（structs/arrays/i31ref）を土台にMoonBit自身のヒープオブジェクトを表現する設計である。つまりホスト側ランタイムにとって「Wasm GC提案への対応」は任意のオプションではなく**必須要件**である。この前提でChicory・WasmKitそれぞれの現状を一次情報（README、Issue、PR）で確認した。

#### Chicory（JVM側候補）

- **Wasm GC提案: 実装済み。** ただし極めて新しい。PR [#1204](https://github.com/dylibso/chicory/pull/1204)「WasmGC in the interpreter」がマージされたのは2026-02-18、直近リリース1.7.5は2026-03-24。**2026-07-31時点で実運用実績は4〜5ヶ月程度**。README公式ロードマップでは「2026年: GC support ✅」の直後に「Performance ☐」が未達のまま残っている。
- **GC統合に関する未解決の設計課題がある。** Issue [#1216](https://github.com/dylibso/chicory/issues/1216)（2026-04-23、OPEN）: 現状の `GcRefStore` はWasmオブジェクトグラフを整数IDで表現し、実際のJavaオブジェクト参照としては保持していないため、**JVMのGCはWasm GCオブジェクトを回収できない**。代わりに1024アロケーションごとの独自mark-sweepで賄っている。つまりMoonBit側のstruct/arrayがFFI境界を頻繁に往復するようなワークロードでは、JVM標準のGCチューニング（世代別GC等）が効かず、独自スイープのタイミング・コストを別途検証する必要がある。
- **AOTコンパイラエンジンでの対応は未確認。** PRタイトルが一貫して「in the interpreter」であり、Chicoryが持つ2つのエンジン（インタプリタ／AOTコンパイラ）のうちAOT側でWasm GCがサポートされているかは今回のIssue/PR調査からは確認できなかった。AOT非対応の場合、MoonBitロジックはインタプリタ実行に限定され、経路Bの`a`（実行性能）に対する当初の期待値をさらに下げる。
- **Component Model: 未実装。** Issue [#673](https://github.com/dylibso/chicory/issues/673)（2024年オープン、後にCOMPLETEDとしてクローズされているが実質的には見送り）でメンテナから明言：「Component Modelは現状Phase 1でまだ大きく変わりうる」「WASI P1の安定化を優先し、Component Modelはエコシステムが追いつくまでさらに時間がかかる」。それ以降、Issue/PR検索でComponent Model関連の進捗は一件も見つからなかった。

#### WasmKit（Swift側候補）

- **Wasm GC提案: 未実装（❌ Not implemented）。** README記載の対応表で明記されている。しかも前提となる Typed Function References 提案（構造化recursive typeの土台）自体も「🚧 Parser implemented」止まりで、意味論的な実行には未対応。GC関連のIssue/PRを検索したが**1件もヒットしなかった**（着手した形跡がない）。
- **Component Model: 開発は活発だが未リリース。** README上は「🚧 In progress（ `main` ブランチ）」。実際、component binary parser・WAT parsing・ `ComponentTypeSerializer` ・WAVE CLI対応など2026年1〜3月にかけて継続的にPRがマージされており（例: [#291](https://github.com/swiftwasm/WasmKit/pull/291), [#293](https://github.com/swiftwasm/WasmKit/pull/293), [#319](https://github.com/swiftwasm/WasmKit/pull/319)）、エンジニアリング投資自体は本物である。ただし直近リリース0.3.1（2026-07-08）にはまだ含まれておらず、 `main` ブランチ限定。

#### この調査がもたらす結論への影響

これは「ホスト側の成熟度次第」という程度問題ではない。**Wasm GC提案がMoonBitのwasm-gc出力を実行するための必須要件である以上、WasmKitがGCを一切実装していない現状は、iOS側での経路Bを現時点で完全にブロックする。** Component Modelの進捗状況とは独立に、GCのないランタイムはMoonBitのwasm-gcモジュールをロードすらできない。Android側（Chicory）はGC自体は動くが、(a) 実績が4〜5ヶ月と浅い、(b) JVM GCとの統合を欠く既知の設計課題が未解決、(c) AOTエンジンでの対応が未確認、という3つの留保がつく。

代替として、WasmKitではなくwasmtime/wasmiのSwiftバインディング（GC対応済みのRust製ランタイムを埋め込む）という道もあるが、これは「純Swift・ネイティブ依存なし」という経路Bが本来評価されていた強み（ABI非依存・配布の単純さ）を後退させ、経路Aと同種のネイティブツールチェーン依存を再導入することになる。この選択自体が`c`（配布・保守のシンプルさ）を毀損するため、単純な代替にはならない。

---

## 経路A・B比較まとめ

| 観点 | 経路A: native / C ABI | 経路B: wasm-gc + Component Model |
| --- | --- | --- |
| GCモデル | 非移動RC（incref/decref）、生ポインタが安定 | GC境界はexternref/handleで隠蔽済み |
| export機構の言語仕様 | `#export_name` が存在（言語機能としては文書化済み） | `pub fn` + `moon.pkg.json` で公式サポート |
| export機構の実サポート状況 | `moon` （ビルドオーケストレーション）は `foreign_library` のnativeライブラリ成果物exportに現状未対応と公式に明言。**ただし2026-07-31の実測で、moonc自体は `#export_name` を正しくコード生成に反映しており、手動リンク（ `cc -shared` ）でC呼び出し可能な `.dylib` を実際に作成・動作確認済み**（ `spike-native-export/` ）。欠落は `moon` のリンク工程1点に限定される | サポート済み |
| ソースでの検証可能性 | native ターゲットのコード生成自体（旧: Clam→C、新: 直接ネイティブコード）は非公開の `moonc` バイナリ内で検証不可。**ただし生成される出力（Cシンボル名等）はビルドごとに観測可能であることを実測で確認**（ `_add` シンボルが `#export_name` 指定通りに出力）。欠けているリンク工程は `moon` （オープンソース、AGPLv3）側にあり、追跡・修正の余地がある | 可能（Wasmバックエンドはオープンソース） |
| ライフタイム管理の実例 | 明示的retain/release（tree-sitter実例） | 未調査（同様のパターンが妥当と推測） |
| ホスト側ツールチェーン成熟度 | JNI/Panama, Kotlin/Native cinterop, Swift Cモジュールマップ — 成熟 | **非対称**: Chicory(JVM)はWasm GC実装済みだが4〜5ヶ月と若くJVM GC非統合の既知課題あり／WasmKit(Swift)はWasm GC**未実装**（iOS側を現状ブロック）。Component ModelはChicory未着手・WasmKit進行中未リリース |
| 長期的保守可能性 | 公式にアナウンス済みの制約＋非公開実装の二重のリスク。制約解消時期も非公開実装の安定性も外部からは追跡できない | オープンソース部分に依存、第三者が保守可能 |

---

## 現時点の結論

1. **言語コア（構文・型システム・意味論）への変更は、いずれの経路でも不要。**
   - 両バックエンドとも他言語連携を意図した境界機構（extern C、wasm export、Component Model）を最初から備えている。

2. **経路Aの評価は、公式サポートの欠如と実際の動作可否を切り分けると、当初より前向きに修正される。** (a) `moon` （ビルドオーケストレーション）が `foreign_library` のnativeライブラリ成果物exportを公式サポートしていないことは実機でも再現した（ `pkgtype(kind: "foreign_library")` を指定してもnativeビルドは無条件に `main` シンボルを要求してリンクエラーになる）。(b) しかし2026-07-31の追加実測で、**この欠落は `moonc` （非公開）のコード生成部分ではなく、 `moon` （オープンソース、AGPLv3）のリンク工程1点に限定されることが判明した**。 `moonc` は `#export_name` で指定した通りのクリーンなCシンボル（ `_add` ）をオブジェクトファイルに正しく出力しており、これを手動リンク（ `cc -shared` ＋MoonBitランタイムの補助オブジェクト）することで、実際にCから呼び出し可能な `.dylib` を作成し、 `add(41) == 42` という正しい実行結果まで確認済みである。
   - この手動リンクは非公式・無保証だが、依存先はブラックボックスの内部実装ではなく「未文書化だが観測可能な `moon` のビルド成果物レイアウト」である。 `moon` 自体がオープンソースであるため、この欠落（コード上のFIXMEコメントとして存在）を追跡・場合によっては修正提案することも選択肢に入る。
   - 残るガバナンス上の制約は、 `moonc` 自体（コード生成部分）が非公開である点のみであり、これは変わらず検証・拡張不能である。ただしその出力（シンボル命名等）は `#export_name` という文書化された言語機能に従っており、少なくとも命名規則の安定性という当初の懸念は実測により大きく後退した。

3. **経路B（wasm-gc + Component Model）は、命名規則・export機構がオープンソースで検証可能という点でMoonBit側の適格性は高いが、2026-07-31時点でホスト側実装がiOSを完全にブロックしている。**
   - 「ホスト側の成熟度次第」という程度問題ではない。WasmKit（Swift）はWasm GC提案を**未実装**（着手した形跡もない）であり、MoonBitのwasm-gc出力はGC提案が必須要件であるため、iOS側での経路Bは現時点で原理的に成立しない。
   - Android側（Chicory）はWasm GC自体は実装済みだが、実運用実績が4〜5ヶ月と浅く、JVM GCとの統合を欠く既知の設計課題（[dylibso/chicory#1216](https://github.com/dylibso/chicory/issues/1216)）が未解決、AOTエンジンでの対応も未確認。
   - Component Modelは両ランタイムとも未リリース（Chicoryは着手見送り、WasmKitは `main` ブランチで開発中）であり、経路B全体を今すぐ採用する根拠にはならない。

4. ライフタイム管理の設計は、 `moonbit_make_external_object` によるGC自動統合ではなく、UniFFI同様「opaqueハンドル＋明示的close/deinitで呼び出す解放関数」を採用すべき（MoonBitチーム自身の実例= `moonbit-tree-sitter` が明示的方式を選んでいることと整合）。

---

## 動機の確認と評価の更新

### 前提の確認

本ライブラリを作る動機は「KotlinMultiplatformのような体験でネイティブアプリなどを作れるヒントになること」であることを確認した。あわせて以下をヒアリングした。

1. 重視する点は (a) 実行時のネイティブらしさ・パフォーマンス と (c) ロジック共有によるコード重複削減 がほぼ同率、やや (c) 寄り。
2. Android側で想定しているのは Kotlin/JVM（通常のAndroidアプリ）であり、Kotlin/Nativeではない。
3. UI層の共有は最初からスコープ外（ロジック層のみの共有）。

### 「KMP的体験」との構造的なギャップ

KMPが実現しているのは次の3要素の同時成立である。

1. 単一のソース・単一のツールチェーン（Kotlinコンパイラ自身がAndroid向けJVMバイトコード・iOS向けKotlin/Nativeバイナリの両方を生成する）
2. 追加のランタイムを持ち込まない（各プラットフォームに元々1つだけ存在するランタイム＝JVM/Kotlin-Nativeの上で完結する）
3. `expect` / `actual` によるDXの一体感（「ライブラリを消費している」感覚がない）

MoonBit経由のアプローチは、このいずれも完全には満たさない。構造的にはKMPよりも、Rust製コアをUniFFI経由でKotlin/Swiftから消費する1PasswordやStripeのSDKアーキテクチャに近い。MoonBitという第三の言語・第三のランタイム（RCベースの独自GC、またはwasm-gcインタプリタ）を、JVM（Android）やSwift ARC（iOS）の上に追加で載せる設計であり、境界には常にFFI/マーシャリング層が明示的に存在する。なお、UI層を共有しない点はKMPの典型的な使われ方（UIはネイティブ、ロジックのみ共有）と天井が同じであり、この点自体は動機と矛盾しない。

### 優先度を踏まえた経路A/Bの再評価

- **「c: ロジック重複削減」はA/Bどちらでも原理的に得られる。** 一度書けば両OSで使い回せるという価値自体は境界の実装方式に依存しない。 `c` の実質は「重複削減が長期的に成立し続けるか」であり、それはFFI境界の**安定性**に依存する。この観点では、経路Aの「nativeバックエンドのCコード生成が非公開である」という既発見の事実は、単なるガバナンス上の懸念にとどまらず、非公開ABIが無告知に変化した場合にbinding層の保守コストが再発し続けるという形で、**`c` という優先事項そのものを直接毀損しうる**。

- **Android=Kotlin/JVMという前提により、配布方式の非対称性が明確になった。**
  - 経路A（native）: ABIごと（ `arm64-v8a` / `armeabi-v7a` / `x86_64` 等）に `.so` をNDKでビルドし、JNI/Panama経由で呼ぶ必要がある。iOS側もXcodeのネイティブツールチェーンが必要。 `a` （ネイティブらしさ・性能）に有利な一方、ビルド・配布の複雑さという形で `c` の実現コストを押し上げる。
  - 経路B（wasm-gc）: 単一の `.wasm` ファイルをChicory（純JVM）・WasmKit（純Swift）がABI非依存で解釈実行する。 `a` （インタプリタ実行によるオーバーヘッド）には不利だが、 `c` （配布・保守のシンプルさ）に寄与する。

- **結論の更新（2026-07-31、Chicory/WasmKit実態調査＋経路Aの手動リンク実測後）：経路Bは「机上では優位だが現状は選べない」、経路Aは「公式手段は未対応だが手動リンクで現に動く」という非対称な状態になった。** WasmKitがWasm GC提案を未実装である以上、iOS側で経路Bを今すぐ採用することは原理的にできない。一方、経路Aは `moon` の公式サポートこそ欠けているが、 `moonc` 自体は正しくCシンボルを出力しており、手動リンクで実際にC呼び出しまで確認済みである。したがって「非公開ABIという保守リスクを受け入れてでも経路Aを取る」という消極的な選択ではなく、「モックまで一度動かして初めて分かった、現実的に着手可能な選択肢」として経路Aを位置づけ直す必要がある。第一段階としてネイティブで試すという方針は、この実測結果によって裏付けられている。ただし手動リンクの再現性・保守コスト（moonのバージョン更新への追随）は未評価であり、これを次の実務的な検証対象とすべきである。

## 残課題（未検証）

- ~~Chicory / WasmKitのwasm-gc対応状況~~ → **2026-07-31調査済み**（本ノート「経路B」節参照）。Chicoryは実装済み（若い・JVM GC非統合の課題あり）、WasmKitは未実装。
- WasmKitのWasm GC提案着手の見込み・時期（Issue/PRが現状皆無のため、着手の兆候が出るまで定期的に追跡する必要がある）。
- ChicoryのAOTコンパイラエンジンでのWasm GC対応有無（インタプリタでの対応は確認済みだが、AOT側は未確認）。
- Chicory Issue [#1216](https://github.com/dylibso/chicory/issues/1216)（JVM GCとの統合）の解消見込み。
- MoonBitのComponent Model対応の実装レベル（どこまでのWIT型が実際にサポートされているか）。ただしChicory/WasmKitとも現時点でComponent Modelがリリース済みでない以上、優先度は下がった。
- 経路Bを選んだ場合の、複合型（レコード・variant・resource）のマーシャリングコストの実測。同様に、GC提案自体の対応がホスト側で揃うまでは着手する意味が薄い。
- **共有予定ロジックの性質（未着手・優先度高）**: 「Chicory/WasmKitの成熟度」と「性能要件を満たすか」は独立した命題である。前者はツールチェーンの機能対応、後者は実行するワークロードの特性（CPUバウンドな計算か、単なるルーティン処理か）に依存する。共有したいロジックの具体像（種類・計算量のオーダー・呼び出し頻度）をヒアリングし、wasm-gcインタプリタ実行で「許容範囲」とみなせる定量的な基準（例: ネイティブ比何倍まで許容するか）を先に言語化しない限り、Chicory/WasmKitの対応状況を確認しても経路Bの採否は判定できない。特にChicoryは現状インタプリタでのみWasm GCが動くため、この論点は「経路Bを選ぶかどうか」の判断により直接的に効いてくる。
- nativeターゲットの `foreign_library` ライブラリ成果物export未対応（本ノート「経路A」節、追記2026-07-31）が解消される見込み・時期のIssue追跡。 `moonbitlang/moon` 側に本件を明示的に追跡するIssueが存在しないため、必要なら自ら起票する選択肢がある。
- ~~経路Aを暫定採用する場合の意思決定~~ → **2026-07-31、ユーザーと合意し経路Aを第一段階として選択。** 以下がこれに伴う新たな残課題。
- **手動リンクの再現性・保守性の評価（優先度高）**: `spike-native-export/` の手動リンクは `~/.moon/lib` 内の未文書化なファイルレイアウト（ `runtime.o` , `moonbit_simdutf.o` , `simdutf.o` , `libbacktrace.a` ）に依存している。moonのバージョンが上がった際にこの構成が変わらないか、再現性をどう担保するか（例: 使用したmoon/moonc正確なバージョンをビルドスクリプトに固定する等）を検討する必要がある。
- **リリースビルドでの再現確認**: 今回の検証はdebug buildのみ。release build（ `MOONBIT_NEW_NATIVE` 環境変数の値によってコード生成戦略が変わる）でも同じ手動リンク手順が通るかは未確認。
- **Android（NDKクロスコンパイル）・iOS（Xcodeツールチェーン）への展開**: 今回の検証はmacOSホスト上のarm64向けのみ。ABIごとの `.so` / `.a` ビルド、および `libbacktrace` / `simdutf` 相当のクロスコンパイル済みオブジェクトの入手可否は未検証。
- ~~JNI（Kotlin側）経由の実呼び出し検証~~ → **2026-07-31確認済み**（本ノート「JNI経由でのKotlin/JVM実呼び出し検証」節）。ただしJava経由での代理確認であり、実際のkotlinc出力での確認ではない。
- ~~kotlinc実機での確認~~ → **2026-08-01確認済み**（本ノート「実際のkotlinc出力での再検証」節）。kotlinc 2.4.10でビルドした `external fun` から、Java検証時と同じMoonBitオブジェクトを使って正しく呼び出せることを確認した。
- ~~Swift Cモジュールマップ経由の実呼び出し検証~~ → **2026-08-01確認済み**（本ノート「Swift（Cモジュールマップ経由）実呼び出し検証」節）。SwiftPMの`systemLibrary`ターゲット経由で、Java/Kotlin検証と同一手順で再構築したdylibを正しく呼び出せた。
- **iOS実機/シミュレータ向けの確認（優先度中）**: Swift検証はmacOSホスト・SwiftPM CLIのみ。実際のiOS向けクロスコンパイル・Xcodeプロジェクト経由でのテストは未実施。
- ~~複合型（文字列・構造体）のマーシャリング~~ → **2026-08-01確認済み**（本ノート「複合型のマーシャリング検証」節）。文字列（双方向）・構造体（不透明ハンドル経由）とも正しく動作し、200万回ループでのクラッシュ・リークなしも確認した。
- **長期保持されるMoonBitオブジェクトのライフタイム管理（優先度高）**: 今回の複合型検証は「受け取ってすぐ使い切る」パターンのみ。JNIでKotlin側がMoonBitオブジェクトをハンドルとして長期保持し、複数回の別呼び出しをまたいで使うケースでの明示的incref/decrefの要否・責任の所在は未検証。
- **`moonbitlang/moon` へのコントリビュート検討**: FIXMEコメントで明示された既知の欠落であるため、この手動リンク手順を `moon` 本体に正式機能として提案する余地がある（AGPLv3ライセンス下での注意点を要確認）。

## 参考リンク

- [Foreign Function Interface (FFI) — MoonBit Documentation](https://docs.moonbitlang.com/en/latest/language/ffi.html)
- [A Guide to MoonBit C-FFI](https://www.moonbitlang.com/pearls/moonbit-cffi)
- [Introduce MoonBit native, up to 15x faster than Java in numerics!](https://www.moonbitlang.com/blog/native)
- [Consuming a High Performance Wasm Library in MoonBit from JavaScript](https://www.moonbitlang.com/blog/call-wasm-from-js)
- [MoonBit - The WebAssembly Component Model](https://component-model.bytecodealliance.org/language-support/building-a-simple-component/moonbit.html)
- [GitHub - dylibso/chicory: Native JVM WebAssembly runtime](https://github.com/dylibso/chicory)
- [GitHub - swiftwasm/WasmKit: WebAssembly Runtime written in Swift](https://github.com/swiftwasm/WasmKit)
- [dylibso/chicory#1204: WasmGC in the interpreter](https://github.com/dylibso/chicory/pull/1204)
- [dylibso/chicory#1216: Enable host JVM GC to collect unreachable WasmGC references](https://github.com/dylibso/chicory/issues/1216)
- [dylibso/chicory#673: Support WASI P2（Component Model見送りの経緯）](https://github.com/dylibso/chicory/issues/673)
- [swiftwasm/WasmKit#105: WASI Preview 2/component model support](https://github.com/swiftwasm/WasmKit/issues/105)
- [GitHub - moonbitlang/moonbit-native-runtime](https://github.com/moonbitlang/moonbit-native-runtime)
- [GitHub - moonbitlang/moonbit-compiler](https://github.com/moonbitlang/moonbit-compiler)
- [GitHub - moonbitlang/moonbit-tree-sitter](https://github.com/moonbitlang/moonbit-tree-sitter)
- [GitHub - moonbitlang/moon](https://github.com/moonbitlang/moon)（ビルドオーケストレータ本体。 `crates/moonutil/src/target.rs` に `TargetBackend` enum定義）
- 参考事例: UniFFI（Rust→Kotlin/Swift）

---

## 補遺: 参照リポジトリのローカルclone

一次情報の再検証のため、以下をローカルにcloneしてコードを済み（2026-07-31）。

- `moonbit-compiler` （OCamlフロントエンド。Clam→Wasm-GC codegenのみ確認可能。native/C向けcodegenは実体なし）
- `moon` （Rust製ビルドオーケストレータ。 `TargetBackend` enum確認用）
- `moonbit-native-runtime` （Cランタイムヘッダ。既存調査の再確認用）
