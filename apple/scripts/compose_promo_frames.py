#!/usr/bin/env python3
"""Compose Anteats Comp C App Store promo frames from real UI screenshots.

Outputs 1290x2796 APP_IPHONE_67 PNGs:
  docs/screenshots/promo/eat.png      bottom-bleed, UCI blue
  docs/screenshots/promo/study.png    dual phones, indigo
  docs/screenshots/promo/campus.png   top-bleed, UCI gold
  docs/screenshots/promo/widgets.png       Home Screen widgets, Comp C
  docs/screenshots/promo/widgets_lock.png  Lock Screen widgets, top-bleed

Never invents app chrome. Phone screens are current docs/screenshots captures.
Widgets are painted from the shipping DiningStatusWidget layout using the
same hall / library facts visible in those captures. No Gym. No em dashes.
"""

from __future__ import annotations

import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H = 1290, 2796

UCI_BLUE = (0, 100, 164)
UCI_BLUE_DEEP = (0, 74, 124)
UCI_BLUE_DARK = (0, 42, 78)
UCI_GOLD = (255, 210, 0)
NAVY = (3, 33, 71)
INDIGO = (36, 16, 92)
INDIGO_DEEP = (16, 6, 48)
INDIGO_RICH = (62, 28, 130)
WHITE = (255, 255, 255)
OPEN_GREEN = (52, 178, 51)

ROOT = Path(__file__).resolve().parents[2]
SHOTS = ROOT / "docs" / "screenshots"
OUT = SHOTS / "promo"
ICON = ROOT / "apple" / "App" / "Assets.xcassets" / "AppIcon.appiconset" / "AppIcon.png"

FONT_CANDIDATES = [
    Path("/tmp/fonts/InterDisplay-Black.ttf"),
    Path("/tmp/fonts/Inter-Black.ttf"),
    Path("/usr/share/fonts/truetype/macos/Inter-Bold.ttf"),
]
CAPTION_CANDIDATES = [
    Path("/tmp/fonts/InterDisplay-Bold.ttf"),
    Path("/usr/share/fonts/truetype/macos/Inter-SemiBold.ttf"),
    Path("/usr/share/fonts/truetype/macos/Inter-Bold.ttf"),
]
BODY_CANDIDATES = [
    Path("/usr/share/fonts/truetype/macos/Inter-Medium.ttf"),
    Path("/usr/share/fonts/truetype/macos/Inter-Regular.ttf"),
]


def first_font(paths: list[Path], size: float) -> ImageFont.FreeTypeFont:
    for path in paths:
        if path.is_file():
            return ImageFont.truetype(str(path), size=size)
    raise FileNotFoundError("No usable Inter font on this machine")


def font_display(size: float) -> ImageFont.FreeTypeFont:
    return first_font(FONT_CANDIDATES, size)


def font_caption(size: float) -> ImageFont.FreeTypeFont:
    return first_font(CAPTION_CANDIDATES, size)


def font_body(size: float) -> ImageFont.FreeTypeFont:
    return first_font(BODY_CANDIDATES, size)


def hex_rgb(color: tuple[int, int, int], a: int = 255) -> tuple[int, int, int, int]:
    return (*color, a)


def vertical_gradient(
    size: tuple[int, int],
    top: tuple[int, int, int],
    bottom: tuple[int, int, int],
) -> Image.Image:
    w, h = size
    img = Image.new("RGBA", size)
    px = img.load()
    for y in range(h):
        t = y / max(h - 1, 1)
        # slight ease so the mid color sits longer
        t = t * t * (3 - 2 * t)
        rgb = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        for x in range(w):
            px[x, y] = (*rgb, 255)
    return img


def add_orb(
    img: Image.Image,
    cx: int,
    cy: int,
    radius: int,
    color: tuple[int, int, int],
    alpha: int = 90,
) -> None:
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    draw.ellipse((cx - radius, cy - radius, cx + radius, cy + radius), fill=(*color, alpha))
    layer = layer.filter(ImageFilter.GaussianBlur(radius=int(radius * 0.55)))
    img.alpha_composite(layer)


