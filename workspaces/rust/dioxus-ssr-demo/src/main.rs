#![allow(non_snake_case)]

use dioxus::prelude::*;
use serde::{Deserialize, Serialize};
use std::time::Duration;

const STYLES: &str = r#"
    body {
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
        max-width: 800px;
        margin: 0 auto;
        padding: 2rem;
        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        min-height: 100vh;
    }
    .container {
        background: white;
        border-radius: 12px;
        padding: 2rem;
        box-shadow: 0 10px 40px rgba(0,0,0,0.2);
    }
    h1 {
        color: #667eea;
        margin-top: 0;
    }
    h2 {
        color: #5a67d8;
    }
    h3 {
        color: #667eea;
        margin: 0 0 0.5rem 0;
    }
    .section {
        margin: 2rem 0;
        padding: 1.5rem;
        background: #f7fafc;
        border-radius: 8px;
        border-left: 4px solid #667eea;
    }
    button {
        background: #667eea;
        color: white;
        border: none;
        padding: 0.75rem 1.5rem;
        border-radius: 6px;
        font-size: 1rem;
        cursor: pointer;
        transition: all 0.2s;
    }
    button:hover {
        background: #5a67d8;
        transform: translateY(-1px);
        box-shadow: 0 4px 12px rgba(102, 126, 234, 0.4);
    }
    .data-item {
        padding: 1rem;
        margin: 0.5rem 0;
        background: white;
        border-radius: 6px;
        border: 1px solid #e2e8f0;
    }
    code {
        background: #edf2f7;
        padding: 0.2rem 0.4rem;
        border-radius: 3px;
        font-family: 'Courier New', monospace;
        color: #667eea;
    }
"#;

#[cfg(feature = "server")]
#[tokio::main]
async fn main() {
    // ログ設定
    tracing_subscriber::fmt::init();

    let addr = dioxus::cli_config::fullstack_address_or_localhost();

    println!("🚀 Server running at http://{}", addr);
    println!("📝 Open your browser to see SSR + Hydration + Suspense in action!");

    // Axumルーターを作成してDioxusアプリケーションを提供
    let router = axum::Router::new()
        .serve_dioxus_application(ServeConfig::new(), App)
        .into_make_service();

    let listener = tokio::net::TcpListener::bind(&addr).await.unwrap();

    axum::serve(listener, router).await.unwrap();
}

#[cfg(feature = "server")]
use dioxus::server::{DioxusRouterExt, ServeConfig};

#[cfg(not(feature = "server"))]
fn main() {
    dioxus::launch(App);
}

#[component]
fn App() -> Element {
    rsx! {
        document::Style {
            {STYLES}
        }
        div { class: "container",
            h1 { "🚀 Dioxus 0.7 SSR + Suspense + Hydration Demo" }

            div { class: "section",
                h2 { "✨ SSR (Server-Side Rendering)" }
                p {
                    "このページはサーバーサイドでレンダリングされています。"
                    br {}
                    "ページソースを表示すると、HTMLが既に生成されているのが確認できます。"
                }
            }

            div { class: "section",
                h2 { "⚡ Suspense Demo" }
                SuspenseDemo {}
            }

            div { class: "section",
                h2 { "💧 Hydration Demo" }
                HydrationDemo {}
            }
        }
    }
}

