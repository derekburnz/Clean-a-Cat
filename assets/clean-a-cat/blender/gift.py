"""The gift stand (issue #502, for the game's #521): where the free pet waits in the spa.

    CleanACat_Prop_GiftStand    a big pink present with a gold ribbon and bow for a pedestal, a mint cushion on its
                                lid where the pet sits, a round lilac board with a gold rim behind the pet, a
                                small lamp on top of the board and a pink heart balloon tied to the lid

The owner on 2026-11-25: "have one pet that can be got by joining group and liking game. Make sure to not crowd any
player with all at once but make sure the pet for liking/joining group is obvious to find." The design's rule since
(gdd.md): the pet is given for a favourite and for joining the group, which a game can check; the like is asked for
in words and never checked. So the stand is a
present that reads as a gift from across the room, its heart balloon stands 7 studs up, over a player's head, and
the pet on it is the pet the player gets (`CleanACat_Pet_Starcoat`, pets.py). A draft: when and how the pet is given is the game's design.

Objects: the stand itself (it collides, so nobody walks through the present), `_Decor` (the bow, two small presents
at its foot, the board's dots and the balloon on its string: walk-through) and `_Lamp`, one ball in deep gold whose part is named `Lamp`.
The lamp is plain SmoothPlastic; the game may light it (the design lights the stand at about minute 7).

Attachments in the stand's first part: `PetSeat` (the cushion's top, facing the front), `Prompt` (in front of the
seal, 1.2 studs up) and `Glow` (the middle of the pet, for a soft light). Root attribute `CatScale` 1.0: a pet up
to that scale sits inside the board's rim. Pivot at the floor in the middle of the present, front to -Y.
"""
import math

from mathutils import Matrix

from common import Builder
from crates import _paw
from stations import _tris

NAME = "CleanACat_Prop_GiftStand"
W = D = 2.2                          # the present's body
H = 1.25
LID = 0.3                            # the lid's height; it reaches LID_OVER past the body all round
LID_OVER = 0.12
CUSHION = (0.74, 0.14)               # radius, height
SEAT = H + LID + CUSHION[1]
BOARD_R = 1.08                       # the board behind the pet
BOARD_Y = D / 2 - 0.1
BOARD_Z = SEAT + 0.88
BOX, LID_SW, RIBBON = "spa_bubblegum", "fur_strawberry", "gold_mid"
CAT_SCALE = 1.0
BALLOON = (1.3, 0.5, 6.05)           # the heart balloon's lower tip; its string runs there from the lid's corner
BUDGET = 2100
_STAND = (math.radians(90), "X")     # a disc stood up, its face to the front


def _present(b, c, s, box, ribbon):
    """A small wrapped present standing at c (its base centre), s across: a box, two ribbon bands and a knot."""
    x, y, z = c
    b.box_base((x, y, z), (s, s, s), box)
    b.box_base((x, y, z + 0.008), (s * 0.24, s + 0.03, s + 0.012), ribbon, bevel=False)
    b.box_base((x, y, z + 0.014), (s + 0.03, s * 0.24, s + 0.018), ribbon, bevel=False)
    b.ico((x, y, z + s + 0.06), s * 0.17, ribbon)


