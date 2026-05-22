# TypeScriptのclassはなぜこうなったのか — 歴史・落とし穴・そして使いどころを探る（kosui）

<https://2026.tskaigi.org/talks/16>

- 特性
  - 構造的部分型
  - 型消去
  - プロトタイプベース
    - JSは関数の呼び出し方でthisが決まる
    - `uploader.upload()` は `this = uploader`
    - 関数を変数経由で呼ぶと `this = undefined`
