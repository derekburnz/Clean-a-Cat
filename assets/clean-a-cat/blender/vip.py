"""The VIP Room before it is built (issue #21): the first long build, the day 2 hook.

  CleanACat_Area_VipLocked    what the player sees before starting the build: a closed fancy double door in the
                              spa's back wall opening (bubblegum leaves with cream panels, round windows and gold
                              handles, a butter crown above), a sign on the door whose cream face is a `Screen` part
                              (front, -Z in Roblox) for the room's name and the timer, and behind the wall, in the
                              back yard, a sky tarp with white straps over scaffold poles, rising above the wall so
                              the room's size shows from inside the spa and from the street.
  CleanACat_Area_VipBuilding  the same door, sign and scaffold while the 8 hour build runs, with the tarp pulled back
                              to show the builder kitten's work: a wooden frame, the lower walls half up in
                              bubblegum, rafters and a stack of planks. The tarp stays on the back and one side.

Both stand at the plot's SpotVipDoor: pivot at the middle of the door opening on the floor, front -Y in Blender
(-Z in Roblox) into the spa room, the yard behind (+Y). The door blocks the opening. An invisible `_Barrier` (solid,
CanQuery off) keeps players out of the building site in the yard. The finished VIP Room is a later issue.
"""

import math

from mathutils import Matrix

from common import Builder
from stations import _tris

DOOR_W, DOOR_H = 8.0, 9.0         # the opening in the plot's back wall (plot.VIP_DOOR, plot.DOOR_H)
WALL_T = 1.0                      # the back wall's thickness: it runs from y -0.5 to 0.5 here
SITE_X = 8.4                      # the building site in the yard: x from -SITE_X to SITE_X
SITE_Y = (1.2, 12.4)              # and y, from just behind the wall to just inside the plot's back edge (13.5)
TARP_H = 13.5                     # the tarp's eaves, above the 12 stud wall
SINK = 0.02                       # every piece on the ground starts this far under the floor


def _door(b):
    """The double door in the opening, a crown over it and the sign on it."""
    w, h = DOOR_W, DOOR_H
    for sx in (1, -1):                                                              # two leaves, a gap between
        x = sx * (w / 4 - 0.01)
        b.box_base((x, 0, -SINK), (w / 2 - 0.06, 0.34, h - 0.03 + SINK), "spa_bubblegum")
        for z0, ph in ((0.7, 2.6), (4.9, 3.2)):                                     # raised panels, room side
            b.box_base((x, -0.17, z0), (w / 2 - 1.0, 0.06, ph), "spa_cream", bevel=False)
        b.cyl((x, -0.19, 3.9), 0.42, 0.06, "spa_sky", segments=10, bevel=False,
              rot=Matrix.Rotation(math.pi / 2, 3, "X"))                             # a round window
        b.box((sx * 0.35, -0.24, 4.2), (0.14, 0.2, 0.9), "gold_mid", bevel=False)   # gold handles by the gap
    # a butter frame round the opening on the wall's room face, and a crown on its header
    fy = -0.6                                                                       # 0.1 into the wall
    for sx in (1, -1):
        b.box_base((sx * (w / 2 + 0.25), fy, -SINK), (0.5, 0.3, h + 0.3 + SINK), "pastel_butter", bevel=False)
    b.box_base((0, fy - 0.01, h - 0.02), (w + 1.2, 0.32, 0.62), "pastel_butter", bevel=False)
    cz, cy = h + 0.55, fy
    b.box_base((0, cy, cz), (2.4, 0.22, 0.6), "pastel_butter")
    for i, x in enumerate((-0.9, 0.0, 0.9)):
        top = 1.0 if i == 1 else 0.75
        b.cyl_base((x, cy, cz + 0.55), 0.26, top, "pastel_butter", segments=6, radius2=0.05, bevel=False)
        b.sphere((x, cy, cz + 0.6 + top), 0.14, "spa_bubblegum" if i == 1 else "spa_mint", segments=6, rings=4)
    # the sign across both leaves: a mint frame, its Screen face is a separate object
    b.box_base((0, -0.26, 5.6), (4.6, 0.2, 2.1), "spa_mint")


def _sign_face():
    s = Builder()
    s.box_base((0, -0.385, 5.78), (4.24, 0.06, 1.74), "offwhite", bevel=False)
    return s


def _scaffold(b):
    """Metal poles at the corners and the middles of the site, with rails at three heights and two plank walks."""
    x0, x1 = -SITE_X - 0.35, SITE_X + 0.35
    y0, y1 = SITE_Y[0] - 0.2, SITE_Y[1] + 0.35
    ym = (y0 + y1) / 2
    top = TARP_H + 1.3
    for x, y in ((x0, y0), (x1, y0), (x0, y1), (x1, y1), (x0, ym), (x1, ym), (0.0, y1)):
        b.cyl_base((x, y, -SINK), 0.14, top, "metal", segments=6, bevel=False)
    for i, z in enumerate((4.6, 9.2, top - 0.4)):                                   # rails, each level a hair apart
        e = 0.006 * i
        for x in (x0, x1):
            b.box((x, (y0 + y1) / 2, z + e), (0.12, y1 - y0, 0.12), "metal", bevel=False)
        b.box((0, y1, z + 0.17 + e), (x1 - x0, 0.12, 0.12), "metal", bevel=False)
    for x in (x0, x1):                                                              # plank walks along the sides
        b.box_base((x + (-0.55 if x < 0 else 0.55), (y0 + y1) / 2, 9.32), (0.9, y1 - y0 - 0.6, 0.12), "wood_light",
                   bevel=False)                                                     # outside the poles


