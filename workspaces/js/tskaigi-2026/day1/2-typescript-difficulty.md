# 業務に残された「よくない型」で考える「TypeScriptの難しさ」（Saji）

<https://2026.tskaigi.org/talks/5>

- 良くない型とは
  - any, as, @ts-ignore, 雑な型ガード関数
- Reactで構築したFormを例として解説
- 頻出例
  - as unknown
  - 文字列 -> Branded型 / リテラル型の限界
- パターン
  - A: 境界由来 & 押し戻せる
  - B: 内部由来 & 押し戻せる
  - C: 内部起因 & 押し戻せない
