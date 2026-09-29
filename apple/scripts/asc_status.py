#!/usr/bin/env python3
"""Read-only App Store Connect status for Anteats. No submit / cancel / mutate.

Never cancel WAITING_FOR_REVIEW / IN_REVIEW, and never replace a live READY_FOR_SALE.

Inventory listing screenshots and app previews on live 1.0.326 and pending
1.0.337. Read-only. Do not cancel review. Do not submit. Do not upload media.
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


def _is_beige(rgb: tuple[int, int, int]) -> bool:
    r, g, b = rgb
    return r > 210 and g > 200 and b < 235 and (r - b) > 12 and (g - b) > 8


def _sample_png_or_jpeg(data: bytes) -> list[tuple[int, int, int]]:
    try:
        from PIL import Image
    except ImportError:
        return []
    from io import BytesIO

    im = Image.open(BytesIO(data)).convert("RGB")
    points = ((0.03, 0.20), (0.97, 0.20), (0.03, 0.38), (0.97, 0.38), (0.50, 0.12))
    samples: list[tuple[int, int, int]] = []
    for fx, fy in points:
        x = min(im.width - 1, max(0, int(im.width * fx)))
        y = min(im.height - 1, max(0, int(im.height * fy)))
        px = im.getpixel((x, y))
        samples.append((int(px[0]), int(px[1]), int(px[2])))
    return samples


def _asset_url(image_asset: dict | None, width: int = 240, height: int = 520) -> str | None:
    if not image_asset:
        return None
    template = image_asset.get("templateUrl")
    if not isinstance(template, str) or not template:
        return None
    return (
        template.replace("{w}", str(width))
        .replace("{h}", str(height))
        .replace("{f}", "png")
    )


def _fetch_bytes(url: str) -> bytes | None:
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "AnteatsASC/1.0"})
        with urllib.request.urlopen(req, timeout=30) as resp:
            return resp.read()
    except Exception:  # noqa: BLE001 — inventory only
        return None


def _canvas_note(data: bytes | None) -> str:
    if not data:
        return "canvas=unsampled"
    samples = _sample_png_or_jpeg(data)
    if not samples:
        return "canvas=unsampled"
    beige = sum(1 for rgb in samples if _is_beige(rgb))
    near_white = sum(1 for r, g, b in samples if min(r, g, b) >= 245)
    near_black = sum(1 for r, g, b in samples if max(r, g, b) <= 40)
    if beige >= 2:
        label = "BEIGE"
    elif near_white >= 2:
        label = "white"
    elif near_black >= 2:
        label = "black"
    else:
        label = "other"
    return f"canvas={label} samples={samples[:3]}"


def dump_listing_media(token: str, version: dict) -> None:
    attrs = version.get("attributes") or {}
    ver = attrs.get("versionString")
    state = attrs.get("appStoreState")
    print(f"version={ver} appStoreState={state}", flush=True)
    if state in {"WAITING_FOR_REVIEW", "IN_REVIEW", "PROCESSING_FOR_REVIEW"}:
        print(
            "  mediaEditable=no "
            "(Apple: cannot upload or edit screenshots or app previews "
            "while Waiting for Review / In Review; deleting a preview is "
            "allowed but we will not. Replacing media requires removing "
            "the version from review, which we will not do.)",
            flush=True,
        )
    elif state in {
        "PREPARE_FOR_SUBMISSION",
        "DEVELOPER_REJECTED",
        "REJECTED",
        "METADATA_REJECTED",
        "INVALID_BINARY",
    }:
        print("  mediaEditable=yes (draft / rejected states only)", flush=True)
    else:
        print(
            "  mediaEditable=no (live / locked version; new version required)",
            flush=True,
        )

    locs = api(
        "GET",
        f"/v1/appStoreVersions/{version['id']}/appStoreVersionLocalizations?limit=5",
        token,
        ok_empty=True,
    ).get("data") or []
    if not locs:
        print("  (no localizations)", flush=True)
        return
    for loc in locs:
        locale = (loc.get("attributes") or {}).get("locale")
        print(f"  locale={locale} localization={loc['id']}", flush=True)
        sets = api(
            "GET",
            f"/v1/appStoreVersionLocalizations/{loc['id']}/appScreenshotSets?limit=20",
            token,
            ok_empty=True,
        ).get("data") or []
        if not sets:
            print("  screenshots=(none)", flush=True)
        for shot_set in sets:
            display = (shot_set.get("attributes") or {}).get("screenshotDisplayType")
            print(f"  screenshotSet type={display} id={shot_set['id']}", flush=True)
            shots = api(
                "GET",
                f"/v1/appScreenshotSets/{shot_set['id']}/appScreenshots?limit=20",
                token,
                ok_empty=True,
            ).get("data") or []
            if not shots:
                print("    (empty set)", flush=True)
            for index, shot in enumerate(shots):
                sattrs = shot.get("attributes") or {}
                delivery = (sattrs.get("assetDeliveryState") or {}).get("state")
                name = sattrs.get("fileName")
                size = sattrs.get("fileSize")
                url = _asset_url(sattrs.get("imageAsset"))
                note = _canvas_note(_fetch_bytes(url) if url else None)
                print(
                    f"    shot[{index}] file={name} bytes={size} "
                    f"delivery={delivery} {note}",
                    flush=True,
                )

        preview_sets = api(
            "GET",
            f"/v1/appStoreVersionLocalizations/{loc['id']}/appPreviewSets?limit=20",
            token,
            ok_empty=True,
        ).get("data") or []
        if not preview_sets:
            print("  previews=(none)", flush=True)
            continue
        for preview_set in preview_sets:
            display = (preview_set.get("attributes") or {}).get("previewType")
            print(f"  previewSet type={display} id={preview_set['id']}", flush=True)
            previews = api(
                "GET",
                f"/v1/appPreviewSets/{preview_set['id']}/appPreviews?limit=10",
                token,
                ok_empty=True,
            ).get("data") or []
            if not previews:
                print("    (empty set)", flush=True)
            for index, preview in enumerate(previews):
                pattrs = preview.get("attributes") or {}
                delivery = (pattrs.get("assetDeliveryState") or {}).get("state")
                video_state = (pattrs.get("videoDeliveryState") or {}).get("state")
                poster = _asset_url(pattrs.get("previewFrameImage") or pattrs.get("imageAsset"))
                if not poster:
                    preview_image = pattrs.get("previewImage") or {}
                    poster = _asset_url(preview_image if isinstance(preview_image, dict) else None)
                note = _canvas_note(_fetch_bytes(poster) if poster else None)
                print(
                    f"    preview[{index}] file={pattrs.get('fileName')} "
                    f"bytes={pattrs.get('fileSize')} mime={pattrs.get('mimeType')} "
                    f"delivery={delivery} video={video_state} "
                    f"posterTime={pattrs.get('previewFrameTimeCode')} {note}",
                    flush=True,
                )
                if pattrs.get("videoUrl"):
                    print(f"      videoUrl={pattrs.get('videoUrl')}", flush=True)


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

    print("--- listingCopy ---", flush=True)
    for v in (versions.get("data") or [])[:3]:
        attrs = v.get("attributes") or {}
        locs = api(
            "GET",
            f"/v1/appStoreVersions/{v['id']}/appStoreVersionLocalizations?limit=5",
            token,
            ok_empty=True,
        ).get("data") or []
        for loc in locs:
            lattrs = loc.get("attributes") or {}
            if lattrs.get("locale") not in {None, "en-US"}:
                continue
            wn = (lattrs.get("whatsNew") or "").replace("\n", " ")
            print(
                f"version={attrs.get('versionString')} "
                f"appStoreState={attrs.get('appStoreState')} "
                f"whatsNew={wn[:400]!r}",
                flush=True,
            )
            if "\u2014" in wn:
                print("  note=What's New still contains an em dash", flush=True)

    print("--- listingMedia ---", flush=True)
    media_versions = []
    for v in versions.get("data") or []:
        state = (v.get("attributes") or {}).get("appStoreState")
        ver = (v.get("attributes") or {}).get("versionString")
        if state in {
            "READY_FOR_SALE",
            "WAITING_FOR_REVIEW",
            "IN_REVIEW",
            "PROCESSING_FOR_REVIEW",
            "PENDING_DEVELOPER_RELEASE",
            "PENDING_APPLE_RELEASE",
        } or ver in {"1.0.326", "1.0.337"}:
            media_versions.append(v)
    if not media_versions:
        print("(none)", flush=True)
    for v in media_versions:
        dump_listing_media(token, v)

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

    print("--- testFlight ---", flush=True)
    latest_q = urllib.parse.urlencode(
        {
            "filter[app]": app_id,
            "sort": "-uploadedDate",
            "limit": "12",
            "include": "preReleaseVersion",
            "fields[builds]": "version,processingState,uploadedDate,expired",
            "fields[preReleaseVersions]": "version",
        }
    )
    latest = api("GET", f"/v1/builds?{latest_q}", token)
    trains = {
        row["id"]: row
        for row in (latest.get("included") or [])
        if row.get("type") == "preReleaseVersions"
    }
    latest_builds = latest.get("data") or []
    train_by_build = {}
    for build in latest_builds:
        rel = ((build.get("relationships") or {}).get("preReleaseVersion") or {}).get("data") or {}
        train_by_build[build.get("id")] = (
            ((trains.get(rel.get("id") or "") or {}).get("attributes") or {}).get("version")
        )

    gq = urllib.parse.urlencode({"filter[app]": app_id, "limit": "50"})
    groups = api("GET", f"/v1/betaGroups?{gq}", token).get("data") or []
    if not groups:
        print("(no beta groups)", flush=True)
    for group in groups:
        gattrs = group.get("attributes") or {}
        kind = "internal" if gattrs.get("isInternalGroup") else "external"
        print(
            f"group={gattrs.get('name')!r} kind={kind} id={group.get('id')}",
            flush=True,
        )
        payload = api(
            "GET",
            f"/v1/betaGroups/{group['id']}/builds?limit=5",
            token,
            ok_empty=True,
        )
        builds = payload.get("data") or []
        if not builds:
            print("  (no builds)", flush=True)
            continue
        for build in builds:
            battrs = build.get("attributes") or {}
            bid = build.get("id")
            train = train_by_build.get(bid)
            if not train and bid:
                linked = api(
                    "GET",
                    f"/v1/builds/{bid}/preReleaseVersion",
                    token,
                    ok_empty=True,
                )
                train = ((linked.get("data") or {}).get("attributes") or {}).get("version")
            print(
                f"  version={train or '—'} "
                f"build={battrs.get('version')} "
                f"processing={battrs.get('processingState')} "
                f"expired={battrs.get('expired')}",
                flush=True,
            )

    print("--- latestBuilds ---", flush=True)
    for build in latest_builds[:8]:
        battrs = build.get("attributes") or {}
        print(
            f"version={train_by_build.get(build.get('id')) or '—'} "
            f"build={battrs.get('version')} "
            f"processing={battrs.get('processingState')} "
            f"expired={battrs.get('expired')}",
            flush=True,
        )

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
