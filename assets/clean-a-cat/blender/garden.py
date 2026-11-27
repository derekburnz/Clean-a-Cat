"""The Garden (issue #579, for the game's #515): the last long build, in the back yard behind the spa's back door.

`build.Garden` in tuning.md: 25,000 coins and 24 hours; "the player's and workers' pets play there". Three looks,
in the family of the VIP Room's (vip.py), all at the plot's SpotGardenDoor: pivot at the middle of the back door's
opening on the floor, front -Y in Blender (-Z in Roblox) into the spa room, the yard behind (+Y).

  CleanACat_Area_GardenLocked    before the build starts: a low white garden gate shut across the back door under a
                                 butter frame, a mint sign in the top of the opening whose cream face is a `Screen`
                                 part (front, -Z in Roblox) for the name and the timer, and behind it a bare soil
                                 plot with weeds, a stack of turf rolls, a seed sign on a stake and a heap under a
                                 sky tarp with white straps (the VIP site's tarp)
  CleanACat_Area_GardenBuilding  while the 24 hours run: the same gate and sign; half the lawn is laid in strips, two
                                 beds are dug with seedlings in, the pond is a hole with its stones piled beside it,
                                 two of the arbour's four posts stand, and a wheelbarrow, a shovel, planks and a tray
                                 of pots wait
  CleanACat_Area_Garden          the finished garden: the gate stands open, a stepping stone path runs to a butter
                                 arbour with a bench at the back, a round pond with lily pads is on the right, a play
                                 lawn with a tunnel, a ball, a scratching post and a pet bed is on the left, flower
                                 beds run along both sides and a pink blossom tree stands in the back corner, 10.5
                                 studs tall. Two lanterns by the gate (`_Bulbs`, lit at night).

The site is 18 studs wide and 11.2 deep. Its left and back edges are the plot's own yard fence; every look adds
one fence run down the right, between the garden and the VIP Room's site. The locked and building looks carry an
invisible `_Barrier` (solid, CanQuery off) over the site, as the VIP looks do. The finished garden has none over the
site: players walk in. It has one invisible slab along each open gate leaf (`_Gate_Barrier`), so nobody walks
through the pickets. Its lawn, path, pond rim, bench, arbour posts, fence and gate posts collide; `_Decor` (toys, stones' trim),
`_Flowers`, `_Canopy` and `_Bulbs` do not.

Attachments in the finished garden's first part, on the lawn unless noted and each turned to face the middle:
SpotGardenEnter (just inside the gate), SpotPetSit1 to SpotPetSit4 (the bench's cushion, a flat stone by the pond,
the pet bed, under the tree) and SpotPetPlay1 to SpotPetPlay4 (by the ball, at the tunnel's mouth, at the
scratching post, at the pond's edge by a lily). Root attributes `PetSpots` 8 and `GroundUp`. No rules in the model.

Side looks (#1050, see SIDE): the same three looks as `CleanACat_Area_GardenSide*` at the plot's SpotGardenSide, for a
plot whose back door leads to the Cat Hotel. The way in is one gate leaf in the left edge, opposite the doorway in
the hotel's right wall.
"""

import math

from mathutils import Matrix

from common import Builder
from stations import _tris

DOOR_W, DOOR_H = 6.0, 9.0         # the back door's opening (plot.BACK_DOOR, plot.DOOR_H)
FRAME_T = 0.38                    # the butter door frame's depth: over rbx_export.MIN_COLLIDE, so it is solid and a
#                                   camera stops on it instead of resting in the wall behind it (camera_rest_parts.py)
WALL_T = 1.0
SITE_X = 9.0                      # the site in the yard: x from -SITE_X to SITE_X about the door's middle
SITE_Y = (1.2, 12.4)              # from just behind the wall to just inside the plot's back fence (13.0)
SINK = 0.02
GROUND = 0.07                     # the lawn's and the soil's top over the spa floor: above the yard's grass (0.04)
FENCE_X = SITE_X + 0.3            # the new fence run on the right
LOCKED, BUILDING, NAME = "CleanACat_Area_GardenLocked", "CleanACat_Area_GardenBuilding", "CleanACat_Area_Garden"
BUDGET = {LOCKED: 2000, BUILDING: 2600, NAME: 5200}
# The side looks (#1050): the Cat Hotel took the back door, so the Garden stands on the old VIP site to the hotel's
# right (pivot at the plot's SpotGardenSide, where SpotVipDoor is) and is entered through a gate in its LEFT edge,
# opposite the doorway in the hotel's right wall (hotel.SIDE_DOOR). Same garden; what differs is listed at SIDE.
SIDE = False                      # set while a side look builds
SIDE_NAMES = {LOCKED: "CleanACat_Area_GardenSideLocked", BUILDING: "CleanACat_Area_GardenSideBuilding",
              NAME: "CleanACat_Area_GardenSide"}
GATE_Y = 6.5                      # the side gate's middle along the left edge (hotel.SIDE_DOOR's middle)
GATE_W = 3.0
LINK = 1.2                        # from the hotel wall's outer face to the site's left edge
SIGN_Z = 5.4                      # the side sign's foot: over a character's head, under the hotel doorway's top (7.0)
_STAND = Matrix.Rotation(math.pi / 2, 3, "X")       # a disc lying flat stood up to face -Y
_RZ = lambda deg: Matrix.Rotation(math.radians(deg), 3, "Z")      # noqa: E731

