"""The VIP Room: its two looks before it is built (issue #21) and the finished room (#448). The first long build,
the day 2 hook.

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
CanQuery off) keeps players out of the building site in the yard.

  CleanACat_Area_VipRoom      the finished room at the same spot, a draft with named spots and no rules: the door
                              leaves stand open, swung back into a room that fills the building site, with a pearl
                              floor to stand on, lilac and gold decor (`_Decor`, not solid), a chandelier, and the
                              Attachments SpotVipEnter, SpotVipStation, SpotVipQueue and SpotVipWait. The name plate
                              inside the top of the opening has the `Screen` part. No barrier: players walk in.
                              Ten seats for the room's residents, the player's washed special cats (#579, ten
                              since #712): Attachments SpotResident1 to SpotResident10, each the top of a lilac pad
                              and turned to face the room, climbing each back corner like steps: a floor cushion, a
                              perch on a post, a shelf under the back window, a shelf under the side window and a
                              high shelf in the corner itself, between the two windows.
"""

import math

from mathutils import Matrix, Vector

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


# ---- the finished room (#448) ------------------------------------------------------------------------------------
ROOM = "CleanACat_Area_VipRoom"
RX = SITE_X                       # the side walls' outer faces
RY0, RY1 = WALL_T / 2, SITE_Y[1]  # from the spa wall's back face to the back wall's outer face
RWT = 0.4                         # wall thickness: thick enough to collide
WALL_SINK = 0.03                  # how far the back of a thin piece on a wall reaches into the wall (#670, as plot.SINK)
EAVES = 12.6                      # the walls' top, over the spa's 12 stud wall (the frame's ring beam)
RISE = 2.4                        # eaves to ridge
BAND = 5.0                        # the bubblegum lower wall the half built room promised
FLOOR_UP = 0.08                   # the room's floor over the spa's: above the yard's grass (0.04)
STATION = (0.0, 8.4)              # where a VIP wash station goes
WAIT = (6.85, 6.9)                # the chaise a VIP customer waits on, along the right wall under its window
QUEUE = (-5.0, 6.8)               # the gold mat a VIP customer stands on, clear of the open door leaves
# The residents' seats (#579): the player's washed special cats sit in the room. Five on each side, low to high,
# mirrored about the runner: a floor cushion under the back window, a perch on a post in the back corner, a shelf
# under the back window, a shelf under the side window and, since there are ten special cats (#712), a high shelf
# in the corner over the perch, carried by both walls. Every seat is past the open door leaves, so all ten
# show from the way in. (kind, x on the right side, y, the pad's top, the turn on the right side in degrees)
RESIDENT_SCALE = 1.2              # a sitting cat at this scale fits a pad
PAD_R = 1.08
CORNER_TOP = 8.7                  # the corner shelves' pads: a step over the other shelves, between the windows
_SEATS = (("cushion", 4.4, 10.6, FLOOR_UP + 0.3, -15.0),
          ("perch", 6.8, 10.8, 2.9, -40.0),
          ("shelf_back", 4.6, 10.95, 5.84, -12.0),
          ("shelf_side", 6.95, 7.05, 5.84, -90.0),
          ("shelf_corner", 6.95, 10.95, CORNER_TOP, -45.0))
# SpotResident1..10: right then left at each height, so the room fills evenly from the floor up
RESIDENTS = [(kind, sx * x, y, z, sx * turn) for kind, x, y, z, turn in _SEATS for sx in (1, -1)]
_RZ = lambda deg: Matrix.Rotation(math.radians(deg), 3, "Z")      # noqa: E731
_STAND = Matrix.Rotation(math.pi / 2, 3, "X")                     # a disc lying flat stood up to face -Y


