"""Customers' things and the spa's small props (issue #16).

  CleanACat_Prop_Carrier      the pet carrier a customer holds (reworked in #449, the owner on 2026-11-25: the old
                              one with its grey bars looked "depressing"). A little house with no bars: a tray with
                              a cushion, a shell with a sloped roof, a chunky handle and an open front (-Y) the
                              cat looks out of over a low scalloped gate with a paw print. The gate is its own
                              child Model, `..._Door_Swing`, pivoted at its hinge on the cat's left side (+X in
                              Blender): turn it about its pivot's up axis by up to 110 degrees to open it.
                              Attachment `CatSeat` on the tray: a walking cat's pivot goes there, facing out of the
                              front, at ScaleTo(CatScale) (root attribute, 0.7) so its ears stay under the roof.
                              Attachment `Grip` at the handle, 1.95 up, for welding it to a customer's hand (#446:
                              it was 2.66 up and the carrier 2.3 tall, too tall to hang from a hand). 1.36 wide,
                              2.0 long, 1.75 to the roof.
  CleanACat_Prop_CarrierSky   the same carrier in two more looks (CARRIERS below), so a line of customers is not
  CleanACat_Prop_CarrierButter  three of one thing: sky with cat ears and stars, butter with a paw badge. The first
                              is cream on a bubblegum tray with a bow and hearts.
  CleanACat_Prop_CarrierRoyal   the special customers' carrier (#476): lilac and gold with a crown on the roof
  CleanACat_Prop_StrayBox     a soft cardboard box with its flaps folded out and a bubblegum blanket inside;
                              `CatSeat` on the blanket for a sitting cat.
  CleanACat_Prop_ChanceBoard  a standing board on two legs by the entrance. Its face part is named `Screen` (front,
                              -Z in Roblox) for Design-Agent's SurfaceGui with the cats and their chances. The Model is
                              tagged `ChanceBoard` and streams in whole.
  CleanACat_Prop_QueueMat     a welcome mat with two paw prints, where a customer waits (put one at each SpotQueue).
  CleanACat_Prop_Cushion      a round pastel cushion for the display window, `CatSeat` on top for a sitting cat at
                              ScaleTo(CatScale) (root attribute, 1.3); one at each SpotWindow.
  CleanACat_Prop_TipJar       the window cats' tip jar: glass, a coin `Fill` the game sizes, a `Screen` label (SpotTipJar).
  CleanACat_Prop_WindowSign   the spa's name sign on the front wall, a `Screen` face for the name (SpotSign).
  CleanACat_Prop_BuildPad     where a locked station will go (#18): a cream floor square inside a dashed pastel tape
                              border, two cones at the front corners, a stack of planks and a small sign at the back
                              whose face is a `Screen` part (front, -Z in Roblox) for the station's name and price.
                              The size of a station pad (SpotStation2, SpotStation3); remove it when the station
                              is built there.

Pivots at the base centre on the floor, front -Y in Blender (-Z in Roblox), unless noted. Nothing here collides
except the chance board's legs and board.
"""

import math

from mathutils import Matrix, Vector

from common import Builder
from stations import _tris

# Carrier: outer size, shell and tray split
# #446: sized so a customer carries it at their side by the handle with a straight arm: the Grip is 1.95 up, under
# a 5 stud customer's hand, and the tray is low. (It was 1.6 x 2.5 x 2.3 with the Grip 2.66 up, which hung under the
# floor from any hand.)
CAR_W, CAR_L, CAR_H = 1.36, 2.0, 1.75
TRAY_H = 0.3
GRIP_H = CAR_H + 0.2    # the middle of the handle's grip, where a hand closes on it
CAT_SCALE = 0.7    # a walking cat rides at ScaleTo(0.7) so its ears stay under the roof (root attribute CatScale)


