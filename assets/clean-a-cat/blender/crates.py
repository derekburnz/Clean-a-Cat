"""The pet crate (issue #438): `CleanACat_Prop_PetCrate`, the reward crate a pet comes out of. A draft.

The owner on 2026-11-24: players "can earn crates that roll for" pets, hard to get and rewarding. The game has no
rules for crates yet, so nothing uses this model; it is here so the crate has a look when they do. It is our own
shape. The owner's library crates are themed loot crates from another game and were not ported.

It must not be taken for the customers' carrier (a little pastel house on a tray), the cardboard
delivery box or the stray box, nor for a plain present, so: wooden slats in a lilac frame, a lilac lid with two cat
ears, and a gold paw latch. Lilac and gold are what a better tool wears (style guide, tool tiers), so the crate reads
as a prize in the game's own colours.

  CleanACat_Prop_PetCrate     2.4 wide, 2.0 deep, 1.55 to the rim; pivot on the floor at the middle, front -Y here
                              (-Z in Roblox). Open at the top under the lid, a bubblegum cushion inside.
      ..._Lid_Swing           the lid with its ears and the paw latch; its pivot is on the hinge line at the back
                              of the rim. Turn it by +LidOpenDegrees about the pivot's X in Roblox to open it.
      ..._Screen              a cream plate on the front, part name `Screen`, for a name or a "?"
                              Attachments: `PetSeat` on the cushion (a sitting cat at CatScale shows its head over
                              the rim), `Burst` over the open top for the opening's effects, `Odds` above the lid
                              for the list of chances (they are shown before a crate is opened, rule 9)
"""

import math

from mathutils import Matrix, Vector

import rbx_export
from common import Builder
from stations import _tris

NAME = "CleanACat_Prop_PetCrate"

W, D, H = 2.4, 2.0, 1.55             # wide, deep, up to the rim
WALL = 0.1
POST = 0.22                          # a corner post's side
RAIL_LO, RAIL_HI = 0.22, 0.2         # the frame's bottom and top rails: how high each is
SLATS = 3
GAP = 0.05                           # the dark gap between two slats
SEAT = 0.2                           # the cushion's top, where the pet sits
LID_T = 0.2
LID_OVER = 0.06                      # how far the lid reaches past the body on the sides and the front
LID_OPEN = 110.0
EAR = (0.66, 0.62)                   # an ear's base and height
EAR_X, EAR_Y = 0.7, -1.25            # where an ear stands on the lid, from the hinge line
CAT_SCALE = 1.25                     # a sitting cat this size has its whole head over the rim and still fits inside

FRAME, SLAT, DARK, GOLD = "pastel_lilac", "wood_light", "fur_latte", "gold_mid"
GIFT_NAME = "CleanACat_Prop_GiftCrate"
GIFT_FRAME, GIFT_SLAT, RIBBON = "spa_bubblegum", "spa_cream", "gold_mid"    # the gift stand's own pink and gold

rbx_export.MODEL_PROPS["_PetCrate"] = {"ModelStreamingMode": "Atomic"}     # the lid and the seat arrive with the crate


def _paw(b, y, z, sw, k=1.0):
    """A paw print on the latch, proud of its face at depth y: a pad and four toes, k times the coin's size."""
    b.box((0, y, z - 0.06 * k), (0.17 * k, 0.03, 0.12 * k), sw, bevel=False)
    for x, dz in ((-0.13, 0.03), (-0.045, 0.1), (0.045, 0.1), (0.13, 0.03)):
        b.box((x * k, y, z + dz * k), (0.065 * k, 0.03, 0.065 * k), sw, bevel=False)


