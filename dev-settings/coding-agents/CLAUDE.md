# CLAUDE.md

## Primary Directive

- Think in English, interact with the user in Japanese.

## 技術スタック

### 主要言語とフレームワーク

- **フロントエンド**: TypeScript (React, Astro, Qwik)
- **バックエンド**: Go (net/http, Echo), PHP (Laravel, Slim Framework), Rust
- **補助言語**: Python (uv)
- **データベース**: MySQL, PostgreSQL, SQLite
- **ツール**: Docker, npm (nvmでNode.js管理), Vite, Vitest, Playwright

### パッケージ管理

- JavaScript/TypeScript: npm
- Python: uv
- Rust: cargo
- PHP: composer

## 開発哲学

- **TDD重視**: デトロイト派（モック最小化、実際のオブジェクト協調）
- **Evergreen原則**: 長期的価値（WHY > WHAT、ビジネスルール重視）
- **Rich Domain Objects**: データ + ロジック、getter/setter排除
- **品質 > 速度**: 持続可能性と保守性を優先

## 実践方法

### アーキテクチャ

- **バックエンド（Go/Rust）**: オニオンアーキテクチャ
  - レイヤー境界厳守、依存性逆転の原則
  - 詳細: `~/.claude/agent-docs/architecture/onion-architecture.md`
- **フロントエンド**: Package by Features
  - 機能ごとにコード凝集
  - 詳細: `~/.claude/agent-docs/architecture/package-by-features.md`
- **フルスタックフレームワーク**: 標準構成を尊重（Laravel等）

### テスト戦略

- **TDDワークフロー**: Red → Green → Refactor
- **デトロイト派**: モックは外部境界のみ、内部は実際のインスタンス
- **Living Documentation**: 日本語テスト名で仕様表現
- **Test Object Pattern**: テストデータを構造体で管理
- **カバレッジ**: 実装前にユーザーと目標協議
- **詳細**:
  - TDDワークフロー: `~/.claude/agent-docs/testing/tdd-workflow.md`
  - テストパターン: `~/.claude/agent-docs/testing/test-object-pattern.md`
  - カバレッジ目標: `~/.claude/agent-docs/testing/coverage-goals.md`

### コーディング規約

- **コミット**: 日本語 + Conventional Commits（UTF-8必須）
  - 詳細: `~/.claude/agent-docs/conventions/commit-messages.md`
- **リファクタリング**: Tidyings（2分以内）vs Refactoring（計画的）
  - 詳細: `~/.claude/agent-docs/conventions/tidyings-vs-refactoring.md`
- **Git Hooks**: UTF-8検証、コードフォーマット
  - 詳細: `~/.claude/agent-docs/conventions/git-hooks.md`
- **エラーメッセージ**: 英語で統一
- **ドキュメント**: TSDoc/Godocで関数・クラス説明（日本語）
- **記述原則**: コードにHow、テストにWhat、コミットログにWhy
- **コードコメント**: **基本的に書かない** 。書く場合はユーザーの明示的な許可が必要
  - コードコメント規約の詳細: `~/.claude/agent-docs/conventions/code-comments.md`

### 実装パターン

- **ドメインオブジェクト**: Rich Domain Objects、値オブジェクト、エンティティ
  - 詳細: `~/.claude/agent-docs/examples/domain-objects.md`
- **リポジトリ**: 抽象型定義（domain）→ 実装（infrastructure）
  - 詳細: `~/.claude/agent-docs/examples/repository-pattern.md`

## Claude Code協働ルール

### 必須事項（YOU MUST）

1. 実装前にテスト作成、実装後に実行確認
2. デトロイト派思想（モックは外部境界のみ）
3. Evergreen原則（ビジネスルール重視、WHY記述）
4. Test Object Patternで階層的テスト記述（原則）
5. レイヤー境界厳守（抽象型経由）
6. カバレッジ目標を実装前に協議
7. Tidyings（2分以内）vs Refactoring（計画的）を区別
8. リファクタリング/リネーム時は全参照を一度に完全監査（複数回の修正ラウンドを避ける）
9. パターンの汎化時は全インスタンスを一括適用（一部だけ更新して残りを放置しない）

### 重要事項（IMPORTANT）

1. ビジネスロジックの実装前にユーザーと方針を擦り合わせ
2. Rich Domain Objects（Anemic Domain Model回避）
3. Getter/setterパターン排除（`getName()` → `name()`）
4. カバレッジ目標未達成時は実装完了とみなさない
5. GitHubリソースアクセスは`gh`コマンド優先
6. デバッグ時は静的解析を優先（debug loggingの追加は最終手段）
7. コードレビュー時、意図的な設計判断をバグとしてフラグしない（不明な場合は質問する）
8. 実装アプローチを提案する前に、現在のアーキテクチャを理解・提示してユーザー承認を得る

### 絶対禁止（NEVER）

1. テストなしでの実装
2. システム破壊コマンドの独断実行（`rm -rf`等）
3. 外部システム以外でのモック使用
4. レイヤー間の直接依存（必ず抽象型経由）
5. 機密情報のハードコーディング

## ワークフロー別ガイドライン

### コードレビュー

- 詳細: `dev-settings/claude/agent-docs/workflows/code-review-guidelines.md`
- レビュー時は明示的な指示がない限りテストを実行しない
- 不自然に見えるコードは、バグと判断する前に意図を確認
- PR説明作成時は既存PRのスタイルを参照

### リファクタリング

- 詳細: `dev-settings/claude/agent-docs/workflows/refactoring-checklist.md`
- 実装前に変更対象の完全なチェックリストを作成し承認を得る
- imports、component名、test、Storybook、型定義など全参照を一度に更新
- 命名規則は既存コードベースのパターンに従う

### デバッグ

- 詳細: `dev-settings/claude/agent-docs/workflows/debugging-workflow.md`
- コード変更前にファイル読み込みとロジックトレースで静的解析
- 複数レイヤーにまたがる問題は調査→診断→アプローチ提示→承認→実装の順

### PR作成

- 詳細: `dev-settings/claude/agent-docs/workflows/pr-description-style.md`
- 既存のマージ済みPRを参照してスタイルを把握
- ユーザー固有のフォーマット規則（太字、装飾、構造）を尊重

---

**品質 > 速度** の哲学で、持続可能で保守性の高いコードを一緒に作りましょう！

すべての詳細ドキュメントは `dev-settings/claude/agent-docs/` に配置されています。

**注**: このリポジトリのagent-docsはgit管理され、複数のPC間で共有されます。
