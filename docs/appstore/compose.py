#!/usr/bin/env python3
"""Compose App Store screenshots for Fonti.

Reads raw 1320×2868 simulator captures from ./raw, lays them onto a brand
canvas with a small F O N T I wordmark, a cream serif headline, and a soft
drop shadow under the screenshot. Writes finished frames to ./frames at
exact App Store dimensions for iPhone 6.9".
"""

from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter

CANVAS_W, CANVAS_H = 1320, 2868

INK = (0x0D, 0x0D, 0x0D)
INK_WARM = (0x1A, 0x14, 0x0C)
CREAM = (0xF5, 0xF0, 0xE8)
CREAM_DIM = (0x95, 0x8C, 0x7E)

NEWYORK = "/System/Library/Fonts/NewYork.ttf"
HELVETICA = "/System/Library/Fonts/HelveticaNeue.ttc"

ROOT = Path(__file__).resolve().parent
RAW_DIR = ROOT / "raw"
OUT_DIR = ROOT / "frames"

# (raw filename, headline)
HEADLINES = [
    ("01-browse-empty.png", "Find your type."),
    ("02-browse-typed.png", "Your text, in every font."),
    ("03-preview.png",      "See it at scale."),
    ("04-saved.png",        "Keep your favourites."),
    ("05-settings.png",     "Make it yours."),
]


def vertical_gradient(c_top, c_bottom):
    """Linear top→bottom gradient. Built as a 1×H strip and stretched."""
    strip = Image.new("RGB", (1, CANVAS_H))
    px = strip.load()
    for y in range(CANVAS_H):
        t = (y / (CANVAS_H - 1)) ** 0.4   # ease — top transitions, bottom flat
        r = int(c_top[0] * (1 - t) + c_bottom[0] * t)
        g = int(c_top[1] * (1 - t) + c_bottom[1] * t)
        b = int(c_top[2] * (1 - t) + c_bottom[2] * t)
        px[0, y] = (r, g, b)
    return strip.resize((CANVAS_W, CANVAS_H), Image.LANCZOS)


def rounded_mask(w, h, r):
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, w - 1, h - 1], radius=r, fill=255)
    return mask


def wrap_text(text, font, max_width, draw):
    words = text.split()
    lines, current = [], ""
    for word in words:
        trial = (current + " " + word).strip()
        bbox = draw.textbbox((0, 0), trial, font=font)
        if bbox[2] - bbox[0] <= max_width:
            current = trial
        else:
            if current:
                lines.append(current)
            current = word
    if current:
        lines.append(current)
    return lines


def draw_centered_text(draw, text, font, y, fill):
    bbox = draw.textbbox((0, 0), text, font=font)
    w = bbox[2] - bbox[0]
    x = (CANVAS_W - w) // 2 - bbox[0]
    draw.text((x, y), text, font=font, fill=fill)


def compose(raw_name, headline, out_path):
    canvas = vertical_gradient(INK_WARM, INK)
    draw = ImageDraw.Draw(canvas)

    # F O N T I wordmark — tracked caps, dim cream
    wm_font = ImageFont.truetype(HELVETICA, 36)
    draw_centered_text(draw, "F O N T I", wm_font, 90, CREAM_DIM)

    # Headline — NewYork serif, large cream
    head_font = ImageFont.truetype(NEWYORK, 116)
    lines = wrap_text(headline, head_font, CANVAS_W - 200, draw)
    head_y = 220
    line_h = 132
    for i, line in enumerate(lines):
        draw_centered_text(draw, line, head_font, head_y + i * line_h, CREAM)
    headline_end = head_y + len(lines) * line_h + 80

    # Screenshot — preserve aspect, fit to remaining height
    shot = Image.open(RAW_DIR / raw_name).convert("RGB")
    target_w = 1040
    target_h = int(target_w * shot.height / shot.width)

    available_h = CANVAS_H - headline_end - 80
    if target_h > available_h:
        scale = available_h / target_h
        target_w = int(target_w * scale)
        target_h = int(target_h * scale)
    shot = shot.resize((target_w, target_h), Image.LANCZOS)

    shot_x = (CANVAS_W - target_w) // 2
    shot_y = headline_end
    corner = 80

    # Shadow
    shadow = Image.new("RGBA", (CANVAS_W, CANVAS_H), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        [shot_x, shot_y + 28, shot_x + target_w, shot_y + target_h + 28],
        radius=corner,
        fill=(0, 0, 0, 220),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(40))
    canvas.paste(shadow, (0, 0), shadow)

    canvas.paste(shot, (shot_x, shot_y), rounded_mask(target_w, target_h, corner))

    canvas.save(out_path, "PNG", optimize=True)
    print(f"  ✓ {out_path.name}")


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for raw_name, headline in HEADLINES:
        compose(raw_name, headline, OUT_DIR / raw_name)
    print(f"\nSaved to {OUT_DIR}")


if __name__ == "__main__":
    main()
