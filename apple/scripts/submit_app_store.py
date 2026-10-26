#!/usr/bin/env python3
"""Prepare Anteats App Store version metadata and submit for App Review.

Uses the modern reviewSubmissions flow (appStoreVersionSubmissions is deprecated).

Required env:
  APP_STORE_CONNECT_KEY_ID
  APP_STORE_CONNECT_ISSUER_ID
  APP_STORE_CONNECT_API_KEY_PATH  — path to AuthKey_*.p8

Optional env:
  BUNDLE_ID                 — default com.atharvgupta.zoteats
  MARKETING_VERSION         — e.g. 1.0.25 (creates version if needed)
  BUILD_NUMBER              — prefer this CFBundleVersion when attaching a build
  METADATA_PATH             — default apple/AppStore/metadata.json
  SCREENSHOT_ROOT           — repo root for relative screenshot paths (default cwd)
  SUBMIT_FOR_REVIEW         — "true" (default) or "false" to only prepare listing
  REVIEW_CONTACT_EMAIL      — default atharvgups@gmail.com
  REVIEW_CONTACT_FIRST_NAME — default Atharv
  REVIEW_CONTACT_LAST_NAME  — default Gupta
  REVIEW_CONTACT_PHONE      — optional
"""

from __future__ import annotations

import hashlib
import json
import mimetypes
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
    import jwt  # PyJWT
except ImportError:
    sys.stderr.write("PyJWT is required: pip install 'PyJWT[crypto]'\n")
    sys.exit(1)

try:
    from PIL import Image
except ImportError:
    Image = None  # type: ignore


API = "https://api.appstoreconnect.apple.com"
BUNDLE_ID = os.environ.get("BUNDLE_ID", "com.atharvgupta.zoteats")
MARKETING_VERSION = os.environ.get("MARKETING_VERSION", "").strip()
BUILD_NUMBER = os.environ.get("BUILD_NUMBER", "").strip()
METADATA_PATH = Path(os.environ.get("METADATA_PATH", "apple/AppStore/metadata.json"))
SCREENSHOT_ROOT = Path(os.environ.get("SCREENSHOT_ROOT", ".")).resolve()
SUBMIT = os.environ.get("SUBMIT_FOR_REVIEW", "true").lower() not in {"0", "false", "no"}
# When true, cancel WAITING_FOR_REVIEW only (never IN_REVIEW / approved).
# First public version 1.0.221 is approved — do not pull it from review.
CANCEL_IN_FLIGHT = os.environ.get("CANCEL_IN_FLIGHT_REVIEW", "true").lower() not in {
    "0",
    "false",
    "no",
}
# When true, POST appStoreVersionReleaseRequests for PENDING_DEVELOPER_RELEASE
# so the approved version actually goes on sale before we create the next one.
RELEASE_PENDING = os.environ.get("RELEASE_PENDING_DEVELOPER_RELEASE", "true").lower() not in {
    "0",
    "false",
    "no",
}
MAX_WAIT = int(os.environ.get("BUILD_WAIT_SECONDS", "2400"))
RELEASE_STATES = {"PENDING_DEVELOPER_RELEASE", "ACCEPTED"}
LIVE_OR_RELEASING_STATES = {
    "READY_FOR_SALE",
    "PENDING_APPLE_RELEASE",
    "PROCESSING_FOR_APP_STORE",
    "READY_FOR_DISTRIBUTION",
    "REPLACED_WITH_NEW_VERSION",
}

# iPhone-only listing slots (TARGETED_DEVICE_FAMILY=1). Cover-fit from the
# simulator capture into each required App Store pixel size.
# APP_IPHONE_69 is not a valid screenshotDisplayType on this app's ASC API yet.
IPHONE_67_SIZE = (1290, 2796)
IPHONE_67_DISPLAY = "APP_IPHONE_67"
SCREENSHOT_SLOTS: dict[str, tuple[int, int]] = {
    "APP_IPHONE_67": (1290, 2796),
    "APP_IPHONE_65": (1242, 2688),
}
PREVIEW_TYPE = os.environ.get("PREVIEW_TYPE", "IPHONE_67").strip() or "IPHONE_67"
SCREENSHOT_WAIT = int(os.environ.get("SCREENSHOT_WAIT_SECONDS", "900"))


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
        if exc.code >= 500:
            return {"errors": [{"status": str(exc.code)}], "server_error": True, "raw": detail}
        die(f"ASC {method} {path} failed ({exc.code}): {detail[:1200]}")


def find_app_id(token: str) -> str:
    q = urllib.parse.urlencode({"filter[bundleId]": BUNDLE_ID, "limit": 1})
    apps = api("GET", f"/v1/apps?{q}", token).get("data") or []
    if not apps:
        die(f"No App Store Connect app found for bundle id {BUNDLE_ID}")
    return apps[0]["id"]


def load_metadata() -> dict:
    if not METADATA_PATH.is_file():
        die(f"Missing metadata file: {METADATA_PATH}")
    meta = json.loads(METADATA_PATH.read_text())
    scripts_dir = str(Path(__file__).resolve().parent)
    if scripts_dir not in sys.path:
        sys.path.insert(0, scripts_dir)
    from check_appstore_copy import listing_em_dash_fields

    bad = listing_em_dash_fields(meta)
    if bad:
        die(
            "App Store listing copy contains em dashes (U+2014) in: "
            + ", ".join(bad)
            + ". Rewrite with commas or periods. No em dashes in metadata, "
            "release notes, or What's New."
        )
    return meta


def list_builds(token: str, app_id: str, limit: int = 50) -> tuple[list[dict], dict]:
    q = urllib.parse.urlencode(
        {
            "filter[app]": app_id,
            "sort": "-uploadedDate",
            "limit": str(limit),
            "include": "preReleaseVersion",
        }
    )
    payload = api("GET", f"/v1/builds?{q}", token)
    trains = {
        row["id"]: row
        for row in (payload.get("included") or [])
        if row.get("type") == "preReleaseVersions"
    }
    return payload.get("data") or [], trains


def build_marketing_version(build: dict, trains: dict) -> str:
    rel = ((build.get("relationships") or {}).get("preReleaseVersion") or {}).get("data") or {}
    train = trains.get(rel.get("id") or "")
    return str(((train or {}).get("attributes") or {}).get("version") or "")


def enrich_marketing_version(token: str, build: dict, trains: dict) -> str:
    train = build_marketing_version(build, trains)
    if train:
        return train
    bid = build.get("id")
    if not bid:
        return ""
    detail = api(
        "GET",
        f"/v1/builds/{bid}/preReleaseVersion",
        token,
        ok_codes={200, 404},
    ).get("data") or {}
    train = str((detail.get("attributes") or {}).get("version") or "")
    if detail.get("id"):
        trains[detail["id"]] = detail
        rel = build.setdefault("relationships", {}).setdefault("preReleaseVersion", {})
        rel["data"] = {"type": "preReleaseVersions", "id": detail["id"]}
    return train


