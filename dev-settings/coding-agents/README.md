# README - Coding Agents

このディレクトリには、Claude Codeやその他コーディングエージェントの開発規約とガイドラインが含まれています。

## Sync to Global Configuration

You can copy the configuration from this repository to `~/.connect0459/coding-agents/` and set up symlinks for Claude and GitHub Copilot to use it across all projects.

### Usage

```bash
cd dev-settings/coding-agents/sync-cmd && go build -o main && ./main
```

### Synchronized Files

Central location (`~/.connect0459/coding-agents/`):

- `AGENTS.md` (physical copy)
- `agent-docs/**` (physical copy)

Symlinks to central location:

- `~/.claude/CLAUDE.md` → `~/.connect0459/coding-agents/AGENTS.md`
- `~/.github/copilot-instructions.md` → `~/.connect0459/coding-agents/AGENTS.md`

Settings (physical copy):

- `claude/settings.json` (permissions only) → `~/.claude/settings.json`

**Note**: Only the `permissions` field from `settings.json` is synchronized. Other settings remain untouched.

**Requirements**: Python 3 is required for this script.

## 設定の優先順位

以下の優先順位で設定を読み込みます：

1. プロジェクトローカル: `<project>/dev-settings/coding-agents/AGENTS.md`
2. グローバル: `~/.claude/CLAUDE.md` (→ `~/.connect0459/coding-agents/AGENTS.md`)

プロジェクト固有の設定を追加したい場合は、このディレクトリを各プロジェクトにコピーしてカスタマイズできます。

## 開発哲学

このプロジェクトは以下の哲学に基づいています：

- **TDD重視**: デトロイト派（モック最小化、実際のオブジェクト協調）
- **Evergreen原則**: 長期的価値（WHY > WHAT、ビジネスルール重視）
- **Rich Domain Objects**: データ + ロジック、getter/setter排除
- **品質 > 速度**: 持続可能性と保守性を優先

詳細は`AGENTS.md`を参照してください。
