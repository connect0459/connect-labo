# TypeScriptでWebAssemblyを用いた型安全なプラグイン設計（glassmonkey）

<https://2026.tskaigi.org/talks/8>

- wasm
- wasi
  - ブラウザの外でWASMをサンドボックスとして動かすためのOSリソースへの標準アクセスAPI
- ゲスト側をRustで書くかTSで書くか
  - もちろんTSの方が重い
- 比較
  - V8のおかげで純TS（baseline）が強い
  - WASM by TSはパフォーマンスが悪いので、それを目的にすると期待が外れる
- まとめ
  - 現在地はpreview2、previewは枯れてきている。商用利用は慎重に。
  - 本命は多言語資産の取り込み。型安全とランタイムのトレードオフ。
  - V8が強いので、無理に使う必要はない。
