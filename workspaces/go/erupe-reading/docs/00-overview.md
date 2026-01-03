# Erupe プロジェクト概要

## プロジェクトについて

**Erupe** は、Monster Hunter Frontier (MHF) というオンラインゲームのサーバーエミュレーターです。複数のプラットフォーム (PC、PlayStation 3/Vita、Wii U) を対象としており、G10以降のバージョンで広くテストされています。

### 基本情報

| 項目 | 内容 |
| :--- | :--- |
| プロジェクトサイズ | 27 MB |
| Go ソースファイル数 | 522個 |
| SQL/ドキュメント | 44個 |
| 使用言語 | Go 1.23.0 |
| データベース | PostgreSQL |
| 開発状況 | アクティブ (ZeruLight による開発) |

### 開発履歴

- **Cappuccino** (2019-2020): 初期開発
- **Einherjar Team** (?-2022): ブラッシュアップ
- **Community Edition** (2022): オープンソース化
- **sekaiwish Fork** (2022)
- **ZeruLight** (2022-2023): 現在の開発者

---

## ディレクトリ構造

```text
Erupe/
├── main.go                 # アプリケーションエントリーポイント
├── config.json             # サーバー設定ファイル
├── go.mod / go.sum         # Go依存性管理
├── Dockerfile              # コンテナ化
│
├── common/                 # 共通ユーティリティパッケージ (11個)
│   ├── byteframe/          # バイト列処理
│   ├── decryption/         # 暗号化/復号化機能
│   ├── mhfcid/             # キャラクターID管理
│   ├── mhfcourse/          # コース管理
│   ├── mhfitem/            # アイテム管理
│   ├── mhfmon/             # モンスター管理
│   ├── pascalstring/       # Pascal文字列処理
│   ├── stringstack/        # 文字列スタック
│   ├── stringsupport/      # 文字列サポート
│   ├── token/              # トークン処理
│   └── bfutil/             # バイナリフレームユーティリティ
│
├── network/                # ネットワークプロトコル層 (444個Go)
│   ├── binpacket/          # バイナリパケット処理
│   ├── clientctx/          # クライアントコンテキスト管理
│   ├── crypto/             # ネットワーク暗号化
│   ├── mhfpacket/          # MHFプロトコルパケット定義 (434+)
│   ├── crypt_conn.go       # 暗号化接続管理
│   ├── crypt_packet.go     # パケット暗号化処理
│   └── packetid.go         # パケットID定義
│
├── server/                 # サーバー実装
│   ├── entranceserver/     # ログイン/入場サーバー
│   ├── signserver/         # 署名/認証サーバー
│   ├── channelserver/      # ゲームプレイサーバー (58個Go)
│   │   ├── sys_*.go        # システムモジュール
│   │   ├── handlers*.go    # 機能別ハンドラー (48個)
│   │   └── compression/    # データ圧縮
│   ├── api/                # REST API サーバー
│   └── discordbot/         # Discord統合ボット
│
├── config/                 # 設定管理
│   └── config.go           # Config構造体と初期化ロジック
│
├── schemas/                # データベース定義
│   ├── init.sql            # 初期化スキーマ (v9.1.0)
│   ├── update-schema/      # 更新スキーマファイル
│   ├── patch-schema/       # 開発用パッチスキーマ
│   └── bundled-schema/     # デモ参照スキーマ
│
├── savedata/               # セーブデータ処理
├── docker/                 # Docker設定
└── bin/                    # バイナリリソース
    ├── quests/             # クエスト定義
    ├── scenarios/          # シナリオ定義
    └── events/             # イベント定義
```

---

## サーバー構成

Erupeは4種類のサーバーを並行稼働させます：

| サーバー | デフォルトポート | 役割 |
| :--- | :--- | :--- |
| Entrance Server | 53310 | サーバー一覧表示、初期接続 |
| Sign Server | 53312 | ユーザー認証、キャラクター管理 |
| Channel Server | 54001-54008 | メインゲームプレイ処理 |
| API Server | 8080 | REST API (ランチャー、スクリーンショット) |

オプションで **Discord Bot** も統合可能です。

---

## 主要な依存関係

```go
require (
  github.com/bwmarrin/discordgo v0.27.1      // Discord API
  github.com/gorilla/handlers v1.5.2         // HTTP ハンドラー
  github.com/gorilla/mux v1.8.1              // ルーター
  github.com/jmoiron/sqlx v1.3.5             // SQL拡張
  github.com/lib/pq v1.10.9                  // PostgreSQL ドライバー
  github.com/spf13/viper v1.17.0             // 設定管理
  go.uber.org/zap v1.26.0                    // ロギング
  golang.org/x/crypto v0.36.0                // 暗号化
)
```

---

## 設定ファイル (config.json)

主要な設定セクション：

```json
{
  "Host": "127.0.0.1",              // バインドIP
  "ClientMode": "ZZ",               // 対応クライアント版 (40+バージョン対応)
  "Database": {                     // PostgreSQL接続
    "Host": "localhost",
    "Port": 5432,
    "User": "postgres",
    "Password": "",
    "Database": "erupe"
  },
  "Entrance": { "Enabled": true, "Port": 53310 },
  "Sign": { "Enabled": true, "Port": 53312 },
  "API": { "Enabled": true, "Port": 8080 },
  "Channel": { "Enabled": true },
  "Discord": { "Enabled": false, "BotToken": "" },
  "GameplayOptions": {
    "MaximumNP": 100000,
    "ZennyMultiplier": 1.00,
    "MaterialMultiplier": 1.00
  },
  "DebugOptions": {
    "CleanDB": false,
    "LogInboundMessages": false
  }
}
```

---

## ビルドと実行

### ローカル実行

```bash
go build
./Erupe
```

または

```bash
go run .
```

### Docker実行

```bash
docker build . -t erupe:dev
docker-compose up -d
```

---

## 次のドキュメント

- [01-program-flow.md](./01-program-flow.md) - プログラムの流れ
- [02-architecture.md](./02-architecture.md) - アーキテクチャ
- [03-implementation.md](./03-implementation.md) - 実装手法
