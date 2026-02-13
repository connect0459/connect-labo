# デバッグワークフロー

## 概要

効果的なデバッグには、**静的解析を優先**し、段階的にアプローチを深めていく体系的なワークフローが必要です。
闇雲にdebug loggingを追加したり、探索的なコード変更を行うのではなく、まず理解することを重視します。

## 基本原則

### 1. コード変更前に静的解析

デバッグの初手は**コードを読み、ロジックをトレース**することです。

❌ **避けるべき**:

```typescript
// いきなりconsole.logを追加
console.log('DEBUG: user', user);
console.log('DEBUG: data', data);
```

✅ **推奨**:

1. 関連ファイルを読み込む
2. データフローをトレース
3. 仮説を立てる
4. 必要に応じてloggingを追加

### 2. 調査 → 診断 → アプローチ提示 → 承認 → 実装

特に複数レイヤーにまたがる問題では、**実装前に診断結果とアプローチをユーザーに提示**します。

```text
Phase 1: 調査（Investigation）
  ↓
Phase 2: 診断（Diagnosis）
  ↓
Phase 3: アプローチ提示（Proposal）
  ↓
Phase 4: ユーザー承認（Approval）
  ↓
Phase 5: 実装（Implementation）
```

### 3. 仮説駆動デバッグ

観測された現象から**仮説を立て、検証**していくアプローチを取ります。

```markdown
## 現象
- ユーザーがログインできない

## 仮説
1. セッションの有効期限切れ
2. 認証トークンの不一致
3. データベース接続エラー

## 検証
1. ログファイルでセッション情報確認 → 有効期限内
2. トークン生成・検証ロジックを確認 → 正常
3. DB接続ログを確認 → タイムアウト発生 ← 根本原因
```

## 実践デバッグワークフロー

### Phase 1: 問題の特定と再現条件の確認

#### 1.1 現象の正確な把握

```markdown
## 問題の詳細

- **発生タイミング**: いつ、どの操作で発生するか
- **エラーメッセージ**: 表示されるエラー内容
- **期待動作**: 本来どう動作すべきか
- **実際の動作**: 現在どう動作しているか
- **影響範囲**: 全ユーザー/特定条件下のみ
```

#### 1.2 再現手順の確認

```markdown
## 再現手順

1. [操作1]
2. [操作2]
3. [エラー発生]

## 再現性

- [ ] 100%再現
- [ ] 間欠的（条件: ___）
- [ ] 一度のみ
```

### Phase 2: 静的解析による原因調査

#### 2.1 関連ファイルの特定

```bash
# エラーメッセージやスタックトレースからファイルを特定
rg "エラーメッセージの一部" -t typescript

# 関連する機能のファイルを検索
rg "LoginService" --files-with-matches
```

#### 2.2 データフローのトレース

```markdown
## データフロー分析

1. **Entry Point**: `login.tsx` のフォーム送信
2. **API Call**: `authService.login(email, password)`
3. **Backend**: `POST /api/auth/login`
4. **Controller**: `AuthController.login()`
5. **Service**: `AuthService.authenticate()`
6. **Repository**: `UserRepository.findByEmail()`
7. **Database**: users テーブルクエリ
```

コードを読みながら、各層でのデータ変換とエラーハンドリングを確認します。

#### 2.3 仮説の構築

静的解析の結果から、考えられる原因の仮説を立てます。

```markdown
## 仮説

### 仮説1: バリデーションエラー
- 根拠: email形式チェックで正規表現が厳しすぎる可能性
- 検証方法: バリデーションロジックを確認

### 仮説2: セッション管理の問題
- 根拠: ログイン後にセッションが正しく設定されていない
- 検証方法: セッション生成・保存ロジックを確認

### 仮説3: データベース接続
- 根拠: タイムアウトエラーが散発的に発生
- 検証方法: DBコネクションプールの設定を確認
```

### Phase 3: 仮説の検証