def _gift_bow(b, x, y, z):
    """A big gold gift bow on the lid at (x, y, z): two puffed loops leaned out, a knot and two tails lying on the lid."""
    for sx in (-1, 1):
        tilt = Matrix.Rotation(math.radians(-24 * sx), 3, "Y") @ Matrix.Rotation(math.radians(90), 3, "X")
        c = Vector((x + sx * 0.36, y, z + 0.26))
        b.cyl(c, 0.34, 0.24, RIBBON, segments=14, rot=tilt, scale=(1, 0.72, 1))          # a loop, seen end on
        for fy in (-1, 1):                                                              # and its opening, both faces
            b.cyl(c + Vector((0, fy * 0.122, 0)), 0.2, 0.01, "gold_dark", segments=14, bevel=False, rot=tilt,
                  scale=(1, 0.6, 1))
        b.box((x + sx * 0.22, y - 0.3, z + 0.02), (0.16, 0.5, 0.05), RIBBON,
              rot=(math.radians(26 * sx), "Z"))                                         # a tail lying on the lid
    b.box((x, y, z + 0.18), (0.26, 0.26, 0.3), "gold_dark")                             # the knot


def _lid(gift=False):
    """The lid, built from the hinge line (the origin): it reaches forward along -y and lies a hair over the rim. The
    gift crate's lid has a gold ribbon cross and a bow where the ears are."""
    b = Builder()
    frame = GIFT_FRAME if gift else FRAME
    ln = D + LID_OVER
    b.box_base((0, -ln / 2, 0.004), (W + 2 * LID_OVER, ln, LID_T), frame)
    b.box_base((0, -D / 2, LID_T), (W - 0.5, D - 0.5, 0.07), "spa_cream")                 # a raised cream panel
    if gift:                                                                            # the ribbon cross and the bow
        b.box_base((0, -ln / 2, 0.012), (0.34, ln + 0.03, LID_T + 0.088), RIBBON, bevel=False)
        b.box_base((0, -D / 2, 0.016), (W + 2 * LID_OVER + 0.03, 0.34, LID_T + 0.088), RIBBON, bevel=False)
        _gift_bow(b, 0, -D / 2, LID_T + 0.1)
    else:
        for sx in (1, -1):                                                              # the ears, tipped out a little
            tilt = Matrix.Rotation(math.radians(-10 * sx), 3, "Y")
            b.pyramid((sx * EAR_X, EAR_Y, LID_T + 0.02), EAR[0], EAR[1], FRAME, rot=tilt)
            b.pyramid((sx * EAR_X, EAR_Y - 0.17, LID_T + 0.03), EAR[0] * 0.56, EAR[1] * 0.62, "spa_bubblegum", rot=tilt)
    # the latch: a lilac tongue down the front with a gold paw medallion on it
    y = -D - 0.02 - 0.04
    b.box((0, y, -0.13), (0.8, 0.08, 0.56), frame)
    b.cyl((0, y - 0.05, -0.14), 0.31, 0.05, GOLD, segments=12, rot=(math.radians(90), "X"), bevel=False)
    _paw(b, y - 0.085, -0.15, "gold_dark", 1.35)
    return b


