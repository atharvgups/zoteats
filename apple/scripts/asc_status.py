#!/usr/bin/env python3
"""Read-only App Store Connect status for Anteats. No submit / cancel / mutate.

Never cancel WAITING_FOR_REVIEW / IN_REVIEW, and never replace a live READY_FOR_SALE.

Launch-loop peek 2026-09-02 ~3:10 PT — read-only. Confirm 1.0.287 live and 1.0.291 still waiting/in review. Leave in-flight. Do not submit Internal. Never cancel live READY_FOR_SALE.
"""

from __future__ import annotations

import json
import os
import sys
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


def die(msg: str) -> None:
    print(f"::error::{msg}", flush=True)
    sys.exit(1)


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


def api(method: str, path: str, token: str, ok_empty: bool = False) -> dict:
    req = urllib.request.Request(
        f"{API}{path}",
        method=method,
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            raw = resp.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", "replace")
        if ok_empty and exc.code in {404, 403}:
            return {}
        die(f"ASC {method} {path} failed ({exc.code}): {detail[:800]}")


def _days_ago(iso: str | None) -> str:
    if not iso:
        return ""
    try:
        submitted = datetime.fromisoformat(iso.replace("Z", "+00:00"))
    except ValueError:
        return ""
    hours = (datetime.now(timezone.utc) - submitted).total_seconds() / 3600
    return f" (~{hours / 24:.1f}d)"


def main() -> None:
    token = make_token()
    q = urllib.parse.urlencode({"filter[bundleId]": BUNDLE_ID, "limit": 1})
    apps = api("GET", f"/v1/apps?{q}", token).get("data") or []
    if not apps:
        die(f"No app for {BUNDLE_ID}")
    app_id = apps[0]["id"]
    print(f"App {BUNDLE_ID} → {app_id}", flush=True)

    vq = urllib.parse.urlencode(
        {
            "filter[platform]": "IOS",
            "limit": "15",
            "fields[appStoreVersions]": "versionString,appStoreState,createdDate",
            "include": "build",
            "fields[builds]": "version,processingState,uploadedDate",
        }
    )
    versions = api("GET", f"/v1/apps/{app_id}/appStoreVersions?{vq}", token)
    builds_by_id = {
        b["id"]: b for b in (versions.get("included") or []) if b.get("type") == "builds"
    }

    print("--- appStoreVersions ---", flush=True)
    waiting = []
    for v in versions.get("data") or []:
        attrs = v.get("attributes") or {}
        rel = ((v.get("relationships") or {}).get("build") or {}).get("data") or {}
        build = builds_by_id.get(rel.get("id") or "")
        battrs = (build or {}).get("attributes") or {}
        build_no = battrs.get("version")
        if not build_no and rel.get("id"):
            linked = api("GET", f"/v1/builds/{rel['id']}", token, ok_empty=True)
            build_no = ((linked.get("data") or {}).get("attributes") or {}).get("version")
        if not build_no:
            linked = api(
                "GET",
                f"/v1/appStoreVersions/{v['id']}/build",
                token,
                ok_empty=True,
            )
            build_no = ((linked.get("data") or {}).get("attributes") or {}).get("version")
        print(
            f"version={attrs.get('versionString')} "
            f"appStoreState={attrs.get('appStoreState')} "
            f"build={build_no or '—'} "
            f"buildProcessing={battrs.get('processingState') or '—'}",
            flush=True,
        )
        if attrs.get("appStoreState") in {
            "WAITING_FOR_REVIEW",
            "IN_REVIEW",
            "PROCESSING_FOR_REVIEW",
        }:
            waiting.append((v["id"], attrs.get("versionString"), attrs.get("appStoreState")))

    sq = urllib.parse.urlencode(
        {"filter[app]": app_id, "filter[platform]": "IOS", "limit": "10"}
    )
    subs = api("GET", f"/v1/reviewSubmissions?{sq}", token).get("data") or []
    print("--- reviewSubmissions ---", flush=True)
    if not subs:
        print("(none)", flush=True)
    in_flight = False
    for sub in subs:
        attrs = sub.get("attributes") or {}
        state = attrs.get("state")
        submitted = attrs.get("submittedDate")
        print(
            f"id={sub.get('id')} state={state} "
            f"created={attrs.get('createdDate')} submitted={submitted}"
            f"{_days_ago(submitted)}",
            flush=True,
        )
        items = api(
            "GET", f"/v1/reviewSubmissions/{sub['id']}/items?limit=20", token, ok_empty=True
        ).get("data") or []
        print(f"  items={len(items)}", flush=True)
        for item in items:
            iattrs = item.get("attributes") or {}
            print(f"  item state={iattrs.get('state')}", flush=True)
        if state in {"WAITING_FOR_REVIEW", "IN_REVIEW", "PROCESSING_FOR_REVIEW"}:
            in_flight = True

    print("--- bottleneck ---", flush=True)
    states = [
        ((v.get("attributes") or {}).get("versionString"), (v.get("attributes") or {}).get("appStoreState"))
        for v in (versions.get("data") or [])
    ]
    pending_release = [s for s in states if s[1] in {"PENDING_DEVELOPER_RELEASE", "ACCEPTED"}]
    live = [s for s in states if s[1] in {"READY_FOR_SALE", "PENDING_APPLE_RELEASE", "PROCESSING_FOR_APP_STORE"}]
    if pending_release:
        ver, state = pending_release[0]
        print(
            f"{ver} is {state} (approved, not on sale yet). "
            "Push appstore-* to release it, then submit the current TestFlight train. "
            "Do not cancel.",
            flush=True,
        )
    elif live and not in_flight:
        ver, state = live[0]
        print(
            f"{ver} is {state}. Public store is live. "
            "Next update: push appstore-<newer> against the current TestFlight train.",
            flush=True,
        )
    elif in_flight:
        print(
            "App Review is still in flight. Do not cancel an approved first version. "
            "Wait for Pending Developer Release / Ready for Sale, then push appstore-*.",
            flush=True,
        )
    elif waiting:
        print(f"Version still listed as {waiting[0][2]} — check items above.", flush=True)
    else:
        print("No in-flight App Review submission.", flush=True)


if __name__ == "__main__":
    main()
