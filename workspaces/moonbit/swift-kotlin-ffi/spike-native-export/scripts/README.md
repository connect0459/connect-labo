# ビルドスクリプト

native ターゲットの2つのコード生成戦略（`../research.md` 参照）にそれぞれ対応する2本のスクリプトがある。

- `build-native-lib.sh` — 「新戦略」（`moon build --target native` のデフォルト、
  Clamから直接マシンコードを生成）用。macOS ホスト上の arm64 向けのみ。
- `build-c-backend-lib.sh` — 「Cバックエンド戦略」（`moon build --target native
  --release`、`MOONBIT_NEW_NATIVE=0`と同義、ポータブルなC99ソースを生成）用。
  任意のCコンパイラ（ホストcc・NDK clang・Xcode clang）を渡せるため、
  Android・iOSクロスコンパイルはこちらを使う。

## build-native-lib.sh

`moon build --target native` は `pkgtype(kind: "foreign_library")` をネイティブターゲットの共有ライブラリとしてリンクするところまでは対応していない（`../research.md` の「経路A」節、および moon 本体の `NativeLinkConfig` に残る `FIXME` を参照）。moonc 自体は `#export_name` を正しくコード生成しているため、このスクリプトは欠けているリンク工程だけを肩代わりする。

やっていることは単純で、(1) `moon build --target native` を実行し（リンクの失敗自体は想定内なので無視する）、(2) 生成された `export_spike.o` / `runtime.o` と `~/.moon/lib` 配下のランタイム補助オブジェクト（`moonbit_simdutf.o` / `simdutf.o` / `libbacktrace.a`）を集め、(3) 呼び出し側が渡した追加の引数（JNIシムの `.c` やインクルードパスなど）とあわせて `cc -shared` でリンクする。

### 使い方

```bash
scripts/build-native-lib.sh -o <output.dylib> [-- 追加のcc引数/ソース]
```

シムを持たないバリアント（Swift・複合型テスト・ライフタイムテスト）はベースのライブラリをそのまま使うだけなので、追加引数は不要。

```bash
scripts/build-native-lib.sh -o swift-test/lib/libexportspike_swift.dylib
scripts/build-native-lib.sh -o swift-release-test/lib/libexportspike_swift_release.dylib
scripts/build-native-lib.sh -o complex-types-test/libexportspike_complex.dylib
scripts/build-native-lib.sh -o lifetime-test/libexportspike_lifetime.dylib
```

JNIシムを使うバリアント（Java・Kotlin）は、JNIヘッダのインクルードパスとシムの `.c` を `--` の後ろに渡す。

```bash
scripts/build-native-lib.sh -o jni-test/libexportspike_jni.dylib -- \
    -I"$JAVA_HOME/include" -I"$JAVA_HOME/include/darwin" jni-test/jni_shim.c

scripts/build-native-lib.sh -o kotlin-test/libexportspike_jni_kotlin.dylib -- \
    -I"$JAVA_HOME/include" -I"$JAVA_HOME/include/darwin" kotlin-test/jni_shim_kotlin.c
```

`kotlin-release-test` のシムは `moonbit.h`（`Moonbit_object_header` / `moonbit_decref` を直接叩く）にも依存しているため、そのインクルードパスも渡す。

```bash
scripts/build-native-lib.sh -o kotlin-release-test/libexportspike_jni_release.dylib -- \
    -I"$JAVA_HOME/include" -I"$JAVA_HOME/include/darwin" -I ~/.moon/include \
    kotlin-release-test/jni_shim_release.c
```

### バージョン警告について

スクリプトは `moon version` / `moonc -v` を、このレシピを最後に検証したバージョン（現時点で `moon 0.1.20260729` / `moonc v0.10.5+5e7afb0c0`）と比較する。一致しない場合はビルドを止めずに警告だけ出す。`~/.moon/lib` 配下のファイル構成は moon の未文書化な内部レイアウトであり、ツールチェーンの更新で無告知に変わりうるため（`../research.md` 参照）、この警告はリンク失敗が起きたときに「スクリプトのバグ」と「ツールチェーンのドリフト」を切り分けるための手がかりとして機能する。ハードフェイルにしていないのは、新しいバージョンでも実際にはレイアウトが変わっていないケースまで一律にブロックしたくないため。

### スコープ外