def wait_for_build(token: str, app_id: str) -> dict:
    deadline = time.time() + MAX_WAIT
    last = None
    want_train = MARKETING_VERSION
    while time.time() < deadline:
        builds, trains = list_builds(token, app_id)
        chosen = None
        for b in builds:
            attrs = b.get("attributes") or {}
            if attrs.get("expired"):
                continue
            if BUILD_NUMBER and str(attrs.get("version")) != str(BUILD_NUMBER):
                continue
            if want_train:
                train = enrich_marketing_version(token, b, trains)
                if train != want_train:
                    continue
            chosen = b
            break
        if chosen:
            state = (chosen.get("attributes") or {}).get("processingState")
            ver = (chosen.get("attributes") or {}).get("version")
            train = enrich_marketing_version(token, chosen, trains) or "?"
            info(f"Build {ver} ({train}): processingState={state}")
            last = state
            if state == "VALID":
                return chosen
            if state in {"INVALID", "FAILED"}:
                die(f"Build ended in state {state}")
        else:
            target = want_train or "any"
            info(f"Waiting for a VALID build on train {target}…")
        time.sleep(30)
    die(f"Timed out waiting for a VALID build (last state={last})")


def editable_states() -> set[str]:
    return {
        "PREPARE_FOR_SUBMISSION",
        "DEVELOPER_REJECTED",
        "REJECTED",
        "METADATA_REJECTED",
        "INVALID_BINARY",
    }


def list_ios_versions(token: str, app_id: str) -> list[dict]:
    q = urllib.parse.urlencode(
        {
            "filter[platform]": "IOS",
            "limit": "20",
            "fields[appStoreVersions]": "versionString,appStoreState,platform",
        }
    )
    return api("GET", f"/v1/apps/{app_id}/appStoreVersions?{q}", token).get("data") or []


def release_pending_developer_release(token: str, app_id: str) -> None:
    """Put an approved-but-unreleased version on sale so a newer version can be created."""
    versions = list_ios_versions(token, app_id)
    pending = [
        v
        for v in versions
        if (v.get("attributes") or {}).get("appStoreState") in RELEASE_STATES
    ]
    if not pending:
        return
    if not RELEASE_PENDING:
        ver = (pending[0].get("attributes") or {}).get("versionString")
        state = (pending[0].get("attributes") or {}).get("appStoreState")
        die(
            f"{ver} is {state}. Set RELEASE_PENDING_DEVELOPER_RELEASE=true "
            "(or tap Release in App Store Connect) so it can go on sale, then re-run."
        )
    for version in pending:
        version_id = version["id"]
        attrs = version.get("attributes") or {}
        ver = attrs.get("versionString")
        state = attrs.get("appStoreState")
        info(f"Releasing {ver} to the App Store (state={state})…")
        result = api(
            "POST",
            "/v1/appStoreVersionReleaseRequests",
            token,
            {
                "data": {
                    "type": "appStoreVersionReleaseRequests",
                    "relationships": {
                        "appStoreVersion": {
                            "data": {"type": "appStoreVersions", "id": version_id}
                        }
                    },
                }
            },
            ok_codes={200, 201, 409, 422},
        )
        if result.get("errors") and not result.get("already_exists") and not result.get("data"):
            die(
                f"Could not release {ver}. In App Store Connect → Anteats → "
                f"{ver} → Release this version. Detail: {json.dumps(result)[:1200]}"
            )
        deadline = time.time() + 300
        while time.time() < deadline:
            detail = api("GET", f"/v1/appStoreVersions/{version_id}", token)
            new_state = ((detail.get("data") or {}).get("attributes") or {}).get("appStoreState")
            info(f"Release poll: {ver} → {new_state}")
            if new_state in LIVE_OR_RELEASING_STATES:
                break
            if new_state in RELEASE_STATES:
                time.sleep(10)
                continue
            break
        else:
            warn(
                f"{ver} release is still settling (last state pending). "
                "Continuing to prepare the next App Store version."
            )


def get_or_create_version(token: str, app_id: str, version_string: str) -> dict:
    versions = list_ios_versions(token, app_id)
    for v in versions:
        attrs = v.get("attributes") or {}
        info(f"Version {attrs.get('versionString')}: {attrs.get('appStoreState')}")
        if attrs.get("versionString") == version_string and attrs.get("appStoreState") in editable_states():
            return v
    for v in versions:
        attrs = v.get("attributes") or {}
        if attrs.get("appStoreState") in editable_states():
            # Reuse editable draft even if version string differs — patch it.
            if attrs.get("versionString") != version_string:
                patched = api(
                    "PATCH",
                    f"/v1/appStoreVersions/{v['id']}",
                    token,
                    {
                        "data": {
                            "type": "appStoreVersions",
                            "id": v["id"],
                            "attributes": {"versionString": version_string},
                        }
                    },
                )
                return patched.get("data") or v
            return v

    last = {}
    for attempt in range(6):
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
            info(f"Created App Store version {version_string} ({version['id']})")
            return version
        last = created
        info(
            f"Could not create {version_string} yet (attempt {attempt + 1}/6); "
            "waiting for the approved version to go on sale…"
        )
        time.sleep(20)
        versions = list_ios_versions(token, app_id)
        for v in versions:
            attrs = v.get("attributes") or {}
            if attrs.get("versionString") == version_string and attrs.get("appStoreState") in editable_states():
                return v
    die(
        "Could not create app store version and no editable draft exists. "
        "If the approved version is still Pending Developer Release, release it "
        "in App Store Connect first (or re-run with RELEASE_PENDING_DEVELOPER_RELEASE=true). "
        f"Detail: {json.dumps(last)[:800]}"
    )


def attach_build(token: str, version_id: str, build_id: str) -> None:
    result = api(
        "PATCH",
        f"/v1/appStoreVersions/{version_id}/relationships/build",
        token,
        {"data": {"type": "builds", "id": build_id}},
        ok_codes={200, 204, 409},
    )
    if result.get("already_exists"):
        info("Build already attached.")
    else:
        info(f"Attached build {build_id} to version {version_id}.")


def ensure_release_type(token: str, app_id: str, version_id: str) -> None:
    """Manual release, unless a live version is already set to automatic."""
    automatic = False
    for version in list_ios_versions(token, app_id):
        state = (version.get("attributes") or {}).get("appStoreState")
        if state not in LIVE_OR_RELEASING_STATES:
            continue
        detail = api("GET", f"/v1/appStoreVersions/{version['id']}", token)
        live_type = ((detail.get("data") or {}).get("attributes") or {}).get("releaseType")
        info(
            "Live version "
            f"{(version.get('attributes') or {}).get('versionString')} "
            f"releaseType={live_type}"
        )
        if live_type == "AFTER_APPROVAL":
            automatic = True
            break
    wanted = "AFTER_APPROVAL" if automatic else "MANUAL"
    result = api(
        "PATCH",
        f"/v1/appStoreVersions/{version_id}",
        token,
        {
            "data": {
                "type": "appStoreVersions",
                "id": version_id,
                "attributes": {"releaseType": wanted},
            }
        },
        ok_codes={200, 204, 409, 422},
    )
    if result.get("errors") and not result.get("data"):
        warn(f"Could not set releaseType={wanted}: {json.dumps(result)[:500]}")
        return
    info(f"Set releaseType={wanted}.")


