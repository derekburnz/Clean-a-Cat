"""The workers' wash stands (#527, for #509): one station for each worker, so a worker and their station arrive
together. A draft: no rules in the models.

The owner on the plan page, 2026-11-25: "Maybe make it so the worker comes with the station." One purchase gives the
worker and their own station, and the player keeps their own tub. So a wash stand must never be taken for the
player's bath: it is a round basin on a cream pedestal, smaller and plainer than the claw-foot tub and the pink
bubble bath, and its colour is one neither bath has.

  CleanACat_Station_WashStand<Name>     Jo, Sam and Lou. 4 studs wide and under 5 deep, so three stand side by side
                                        on the 12 studs of back wall between the plot's two doors (Review-QA after
                                        #577); pivot on the floor at the middle, front -Y here (-Z in Roblox).
      ..._Water, ..._Foam               the deep blue water (solid, as in the baths) and the lather on it
      ..._Decor                         what a player must never snag on, walk-through in the game: the head of Jo's
                                        shower up at head height, and the leaves and flowers of Lou's plant
      ..._Barrier                       Sam's only: an invisible solid box in the shelf, whose boards are too thin to
                                        collide. The basin and Lou's pot are solid; Jo's thin pole is walk-through
  Attachments: `CatSeat` in the basin (a sitting cat at the attribute `CatScale`, 1.5, faces the front) and
  `WorkerSpot` on the floor mat right of the basin, turned so a worker pivoted to it faces the cat.
  Attributes: `Worker` (the staff model's `Look`: Jo, Sam or Lou), `SeatHeight`, `CatScale`.

The three differ by shape as well as colour, so a player can tell whose stand is whose from across the spa:
  Jo    peach basin, a pink heart, a brass standing shower behind it
  Sam   mint basin, a blue drop, a shelf of bottles, towels and a rubber duck
  Lou   butter basin, an orange flower, a tall plant in a butter pot
The tall piece stands in the back corner away from the worker, where the worker never hides it and it shows
beside or over the cat from the front. No lilac
and no gold: those mean a special customer or a top tier. The worker stands at the side, not behind the cat, so the
cat's face and the progress bar over it (#528) stay clear.
"""

import math

from mathutils import Matrix, Vector

import common
from common import Builder
from stations import STATION_CAT_SCALE, _barrier, _tris, foam_bubble, foam_mound, water_shine

PREFIX = "CleanACat_Station_WashStand"
SEAT = 1.2                        # the CatSeat: lower than the tub's 1.5, so a worker's hands come down onto the cat
WATER = SEAT + 0.27               # as far up the cat as in the tub (dirt.TUB_WATER at the 1.5 scale)
RIM = WATER + 0.06                # the water stands just under the rim, as in both baths
FLOOR = RIM - 0.21                # top of the solid bowl
HALF_W = 2.0                      # nothing reaches further than this to either side
BX, BY = -0.5, -0.7               # the basin's centre: its left edge on the stand's left edge
R = 1.5                           # the basin's outer radius at the rim
WALL = 0.3
N = 12                            # blocks in the rim, and the bowl's sides
WX, WY = 1.5, BY                  # where the worker stands, beside the cat
TALL = (-1.7, 1.75)               # where the tall piece stands: the back corner away from the worker
HEAD_TIP = 32.0                   # how far Jo's shower head tips towards the cat, degrees
TAP_DEG = 125.0                   # the tap, on the back rim behind the cat's right ear
FRONT = Matrix.Rotation(math.pi / 2, 3, "X")       # stands a disc up to face the front
TURN = Matrix.Rotation(math.radians(15), 3, "Z")   # a flat side of the twelve sided bowl faces the front

LOOKS = {
    "Jo": dict(bowl="fur_peach", emblem="heart", tall="shower", tap=False),
    "Sam": dict(bowl="spa_mint", emblem="drop", tall="shelf", tap=True),
    "Lou": dict(bowl="pastel_butter", emblem="flower", tall="plant", tap=True),
}


def _rim_at(deg, r):
    t = math.radians(deg)
    return BX + math.cos(t) * r, BY + math.sin(t) * r, t


def _basin(b, sw):
    """A cream plinth and stem, a brass band, the bowl in the worker's colour and a cream rolled rim of blocks.
    Neighbouring rim blocks differ a hair in height so their crossing corners share no plane."""
    b.cyl((BX, BY, 0.1), 1.3, 0.2, "spa_cream", segments=N, bevel=False, rot=TURN)
    b.cyl((BX, BY, 0.43), 1.05, 0.5, "spa_cream", segments=N, bevel=False, rot=TURN)
    b.cyl((BX, BY, 0.66), 1.13, 0.12, "brass", segments=N, bevel=False, rot=TURN)
    z0 = 0.69
    b.cyl((BX, BY, (z0 + FLOOR) / 2), R - 0.05, FLOOR - z0, sw, segments=N, bevel=False, rot=TURN)
    r = R - 0.03 - WALL / 2
    w = 2 * (R - 0.03) * math.tan(math.pi / N) + 0.03
    for i in range(N):
        x, y, t = _rim_at(360.0 * i / N, r)
        b.box_base((x, y, FLOOR - 0.03 - 0.003 * (i % 2)), (WALL + 0.06, w, RIM - FLOOR + 0.03 + 0.007 * (i % 2)),
                   "spa_cream", rot=Matrix.Rotation(t, 3, "Z"))


