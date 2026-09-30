#!/usr/bin/env python3
"""Upload one App Store preview video onto an editable version.

Never submits, never cancels, never creates a new marketing version.
Requires TARGET_VERSION to already be editable (after a review cancel).

Required env:
  APP_STORE_CONNECT_KEY_ID
  APP_STORE_CONNECT_ISSUER_ID
  APP_STORE_CONNECT_API_KEY_PATH
  TARGET_VERSION           — e.g. 1.0.337

Optional env:
  BUNDLE_ID                — default com.atharvgupta.zoteats
  METADATA_PATH            — default apple/AppStore/metadata.json
  PREVIEW_FILE             — override path to the mp4
"""

from __future__ import annotations

import hashlib
import json
import os
import subprocess
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
    sys.stderr.write("PyJWT is required: pip install 'PyJWT[crypto]'\n")
    sys.exit(1)


API = "https://api.appstoreconnect.apple.com"
BUNDLE_ID = os.environ.get("BUNDLE_ID", "com.atharvgupta.zoteats")
METADATA_PATH = Path(os.environ.get("METADATA_PATH", "apple/AppStore/metadata.json"))
TARGET_VERSION = os.environ.get("TARGET_VERSION", "").strip()
PREVIEW_TYPE = os.environ.get("PREVIEW_TYPE", "IPHONE_67").strip() or "IPHONE_67"

EDITABLE_STATES = {
    "PREPARE_FOR_SUBMISSION",
    "DEVELOPER_REJECTED",
    "REJECTED",
    "METADATA_REJECTED",
    "INVALID_BINARY",
}


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
            if not raw:
                return {}
            return json.loads(raw)
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", "replace")
        if exc.code == 409:
            info(f"ASC {method} {path} conflict (409): {detail[:400]}")
            return {"errors": [{"status": "409"}], "already_exists": True, "raw": detail}
        if exc.code in ok:
            return json.loads(detail) if detail else {}
        die(f"ASC {method} {path} failed ({exc.code}): {detail[:1200]}")


def upload_bytes(url: str, data: bytes, headers: dict) -> None:
    req = urllib.request.Request(url, data=data, method="PUT", headers=headers)
    with urllib.request.urlopen(req, timeout=180) as resp:
        resp.read()


def probe(path: Path) -> tuple[float, int, int]:
    raw = subprocess.check_output(
        [
            "ffprobe",
            "-v",
            "error",
            "-select_streams",
            "v:0",
            "-show_entries",
            "stream=width,height:format=duration",
            "-of",
            "json",
            str(path),
        ],
        text=True,
    )
    info = json.loads(raw)
    duration = float((info.get("format") or {}).get("duration") or 0)
    stream = (info.get("streams") or [{}])[0]
    return duration, int(stream.get("width") or 0), int(stream.get("height") or 0)


def preview_path(meta: dict) -> Path:
    override = os.environ.get("PREVIEW_FILE", "").strip()
    if override:
        return Path(override)
    rel = meta.get("preview_file") or "docs/previews/iphone67.mp4"
    return Path(rel)


