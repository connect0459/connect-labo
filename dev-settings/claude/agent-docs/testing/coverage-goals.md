# テストカバレッジ目標設定

## 基本方針

**実装開始前に必ずユーザーとカバレッジ目標を協議し、定量的な指標を設定します。**

カバレッジ目標未達成時は実装完了とみなさず、テスト追加で目標達成を必須とします。

## ヒアリング項目

実装前に以下の項目をユーザーと確認します：

```markdown
## テストカバレッジ目標設定

### プロジェクト情報
- プロジェクト種別: [新規開発/機能追加/リファクタリング/バグ修正]
- 重要度: [高/中/低]
- リスクレベル: [高/中/低]

### カバレッジ目標
- 行カバレッジ目標: ____%
- 分岐カバレッジ目標: ____%
- 関数カバレッジ目標: ____%

### 特別な考慮事項
- 除外対象ファイル: [設定ファイル/自動生成コード等]
- 重点テスト対象: [コアビジネスロジック/セキュリティ関連等]
```

## プロジェクト種別別の推奨カバレッジ

| プロジェクト種別 | 行カバレッジ | 分岐カバレッジ | 関数カバレッジ |
|------------------|--------------|----------------|----------------|
| 新規開発（高重要度） | 90%以上 | 85%以上 | 95%以上 |
| 新規開発（中重要度） | 80%以上 | 75%以上 | 90%以上 |
| 機能追加 | 85%以上 | 80%以上 | 90%以上 |
| リファクタリング | 95%以上 | 90%以上 | 98%以上 |
| バグ修正 | 100% | 100% | 100% |

## カバレッジの種類

### 行カバレッジ（Line Coverage）

**定義**: 実行された行数の割合

```go
func Calculate(x int) int {
    if x > 0 {        // ← この行は実行された
        return x * 2  // ← この行は実行された
    }
    return 0          // ← この行は実行されなかった（50%カバレッジ）
}
```

### 分岐カバレッジ（Branch Coverage）

**定義**: すべての条件分岐（true/false）が実行された割合

```go
func Validate(x int) bool {
    if x > 0 && x < 100 {  // true/false両方のパターンをテスト
        return true
    }
    return false
}
```

### 関数カバレッジ（Function Coverage）

**定義**: 実行された関数の割合

```go
func Add(a, b int) int { return a + b }      // ← テストで実行された
func Subtract(a, b int) int { return a - b } // ← テストで実行されなかった（50%カバレッジ）
```

## カバレッジ測定コマンド

### Go

```bash
# カバレッジを測定して結果を表示
go test -cover ./...

# 詳細なカバレッジレポート生成
go test -coverprofile=coverage.out ./...
go tool cover -html=coverage.out -o coverage.html
```

### TypeScript (Vitest)

```bash
# vitest.config.tsにcoverageの設定を追加
vitest --coverage
```

```typescript
// vitest.config.ts
export default defineConfig({
  test: {
    coverage: {
      provider: 'v8',
      reporter: ['text', 'html'],
      statements: 80,
      branches: 75,
      functions: 90,
      lines: 80,
    },
  },
})
```

### Rust

```bash
# cargo-tarpaulinのインストール
cargo install cargo-tarpaulin

# カバレッジ測定
cargo tarpaulin --out Html
```

### PHP (PHPUnit)

```bash
# カバレッジ測定（Xdebugが必要）
phpunit --coverage-html coverage
```

## 除外対象の例

以下のファイルはカバレッジ測定から除外することを検討：

- **設定ファイル**: `config.go`, `settings.ts`
- **自動生成コード**: `*.pb.go`, `*.generated.ts`
- **メインエントリポイント**: `main.go`, `index.ts`
- **モックコード**: `*_mock.go`, `*.mock.ts`

### Go: 除外設定例

```go
// コメントで除外
//go:coverage ignore
func GeneratedCode() {
    // ...
}
```

### TypeScript (Vitest): 除外設定例

```typescript
// vitest.config.ts
export default defineConfig({
  test: {
    coverage: {
      exclude: [
        '**/*.config.ts',
        '**/*.d.ts',
        '**/dist/**',
        '**/node_modules/**',
      ],
    },
  },
})
```

## 重点テスト対象

カバレッジ100%を目指すべき箇所：

- **コアビジネスロジック**: ドメイン層のロジック
- **セキュリティ関連**: 認証・認可のロジック
- **金額計算**: 決済・課金のロジック
- **データ整合性**: トランザクション処理

## カバレッジの限界

カバレッジ100%でも、以下は保証されません：

- ビジネスロジックの正しさ
- エッジケースの網羅
- 実装の品質

**カバレッジは品質の必要条件であって、十分条件ではありません。**

Evergreenテストの原則に従い、ビジネスルールと振る舞いに焦点を当てたテストを書くことが重要です。
