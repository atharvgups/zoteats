#!/usr/bin/env python3
"""Promote the previous TestFlight build to an External Testing group.

Intended flow after each CI upload of build N (what you're dogfooding):
  1. Wait until build N finishes App Store Connect processing.
  2. Find the prior VALID build (N-1).
  3. Attach that prior build to the external beta group and submit/notify.

External testers therefore track one behind the build you're actively testing,
while still getting automatic updates on every new upload.

Required env:
  APP_STORE_CONNECT_KEY_ID
  APP_STORE_CONNECT_ISSUER_ID
  APP_STORE_CONNECT_API_KEY_PATH  — path to AuthKey_*.p8

Optional env:
  BUNDLE_ID                      — default com.atharvgupta.zoteats
  BUILD_NUMBER                   — CFBundleVersion just uploaded (required to
                                   identify "current"; skips promote if unset)
  TESTFLIGHT_EXTERNAL_GROUP_NAME — default "Zot Eats Testers!"
  PROMOTE_WAIT_SECONDS           — max wait for processing (default 2400)
"""

from __future__ import annotations

import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timedelta, timezone
from pathlib import Path

try:
    import jwt  # PyJWT
except ImportError:
    sys.stderr.write("PyJWT is required: pip install PyJWT cryptography\n")
    sys.exit(1)


API = "https://api.appstoreconnect.apple.com"
BUNDLE_ID = os.environ.get("BUNDLE_ID", "com.atharvgupta.zoteats")
GROUP_NAME = os.environ.get("TESTFLIGHT_EXTERNAL_GROUP_NAME", "Zot Eats Testers!")
BUILD_NUMBER = os.environ.get("BUILD_NUMBER", "").strip()
MAX_WAIT = int(os.environ.get("PROMOTE_WAIT_SECONDS", "2400"))


def die(msg: str, code: int = 1) -> None:
    print(f"::error::{msg}", flush=True)
    sys.exit(code)


def info(msg: str) -> None:
    print(msg, flush=True)


def make_token() -> str:
    key_id = os.environ.get("APP_STORE_CONNECT_KEY_ID", "")
    issuer = os.environ.get("APP_STORE_CONNECT_ISSUER_ID", "")
    key_path = os.environ.get("APP_STORE_CONNECT_API_KEY_PATH", "")
    if not key_id or not issuer or not key_path:
        die("Missing APP_STORE_CONNECT_KEY_ID / ISSUER_ID / API_KEY_PATH")
    private_key = Path(key_path).read_text()
    now = datetime.now(timezone.utc)
    payload = {
        "iss": issuer,
        "iat": int(now.timestamp()),
        "exp": int((now + timedelta(minutes=15)).timestamp()),
        "aud": "appstoreconnect-v1",
    }
    return jwt.encode(
        payload,
        private_key,
        algorithm="ES256",
        headers={"kid": key_id, "typ": "JWT"},
    )


