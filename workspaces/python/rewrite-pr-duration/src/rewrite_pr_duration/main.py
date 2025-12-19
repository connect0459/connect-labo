"""メインエントリーポイント"""

import argparse
import sys
from pathlib import Path

from .calculator import WorkHoursCalculator
from .config import load_config
from .pr_updater import PRUpdater


def main() -> int:
    """メイン処理

    Returns:
        終了コード（0: 成功、1: エラー）
    """
    parser = argparse.ArgumentParser(
        description="GitHub PRの作業時間を自動計算してbodyを更新するツール",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
使用例:
  # デフォルトの設定ファイル（./config.toml）を使用
  rewrite-pr-duration

  # カスタム設定ファイルを指定
  rewrite-pr-duration --config /path/to/config.toml

  # Dry-runモードで実行（実際には更新しない）
  rewrite-pr-duration --dry-run
        """,
    )

    parser.add_argument(
        "-c",
        "--config",
        type=Path,
        default=Path("config.toml"),
        help="設定ファイルのパス（デフォルト: config.toml）",
    )

    parser.add_argument(
        "-d",
        "--dry-run",
        action="store_true",
        help="Dry-runモード（実際には更新しない）",
    )

    parser.add_argument(
        "-v",
        "--verbose",
        action="store_true",
        help="詳細ログを出力",
    )

    args = parser.parse_args()

    # 設定ファイルを読み込み
    try:
        config = load_config(args.config)
    except (FileNotFoundError, ValueError) as e:
        print(f"Error: {e}", file=sys.stderr)
        print(
            f"\nヒント: config.example.toml をコピーして {args.config} を作成してください",
            file=sys.stderr,
        )
        return 1

    # コマンドライン引数で設定を上書き
    if args.dry_run:
        config.options.dry_run = True
    if args.verbose:
        config.options.verbose = True

    # 処理開始
    print("=" * 80)
    print("GitHub PR作業時間更新ツール")
    print("=" * 80)
    print()

    if config.options.dry_run:
        print("【DRY-RUNモード】実際にはPRを更新しません")
        print()

    print(
        f"対象期間: {config.period.start_date.date()} ~ {config.period.end_date.date()}"
    )
    print(f"対象リポジトリ数: {len(config.repositories)}")
    print()

    # 作業時間計算機とPR更新機を初期化
    calculator = WorkHoursCalculator(config)
    updater = PRUpdater(config, calculator)

    # 各リポジトリを処理
    total_prs = 0
    total_needs_update = 0
    total_updated = 0
    total_failed = 0

    for repo in config.repositories:
        print(f"処理中: {repo}")
        print("-" * 80)

        # PR一覧を取得
        pr_numbers = updater.get_pr_list(repo)
        if not pr_numbers:
            print("  対象PRなし")
            print()
            continue

        print(f"  対象PR数: {len(pr_numbers)}")

        # 各PRを処理
        for pr_number in pr_numbers:
            total_prs += 1

            if config.options.verbose:
                print(f"  PR #{pr_number} を処理中...")

            pr_info = updater.get_pr_info(repo, pr_number)
            if pr_info is None:
                total_failed += 1
                continue

            if not pr_info.needs_update:
                if config.options.verbose:
                    print("    -> プレースホルダーなし（スキップ）")
                continue

            total_needs_update += 1

            if config.options.verbose:
                print(f"    -> 作業時間: {pr_info.work_hours_formatted or 'N/A'}")

            # PRを更新
            success = updater.update_pr_body(pr_info)
            if success:
                total_updated += 1
                print(f"  ✓ PR #{pr_number}: {pr_info.work_hours_formatted} に更新")
            else:
                if config.options.verbose:
                    print("    -> 更新不要またはスキップ")

        print()

    # 結果サマリー
    print("=" * 80)
    print("処理完了")
    print("=" * 80)
    print(f"対象PR数: {total_prs}")
    print(f"更新対象PR数: {total_needs_update}")
    print(f"更新成功: {total_updated}")
    print(f"更新失敗: {total_failed}")
    print()

    if config.options.dry_run:
        print("【DRY-RUNモード】実際にはPRを更新していません")
        print("設定を確認後、--dry-run オプションを外して再実行してください")

    return 0


if __name__ == "__main__":
    sys.exit(main())
