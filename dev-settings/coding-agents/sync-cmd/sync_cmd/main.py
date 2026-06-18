import sys
from pathlib import Path

from sync_cmd import checksum, dirsync, permissions, symlink, term


def main() -> None:
    sys.exit(run())


def run() -> int:
    source_dir = Path(__file__).resolve().parent.parent.parent

    home = Path.home()
    central_dir = home / ".connect0459" / "coding-agents"
    claude_dir = home / ".claude"
    github_dir = home / ".github"

    source_agents_md = source_dir / "AGENTS.md"
    source_agent_docs = source_dir / "agent-docs"
    source_settings = source_dir / "dot-claude" / "settings.json"

    central_agents_md = central_dir / "AGENTS.md"
    central_agent_docs = central_dir / "agent-docs"

    claude_md = claude_dir / "CLAUDE.md"
    claude_settings = claude_dir / "settings.json"
    copilot_instructions = github_dir / "copilot-instructions.md"

    print(term.bold("Coding agents configuration sync tool"))
    print(f"{term.dim('Source:')}  {source_dir}")
    print(f"{term.dim('Central:')} {central_dir}")
    print(f"{term.dim('Claude:')}  {claude_dir}")
    print()

    before = {
        "agents_md": checksum.of(central_agents_md),
        "agent_docs": checksum.of(central_agent_docs),
        "settings": checksum.of(claude_settings),
    }

    central_agent_docs.mkdir(parents=True, exist_ok=True)
    claude_dir.mkdir(parents=True, exist_ok=True)
    github_dir.mkdir(parents=True, exist_ok=True)

    print(term.cyan("Syncing AGENTS.md to central location"))
    try:
        dirsync.copy_file(source_agents_md, central_agents_md)
    except Exception as e:
        print(term.red(f"failed to copy AGENTS.md: {e}"), file=sys.stderr)
        return 1

    print(term.cyan("Syncing agent-docs directory to central location"))
    try:
        dirsync.sync(source_agent_docs, central_agent_docs)
    except Exception as e:
        print(term.red(f"failed to sync agent-docs: {e}"), file=sys.stderr)
        return 1

    settings_exists = source_settings.exists()
    if settings_exists:
        print(term.cyan("Syncing settings from settings.json"))
        try:
            permissions.merge(source_settings, claude_settings)
        except Exception as e:
            print(term.red(f"failed to merge settings: {e}"), file=sys.stderr)
            return 1

    print()
    print(term.cyan("Setting up symlinks..."))
    try:
        symlink.setup(central_agents_md, claude_md)
    except Exception as e:
        print(term.red(f"failed to setup symlink for CLAUDE.md: {e}"), file=sys.stderr)
        return 1
    print(f"  {claude_md} -> {central_agents_md}")

    try:
        symlink.setup(central_agents_md, copilot_instructions)
    except Exception as e:
        print(term.red(f"failed to setup symlink for copilot-instructions.md: {e}"), file=sys.stderr)
        return 1
    print(f"  {copilot_instructions} -> {central_agents_md}")
    print()

    after = {
        "agents_md": checksum.of(central_agents_md),
        "agent_docs": checksum.of(central_agent_docs),
        "settings": checksum.of(claude_settings),
    }

    separator = term.dim("━" * 38)
    print(separator)
    print(term.bold("Change Detection Report"))
    print(separator)

    items: list[tuple[str, str, str]] = [
        ("AGENTS.md", "agents_md", "docs"),
        ("agent-docs/", "agent_docs", "docs"),
    ]
    if settings_exists:
        items.append(("settings.json", "settings", "docs"))

    rows: list[tuple[str, str, str, bool]] = []
    has_changes = False
    for name, key, item_type in items:
        if before[key] != after[key]:
            rows.append(("✓", item_type, name, True))
            has_changes = True
        else:
            rows.append(("-", item_type, name, False))

    if _is_symlink(claude_md):
        rows.append(("✓", "symlink", "Claude", True))
        has_changes = True
    if _is_symlink(copilot_instructions):
        rows.append(("✓", "symlink", "GitHub Copilot", True))
        has_changes = True

    headers = ("Status", "Type", "Name")
    widths = [len(h) for h in headers]
    for status, item_type, name, _ in rows:
        widths[0] = max(widths[0], len(status))
        widths[1] = max(widths[1], len(item_type))
        widths[2] = max(widths[2], len(name))
    w0, w1, w2 = widths

    def sep(left: str, mid: str, right: str, fill: str) -> str:
        return left + fill * (w0 + 2) + mid + fill * (w1 + 2) + mid + fill * (w2 + 2) + right

    print(term.dim(sep("┌", "┬", "┐", "─")))
    print(f"│ {headers[0]:<{w0}} │ {headers[1]:<{w1}} │ {headers[2]:<{w2}} │")
    print(term.dim(sep("├", "┼", "┤", "─")))
    for status, item_type, name, changed in rows:
        row_line = f"│ {status:<{w0}} │ {item_type:<{w1}} │ {name:<{w2}} │"
        print(term.green(row_line) if changed else term.dim(row_line))
    print(term.dim(sep("└", "┴", "┘", "─")))

    if has_changes:
        print(term.bold_green("✓ Changes were applied successfully"))
    else:
        print(term.bold_green("✓ All files were already up to date"))

    return 0


def _is_symlink(path: Path) -> bool:
    try:
        return path.is_symlink()
    except Exception:
        return False