# The three carriers (#449): one build, a look each. Every look differs in shape as well as colour: the roof's
# ornament and what is on the sides. (shell, tray, gate and handle, cushion, accent, roof ornament, side shape)
CARRIERS = {
    "CleanACat_Prop_Carrier": ("spa_cream", "spa_bubblegum", "spa_mint", "pastel_butter", "bow_pink", "bow", "heart"),
    "CleanACat_Prop_CarrierSky": ("spa_sky", "spa_cream", "pastel_butter", "spa_bubblegum", "spa_cream", "ears",
                                  "star"),
    "CleanACat_Prop_CarrierButter": ("pastel_butter", "spa_mint", "spa_bubblegum", "spa_sky", "spa_cream", "none",
                                     "paw"),
    # the special customers' carrier (#476): lilac and gold, the game's prize colours. Since #486 it has no roof:
    # a special cat's head and back pieces stand taller and wider than a roof allows, and the prize shows on the way in
    "CleanACat_Prop_CarrierRoyal": ("pastel_lilac", "velvet_lilac", "gold_mid", "spa_bubblegum", "gold_mid", "open",
                                    "star"),
}
ROOF_FROM = 1.36        # where the side walls stop and the roof slopes in
ROOF_IN = 0.32         # how far each slope comes in by the top
GATE_H = 0.28          # the gate's straight part; three scallops stand on it
_FRONT = (math.radians(90), "X")           # a flat shape stood up to face the front


def _heart(b, x, y, z, size, sw, sx):
    """A heart `size` wide on the carrier's side at x: two discs and a square on its corner."""
    r = size * 0.27
    for dy in (-1, 1):                         # each piece its own depth, so no two faces share a plane
        b.cyl((x, y + dy * r * 0.86, z + r * 0.45), r, 0.05 + 0.008 * dy, sw, segments=8, bevel=False,
              rot=_on_side(sx))
    k = r * 1.7
    b.box((x, y, z - r * 0.33), (0.066, k, k), sw, bevel=False,
          rot=Matrix.Rotation(math.radians(45), 3, "X"))


def _on_side(sx):
    """Turns a flat shape drawn in (along, up) to face out of the carrier's side sx."""
    return Matrix.Rotation(math.radians(90 * sx), 3, "Z") @ Matrix.Rotation(math.radians(90), 3, "X")


