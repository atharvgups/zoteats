#!/usr/bin/env python3
"""Refuse em dashes in Android user-facing copy."""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SKIP_DIRS = {".gradle", "build", ".idea"}
EM = "\u2014"
EN = "\u2013"


def main() -> int:
    bad: list[str] = []
    for path in ROOT.rglob("*"):
        if not path.is_file():
            continue
        if any(part in SKIP_DIRS for part in path.parts):
            continue
        if path.suffix not in {".kt", ".xml", ".kts", ".md", ".sh", ".py", ".json"}:
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        if EM in text or EN in text:
            bad.append(str(path.relative_to(ROOT)))
    if bad:
        print("Em dash or en dash in Android copy:")
        for item in bad:
            print(f"  {item}")
        return 1
    print("Android copy has no em dashes.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
