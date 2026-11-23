"""The builder kitten and its things (issue #20): the kitten hammers at a locked station while the build countdown runs.

  CleanACat_NPC_BuilderKitten  the standing cat body (S, with arms) from cats.py, about 1.8 studs tall, in a hazel
                               coat with oat socks and chest that no index cat has, so it never reads as collectible.
                               Built from the same pieces as every cat: child Models Head (with eyes and ears), Tail,
                               LegF1 and LegF2 (the arms, pivoted at the shoulders), LegB1 and LegB2. Attachments:
                               `HatSlot` on top of the head and `HammerGrip` in its right paw (LegF2).
  CleanACat_Prop_HardHat       a butter hard hat with a ridge, a peak at the front and a mint paw sticker. Attachment
                               `HatSlot` at its pivot, the middle of its rim: line it up with the kitten's `HatSlot`
                               and weld it to the Head part. The ears poke through it.
  CleanACat_Prop_Hammer        a wooden hammer with a bubblegum head. Its pivot is the grip, where the paw holds it,
                               with an Attachment `Grip` there: line it up with the kitten's `HammerGrip`. The handle
                               points to the front (-Z in Roblox) and the striking face down, so turning it about its
                               pivot's X axis lifts the head and brings it down (Motion-FX's hammer loop).
  CleanACat_Prop_Toolbox       a sky toolbox with a handle, latches and a wrench on the lid. Attachment
                               `CountdownAnchor` above it, for the build countdown BillboardGui.

The kitten and the toolbox stand on the floor (pivot at the base centre, front -Y in Blender, -Z in Roblox). Nothing
here collides. Nothing is uploaded: all Part-built. The hat, hammer and toolbox stay under 400 triangles together.
"""

import math

from mathutils import Matrix, Vector

import cats
import common
from common import Builder
from stations import _tris

KITTEN = dict(rarity="Common", fur="fur_hazel", second="fur_hazel", eyes="eye_chartreuse", pattern="solid",
              muzzle="fur_oat", socks="fur_oat", eye_k=1.08, scale=1.0)
KITTEN_NAME = "CleanACat_NPC_BuilderKitten"
# The hat, hammer and toolbox are drawn for a kitten at scale 0.8 and grow with it, so they always fit.
FIT = KITTEN["scale"] / 0.8


def _fit(ob):
    if FIT != 1.0:
        common.scale_mesh(ob, FIT)
    return ob


def _kitten_points():
    """(head top, right paw) in the kitten's model space, scale included."""
    k = cats.scale_of(KITTEN, "work")
    j = cats.joints(KITTEN, "work")
    h = cats.dims(KITTEN, "work")["head"]
    top = Vector(j["Head"]) + Vector((0.0, h["c"][1], h["top"])) * k
    paw = Vector(j["LegF2"]) + Vector((0.0, -0.01, cats.S_PAW_Z)) * k
    return top, paw


def build_kitten(mat):
    return cats.build_cat("Builder", mat, spec=KITTEN, base=KITTEN_NAME, body="work", held=False)


def kitten_rbx_extras():
    top, paw = _kitten_points()
    return {"attachments": [("_Head", "HatSlot", Matrix.Translation(top)),
                            ("_LegF2", "HammerGrip", Matrix.Translation(paw))],
            "attributes": {"Scale": {"Float64": KITTEN["scale"]}, "Role": "Builder"}}


HAT_R = 0.4         # the dome's radius at the rim, a little narrower than the kitten's head


def build_hard_hat(mat):
    name = "CleanACat_Prop_HardHat"
    b = Builder()
    b.sphere((0, 0, 0.0), HAT_R, "pastel_butter", segments=10, rings=5, scale=(1, 1, 0.62))   # the dome
    b.cyl_base((0, -0.04, -0.03), HAT_R + 0.05, 0.05, "pastel_butter", segments=10, bevel=False,
               scale=(1, 1.08, 1))                                                  # the rim, deeper at the front
    b.box((0, -HAT_R - 0.04, 0.0), (0.5, 0.2, 0.04), "pastel_butter", bevel=False,
          rot=Matrix.Rotation(math.radians(-12), 3, "X"))                           # the peak, tipped down a little
    b.box((0, 0.0, HAT_R * 0.62 - 0.03), (0.1, 0.5, 0.08), "pastel_butter", bevel=False)      # the ridge front to back
    b.box((0, -HAT_R * 0.8, 0.13), (0.16, 0.04, 0.14), "spa_mint", bevel=False,
          rot=Matrix.Rotation(math.radians(-38), 3, "X"))                           # a paw sticker on the front
    return [_fit(_tris(b.finalize(name, mat)))]