def _carrier(name, mat):
    """A cosy carrier with no bars: the cat looks out of an open house-shaped front over a low scalloped gate."""
    shell, tray, trim, cushion, accent, roof, side = CARRIERS[name]
    w, ln, h = CAR_W, CAR_L, CAR_H
    wt = 0.12
    b = Builder()
    b.box_base((0, 0, 0), (w, ln, TRAY_H), tray)                                    # the tray
    b.box_base((0, 0, TRAY_H - 0.12), (w + 0.08, ln + 0.08, 0.1), "spa_cream")      # a cream lip round its top
    b.box_base((0, 0.0, TRAY_H - 0.06), (w - 0.36, ln - 0.4, 0.1), cushion)          # the cushion the cat stands on
    # the shell: two sides, two roof slopes, the roof and a back the shape of the front opening
    for sx in (1, -1):
        b.box_base((sx * (w / 2 - 0.02 - wt / 2), 0.06, TRAY_H - 0.05), (wt, ln - 0.14, ROOF_FROM - TRAY_H + 0.07),
                   shell, bevel=False)
        if roof == "open":                 # no roof (#486): a gold rail caps each wall and carries the handle's hoop
            b.box_base((sx * (w / 2 - 0.02 - wt / 2 + 0.035), 0.06, ROOF_FROM + 0.01), (wt + 0.07, ln - 0.08, 0.08), trim)
            b.box_base((sx * (w / 2 - 0.02 - wt / 2), 0.06, ROOF_FROM + 0.05), (0.15, 0.2, GRIP_H - ROOF_FROM - 0.07),
                       trim, bevel=False)
            continue
        run, rise = ROOF_IN, h - ROOF_FROM
        slope = math.atan2(rise, run)
        mid = (sx * (w / 2 - 0.02 - run / 2 - 0.045), 0.06, ROOF_FROM + rise / 2 - 0.03)
        b.box(mid, (math.hypot(run, rise) + 0.16, ln - 0.13, wt), shell, bevel=False,
              rot=Matrix.Rotation(sx * slope, 3, "Y"))
    if roof != "open":
        b.box_base((0, 0.06, h - wt), (w - 2 * ROOF_IN + 0.1, ln - 0.12, wt), shell)             # the roof
    x0, x1 = w / 2 - 0.08, w / 2 - ROOF_IN - 0.02
    z0, zs, z1 = TRAY_H - 0.06, ROOF_FROM, h - 0.06
    zm = (z0 + z1) / 2
    back = [(x0, z0 - zm), (x0, zs - zm), (x1, z1 - zm), (-x1, z1 - zm), (-x0, zs - zm), (-x0, z0 - zm)]
    b.prism((0, ln / 2 - wt / 2 - 0.02, zm), [(-x, z) for x, z in reversed(back)], wt, shell, rot=_FRONT)
    # the handle: two posts and a chunky grip
    if roof == "open":                     # the hoop's top bar: the same grip, as wide as the carrier
        b.box((0, 0.06, GRIP_H), (w + 0.06, 0.26, 0.16), trim)
        y, z = ln / 2 - wt / 2 - 0.02, h - 0.07                                    # a little crown on the headboard
        b.box_base((0, y, z), (0.5, 0.2, 0.13), accent, bevel=False)
        for dx, ht in ((-0.17, 0.16), (0.0, 0.24), (0.17, 0.16)):
            b.pyramid((dx, y, z + 0.13), 0.16, ht, accent)
        b.box((0, y - 0.105, z + 0.07), (0.09, 0.03, 0.09), "royal_berry", bevel=False,
              rot=Matrix.Rotation(math.radians(45), 3, "Y"))
    else:
        for sx in (1, -1):
            b.box_base((sx * 0.33, 0.06, h - 0.02), (0.15, 0.2, 0.17), trim, bevel=False)
        b.box((0, 0.06, GRIP_H), (0.9, 0.26, 0.16), trim)
    if roof == "bow":                                                              # a bow on the front of the roof
        y, z = -ln / 2 + 0.18, h + 0.09
        b.box((0, y, z), (0.18, 0.16, 0.18), accent)
        for sx in (1, -1):
            b.sphere((sx * 0.23, y, z + 0.03), 0.2, accent, segments=8, rings=4, scale=(1.0, 0.55, 0.75),
                     rot=Matrix.Rotation(math.radians(-16 * sx), 3, "Y"))
    elif roof == "ears":                                                           # two cat ears on the slopes
        for sx in (1, -1):
            tilt = Matrix.Rotation(math.radians(-14 * sx), 3, "Y")
            b.pyramid((sx * 0.34, -ln / 2 + 0.42, h - 0.08), 0.4, 0.44, shell, rot=tilt)
            b.pyramid((sx * 0.34, -ln / 2 + 0.31, h - 0.07), 0.23, 0.28, "spa_bubblegum", rot=tilt)
    elif roof == "crown":                                                          # a little crown on the roof's front
        y, z = -ln / 2 + 0.3, h - 0.01
        b.box_base((0, y, z), (0.5, 0.3, 0.13), accent, bevel=False)
        for dx, ht in ((-0.17, 0.16), (0.0, 0.24), (0.17, 0.16)):
            b.pyramid((dx, y, z + 0.13), 0.16, ht, accent)
        b.box((0, y - 0.155, z + 0.07), (0.09, 0.03, 0.09), "royal_berry", bevel=False,
              rot=Matrix.Rotation(math.radians(45), 3, "Y"))
    for sx in (1, -1):                                                             # what is on each side
        x, zc = sx * (w / 2 - 0.02 + 0.025), TRAY_H + 0.52
        if side == "heart":
            _heart(b, x, 0.12, zc, 0.52, accent, sx)
            _heart(b, x, -0.5, zc + 0.17, 0.26, "spa_mint", sx)
        elif side == "star":
            b.star((x, 0.0, zc), 0.36, 0.17, 0.05, accent, rot=_on_side(sx))
        else:                                                                      # a round badge with a paw print
            b.cyl((x, 0.1, zc), 0.36, 0.05, accent, segments=14, bevel=False, rot=_on_side(sx))
            px = sx * (w / 2 - 0.02 + 0.06)
            b.box((px, 0.1, zc - 0.07), (0.03, 0.26, 0.17), trim, bevel=False)
            for dy, dz in ((-0.18, 0.07), (-0.06, 0.16), (0.06, 0.16), (0.18, 0.07)):
                b.box((px, 0.1 + dy, zc + dz), (0.03, 0.095, 0.095), trim, bevel=False)
    main = _tris(b.finalize(name, mat))
    # the gate: built from its hinge (the cat's left front corner, +X), the far side at -dw. Low, so the cat's face
    # is in the open above it, with a scalloped top and a paw print
    d = Builder()
    dw = w - 0.24
    d.box((-dw / 2, 0, 0), (dw, 0.09, GATE_H), trim)
    for i in range(3):
        d.cyl((-dw * (2 * i + 1) / 6, 0.0, GATE_H / 2 - 0.02), dw / 6, 0.07, trim, segments=12, bevel=False,
              rot=_FRONT)
    d.box((-dw / 2, -0.055, -0.05), (0.22, 0.03, 0.15), "spa_cream", bevel=False)
    for dx, dz in ((-0.17, 0.05), (-0.06, 0.13), (0.06, 0.13), (0.17, 0.05)):
        d.box((-dw / 2 + dx, -0.055, -0.05 + dz), (0.08, 0.03, 0.08), "spa_cream", bevel=False)
    hinge = (w / 2 - 0.12, -ln / 2 + 0.075, TRAY_H + 0.03 + GATE_H / 2)              # on the shell's front face
    door = _tris(d.finalize(name + "_Door_Swing", mat, bevel=0, location=hinge))
    return [main, door]