def _window(b, at, turn, w=2.2, h=2.6):
    """An arched window on a wall face: a gold frame and a sky pane, built facing -Y at `at` (the middle of the
    square part) and turned about Z by `turn` degrees. No hole in the wall: one goes on each face. Four parts;
    the outside ones lost their glazing bars for phones (#688)."""
    R = _RZ(turn)

    def p(dx, dy, dz):
        v = R @ Vector((dx, dy, dz))
        return (at[0] + v.x, at[1] + v.y, at[2] + v.z)

    def slab(front, back):                       # a piece from `front` proud of the wall to `back` inside it
        return -(front - back) / 2, front + back

    # each piece ends at its own depth, in front and inside the wall, so no two faces share a plane
    y, d = slab(0.08, 0.05)
    b.box(p(0, y, 0), (w + 0.4, d, h + 0.2), "gold_mid", bevel=False, rot=R)
    y, d = slab(0.092, 0.07)
    b.cyl(p(0, y, h / 2), w / 2 + 0.2, d, "gold_mid", segments=10, bevel=False, rot=R @ _STAND)
    y, d = slab(0.12, 0.09)
    b.box(p(0, y, 0), (w, d, h), "spa_sky", bevel=False, rot=R)
    y, d = slab(0.132, 0.11)
    b.cyl(p(0, y, h / 2), w / 2, d, "spa_sky", segments=10, bevel=False, rot=R @ _STAND)


def _shell(b):
    """Floor, walls in two bands, the lining on the spa wall's back, gables and the roof."""
    x0, x1, y0, y1, t = -RX, RX, RY0, RY1, RWT
    ym = (y0 + y1) / 2
    b.box_base((0, ym, FLOOR_UP - 0.4), (x1 - x0 - 0.02, y1 - y0 - 0.02, 0.4), "pearl", bevel=False)        # the floor
    b.box_base((0, 0, -SINK), (DOOR_W - 0.1, WALL_T + 0.3, 0.05 + SINK), "gold_mid", bevel=False)          # a threshold
    for sx in (1, -1):                                                                                    # side walls
        x = sx * (RX - t / 2)
        b.box_base((x, ym, -SINK), (t, y1 - y0, BAND + SINK), "spa_bubblegum", bevel=False)
        b.box_base((x, ym, BAND), (t - 0.01, y1 - y0 - 0.01, EAVES - BAND), "spa_cream", bevel=False)
        b.box((sx * (RX - t - 0.05 + WALL_SINK / 2), ym, BAND + 0.1), (0.1 + WALL_SINK, y1 - y0 - 2 * t - 0.02, 0.24),
              "gold_mid", bevel=False)                                                                    # a rail
    xin = RX - t                                                                                          # back wall
    b.box_base((0, y1 - t / 2, -SINK + 0.004), (2 * xin, t, BAND + SINK - 0.004), "spa_bubblegum", bevel=False)
    b.box_base((0, y1 - t / 2, BAND + 0.002), (2 * xin, t - 0.01, EAVES - BAND - 0.002), "spa_cream", bevel=False)
    b.box((0, y1 - t - 0.05 + WALL_SINK / 2, BAND + 0.1), (2 * xin - 0.24, 0.1 + WALL_SINK, 0.24), "gold_mid", bevel=False)
    # the lining on the back of the spa's wall, round the door opening, and the wall over the spa's wall
    # (each piece's back is WALL_SINK or more inside the spa's wall: a camera resting on that wall sees no back)
    ws = WALL_SINK

    def lining(x, z, w, h, front, swatch, k=0):          # from `front` off the spa wall's back face to inside it
        back = ws + 0.004 * k
        b.box_base((x, y0 + (front - back) / 2, z), (w, front + back, h), swatch, bevel=False)

    for sx in (1, -1):
        xa, xb = DOOR_W / 2, xin
        lining(sx * (xa + xb) / 2, FLOOR_UP, xb - xa, BAND - FLOOR_UP, 0.12, "spa_bubblegum")
        lining(sx * (xa + xb) / 2, BAND + 0.002, xb - xa, EAVES - BAND - 0.002, 0.115, "spa_cream", k=1)
        lining(sx * (xa + xb) / 2, BAND - 0.02, xb - xa - 0.3, 0.24, 0.22, "gold_mid", k=2)              # a rail
    lining(0, DOOR_H, DOOR_W, EAVES - DOOR_H, 0.11, "spa_cream", k=3)
    b.box_base((0, y0 + t / 2 + 0.13, 12.0), (2 * xin, t, EAVES - 12.0), "spa_cream", bevel=False)
    # gables: a triangle over each end wall
    tri = [(-RX, -RISE / 3), (RX, -RISE / 3), (0.0, 2 * RISE / 3)]
    for y in (y0 + t / 2 + 0.13, y1 - t / 2):
        b.prism((0, y, EAVES + RISE / 3), tri, t - 0.02, "spa_cream", rot=_STAND)
    # the roof: two velvet slabs with a gold ridge, overhanging the walls
    half, over = RX, 0.7
    ang = math.atan2(RISE, half)
    ln = math.hypot(RISE, half) + over
    for sx in (1, -1):
        rot = Matrix.Rotation(sx * ang, 3, "Y")
        mid = (half - over * math.cos(ang) / 2 + 0.3) / 2 + 0.2
        b.box((sx * mid, ym + 0.15, EAVES + RISE / 2 + 0.18 - 0.2 * math.sin(ang) + 0.01 * (sx > 0)),
              (ln, y1 - y0 + 1.0 - 0.03 * (sx > 0), 0.3), "velvet_lilac", bevel=False, rot=rot)
    b.box((0, ym + 0.15, EAVES + RISE + 0.3), (0.7, y1 - y0 + 1.2, 0.3), "gold_mid", bevel=False)
    # windows: one in each side wall and two in the back, a pane on both faces
    for sx in (1, -1):
        b_out = (sx * RX, ym + 0.6, 8.3)
        _window(b, b_out, 90 * sx)
        _window(b, (sx * (RX - t), ym + 0.6, 8.3), -90 * sx)
    for x in (-4.6, 4.6):
        _window(b, (x, y1, 8.3), 180)
        _window(b, (x, y1 - t, 8.3), 0)