LAWN, SOIL, STONE = "eye_green", "fur_brown", "paving_light"
PETALS = ("spa_bubblegum", "pastel_butter", "pastel_lilac", "offwhite", "fur_strawberry")
POND = (5.0, 5.2, 2.1)            # x, y, the water's radius
ARBOUR = (0.0, 10.4)              # the arbour's middle; its bench faces the gate
TREE = (-7.2, 10.6)
BED_Y = (2.4, 8.6)                # the flower beds along the side fences
def _face(x, y, tx, ty):
    """The turn in degrees that makes a thing at (x, y) face (tx, ty): 0 faces the spa (-Y)."""
    return round(math.degrees(math.atan2(tx - x, -(ty - y))), 1)


BALL = (-3.3, 5.2)
TUNNEL = (-5.6, 3.6)              # its middle; it lies along Y, 2.6 long
POST = (-2.0, 8.3)                # the scratching post
BED = (-6.9, 7.7)                 # the pet bed
SIDE_BED = (-4.7, 9.7)            # the pet bed in the side looks: clear of the side gate and its open leaf
# the pets' spots in the finished garden: (name, x, y, z over GROUND, turn in degrees)
STONE_SIT = (1.95, 4.35)          # the flat stone by the pond: clear of the open gate leaf, its edge at the pond's bank
# #680: every pet at pet scale must stand clear of every prop here (a pet is up to 0.73 long each way from its pivot
# and 0.62 wide at scale 0.7), with room to move at the toys.
PET_SPOTS = (("SpotPetSit1", 0.0, 10.4, 1.19, 0.0),                              # on the bench's cushion, facing the gate, tail clear of its back
             ("SpotPetSit2", STONE_SIT[0], STONE_SIT[1], 0.06, _face(STONE_SIT[0], STONE_SIT[1], POND[0], POND[1])),   # the flat stone, looking at the pond
             ("SpotPetSit3", BED[0], BED[1], 0.32, _face(BED[0], BED[1], 0.0, 6.0)),      # the pet bed
             ("SpotPetSit4", -5.4, 10.4, 0.0, _face(-5.4, 10.4, 0.0, 6.0)),         # under the tree
             ("SpotPetPlay1", -2.3, 4.3, 0.0, _face(-2.3, 4.3, *BALL)),             # by the ball
             ("SpotPetPlay2", TUNNEL[0], TUNNEL[1] + 2.9, 0.0, 0.0),               # 1.6 studs from the tunnel's mouth, looking in
             ("SpotPetPlay3", -3.0, 7.5, 0.0, _face(-3.0, 7.5, *POST)),             # at the scratching post
             ("SpotPetPlay4", 3.4, 7.6, 0.0, _face(3.4, 7.6, POND[0], POND[1])))    # at the pond's edge


# ---- shared by all three looks ---------------------------------------------------------------------------------
def _frame(b):
    """A butter frame round the back door on the wall's room face, as round the VIP door. No crown: the strays' sign
    hangs over this door."""
    w, h = DOOR_W, DOOR_H
    fy, fo = -0.6, (FRAME_T - 0.3) / 2
    for sx in (1, -1):
        b.box_base((sx * (w / 2 + 0.25), fy - fo, -SINK), (0.5, FRAME_T, h + 0.3 + SINK), "pastel_butter",
                   bevel=False)
    b.box_base((0, fy - 0.01 - fo, h - 0.02), (w + 1.2, FRAME_T + 0.02, 0.62), "pastel_butter", bevel=False)


def _sign(name, mat, tall):
    """The mint sign inside the top of the opening and its cream `Screen` face. `tall` leaves room for a timer under
    the name (the Screen is the VIP door sign's size); the finished garden's is the VIP Room's name plate."""
    if SIDE:                               # across the two tall gate posts, its face toward the hotel's doorway (-X)
        hh, fh = (1.6, 1.3) if tall else (1.2, 0.96)
        s, f = Builder(), Builder()
        s.box_base((-SITE_X, GATE_Y, SIGN_Z), (0.3, GATE_W + 1.2, hh), "spa_mint")
        f.box_base((-SITE_X - 0.16, GATE_Y, SIGN_Z + (hh - fh) / 2), (0.06, GATE_W + 0.84, fh), "offwhite", bevel=False)
        return [s.finalize(name + "_Sign_Decor", mat), f.finalize(name + "_Screen", mat, bevel=0)]
    hh, fh = (2.1, 1.74) if tall else (1.2, 0.96)
    s = Builder()
    s.box_base((0, 0.0, DOOR_H - 0.05 - hh), (4.6, 0.3, hh), "spa_mint")
    f = Builder()
    f.box_base((0, -0.16, DOOR_H - 0.05 - hh + (hh - fh) / 2), (4.24, 0.06, fh), "offwhite", bevel=False)
    return [s.finalize(name + "_Sign_Decor", mat), f.finalize(name + "_Screen", mat, bevel=0)]


