#!/usr/bin/env python3
"""Google Play feature graphic (1024x500) composed from a real gameplay screenshot.

    pip install pillow
    python3 tools/gen_store_art.py store/screenshots/play_phone_land_4.png

Writes store/feature_graphic_1024x500.png: the screenshot (cropped, darkened on the left),
the game icon, the name and a one-line tagline in the game's own Lato font.
"""
import os, sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
W, H = 1024, 500


def font(weight, size):
    return ImageFont.truetype(os.path.join(ROOT, "assets", "fonts", "Lato-%s.ttf" % weight), size)


def main(shot):
    src = Image.open(shot).convert("RGB")
    k = max(W / src.width, H / src.height)
    src = src.resize((int(src.width * k), int(src.height * k)), Image.LANCZOS)
    x0 = (src.width - W) // 2
    y0 = (src.height - H) // 2
    img = src.crop((x0, y0, x0 + W, y0 + H))
    # Darken the left half for the title (left-to-right gradient).
    shade = Image.new("L", (W, H))
    d = ImageDraw.Draw(shade)
    for x in range(W):
        d.line([(x, 0), (x, H)], fill=int(215 * max(0.0, 1.0 - x / (W * 0.62))))
    dark = Image.new("RGB", (W, H), (4, 30, 24))
    img = Image.composite(dark, img, shade)
    icon = Image.open(os.path.join(ROOT, "assets", "icons", "icon_512_play.png")).convert("RGBA").resize((150, 150), Image.LANCZOS)
    mask = Image.new("L", icon.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, 149, 149), 34, fill=255)
    img.paste(icon, (56, 70), mask)
    draw = ImageDraw.Draw(img)
    gold, white, sand = (253, 201, 84), (250, 247, 237), (242, 222, 178)

    def text(xy, s, f, fill):
        x, y = xy
        for dx, dy in ((-3, 0), (3, 0), (0, -3), (0, 3), (-2, -2), (2, 2), (-2, 2), (2, -2)):
            draw.text((x + dx, y + dy), s, font=f, fill=(12, 10, 8))
        draw.text((x, y), s, font=f, fill=fill)

    text((56, 238), "TAP TAP", font("Black", 74), white)
    text((56, 312), "CRICKET", font("Black", 74), gold)
    text((60, 410), "One-tap street cricket. Time it. Hit it for six!", font("Bold", 28), sand)
    out = os.path.join(ROOT, "store", "feature_graphic_1024x500.png")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    img.save(out)
    print("wrote", out)


if __name__ == "__main__":
    main(sys.argv[1])
