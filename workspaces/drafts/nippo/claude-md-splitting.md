# 【日報】2025-12-11

## CLAUDE.mdの分割戦略

先日、AnthropicからCLAUDE.mdを細かいrulesファイルに分割する方法が提案された（[Manage Claude's memory](https://code.claude.com/docs/en/memory#modular-rules-with-claude/rules/)）。一方で、HumanLayerからも [Writing a good CLAUDE.md](https://www.humanlayer.dev/blog/writing-a-good-claude-md) というCLAUDE.mdのベストプラクティスが公開され、こちらでもCLAUDE.mdの分割が推奨されている。これらは一見同じもののように見えたが、両者を比較してみると異なる特性を持っていることがわかったので、両者の主張とその違いを簡潔にまとめる。

### 主な相違点

#### ファイルの長さと内容量

公式ドキュメントでは、ファイル長に関する具体的な制限は言及されていない。「具体的に書く」「構造化する」「定期的にレビューする」といったベストプラクティスが挙げられているが、上限についての指針はない。

HumanLayerは厳格な制限を推奨している。300行以下が望ましく、HumanLayer社の実例は60行未満だそう。この背景として、研究論文を引用しており、LLMは約150-200個の指示にしか安定して従えないとのこと。

さらに、Claude Codeのシステムプロンプト自体に約50個の指示が含まれているとの分析結果を示している。つまり、残りの100-150個の指示枠をCLAUDE.mdで使い切ってしまうと、Claude自体のパフォーマンスが低下するという主張を展開している。

#### Claudeが無視する可能性

公式ドキュメントでは、この点について言及がない。一方、HumanLayerの記事には、Claude CodeがCLAUDE.mdを注入する際に以下のようなシステムリマインダーを付与しているとの記述がある。

```text
<system-reminder>
      IMPORTANT: this context may or may not be relevant to your tasks.
      You should not respond to this context unless it is highly relevant to your task.
</system-reminder>
```

この記述は、HumanLayerが `ANTHROPIC_BASE_URL` を用いたロギングプロキシで調査した結果として記載されている。つまり、CLAUDE.mdの内容がタスクに関連性が低いと判断された場合、Claudeは意図的に無視する可能性があるということだそうだ。自分はこの調査を再現するまで追えていないので、気になる人は検証してみてほしい。

#### 何を書くべきか

公式ドキュメントでは以下のような抽象的な説明にとどまっている。

- よく使うコマンド（build, test, lint）
- コードスタイルと命名規則
- プロジェクト固有のアーキテクチャパターン

一方、HumanLayerは記述形式のフレームワークを提示している。

- WHAT: 技術スタック、プロジェクト構造、コードマップ
- WHY: プロジェクトの目的、各部分の役割
- HOW: 作業方法（例：bunを使うか、テストの実行方法など）

このフレームワークによって、WHATだけでなくWHYも含めることで、Claudeが単なるコード生成器ではなく、プロジェクトの意図を理解した協力者として機能しやすくなる、とされている。

### `.claude/rules/` と `agent_docs/` の比較

`.claude/rules/` はClaude Code公式が提供する機能で、起動時に全て自動読み込みされる。一方、 `agent_docs/` はHumanLayerが提案するベストプラクティスで、Claudeに読むよう指示することで手動で読み込ませる方式だ。

| 項目 | `.claude/rules/` | `agent_docs/` |
| :---- | :---- | :---- |
| 提供元 | Claude Code公式 | HumanLayerのベストプラクティス提案 |
| 読み込みタイミング | 自動（起動時に全て読み込み） | 手動（Claudeに読むよう指示） |
| 目的 | モジュール化されたルール管理 | Progressive Disclosure（段階的開示） |

#### `.claude/rules/` の仕組み

公式ドキュメントによると、 `.claude/rules/` ディレクトリは大規模プロジェクト向けのモジュール化機能であるとされている。

```text
your-project/
├── .claude/
│   ├── CLAUDE.md
│   └── rules/
│       ├── code-style.md
│       ├── testing.md
│       └── security.md
```

`rules/` 内の全 `.md` ファイルは起動時に自動的に読み込まれ、 `CLAUDE.md` と同じ優先度でプロジェクトメモリとして扱われる。symlinkによる複数プロジェクト間での共有もサポートしており、ユーザーレベルのルール（`~/.claude/rules/`）も設定可能とのこと。

#### `agent_docs/` の仕組み

HumanLayerが提案する `agent_docs/` は、自動読み込みを避け、必要なときだけ情報を参照させるアプローチである。

```text
agent_docs/
├── building_the_project.md
├── running_tests.md
├── code_conventions.md
├── database_schema.md
└── service_architecture.md
```

CLAUDE.mdには、これらのファイルの存在と概要のみを記載し、Claudeが必要と判断したときに読み込ませる。HumanLayerが「コピーよりポインタを優先せよ」（"Prefer pointers to copies"）と述べているのは、必要なときに辿れる参照を予め渡しておけ、ということだと思われる。

`.claude/rules/` はファイルの整理には役立つが、全て自動読み込みされる点では `CLAUDE.md` に直接書くのとコンテキストウィンドウへの影響は本質的に同じと捉えることもできる。一方、 `agent_docs/` 方式はコンテキストウィンドウの節約を目的としており、タスクに関連する情報のみを動的に読み込ませることで、指示数の増加を抑えることを狙っている。

### まとめ

セキュリティポリシーや命名規則、チーム内の共通ルールなどは常に適用すべき情報のため、 `.claude/rules/` でドキュメントを分割して情報を整理する。コンテキストウィンドウの最小化や、DBスキーマやアーキテクチャなどの特定タスクでのみ必要な情報は `agent_docs` 方式で独自に分けると良いと思われる。

両者を併用することも可能なので、以下のような構成で運用してみても良いかも知れない。

```text
your-project/
├── .claude/
│   ├── CLAUDE.md          # 最小限の常時適用ルール + agent_docs/へのポインタ
│   └── rules/
│       └── security.md    # 常に適用すべきセキュリティルール
├── agent_docs/            # 必要なときだけ参照する詳細ドキュメント
│   ├── database_schema.md
│   ├── api_conventions.md
│   └── deployment.md
```
