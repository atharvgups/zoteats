#!/usr/bin/env python3
"""Merge one community review into apple/community-reviews.json.

Used by .github/workflows/reviews-ingest.yml. Payload JSON:
  dishName, stars, note, authorID, authorLabel, updatedAt (optional ISO-8601)
stars <= 0 removes that author's review for the dish.
"""

from __future__ import annotations

import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FEED = ROOT / "apple" / "community-reviews.json"


def key(name: str) -> str:
    return name.strip().lower()


def review_id(item: dict) -> str:
    author = (item.get("authorID") or "local").strip() or "local"
    return f"{key(item.get('dishName') or '')}|{author}"


def load_feed() -> list[dict]:
    if not FEED.is_file():
        return []
    raw = json.loads(FEED.read_text())
    if isinstance(raw, dict):
        return list(raw.get("reviews") or [])
    if isinstance(raw, list):
        return raw
    return []


def save_feed(reviews: list[dict]) -> None:
    reviews = sorted(
        reviews,
        key=lambda item: (item.get("updatedAt") or "", item.get("dishName") or ""),
        reverse=True,
    )
    FEED.write_text(json.dumps({"reviews": reviews}, indent=2) + "\n")


def main() -> int:
    payload_raw = os.environ.get("REVIEW_PAYLOAD", "").strip()
    if not payload_raw:
        print("REVIEW_PAYLOAD is empty", file=sys.stderr)
        return 1
    payload = json.loads(payload_raw)
    dish = str(payload.get("dishName") or "").strip()
    author = str(payload.get("authorID") or "").strip()
    if not dish or not author:
        print("dishName and authorID are required", file=sys.stderr)
        return 1
    stars = int(payload.get("stars") or 0)
    existing = load_feed()
    wanted = f"{key(dish)}|{author}"
    kept = [item for item in existing if review_id(item) != wanted]
    if stars > 0:
        kept.append(
            {
                "dishName": dish,
                "stars": max(1, min(5, stars)),
                "note": str(payload.get("note") or "")[:280],
                "updatedAt": str(payload.get("updatedAt") or datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")),
                "authorID": author,
                "authorLabel": str(payload.get("authorLabel") or "Anteater"),
            }
        )
    save_feed(kept)
    print(f"Wrote {len(kept)} reviews to {FEED}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
