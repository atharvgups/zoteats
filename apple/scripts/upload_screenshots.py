#!/usr/bin/env python3
"""Replace App Store Connect listing screenshots only.

Never submits for App Review, never releases a version, never cancels review,
never attaches a new binary. Updates media on an editable draft (or creates
one if ASC requires it for screenshots). Live READY_FOR_SALE binary stays.

Required env:
  APP_STORE_CONNECT_KEY_ID
  APP_STORE_CONNECT_ISSUER_ID
  APP_STORE_CONNECT_API_KEY_PATH

Optional env:
  BUNDLE_ID            — default com.atharvgupta.zoteats
  METADATA_PATH        — default apple/AppStore/metadata.json
  SCREENSHOT_ROOT      — repo root (default cwd)
  SCREENSHOT_DIR       — override directory of listing PNGs
"""

from __future__ import annotations

import hashlib
import json
import mimetypes
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
    sys.stderr.write("PyJWT is required: pip install 'PyJWT[crypto]'\n")
    sys.exit(1)

try:
    from PIL import Image
except ImportError:
    sys.stderr.write("Pillow is required: pip install Pillow\n")
    sys.exit(1)


API = "https://api.appstoreconnect.apple.com"
BUNDLE_ID = os.environ.get("BUNDLE_ID", "com.atharvgupta.zoteats")
METADATA_PATH = Path(os.environ.get("METADATA_PATH", "apple/AppStore/metadata.json"))
SCREENSHOT_ROOT = Path(os.environ.get("SCREENSHOT_ROOT", ".")).resolve()
SCREENSHOT_DIR = os.environ.get("SCREENSHOT_DIR", "").strip()

# Apple screenshot slot pixel sizes (portrait).
DISPLAY_SIZES: dict[str, tuple[int, int]] = {
    "APP_IPHONE_69": (1320, 2868),
    "APP_IPHONE_67": (1290, 2796),
    "APP_IPHONE_65": (1242, 2688),
    "APP_IPHONE_61": (1179, 2556),
    "APP_IPHONE_58": (1170, 2532),
    "APP_IPHONE_55": (1242, 2208),
    "APP_IPAD_PRO_3GEN_129": (2048, 2732),
    "APP_IPAD_PRO_129": (2048, 2732),
    "APP_IPAD_PRO_11": (1668, 2388),
    "APP_IPAD_107": (1668, 2388),
    "APP_IPAD_105": (1668, 2224),
    "APP_IPAD_97": (1536, 2048),
}

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


def find_app_id(token: str) -> str:
    q = urllib.parse.urlencode({"filter[bundleId]": BUNDLE_ID, "limit": 1})
    apps = api("GET", f"/v1/apps?{q}", token).get("data") or []
    if not apps:
        die(f"No App Store Connect app found for bundle id {BUNDLE_ID}")
    return apps[0]["id"]


def list_ios_versions(token: str, app_id: str) -> list[dict]:
    q = urllib.parse.urlencode(
        {
            "filter[platform]": "IOS",
            "limit": "20",
            "fields[appStoreVersions]": "versionString,appStoreState,platform",
        }
    )
    return api("GET", f"/v1/apps/{app_id}/appStoreVersions?{q}", token).get("data") or []


def localization_id(token: str, version_id: str, locale: str = "en-US") -> str | None:
    q = urllib.parse.urlencode({"limit": "10"})
    locs = api(
        "GET", f"/v1/appStoreVersions/{version_id}/appStoreVersionLocalizations?{q}", token
    ).get("data") or []
    for loc in locs:
        if (loc.get("attributes") or {}).get("locale") == locale:
            return loc["id"]
    return locs[0]["id"] if locs else None


def screenshot_sets(token: str, localization_id: str) -> list[dict]:
    return (
        api(
            "GET",
            f"/v1/appStoreVersionLocalizations/{localization_id}/appScreenshotSets?limit=20",
            token,
            ok_codes={200, 404},
        ).get("data")
        or []
    )


def display_types_from_sets(sets: list[dict]) -> list[str]:
    types: list[str] = []
    for shot_set in sets:
        display = (shot_set.get("attributes") or {}).get("screenshotDisplayType")
        if display and display not in types:
            types.append(display)
    return types


def pick_editable_version(versions: list[dict]) -> dict | None:
    for version in versions:
        state = (version.get("attributes") or {}).get("appStoreState")
        if state in EDITABLE_STATES:
            return version
    return None


def create_draft_version(token: str, app_id: str, version_string: str) -> dict:
    created = api(
        "POST",
        "/v1/appStoreVersions",
        token,
        {
            "data": {
                "type": "appStoreVersions",
                "attributes": {"platform": "IOS", "versionString": version_string},
                "relationships": {"app": {"data": {"type": "apps", "id": app_id}}},
            }
        },
        ok_codes={200, 201, 409, 422},
    )
    version = created.get("data")
    if version:
        info(f"Created App Store version draft {version_string} ({version['id']}) — not submitted.")
        return version
    die(
        "No editable App Store version and ASC refused to create a draft. "
        "Screenshots were not uploaded. Live version was not released. "
        f"Detail: {json.dumps(created)[:800]}"
    )