def ensure_version_copyright(token: str, version_id: str, meta: dict) -> None:
    copyright_text = (meta.get("copyright") or "").strip()
    if not copyright_text:
        warn("metadata.json missing copyright — ASC will reject first submit.")
        return
    result = api(
        "PATCH",
        f"/v1/appStoreVersions/{version_id}",
        token,
        {
            "data": {
                "type": "appStoreVersions",
                "id": version_id,
                "attributes": {"copyright": copyright_text},
            }
        },
        ok_codes={200, 204, 409, 422},
    )
    if result.get("errors") and not result.get("data"):
        die(f"Could not set copyright: {json.dumps(result)[:800]}")
    info(f"Set version copyright={copyright_text!r}.")


def ensure_content_rights(token: str, app_id: str) -> None:
    """First-submit ASC requires contentRightsDeclaration on the app."""
    result = api(
        "PATCH",
        f"/v1/apps/{app_id}",
        token,
        {
            "data": {
                "type": "apps",
                "id": app_id,
                "attributes": {
                    "contentRightsDeclaration": "DOES_NOT_USE_THIRD_PARTY_CONTENT"
                },
            }
        },
        ok_codes={200, 204, 409, 422},
    )
    if result.get("errors") and not result.get("data"):
        die(f"Could not set contentRightsDeclaration: {json.dumps(result)[:800]}")
    info("Set contentRightsDeclaration=DOES_NOT_USE_THIRD_PARTY_CONTENT.")


def ensure_version_localization(token: str, version_id: str, meta: dict) -> str:
    locale = meta.get("locale", "en-US")
    q = urllib.parse.urlencode({"limit": "10"})
    locs = api(
        "GET", f"/v1/appStoreVersions/{version_id}/appStoreVersionLocalizations?{q}", token
    ).get("data") or []
    loc_id = None
    for loc in locs:
        if (loc.get("attributes") or {}).get("locale") == locale:
            loc_id = loc["id"]
            break
    attrs = {
        "description": meta["description"],
        "keywords": meta["keywords"][:100],
        "marketingUrl": meta.get("marketing_url"),
        "promotionalText": meta.get("promotional_text"),
        "supportUrl": meta.get("support_url"),
        "whatsNew": meta.get("whats_new"),
    }
    if loc_id is None:
        created = api(
            "POST",
            "/v1/appStoreVersionLocalizations",
            token,
            {
                "data": {
                    "type": "appStoreVersionLocalizations",
                    "attributes": {"locale": locale, **attrs},
                    "relationships": {
                        "appStoreVersion": {
                            "data": {"type": "appStoreVersions", "id": version_id}
                        }
                    },
                }
            },
            ok_codes={200, 201, 409, 422},
        )
        if created.get("errors") or created.get("already_exists"):
            # First App Store version often rejects whatsNew — retry without it.
            attrs_no_wn = {k: v for k, v in attrs.items() if k != "whatsNew"}
            created = api(
                "POST",
                "/v1/appStoreVersionLocalizations",
                token,
                {
                    "data": {
                        "type": "appStoreVersionLocalizations",
                        "attributes": {"locale": locale, **attrs_no_wn},
                        "relationships": {
                            "appStoreVersion": {
                                "data": {"type": "appStoreVersions", "id": version_id}
                            }
                        },
                    }
                },
            )
        loc_id = (created.get("data") or {}).get("id")
        if not loc_id:
            # Race: localization may already exist after a 409.
            locs = api(
                "GET",
                f"/v1/appStoreVersions/{version_id}/appStoreVersionLocalizations?{q}",
                token,
            ).get("data") or []
            for loc in locs:
                if (loc.get("attributes") or {}).get("locale") == locale:
                    loc_id = loc["id"]
                    break
        if not loc_id:
            die("Failed to create version localization.")
        info(f"Created {locale} version localization.")
    else:
        patched = api(
            "PATCH",
            f"/v1/appStoreVersionLocalizations/{loc_id}",
            token,
            {
                "data": {
                    "type": "appStoreVersionLocalizations",
                    "id": loc_id,
                    "attributes": attrs,
                }
            },
            ok_codes={200, 204, 409, 422},
        )
        # First version / locked state: ASC rejects editing whatsNew — drop it and retry.
        raw = str(patched.get("raw") or "")
        if patched.get("errors") or "whatsNew" in raw:
            attrs_no_wn = {k: v for k, v in attrs.items() if k != "whatsNew"}
            api(
                "PATCH",
                f"/v1/appStoreVersionLocalizations/{loc_id}",
                token,
                {
                    "data": {
                        "type": "appStoreVersionLocalizations",
                        "id": loc_id,
                        "attributes": attrs_no_wn,
                    }
                },
                ok_codes={200, 204, 409, 422},
            )
            warn("whatsNew not editable on this version (common for first release) — other listing fields updated.")
        info(f"Updated {locale} version localization.")
    return loc_id


def ensure_review_detail(token: str, version_id: str, meta: dict) -> None:
    email = os.environ.get("REVIEW_CONTACT_EMAIL", "atharvgups@gmail.com")
    first = os.environ.get("REVIEW_CONTACT_FIRST_NAME", "Atharv")
    last = os.environ.get("REVIEW_CONTACT_LAST_NAME", "Gupta")
    phone = os.environ.get("REVIEW_CONTACT_PHONE", "").strip()
    if not phone:
        die(
            "REVIEW_CONTACT_PHONE is required by App Store Connect for App Review. "
            "Add it as a GitHub Actions secret, then re-run the App Store workflow."
        )
    existing = api(
        "GET", f"/v1/appStoreVersions/{version_id}/appStoreReviewDetail", token
    ).get("data")
    attrs = {
        "contactEmail": email,
        "contactFirstName": first,
        "contactLastName": last,
        "contactPhone": phone,
        "demoAccountRequired": False,
        "notes": meta.get("review_notes", ""),
    }
    if existing:
        api(
            "PATCH",
            f"/v1/appStoreReviewDetails/{existing['id']}",
            token,
            {
                "data": {
                    "type": "appStoreReviewDetails",
                    "id": existing["id"],
                    "attributes": attrs,
                }
            },
        )
        info("Updated App Review contact / notes.")
    else:
        api(
            "POST",
            "/v1/appStoreReviewDetails",
            token,
            {
                "data": {
                    "type": "appStoreReviewDetails",
                    "attributes": attrs,
                    "relationships": {
                        "appStoreVersion": {
                            "data": {"type": "appStoreVersions", "id": version_id}
                        }
                    },
                }
            },
        )
        info("Created App Review contact / notes.")


