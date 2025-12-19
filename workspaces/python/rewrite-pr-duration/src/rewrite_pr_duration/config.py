"""設定ファイルの読み込みと管理"""

import tomllib
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path


@dataclass
class WorkHours:
    """勤務時間設定"""

    start_hour: int
    start_minute: int
    end_hour: int
    end_minute: int


@dataclass
class Period:
    """対象期間設定"""

    start_date: datetime
    end_date: datetime


@dataclass
class Options:
    """実行オプション"""

    dry_run: bool
    verbose: bool


@dataclass
class Config:
    """アプリケーション設定"""

    repositories: list[str]
    period: Period
    work_hours: WorkHours
    holidays: list[datetime]
    placeholders: list[str]
    options: Options


def load_config(config_path: Path | str) -> Config:
    """設定ファイルを読み込む

    Args:
        config_path: 設定ファイルのパス

    Returns:
        設定オブジェクト

    Raises:
        FileNotFoundError: 設定ファイルが見つからない場合
        ValueError: 設定ファイルの形式が不正な場合
    """
    path = Path(config_path)
    if not path.exists():
        raise FileNotFoundError(f"設定ファイルが見つかりません: {path}")

    with path.open("rb") as f:
        data = tomllib.load(f)

    try:
        # リポジトリ設定
        repositories = data["repositories"]["targets"]

        # 期間設定
        period_data = data["period"]
        period = Period(
            start_date=datetime.fromisoformat(period_data["start_date"]),
            end_date=datetime.fromisoformat(period_data["end_date"]),
        )

        # 勤務時間設定
        work_hours_data = data["work_hours"]
        work_hours = WorkHours(
            start_hour=work_hours_data["start_hour"],
            start_minute=work_hours_data["start_minute"],
            end_hour=work_hours_data["end_hour"],
            end_minute=work_hours_data["end_minute"],
        )

        # 祝日設定
        holidays_data = data["holidays"][0]["dates"]
        holidays = [datetime.fromisoformat(date) for date in holidays_data]

        # プレースホルダーパターン
        placeholders = data["placeholders"]["patterns"]

        # 実行オプション
        options_data = data["options"]
        options = Options(
            dry_run=options_data["dry_run"],
            verbose=options_data["verbose"],
        )

        return Config(
            repositories=repositories,
            period=period,
            work_hours=work_hours,
            holidays=holidays,
            placeholders=placeholders,
            options=options,
        )
    except KeyError as e:
        raise ValueError(f"設定ファイルに必須項目が不足しています: {e}") from e
    except (ValueError, TypeError) as e:
        raise ValueError(f"設定ファイルの形式が不正です: {e}") from e
