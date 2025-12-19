"""設定ファイル読み込みのテスト"""

import tempfile
from datetime import datetime
from pathlib import Path

import pytest

from rewrite_pr_duration.config import Config, load_config


def test_load_config_success():
    """正常な設定ファイルの読み込みテスト"""
    config_content = """
[repositories]
targets = ["org/repo1", "org/repo2"]

[period]
start_date = "2025-10-01"
end_date = "2025-12-31"

[work_hours]
start_hour = 9
start_minute = 30
end_hour = 18
end_minute = 30

[[holidays]]
dates = ["2025-10-14", "2025-11-04"]

[placeholders]
patterns = ["xx 時間", "xx時間"]

[options]
dry_run = false
verbose = true
"""

    with tempfile.NamedTemporaryFile(mode="w", suffix=".toml", delete=False) as f:
        f.write(config_content)
        temp_path = Path(f.name)

    try:
        config = load_config(temp_path)

        assert isinstance(config, Config)
        assert config.repositories == ["org/repo1", "org/repo2"]
        assert config.period.start_date == datetime(2025, 10, 1)
        assert config.period.end_date == datetime(2025, 12, 31)
        assert config.work_hours.start_hour == 9
        assert config.work_hours.start_minute == 30
        assert config.work_hours.end_hour == 18
        assert config.work_hours.end_minute == 30
        assert len(config.holidays) == 2
        assert config.holidays[0] == datetime(2025, 10, 14)
        assert config.placeholders == ["xx 時間", "xx時間"]
        assert config.options.dry_run is False
        assert config.options.verbose is True
    finally:
        temp_path.unlink()


def test_load_config_file_not_found():
    """存在しない設定ファイルのテスト"""
    with pytest.raises(FileNotFoundError):
        load_config(Path("/nonexistent/config.toml"))


def test_load_config_invalid_format():
    """不正な形式の設定ファイルのテスト"""
    config_content = """
[repositories]
# targets が欠落している
"""

    with tempfile.NamedTemporaryFile(mode="w", suffix=".toml", delete=False) as f:
        f.write(config_content)
        temp_path = Path(f.name)

    try:
        with pytest.raises(ValueError, match="必須項目が不足しています"):
            load_config(temp_path)
    finally:
        temp_path.unlink()
