"""The street the spa plots stand on (issue #15): `CleanACat_Area_Street`.

Six plots stand side by side along the street, 44 studs apart pivot to pivot, their fronts to the street (-Y in
Blender, -Z in Roblox). The street holds everything round them: grass ground, a pavement in front of the plots with a
curb, a two lane road with white dashes, a far pavement, a row of pastel houses across the road as a backdrop, a
hedge and trees behind the plots, hedges at both ends, and invisible `_Barrier` walls (solid, CanQuery off) round the
edge so nobody walks off the world.

Pivot: slot 1's plot pivot (the middle of plot 1 on the ground). Place the street with its pivot at
SpaLayout.PIVOT_POSITION; Attachments `PlotSlot1` to `PlotSlot6` mark each plot's pivot, in the order of
SpaLayout.slotPivot (slot 1 in the middle, then one step right, one left, two right, two left, three right; right is
+X in Roblox, which is -X here). The plots themselves are placed by the game, not built in.
"""

import math

from mathutils import Matrix

from common import Builder
from stations import _tris

NAME = "CleanACat_Area_Street"
TOP = 0.5                         # pavement top, level with the plots' floor slab (plot.FLOOR)
SLOTS = 6
PAVE = 8.0                        # pavement depth in front of the plots
ROAD = 20.0
FAR = 6.0                         # far pavement
GRID0 = 0.0                       # the houses' 30 stud grid starts this far in from the street's end


def slot_x(slot, pitch=None):
    """Blender x of plot `slot`'s pivot (SpaLayout.slotPivot: Roblox +X is Blender -X)."""
    steps = slot // 2
    side = 1 if slot % 2 == 0 else -1
    return -side * steps * (PITCH if pitch is None else pitch)


def _numbers(pitch, front, back):
    """The street's measures for plots `pitch` apart pivot to pivot whose ground runs from y `front` to `back`."""
    xs = [slot_x(s, pitch) for s in range(1, SLOTS + 1)]
    y_road0 = front - PAVE - 0.6                        # past the curb
    y_road1 = y_road0 - ROAD
    return {"PITCH": pitch, "XS": xs,
            "X0": min(xs) - pitch / 2 - 8.0,            # the street's ends, a little past the outer plots
            "X1": max(xs) + pitch / 2 + 8.0,
            "FRONT": front, "BACK": back,               # the plots' front and back edges
            "Y_ROAD0": y_road0, "Y_ROAD1": y_road1, "Y_FAR": y_road1 - 0.6 - FAR}


PLOT_D = 48.0                     # plot.PLOT_D
PITCH = 44.0                      # plot pivot to plot pivot (plot.PLOT_W)
XS = X0 = X1 = FRONT = BACK = Y_ROAD0 = Y_ROAD1 = Y_FAR = None
globals().update(_numbers(PITCH, -PLOT_D / 2, PLOT_D / 2))


def _ground(b):
    w = X1 - X0 + 40
    cx = (X0 + X1) / 2
    b.box_base((cx, -20.0, -1.03), (w, BACK - Y_FAR + 70, 1.0), "leaf_green", bevel=False)      # grass, top -0.03
    # the pavements and curbs: the near pavement meets the plots' front edge
    b.box_base((cx, FRONT - PAVE / 2, -0.04), (X1 - X0, PAVE, TOP + 0.04), "paving_light", bevel=False)
    b.box_base((cx, FRONT - PAVE - 0.3, -0.05), (X1 - X0 + 0.02, 0.6, TOP + 0.13), "spa_cream", bevel=False)
    b.box_base((cx, Y_ROAD1 - 0.3, -0.05), (X1 - X0 + 0.02, 0.6, TOP + 0.13), "spa_cream", bevel=False)
    b.box_base((cx, Y_ROAD1 - 0.6 - FAR / 2, -0.04), (X1 - X0, FAR, TOP + 0.04), "paving_light", bevel=False)
    b.box_base((cx, (Y_ROAD0 + Y_ROAD1) / 2, -0.06), (X1 - X0 + 0.04, ROAD + 0.02, 0.28), "concrete_dark",
               bevel=False)                                                                    # the road, top 0.22
    # the paving beyond the outer plots, so the near pavement's back edge is never open grass by a plot
    for x in (min(XS) - PITCH / 2 - 4.0, max(XS) + PITCH / 2 + 4.0):
        b.box_base((x, (FRONT + BACK) / 2, -0.04), (8.0, BACK - FRONT, TOP + 0.04), "paving_light", bevel=False)


