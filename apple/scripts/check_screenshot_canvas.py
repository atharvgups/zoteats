#!/usr/bin/env python3
"""Fail if listing screenshots still use beige / gradient chrome instead of
plain white light / plain black dark canvas."""

from __future__ import annotations

import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    sys.stderr.write("Pillow is required: pip install Pillow\n")
    sys.exit(1)


def sample(im: Image.Image, fx: float, fy: float) -> tuple[int, int, int]:
    x = min(im.width - 1, max(0, int(im.width * fx)))
    y = min(im.height - 1, max(0, int(im.height * fy)))
    px = im.getpixel((x, y))
    return int(px[0]), int(px[1]), int(px[2])


def is_beige(rgb: tuple[int, int, int]) -> bool:
    r, g, b = rgb
    return r > 210 and g > 200 and b < 235 and (r - b) > 12 and (g - b) > 8


def is_near_white(rgb: tuple[int, int, int]) -> bool:
    return min(rgb) >= 245


def is_near_black(rgb: tuple[int, int, int]) -> bool:
    return max(rgb) <= 40


# Side gutters on full-tab screens (avoid titles / Dynamic Island).
TAB_POINTS = ((0.03, 0.20), (0.97, 0.20), (0.03, 0.38), (0.97, 0.38))
# Center of a presented sheet — still must not be beige.
SHEET_POINTS = ((0.50, 0.42), (0.50, 0.55), (0.20, 0.42))

TAB_LIGHT = {"eat_light.png", "campus.png", "study.png"}
SHEET_LIGHT = {
    "settings.png",
    "campus_menu.png",
    "plate_light.png",
    "dish_nutrition_light.png",
}
DARK_FILES = {"eat_dark.png"}
LIGHT_FILES = TAB_LIGHT | SHEET_LIGHT


def check_file(path: Path, want_dark: bool, sheet: bool) -> list[str]:
    im = Image.open(path).convert("RGB")
    errors: list[str] = []
    points = SHEET_POINTS if sheet else TAB_POINTS
    samples = [sample(im, fx, fy) for fx, fy in points]
    beige_hits = sum(1 for rgb in samples if is_beige(rgb))
    if beige_hits >= 2:
        errors.append(f"{path.name}: canvas still looks beige ({samples[:3]})")
        return errors
    if sheet:
        return errors
    if want_dark:
        dark_hits = sum(1 for rgb in samples if is_near_black(rgb))
        if dark_hits < 2:
            errors.append(f"{path.name}: expected plain black dark canvas ({samples[:3]})")
    else:
        white_hits = sum(1 for rgb in samples if is_near_white(rgb))
        if white_hits < 2:
            errors.append(f"{path.name}: expected plain white light canvas ({samples[:3]})")
    return errors


def check_preview_frames(root: Path) -> list[str]:
    frames = sorted(root.glob("*.png"))
    if not frames:
        return [f"no preview frames in {root}"]
    errors: list[str] = []
    beige_frames = 0
    for path in frames:
        im = Image.open(path).convert("RGB")
        samples = [sample(im, fx, fy) for fx, fy in TAB_POINTS]
        if sum(1 for rgb in samples if is_beige(rgb)) >= 2:
            beige_frames += 1
            errors.append(f"{path.name}: preview frame still looks beige ({samples[:3]})")
        print(f"preview {path.name}: {im.size[0]}x{im.size[1]} samples={samples[:2]}", flush=True)
    if beige_frames:
        errors.append(f"{beige_frames} preview frame(s) still beige")
    return errors


def main() -> None:
    args = [a for a in sys.argv[1:] if a]
    root = Path(args[0] if args else "screenshots/listing")
    preview_root = Path(args[1]) if len(args) > 1 else None
    if not root.is_dir():
        print(f"::error::Screenshot listing dir missing: {root}", flush=True)
        sys.exit(1)
    errors: list[str] = []
    for name in sorted(LIGHT_FILES | DARK_FILES):
        path = root / name
        if not path.is_file():
            errors.append(f"missing {name}")
            continue
        errors.extend(
            check_file(
                path,
                want_dark=name in DARK_FILES,
                sheet=name in SHEET_LIGHT,
            )
        )
        im = Image.open(path)
        print(f"{name}: {im.size[0]}x{im.size[1]} {path.stat().st_size} bytes", flush=True)
    eat = root / "eat_light.png"
    for dup in ("plate_light.png", "dish_nutrition_light.png"):
        other = root / dup
        if eat.is_file() and other.is_file() and eat.read_bytes() == other.read_bytes():
            errors.append(f"{dup} is identical to eat_light.png (sheet did not open)")
    study = root / "study.png"
    if study.is_file() and study.stat().st_size < 200_000:
        errors.append("study.png looks like a skeleton / empty load")
    if preview_root is not None:
        if preview_root.is_dir():
            errors.extend(check_preview_frames(preview_root))
        else:
            errors.append(f"preview frames dir missing: {preview_root}")
    if errors:
        for err in errors:
            print(f"::error::{err}", flush=True)
        sys.exit(1)
    print("Canvas check passed (plain white light / plain black dark).", flush=True)


if __name__ == "__main__":
    main()
