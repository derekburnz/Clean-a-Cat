"""The spa's human staff (issue #482): the helpers a player hires, as game models on the townsfolk body. A draft.

The owner picked human staff on the plan page (2026-11-25: "yes suds doesnt help tho"; on 2026-11-24, "helpers are
likely going to be staff like humans"). Until now they were two portrait drafts on a stand-in figure (staff.py) and the
game still had the three helper kittens (busy_spa). These are built by townsfolk.build_figure, so they share the
customers' joints and walk.

  CleanACat_NPC_Staff_<Name>      Model, pivot on the floor between the feet, front -Y here (-Z in Roblox).
      ..._Body, _Head, _ArmL, _ArmR, _LegL, _LegR     as on a customer (townsfolk.py). Both arms hang straight.
  Attachments: `Grip` in the right hand and `GripL` in the left (for the step's tool or a cat), `Overhead` over the
  head for a name, a level or a bubble.
  Attributes: `Look` (the name), `Role` = "Staff", `Staff` = true, `WalkSpeed`, `LegLength`, `Height`, and
  `CarryArmDegrees` = 0 (kept so code written for a customer reads the same attributes).

The uniform is the same on all three and says "works here" from every side, beside customers who wear mint, pink and
sky too: scrubs (a mint smock with short sleeves and mint trousers, so the forearms are bare, which no customer's
are), a cream bib apron with a big pink paw, a pink waistband tied in a bow at the back, cream straps that cross on
the back, a cream towelling headband with a pink paw, pink clogs, a towel and a pocket with a sponge and a brush.
No lilac or gold: those mean a special customer (#479). No hat: hats are the customers'.

Jo and Sam are the working names from the portrait drafts; Lou is the third, for the Helpers screen's three spots.
Each differs by build, skin and hair only. No level, price or speed here: those are the game's.
"""

from mathutils import Matrix

import rbx_export
import townsfolk
from townsfolk import ADULT, SMALL, TALL, Frame, Piece

PREFIX = "CleanACat_NPC_Staff_"
SMOCK, CLOTH, TRIM = "spa_mint", "spa_cream", "nose_bubblegum"

UNIFORM = dict(top=SMOCK, pants=SMOCK, shoes="spa_bubblegum", short_sleeves=CLOTH, apron=(CLOTH, TRIM),
               headband=(CLOTH, TRIM), towel="spa_sky", pocket_tools=True)

LOOKS = {
    "Jo": dict(UNIFORM, body=ADULT, skin="skin_light", hair="fur_ginger", style="bob"),
    "Sam": dict(UNIFORM, body=TALL, skin="skin_deep", hair="fur_black", style="short", brows=True),
    "Lou": dict(UNIFORM, body=SMALL, skin="skin_tan", hair="choco", style="ponytail", tie=TRIM, brows=True),
}

for _n in LOOKS:                                        # a walker arrives whole, its arms and legs with it
    rbx_export.MODEL_PROPS["_Staff_" + _n] = {"ModelStreamingMode": "Atomic"}


def build_staff(name, mat):
    return townsfolk.build_figure(PREFIX + name, LOOKS[name], mat, carry=False)


def hand_at(look, sx):
    """The middle of a hand in the figure's space; sx 1 is its own left."""
    f = Frame(look["body"])
    return Piece((sx * f.arm_x, 0, f.shoulder)).at((sx * f.arm_x, 0, f.hand))


def staff_rbx_extras(name):
    look = LOOKS[name]
    f = Frame(look["body"])
    top = townsfolk.top_of(look)
    return {"attachments": [("_ArmR", "Grip", Matrix.Translation(hand_at(look, -1))),
                            ("_ArmL", "GripL", Matrix.Translation(hand_at(look, 1))),
                            ("_Body", "Overhead", Matrix.Translation((0.0, 0.0, top + 0.6)))],
            "attributes": {"Look": {"String": name}, "Role": "Staff", "Staff": {"Bool": True},
                           "WalkSpeed": {"Float64": look["body"]["speed"]},
                           "LegLength": {"Float64": round(f.leg_joint, 3)},
                           "CarryArmDegrees": {"Float64": 0.0}, "Height": {"Float64": round(top, 3)}}}


ASSETS = {PREFIX + n: ((lambda mat, n=n: build_staff(n, mat)), 1600) for n in LOOKS}
EXTRAS = {PREFIX + n: (lambda n=n: staff_rbx_extras(n)) for n in LOOKS}