def _surround(b):
    """The butter frame round the opening on the spa's side and the crown on its header, as on the closed door."""
    w, h = DOOR_W, DOOR_H
    fy = -0.6
    for sx in (1, -1):
        b.box_base((sx * (w / 2 + 0.25), fy, -SINK), (0.5, 0.3, h + 0.3 + SINK), "pastel_butter", bevel=False)
    b.box_base((0, fy - 0.01, h - 0.02), (w + 1.2, 0.32, 0.62), "pastel_butter", bevel=False)
    cz, cy = h + 0.55, fy
    b.box_base((0, cy, cz), (2.4, 0.22, 0.6), "pastel_butter")
    for i, x in enumerate((-0.9, 0.0, 0.9)):
        top = 1.0 if i == 1 else 0.75
        b.cyl_base((x, cy, cz + 0.55), 0.26, top, "pastel_butter", segments=6, radius2=0.05, bevel=False)
        b.sphere((x, cy, cz + 0.6 + top), 0.14, "spa_bubblegum" if i == 1 else "spa_mint", segments=6, rings=4)


def _open_leaves(b):
    """The two door leaves swung back into the room and standing open, one each side of the way in."""
    lw, h = DOOR_W / 2 - 0.06, DOOR_H - 0.03
    for sx in (1, -1):
        x = sx * (DOOR_W / 2 + 0.19)                                 # clear of the opening
        y = RY0 + 0.2 + lw / 2
        b.box_base((x, y, FLOOR_UP), (0.34, lw, h - FLOOR_UP), "spa_bubblegum")
        for z0, ph in ((0.7, 2.6), (4.9, 3.2)):                      # raised panels, on both faces: the room sees the back
            b.box_base((x - sx * 0.17, y, z0), (0.06, lw - 0.94, ph), "spa_cream", bevel=False)
            b.box_base((x + sx * 0.17, y, z0), (0.06, lw - 0.94, ph), "spa_cream", bevel=False)
        b.cyl((x - sx * 0.19, y, 3.9), 0.42, 0.06, "spa_sky", segments=10, bevel=False,
              rot=Matrix.Rotation(math.pi / 2, 3, "Y"))               # the round window
        b.box((x - sx * 0.24, y + lw / 2 - 0.35, 4.2), (0.2, 0.14, 0.9), "gold_mid", bevel=False)     # the gold handle


