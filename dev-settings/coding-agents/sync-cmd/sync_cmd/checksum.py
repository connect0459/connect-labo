import hashlib
from pathlib import Path


def _file_digest(path: Path) -> str:
    try:
        h = hashlib.sha256()
        with open(path, "rb") as f:
            for chunk in iter(lambda: f.read(8192), b""):
                h.update(chunk)
        return h.hexdigest()
    except Exception:
        return "NOT_EXISTS"


def _directory_digest(dir_path: Path) -> str:
    if not dir_path.is_dir():
        return "NOT_EXISTS"

    h = hashlib.sha256()
    entries = sorted(
        (p.relative_to(dir_path), p)
        for p in dir_path.rglob("*")
        if p.is_file()
    )
    for rel, abs_path in entries:
        h.update(str(rel).encode())
        h.update(_file_digest(abs_path).encode())

    return h.hexdigest()


def of(path: Path) -> str:
    path = Path(path)
    if not path.exists():
        return "NOT_EXISTS"
    if path.is_dir():
        return _directory_digest(path)
    return _file_digest(path)