def listing_files(meta: dict) -> list[Path]:
    if SCREENSHOT_DIR:
        root = Path(SCREENSHOT_DIR)
        names = meta.get("screenshot_files") or []
        files: list[Path] = []
        for rel in names:
            candidate = root / Path(rel).name
            if candidate.is_file():
                files.append(candidate)
            else:
                warn(f"Screenshot missing: {candidate}")
        return files
    files = []
    for rel in meta.get("screenshot_files") or []:
        src = (SCREENSHOT_ROOT / rel).resolve()
        if src.is_file():
            files.append(src)
        else:
            warn(f"Screenshot missing: {src}")
    return files


def resize_cover(src: Path, dest: Path, size: tuple[int, int]) -> Path:
    dest.parent.mkdir(parents=True, exist_ok=True)
    im = Image.open(src).convert("RGB")
    tw, th = size
    scale = max(tw / im.width, th / im.height)
    nw, nh = int(im.width * scale), int(im.height * scale)
    im = im.resize((nw, nh), Image.Resampling.LANCZOS)
    left = (nw - tw) // 2
    top = (nh - th) // 2
    im = im.crop((left, top, left + tw, top + th))
    im.save(dest, format="PNG", optimize=True)
    return dest


def upload_bytes(url: str, data: bytes, headers: dict) -> None:
    req = urllib.request.Request(url, data=data, method="PUT", headers=headers)
    with urllib.request.urlopen(req, timeout=120) as resp:
        resp.read()


def ensure_set(token: str, localization_id: str, display_type: str, existing: list[dict]) -> str | None:
    for shot_set in existing:
        if (shot_set.get("attributes") or {}).get("screenshotDisplayType") == display_type:
            return shot_set["id"]
    created = api(
        "POST",
        "/v1/appScreenshotSets",
        token,
        {
            "data": {
                "type": "appScreenshotSets",
                "attributes": {"screenshotDisplayType": display_type},
                "relationships": {
                    "appStoreVersionLocalization": {
                        "data": {
                            "type": "appStoreVersionLocalizations",
                            "id": localization_id,
                        }
                    }
                },
            }
        },
        ok_codes={200, 201, 409, 422},
    )
    if created.get("already_exists") or created.get("errors"):
        refreshed = screenshot_sets(token, localization_id)
        for shot_set in refreshed:
            if (shot_set.get("attributes") or {}).get("screenshotDisplayType") == display_type:
                return shot_set["id"]
        warn(f"Could not create screenshot set {display_type}: {json.dumps(created)[:400]}")
        return None
    set_id = (created.get("data") or {}).get("id")
    return set_id


def clear_set(token: str, set_id: str) -> None:
    existing = api(
        "GET", f"/v1/appScreenshotSets/{set_id}/appScreenshots?limit=20", token
    ).get("data") or []
    for shot in existing:
        api("DELETE", f"/v1/appScreenshots/{shot['id']}", token, ok_codes={200, 204, 404})


def upload_set(token: str, set_id: str, display_type: str, files: list[Path], tmp: Path) -> int:
    size = DISPLAY_SIZES.get(display_type)
    if not size:
        warn(f"No pixel size mapped for {display_type}; skipping slot.")
        return 0
    uploaded = 0
    for index, src in enumerate(files[:10]):
        prepared = resize_cover(src, tmp / display_type / f"{index:02d}.png", size)
        data = prepared.read_bytes()
        checksum = hashlib.md5(data).hexdigest()
        reserve = api(
            "POST",
            "/v1/appScreenshots",
            token,
            {
                "data": {
                    "type": "appScreenshots",
                    "attributes": {
                        "fileName": prepared.name,
                        "fileSize": len(data),
                    },
                    "relationships": {
                        "appScreenshotSet": {
                            "data": {"type": "appScreenshotSets", "id": set_id}
                        }
                    },
                }
            },
        )
        shot = reserve.get("data") or {}
        shot_id = shot.get("id")
        ops = (shot.get("attributes") or {}).get("uploadOperations") or []
        if not shot_id or not ops:
            detail = api("GET", f"/v1/appScreenshots/{shot_id}", token) if shot_id else {}
            ops = ((detail.get("data") or {}).get("attributes") or {}).get("uploadOperations") or []
        if not shot_id or not ops:
            warn(f"No upload operations for {src.name} → {display_type}")
            continue
        for op in ops:
            offset = int(op.get("offset") or 0)
            length = int(op.get("length") or len(data))
            chunk = data[offset : offset + length]
            headers = {
                h["name"]: h["value"]
                for h in (op.get("requestHeaders") or [])
                if h.get("name") and h.get("value") is not None
            }
            headers.setdefault(
                "Content-Type", mimetypes.guess_type(prepared.name)[0] or "image/png"
            )
            upload_bytes(op["url"], chunk, headers)
        api(
            "PATCH",
            f"/v1/appScreenshots/{shot_id}",
            token,
            {
                "data": {
                    "type": "appScreenshots",
                    "id": shot_id,
                    "attributes": {
                        "uploaded": True,
                        "sourceFileChecksum": checksum,
                    },
                }
            },
            ok_codes={200, 204, 409, 422},
        )
        info(f"Uploaded {src.name} → {display_type} {size[0]}x{size[1]}")
        uploaded += 1
    return uploaded


