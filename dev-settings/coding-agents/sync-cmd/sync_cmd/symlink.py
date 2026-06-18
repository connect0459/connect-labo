from pathlib import Path


def setup(target: Path, link: Path) -> None:
    target, link = Path(target), Path(link)
    if link.exists() or link.is_symlink():
        link.unlink()
    link.symlink_to(target)
