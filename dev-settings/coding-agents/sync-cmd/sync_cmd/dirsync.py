import shutil
from pathlib import Path


def sync(src: Path, dst: Path) -> None:
    src, dst = Path(src), Path(dst)
    if dst.is_dir():
        _delete_extra_files(src, dst)
        _delete_empty_dirs(dst)
    _copy_tree(src, dst)


def copy_file(src: Path, dst: Path) -> None:
    src, dst = Path(src), Path(dst)
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)


def _delete_extra_files(src: Path, dst: Path) -> None:
    for path in list(dst.rglob("*")):
        if path.is_file():
            rel = path.relative_to(dst)
            if not (src / rel).exists():
                path.unlink()


def _delete_empty_dirs(dst: Path) -> None:
    dirs = sorted(
        [p for p in dst.rglob("*") if p.is_dir() and p != dst],
        key=lambda d: len(d.parts),
        reverse=True,
    )
    for d in dirs:
        if not any(d.iterdir()):
            d.rmdir()


def _copy_tree(src: Path, dst: Path) -> None:
    for path in src.rglob("*"):
        rel = path.relative_to(src)
        target = dst / rel
        if path.is_dir():
            target.mkdir(parents=True, exist_ok=True)
        else:
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, target)
