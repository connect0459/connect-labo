# TDD ワークフロー（t_wada流）

## 基本原則

### Red-Green-Refactor サイクル

1. **Red**: 失敗するテストを書く
2. **Green**: テストを通す最小限の実装
3. **Refactor**: リファクタリング

### TDDの心得

- **小さなステップで進める**: 一度に多くを実装しない
- **仮実装（ベタ書き）から始める**: まず動くコードを書く
- **三角測量で一般化する**: 複数のテストケースから共通ロジックを抽出
- **明白な実装が分かる場合は直接実装してもOK**: 自信がある場合は仮実装をスキップ可
- **テストリストを常に更新する**: 思いついたテストケースをメモ
- **不安なところからテストを書く**: 最もリスクの高い部分から始める

## TODOリスト駆動開発

### TODOリストの作成

実装前に、必要なテストケースをリストアップします。

```markdown
## User登録機能 TODO

- [ ] 有効なメールアドレスでユーザー登録できる
- [ ] 無効なメールアドレスの場合はエラー
- [ ] 空のメールアドレスの場合はエラー
- [ ] 重複したメールアドレスの場合はエラー
- [ ] パスワードが8文字未満の場合はエラー
- [ ] パスワードが8文字以上の場合は登録できる
```

### TODOの優先順位

1. **ハッピーパス**: 正常系のテストから始める
2. **エッジケース**: 境界値のテスト
3. **異常系**: エラーケースのテスト

## 実践例：仮実装 → 三角測量 → 本実装

### Step 1: Red - 失敗するテストを書く

```go
func TestUserService(t *testing.T) {
    t.Run("有効なメールアドレスでユーザー登録できる", func(t *testing.T) {
        service := NewUserService()
        user, err := service.Register("test@example.com", "password123")

        if err != nil {
            t.Errorf("エラーが発生しました: %v", err)
        }
        if user.Email != "test@example.com" {
            t.Errorf("メールアドレスが一致しません")
        }
    })
}
```

### Step 2: Green - 仮実装（ベタ書き）

```go
func (s *UserService) Register(email, password string) (*User, error) {
    // まずはベタ書きで通す
    return &User{Email: "test@example.com"}, nil
}
```

### Step 3: Red - 2つ目のテストを追加（三角測量）

```go
t.Run("別のメールアドレスでもユーザー登録できる", func(t *testing.T) {
    service := NewUserService()
    user, err := service.Register("another@example.com", "password123")

    if err != nil {
        t.Errorf("エラーが発生しました: %v", err)
    }
    if user.Email != "another@example.com" {
        t.Errorf("メールアドレスが一致しません")
    }
})
```

### Step 4: Green - 本実装

```go
func (s *UserService) Register(email, password string) (*User, error) {
    // 三角測量により一般化
    return &User{Email: email}, nil
}
```

### Step 5: Refactor - リファクタリング

テストが通った状態で、コードの品質を向上させます。

## テストの優先度

```text
ユニットテスト > 結合テスト > E2Eテスト
```

### ユニットテスト

- **対象**: 単一の関数・メソッド
- **依存**: 外部依存を最小化（デトロイト派）
- **速度**: 高速（ミリ秒単位）

### 結合テスト

- **対象**: 複数のコンポーネントの協調
- **依存**: 実際のDBやファイルシステム（可能な限り）
- **速度**: 中速（秒単位）

### E2Eテスト

- **対象**: システム全体の動作
- **依存**: 実際の環境
- **速度**: 低速（分単位）

## デトロイト派のテスト哲学

### 基本方針

- **モックの使用は極力避ける**: 実際のオブジェクトとの協調を重視
- **モック使用判断**: 外部システム（API、ファイルI/O、ネットワーク）との境界でのみ使用
- **内部協調**: ドメインオブジェクト同士の協調は実際のインスタンスでテスト
- **テスト対象**: 行動（behavior）をテストし、実装の詳細ではなく結果を検証

### 例：モックを使わないテスト

```go
// Good: 実際のインメモリリポジトリを使用
func TestUserService(t *testing.T) {
    userRepo := memory.NewUserRepository() // 実装
    service := NewUserService(userRepo)

    user, err := service.CreateUser("太郎")
    // ...
}
```

```go
// Bad: 不必要なモック（外部システムではない）
func TestUserService(t *testing.T) {
    mockRepo := &MockUserRepository{} // モック
    service := NewUserService(mockRepo)
    // ...
}
```

## Evergreenテストの原則

テストは時間が経っても価値を保ち続ける内容に焦点を当てる。
詳細は `agent_docs/testing/evergreen-principles.md` を参照してください。

### Evergreenの基本原則

- **実装詳細ではなく振る舞いをテスト**: 内部実装が変わってもテストが壊れない
- **ビジネスルールに焦点**: 技術的な詳細ではなく、ビジネス上重要な振る舞いをテスト
- **仕様を表現**: テストコードそのものが仕様書として機能
- **不変の要件を優先**: 長期的に変わらないビジネスルールを優先

## カバレッジ目標

実装開始前に必ずユーザーとカバレッジ目標を協議し、定量的な指標を設定します。
詳細は `agent_docs/testing/coverage-goals.md` を参照してください。

## 構造化テスト設計

詳細は `agent_docs/testing/test-object-pattern.md` を参照してください。