def ensure_export_compliance(token: str, build_id: str) -> None:
    """Declare usesNonExemptEncryption=false on the build (standard HTTPS only)."""
    result = api(
        "PATCH",
        f"/v1/builds/{build_id}",
        token,
        {
            "data": {
                "type": "builds",
                "id": build_id,
                "attributes": {"usesNonExemptEncryption": False},
            }
        },
        ok_codes={200, 204, 409, 403, 422},
    )
    if result.get("errors"):
        warn(
            "Could not set usesNonExemptEncryption on the build "
            "(may already be answered in ASC). Continuing."
        )
    else:
        info("Set usesNonExemptEncryption=false on the build.")


def ensure_app_info(token: str, app_id: str, meta: dict) -> None:
    infos = api("GET", f"/v1/apps/{app_id}/appInfos?limit=5", token).get("data") or []
    if not infos:
        warn("No appInfos found — skip name/subtitle/privacy/category.")
        return
    # Prefer the one tied to the prepare-for-submission state when present.
    app_info = infos[0]
    for info_row in infos:
        state = (info_row.get("attributes") or {}).get("appStoreState")
        if state in editable_states() or state in {"READY_FOR_DISTRIBUTION", "REPLACE_YOUR_BINARY"}:
            app_info = info_row
            break
    info_id = app_info["id"]

    # Categories
    cats = api(
        "GET",
        "/v1/appCategories?filter[platforms]=IOS&limit=200",
        token,
    ).get("data") or []
    by_id = {c["id"]: c for c in cats}
    # ASC uses IDs like "FOOD_AND_DRINK"
    primary = meta.get("primary_category", "FOOD_AND_DRINK")
    secondary = meta.get("secondary_category")
    if primary in by_id or True:
        body: dict = {
            "data": {
                "type": "appInfos",
                "id": info_id,
                "relationships": {
                    "primaryCategory": {
                        "data": {"type": "appCategories", "id": primary}
                    }
                },
            }
        }
        if secondary:
            body["data"]["relationships"]["secondaryCategory"] = {
                "data": {"type": "appCategories", "id": secondary}
            }
        api("PATCH", f"/v1/appInfos/{info_id}", token, body, ok_codes={200, 204, 409, 422})
        info(f"Set categories primary={primary} secondary={secondary}.")

    locale = meta.get("locale", "en-US")
    locs = api(
        "GET", f"/v1/appInfos/{info_id}/appInfoLocalizations?limit=10", token
    ).get("data") or []
    loc_id = None
    for loc in locs:
        if (loc.get("attributes") or {}).get("locale") == locale:
            loc_id = loc["id"]
            break
    loc_attrs = {
        "name": meta.get("name", "Anteats"),
        "subtitle": meta.get("subtitle", ""),
        "privacyPolicyUrl": meta.get("privacy_policy_url"),
        "privacyChoicesUrl": None,
    }
    if loc_id is None:
        created = api(
            "POST",
            "/v1/appInfoLocalizations",
            token,
            {
                "data": {
                    "type": "appInfoLocalizations",
                    "attributes": {"locale": locale, **{k: v for k, v in loc_attrs.items() if v}},
                    "relationships": {
                        "appInfo": {"data": {"type": "appInfos", "id": info_id}}
                    },
                }
            },
        )
        loc_id = (created.get("data") or {}).get("id")
        info(f"Created app info localization ({locale}).")
    else:
        api(
            "PATCH",
            f"/v1/appInfoLocalizations/{loc_id}",
            token,
            {
                "data": {
                    "type": "appInfoLocalizations",
                    "id": loc_id,
                    "attributes": {k: v for k, v in loc_attrs.items() if v is not None},
                }
            },
        )
        info(f"Updated app info localization ({locale}).")


def resize_screenshot(src: Path, dest: Path, size: tuple[int, int] = IPHONE_67_SIZE) -> Path:
    if Image is None:
        warn("Pillow missing. Uploading screenshots at original size.")
        return src
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


def _screenshot_sets(token: str, localization_id: str) -> list[dict]:
    return (
        api(
            "GET",
            f"/v1/appStoreVersionLocalizations/{localization_id}/appScreenshotSets?limit=20",
            token,
            ok_codes={200, 404},
        ).get("data")
        or []
    )