def add_vignette(img: Image.Image, strength: float = 0.38) -> None:
    w, h = img.size
    ys, xs = np.ogrid[:h, :w]
    nx = (xs - w / 2) / (w / 2)
    ny = (ys - h / 2) / (h / 2)
    r = np.sqrt(nx * nx + ny * ny)
    shade = np.clip((r - 0.35) / 1.15, 0, 1) * strength
    shade = (shade * 255).astype(np.uint8)
    overlay = np.zeros((h, w, 4), dtype=np.uint8)
    overlay[..., 3] = shade
    img.alpha_composite(Image.fromarray(overlay, "RGBA"))


def add_grain(img: Image.Image, amount: int = 16) -> None:
    arr = np.array(img)
    noise = np.random.default_rng(19).integers(-amount, amount + 1, size=arr.shape[:2], dtype=np.int16)
    rgb = arr[..., :3].astype(np.int16) + noise[..., None]
    arr[..., :3] = np.clip(rgb, 0, 255).astype(np.uint8)
    img.paste(Image.fromarray(arr, "RGBA"))


def rounded_mask(size: tuple[int, int], radius: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius=radius, fill=255)
    return mask


def tracked_width(text: str, font: ImageFont.FreeTypeFont, tracking: float) -> float:
    if not text:
        return 0
    widths = [font.getlength(ch) for ch in text]
    return sum(widths) + tracking * font.size * (len(text) - 1)


def draw_tracked(
    draw: ImageDraw.ImageDraw,
    xy: tuple[float, float],
    text: str,
    font: ImageFont.FreeTypeFont,
    fill,
    tracking: float = -0.055,
) -> None:
    x, y = xy
    for ch in text:
        draw.text((x, y), ch, font=font, fill=fill)
        x += font.getlength(ch) + tracking * font.size


def draw_title(
    canvas: Image.Image,
    text: str,
    color: tuple[int, int, int],
    *,
    y: int,
    size: int,
    tracking: float = -0.07,
    shadow: bool = True,
    align: str = "center",
    x: int | None = None,
) -> int:
    """Draw a huge lowercase title. Returns the baseline box height."""
    font = font_display(size)
    width = tracked_width(text, font, tracking)
    if x is None:
        if align == "center":
            x = (W - width) / 2
        elif align == "left":
            x = 72
        else:
            x = W - 72 - width
    draw = ImageDraw.Draw(canvas)
    if shadow:
        for ox, oy, a in ((0, 10, 50), (0, 4, 70)):
            draw_tracked(draw, (x + ox, y + oy), text, font, (* (0, 0, 0), a), tracking)
    draw_tracked(draw, (x, y), text, font, color, tracking)
    bbox = font.getbbox("Hg")
    return int(bbox[3] - bbox[1])


def draw_subtitle(canvas: Image.Image, text: str, color, y: int, size: int = 36) -> None:
    font = font_caption(size)
    draw = ImageDraw.Draw(canvas)
    tracking = 0.04
    width = tracked_width(text, font, tracking)
    draw_tracked(draw, ((W - width) / 2, y), text, font, color, tracking)


def load_shot(name: str) -> Image.Image:
    path = SHOTS / name
    im = Image.open(path).convert("RGBA")
    if im.size != (W, H):
        im = im.resize((W, H), Image.Resampling.LANCZOS)
    return im


def crop_screen(shot: Image.Image, offset_y: int = 0) -> Image.Image:
    """Re-window a capture so a different slice of the real UI fills the phone."""
    if offset_y == 0:
        return shot
    canvas = Image.new("RGBA", shot.size, shot.getpixel((2, shot.size[1] - 2)))
    canvas.paste(shot, (0, -offset_y))
    return canvas


def zoom_region(shot: Image.Image, top: float, bottom: float) -> Image.Image:
    """Scale a vertical slice of a real capture to fill the phone screen."""
    w, h = shot.size
    y0 = max(0, int(h * top))
    y1 = min(h, int(h * bottom))
    region = shot.crop((0, y0, w, y1))
    return region.resize((w, h), Image.Resampling.LANCZOS)


