"""The opening scene's props (issue #279). The owner, 2026-11-24: a truck drives past the spa, hits a bump, "a box
falls off the back and lands in-front of you on the street you open it" and a muddy stray is inside, who becomes Suds
the mascot once he is washed. "should be a random brown box".

  CleanACat_Prop_DeliveryTruck  a small pastel delivery truck, our own design, no brand and no writing: a butter
                                cab, a cream cargo box with a sky stripe and a parcel picture on each side. About 6
                                wide, 7.6 tall and 13 long, so it fits one 10 stud lane. Pivot on the ground under
                                its middle, nose at -Y in Blender (-Z in Roblox). Its pieces, each a child Model:
                                  ..._Door                      the one rear door, hinged along its top edge (its
                                                                pivot is the middle of the hinge): turn it about
                                                                its pivot's X axis and it flaps up and out
                                  ..._FL_Wheel, _FR_Wheel, _BL_Wheel, _BR_Wheel   pivoted at the axle, spin about X
                                The cargo box is hollow with a dark lining; Attachment `Tailgate` on the Body at the
                                rear edge of the cargo floor, where the box leaves. Root attribute DoorOpenDegrees.
  CleanACat_Prop_DeliveryBox    a plain brown cardboard box, built shut, no writing: 2.4 wide, 2.4 deep, 1.8 tall.
                                Pivot at the bottom centre. Four flaps, each a child Model pivoted at the middle of
                                its hinge on the rim: ..._FlapL and ..._FlapR (the big two on top, meeting in the
                                middle under a strip of tape) and ..._FlapF and ..._FlapB (the short two under them).
                                Each flap's pivot has its X pointing from the hinge into the box and its Y up, so
                                every flap opens with the same turn: FlapOpenDegrees (root attribute) about the
                                pivot's own Z. Open the big two first. Attachments on the Body: `CatSeat` on the box floor (a sitting cat
                                at scale 1 is hidden under the shut flaps) and `Peek` at the rim, where the cat's
                                chest rises to when it looks out.
  CleanACat_Prop_SpeedBump      a striped hump one lane wide (10 by 1.4, 0.35 high) for the road, pivot at the base
                                centre: the bump the truck jolts over.
  CleanACat_Prop_Pothole        the owner, after his dev test: "speed bump should be changed to pothole". A broken
                                patch of road about 3.3 by 2.5: a dark hole floor with a muddy puddle, a rim of
                                cracked road chunks standing up to 0.12 over the road, cracks running out and a few
                                crumbs. It lies on the road top (the road is one block, so nothing is cut out of
                                it); the raised rim round the dark middle is what reads as depth. Pivot at the base
                                centre. It takes the speed bump's place in the opening; the bump stays until no code
                                clones it.

Nothing here collides except the truck's body and the speed bump. The truck and the box stream in whole
(rbx_export.MODEL_PROPS), because the scene turns their pieces.
"""

import math

from mathutils import Matrix, Vector

from common import Builder
from stations import _tris

TRUCK, BOX, BUMP = "CleanACat_Prop_DeliveryTruck", "CleanACat_Prop_DeliveryBox", "CleanACat_Prop_SpeedBump"
POTHOLE = "CleanACat_Prop_Pothole"

# -- the truck -------------------------------------------------------------------------------------------------------
T_W, T_L, T_H = 6.0, 13.0, 7.6
NOSE, REAR = -T_L / 2, T_L / 2
WHEEL_R, WHEEL_W = 1.1, 0.9
WHEELS = {"FL": (1, -3.9), "FR": (-1, -3.9), "BL": (1, 3.4), "BR": (-1, 3.4)}     # the truck's left is +X, like a cat's
WHEEL_X = T_W / 2 - WHEEL_W / 2 - 0.03
WHEEL_SEG = 14
AXLE_Z = WHEEL_R * math.cos(math.pi / WHEEL_SEG)     # the tyre is drawn with a flat on the road
CAB_END = -2.9                    # where the cab stops and the cargo box starts
FLOOR_Z = 1.95                    # the cargo floor's top
WALL = 0.25
DOOR_Z = T_H - 0.42               # the hinge line
DOOR_OPEN = 75.0
X90 = (math.radians(90), "X")
Y90 = (math.radians(90), "Y")


