# 実装手法

## デザインパターン

Erupe では複数のデザインパターンが効果的に活用されています。

### 1. Factory パターン

パケットタイプの動的生成に使用されています。

**実装箇所**: `network/mhfpacket/mhfpacket.go`

```go
// FromOpcode はオペコードから適切なパケット型を生成する Factory
func FromOpcode(opcode network.PacketID) MHFPacket {
    switch opcode {
    case network.MSG_SYS_PING:
        return &MsgSysPing{}
    case network.MSG_SYS_ACK:
        return &MsgSysAck{}
    case network.MSG_MHF_SAVEDATA:
        return &MsgMhfSavedata{}
    // ... 434+ ケース
    default:
        return nil
    }
}
```

**利点**:

- オペコードからの遅延バインディング
- 新規パケット追加が容易
- クライアント依存性の分離

---

### 2. Handler Table パターン

パケットを対応するハンドラー関数にディスパッチします。

**実装箇所**: `server/channelserver/handlers.go`

```go
type handlerFunc func(*Session, mhfpacket.MHFPacket)

var handlerTable = map[network.PacketID]handlerFunc{
    network.MSG_SYS_PING:           handleMsgSysPing,
    network.MSG_SYS_TIME:           handleMsgSysTime,
    network.MSG_MHF_ENUMERATE_QUEST: handleMsgMhfEnumerateQuest,
    // ... 多数のマッピング
}

// パケット処理時の呼び出し
func (s *Session) handlePacket(pkt mhfpacket.MHFPacket) {
    if handler, ok := handlerTable[pkt.Opcode()]; ok {
        handler(s, pkt)
    }
}
```

**利点**:

- O(1) のルーティング
- リフレクション不要
- 機能別ファイル分割が容易

---

### 3. Observer パターン (Broadcast)

イベント駆動のメッセージ配信に使用されています。

**実装箇所**: `server/channelserver/sys_stage.go`, `sys_channel_server.go`

```go
// Stage 内の全セッションにブロードキャスト
func (s *Stage) BroadcastMHF(pkt mhfpacket.MHFPacket, ignoredSession *Session) {
    s.RLock()
    defer s.RUnlock()
    for session := range s.clients {
        if session != ignoredSession && !session.closed {
            session.QueueSendMHF(pkt)
        }
    }
}

// 全チャネルサーバーにワールドキャスト
func (s *Server) WorldcastMHF(pkt mhfpacket.MHFPacket, ignoredSession *Session, ignoredChannel *Server) {
    for _, channel := range s.Channels {
        if channel != ignoredChannel {
            channel.BroadcastMHF(pkt, ignoredSession)
        }
    }
}
```

**用途**:

- プレイヤー位置の同期
- チャットメッセージ配信
- ギルドイベント通知

---

### 4. Strategy パターン

複数のアルゴリズム実装を切り替えます。

**実装例 1: ByteFrame のエンディアン**:

```go
type ByteFrame struct {
    data   []byte
    offset int
    isLE   bool  // Little Endian / Big Endian 切り替え
}

func (bf *ByteFrame) SetLE() { bf.isLE = true }
func (bf *ByteFrame) SetBE() { bf.isLE = false }

func (bf *ByteFrame) ReadUint16() uint16 {
    if bf.isLE {
        return binary.LittleEndian.Uint16(...)
    }
    return binary.BigEndian.Uint16(...)
}
```

**実装例 2: 圧縮アルゴリズム**:

```text
channelserver/compression/
├── deltacomp/   # 差分圧縮
│   └── deltacomp.go
└── nullcomp/    # 無圧縮 (パススルー)
    └── nullcomp.go
```

**実装例 3: 認証ストラテジー**:

```go
// Sign Server での認証タイプ分岐
switch {
case strings.HasPrefix(reqString, "DSGN:"):
    // PC 認証
case strings.HasPrefix(reqString, "PS3SGN:"):
    // PlayStation 3 認証
case strings.HasPrefix(reqString, "PS4SGN:"):
    // PlayStation 4 認証
case strings.HasPrefix(reqString, "VITASGN:"):
    // PS Vita 認証
case strings.HasPrefix(reqString, "WIIUSGN:"):
    // Wii U 認証
}
```

---

### 5. Builder パターン

パケットのバイナリ構築に使用されています。

**実装箇所**: 各パケット型の `Build()` メソッド

