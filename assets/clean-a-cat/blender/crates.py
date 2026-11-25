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

from mathutils import Matrix

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

rbx_export.MODEL_PROPS["_PetCrate"] = {"ModelStreamingMode": "Atomic"}     # the lid and the seat arrive with the crate


def _paw(b, y, z, sw, k=1.0):
    """A paw print on the latch, proud of its face at depth y: a pad and four toes, k times the coin's size."""
    b.box((0, y, z - 0.06 * k), (0.17 * k, 0.03, 0.12 * k), sw, bevel=False)
    for x, dz in ((-0.13, 0.03), (-0.045, 0.1), (0.045, 0.1), (0.13, 0.03)):
        b.box((x * k, y, z + dz * k), (0.065 * k, 0.03, 0.065 * k), sw, bevel=False)


def _lid():
    """The lid, built from the hinge line (the origin): it reaches forward along -y and lies a hair over the rim."""
    b = Builder()
    ln = D + LID_OVER
    b.box_base((0, -ln / 2, 0.004), (W + 2 * LID_OVER, ln, LID_T), FRAME)
    b.box_base((0, -D / 2, LID_T), (W - 0.5, D - 0.5, 0.07), "spa_cream")                 # a raised cream panel
    for sx in (1, -1):                                                                  # the ears, tipped out a little
        tilt = Matrix.Rotation(math.radians(-10 * sx), 3, "Y")
        b.pyramid((sx * EAR_X, EAR_Y, LID_T + 0.02), EAR[0], EAR[1], FRAME, rot=tilt)
        b.pyramid((sx * EAR_X, EAR_Y - 0.17, LID_T + 0.03), EAR[0] * 0.56, EAR[1] * 0.62, "spa_bubblegum", rot=tilt)
    # the latch: a lilac tongue down the front with a gold paw medallion on it
    y = -D - 0.02 - 0.04
    b.box((0, y, -0.13), (0.8, 0.08, 0.56), FRAME)
    b.cyl((0, y - 0.05, -0.14), 0.31, 0.05, GOLD, segments=12, rot=(math.radians(90), "X"), bevel=False)
    _paw(b, y - 0.085, -0.15, "gold_dark", 1.35)
    return b


def build_pet_crate(mat):
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
            b.box_base((0, sy * (D / 2 - 0.04), z), (W - 2 * POST + 0.04, 0.06, slat_h), SLAT, bevel=False)
        b.box_base((0, sy * (D / 2 - 0.04), 0.006), (W - 2 * POST + 0.02, 0.07, RAIL_LO - 0.006), FRAME, bevel=False)
        b.box_base((0, sy * (D / 2 - 0.04), H - RAIL_HI), (W - 2 * POST + 0.02, 0.07, RAIL_HI), FRAME, bevel=False)
    for sx in (1, -1):                                                                  # the two sides
        x = sx * (W / 2 - 0.03 - WALL / 2)
        b.box_base((x, 0, 0.03), (WALL, D - 0.06 - 2 * WALL - 0.004, H - 0.05), DARK, bevel=False)
        for i in range(SLATS):
            z = RAIL_LO + GAP + i * (slat_h + GAP)
            b.box_base((sx * (W / 2 - 0.04), 0, z), (0.06, D - 2 * POST + 0.04, slat_h), SLAT, bevel=False)
        b.box_base((sx * (W / 2 - 0.04), 0, 0.006), (0.07, D - 2 * POST + 0.02, RAIL_LO - 0.006), FRAME, bevel=False)
        b.box_base((sx * (W / 2 - 0.04), 0, H - RAIL_HI), (0.07, D - 2 * POST + 0.02, RAIL_HI), FRAME, bevel=False)
        # a cream grip over the middle slat
        zc = RAIL_LO + GAP + slat_h + GAP + slat_h / 2
        b.box((sx * (W / 2 + 0.02), 0, zc), (0.08, 0.7, 0.14), "spa_cream")
        for sx2 in (1, -1):                                                             # the four corner posts
            b.box_base((sx * (W / 2 - POST / 2), sx2 * (D / 2 - POST / 2), 0), (POST, POST, H - 0.006), FRAME)
    for sx in (1, -1):                                                                  # two gold hinges at the back
        b.cyl((sx * 0.62, D / 2 + 0.035, H - 0.02), 0.07, 0.34, GOLD, segments=8, rot=(math.radians(90), "Y"),
              bevel=False)
    main = _tris(b.finalize(NAME, mat))

    lid = _tris(_lid().finalize(NAME + "_Lid_Swing", mat, location=(0, D / 2, H)))

    s = Builder()                                                                       # the front plate
    zc = RAIL_LO + GAP + slat_h + GAP + slat_h / 2
    s.box((0, -D / 2 + 0.005, zc - 0.12), (1.2, 0.05, 0.46), "spa_cream", bevel=False)
    screen = s.finalize(NAME + "_Screen", mat, bevel=0)
    return [main, lid, screen]


def pet_crate_rbx_extras():
    return {"attachments": [(NAME, "PetSeat", Matrix.Translation((0.0, 0.0, SEAT))),
                            (NAME, "Burst", Matrix.Translation((0.0, 0.0, H + 0.3))),
                            (NAME, "Odds", Matrix.Translation((0.0, -D / 2, H + 1.6)))],
            "attributes": {"LidOpenDegrees": {"Float64": LID_OPEN}, "CatScale": {"Float64": CAT_SCALE}}}


ASSETS = {NAME: (build_pet_crate, 900)}
EXTRAS = {NAME: pet_crate_rbx_extras}
