# アーキテクチャ

## 全体構成

Erupeは **マルチサーバーアーキテクチャ** を採用しており、単一のモノリシックアプリケーション内で複数のサービスを並行稼働させます。

```text
┌─────────────────────────────────────────────────────────────────┐
│                         main.go                                  │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌────────────┐ │
│  │  Config    │  │  Logger    │  │  Database  │  │  Discord   │ │
│  │  (Viper)   │  │  (Zap)     │  │  (sqlx)    │  │  (optional)│ │
│  └─────┬──────┘  └─────┬──────┘  └─────┬──────┘  └─────┬──────┘ │
│        │               │               │               │        │
│        └───────────────┼───────────────┼───────────────┘        │
│                        │ (依存性注入)   │                        │
│   ┌────────────────────┼───────────────┼────────────────────┐   │
│   ▼                    ▼               ▼                    ▼   │
│ ┌──────────┐  ┌──────────┐  ┌──────────────────┐  ┌──────────┐ │
│ │ Entrance │  │   Sign   │  │ Channel Servers  │  │   API    │ │
│ │  Server  │  │  Server  │  │  (複数インスタンス) │  │  Server  │ │
│ │ TCP:53310│  │ TCP:53312│  │  TCP:54001-54008 │  │ HTTP:8080│ │
│ └──────────┘  └──────────┘  └──────────────────┘  └──────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

---

## レイヤー構成

### ネットワークレイヤー (network/)

暗号化された MHF プロトコルを処理するレイヤーです。

```text
network/
├── crypto/           # 暗号化アルゴリズム
├── binpacket/        # バイナリパケットプリミティブ
├── clientctx/        # クライアントコンテキスト
├── mhfpacket/        # MHF パケット定義 (434+ タイプ)
├── crypt_conn.go     # 暗号化接続ラッパー
├── crypt_packet.go   # パケット暗号化処理
└── packetid.go       # パケット ID enum
```

**レイヤー構造**:

```text
Application Layer (MHFPacket)
        ▲
        │ Parse() / Build()
        ▼
Encryption Layer (CryptConn)
        ▲
        │ Encrypt / Decrypt
        ▼
Transport Layer (net.Conn - TCP)
```

---

### サーバーレイヤー (server/)

各サーバータイプの実装を含むレイヤーです。

```text
server/
├── entranceserver/   # ステートレス、サーバー一覧
├── signserver/       # セッション認証
├── channelserver/    # ステートフル、ゲームプレイ
├── api/              # REST API
└── discordbot/       # Discord 統合
```

---

### 共通レイヤー (common/)

ゲーム固有のユーティリティを提供するレイヤーです。

```text
common/
├── byteframe/        # バイナリストリーム操作
├── decryption/       # クライアントデータ復号
├── mhfcid/           # キャラクター ID
├── mhfcourse/        # サブスクリプションコース
├── mhfitem/          # アイテムデータ
├── mhfmon/           # モンスターデータ
├── pascalstring/     # Pascal 文字列
├── token/            # トークン生成
└── ...
```

---

## パケットアーキテクチャ

### 3層暗号化構造

```text
┌───────────────────────────────────────────────────────────────┐
│ Layer 1: CryptConn (暗号化接続)                               │
│ ┌───────────────────────────────────────────────────────────┐ │
│ │ 14-byte Encrypted Header                                   │ │
│ │ ┌────┬──────────┬──────────┬──────────┬────────┬────────┐ │ │
│ │ │Pf0 │KeyRotDelta│PacketNum │DataSize  │PrevChk │Chk0-2  │ │ │
│ │ └────┴──────────┴──────────┴──────────┴────────┴────────┘ │ │
│ └───────────────────────────────────────────────────────────┘ │
├───────────────────────────────────────────────────────────────┤
│ Layer 2: Crypto (暗号化エンジン)                              │
│ - 256-byte 置換テーブル (_encryptKey, _decryptKey)           │
│ - 共有暗号キー (_sharedCryptKey)                             │
│ - トリプルチェックサム検証                                    │
└───────────────────────────────────────────────────────────────┘
        │
        ▼
┌───────────────────────────────────────────────────────────────┐
│ Layer 3: MHFPacket (プロトコル)                               │
│ ┌───────────────────────────────────────────────────────────┐ │
│ │ interface MHFPacket {                                      │ │
│ │     Parse(bf *ByteFrame, ctx *ClientContext) error         │ │
│ │     Build(bf *ByteFrame, ctx *ClientContext) error         │ │
│ │     Opcode() PacketID                                      │ │
│ │ }                                                          │ │
│ └───────────────────────────────────────────────────────────┘ │
└───────────────────────────────────────────────────────────────┘
```

### パケット処理パイプライン

```text
受信側:
Raw TCP Data → CryptConn.ReadPacket() → Decrypt → Checksum Verify
    → FromOpcode() [Factory] → MHFPacket.Parse() → Handler

送信側:
Handler → MHFPacket.Build() → CryptConn.SendPacket() → Encrypt
    → Checksum Generate → Raw TCP Data
