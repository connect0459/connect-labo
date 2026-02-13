# Tidyings vs Refactoring（Kent Beck's Tidyings）

## 概要

Kent Beckが提唱するTidyingsの概念を取り入れ、リファクタリングの意味を明確に区別します。
適切な判断基準により、効率的で安全なコード改善を実現します。

## 境界づけられたコンテキスト

### Tidyings（整理整頓）

**定義**: 機会主義的で軽量な日常的コード改善

**特徴**:

- 機能実装やバグ修正の「ついで」に行う
- **2-5分以内**で完了する小さな改善
- レビューで指摘されるような明らかな問題の修正
- リスクが低く、即座に実行可能
- テストは既存のもので十分（新規テスト不要）

**例**:

- 不要な`else`句の削除
- 変数名のタイポ修正
- 未使用のインポート削除
- 重複したコードの抽出（小規模）

### Refactoring（リファクタリング）

**定義**: 計画的で構造的なコード変更

**特徴**:

- 事前計画が必要な大きな変更
- 設計パターンやアーキテクチャの変更
- 新しいテストケースの追加が必要
- リスクを伴う可能性があり、慎重な実施が必要
- 専用の時間枠を確保して実行

**例**:

- デザインパターンの導入
- アーキテクチャレイヤーの分離
- 大規模な関数の分割
- データ構造の変更

## 実践ガイドライン

### Tidyingsの実践ルール

1. **2分ルール**: 2分以内で完了しない場合はリファクタリングとして別途計画
2. **テスト実行**: tidying後は必ず既存テストを実行して動作確認
3. **即座実行**: 気づいたらその場で実行（後回しにしない）
4. **コミット分離**: tidyingは独立したコミットにする

### Refactoringの計画フロー

1. **現状分析**: 変更が必要な理由と範囲を明確化
2. **テスト充実**: リファクタリング前にテストカバレッジを向上
3. **段階的実行**: 小さなステップに分けて実行
4. **継続テスト**: 各ステップでテスト実行を確認

## 判断フローチャート

```text
コード改善を思いついた
  ↓
2分以内で完了する？
  ↓ Yes                    ↓ No
  Tidyings                 Refactoring
  ↓                        ↓
  その場で実行              計画を立てる
  ↓                        ↓
  テスト実行                テスト追加
  ↓                        ↓
  独立コミット              段階的実行
```

## コミットメッセージの使い分け

### Tidyings

```bash
git commit -m "tidy: remove unnecessary else clause in getUserName"
git commit -m "tidy: fix variable name typo in validation"
git commit -m "tidy: remove unused import in UserService"
```

### Refactoring

```bash
git commit -m "refactor: extract user validation logic to domain service"
git commit -m "refactor: implement repository pattern for user persistence"
git commit -m "refactor: split UserService into multiple domain services"
```

## 実践例

### Tidyings の例

#### Before

```go
func getUserName(user *User) string {
    if user != nil {
        return user.Name
    } else {  // 不要なelse
        return ""
    }
}
```

#### After（Tidying: 30秒で完了）

```go
func getUserName(user *User) string {
    if user != nil {
        return user.Name
    }
    return ""
}
```

```bash
git commit -m "tidy: remove unnecessary else clause in getUserName"
```

### Refactoring の例

#### Before（Refactoring）

```go
// UserServiceが肥大化している
type UserService struct {
    db *gorm.DB
}

func (s *UserService) CreateUser(email, password string) error {
    // バリデーション
    if email == "" { return errors.New("invalid email") }
    // パスワードハッシュ化
    hash, _ := bcrypt.GenerateFromPassword([]byte(password), 10)
    // DB保存
    return s.db.Create(&User{Email: email, Password: hash}).Error
}
```

#### After（Refactoring: 計画的に実施）

```go
// ドメイン層
type User struct {
    email    Email    // 値オブジェクト
    password Password // 値オブジェクト
}

// アプリケーション層
type UserService struct {
    userRepo domain.UserRepository
}

func (s *UserService) CreateUser(email, password string) error {
    user, err := domain.NewUser(email, password) // バリデーションはドメイン層
    if err != nil { return err }
    return s.userRepo.Save(user)
}
```

```bash
git commit -m "refactor: extract user validation to domain layer

Introduce value objects (Email, Password) for validation.
Separate persistence logic to repository pattern.
This improves testability and follows DDD principles."
```

## よくある質問

### Q: 3分かかりそうな改善はどうする？

**A**: Refactoringとして扱い、計画を立ててから実施してください。
2分ルールは厳密ではありませんが、判断基準として有効です。

### Q: Tidying中に大きな問題を発見したら？

**A**: Tidyingを一旦コミットし、大きな問題はRefactoringとして別途取り組んでください。

### Q: TDD中のRefactorステップはどちら？

**A**: TDDのRefactorステップは**Tidyings**に近いです。
テストが通った後の小さな改善を行います。大きな構造変更が必要な場合は、
別途Refactoringとして計画してください。

## Coding Agentとの協働

### Coding Agentに指示する際

**Tidyingsを依頼**:

```text
「この関数の不要なelse句を削除して」
```

**Refactoringを依頼**:

```text
「UserServiceをドメイン層とアプリケーション層に分離して。
計画を立ててから実施してください。」
```

### Coding Agentの判断基準

Coding Agentは以下の基準で自動判断します：

- **2分以内**: その場でTidyingsを実行
- **2分以上**: Refactoringとして計画を提案

ユーザーに確認が必要な場合は、事前に判断基準を説明します。
