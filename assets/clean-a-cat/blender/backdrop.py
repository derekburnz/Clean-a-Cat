"""The world round the street (issue #349): `CleanACat_Area_Backdrop`. The owner, 2026-11-24, after his dev test of the
opening: "draft the world/background and sky to help set the atmosphere". Until now the road ended in a hedge at both
ends of the street and there was nothing past the houses but sky. This is a first draft of what lies beyond; the sky,
the clouds and the lighting are Motion-FX's.

Placed once with no turn at the street's pivot (slot 1's plot pivot on the ground, like CleanACat_Area_Street), in the
street's own space. Its pieces, each a child Model:

  CleanACat_Area_Backdrop           the road carried on past both ends of the street with its pavements and curbs,
                                    cottages and trees along it, a second row of roofs and trees behind the houses
                                    across the road with a clock tower in it, bushes, and trees on the hills
  CleanACat_Area_Backdrop_Ground    one flat grass plate under all of it, its top a hair under the street's own
                                    ground, so there is no seam and no flicker where they overlap
  CleanACat_Area_Backdrop_Dashes    the road's white dashes, carried on
  CleanACat_Area_Backdrop_Hills     the near ring of rolling hills, sunk well into the ground so each rises gently;
                                    one sits on the road's line at either end, so the road runs up and over out of sight
  CleanACat_Area_Backdrop_HillsFar  the far ring, bigger and paler, so the horizon reads as layers of countryside

Nothing here collides, casts a shadow or takes a raycast (rbx_export BACKDROP: "_Backdrop" in the asset's name): it is
scenery past the street's invisible walls, out of reach, and nothing in the opening waits on it. Every piece keeps
clear of the street's own model (street.X0 to street.X1, street.Y_FAR - 18 to street.BACK + 16).

The hills, the round trees and the cottages are the backdrop generator of the owner's asset library
(derekburnz/Roblox-Asset-Library, models/blender-generators/backdrop.py) restyled to Bubble Pastel, 2026-11-24.
"""

import math

import rbx_export
import street
from common import Builder
from stations import _tris

N = "CleanACat_Area_Backdrop"
GROUND_Z = -0.08                   # the plate's top: under the street's ground (top -0.03)
REACH = 170.0                      # how far the road carries on past each end of the street
FAR_RGB = (166, 204, 150)          # the far hills: the grass, paler
rbx_export.LOOKS[N + "_HillsFar"] = ([round(v / 255, 4) for v in FAR_RGB], "SmoothPlastic")

WALLS = ("spa_sky", "pastel_butter", "spa_mint", "pastel_lilac", "spa_bubblegum", "spa_cream")
ROOFS = ("blush", "terracotta", "fur_slate", "nose_brick")
LEAVES = ("leaf_green", "leaf_dark", "leaf_green", "spa_mint")


def _hash(*v):
    h = 0
    for x in v:
        h = (h * 1000003 + int(round(x * 1000))) & 0xFFFFFFFF
    h ^= h >> 13
    h = (h * 0x5BD1E995) & 0xFFFFFFFF
    return (h ^ (h >> 15)) / 0xFFFFFFFF


# -- hills ------------------------------------------------------------------------------------------------------------
SINK = 1.6                         # a hill's centre sits SINK x its rise under the ground, so it meets it gently


def hill(b, x, y, along, across, rise, turn, swatch="leaf_green"):
    """An ellipsoid sunk into the ground: `along` and `across` are its foot's half lengths, `rise` its height over
    the ground, turned `turn` degrees about Z so `along` runs that way."""
    full = rise * (1 + SINK)
    f = math.sqrt(1 - (SINK / (1 + SINK)) ** 2)        # the foot is this much of the full radius
    b.ico((x, y, GROUND_Z - rise * SINK), 1.0, swatch, subdivisions=2, scale=(along / f, across / f, full),
          rot=(math.radians(turn), "Z"))