```

---

## セッション管理アーキテクチャ

### Channel Server のセッション構造

```text
┌─────────────────────────────────────────────────────────────┐
│                      Server                                  │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ sync.Mutex (スレッドセーフ)                             │ │
│  ├────────────────────────────────────────────────────────┤ │
│  │ sessions map[net.Conn]*Session                         │ │
│  │ stages map[string]*Stage                               │ │
│  │ semaphore map[string]*Semaphore                        │ │
│  └────────────────────────────────────────────────────────┘ │
│           │                                                  │
│           ▼                                                  │
│  ┌─────────────────┐  ┌─────────────────┐                   │
│  │    Session 1    │  │    Session 2    │  ...              │
│  │  ┌───────────┐  │  │  ┌───────────┐  │                   │
│  │  │ sendLoop  │  │  │  │ sendLoop  │  │                   │
│  │  │ recvLoop  │  │  │  │ recvLoop  │  │                   │
│  │  └───────────┘  │  │  └───────────┘  │                   │
│  └─────────────────┘  └─────────────────┘                   │
└─────────────────────────────────────────────────────────────┘
```

### ゴルーチン構成

```text
Server
├── acceptClients()        # 接続受付ループ
├── manageSessions()       # セッション管理ループ
└── invalidateSessions()   # タイムアウト検出 (10秒間隔)

Per Session:
├── sendLoop()             # パケット送信ループ
└── recvLoop()             # パケット受信ループ
```

---

## ステージとセマフォ

### Stage (ゲームエリア)

ゲーム内の空間単位を表現します。

```text
┌─────────────────────────────────────────────────────┐
│                     Stage                            │
│  ┌────────────────────────────────────────────────┐ │
│  │ sync.RWMutex (読み書きロック)                   │ │
│  ├────────────────────────────────────────────────┤ │
│  │ id string                     # ステージ ID    │ │
│  │ objects map[uint32]*Object    # オブジェクト    │ │
│  │ clients map[*Session]uint32   # 参加セッション  │ │
│  │ password []byte               # パスワード保護  │ │
│  │ rawBinaryData []byte          # バイナリ設定    │ │
│  └────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────┘
```

### Semaphore (同期プリミティブ)

ギルドイベントや特殊クエスト (Raviente) で使用される同期機構です。

```text
┌─────────────────────────────────────────────────────┐
│                   Semaphore                          │
│  ┌────────────────────────────────────────────────┐ │
│  │ id string                     # セマフォ ID    │ │
│  │ clients map[*Session]uint32   # 参加セッション  │ │
│  │ state uint32                  # 状態           │ │
│  └────────────────────────────────────────────────┘ │
│                                                      │
│  ID空間: 0x000E0000, 0x000F0000 プレフィックス       │
└─────────────────────────────────────────────────────┘
```

---

## データベースアーキテクチャ

### 接続管理

```text
┌─────────────────────────────────────────────────────┐
│                PostgreSQL Connection Pool            │
│  ┌────────────────────────────────────────────────┐ │
│  │ *sqlx.DB (github.com/jmoiron/sqlx)             │ │
│  │  - Named queries サポート                      │ │
│  │  - database/sql ラッパー                       │ │
│  └────────────────────────────────────────────────┘ │
│                        │                             │
│     ┌──────────────────┼──────────────────┐         │
│     ▼                  ▼                  ▼         │
│  Entrance           Sign             Channel        │
│  Server             Server           Servers        │
└─────────────────────────────────────────────────────┘
```

### 主要テーブル

| テーブル | 用途 |
| :--- | :--- |
| `users` | ユーザーアカウント |
| `characters` | キャラクターデータ |
| `guilds` | ギルド情報 |
| `sign_sessions` | 認証セッション (起動時クリア) |
| `servers` | サーバー登録情報 |

---

## クロスチャネル通信

### WorldcastMHF

全チャネルサーバーにパケットをブロードキャストする機構です。

```text
┌─────────────────────────────────────────────────────────────┐
│                    Channel Server A                          │
│  Session.WorldcastMHF(pkt, nil, nil)                        │
│           │                                                  │
│           ▼                                                  │
│  ┌─────────────────┐                                        │
│  │ server.Channels │ ← 全チャネルへの参照                    │
│  └────────┬────────┘                                        │
│           │                                                  │
│     ┌─────┼─────────────────────┐                           │
│     ▼     ▼                     ▼                           │
│  ┌─────┐ ┌─────┐             ┌─────┐                        │
│  │ Ch A│ │ Ch B│     ...     │ Ch N│                        │
│  └──┬──┘ └──┬──┘             └──┬──┘                        │
│     │       │                   │                            │
│     ▼       ▼                   ▼                            │
│  BroadcastMHF() to all sessions in each channel             │
└─────────────────────────────────────────────────────────────┘
```

---

## 設定駆動アーキテクチャ

### Config 構造体

```go
type ErupeConfig struct {
    Host        string           // バインド IP
    ClientMode  string           // クライアント版 (40+ 対応)
    Database    DatabaseConfig   // PostgreSQL 設定
    Entrance    EntranceConfig   // 入場サーバー設定
    Sign        SignConfig       // 認証サーバー設定
    API         APIConfig        // REST API 設定
    Channel     ChannelConfig    // チャネルサーバー設定
    Discord     DiscordConfig    // Discord 統合
    GameplayOptions GameplayOpts // ゲームプレイ調整
    DebugOptions    DebugOpts    // デバッグ機能
}
```

### チャネル ID 計算

```go
// Entrance と Channel のインデックスから一意の ID を生成
serverID := 4096 + (entranceIndex * 256) + (16 + channelIndex)

// GlobalID 文字列 (例: "0101" = Entrance 1, Channel 1)
globalID := fmt.Sprintf("%02d%02d", entranceIndex+1, channelIndex+1)
```

---

## 次のドキュメント

- [03-implementation.md](./03-implementation.md) - 実装手法