HANDLE = 0.62       # the handle's length; the grip is 0.12 from its back end


def build_hammer(mat):
    """Held out to the front: the handle runs forward (-Y) from the grip, the head stands up at its end with the
    striking face down, so the head comes down on the build pad when the hammer turns about the grip's X axis."""
    name = "CleanACat_Prop_Hammer"
    b = Builder()
    b.box((0, -(HANDLE / 2 - 0.12), 0), (0.07, HANDLE, 0.07), "wood_light", bevel=False)   # the handle
    hy = -(HANDLE - 0.2)
    b.box((0, hy, 0.02), (0.15, 0.15, 0.36), "spa_bubblegum")                       # the head, upright
    b.cyl((0, hy, -0.19), 0.085, 0.06, "metal", segments=8, bevel=False)            # the striking face, down
    b.box((0, hy + 0.08, 0.22), (0.12, 0.08, 0.14), "spa_bubblegum", bevel=False,
          rot=Matrix.Rotation(math.radians(-30), 3, "X"))                           # the claw, curled back
    return [_fit(_tris(b.finalize(name, mat)))]


BOX_W, BOX_D, BOX_H = 1.0, 0.5, 0.42
COUNTDOWN_Z = 1.9   # the countdown's anchor above the toolbox, level with the kitten's ears (times FIT)


def build_toolbox(mat):
    name = "CleanACat_Prop_Toolbox"
    b = Builder()
    b.box_base((0, 0, 0), (BOX_W, BOX_D, BOX_H), "spa_sky")                          # the box
    b.box_base((0, 0, BOX_H - 0.02), (BOX_W + 0.04, BOX_D + 0.04, 0.1), "spa_sky", bevel=False)   # the lid
    for sx in (1, -1):
        b.box((sx * 0.3, -BOX_D / 2 - 0.015, BOX_H - 0.06), (0.1, 0.04, 0.12), "metal", bevel=False)   # latches
        b.box_base((sx * 0.28, 0, BOX_H + 0.07), (0.06, 0.06, 0.2), "metal", bevel=False)        # handle posts
    b.box((0, 0, BOX_H + 0.28), (0.6, 0.08, 0.07), "spa_bubblegum", bevel=False)               # the handle
    rot = Matrix.Rotation(math.radians(20), 3, "Z")                                  # a wrench lying on the lid
    b.box((0.05, 0.02, BOX_H + 0.1), (0.5, 0.06, 0.03), "metal", bevel=False, rot=rot)
    b.box((0.05 + 0.27 * math.cos(math.radians(20)), 0.02 + 0.27 * math.sin(math.radians(20)), BOX_H + 0.1),
          (0.12, 0.14, 0.035), "metal", bevel=False, rot=rot)                       # its jaw
    return [_fit(_tris(b.finalize(name, mat)))]


def toolbox_rbx_extras():
    return {"attachments": [("CleanACat_Prop_Toolbox", "CountdownAnchor", Matrix.Translation((0.0, 0.0, COUNTDOWN_Z * FIT)))]}


def hard_hat_rbx_extras():
    return {"attachments": [("CleanACat_Prop_HardHat", "HatSlot", Matrix.Identity(4))]}


def hammer_rbx_extras():
    return {"attachments": [("CleanACat_Prop_Hammer", "Grip", Matrix.Identity(4))]}


ASSETS = {
    KITTEN_NAME: (build_kitten, 1500),
    "CleanACat_Prop_HardHat": (build_hard_hat, 160),
    "CleanACat_Prop_Hammer": (build_hammer, 100),
    "CleanACat_Prop_Toolbox": (build_toolbox, 140),
}
EXTRAS = {KITTEN_NAME: kitten_rbx_extras, "CleanACat_Prop_HardHat": hard_hat_rbx_extras,
          "CleanACat_Prop_Hammer": hammer_rbx_extras, "CleanACat_Prop_Toolbox": toolbox_rbx_extras}