/// Dioxus 0.7のuse_server_futureを使ったSuspense実装
#[component]
fn SuspenseDemo() -> Element {
    // use_server_futureを使用してサーバーサイドでデータを取得し、
    // クライアントサイドに自動的にシリアライズして渡す
    // ?演算子でResourceを抽出（RenderErrorの場合はエラーを伝播）
    let data = use_server_future(|| async {
        // サーバーサイドで実行される非同期処理
        #[cfg(feature = "server")]
        {
            tokio::time::sleep(Duration::from_secs(3)).await;
        }

        // クライアント・サーバー両方で同じデータを返す
        Ok::<Vec<DataItem>, ServerFnError>(vec![
            DataItem {
                id: 1,
                title: "データ1".to_string(),
                description: "サーバーから取得したデータ".to_string(),
            },
            DataItem {
                id: 2,
                title: "データ2".to_string(),
                description: "非同期処理が完了しました".to_string(),
            },
            DataItem {
                id: 3,
                title: "データ3".to_string(),
                description: "Suspenseで表示されています".to_string(),
            },
        ])
    })?;

    // Resourceに対してreadを呼び出し、ステータスをチェック
    match data.read().as_ref() {
        None => {
            // データ読み込み中のフォールバックUI
            rsx! {
                div {
                    p { style: "color: #667eea; font-weight: bold;",
                        "⏳ サーバーからデータを読み込んでいます..."
                    }
                    p {
                        code { "use_server_future" }
                        " を使って非同期データを取得しています。"
                        br {}
                        "サーバーサイドで3秒待機した後、データを返しています。"
                    }
                    p { style: "font-style: italic; color: #718096;",
                        "※ このメッセージが表示されている間、バックグラウンドでデータを取得しています"
                    }
                }
            }
        }
        Some(Err(_)) => {
            // エラー時のUI
            rsx! {
                div { class: "data-item",
                    p { style: "color: #e53e3e; font-weight: bold;",
                        "❌ エラーが発生しました"
                    }
                }
            }
        }
        Some(Ok(items)) => {
            // データ取得成功時のUI
            rsx! {
                div {
                    p {
                        code { "use_server_future" }
                        " を使って非同期データを取得しています。"
                        br {}
                        "サーバーサイドで3秒待機した後、データを返しています。"
                    }
                    p { style: "color: #48bb78; font-weight: bold;",
                        "✅ データの読み込みが完了しました！"
                    }

                    div {
                        for item in items {
                            div { class: "data-item",
                                h3 { "{item.title}" }
                                p { "{item.description}" }
                                small { "ID: {item.id}" }
                            }
                        }
                    }
                }
            }
        }
    }
}

/// サーバーとクライアント間で共有されるデータ構造
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
struct DataItem {
    id: u32,
    title: String,
    description: String,
}

/// Hydrationを確認するためのインタラクティブコンポーネント
#[component]
fn HydrationDemo() -> Element {
    let mut count = use_signal(|| 0);

    // use_server_cachedを使ってサーバーサイドで生成された
    // ランダムな初期値をクライアントと同期
    let initial_random = use_server_cached(|| {
        #[cfg(feature = "server")]
        {
            use rand::Rng;
            rand::thread_rng().gen_range(1..=100)
        }
        #[cfg(not(feature = "server"))]
        {
            0
        }
    });

    rsx! {
        div {
            p {
                "このカウンターは、SSRされたHTMLがクライアントサイドで"
                strong { "hydrate（水分補給）" }
                "されてインタラクティブになっています。"
            }

            div { class: "data-item",
                p {
                    strong { "サーバー生成の初期ランダム値: " }
                    span { "{initial_random}" }
                }
                p {
                    em { "※ このランダム値はサーバーで生成され、クライアントに同期されています" }
                }
            }

            div { class: "data-item",
                p {
                    strong { "カウント: " }
                    span { style: "font-size: 2rem; color: #667eea;", "{count}" }
                }

                div { style: "margin-top: 1rem;",
                    button {
                        onclick: move |_| count += 1,
                        "➕ カウントアップ"
                    }

                    button {
                        onclick: move |_| count -= 1,
                        style: "margin-left: 0.5rem;",
                        "➖ カウントダウン"
                    }

                    button {
                        onclick: move |_| count.set(0),
                        style: "margin-left: 0.5rem; background: #e53e3e;",
                        "🔄 リセット"
                    }
                }
            }

            p {
                small {
                    "💡 ボタンをクリックできるのは、クライアントサイドでJavaScriptが"
                    "正しくhydrateされているためです！"
                }
            }
        }
    }
}
