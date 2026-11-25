"""Props a cat wears.

  CleanACat_Bow_Pink, CleanACat_Bow_Mint, CleanACat_Bow_Sky   the three bows the player picks after brushing (#14).
      Two puffed loops, a knot and two short tails lying back over the crown. Pivot at the base of the knot, front
      -Y in Blender (-Z in Roblox). The knot part carries the Attachment `BowSlot`; every cat's Head part has a
      `BowSlot` too (cats.bow_at), so the game puts a bow on with
          bow:PivotTo(catHeadBowSlot.WorldCFrame * bowSlot.CFrame:Inverse())
      and welds it to the Head. A bow is drawn for a scale 1 cat: ScaleTo it by the cat's Scale attribute.
      Nothing collides.

  CleanACat_Prop_BowButtonPink, ..._BowButtonMint, ..._BowButtonSky   the three buttons the player taps to pick a
      bow (#441), in place of plain coloured slabs made in code. A round cream face in a rim of the bow's colour
      with a big bow on it, standing up with its face to the front. 1.1 studs across, so three stack at the tight
      wash scene's 1.15 stud spacing. Pivot at the middle, where a slab's middle was. The rim disc is the biggest
      part and the tap target; the root attribute `BowId` is the game's id for the bow (`BowPink`...).

PROPS and build() stay the hook cats.build_cat looks up for a prop built into a cat model (the builder kitten's hard
hat, #20). Empty for now.
"""

import math

from mathutils import Matrix

from common import Builder
from stations import _tris

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


BUTTONS = {"CleanACat_Prop_BowButton" + n.rsplit("_", 1)[1]: sw for n, sw in BOWS.items()}
BUTTON_R = 0.55          # the rim's radius: 1.1 across
_FACING = (math.radians(90), "X")           # a disc stood up, its face to the front


def build_bow_button(name, mat):
    sw = BUTTONS[name]
    b = Builder()
    b.cyl((0, 0.03, 0), BUTTON_R, 0.16, sw, segments=16, rot=_FACING)                        # the rim
    b.cyl((0, -0.06, 0), BUTTON_R - 0.09, 0.06, "spa_cream", segments=16, rot=_FACING, bevel=False)   # the face
    y = -0.15                                                                              # the bow, proud of the face
    b.box((0, y, 0.05), (0.2, 0.16, 0.2), sw)                                              # the knot
    for sx in (1, -1):                                                                     # two puffed loops
        rot = Matrix.Rotation(math.radians(-18 * sx), 3, "Y")
        b.sphere((sx * 0.25, y, 0.1), 0.2, sw, segments=8, rings=4, scale=(1.0, 0.5, 0.75), rot=rot)
    for sx in (1, -1):                                                                     # two tails, splayed
        rot = Matrix.Rotation(math.radians(24 * sx), 3, "Y")
        b.box((sx * 0.13, y + 0.02, -0.15), (0.11, 0.06, 0.3), sw, bevel=False, rot=rot)
    return [_tris(b.finalize(name, mat))]


def bow_button_rbx_extras(name):
    return lambda: {"attributes": {"BowId": {"String": "Bow" + name[len("CleanACat_Prop_BowButton"):]}}}


ASSETS = {n: (lambda mat, n=n: build_bow(n, mat), 200) for n in BOWS}
ASSETS.update({n: (lambda mat, n=n: build_bow_button(n, mat), 450) for n in BUTTONS})
EXTRAS = {n: bow_rbx_extras(n) for n in BOWS}
EXTRAS.update({n: bow_button_rbx_extras(n) for n in BUTTONS})