def _emblem(b, kind):
    """The worker's mark on the bowl's front: a white badge with a heart, a drop or a flower on it."""
    y = BY - (R - 0.05) * math.cos(math.pi / N)        # the bowl's flat front face
    z = (0.69 + FLOOR) / 2 + 0.01
    b.cyl((BX, y - 0.005, z), 0.27, 0.05, "offwhite", segments=N, bevel=False, rot=FRONT)
    y -= 0.03

    def disc(dx, dz, r, sw, k=0):
        b.cyl((BX + dx, y - 0.01 * k, z + dz), r, 0.05 + 0.006 * k, sw, segments=10, bevel=False, rot=FRONT)

    if kind == "heart":
        disc(-0.085, 0.055, 0.1, "nose_bubblegum")
        disc(0.085, 0.055, 0.1, "nose_bubblegum", 1)
        b.box((BX, y - 0.006, z - 0.035), (0.178, 0.07, 0.178), "nose_bubblegum", bevel=False,
              rot=Matrix.Rotation(math.pi / 4, 3, "Y"))
    elif kind == "drop":
        disc(0.0, -0.045, 0.125, "water")
        b.box((BX, y - 0.006, z + 0.045), (0.165, 0.07, 0.165), "water", bevel=False,
              rot=Matrix.Rotation(math.pi / 4, 3, "Y"))
    else:
        for j in range(5):
            t = math.pi / 2 + 2 * math.pi * j / 5
            disc(math.cos(t) * 0.115, math.sin(t) * 0.115, 0.078, "fur_marmalade", j % 3)
        disc(0.0, 0.0, 0.07, "pastel_butter", 3)


def _tap(b):
    """A small brass tap on the back rim, its mouth in over the water, with a pink and a sky knob."""
    x, y, t = _rim_at(TAP_DEG, R - 0.03 - WALL / 2)
    ix, iy = -math.cos(t), -math.sin(t)                # in towards the middle
    b.cyl_base((x, y, RIM - 0.02), 0.16, 0.08, "brass", segments=8, bevel=False)
    b.cyl_base((x, y, RIM + 0.03), 0.075, 0.62, "brass", segments=8, bevel=False)
    top = RIM + 0.62
    b.cyl((x + ix * 0.2, y + iy * 0.2, top), 0.075, 0.56, "brass", segments=8, bevel=False,
          rot=Matrix.Rotation(t, 3, "Z") @ Matrix.Rotation(math.pi / 2, 3, "Y"))
    b.cyl((x + ix * 0.4, y + iy * 0.4, top - 0.1), 0.1, 0.16, "brass", segments=8, bevel=False)
    for sgn, sw in ((1, "spa_bubblegum"), (-1, "spa_sky")):
        b.sphere((x - sgn * iy * 0.3, y + sgn * ix * 0.3, RIM + 0.09), 0.11, sw, segments=8, rings=4)


def _mat_pad(b, sw):
    """The worker's floor mat: it marks their place while they are away fetching a cat."""
    b.box_base((WX, WY, 0), (1.0, 1.7, 0.05), "spa_cream")
    b.box_base((WX, WY, 0.012), (0.78, 1.46, 0.07), sw)