def wait_for_processing(token: str, localization_id: str, timeout_s: int = 180) -> None:
    deadline = time.time() + timeout_s
    while time.time() < deadline:
        sets = screenshot_sets(token, localization_id)
        pending = 0
        for shot_set in sets:
            shots = api(
                "GET",
                f"/v1/appScreenshotSets/{shot_set['id']}/appScreenshots?limit=50"
                "&fields[appScreenshots]=assetDeliveryState,fileName",
                token,
                ok_codes={200, 404},
            ).get("data") or []
            for shot in shots:
                state = ((shot.get("attributes") or {}).get("assetDeliveryState") or {}).get(
                    "state"
                )
                if state not in {"COMPLETE", "FAILED", None}:
                    pending += 1
                elif state == "FAILED":
                    warn(f"Screenshot asset failed: {shot.get('id')}")
        if pending == 0:
            info("Screenshot assets finished processing.")
            return
        info(f"Waiting for {pending} screenshot(s) to finish processing…")
        time.sleep(15)
    warn("Timed out waiting for screenshot processing.")


def main() -> None:
    if os.environ.get("SUBMIT_FOR_REVIEW", "").lower() in {"1", "true", "yes"}:
        die("Refusing to run: SUBMIT_FOR_REVIEW is set. This script never submits.")
    if os.environ.get("RELEASE_PENDING_DEVELOPER_RELEASE", "").lower() in {"1", "true", "yes"}:
        die("Refusing to run: release flag is set. This script never releases.")

    if not METADATA_PATH.is_file():
        die(f"Missing metadata file: {METADATA_PATH}")
    meta = json.loads(METADATA_PATH.read_text())
    files = listing_files(meta)
    if not files:
        die("No listing screenshot files found — aborting so ASC is not cleared.")

    token = make_token()
    app_id = find_app_id(token)
    info(f"App {BUNDLE_ID} → {app_id}")
    versions = list_ios_versions(token, app_id)

    live_types: list[str] = []
    for version in versions:
        attrs = version.get("attributes") or {}
        info(f"Version {attrs.get('versionString')}: {attrs.get('appStoreState')}")
        if attrs.get("appStoreState") in {
            "READY_FOR_SALE",
            "PENDING_APPLE_RELEASE",
            "PROCESSING_FOR_APP_STORE",
        }:
            loc = localization_id(token, version["id"], meta.get("locale", "en-US"))
            if loc:
                live_types = display_types_from_sets(screenshot_sets(token, loc))
                info(
                    f"Live {attrs.get('versionString')} screenshot slots: "
                    f"{', '.join(live_types) or '(none)'}"
                )
            break

    draft = pick_editable_version(versions)
    if draft is None:
        # ASC needs a version draft to hold new media. Do not touch live 1.0.298.
        next_ver = os.environ.get("MARKETING_VERSION", "").strip() or "1.0.307"
        info(f"No editable draft; creating unsubmitted {next_ver} for media only.")
        draft = create_draft_version(token, app_id, next_ver)
    attrs = draft.get("attributes") or {}
    version_id = draft["id"]
    info(
        f"Updating screenshots on draft {attrs.get('versionString')} "
        f"(state={attrs.get('appStoreState')}). Not submitting. Not releasing."
    )

    loc_id = localization_id(token, version_id, meta.get("locale", "en-US"))
    if not loc_id:
        die("Draft has no version localization — cannot attach screenshots.")

    existing = screenshot_sets(token, loc_id)
    draft_types = display_types_from_sets(existing)
    info(f"Draft screenshot slots before replace: {', '.join(draft_types) or '(none)'}")

    targets: list[str] = []
    for display in ["APP_IPHONE_67", *live_types, *draft_types]:
        if display not in targets:
            targets.append(display)

    tmp = Path(os.environ.get("RUNNER_TEMP", "/tmp")) / "anteats-listing-screenshots"
    report: list[str] = []
    for display in targets:
        set_id = ensure_set(token, loc_id, display, existing)
        if not set_id:
            continue
        clear_set(token, set_id)
        count = upload_set(token, set_id, display, files, tmp)
        size = DISPLAY_SIZES.get(display)
        size_s = f"{size[0]}x{size[1]}" if size else "?"
        report.append(f"{display} {size_s}: {count} file(s)")
        existing = screenshot_sets(token, loc_id)

    wait_for_processing(token, loc_id)

    info("--- screenshot upload report ---")
    for line in report:
        info(line)
    info("Files:")
    for path in files:
        info(f"  {path}")
    info("App Review was NOT submitted.")
    info("No version was released to the public store.")


if __name__ == "__main__":
    main()
