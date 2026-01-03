# プログラムの流れ

## メインエントリーポイント

Erupeのエントリーポイントは `main.go` です。プログラムは以下の順序で初期化されます。

### 初期化シーケンス

```text
main()
├── 1. ロガーセットアップ (zap.Logger)
├── 2. 設定読み込み (config.json)
├── 3. バリデーション (DB パスワード、ホストアドレス)
├── 4. Discord ボット初期化 (オプション)
├── 5. PostgreSQL 接続確立
├── 6. DB クリーンアップ (古いセッション削除)
├── 7. サーバー群の起動
│   ├── Entrance Server
│   ├── Sign Server
│   ├── API Server
│   └── Channel Servers (複数)
└── 8. シグナル待機 (Ctrl+C でシャットダウン)
```

---

## サーバー起動プロセス

### 1. Entrance Server (入場サーバー)

**ファイル**: `server/entranceserver/entrance_server.go`

**起動フロー**:

```go
entranceServer := entranceserver.NewServer(logger, config, db)
entranceServer.Start()
```

**処理内容**:

- TCP リスナーを設定ポート (53310) でバインド
- `acceptClients()` ゴルーチンで接続待機
- 各接続に対して `handleEntranceServerConnection()` を実行:
  1. 8バイトの NULL 初期化パケットを読み込み
  2. `CryptConn` で暗号化接続を確立
  3. クライアントからのパケットを読み込み
  4. サーバー一覧レスポンス (`makeSv2Resp()`) を送信
  5. 接続をクローズ (ステートレスプロトコル)

---

### 2. Sign Server (認証サーバー)

**ファイル**: `server/signserver/sign_server.go`

**起動フロー**:

```go
signServer := signserver.NewServer(logger, config, db)
signServer.Start()
```

**処理内容**:

- TCP リスナーを設定ポート (53312) でバインド
- `acceptClients()` ゴルーチンで接続待機
- 各接続で `Session` を作成:
  1. 8バイトの NULL 初期化パケットを読み込み
  2. `CryptConn` で暗号化接続を確立
  3. `session.work()` で1パケットを処理:
     - リクエストタイプを解析 (DSGN:, PS4SGN:, VITASGN: など)
     - ユーザー認証、PSNアカウントリンク、キャラクター削除を処理
     - レスポンス送信後に接続クローズ

---

### 3. API Server (REST API サーバー)

**ファイル**: `server/api/api_server.go`

**起動フロー**:

```go
apiServer := api.NewAPIServer(logger, config, db)
apiServer.Start()
```

**エンドポイント**:

- `/launcher` - ランチャー HTML/コンテンツ
- `/login`, `/register` - ユーザー認証
- `/character/create`, `/character/delete` - キャラクター管理
- `/character/export` - セーブデータエクスポート
- `/api/ss/bbs/upload.php`, `/api/ss/bbs/{id}` - スクリーンショット

**処理内容**:

- `gorilla/mux` ルーターでエンドポイント設定
- CORS ヘッダーとロギングミドルウェア設定
- バックグラウンドゴルーチンで HTTP サーバー起動
- 250ms 待機して即時エラーを検出

---

### 4. Channel Server (ゲームプレイサーバー)

**ファイル**: `server/channelserver/sys_channel_server.go`

**起動フロー**:

```go
for _, entry := range config.Entrance.Entries {
    for _, channel := range entry.Channels {
        c := channelserver.NewServer(...)
        c.Start()
        channelServers = append(channelServers, c)
    }
}
// 全チャネル起動後、相互参照を設定
for _, c := range channelServers {
    c.Channels = channelServers
}
```

**処理内容**:

- 各チャネルに固有の ID を割り当て (例: "0101" = Entrance 1, Channel 1)
- TCP リスナーを動的ポートでバインド
- 3つのゴルーチンを起動:
  - `acceptClients()` - 新規接続を受け付け
  - `manageSessions()` - セッションライフサイクル管理
  - `invalidateSessions()` - 10秒ごとにタイムアウトチェック (30秒)
- 各接続で `Session` を作成し、送受信ループを開始

---

## リクエスト処理フロー

### Channel Server のパケット処理

