"""Hand tools (issue #13 for the sponges, #14 for the brush).

  CleanACat_Tool_Sponge        the starting sponge: butter yellow with a mint scrub top
  CleanACat_Tool_SpongeBubble  Bubble Soap (30 coins): a bigger sponge with a foam cluster on top, a wider scrub
  CleanACat_Tool_SpongeGolden  the Golden Sponge game pass: gold with a pale gold top and gold bubbles
  CleanACat_Tool_Brush         the grooming brush: a bubblegum back with cream bristles and a light wood handle

Drafts for the other wash steps (#123): rinse, pick out burrs, towel dry, trim nails, blow dry and lather.

  CleanACat_Tool_Shower    a hand shower: a white grip, a sky blue head tipped forward and down, a hose stub.
                           Attachment `Nozzle` on the face plate, its +Y (Roblox) along the spray
  CleanACat_Tool_Comb      a grooming comb: a mint handle and spine, seven metal teeth pointing down
  CleanACat_Tool_Tweezers  big tweezers: two metal arms open toward the front, pink grip pads
  CleanACat_Tool_Towel     a folded bubblegum towel with two cream stripes
  CleanACat_Tool_Clipper   a nail clipper: two metal blades and a sky blue lever
  CleanACat_Tool_Dryer     a hand dryer: a bubblegum barrel, a cream nozzle, a darker pink grip. Attachment `Air`
                           at the nozzle's mouth, its +Y (Roblox) along the air
  CleanACat_Tool_Shampoo   a pump bottle: lilac, a cream label with a pink paw, a white pump

Each is one object, so the Part model is a Model of Parts whose biggest part is named `Handle` (rbx_export
RENAME_BIGGEST): the game moves the parts into a Roblox Tool and welds them to Handle. Pivot at the grip centre
(the middle of the sponge body), front -Y. Nothing collides. Sized to read in a player's hand on a phone: about
twice a real sponge.
"""

import math

from mathutils import Matrix, Vector

from common import Builder

SPONGES = {
    # name: (body swatch, top swatch, bubble swatch or None, scale)
    "CleanACat_Tool_Sponge": ("pastel_butter", "spa_mint", None, 1.0),
    "CleanACat_Tool_SpongeBubble": ("pastel_butter", "spa_mint", "foam", 1.2),
    "CleanACat_Tool_SpongeGolden": ("gold_mid", "gold_light", "gold_light", 1.2),
}


def build_sponge(name, mat):
    body, top, bubbles, k = SPONGES[name]
    b = Builder()
    b.box((0, 0, 0), (1.0 * k, 0.65 * k, 0.4 * k), body)
    b.box((0, 0, 0.26 * k), (1.04 * k, 0.69 * k, 0.16 * k), top)          # overlaps the body: no shared face
    for x, y in ((-0.25, -0.12), (0.2, 0.1), (0.05, -0.2), (-0.1, 0.18)):   # sponge holes on the front face
        b.box((x * k, -0.326 * k, (y - 0.02) * k * 0.6), (0.09 * k, 0.02, 0.09 * k), "wood_light" if body != "gold_mid"
              else "gold_dark", bevel=False)
    if bubbles:
        for x, y, z, r in ((-0.22, 0.0, 0.46, 0.17), (0.12, -0.08, 0.44, 0.14), (0.3, 0.12, 0.4, 0.1),
                           (-0.04, 0.12, 0.58, 0.12)):               # each sunk into the top or another bubble
            b.sphere((x * k, y * k, z * k), r * k, bubbles, segments=8, rings=5)
    return [b.finalize(name, mat)]


def build_brush(mat):
    """The brush, held by its handle: the pivot is the middle of the handle and the head points forward (-Y), the
    bristles down, so a stroke reads from the player's camera. The head is the biggest part, so it is `Handle`."""
    name = "CleanACat_Tool_Brush"
    b = Builder()
    b.box((0, 0, 0), (0.16, 0.6, 0.12), "wood_light")                          # handle, the grip
    b.box((0, -0.5, 0.02), (0.56, 0.44, 0.14), "spa_bubblegum")                # the back of the head
    for i, y in enumerate((-0.66, -0.5, -0.34)):                               # three rows of bristles
        b.box((0, y, -0.1), (0.48, 0.09, 0.14), "foam" if i != 1 else "spa_cream", bevel=False)
    return [b.finalize(name, mat)]


