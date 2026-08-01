# build-native-lib.sh

`moon build --target native` は `pkgtype(kind: "foreign_library")` を
ネイティブターゲットの共有ライブラリとしてリンクするところまでは対応していない
（`../research.md` の「経路A」節、および moon 本体の `NativeLinkConfig` に残る
`FIXME` を参照）。moonc 自体は `#export_name` を正しくコード生成しているため、
このスクリプトは欠けているリンク工程だけを肩代わりする。

やっていることは単純で、(1) `moon build --target native` を実行し（リンクの
失敗自体は想定内なので無視する）、(2) 生成された `export_spike.o` /
`runtime.o` と `~/.moon/lib` 配下のランタイム補助オブジェクト
（`moonbit_simdutf.o` / `simdutf.o` / `libbacktrace.a`）を集め、(3) 呼び出し側が
渡した追加の引数（JNIシムの `.c` やインクルードパスなど）とあわせて
`cc -shared` でリンクする。

## 使い方

```bash
scripts/build-native-lib.sh -o <output.dylib> [-- 追加のcc引数/ソース]
```

シムを持たないバリアント（Swift・複合型テスト・ライフタイムテスト）はベースの
ライブラリをそのまま使うだけなので、追加引数は不要。

```bash
scripts/build-native-lib.sh -o swift-test/lib/libexportspike_swift.dylib
scripts/build-native-lib.sh -o swift-release-test/lib/libexportspike_swift_release.dylib
scripts/build-native-lib.sh -o complex-types-test/libexportspike_complex.dylib
scripts/build-native-lib.sh -o lifetime-test/libexportspike_lifetime.dylib
```

JNIシムを使うバリアント（Java・Kotlin）は、JNIヘッダのインクルードパスとシムの
`.c` を `--` の後ろに渡す。

```bash
scripts/build-native-lib.sh -o jni-test/libexportspike_jni.dylib -- \
    -I"$JAVA_HOME/include" -I"$JAVA_HOME/include/darwin" jni-test/jni_shim.c

scripts/build-native-lib.sh -o kotlin-test/libexportspike_jni_kotlin.dylib -- \
    -I"$JAVA_HOME/include" -I"$JAVA_HOME/include/darwin" kotlin-test/jni_shim_kotlin.c
```

`kotlin-release-test` のシムは `moonbit.h`（`Moonbit_object_header` /
`moonbit_decref` を直接叩く）にも依存しているため、そのインクルードパスも渡す。

```bash
scripts/build-native-lib.sh -o kotlin-release-test/libexportspike_jni_release.dylib -- \
    -I"$JAVA_HOME/include" -I"$JAVA_HOME/include/darwin" -I ~/.moon/include \
    kotlin-release-test/jni_shim_release.c
```

## バージョン警告について

スクリプトは `moon version` / `moonc -v` を、このレシピを最後に検証した
バージョン（現時点で `moon 0.1.20260729` / `moonc v0.10.5+5e7afb0c0`）と比較する。
一致しない場合はビルドを止めずに警告だけ出す。`~/.moon/lib` 配下のファイル
構成は moon の未文書化な内部レイアウトであり、ツールチェーンの更新で無告知に
変わりうるため（`../research.md` 参照）、この警告はリンク失敗が起きたときに
「スクリプトのバグ」と「ツールチェーンのドリフト」を切り分けるための手がかり
として機能する。ハードフェイルにしていないのは、新しいバージョンでも実際には
レイアウトが変わっていないケースまで一律にブロックしたくないため。

## スコープ外

- このスクリプトは native ターゲットの「新戦略」（`moon build --target native`
  のデフォルト、Clamから直接マシンコードを生成）専用であり、macOS ホスト上の
  arm64 向けビルドのみを扱う。
- Android（NDKクロスコンパイル）・iOS（Xcodeツールチェーン、実機/シミュレータ）
  向けのビルドは**このスクリプトの対象外だが、実現不可能ではない**。
  2026-08-01の調査で、`moon build --target native --release`（＝Cバックエンド
  戦略、`MOONBIT_NEW_NATIVE=0`と同義）が出力するポータブルなC99ソース
  （`export_spike.c` / `~/.moon/lib/runtime.c`）を NDK/Xcode の clang で直接
  コンパイルすれば、iOS Simulator・Android実機の双方で動作することを実測で
  確認した（詳細は `../research.md` の「訂正：moonc の『Cバックエンド』経由で
  Android/iOSともに実機で動作した」節を参照）。このスクリプトをCバックエンド
  戦略に対応させる作業は `../research.md` の残課題として別途追跡している。