def make_iphone(screen: Image.Image, screen_w: int) -> Image.Image:
    """Realistic iPhone chassis around a real screenshot. Dynamic Island stays in the capture."""
    scale = screen_w / screen.size[0]
    screen_h = int(screen.size[1] * scale)
    screen = screen.resize((screen_w, screen_h), Image.Resampling.LANCZOS)

    bezel = max(13, int(screen_w * 0.026))
    # Side buttons stick out of the chassis.
    button = max(7, int(screen_w * 0.014))
    outer_w = screen_w + bezel * 2
    outer_h = screen_h + bezel * 2
    pad = button + 8
    device = Image.new("RGBA", (outer_w + pad * 2, outer_h + 8), (0, 0, 0, 0))
    ox, oy = pad, 4
    draw = ImageDraw.Draw(device)

    outer_r = int(screen_w * 0.148)
    inner_r = int(screen_w * 0.122)

    # Side buttons (volume left, power right)
    vol_x0 = ox - button + 2
    draw.rounded_rectangle((vol_x0, oy + int(outer_h * 0.18), ox + 3, oy + int(outer_h * 0.18) + int(outer_h * 0.07)), 4, fill=(28, 28, 30, 255))
    draw.rounded_rectangle((vol_x0, oy + int(outer_h * 0.27), ox + 3, oy + int(outer_h * 0.27) + int(outer_h * 0.07)), 4, fill=(28, 28, 30, 255))
    pwr_x1 = ox + outer_w + button - 2
    draw.rounded_rectangle((ox + outer_w - 3, oy + int(outer_h * 0.22), pwr_x1, oy + int(outer_h * 0.22) + int(outer_h * 0.11)), 4, fill=(28, 28, 30, 255))

    # Chassis
    chassis = (18, 18, 20, 255)
    draw.rounded_rectangle((ox, oy, ox + outer_w - 1, oy + outer_h - 1), radius=outer_r, fill=chassis)
    # Soft metal rim highlight
    highlight = Image.new("RGBA", device.size, (0, 0, 0, 0))
    hd = ImageDraw.Draw(highlight)
    hd.rounded_rectangle((ox + 1, oy + 1, ox + outer_w - 2, oy + outer_h - 2), radius=outer_r - 1, outline=(255, 255, 255, 38), width=2)
    hd.rounded_rectangle((ox + 2, oy + 2, ox + outer_w - 8, oy + int(outer_h * 0.18)), radius=outer_r - 2, outline=(255, 255, 255, 22), width=1)
    device.alpha_composite(highlight)

    # Screen
    sx, sy = ox + bezel, oy + bezel
    screen_mask = rounded_mask((screen_w, screen_h), inner_r)
    device.paste(screen, (sx, sy), screen_mask)
    return device


def device_shadow(device: Image.Image, radius: int = 48, offset: tuple[int, int] = (0, 28)) -> Image.Image:
    alpha = device.split()[-1]
    shadow = Image.new("RGBA", device.size, (0, 0, 0, 0))
    shadow.putalpha(alpha.point(lambda a: int(a * 0.55)))
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=radius))
    padded = Image.new("RGBA", (device.size[0] + abs(offset[0]) + radius * 2, device.size[1] + abs(offset[1]) + radius * 2), (0, 0, 0, 0))
    padded.alpha_composite(shadow, (radius + max(offset[0], 0), radius + max(offset[1], 0)))
    return padded


def paste_device(
    canvas: Image.Image,
    device: Image.Image,
    *,
    x: int,
    y: int,
    angle: float = 0,
    shadow_radius: int = 52,
) -> None:
    work = device
    if angle:
        work = device.rotate(angle, resample=Image.Resampling.BICUBIC, expand=True)
    shadow = device_shadow(work, radius=shadow_radius)
    # Align shadow under the device
    sx = x - (shadow.size[0] - work.size[0]) // 2
    sy = y - (shadow.size[1] - work.size[1]) // 2 + 10
    canvas.alpha_composite(shadow, (sx, sy))
    canvas.alpha_composite(work, (x, y))