def _wheel(mat, name, side):
    b = Builder()
    b.cyl((0, 0, 0), WHEEL_R, WHEEL_W, "fur_black", segments=WHEEL_SEG, rot=Y90)
    b.cyl((side * 0.06, 0, 0), 0.56, WHEEL_W, "spa_cream", segments=10, bevel=False, rot=Y90)   # the hub, proud outside
    b.cyl((side * 0.1, 0, 0), 0.2, WHEEL_W, "pastel_butter", segments=8, bevel=False, rot=Y90)
    return b


def build_truck(mat):
    w = T_W / 2
    b = Builder()
    b.box((0, 0.05, 1.42), (T_W - 1.9, T_L - 0.5, 0.62), "concrete_dark", bevel=False)            # the chassis
    # the cab: a low nose and the cabin set back on it
    cab, sky = "pastel_butter", "pastel_sky"
    b.box_base((0, (NOSE + CAB_END) / 2 + 0.05, 1.5), (T_W - 0.2, CAB_END - NOSE - 0.1, 2.0), cab)
    b.box_base((0, (NOSE + CAB_END) / 2 + 0.38, 3.46), (T_W - 0.3, CAB_END - NOSE - 0.86, 2.2), cab)
    b.box_base((0, (NOSE + CAB_END) / 2 + 0.38, 5.62), (T_W - 0.7, CAB_END - NOSE - 1.3, 0.16), "spa_cream")   # roof cap
    front = NOSE + 0.72                                                                          # the cabin's front face
    b.box((0, front - 0.02, 4.62), (T_W - 1.1, 0.1, 1.5), sky, bevel=False)                      # windscreen
    b.box((-1.2, front - 0.05, 4.95), (1.3, 0.06, 0.2), "foam", bevel=False,
          rot=Matrix.Rotation(math.radians(-20), 3, "Y"))                                        # its glint
    for sx in (1, -1):
        b.box((sx * (w - 0.13), -4.3, 4.62), (0.1, 1.9, 1.4), sky, bevel=False)                  # side windows
        b.box((sx * (w - 0.11), -4.3, 3.0), (0.08, 0.5, 0.14), "spa_cream", bevel=False)         # door handles
        b.box((sx * (w - 0.05), front + 0.25, 4.5), (0.34, 0.14, 0.7), "spa_cream")              # mirrors
        b.cyl((sx * 1.85, NOSE + 0.07, 2.75), 0.42, 0.16, "foam", segments=10, bevel=False, rot=X90)   # headlamps
        b.cyl((sx * 1.85, NOSE + 0.03, 2.75), 0.27, 0.16, "lamp_warm", segments=10, bevel=False, rot=X90)
    b.box((0, NOSE + 0.08, 2.72), (1.7, 0.12, 0.5), "spa_cream", bevel=False)                    # grille
    for i in (-1, 0, 1):
        b.box((i * 0.5, NOSE + 0.045, 2.72), (0.14, 0.1, 0.32), "concrete_dark", bevel=False)
    b.box((0, NOSE - 0.02, 1.72), (T_W - 0.1, 0.36, 0.5), "spa_cream")                           # front bumper
    # the cargo box: floor, roof, front wall and two sides, hollow, open at the rear
    y0, ln = CAB_END + 0.2, REAR - (CAB_END + 0.2)
    yc = y0 + ln / 2
    body = "spa_cream"
    b.box_base((0, yc, 1.7), (T_W, ln, FLOOR_Z - 1.7), body, bevel=False)                        # floor
    b.box_base((0, yc, T_H - WALL), (T_W, ln, WALL), body)                                       # roof
    b.box_base((0, y0 + WALL / 2, FLOOR_Z - 0.02), (T_W - 0.02, WALL, T_H - WALL - FLOOR_Z + 0.04), body, bevel=False)
    for sx in (1, -1):
        b.box_base((sx * (w - WALL / 2), yc + 0.01, FLOOR_Z - 0.03), (WALL, ln - 0.02, T_H - WALL - FLOOR_Z + 0.06), body,
                   bevel=False)
    lin, li = "fur_slate", 0.03                                                                  # the dark lining
    hold_h = T_H - WALL - FLOOR_Z
    b.box_base((0, yc + 0.1, FLOOR_Z), (T_W - 2 * WALL - 0.02, ln - WALL - 0.24, li), "concrete_dark", bevel=False)
    b.box((0, yc + 0.1, T_H - WALL - li / 2), (T_W - 2 * WALL - 0.03, ln - WALL - 0.26, li), lin, bevel=False)
    b.box_base((0, y0 + WALL + li / 2, FLOOR_Z + li), (T_W - 2 * WALL - 0.04, li, hold_h - 2 * li - 0.01), lin, bevel=False)
    for sx in (1, -1):
        b.box_base((sx * (w - WALL - li / 2), yc + 0.11, FLOOR_Z + li + 0.004), (li, ln - WALL - 0.28, hold_h - 2 * li - 0.02),
                   lin, bevel=False)
    for sx in (1, -1):                                                                           # the sides' paint
        xs = sx * (w + 0.02)
        b.box((xs, yc, 2.75), (0.06, ln - 0.5, 0.5), "spa_sky", bevel=False)                     # a stripe
        b.box((xs, yc + 0.3, 5.1), (0.07, 2.2, 1.8), "cardboard", bevel=False)                   # a parcel picture:
        b.box((xs + sx * 0.008, yc + 0.3, 5.86), (0.07, 2.36, 0.3), "fur_latte", bevel=False)      # its lid, a little wider
        b.box((xs + sx * 0.016, yc + 0.3, 5.58), (0.07, 0.4, 0.78), "paving_sand", bevel=False)    # the tape's end
    for sx in (1, -1):                                                                           # rear lamps, back step
        b.box((sx * (w - 0.42), REAR + 0.04, 2.2), (0.5, 0.1, 0.34), "nose_pink", bevel=False)
    b.box((0, REAR - 0.1, 1.5), (T_W - 2.2, 0.6, 0.2), "metal")
    main = _tris(b.finalize(TRUCK + "_Body", mat))
    objs = [main]
    # the rear door, built hanging from its hinge
    d = Builder()
    dw, dh = T_W - 0.36, DOOR_Z - FLOOR_Z + 0.2
    d.box((0, 0.09, -dh / 2), (dw, 0.16, dh), "pastel_butter")
    for z in (-0.5, -dh / 2, -dh + 0.5):                                                         # three ribs
        d.box((0, 0.185, z), (dw - 0.5, 0.06, 0.2), "spa_cream", bevel=False)
    d.box((0, 0.2, -dh + 1.1), (1.0, 0.06, 0.22), "metal", bevel=False)                          # the handle
    d.cyl((0, 0.06, 0.0), 0.11, dw - 0.2, "metal", segments=8, bevel=False, rot=Y90)             # the hinge rod
    objs.append(_tris(d.finalize(TRUCK + "_Door", mat, location=(0, REAR, DOOR_Z))))
    for key, (side, y) in WHEELS.items():
        objs.append(_tris(_wheel(mat, key, side).finalize(f"{TRUCK}_{key}_Wheel", mat,
                                                           location=(side * WHEEL_X, y, AXLE_Z))))
    return objs