def _gate_posts(b):
    """Two white posts with mint caps just behind the wall, each side of the way through. Side looks: two tall posts
    on the left edge that carry the sign, a stone step across the gap to the hotel's doorway and a short white wall
    each side of it."""
    if SIDE:
        gx = -SITE_X
        for sy in (1, -1):
            b.box_base((gx, GATE_Y + sy * (GATE_W / 2 + 0.25), -SINK), (0.5, 0.5, SIGN_Z + SINK), "offwhite", bevel=False)
            b.box_base((gx - LINK / 2 - 0.25, GATE_Y + sy * (GATE_W / 2 + 0.36), -SINK - 0.002), (LINK - 0.5, 0.28, 2.4 + SINK),
                       "offwhite", bevel=False)
        b.box_base((gx - LINK / 2, GATE_Y, -0.31), (LINK, GATE_W, GROUND + 0.31 - 0.004), STONE, bevel=False)
        return
    for sx in (1, -1):
        b.box_base((sx * (DOOR_W / 2 + 0.05), 0.95, -SINK), (0.5, 0.5, 3.9 + SINK), "offwhite", bevel=False)
        b.sphere((sx * (DOOR_W / 2 + 0.05), 0.95, 4.1), 0.34, "spa_mint", segments=8, rings=5)


def _leaf(b, hinge, turn, sx):
    """One gate leaf from its hinge: five white pickets rising toward the hinge, two rails and a pink button at
    the latch end. `turn` swings it about the hinge (0 is shut, across the opening)."""
    R = _RZ(turn)
    hx, hy = hinge

    def at(u, v=0.0):                      # u along the leaf from the hinge toward the latch, v out of its plane
        dx, dy = -sx * u, v
        c, s = math.cos(math.radians(turn)), math.sin(math.radians(turn))
        return hx + dx * c - dy * s, hy + dx * s + dy * c

    for i in range(5):
        u = 0.36 + 0.56 * i
        h = 3.3 - 0.22 * i
        x, y = at(u)
        b.box_base((x, y, 0.28), (0.4, 0.14, h - 0.28), "offwhite", bevel=False, rot=R)
        b.cyl((x, y, h + 0.14), 0.2, 0.19, "offwhite", segments=6, bevel=False, rot=R @ _STAND)
    for z in (0.9, 2.1):
        x, y = at(1.4, 0.1)
        b.box((x, y, z), (2.6, 0.1, 0.24), "offwhite", bevel=False, rot=R)
    x, y = at(2.5, -0.1)
    b.cyl((x, y, 1.9), 0.22, 0.08, "fur_strawberry", segments=8, bevel=False, rot=R @ _STAND)


def _gate(b, open_):
    if SIDE:                               # one leaf, hinged at the gate's far end, swinging into the garden
        _leaf(b, (-SITE_X, GATE_Y + GATE_W / 2 - 0.05), (190 if open_ else 90), 1)
        return
    for sx in (1, -1):
        hinge = (sx * (DOOR_W / 2 - 0.2), 0.95)
        _leaf(b, hinge, (-sx * 100 if open_ else 0), sx)


SLAB_H = 12.0                     # the open gate leaves' invisible slabs: over a jumping character's root part


def _leaf_barrier(name, mat):
    """An invisible solid slab along each open gate leaf, so a player walks round the leaf and not through its thin
    pickets (which stay walk-through: thin solid rails read as ladder rungs to a Roblox character). CanQuery is
    off, as on every `_Barrier` here, so the camera and taps pass through it. SLAB_H tall: a slab as
    low as the leaf (3.3 studs) was hopped by a phone's auto jump (#736), and one of 8.5 studs by a moving jump,
    which lifts an R15 root part's bottom to about 9.3 studs off the floor, legs passing through (#741)."""
    b = Builder()
    if SIDE:
        turn = 190
        c, s = math.cos(math.radians(turn)), math.sin(math.radians(turn))
        hx, hy = -SITE_X, GATE_Y + GATE_W / 2 - 0.05
        b.box_base((hx - 1.48 * c, hy - 1.48 * s, -0.01), (2.75, 0.34, SLAB_H), "metal", bevel=False, rot=_RZ(turn))
        for sy in (1, -1):                 # and over the short walls across the gap to the hotel
            b.box_base((-SITE_X - LINK / 2, GATE_Y + sy * (GATE_W / 2 + 0.36), -0.012), (LINK + 0.3, 0.34, SLAB_H),
                       "metal", bevel=False)
    for sx in (() if SIDE else (1, -1)):
        turn = -sx * 100
        c, s = math.cos(math.radians(turn)), math.sin(math.radians(turn))
        hx, hy = sx * (DOOR_W / 2 - 0.2), 0.95
        b.box_base((hx - sx * 1.48 * c, hy - sx * 1.48 * s, -0.01), (2.75, 0.34, SLAB_H + 0.01 * (sx > 0)), "metal",
                   bevel=False, rot=_RZ(turn))                    # no face shares a plane with a picket or a rail
    ob = b.finalize(name + "_Gate_Barrier", mat, bevel=0)
    ob.hide_render = True
    return ob