```go
func (m *MsgMhfSavedata) Build(bf *byteframe.ByteFrame, ctx *clientctx.ClientContext) error {
    bf.WriteUint16(uint16(m.Opcode()))
    bf.WriteUint32(m.CharacterID)
    bf.WriteBytes(m.SaveData)
    return nil
}
```

---

### 6. 依存性注入 (DI)

コンポーネント間の結合を緩くするために使用されています。

```go
// サーバー作成時に依存性を注入
func NewServer(
    logger *zap.Logger,      // ロガー注入
    config *config.Config,   // 設定注入
    db *sqlx.DB,             // データベース注入
) *Server {
    return &Server{
        logger: logger,
        config: config,
        db:     db,
    }
}
```

**利点**:

- テスト容易性の向上
- コンポーネント交換が容易
- 明示的な依存関係

---

### 7. Mutex 保護パターン

共有状態のスレッドセーフな操作を保証します。

```go
type Server struct {
    sync.Mutex  // 排他ロック
    sessions map[net.Conn]*Session
}

type Stage struct {
    sync.RWMutex  // 読み書きロック
    objects map[uint32]*Object
    clients map[*Session]uint32
}

// 使用例
func (s *Server) AddSession(conn net.Conn, session *Session) {
    s.Lock()
    defer s.Unlock()
    s.sessions[conn] = session
}

func (st *Stage) GetClients() []*Session {
    st.RLock()  // 読み取りロック (複数同時可)
    defer st.RUnlock()
    // ...
}
```

---

### 8. Template Method パターン

サーバーの共通インターフェースを定義しています。

```go
// 各サーバーは同じライフサイクルメソッドを実装
type Server interface {
    Start() error
    Shutdown()
}

// Entrance, Sign, Channel, API すべてが実装
entranceServer.Start()
signServer.Start()
channelServer.Start()
apiServer.Start()

// シャットダウンも同様
entranceServer.Shutdown()
// ...
```

---

## Go イディオム

### チャネルによる通信

```go
type Server struct {
    acceptConns chan net.Conn   // 新規接続キュー
    deleteConns chan net.Conn   // 削除リクエストキュー
}

type Session struct {
    sendPackets chan mhfpacket.MHFPacket  // 送信キュー (バッファ: 20)
}

// select による多重待機
func (s *Server) manageSessions() {
    for {
        select {
        case conn := <-s.acceptConns:
            // 新規セッション作成
        case conn := <-s.deleteConns:
            // セッション削除
        }
    }
}
```

---

### ゴルーチンによる並行処理

```go
// サーバー起動時に複数のゴルーチンを生成
func (s *Server) Start() {
    go s.acceptClients()       // 接続受付
    go s.manageSessions()      // セッション管理
    go s.invalidateSessions()  // タイムアウト検出
}

// セッションごとに送受信ループ
func NewSession(server *Server, conn net.Conn) *Session {
    s := &Session{...}
    go s.sendLoop()  // 送信ゴルーチン
    go s.recvLoop()  // 受信ゴルーチン
    return s
}
```

---

### defer による確実なリソース解放

```go
func (s *Stage) BroadcastMHF(...) {
    s.RLock()
    defer s.RUnlock()  // 関数終了時に必ずアンロック
    // ...
}

func (s *Session) work() {
    defer s.conn.Close()  // 関数終了時に必ず接続クローズ
    // ...
}
```

---

## インターフェース設計

### MHFPacket インターフェース

```go
// パケット共通インターフェース
type MHFPacket interface {
    Parser   // Parse(bf *ByteFrame, ctx *ClientContext) error
    Builder  // Build(bf *ByteFrame, ctx *ClientContext) error
    Opcoder  // Opcode() network.PacketID
}

// 各パケット型が実装
type MsgSysPing struct{}

func (m *MsgSysPing) Opcode() network.PacketID { return network.MSG_SYS_PING }
func (m *MsgSysPing) Parse(bf *byteframe.ByteFrame, ctx *clientctx.ClientContext) error { return nil }
func (m *MsgSysPing) Build(bf *byteframe.ByteFrame, ctx *clientctx.ClientContext) error {
    bf.WriteUint16(uint16(m.Opcode()))
    return nil
}
```

---

## バイナリプロトコル処理

### ByteFrame ユーティリティ