def hill_top(x, y, hills):
    """The ground's height at (x, y): the highest hill there, or the plate."""
    best = GROUND_Z
    for hx, hy, along, across, rise, turn in hills:
        f = math.sqrt(1 - (SINK / (1 + SINK)) ** 2)
        a, c, full = along / f, across / f, rise * (1 + SINK)
        t = math.radians(turn)
        dx, dy = x - hx, y - hy
        u, v = dx * math.cos(t) + dy * math.sin(t), -dx * math.sin(t) + dy * math.cos(t)
        q = 1 - (u / a) ** 2 - (v / c) ** 2
        if q > 0:
            best = max(best, GROUND_Z - rise * SINK + full * math.sqrt(q))
    return best


X0, X1 = street.X0, street.X1
CX = (X0 + X1) / 2
Y_ROAD = (street.Y_ROAD0 + street.Y_ROAD1) / 2
Y_BEHIND = street.Y_FAR - 18.0                         # the back of the street's own houses
# (x, y, along, across, rise, turn): the near ring. The two on the road's line swallow the road's ends.
NEAR = (
    (X1 + REACH + 26, Y_ROAD - 4, 62, 44, 15, 80), (X0 - REACH - 26, Y_ROAD + 4, 62, 44, 16, 100),
    (X1 + 120, Y_BEHIND - 62, 70, 40, 17, 20), (CX + 70, Y_BEHIND - 84, 80, 42, 21, -8), (CX - 40, Y_BEHIND - 92, 86, 44, 19, 6),
    (X0 + 20, Y_BEHIND - 80, 78, 42, 22, -10), (X0 - 110, Y_BEHIND - 58, 70, 40, 18, -24),
    (X1 + 130, street.BACK + 76, 72, 40, 16, -18), (CX + 60, street.BACK + 96, 84, 42, 20, 5), (CX - 60, street.BACK + 102, 84, 42, 18, -6),
    (X0 - 10, street.BACK + 92, 76, 40, 21, 10), (X0 - 130, street.BACK + 70, 70, 40, 17, 22),
)
FAR = (
    (X1 + 280, Y_ROAD - 30, 120, 80, 44, 85), (X0 - 280, Y_ROAD + 20, 120, 80, 48, 95),
    (X1 + 150, Y_BEHIND - 190, 130, 70, 46, 24), (CX + 40, Y_BEHIND - 220, 150, 76, 58, -4), (X0 - 40, Y_BEHIND - 205, 140, 72, 50, 8),
    (X0 - 220, Y_BEHIND - 150, 120, 70, 42, -30),
    (X1 + 170, street.BACK + 210, 130, 70, 44, -22), (CX, street.BACK + 236, 150, 76, 54, 3), (X0 - 150, street.BACK + 200, 130, 70, 46, 20),
)


# -- trees, bushes, cottages --------------------------------------------------------------------------------------------
def tree(b, x, y, s=1.0, leaf="leaf_green", z=GROUND_Z, crowns=2):
    """A round tree: a trunk and one or two plain balls (a scaled ball is two instances in Roblox)."""
    z -= 0.3 * s
    b.cyl_base((x, y, z), 0.5 * s, 4.4 * s, "wood_light", segments=6, bevel=False)
    b.sphere((x, y, z + 6.0 * s), 3.1 * s, leaf, segments=8, rings=5)
    if crowns > 1:
        b.sphere((x + 1.6 * s, y + 0.6 * s, z + 4.8 * s), 2.3 * s, leaf, segments=8, rings=5)


def bush(b, x, y, s=1.0, leaf="leaf_dark"):
    b.sphere((x, y, GROUND_Z + 0.5 * s), 1.6 * s, leaf, segments=8, rings=5, scale=(1.5, 1.0, 0.8))


