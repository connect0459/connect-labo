import json
from pathlib import Path


def merge(source_path: Path, target_path: Path) -> None:
    source_path, target_path = Path(source_path), Path(target_path)
    source_map: dict = json.loads(source_path.read_text(encoding="utf-8"))

    target_map: dict = {}
    if target_path.exists():
        try:
            target_map = json.loads(target_path.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError, UnicodeDecodeError):
            pass

    target_map.update(source_map)

    target_path.write_text(json.dumps(target_map, indent=2) + "\n")