```go
type ByteFrame struct {
    data   []byte
    offset int
    isLE   bool
}

// 読み取りメソッド
func (bf *ByteFrame) ReadUint8() uint8
func (bf *ByteFrame) ReadUint16() uint16
func (bf *ByteFrame) ReadUint32() uint32
func (bf *ByteFrame) ReadBytes(n int) []byte

// 書き込みメソッド
func (bf *ByteFrame) WriteUint8(v uint8)
func (bf *ByteFrame) WriteUint16(v uint16)
func (bf *ByteFrame) WriteUint32(v uint32)
func (bf *ByteFrame) WriteBytes(data []byte)

// カーソル操作
func (bf *ByteFrame) Seek(offset int64, whence int)
func (bf *ByteFrame) Index() int
```

---

### パケットヘッダー構造

```go
type PacketHeader struct {
    Pf0                     uint8   // フラグ
    KeyRotDelta             uint8   // キーローテーション
    PacketNum               uint16  // シーケンス番号
    DataSize                uint16  // ペイロードサイズ
    PrevPacketCombinedCheck uint16  // 前パケットチェックサム
    Check0                  uint16  // チェックサム 0
    Check1                  uint16  // チェックサム 1
    Check2                  uint16  // チェックサム 2
}
```

---

## エラーハンドリング

### 復帰可能なエラー

```go
func (cc *CryptConn) ReadPacket() ([]byte, error) {
    // チェックサムエラー時にキー復元を試行
    if checksumMismatch {
        recoveredKey, err := cc.bruteforceKeyRecovery()
        if err != nil {
            return nil, fmt.Errorf("key recovery failed: %w", err)
        }
        cc.key = recoveredKey
        // 再試行
    }
    // ...
}
```

### ロギング

```go
// zap ロガーによる構造化ログ
s.logger.Info("Session started",
    zap.String("addr", conn.RemoteAddr().String()),
    zap.Uint32("charID", s.charID),
)

s.logger.Error("Packet parse failed",
    zap.Error(err),
    zap.Uint16("opcode", uint16(opcode)),
)
```

---

## データベースアクセス

### sqlx による拡張クエリ

```go
// Named クエリ
rows, err := db.NamedQuery(`
    SELECT id, name, level
    FROM characters
    WHERE user_id = :user_id
`, map[string]interface{}{
    "user_id": userID,
})

// 直接クエリ
var rights int
err := db.QueryRow(`
    SELECT rights FROM users WHERE id = $1
`, userID).Scan(&rights)

// 実行
db.MustExec(`
    DELETE FROM sign_sessions WHERE token = $1
`, token)
```

---

## テスト

### 既存のテストファイル

```text
server/
├── entranceserver/
│   └── crypto_test.go           # 暗号化テスト
└── channelserver/
    └── compression/
        └── deltacomp_test.go    # 圧縮テスト
```

### テスト実行

```bash
go test ./...
```

---

## 固有の実装特性

### Raviente 特殊処理

大規模レイドボス用の特別なロジックが実装されています。

```go
// プレイヤー数に応じた難易度調整
func (s *Server) calculateRavienteMultiplier(playerCount int) float64 {
    switch {
    case playerCount <= s.config.GameplayOptions.RavienteMaxPlayers:
        return 1.0
    case playerCount <= 16:
        return 1.5
    default:
        return 2.0
    }
}
```

### 40+ クライアントバージョン対応

```go
// ClientMode による分岐
switch config.ClientMode {
case "S1.0", "S1.5", "S2.0":
    // 旧バージョン処理
case "G1", "G2", "G3", ..., "G10":
    // G シリーズ処理
case "Z1", "Z2", "ZZ":
    // 最新バージョン処理
}
```

### セマフォ ID 空間

```go
// 特定の ID プレフィックスで用途を区別
const (
    SemaphoreGuildEvent   = 0x000E0000  // ギルドイベント用
    SemaphoreSpecialQuest = 0x000F0000  // 特殊クエスト用
)
```

---

## まとめ

Erupe は以下の点で優れた実装を示しています：

| カテゴリ | 特徴 |
| :--- | :--- |
| デザインパターン | Factory, Observer, Strategy, Builder, Template Method |
| 並行処理 | ゴルーチン + チャネルによる Go イディオムの活用 |
| スレッドセーフ | Mutex/RWMutex による適切な保護 |
| 拡張性 | Handler Table による機能追加容易性 |
| 保守性 | 依存性注入、インターフェース設計 |
| プロトコル | 多層暗号化、チェックサム検証 |
