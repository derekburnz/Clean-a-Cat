"""The wash room (issue #856): the clean room the wash screen draws around the close-up wash view, so the player sees
only the cat, the tub and a calm pastel bathroom while they wash (Derek on dev, 2026-11-26: "make the cat washing
minigame a whole different screen ... don't make it still show stuff in background").

  CleanACat_Area_WashRoom     a room HALF studs each way from the tub's spot and HEIGHT high, every face turned
                              inward: a pale tile floor with sky tiles in a checker, mint tiled walls to a butter
                              rail, cream walls above, a white ceiling with a round lamp. The decor is on the back
                              wall, the one the wash camera looks at over the cat: a round sky window over the tub, a
                              shelf of rolled towels, bottles and a rubber duck on the left, two towels on hooks on
                              the right, soap bubbles in the top corners. Each side wall has its own piece (a towel
                              rail, a round mirror), a plant stands in each back corner and a round bath mat lies in
                              front of the tub.

Pivot at the tub's spot on the floor, front -Y in Blender (-Z in Roblox): WashScreenController turns the room so its
front faces the cat's face, so the camera stands on the -Y side and sees the +Y wall behind the cat. The sizes match
WashScreenRules (HALF 13, HEIGHT 12, FLOOR_LIFT 0.05); nothing stands within KEEP (4.5) of the spot but the bath mat,
which lies flat in front of the tub. The controller makes every part non-solid with no shadow.
"""

import math

from mathutils import Matrix

from common import Builder
from stations import _tris

NAME = "CleanACat_Area_WashRoom"
HALF = 13.0                     # WashScreenRules.HALF: the walls' inner faces stand this far from the spot
HEIGHT = 12.0                   # WashScreenRules.HEIGHT: the ceiling's underside
WALL = 1.0                      # WashScreenRules.WALL
LIFT = 0.05                     # WashScreenRules.FLOOR_LIFT: the floor's top, clear of the plot's floor
RAIL = 4.0                      # the top of the tiled band on the walls
SINK = 0.06                     # how far the back of every piece on a wall reaches into the wall
FLOOR, FLOOR_TILE = "spa_tile", "tile_sky"
BAND, BAND_TILE, TRIM, UPPER, CEILING = "spa_mint", "spa_tile", "pastel_butter", "spa_cream", "foam"
_STAND = Matrix.Rotation(math.pi / 2, 3, "X")          # a disc lying flat stood up to face -Y
_SIDE = Matrix.Rotation(math.pi / 2, 3, "Y")           # a disc lying flat stood up to face +-X


def _shell(b):
    """Floor, ceiling and four walls, the tiled band and its rail on every wall, the floor's checker."""
    # every slab is a hair short of the next one's outer faces, so no two faces share a plane
    span = 2 * (HALF + WALL)
    b.box_base((0, 0, LIFT - WALL), (span - 0.06, span - 0.06, WALL), FLOOR, bevel=False)       # the floor
    b.box_base((0, 0, HEIGHT), (span - 0.06, span - 0.06, WALL), CEILING, bevel=False)         # the ceiling
    for sy in (1, -1):                                                                         # back and front walls
        b.box_base((0, sy * (HALF + WALL / 2), 0), (span, WALL, HEIGHT + 0.4), UPPER, bevel=False)
    for sx in (1, -1):                                                                         # the side walls
        b.box_base((sx * (HALF + WALL / 2 - 0.01), 0, -0.05), (WALL - 0.02, 2 * HALF + 0.9, HEIGHT + 0.3), UPPER,
                   bevel=False)
    # the floor's checker: sky tiles on every other 4 stud square, their tops a hair over the floor
    for i in range(-3, 4):
        for j in range(-3, 4):
            if (i + j) % 2:
                b.box_base((4 * i, 4 * j, LIFT - 0.04), (3.9, 3.9, 0.05), FLOOR_TILE, bevel=False)
    # the tiled band: a mint lining up to RAIL on each wall with pale 2 stud tiles on it in a checker, and a butter
    # rail over it. Each layer stands a little further out than the one under it.
    band_t, tile_t, rail_t = 0.1, 0.14, 0.24
    for k, (axis, sign) in enumerate((("y", 1), ("y", -1), ("x", 1), ("x", -1))):
        inner = sign * HALF
        n = 13                                                       # 2 stud tiles along each 26 stud wall

        def flat(along, z0, h, depth, w, sw, sink=SINK):            # each layer's back a different depth in
            off = inner - sign * (depth - sink) / 2
            if axis == "y":
                b.box_base((along, off, z0), (w, depth + sink, h), sw, bevel=False)
            else:
                b.box_base((off, along, z0), (depth + sink, w, h), sw, bevel=False)

        # the walls meet in the corners, so each wall's layers are a hair taller or lower than the last wall's
        flat(0, LIFT - 0.02 - 0.004 * k, RAIL - LIFT + 0.02, band_t, 2 * HALF - 0.02 - 0.004 * k, BAND)
        for t in range(n):
            for r in range(2):
                if (t + r + k) % 2:
                    flat(-HALF + 1 + 2 * t, LIFT + 2 * r + 0.04 + 0.003 * k, 1.9 - 0.007 * k, tile_t, 1.9, BAND_TILE,
                         sink=SINK - 0.02)
        flat(0, RAIL - 0.02 - 0.004 * k, 0.36 + 0.008 * k, rail_t, 2 * HALF - 0.03 - 0.004 * k, TRIM,
             sink=SINK + 0.02)