def _tarp(b, sides=("front", "back", "left", "right", "roof")):
    """Sky tarp walls a little inside the scaffold, white straps round them, a pitched tarp roof."""
    x0, x1 = -SITE_X, SITE_X
    y0, y1 = SITE_Y
    t = 0.1
    if "back" in sides:
        b.box_base((0, y1, -SINK), (x1 - x0, t, TARP_H + SINK), "spa_sky", bevel=False)
    if "front" in sides:                                                            # behind the wall, shows above it
        b.box_base((0, y0, 6.0), (x1 - x0 - 0.02, t, TARP_H - 6.0), "spa_sky", bevel=False)
    for side, x in (("left", x0), ("right", x1)):
        if side in sides:
            b.box_base((x, (y0 + y1) / 2, -SINK + 0.01), (t, y1 - y0 - 0.02, TARP_H + SINK - 0.02), "spa_sky",
                       bevel=False)
            for z in (3.5, 8.0, 12.0):                                              # straps
                b.box((x + (0.06 if x > 0 else -0.06), (y0 + y1) / 2, z), (0.04, y1 - y0 - 0.1, 0.3), "offwhite",
                      bevel=False)
    if "roof" in sides:
        rise = 2.2
        half = (x1 - x0) / 2
        ang = math.atan2(rise, half)
        ln = math.hypot(rise, half) + 0.15
        for sx in (1, -1):
            rot = Matrix.Rotation(sx * ang, 3, "Y")
            b.box((sx * half / 2, (y0 + y1) / 2, TARP_H + rise / 2 + 0.03 * (sx > 0)), (ln, y1 - y0 + 0.3, t),
                  "spa_sky", bevel=False, rot=rot)
        b.box((0, (y0 + y1) / 2, TARP_H + rise + 0.02), (0.5, y1 - y0 + 0.36, 0.14), "offwhite", bevel=False)


def _frame(b):
    """The builder kitten's work, about half done: posts, a ring beam, the lower walls, some rafters, planks."""
    x0, x1 = -SITE_X + 0.6, SITE_X - 0.6
    y0, y1 = SITE_Y[0] + 0.6, SITE_Y[1] - 0.6
    ph = 12.6                                                                       # over the spa's 12 stud wall
    for x in (x0, -2.6, 2.6, x1):
        for y in (y0, y1):
            b.box_base((x, y, -SINK), (0.5, 0.5, ph), "wood_light", bevel=False)
    for x in (x0, x1):
        b.box_base((x, (y0 + y1) / 2, -SINK), (0.5, 0.5, ph), "wood_light", bevel=False)
    for y in (y0, y1):                                                              # the ring beam
        b.box((0, y, ph + 0.2), (x1 - x0 + 0.6, 0.56, 0.4), "wood_light", bevel=False)
    for x in (x0, x1):
        b.box((x, (y0 + y1) / 2, ph + 0.21), (0.56, y1 - y0 - 0.02, 0.36), "wood_light", bevel=False)
    # lower walls, half up: the front and the left done to 5, the right begun
    b.box_base((0, y0 + 0.02, -SINK + 0.008), (x1 - x0 - 0.04, 0.3, 5.0), "spa_bubblegum", bevel=False)
    b.box_base((x0 + 0.02, (y0 + y1) / 2, -SINK + 0.005), (0.3, y1 - y0 - 0.6, 5.0), "spa_bubblegum", bevel=False)
    b.box_base((x1 - 0.02, y0 + 2.4, -SINK + 0.005), (0.3, 4.0, 2.5), "spa_bubblegum", bevel=False)
    for i in range(3):                                                              # three rafters over the front
        y = y0 + 0.9 + 1.6 * i
        for sx in (1, -1):
            rot = Matrix.Rotation(sx * math.atan2(2.2, (x1 - x0) / 2), 3, "Y")
            b.box((sx * (x1 - x0) / 4, y, ph + 1.5 + 0.01 * i), (math.hypot(2.2, (x1 - x0) / 2), 0.3, 0.3),
                  "wood_light", bevel=False, rot=rot)
    for i in range(4):                                                              # planks waiting in the yard
        rot = Matrix.Rotation(math.radians(4 * (i % 2)), 3, "Z")
        b.box_base((1.5, y1 - 2.2, -SINK + 0.24 * i), (5.0, 0.8, 0.25), "wood_light", bevel=False, rot=rot)


def _barrier(name, mat):
    b = Builder()
    b.box_base((0, (SITE_Y[0] + SITE_Y[1]) / 2 + 0.1, -0.05), (2 * SITE_X + 1.13, SITE_Y[1] - SITE_Y[0] + 1.23,
                                                                 TARP_H + 2.03), "metal", bevel=False)
    ob = b.finalize(name + "_Barrier", mat, bevel=0)
    ob.hide_render = True
    return ob


def build_vip_locked(mat):
    name = "CleanACat_Area_VipLocked"
    b = Builder()
    _door(b)
    _scaffold(b)
    _tarp(b)
    main = _tris(b.finalize(name, mat))
    return [main, _sign_face().finalize(name + "_Screen", mat, bevel=0), _barrier(name, mat)]


def build_vip_building(mat):
    name = "CleanACat_Area_VipBuilding"
    b = Builder()
    _door(b)
    _scaffold(b)
    _tarp(b, sides=("back", "right"))
    _frame(b)
    main = _tris(b.finalize(name, mat))
    return [main, _sign_face().finalize(name + "_Screen", mat, bevel=0), _barrier(name, mat)]


ASSETS = {"CleanACat_Area_VipLocked": (build_vip_locked, 2000),
          "CleanACat_Area_VipBuilding": (build_vip_building, 2000)}
EXTRAS = {}
