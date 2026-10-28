#!/usr/bin/env python3
"""Merge one dish-wrong report into apple/community-dish-reports.json.

Used by .github/workflows/reports-ingest.yml. Payload JSON:
  date, hall, meal, dishID, dishName, reason, authorID, updatedAt (optional ISO-8601)
"""

from __future__ import annotations

import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FEED = ROOT / "apple" / "community-dish-reports.json"

REASONS = {"notAtHall", "notServed", "wrongStation"}


def canonical_hall(hall: str) -> str:
    trimmed = hall.strip().lower()
    if trimmed in {"oasis", "the-oasis", "the-oasis-dining-hall"}:
        return "oasis"
    if trimmed == "the-anteatery":
        return "anteatery"
    return trimmed


def canonical_meal(meal: str) -> str:
    lower = meal.strip().lower()
    if "brunch" in lower or "breakfast" in lower:
        return "Breakfast"
    if "lunch" in lower:
        return "Lunch"
    if "dinner" in lower:
        return "Dinner"
    if "afternoon snack" in lower or (
        "snack" in lower and "evening" not in lower and "late" not in lower
    ):
        return "Afternoon Snack"
    if "late night" in lower or "evening snack" in lower or "overnight" in lower:
        return "Late Night"
    return meal.strip()


def canonical_dish_id(dish_id: str, dish_name: str) -> str:
    trimmed = dish_id.strip()
    if trimmed:
        return trimmed
    name = dish_name.strip().lower()
    return f"name:{name}" if name else ""


def listing_key(item: dict) -> str:
    return "|".join(
        [
            str(item.get("date") or "").strip(),
            canonical_hall(str(item.get("hall") or "")),
            canonical_meal(str(item.get("meal") or "")).lower(),
            canonical_dish_id(str(item.get("dishID") or ""), str(item.get("dishName") or "")).lower(),
        ]
    )


def report_id(item: dict) -> str:
    author = str(item.get("authorID") or "").strip()
    return f"{listing_key(item)}|{author}"


def load_feed() -> list[dict]:
    if not FEED.is_file():
        return []
    raw = json.loads(FEED.read_text())
    if isinstance(raw, dict):
        return list(raw.get("reports") or [])
    if isinstance(raw, list):
        return raw
    return []


def save_feed(reports: list[dict]) -> None:
    reports = sorted(
        reports,
        key=lambda item: (item.get("updatedAt") or "", item.get("dishName") or ""),
        reverse=True,
    )
    FEED.write_text(json.dumps({"reports": reports}, indent=2) + "\n")


def main() -> int:
    payload_raw = os.environ.get("REPORT_PAYLOAD", "").strip()
    if not payload_raw:
        print("REPORT_PAYLOAD is empty", file=sys.stderr)
        return 1
    payload = json.loads(payload_raw)
    date = str(payload.get("date") or "").strip()
    hall = canonical_hall(str(payload.get("hall") or ""))
    meal = canonical_meal(str(payload.get("meal") or ""))
    dish_name = str(payload.get("dishName") or "").strip()
    dish_id = canonical_dish_id(str(payload.get("dishID") or ""), dish_name)
    author = str(payload.get("authorID") or "").strip()
    reason = str(payload.get("reason") or "").strip()
    if not date or not hall or not meal or not dish_id or not author:
        print("date, hall, meal, dishID, and authorID are required", file=sys.stderr)
        return 1
    if reason not in REASONS:
        print(f"unknown reason {reason!r}", file=sys.stderr)
        return 1
    existing = load_feed()
    wanted = report_id(
        {
            "date": date,
            "hall": hall,
            "meal": meal,
            "dishID": dish_id,
            "dishName": dish_name,
            "authorID": author,
        }
    )
    kept = [item for item in existing if report_id(item) != wanted]
    kept.append(
        {
            "date": date,
            "hall": hall,
            "meal": meal,
            "dishID": dish_id,
            "dishName": dish_name,
            "reason": reason,
            "authorID": author,
            "updatedAt": str(
                payload.get("updatedAt")
                or datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
            ),
        }
    )
    save_feed(kept)
    print(f"Wrote {len(kept)} reports to {FEED}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