# -- #123 drafts for the other wash steps ------------------------------------------------------------------------
_ALONG_Y = (math.radians(90), "X")              # a cylinder lying front to back: its top end toward -Y
SHOWER_TILT = math.radians(115)                 # the shower head looks forward and 25 degrees down
SHOWER_HEAD = Vector((0.0, -0.2, 0.56))         # the middle of the head
DRYER_Z = 0.52                                  # the barrel's axis above the middle of the grip
DRYER_MOUTH = -0.86                             # the nozzle's mouth


def _shower_rot():
    return Matrix.Rotation(SHOWER_TILT, 3, "X")


def build_shower(mat):
    """The rinse step. Held by the grip, pivot at its middle; the head sprays forward and down."""
    b = Builder()
    b.cyl((0, 0, 0), 0.13, 0.76, "spa_tile", segments=8)                       # the grip
    b.cyl((0, 0, -0.2), 0.16, 0.12, "bow_sky", segments=8, bevel=False)        # a collar low on the grip
    b.cyl((0, 0, -0.45), 0.08, 0.16, "metal", segments=8, bevel=False)         # the hose stub
    b.sphere((0, -0.03, 0.42), 0.19, "bow_sky", segments=6, rings=4)          # the joint under the head
    rot, c = _shower_rot(), SHOWER_HEAD
    b.cyl(c, 0.3, 0.26, "bow_sky", segments=10, rot=rot, radius2=0.4)          # the head, flaring to the front
    b.cyl(c + rot @ Vector((0, 0, 0.14)), 0.33, 0.04, "spa_tile", segments=10, rot=rot, bevel=False)   # face plate
    for x, y in ((0, 0), (0.17, 0.0), (-0.17, 0.0), (0.0, 0.17), (0.0, -0.17)):                       # five holes
        b.box(c + rot @ Vector((x, y, 0.165)), (0.09, 0.09, 0.03), "water", bevel=False, rot=rot)
    return [b.finalize("CleanACat_Tool_Shower", mat)]


def shower_rbx_extras():
    rot = _shower_rot()
    at = Matrix.Translation(SHOWER_HEAD + rot @ Vector((0, 0, 0.19))) @ rot.to_4x4()   # +Z (Roblox +Y) along the spray
    return {"attachments": [("CleanACat_Tool_Shower", "Nozzle", at)]}


def build_comb(mat):
    """Picks burrs out of fur. Held by the handle, pivot at its middle; the teeth point down and the spine forward."""
    b = Builder()
    b.box((0, 0.3, 0), (0.16, 0.62, 0.32), "bow_mint")                         # the handle
    b.box((0, -0.38, 0.07), (0.12, 0.84, 0.16), "bow_mint")                    # the spine, a hair lower on top
    for i in range(7):                                                         # teeth, sunk into the spine
        b.box((0, -0.74 + i * 0.115, -0.15), (0.09, 0.06, 0.36), "metal", bevel=False)
    return [b.finalize("CleanACat_Tool_Comb", mat)]


def build_tweezers(mat):
    """Lifts a burr or a leaf off the fur. Pivot at the middle; the arms open toward the front."""
    b = Builder()
    b.box((0, 0.56, 0), (0.2, 0.16, 0.24), "metal")                            # the bend at the back
    for sx in (1, -1):
        rot = Matrix.Rotation(math.radians(10 * sx), 3, "Z")
        b.box((sx * 0.105, 0.0, 0), (0.09, 1.16, 0.2), "metal", rot=rot)       # an arm
        b.box((sx * 0.14, 0.1, 0), (0.07, 0.42, 0.26), "bow_pink", rot=rot)    # its grip pad, proud of the arm
    return [b.finalize("CleanACat_Tool_Tweezers", mat)]


def build_towel(mat):
    """The towel dry step: folded in three, two cream stripes near one end. Pivot at the middle."""
    b = Builder()
    for i, (w, d) in enumerate(((1.04, 0.74), (1.0, 0.7), (0.96, 0.66))):
        b.box((0, 0, -0.12 + i * 0.12), (w, d, 0.13), "spa_bubblegum")         # each fold sunk into the one below
    for x in (0.2, 0.36):                                                      # stripes over the top fold
        b.box((x, 0, 0.125), (0.09, 0.68, 0.14), "spa_cream", bevel=False)
    return [b.finalize("CleanACat_Tool_Towel", mat)]


