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
MAX_WAIT = int(os.environ.get("BUILD_WAIT_SECONDS", "2400"))

# iPhone 6.7" App Store slot (iPhone 15 Pro Max / similar).
IPHONE_67_SIZE = (1290, 2796)
IPHONE_67_DISPLAY = "APP_IPHONE_67"


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
    return json.loads(METADATA_PATH.read_text())


def list_builds(token: str, app_id: str, limit: int = 40) -> list[dict]:
    q = urllib.parse.urlencode(
        {
            "filter[app]": app_id,
            "sort": "-uploadedDate",
            "limit": str(limit),
            "fields[builds]": "version,processingState,uploadedDate,expired",
        }
    )
    return api("GET", f"/v1/builds?{q}", token).get("data") or []


def wait_for_build(token: str, app_id: str) -> dict:
    deadline = time.time() + MAX_WAIT
    last = None
    while time.time() < deadline:
        builds = list_builds(token, app_id)
        chosen = None
        if BUILD_NUMBER:
            for b in builds:
                if str((b.get("attributes") or {}).get("version")) == str(BUILD_NUMBER):
                    chosen = b
                    break
        else:
            for b in builds:
                attrs = b.get("attributes") or {}
                if attrs.get("expired"):
                    continue
                if attrs.get("processingState") in {"VALID", "PROCESSING", "PROCESSING_EXCEPTION", None, "VALIDATING"}:
                    chosen = b
                    if attrs.get("processingState") == "VALID":
                        break
        if chosen:
            state = (chosen.get("attributes") or {}).get("processingState")
            ver = (chosen.get("attributes") or {}).get("version")
            info(f"Build {ver}: processingState={state}")
            last = state
            if state == "VALID":
                return chosen
            if state in {"INVALID", "FAILED"}:
                die(f"Build ended in state {state}")
        else:
            info("Waiting for a build to appear…")
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


def get_or_create_version(token: str, app_id: str, version_string: str) -> dict:
    q = urllib.parse.urlencode(
        {
            "filter[platform]": "IOS",
            "limit": "20",
            "fields[appStoreVersions]": "versionString,appStoreState,platform",
        }
    )
    versions = api("GET", f"/v1/apps/{app_id}/appStoreVersions?{q}", token).get("data") or []
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
    )
    if created.get("already_exists"):
        die("Could not create app store version and no editable draft exists.")
    version = created.get("data")
    if not version:
        die("Creating appStoreVersion returned empty data.")
    info(f"Created App Store version {version_string} ({version['id']})")
    return version


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


def resize_screenshot(src: Path, dest: Path) -> Path:
    if Image is None:
        warn("Pillow missing — uploading screenshots at original size.")
        return src
    dest.parent.mkdir(parents=True, exist_ok=True)
    im = Image.open(src).convert("RGB")
    # Cover-fit into 1290x2796 (center crop).
    tw, th = IPHONE_67_SIZE
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


def ensure_screenshots(token: str, localization_id: str, meta: dict) -> None:
    files = meta.get("screenshot_files") or []
    if not files:
        warn("No screenshot_files in metadata — skipping screenshot upload.")
        return

    sets = api(
        "GET",
        f"/v1/appStoreVersionLocalizations/{localization_id}/appScreenshotSets?limit=20",
        token,
    ).get("data") or []
    set_id = None
    for s in sets:
        if (s.get("attributes") or {}).get("screenshotDisplayType") == IPHONE_67_DISPLAY:
            set_id = s["id"]
            break
    if set_id is None:
        created = api(
            "POST",
            "/v1/appScreenshotSets",
            token,
            {
                "data": {
                    "type": "appScreenshotSets",
                    "attributes": {"screenshotDisplayType": IPHONE_67_DISPLAY},
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
        )
        if created.get("already_exists"):
            sets = api(
                "GET",
                f"/v1/appStoreVersionLocalizations/{localization_id}/appScreenshotSets?limit=20",
                token,
            ).get("data") or []
            for s in sets:
                if (s.get("attributes") or {}).get("screenshotDisplayType") == IPHONE_67_DISPLAY:
                    set_id = s["id"]
                    break
        else:
            set_id = (created.get("data") or {}).get("id")
    if not set_id:
        warn("Could not create/find APP_IPHONE_67 screenshot set — upload screenshots in ASC UI.")
        return

    # Clear existing screenshots so we replace with the current set.
    existing = api(
        "GET", f"/v1/appScreenshotSets/{set_id}/appScreenshots?limit=20", token
    ).get("data") or []
    for shot in existing:
        api("DELETE", f"/v1/appScreenshots/{shot['id']}", token, ok_codes={200, 204, 404})

    tmp = Path(os.environ.get("RUNNER_TEMP", "/tmp")) / "anteats-screenshots"
    for index, rel in enumerate(files[:10]):
        src = (SCREENSHOT_ROOT / rel).resolve()
        if not src.is_file():
            warn(f"Screenshot missing: {src}")
            continue
        prepared = resize_screenshot(src, tmp / f"{index:02d}.png")
        data = prepared.read_bytes()
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
            # Some API versions put uploadOperations in included — try refetch.
            detail = api("GET", f"/v1/appScreenshots/{shot_id}", token) if shot_id else {}
            ops = ((detail.get("data") or {}).get("attributes") or {}).get("uploadOperations") or []
        if not shot_id or not ops:
            warn(f"No upload operations for {rel}; skip.")
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
            # Default content type for PNG if ASC omitted headers.
            headers.setdefault("Content-Type", mimetypes.guess_type(prepared.name)[0] or "image/png")
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
                        "sourceFileChecksum": None,
                    },
                }
            },
            ok_codes={200, 204, 409, 422},
        )
        info(f"Uploaded screenshot {rel} → {IPHONE_67_DISPLAY}")