def main() -> None:
    if not TARGET_VERSION:
        die("TARGET_VERSION is required so we do not create a new draft.")
    if os.environ.get("SUBMIT_FOR_REVIEW", "").lower() in {"1", "true", "yes"}:
        die("Refusing to run: SUBMIT_FOR_REVIEW is set. This script never submits.")

    meta = json.loads(METADATA_PATH.read_text()) if METADATA_PATH.is_file() else {}
    src = preview_path(meta)
    if not src.is_file():
        die(f"Preview file missing: {src}. Capture it first.")

    duration, width, height = probe(src)
    info(f"Preview {src} {width}x{height} {duration:.1f}s")
    if duration < 15 or duration > 30:
        die(
            f"Preview is {duration:.1f}s. Apple wants 15-30 seconds. "
            "Not uploading. Recapture a short clip."
        )
    if "\u2014" in src.name:
        die("Preview filename contains an em dash.")

    token = make_token()
    q = urllib.parse.urlencode({"filter[bundleId]": BUNDLE_ID, "limit": 1})
    apps = api("GET", f"/v1/apps?{q}", token).get("data") or []
    if not apps:
        die(f"No app for {BUNDLE_ID}")
    app_id = apps[0]["id"]

    vq = urllib.parse.urlencode(
        {
            "filter[platform]": "IOS",
            "limit": "20",
            "fields[appStoreVersions]": "versionString,appStoreState",
        }
    )
    versions = api("GET", f"/v1/apps/{app_id}/appStoreVersions?{vq}", token).get("data") or []
    target = None
    for version in versions:
        attrs = version.get("attributes") or {}
        info(f"Version {attrs.get('versionString')}: {attrs.get('appStoreState')}")
        if attrs.get("versionString") == TARGET_VERSION:
            target = version
    if target is None:
        die(f"{TARGET_VERSION} not found.")
    state = (target.get("attributes") or {}).get("appStoreState")
    if state not in EDITABLE_STATES:
        die(f"{TARGET_VERSION} is {state}, not editable. Cancel review first.")

    locs = api(
        "GET",
        f"/v1/appStoreVersions/{target['id']}/appStoreVersionLocalizations?limit=10",
        token,
    ).get("data") or []
    loc_id = None
    for loc in locs:
        if (loc.get("attributes") or {}).get("locale") == meta.get("locale", "en-US"):
            loc_id = loc["id"]
            break
    if not loc_id and locs:
        loc_id = locs[0]["id"]
    if not loc_id:
        die("No version localization for preview upload.")

    sets = api(
        "GET",
        f"/v1/appStoreVersionLocalizations/{loc_id}/appPreviewSets?limit=20",
        token,
        ok_codes={200, 404},
    ).get("data") or []
    set_id = None
    for preview_set in sets:
        if (preview_set.get("attributes") or {}).get("previewType") == PREVIEW_TYPE:
            set_id = preview_set["id"]
            break
    if set_id is None:
        created = api(
            "POST",
            "/v1/appPreviewSets",
            token,
            {
                "data": {
                    "type": "appPreviewSets",
                    "attributes": {"previewType": PREVIEW_TYPE},
                    "relationships": {
                        "appStoreVersionLocalization": {
                            "data": {
                                "type": "appStoreVersionLocalizations",
                                "id": loc_id,
                            }
                        }
                    },
                }
            },
            ok_codes={200, 201, 409, 422},
        )
        set_id = (created.get("data") or {}).get("id")
        if not set_id:
            refreshed = api(
                "GET",
                f"/v1/appStoreVersionLocalizations/{loc_id}/appPreviewSets?limit=20",
                token,
            ).get("data") or []
            for preview_set in refreshed:
                if (preview_set.get("attributes") or {}).get("previewType") == PREVIEW_TYPE:
                    set_id = preview_set["id"]
                    break
    if not set_id:
        die(f"Could not create/find preview set {PREVIEW_TYPE}.")

    existing = api(
        "GET", f"/v1/appPreviewSets/{set_id}/appPreviews?limit=10", token
    ).get("data") or []
    for preview in existing:
        api("DELETE", f"/v1/appPreviews/{preview['id']}", token, ok_codes={200, 204, 404})

    data = src.read_bytes()
    checksum = hashlib.md5(data).hexdigest()
    reserve = api(
        "POST",
        "/v1/appPreviews",
        token,
        {
            "data": {
                "type": "appPreviews",
                "attributes": {
                    "fileName": src.name,
                    "fileSize": len(data),
                    "mimeType": "video/mp4",
                    "previewFrameTimeCode": "00:00:02:00",
                },
                "relationships": {
                    "appPreviewSet": {
                        "data": {"type": "appPreviewSets", "id": set_id}
                    }
                },
            }
        },
    )
    preview = reserve.get("data") or {}
    preview_id = preview.get("id")
    ops = (preview.get("attributes") or {}).get("uploadOperations") or []
    if preview_id and not ops:
        detail = api("GET", f"/v1/appPreviews/{preview_id}", token)
        ops = ((detail.get("data") or {}).get("attributes") or {}).get("uploadOperations") or []
    if not preview_id or not ops:
        die(f"No upload operations for preview. Raw: {json.dumps(reserve)[:800]}")

    for op in ops:
        offset = int(op.get("offset") or 0)
        length = int(op.get("length") or len(data))
        chunk = data[offset : offset + length]
        headers = {
            h["name"]: h["value"]
            for h in (op.get("requestHeaders") or [])
            if h.get("name") and h.get("value") is not None
        }
        headers.setdefault("Content-Type", "video/mp4")
        upload_bytes(op["url"], chunk, headers)

    api(
        "PATCH",
        f"/v1/appPreviews/{preview_id}",
        token,
        {
            "data": {
                "type": "appPreviews",
                "id": preview_id,
                "attributes": {
                    "uploaded": True,
                    "sourceFileChecksum": checksum,
                    "previewFrameTimeCode": "00:00:02:00",
                },
            }
        },
        ok_codes={200, 204, 409, 422},
    )
    info(f"Uploaded preview {src.name} ({len(data)} bytes) to {TARGET_VERSION} {PREVIEW_TYPE}.")

    deadline = time.time() + 300
    while time.time() < deadline:
        detail = api("GET", f"/v1/appPreviews/{preview_id}", token)
        attrs = (detail.get("data") or {}).get("attributes") or {}
        delivery = (attrs.get("assetDeliveryState") or {}).get("state")
        video = (attrs.get("videoDeliveryState") or {}).get("state")
        info(f"Preview processing delivery={delivery} video={video}")
        if delivery == "FAILED" or video == "FAILED":
            die("ASC failed to process the preview video.")
        if delivery in {"COMPLETE", None} and video in {"COMPLETE", None, "COMPLETE"}:
            return
        if delivery == "COMPLETE":
            return
        time.sleep(15)
    info("Preview still processing; continuing.")


if __name__ == "__main__":
    main()