def _ensure_screenshot_set(token: str, localization_id: str, display: str, existing: list[dict]) -> str | None:
    for shot_set in existing:
        if (shot_set.get("attributes") or {}).get("screenshotDisplayType") == display:
            return shot_set["id"]
    created = api(
        "POST",
        "/v1/appScreenshotSets",
        token,
        {
            "data": {
                "type": "appScreenshotSets",
                "attributes": {"screenshotDisplayType": display},
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
    set_id = (created.get("data") or {}).get("id")
    if set_id:
        return set_id
    refreshed = _screenshot_sets(token, localization_id)
    for shot_set in refreshed:
        if (shot_set.get("attributes") or {}).get("screenshotDisplayType") == display:
            return shot_set["id"]
    warn(f"Could not create/find screenshot set {display}.")
    return None


def _clear_screenshot_set(token: str, set_id: str) -> None:
    existing = api(
        "GET", f"/v1/appScreenshotSets/{set_id}/appScreenshots?limit=20", token
    ).get("data") or []
    for shot in existing:
        for attempt in range(4):
            result = api(
                "DELETE",
                f"/v1/appScreenshots/{shot['id']}",
                token,
                ok_codes={200, 204, 404},
            )
            if not result.get("server_error"):
                break
            warn(f"ASC 5xx deleting screenshot {shot['id']}; retry {attempt + 1}")
            time.sleep(3 + attempt * 3)


def _screenshot_state(shot: dict) -> str:
    return str(((shot.get("attributes") or {}).get("assetDeliveryState") or {}).get("state") or "")


def _list_screenshots(token: str, set_id: str) -> list[dict]:
    return (
        api(
            "GET",
            f"/v1/appScreenshotSets/{set_id}/appScreenshots?limit=50"
            "&fields[appScreenshots]=assetDeliveryState,fileName",
            token,
            ok_codes={200, 404},
        ).get("data")
        or []
    )


def ensure_screenshots(token: str, localization_id: str, meta: dict) -> None:
    files = meta.get("screenshot_files") or []
    if not files:
        warn("No screenshot_files in metadata. Skipping screenshot upload.")
        return

    sources: list[tuple[str, Path]] = []
    for rel in files[:10]:
        src = (SCREENSHOT_ROOT / rel).resolve()
        if src.is_file():
            sources.append((rel, src))
        else:
            warn(f"Screenshot missing: {src}")
    if not sources:
        warn("No screenshot files on disk. Skipping screenshot upload.")
        return

    existing = _screenshot_sets(token, localization_id)
    tmp = Path(os.environ.get("RUNNER_TEMP", "/tmp")) / "anteats-screenshots"
    for display, size in SCREENSHOT_SLOTS.items():
        set_id = _ensure_screenshot_set(token, localization_id, display, existing)
        if not set_id:
            continue
        shots = _list_screenshots(token, set_id)
        complete_n = sum(
            1
            for shot in shots
            if _screenshot_state(shot) in {"COMPLETE", "COMPLETE_WITH_WARNINGS"}
        )
        failed_n = sum(1 for shot in shots if _screenshot_state(shot) == "FAILED")
        pending_n = len(shots) - complete_n - failed_n
        if complete_n >= min(len(sources), 8) or (complete_n >= 3 and pending_n == 0):
            info(
                f"{display} already has {complete_n} complete screenshot(s); skipping re-upload."
            )
            continue
        if shots and pending_n:
            info(
                f"{display}: {pending_n} screenshot(s) still processing "
                f"({complete_n} complete). Waiting instead of replacing."
            )
            continue
        _clear_screenshot_set(token, set_id)
        for index, (rel, src) in enumerate(sources):
            prepared = resize_screenshot(src, tmp / display / f"{index:02d}.png", size)
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
                ops = ((detail.get("data") or {}).get("attributes") or {}).get(
                    "uploadOperations"
                ) or []
            if not shot_id or not ops:
                warn(f"No upload operations for {rel} → {display}")
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
            info(f"Uploaded screenshot {rel} → {display} {size[0]}x{size[1]}")
        existing = _screenshot_sets(token, localization_id)


def ensure_preview(token: str, localization_id: str, meta: dict) -> None:
    rel = meta.get("preview_file") or "docs/previews/iphone67.mp4"
    src = Path(os.environ.get("PREVIEW_FILE", "").strip() or (SCREENSHOT_ROOT / rel))
    if not src.is_file():
        warn(f"Preview file missing ({src}). Skipping preview upload.")
        return
    if "\u2014" in src.name:
        die("Preview filename contains an em dash.")
    data = src.read_bytes()
    if not data:
        warn(f"Preview file empty ({src}). Skipping preview upload.")
        return
    try:
        probe = subprocess.check_output(
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
                str(src),
            ],
            text=True,
        )
        info_json = json.loads(probe)
        duration = float((info_json.get("format") or {}).get("duration") or 0)
        stream = (info_json.get("streams") or [{}])[0]
        width = int(stream.get("width") or 0)
        height = int(stream.get("height") or 0)
        info(f"Preview {src.name} {width}x{height} {duration:.1f}s")
        if duration and (duration < 15 or duration > 30):
            warn(
                f"Preview is {duration:.1f}s (Apple wants 15-30). Uploading anyway."
            )
    except (OSError, subprocess.CalledProcessError, json.JSONDecodeError, ValueError) as exc:
        warn(f"Could not probe preview ({exc}); uploading {src.name} as-is.")

    sets = api(
        "GET",
        f"/v1/appStoreVersionLocalizations/{localization_id}/appPreviewSets?limit=20",
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
                                "id": localization_id,
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
                f"/v1/appStoreVersionLocalizations/{localization_id}/appPreviewSets?limit=20",
                token,
                ok_codes={200, 404},
            ).get("data") or []
            for preview_set in refreshed:
                if (preview_set.get("attributes") or {}).get("previewType") == PREVIEW_TYPE:
                    set_id = preview_set["id"]
                    break
    if not set_id:
        warn(f"Could not create/find preview set {PREVIEW_TYPE}. Skipping preview.")
        return

    existing = api(
        "GET", f"/v1/appPreviewSets/{set_id}/appPreviews?limit=10", token
    ).get("data") or []
    ready = [
        preview
        for preview in existing
        if _preview_delivery(preview) in {"COMPLETE", "COMPLETE_WITH_WARNINGS"}
        or _preview_video(preview) in {"COMPLETE", "COMPLETE_WITH_WARNINGS"}
    ]
    if ready:
        info("Preview already on ASC and complete; skipping re-upload.")
        return
    processing = [
        preview
        for preview in existing
        if _preview_is_processing(preview)
    ]
    if processing:
        info("Preview already uploaded and still processing; waiting instead of replacing it.")
        if _wait_preview_complete(token, processing[0]["id"], seconds=900):
            return
        warn("Existing preview still processing after wait; not deleting it.")
        return
    for preview in existing:
        for attempt in range(4):
            result = api(
                "DELETE",
                f"/v1/appPreviews/{preview['id']}",
                token,
                ok_codes={200, 204, 404},
            )
            if not result.get("server_error"):
                break
            warn(f"ASC 5xx deleting preview {preview['id']}; retry {attempt + 1}")
            time.sleep(3 + attempt * 3)

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
                    "previewFrameTimeCode": "00:00:05:00",
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
        warn(f"No upload operations for preview. Raw: {json.dumps(reserve)[:800]}")
        return
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
                    "previewFrameTimeCode": "00:00:05:00",
                },
            }
        },
        ok_codes={200, 204, 409, 422},
    )
    info(f"Uploaded preview {src.name} ({len(data)} bytes) to {PREVIEW_TYPE}.")
    if not _wait_preview_complete(token, preview_id, seconds=900):
        warn("Timed out waiting for preview processing; continuing submit.")


def _preview_attrs(preview: dict) -> dict:
    return preview.get("attributes") or {}


def _preview_delivery(preview: dict) -> str:
    return str((_preview_attrs(preview).get("assetDeliveryState") or {}).get("state") or "")


def _preview_video(preview: dict) -> str:
    return str((_preview_attrs(preview).get("videoDeliveryState") or {}).get("state") or "")


def _preview_is_processing(preview: dict) -> bool:
    states = {_preview_delivery(preview), _preview_video(preview)}
    return any(
        state in {"PROCESSING", "WAIT_FOR_PROCESSING", "UPLOAD_COMPLETE", "AWAITING_UPLOAD"}
        or "PROCESS" in state
        for state in states
        if state
    )


def _wait_preview_complete(token: str, preview_id: str, seconds: int = 900) -> bool:
    deadline = time.time() + seconds
    while time.time() < deadline:
        detail = api("GET", f"/v1/appPreviews/{preview_id}", token)
        attrs = (detail.get("data") or {}).get("attributes") or {}
        delivery = str((attrs.get("assetDeliveryState") or {}).get("state") or "")
        video = str((attrs.get("videoDeliveryState") or {}).get("state") or "")
        info(f"Preview processing delivery={delivery} video={video}")
        if delivery == "FAILED" or video == "FAILED":
            warn(f"ASC failed to process the preview. attrs={json.dumps(attrs)[:800]}")
            return False
        if delivery in {"COMPLETE", "COMPLETE_WITH_WARNINGS"}:
            info("Preview asset is COMPLETE.")
            return True
        time.sleep(15)
    return False



