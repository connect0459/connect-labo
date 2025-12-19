"""PR更新ロジック"""

import json
import re
import subprocess
import sys
from dataclasses import dataclass

from .calculator import WorkHoursCalculator
from .config import Config


@dataclass
class PRInfo:
    """PR情報"""

    repo: str
    pr_number: int
    state: str
    created_at: str
    merged_at: str | None
    closed_at: str | None
    body: str
    work_hours: float | None = None
    work_hours_formatted: str | None = None
    needs_update: bool = False


class PRUpdater:
    """PR更新クラス"""

    def __init__(self, config: Config, calculator: WorkHoursCalculator):
        """初期化

        Args:
            config: アプリケーション設定
            calculator: 作業時間計算機
        """
        self.config = config
        self.calculator = calculator

    def get_pr_list(self, repo: str) -> list[int]:
        """指定期間内に作成されたPRのリストを取得

        Args:
            repo: リポジトリ名（org/repo形式）

        Returns:
            PR番号のリスト
        """
        try:
            # gh pr list で期間内のPRを取得
            # --state all で全ステータスのPRを取得
            # --json number,createdAt でJSONフォーマットで取得
            result = subprocess.run(
                [
                    "gh",
                    "pr",
                    "list",
                    "--repo",
                    repo,
                    "--state",
                    "all",
                    "--limit",
                    "1000",
                    "--json",
                    "number,createdAt",
                ],
                capture_output=True,
                text=True,
                check=True,
            )

            prs = json.loads(result.stdout)
            pr_numbers = []

            for pr in prs:
                created_at = self.calculator.utc_to_jst(pr["createdAt"])
                # 期間内に作成されたPRのみを対象
                if (
                    self.config.period.start_date
                    <= created_at
                    <= self.config.period.end_date
                ):
                    pr_numbers.append(pr["number"])

            return pr_numbers

        except subprocess.CalledProcessError as e:
            print(f"Error fetching PR list for {repo}: {e}", file=sys.stderr)
            print(f"stderr: {e.stderr}", file=sys.stderr)
            return []
        except json.JSONDecodeError as e:
            print(f"Error parsing JSON for PR list {repo}: {e}", file=sys.stderr)
            return []

    def get_pr_info(self, repo: str, pr_number: int) -> PRInfo | None:
        """PR情報を取得

        Args:
            repo: リポジトリ名（org/repo形式）
            pr_number: PR番号

        Returns:
            PR情報、取得失敗時はNone
        """
        try:
            result = subprocess.run(
                [
                    "gh",
                    "pr",
                    "view",
                    str(pr_number),
                    "--repo",
                    repo,
                    "--json",
                    "body,createdAt,mergedAt,closedAt,state",
                ],
                capture_output=True,
                text=True,
                check=True,
            )
            data = json.loads(result.stdout)

            body = data.get("body", "")
            created_at = data.get("createdAt")
            merged_at = data.get("mergedAt")
            closed_at = data.get("closedAt")
            state = data.get("state")

            # bodyにプレースホルダーが含まれているかチェック
            needs_update = self._has_placeholder(body)

            # 作業時間を計算
            end_at = merged_at or closed_at
            work_hours = None
            work_hours_formatted = None

            if created_at and end_at:
                start_jst = self.calculator.utc_to_jst(created_at)
                end_jst = self.calculator.utc_to_jst(end_at)
                work_hours = self.calculator.calculate_work_hours(start_jst, end_jst)
                work_hours_formatted = self.calculator.format_hours(work_hours)

            return PRInfo(
                repo=repo,
                pr_number=pr_number,
                state=state,
                created_at=created_at,
                merged_at=merged_at,
                closed_at=closed_at,
                body=body,
                work_hours=work_hours,
                work_hours_formatted=work_hours_formatted,
                needs_update=needs_update,
            )

        except subprocess.CalledProcessError as e:
            print(f"Error fetching PR {repo}#{pr_number}: {e}", file=sys.stderr)
            return None
        except json.JSONDecodeError as e:
            print(f"Error parsing JSON for PR {repo}#{pr_number}: {e}", file=sys.stderr)
            return None

    def _has_placeholder(self, body: str) -> bool:
        """bodyにプレースホルダーが含まれているかチェック

        Args:
            body: PRのbody

        Returns:
            プレースホルダーが含まれている場合True
        """
        if body is None:
            return False

        for placeholder in self.config.placeholders:
            # プレースホルダーをエスケープして正規表現として使用
            escaped = re.escape(placeholder)
            if re.search(escaped, body):
                return True

        return False

    def update_pr_body(self, pr_info: PRInfo) -> bool:
        """PRのbodyを更新

        Args:
            pr_info: PR情報

        Returns:
            更新成功時True
        """
        if not pr_info.needs_update or not pr_info.work_hours_formatted:
            return False

        # bodyを更新
        new_body = self._replace_placeholder(pr_info.body, pr_info.work_hours_formatted)

        # 変更がない場合はスキップ
        if pr_info.body == new_body:
            return False

        # Dry-runモードの場合は実際には更新しない
        if self.config.options.dry_run:
            print(f"[DRY-RUN] Would update {pr_info.repo}#{pr_info.pr_number}")
            return True

        # PRを更新
        try:
            subprocess.run(
                [
                    "gh",
                    "pr",
                    "edit",
                    str(pr_info.pr_number),
                    "--repo",
                    pr_info.repo,
                    "--body",
                    new_body,
                ],
                capture_output=True,
                text=True,
                check=True,
            )
            return True
        except subprocess.CalledProcessError as e:
            print(
                f"Error updating PR {pr_info.repo}#{pr_info.pr_number}: {e}",
                file=sys.stderr,
            )
            print(f"stderr: {e.stderr}", file=sys.stderr)
            return False

    def _replace_placeholder(self, body: str, work_hours_formatted: str) -> str:
        """bodyのプレースホルダーを実際の作業時間に置き換え

        Args:
            body: PRのbody
            work_hours_formatted: 整形された作業時間

        Returns:
            更新後のbody
        """
        # 様々なパターンに対応した正規表現
        # 「実際にかかった時間」の後に、コロンや改行、箇条書き記号を経て、プレースホルダーが続くパターン
        pattern = r"(実際にかかった時間\s*[:：]?\s*\r?\n?\s*[-*]?\s*)(?:約?\s*)?(?:XX|xx)\s*時間"
        replacement = r"\g<1>" + work_hours_formatted
        new_body = re.sub(pattern, replacement, body)
        return new_body