def build_carrier(mat):
    return _carrier("CleanACat_Prop_Carrier", mat)


def carrier_rbx_extras(name="CleanACat_Prop_Carrier"):
    return {"attachments": [(name, "CatSeat", Matrix.Translation((0.0, 0.06, TRAY_H))),
                            (name, "Grip", Matrix.Translation((0.0, 0.06, GRIP_H)))],
            "attributes": {"DoorOpenDegrees": {"Float64": 110.0}, "CatScale": {"Float64": CAT_SCALE}}}


BOX = 1.8          # the stray box's outer width and depth
BOX_H = 0.85


def build_stray_box(mat):
    name = "CleanACat_Prop_StrayBox"
    b = Builder()
    t = 0.08
    b.box_base((0, 0, 0), (BOX - 0.04, BOX - 0.04, 0.1), "cardboard", bevel=False)  # floor, inside the walls
    for sy in (1, -1):
        b.box_base((0, sy * (BOX / 2 - t / 2), 0.02), (BOX - 0.02, t, BOX_H), "cardboard", bevel=False)
    for sx in (1, -1):
        b.box_base((sx * (BOX / 2 - t / 2), 0, 0.03), (t, BOX - 2 * t + 0.04, BOX_H - 0.02), "cardboard", bevel=False)
    for sx, sy, ax in ((0, -1, "X"), (0, 1, "X"), (-1, 0, "Y"), (1, 0, "Y")):      # flaps folded out and down
        ang = math.radians(-35 if ax == "X" else 35) * (sy or sx)
        rot = Matrix.Rotation(ang * (-1 if ax == "Y" else 1), 3, ax)
        flap = (BOX - 0.06, 0.55, 0.05) if ax == "X" else (0.55, BOX - 0.1, 0.05)
        off = 0.2                                                                   # hinged on the wall top
        b.box((sx * (BOX / 2 + off), sy * (BOX / 2 + off), BOX_H - 0.14), flap, "cardboard", bevel=False, rot=rot)
    b.box_base((0, 0, 0.09), (BOX - 2 * t - 0.04, BOX - 2 * t - 0.04, 0.22), "spa_bubblegum")      # the blanket
    b.box((0.35, -0.6, 0.38), (0.6, 0.3, 0.2), "spa_bubblegum", rot=Matrix.Rotation(math.radians(20), 3, "Z"))  # a fold
    return [_tris(b.finalize(name, mat))]


def stray_box_rbx_extras():
    return {"attachments": [("CleanACat_Prop_StrayBox", "CatSeat", Matrix.Translation((0.0, 0.0, 0.31)))]}


BOARD_W, BOARD_H, BOARD_Z = 4.0, 3.2, 2.2      # the board, and how high its bottom edge stands


def build_chance_board(mat):
    name = "CleanACat_Prop_ChanceBoard"
    b = Builder()
    for sx in (1, -1):                                                              # two legs with feet
        b.box_base((sx * (BOARD_W / 2 - 0.35), 0.05, 0.02), (0.25, 0.25, BOARD_Z + BOARD_H - 0.22), "wood_light")
        b.box_base((sx * (BOARD_W / 2 - 0.35), 0.05, 0), (0.45, 1.1, 0.12), "wood_light", bevel=False)
    b.box_base((0, 0.1, BOARD_Z), (BOARD_W, 0.26, BOARD_H), "spa_bubblegum")       # the frame
    b.box_base((0, 0.1, BOARD_Z + BOARD_H - 0.02), (BOARD_W * 0.6, 0.2, 0.5), "spa_mint")   # a header
    main = b.finalize(name, mat)
    s = Builder()
    s.box_base((0, -0.04, BOARD_Z + 0.18), (BOARD_W - 0.36, 0.06, BOARD_H - 0.36), "offwhite", bevel=False)
    screen = s.finalize(name + "_Screen", mat, bevel=0)
    return [main, screen]


