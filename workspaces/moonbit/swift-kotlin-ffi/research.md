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
- 逆方向（**export方向**：C/JVM/Swiftホストから任意のMoonBit `pub fn` を呼ぶための一般的な規約・ヘッダ生成）は、公式ドキュメントには記載がない。

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

### 未確認・要検証の課題

- ホスト側（Kotlin/Swift）のWasmランタイムの成熟度。
  - JVM側候補: [Chicory](https://github.com/dylibso/chicory)（純Java、JNI/ネイティブ依存なし）。wasm-gc完全対応・Component Model bindgenの現状は今回確認しきれていない。
  - Swift側候補: WasmKit（純Swift実装、SwiftWasm系）。同様に要確認。
- これらはMoonBit側の問題ではなく、エコシステム全体（ホスト言語側ツールチェーン）の成熟度の問題として切り分けるべき。

---

## 経路A・B比較まとめ

| 観点 | 経路A: native / C ABI | 経路B: wasm-gc + Component Model |
| --- | --- | --- |
| GCモデル | 非移動RC（incref/decref）、生ポインタが安定 | GC境界はexternref/handleで隠蔽済み |
| export機構のドキュメント | なし（import方向のみ文書化） | `pub fn` + `moon.pkg.json` で公式サポート |
| ソースでの検証可能性 | **不可（Cコード生成部分が非公開）** | 可能（Wasmバックエンドはオープンソース） |
| ライフタイム管理の実例 | 明示的retain/release（tree-sitter実例） | 未調査（同様のパターンが妥当と推測） |
| ホスト側ツールチェーン成熟度 | JNI/Panama, Kotlin/Native cinterop, Swift Cモジュールマップ — 成熟 | Chicory/WasmKitのwasm-gc対応 — 要検証 |
| 長期的保守可能性 | 非公開コンポーネントの未文書化な挙動に依存 | オープンソース部分に依存、第三者が保守可能 |

---

## 現時点の結論

1. **言語コア（構文・型システム・意味論）への変更は、いずれの経路でも不要。**
   - 両バックエンドとも他言語連携を意図した境界機構（extern C、wasm export、Component Model）を最初から備えている。

2. **ただし経路Aは「コアに手を入れる必要があるか」以前に、対象となるnativeバックエンドのCコード生成部分がクローズドソースであるため、検証も拡張も原理的にできない。**
   - これは技術的成熟度ではなくガバナンス上の制約であり、長期的な保守可能性の観点で構造的に不利。

3. **経路B（wasm-gc + Component Model）の方が、命名規則・export機構がオープンソースで検証可能という点でライブラリ基盤として適格性が高い。**
   - ボトルネックはMoonBit側ではなく、ホスト側（Chicory/WasmKitのwasm-gc・Component Model対応）の成熟度にある。

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

- **結論：優先度（a≒c、やや c寄り）だけでは経路A/Bを決め切れない。** 両者はそれぞれ異なる形でトレードオフを含んでおり、机上の優先度だけで一方に倒れる状況ではなくなった。決定の実質的なボトルネックは、既存の残課題であるChicory/WasmKitのwasm-gc対応とComponent Model bindgenの成熟度に一本化されたと言える。ここが十分に成熟していれば経路Bが `a` の欠点を許容範囲に抑えつつ `c` で優位に立ち、未成熟であれば経路Aの性能・単純さを、非公開ABIという保守リスクを受け入れてでも取る、という判断になる。

## 残課題（未検証）

- Chicory / WasmKitのwasm-gc対応状況とComponent Model bindgenの現在地。
- MoonBitのComponent Model対応の実装レベル（どこまでのWIT型が実際にサポートされているか）。
- 経路Bを選んだ場合の、複合型（レコード・variant・resource）のマーシャリングコストの実測。

## 参考リンク

- [Foreign Function Interface (FFI) — MoonBit Documentation](https://docs.moonbitlang.com/en/latest/language/ffi.html)
- [A Guide to MoonBit C-FFI](https://www.moonbitlang.com/pearls/moonbit-cffi)
- [Introduce MoonBit native, up to 15x faster than Java in numerics!](https://www.moonbitlang.com/blog/native)
- [Consuming a High Performance Wasm Library in MoonBit from JavaScript](https://www.moonbitlang.com/blog/call-wasm-from-js)
- [MoonBit - The WebAssembly Component Model](https://component-model.bytecodealliance.org/language-support/building-a-simple-component/moonbit.html)
- [GitHub - dylibso/chicory: Native JVM WebAssembly runtime](https://github.com/dylibso/chicory)
- [GitHub - moonbitlang/moonbit-native-runtime](https://github.com/moonbitlang/moonbit-native-runtime)
- [GitHub - moonbitlang/moonbit-compiler](https://github.com/moonbitlang/moonbit-compiler)
- [GitHub - moonbitlang/moonbit-tree-sitter](https://github.com/moonbitlang/moonbit-tree-sitter)
- 参考事例: UniFFI（Rust→Kotlin/Swift）
