#!/usr/bin/env python3
"""Small, tileable textures for a realistic ground (generated offline, so phones only
load a few small images - nothing is computed on the device).

    pip install numpy pillow
    python3 tools/gen_textures.py

Writes assets/textures/:
    grass.png  256x256  tileable grass detail, near-neutral (tinted in game by stripe colour)
    pitch.png  128x512  dry, rolled pitch with cracks and worn footmark areas (x = width)
    crowd.png  512x128  tileable rows of seated spectators (u along the stand, v up it)
"""
import os
import numpy as np
from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "assets", "textures")
rng = np.random.default_rng(20261110)


def tile_noise(h, w, scale, octaves=4):
    """Tileable value noise in [0, 1] (periodic interpolation of a random lattice)."""
    acc = np.zeros((h, w))
    amp, total = 1.0, 0.0
    for o in range(octaves):
        gh, gw = max(2, int(h / scale * 2 ** o)), max(2, int(w / scale * 2 ** o))
        lat = rng.random((gh, gw))
        ys = np.linspace(0, gh, h, endpoint=False)
        xs = np.linspace(0, gw, w, endpoint=False)
        y0 = np.floor(ys).astype(int); x0 = np.floor(xs).astype(int)
        fy = ys - y0; fx = xs - x0
        fy = fy * fy * (3 - 2 * fy); fx = fx * fx * (3 - 2 * fx)
        y1 = (y0 + 1) % gh; x1 = (x0 + 1) % gw
        a = lat[np.ix_(y0, x0)]; b = lat[np.ix_(y0, x1)]
        c = lat[np.ix_(y1, x0)]; d = lat[np.ix_(y1, x1)]
        top = a + (b - a) * fx[None, :]
        bot = c + (d - c) * fx[None, :]
        acc += (top + (bot - top) * fy[:, None]) * amp
        total += amp
        amp *= 0.5
    return acc / total


def save(name, arr):
    os.makedirs(OUT, exist_ok=True)
    Image.fromarray(np.clip(arr * 255, 0, 255).astype(np.uint8)).save(os.path.join(OUT, name), optimize=True)


def grass():
    # Neutral-ish green (the game tints it per atmosphere and for the mowing stripes).
    n = 256
    patch = tile_noise(n, n, 64)
    fine = rng.random((n, n))
    blades = np.zeros((n, n))
    for _ in range(9000):   # short vertical-ish blades
        x, y = rng.integers(0, n, 2)
        ln = rng.integers(2, 6)
        for k in range(ln):
            blades[(y - k) % n, (x + (k // 3)) % n] += 0.5
    v = 0.86 + 0.12 * (patch - 0.5) + 0.06 * (fine - 0.5) + 0.08 * (np.clip(blades, 0, 1) - 0.3)
    # Near-neutral (slightly warm in the dry patches): the game multiplies it by the
    # stripe colour, so one texture serves every venue, stripe and light.
    dry = tile_noise(n, n, 96, 3)
    tint = np.stack([1.0 + 0.06 * (dry - 0.5), np.ones_like(dry), 0.96 - 0.06 * (dry - 0.5)], -1)
    img = np.clip(v[..., None] * tint, 0, 1)
    save("grass.png", img)


def pitch():
    h, w = 512, 128
    n1 = tile_noise(h, w, 48)
    fine = rng.random((h, w))
    base = np.array([0.80, 0.68, 0.48])
    v = 0.92 + 0.08 * (n1 - 0.5) + 0.05 * (fine - 0.5)
    # A faint green tinge down the middle strip (where grass survives on a used pitch)
    xs = np.linspace(-1, 1, w)
    v = v[..., None] * base[None, None, :]
    v[..., 1] += 0.02 * np.exp(-(xs[None, :] * 2.2) ** 2)
    # Cracks: short random walks
    img = v.copy()
    for _ in range(70):
        y, x = rng.integers(0, h), rng.integers(0, w)
        for k in range(rng.integers(14, 40)):
            img[y % h, x % w] *= 0.88
            y += rng.integers(-1, 2); x += rng.integers(-1, 2)
    # Worn footmark areas near each end (scuffed, darker, rougher)
    yy = np.arange(h)[:, None]; xx = np.arange(w)[None, :]
    for cy in (28, 70, h - 70, h - 28):
        for cx in (int(w * 0.32), int(w * 0.68)):
            d = ((yy - cy) / 26.0) ** 2 + ((xx - cx) / 16.0) ** 2
            m = np.exp(-d) * (0.75 + 0.5 * fine)
            img *= (1.0 - 0.18 * m)[..., None]
    save("pitch.png", img)


def crowd():
    # Rows of seated spectators: heads and shirts in varied colours over dark seating.
    w, h = 512, 128
    img = np.zeros((h, w, 3))
    img[:] = np.array([0.2, 0.23, 0.3])   # blue-grey seats
    rows = 8
    rh = h / rows
    shirts = np.array([[0.85, 0.2, 0.2], [0.15, 0.4, 0.75], [0.95, 0.95, 0.92], [0.1, 0.5, 0.3],
                       [0.95, 0.75, 0.2], [0.6, 0.25, 0.55], [0.2, 0.2, 0.22], [0.9, 0.5, 0.2],
                       [0.3, 0.65, 0.85], [0.75, 0.75, 0.78]])
    skins = np.array([[0.78, 0.58, 0.44], [0.62, 0.44, 0.32], [0.48, 0.33, 0.24], [0.86, 0.68, 0.55]])
    for r in range(rows):
        y0 = int(r * rh)
        img[y0:y0 + 2] = np.array([0.32, 0.33, 0.36])   # seat row edge
        x = rng.uniform(0, 4)
        while x < w:
            if rng.random() < 0.9:   # some empty seats
                cx = int(x) % w
                # Muted: from the stands' distance colours blend toward grey.
                sh = shirts[rng.integers(0, len(shirts))] * 0.62 + 0.18
                sk = skins[rng.integers(0, len(skins))]
                for dy in range(int(rh * 0.45), int(rh * 0.95)):
                    for dx in range(-2, 3):
                        img[(y0 + dy) % h, (cx + dx) % w] = sh * (0.85 + 0.15 * rng.random())
                for dy in range(int(rh * 0.18), int(rh * 0.45)):
                    for dx in range(-1, 2):
                        img[(y0 + dy) % h, (cx + dx) % w] = sk
            x += rng.uniform(5.5, 7.5)
    # Light from the front, darker toward the back rows (top of the image)
    shade = np.linspace(0.78, 1.0, h)[::-1][:, None, None]
    save("crowd.png", img * shade)


if __name__ == "__main__":
    grass()
    pitch()
    crowd()
    print("textures written to", OUT)