def _dashes(b):
    y = (Y_ROAD0 + Y_ROAD1) / 2
    n = int((X1 - X0) // 12)
    for i in range(n):
        x = X0 + 6.0 + 12.0 * i
        b.box_base((x, y, 0.21), (6.0, 0.5, 0.03), "offwhite", bevel=False)


HOUSE_COLOURS = ("spa_sky", "pastel_butter", "spa_mint", "pastel_lilac", "spa_bubblegum", "spa_cream")


ROOFS = ("blush", "terracotta", "fur_slate", "nose_brick")
AWNINGS = ("spa_bubblegum", "spa_mint", "spa_sky", "pastel_butter")


def _window(b, x, fy, z, w=3.6, h=3.2, box=True):
    """A framed window on a house front (the front faces +Y): glass, a cream frame, a sill and a flower box."""
    b.box_base((x, fy, z), (w, 0.3, h), "glass", bevel=False)
    b.box_base((x, fy - 0.03, z + h - 0.02), (w + 0.5, 0.36, 0.3), "spa_cream", bevel=False)            # the head
    b.box_base((x, fy + 0.07, z - 0.3), (w + 0.7, 0.5, 0.3), "spa_cream", bevel=False)                  # the sill
    if box:
        b.box_base((x, fy + 0.42, z - 0.28), (w - 0.2, 0.5, 0.5), "wood_light", bevel=False)            # the flower box
        for i, sw in enumerate(("spa_bubblegum", "pastel_butter", "spa_bubblegum")):
            b.sphere((x + (i - 1) * (w - 1.2) / 2, fy + 0.42, z + 0.38), 0.36, sw, segments=6, rings=4)


def _door(b, x, fy, colour, awning):
    """A front door with a step, a cream frame, a knob and a little awning over it."""
    b.box_base((x, fy + 0.35, -0.02), (4.4, 1.3, TOP + 0.3), "paving_light", bevel=False)               # the step
    b.box_base((x, fy, TOP), (3.0, 0.3, 5.6), colour, bevel=False)
    b.box_base((x, fy - 0.04, TOP + 5.58), (3.6, 0.34, 0.34), "spa_cream", bevel=False)
    b.sphere((x + 1.0, fy + 0.2, TOP + 2.7), 0.18, "fur_golden", segments=6, rings=4)
    b.wedge((x, fy + 0.85, TOP + 6.5), (4.6, 1.8, 0.9), awning, bevel=False, rot=(math.radians(180), "Z"))


def _gable(b, x, y, w, d, h, roof, front):
    """A gable roof on a house whose top is at h: two wedges. `front` True turns the gable to the street (the ridge
    runs front to back), else the ridge runs along the street."""
    if front:
        rise = 0.36 * w
        for s in (1, -1):
            b.wedge((x + s * (w / 4 + 0.25), y, h + rise / 2), (d + 1.4, w / 2 + 0.5, rise), roof, bevel=False,
                    rot=(math.radians(90 * s), "Z"))
        return rise
    rise = 0.4 * d
    for s in (1, -1):
        b.wedge((x, y + s * (d / 4 + 0.3), h + rise / 2), (w + 1.6, d / 2 + 0.6, rise), roof, bevel=False,
                rot=(math.radians(0 if s < 0 else 180), "Z"))
    return rise


def _houses(b):
    """Pastel town houses across the road (#349: the first draft was nine flat roofed boxes). Three kinds take
    turns: a cottage with its ridge along the street, a shop with a flat roof and a striped awning, and a tall
    house with its gable to the street. Each has a door with a step and a little awning, framed windows with flower
    boxes and a cream band at its foot. No writing anywhere."""
    y = Y_FAR - 9.0
    n = int((X1 - X0) // 30)
    for i in range(n):
        x = X0 + GRID0 + 15.0 + 30.0 * i
        kind = i % 3
        w, d = 22.0, 14.0
        h = (9.0, 10.5, 13.0)[kind] + (i % 2)
        wall = HOUSE_COLOURS[i % len(HOUSE_COLOURS)]
        roof, awning = ROOFS[i % len(ROOFS)], AWNINGS[(i + 1) % len(AWNINGS)]
        fy = y + d / 2 + 0.1                                    # the side that faces the street (+Y here)
        b.box_base((x, y, -0.05), (w, d, h + 0.05), wall, bevel=False)
        b.box_base((x, y, -0.04), (w + 0.4, d + 0.4, 1.0), "spa_cream", bevel=False)                    # the foot band
        if kind == 0:                                           # the cottage
            rise = _gable(b, x, y, w, d, h, roof, front=False)
            b.box_base((x + 6.0, y - 1.5, h + rise * 0.25), (1.8, 1.8, rise * 0.95), "nose_brick", bevel=False)
            b.box_base((x + 6.0, y - 1.5, h + rise * 1.2 - 0.02), (2.2, 2.2, 0.4), "spa_cream", bevel=False)
            _door(b, x, fy, "wood_light", awning)
            for wx in (-6.5, 6.5):
                _window(b, x + wx, fy, 3.6)
        elif kind == 1:                                         # the shop
            b.box_base((x, y + 0.01, h - 0.02), (w + 1.0, d + 1.0, 1.0), "spa_cream", bevel=False)     # the cornice
            _door(b, x - 6.5, fy, "wood_light", awning)
            b.box_base((x + 3.0, fy, 2.2), (11.0, 0.3, 4.6), "glass", bevel=False)                     # the shop window
            b.box_base((x + 3.0, fy + 0.07, 1.9), (11.6, 0.5, 0.32), "spa_cream", bevel=False)
            n_stripes = 6
            for k in range(n_stripes):                          # a striped awning over it
                sx = x + 3.0 - 6.0 + 12.0 * (k + 0.5) / n_stripes
                b.wedge((sx, fy + 1.3, 7.7), (12.0 / n_stripes - 0.004, 2.8, 1.3), awning if k % 2 == 0 else "spa_cream",
                        bevel=False, rot=(math.radians(180), "Z"))
            for wx in (-6.5, 3.0):
                _window(b, x + wx, fy, h - 3.4, w=3.2, h=2.2, box=False)
        else:                                                   # the tall house
            _gable(b, x, y, w, d, h, roof, front=True)
            _door(b, x, fy, "wood_light", awning)
            for wx in (-6.5, 6.5):
                _window(b, x + wx, fy, 3.2)
                _window(b, x + wx, fy, 8.6, h=2.8, box=False)
            b.cyl((x, fy + 0.66, h + 2.3), 1.3, 0.3, "glass", segments=10, bevel=False, rot=(math.radians(90), "X"))   # in the gable, which stands 0.7 proud


def _far_pavement(b):
    """What stands on the far pavement and between the houses: a hedge and a round tree in each gap, street lamps,
    a bench, a post box and a hydrant. None of it carries writing."""
    n = int((X1 - X0) // 30)
    yh = Y_FAR - 4.0
    for i in range(n + 1):                                      # the gaps between the houses
        x = X0 + GRID0 + 30.0 * i
        if 0 < i < n:
            b.box_base((x, yh, -0.05), (7.4, 1.6, 2.4), "leaf_dark", bevel=False)
        h = 6.0 + 1.5 * (i % 3)
        b.cyl_base((x, yh - 5.0, -0.05), 0.7, h, "wood_light", segments=6, bevel=False)
        b.sphere((x, yh - 5.0, h + 2.4), 3.6, ("leaf_green", "leaf_dark", "spa_mint")[i % 3], segments=8, rings=5)
    yl = Y_ROAD1 - 2.0
    for i in range(n):                                          # a lamp in front of every house's corner
        x = X0 + GRID0 + 4.0 + 30.0 * i
        b.cyl_base((x, yl, TOP - 0.02), 0.5, 0.5, "fur_slate", segments=8, bevel=False)
        b.cyl_base((x, yl, TOP + 0.4), 0.2, 9.0, "fur_slate", segments=6, bevel=False)
        b.box_base((x, yl + 0.7, TOP + 9.2), (0.5, 1.9, 0.3), "fur_slate", bevel=False)
        b.box_base((x, yl + 1.3, TOP + 8.55), (0.9, 0.9, 0.66), "lamp_warm", bevel=False)
    for i in range(1, n, 3):                                    # a bench by every third house
        x = X0 + GRID0 + 15.0 + 30.0 * i + 8.5
        yb = Y_FAR + 1.2
        b.box_base((x, yb, TOP + 1.2), (4.6, 1.3, 0.24), "wood_light", bevel=False)
        b.box_base((x, yb - 0.6, TOP + 1.42), (4.6, 0.24, 1.3), "wood_light", bevel=False)
        for sx in (-1.9, 1.9):
            b.box_base((x + sx, yb, TOP - 0.02), (0.3, 1.1, 1.24), "fur_slate", bevel=False)
    for i in range(0, n, 3):                                    # a post box and a hydrant, turn about
        x = X0 + GRID0 + 15.0 + 30.0 * i - 9.0
        b.box_base((x, Y_FAR + 1.0, TOP - 0.02), (1.2, 1.2, 3.2), "nose_brick", bevel=False)
        b.box_base((x, Y_FAR + 1.0, TOP + 3.16), (1.5, 1.5, 0.4), "spa_cream", bevel=False)
        xh = x + 21.0
        b.cyl_base((xh, Y_ROAD1 - 1.4, TOP - 0.02), 0.45, 1.5, "bowl_red", segments=8, bevel=False)
        b.sphere((xh, Y_ROAD1 - 1.4, TOP + 1.5), 0.45, "bowl_red", segments=6, rings=4)


def _greenery(b):
    """A hedge behind the plots and beside the outer plots, and round trees behind the hedge."""
    cx = (X0 + X1) / 2
    b.box_base((cx, BACK + 2.0, -0.05), (X1 - X0, 3.0, 4.0), "leaf_dark", bevel=False)
    for x in (X0 - 1.5, X1 + 1.5):                 # beside the outer plots only: the road runs on past the street's
        b.box_base((x, (FRONT + BACK) / 2 + 2.0, -0.06), (3.0, BACK - FRONT + 4.0, 4.02), "leaf_dark", bevel=False)   # ends (#349)
    n = int((X1 - X0) // 24)
    for i in range(n):
        x = X0 + 12.0 + 24.0 * i
        y = BACK + 9.0 + 3.0 * (i % 2)
        h = 7.0 + 1.5 * (i % 3)
        b.cyl_base((x, y, -0.05), 0.9, h, "wood_light", segments=8, bevel=False)
        b.sphere((x, y, h + 3.0), 4.5, "leaf_green" if i % 2 else "leaf_dark", segments=10, rings=7)


def _barrier(name, mat):
    """Invisible walls round the street: both ends, behind the trees and in front of the houses."""
    b = Builder()
    H = 40.0
    yb0, yb1 = Y_FAR - 2.45, BACK + 18.0               # its face a hair off the house fronts, not in their plane
    for x in (X0 - 3.5, X1 + 3.5):
        b.box_base((x, (yb0 + yb1) / 2, -0.1), (1.0, yb1 - yb0 + 1.0, H), "metal", bevel=False)
    for y in (yb0, yb1):
        b.box_base(((X0 + X1) / 2, y, -0.1), (X1 - X0 + 6.0, 1.0, H - 0.02), "metal", bevel=False)
    ob = b.finalize(name + "_Barrier", mat, bevel=0)
    ob.hide_render = True
    return ob


def build_street(mat):
    name = NAME
    objs = []
    for suffix, fn in (("", _ground), ("_Dashes", _dashes), ("_Houses", _houses), ("_Greenery", _greenery),
                       ("_Pavement", _far_pavement)):
        b = Builder()
        fn(b)
        objs.append(_tris(b.finalize(name + suffix, mat, bevel=0)))
    objs.append(_barrier(name, mat))
    return objs


def street_rbx_extras():
    atts = [(NAME, f"PlotSlot{s}", Matrix.Translation((slot_x(s), 0.0, 0.0)))
            for s in range(1, SLOTS + 1)]
    return {"attachments": atts, "attributes": {"PlotSpacing": {"Float64": PITCH}, "PlotCount": {"Float64": SLOTS}}}


# -- the street for the bigger plots (#746) ------------------------------------------------------------------------------
# CleanACat_Area_SpaPlotBig is 56 studs wide and its ground runs 6 studs further back, so six of them need a longer,
# deeper street: `CleanACat_Area_StreetBig`, the same street at a 56 stud pitch. Its front edge, pavement, road and
# houses stand where the small street's do; the hedge, the trees and the wall behind the plots stand 6 studs further
# back. Eleven houses instead of nine, set in 11 studs so the row is centred. The pivot is still slot 1's plot pivot,
# no turn, and PlotSlot1 to PlotSlot6 and PlotSpacing (56) say where the plots go.
BIG_NAME = "CleanACat_Area_StreetBig"
BIG_PITCH, BIG_FRONT, BIG_BACK = 56.0, -24.0, 30.0     # plot.BIG's PLOT_X width and PLOT_Y
BIG = dict(_numbers(BIG_PITCH, BIG_FRONT, BIG_BACK), NAME=BIG_NAME, GRID0=11.0)


class big_layout:
    """`with big_layout():` builds with the bigger street's numbers (plot.big_layout does the same for the plot)."""

    def __enter__(self):
        self.old = {k: globals()[k] for k in BIG}
        globals().update(BIG)

    def __exit__(self, *exc):
        globals().update(self.old)


def build_street_big(mat):
    with big_layout():
        return build_street(mat)


def street_big_rbx_extras():
    with big_layout():
        return street_rbx_extras()


ASSETS = {"CleanACat_Area_Street": (build_street, 20000), BIG_NAME: (build_street_big, 24000)}
EXTRAS = {"CleanACat_Area_Street": street_rbx_extras, BIG_NAME: street_big_rbx_extras}