def _fence(b):
    """The fence run down the right of the site, the plot's own low white fence: posts and two rails."""
    y0, y1 = 0.75, 12.85
    for k in range(5):
        y = y0 + (y1 - y0) * k / 4
        b.box_base((FENCE_X, y, -SINK - 0.002 * k), (0.3, 0.3, 2.4 + SINK), "offwhite", bevel=False)
    for z in (0.9, 1.9):
        b.box((FENCE_X, (y0 + y1) / 2, z), (0.12, y1 - y0, 0.22), "offwhite", bevel=False)
    if SIDE:                               # and down the left, each side of the gate
        for ya, yb in ((y0, GATE_Y - GATE_W / 2 - 0.5), (GATE_Y + GATE_W / 2 + 0.5, y1)):
            for k in range(3):
                b.box_base((-SITE_X, ya + (yb - ya) * k / 2 + (0.2 if k == 0 else -0.2 if k == 2 else 0), -SINK - 0.003 * k),
                           (0.3, 0.3, 2.4 + SINK), "offwhite", bevel=False)
            for z in (0.9, 1.9):
                b.box((-SITE_X, (ya + yb) / 2, z), (0.12, yb - ya, 0.22), "offwhite", bevel=False)


def _barrier(name, mat):
    b = Builder()
    if SIDE:
        for sy in (1, -1):
            b.box_base((-SITE_X - LINK / 2 - 0.2, GATE_Y + sy * (GATE_W / 2 + 0.36), -0.06), (LINK, 0.34, 12.0), "metal",
                       bevel=False)
    b.box_base((0.15, (SITE_Y[0] + SITE_Y[1]) / 2 + 0.05, -0.05), (2 * SITE_X + 0.96, SITE_Y[1] - SITE_Y[0] + 1.34, 12.0),
               "metal", bevel=False)
    ob = b.finalize(name + "_Barrier", mat, bevel=0)
    ob.hide_render = True
    return ob


def _ground(b, swatch):
    x0, x1, y0, y1 = -SITE_X, SITE_X, SITE_Y[0], SITE_Y[1]
    b.box_base((0, (y0 + y1) / 2, -0.33), (x1 - x0, y1 - y0, GROUND + 0.33), swatch, bevel=False)
    if SIDE:
        return
    b.box_base((0, (0.5 + y0) / 2 + 0.01, -0.31), (DOOR_W + 1.6, y0 - 0.5 + 0.04, GROUND + 0.31 - 0.004), STONE,
               bevel=False)                                                # a stone step from the door to the site


def _flower(b, x, y, k, i):
    """One flower: a stem, a head in the i-th petal colour and a butter eye."""
    b.box_base((x, y, GROUND - 0.03), (0.09, 0.09, 0.5 * k + 0.03), "leaf_dark", bevel=False)
    b.ico((x, y, GROUND + 0.5 * k + 0.16), 0.24 * k, PETALS[i % len(PETALS)])


def _planks(b, x, y, turn=0.0):
    for i in range(4):
        b.box_base((x, y, GROUND - 0.01 + 0.24 * i), (4.4, 0.8, 0.25), "wood_light", bevel=False,
                   rot=_RZ(turn + 4 * (i % 2)))


def _turf_roll(b, x, y, z, turn=0.0):
    rot = _RZ(turn) @ Matrix.Rotation(math.pi / 2, 3, "Y")
    b.cyl((x, y, z), 0.42, 1.8, "leaf_green", segments=8, bevel=False, rot=rot)
    b.cyl((x, y, z), 0.34, 1.84, SOIL, segments=8, bevel=False, rot=rot)


# ---- the locked look -------------------------------------------------------------------------------------------
def build_garden_locked(mat):
    b = Builder()
    if not SIDE:
        _frame(b)
    _gate_posts(b)
    _gate(b, False)
    _fence(b)
    _ground(b, SOIL)
    main = _tris(b.finalize(LOCKED, mat))
    d = Builder()
    for i, (x, y) in enumerate(((-6.0, 3.0), (-2.4, 6.4), (3.4, 4.0), (6.6, 6.4), (-7.2, 9.2), (-1.0, 10.6))):   # weeds
        for j, (dx, lean) in enumerate(((-0.12, 20), (0.0, 0), (0.12, -20))):
            d.box_base((x + dx, y + 0.05 * j, GROUND - 0.02), (0.1, 0.1, 0.5 + 0.12 * (j == 1)), "leaf_green",
                       bevel=False, rot=Matrix.Rotation(math.radians(lean), 3, "Y"))
    for i, (dy, z) in enumerate(((-0.45, 0.42), (0.45, 0.42), (0.0, 1.14))):                                    # turf rolls
        _turf_roll(d, -5.6 + 0.1 * i, (3.4 if SIDE else 6.2) + dy, GROUND + z)
    # a seed sign on a stake: a cream card with a pink flower, facing the gate
    d.box_base((2.2, 3.0, GROUND - 0.02), (0.16, 0.14, 2.3), "wood_light", bevel=False)
    d.box((2.2, 2.9, GROUND + 2.2), (1.3, 0.1, 1.5), "wood_light", bevel=False)
    d.box((2.2, 2.84, GROUND + 2.2), (1.06, 0.06, 1.26), "spa_cream", bevel=False)
    d.cyl((2.2, 2.8, GROUND + 2.35), 0.3, 0.05, "spa_bubblegum", segments=8, bevel=False, rot=_STAND)
    d.cyl((2.2, 2.775, GROUND + 2.35), 0.12, 0.05, "pastel_butter", segments=6, bevel=False, rot=_STAND)
    d.box((2.2, 2.795, GROUND + 1.87), (0.08, 0.05, 0.42), "leaf_dark", bevel=False)
    # a heap under a sky tarp with white straps, at the back
    hx, hy = 3.6, 9.6
    d.box_base((hx, hy, GROUND - 0.02), (5.2, 3.2, 1.7), "spa_sky", bevel=False)
    d.box_base((hx, hy, GROUND + 1.67), (3.8, 2.2, 0.7), "spa_sky")
    for dx in (-1.5, 1.5):
        d.box((hx + dx, hy, GROUND + 0.86), (0.3, 3.28, 1.74), "offwhite", bevel=False)
    return [main, _tris(d.finalize(LOCKED + "_Decor", mat))] + _sign(LOCKED, mat, True) + [_barrier(LOCKED, mat)]