def _decor(b):
    """What makes the room special, none of it solid: a runner to a round mat for the station, ropes, a chaise to
    wait on, a gold standing mat, plants, portraits and a star."""
    sx0, sy0 = STATION
    z = FLOOR_UP
    # each piece on the floor starts a little further under it than the last, so no two undersides share a plane
    r0, r1 = RY0 + 0.4, sy0 - 2.2
    b.box_base((0, (r0 + r1) / 2, z - 0.01), (2.6, r1 - r0, 0.04), "velvet_lilac", bevel=False)                 # runner
    for sx in (1, -1):
        b.box_base((sx * 1.38, (r0 + r1) / 2 - 0.01, z - 0.02 - 0.004 * sx), (0.16, r1 - r0, 0.06 + 0.004 * sx),
                   "gold_mid", bevel=False)
    b.cyl_base((sx0, sy0, z - 0.03), 3.0, 0.08, "gold_mid", segments=16, bevel=False)                           # the mat
    b.cyl_base((sx0, sy0, z - 0.04), 2.75, 0.11, "pastel_lilac", segments=16, bevel=False)
    b.cyl_base((sx0, sy0, z + 0.07), 1.3, 0.03, "pearl", segments=12, bevel=False)   # a pearl disc (a star until #688:
    #                                                                                  the station stands on it)
    for sx in (1, -1):                                                # rope posts along the runner
        for y in (2.0, 5.4):
            b.cyl_base((sx * 2.0, y, z - 0.05), 0.3, 0.15, "gold_mid", segments=8, bevel=False)
            b.cyl_base((sx * 2.0, y, z + 0.1), 0.09, 2.3, "gold_mid", segments=6, bevel=False)
            b.sphere((sx * 2.0, y, z + 2.5), 0.2, "gold_mid", segments=8, rings=4)
        b.box((sx * 2.0, 3.7, z + 2.05), (0.14, 3.5, 0.14), "velvet_lilac", bevel=False)                       # the rope
    wx, wy = WAIT                                    # the chaise, its back to the right wall: a seat, a back and a roll
    b.box_base((wx, wy, z + 0.3), (1.6, 3.2, 0.6), "pastel_lilac")
    b.box_base((wx + 0.72, wy, z + 0.9), (0.36, 3.2, 1.1), "pastel_lilac")
    b.cyl((wx - 0.05, wy + 1.45, z + 1.1), 0.36, 1.44, "velvet_lilac", segments=8, bevel=False, rot=(math.pi / 2, "Y"))
    b.box_base((wx, wy, z - 0.06), (1.3, 2.9, 0.38), "gold_mid", bevel=False)      # a gold plinth (four legs until #688)
    qx, qy = QUEUE                                                    # the standing mat, with a paw
    b.cyl_base((qx, qy, z - 0.07), 1.15, 0.11, "gold_mid", segments=12, bevel=False)
    b.cyl_base((qx, qy, z - 0.08), 1.0, 0.14, "spa_bubblegum", segments=12, bevel=False)
    b.box((qx, qy + 0.12, z + 0.075), (0.5, 0.36, 0.03), "pearl", bevel=False)
    for dx, dy in ((-0.38, -0.2), (-0.13, -0.42), (0.13, -0.42), (0.38, -0.2)):
        b.box((qx + dx, qy + dy, z + 0.075), (0.2, 0.2, 0.03), "pearl", bevel=False)
    for sx in (1, -1):                # a plant in each front corner, behind the open leaves (the back corners are
        px, py = sx * (RX - RWT - 1.1), RY0 + 1.5                     # the residents' since #579)
        b.cyl_base((px, py, z - 0.09 - 0.004 * sx), 0.5, 0.99 + 0.004 * sx, "gold_mid", segments=8, bevel=False, radius2=0.65)
        b.sphere((px, py, z + 1.6), 0.85, "leaf_green", segments=8, rings=5)
        b.sphere((px + 0.3 * sx, py - 0.2, z + 2.4), 0.6, "leaf_dark", segments=8, rings=5)
    # on the back wall over the station: a big gold star in a ring, a crown of three points over it
    # (both backs are inside the wall, the star's a hair deeper: a camera resting on the wall sees no back, #670)
    wy_ = RY1 - RWT
    b.cyl((sx0, wy_ - 0.045, 8.3), 1.25, 0.15, "pearl", segments=16, bevel=False, rot=_STAND)
    b.star((sx0, wy_ - 0.072, 8.3), 1.0, 0.45, 0.216, "gold_mid", rot=_STAND)
    # three cat portraits on the left wall: a gold frame, a pearl card and a cat's head in it
    # (every layer's back is inside the wall, a hair deeper each, so a camera resting on the wall sees no back)
    lx = -(RX - RWT)

    def flat(front, k, y, zc, w, h, sw, rot=None):
        back = WALL_SINK + 0.004 * k
        b.box((lx + (front - back) / 2, y, zc), (front + back, w, h), sw, bevel=False, rot=rot)

    for i, sw in enumerate(("fur_orange", "fur_grey", "fur_cream")):
        y = 5.4 + i * 2.0
        flat(0.1, 0, y, 3.2, 1.7, 2.0, "gold_mid")
        flat(0.14, 1, y, 3.2, 1.4, 1.7, "pearl")
        flat(0.18, 2, y, 3.05, 0.8, 0.7, sw)                                                                  # a head
        for j, dy in enumerate((-0.25, 0.25)):                                                                # its ears
            flat(0.186, 3 + j, y + dy, 3.4, 0.3, 0.3, sw, rot=Matrix.Rotation(math.pi / 4, 3, "X"))