```text
クライアント
    │
    ▼
┌─────────────────────────────────┐
│  Session.recvLoop()             │
│  ├─ CryptConn.ReadPacket()      │  ← 暗号化パケット受信
│  │   └─ Crypto.Crypto()         │  ← 復号化 + チェックサム検証
│  └─ Session.handlePacketGroup() │
│      ├─ MHFPacket.FromOpcode()  │  ← パケットタイプ特定 (Factory)
│      ├─ MHFPacket.Parse()       │  ← バイナリデシリアライズ
│      └─ handlerTable[opcode]()  │  ← ハンドラー呼び出し
└─────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────┐
│  Handler (handlers_*.go)        │
│  ├─ ゲームロジック実行          │
│  ├─ データベースクエリ          │
│  └─ Session.QueueSendMHF(pkt)   │  ← レスポンスキュー
└─────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────┐
│  Session.sendLoop()             │
│  ├─ パケットをバッチ処理        │
│  ├─ MHFPacket.Build()           │  ← バイナリシリアライズ
│  └─ CryptConn.SendPacket()      │  ← 暗号化して送信
└─────────────────────────────────┘
    │
    ▼
クライアント
```

### ハンドラーの種類

`channelserver/` 内の 48個のハンドラーファイル:

- **クエスト関連**: `handlers_quest.go`, `handlers_reserve.go`
- **ギルド**: `handlers_guild.go` (最大、58KB), `handlers_guild_member.go`, `handlers_guild_alliance.go`
- **戦闘**: `handlers_seibattle.go`, `handlers_tournament.go`, `handlers_tower.go`
- **イベント**: `handlers_diva.go`, `handlers_festa.go`
- **ショップ**: `handlers_shop_gacha.go`
- **ユーザー**: `handlers_users.go`, `handlers_character.go`
- **ハウス**: `handlers_house.go`
- **その他**: `handlers_stage.go`, `handlers_object.go`, `handlers_mail.go`

---

## セッション管理

### セッションライフサイクル

```text
1. Accept
   net.Listener.Accept() → 新規接続
       │
2. Create
   NewSession(server, conn) → Session 構造体作成
       │
3. Initialize
   ├─ CryptConn 作成 (暗号化レイヤー)
   ├─ sendLoop() ゴルーチン起動
   └─ recvLoop() ゴルーチン起動
       │
4. Running
   パケット送受信、ゲーム処理
       │
5. Timeout Detection
   30秒間パケットなし → invalidateSessions() が検出
       │
6. Cleanup
   ├─ logoutPlayer() 呼び出し
   ├─ Session.closed = true
   └─ 接続クローズ
```

### Session 構造体の主要フィールド

```go
type Session struct {
    // 接続情報
    conn     net.Conn
    cryptConn *CryptConn

    // 認証情報
    charID    uint32      // キャラクター ID
    token     string      // ユーザートークン
    loginTime time.Time   // ログイン時刻

    // 状態管理
    stage        *Stage      // 現在のステージ
    reservedStage *Stage     // 予約ステージ
    semaphore    [2]*Semaphore

    // パケット処理
    sendPackets chan MHFPacket  // 送信キュー (バッファ: 20)
    lastPacket  time.Time       // 最後のパケット時刻

    // フラグ
    closed bool
}
```

---

## グレースフルシャットダウン

`Ctrl+C` または `SIGTERM` 受信時:

```text
1. シグナルハンドラが割り込み検知
       │
2. ソフトクラッシュ無効でなければ:
   ├─ 全チャネルサーバーにシャットダウン通知
   └─ 10秒カウントダウン (プレイヤーに警告)
       │
3. サーバーを逆順でシャットダウン:
   ├─ Channel Servers (全チャネル)
   ├─ Sign Server
   ├─ API Server
   └─ Entrance Server
       │
4. 1秒待機 (クリーンアップ)
       │
5. プロセス終了
```

---

## ブロードキャスト機構

### ブロードキャストの種類

```go
// 同一サーバー内の全セッション
Server.BroadcastMHF(pkt, ignoredSession)

// 全チャネルサーバー (ワールドキャスト)
Server.WorldcastMHF(pkt, ignoredSession, channel)

// 同一ステージ内のセッション
Stage.BroadcastMHF(pkt, ignoredSession)

// 同一セマフォ内のセッション
Semaphore.BroadcastMHF(pkt, ignoredSession)
```

### 使用例

- **位置更新**: ステージ内の他プレイヤーに座標を送信
- **チャット**: ワールドキャストで全チャネルに配信
- **ギルドイベント**: セマフォで参加者にのみ通知

---

## 次のドキュメント

- [02-architecture.md](./02-architecture.md) - アーキテクチャ
- [03-implementation.md](./03-implementation.md) - 実装手法