def build_pet_crate(mat, gift=False):
    name, frame_sw, slat_sw = (GIFT_NAME, GIFT_FRAME, GIFT_SLAT) if gift else (NAME, FRAME, SLAT)
    b = Builder()
    b.box_base((0, 0, 0.012), (W - 0.1, D - 0.1, 0.088), DARK, bevel=False)              # the floor
    b.box_base((0, 0, 0.1), (W - 2 * WALL - 0.24, D - 2 * WALL - 0.24, SEAT - 0.1), "spa_bubblegum")   # the cushion
    zone = H - RAIL_LO - RAIL_HI                                                        # what the slats share
    slat_h = (zone - GAP * (SLATS + 1)) / SLATS
    for sy in (1, -1):                                                                  # front and back
        y = sy * (D / 2 - 0.03 - WALL / 2)
        b.box_base((0, y, 0.02), (W - 0.08, WALL, H - 0.03), DARK, bevel=False)
        for i in range(SLATS):
            z = RAIL_LO + GAP + i * (slat_h + GAP)
            b.box_base((0, sy * (D / 2 - 0.04), z), (W - 2 * POST + 0.04, 0.06, slat_h), slat_sw, bevel=False)
        b.box_base((0, sy * (D / 2 - 0.04), 0.006), (W - 2 * POST + 0.02, 0.07, RAIL_LO - 0.006), frame_sw, bevel=False)
        b.box_base((0, sy * (D / 2 - 0.04), H - RAIL_HI), (W - 2 * POST + 0.02, 0.07, RAIL_HI), frame_sw, bevel=False)
    for sx in (1, -1):                                                                  # the two sides
        x = sx * (W / 2 - 0.03 - WALL / 2)
        b.box_base((x, 0, 0.03), (WALL, D - 0.06 - 2 * WALL - 0.004, H - 0.05), DARK, bevel=False)
        for i in range(SLATS):
            z = RAIL_LO + GAP + i * (slat_h + GAP)
            b.box_base((sx * (W / 2 - 0.04), 0, z), (0.06, D - 2 * POST + 0.04, slat_h), slat_sw, bevel=False)
        b.box_base((sx * (W / 2 - 0.04), 0, 0.006), (0.07, D - 2 * POST + 0.02, RAIL_LO - 0.006), frame_sw, bevel=False)
        b.box_base((sx * (W / 2 - 0.04), 0, H - RAIL_HI), (0.07, D - 2 * POST + 0.02, RAIL_HI), frame_sw, bevel=False)
        zc = RAIL_LO + GAP + slat_h + GAP + slat_h / 2
        if gift:                                        # the gift ribbon runs down each side, under the lid's band
            b.box_base((sx * (W / 2 + 0.005), 0, 0.01), (0.1, 0.34, H - 0.047), RIBBON, bevel=False)
        else:                                           # a cream grip over the middle slat
            b.box((sx * (W / 2 + 0.02), 0, zc), (0.08, 0.7, 0.14), "spa_cream")
        for sx2 in (1, -1):                                                             # the four corner posts
            b.box_base((sx * (W / 2 - POST / 2), sx2 * (D / 2 - POST / 2), 0), (POST, POST, H - 0.006), frame_sw)
    for sx in (1, -1):                                                                  # two gold hinges at the back
        b.cyl((sx * 0.62, D / 2 + 0.035, H - 0.02), 0.07, 0.34, GOLD, segments=8, rot=(math.radians(90), "Y"),
              bevel=False)
    main = _tris(b.finalize(name, mat))

    lid = _tris(_lid(gift).finalize(name + "_Lid_Swing", mat, location=(0, D / 2, H)))

    s = Builder()                                                                       # the front plate
    zc = RAIL_LO + GAP + slat_h + GAP + slat_h / 2
    s.box((0, -D / 2 + 0.005, zc - 0.12), (1.2, 0.05, 0.46), "spa_cream", bevel=False)
    screen = s.finalize(name + "_Screen", mat, bevel=0)
    return [main, lid, screen]


def pet_crate_rbx_extras(name=NAME):
    return {"attachments": [(name, "PetSeat", Matrix.Translation((0.0, 0.0, SEAT))),
                            (name, "Burst", Matrix.Translation((0.0, 0.0, H + 0.3))),
                            (name, "Odds", Matrix.Translation((0.0, -D / 2, H + 1.6)))],
            "attributes": {"LidOpenDegrees": {"Float64": LID_OPEN}, "CatScale": {"Float64": CAT_SCALE}}}


# -- the gift crate (#859) -----------------------------------------------------------------------------------------------
# Derek, 2026-11-26: "for the group reward maybe make it a crate to open so that people can pull something from it".
# `CleanACat_Prop_GiftCrate` is the pet crate wrapped as a present: the gift stand's pink frame with cream slats, a gold
# ribbon down both sides and in a cross over the lid, and a gold bow on the lid where the pet crate has its ears. The
# same size, pivot, lid hinge, Attachments and attributes as the pet crate, so the game opens it the same way.
rbx_export.MODEL_PROPS["_GiftCrate"] = {"ModelStreamingMode": "Atomic"}


def build_gift_crate(mat):
    return build_pet_crate(mat, gift=True)


ASSETS = {NAME: (build_pet_crate, 900), GIFT_NAME: (build_gift_crate, 1600)}
EXTRAS = {NAME: pet_crate_rbx_extras, GIFT_NAME: lambda: pet_crate_rbx_extras(GIFT_NAME)}
