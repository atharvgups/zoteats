#!/usr/bin/env python3
"""Cancel one in-flight App Store review submission (WAITING_FOR_REVIEW / IN_REVIEW).

Atharv-explicit: pull TARGET_VERSION off App Review so it does not go live.
Does NOT submit a replacement. Does NOT touch READY_FOR_SALE (live 1.0.298).

Required env:
  APP_STORE_CONNECT_KEY_ID
  APP_STORE_CONNECT_ISSUER_ID
  APP_STORE_CONNECT_API_KEY_PATH

Optional env:
  BUNDLE_ID                 — default com.atharvgupta.zoteats
  TARGET_VERSION            — default 1.0.300
  PROTECTED_LIVE_VERSION    — default 1.0.298 (never cancel this)
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
    import jwt
except ImportError:
    sys.stderr.write("PyJWT required: pip install 'PyJWT[crypto]'\n")
    sys.exit(1)

API = "https://api.appstoreconnect.apple.com"
BUNDLE_ID = os.environ.get("BUNDLE_ID", "com.atharvgupta.zoteats")
TARGET_VERSION = os.environ.get("TARGET_VERSION", "1.0.300").strip()
PROTECTED_LIVE_VERSION = os.environ.get("PROTECTED_LIVE_VERSION", "1.0.298").strip()

IN_FLIGHT = {"WAITING_FOR_REVIEW", "IN_REVIEW", "PROCESSING_FOR_REVIEW"}
PROTECTED_STATES = {
    "READY_FOR_SALE",
    "PENDING_APPLE_RELEASE",
    "PROCESSING_FOR_APP_STORE",
    "READY_FOR_DISTRIBUTION",
}
DONE_SUB_STATES = {"COMPLETE", "COMPLETED", "CANCELED", "CANCELLED"}


def die(msg: str) -> None:
    print(f"::error::{msg}", flush=True)
    sys.exit(1)


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
    return jwt.encode(
        {
            "iss": issuer,
            "iat": int(now.timestamp()),
            "exp": int((now + timedelta(minutes=15)).timestamp()),
            "aud": "appstoreconnect-v1",
        },
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
    ok_codes: set[int] | None = None,
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
    ok = ok_codes or {200, 201, 204}
    try:
        with urllib.request.urlopen(req, timeout=90) as resp:
            raw = resp.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", "replace")
        if exc.code in (ok_codes or set()) or exc.code in ok:
            return json.loads(detail) if detail else {}
        die(f"ASC {method} {path} failed ({exc.code}): {detail[:1500]}")


def version_of(row: dict) -> tuple[str, str]:
    attrs = row.get("attributes") or {}
    return str(attrs.get("versionString") or ""), str(attrs.get("appStoreState") or "")


def resolve_submission_version(token: str, sub: dict, versions_by_id: dict[str, dict]) -> str:
    rel = ((sub.get("relationships") or {}).get("appStoreVersionForReview") or {}).get("data") or {}
    vid = rel.get("id")
    if vid and vid in versions_by_id:
        return version_of(versions_by_id[vid])[0]
    if vid:
        linked = api("GET", f"/v1/appStoreVersions/{vid}", token, ok_codes={200, 404})
        data = linked.get("data") or {}
        if data:
            return version_of(data)[0]
    items = api(
        "GET",
        f"/v1/reviewSubmissions/{sub['id']}/items?include=appStoreVersion&limit=20",
        token,
        ok_codes={200, 404},
    )
    included = {
        row["id"]: row
        for row in (items.get("included") or [])
        if row.get("type") == "appStoreVersions"
    }
    for item in items.get("data") or []:
        irel = ((item.get("relationships") or {}).get("appStoreVersion") or {}).get("data") or {}
        iid = irel.get("id")
        if iid and iid in included:
            return version_of(included[iid])[0]
        if iid and iid in versions_by_id:
            return version_of(versions_by_id[iid])[0]
    return ""


def cancel_submission(token: str, sid: str, state: str) -> None:
    info(f"Canceling reviewSubmission {sid} (state={state})…")
    result = api(
        "PATCH",
        f"/v1/reviewSubmissions/{sid}",
        token,
        {
            "data": {
                "type": "reviewSubmissions",
                "id": sid,
                "attributes": {"canceled": True},
            }
        },
        ok_codes={200, 409, 422},
    )
    if result.get("errors") and not result.get("data"):
        die(
            "ASC refused to cancel the in-flight review submission via API. "
            f"Detail: {json.dumps(result)[:1500]}"
        )
    deadline = time.time() + 180
    while time.time() < deadline:
        detail = api("GET", f"/v1/reviewSubmissions/{sid}", token, ok_codes={200, 404})
        new_state = ((detail.get("data") or {}).get("attributes") or {}).get("state")
        info(f"Cancel poll: {sid} → {new_state}")
        if new_state in DONE_SUB_STATES or new_state is None:
            return
        if new_state == "CANCELING":
            time.sleep(5)
            continue
        time.sleep(5)
    info(f"Cancel of {sid} still settling; check ASC status.")


def main() -> None:
    if not TARGET_VERSION:
        die("TARGET_VERSION is empty")
    token = make_token()
    q = urllib.parse.urlencode({"filter[bundleId]": BUNDLE_ID, "limit": 1})
    apps = api("GET", f"/v1/apps?{q}", token).get("data") or []
    if not apps:
        die(f"No app for {BUNDLE_ID}")
    app_id = apps[0]["id"]
    info(f"App {BUNDLE_ID} → {app_id}")
    info(f"Cancel target={TARGET_VERSION}; protect live={PROTECTED_LIVE_VERSION}")

    vq = urllib.parse.urlencode(
        {
            "filter[platform]": "IOS",
            "limit": "20",
            "fields[appStoreVersions]": "versionString,appStoreState",
        }
    )
    versions = api("GET", f"/v1/apps/{app_id}/appStoreVersions?{vq}", token).get("data") or []
    versions_by_id = {v["id"]: v for v in versions}

    target_state = ""
    live_ok = False
    for v in versions:
        ver, state = version_of(v)
        info(f"version={ver} appStoreState={state}")
        if ver == PROTECTED_LIVE_VERSION and state in PROTECTED_STATES:
            live_ok = True
        if ver == TARGET_VERSION:
            target_state = state
            if state in PROTECTED_STATES:
                die(
                    f"{TARGET_VERSION} is {state}. Refusing to cancel a live/releasing version. "
                    "PROTECTED_LIVE_VERSION must stay on the store."
                )

    if TARGET_VERSION == PROTECTED_LIVE_VERSION:
        die("TARGET_VERSION is the protected live version — refusing.")
    if not live_ok:
        info(
            f"Note: {PROTECTED_LIVE_VERSION} was not listed as READY_FOR_SALE in this page; "
            "still refusing to cancel any READY_FOR_SALE submission."
        )

    if target_state and target_state not in IN_FLIGHT:
        info(
            f"{TARGET_VERSION} is already {target_state} — not in App Review. Nothing to cancel."
        )
        return

    sq = urllib.parse.urlencode(
        {
            "filter[app]": app_id,
            "filter[platform]": "IOS",
            "limit": "10",
            "include": "appStoreVersionForReview",
        }
    )
    payload = api("GET", f"/v1/reviewSubmissions?{sq}", token, ok_codes={200, 400})
    if payload.get("errors"):
        sq = urllib.parse.urlencode(
            {"filter[app]": app_id, "filter[platform]": "IOS", "limit": "10"}
        )
        payload = api("GET", f"/v1/reviewSubmissions?{sq}", token)
    for row in payload.get("included") or []:
        if row.get("type") == "appStoreVersions":
            versions_by_id.setdefault(row["id"], row)

    canceled = 0
    for sub in payload.get("data") or []:
        state = (sub.get("attributes") or {}).get("state")
        ver = resolve_submission_version(token, sub, versions_by_id)
        info(f"reviewSubmission id={sub.get('id')} state={state} version={ver or '—'}")
        if state not in IN_FLIGHT:
            continue
        if ver == PROTECTED_LIVE_VERSION:
            die(f"Refusing to cancel a review submission linked to live {PROTECTED_LIVE_VERSION}")
        if ver and ver != TARGET_VERSION:
            info(f"Skipping {sub.get('id')} — linked to {ver}, not {TARGET_VERSION}")
            continue
        if not ver and target_state not in IN_FLIGHT:
            info(f"Skipping {sub.get('id')} — version unresolved and target not in review")
            continue
        if not ver:
            info(
                f"Version unresolved on {sub.get('id')}; {TARGET_VERSION} is {target_state or 'missing'} "
                "so canceling this in-flight submission."
            )
        cancel_submission(token, sub["id"], str(state))
        canceled += 1

    if canceled == 0 and target_state in IN_FLIGHT:
        die(
            f"{TARGET_VERSION} is still {target_state} but no matching reviewSubmission was canceled. "
            "Check App Store Connect → App Review."
        )
    if canceled == 0:
        info("No in-flight review submission matched the target. Done.")
        return
    info(f"Canceled {canceled} review submission(s) for {TARGET_VERSION}. No replacement submitted.")


if __name__ == "__main__":
    main()