#### 3.1 ログ・エラー出力の確認

既存のログを確認します。

```bash
# アプリケーションログ
tail -f logs/app.log

# エラーログ
tail -f logs/error.log

# データベースログ
tail -f /var/log/mysql/mysql.log
```

#### 3.2 コード上での検証

```typescript
// バリデーションロジックを確認
function validateEmail(email: string): boolean {
  // 正規表現が厳しすぎないか確認
  const regex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return regex.test(email);
}

// セッション設定を確認
function createSession(userId: string) {
  // セッションが正しく設定されているか
  session.set('userId', userId);
  session.set('createdAt', Date.now());
}
```

#### 3.3 必要に応じてloggingを追加

静的解析だけでは不明な場合、**最小限のlogging**を追加します。

```typescript
// Good: ピンポイントで必要な情報のみログ
logger.debug('Login attempt', { email, timestamp: Date.now() });

// Bad: 闇雲に全てをログ
console.log('user:', user);
console.log('data:', data);
console.log('config:', config);
```

### Phase 4: アプローチの提示とユーザー承認

診断結果とアプローチをユーザーに提示します。

```markdown
## 診断結果

### 根本原因

データベースコネクションプールの最大接続数が5に設定されており、
同時アクセス数が多い時間帯にコネクション枯渇が発生しています。

### 証拠

1. エラーログに「connection pool timeout」が記録
2. 発生時刻が平日12時台に集中
3. コネクションプールの設定が `maxConnections: 5`

## 修正アプローチ

### 提案1: コネクションプール設定の変更（推奨）

- `maxConnections` を 20 に増加
- `connectionTimeout` を 10000ms に設定
- 影響: 設定変更のみ、リスク低

### 提案2: コネクション管理の改善

- 長時間保持しているコネクションをクローズ
- 使用していないコネクションの早期解放
- 影響: コード変更が必要、テストが必要

## 推奨アプローチ

提案1を実施し、様子を見ることを推奨します。
問題が継続する場合は提案2も検討します。

承認いただければ実装を開始します。
```

### Phase 5: 実装と検証

#### 5.1 修正の実装

承認を得たアプローチに従って実装します。

```typescript
// 修正前
const pool = mysql.createPool({
  host: 'localhost',
  user: 'root',
  password: 'password',
  database: 'mydb',
  connectionLimit: 5, // ← 問題
});

// 修正後
const pool = mysql.createPool({
  host: 'localhost',
  user: 'root',
  password: 'password',
  database: 'mydb',
  connectionLimit: 20, // ← 修正
  connectTimeout: 10000,
});
```

#### 5.2 テストによる検証

```bash
# ユニットテストの実行
npm test

# 手動テスト
# 1. ログイン画面でテストユーザーでログイン
# 2. 複数ブラウザで同時ログインを試行
# 3. エラーが発生しないことを確認
```

#### 5.3 モニタリング

修正後、問題が解消されたかモニタリングします。

```bash
# エラーログを監視
tail -f logs/error.log | grep "connection pool"

# アプリケーションメトリクスを確認
# - 同時接続数
# - レスポンスタイム
# - エラー率
```

## レイヤー別デバッグ戦略

### フロントエンド（React/TypeScript）

#### フロントエンドのデバッグ観点

1. **状態管理**: stateの変化を追跡
2. **API通信**: リクエスト/レスポンスの確認
3. **レンダリング**: 無限ループ、不要な再レンダリング
4. **イベントハンドリング**: クリックイベント等の伝播

#### フロントエンドのツール

```typescript
// React DevTools
// - Component tree
// - Props/State inspection

// ブラウザ DevTools
// - Network tab: API通信確認
// - Console: エラーメッセージ
// - Sources: ブレークポイント

// Redux DevTools（Redux使用時）
// - Action履歴
// - State変化
```

### バックエンド（Go/PHP/Rust）

#### バックエンドのデバッグ観点

