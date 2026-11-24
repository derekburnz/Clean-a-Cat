"""The HUD coin (#185): the owner's library coin picture with its outline redrawn in the HUD ink.

    python3 hud_coin.py <library CatCafe_Icon_Coins.png> <out CleanACat_Icon_Hud_Coins.png>

Plain Python with Pillow and numpy. The owner chose his library's coin over a coin rendered here, then asked for it to
be re-outlined to match the other five HUD pictures (2026-11-24: "just reoutline it"). So the coin itself is not
touched: only the library's brown outline (#6B3D0A, 10 px) turns into the ink the other five use (#45226B), and it
grows to their 13 px. Where the outline's edge blends into the gold, the brown share of each pixel is swapped for ink.
"""

import sys

import numpy as np
from PIL import Image

BROWN = np.array((107, 61, 10), dtype=np.float32)      # the library outline, measured from the file
INK = np.array((0x45, 0x22, 0x6B), dtype=np.float32)   # the outline of hud_icons.py
WIDTH, GROW = 10, 3                                    # px: the library's outline, and what takes it to our 13
EXACT, PURE, REACH = 3.0, 12.0, 150.0                  # colour distance: the outline's own colour, outline, gold


def _disc(r):
    return [(dy, dx) for dy in range(-r, r + 1) for dx in range(-r, r + 1) if dx * dx + dy * dy <= r * r]


def _grow(mask, r):
    out = mask.copy()
    for dy, dx in _disc(r):
        out = np.maximum(out, np.roll(np.roll(mask, dy, 0), dx, 1))
    return out


def reoutline(src, dst):
    px = np.array(Image.open(src).convert("RGBA")).astype(np.float32)
    rgb, a = px[:, :, :3], px[:, :, 3] / 255.0
    dist = np.sqrt(((rgb - BROWN) ** 2).sum(axis=2))
    outline = ((dist < PURE) & (a > 0)).astype(np.float32)
    # Only as far in as the outline reaches: the dark seam between the two coins is nearly the same brown. A notch
    # the outline filled (between the twinkle and the coin) lies deeper, so it is reached by spreading from the
    # outline through pixels of exactly its colour, which a rendered shadow never holds for long.
    near = _grow((a < 0.5).astype(np.float32), WIDTH + 2) > 0
    exact = (dist < EXACT) & (a > 0)
    fill = exact & near
    while True:
        spread = fill.copy()
        for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            spread |= np.roll(np.roll(fill, dy, 0), dx, 1)
        spread &= exact
        if (spread == fill).all():
            break
        fill = spread
    reach = near | (_grow(fill.astype(np.float32), 2) > 0)
    band = (_grow(outline, 2) > 0) & reach
    share = np.clip(1.0 - dist / REACH, 0.0, 1.0) * band
    rgb = rgb + share[:, :, None] * (INK - BROWN)
    grown = _grow(a, GROW)
    out = np.empty_like(px)
    out[:, :, :3] = rgb * a[:, :, None] + INK * (1.0 - a[:, :, None])
    out[:, :, 3] = grown * 255.0
    Image.fromarray(np.clip(out + 0.5, 0, 255).astype(np.uint8), "RGBA").save(dst)
    return int(outline.sum()), int((share > 0).sum())


if __name__ == "__main__":
    print("outline pixels %d, recoloured %d" % reoutline(sys.argv[1], sys.argv[2]))