def build_queue_mat(mat):
    name = "CleanACat_Prop_QueueMat"
    b = Builder()
    b.box_base((0, 0, 0), (2.4, 1.6, 0.08), "spa_bubblegum")
    for x, y, turn in ((-0.45, 0.15, 10), (0.45, -0.2, -10)):                       # two paw prints
        R = Matrix.Rotation(math.radians(turn), 3, "Z")
        b.box_base((x, y, 0.06), (0.36, 0.3, 0.04), "offwhite", bevel=False, rot=R)
        for i, (tx, ty) in enumerate(((-0.17, -0.26), (0.0, -0.32), (0.17, -0.26))):
            p = R @ Vector((tx, ty, 0))
            b.box_base((x + p.x, y + p.y, 0.06), (0.11, 0.11, 0.04 + 0.002 * i), "offwhite", bevel=False, rot=R)
    return [b.finalize(name, mat)]


CUSHION_R, CUSHION_H = 1.15, 0.38
WINDOW_CAT_SCALE = 1.3   # window cats sit at ScaleTo(1.3) so they read from the street and the next plot (CatScale)


def build_cushion(mat):
    """A round pastel cushion for the display window (#17): a fat pad with a puffed top and four tassels."""
    name = "CleanACat_Prop_Cushion"
    b = Builder()
    b.cyl_base((0, 0, 0), CUSHION_R, CUSHION_H - 0.12, "spa_bubblegum", segments=12, bevel=False)
    b.cyl_base((0, 0, CUSHION_H - 0.14), CUSHION_R - 0.06, 0.13, "spa_bubblegum", segments=12, radius2=CUSHION_R - 0.32,
               bevel=False)                                                         # the puffed top
    b.cyl_base((0, 0, CUSHION_H - 0.03), 0.16, 0.04, "spa_cream", segments=8, bevel=False)   # the button
    for a in range(4):                                                              # tassels round the edge
        t = math.radians(45 + 90 * a)
        b.sphere((math.cos(t) * (CUSHION_R - 0.02), math.sin(t) * (CUSHION_R - 0.02), 0.16), 0.11, "spa_cream",
                 segments=6, rings=4)
    return [_tris(b.finalize(name, mat))]


def cushion_rbx_extras():
    return {"attachments": [("CleanACat_Prop_Cushion", "CatSeat", Matrix.Translation((0.0, 0.0, CUSHION_H - 0.03)))],
            "attributes": {"CatScale": {"Float64": WINDOW_CAT_SCALE}}}


BED_R = 1.1              # the basket's outer radius: 2.2 wide in a 2.5 stretch of wall
BED_BASE, BED_PAD = 0.14, 0.22
BED_RIM = (0.24, 0.5)    # the plush rim: how thick, how high
BED_SEAT = BED_BASE - 0.02 + BED_PAD    # the pad's top, where he sits
BED_SIT = (-0.18, -0.06) # his seat off the basket's middle: a sitting cat's tail curls round his left side, so
                         # he sits a little to his right and the tail lies inside the rim, not through it
BED_CAT_SCALE = 1.2      # the mascot sits a little bigger than life, so he reads from the tub and from the street
BED = "CleanACat_Prop_SudsBed"


def build_suds_bed(mat):
    """The mascot's bed (#297, a basket since #333): a low round basket with a cream base, a plush mint rim and a
    bubblegum pad, and a gold bell on the front of the rim like the one on his collar. It stands on the floor just
    inside the entrance, between the door and the chance board (SpotMascot). The first bed stood on a post and read
    as a cake stand; low on the floor it reads as a cat bed at once."""
    rim_t, rim_h = BED_RIM
    rim_z = BED_BASE - 0.01 + rim_h / 2
    b = Builder()
    b.cyl_base((0, 0, 0), BED_R - 0.06, BED_BASE, "spa_cream", segments=14, bevel=False)             # the base
    b.ring((0, 0, rim_z), BED_R, rim_t, rim_h, "spa_mint", segments=14)                              # the rim
    b.cyl_base((0, 0, BED_BASE - 0.02), BED_R - rim_t + 0.03, BED_PAD, "spa_bubblegum", segments=14, bevel=False)   # the pad
    b.box((0, -BED_R - 0.02, rim_z + 0.06), (0.14, 0.1, 0.14), "spa_cream", bevel=False)             # the bell's loop
    b.sphere((0, -BED_R - 0.09, rim_z - 0.1), 0.17, "fur_golden", segments=8, rings=5)
    b.box((0, -BED_R - 0.23, rim_z - 0.16), (0.04, 0.07, 0.1), "fur_brown", bevel=False)             # its slot
    return [_tris(b.finalize(BED, mat))]