def _on_back(b, x, z, w, h, depth, sw, k=0, rot=None):
    """A flat piece on the back wall, its front `depth` out from the wall, its back SINK (and a hair per layer k) in."""
    back = SINK + 0.004 * k
    b.box((x, HALF - (depth - back) / 2, z), (w, depth + back, h), sw, bevel=False, rot=rot)


def _window(b):
    """A round sky window over the tub: a white frame round a sky pane with a cloud, a cross of white bars, a butter
    sill. The pane stands a little out of the frame's disc, so the frame shows as a rim."""
    x, z, r = 0.0, 9.1, 2.3                         # high, so it shows over the cat's head, not behind it
    b.cyl((x, HALF - 0.1, z), r, 0.2 + 2 * SINK, "foam", segments=24, bevel=False, rot=_STAND)        # the frame
    b.cyl((x, HALF - 0.2, z), r - 0.35, 0.22, "pastel_sky", segments=24, bevel=False, rot=_STAND)
    for i, (dx, dz, s) in enumerate(((-0.7, -0.6, 0.45), (-0.2, -0.4, 0.6), (0.4, -0.6, 0.42))):     # a cloud
        b.cyl((x + dx, HALF - 0.32 - 0.006 * i, z + dz), s, 0.1 + 0.004 * i, "foam", segments=12, bevel=False, rot=_STAND)
    _on_back(b, x, z, 0.24, 2 * r - 0.5, 0.4, "foam", k=1)                                             # the bars
    _on_back(b, x, z, 2 * r - 0.5, 0.24, 0.41, "foam", k=2)
    _on_back(b, x, z - r - 0.12, 2 * r + 0.6, 0.3, 0.5, TRIM, k=3)                                    # the sill


def _shelf(b):
    """A shelf on the left of the back wall: rolled towels, two bottles and a rubber duck."""
    x0, z = -8.0, 6.2
    _on_back(b, x0, z, 6.0, 0.24, 1.2, "caramel_wood")
    for sx in (-2.4, 2.4):                                                                        # its brackets
        _on_back(b, x0 + sx, z - 0.5, 0.2, 0.8, 0.9, "caramel_wood", k=1)
    y = HALF - 0.62
    for i, sw in enumerate(("spa_bubblegum", "spa_mint", "pastel_butter")):                       # rolled towels
        b.cyl((x0 - 2.2 + 0.95 * i, y, z + 0.12 + 0.4), 0.4, 1.0, sw, segments=12, bevel=False, rot=_STAND)
        b.cyl((x0 - 2.2 + 0.95 * i, y - 0.505, z + 0.52), 0.14, 0.02, "foam", segments=8, bevel=False, rot=_STAND)
    for i, (sw, h) in enumerate((("pastel_lilac", 1.1), ("spa_sky", 0.85))):                      # bottles
        bx = x0 + 0.9 + 0.75 * i
        b.cyl_base((bx, y, z + 0.1), 0.3, h, sw, segments=12)
        b.cyl_base((bx, y, z + 0.1 + h - 0.02), 0.13, 0.28, "foam", segments=8, bevel=False)
    dx = x0 + 2.4                                                                                 # the duck
    b.sphere((dx, y, z + 0.42), 0.42, "fur_golden", segments=10, rings=6, scale=(1.15, 0.9, 0.75))
    b.sphere((dx + 0.22, y, z + 0.85), 0.27, "fur_golden", segments=10, rings=6)
    b.box((dx + 0.5, y, z + 0.82), (0.28, 0.2, 0.1), "fur_orange")
    for sy in (-1, 1):
        b.box((dx + 0.33, y + 0.24 * sy, z + 0.92), (0.08, 0.08, 0.1), "fur_black", bevel=False)