def build_clipper(mat):
    """Trims a claw. Two thin blades joined at the back and open at the jaws, a long lever on a pin with a sky blue
    thumb pad at its tail. Pivot at the middle, the jaws to the front."""
    b = Builder()
    b.box((0, 0, -0.07), (0.3, 1.0, 0.06), "metal")                            # the lower blade
    b.box((0, 0.02, 0.02), (0.3, 0.98, 0.06), "metal", rot=(math.radians(-6), "X"))    # the upper, open at the jaws
    b.box((0, 0.46, -0.04), (0.26, 0.1, 0.1), "concrete", bevel=False)         # the rivet block at the back
    b.cyl((0, -0.3, 0.06), 0.06, 0.26, "concrete", segments=8, bevel=False)    # the pin
    tilt = math.radians(22)
    along = Vector((0, math.cos(tilt), math.sin(tilt)))                        # from the pin back and up
    up = Vector((0, -math.sin(tilt), math.cos(tilt)))
    pin = Vector((0, -0.3, 0.14))
    b.box(pin + along * 0.4, (0.26, 0.96, 0.06), "fur_silver", rot=(tilt, "X"))        # the lever
    b.box(pin + along * 0.7 + up * 0.045, (0.3, 0.36, 0.07), "bow_sky", rot=(tilt, "X"))   # its thumb pad
    return [b.finalize("CleanACat_Tool_Clipper", mat)]


def build_dryer(mat):
    """The blow dry step. Held by the grip, pivot at its middle; the barrel points forward."""
    b = Builder()
    b.box((0, 0.03, 0), (0.24, 0.28, 0.66), "bow_pink", rot=(math.radians(-10), "X"))        # the grip
    b.box((0, -0.13, 0.08), (0.1, 0.05, 0.16), "spa_cream", bevel=False, rot=(math.radians(-10), "X"))   # the switch
    b.cyl((0, -0.08, DRYER_Z), 0.32, 0.8, "spa_bubblegum", segments=12, rot=_ALONG_Y)        # the barrel
    b.cyl((0, 0.34, DRYER_Z), 0.26, 0.08, "metal", segments=12, rot=_ALONG_Y, bevel=False)   # the grille at the back
    b.cyl((0, -0.66, DRYER_Z), 0.27, 0.4, "spa_cream", segments=12, rot=_ALONG_Y, radius2=0.22)   # the nozzle
    return [b.finalize("CleanACat_Tool_Dryer", mat)]


def dryer_rbx_extras():
    at = Matrix.Translation((0, DRYER_MOUTH, DRYER_Z)) @ Matrix.Rotation(math.radians(90), 4, "X")   # +Z toward -Y
    return {"attachments": [("CleanACat_Tool_Dryer", "Air", at)]}


def build_shampoo(mat):
    """The lather step. A pump bottle, pivot at the middle of the bottle, the spout and the label to the front."""
    b = Builder()
    b.cyl((0, 0, 0), 0.32, 0.72, "pastel_lilac", segments=14)                  # the bottle
    b.cyl((0, 0, -0.02), 0.335, 0.34, "spa_cream", segments=14, bevel=False)   # the label, proud of it
    b.box((0, -0.33, -0.07), (0.16, 0.05, 0.13), "bow_pink", bevel=False)      # a paw on the label: the pad
    for x in (-0.1, 0.0, 0.1):                                                 # and three toes
        b.box((x, -0.33 + abs(x) * 0.12, 0.06), (0.07, 0.05, 0.07), "bow_pink", bevel=False)
    b.cyl((0, 0, 0.42), 0.3, 0.14, "pastel_lilac", segments=14, radius2=0.13, bevel=False)   # the shoulder
    b.cyl((0, 0, 0.56), 0.1, 0.18, "foam", segments=10, bevel=False)           # the pump's stem
    b.box((0, -0.1, 0.68), (0.2, 0.46, 0.1), "foam")                           # the pump head
    b.box((0, -0.29, 0.61), (0.12, 0.08, 0.1), "foam", bevel=False)            # the spout, turned down
    return [b.finalize("CleanACat_Tool_Shampoo", mat)]


ASSETS = {n: (lambda mat, n=n: build_sponge(n, mat), 400) for n in SPONGES}
ASSETS["CleanACat_Tool_Brush"] = (build_brush, 200)
ASSETS.update({"CleanACat_Tool_Shower": (build_shower, 400), "CleanACat_Tool_Comb": (build_comb, 300),
               "CleanACat_Tool_Tweezers": (build_tweezers, 200), "CleanACat_Tool_Towel": (build_towel, 200),
               "CleanACat_Tool_Clipper": (build_clipper, 200), "CleanACat_Tool_Dryer": (build_dryer, 400),
               "CleanACat_Tool_Shampoo": (build_shampoo, 400)})
EXTRAS = {"CleanACat_Tool_Shower": shower_rbx_extras, "CleanACat_Tool_Dryer": dryer_rbx_extras}