# ---- the building look -----------------------------------------------------------------------------------------
def build_garden_building(mat):
    b = Builder()
    if not SIDE:
        _frame(b)
    _gate_posts(b)
    _gate(b, False)
    _fence(b)
    _ground(b, SOIL)
    for sy in (0, 1):                                              # two of the arbour's posts are up, with a beam
        b.box_base((ARBOUR[0] - 2.4, ARBOUR[1] - 1.1 + 2.2 * sy, GROUND - 0.02), (0.5, 0.5, 6.2), "pastel_butter",
                   bevel=False)
    b.box((ARBOUR[0] - 2.4, ARBOUR[1], GROUND + 6.3), (0.58, 3.4, 0.4), "pastel_butter", bevel=False)
    main = _tris(b.finalize(BUILDING, mat))
    d = Builder()
    for i in range(3):                                             # the lawn goes down in strips from the left
        d.box_base((-7.4 + 2.5 * i, 6.8, GROUND - 0.01), (2.3, 10.4 - 1.6 * i, 0.07 + 0.002 * i), LAWN, bevel=False)
    _turf_roll(d, 0.6, 3.4, GROUND + 0.42, 90)
    _turf_roll(d, 0.6, 5.5, GROUND + 0.42, 80)
    for sx in (1,):                                                # the right bed is dug: a dark strip, seedlings in
        d.box_base((7.6, (BED_Y[0] + BED_Y[1]) / 2, GROUND - 0.015), (1.6, BED_Y[1] - BED_Y[0], 0.14), "mud", bevel=False)
        for k in range(5):
            d.box_base((7.6, BED_Y[0] + 0.6 + 1.25 * k, GROUND + 0.1), (0.1, 0.1, 0.34), "leaf_green", bevel=False)
            d.ico((7.6, BED_Y[0] + 0.6 + 1.25 * k, GROUND + 0.5), 0.13, "leaf_green")
    px, py, pr = POND                                              # the pond is a hole, its stones piled beside it
    d.cyl_base((px, py, GROUND - 0.018), pr + 0.2, 0.05, "mud", segments=12, bevel=False)
    d.cyl_base((px, py, GROUND - 0.014), pr - 0.3, 0.06, "choco", segments=12, bevel=False)
    for i, (dx, dy, dz, r) in enumerate(((0.0, 0.0, 0.0, 0.5), (0.7, 0.2, 0.0, 0.42), (0.3, 0.6, 0.0, 0.44),
                                         (0.35, 0.25, 0.5, 0.4))):
        d.sphere((px - 3.1 + dx, py + 1.9 + dy, GROUND + 0.24 + dz), r, STONE if i % 2 else "paving_sand", segments=6,
                 rings=4, scale=(1.0, 1.0, 0.7))
    # a wheelbarrow of soil: a mint tray, a soil heap, wood handles, a wheel
    wx, wy = 3.0, 9.0
    d.box((wx, wy, GROUND + 1.0), (1.7, 2.2, 0.7), "spa_mint")
    d.sphere((wx, wy, GROUND + 1.36), 0.8, SOIL, segments=8, rings=4, scale=(1.0, 1.25, 0.5))
    d.cyl((wx, wy - 1.35, GROUND + 0.45), 0.45, 0.3, "fur_charcoal", segments=10, bevel=False,
          rot=Matrix.Rotation(math.pi / 2, 3, "Y"))
    d.box((wx, wy - 1.2, GROUND + 0.72), (0.16, 0.5, 0.5), "wood_light", bevel=False)
    for sx in (1, -1):
        d.box((wx + sx * 0.7, wy + 1.5, GROUND + 0.95), (0.14, 1.5, 0.14), "wood_light", bevel=False)
        d.box_base((wx + sx * 0.7, wy + 0.8, GROUND - 0.02), (0.14, 0.14, 0.72), "wood_light", bevel=False)
    # a shovel stood in the soil, planks, the other two posts lying down, a tray of pots
    d.box_base((-0.6, 8.6, GROUND - 0.02), (0.14, 0.14, 2.9), "wood_light", bevel=False)
    d.box((-0.6, 8.6, GROUND + 0.34), (0.6, 0.1, 0.7), "metal", bevel=False)
    d.box((-0.6, 8.6, GROUND + 2.95), (0.5, 0.14, 0.14), "wood_light", bevel=False)
    _planks(d, 5.4, 11.3)
    for i in (0, 1):
        d.box_base((0.4 + 0.2 * i, 11.0 + 0.62 * i, GROUND - 0.012 - 0.002 * i), (6.2, 0.5, 0.5), "pastel_butter",
                   bevel=False, rot=_RZ(3 - 7 * i))
    d.box_base((-5.2, 2.5, GROUND + 0.062), (2.4, 1.3, 0.2), "wood_light", bevel=False)
    for i in range(3):
        x = -6.0 + 0.8 * i
        d.cyl_base((x, 2.5, GROUND + 0.25), 0.26, 0.42, "terracotta", segments=8, bevel=False, radius2=0.34)
        _flower(d, x, 2.5, 0.9, i)
    return ([main, _tris(d.finalize(BUILDING + "_Decor", mat))] + _sign(BUILDING, mat, True)
            + [_barrier(BUILDING, mat)])


