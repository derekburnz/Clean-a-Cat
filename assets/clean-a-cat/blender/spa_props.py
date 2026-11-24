"""Customers' things and the spa's small props (issue #16).

  CleanACat_Prop_Carrier      a rounded pet carrier a customer holds: a bubblegum tray, a cream shell with side vents,
                              a handle on top and a grille door at the front (-Y). The door is its own child Model,
                              `..._Door_Swing`, pivoted at its hinge on the cat's left side (+X in Blender): turn it
                              about its pivot's up axis by up to 110 degrees to open it. Attachment `CatSeat` on the
                              tray: a walking cat's pivot goes there, facing out of the door, at ScaleTo(CatScale)
                              (root attribute, 0.8) so it fits under the shell and shows through the grille.
                              Attachment `Grip` at the handle, for welding it to a customer's hands.
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
CAR_W, CAR_L, CAR_H = 1.6, 2.5, 2.3
TRAY_H = 0.7
CAT_SCALE = 0.8    # a walking cat rides at ScaleTo(0.8) so its ears stay under the shell (root attribute CatScale)


def build_carrier(mat):
    name = "CleanACat_Prop_Carrier"
    w, ln, h = CAR_W, CAR_L, CAR_H
    b = Builder()
    b.box_base((0, 0, 0), (w, ln, TRAY_H), "spa_bubblegum")                         # the tray
    # the shell: open at the front behind the grille so the cat shows; roof, back and two sides
    sh, wt = h - TRAY_H + 0.06, 0.12
    b.box_base((0, 0.06, h - wt), (w - 0.04, ln - 0.12, wt), "spa_cream")                       # roof
    b.box_base((0, ln / 2 - wt / 2, TRAY_H - 0.06), (w - 0.06, wt, sh - wt + 0.03), "spa_cream", bevel=False)  # back
    for sx in (1, -1):
        b.box_base((sx * (w / 2 - 0.02 - wt / 2), 0.06, TRAY_H - 0.05), (wt, ln - 0.14, sh - wt + 0.02), "spa_cream",
                   bevel=False)
    for sx in (1, -1):                                                              # side vents: three slots
        for i in range(3):
            b.box((sx * (w / 2 - 0.015), 0.35 + 0.45 * (i - 1), TRAY_H + 0.85), (0.04, 0.2, 0.55), "spa_mint",
                  bevel=False)
    for sx in (1, -1):                                                              # handle posts and grip
        b.box_base((sx * 0.38, 0.06, h - 0.02), (0.14, 0.2, 0.32), "spa_mint", bevel=False)
    b.box((0, 0.06, h + 0.36), (0.9, 0.22, 0.14), "spa_mint")
    main = _tris(b.finalize(name, mat))
    # the door: a grille built from its hinge (the cat's left front corner, +X), the far side at -dw
    d = Builder()
    dw, dh = w - 0.24, h - TRAY_H - 0.28
    for x in (-0.05, -dw + 0.05):                                                   # the two sides
        d.box((x, 0, 0), (0.1, 0.08, dh), "metal", bevel=False)
    for z in (dh / 2 - 0.06, -dh / 2 + 0.06):                                       # top and bottom, inside the sides
        d.box((-dw / 2, 0, z), (dw - 0.18, 0.07, 0.1), "metal", bevel=False)
    for i in range(1, 5):                                                           # four bars
        d.box((-dw * i / 5, 0, 0), (0.05, 0.05, dh - 0.2), "metal", bevel=False)
    hinge = (w / 2 - 0.12, -ln / 2 + 0.075, TRAY_H + 0.14 + dh / 2)                  # on the shell's front face
    door = d.finalize(name + "_Door_Swing", mat, bevel=0, location=hinge)
    return [main, door]


def carrier_rbx_extras():
    return {"attachments": [("CleanACat_Prop_Carrier", "CatSeat", Matrix.Translation((0.0, 0.06, TRAY_H))),
                            ("CleanACat_Prop_Carrier", "Grip", Matrix.Translation((0.0, 0.06, CAR_H + 0.36)))],
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


def build_window_sign(mat):
    """The spa's name sign on the front wall (#17): a bubblegum board with a mint frame, two brackets, and a cream
    face named `Screen` (front, -Z in Roblox) for a SurfaceGui with the player's spa name. Pivot at the middle of its
    back, which goes flat on the wall at the plot's SpotSign."""
    name = "CleanACat_Prop_WindowSign"
    b = Builder()
    b.box((0, -0.18, 0), (SIGN_W, 0.3, SIGN_H), "spa_mint")                        # the frame
    for sx in (1, -1):                                                              # brackets into the wall
        b.box((sx * (SIGN_W / 2 - 0.6), -0.02, 0), (0.3, 0.06, SIGN_H - 0.6), "metal", bevel=False)
    main = b.finalize(name, mat)
    s = Builder()
    s.box((0, -0.35, 0), (SIGN_W - 0.5, 0.06, SIGN_H - 0.5), "spa_cream", bevel=False)
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


ASSETS = {
    "CleanACat_Prop_BuildPad": (build_build_pad, 600),
    "CleanACat_Prop_Cushion": (build_cushion, 300),
    "CleanACat_Prop_TipJar": (build_tip_jar, 400),
    "CleanACat_Prop_WindowSign": (build_window_sign, 300),
    "CleanACat_Prop_Carrier": (build_carrier, 400),
    "CleanACat_Prop_StrayBox": (build_stray_box, 200),
    "CleanACat_Prop_ChanceBoard": (build_chance_board, 400),
    "CleanACat_Prop_QueueMat": (build_queue_mat, 200),
}
EXTRAS = {"CleanACat_Prop_Carrier": carrier_rbx_extras, "CleanACat_Prop_StrayBox": stray_box_rbx_extras,
          "CleanACat_Prop_Cushion": cushion_rbx_extras, "CleanACat_Prop_TipJar": tip_jar_rbx_extras}