def ensure_age_rating(token: str, version_id: str, app_id: str) -> None:
    """Mark a clean age questionnaire for a campus utility with no mature content."""
    decl = api(
        "GET",
        f"/v1/appStoreVersions/{version_id}/ageRatingDeclaration",
        token,
        ok_codes={200, 404},
    ).get("data")
    if not decl:
        # Newer ASC apps hang the questionnaire off appInfo instead.
        infos = api("GET", f"/v1/apps/{app_id}/appInfos?limit=5", token).get("data") or []
        for info_row in infos:
            decl = api(
                "GET",
                f"/v1/appInfos/{info_row['id']}/ageRatingDeclaration",
                token,
                ok_codes={200, 404},
            ).get("data")
            if decl:
                break
    if not decl:
        warn("No ageRatingDeclaration found — complete Age Rating once in App Store Connect.")
        return
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
    # Prefer modern INFREQUENT/FREQUENT enums; fall back values still accepted as NONE.
    attrs = {k: "NONE" for k in none_keys}
    attrs.update(
        {
            "gambling": False,
            "unrestrictedWebAccess": False,
            "lootBox": False,
            "healthOrWellnessTopics": False,
            "messagingAndChat": False,
            "parentalControls": False,
            "ageAssurance": False,
            # ASC 2025+ capabilities — required on PATCH or review attach fails.
            "advertising": False,
            "userGeneratedContent": False,
        }
    )
    result = api(
        "PATCH",
        f"/v1/ageRatingDeclarations/{decl['id']}",
        token,
        {
            "data": {
                "type": "ageRatingDeclarations",
                "id": decl["id"],
                "attributes": attrs,
            }
        },
        ok_codes={200, 204, 409, 422},
    )
    if result.get("errors") and not result.get("data"):
        die(
            "Age rating PATCH incomplete — ASC will reject App Review attach. "
            "In App Store Connect → App Information → Age Ratings, answer all "
            "capability questions (Advertising / UGC / Messaging = No for Anteats), "
            f"or fix the submit script attributes. Detail: {json.dumps(result)[:2000]}"
        )
    info("Updated age rating declaration (all content descriptors NONE).")




def submit_for_review(token: str, app_id: str, version_id: str) -> None:
    q = urllib.parse.urlencode(
        {
            "filter[app]": app_id,
            "filter[platform]": "IOS",
            "limit": "10",
        }
    )
    existing = api("GET", f"/v1/reviewSubmissions?{q}", token).get("data") or []
    for sub in existing:
        state = (sub.get("attributes") or {}).get("state")
        info(f"Existing reviewSubmission state={state}")
        if state in {"WAITING_FOR_REVIEW", "IN_REVIEW", "PROCESSING_FOR_REVIEW"}:
            info(f"Already in review (state={state}). Nothing to do.")
            return
        if state in {"READY_FOR_REVIEW", "UNRESOLVED_ISSUES"}:
            # Cancel stale drafts so we can create a clean submission with the version attached.
            api(
                "PATCH",
                f"/v1/reviewSubmissions/{sub['id']}",
                token,
                {
                    "data": {
                        "type": "reviewSubmissions",
                        "id": sub["id"],
                        "attributes": {"canceled": True},
                    }
                },
                ok_codes={200, 204, 409, 422},
            )
            info(f"Canceled stale review submission {sub['id']} (was {state}).")

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
    )
    submission_id = (created.get("data") or {}).get("id")
    if not submission_id:
        die(f"Could not create review submission: {json.dumps(created)[:800]}")

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
    if item.get("errors") and not item.get("data") and not item.get("already_exists"):
        die(
            "Could not add appStoreVersion to review submission (often incomplete "
            "Age Rating / Pricing / App Privacy). "
            f"Detail: {json.dumps(item)[:2500]}"
        )

    items = api(
        "GET",
        f"/v1/reviewSubmissions/{submission_id}/items?limit=20",
        token,
        ok_codes={200, 404},
    ).get("data") or []
    info(f"Review submission items: {len(items)}")
    if not items:
        die(
            "Review submission has zero items after attach — ASC will reject submit. "
            "Usually Age Rating (Advertising), Pricing (Free), or App Privacy is incomplete. "
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
            "Pricing (Free), App Privacy (Data Not Collected), Age Rating (if still open), "
            "and a Review contact phone. Then re-run. "
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
        f"(state={state!r}). Finish Pricing (Free) + App Privacy in App Store Connect, "
        "set GitHub secret REVIEW_CONTACT_PHONE if asked, then re-run appstore-* . "
        f"Raw: {json.dumps(confirmed)[:800]}"
    )



def main() -> None:
    meta = load_metadata()
    token = make_token()
    app_id = find_app_id(token)
    info(f"App {BUNDLE_ID} → {app_id}")

    version_string = MARKETING_VERSION or meta.get("default_version") or "1.0.25"
    build = wait_for_build(token, app_id)
    build_id = build["id"]
    build_ver = (build.get("attributes") or {}).get("version")
    info(f"Using build CFBundleVersion={build_ver} id={build_id}")

    version = get_or_create_version(token, app_id, version_string)
    version_id = version["id"]
    attach_build(token, version_id, build_id)
    ensure_export_compliance(token, build_id)
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

    if not SUBMIT:
        info("SUBMIT_FOR_REVIEW=false — listing prepared, not submitted.")
        return

    submit_for_review(token, app_id, version_id)
    info(
        "Done. Watch App Store Connect → App Review. "
        "If Apple asks for age rating / pricing / extra screenshot sizes, finish those once in the UI."
    )


if __name__ == "__main__":
    main()