def _age_rating_content_attrs() -> dict:
    none_keys = [
        "alcoholTobaccoOrDrugUseOrReferences",
        "contests",
        "gamblingSimulated",
        "medicalOrTreatmentInformation",
        "profanityOrCrudeHumor",
        "sexualContentGraphicAndNudity",
        "sexualContentOrNudity",
        "horrorOrFearThemes",
        "matureOrSuggestiveThemes",
        "violenceCartoonOrFantasy",
        "violenceRealistic",
        "violenceRealisticProlongedGraphicOrSadistic",
        "gunsOrOtherWeapons",
    ]
    attrs = {k: "NONE" for k in none_keys}
    attrs.update(_age_rating_capability_attrs())
    attrs.update(
        {
            "gambling": False,
            "unrestrictedWebAccess": False,
            "lootBox": False,
        }
    )
    return attrs


def _age_rating_capability_attrs() -> dict:
    # ASC 4.4.1 (Sept 2026) requires socialMedia on review attach.
    return {
        "healthOrWellnessTopics": False,
        "messagingAndChat": False,
        "parentalControls": False,
        "ageAssurance": False,
        "advertising": False,
        "userGeneratedContent": False,
        "socialMedia": False,
        "socialMediaAgeRestricted": False,
    }


def _patch_age_rating(token: str, decl_id: str, attrs: dict) -> dict:
    return api(
        "PATCH",
        f"/v1/ageRatingDeclarations/{decl_id}",
        token,
        {
            "data": {
                "type": "ageRatingDeclarations",
                "id": decl_id,
                "attributes": attrs,
            }
        },
        ok_codes={200, 204, 409, 422},
    )


def _age_rating_patch_applied(result: dict) -> bool:
    if result.get("data") is not None:
        return True
    if result.get("errors") or result.get("already_exists"):
        return False
    return True


def _collect_age_rating_decls(
    token: str, version_id: str, app_id: str
) -> list[tuple[str, dict]]:
    """Editable AppInfo first. Live READY_FOR_SALE declarations are often locked."""
    found: list[tuple[str, dict]] = []
    seen: set[str] = set()

    def add(source: str, decl: dict | None) -> None:
        if not decl or not decl.get("id") or decl["id"] in seen:
            return
        seen.add(decl["id"])
        found.append((source, decl))

    infos = api("GET", f"/v1/apps/{app_id}/appInfos?limit=5", token).get("data") or []
    editable: list[tuple[str, dict | None]] = []
    other: list[tuple[str, dict | None]] = []
    for info_row in infos:
        state = (info_row.get("attributes") or {}).get("appStoreState")
        decl = api(
            "GET",
            f"/v1/appInfos/{info_row['id']}/ageRatingDeclaration",
            token,
            ok_codes={200, 404},
        ).get("data")
        label = f"appInfo {info_row['id']} state={state}"
        (editable if state in editable_states() else other).append((label, decl))
    for source, decl in editable + other:
        add(source, decl)

    version_decl = api(
        "GET",
        f"/v1/appStoreVersions/{version_id}/ageRatingDeclaration",
        token,
        ok_codes={200, 404},
    ).get("data")
    add(f"appStoreVersion {version_id}", version_decl)
    return found


def ensure_age_rating(token: str, version_id: str, app_id: str) -> None:
    """Mark a clean age questionnaire, including required socialMedia=false."""
    decls = _collect_age_rating_decls(token, version_id, app_id)
    if not decls:
        die(
            "No ageRatingDeclaration found. In App Store Connect → App Information → "
            "Age Ratings, answer Social Media = No, then re-run."
        )

    attempts: list[tuple[str, dict]] = [
        ("full", _age_rating_content_attrs()),
        ("capabilities", _age_rating_capability_attrs()),
        ("socialMedia", {"socialMedia": False}),
        ("socialMedia+restricted", {"socialMedia": False, "socialMediaAgeRestricted": False}),
    ]
    last_raw = ""
    applied = False
    for source, decl in decls:
        for label, attrs in attempts:
            result = _patch_age_rating(token, decl["id"], attrs)
            if _age_rating_patch_applied(result):
                info(f"Updated age rating ({label}) on {source}.")
                applied = True
                break
            last_raw = str(result.get("raw") or json.dumps(result))
            info(f"Age rating PATCH {label} on {source} did not apply: {last_raw[:400]}")
    if not applied:
        die(
            "Age rating PATCH could not set socialMedia. App Review attach will fail. "
            "In App Store Connect → App Information → Age Ratings, answer Social Media = No "
            f"(no social feed in Anteats). Detail: {last_raw[:2000]}"
        )


def ensure_app_privacy(token: str, app_id: str) -> None:
    """Best-effort Data Not Collected declaration + publish.

    Official ASC Connect API often 404s ``appDataUsages`` (Apple gates nutrition
    labels behind the App Store Connect UI). Never hard-fail here — surface a
    clear App Privacy Publish reminder and let review attach report the real
    remaining blocker.
    """
    usages = api(
        "GET",
        f"/v1/apps/{app_id}/dataUsages?limit=50&include=dataProtection,category,purpose",
        token,
        ok_codes={200, 404, 403},
    )
    if usages.get("errors") or (
        isinstance(usages.get("raw"), str) and "does not exist" in (usages.get("raw") or "")
    ):
        warn(
            "App Privacy dataUsages API unavailable — Atharv must open "
            "App Store Connect → App Privacy → Data Not Collected → Publish."
        )
        return

    rows = usages.get("data") or []

    def protection_id(usage: dict) -> str | None:
        rel = ((usage.get("relationships") or {}).get("dataProtection") or {}).get("data") or {}
        return rel.get("id")

    prior_count = len(rows)
    has_not_collected = any(protection_id(u) == "DATA_NOT_COLLECTED" for u in rows)
    if rows and not has_not_collected:
        for usage in rows:
            uid = usage.get("id")
            if not uid:
                continue
            api(
                "DELETE",
                f"/v1/appDataUsages/{uid}",
                token,
                ok_codes={200, 204, 404, 409, 422},
            )
        rows = []
        has_not_collected = False
        info(f"Cleared {prior_count} prior appDataUsages rows.")

    if not has_not_collected:
        created = api(
            "POST",
            "/v1/appDataUsages",
            token,
            {
                "data": {
                    "type": "appDataUsages",
                    "relationships": {
                        "app": {"data": {"type": "apps", "id": app_id}},
                        "dataProtection": {
                            "data": {
                                "type": "appDataUsageDataProtections",
                                "id": "DATA_NOT_COLLECTED",
                            }
                        },
                    },
                }
            },
            ok_codes={200, 201, 404, 409, 422},
        )
        if created.get("errors") and not created.get("data"):
            warn(
                "Could not declare DATA_NOT_COLLECTED via API (often unavailable). "
                "Atharv: App Store Connect → App Privacy → Data Not Collected → Publish. "
                f"Detail: {json.dumps(created)[:600]}"
            )
            return
        info("Declared App Privacy: DATA_NOT_COLLECTED.")
    else:
        info("App Privacy already declares DATA_NOT_COLLECTED.")

    state = api(
        "GET",
        f"/v1/apps/{app_id}/dataUsagePublishState",
        token,
        ok_codes={200, 404, 403},
    ).get("data")
    if not state:
        warn(
            "No dataUsagePublishState via API — Atharv must Publish App Privacy "
            "in App Store Connect if submit still fails."
        )
        return
    if (state.get("attributes") or {}).get("published") is True:
        info("App Privacy answers already published.")
        return
    published = api(
        "PATCH",
        f"/v1/appDataUsagesPublishState/{state['id']}",
        token,
        {
            "data": {
                "type": "appDataUsagesPublishState",
                "id": state["id"],
                "attributes": {"published": True},
            }
        },
        ok_codes={200, 204, 404, 409, 422},
    )
    if published.get("errors") and not published.get("data"):
        warn(
            "Could not publish App Privacy via API. "
            "Atharv: App Store Connect → App Privacy → Publish. "
            f"Detail: {json.dumps(published)[:600]}"
        )
        return
    info("Published App Privacy answers (Data Not Collected).")