def truck_rbx_extras():
    return {"attachments": [("_Body", "Tailgate", Matrix.Translation((0.0, REAR, FLOOR_Z)))],
            "attributes": {"DoorOpenDegrees": {"Float64": DOOR_OPEN}, "WheelRadius": {"Float64": WHEEL_R}}}


# -- the box ---------------------------------------------------------------------------------------------------------
B_W, B_H = 2.4, 1.8
B_T = 0.08                        # wall thickness
RIM = B_H - 0.1                   # the walls' top; the flaps lie on it
MINOR_T, MAJOR_T = 0.045, 0.05
MINOR_L = 0.78                    # how far a short flap reaches in from its edge
FLAP_OPEN = 215.0                 # degrees a flap turns about its hinge from shut to hanging open
BOX_SEAT = 0.08
CARD, TAPE = "cardboard", "paving_sand"


def _flap(kind):
    """One flap built from its hinge (the origin), lying shut. L and R reach in along -x and +x, F and B along +y
    and -y."""
    b = Builder()
    if kind in ("L", "R"):
        s = -1 if kind == "L" else 1
        ln = B_W / 2 - 0.006
        b.box((s * ln / 2, 0, 0), (ln, B_W - 0.03, MAJOR_T), CARD, bevel=False)
        b.box((s * (ln - 0.09), 0, MAJOR_T / 2 + 0.004), (0.17, B_W - 0.036, 0.012), TAPE, bevel=False)   # the tape
    else:
        s = 1 if kind == "F" else -1
        b.box((0, s * MINOR_L / 2, 0), (B_W - 2 * B_T - 0.05, MINOR_L, MINOR_T), CARD, bevel=False)
    return b


