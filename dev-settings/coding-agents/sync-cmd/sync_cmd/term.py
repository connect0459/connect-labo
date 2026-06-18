import sys

_enabled = sys.stdout.isatty()


def _wrap(code: str, s: str) -> str:
    if not _enabled:
        return s
    return f"\033[{code}m{s}\033[0m"


def bold(s: str) -> str:
    return _wrap("1", s)


def dim(s: str) -> str:
    return _wrap("2", s)


def red(s: str) -> str:
    return _wrap("31", s)


def green(s: str) -> str:
    return _wrap("32", s)


def cyan(s: str) -> str:
    return _wrap("36", s)


def bold_green(s: str) -> str:
    return _wrap("1;32", s)