# ---- the finished garden ---------------------------------------------------------------------------------------
def _path(b):
    """Stepping stones from the gate to the arbour, and one flat stone toward the pond for a pet to sit on. Each a
    hair higher than the last."""
    stones = ((0.0, 2.3, 0.85), (0.35, 3.9, 0.8), (-0.2, 5.4, 0.85), (0.3, 6.9, 0.8), (-0.1, 8.3, 0.8),
              (STONE_SIT[0], STONE_SIT[1], 0.72))
    if SIDE:                               # in from the side gate to the middle, then on to the arbour and the pond
        stones = ((-7.5, GATE_Y, 0.85), (-5.7, GATE_Y - 0.1, 0.8), (-3.9, GATE_Y + 0.15, 0.85), (-2.0, GATE_Y - 0.1, 0.8)) + stones[2:]
    for i, (x, y, r) in enumerate(stones):
        b.cyl_base((x, y, GROUND - 0.05 - 0.003 * i), r, 0.08 + 0.007 * i, STONE if i % 2 == 0 else "paving_sand",
                   segments=10, bevel=False, scale=(1.0, 0.82, 1.0))


def _pond(b, d, w):
    px, py, pr = POND
    b.cyl_base((px, py, GROUND - 0.07), pr + 0.42, 0.13, "paving_sand", segments=14, bevel=False)     # the sandy bank
    # solid water a little over the bank, thick enough to walk on: no swimming and nothing see-through
    w.cyl_base((px, py, GROUND - 0.29), pr, 0.4, "water", segments=14, bevel=False)
    w.cyl_base((px - 0.3, py + 0.2, GROUND - 0.28), pr * 0.55, 0.4, "spa_sky", segments=12, bevel=False)   # a paler middle
    for i in range(11):                                            # stones on the bank, all round
        a = math.radians(360 / 11 * i + 12)
        d.sphere((px + math.cos(a) * (pr + 0.2), py + math.sin(a) * (pr + 0.2), GROUND + 0.16), 0.3 + 0.06 * (i % 2),
                 STONE if i % 3 else "paving_tan", segments=6, rings=4, scale=(1.0, 1.0, 0.62))
    for i, (dx, dy, r) in enumerate(((-0.9, 0.7, 0.55), (0.9, -0.7, 0.48), (0.7, 1.1, 0.4))):          # lily pads
        d.cyl_base((px + dx, py + dy, GROUND + 0.1), r, 0.07 + 0.004 * i, "leaf_green", segments=8, bevel=False)
    d.ico((px - 0.9, py + 0.7, GROUND + 0.3), 0.22, "spa_bubblegum")
    d.ico((px - 0.9, py + 0.7, GROUND + 0.46), 0.11, "pastel_butter")


def _arbour(b, d, f):
    """Four butter posts, beams and slats, flowers along the top, and a bench with a lilac cushion under it."""
    ax, ay = ARBOUR
    top = 6.2
    for sx in (1, -1):
        for sy in (1, -1):
            b.box_base((ax + sx * 2.4, ay + sy * 1.1, GROUND - 0.02), (0.5, 0.5, top), "pastel_butter", bevel=False)
        b.box((ax + sx * 2.4, ay, GROUND + top + 0.1), (0.58, 3.4, 0.4), "pastel_butter", bevel=False)
    for i in range(5):
        b.box((ax, ay - 1.2 + 0.6 * i, GROUND + top + 0.36 + 0.004 * i), (6.0, 0.24, 0.24), "pastel_butter", bevel=False)
    for i in range(9):                                             # blossoms and leaves along the front beam
        x = ax - 2.8 + 0.7 * i
        f.ico((x, ay - 1.42, GROUND + top + 0.3 + 0.1 * (i % 2)), 0.3, PETALS[i % 3] if i % 2 == 0 else "leaf_green")
    for sx in (1, -1):                                             # a vine up each front post
        for k in range(4):
            f.ico((ax + sx * 2.4, ay - 1.42, GROUND + 1.2 + 1.3 * k), 0.24, "leaf_green" if k % 2 else PETALS[k])
    # the bench: a seat, a back, two ends and a cushion
    by = ay + 0.35
    b.box_base((ax, by, GROUND + 0.5), (3.6, 1.3, 0.4), "wood_light")
    b.box_base((ax, by + 0.55, GROUND + 0.88), (3.6, 0.28, 1.5), "wood_light")
    for sx in (1, -1):
        b.box_base((ax + sx * 1.66, by + 0.03, GROUND - 0.024), (0.3, 1.44, 1.5), "wood_light", bevel=False)
    d.box_base((ax, by - 0.07, GROUND + 0.89), (2.9, 1.12, 0.3), "pastel_lilac")   # to the seat's front edge (#680)