def assert_no_emdash(*texts: str) -> None:
    for text in texts:
        if "\u2014" in text or "\u2013" in text:
            raise SystemExit(f"Promo copy contains a dash that is not allowed: {text!r}")


# --- Widgets painted from apple/Widgets/ZotEatsWidgets.swift ---

def _widget_chrome(size: tuple[int, int], family: str) -> Image.Image:
    """Dining Halls widget: UCI blue canvas, gold ZOTEATS kicker, hall rows from Eat + Study captures."""
    w, h = size
    img = Image.new("RGBA", size, (*UCI_BLUE, 255))
    add_orb(img, int(w * 0.85), 8, int(w * 0.4), (0, 140, 200), 50)
    radius = 36 if family == "small" else 32
    mask = rounded_mask(size, radius)
    draw = ImageDraw.Draw(img)
    kicker = font_caption(max(13, int(h * 0.068)))
    body = font_caption(max(16, int(h * 0.082)))
    status = font_body(max(13, int(h * 0.058)))
    pad = max(16, int(w * 0.045))
    y = max(12, int(h * 0.055))
    draw.text((pad, y), "ZOTEATS", font=kicker, fill=UCI_GOLD)
    y += int(h * 0.155)

    halls = [
        ("Anteatery", "Dinner", True),
        ("Brandywine", "Dinner", True),
    ]
    if family == "medium":
        halls.append(("Oasis", "Coming soon", False))

    row_h = int((h - y - (48 if family == "medium" else 16)) / max(len(halls), 1))
    for name, line, is_open in halls:
        dot = OPEN_GREEN if is_open else (220, 220, 220)
        cy = y + 8
        draw.ellipse((pad, cy, pad + 10, cy + 10), fill=dot)
        draw.text((pad + 20, y), name, font=body, fill=WHITE)
        draw.text((pad + 20, y + int(h * 0.095)), line, font=status, fill=(255, 255, 255, 200))
        y += row_h

    if family == "medium":
        y = h - 42
        draw.line((pad, y - 8, w - pad, y - 8), fill=(255, 255, 255, 55), width=1)
        quiet = font_body(18)
        draw.text((pad, y), "Quietest: Langson", font=quiet, fill=(255, 255, 255, 235))
        pct = "9%"
        gold = font_caption(18)
        draw.text((w - pad - gold.getlength(pct), y), pct, font=gold, fill=UCI_GOLD)

    out = Image.new("RGBA", size, (0, 0, 0, 0))
    out.paste(img, (0, 0), mask)
    return out