def _shower(b, top_b, sw):
    """Jo's: a brass standing shower behind the basin, its head turned in over the water. The pole is solid; the ball
    on top, the arm and the head go to `top_b` (the walk-through `_Decor`), up where a jumping player's head is."""
    x, y = TALL
    dx, dy = BX - x, BY - y
    n = math.hypot(dx, dy)
    dx, dy = dx / n, dy / n
    top = 4.45
    b.cyl_base((x, y, 0), 0.3, 0.12, "spa_cream", segments=10, bevel=False)
    b.cyl_base((x, y, 0.06), 0.12, top - 0.06, "brass", segments=8, bevel=False)
    top_b.sphere((x, y, top), 0.2, "brass", segments=8, rings=4)
    turn = Matrix.Rotation(math.atan2(dy, dx), 3, "Z")
    top_b.cyl((x + dx * 0.6, y + dy * 0.6, top), 0.1, 1.2, "brass", segments=8, bevel=False,
              rot=turn @ Matrix.Rotation(math.pi / 2, 3, "Y"))
    # the head: a wide rain shower tipped towards the cat, so its cream face with blue nozzles shows from the front
    tip = turn @ Matrix.Rotation(math.radians(-HEAD_TIP), 3, "Y")
    hx, hy, hz = x + dx * 1.3, y + dy * 1.3, top - 0.08
    down = tip @ Vector((0.0, 0.0, -1.0))
    top_b.cyl((hx, hy, hz), 0.62, 0.22, sw, segments=12, bevel=False, rot=tip)
    top_b.cyl((hx + down.x * 0.13, hy + down.y * 0.13, hz + down.z * 0.13), 0.5, 0.08, "spa_cream", segments=12,
              bevel=False, rot=tip)
    for k, (u, v) in enumerate(((0.0, 0.0), (0.26, 0.0), (-0.26, 0.0), (0.0, 0.26), (0.0, -0.26))):
        c = Vector((hx, hy, hz)) + down * 0.165 + tip @ Vector((u, v, 0.0))
        top_b.cyl(tuple(c), 0.07, 0.04 + 0.004 * k, "water", segments=6, bevel=False, rot=tip)
    b.sphere((x, y, 1.75), 0.13, "spa_bubblegum", segments=8, rings=4)       # the hot and cold knobs, on the pole
    b.sphere((x, y, 2.1), 0.13, "spa_sky", segments=8, rings=4)


SHELF = (1.2, 0.6, 3.6)                                  # the shelf's width, depth and height
SHELF_AT = (-HALF_W + (SHELF[0] + 0.1) / 2, TALL[1] + 0.3)


def _shelf(b, _top_b, sw):
    """Sam's: a cream shelf with the worker's colour behind it, holding bottles, rolled towels and a rubber duck."""
    w, d, h = SHELF
    x, y = SHELF_AT
    for sx in (-1, 1):
        b.box_base((x + sx * (w / 2 - 0.05), y, 0), (0.1, d, h + 0.004 * (sx > 0)), "spa_cream")
    b.box_base((x, y + d / 2 - 0.07, 0.02), (w - 0.12, 0.08, h - 0.05), sw, bevel=False)
    levels = (1.75, 2.65)
    for k, z in enumerate(levels):
        b.box_base((x, y - 0.02, z), (w - 0.1 - 0.01 * k, d - 0.1, 0.1), "wood_light", bevel=False)
    b.box_base((x, y - 0.01, h - 0.02), (w + 0.1, d + 0.08, 0.12), "spa_cream")
    z = levels[0] + 0.1
    b.cyl_base((x - 0.31, y - 0.05, z - 0.01), 0.15, 0.52, "spa_sky", segments=8)             # shampoo
    b.cyl_base((x - 0.31, y - 0.05, z + 0.5), 0.07, 0.13, "spa_cream", segments=6, bevel=False)
    b.cyl_base((x - 0.02, y - 0.05, z - 0.01), 0.13, 0.4, "spa_bubblegum", segments=8)         # conditioner
    b.cyl_base((x - 0.02, y - 0.05, z + 0.38), 0.06, 0.11, "spa_cream", segments=6, bevel=False)
    b.cyl_base((x + 0.3, y - 0.05, z - 0.01), 0.17, 0.3, "pastel_butter", segments=8)         # a jar
    b.cyl_base((x + 0.3, y - 0.05, z + 0.28), 0.185, 0.07, "wood_light", segments=8, bevel=False)
    z = levels[1] + 0.1
    lie = Matrix.Rotation(math.pi / 2, 3, "X")                                                # rolled towels
    for k, (dx, dz, tw) in enumerate(((-0.26, 0.16, "spa_cream"), (0.08, 0.16, "spa_sky"), (-0.09, 0.4, "spa_bubblegum"))):
        b.cyl((x + dx, y - 0.04 - 0.012 * k, z + dz - 0.005), 0.17, 0.44 - 0.01 * k, tw, segments=8, bevel=False,
              rot=lie)
    z = h + 0.1                                                                               # the duck, on top
    b.sphere((x - 0.05, y - 0.05, z + 0.15), 0.2, "pastel_butter", segments=8, rings=5, scale=(1.15, 1.0, 0.85))
    b.sphere((x + 0.1, y - 0.1, z + 0.38), 0.14, "pastel_butter", segments=8, rings=5)
    b.box((x + 0.23, y - 0.16, z + 0.36), (0.12, 0.1, 0.05), "fur_marmalade", bevel=False,
          rot=Matrix.Rotation(math.radians(-25), 3, "Z"))


