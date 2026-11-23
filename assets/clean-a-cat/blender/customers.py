"""Customers (issue #16). A customer is Roblox's own R15 rig, made in game with
Players:CreateHumanoidModelFromDescription from a HumanoidDescription that sets only body colours (no clothing
images, no catalogue items, so nothing waits on an upload), wearing one of our accessories:

  CleanACat_NPC_SunHat    a wide straw-coloured sun hat with a pink band     Attachment HatAttachment
  CleanACat_NPC_Scarf     a mint scarf with one end hanging at the front     Attachment NeckAttachment
  CleanACat_NPC_ToteBag   a sky tote bag on a strap, at the left hip          Attachment LeftShoulderAttachment

Each is a Model whose biggest part is `Handle` and holds the named Attachment, placed where the R15 body has the
same Attachment (the top of the head, the base of the neck, the top of the left shoulder). To dress a customer:
make an Accessory, move the parts into it, weld them to Handle, unanchor them and call Humanoid:AddAccessory; the
Humanoid lines the two Attachments up. Pivot at the Attachment. Nothing collides.

LOOKS lists the four customers (body colours as palette swatches, and the accessory); the style guide has the same
table with hex colours for the HumanoidDescription.
"""

import math

from mathutils import Matrix

from common import Builder
from stations import _tris

ATTACH = {"CleanACat_NPC_SunHat": "HatAttachment", "CleanACat_NPC_Scarf": "NeckAttachment",
          "CleanACat_NPC_ToteBag": "LeftShoulderAttachment"}

LOOKS = [
    # name, skin (head and arms), shirt (torso), trousers (legs), accessory
    ("Sunny", "skin_light", "spa_mint", "pants_navy", "CleanACat_NPC_SunHat"),
    ("Mo", "skin_deep", "pastel_butter", "shirt_blue", "CleanACat_NPC_Scarf"),
    ("Pip", "skin_tan", "spa_sky", "wood_light", "CleanACat_NPC_ToteBag"),
    ("Rae", "skin_tan", "spa_bubblegum", "pants_navy", "CleanACat_NPC_SunHat"),
]


def build_sun_hat(mat):
    name = "CleanACat_NPC_SunHat"
    b = Builder()
    b.cyl_base((0, 0, -0.12), 1.15, 0.08, "pastel_butter", segments=16, bevel=False)    # the brim, round the head
    b.cyl_base((0, 0, -0.1), 0.66, 0.5, "pastel_butter", segments=12, radius2=0.58)     # the crown
    b.cyl_base((0, 0, -0.05), 0.68, 0.14, "spa_bubblegum", segments=12, bevel=False)    # the band
    b.sphere((0.55, -0.35, 0.05), 0.14, "spa_bubblegum", segments=8, rings=4)           # a bow knot on the band
    return [_tris(b.finalize(name, mat))]


def build_scarf(mat):
    name = "CleanACat_NPC_Scarf"
    b = Builder()
    w, d, t, h = 1.45, 1.15, 0.28, 0.34                                                  # a loop round the neck
    for sy in (1, -1):
        b.box_base((0, sy * (d / 2 - t / 2), -0.05), (w, t, h), "spa_mint")
    for sx in (1, -1):
        b.box_base((sx * (w / 2 - t / 2), 0, -0.04), (t, d - 2 * t + 0.02, h - 0.02), "spa_mint")
    tilt = Matrix.Rotation(math.radians(8), 3, "Y")
    b.box((0.35, -d / 2 + 0.06, -0.55), (0.3, 0.12, 0.9), "spa_mint", rot=tilt)        # the end hanging down the front
    for i in range(3):                                                                   # stripes across the end
        b.box((0.35 - 0.98 * (i * 0.25 - 0.25) * math.sin(math.radians(8)), -d / 2 - 0.005,
               -0.55 + (i - 1) * 0.25), (0.31, 0.02, 0.07), "offwhite", bevel=False, rot=tilt)
    return [b.finalize(name, mat)]


def build_tote_bag(mat):
    name = "CleanACat_NPC_ToteBag"
    b = Builder()
    # The R15 LeftShoulderAttachment is at the top outer corner of the torso; the arm hangs just outside it, so the
    # strap runs over the top of the arm and the bag hangs outside the arm, at the hip.
    top, bag = (0.5, 0.0, 0.12), (1.25, 0.0, -1.15)
    dx, dz = bag[0] - top[0], bag[2] - top[2]
    strap = Matrix.Rotation(math.atan2(dx, dz), 3, "Y")
    b.box(((top[0] + bag[0]) / 2, 0.0, (top[2] + bag[2]) / 2), (0.1, 0.12, math.hypot(dx, dz) + 0.1), "spa_sky",
          bevel=False, rot=strap)
    b.box_base((1.25, 0.0, -2.25), (0.4, 1.2, 1.15), "spa_sky")                           # the bag at the hip
    b.box((1.46, 0.0, -1.68), (0.02, 0.6, 0.4), "offwhite", bevel=False)                # a pocket
    return [b.finalize(name, mat)]


def _att(name):
    return lambda: {"attachments": [(name, ATTACH[name], Matrix.Identity(4))],
                    "attributes": {"Accessory": ATTACH[name]}}


ASSETS = {
    "CleanACat_NPC_SunHat": (build_sun_hat, 400),
    "CleanACat_NPC_Scarf": (build_scarf, 400),
    "CleanACat_NPC_ToteBag": (build_tote_bag, 400),
}
EXTRAS = {n: _att(n) for n in ASSETS}
