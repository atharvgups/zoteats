#!/usr/bin/env python3
"""Read-only App Store Connect status for Anteats. No submit / cancel / mutate."""

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


def api(method: str, path: str, token: str) -> dict:
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
        die(f"ASC {method} {path} failed ({exc.code}): {detail[:800]}")


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
    for v in versions.get("data") or []:
        attrs = v.get("attributes") or {}
        rel = ((v.get("relationships") or {}).get("build") or {}).get("data") or {}
        build = builds_by_id.get(rel.get("id") or "")
        battrs = (build or {}).get("attributes") or {}
        print(
            f"version={attrs.get('versionString')} "
            f"appStoreState={attrs.get('appStoreState')} "
            f"build={battrs.get('version') or '—'} "
            f"buildProcessing={battrs.get('processingState') or '—'}",
            flush=True,
        )

    sq = urllib.parse.urlencode(
        {"filter[app]": app_id, "filter[platform]": "IOS", "limit": "10"}
    )
    subs = api("GET", f"/v1/reviewSubmissions?{sq}", token).get("data") or []
    print("--- reviewSubmissions ---", flush=True)
    if not subs:
        print("(none)", flush=True)
    for sub in subs:
        attrs = sub.get("attributes") or {}
        print(
            f"id={sub.get('id')} state={attrs.get('state')} "
            f"created={attrs.get('createdDate')} submitted={attrs.get('submittedDate')}",
            flush=True,
        )


if __name__ == "__main__":
    main()