def wait_for_screenshot_processing(
    token: str, localization_id: str, timeout_s: int | None = None
) -> None:
    """Avoid ASSET_IN_POST_PROCESSING on review attach."""
    timeout = SCREENSHOT_WAIT if timeout_s is None else timeout_s
    deadline = time.time() + timeout
    while time.time() < deadline:
        sets = api(
            "GET",
            f"/v1/appStoreVersionLocalizations/{localization_id}/appScreenshotSets?limit=10",
            token,
            ok_codes={200, 404},
        ).get("data") or []
        pending = 0
        complete = 0
        for shot_set in sets:
            display = (shot_set.get("attributes") or {}).get("screenshotDisplayType")
            if display and display not in SCREENSHOT_SLOTS:
                continue
            for shot in _list_screenshots(token, shot_set["id"]):
                state = _screenshot_state(shot)
                if state in {"COMPLETE", "COMPLETE_WITH_WARNINGS"}:
                    complete += 1
                elif state != "FAILED":
                    pending += 1
        if pending == 0:
            if complete == 0:
                die("No complete App Store screenshots after wait. Re-run after media uploads.")
            info(f"Screenshot assets ready for review ({complete} complete).")
            return
        info(f"Waiting for {pending} screenshot(s) to finish processing…")
        time.sleep(20)
    die(
        f"Screenshots still processing after {timeout}s. Re-run submit_only once "
        "App Store Connect shows the listing screenshots as ready."
    )


def cancel_in_flight_review_submissions(token: str, app_id: str) -> None:
    """Cancel WAITING_FOR_REVIEW drafts only. Never cancel IN_REVIEW / approved."""
    q = urllib.parse.urlencode(
        {
            "filter[app]": app_id,
            "filter[platform]": "IOS",
            "limit": "10",
        }
    )
    existing = api("GET", f"/v1/reviewSubmissions?{q}", token).get("data") or []
    approved_or_live = any(
        (v.get("attributes") or {}).get("appStoreState") in (RELEASE_STATES | LIVE_OR_RELEASING_STATES)
        for v in list_ios_versions(token, app_id)
    )
    with_apple = [
        sub
        for sub in existing
        if (sub.get("attributes") or {}).get("state")
        in {"IN_REVIEW", "PROCESSING_FOR_REVIEW"}
    ]
    if with_apple and approved_or_live:
        info(
            "An IN_REVIEW submission record is still listed, but a version is "
            "already approved or live — not canceling it."
        )
        with_apple = []
    if with_apple:
        state = (with_apple[0].get("attributes") or {}).get("state")
        die(
            f"An App Review submission is still {state}. Do not cancel — "
            "1.0.221 was approved for distribution. Wait until it is "
            "Pending Developer Release or Ready for Sale, then re-run."
        )
    in_flight = [
        sub
        for sub in existing
        if (sub.get("attributes") or {}).get("state")
        in {"WAITING_FOR_REVIEW", "CANCELING"}
    ]
    if not in_flight:
        return
    if not CANCEL_IN_FLIGHT:
        die(
            "An App Review submission is still WAITING_FOR_REVIEW. "
            "Cancel it in App Store Connect → Anteats → App Review → Cancel Submission, "
            "then re-run. Or set CANCEL_IN_FLIGHT_REVIEW=true."
        )
    for sub in in_flight:
        sid = sub["id"]
        state = (sub.get("attributes") or {}).get("state")
        info(f"Canceling in-flight reviewSubmission {sid} (state={state})…")
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
                "Do this once in the UI: App Store Connect → Anteats → App Review → "
                "Cancel Submission (or remove this version from review), then re-run "
                f"appstore-*. Detail: {json.dumps(result)[:1500]}"
            )
        # Poll until COMPLETE / CANCELED so create isn't blocked.
        deadline = time.time() + 180
        while time.time() < deadline:
            detail = api("GET", f"/v1/reviewSubmissions/{sid}", token, ok_codes={200, 404})
            new_state = ((detail.get("data") or {}).get("attributes") or {}).get("state")
            info(f"Cancel poll: {sid} → {new_state}")
            if new_state in {"COMPLETE", "COMPLETED", "CANCELED", "CANCELLED", None}:
                break
            if new_state == "CANCELING":
                time.sleep(5)
                continue
            time.sleep(5)
        else:
            warn(
                f"Cancel of {sid} still settling — continuing; create may need a UI cancel "
                "if ASC returns CONCURRENT_REVIEW_SUBMISSION_LIMIT_EXCEEDED."
            )