def cottage(b, x, y, w, d, h, wall, roof, face=1, chimney=True):
    """A little pastel house whose front faces +Y (face 1) or -Y (face -1): walls, a gable roof of two wedges with
    its ridge along X, a chimney, a door and two windows."""
    b.box_base((x, y, GROUND_Z), (w, d, h), wall, bevel=False)
    rise = 0.42 * d
    for s in (1, -1):                                  # each roof half rises to the ridge
        b.wedge((x, y + s * (d / 4 + 0.3), GROUND_Z + h + rise / 2), (w + 1.4, d / 2 + 0.6, rise), roof, bevel=False,
                rot=(math.radians(0 if s < 0 else 180), "Z"))
    if chimney:
        b.box_base((x + w * 0.27, y - face * d * 0.12, GROUND_Z + h + rise * 0.2), (1.3, 1.3, rise * 0.95), "nose_brick", bevel=False)
    fy = y + face * (d / 2 + 0.08)
    b.box_base((x, fy, GROUND_Z), (2.2, 0.2, 4.2), "wood_light", bevel=False)                          # door
    for s in (1, -1):
        b.box_base((x + s * w * 0.3, fy, GROUND_Z + h * 0.42), (2.6, 0.2, 2.4), "pastel_sky", bevel=False)   # windows
        b.box_base((x + s * w * 0.3, fy + face * 0.06, GROUND_Z + h * 0.42 - 0.3), (3.0, 0.3, 0.3), "offwhite", bevel=False)


def tower(b, x, y):
    """A clock tower for the skyline: a cream shaft, a bubblegum belfry with a blank clock face toward the street, a
    blush roof. No writing, no hands that tell a time."""
    z = GROUND_Z
    b.box_base((x, y, z), (7.0, 7.0, 26.0), "spa_cream", bevel=False)
    b.box_base((x, y, z + 25.98), (8.2, 8.2, 1.0), "spa_mint", bevel=False)
    b.box_base((x, y, z + 26.96), (6.4, 6.4, 6.0), "spa_bubblegum", bevel=False)
    b.cyl((x, y + 3.25, z + 30.0), 2.2, 0.3, "offwhite", segments=12, bevel=False, rot=(math.radians(90), "X"))
    b.box((x, y + 3.45, z + 30.5), (0.3, 0.12, 1.4), "fur_slate", bevel=False)
    b.box((x + 0.5, y + 3.46, z + 30.0), (1.2, 0.12, 0.3), "fur_slate", bevel=False)
    for s in (1, -1):
        b.wedge((x, y + s * 1.9, z + 34.9), (7.6, 3.8, 4.0), "blush", bevel=False, rot=(math.radians(0 if s < 0 else 180), "Z"))