FLAP_HINGE = {"L": (B_W / 2, 0.0, RIM + MINOR_T + 0.004 + MAJOR_T / 2), "R": (-B_W / 2, 0.0, RIM + MINOR_T + 0.004 + MAJOR_T / 2),
              "F": (0.0, -B_W / 2 + B_T / 2, RIM + MINOR_T / 2 + 0.002), "B": (0.0, B_W / 2 - B_T / 2, RIM + MINOR_T / 2 + 0.002)}
# Blender axis and sign of the turn that opens each flap (scenes use these; in Roblox the game turns the flap Model)
FLAP_TURN = {"L": ("Y", 1), "R": ("Y", -1), "F": ("X", 1), "B": ("X", -1)}


def build_box(mat):
    b = Builder()
    b.box_base((0, 0, 0), (B_W - 0.04, B_W - 0.04, BOX_SEAT), CARD, bevel=False)                   # floor
    for sy in (1, -1):
        b.box_base((0, sy * (B_W / 2 - B_T / 2), 0.02), (B_W - 0.02, B_T, RIM - 0.02), CARD, bevel=False)
    for sx in (1, -1):
        # the side walls stand a short flap's thickness higher, so no slit shows under the big flaps between the
        # short ones
        b.box_base((sx * (B_W / 2 - B_T / 2), 0, 0.03), (B_T, B_W - 2 * B_T + 0.04, RIM + MINOR_T - 0.03), CARD, bevel=False)
        b.box((sx * (B_W / 2 + 0.004), 0, RIM - 0.42), (0.03, 0.62, 0.17), "fur_toffee", bevel=False)   # hand holes
    for sy in (1, -1):                                                                           # the tape's ends
        b.box((0, sy * (B_W / 2 + 0.004), RIM - 0.2), (0.34, 0.02, 0.5), TAPE, bevel=False)
    objs = [b.finalize(BOX + "_Body", mat, bevel=0)]
    for kind in "LRFB":
        objs.append(_flap(kind).finalize(f"{BOX}_Flap{kind}", mat, bevel=0, location=FLAP_HINGE[kind]))
    return objs


def box_rbx_extras():
    return {"attachments": [("_Body", "CatSeat", Matrix.Translation((0.0, 0.0, BOX_SEAT))),
                            ("_Body", "Peek", Matrix.Translation((0.0, 0.0, RIM)))],
            "attributes": {"FlapOpenDegrees": {"Float64": FLAP_OPEN}},
            # every flap's pivot has its X pointing from the hinge into the box and its Y up, so the scene opens each
            # one with the same turn: +FlapOpenDegrees about the pivot's own Z (Roblox axes)
            "pivot_turns": {"_FlapR": Matrix.Rotation(math.radians(180), 3, "Y"),
                            "_FlapF": Matrix.Rotation(math.radians(-90), 3, "Y"),
                            "_FlapB": Matrix.Rotation(math.radians(90), 3, "Y")}}


# -- the speed bump --------------------------------------------------------------------------------------------------
BUMP_W, BUMP_D, BUMP_H = 10.0, 1.4, 0.35


