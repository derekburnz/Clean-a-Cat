"""Clean a Cat: the human spa staff, a draft for screen pictures only (#185).

The owner's lean on 2026-11-24 is that helpers are human staff, not kittens. Nothing here is a game model yet: build()
dresses the stand-in blocky figure (scenes.avatar) for a portrait, and hud_icons.py reads the same colours for the
Helper button, so the two always match.

The uniform has to say "works here" beside customers, who are the same blocky people in sun hats, scarves or berets
(one of them in a mint tee): a mint smock with short sleeves and cream cuffs, a cream collar with two points, a cream
name badge with a pink paw, and never a hat. Each look is one person: skin, hair colour, hair style and blush.
"""

from common import Builder
import scenes

SMOCK, TRIM, BADGE_PAW = "spa_mint", "spa_cream", "nose_bubblegum"
FACE_INK, GLINT = "choco", "foam"

LOOKS = [
    # name, skin, hair colour, hair style, blush
    ("Jo", "skin_light", "fur_ginger", "bob", "nose_bubblegum"),
    ("Sam", "skin_deep", "fur_black", "crop", "nose_brick"),
]

HEAD_LO, HEAD_HI, HEAD_HALF = 3.6, 4.75, 0.575          # the stand-in figure's head (scenes.avatar)
FACE_Y, FACE_Z = -0.575, 4.175
X = (1.5707963267948966, "X")                            # stands a flat shape up to face the front


def _uniform(b):
    for sx in (-1, 1):
        b.box((sx * 1.5, 0, 3.26), (1.03, 1.03, 0.74), SMOCK)                        # short sleeve
        b.box((sx * 1.5, 0, 2.9), (1.09, 1.09, 0.16), TRIM)                          # cuff
        b.prism((sx * 0.27, -0.5, 3.4), [(-0.25, 0.17), (0.0, -0.19), (0.25, 0.17)], 0.07, TRIM, rot=X)   # collar point
    b.box((0, 0, 3.585), (1.5, 1.05, 0.11), TRIM)                                    # collar
    bx, by, bz = 0.5, -0.495, 3.07                                                   # name badge, on the heart side
    b.box((bx, by, bz), (0.5, 0.05, 0.34), TRIM)
    b.box((bx, by - 0.03, bz - 0.05), (0.16, 0.03, 0.12), BADGE_PAW, bevel=False)
    for dx in (-0.11, 0.0, 0.11):
        b.box((bx + dx, by - 0.03, bz + 0.07 - abs(dx) * 0.25), (0.07, 0.03, 0.07), BADGE_PAW, bevel=False)


def _face(b, blush):
    y = FACE_Y - 0.012
    for sx in (-1, 1):
        b.box((sx * 0.25, y, FACE_Z + 0.08), (0.15, 0.03, 0.26), FACE_INK, bevel=False)          # eye
        b.box((sx * 0.25 + 0.03, y - 0.012, FACE_Z + 0.15), (0.05, 0.03, 0.07), GLINT, bevel=False)
        b.box((sx * 0.37, y, FACE_Z - 0.16), (0.16, 0.02, 0.08), blush, bevel=False)              # cheek
        b.box((sx * 0.2, y, FACE_Z - 0.2), (0.07, 0.03, 0.07), FACE_INK, bevel=False)            # smile corner
    b.box((0, y, FACE_Z - 0.27), (0.4, 0.03, 0.07), FACE_INK, bevel=False)                       # smile


def _hair(b, style, colour):
    if style == "bob":                                   # chin length, a swept fringe, a lock each side and a bun
        b.box((0, 0.0, 4.81), (1.35, 1.35, 0.3), colour)
        b.prism((0, -0.66, 4.63), [(-0.7, 0.18), (-0.7, -0.27), (0.7, -0.03), (0.7, 0.18)], 0.12, colour, rot=X)
        for sx in (-1, 1):
            b.box((sx * 0.57, -0.585, 4.06), (0.21, 0.18, 0.8), colour)
            b.box((sx * 0.62, 0.06, 4.18), (0.11, 1.23, 1.04), colour)
        b.box((0, 0.62, 4.16), (1.35, 0.11, 1.0), colour)
        b.sphere((0, 0.34, 5.0), 0.34, colour, segments=10, rings=6)
    else:                                                # "crop": short curls on top, short sides, square temples
        b.box((0, 0.0, 4.85), (1.31, 1.31, 0.3), colour)
        for i, cx in enumerate((-0.42, 0.0, 0.42)):
            for j, cy in enumerate((-0.42, 0.0, 0.42)):
                b.box((cx, cy, 5.02 + 0.03 * ((i + j) % 2)), (0.38, 0.38, 0.16), colour)
        for sx in (-1, 1):
            b.box((sx * 0.56, -0.59, 4.58), (0.2, 0.13, 0.26), colour)
            b.box((sx * 0.61, 0.08, 4.5), (0.09, 1.15, 0.42), colour)
        b.box((0, 0.61, 4.42), (1.31, 0.09, 0.58), colour)


def build(mat, look):
    """The stand-in figure as staff member `look` (a LOOKS row). Returns the objects; the head parts' names end in
    _Head, so a portrait can frame on them."""
    name, skin, hair, style, blush = look
    body = scenes.avatar(mat, (0, 0, 0), skin, SMOCK, "pants_navy")
    b = Builder()
    _uniform(b)
    kit = b.finalize(f"Staff{name}_Uniform", mat)
    h = Builder()
    _hair(h, style, hair)
    top = h.finalize(f"Staff{name}_Hair_Head", mat)
    f = Builder()
    _face(f, blush)
    face = f.finalize(f"Staff{name}_Face", mat, bevel=0)
    return [body, kit, top, face]
