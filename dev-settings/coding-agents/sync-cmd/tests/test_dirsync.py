from pathlib import Path

from sync_cmd.dirsync import sync, copy_file


def test_sync_copies_file_from_src_to_dst(tmp_path: Path) -> None:
    src = tmp_path / "src"
    dst = tmp_path / "dst"
    src.mkdir()
    (src / "file.txt").write_text("content")

    sync(src, dst)

    assert (dst / "file.txt").read_text() == "content"


def test_sync_handles_nested_directory_structure(tmp_path: Path) -> None:
    src = tmp_path / "src"
    dst = tmp_path / "dst"
    deep = src / "sub" / "deep"
    deep.mkdir(parents=True)
    (deep / "nested.txt").write_text("deep content")

    sync(src, dst)

    assert (dst / "sub" / "deep" / "nested.txt").read_text() == "deep content"


def test_sync_overwrites_existing_file(tmp_path: Path) -> None:
    src = tmp_path / "src"
    dst = tmp_path / "dst"
    src.mkdir()
    dst.mkdir()
    (src / "file.txt").write_text("updated")
    (dst / "file.txt").write_text("old")

    sync(src, dst)

    assert (dst / "file.txt").read_text() == "updated"


def test_sync_deletes_files_not_in_src(tmp_path: Path) -> None:
    src = tmp_path / "src"
    dst = tmp_path / "dst"
    src.mkdir()
    dst.mkdir()
    (src / "keep.txt").write_text("keep")
    (dst / "keep.txt").write_text("old")
    (dst / "remove.txt").write_text("should be removed")

    sync(src, dst)

    assert (dst / "keep.txt").exists()
    assert not (dst / "remove.txt").exists()


def test_sync_deletes_empty_dirs_not_in_src(tmp_path: Path) -> None:
    src = tmp_path / "src"
    dst = tmp_path / "dst"
    src.mkdir()
    dst.mkdir()
    (dst / "empty_dir").mkdir()

    sync(src, dst)

    assert not (dst / "empty_dir").exists()


def test_sync_works_when_dst_does_not_exist(tmp_path: Path) -> None:
    src = tmp_path / "src"
    dst = tmp_path / "dst"
    src.mkdir()
    (src / "file.txt").write_text("content")

    sync(src, dst)

    assert (dst / "file.txt").read_text() == "content"


def test_copy_file_creates_dst_and_copies_content(tmp_path: Path) -> None:
    src = tmp_path / "src.txt"
    dst = tmp_path / "sub" / "dst.txt"
    src.write_text("hello")

    copy_file(src, dst)

    assert dst.read_text() == "hello"
