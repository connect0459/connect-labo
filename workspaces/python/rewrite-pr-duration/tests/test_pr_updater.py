"""PR更新処理のテスト"""

import json
from datetime import datetime
from unittest.mock import MagicMock, patch

import pytest
from rewrite_pr_duration.calculator import WorkHoursCalculator
from rewrite_pr_duration.config import Config, Options, Period, WorkHours
from rewrite_pr_duration.pr_updater import PRInfo, PRUpdater


@pytest.fixture
def test_config():
    """テスト用の設定を作成"""
    return Config(
        repositories=["org/repo"],
        period=Period(
            start_date=datetime(2025, 10, 1), end_date=datetime(2025, 12, 31)
        ),
        work_hours=WorkHours(start_hour=9, start_minute=30, end_hour=18, end_minute=30),
        holidays=[],
        placeholders=["xx 時間", "xx時間", "約xx時間"],
        options=Options(dry_run=False, verbose=False),
    )


@pytest.fixture
def calculator(test_config):
    """テスト用の計算機を作成"""
    return WorkHoursCalculator(test_config)


@pytest.fixture
def updater(test_config, calculator):
    """テスト用のPR更新機を作成"""
    return PRUpdater(test_config, calculator)


def test_has_placeholder_found(updater):
    """プレースホルダー検出テスト（見つかる場合）"""
    body = """
## 作業時間

* 見積り: 1時間
* 実際にかかった時間: xx 時間
"""
    assert updater._has_placeholder(body) is True


def test_has_placeholder_not_found(updater):
    """プレースホルダー検出テスト（見つからない場合）"""
    body = """
## 作業時間

* 見積り: 1時間
* 実際にかかった時間: 2時間30分
"""
    assert updater._has_placeholder(body) is False


def test_has_placeholder_none_body(updater):
    """プレースホルダー検出テスト（bodyがNone）"""
    assert updater._has_placeholder(None) is False


def test_replace_placeholder_with_hyphen(updater):
    """プレースホルダー置換テスト（ハイフン形式）"""
    body = """
## 作業時間

- 見積り: 1時間
- 実際にかかった時間: xx 時間
"""
    expected = """
## 作業時間

- 見積り: 1時間
- 実際にかかった時間: 2時間30分
"""
    result = updater._replace_placeholder(body, "2時間30分")
    assert result == expected


def test_replace_placeholder_with_asterisk(updater):
    """プレースホルダー置換テスト（アスタリスク形式）"""
    body = """
## 作業時間

* 見積り: 1時間
* 実際にかかった時間: xx時間
"""
    expected = """
## 作業時間

* 見積り: 1時間
* 実際にかかった時間: 1時間30分
"""
    result = updater._replace_placeholder(body, "1時間30分")
    assert result == expected


def test_replace_placeholder_with_colon(updater):
    """プレースホルダー置換テスト（コロン形式）"""
    body = """
## 作業時間

- 見積り: 1時間
- 実際にかかった時間: 約xx時間
"""
    expected = """
## 作業時間

- 見積り: 1時間
- 実際にかかった時間: 45分
"""
    result = updater._replace_placeholder(body, "45分")
    assert result == expected


@patch("rewrite_pr_duration.pr_updater.subprocess.run")
def test_get_pr_info_success(mock_run, updater):
    """PR情報取得テスト（成功）"""
    mock_response = {
        "body": "## 作業時間\n- 実際にかかった時間: xx 時間",
        "createdAt": "2025-10-01T01:00:00Z",
        "mergedAt": "2025-10-01T02:00:00Z",
        "closedAt": "2025-10-01T02:00:00Z",
        "state": "MERGED",
    }

    mock_run.return_value = MagicMock(stdout=json.dumps(mock_response), returncode=0)

    pr_info = updater.get_pr_info("org/repo", 123)

    assert pr_info is not None
    assert pr_info.repo == "org/repo"
    assert pr_info.pr_number == 123
    assert pr_info.state == "MERGED"
    assert pr_info.needs_update is True
    assert pr_info.work_hours == 1.0  # 10:00 - 11:00 JST = 1.0時間


@patch("rewrite_pr_duration.pr_updater.subprocess.run")
def test_get_pr_list_success(mock_run, updater):
    """PR一覧取得テスト（成功）"""
    mock_response = [
        {"number": 1, "createdAt": "2025-10-01T01:00:00Z"},
        {"number": 2, "createdAt": "2025-10-15T01:00:00Z"},
        {"number": 3, "createdAt": "2026-01-01T01:00:00Z"},  # 期間外
    ]

    mock_run.return_value = MagicMock(stdout=json.dumps(mock_response), returncode=0)

    pr_numbers = updater.get_pr_list("org/repo")

    # 期間内のPRのみ返される
    assert pr_numbers == [1, 2]


@patch("rewrite_pr_duration.pr_updater.subprocess.run")
def test_update_pr_body_success(mock_run, updater):
    """PR body更新テスト（成功）"""
    pr_info = PRInfo(
        repo="org/repo",
        pr_number=123,
        state="MERGED",
        created_at="2025-10-01T01:00:00Z",
        merged_at="2025-10-01T02:00:00Z",
        closed_at="2025-10-01T02:00:00Z",
        body="実際にかかった時間: xx 時間",
        work_hours=1.5,
        work_hours_formatted="1時間30分",
        needs_update=True,
    )

    mock_run.return_value = MagicMock(returncode=0)

    result = updater.update_pr_body(pr_info)

    assert result is True
    mock_run.assert_called_once()


def test_update_pr_body_dry_run(test_config, calculator):
    """PR body更新テスト（Dry-runモード）"""
    # Dry-runモードを有効化
    test_config.options.dry_run = True
    updater = PRUpdater(test_config, calculator)

    pr_info = PRInfo(
        repo="org/repo",
        pr_number=123,
        state="MERGED",
        created_at="2025-10-01T01:00:00Z",
        merged_at="2025-10-01T02:00:00Z",
        closed_at="2025-10-01T02:00:00Z",
        body="実際にかかった時間: xx 時間",
        work_hours=1.5,
        work_hours_formatted="1時間30分",
        needs_update=True,
    )

    # Dry-runモードでは実際には更新しないがTrueを返す
    result = updater.update_pr_body(pr_info)
    assert result is True


def test_update_pr_body_no_changes(updater):
    """PR body更新テスト（変更なし）"""
    pr_info = PRInfo(
        repo="org/repo",
        pr_number=123,
        state="MERGED",
        created_at="2025-10-01T01:00:00Z",
        merged_at="2025-10-01T02:00:00Z",
        closed_at="2025-10-01T02:00:00Z",
        body="実際にかかった時間: 1時間30分",  # 既に更新済み
        work_hours=1.5,
        work_hours_formatted="1時間30分",
        needs_update=False,
    )

    result = updater.update_pr_body(pr_info)
    assert result is False
