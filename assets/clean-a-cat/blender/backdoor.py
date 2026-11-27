"""The back door as a locked expansion (issue #1041): a friendly building site, and the same door unlocked.

Derek, 2026-11-27: "something at the backdoor if thats an expansion you have to get for some sort of upgrade maybe
its blocked off with caution tape and some construction materials etc ... when they go to it be unlocked". Two looks,
both at the plot's SpotGardenDoor (the middle of the back door's opening on the floor, front -Y in Blender, -Z in
Roblox, into the spa room, the yard behind), so they fit the small and the big plot:

  CleanACat_Area_BackDoorLocked  a closed mint door in the butter frame (the VIP and Garden doors' frame), two
                                 strips of butter caution tape with ink stripes crossed over it, pinned at the frame
                                 with pink tabs, a sawhorse across the doorway with a cream and pink striped board,
                                 three planks leant on the door, three pastel paint pots (one up on the sawhorse)
                                 and an apricot cone. An invisible `_Barrier` (solid, CanQuery off) keeps players
                                 out of the props; the door itself is solid. Attachment `PromptAnchor` in front of
                                 the sawhorse at chest height, for the unlock prompt.
  CleanACat_Area_BackDoorOpen    the same frame with the door swung open flat against the wall's yard side; the
                                 way through is clear and there is no barrier.

Everything stays inside the door's own 6 studs plus the frame and 2.9 studs into the room, clear of the stray box on
the left and Sam's wash stand on the right in both plots. Nothing sharp and no black: the tape's stripes are the UI
ink on butter. Props are `_Decor` (not solid), the frame and the door collide. What is behind the door is not here:
it waits on Derek's pick (Design-Agent's plan page). The Garden's looks put their own gate in this doorway, so the
game shows one or the other.
"""

import math

from mathutils import Matrix, Vector

from common import Builder
from stations import _tris

DOOR_W, DOOR_H = 6.0, 9.0         # the back door's opening (plot.BACK_DOOR, plot.DOOR_H)
FRAME_T = 0.38                    # as garden.FRAME_T: solid, so the camera stops on it
SINK = 0.02
LEAF_T = 0.4                      # the door: thick enough to be solid
LOCKED, OPEN = "CleanACat_Area_BackDoorLocked", "CleanACat_Area_BackDoorOpen"
DOOR_C, PANEL, TAPE, STRIPE = "spa_mint", "spa_cream", "pastel_butter", "fur_ink"
WOOD, WOOD2 = "wood_light", "caramel_wood"
POTS = ("spa_bubblegum", "spa_sky", "spa_mint")
CONE = "fur_apricot"
TAPE_Y = -0.92                    # just in front of the frame's face (-0.83)
_RZ = lambda deg: Matrix.Rotation(math.radians(deg), 3, "Z")      # noqa: E731
_RY = lambda rad: Matrix.Rotation(rad, 3, "Y")                     # noqa: E731
_STAND = Matrix.Rotation(math.pi / 2, 3, "X")


def _frame(b):
    """The butter frame round the opening on the wall's room face (garden._frame)."""
    w, h = DOOR_W, DOOR_H
    fy, fo = -0.6, (FRAME_T - 0.3) / 2
    for sx in (1, -1):
        b.box_base((sx * (w / 2 + 0.25), fy - fo, -SINK), (0.5, FRAME_T, h + 0.3 + SINK), "pastel_butter",
                   bevel=False)
    b.box_base((0, fy - 0.01 - fo, h - 0.02), (w + 1.2, FRAME_T + 0.02, 0.62), "pastel_butter", bevel=False)


def _door(b, at, turn):
    """The door leaf from its hinge at `at` (its left edge seen from the room), `turn` degrees about the hinge (0:
    shut across the opening). Mint with two cream panels on each face, a round sky window and a butter knob."""
    lw, lh = DOOR_W - 0.08, DOOR_H - 0.05
    R = _RZ(turn)
    hx, hy = at

    def p(u, v, z):                     # u along the leaf from the hinge, v out of its room face (-Y when shut)
        q = R @ Vector((u, -v, 0.0))
        return (hx + q.x, hy + q.y, z)

    b.box_base(p(lw / 2, 0, 0), (lw, LEAF_T, lh), DOOR_C, rot=R)
    for side in (1, -1):
        for z0, ph in ((0.8, 3.0), (5.0, 3.0)):
            b.box_base(p(lw / 2, side * (LEAF_T / 2 + 0.02), z0), (lw - 1.4, 0.06, ph), PANEL, bevel=False, rot=R)
        b.cyl(p(lw / 2, side * (LEAF_T / 2 + 0.05), 6.5), 0.62, 0.06, "spa_sky", segments=14, bevel=False,
              rot=R @ _STAND)
        b.sphere(p(lw - 0.55, side * (LEAF_T / 2 + 0.14), 4.3), 0.2, "pastel_butter", segments=8, rings=5)


def _tape(d, x0, z0, x1, z1, ty=TAPE_Y):
    """One strip of caution tape from (x0, z0) to (x1, z1) across the door's front: butter with ink stripes."""
    dx, dz = x1 - x0, z1 - z0
    length = math.hypot(dx, dz)
    ang = -math.atan2(dz, dx)
    rot = _RY(ang)
    cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
    d.box((cx, ty, cz), (length, 0.05, 0.62), TAPE, bevel=False, rot=rot)
    n = int(length / 0.9)
    for i in range(n):
        t = (i + 0.5) / n - 0.5
        d.box((cx + dx * t, ty - 0.035, cz + dz * t), (0.26, 0.03, 0.62), STRIPE, bevel=False,
              rot=rot @ _RY(-0.6))
    for x, z in ((x0, z0), (x1, z1)):                                 # pink tabs pin the ends to the frame
        d.box((x, ty - 0.06, z), (0.5, 0.05, 0.5), "spa_bubblegum", bevel=False, rot=_RY(0.785))