# -- the pieces ---------------------------------------------------------------------------------------------------------
def _road(b, dashes):
    """The road, its pavements and curbs carried on REACH past each end of the street, in the street's own sizes."""
    top = street.TOP
    for x0, x1 in ((X1, X1 + REACH), (X0 - REACH, X0)):
        cx, ln = (x0 + x1) / 2, x1 - x0
        b.box_base((cx, Y_ROAD, -0.09), (ln, street.ROAD + 0.02, 0.31), "concrete_dark", bevel=False)           # top 0.22
        for y in (street.Y_ROAD0 + 0.3, street.Y_ROAD1 - 0.3):
            b.box_base((cx, y, -0.1), (ln, 0.6, top + 0.18), "spa_cream", bevel=False)                           # curbs
        b.box_base((cx, street.FRONT - street.PAVE / 2, -0.1), (ln, street.PAVE, top + 0.1), "paving_light", bevel=False)
        b.box_base((cx, street.Y_ROAD1 - 0.6 - street.FAR / 2, -0.1), (ln, street.FAR, top + 0.1), "paving_light", bevel=False)
        n = int(ln // 12)
        for i in range(n):
            dashes.box_base((x0 + 6.0 + 12.0 * i, Y_ROAD, 0.21), (6.0, 0.5, 0.03), "offwhite", bevel=False)


def _along_the_road(b):
    """Cottages and trees on both sides of the road past the street's ends."""
    k = 0
    for sign, x_from in ((1, X1), (-1, X0)):
        for i in range(4):
            x = x_from + sign * (22.0 + 38.0 * i)
            for side, y, face in ((0, street.Y_FAR - 11.0, 1), (1, street.FRONT + 9.0, -1)):
                h = _hash(i, side, sign + 2)
                cottage(b, x + (h - 0.5) * 6, y, 17.0 + 4 * h, 12.0, 8.0 + 3.0 * _hash(k, 5), WALLS[k % len(WALLS)],
                        ROOFS[(k + side) % len(ROOFS)], face)
                tree(b, x + sign * 17.0, y - face * 1.0, 1.1 + 0.5 * _hash(k, 9), LEAVES[k % len(LEAVES)])
                k += 1


def _second_row(b):
    """Behind the houses across the road: taller roofs, a clock tower and a line of big trees, so the street's own
    houses do not stand against bare sky."""
    y = Y_BEHIND - 14.0
    n = 8
    for i in range(n):
        x = X0 + 18.0 + (X1 - X0 - 36.0) * i / (n - 1)
        h = _hash(i, 4)
        if i == 4:
            tower(b, x + 6.0, y - 4.0)
            continue
        cottage(b, x, y - 6 * h, 20.0 + 6 * h, 13.0, 15.0 + 6.0 * _hash(i, 8), WALLS[(i + 3) % len(WALLS)],
                ROOFS[(i + 1) % len(ROOFS)], 1, chimney=i % 2 == 0)
    for i in range(14):                                # the big trees between and behind them
        x = X0 + 6.0 + (X1 - X0 - 12.0) * i / 13
        tree(b, x + (_hash(i, 2) - 0.5) * 8, y - 16.0 - 8 * _hash(i, 6), 2.0 + 1.0 * _hash(i, 3), LEAVES[i % len(LEAVES)],
             crowns=1 + i % 2)
    for i in range(10):                                # and behind the spas, past the street's own trees
        x = X0 + 10.0 + (X1 - X0 - 20.0) * i / 9
        tree(b, x + (_hash(i, 12) - 0.5) * 10, street.BACK + 34.0 + 10 * _hash(i, 16), 2.0 + 1.0 * _hash(i, 13),
             LEAVES[(i + 1) % len(LEAVES)], crowns=1 + i % 2)


def _on_the_hills(b):
    """Trees on the near hills' upper slopes and far trees on the far ring; bushes on the open grass."""
    for ring, per, scale, seed in ((NEAR, 3, 1.7, 5), (FAR, 3, 3.2, 6)):
        for i, (hx, hy, along, across, _rise, turn) in enumerate(ring):
            if ring is NEAR and i < 2:                 # the two hills the road runs up stay bare on its line
                continue
            for k in range(per):
                a = 2 * math.pi * _hash(seed, i, k)
                d = 0.15 + 0.4 * _hash(k, i, seed)
                t = math.radians(turn)
                u, v = math.cos(a) * along * d, math.sin(a) * across * d
                x, y = hx + u * math.cos(t) - v * math.sin(t), hy + u * math.sin(t) + v * math.cos(t)
                leaf = "blush" if _hash(i, k, 7) > 0.86 else LEAVES[int(_hash(k, seed, i) * 4) % 4]
                tree(b, x, y, scale * (0.8 + 0.5 * _hash(i, k, seed)), leaf, z=hill_top(x, y, ring), crowns=1)
    for i in range(12):
        x = X0 - 150 + (X1 - X0 + 300) * _hash(i, 21)
        y = (Y_BEHIND - 46 - 20 * _hash(i, 22)) if i % 2 else (street.BACK + 50 + 16 * _hash(i, 23))
        bush(b, x, y, 1.4 + 1.2 * _hash(i, 24), LEAVES[i % 2])


def build_backdrop(mat):
    main, ground, dashes, near, far = Builder(), Builder(), Builder(), Builder(), Builder()
    w, d = X1 - X0 + 2 * REACH + 560, 720.0
    ground.box_base((CX, Y_ROAD + 20.0, GROUND_Z - 1.0), (w, d, 1.0), "leaf_green", bevel=False)
    _road(main, dashes)
    _along_the_road(main)
    _second_row(main)
    _on_the_hills(main)
    for h in NEAR:
        hill(near, *h)
    for h in FAR:
        hill(far, *h)
    return [_tris(main.finalize(N, mat, bevel=0)), _tris(ground.finalize(N + "_Ground", mat, bevel=0)),
            _tris(dashes.finalize(N + "_Dashes", mat, bevel=0)), _tris(near.finalize(N + "_Hills", mat, bevel=0)),
            _tris(far.finalize(N + "_HillsFar", mat, bevel=0))]


ASSETS = {N: (build_backdrop, 40000)}
EXTRAS = {}