def api(
    method: str,
    path: str,
    token: str,
    body: dict | None = None,
    *,
    allow_statuses: set[int] | None = None,
) -> dict:
    url = path if path.startswith("http") else f"{API}{path}"
    data = None if body is None else json.dumps(body).encode()
    req = urllib.request.Request(
        url,
        data=data,
        method=method,
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
            "Accept": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            raw = resp.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", "replace")
        # 409 Conflict often means the relationship already exists — treat as ok.
        if exc.code == 409:
            info(f"ASC {method} {path} already applied (409): {detail[:300]}")
            return {"errors": [{"status": "409"}], "already_exists": True}
        if allow_statuses and exc.code in allow_statuses:
            return {
                "errors": [{"status": str(exc.code), "detail": detail[:800]}],
                "http_status": exc.code,
            }
        die(f"ASC {method} {path} failed ({exc.code}): {detail[:800]}")
    return {}


def find_app_id(token: str) -> str:
    q = urllib.parse.urlencode({"filter[bundleId]": BUNDLE_ID, "limit": 1})
    data = api("GET", f"/v1/apps?{q}", token)
    apps = data.get("data") or []
    if not apps:
        die(f"No App Store Connect app found for bundle id {BUNDLE_ID}")
    return apps[0]["id"]


def list_builds(token: str, app_id: str, limit: int = 30) -> list[dict]:
    q = urllib.parse.urlencode(
        {
            "filter[app]": app_id,
            "sort": "-uploadedDate",
            "limit": str(limit),
            "fields[builds]": "version,processingState,uploadedDate,expired",
        }
    )
    data = api("GET", f"/v1/builds?{q}", token)
    return data.get("data") or []


def wait_for_current_build(token: str, app_id: str) -> dict | None:
    """Poll until the just-uploaded BUILD_NUMBER is present and finished processing."""
    if not BUILD_NUMBER:
        return None
    deadline = time.time() + MAX_WAIT
    last_state = None
    while time.time() < deadline:
        for build in list_builds(token, app_id):
            attrs = build.get("attributes") or {}
            if str(attrs.get("version")) != str(BUILD_NUMBER):
                continue
            state = attrs.get("processingState")
            last_state = state
            info(f"Current build {BUILD_NUMBER}: processingState={state}")
            if state == "VALID":
                return build
            if state in {"INVALID", "FAILED"}:
                die(f"Current build {BUILD_NUMBER} ended in state {state}")
            break
        else:
            info(f"Waiting for build {BUILD_NUMBER} to appear in App Store Connect…")
        time.sleep(30)
    die(
        f"Timed out waiting for build {BUILD_NUMBER} "
        f"(last state={last_state}). External promote skipped."
    )


def previous_valid_builds(
    builds: list[dict], current_id: str | None, *, skip_ids: set[str] | None = None
) -> list[dict]:
    """Return prior VALID non-expired builds newest-first (N−1, N−2, …)."""
    skip = set(skip_ids or ())
    candidates: list[dict] = []
    for build in builds:
        build_id = build.get("id")
        if not build_id or build_id in skip:
            continue
        if current_id and build_id == current_id:
            continue
        attrs = build.get("attributes") or {}
        if attrs.get("expired"):
            continue
        if attrs.get("processingState") != "VALID":
            continue
        candidates.append(build)
    return candidates


def build_still_exists(token: str, build_id: str) -> bool:
    """Confirm ASC still has this build (list endpoints can briefly return stale ids)."""
    result = api("GET", f"/v1/builds/{build_id}", token, allow_statuses={404})
    if result.get("http_status") == 404:
        return False
    return bool(result.get("data"))


def find_external_group(token: str, app_id: str) -> dict:
    q = urllib.parse.urlencode({"filter[app]": app_id, "limit": 50})
    data = api("GET", f"/v1/betaGroups?{q}", token)
    groups = data.get("data") or []
    # Prefer exact name match among non-internal groups.
    for group in groups:
        attrs = group.get("attributes") or {}
        if attrs.get("isInternalGroup"):
            continue
        if attrs.get("name") == GROUP_NAME:
            return group
    # Fall back to the first external group if the preferred name isn't set up yet.
    external = [
        g for g in groups if not (g.get("attributes") or {}).get("isInternalGroup")
    ]
    if not external:
        die(
            f'No external TestFlight group found. Create a group named "{GROUP_NAME}" '
            "in App Store Connect → TestFlight → External Testing."
        )
    if GROUP_NAME:
        info(
            f'No group named "{GROUP_NAME}"; using "{external[0]["attributes"]["name"]}"'
        )
    return external[0]


def ensure_whats_new(token: str, build_id: str) -> None:
    """External distribution requires at least one beta build localization."""
    q = urllib.parse.urlencode({"filter[build]": build_id, "limit": 5})
    existing = api("GET", f"/v1/betaBuildLocalizations?{q}", token).get("data") or []
    if existing:
        return
    api(
        "POST",
        "/v1/betaBuildLocalizations",
        token,
        {
            "data": {
                "type": "betaBuildLocalizations",
                "attributes": {
                    "locale": "en-US",
                    "whatsNew": "Bug fixes and improvements.",
                },
                "relationships": {
                    "build": {"data": {"type": "builds", "id": build_id}}
                },
            }
        },
    )
    info("Created en-US What's New for the promoted build.")


def add_build_to_group(token: str, group_id: str, build_id: str) -> dict:
    """Attach build↔group. Try both relationship directions; ASC 404s are flaky."""
    group_first = api(
        "POST",
        f"/v1/betaGroups/{group_id}/relationships/builds",
        token,
        {"data": [{"type": "builds", "id": build_id}]},
        allow_statuses={404},
    )
    if group_first.get("http_status") != 404:
        return group_first

    detail = ""
    errors = group_first.get("errors") or []
    if errors:
        detail = str(errors[0].get("detail") or "")[:240]
    info(
        f"Group→build attach 404 for {build_id}"
        + (f": {detail}" if detail else "")
        + "; trying build→group."
    )

    return api(
        "POST",
        f"/v1/builds/{build_id}/relationships/betaGroups",
        token,
        {"data": [{"type": "betaGroups", "id": group_id}]},
        allow_statuses={404},
    )


def ensure_beta_review(token: str, build_id: str) -> dict:
    q = urllib.parse.urlencode({"filter[build]": build_id, "limit": 1})
    existing = api("GET", f"/v1/betaAppReviewSubmissions?{q}", token).get("data") or []
    if existing:
        state = (existing[0].get("attributes") or {}).get("betaReviewState")
        info(f"Beta review already present (state={state}).")
        return {"already_exists": True}
    return api(
        "POST",
        "/v1/betaAppReviewSubmissions",
        token,
        {
            "data": {
                "type": "betaAppReviewSubmissions",
                "relationships": {
                    "build": {"data": {"type": "builds", "id": build_id}}
                },
            }
        },
        allow_statuses={404},
    )


def promote_build(token: str, group_id: str, build: dict) -> bool:
    """Attach + submit one prior build. Returns False if ASC no longer has it."""
    build_id = build["id"]
    version = (build.get("attributes") or {}).get("version")
    if not build_still_exists(token, build_id):
        info(f"Skipping stale build id {build_id} (version={version}); not found in ASC.")
        return False

    ensure_whats_new(token, build_id)
    attach = add_build_to_group(token, group_id, build_id)
    if attach.get("http_status") == 404:
        info(f"ASC could not attach build {version} ({build_id}); trying older build.")
        return False
    if not attach.get("already_exists"):
        info("Attached previous build to the external group.")

    review = ensure_beta_review(token, build_id)
    if review.get("http_status") == 404:
        info(f"ASC could not submit build {version} ({build_id}) for beta review; trying older.")
        return False
    if review.get("already_exists"):
        pass
    else:
        info("Submitted previous build for external Beta App Review / distribution.")
    return True


def main() -> None:
    if not BUILD_NUMBER:
        die("BUILD_NUMBER env is required (CFBundleVersion just uploaded).")

    token = make_token()
    app_id = find_app_id(token)
    info(f"App {BUNDLE_ID} → {app_id}")

    current = wait_for_current_build(token, app_id)
    current_id = current["id"] if current else None
    group = find_external_group(token, app_id)
    group_id = group["id"]
    group_name = (group.get("attributes") or {}).get("name")
    info(f"External group: {group_name} ({group_id})")

    skip_ids: set[str] = set()
    # Refetch + walk N−1, N−2, … when ASC returns stale build ids (common after
    # force-retags of the same marketing version).
    for attempt in range(5):
        builds = list_builds(token, app_id, limit=50)
        candidates = previous_valid_builds(builds, current_id, skip_ids=skip_ids)
        if not candidates:
            info(
                "No previous VALID build to promote yet "
                "(first upload, or nothing older is ready). Skipping."
            )
            return

        previous = candidates[0]
        prev_attrs = previous.get("attributes") or {}
        prev_version = prev_attrs.get("version")
        info(
            f"Promoting previous build {prev_version} "
            f"(id={previous['id']}) to external testers; "
            f"keeping current {BUILD_NUMBER} for internal dogfooding"
            + (f" (attempt {attempt + 1})." if attempt else ".")
        )

        if promote_build(token, group_id, previous):
            info(
                "Done. External testers will get build "
                f"{prev_version} once review/notify completes."
            )
            return

        skip_ids.add(previous["id"])
        time.sleep(5)

    die(
        "Could not promote any previous VALID build to External Testing "
        f"(skipped stale ids: {sorted(skip_ids)})."
    )


if __name__ == "__main__":
    main()