def submit_for_review(token: str, app_id: str, version_id: str) -> None:
    cancel_in_flight_review_submissions(token, app_id)

    q = urllib.parse.urlencode(
        {
            "filter[app]": app_id,
            "filter[platform]": "IOS",
            "limit": "10",
        }
    )
    existing = api("GET", f"/v1/reviewSubmissions?{q}", token).get("data") or []
    reusable_id: str | None = None
    for sub in existing:
        state = (sub.get("attributes") or {}).get("state")
        info(f"Existing reviewSubmission state={state}")
        if state in {"WAITING_FOR_REVIEW", "IN_REVIEW", "PROCESSING_FOR_REVIEW"}:
            die(
                f"Still in review after cancel attempt (state={state}). "
                "App Store Connect → Anteats → App Review → Cancel Submission, then re-run."
            )
        if state in {"READY_FOR_REVIEW", "UNRESOLVED_ISSUES"} and reusable_id is None:
            # Prefer reuse — ASC often refuses cancel ("not cancellable") and then
            # blocks create with CONCURRENT_REVIEW_SUBMISSION_LIMIT_EXCEEDED.
            reusable_id = sub["id"]

    submission_id = reusable_id
    if submission_id:
        info(f"Reusing open review submission {submission_id}.")
    else:
        created = api(
            "POST",
            "/v1/reviewSubmissions",
            token,
            {
                "data": {
                    "type": "reviewSubmissions",
                    "attributes": {"platform": "IOS"},
                    "relationships": {
                        "app": {"data": {"type": "apps", "id": app_id}}
                    },
                }
            },
            ok_codes={200, 201, 409, 422},
        )
        submission_id = (created.get("data") or {}).get("id")
        if not submission_id:
            # Last resort: pick any non-terminal submission ASC still holds.
            for sub in existing:
                state = (sub.get("attributes") or {}).get("state")
                if state not in {
                    "COMPLETE",
                    "COMPLETED",
                    "CANCELED",
                    "CANCELLED",
                    None,
                }:
                    submission_id = sub["id"]
                    info(
                        f"Create blocked; falling back to existing submission "
                        f"{submission_id} (state={state})."
                    )
                    break
        if not submission_id:
            die(
                "Could not create or reuse a review submission. In App Store Connect "
                "→ App Review, cancel leftover draft submissions, and confirm App Privacy "
                "is Published (Data Not Collected), then re-run. "
                f"Detail: {json.dumps(created)[:1500]}"
            )

    item: dict = {}
    for attempt in range(8):
        item = api(
            "POST",
            "/v1/reviewSubmissionItems",
            token,
            {
                "data": {
                    "type": "reviewSubmissionItems",
                    "relationships": {
                        "reviewSubmission": {
                            "data": {"type": "reviewSubmissions", "id": submission_id}
                        },
                        "appStoreVersion": {
                            "data": {"type": "appStoreVersions", "id": version_id}
                        },
                    },
                }
            },
            ok_codes={200, 201, 409, 422},
        )
        if item.get("data"):
            break
        raw = str(item.get("raw") or json.dumps(item))
        if "socialMedia" in raw:
            die(
                "App Review attach still missing age-rating socialMedia. "
                "In App Store Connect → App Information → Age Ratings, answer "
                f"Social Media = No, then re-run. Detail: {raw[:2000]}"
            )
        if "ASSET_IN_POST_PROCESSING" in raw:
            info(
                f"Screenshots still processing on attach attempt {attempt + 1}/8; waiting 30s."
            )
            time.sleep(30)
            continue
        if item.get("errors") and not item.get("data"):
            if "ENTITY_STATE_INVALID" in raw or "ATTRIBUTE.REQUIRED" in raw:
                die(
                    "Could not add appStoreVersion to review submission (often incomplete "
                    "App Privacy Publish, age rating, or screenshots). "
                    f"Detail: {raw[:2500]}"
                )
            info(f"Attach 409 treated as already present: {raw[:300]}")
        break

    items = api(
        "GET",
        f"/v1/reviewSubmissions/{submission_id}/items?limit=20",
        token,
        ok_codes={200, 404},
    ).get("data") or []
    info(f"Review submission items: {len(items)}")
    if not items:
        die(
            "Review submission has zero items after attach. "
            "Usually App Privacy is not Published, age rating socialMedia is unset, "
            "or screenshots are still processing. "
            f"Attach attempt: {json.dumps(item)[:2000]}"
        )

    # Do not treat 409 as success here — we need the real error body.
    url = f"{API}/v1/reviewSubmissions/{submission_id}"
    body = {
        "data": {
            "type": "reviewSubmissions",
            "id": submission_id,
            "attributes": {"submitted": True},
        }
    }
    data = json.dumps(body).encode()
    req = urllib.request.Request(
        url,
        data=data,
        method="PATCH",
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
            "Accept": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=90) as resp:
            raw = resp.read()
            confirmed = json.loads(raw) if raw else {}
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", "replace")
        die(
            "ASC rejected submitted=true. In App Store Connect complete: "
            "App Privacy (Data Not Collected — Publish), and clear any stuck "
            "App Review drafts. Then re-run. "
            f"HTTP {exc.code}: {detail[:1200]}"
        )

    state = ((confirmed.get("data") or {}).get("attributes") or {}).get("state")
    if not state:
        detail = api("GET", f"/v1/reviewSubmissions/{submission_id}", token)
        state = ((detail.get("data") or {}).get("attributes") or {}).get("state")
    if state in {"WAITING_FOR_REVIEW", "IN_REVIEW", "PROCESSING_FOR_REVIEW"}:
        info(f"Submitted for App Store review. State: {state}")
        return
    die(
        "Review submission is not with App Review yet "
        f"(state={state!r}). Finish App Privacy (Publish Data Not Collected) in "
        "App Store Connect, then re-run appstore-* . "
        f"Raw: {json.dumps(confirmed)[:800]}"
    )



def main() -> None:
    meta = load_metadata()
    token = make_token()
    app_id = find_app_id(token)
    info(f"App {BUNDLE_ID} → {app_id}")

    version_string = MARKETING_VERSION or meta.get("default_version") or "1.0.25"
    global BUILD_NUMBER
    if not BUILD_NUMBER:
        BUILD_NUMBER = str(meta.get("default_build") or "").strip()
    build = wait_for_build(token, app_id)
    build_id = build["id"]
    build_ver = (build.get("attributes") or {}).get("version")
    info(f"Using build CFBundleVersion={build_ver} id={build_id}")

    # Put the approved first version on sale, then cancel leftover WAITING drafts
    # (never IN_REVIEW) so ASC will allow creating the next marketing version.
    release_pending_developer_release(token, app_id)
    cancel_in_flight_review_submissions(token, app_id)

    version = get_or_create_version(token, app_id, version_string)
    version_id = version["id"]
    attach_build(token, version_id, build_id)
    ensure_release_type(token, app_id, version_id)
    ensure_export_compliance(token, build_id)
    ensure_content_rights(token, app_id)
    ensure_version_copyright(token, version_id, meta)
    ensure_app_privacy(token, app_id)
    ensure_app_info(token, app_id, meta)
    loc_id = ensure_version_localization(token, version_id, meta)
    ensure_review_detail(token, version_id, meta)
    ensure_age_rating(token, version_id, app_id)
    try:
        ensure_screenshots(token, loc_id, meta)
    except SystemExit:
        raise
    except Exception as exc:  # noqa: BLE001 — best-effort screenshots
        warn(f"Screenshot upload failed ({exc}); continue and let ASC validate.")
    wait_for_screenshot_processing(token, loc_id)
    try:
        ensure_preview(token, loc_id, meta)
    except SystemExit:
        raise
    except Exception as exc:  # noqa: BLE001 — best-effort preview
        warn(f"Preview upload failed ({exc}); continue and let ASC validate.")

    if not SUBMIT:
        info("SUBMIT_FOR_REVIEW=false — listing prepared, not submitted.")
        return

    submit_for_review(token, app_id, version_id)
    info(
        "Done. Watch App Store Connect → App Review. "
        "If Apple still asks for App Privacy Publish or extra screenshot sizes, finish those once in the UI."
    )


if __name__ == "__main__":
    main()