def make_home_screen(width: int) -> Image.Image:
    """iOS Home Screen mock: Comp C wallpaper + shipping Small/Medium dining widgets + real icon."""
    height = int(width * H / W)
    wall = vertical_gradient((width, height), (8, 18, 48), (0, 70, 120))
    add_orb(wall, int(width * 0.25), int(height * 0.22), int(width * 0.55), UCI_GOLD, 38)
    add_orb(wall, int(width * 0.85), int(height * 0.55), int(width * 0.5), INDIGO_RICH, 70)
    add_vignette(wall, 0.28)

    # Status / island already-look: draw a compact island + 9:41 to match captures
    d = ImageDraw.Draw(wall)
    island_w, island_h = int(width * 0.28), int(width * 0.075)
    ix = (width - island_w) // 2
    iy = int(width * 0.045)
    d.rounded_rectangle((ix, iy, ix + island_w, iy + island_h), island_h // 2, fill=(0, 0, 0, 230))
    time_font = font_caption(int(width * 0.045))
    d.text((int(width * 0.07), int(width * 0.055)), "9:41", font=time_font, fill=WHITE)

    scale = width / 390
    med_w, med_h = int(362 * scale), int(170 * scale)
    sm_w, sm_h = int(174 * scale), int(170 * scale)
    gap = int(14 * scale)
    x0 = (width - med_w) // 2
    y0 = int(height * 0.13)

    medium = _widget_chrome((med_w, med_h), "medium")
    small = _widget_chrome((sm_w, sm_h), "small")
    wall.alpha_composite(medium, (x0, y0))
    wall.alpha_composite(small, (x0, y0 + med_h + gap))

    if ICON.is_file():
        icon_s = sm_h
        icon = Image.open(ICON).convert("RGBA").resize((icon_s, icon_s), Image.Resampling.LANCZOS)
        icon.putalpha(rounded_mask((icon_s, icon_s), int(icon_s * 0.223)))
        wall.alpha_composite(icon, (x0 + sm_w + gap, y0 + med_h + gap))
        label = font_body(max(15, int(width * 0.034)))
        name = "Anteats"
        lw = label.getlength(name)
        d.text((x0 + sm_w + gap + (icon_s - lw) / 2, y0 + med_h + gap + icon_s + 10), name, font=label, fill=WHITE)

    dy = y0 + med_h + gap + sm_h + int(70 * scale)
    d.ellipse((width // 2 - 5, dy, width // 2 + 5, dy + 10), fill=WHITE)
    d.ellipse((width // 2 + 16, dy + 2, width // 2 + 22, dy + 8), fill=(255, 255, 255, 120))
    return wall


def compose_eat() -> Image.Image:
    canvas = vertical_gradient((W, H), (0, 118, 186), UCI_BLUE_DARK)
    add_orb(canvas, 1080, 240, 520, UCI_GOLD, 28)
    add_orb(canvas, 180, 2100, 480, UCI_BLUE_DEEP, 90)
    add_vignette(canvas, 0.32)
    add_grain(canvas, 10)

    assert_no_emdash("eat", "for Anteaters")
    draw_title(canvas, "eat", UCI_GOLD, y=150, size=310, tracking=-0.085)
    draw_subtitle(canvas, "for Anteaters", (255, 255, 255, 235), y=492, size=46)

    screen = load_shot("eat_light.png")
    phone = make_iphone(screen, 1000)
    x = (W - phone.size[0]) // 2
    y = 880
    paste_device(canvas, phone, x=x, y=y, shadow_radius=60)
    return canvas


def compose_study() -> Image.Image:
    canvas = vertical_gradient((W, H), INDIGO_RICH, INDIGO_DEEP)
    add_orb(canvas, 200, 320, 460, (120, 70, 210), 55)
    add_orb(canvas, 1100, 1700, 520, UCI_GOLD, 18)
    add_vignette(canvas, 0.36)
    add_grain(canvas, 11)

    assert_no_emdash("study")
    draw_title(canvas, "study", UCI_GOLD, y=150, size=228, tracking=-0.065)

    shot = load_shot("study.png")
    list_phone = make_iphone(zoom_region(shot, 0.0, 0.46), 660)
    floor_phone = make_iphone(zoom_region(shot, 0.34, 0.92), 720)

    paste_device(canvas, list_phone, x=-30, y=720, angle=-8, shadow_radius=44)
    paste_device(canvas, floor_phone, x=400, y=1040, angle=7, shadow_radius=50)
    return canvas


def compose_campus() -> Image.Image:
    canvas = vertical_gradient((W, H), (255, 220, 40), (232, 168, 0))
    add_orb(canvas, 200, 2400, 540, (255, 245, 170), 70)
    add_orb(canvas, 1100, 400, 420, (255, 180, 0), 50)
    add_vignette(canvas, 0.18)
    add_grain(canvas, 9)

    assert_no_emdash("campus")
    screen = load_shot("campus.png")
    phone = make_iphone(screen, 1000)
    # Top bleed: device hangs from above, place cards sit toward the middle
    x = (W - phone.size[0]) // 2
    y = -620
    paste_device(canvas, phone, x=x, y=y, shadow_radius=58)

    # Title lives in the gold field under the phone
    draw_title(canvas, "campus", NAVY, y=1840, size=236, tracking=-0.055, shadow=False)
    return canvas


def compose_widgets() -> Image.Image:
    canvas = vertical_gradient((W, H), (10, 16, 40), (0, 56, 104))
    add_orb(canvas, 980, 280, 500, UCI_GOLD, 26)
    add_orb(canvas, 240, 1900, 520, INDIGO_RICH, 80)
    add_vignette(canvas, 0.34)
    add_grain(canvas, 10)

    assert_no_emdash("live", "Home Screen widgets")
    draw_title(canvas, "live", UCI_GOLD, y=160, size=268, tracking=-0.075)
    draw_subtitle(canvas, "Home Screen widgets", (255, 255, 255, 220), y=470, size=36)

    home = make_home_screen(900)
    phone = make_iphone(home, 900)
    paste_device(canvas, phone, x=40, y=560, angle=-5, shadow_radius=56)
    return canvas


def make_lock_screen(width: int) -> Image.Image:
    """Lock Screen mock: Comp C wallpaper, 9:41, Small + Medium dining widgets."""
    height = int(width * H / W)
    wall = vertical_gradient((width, height), (6, 12, 36), (0, 78, 128))
    add_orb(wall, int(width * 0.7), int(height * 0.2), int(width * 0.6), UCI_GOLD, 30)
    add_vignette(wall, 0.3)
    d = ImageDraw.Draw(wall)
    island_w, island_h = int(width * 0.28), int(width * 0.075)
    ix = (width - island_w) // 2
    iy = int(width * 0.04)
    d.rounded_rectangle((ix, iy, ix + island_w, iy + island_h), island_h // 2, fill=(0, 0, 0, 230))

    time_font = font_display(int(width * 0.22))
    time = "9:41"
    tw = time_font.getlength(time)
    d.text(((width - tw) / 2, int(height * 0.10)), time, font=time_font, fill=WHITE)
    date_font = font_caption(int(width * 0.042))
    date = "Saturday, September 19"
    dw = date_font.getlength(date)
    d.text(((width - dw) / 2, int(height * 0.22)), date, font=date_font, fill=(255, 255, 255, 220))

    scale = width / 390
    med_w, med_h = int(362 * scale), int(168 * scale)
    sm_w, sm_h = int(174 * scale), int(168 * scale)
    gap = int(14 * scale)
    x0 = (width - med_w) // 2
    y0 = int(height * 0.30)
    wall.alpha_composite(_widget_chrome((med_w, med_h), "medium"), (x0, y0))
    wall.alpha_composite(_widget_chrome((sm_w, sm_h), "small"), (x0, y0 + med_h + gap))
    return wall


def compose_widgets_lock() -> Image.Image:
    canvas = vertical_gradient((W, H), INDIGO, INDIGO_DEEP)
    add_orb(canvas, 200, 2400, 500, UCI_GOLD, 22)
    add_vignette(canvas, 0.3)
    add_grain(canvas, 10)
    assert_no_emdash("glance")

    lock = make_lock_screen(980)
    phone = make_iphone(lock, 980)
    x = (W - phone.size[0]) // 2
    # Island clips off the top; 9:41 and both widgets stay on-card
    paste_device(canvas, phone, x=x, y=-160, shadow_radius=58)
    draw_title(canvas, "glance", UCI_GOLD, y=2140, size=188, tracking=-0.06)
    return canvas


def save(img: Image.Image, name: str) -> Path:
    OUT.mkdir(parents=True, exist_ok=True)
    # Flatten onto opaque pixels (ASC wants RGB PNG)
    rgb = Image.new("RGB", img.size, (0, 0, 0))
    rgb.paste(img, mask=img.split()[-1])
    path = OUT / name
    rgb.save(path, "PNG", optimize=True)
    print(f"wrote {path.relative_to(ROOT)} {rgb.size}")
    return path


def main() -> None:
    save(compose_eat(), "eat.png")
    save(compose_study(), "study.png")
    save(compose_campus(), "campus.png")
    save(compose_widgets(), "widgets.png")
    save(compose_widgets_lock(), "widgets_lock.png")


if __name__ == "__main__":
    main()
