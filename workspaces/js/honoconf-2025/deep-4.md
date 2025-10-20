# The Journey of the Node.js Adapter through Performance and Portability

- `@hono/node-adapter`
- クラウド上で動かすなどが主流
  - Node.jsにはAPIがないので、アダプターを作ってあげる必要がある
- PRの変遷
  - v0.4.0:ReadableStreamのサポートを強化
  - v1.0.0:node@v18をサポート
    - fetch APIへのサポート
  - v1.2.0:HTTP/2のサポート
  - v1.3.0:パフォーマンスチューニング
    - Web標準のReq/Resの生成が遅い
    - 標準のRequestをextendsしてurl,headers,incomingなどを残す
    - 技術選定のテーブルにあげるためにダーティなやり方でも早い方法にしたかった
  - v1.8.0
    - 途中で中断された時の処理
