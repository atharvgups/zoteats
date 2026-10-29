#!/usr/bin/env python3
"""POST an Other dish note to the feedback webhook.

Used by .github/workflows/feedback-ingest.yml. Reads:
  FEEDBACK_PAYLOAD               JSON from repository_dispatch client_payload
  ANTEATS_FEEDBACK_WEBHOOK_URL   webhook URL (repo variable or secret)
  ANTEATS_FEEDBACK_WEBHOOK_KEY   sent as the Authorization header (repo secret)

If the URL is missing, exits 0 without posting so the app can still show
Thanks, noted. The URL and key never ship in the iOS or Android binary.
"""

from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.request

MAX_CHARACTERS = 500


def clipped(text: str) -> str:
    return text.strip()[:MAX_CHARACTERS]


def webhook_body(payload: dict) -> dict:
    return {
        "text": clipped(str(payload.get("text") or "")),
        "dish": str(payload.get("dishName") or payload.get("dish") or "").strip(),
        "hall": str(payload.get("hall") or "").strip(),
        "meal": str(payload.get("meal") or "").strip(),
        "date": str(payload.get("date") or "").strip(),
    }


def post_feedback(
    url: str,
    key: str,
    payload: dict,
    opener=None,
) -> int:
    body = webhook_body(payload)
    if not body["text"]:
        print("Feedback text is empty; skipping")
        return 0
    trimmed_url = url.strip()
    if not trimmed_url:
        print("ANTEATS_FEEDBACK_WEBHOOK_URL missing; skipping")
        return 0
    data = json.dumps(body).encode("utf-8")
    request = urllib.request.Request(trimmed_url, data=data, method="POST")
    request.add_header("Content-Type", "application/json")
    request.add_header("User-Agent", "Anteats/1.0 (UCI student utility)")
    trimmed_key = key.strip()
    if trimmed_key:
        request.add_header("Authorization", trimmed_key)
    open_url = opener or urllib.request.urlopen
    try:
        with open_url(request, timeout=20) as response:
            status = getattr(response, "status", 200)
            print(f"Webhook POST {status}")
            return 0 if 200 <= int(status) < 300 else 1
    except urllib.error.HTTPError as error:
        print(f"Webhook POST failed HTTP {error.code}", file=sys.stderr)
        return 1
    except urllib.error.URLError as error:
        print(f"Webhook POST failed: {error.reason}", file=sys.stderr)
        return 1


def main() -> int:
    raw = os.environ.get("FEEDBACK_PAYLOAD", "").strip()
    if not raw:
        print("FEEDBACK_PAYLOAD is empty", file=sys.stderr)
        return 1
    payload = json.loads(raw)
    return post_feedback(
        url=os.environ.get("ANTEATS_FEEDBACK_WEBHOOK_URL", ""),
        key=os.environ.get("ANTEATS_FEEDBACK_WEBHOOK_KEY", ""),
        payload=payload,
    )


if __name__ == "__main__":
    sys.exit(main())
