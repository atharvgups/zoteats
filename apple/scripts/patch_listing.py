#!/usr/bin/env python3
"""Patch App Store listing copy for an existing version. No new binary.

Updates description / promotional text / What's New from metadata.json.
Does not create versions, cancel review, attach builds, or submit.

What's New is often locked once a version is Ready for Sale. This script
tries the patch and reports whether Apple accepted it.
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
MARKETING_VERSION = os.environ.get("MARKETING_VERSION", "").strip()
METADATA_PATH = Path(os.environ.get("METADATA_PATH", "apple/AppStore/metadata.json"))

SCRIPTS = Path(__file__).resolve().parent
if str(SCRIPTS) not in sys.path:
    sys.path.insert(0, str(SCRIPTS))
from check_appstore_copy import listing_em_dash_fields, load_metadata  # noqa: E402


def die(msg: str) -> None:
    print(f"::error::{msg}", flush=True)
    sys.exit(1)


def info(msg: str) -> None:
    print(msg, flush=True)


def warn(msg: str) -> None:
    print(f"::warning::{msg}", flush=True)


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


def api(method: str, path: str, token: str, body: dict | None = None) -> dict:
    data = None if body is None else json.dumps(body).encode()
    req = urllib.request.Request(
        f"{API}{path}",
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
        try:
            parsed = json.loads(detail) if detail else {}
        except json.JSONDecodeError:
            parsed = {"raw": detail}
        parsed["http_status"] = exc.code
        return parsed


def main() -> None:
    meta = load_metadata(METADATA_PATH)
    bad = listing_em_dash_fields(meta)
    if bad:
        die(
            "App Store listing copy contains em dashes (U+2014) in: "
            + ", ".join(bad)
            + ". Rewrite with commas or periods before patching ASC."
        )

    token = make_token()
    q = urllib.parse.urlencode({"filter[bundleId]": BUNDLE_ID, "limit": 1})
    apps = api("GET", f"/v1/apps?{q}", token).get("data") or []
    if not apps:
        die(f"No app for {BUNDLE_ID}")
    app_id = apps[0]["id"]

    vq = urllib.parse.urlencode(
        {
            "filter[platform]": "IOS",
            "limit": "15",
            "fields[appStoreVersions]": "versionString,appStoreState",
        }
    )
    versions = api("GET", f"/v1/apps/{app_id}/appStoreVersions?{vq}", token).get("data") or []
    if not versions:
        die("No iOS App Store versions.")

    chosen = None
    for version in versions:
        attrs = version.get("attributes") or {}
        info(f"Version {attrs.get('versionString')}: {attrs.get('appStoreState')}")
        if MARKETING_VERSION and attrs.get("versionString") == MARKETING_VERSION:
            chosen = version
            break
    if chosen is None:
        if MARKETING_VERSION:
            die(f"No App Store version {MARKETING_VERSION}.")
        chosen = versions[0]

    attrs = chosen.get("attributes") or {}
    version_id = chosen["id"]
    ver = attrs.get("versionString")
    state = attrs.get("appStoreState")
    info(f"Patching listing for {ver} ({state}).")

    locale = meta.get("locale", "en-US")
    locs = api(
        "GET",
        f"/v1/appStoreVersions/{version_id}/appStoreVersionLocalizations?limit=10",
        token,
    ).get("data") or []
    loc = next(
        (row for row in locs if (row.get("attributes") or {}).get("locale") == locale),
        None,
    )
    if loc is None:
        die(f"No {locale} localization on {ver}.")

    loc_id = loc["id"]
    current = (loc.get("attributes") or {}).get("whatsNew") or ""
    wanted = meta.get("whats_new") or ""
    info(f"Current What's New: {current}")
    info(f"Wanted What's New: {wanted}")

    patch_attrs = {
        "description": meta["description"],
        "keywords": meta["keywords"][:100],
        "marketingUrl": meta.get("marketing_url"),
        "promotionalText": meta.get("promotional_text"),
        "supportUrl": meta.get("support_url"),
        "whatsNew": wanted,
    }
    patched = api(
        "PATCH",
        f"/v1/appStoreVersionLocalizations/{loc_id}",
        token,
        {
            "data": {
                "type": "appStoreVersionLocalizations",
                "id": loc_id,
                "attributes": patch_attrs,
            }
        },
    )
    if patched.get("data"):
        new_wn = ((patched.get("data") or {}).get("attributes") or {}).get("whatsNew") or ""
        info(f"ASC accepted listing patch. What's New now: {new_wn}")
        if "\u2014" in new_wn:
            die("ASC still has an em dash in What's New after patch.")
        return

    errors = patched.get("errors") or []
    detail = json.dumps(errors or patched)[:800]
    warn(f"Full listing patch failed ({patched.get('http_status')}): {detail}")

    # Live versions often lock What's New. Retry without it so other fields can update.
    no_wn = {k: v for k, v in patch_attrs.items() if k != "whatsNew"}
    retried = api(
        "PATCH",
        f"/v1/appStoreVersionLocalizations/{loc_id}",
        token,
        {
            "data": {
                "type": "appStoreVersionLocalizations",
                "id": loc_id,
                "attributes": no_wn,
            }
        },
    )
    if retried.get("data"):
        warn(
            f"What's New is locked on {ver} ({state}). Other listing fields updated. "
            "A new App Store version is required to change live release notes."
        )
        sys.exit(0)
    die(f"Could not patch listing for {ver}: {json.dumps(retried)[:800]}")


if __name__ == "__main__":
    main()
