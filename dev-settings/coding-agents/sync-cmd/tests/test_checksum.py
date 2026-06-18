from pathlib import Path

from sync_cmd.checksum import _file_digest, _directory_digest, of


def test_file_digest_returns_64char_hex(tmp_path: Path) -> None:
    f = tmp_path / "hello.txt"
    f.write_bytes(b"hello")
    assert len(_file_digest(f)) == 64


def test_file_digest_same_content_returns_same_checksum(tmp_path: Path) -> None:
    a = tmp_path / "a.txt"
    b = tmp_path / "b.txt"
    a.write_bytes(b"same content")
    b.write_bytes(b"same content")
    assert _file_digest(a) == _file_digest(b)


def test_file_digest_different_content_returns_different_checksums(tmp_path: Path) -> None:
    a = tmp_path / "a.txt"
    b = tmp_path / "b.txt"
    a.write_bytes(b"content A")
    b.write_bytes(b"content B")
    assert _file_digest(a) != _file_digest(b)


def test_file_digest_nonexistent_returns_not_exists(tmp_path: Path) -> None:
    assert _file_digest(tmp_path / "nonexistent.txt") == "NOT_EXISTS"


def test_directory_digest_returns_64char_hex(tmp_path: Path) -> None:
    (tmp_path / "file.txt").write_bytes(b"content")
    assert len(_directory_digest(tmp_path)) == 64


def test_directory_digest_changes_when_file_added(tmp_path: Path) -> None:
    (tmp_path / "file.txt").write_bytes(b"content")
    before = _directory_digest(tmp_path)
    (tmp_path / "new.txt").write_bytes(b"new")
    after = _directory_digest(tmp_path)
    assert before != after


def test_directory_digest_same_structure_returns_same_checksum(tmp_path: Path) -> None:
    dir_a = tmp_path / "a"
    dir_b = tmp_path / "b"
    for d in (dir_a, dir_b):
        d.mkdir()
        (d / "file.txt").write_bytes(b"same")
        sub = d / "sub"
        sub.mkdir()
        (sub / "nested.txt").write_bytes(b"nested")
    assert _directory_digest(dir_a) == _directory_digest(dir_b)


def test_directory_digest_nonexistent_returns_not_exists(tmp_path: Path) -> None:
    assert _directory_digest(tmp_path / "nonexistent") == "NOT_EXISTS"


def test_of_returns_file_checksum_for_file(tmp_path: Path) -> None:
    f = tmp_path / "file.txt"
    f.write_bytes(b"content")
    assert of(f) == _file_digest(f)


def test_of_returns_directory_checksum_for_directory(tmp_path: Path) -> None:
    (tmp_path / "file.txt").write_bytes(b"content")
    assert of(tmp_path) == _directory_digest(tmp_path)


def test_of_nonexistent_returns_not_exists(tmp_path: Path) -> None:
    assert of(tmp_path / "nonexistent") == "NOT_EXISTS"
