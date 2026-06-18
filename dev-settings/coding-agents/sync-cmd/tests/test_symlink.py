from pathlib import Path

from sync_cmd.symlink import setup


def test_setup_creates_symlink(tmp_path: Path) -> None:
    target = tmp_path / "target.txt"
    link = tmp_path / "link.txt"
    target.write_text("content")

    setup(target, link)

    assert link.is_symlink()
    assert link.resolve() == target.resolve()
    assert link.read_text() == "content"


def test_setup_replaces_existing_symlink(tmp_path: Path) -> None:
    old_target = tmp_path / "old.txt"
    new_target = tmp_path / "new.txt"
    link = tmp_path / "link.txt"
    old_target.write_text("old")
    new_target.write_text("new")
    link.symlink_to(old_target)

    setup(new_target, link)

    assert link.is_symlink()
    assert link.resolve() == new_target.resolve()
    assert link.read_text() == "new"


def test_setup_replaces_regular_file_with_symlink(tmp_path: Path) -> None:
    target = tmp_path / "target.txt"
    link = tmp_path / "link.txt"
    target.write_text("target content")
    link.write_text("regular file")

    setup(target, link)

    assert link.is_symlink()
    assert link.read_text() == "target content"