def suds_bed_rbx_extras():
    return {"attachments": [(BED, "CatSeat", Matrix.Translation((*BED_SIT, BED_SEAT)))],
            "attributes": {"CatScale": {"Float64": BED_CAT_SCALE}}}


JAR = (0.9, 0.9, 1.2)    # the glass jar's outer size
JAR_WALL = 0.06


def build_tip_jar(mat):
    """The tip jar (#17): a square glass jar (its own part, `_Glass`, 0.6 see-through, one box), a gold coin fill (`Fill`, a
    Block the game sizes from empty to full: its bottom stays at the root attribute FillBottom and its full height is
    FillHeight; keep it hidden when empty), a mint lid and a cream label on the front (`Screen`, for a SurfaceGui with
    the count)."""
    name = "CleanACat_Prop_TipJar"
    w, d, h = JAR
    b = Builder()
    b.box_base((0, 0, 0), (w + 0.08, d + 0.08, 0.1), "spa_mint", bevel=False)       # the base
    b.cyl_base((0, 0, h + 0.07), 0.42, 0.16, "spa_mint", segments=12, bevel=False)  # the lid
    b.box_base((0, 0, h + 0.2), (0.2, 0.2, 0.12), "spa_mint", bevel=False)          # the knob
    main = _tris(b.finalize(name, mat))
    g = Builder()
    g.box_base((0, 0, 0.09), (w, d, h - 0.02), "glass", bevel=False)                # one box: see-through parts must
    # never overlap (#176, #235). A rim under the lid used to sit 0.02 inside this box; it was hidden but for a sliver.
    glass = g.finalize(name + "_Glass", mat, bevel=0)
    f = Builder()
    f.box_base((0, 0, FILL_BOTTOM), (w - 2 * JAR_WALL, d - 2 * JAR_WALL, FILL_HEIGHT), "gold_mid", bevel=False)
    fill = f.finalize(name + "_Fill", mat, bevel=0)
    s = Builder()
    s.box_base((0, -d / 2 - 0.025, 0.35), (0.62, 0.04, 0.42), "spa_cream", bevel=False)
    screen = s.finalize(name + "_Screen", mat, bevel=0)
    return [main, glass, fill, screen]


FILL_BOTTOM = 0.08                      # sunk a hair into the base, inside the glass
FILL_HEIGHT = 0.8                       # full: a little under the jar's shoulder


def tip_jar_rbx_extras():
    return {"attributes": {"FillBottom": {"Float64": FILL_BOTTOM}, "FillHeight": {"Float64": FILL_HEIGHT}}}


SIGN_W, SIGN_H = 6.0, 2.4


SIGN_EDGE = 0.45      # the dark frame showing round the face on every side


def build_window_sign(mat):
    """The spa's name sign on the front wall (#17): a framed board with two brackets and a cream face named `Screen`
    (front, -Z in Roblox) for a SurfaceGui with the player's spa name. Pivot at the middle of its back, which goes
    flat on the wall at the plot's SpotSign.

    The frame is navy with a thin mint lip inside it (#360). It was mint, and on the bubblegum wall the whole sign
    was pastel on pastel: a Studio check measured the cream face at 1.6 to 1 against the wall, sky on or off. No pale
    colour can reach 3 to 1 against that pink (white itself is 1.7 to 1), so the face stays cream for dark name text
    and the frame carries the contrast: navy is over 6 to 1 against the wall and over 9 to 1 against the face. The
    face is the size it was, so a SurfaceGui laid out for it still fits."""
    name = "CleanACat_Prop_WindowSign"
    fw, fh = SIGN_W - 0.5, SIGN_H - 0.5                                             # the face
    b = Builder()
    b.box((0, -0.18, 0), (fw + 2 * SIGN_EDGE, 0.3, fh + 2 * SIGN_EDGE), "pants_navy")   # the frame
    b.box((0, -0.31, 0), (fw + 0.24, 0.06, fh + 0.24), "spa_mint", bevel=False)     # the lip round the face
    for sx in (1, -1):                                                              # brackets into the wall
        b.box((sx * (SIGN_W / 2 - 0.6), -0.02, 0), (0.3, 0.06, SIGN_H - 0.6), "metal", bevel=False)
    main = b.finalize(name, mat)
    s = Builder()
    s.box((0, -0.35, 0), (fw, 0.06, fh), "spa_cream", bevel=False)
    screen = s.finalize(name + "_Screen", mat, bevel=0)
    return [main, screen]