このスクリプトは native ターゲットの「新戦略」専用であり、macOS ホスト上の arm64 向けビルドのみを扱う。Android/iOSクロスコンパイルは対象外（`build-c-backend-lib.sh` を使う）。

## build-c-backend-lib.sh

`moon build --target native --release`（`MOONBIT_NEW_NATIVE=0` と同義）は `build-native-lib.sh` が前提とする「新戦略」とは別のコード生成戦略で、ポータブルなC99ソース（`export_spike.c`）を出力する。moonc の関与はこのCテキストの生成で終わり、実際のターゲット固有コンパイルは呼び出し側が渡す任意のCコンパイラに委ねられるため、moonc 自身が持つ native `-target` の制限（macOS/Linux-glibc/Windowsのみ、Android/iOSのトリプルなし）は関係ない。2026-08-01に、iOS Simulator（`xcrun simctl spawn` での実行まで）・Android（NDKの`aarch64-linux-android24-clang`でのELF共有ライブラリ生成まで）の両方で無改造のまま動作することを実測した（詳細は `../research.md` の「訂正：moonc の『Cバックエンド』経由でAndroid/iOSともに実機で動作した」節）。

やっていることは、(1) `moon build --target native --release` を実行し（リンクの失敗自体は想定内なので無視する）、(2) 生成された `export_spike.c` と `~/.moon/lib/runtime.c`（ポータブルなランタイム本体）を、(3) 呼び出し側が指定したCコンパイラ・追加引数（`-target`/`-isysroot`/JNIシムなど）とあわせてコンパイルする。デフォルトで `-DMOONBIT_NATIVE_NO_SYS_HEADER` を付与し、`runtime.c` 内のファイルシステム/乱数系POSIX呼び出し（`dirent.h` / `sys/random.h` 等、iOS SDKには存在しないヘッダを要求する）を無効化したフォールバック実装に切り替える。`moonbit_simdutf.o` / `libbacktrace.a` のような外部の事前コンパイル済みオブジェクトは一切不要（`runtime.c` 自身が `MOONBIT_USE_SIMDUTF` / `MOONBIT_ALLOW_STACKTRACE` 未定義時のポータブルなフォールバック実装を持っている）。

### 使い方

```bash
scripts/build-c-backend-lib.sh -o <output> [-c <cc>] [-p] [-- 追加のcc引数/ソース]
```

`-c` は使用するCコンパイラ（デフォルト: `cc`）、`-p` は `MOONBIT_NATIVE_NO_SYS_HEADER` を付与しない（POSIXファイルシステム/乱数APIが必要なホストビルド向け、未検証のオプトアウト）。

ホストmacOS向け（`build-native-lib.sh` と同じMoonBitコードだが別のコード生成経路であることの単体確認用）:

```bash
scripts/build-c-backend-lib.sh -o /tmp/libexportspike_c_backend.dylib
```

iOS Simulator向け:

```bash
SDK=$(xcrun --sdk iphonesimulator --show-sdk-path)
scripts/build-c-backend-lib.sh -o ios-test/lib/libexportspike_ios_sim.dylib -- \
    -target arm64-apple-ios17.0-simulator -isysroot "$SDK"
```

Android（NDK）向け:

```bash
NDK=/opt/homebrew/Caskroom/android-ndk/29/AndroidNDK*.app/Contents/NDK
scripts/build-c-backend-lib.sh \
    -c "$NDK"/toolchains/llvm/prebuilt/darwin-x86_64/bin/aarch64-linux-android24-clang \
    -o android-test/libexportspike_android.so -- -fPIC
```

### 既知の未解決事項

- `MOONBIT_USE_SIMDUTF` / `MOONBIT_ALLOW_STACKTRACE` を有効にする場合の
  ターゲットごとの取捨選択方針は未検討（現状は常に無効＝ポータブルな
  フォールバック実装を使う）。
- `MOONBIT_NATIVE_NO_SYS_HEADER` はファイルシステム/乱数APIを丸ごと無効化
  する粗い切り替えであり、実運用でどこまで必要かは未調査。
- iOS実デバイス（Simulatorではなく）・Androidエミュレータ/実機上での実行
  確認、複合型（文字列・構造体）マーシャリングのAndroid/iOSでの再現確認は
  いずれも未実施（`../research.md` の残課題を参照）。
