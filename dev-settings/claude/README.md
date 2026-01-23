# Claude設定ファイル

このディレクトリには、Claude Codeの開発規約とガイドラインが含まれています。

## ファイル構成

```text
dev-settings/claude/
├── CLAUDE.md                            # メイン設定ファイル
├── agent-docs/                          # 詳細ドキュメント
│   ├── architecture/                    # アーキテクチャガイド
│   │   ├── onion-architecture.md
│   │   └── package-by-features.md
│   ├── conventions/                     # コーディング規約
│   │   ├── code-comments.md
│   │   ├── commit-messages.md
│   │   ├── git-hooks.md
│   │   └── tidyings-vs-refactoring.md
│   ├── examples/                        # 実装パターン例
│   │   ├── domain-objects.md
│   │   └── repository-pattern.md
│   └── testing/                         # テスト戦略
│       ├── coverage-goals.md
│       ├── tdd-workflow.md
│       └── test-object-pattern.md
├── human-like-writing-style-guide.md    # 文章スタイルガイド
├── prompts.md                           # プロンプト集
├── settings.json                        # Claude Code設定
├── sync-to-global.sh                    # グローバル同期スクリプト
└── README.md                            # このファイル
```

## Sync to Global Configuration

You can copy the configuration from this repository to `~/.claude/` to use it across all projects.

### Usage

```bash
# Run from repository root
./dev-settings/claude/sync-to-global.sh

# Or run from claude directory
cd dev-settings/claude
./sync-to-global.sh
```

### Synchronized Files

- `CLAUDE.md` → `~/.claude/CLAUDE.md`
- `agent-docs/**` → `~/.claude/agent-docs/**`
- `settings.json` (permissions only) → `~/.claude/settings.json`

**Note**: Only the `permissions` field from `settings.json` is synchronized. Other settings remain untouched.

**Requirements**: The `jq` command is required to sync permissions. Install with `brew install jq` if not available.

## 設定の優先順位

Claude Codeは以下の優先順位で設定を読み込みます：

1. プロジェクトローカル: `<project>/dev-settings/claude/CLAUDE.md`
2. グローバル: `~/.claude/CLAUDE.md`

プロジェクト固有の設定を追加したい場合は、このディレクトリを各プロジェクトにコピーしてカスタマイズできます。

## 開発哲学

このプロジェクトは以下の哲学に基づいています：

- **TDD重視**: デトロイト派（モック最小化、実際のオブジェクト協調）
- **Evergreen原則**: 長期的価値（WHY > WHAT、ビジネスルール重視）
- **Rich Domain Objects**: データ + ロジック、getter/setter排除
- **品質 > 速度**: 持続可能性と保守性を優先

詳細は`CLAUDE.md`を参照してください。
