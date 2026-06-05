#!/usr/bin/env python3
"""Render the Fonti app icon: cream serif 'F' on near-black, 1024x1024."""

from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

CANVAS = 1024
INK = (0x0D, 0x0D, 0x0D)
CREAM = (0xF5, 0xF0, 0xE8)
FONT_PATH = "/System/Library/Fonts/NewYork.ttf"

OUT = Path(__file__).resolve().parents[1] / \
    "Fonti/Assets.xcassets/AppIcon.appiconset/icon-1024.png"


def main() -> None:
    image = Image.new("RGB", (CANVAS, CANVAS), INK)
    draw = ImageDraw.Draw(image)

    # Aim for the F glyph to occupy ~70% of the canvas height.
    point_size = int(CANVAS * 0.72)
    font = ImageFont.truetype(FONT_PATH, point_size)

    glyph = "F"
    bbox = draw.textbbox((0, 0), glyph, font=font)
    glyph_w = bbox[2] - bbox[0]
    glyph_h = bbox[3] - bbox[1]

    # Optical centering: nudge slightly left to balance the F's right-side
    # negative space, and slightly up so the serif baseline visually centers.
    nudge_x = -int(CANVAS * 0.015)
    nudge_y = -int(CANVAS * 0.04)

    x = (CANVAS - glyph_w) // 2 - bbox[0] + nudge_x
    y = (CANVAS - glyph_h) // 2 - bbox[1] + nudge_y

    draw.text((x, y), glyph, font=font, fill=CREAM)

    OUT.parent.mkdir(parents=True, exist_ok=True)
    image.save(OUT, "PNG", optimize=True)
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()
