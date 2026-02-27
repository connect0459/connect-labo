# コミットメッセージ規約

## 基本方針

- **フォーマット**: 日本語 + Conventional Commits準拠
- **エンコーディング**: UTF-8のみ（必須）
- **OSS開発**: 英語推奨（ユーザーに確認）

## Conventional Commits

### フォーマット

```text
<type>: <subject>

<body>

<footer>
```

### Type（種類）

| Type | 説明 | 例 |
| :--- | :--- | :--- |
| `feat` | 新機能 | `feat: ユーザー登録機能を追加` |
| `fix` | バグ修正 | `fix: ログイン時のバリデーションエラーを修正` |
| `docs` | ドキュメント | `docs: READMEにセットアップ手順を追加` |
| `style` | コードスタイル | `style: インデントを修正` |
| `refactor` | リファクタリング | `refactor: ユーザーサービスをドメイン層に移動` |
| `tidy` | 整理整頓（Tidyings） | `tidy: 不要なelse句を削除` |
| `test` | テスト | `test: ユーザー作成のテストを追加` |
| `chore` | その他 | `chore: 依存関係を更新` |

### Subject（件名）

- **50文字以内**: 簡潔に
- **命令形**: 「追加する」ではなく「追加」
- **句読点不要**: 末尾にピリオドをつけない

### Body（本文）

- **72文字で改行**: 読みやすさのため
- **WHYを記述**: 何を変更したかではなく、なぜ変更したか
- **省略可**: 件名で十分な場合は不要

### Footer（フッター）

- **Breaking Changes**: `BREAKING CHANGE:` で始める
- **Issue参照**: `Closes #123`, `Fixes #456`

## 実践例

### 良い例

```text
feat: ユーザー登録時のメールアドレス検証を追加

重複登録を防ぐため、メールアドレスの一意性チェックを実装。
既存のユーザーと同じメールアドレスでの登録を防止します。

Closes #42
```

```text
fix: 注文金額計算時の消費税の丸め誤差を修正

Math.round()からBigDecimalに変更し、金額計算の精度を向上。
これにより、1円単位での誤差が発生しなくなります。

Fixes #78
```

```text
tidy: UserService内の不要な変数を削除

使用されていないtempUser変数を削除。
```

### 避けるべき例

```text
feat: いろいろ修正

（何を修正したか不明）
```

```text
fix: bug fix

（どのバグを修正したか不明）
```

```text
update: コードを更新

（typeが不適切、内容が不明確）
```

## TDD時のコミット戦略

### Red-Green-Refactorでコミット分離

```bash
# Red: テスト追加
git commit -m "test: ユーザー登録時のメールアドレス検証テストを追加"

# Green: 最小実装
git commit -m "feat: メールアドレス検証を実装"

# Refactor: リファクタリング
git commit -m "refactor: メールアドレス検証ロジックをドメイン層に移動"
```

### Tidyings vs Refactoring

詳細は `agent-docs/conventions/tidyings-vs-refactoring.md` を参照してください。

```bash
# Tidyings（2分以内の小さな改善）
git commit -m "tidy: remove unnecessary else clause in getUserName"

# Refactoring（計画的な大きな変更）
git commit -m "refactor: extract user validation logic to domain service"
```

## UTF-8エンコーディング検証

冒頭で述べたとおり、本プロジェクトではコミットメッセージのエンコーディングをUTF-8に統一します。
特に複数のコーディングエージェント（人間・AIツールなど）が協働する環境では、文字化けや解析エラーを防ぐために、UTF-8であることを機械的に検証しておくことが重要です。
コミットメッセージは必ずUTF-8エンコーディングで記述する必要があります。

## OSS開発時の考慮事項

OSSプロジェクトでは、国際的なコミュニティのため英語でのコミットメッセージが推奨されます。

### 英語版の例

```text
feat: add email validation for user registration

Implement uniqueness check for email addresses to prevent duplicate registrations.
This ensures that users cannot register with an existing email address.

Closes #42
```

**重要**: OSS開発を開始する際は、ユーザーに英語でのコミットメッセージに切り替えるか確認してください。
