#!/usr/bin/env python3
"""Compose App Store screenshots for Fonti.

Reads raw 1320×2868 simulator captures from ./raw, lays them onto a brand
canvas with a small F O N T I wordmark, a cream serif headline, a radial
spotlight behind the device, and a titanium device bezel around the
screenshot. Writes finished frames to ./frames at exact App Store
dimensions for iPhone 6.9".
"""

from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import numpy as np

CANVAS_W, CANVAS_H = 1284, 2778

# Brand
INK = (0x0D, 0x0D, 0x0D)
INK_DEEP = (0x14, 0x10, 0x0B)
SPOTLIGHT_WARM = (0x44, 0x36, 0x28)   # warm copper-amber glow tint
CREAM = (0xF5, 0xF0, 0xE8)
CREAM_DIM = (0x95, 0x8C, 0x7E)

# Device bezel — natural-titanium look
BEZEL_OUTER = (0x6A, 0x60, 0x55)
BEZEL_INNER = (0x2A, 0x24, 0x1F)
BEZEL_THICKNESS = 18

NEWYORK = "/System/Library/Fonts/NewYork.ttf"
HELVETICA = "/System/Library/Fonts/HelveticaNeue.ttc"

ROOT = Path(__file__).resolve().parent
RAW_DIR = ROOT / "raw"
OUT_DIR = ROOT / "frames"

HEADLINES = [
    ("01-browse-empty.png", "Find your type."),
    ("02-browse-typed.png", "Your text, in every font."),
    ("03-preview.png",      "See it at scale."),
    ("04-saved.png",        "Keep your favourites."),
    ("05-settings.png",     "Make it yours."),
]


def base_canvas():
    """Deep ink with a warm radial spotlight centered behind the device."""
    # Start with deep ink
    canvas = Image.new("RGB", (CANVAS_W, CANVAS_H), INK_DEEP)

    # Build a radial spotlight via numpy — fast and smooth
    y, x = np.indices((CANVAS_H, CANVAS_W))
    cx, cy = CANVAS_W / 2, CANVAS_H * 0.62
    dist = np.sqrt((x - cx) ** 2 + (y - cy) ** 2)
    max_r = max(CANVAS_W, CANVAS_H) * 0.55
    t = np.clip(dist / max_r, 0, 1)
    t = t ** 0.7  # ease
    intensity = (1.0 - t)[..., np.newaxis]

    base_arr = np.array(canvas, dtype=np.float32)
    warm_arr = np.array(SPOTLIGHT_WARM, dtype=np.float32)

    blended = base_arr * (1 - intensity * 0.85) + warm_arr * (intensity * 0.85)
    return Image.fromarray(blended.astype(np.uint8))


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


def draw_device_bezel(canvas, shot_x, shot_y, shot_w, shot_h, screen_corner):
    """Paint a thin titanium bezel ring + a faint inner shadow."""
    outer_corner = screen_corner + BEZEL_THICKNESS
    outer_box = [
        shot_x - BEZEL_THICKNESS,
        shot_y - BEZEL_THICKNESS,
        shot_x + shot_w + BEZEL_THICKNESS - 1,
        shot_y + shot_h + BEZEL_THICKNESS - 1,
    ]

    # Soft outer glow under the bezel — makes the device feel "lit"
    glow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(glow).rounded_rectangle(
        [outer_box[0] - 30, outer_box[1] - 20,
         outer_box[2] + 30, outer_box[3] + 50],
        radius=outer_corner + 30,
        fill=(0xE8, 0xA0, 0x40, 40),  # soft amber halo
    )
    glow = glow.filter(ImageFilter.GaussianBlur(60))
    canvas.paste(glow, (0, 0), glow)

    # The bezel itself — gradient ring (lighter top → darker bottom for depth)
    bezel = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    bd = ImageDraw.Draw(bezel)
    bd.rounded_rectangle(outer_box, radius=outer_corner, fill=(*BEZEL_OUTER, 255))
    # Inner darker rim
    inner_inset = 4
    bd.rounded_rectangle(
        [outer_box[0] + inner_inset, outer_box[1] + inner_inset,
         outer_box[2] - inner_inset, outer_box[3] - inner_inset],
        radius=outer_corner - inner_inset,
        fill=(*BEZEL_INNER, 255),
    )
    canvas.paste(bezel, (0, 0), bezel)


def compose(raw_name, headline, out_path):
    canvas = base_canvas()
    draw = ImageDraw.Draw(canvas)

    # F O N T I wordmark
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

    # Screenshot sizing
    shot = Image.open(RAW_DIR / raw_name).convert("RGB")
    target_w = 1000
    target_h = int(target_w * shot.height / shot.width)

    # Reserve room for bezel + bottom margin
    available_h = CANVAS_H - headline_end - 80 - BEZEL_THICKNESS * 2
    if target_h > available_h:
        scale = available_h / target_h
        target_w = int(target_w * scale)
        target_h = int(target_h * scale)
    shot = shot.resize((target_w, target_h), Image.LANCZOS)

    shot_x = (CANVAS_W - target_w) // 2
    shot_y = headline_end + BEZEL_THICKNESS
    screen_corner = 80

    # Bezel (paints around shot_x/y)
    draw_device_bezel(canvas, shot_x, shot_y, target_w, target_h, screen_corner)

    # Soft drop shadow under the whole device
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        [shot_x - BEZEL_THICKNESS, shot_y - BEZEL_THICKNESS + 40,
         shot_x + target_w + BEZEL_THICKNESS, shot_y + target_h + BEZEL_THICKNESS + 40],
        radius=screen_corner + BEZEL_THICKNESS,
        fill=(0, 0, 0, 210),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(45))

    # Composite shadow BELOW the bezel by recomposing in z-order:
    # gradient → shadow → bezel → screen
    final = base_canvas()
    fd = ImageDraw.Draw(final)
    draw_centered_text(fd, "F O N T I", wm_font, 90, CREAM_DIM)
    for i, line in enumerate(lines):
        draw_centered_text(fd, line, head_font, head_y + i * line_h, CREAM)
    final.paste(shadow, (0, 0), shadow)
    draw_device_bezel(final, shot_x, shot_y, target_w, target_h, screen_corner)
    final.paste(shot, (shot_x, shot_y), rounded_mask(target_w, target_h, screen_corner))

    final.save(out_path, "PNG", optimize=True)
    print(f"  ✓ {out_path.name}")


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for raw_name, headline in HEADLINES:
        compose(raw_name, headline, OUT_DIR / raw_name)
    print(f"\nSaved to {OUT_DIR}")


if __name__ == "__main__":
    main()