def build_gift_stand(mat, balloon=True):
    """`balloon=False` leaves the balloon off: the card picture's look, where it would shrink the present."""
    b, dec, lamp = Builder(), Builder(), Builder()
    b.box_base((0, 0, 0), (W, D, H), BOX)                                               # the present
    b.box_base((0, 0, 0.01), (0.42, D + 0.05, H - 0.004), RIBBON, bevel=False)          # its ribbon, front to back
    b.box_base((0, 0, 0.016), (W + 0.05, 0.42, H - 0.004), RIBBON, bevel=False)         # and side to side
    lw = W + 2 * LID_OVER
    b.box_base((0, 0, H), (lw, lw, LID), LID_SW)                                        # the lid
    b.box_base((0, 0, H - 0.01), (0.42, lw + 0.05, LID + 0.03), RIBBON, bevel=False)
    b.box_base((0, 0, H - 0.016), (lw + 0.05, 0.42, LID + 0.04), RIBBON, bevel=False)
    b.cyl((0, 0, H + LID + CUSHION[1] / 2), CUSHION[0], CUSHION[1], "spa_mint", segments=16)   # the cushion
    b.cyl((0, 0, H + LID + 0.04), CUSHION[0] + 0.07, 0.11, "spa_cream", segments=16)            # and its piping
    # the board behind the pet: a gold rim, a lilac face and a deeper heart, each proud of the last at the front
    b.cyl((0, BOARD_Y + 0.03, BOARD_Z), BOARD_R + 0.1, 0.1, RIBBON, segments=20, rot=_STAND, bevel=False)
    b.cyl((0, BOARD_Y, BOARD_Z), BOARD_R, 0.14, "pastel_lilac", segments=20, rot=_STAND, bevel=False)
    b.cyl((0, BOARD_Y - 0.015, BOARD_Z), BOARD_R - 0.22, 0.15, "velvet_lilac", segments=20, rot=_STAND, bevel=False)
    for k in range(10):                                                                 # pale gold dots round it
        a = math.radians(36 * k + 18)
        dec.ico((math.cos(a) * (BOARD_R - 0.11), BOARD_Y - 0.07, BOARD_Z + math.sin(a) * (BOARD_R - 0.11)), 0.065,
                "gold_light")
    top = BOARD_Z + BOARD_R + 0.1
    b.cyl((0, BOARD_Y + 0.03, top + 0.03), 0.17, 0.14, RIBBON, segments=10)             # the lamp's cup
    lamp.ico((0, BOARD_Y + 0.03, top + 0.22), 0.2, "eye_gold")
    # the seal on the front: a cream disc with a pink paw, where the ribbons cross
    fy = -D / 2 - 0.025
    b.cyl((0, fy - 0.02, 0.62), 0.44, 0.06, "spa_cream", segments=16, rot=_STAND, bevel=False)
    b.cyl((0, fy - 0.004, 0.62), 0.5, 0.04, "gold_light", segments=16, rot=_STAND, bevel=False)
    _paw(b, fy - 0.055, 0.62, "fur_strawberry", k=1.9)
    # the bow on the lid's front edge
    by, bz = -lw / 2 - 0.14, H + LID * 0.55
    for sx in (1, -1):
        tip = Matrix.Rotation(math.radians(-16 * sx), 3, "Y")
        dec.sphere((sx * 0.43, by, bz + 0.06), 0.38, RIBBON, segments=10, rings=5, scale=(1.0, 0.42, 0.7), rot=tip)
        dec.sphere((sx * 0.45, by - 0.07, bz + 0.07), 0.19, "gold_light", segments=8, rings=4, scale=(1.0, 0.42, 0.7),
                   rot=tip)
        lean = Matrix.Rotation(math.radians(-24 * sx), 3, "Y")
        d = lean @ Matrix.Translation((0, 0, -1)).translation
        dec.box((sx * 0.1 + d.x * 0.34, by + 0.03 + 0.008 * sx, bz - 0.02 + d.z * 0.34), (0.2, 0.07, 0.68), RIBBON,
                bevel=False, rot=lean)
    dec.box((0, by - 0.02, bz + 0.05), (0.26, 0.3, 0.26), RIBBON)
    # two small presents at its foot
    _present(dec, (W / 2 + 0.26, -0.72, 0.0), 0.62, "spa_mint", "fur_strawberry")
    _present(dec, (-W / 2 - 0.19, -0.86, 0.0), 0.46, "spa_sky", "pastel_butter")
    # the heart balloon: tied to the lid's back corner, beside the board, so the gift shows over a crowd
    kx, ky, kz = 0.98, 0.5, H + LID
    tx, ty, tz = BALLOON
    run = math.hypot(tx - kx, tz - kz)
    if balloon:
        dec.ico((kx, ky, kz + 0.05), 0.09, "gold_light")
        dec.box(((kx + tx) / 2, ky, (kz + tz) / 2), (0.05, 0.05, run), "gold_light", bevel=False,
                rot=Matrix.Rotation(math.atan2(tx - kx, tz - kz), 3, "Y"))
        dec.cyl((tx, ty, tz + 0.4), 0.06, 0.8, "fur_strawberry", segments=10, bevel=False, radius2=0.66,
                scale=(1.0, 0.62, 1.0))
        for sx in (1, -1):
            dec.sphere((tx + sx * 0.31, ty, tz + 0.83), 0.4, "fur_strawberry", segments=8, rings=5,
                       scale=(1.0, 0.7, 1.0))
        dec.sphere((tx - 0.42, ty - 0.2, tz + 0.98), 0.1, "fur_rose", segments=6, rings=4, scale=(1.0, 0.6, 1.3))
    return [_tris(b.finalize(NAME, mat)), _tris(dec.finalize(NAME + "_Decor", mat)),
            lamp.finalize(NAME + "_Lamp", mat)]


def gift_stand_rbx_extras():
    return {"attachments": [(NAME, "PetSeat", Matrix.Translation((0.0, 0.0, SEAT))),
                            (NAME, "Prompt", Matrix.Translation((0.0, -D / 2 - 0.4, 1.2))),
                            (NAME, "Glow", Matrix.Translation((0.0, 0.1, SEAT + 0.85)))],
            "attributes": {"CatScale": {"Float64": CAT_SCALE}, "SeatHeight": {"Float64": round(SEAT, 3)}}}


ASSETS = {NAME: (build_gift_stand, BUDGET)}
EXTRAS = {NAME: gift_stand_rbx_extras}
