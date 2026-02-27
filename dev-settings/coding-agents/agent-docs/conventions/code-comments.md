# コードコメント規約

> 哲学的背景・原則の概要: `dev-settings/coding-agents/agent-docs/essences/living-documentation.md`（「コードコメントへの適用」セクション）

## ユーザーが手動でコメントを書く場合の原則

手動でコメントを書く場合は、**Why not（選択しなかった理由）を優先**します。

- **コードコメント**: 選択しなかった理由（Why not）を記述

---

## 手動コメントでWhy notを優先する理由

以下は、ユーザーが手動でコメントを書く場合のガイドラインです。

### 1. 認識ギャップの防止

「あえてやらなかったこと」を言語化しないと、レビュワーや後続開発者には「知識不足でやらなかった」と誤解されます。

```go
// Bad: コメントなし
func GetUsers() []User {
    users := userRepo.FindAll()
    for _, user := range users {
        user.Posts = postRepo.FindByUserID(user.ID) // N+1問題
    }
    return users
}

// Good: Why notを記述
func GetUsers() []User {
    // N+1問題が存在するが、データ量が300件程度のため
    // JOIN最適化は実装していない。1000件を超える場合は要検討。
    users := userRepo.FindAll()
    for _, user := range users {
        user.Posts = postRepo.FindByUserID(user.ID)
    }
    return users
}
```

### 2. 改善選択肢の可視化

**改善できたのに敢えてしなかった選択肢**を記録することが、最も重要な情報価値を持ちます。

Why（理由）は実装を見れば推測できますが、Why not（選択しなかった理由）は実装からは見えません。

### 3. 長期的な技術的負債の防止

後発開発者がコードをコピペする際、最適化されていない実装の理由が不明だと、同じ非効率なパターンが蔓延します。

```typescript
// Bad: コメントなし
const data = await fetchAll();
const result = data.map(item => transform(item)); // 同期処理

// Good: Why notを記述
const data = await fetchAll();
// Promise.allで並列処理も可能だが、APIレート制限（10req/sec）を
// 考慮し、あえて逐次処理を選択
const result = data.map(item => transform(item));
```

## 手動コメント記述のガイドライン

ユーザーが手動でコメントを書く場合の優先順位とルールです。

### 優先順位

1. **Why not（最優先）**: 改善できたが敢えてしなかった理由
2. **Why（補助）**: 複雑なロジックの理由（コードから推測困難な場合のみ）
3. **What（避ける）**: コード自体が語るべき内容

### Evergreenなコメント

時間が経っても価値を失わないコメントを書きます。

```go
// Bad: 実装詳細に依存（時間で陳腐化）
// このメソッドは呼び出し元でエラーハンドリングされます

// Good: ビジネス判断（長期的に有効）
// 会員ランクの昇格判定は即時反映せず、バッチ処理で翌日反映する。
// これはランク変動によるユーザー混乱を防ぐためのビジネス要件。
```

### 避けるべきコメント

```typescript
// Bad: コードを繰り返すだけ
// ユーザーIDを取得
const userId = user.id;

// Bad: 実装のタイミング（Dead Code化しやすい）
// この関数はログイン後に呼ばれる

// Bad: 自明な内容
let count = 0; // カウンターを初期化
```

## 実践例

### 例1: パフォーマンス最適化を見送った理由

```rust
// N+1問題が存在するが、以下の理由で最適化していない：
// - 現在のデータ量: 約200件
// - 平均レスポンス: 50ms
// - ビジネス要件: 100ms以内であればOK
// ※1000件を超える、またはレスポンスが100msを超える場合は
//   JOINクエリでの最適化を検討すること
fn get_users_with_posts(&self) -> Vec<UserWithPosts> {
    let users = self.user_repo.find_all();
    users.into_iter().map(|user| {
        let posts = self.post_repo.find_by_user_id(user.id);
        UserWithPosts { user, posts }
    }).collect()
}
```

### 例2: セキュリティ対策を見送った理由

```typescript
// CSRFトークンの検証を実装していない理由：
// - このAPIはRead-Onlyで状態変更を行わない
// - 認証はJWT Bearerトークンで行われている
// - 将来POST/PUT/DELETEを追加する場合は要実装
async function getUserData(userId: string) {
    return await db.users.findById(userId);
}
```

### 例3: エラーハンドリングを簡略化した理由

```php
// エラー時にリトライ処理を実装していない理由：
// - この処理は手動実行のバッチであり、失敗時は人間が再実行する
// - 自動リトライによる重複実行のリスクを避ける
// ※将来cronで自動実行する場合は、冪等性とリトライ処理の実装が必要
function importUsers(array $data): void
{
    foreach ($data as $row) {
        $this->userRepository->create($row);
    }
}
```

## Why を記述する場合

Why not が最優先ですが、以下の場合は Why も有用です：

### 1. ビジネスルールの背景

```go
// 会員登録から7日間は退会できない仕様。
// これは不正登録・即退会による特典の悪用を防ぐため。
func (s *UserService) CanWithdraw(user *User) bool {
    return time.Since(user.RegisteredAt) > 7*24*time.Hour
}
```

### 2. 複雑なアルゴリズムの意図

```typescript
// Luhnアルゴリズムでクレジットカード番号の妥当性を検証。
// チェックディジット計算により入力ミスを検出できる。
function validateCardNumber(cardNumber: string): boolean {
    // 実装...
}
```

### 3. 非自明な回避策

```rust
// Rustのborrowチェッカー制約により、通常のイテレータでは
// 所有権エラーが発生するため、インデックスアクセスを使用
for i in 0..items.len() {
    process(&items[i]);
}
```

## 参考資料

- [コードコメントにおける「Why Not」の重要性](https://zenn.dev/never_be_a_pm/articles/69d204df1a8c4a)
- Evergreen原則: `~/.connect0459/coding-agents/agent-docs/testing/tdd-workflow.md`

## まとめ

### Coding Agent使用時

- **基本原則**: コードコメントは書かない
- **例外**: ユーザーが明示的に許可した場合のみ
  - Why not（選択しなかった理由）を表すコメントになっているか確認
  - GitHub URL等の参照は例外的に許可

### 手動でコメントを書く場合

- **コメントの最優先事項**: 改善できたが敢えてしなかった理由（Why not）
- **目的**: 認識ギャップの防止、技術的負債の予防
- **Evergreen**: 時間が経っても価値を失わない内容を記述
- **避けるべき**: 実装詳細の繰り返し、タイミングに依存する内容
