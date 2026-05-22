# 型で頑張るプロダクト国際化（Shotaro Ozawa）

<https://2026.tskaigi.org/talks/12>

- 課題
  - t関数のラップ漏れ
  - 辞書データ登録漏れ

- Selector API

    ```ts
    // before
    t('key');

    // after
    t($ => $.key);
    ```

- before
  - `typeof 翻訳データ` を再起的に操作して文字列 `Union` 型で結びつける
- after
  - ほぼそのままオブジェクトの値を取ってくる
