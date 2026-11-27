"""The builder (issue #891): a person in overalls who stands at a running build, in place of the hard hat kitten.

Derek's answer on the plan page (q2-builder, approved with the design lock, 2026-11-25): a human builder in overalls
stands at a running build, not the hard hat kitten. Built by townsfolk.build_figure like the customers and the staff,
so it has the same joints and walk (CustomerMotion) and stands the same way on R6 and R15 servers: it is a Model of
Parts, not an avatar, so nothing depends on the player's rig.

  CleanACat_NPC_Builder   Model, pivot on the floor between the feet, front -Y here (-Z in Roblox).
      ..._Body, _Head, _ArmL, _ArmR, _LegL, _LegR     as on a customer (townsfolk.py). Both arms hang straight.
  Attachments: `HammerGrip` in the right hand, where CleanACat_Prop_Hammer's `Grip` goes (the same name as on the
  kitten, so StationService's code for it carries over), `Grip` (the same spot, for any other tool) and `GripL` in the
  left hand, `Overhead` over the hard hat for the build countdown or a bubble.
  Attributes: `Look` = "Builder", `Role` = "Builder", `WalkSpeed`, `LegLength`, `Height`, `ArmsStraight` = true and
  `CarryArmDegrees` = 0 (so code written for a customer reads the same attributes).

The look says "builds things" from every side and never "works in the spa" or "a customer": orange dungarees over a
cream tee with rolled sleeves, a butter hard hat with a peak and a ridge (the kitten's hat colour), a brown tool
belt with two pouches and a wrench, and brown work boots. No mint (the staff's), no lilac or gold (the special
customers'). The hammer stays the separate prop, so Motion-FX can swing it.
"""

from mathutils import Matrix

import rbx_export
import townsfolk
from townsfolk import ADULT, Frame, Piece

NAME = "CleanACat_NPC_Builder"
LOOK = dict(body=ADULT, skin="skin_tan", hair="hair_brown", style="short", brows=True, top="offwhite",
            short_sleeves="offwhite", overalls="fur_orange", shoes="dark_wood", hardhat="pastel_butter",
            toolbelt=("dark_wood", "caramel_wood"))

rbx_export.MODEL_PROPS["_NPC_Builder"] = {"ModelStreamingMode": "Atomic"}     # it arrives whole


def build_builder(mat):
    return townsfolk.build_figure(NAME, LOOK, mat, carry=False)


def _hand(sx):
    f = Frame(LOOK["body"])
    return Piece((sx * f.arm_x, 0, f.shoulder)).at((sx * f.arm_x, 0, f.hand))


def builder_rbx_extras():
    f = Frame(LOOK["body"])
    top = townsfolk.top_of(LOOK)
    return {"attachments": [("_ArmR", "HammerGrip", Matrix.Translation(_hand(-1))),
                            ("_ArmR", "Grip", Matrix.Translation(_hand(-1))),
                            ("_ArmL", "GripL", Matrix.Translation(_hand(1))),
                            ("_Body", "Overhead", Matrix.Translation((0.0, 0.0, top + 0.6)))],
            "attributes": {"Look": {"String": "Builder"}, "Role": "Builder",
                           "WalkSpeed": {"Float64": LOOK["body"]["speed"]},
                           "LegLength": {"Float64": round(f.leg_joint, 3)}, "ArmsStraight": {"Bool": True},
                           "CarryArmDegrees": {"Float64": 0.0}, "Height": {"Float64": round(top, 3)}}}


ASSETS = {NAME: (build_builder, 1600)}
EXTRAS = {NAME: builder_rbx_extras}
