"""作業時間計算のテスト"""

from datetime import datetime

import pytest

from rewrite_pr_duration.calculator import WorkHoursCalculator
from rewrite_pr_duration.config import Config, Options, Period, WorkHours


@pytest.fixture
def test_config():
    """テスト用の設定を作成"""
    return Config(
        repositories=["org/repo"],
        period=Period(
            start_date=datetime(2025, 10, 1), end_date=datetime(2025, 12, 31)
        ),
        work_hours=WorkHours(start_hour=9, start_minute=30, end_hour=18, end_minute=30),
        holidays=[
            datetime(2025, 10, 14),  # 火曜日（スポーツの日）
            datetime(2025, 11, 4),  # 月曜日（文化の日の振替休日）
        ],
        placeholders=["xx 時間"],
        options=Options(dry_run=False, verbose=False),
    )


@pytest.fixture
def calculator(test_config):
    """テスト用の計算機を作成"""
    return WorkHoursCalculator(test_config)


def test_is_workday_weekday(calculator):
    """平日の判定テスト"""
    # 2025-10-01は水曜日
    dt = datetime(2025, 10, 1, 10, 0)
    assert calculator.is_workday(dt) is True


def test_is_workday_saturday(calculator):
    """土曜日の判定テスト"""
    # 2025-10-04は土曜日
    dt = datetime(2025, 10, 4, 10, 0)
    assert calculator.is_workday(dt) is False


def test_is_workday_sunday(calculator):
    """日曜日の判定テスト"""
    # 2025-10-05は日曜日
    dt = datetime(2025, 10, 5, 10, 0)
    assert calculator.is_workday(dt) is False


def test_is_workday_holiday(calculator):
    """祝日の判定テスト"""
    # 2025-10-14は火曜日だが祝日
    dt = datetime(2025, 10, 14, 10, 0)
    assert calculator.is_workday(dt) is False


def test_calculate_work_hours_same_day():
    """同日内の作業時間計算テスト"""
    config = Config(
        repositories=["org/repo"],
        period=Period(
            start_date=datetime(2025, 10, 1), end_date=datetime(2025, 12, 31)
        ),
        work_hours=WorkHours(start_hour=9, start_minute=30, end_hour=18, end_minute=30),
        holidays=[],
        placeholders=["xx 時間"],
        options=Options(dry_run=False, verbose=False),
    )
    calculator = WorkHoursCalculator(config)

    # 2025-10-01（水曜日）10:00 ~ 11:00 = 1時間
    start = datetime(2025, 10, 1, 10, 0)
    end = datetime(2025, 10, 1, 11, 0)
    hours = calculator.calculate_work_hours(start, end)
    assert hours == 1.0


def test_calculate_work_hours_before_work_start():
    """勤務開始前の作業時間計算テスト"""
    config = Config(
        repositories=["org/repo"],
        period=Period(
            start_date=datetime(2025, 10, 1), end_date=datetime(2025, 12, 31)
        ),
        work_hours=WorkHours(start_hour=9, start_minute=30, end_hour=18, end_minute=30),
        holidays=[],
        placeholders=["xx 時間"],
        options=Options(dry_run=False, verbose=False),
    )
    calculator = WorkHoursCalculator(config)

    # 2025-10-01（水曜日）8:00 ~ 10:00
    # 実際にカウントされるのは 9:30 ~ 10:00 = 0.5時間
    start = datetime(2025, 10, 1, 8, 0)
    end = datetime(2025, 10, 1, 10, 0)
    hours = calculator.calculate_work_hours(start, end)
    assert hours == 0.5


def test_calculate_work_hours_after_work_end():
    """勤務終了後の作業時間計算テスト"""
    config = Config(
        repositories=["org/repo"],
        period=Period(
            start_date=datetime(2025, 10, 1), end_date=datetime(2025, 12, 31)
        ),
        work_hours=WorkHours(start_hour=9, start_minute=30, end_hour=18, end_minute=30),
        holidays=[],
        placeholders=["xx 時間"],
        options=Options(dry_run=False, verbose=False),
    )
    calculator = WorkHoursCalculator(config)

    # 2025-10-01（水曜日）17:00 ~ 20:00
    # 実際にカウントされるのは 17:00 ~ 18:30 = 1.5時間
    start = datetime(2025, 10, 1, 17, 0)
    end = datetime(2025, 10, 1, 20, 0)
    hours = calculator.calculate_work_hours(start, end)
    assert hours == 1.5


def test_calculate_work_hours_across_weekend():
    """週末をまたぐ作業時間計算テスト"""
    config = Config(
        repositories=["org/repo"],
        period=Period(
            start_date=datetime(2025, 10, 1), end_date=datetime(2025, 12, 31)
        ),
        work_hours=WorkHours(start_hour=9, start_minute=30, end_hour=18, end_minute=30),
        holidays=[],
        placeholders=["xx 時間"],
        options=Options(dry_run=False, verbose=False),
    )
    calculator = WorkHoursCalculator(config)

    # 2025-10-03（金曜日）17:00 ~ 2025-10-06（月曜日）11:00
    # 金曜日: 17:00 ~ 18:30 = 1.5時間
    # 土日: カウントしない
    # 月曜日: 9:30 ~ 11:00 = 1.5時間
    # 合計: 3.0時間
    start = datetime(2025, 10, 3, 17, 0)
    end = datetime(2025, 10, 6, 11, 0)
    hours = calculator.calculate_work_hours(start, end)
    assert hours == 3.0


def test_format_hours_only_hours():
    """時間のみの整形テスト"""
    assert WorkHoursCalculator.format_hours(1.0) == "1時間"
    assert WorkHoursCalculator.format_hours(5.0) == "5時間"


def test_format_hours_only_minutes():
    """分のみの整形テスト"""
    assert WorkHoursCalculator.format_hours(0.5) == "30分"
    assert WorkHoursCalculator.format_hours(0.25) == "15分"


def test_format_hours_hours_and_minutes():
    """時間と分の整形テスト"""
    assert WorkHoursCalculator.format_hours(1.5) == "1時間30分"
    assert WorkHoursCalculator.format_hours(2.25) == "2時間15分"


def test_format_hours_zero():
    """0時間の整形テスト"""
    assert WorkHoursCalculator.format_hours(0.0) == "0分"


def test_utc_to_jst():
    """UTC→JST変換テスト"""
    utc_str = "2025-10-01T01:00:00Z"
    jst_dt = WorkHoursCalculator.utc_to_jst(utc_str)
    assert jst_dt == datetime(2025, 10, 1, 10, 0)