def build_bump(mat):
    b = Builder()
    n = 5
    seg = BUMP_W / n
    for i in range(n):
        x = -BUMP_W / 2 + seg * (i + 0.5)
        sw = "pastel_butter" if i % 2 == 0 else "spa_cream"
        b.box_base((x, 0, 0), (seg - 0.004, BUMP_D, 0.2), sw, bevel=False)
        b.box_base((x, 0, 0.19), (seg - 0.004, BUMP_D * 0.56, BUMP_H - 0.19), sw)
    return [b.finalize(BUMP, mat)]


# -- the pothole ------------------------------------------------------------------------------------------------------
# Floor entries: (x, y, base), (wide, deep, high), turn in degrees, swatch. The pieces overlap and are turned, so no
# two of them share a bottom or a top height (each base is a few thousandths over the last): no face of one lies in
# the plane of another's.
POTHOLE_FLOOR = (((0.0, 0.0, 0.0), (2.5, 1.7, 0.02), 8, "fur_black"), ((-0.55, 0.25, 0.004), (1.6, 1.55, 0.03), -20, "fur_black"),
                 ((0.6, -0.2, 0.008), (1.7, 1.35, 0.04), 25, "fur_black"),
                 ((0.1, 0.05, 0.012), (1.5, 0.9, 0.05), 12, "mud"), ((-0.15, 0.12, 0.016), (0.7, 0.4, 0.062), -15, "mud_wet"))
POTHOLE_RIM = ((0, 0.74, 0.34, 0.10), (38, 0.62, 0.3, 0.07), (75, 0.7, 0.36, 0.12), (118, 0.6, 0.3, 0.08),
               (160, 0.72, 0.34, 0.11), (200, 0.58, 0.3, 0.07), (238, 0.7, 0.36, 0.12), (282, 0.64, 0.3, 0.09),
               (322, 0.68, 0.34, 0.06))               # round the hole: at this angle, a chunk this long, deep and high
POTHOLE_R = (1.42, 1.02)                               # the rim's middle line: half the hole's width and depth
POTHOLE_CRACKS = ((20, 0.9), (95, 0.5), (158, 0.9), (262, 0.5))    # out from the rim: at this angle, this long
POTHOLE_CRUMBS = ((75, 0.2, 0.13), (200, 0.17, 0.10), (322, 0.22, 0.15))   # on the outside of the rim chunk at this angle


def build_pothole(mat):
    b = Builder()
    for (x, y, base), size, turn, sw in POTHOLE_FLOOR:
        b.box_base((x, y, base), size, sw, bevel=False, rot=(math.radians(turn), "Z"))
    rx, ry = POTHOLE_R

    def out(angle, more=0.0):
        a = math.radians(angle)
        p = Vector((rx * math.cos(a), ry * math.sin(a), 0.0))
        return p + p.normalized() * more

    for i, (angle, length, deep, high) in enumerate(POTHOLE_RIM):      # each chunk lies along the hole's edge
        p = out(angle)
        along = math.atan2(ry * math.cos(math.radians(angle)), -rx * math.sin(math.radians(angle)))
        b.box_base((p.x, p.y, (0.0058, 0.0100, 0.0138)[i % 3]), (length, deep, high), "concrete", bevel=False, rot=(along, "Z"))
    for i, (angle, length) in enumerate(POTHOLE_CRACKS):               # a crack starts under the rim and runs out
        p = out(angle, length / 2 - 0.35)
        b.box_base((p.x, p.y, (0.0012, 0.0019, 0.0026, 0.0015)[i]), (length, 0.07, 0.0138), "fur_black", bevel=False,
                   rot=(math.atan2(p.y, p.x), "Z"))
    for i, (angle, size, high) in enumerate(POTHOLE_CRUMBS):           # a crumb leans on its chunk's outside
        p = out(angle, 0.2)
        b.box_base((p.x, p.y, 0.0007 + 0.0009 * i), (size, size * 0.85, high), "fur_soot", bevel=False,
                   rot=(math.radians(angle * 1.7), "Z"))
    return [b.finalize(POTHOLE, mat)]


ASSETS = {TRUCK: (build_truck, 2500), BOX: (build_box, 300), BUMP: (build_bump, 300), POTHOLE: (build_pothole, 300)}
EXTRAS = {TRUCK: truck_rbx_extras, BOX: box_rbx_extras}
