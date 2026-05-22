# OSSのコードベースにneverthrowを漸進的に導入して、AIにも人間にも優しいエラーハンドリングを実現する（IkedaNoritaka）

<https://2026.tskaigi.org/talks/11>

- neverthrowを用いて、AIにとっても人間にとっても可読性の高いコードベースを目指す
- neverthrowは `Result<T, E>` を返すライブラリ
  - 成功、失敗に応じてどちらかが入っている
- シグネチャとskillがAI生成コードに与える影響
  - 共通: countDependencies（package.jsonの依存数を数える関数）
  - A: try/catch（<https://github.com/liam-hq/liam/pull/4096>）
  - B: Result（<https://github.com/liam-hq/liam/pull/4097>）
