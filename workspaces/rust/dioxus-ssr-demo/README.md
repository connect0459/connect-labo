# dioxus-ssr-demo

Dioxus 0.7のフルスタック機能（SSR、Suspense、Hydration）を実装したデモアプリケーションです。

## プロジェクト概要

このプロジェクトは、以下の技術を実証するために作成されました：

- **SSR (Server-Side Rendering)**: サーバーサイドでHTMLを事前レンダリング
- **Suspense**: 非同期データ取得時のフォールバックUI表示
- **Hydration**: SSRされたHTMLをクライアントサイドでインタラクティブに変換

## 技術スタック

- **Rust**: システムプログラミング言語
- **Dioxus 0.7**: Rustのフルスタック向けUIフレームワーク
- **Axum 0.8**: Webサーバーフレームワーク
- **Tokio**: 非同期ランタイム

## プロジェクト構成

```text
dioxus-ssr-demo/
├── src/
│   └── main.rs          # メインアプリケーションコード
├── Cargo.toml           # プロジェクト依存関係
└── README.md            # このファイル
```

## 主要コンポーネント

### App

ルートコンポーネント。SSR、Suspense、Hydrationの3つのセクションを含みます。

### SuspenseDemo

`use_server_future`を使用した非同期データ取得のデモです。サーバーサイドで3秒間待機してからデータを返し、その間フォールバックUIを表示します。

**実装の重要ポイント:**

```rust
let data = use_server_future(|| async {
    #[cfg(feature = "server")]
    {
        tokio::time::sleep(Duration::from_secs(3)).await;
    }
    Ok::<Vec<DataItem>, ServerFnError>(...)
})?;

match data.read().as_ref() {
    None => { /* フォールバックUI */ }
    Some(Ok(items)) => { /* データ表示 */ }
    Some(Err(_)) => { /* エラー表示 */ }
}
```

`use_server_future`は`Result<Resource<T>, RenderError>`を返すため、`?`演算子で`Resource`を抽出してから、`read()`メソッドでデータの状態をチェックします。

### HydrationDemo

インタラクティブなカウンターコンポーネントで、クライアントサイドでのHydrationを実証します。`use_server_cached`を使用してサーバー生成のランダム値をクライアントと同期します。

## 修正履歴

### Suspense実装の問題と修正

**問題点:**

初期実装では、`use_server_future`の戻り値の扱いが不適切で、以下の問題がありました：

1. `?`演算子なしで`data.read()`を直接呼び出していた
2. `Result<Resource<T>, RenderError>`から`Resource<T>`を抽出せずに使用していた

この実装では、コンパイルエラーが発生し、本来のSuspenseの動作が実現できていませんでした。

**修正内容:**

1. `use_server_future`の後に`?`演算子を追加して`Resource`を抽出
2. `Resource::read()`メソッドで`Option<Result<T, E>>`を取得
3. `match`文で`None`（読み込み中）、`Some(Ok(...))`（成功）、`Some(Err(...))`（エラー）の各ケースを明示的に処理

これにより、正しいSuspenseライクな動作を実現：

- データ読み込み中: フォールバックUIを表示
- データ取得成功: 実際のデータを表示
- エラー発生: エラーメッセージを表示

## 起動方法

### 前提条件

- Rust（最新安定版）
- Dioxus CLI（`dx`）

Dioxus CLIのインストール:

```bash
cargo install dioxus-cli
```

### 開発サーバーの起動

```bash
dx serve --fullstack
```

サーバーは通常 `http://localhost:8080` で起動します。

### ビルドのみ実行

```bash
cargo build --features server
```

### 本番ビルド

```bash
dx build --release --fullstack
```

## 動作確認

1. ブラウザで `http://localhost:8080` にアクセス
2. **Suspense Demo** セクションを確認:
   - 初期表示時に「⏳ サーバーからデータを読み込んでいます...」が表示される
   - 3秒後にデータが表示される
3. **Hydration Demo** セクションを確認:
   - サーバー生成のランダム値が表示される
   - カウンターボタンをクリックして、クライアントサイドのインタラクティブ性を確認

## 学習ポイント

1. **use_server_future**: サーバーサイドで非同期処理を実行し、結果をクライアントに自動シリアライズ
2. **Resource::read()**: 非同期データの状態（None/Some(Ok/Err)）を確認
3. **use_server_cached**: サーバー生成のデータをクライアントと同期
4. **Suspense境界**: 明示的な`Suspense`コンポーネントなしで、手動でフォールバックUIを管理

## 参考リンク

- [Dioxus公式ドキュメント](https://dioxuslabs.com/learn/0.7/getting_started)
- [Dioxus Fullstack Guide](https://dioxuslabs.com/learn/0.7/fullstack)