def _pad(b, x, y, top, r=PAD_R):
    """A resident's lilac pad, its top at `top`, sunk a little into what carries it."""
    b.cyl_base((x, y, top - 0.2), r, 0.2, "velvet_lilac", segments=10, bevel=False)


def _residents(b):
    """The ten seats (RESIDENTS), none of it solid. Pieces that share a floor or a wall start at different depths,
    so no two faces share a plane."""
    for i, (kind, x, y, top, _turn) in enumerate(RESIDENTS):
        sx = 1 if x > 0 else -1
        e = 0.004 * (i % 2)
        if kind == "cushion":                        # a gold rim on the floor and the pad in it
            b.cyl_base((x, y, FLOOR_UP - 0.11 - e), PAD_R + 0.09, 0.27 + e, "gold_mid", segments=10, bevel=False)
            b.cyl_base((x, y, FLOOR_UP - 0.1 - e), PAD_R, top - FLOOR_UP + 0.1 + e, "velvet_lilac", segments=10,
                       bevel=False)
        elif kind == "perch":                        # a lilac post with gold bands, a pearl plate and the pad
            plate = top - 0.39
            b.cyl_base((x, y, FLOOR_UP - 0.12 - e), 0.72, 0.3 + e, "gold_mid", segments=10, bevel=False)
            b.cyl_base((x, y, FLOOR_UP - 0.13 - e), 0.36, plate - FLOOR_UP + 0.16 + e, "velvet_lilac", segments=8,
                       bevel=False)
            b.cyl_base((x, y, plate - 0.26), 0.52, 0.24, "gold_mid", segments=8, bevel=False)
            b.cyl_base((x, y, plate), PAD_R + 0.07, 0.2, "pearl", segments=10, bevel=False)
            _pad(b, x, y, top)
            # a gold ball hangs from the plate's edge on the room's side: something to bat at (a star until #688)
            hx, hy = x - sx * 0.8, y - 0.62
            b.box((hx, hy, plate - 0.3), (0.05, 0.05, 0.64), "gold_mid", bevel=False)
            b.sphere((hx, hy, plate - 0.78), 0.2, "gold_mid", segments=6, rings=4)
        else:                                        # a pearl shelf on one wide gold bracket (two until #688), the pad on it
            plate = top - 0.39
            b.cyl_base((x, y, plate), PAD_R + 0.12, 0.2, "pearl", segments=10, bevel=False)
            _pad(b, x, y, top)
            lean = math.atan2(0.75, 1.1)
            if kind in ("shelf_back", "shelf_corner"):   # the wall is behind (+Y): the bracket runs back and down to it
                wall = RY1 - RWT
                b.box((x, (y + wall) / 2 + 0.02, plate - 0.37), (0.5, 1.36, 0.16), "gold_mid",
                      bevel=False, rot=Matrix.Rotation(-lean, 3, "X"))
            else:                                    # the wall is to the side
                wall = sx * (RX - RWT)
                b.box(((x + wall) / 2 + sx * 0.02, y, plate - 0.37), (1.36, 0.5, 0.16),
                      "gold_mid", bevel=False, rot=Matrix.Rotation(sx * lean, 3, "Y"))


