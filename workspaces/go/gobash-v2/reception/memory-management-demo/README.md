# メモリ管理デモ - 各言語のSharing Up/Sharing Down実装

このプロジェクトは、C、Go、Java、Rustの4つの言語におけるメモリ管理の違いを実際のコードで体験するためのデモ環境です。

## 概要

各言語で以下のメモリ管理概念を実装し、その違いを理解できます：

- **Sharing Up**: 子から親へポインタを返す（戻り値がポインタ）
- **Sharing Down**: 親から子へポインタを渡す（引数がポインタ）
- スタックとヒープの違い
- 各言語の安全性保証メカニズム

## プロジェクト構成

```text
memory-management-demo/
├── c-example/          # C言語のデモ（未定義動作の例）
│   ├── main.c
│   └── Dockerfile
├── go-example/         # Go言語のデモ（エスケープ解析）
│   ├── main.go
│   ├── go.mod
│   └── Dockerfile
├── java-example/       # Java言語のデモ（すべてヒープ）
│   ├── Main.java
│   └── Dockerfile
├── rust-example/       # Rust言語のデモ（借用チェッカー）
│   ├── src/
│   │   └── main.rs
│   ├── Cargo.toml
│   └── Dockerfile
├── docker-compose.yml
├── Makefile
└── README.md
```

## セットアップ

### 必要な環境

- Docker
- Docker Compose
- Make（オプション）

### イメージのビルド

```bash
# すべての言語のDockerイメージをビルド
make build

# または
docker compose build
```

## 実行方法

### コンテナを起動して対話的に実行（推奨）

コンテナを起動したままにして、任意のタイミングで各言語のデモを実行できます：

```bash
# コンテナを起動
docker compose up -d

# 各言語のデモを実行
docker exec memory-demo-c ./main
docker exec memory-demo-go ./main
docker exec memory-demo-java java Main
docker exec memory-demo-rust ./target/release/memory-demo

# コンテナを停止
docker compose down
```

コンテナ内に入って対話的に作業することもできます：

```bash
# C言語コンテナに入る
docker exec -it memory-demo-c bash

# Go言語コンテナに入る
docker exec -it memory-demo-go bash

# Java言語コンテナに入る
docker exec -it memory-demo-java bash

# Rust言語コンテナに入る
docker exec -it memory-demo-rust bash
```

### すべてのデモを順次実行

```bash
make run-all
```

### 個別の言語のデモを実行

#### C言語のデモ

```bash
make run-c
# または
docker compose run --rm c-example
# または（コンテナ起動済みの場合）
docker exec memory-demo-c ./main
```

**学べること:**

- ローカル変数のアドレスを返す未定義動作
- 手動でのヒープ管理（malloc/free）
- Sharing Downの安全性

#### Go言語のデモ

```bash
make run-go
# または
docker compose run --rm go-example
# または（コンテナ起動済みの場合）
docker exec memory-demo-go ./main
```

**学べること:**

- エスケープ解析による自動ヒープ割り当て
- Sharing Upの安全性
- 値渡しとポインタ渡しのパフォーマンス比較
- メモリ統計の確認

#### Java言語のデモ

```bash
make run-java
# または
docker compose run --rm java-example
# または（コンテナ起動済みの場合）
docker exec memory-demo-java java Main
```

**学べること:**

- すべてのオブジェクトがヒープに確保される仕組み
- ガベージコレクション
- 参照の値渡し

#### Rust言語のデモ

```bash
make run-rust
# または
docker compose run --rm rust-example
# または（コンテナ起動済みの場合）
docker exec memory-demo-rust ./target/release/memory-demo
```

**学べること:**

- 借用チェッカーによるコンパイル時の安全性保証
- 所有権とムーブセマンティクス
- ライフタイムパラメータ
- GC不要のメモリ管理

## 各言語の比較表

| 言語 | 安全性保証 | 方法 | GC | 特徴 |
|------|-----------|------|-----|------|
| C | なし | 手動管理 | なし | 未定義動作のリスク、パフォーマンス最優先 |
| Go | あり | エスケープ解析 | あり | 自動判断、バランス重視 |
| Java | あり | 全てヒープ | あり | シンプル、使いやすさ重視 |
| Rust | あり | 借用チェッカー | なし | コンパイル時保証、予測可能性重視 |

## 詳細ドキュメント

各概念の詳しい説明は [`1-sharing_up_and_down.md`](../1-sharing_up_and_down.md) を参照してください。

## クリーンアップ

```bash
# すべてのコンテナとイメージを削除
make clean

# または
docker compose down --rmi all --volumes
```

## 学習のポイント

### 1. C言語

- ローカル変数のポインタを返すと何が起こるか
- なぜ手動でのメモリ管理が必要か
- Sharing Downはなぜ安全か

### 2. Go言語

- エスケープ解析の仕組み
- スタックとヒープの使い分け
- パフォーマンスとのトレードオフ

### 3. Java言語

- なぜSharing Upの問題が発生しないか
- 全てをヒープに置くメリット・デメリット
- GCの役割

### 4. Rust言語

- コンパイル時にどう安全性を保証するか
- 所有権システムの利点
- GCなしでどうメモリを管理するか

## トラブルシューティング

### Dockerイメージのビルドに失敗する場合

```bash
# キャッシュを削除してビルド
docker compose build --no-cache
```

### コンテナが残っている場合

```bash
# 実行中のコンテナを停止
docker compose down
```

## ライセンス

このデモプロジェクトは学習目的で作成されています。

## 参考資料

- [Go公式ドキュメント - Escape Analysis](https://github.com/golang/go/wiki/CompilerOptimizations#escape-analysis)
- [Rust Book - Understanding Ownership](https://doc.rust-lang.org/book/ch04-00-understanding-ownership.html)
- [Java Specifications - Memory Management](https://docs.oracle.com/javase/specs/)