PAD = 4.8          # the build pad's side, just inside the plot's 5 stud station pad
PAD_H = 0.1


def _cone(b, x, y):
    b.box_base((x, y, PAD_H - 0.025), (0.72, 0.72, 0.105), "spa_bubblegum", bevel=False)
    b.cyl_base((x, y, PAD_H + 0.07), 0.3, 1.0, "spa_bubblegum", segments=10, radius2=0.06, bevel=False)
    b.cyl_base((x, y, PAD_H + 0.44), 0.225, 0.18, "offwhite", segments=10, radius2=0.182, bevel=False)   # a band


def build_build_pad(mat):
    name = "CleanACat_Prop_BuildPad"
    b = Builder()
    b.box_base((0, 0, 0), (PAD, PAD, PAD_H), "spa_cream", bevel=False)            # the floor square
    n, t = 5, 0.28                                                                  # tape: 5 dashes a side
    for side in range(4):
        ln = PAD - 0.2 if side < 2 else PAD - 0.2 - 2 * t - 0.08                    # left and right stop short
        step = ln / n
        for i in range(n):
            c = -ln / 2 + step * (i + 0.5)
            sw = "spa_bubblegum" if (i + side) % 2 else "pastel_butter"
            off = PAD / 2 - 0.1 - t / 2
            if side < 2:
                at, size = (c, (1 if side else -1) * off, PAD_H - 0.01), (step - 0.05, t, 0.04)
            else:
                at, size = ((1 if side == 3 else -1) * off, c, PAD_H - 0.01), (t, step - 0.05, 0.04)
            b.box_base(at, size, sw, bevel=False)
    for sx in (1, -1):
        _cone(b, sx * 1.75, -1.75)
    for i in range(3):                                                              # a stack of planks
        rot = Matrix.Rotation(math.radians(8 * (i - 1)), 3, "Z")
        b.box_base((1.3, 0.75, PAD_H + 0.015 + 0.15 * i), (1.6, 0.42, 0.16), "wood_light", bevel=False,
                   rot=rot)
    for sx in (1, -1):                                                              # the sign's posts
        b.box_base((sx * 0.85, 1.75, PAD_H - 0.02), (0.16, 0.16, 1.96), "wood_light", bevel=False)
    b.box_base((0, 1.75, 0.95), (2.1, 0.18, 1.15), "spa_mint")                      # the board
    main = _tris(b.finalize(name, mat))
    s = Builder()
    s.box_base((0, 1.64, 1.04), (1.86, 0.05, 0.97), "offwhite", bevel=False)
    screen = s.finalize(name + "_Screen", mat, bevel=0)
    return [main, screen]


CAMERA = "CleanACat_Prop_PhotoCamera"
CAM_BODY = (1.4, 0.7, 0.9)       # the camera's body: wide, deep, high (the placeholder block was 1.4 x 1 x 1)
CAM_Z = 2.45                     # the body's middle over the floor: where the placeholder's middle was
CAM_FEET = 0.72                  # how far each tripod foot stands from the middle


