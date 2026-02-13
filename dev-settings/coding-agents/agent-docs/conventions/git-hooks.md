# Git Hooks 推奨設定

## 概要

Git Hooksを使用してコミットメッセージのUTF-8エンコーディングを自動検証します。
これにより、日本語を含むConventional Commitsメッセージの品質を保証します。

## コミットメッセージのUTF-8検証

### 必要性

コミットメッセージは必ずUTF-8エンコーディングで記述する必要があります。
これを自動的に検証するため、`commit-msg`フックの設定を推奨します。

### セットアップ手順

#### 1. フックファイルの作成

```bash
touch .git/hooks/commit-msg
chmod +x .git/hooks/commit-msg
```

#### 2. フック内容の記述

`.git/hooks/commit-msg`に以下を記述：

```bash
#!/bin/sh
# UTF-8エンコーディング検証フック

commit_msg_file=$1

if ! iconv -f UTF-8 -t UTF-8 "$commit_msg_file" > /dev/null 2>&1; then
    echo "Error: Commit messages must be in UTF-8 encoding"
    exit 1
fi
```

#### 3. 動作確認

```bash
# 正常なコミット（UTF-8）
git commit -m "feat: ユーザー登録機能を追加"
# → 成功

# 異常なコミット（非UTF-8）
# → エラーが表示され、コミットが拒否される
```

## その他の推奨フック

### pre-commit: コードフォーマット自動実行

```bash
#!/bin/sh
# pre-commit: コードフォーマット自動実行

# Go
if git diff --cached --name-only | grep -q '\.go$'; then
    go fmt ./...
    git add -u
fi

# TypeScript
if git diff --cached --name-only | grep -q '\.\(ts\|tsx\)$'; then
    npm run format
    git add -u
fi

# Rust
if git diff --cached --name-only | grep -q '\.rs$'; then
    cargo fmt
    git add -u
fi
```

### prepare-commit-msg: テンプレート挿入

```bash
#!/bin/sh
# prepare-commit-msg: Conventional Commitsテンプレート

commit_msg_file=$1
commit_source=$2

# メッセージが空の場合のみテンプレートを挿入
if [ -z "$commit_source" ]; then
    cat > "$commit_msg_file" << 'EOF'
# <type>: <subject>
#
# <body>
#
# Types: feat, fix, docs, style, refactor, tidy, test, chore
# Subject: 50文字以内、命令形、句読点不要
# Body: 72文字で改行、WHYを記述
EOF
fi
```

## チーム開発での共有

### 注意事項

- `.git/hooks`はリポジトリに含まれません（ローカル環境のみ）
- チーム開発の場合は、READMEやセットアップドキュメントに設定手順を記載

### 共有方法の例

#### 1. スクリプトで自動セットアップ

```bash
# scripts/setup-hooks.sh
#!/bin/bash

# commit-msg フックをセットアップ
cat > .git/hooks/commit-msg << 'EOF'
#!/bin/sh
commit_msg_file=$1
if ! iconv -f UTF-8 -t UTF-8 "$commit_msg_file" > /dev/null 2>&1; then
    echo "Error: Commit messages must be in UTF-8 encoding"
    exit 1
fi
EOF

chmod +x .git/hooks/commit-msg

echo "Git hooks setup complete!"
```

```bash
# 実行
./scripts/setup-hooks.sh
```

#### 2. README.mdに手順を記載

```markdown
## セットアップ

### Git Hooks設定

コミットメッセージの品質を保つため、以下のコマンドでGit Hooksを設定してください：

\`\`\`bash
./scripts/setup-hooks.sh
\`\`\`
```

## Husky（Node.js プロジェクト）

Node.jsプロジェクトでは、Huskyを使用してGit Hooksを管理することを推奨します。

### インストール

```bash
npm install --save-dev husky
npx husky install
npm pkg set scripts.prepare="husky install"
```

### commit-msgフックの追加

```bash
npx husky add .husky/commit-msg 'npx --no -- commitlint --edit "$1"'
```

### commitlint設定

```bash
npm install --save-dev @commitlint/cli @commitlint/config-conventional
```

```javascript
// commitlint.config.js
module.exports = {
  extends: ['@commitlint/config-conventional'],
  rules: {
    // UTF-8検証は別途スクリプトで実施
    'body-max-line-length': [2, 'always', 72],
    'subject-max-length': [2, 'always', 50],
  },
}
```

## pre-commit（Python プロジェクト）

Pythonプロジェクトでは、pre-commitフレームワークを使用します。

### インストール方法

```bash
pip install pre-commit
# または
uv pip install pre-commit
```

### .pre-commit-config.yaml

```yaml
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.4.0
    hooks:
      - id: check-yaml
      - id: end-of-file-fixer
      - id: trailing-whitespace
      - id: check-added-large-files

  - repo: local
    hooks:
      - id: utf8-commit-msg
        name: UTF-8 Commit Message
        entry: bash -c 'iconv -f UTF-8 -t UTF-8 .git/COMMIT_EDITMSG > /dev/null'
        language: system
        stages: [commit-msg]
```

### セットアップ

```bash
pre-commit install
pre-commit install --hook-type commit-msg
```

## トラブルシューティング

### フックが実行されない

```bash
# フックファイルに実行権限があるか確認
ls -la .git/hooks/commit-msg

# 実行権限がない場合は付与
chmod +x .git/hooks/commit-msg
```

### UTF-8検証が動作しない

```bash
# iconvがインストールされているか確認
which iconv

# macOS: iconv は標準でインストール済み
# Linux: 必要に応じてインストール
sudo apt-get install libc-bin
```

## 参考リンク

- [Git Hooks 公式ドキュメント](https://git-scm.com/docs/githooks)
- [Husky](https://typicode.github.io/husky/)
- [pre-commit](https://pre-commit.com/)
- [commitlint](https://commitlint.js.org/)