def _beds(b, f):
    """A flower bed along each side fence: a stone edge, soil and two rows of flowers; a round bush at each end."""
    y0, y1 = BED_Y
    n = 0
    for sx in (1, -1):
        x = sx * (SITE_X - 1.0)
        if SIDE and sx < 0:                # the left bed stops short of the side gate
            y1 = GATE_Y - GATE_W / 2 - 1.0
        b.box_base((x, (y0 + y1) / 2, GROUND - 0.04), (1.9, y1 - y0 + 0.3, 0.3), STONE, bevel=False)
        b.box_base((x, (y0 + y1) / 2, GROUND - 0.035), (1.5, y1 - y0 - 0.1, 0.36), SOIL, bevel=False)
        rows = 2 if SIDE and sx < 0 else 6
        for k in range(rows):
            for j in (0, 1):
                n += 1
                _flower(f, x - 0.36 + 0.72 * j, y0 + 0.5 + (y1 - y0 - 1.0) * k / (rows - 1) + 0.25 * j,
                        1.0 + 0.3 * ((k + j) % 2), n)
        f.sphere((x, y0 - 0.75, GROUND + 0.6), 0.8, "leaf_green", segments=8, rings=5)
        if SIDE and sx < 0:
            continue
        f.sphere((x, y1 + 0.85, GROUND + 0.66), 0.86, "leaf_dark" if sx > 0 else "leaf_green", segments=8, rings=5)


def _toys(d):
    """The play lawn on the left, none of it solid: a tunnel, a ball, a scratching post with a feather and a pet bed."""
    # the tunnel: a mint tube lying along Y with a dark mouth each end and two cream bands
    tx, ty = TUNNEL
    lay = Matrix.Rotation(math.pi / 2, 3, "X")
    d.cyl((tx, ty, GROUND + 0.92), 1.0, 2.6, "spa_mint", segments=10, bevel=False, rot=lay)
    d.cyl((tx, ty, GROUND + 0.92), 0.8, 2.64, "fur_ink", segments=10, bevel=False, rot=lay)
    for dy in (-0.7, 0.7):
        d.cyl((tx, ty + dy, GROUND + 0.92), 1.04, 0.3, "spa_cream", segments=10, bevel=False, rot=lay)
    # the ball: bubblegum with a cream band
    d.sphere((BALL[0], BALL[1], GROUND + 0.5), 0.52, "spa_bubblegum", segments=10, rings=6)
    d.cyl((BALL[0], BALL[1], GROUND + 0.5), 0.535, 0.2, "spa_cream", segments=10, bevel=False,
          rot=Matrix.Rotation(math.radians(35), 3, "X"))
    # the scratching post: a base, a rope post in two pinks, a top and a feather on a bent wire
    sx_, sy_ = POST
    d.box_base((sx_, sy_, GROUND - 0.016), (1.5, 1.5, 0.24), "wood_light")
    d.cyl_base((sx_, sy_, GROUND + 0.2), 0.3, 2.3, "fur_rose", segments=8, bevel=False)
    for k in range(3):
        d.cyl_base((sx_, sy_, GROUND + 0.55 + 0.7 * k), 0.325, 0.3, "fur_strawberry", segments=8, bevel=False)
    d.cyl_base((sx_, sy_, GROUND + 2.48), 0.62, 0.22, "wood_light", segments=8, bevel=False)
    d.box((sx_ + 0.45, sy_, GROUND + 3.0), (0.06, 0.06, 0.8), "gold_mid", bevel=False,
          rot=Matrix.Rotation(math.radians(40), 3, "Y"))
    d.ico((sx_ + 0.76, sy_, GROUND + 3.34), 0.2, "pastel_lilac", scale=(1.0, 0.5, 1.5))
    # the pet bed: a bubblegum ring and a cream pad
    bx, by = SIDE_BED if SIDE else BED
    d.cyl_base((bx, by, GROUND - 0.012), 1.05, 0.46, "spa_bubblegum", segments=10, bevel=False)
    d.cyl_base((bx, by, GROUND - 0.008), 0.8, 0.33, "spa_cream", segments=10, bevel=False)


