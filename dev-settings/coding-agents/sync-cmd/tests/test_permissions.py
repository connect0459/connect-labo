import json
from pathlib import Path

from sync_cmd.permissions import merge


def _read_json(path: Path) -> dict:
    return json.loads(path.read_text())


def test_merge_applies_source_permissions_to_target(tmp_path: Path) -> None:
    source = tmp_path / "source.json"
    target = tmp_path / "target.json"
    source.write_text('{"permissions": {"allow": ["read"]}}')
    target.write_text("{}")

    merge(source, target)

    result = _read_json(target)
    assert result["permissions"]["allow"] == ["read"]


def test_merge_creates_target_when_not_exists(tmp_path: Path) -> None:
    source = tmp_path / "source.json"
    target = tmp_path / "target.json"
    source.write_text('{"permissions": {"allow": ["write"]}}')

    merge(source, target)

    result = _read_json(target)
    assert result["permissions"]["allow"] == ["write"]


def test_merge_overwrites_existing_permissions(tmp_path: Path) -> None:
    source = tmp_path / "source.json"
    target = tmp_path / "target.json"
    source.write_text('{"permissions": {"allow": ["new"]}}')
    target.write_text('{"permissions": {"allow": ["old"]}}')

    merge(source, target)

    result = _read_json(target)
    assert result["permissions"]["allow"] == ["new"]


def test_merge_preserves_non_permissions_fields_in_target(tmp_path: Path) -> None:
    source = tmp_path / "source.json"
    target = tmp_path / "target.json"
    source.write_text('{"permissions": {"allow": []}}')
    target.write_text('{"theme": "dark", "permissions": {"allow": ["old"]}}')

    merge(source, target)

    result = _read_json(target)
    assert result["theme"] == "dark"
    assert result["permissions"]["allow"] == []


def test_merge_applies_all_source_fields_to_target(tmp_path: Path) -> None:
    source = tmp_path / "source.json"
    target = tmp_path / "target.json"
    source.write_text(
        '{"permissions": {"allow": ["read"]}, "enabledPlugins": {"cc-plugin@connect0459": true}, "extraKnownMarketplaces": {"connect0459": {}}}'
    )
    target.write_text("{}")

    merge(source, target)

    result = _read_json(target)
    assert "enabledPlugins" in result
    assert "extraKnownMarketplaces" in result


def test_merge_does_not_add_permissions_when_source_has_none(tmp_path: Path) -> None:
    source = tmp_path / "source.json"
    target = tmp_path / "target.json"
    source.write_text('{"other": "value"}')
    target.write_text("{}")

    merge(source, target)

    result = _read_json(target)
    assert "permissions" not in result
    assert result["other"] == "value"