def _plant(b, top_b, sw):
    """Lou's: a tall leafy plant in a pot of the worker's colour, with three pink flowers. The pot and the stem are
    solid; the leaves and flowers go to `top_b` (the walk-through `_Decor`), so nobody snags on them."""
    x, y = -HALF_W + 0.8, TALL[1]
    b.cyl_base((x, y, 0), 0.4, 0.78, sw, segments=10, bevel=False, radius2=0.5)
    b.cyl_base((x, y, 0.72), 0.55, 0.14, "spa_cream", segments=10, bevel=False)
    b.cyl_base((x, y, 0.8), 0.44, 0.09, "dark_wood", segments=10, bevel=False)
    up = 0.5                                             # the leaves start above the cat's ears, so they show over it
    b.cyl_base((x, y, 0.85), 0.08, 2.2 + up, "leaf_dark", segments=6, bevel=False)
    for dx, dy, z, r, lw in ((0.0, 0.0, 3.35, 0.6, "leaf_green"), (-0.36, 0.1, 2.9, 0.42, "leaf_dark"),
                             (0.38, 0.0, 2.98, 0.4, "leaf_dark"), (0.04, -0.2, 3.88, 0.4, "leaf_green"),
                             (0.02, -0.38, 2.78, 0.34, "leaf_green")):
        top_b.sphere((x + dx, y + dy, z + up), r, lw, segments=8, rings=5)
    for dx, dy, z in ((-0.28, -0.42, 3.42), (0.34, -0.36, 3.22), (0.02, -0.52, 3.96)):
        top_b.sphere((x + dx, y + dy, z + up), 0.14, "spa_bubblegum", segments=8, rings=4)


TALLS = {"shower": _shower, "shelf": _shelf, "plant": _plant}
# lather on the water round the cat, as (degrees round the basin, distance from its middle, size)
MOUNDS = [(205, 0.86, 0.34), (-25, 0.86, 0.32), (62, 0.84, 0.3), (270, 0.92, 0.27)]
BALLS = [(228, 0.9, 0.15), (-48, 0.92, 0.14), (40, 0.92, 0.13), (180, 0.95, 0.12)]


def _water():
    b = Builder()
    z = FLOOR + 0.004
    b.cyl((BX, BY, (z + WATER) / 2), R - WALL - 0.04, WATER - z, "water", segments=16, bevel=False)
    water_shine(b, WATER, [(BX - 0.25, BY - 0.98, 0.5, 0), (BX + 0.5, BY - 0.86, 0.26, 20),
                           (BX - 0.95, BY + 0.3, 0.3, 90)])
    return b


def _foam():
    b = Builder()
    for deg, d, r in MOUNDS:
        x, y, _t = _rim_at(deg, d)
        foam_mound(b, x, y, WATER, r)
    for deg, d, r in BALLS:
        x, y, _t = _rim_at(deg, d)
        foam_bubble(b, x, y, WATER - 0.03, r)
    return b


def build_stand(who, mat):
    name = PREFIX + who
    look = LOOKS[who]
    b = Builder()
    _basin(b, look["bowl"])
    _emblem(b, look["emblem"])
    if look["tap"]:
        _tap(b)
    _mat_pad(b, look["bowl"])
    top_b = Builder()
    TALLS[look["tall"]](b, top_b, look["bowl"])
    objs = [_tris(b.finalize(name, mat)),
            _tris(_water().finalize(name + "_Water", mat, bevel=0)),
            common.shade_smooth(_foam().finalize(name + "_Foam", mat))]
    if top_b.bm.verts:
        objs.append(_tris(top_b.finalize(name + "_Decor", mat)))
    if look["tall"] == "shelf":            # its boards are too thin to collide, so an invisible box keeps players out
        objs.append(_barrier(name, mat, (SHELF[0] - 0.04, SHELF[1] - 0.04, SHELF[2] - 0.1), (*SHELF_AT, 0.03)))
    return objs


def stand_rbx_extras(who):
    name = PREFIX + who
    spot = Matrix.Translation((WX, WY, 0.0)) @ Matrix.Rotation(-math.pi / 2, 4, "Z")     # a worker's front to the cat
    return lambda: {"attachments": [(name, "CatSeat", Matrix.Translation((BX, BY, SEAT))),
                                    (name, "WorkerSpot", spot)],
                    "attributes": {"Worker": {"String": who}, "SeatHeight": {"Float64": SEAT},
                                   "CatScale": {"Float64": STATION_CAT_SCALE}}}


# The other stations keep 1,200 triangles. Here the balls of lather, the knobs and the leaves are Ball parts in the
# game, which the engine draws itself, so their triangles are only the preview mesh (as on the two baths).
BUDGET = 2500
ASSETS = {PREFIX + who: (lambda mat, who=who: build_stand(who, mat), BUDGET) for who in LOOKS}
EXTRAS = {PREFIX + who: stand_rbx_extras(who) for who in LOOKS}