def build_photo_camera(mat):
    """The photo step's camera (#344): a small friendly camera on a short tripod beside the tub, the thing the
    player taps to take the after photo. It stood in as a plain block (PH_Buttons.Camera), which the owner saw on dev
    as a black block. Cream body with a bubblegum top, a mint lens ring round a dark lens with a glint, a butter
    flash and a gold shutter button. No writing, no brand. Pivot at the base centre, the lens at the front (-Z in
    Roblox). Attachment `Tap` at the body's middle."""
    w, d, h = CAM_BODY
    top, bottom, front = CAM_Z + h / 2, CAM_Z - h / 2, -d / 2
    quarter = (math.radians(90), "X")                  # lays a cylinder along the front to back line
    b = Builder()
    hub = Vector((0.0, 0.0, bottom - 0.3))
    for i in range(3):                                 # one leg to the back, two to the front corners
        a = math.radians(90 + 120 * i)
        foot = Vector((CAM_FEET * math.cos(a), CAM_FEET * math.sin(a), 0.0))
        end = foot + Vector((0.0, 0.0, 0.09))          # the leg stops inside its foot, clear of the floor
        way = (end - hub).normalized()
        side = Vector((0, 0, 1)).cross(way).normalized()
        rot = Matrix((side, way.cross(side), way)).transposed().to_4x4()
        length = (end - hub).length
        b.box(tuple(hub + way * (length / 2)), (0.13, 0.13, length), "wood_light", bevel=False, rot=rot)
        b.cyl_base((foot.x, foot.y, 0.0), 0.13, 0.14, "spa_mint", segments=8, bevel=False)
    b.cyl_base((0, 0, hub.z - 0.1), 0.2, 0.2, "spa_mint", segments=10, bevel=False)             # the tripod's head
    b.cyl_base((0, 0, hub.z + 0.08), 0.1, bottom - hub.z - 0.07, "spa_cream", segments=8, bevel=False)   # its post
    b.box((0, 0, CAM_Z), (w, d, h), "spa_cream")
    b.box((0, 0, top - 0.11), (w + 0.04, d + 0.04, 0.24), "spa_bubblegum")                      # the top band
    b.cyl((0.12, front - 0.07, CAM_Z - 0.08), 0.36, 0.18, "spa_mint", segments=14, rot=quarter)  # the lens ring
    b.cyl((0.12, front - 0.2, CAM_Z - 0.08), 0.27, 0.14, "spa_sky", segments=14, bevel=False, rot=quarter)
    b.cyl((0.12, front - 0.28, CAM_Z - 0.08), 0.19, 0.05, "fur_black", segments=14, bevel=False, rot=quarter)
    b.box((0.05, front - 0.31, CAM_Z - 0.01), (0.08, 0.02, 0.08), "fur_white", bevel=False)     # the glint
    b.box((-0.48, front - 0.02, top - 0.11), (0.26, 0.05, 0.14), "spa_sky", bevel=False)        # the viewfinder
    b.box_base((-0.4, 0.02, top), (0.42, 0.36, 0.2), "pastel_butter")                           # the flash
    b.box((-0.4, -0.17, top + 0.1), (0.3, 0.03, 0.12), "fur_white", bevel=False)                # its face
    b.cyl_base((0.42, 0.0, top), 0.12, 0.1, "fur_golden", segments=10, bevel=False)             # the shutter button
    return [_tris(b.finalize(CAMERA, mat))]


def photo_camera_rbx_extras():
    return {"attachments": [(CAMERA, "Tap", Matrix.Translation((0.0, 0.0, CAM_Z)))]}


ASSETS = {
    "CleanACat_Prop_BuildPad": (build_build_pad, 600),
    "CleanACat_Prop_Cushion": (build_cushion, 300),
    "CleanACat_Prop_TipJar": (build_tip_jar, 400),
    "CleanACat_Prop_WindowSign": (build_window_sign, 300),
    "CleanACat_Prop_Carrier": (build_carrier, 950),
    "CleanACat_Prop_CarrierSky": (lambda mat: _carrier("CleanACat_Prop_CarrierSky", mat), 950),
    "CleanACat_Prop_CarrierButter": (lambda mat: _carrier("CleanACat_Prop_CarrierButter", mat), 950),
    "CleanACat_Prop_CarrierRoyal": (lambda mat: _carrier("CleanACat_Prop_CarrierRoyal", mat), 950),
    "CleanACat_Prop_StrayBox": (build_stray_box, 200),
    "CleanACat_Prop_ChanceBoard": (build_chance_board, 400),
    "CleanACat_Prop_QueueMat": (build_queue_mat, 200),
    BED: (build_suds_bed, 800),
    CAMERA: (build_photo_camera, 700),
}
EXTRAS = {"CleanACat_Prop_Carrier": carrier_rbx_extras,
          "CleanACat_Prop_CarrierSky": lambda: carrier_rbx_extras("CleanACat_Prop_CarrierSky"),
          "CleanACat_Prop_CarrierButter": lambda: carrier_rbx_extras("CleanACat_Prop_CarrierButter"),
          "CleanACat_Prop_CarrierRoyal": lambda: carrier_rbx_extras("CleanACat_Prop_CarrierRoyal"),
          "CleanACat_Prop_StrayBox": stray_box_rbx_extras,
          "CleanACat_Prop_Cushion": cushion_rbx_extras, "CleanACat_Prop_TipJar": tip_jar_rbx_extras,
          BED: suds_bed_rbx_extras, CAMERA: photo_camera_rbx_extras}
