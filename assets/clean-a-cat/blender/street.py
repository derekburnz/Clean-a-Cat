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

from mathutils import Matrix

from common import Builder
from stations import _tris

PITCH = 44.0                      # plot pivot to plot pivot (plot.PLOT_W)
PLOT_D = 48.0                     # plot.PLOT_D
TOP = 0.5                         # pavement top, level with the plots' floor slab (plot.FLOOR)
SLOTS = 6


def slot_x(slot):
    """Blender x of plot `slot`'s pivot (SpaLayout.slotPivot: Roblox +X is Blender -X)."""
    steps = slot // 2
    side = 1 if slot % 2 == 0 else -1
    return -side * steps * PITCH


XS = [slot_x(s) for s in range(1, SLOTS + 1)]
X0 = min(XS) - PITCH / 2 - 8.0    # the street's ends, a little past the outer plots
X1 = max(XS) + PITCH / 2 + 8.0
FRONT = -PLOT_D / 2               # the plots' front edge
PAVE = 8.0                        # pavement depth in front of the plots
ROAD = 20.0
FAR = 6.0                         # far pavement
Y_ROAD0 = FRONT - PAVE - 0.6      # past the curb
Y_ROAD1 = Y_ROAD0 - ROAD
Y_FAR = Y_ROAD1 - 0.6 - FAR
BACK = PLOT_D / 2


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
        b.box_base((x, 0.0, -0.04), (8.0, PLOT_D, TOP + 0.04), "paving_light", bevel=False)


def _dashes(b):
    y = (Y_ROAD0 + Y_ROAD1) / 2
    n = int((X1 - X0) // 12)
    for i in range(n):
        x = X0 + 6.0 + 12.0 * i
        b.box_base((x, y, 0.21), (6.0, 0.5, 0.03), "offwhite", bevel=False)


HOUSE_COLOURS = ("spa_sky", "pastel_butter", "spa_mint", "pastel_lilac", "spa_bubblegum", "spa_cream")


def _houses(b):
    """Pastel town houses across the road, flat roofed with a cream cornice, each with a door and two windows on
    the side that faces the street."""
    y = Y_FAR - 9.0
    n = int((X1 - X0) // 30)
    for i in range(n):
        x = X0 + 15.0 + 30.0 * i
        w, d, h = 22.0, 14.0, 10.0 + 1.5 * (i % 3)
        b.box_base((x, y, -0.05), (w, d, h + 0.05), HOUSE_COLOURS[i % len(HOUSE_COLOURS)], bevel=False)
        b.box_base((x, y + 0.01, h - 0.02), (w + 1.0, d + 1.0, 1.0), "spa_cream", bevel=False)     # the cornice
        fy = y + d / 2 + 0.1                                    # the side that faces the street (+Y here)
        b.box_base((x, fy, -0.02), (3.2, 0.3, 6.0), "wood_light", bevel=False)
        for wx in (-6.0, 6.0):
            b.box_base((x + wx, fy, 4.5), (4.0, 0.3, 3.5), "glass", bevel=False)


def _greenery(b):
    """A hedge behind the plots and at both ends, and round trees behind the hedge."""
    cx = (X0 + X1) / 2
    b.box_base((cx, BACK + 2.0, -0.05), (X1 - X0, 3.0, 4.0), "leaf_dark", bevel=False)
    for x in (X0 - 1.5, X1 + 1.5):
        b.box_base((x, (Y_FAR + BACK) / 2 + 1.0, -0.06), (3.0, BACK - Y_FAR + 6.0, 4.02), "leaf_dark", bevel=False)
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
    name = "CleanACat_Area_Street"
    objs = []
    for suffix, fn in (("", _ground), ("_Dashes", _dashes), ("_Houses", _houses), ("_Greenery", _greenery)):
        b = Builder()
        fn(b)
        objs.append(_tris(b.finalize(name + suffix, mat, bevel=0)))
    objs.append(_barrier(name, mat))
    return objs


def street_rbx_extras():
    atts = [("CleanACat_Area_Street", f"PlotSlot{s}", Matrix.Translation((slot_x(s), 0.0, 0.0)))
            for s in range(1, SLOTS + 1)]
    return {"attachments": atts, "attributes": {"PlotSpacing": {"Float64": PITCH}, "PlotCount": {"Float64": SLOTS}}}


ASSETS = {"CleanACat_Area_Street": (build_street, 20000)}
EXTRAS = {"CleanACat_Area_Street": street_rbx_extras}