1. **リクエスト処理**: ルーティング、ミドルウェア
2. **ビジネスロジック**: バリデーション、データ変換
3. **データベース**: クエリ、コネクション
4. **外部API**: タイムアウト、エラーハンドリング

#### バックエンドのツール

```bash
# ログ確認
tail -f logs/app.log

# データベースクエリログ
# MySQL
SET GLOBAL general_log = 'ON';
tail -f /var/log/mysql/mysql.log

# PHPのエラーログ
tail -f /var/log/php/error.log

# Goのpprof（パフォーマンス解析）
go tool pprof http://localhost:6060/debug/pprof/profile
```

### データベース

#### データベースのデバッグ観点

1. **クエリパフォーマンス**: スロークエリ
2. **インデックス**: 適切なインデックス設定
3. **ロック**: デッドロック、長時間ロック
4. **コネクション**: プール設定、リーク

#### データベースのツール

```sql
-- スロークエリログの確認
SHOW VARIABLES LIKE 'slow_query_log';

-- 実行計画の確認
EXPLAIN SELECT * FROM users WHERE email = 'test@example.com';

-- コネクション状態の確認
SHOW PROCESSLIST;

-- デッドロックの確認
SHOW ENGINE INNODB STATUS;
```

## よくあるアンチパターン

### 1. 闇雲なconsole.log追加

❌ **避けるべき**:

```typescript
console.log('1');
console.log('2');
console.log('user', user);
console.log('data', data);
console.log('3');
```

✅ **推奨**:

```typescript
// 仮説: userがundefinedかもしれない
logger.debug('User validation', {
  userExists: !!user,
  userId: user?.id,
});
```

### 2. 探索的なコード変更

❌ **避けるべき**:

```typescript
// とりあえず色々試してみる
// await fetchUser(id);
// await fetchUser(id.toString());
const user = await fetchUser(String(id));
```

✅ **推奨**:

```typescript
// 1. idの型を確認（number | string?）
// 2. fetchUserの期待する型を確認
// 3. 型が一致しない原因を調査
// 4. 適切な修正を実施
```

### 3. エラーの握りつぶし

❌ **避けるべき**:

```typescript
try {
  await riskyOperation();
} catch (error) {
  // エラーを無視
}
```

✅ **推奨**:

```typescript
try {
  await riskyOperation();
} catch (error) {
  logger.error('Risky operation failed', { error, context });
  throw error; // または適切なエラーハンドリング
}
```

## Coding Agentでのデバッグ依頼

### 基本テンプレート

```text
[現象の説明] が発生しています。

デバッグをお願いします:

1. コード変更や logging 追加は行わず、まず静的解析
2. 関連ファイルを読み込み、データフローをトレース
3. 考えられる原因の仮説を複数提示
4. 各仮説の根拠と検証方法を説明
5. 最も可能性の高い原因とアプローチを提案
6. 私の承認後に実装開始
```

### 複数レイヤーにまたがる問題

```text
[現象] が発生しています。
フロントエンド（React）とバックエンド（PHP）の両方が関係していそうです。

以下の順で調査してください:

1. フロントエンドのAPI呼び出しを確認
2. バックエンドのエンドポイント処理を確認
3. データベースクエリを確認
4. どのレイヤーで問題が発生しているか特定
5. 修正アプローチを提案

コード変更は承認後にお願いします。
```

## まとめ

- **静的解析を優先**: いきなりlogging追加やコード変更をしない
- **仮説駆動**: 現象から仮説を立て、検証する
- **調査→診断→提案→承認→実装**: 段階的に進める
- **ピンポイントlogging**: 必要最小限のloggingのみ追加
- **根本原因を探る**: 表面的な対処ではなく、根本原因を解決

---

**参考資料**:

- `dev-settings/claude/agent-docs/testing/tdd-workflow.md` - テスト駆動開発
- `dev-settings/claude/agent-docs/conventions/code-comments.md` - コメント規約
