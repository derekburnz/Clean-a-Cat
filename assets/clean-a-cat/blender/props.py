"""Props a cat wears.

  CleanACat_Bow_Pink, CleanACat_Bow_Mint, CleanACat_Bow_Sky   the three bows the player picks after brushing (#14).
      Two puffed loops, a knot and two short tails lying back over the crown. Pivot at the base of the knot, front
      -Y in Blender (-Z in Roblox). The knot part carries the Attachment `BowSlot`; every cat's Head part has a
      `BowSlot` too (cats.bow_at), so the game puts a bow on with
          bow:PivotTo(catHeadBowSlot.WorldCFrame * bowSlot.CFrame:Inverse())
      and welds it to the Head. A bow is drawn for a scale 1 cat: ScaleTo it by the cat's Scale attribute.
      Nothing collides.

PROPS and build() stay the hook cats.build_cat looks up for a prop built into a cat model (the builder kitten's hard
hat, #20). Empty for now.
"""

import math

from mathutils import Matrix

from common import Builder

PROPS = {}


def build(name, spec, body, d):
    return {}


def piece_follows(name, suffix):
    return "Head"


BOWS = {"CleanACat_Bow_Pink": "bow_pink", "CleanACat_Bow_Mint": "bow_mint", "CleanACat_Bow_Sky": "bow_sky"}
KNOT = (0.15, 0.13, 0.13)


def build_bow(name, mat):
    sw = BOWS[name]
    b = Builder()
    b.box_base((0, 0, 0.0), KNOT, sw)                                   # the knot, its base on the crown
    for sx in (1, -1):                                                  # loops tilted up and out from the knot
        rot = Matrix.Rotation(math.radians(-18 * sx), 3, "Y")
        b.sphere((sx * 0.2, 0.0, 0.1), 0.18, sw, segments=8, rings=4, scale=(1.0, 0.5, 0.72), rot=rot)
    for sx in (1, -1):                                                  # tails lying back over the head, splayed
        rot = Matrix.Rotation(math.radians(22 * sx), 3, "Z")
        b.box((sx * 0.09, 0.12, 0.03), (0.09, 0.24, 0.035), sw, bevel=False, rot=rot)
    return [b.finalize(name, mat)]


def bow_rbx_extras(name):
    return lambda: {"attachments": [(name, "BowSlot", Matrix.Identity(4))]}


ASSETS = {n: (lambda mat, n=n: build_bow(n, mat), 200) for n in BOWS}
EXTRAS = {n: bow_rbx_extras(n) for n in BOWS}
