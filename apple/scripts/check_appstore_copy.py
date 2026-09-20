#!/usr/bin/env python3
"""Refuse App Store listing copy that uses em dashes.

Atharv rule: no em dashes (U+2014) in App Store metadata, release notes,
or What's New. Prefer short human sentences with commas or periods.

Used by:
  - apple/scripts/submit_app_store.py (appstore-* ships)
  - apple/scripts/patch_listing.py (metadata-only ASC patch)
  - CI: python3 apple/scripts/check_appstore_copy.py
"""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path

EM_DASH = "\u2014"
LISTING_FIELDS = (
    "name",
    "subtitle",
    "keywords",
    "promotional_text",
    "description",
    "whats_new",
    "review_notes",
    "copyright",
)


def listing_em_dash_fields(meta: dict) -> list[str]:
    hits: list[str] = []
    for key in LISTING_FIELDS:
        value = meta.get(key)
        if isinstance(value, str) and EM_DASH in value:
            hits.append(key)
    return hits


def load_metadata(path: Path) -> dict:
    if not path.is_file():
        raise FileNotFoundError(f"Missing metadata file: {path}")
    return json.loads(path.read_text())


def main() -> int:
    path = Path(os.environ.get("METADATA_PATH", "apple/AppStore/metadata.json"))
    try:
        meta = load_metadata(path)
    except (OSError, json.JSONDecodeError) as exc:
        print(f"::error::{exc}", flush=True)
        return 1
    bad = listing_em_dash_fields(meta)
    if bad:
        print(
            "::error::App Store listing copy contains em dashes (U+2014) in: "
            + ", ".join(bad)
            + ". Rewrite with commas or periods. No em dashes in metadata, "
            "release notes, or What's New.",
            flush=True,
        )
        return 1
    print(f"App Store listing copy is clean (no em dashes) in {path}.", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