def _tree(b, c):
    """A blossom tree in the back left corner: a trunk and four pink clouds."""
    tx, ty = TREE
    b.cyl_base((tx, ty, GROUND - 0.02), 0.5, 5.4, "fur_acorn", segments=8, bevel=False, radius2=0.34)
    c.sphere((tx, ty, GROUND + 7.2), 2.5, "spa_bubblegum", segments=8, rings=6, scale=(1.0, 1.0, 0.82))
    c.sphere((tx + 1.6, ty - 0.6, GROUND + 5.9), 1.7, "fur_rose", segments=8, rings=5, scale=(1.0, 1.0, 0.8))
    c.sphere((tx - 0.9, ty - 1.3, GROUND + 5.6), 1.5, "fur_strawberry", segments=8, rings=5, scale=(1.0, 1.0, 0.8))
    c.sphere((tx + 0.3, ty + 0.4, GROUND + 9.3), 1.5, "fur_rose", segments=8, rings=5, scale=(1.0, 1.0, 0.8))


def _lanterns(b, name, mat):
    """A lantern each side of the gate, inside: a white post, a mint cap and a warm bulb (`_Bulbs`)."""
    g = Builder()
    for sx in (1, -1):
        x, y = (-6.9, GATE_Y + (2.5 if sx > 0 else -1.6)) if SIDE else (sx * 4.6, 2.0)
        b.box_base((x, y, GROUND - 0.02), (0.3, 0.3, 3.2), "offwhite", bevel=False)
        b.box((x, y, GROUND + 3.24), (0.7, 0.7, 0.16), "offwhite", bevel=False)
        b.box_base((x, y, GROUND + 3.3), (0.1, 0.1, 0.76), "offwhite", bevel=False)      # a rod through the bulb
        b.cyl_base((x, y, GROUND + 4.02), 0.5, 0.4, "spa_mint", segments=8, bevel=False, radius2=0.08)
        g.sphere((x, y, GROUND + 3.72), 0.34, "lamp_warm", segments=8, rings=5)
    return _tris(g.finalize(name + "_Bulbs", mat))


def build_garden(mat):
    b, d, f, c, w = Builder(), Builder(), Builder(), Builder(), Builder()
    if not SIDE:
        _frame(b)
    _gate_posts(b)
    _gate(b, True)
    _fence(b)
    _ground(b, LAWN)
    _path(b)
    _pond(b, d, w)
    _arbour(b, d, f)
    _beds(b, f)
    _toys(d)
    _tree(b, c)
    bulbs = _lanterns(b, NAME, mat)
    return ([_tris(b.finalize(NAME, mat)), _tris(d.finalize(NAME + "_Decor", mat)),
             _tris(f.finalize(NAME + "_Flowers", mat)), _tris(c.finalize(NAME + "_Canopy", mat)),
             _tris(w.finalize(NAME + "_Pond", mat)), bulbs] + _sign(NAME, mat, False)
            + [_leaf_barrier(NAME, mat)])


def garden_rbx_extras():
    def at(x, y, z=0.0, turn=0.0):
        return Matrix.Translation((x, y, GROUND + z)) @ Matrix.Rotation(math.radians(turn), 4, "Z")
    atts = [(NAME, "SpotGardenEnter", at(0.0, 2.3, 0.03, 180.0))]
    atts += [(NAME, n, at(x, y, z, turn)) for n, x, y, z, turn in PET_SPOTS]
    return {"attachments": atts,
            "attributes": {"GroundUp": {"Float64": GROUND}, "PetSpots": len(PET_SPOTS)}}


def _side(fn, base):
    """Build `fn` as its side look: SIDE on and the three names swapped for the length of the build."""
    def build(mat):
        global SIDE, LOCKED, BUILDING, NAME
        old = (LOCKED, BUILDING, NAME)
        SIDE, LOCKED, BUILDING, NAME = True, SIDE_NAMES[old[0]], SIDE_NAMES[old[1]], SIDE_NAMES[old[2]]
        try:
            return fn(mat)
        finally:
            SIDE, (LOCKED, BUILDING, NAME) = False, old
    return build


def garden_side_rbx_extras():
    def at(x, y, z=0.0, turn=0.0):
        return Matrix.Translation((x, y, GROUND + z)) @ Matrix.Rotation(math.radians(turn), 4, "Z")
    name = SIDE_NAMES[NAME]
    atts = [(name, "SpotGardenEnter", at(-7.5, GATE_Y, 0.03, 90.0))]
    for n, x, y, z, turn in PET_SPOTS:
        if n == "SpotPetSit3":
            x, y, turn = SIDE_BED[0], SIDE_BED[1], _face(SIDE_BED[0], SIDE_BED[1], 0.0, 6.0)
        atts.append((name, n, at(x, y, z, turn)))
    return {"attachments": atts,
            "attributes": {"GroundUp": {"Float64": GROUND}, "PetSpots": len(PET_SPOTS), "Side": True}}


ASSETS = {LOCKED: (build_garden_locked, BUDGET[LOCKED]),
          BUILDING: (build_garden_building, BUDGET[BUILDING]),
          NAME: (build_garden, BUDGET[NAME]),
          SIDE_NAMES[LOCKED]: (_side(build_garden_locked, LOCKED), BUDGET[LOCKED]),
          SIDE_NAMES[BUILDING]: (_side(build_garden_building, BUILDING), BUDGET[BUILDING]),
          SIDE_NAMES[NAME]: (_side(build_garden, NAME), BUDGET[NAME])}
EXTRAS = {NAME: garden_rbx_extras, SIDE_NAMES[NAME]: garden_side_rbx_extras}