def _lamp(name, mat):
    """The chandelier: a gold ring on a rod from the ridge, with warm bulbs (lit at night like every `_Bulbs`)."""
    y = (RY0 + RY1) / 2
    b = Builder()
    b.cyl_base((0, y, 10.4), 0.07, EAVES + RISE - 10.4, "gold_mid", segments=6, bevel=False)
    b.cyl_base((0, y, 10.2), 1.5, 0.22, "gold_mid", segments=12, bevel=False)
    b.cyl_base((0, y, 10.42), 0.5, 0.25, "gold_mid", segments=8, bevel=False)
    ring = _tris(b.finalize(name + "_Lamp_Decor", mat))
    g = Builder()
    for k in range(6):
        a = math.radians(60 * k)
        g.sphere((1.3 * math.cos(a), y + 1.3 * math.sin(a), 10.0), 0.3, "lamp_warm", segments=8, rings=5)
    bulbs = _tris(g.finalize(name + "_Bulbs", mat))
    return [ring, bulbs]


def build_vip_room(mat):
    b = Builder()
    _shell(b)
    _surround(b)
    _open_leaves(b)
    main = _tris(b.finalize(ROOM, mat))
    d = Builder()
    _decor(d)
    _residents(d)
    decor = _tris(d.finalize(ROOM + "_Decor", mat))
    s = Builder()                                    # the room's name plate over the way in, inside the opening
    s.box_base((0, 0.0, DOOR_H - 1.25), (4.6, 0.3, 1.2), "spa_mint")
    plate = s.finalize(ROOM + "_Sign_Decor", mat)
    f = Builder()
    f.box_base((0, -0.16, DOOR_H - 1.13), (4.24, 0.06, 0.96), "offwhite", bevel=False)
    face = f.finalize(ROOM + "_Screen", mat, bevel=0)
    return [main, decor, plate, face] + _lamp(ROOM, mat)


def vip_room_rbx_extras():
    def at(x, y, z=FLOOR_UP):
        return Matrix.Translation((x, y, z))
    seats = [(ROOM, f"SpotResident{i + 1}", at(x, y, top) @ Matrix.Rotation(math.radians(turn), 4, "Z"))
             for i, (_kind, x, y, top, turn) in enumerate(RESIDENTS)]
    return {"attachments": [(ROOM, "SpotVipStation", at(*STATION)),
                            (ROOM, "SpotVipWait", at(WAIT[0], WAIT[1], FLOOR_UP + 0.9)),
                            (ROOM, "SpotVipQueue", at(*QUEUE)),
                            (ROOM, "SpotVipEnter", at(0.0, RY0 + 1.6))] + seats,
            # which way each of the first four faces is the game's to set: the station's front is the door (-Z),
            # the chaise faces the room (-X here, +X in Roblox). A resident's seat is turned already: its front
            # (-Z in Roblox) looks into the room.
            "attributes": {"FloorUp": {"Float64": FLOOR_UP}, "ResidentSeats": len(RESIDENTS),
                           "ResidentScale": {"Float64": RESIDENT_SCALE}}}


ASSETS = {"CleanACat_Area_VipLocked": (build_vip_locked, 2000),
          "CleanACat_Area_VipBuilding": (build_vip_building, 2000),
          ROOM: (build_vip_room, 5000)}
EXTRAS = {ROOM: vip_room_rbx_extras}
