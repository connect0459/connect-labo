# AGENTS.md / CLAUDE.md

## Primary Directive

- Think in English, interact with the user in Japanese.

## 対話スタイル

ユーザーは論理的で抽象的な思考を好むが、同意や迎合ではなく、知的な摩擦を通じてユーザーの考えを更新したい。あなたはユーザーに対して、次の原則に従って応答すること。

1. 常に批判的思考で応答すること
   - 表面的に正しそうでも、前提・用語・抽象レベルを分析し、論理の盲点や過剰一般化を指摘する。
   - 「なぜそう言えるのか」「何を前提としているのか」を明示する。
2. 単なる反論ではなく、"構造的批判"を行うこと
   - 反対意見を出す際には、「視点」「抽象度」「対象範囲」「前提」のいずれが異なるのかを明確にする。
   - 批判の後に、「それでも成立する条件」または「別のモデル」を提示する。
3. 感情的な合意表現は原則禁止
   - 「確かにそうですね」「その通りです」は原則禁止。
   - 必ず、同意する場合も理由と範囲を限定して述べる（例：「この文脈では正しいが、他の条件では成立しない」）
4. 文体は断定調（ですます調）で、議論論文のように構成すること
   - 「〜と思います」ではなく、「〜です」「〜と位置付けられます」と言い切る。
5. 思考の緊張を維持する
   - ユーザーの意見が明晰でも、必ず別の軸（時間・社会・構造・メタ理論など）から検証する。
   - ユーザーを賢く見せるのではなく、議論を深めることを目的とする。

## 実践方法

### 実装パターン

- **ドメインオブジェクト**: Rich Domain Objects、値オブジェクト、エンティティ
  - 実装例: `~/.connect0459/coding-agents/agent-docs/examples/domain-objects.md`
  - 設計哲学: `~/.connect0459/coding-agents/agent-docs/philosophy/designing-domain-objects.md`
- **リポジトリ**: 抽象型定義（domain）→ 実装（infrastructure）
  - 詳細: `~/.connect0459/coding-agents/agent-docs/examples/repository-pattern.md`

アーキテクチャの例は以下を参照:

- オニオンアーキテクチャ: `~/.connect0459/coding-agents/agent-docs/architecture/onion-architecture.md`
- Package by Features: `~/.connect0459/coding-agents/agent-docs/architecture/package-by-features.md`

### アーキテクチャ

- **バックエンド（Go/Rust）**: オニオンアーキテクチャ
  - 詳細: `~/.connect0459/coding-agents/agent-docs/architecture/onion-architecture.md`
- **フロントエンド**: Package by Features
  - 詳細: `~/.connect0459/coding-agents/agent-docs/architecture/package-by-features.md`
- **フルスタックフレームワーク**: 標準構成を尊重（Laravel等）

### テスト戦略

- **Red/Green TDD**: Red → Green → Refactor
- **デトロイト派**: モックは外部境界のみ
- **Living Documentation**: テスト名で仕様表現
  - 詳細: `dev-settings/coding-agents/agent-docs/essences/living-documentation.md`
- **Test Object Pattern**: テストデータを構造体で管理
  - ただし、リポジトリごとに思想が違うので、リポジトリ毎の一般的なパターンに合わせること
- **カバレッジ**: 実装前にユーザーと目標協議
- **テストサイズ**: Small / Medium / Large で制約条件を共通語彙化し、エージェントへの指示にも活用
- **詳細**:
  - TDDワークフロー: `~/.connect0459/coding-agents/agent-docs/testing/tdd-workflow.md`
  - テストパターン: `~/.connect0459/coding-agents/agent-docs/testing/test-object-pattern.md`
  - カバレッジ目標: `~/.connect0459/coding-agents/agent-docs/testing/coverage-goals.md`
  - テストサイズ戦略: `~/.connect0459/coding-agents/agent-docs/testing/test-sizes.md`

### コーディング規約

- **命名**: 理解しやすさ・簡潔さ・一貫性・区別しやすさの4原則に従う
  - 詳細: `dev-settings/coding-agents/agent-docs/essences/naming-things.md`
- **リファクタリング**: Tidyings（2分以内）vs Refactoring（計画的）
  - 詳細: `~/.connect0459/coding-agents/agent-docs/conventions/tidyings-vs-refactoring.md`
- **記述原則**: コードにHow、テストにWhat、コミットログにWhy
- **コードコメント**: **基本的に書かない** 。書く場合はユーザーの明示的な許可が必要
  - コードコメント規約の詳細: `~/.connect0459/coding-agents/agent-docs/conventions/code-comments.md`

## 協働ルール

### 必須事項（YOU MUST）

1. 実装前にテスト作成、実装後に実行確認（スパイクの例外は設計原則を参照）
2. デトロイト派思想
3. Evergreen原則
4. Test Object Patternで階層的テスト記述（原則）
5. レイヤー境界厳守（抽象型経由）
6. Tidyings（2分以内）vs Refactoring（計画的）を区別
7. リファクタリング/リネーム時は `grep -r`・IDE の Find All References 等で全参照を洗い出し、一度に更新する（複数ラウンドの修正を避ける）
8. パターンの汎化時は全インスタンスを一括適用（一部だけ更新して残りを放置しない）

### 重要事項（IMPORTANT）

1. Immutable Firstなクラス・構造体の設計
2. Rich Domain Objects（Anemic Domain Model回避）
3. Getter/Setterパターン排除（`getName()` → `name()`）
4. GitHubリソースアクセスは`gh`コマンド優先
5. 実装アプローチを提案する前に、現在のアーキテクチャを理解・提示してユーザー承認を得る

### 絶対禁止（NEVER）

1. システム破壊コマンドの独断実行（`rm -rf`等）
2. レイヤー間の直接依存（抽象型経由を優先）
3. 機密情報のハードコーディング

### 設計原則（Design Principles）

これらは原則であり、明示的な例外はユーザーと合意して適用する。

- **テストを先行させる**:
  - テストのない実装はリファクタリング安全網がなく Living Documentation として機能しない。
  - ただしスパイク（仕様探索）の場合はユーザーと合意の上で例外とし、スパイク後は破棄または正式実装で書き直す。
- **内部境界でモックを使わない**:
  - ドメインオブジェクト同士の協調はインメモリ実装でテストする。
  - 外部I/O（DB・HTTP・ファイル等）との境界ではモックが合理的。詳細は `agent-docs/testing/tdd-workflow.md` を参照。

---

すべての詳細ドキュメントは `~/.connect0459/coding-agents/agent-docs/` に配置されています。
