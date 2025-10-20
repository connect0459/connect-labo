# Go で WebAssembly を利用した実用的なプラグインシステムの構築方法

## URLs

- [Go で WebAssembly を利用した実用的なプラグインシステムの構築方法 | Go Conference 2025](https://gocon.jp/2025/talks/958532/)

## メモ

- WASMとは
  - ブラウザ以外の用途にも注目が集まっている
- プラグインシステムにおけるWASMのメリット
  - Guestで実行する処理をHostで制限することができる
  - GuestがクラッシュしてもHostが巻き込まれない
  - 一度ビルドしたらどこでも動く
- WASM以外の選択肢
  - Shared Library
    - `go build -buildmode=plugin`
    - `plugin.Open`で利用
    - HostとGuestでメモリを共有する
    - HostとGuestでGo Modulesのバージョン統一の必要性
    - `rm -rf /`実行可能
  - RPC
    - HostとGuestは別プロセス
    - HTTP/gRPC/STDIOなどを利用してGuestと通信する
    - `rm -rf /`実行可能
- GoとWASMの関係
  - WASMとWASI（WebAssembly System Interface）
  - TinyGo
    - 小型デバイスや込々環境向けの軽量Goコンパイラ
  - GoのWASMランタイム選択肢
    - wazero一択
    - PureGoで実装されている唯一のWASMランタイム
    - InterpreterとCompilerの二つのランタイムを持つ
      - Interpreter：逐次WASM命令を実行する
      - Compiler：Binaryから実行
- WASMを使ったプラグインシステムの壁
  - HTTP ServerでWASMプラグインを運用する例を考える
  - 並行処理の壁
    - Guest関数を呼び出したとき、関数を抜けると非同期処理も停止
      - GuestでHTTP Listenするコードは書けない
    - WASMインスタンスはシングルスレッド/非同期割り込みなし
  - メモリ管理の壁
    - シングルスレッドのWASMインスタンスをリクエストごとに作ると、1インスタンスごとのサイズが大きくメモリ使用率が増加する
      - 最小でも8MB使うらしい。
  - Network Socketの壁
    - WASI P1では`sock_send`や`sock_recv`が実装されていない
  - TLSの壁
    - WASI P1ビルドでは、サーバー証明書の正当性を検証しづらい
  - コマンド実行の壁
    - `exec.Command`をサポートしていない
    - コマンド実行でしか認証情報を取得できない場合に詰む
  - 標準ライブラリの実装を差し替える
    - `go build -overlay`
      - ビルド時にファイルを任意のものに差し替え可能
      - 置き換えるファイルの対応関係を記述したJSONファイルを用意して引数に指定。イメージ↓

      - ```json
        {
          "Replace":{
            "before":"/tmp/hoge.go"
            "after":"/tmp/fuga.go"
          }
        }
        ```

    - `linkname directive`
      - Symbol解決のタイミングをリンク時に遅らせることで、パッケージの循環参照問題を解決できる（importする必要がない）
  - プラグインの非同期処理をサポートする
    - osパッケージのI/O標準実装を差し替えて対応
    - wasmexportに依存せず、main loopでプロセスを活かし続ける
    - ResponseはHost側の関数を使う
