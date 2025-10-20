# encoding/json/v2

## URLs

- [encoding/json/v2で何が変わる? - v1からv2への変化を徹底比較 | Go Conference 2025](https://gocon.jp/2025/talks/958036/)
- [encoding/json/v2で何が変わるか - Speaker Deck](https://speakerdeck.com/nagano/v2dehe-gabian-waruka)

## メモ

- 自社サービス紹介
  - 基盤サービスにGo
- 従来のencoding/jsonの課題
  - 重複キーの受理：最後の値のみ保持
  - 無効UTF-8の許容：データ破損リスク
  - 大文字小文字の無視：RFC8259では区別するがv1は区別しない
  - map/sliceのゼロ値：ゼロ値はnullではなく{}/[]で扱いたい
- v2で変わること、変わらないこと
  - v1とv2は後方互換性あり
  - Breaking Changes
    - ゼロ値とomitemptyの扱い
    - マーシャル/アンマーシャルの記述
