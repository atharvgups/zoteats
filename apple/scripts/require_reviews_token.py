#!/usr/bin/env python3
"""Fail a release build when ZOTEATS_REVIEWS_TOKEN is empty.

Used by TestFlight and Android workflows. Reads:
  ZOTEATS_REVIEWS_TOKEN
  ZOTEATS_REQUIRE_REVIEWS_TOKEN  (true/1/yes to fail closed)

If the token is empty and require is true, exit 1 so we never ship a build
that silently drops student reports.
If the token is empty and require is not set, print a warning and exit 0
so the guard can land before the secret exists.
If the token is present, exit 0.
"""

from __future__ import annotations

import os
import sys


def is_required(raw: str) -> bool:
    return raw.strip().lower() in {"1", "true", "yes", "on"}


def check_token(token: str, require: str) -> tuple[int, str]:
    if token.strip():
        return 0, "ZOTEATS_REVIEWS_TOKEN is set"
    message = (
        "ZOTEATS_REVIEWS_TOKEN is empty. Student reports, Other notes, and "
        "ratings will not leave the phone. Add a fine-grained PAT (this repo, "
        "Contents: Read and write) at Settings -> Secrets and variables -> "
        "Actions, then set variable ZOTEATS_REQUIRE_REVIEWS_TOKEN=true."
    )
    if is_required(require):
        return 1, f"::error::{message}"
    return 0, f"::warning::{message}"


def main() -> int:
    code, line = check_token(
        os.environ.get("ZOTEATS_REVIEWS_TOKEN", ""),
        os.environ.get("ZOTEATS_REQUIRE_REVIEWS_TOKEN")
        or os.environ.get("REQUIRE_REVIEWS_TOKEN", ""),
    )
    print(line)
    return code


if __name__ == "__main__":
    sys.exit(main())
