# module

## URLs

- [サプライチェーン攻撃に学ぶmoduleの仕組みとセキュリティ対策 | Go Conference 2025](https://gocon.jp/2025/talks/939638/)
- [サプライチェーン攻撃に学ぶModuleの仕組みと セキュリティ対策 - Speaker Deck](https://speakerdeck.com/kuro_kurorrr/understanding-module-through-the-lens-of-supply-chain-attacks)

## メモ

- Module Proxyとは
  - GOPROXYプロトコルを実装するHTTPサーバー
  - メリット
    - 高速化と効率化
      - 特定のモジュールのメタデータのみ参照可能
    - 依存関係の消失から保護
      - オリジナルの場所から消えてもキャッシュし続ける
  - 最初に`go get`された時点のコードをキャッシュするため、キャッシュ後に悪意のあるコードをクリーンなコードにしてGitHubに公開すれば、見た目では問題のないコードに見える
  - IPアドレスを構築する場合の例
    - constの数を`_r`関数で桁を入れ替えるなど不要な操作をして見かけ上構築できるようにしているが、リモートでコマンドを実行するコードが潜んでいる
- Go Modulesの仕組み
  - MVS（最小バージョン選択）
  - 自分が必要なものの中で一番バージョンが低いものを選択
  - 予期しないバージョンアップを防止
  - `go.sum`について
    - 1行目：モジュール全体のハッシュ
    - 2行目：`go.mod`のハッシュ
    - Merkle Treeによる改ざん検出
- typosquattingの防止策
  - 依存関係を手書きせず、goplsで追加
  - タイポをlintで検知する
  - `go mod verify`は最初のコードから改ざんされていないかのチェックなので、最初から悪意のあるコードは検出できない