def _sawhorse(d, y):
    """Across the doorway: a beam on two pairs of splayed legs, a striped board in front."""
    top, half = 2.5, 2.2
    d.box((0, y, top), (2 * half + 0.4, 0.4, 0.34), WOOD)
    for sx in (1, -1):
        for sy in (1, -1):
            d.box((sx * (half - 0.35 + sy * 0.04), y + sy * 0.32, top / 2 - 0.01), (0.26, 0.26, top + 0.02), WOOD2,
                  bevel=False, rot=Matrix.Rotation(sy * 0.24, 3, "X") @ _RY(-sx * 0.08))
    board_z = 1.55
    d.box((0, y - 0.32, board_z), (2 * half, 0.12, 0.62), PANEL, bevel=False)
    k = 7
    for i in range(k):
        x = -half + (i + 0.5) * 2 * half / k
        d.box((x, y - 0.39, board_z), (0.28, 0.06, 0.6), "spa_bubblegum", bevel=False, rot=_RY(-0.6))
    return top + 0.17


def _pot(d, x, y, z, swatch, k):
    """A paint pot: a cream tin with a coloured band, a coloured lid with a drip down the side and a wire handle."""
    r, h = 0.36, 0.62
    d.cyl_base((x, y, z), r, h, "offwhite", segments=12)
    d.cyl_base((x, y, z + 0.18), r + 0.02, 0.24, swatch, segments=12, bevel=False)
    d.cyl_base((x, y, z + h - 0.01), r + 0.03, 0.08, swatch, segments=12, bevel=False)
    a = 0.6 + k
    d.box((x + r * math.cos(a) * 1.02, y + r * math.sin(a) * 1.02, z + h - 0.12), (0.12, 0.08, 0.28), swatch,
          bevel=False, rot=_RZ(math.degrees(a) + 90))                  # a drip over the rim
    d.box((x, y, z + h + 0.32), (2 * r - 0.04, 0.05, 0.05), "metal", bevel=False, rot=_RZ(20 * k))   # the handle
    for sx in (1, -1):
        d.box((x + sx * (r - 0.04) * math.cos(math.radians(20 * k)), y + sx * (r - 0.04) * math.sin(math.radians(20 * k)),
               z + h + 0.19), (0.07, 0.07, 0.3), "metal", bevel=False, rot=_RZ(20 * k))


def _planks(d):
    """Three planks leant on the door's right half."""
    face = -LEAF_T / 2 - 0.09                          # the door's room face, less half a plank
    for i, (x, foot, top) in enumerate(((1.0, -0.95, 5.6), (1.72, -1.05, 5.2), (2.38, -0.9, 4.8))):
        lean = math.atan2(face - foot, top)            # the top leans back onto the door
        d.box(((x, (foot + face) / 2, top / 2)), (0.62, 0.14, math.hypot(top, face - foot)),
              WOOD if i % 2 == 0 else WOOD2, rot=Matrix.Rotation(-lean, 3, "X"))


def _cone(d, x, y):
    d.box_base((x, y, -SINK), (0.9, 0.9, 0.14 + SINK), CONE)
    d.cyl_base((x, y, 0.1), 0.36, 1.3, CONE, segments=10, radius2=0.07, bevel=False)
    d.cyl_base((x, y, 0.62), 0.275, 0.26, "offwhite", segments=10, radius2=0.22, bevel=False)
    d.sphere((x, y, 1.44), 0.1, CONE, segments=6, rings=4)


def _barrier(name, mat):
    b = Builder()
    b.box_base((0.0, -1.45, -0.05), (5.5, 2.9, 12.0), "metal", bevel=False)
    ob = b.finalize(name + "_Barrier", mat, bevel=0)
    ob.hide_render = True
    return ob


def build_locked(mat):
    b, d = Builder(), Builder()
    _frame(b)
    _door(b, (-DOOR_W / 2 + 0.04, 0.0), 0)
    _tape(d, -2.95, 7.4, 2.95, 1.6)
    _tape(d, -2.95, 2.0, 2.95, 7.8, TAPE_Y - 0.09)       # in front of the first, so the crossing never flickers
    beam = _sawhorse(d, -1.75)
    _planks(d)
    _pot(d, -1.95, -2.35, -SINK, POTS[0], 0)
    _pot(d, -1.15, -2.55, -SINK + 0.002, POTS[1], 1)
    _pot(d, 1.1, -1.75, beam - 0.01, POTS[2], 2)
    _cone(d, 2.1, -2.35)
    return [_tris(b.finalize(LOCKED, mat)), _tris(d.finalize(LOCKED + "_Decor", mat)), _barrier(LOCKED, mat)]


def build_open(mat):
    b = Builder()
    _frame(b)
    # swung out into the yard on its left hinge and flat against the back of the wall, clear of the way through
    _door(b, (-DOOR_W / 2 + 0.04, 0.5 + LEAF_T / 2 + 0.02), -180 + 2)
    return [_tris(b.finalize(OPEN, mat))]


def locked_rbx_extras():
    return {"attachments": [(LOCKED, "PromptAnchor", Matrix.Translation((0.0, -3.1, 3.0)))],
            "attributes": {"Expansion": "BackDoor", "Locked": {"Bool": True}}}


def open_rbx_extras():
    return {"attributes": {"Expansion": "BackDoor", "Locked": {"Bool": False}}}


ASSETS = {LOCKED: (build_locked, 2200), OPEN: (build_open, 800)}
EXTRAS = {LOCKED: locked_rbx_extras, OPEN: open_rbx_extras}
