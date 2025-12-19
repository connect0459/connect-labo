# rewrite-pr-duration

GitHub PRの作業時間を自動計算してbodyを更新するツール

## 概要

GitHub PRのbodyに記載されている「実際にかかった時間: xx 時間」といったプレースホルダーを、PR作成からマージ/クローズまでの実稼働時間で自動的に更新します。

### 主な機能

- **稼働時間の自動計算**: PR作成からマージ/クローズまでの時間を、平日の勤務時間のみでカウント
- **複数リポジトリ対応**: 一度に複数のリポジトリを処理可能
- **柔軟な設定**: 勤務時間、祝日、プレースホルダーパターンなどを自由に設定
- **Dry-runモード**: 実際に更新する前に動作確認が可能

## インストール

```bash
# プロジェクトディレクトリに移動
cd /Users/akira/workspaces/repo/connect-labo/workspaces/python/rewrite-pr-duration

# 依存関係をインストール
uv sync
```

## 使い方

### 1. 設定ファイルの準備

```bash
# サンプル設定ファイルをコピー
cp config.example.toml config.toml

# 設定ファイルを編集
# - 対象リポジトリ
# - 対象期間
# - 勤務時間
# - 祝日
# などを設定してください
```

### 2. 実行

```bash
# 設定ファイルを確認（Dry-runモード）
uv run rewrite-pr-duration --dry-run

# 実際に更新
uv run rewrite-pr-duration

# カスタム設定ファイルを指定
uv run rewrite-pr-duration --config /path/to/config.toml

# 詳細ログを出力
uv run rewrite-pr-duration --verbose
```

## 設定ファイル

設定ファイル（`config.toml`）で以下の項目を設定できます:

### 対象リポジトリ

```toml
[repositories]
targets = [
    "organization/repository1",
    "organization/repository2",
]
```

### 対象期間

```toml
[period]
start_date = "2025-10-01"  # 開始日
end_date = "2025-12-19"     # 終了日
```

### 勤務時間

```toml
[work_hours]
start_hour = 9
start_minute = 30
end_hour = 18
end_minute = 30
```

### 祝日

```toml
[[holidays]]
dates = [
    "2025-10-14",  # スポーツの日
    "2025-11-04",  # 文化の日の振替休日
]
```

### プレースホルダーパターン

```toml
[placeholders]
patterns = [
    "xx 時間",
    "xx時間",
    "約xx時間",
    "XX時間",
]
```

### 実行オプション

```toml
[options]
dry_run = false   # true の場合、実際には更新しない
verbose = true    # 詳細ログを出力
```

## 開発

### テストの実行

```bash
# すべてのテストを実行
uv run pytest

# カバレッジ付きで実行
uv run pytest --cov=rewrite_pr_duration --cov-report=html

# 特定のテストファイルのみ実行
uv run pytest tests/test_calculator.py
```

### プロジェクト構成

```text
rewrite-pr-duration/
├── src/
│   └── rewrite_pr_duration/
│       ├── __init__.py
│       ├── main.py          # エントリーポイント
│       ├── config.py        # 設定管理
│       ├── calculator.py    # 作業時間計算
│       └── pr_updater.py    # PR更新処理
├── tests/
│   ├── __init__.py
│   ├── test_calculator.py
│   ├── test_config.py
│   └── test_pr_updater.py
├── config.example.toml      # 設定ファイルのサンプル
├── config.toml              # 実際の設定ファイル（要作成）
├── pyproject.toml
└── README.md
```

## 動作要件

- Python 3.11 以上
- GitHub CLI (`gh`) がインストールされており、認証済みであること
- 対象リポジトリへのアクセス権限があること

## ライセンス

MIT License

## 作者

connect0459
