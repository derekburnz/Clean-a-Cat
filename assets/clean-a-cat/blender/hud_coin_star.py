"""The HUD coin with a star on its face in place of the money sign.

    python3 hud_coin_star.py <CleanACat_Icon_Hud_Coins.png> <out.png>

Plain Python with Pillow. Run once on the coin hud_coin.py made (git history has it). The owner's library coin
carried an S with a bar, which reads as a money sign: Review-QA's image gate refuses real-money symbols, and the shop
coins already use a star. Derek, 2026-11-27, on the side by side: "star is fine". Only the face changes: the sign is
covered with the face's own colour and a raised five point star is drawn in the coin's darker golds, lying on the
face at its tilt. The coin, its outline and its twinkle stay as they were.
"""

import math
import sys

from PIL import Image, ImageDraw

FACE = (216, 196, 133, 255)                    # the coin face, measured from the file
TOP, SIDE = (200, 146, 52, 255), (150, 104, 34, 255)
CENTRE, TILT, SQUASH = (238, 186), -6.0, 0.5   # the face's middle (px at 512), its turn and how flat it lies
COVER, STAR, RISE = (128, 162), (100, 46), 12  # the patch over the sign, the star's radii, its height in px
FOOT, FOOT_FROM = (254, 259, 290, 273), (300, 266)  # the foot's box on the rim, and where its colour is read
SS = 4                                         # drawn at four times the size, then scaled down


def _at(x, y, dz=0.0):
    a = math.radians(TILT)
    return ((CENTRE[0] + x * math.cos(a) - y * math.sin(a)) * SS,
            (CENTRE[1] + (x * math.sin(a) + y * math.cos(a)) * SQUASH + dz) * SS)


def _star(dz):
    return [_at((STAR[i % 2]) * math.sin(i * math.pi / 5), -(STAR[i % 2]) * math.cos(i * math.pi / 5), dz)
            for i in range(10)]


def main(src, out):
    im = Image.open(src).convert("RGBA")
    size = im.width
    big = im.resize((size * SS, size * SS), Image.LANCZOS)
    d = ImageDraw.Draw(big)
    d.polygon([_at(COVER[0] * math.cos(t / 60 * 2 * math.pi), COVER[1] * math.sin(t / 60 * 2 * math.pi))
               for t in range(60)], fill=FACE)
    rim = im.getpixel(FOOT_FROM)                               # the bar's foot reached the rim: painted over
    d.ellipse([v * SS for v in FOOT], fill=rim)
    low, up = _star(RISE * 0.4), _star(-RISE * 0.6)
    d.polygon(low, fill=SIDE)
    for i in range(10):
        d.polygon([low[i], low[(i + 1) % 10], up[(i + 1) % 10], up[i]], fill=SIDE)
    d.polygon(up, fill=TOP)
    big.resize((size, size), Image.LANCZOS).save(out)
    print("hud coin:", out)


if __name__ == "__main__":
    main(*sys.argv[1:3])