def _hooks(b):
    """Two towels on hooks on the right of the back wall, each with a stripe near its hem."""
    z = 7.0
    _on_back(b, 8.0, z + 0.2, 5.2, 0.3, 0.2, "caramel_wood")                                     # the hook board
    for i, (sw, st) in enumerate((("spa_sky", "foam"), ("spa_bubblegum", "foam"))):
        x = 6.6 + 2.8 * i
        _on_back(b, x, z - 0.05, 0.16, 0.3, 0.46, "gold_mid", k=1)                                # a hook
        _on_back(b, x, z - 1.6, 1.7, 2.8, 0.36, sw, k=2)                                         # the towel
        _on_back(b, x, z - 2.6, 1.72, 0.22, 0.38, st, k=3)                                       # its stripe
        _on_back(b, x, z - 0.32, 1.0, 0.3, 0.42, sw, k=4)                                        # its fold over the hook


def _bubbles(b):
    """Soap bubbles on the back wall's top corners: sky discs with a white glint."""
    for i, (x, z, r) in enumerate(((-10.8, 10.4, 0.8), (-8.9, 11.1, 0.45), (-11.6, 8.9, 0.35), (10.6, 10.2, 0.75),
                                   (8.6, 11.0, 0.5), (11.5, 8.8, 0.38), (4.6, 10.8, 0.3), (-4.4, 10.6, 0.34))):
        b.cyl((x, HALF - 0.04, z), r, 0.08 + 2 * SINK, "bubble", segments=16, bevel=False, rot=_STAND)
        b.cyl((x - 0.32 * r, HALF - 0.15, z + 0.32 * r), 0.22 * r, 0.04, "foam", segments=8, bevel=False,
              rot=_STAND)


SIDE_Y = 5.0   # the side wall pieces sit back towards the tub, so the phone frame shows them whole (Review-QA)


def _sides(b):
    """A towel rail with a lilac towel on the left wall and a round mirror on the right."""
    x, yc = -HALF, SIDE_Y                                                                         # the towel rail
    for y in (yc - 2.0, yc + 2.0):
        b.box((x + 0.25 - SINK / 2, y, 6.6), (0.5 + SINK, 0.2, 0.2), "gold_mid", bevel=False)
    b.cyl((x + 0.45, yc, 6.6), 0.1, 4.4, "gold_mid", segments=8, bevel=False, rot=_STAND)
    b.box((x + 0.45, yc, 5.3), (0.36, 3.0, 2.7), "pastel_lilac", bevel=False)
    b.box((x + 0.45, yc, 4.3), (0.38, 3.02, 0.2), "foam", bevel=False)
    x = HALF                                                                                      # the round mirror
    b.cyl((x - 0.1 + SINK / 2, yc, 7.0), 2.0, 0.2 + SINK, "spa_bubblegum", segments=24, bevel=False, rot=_SIDE)
    b.cyl((x - 0.14 + SINK / 2, yc, 7.0), 1.65, 0.24 + SINK, "glass", segments=24, bevel=False, rot=_SIDE)
    b.box((x - 0.15 + SINK / 2 + 0.01, yc - 0.5, 7.6), (0.26 + SINK, 0.3, 0.9), "foam", bevel=False,
          rot=Matrix.Rotation(math.radians(30), 3, "X"))                                         # its glint


def _floor(b):
    """A plant in each back corner, a round fluffy mat in front of the tub."""
    for sx in (1, -1):
        px, py = sx * (HALF - 1.4), HALF - 1.4
        b.cyl_base((px, py, LIFT - 0.04 - 0.004 * (sx > 0)), 0.65, 1.3, "terracotta", segments=10, bevel=False,
                   radius2=0.85)
        b.sphere((px, py, LIFT + 2.2), 1.1, "leaf_green", segments=10, rings=6)
        b.sphere((px - 0.4 * sx, py - 0.3, LIFT + 3.1), 0.8, "leaf_dark", segments=8, rings=5)
        b.sphere((px + 0.3 * sx, py - 0.6, LIFT + 1.7), 0.7, "leaf_dark", segments=8, rings=5)
    b.cyl_base((0, -5.6, LIFT - 0.02), 2.4, 0.1, "spa_bubblegum", segments=20, bevel=False)            # the mat
    b.cyl_base((0, -5.6, LIFT - 0.03), 1.7, 0.13, "fur_rose", segments=20, bevel=False)


def _lamp(b):
    """A round lamp in the ceiling over the tub."""
    b.cyl_base((0, 0, HEIGHT - 0.3), 1.6, 0.4, "pastel_butter", segments=20, bevel=False)
    b.cyl_base((0, 0, HEIGHT - 0.36), 1.25, 0.2, "lamp_warm", segments=20, bevel=False)


def build_wash_room(mat):
    b = Builder()
    _shell(b)
    main = _tris(b.finalize(NAME, mat))
    d = Builder()
    _window(d)
    _shelf(d)
    _hooks(d)
    _bubbles(d)
    _sides(d)
    _floor(d)
    _lamp(d)
    decor = _tris(d.finalize(NAME + "_Decor", mat))
    return [main, decor]


ASSETS = {NAME: (build_wash_room, 9000)}
EXTRAS = {}
