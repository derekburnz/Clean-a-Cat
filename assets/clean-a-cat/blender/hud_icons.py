"""Five of the six HUD button pictures (#185), thirteen small screen pictures (#251, #259) and five tiny ones (#255):
CleanACat_Icon_Hud_<Name>, 512 px, see-through, with a thick ink outline.

    python hud_icons.py <out folder> [--only Index,Tools]

Runs in Blender's Python (bpy). The blend the owner picked "for now" (2026-11-24): our look mixed with his
library's HUD icons. Each picture is one bold object you can name at 48 px (ours), built fat with rounded
edges, soft light and a slight three-quarter tilt (his library's; the camera, the two lights and the outline pass are
ported from its icons.py), in Bubble Pastel colours with the UI's ink outline.

  Index     the Cat Index: a purple book with a cream cat's face on the cover and a pink bookmark
  Settings  a blue grey gear with a cream middle
  Tools     a pink toolbox thrown open, a scrub brush standing in it and a soap bottle beside it (the owner asked
            for a toolbox in place of the scrub brush, whose soap bubbles "makes no sense"; shut, it could pass for a
            lunchbox)
  Helper    a member of the human staff: head and shoulders in the spa uniform, the first look in staff.py
  Build     a blue hammer with a wooden handle (no paw on it: the owner, 2026-11-24, "the toolbox and hammer paw is
            not needed")

Ten small pictures in the same style follow them (#251), for names the UI otherwise draws as a system emoji: Camera,
Paw, Heart, Gift, Music, Speaker, Shake, Sparkle, Dice and Check. They are used in rows and badges, smaller than the
buttons, so each is one plain shape. Three more joined them (#259), the last names that drew an emoji: Pointer (the
tutorial's arrow), Star (a star earned for a wash) and Station (a bath, for the recap card's bonus row).

Six more in the button pictures' build joined them for milestone 1 (#527): Quests (a lilac clipboard with a green
tick), Shop (a little shopfront under a pink and white awning), Pets (a lilac cat's head in a pink collar with a gold
bell), Crate (the pet crate of crates.py, simplified: slats, a lilac lid with cat ears, a gold paw latch), Bow (a pink
bow) and Helpers (Jo of the real staff, spa_staff.py, in the headband and the bib apron; the Helpers button used the
older Helper picture, which has neither). Each was checked at 36 px.

Staff (#929) replaced Helpers on the Helpers button: the staff's apron on its own, no face, so it is never one helper.

Five tiny pictures came before those (#255), for the queue window: Crown (a VIP), Lock (a need whose station is not built) and
the three needs Mud, Tangles and Wet. A need draws at about 18 to 21 px on a phone, inside a round white chip, and the
lock badge at about 13 to 16 px. So each is one flat shape seen almost straight on (TINY_VIEW), in one colour that
stands off white, with at most one mark on it, and its outline is nearly twice as thick (TINY_OUTLINE), which leaves
about one pixel of ink at 20 px. Check them at 18 px in the chip, not on a big tile.

There is no coin here on purpose. The owner picked his library's own coin picture for the HUD (2026-11-24: "use
library coin ... the other new coin doesn't look as good", the paw on it was done badly), then asked for it to be
re-outlined to match. hud_coin.py does that from the library's CatCafe_Icon_Coins.png; a rebuild here must not bring a
rendered coin back.

Nothing here is a game model and nothing is uploaded: the ui-designer decides what goes into the game.
"""

import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import bpy  # noqa: E402
import numpy as np  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

import common  # noqa: E402
import palette  # noqa: E402
import staff  # noqa: E402
from common import Builder  # noqa: E402

SIZE, PAD = 512, 0.07
INK = (0x45 / 255, 0x22 / 255, 0x6B / 255)     # the UI's ink, #45226B
OUTLINE = 13                                   # px at 512: thick, so the shape holds at 48 px
SOFT = (0.1, 3)                                # bevel width and segments: rounder edges than a game model's
X = (math.radians(90), "X")                    # stands a flat shape up so it faces the camera (-Y)


def _ink_mat():
    """The outline's own colour as a flat, unlit material, for a detail drawn in ink (the book cat's eyes)."""
    m = bpy.data.materials.get("_HudInk")
    if m:
        return m
    m = bpy.data.materials.new("_HudInk")
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (*[palette.srgb_to_linear(c) for c in INK], 1.0)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(em.outputs["Emission"], out.inputs["Surface"])
    return m


def _fin(b, name, mat, tilt=0.0, ink=None):
    """One soft-edged mesh, leaned `tilt` degrees to the right (a tool held at an angle). `ink` is a second
    Builder holding what is drawn flat in the outline's colour."""
    old = common.BEVEL_SEGMENTS
    common.BEVEL_SEGMENTS = SOFT[1]
    try:
        objs = [b.finalize("CleanACat_IconArt_Hud_" + name, mat, bevel=SOFT[0])]
    finally:
        common.BEVEL_SEGMENTS = old
    if ink is not None:
        objs.append(ink.finalize("CleanACat_IconArt_Hud_" + name + "_Ink", _ink_mat(), bevel=0))
    for ob in objs:
        ob.rotation_euler = (0, math.radians(tilt), 0)
    bpy.context.view_layer.update()
    return objs


def _paw(b, x, y, z, r, swatch, rot=None, depth=0.05):
    """A paw print lying flat at (x, y, z), toes toward +Y: one pad and three toes. `rot` turns it to face out."""
    m = rot or Matrix.Identity(3)
    for dx, dy, k, sc in ((0, -0.42, 1.0, (1.2, 0.9, 1)), (-0.95, 0.5, 0.46, (1, 1, 1)), (0, 0.98, 0.46, (1, 1, 1)),
                          (0.95, 0.5, 0.46, (1, 1, 1))):
        c = Vector((x, y, z)) + m @ Vector((dx * r, dy * r, 0))
        b.cyl(tuple(c), r * k, depth, swatch, segments=14, bevel=False, rot=rot, scale=sc)


def _twinkle(b, x, y, z, r):
    """The white four-point twinkle from the library's coin picture: the set's shared highlight."""
    b.star((x, y, z), r, r * 0.3, 0.07, "foam", points=4, rot=X)


def index(mat):
    """The Cat Index: a closed book standing up, a cat's face on the cover so it is a cat collection and not just
    a book. The eyes are drawn flat in the outline's ink."""
    b, k = Builder(), Builder()
    w, h, d = 1.9, 2.4, 0.6
    b.box((0.1, 0.02, h / 2), (w - 0.14, d - 0.18, h - 0.2), "spa_cream")               # the pages
    b.box((0, d / 2 - 0.05, h / 2), (w, 0.1, h), "velvet_lilac")                        # the back cover
    b.box((0, -d / 2 + 0.05, h / 2), (w, 0.1, h), "velvet_lilac")                       # the front cover
    b.box((-w / 2 + 0.05, 0, h / 2), (0.26, d + 0.06, h + 0.04), "coat_lilac")          # the spine
    fy = -d / 2 - 0.02
    cx, cz = 0.18, 1.1
    b.cyl((cx, fy, cz), 0.64, 0.08, "spa_cream", segments=20, rot=X, scale=(1.0, 0.86, 1.0))   # the face
    for sx in (-1, 1):                                                                   # the ears
        b.prism((cx + sx * 0.38, fy + 0.01, cz + 0.44), [(-0.27, -0.12), (0.27, -0.12), (sx * 0.1, 0.46)], 0.08,
                "spa_cream", rot=X)
        b.prism((cx + sx * 0.37, fy - 0.02, cz + 0.47), [(-0.12, -0.06), (0.12, -0.06), (sx * 0.05, 0.22)], 0.04,
                "nose_bubblegum", rot=X)
        k.box((cx + sx * 0.26, fy - 0.05, cz + 0.05), (0.18, 0.04, 0.3), "coat_inky", bevel=False)   # the eyes
    b.box((cx, fy - 0.05, cz - 0.2), (0.17, 0.04, 0.11), "nose_bubblegum")               # the nose
    b.box((0.5, 0.08, -0.14), (0.26, 0.05, 0.5), "bow_pink")                             # the bookmark
    _twinkle(b, 0.82, fy - 0.02, 2.26, 0.34)
    return _fin(b, "Index", mat, ink=k)


def settings(mat):
    """A gear: eight square teeth, a darker hub and a cream middle."""
    b = Builder()
    b.cyl((0, 0, 0), 0.84, 0.44, "fur_blue", segments=24, rot=X)
    for i in range(8):
        a = math.radians(45 * i)
        b.box((0.94 * math.sin(a), 0, 0.94 * math.cos(a)), (0.46, 0.38, 0.44), "fur_blue", rot=(a, "Y"))
    b.cyl((0, -0.05, 0), 0.45, 0.44, "fur_slate", segments=20, rot=X)
    b.cyl((0, -0.09, 0), 0.22, 0.44, "spa_cream", segments=16, rot=X)
    return _fin(b, "Settings", mat)


def tools(mat):
    """The wash tools: a fat pink toolbox with its lid thrown open, a scrub brush standing in it with its white
    bristles to the front and a soap bottle with a pump beside it, and a gold latch. No paw on the front: the owner
    asked for it to go (2026-11-24, "the toolbox and hammer paw is not needed"). (The first draft was
    a scrub brush with soap bubbles; the owner: "the bubbles on the back of brush makes no sense ... a toolbox would
    be better". Shut, the toolbox could pass for a lunchbox at 48 px (Review-QA, #234), so #242 opened it. On a phone
    the button is about 36 pt, where a brush lying inside the box blurred into it, so #247 stood the brush up to
    break the outline, and made the carry handle tall so it still shows above the lid: that handle is what says
    "toolbox".) Nothing may poke through the lid: it opens 44 degrees, and the tools stand in front of its edge."""
    b = Builder()
    w, d = 2.4, 1.4
    b.box((0, 0, 0.62), (w, d, 1.24), "spa_bubblegum")                                   # the box
    up = Matrix.Rotation(math.radians(-44), 3, "X")                                      # the lid, hinged at the back
    hinge = Vector((0, d / 2 + 0.07, 1.26))

    def lid(c, size, swatch):
        b.box(tuple(hinge + up @ (Vector(c) - hinge)), size, swatch, rot=up)

    lid((0, 0, 1.54), (w + 0.14, d + 0.14, 0.56), "nose_bubblegum")
    for sx in (-1, 1):                                                                   # the carry handle: tall
        lid((sx * 0.66, -0.3, 2.1), (0.26, 0.32, 0.64), "spa_cream")                     # and near the lid's front, so
    lid((0, -0.3, 2.5), (1.8, 0.38, 0.28), "spa_cream")                                  # it shows above the open lid
    b.box((0, -d / 2 - 0.1, 0.9), (0.5, 0.14, 0.5), "gold_mid")                          # the latch
    lean = Matrix.Rotation(math.radians(-20), 3, "Y") @ Matrix.Rotation(math.radians(12), 3, "X")
    foot = Vector((-0.72, -0.45, 0.9))                                                    # a scrub brush standing at

    def brush(c, size, swatch):                                                          # the left end, leaning out
        b.box(tuple(foot + lean @ Vector(c)), size, swatch, rot=lean)

    brush((0, 0, 0.7), (0.3, 0.26, 1.4), "spa_sky")                                      # its handle,
    brush((0, 0, 1.8), (0.86, 0.34, 1.0), "spa_sky")                                     # its back
    brush((0, -0.22, 1.8), (0.72, 0.2, 0.84), "foam")                                    # and its bristles
    b.cyl((0.6, -0.42, 1.65), 0.28, 0.9, "spa_mint", segments=14)                        # a soap bottle and its pump
    b.cyl((0.6, -0.52, 2.22), 0.12, 0.26, "spa_cream", segments=12)
    b.box((0.52, -0.6, 2.4), (0.42, 0.2, 0.14), "spa_cream")
    return _fin(b, "Tools", mat)


def build(mat):
    """Build mode: a fat hammer with a wooden handle, a flat face one side and a claw the other. Plain: the owner
    asked for the white paw on its head to go (2026-11-24)."""
    b = Builder()
    b.box((0, 0, 0.8), (0.6, 0.6, 1.6), "caramel_wood")                                  # the handle
    b.box((0, 0, 2.1), (1.5, 0.9, 1.0), "bow_sky")                                       # the head
    b.box((-0.95, 0, 2.1), (0.38, 1.06, 1.2), "bow_sky")                                 # its flat face
    b.prism((1.05, 0, 2.1), [(-0.3, 0.5), (-0.3, -0.5), (0.42, -0.42), (0.42, -0.1)], 0.84, "bow_sky",
            rot=X)                                                                       # the claw
    return _fin(b, "Build", mat, tilt=22)


def helper(mat):
    """The helper: a person on the spa's staff. The owner, 2026-11-24: "helpers are likely going to be staff like
    humans", then a split: human staff do the washing and the kitten stays as the mascot. A chunky head and shoulders
    of the first staff look in staff.py, in the same uniform as the staff portraits (mint smock, cream collar, paw
    name badge, no hat). The kitten head this button had before is in git history (#211)."""
    _, skin, hair, _, blush = staff.LOOKS[0]
    b, k = Builder(), Builder()
    b.box((0, 0, 0.5), (2.2, 1.2, 0.68), staff.SMOCK)                                    # the smock's shoulders
    b.box((0, 0, 0.86), (1.8, 1.3, 0.12), staff.TRIM)                                    # its collar and two points
    for sx in (-1, 1):
        b.prism((sx * 0.3, -0.62, 0.6), [(-0.28, 0.2), (0.0, -0.22), (0.28, 0.2)], 0.08, staff.TRIM, rot=X)
    b.box((0.76, -0.61, 0.47), (0.48, 0.06, 0.36), staff.TRIM)                           # the name badge
    _paw(b, 0.76, -0.65, 0.46, 0.11, staff.BADGE_PAW, rot=Matrix.Rotation(math.radians(90), 3, "X"), depth=0.04)
    b.box((0, 0, 1.62), (1.5, 1.4, 1.5), skin)                                           # the head
    b.box((0, 0, 2.36), (1.7, 1.6, 0.42), hair)                                          # hair: top, swept fringe,
    b.prism((0, -0.79, 2.12), [(-0.9, 0.22), (-0.9, -0.3), (0.9, -0.02), (0.9, 0.22)], 0.14, hair, rot=X)
    for sx in (-1, 1):                                                                   # a lock each side, sides,
        b.box((sx * 0.72, -0.7, 1.5), (0.3, 0.24, 1.1), hair)
        b.box((sx * 0.8, 0.08, 1.58), (0.14, 1.46, 1.26), hair)
    b.box((0, 0.78, 1.6), (1.7, 0.14, 1.3), hair)                                        # back
    b.sphere((0, 0.4, 2.62), 0.44, hair, segments=10, rings=6)                           # and a bun
    fy = -0.72
    for sx in (-1, 1):
        k.box((sx * 0.3, fy, 1.6), (0.19, 0.04, 0.34), "coat_inky", bevel=False)         # the eyes
        b.box((sx * 0.3 + 0.04, fy - 0.03, 1.7), (0.07, 0.04, 0.09), "foam", bevel=False)
        b.cyl((sx * 0.47, fy, 1.27), 0.1, 0.04, blush, segments=10, bevel=False, rot=X)   # round cheeks, as on the models (#776)
        k.box((sx * 0.21, fy, 1.24), (0.09, 0.04, 0.09), "coat_inky", bevel=False)       # the smile's corners
    k.box((0, fy, 1.15), (0.42, 0.04, 0.09), "coat_inky", bevel=False)                   # the smile
    return _fin(b, "Helper", mat, ink=k)


# --- the small pictures (#251): row and badge icons, used smaller than the buttons, so each is one plain shape ---

def camera(mat):
    """Photo: a sky blue camera, a cream lens ring round a dark lens, a pink shutter button."""
    b, k = Builder(), Builder()
    b.box((0, 0, 0.75), (2.4, 1.0, 1.5), "spa_sky")                                      # the body
    b.box((-0.5, 0, 1.64), (0.9, 0.8, 0.32), "spa_sky")                                  # the viewfinder hump
    b.box((0.72, 0, 1.6), (0.46, 0.5, 0.24), "nose_bubblegum")                           # the shutter button
    b.cyl((0.12, -0.56, 0.72), 0.64, 0.3, "spa_cream", segments=24, rot=X)               # the lens ring
    k.cyl((0.12, -0.72, 0.72), 0.42, 0.04, "coat_inky", segments=24, bevel=False, rot=X)  # the lens
    b.cyl((0.28, -0.75, 0.88), 0.13, 0.04, "foam", segments=12, bevel=False, rot=X)      # its glint
    b.box((-0.82, -0.52, 1.14), (0.42, 0.08, 0.26), "gold_light")                        # the flash
    return _fin(b, "Camera", mat, ink=k)


def paw(mat):
    """A cat's paw print: a wide pad and four toes in an arc, each apart from the pad so the outline runs between
    them (toes that touch the pad make one blob with round ears), in the spa's deep pink."""
    b = Builder()
    b.cyl((0, 0, -0.5), 0.72, 0.5, "nose_bubblegum", segments=24, rot=X, scale=(1.3, 1, 0.82))
    for dx, dz in ((-1.02, 0.12), (-0.38, 0.74), (0.38, 0.74), (1.02, 0.12)):
        b.cyl((dx, 0, dz), 0.31, 0.5, "nose_bubblegum", segments=20, rot=X, scale=(0.9, 1, 1.15))
    return _fin(b, "Paw", mat)


def heart(mat):
    """A fat pink heart with one white glint."""
    b = Builder()
    b.prism((0, 0, 0), _heart_pts(), 0.6, "nose_bubblegum", bevel=True, rot=X)
    b.cyl((-0.52, -0.31, 0.42), 0.17, 0.04, "foam", segments=12, bevel=False, rot=X, scale=(1.5, 1, 1))
    return _fin(b, "Heart", mat)


def gift(mat):
    """A reward: a mint box with a lid, a pink ribbon both ways and a bow on top."""
    b = Builder()
    b.box((0, 0, 0.72), (1.9, 1.9, 1.44), "spa_mint")                                    # the box
    b.box((0, 0, 1.6), (2.1, 2.1, 0.4), "spa_mint")                                      # the lid
    b.box((0, 0, 0.92), (0.46, 2.14, 1.84), "nose_bubblegum")                            # the ribbon, front to back
    b.box((0, 0, 0.92), (2.14, 0.46, 1.86), "nose_bubblegum")                            # and side to side
    for sx in (-1, 1):                                                                   # the bow
        b.sphere((sx * 0.46, 0, 2.12), 0.44, "nose_bubblegum", segments=12, rings=8, scale=(1, 0.7, 0.72),
                 rot=(math.radians(sx * -18), "Y"))
    b.box((0, 0, 2.06), (0.34, 0.5, 0.36), "nose_bubblegum")
    return _fin(b, "Gift", mat)


def music(mat):
    """Music: two joined notes in purple."""
    b = Builder()
    for x, z in ((-0.7, 0.4), (0.7, 0.75)):
        b.sphere((x, 0, z), 0.46, "velvet_lilac", segments=14, rings=8, scale=(1.15, 0.7, 0.85),
                 rot=(math.radians(-20), "Y"))                                           # a note's head
        b.box((x + 0.36, 0, z + 0.98), (0.22, 0.3, 1.96), "velvet_lilac")                # and its stem
    b.prism((0.36, 0, 2.5), [(-0.82, -0.42), (0.82, -0.07), (0.82, 0.42), (-0.82, 0.07)], 0.3, "velvet_lilac",
            bevel=True, rot=X)                                                           # the beam
    return _fin(b, "Music", mat)


def speaker(mat):
    """Sound effects: a speaker and two sound waves, each wave three straight pieces. In the bath water's blue: the
    pale sky blue of the camera faded on mint and on the world's green at 36 px, and so did thinner waves (#253)."""
    b = Builder()
    b.prism((-0.75, 0, 0), [(-0.9, -0.36), (-0.35, -0.36), (0.4, -1.0), (0.4, 1.0), (-0.35, 0.36), (-0.9, 0.36)],
            0.6, "water", bevel=True, rot=X)
    for radius, span, long in ((0.74, 34, 0.52), (1.36, 30, 0.8)):
        for a in (-span, 0, span):
            t = math.radians(a)
            b.box((-0.35 + radius * math.cos(t), 0, radius * math.sin(t)), (0.34, 0.34, long), "water",
                  rot=(-t, "Y"))
    return _fin(b, "Speaker", mat)


def shake(mat):
    """Screen shake: a purple phone leaning over, with two motion marks each side."""
    b = Builder()
    b.box((0, 0, 1.1), (1.25, 0.34, 2.2), "velvet_lilac")                                # the phone
    b.box((0, -0.16, 1.2), (0.98, 0.08, 1.56), "spa_cream")                              # its screen
    b.cyl((0, -0.18, 0.2), 0.11, 0.06, "spa_cream", segments=12, bevel=False, rot=X)     # its button
    for sx in (-1, 1):
        b.box((sx * 1.0, 0, 1.1), (0.2, 0.3, 1.0), "pastel_lilac", rot=(math.radians(sx * -10), "Y"))
        b.box((sx * 1.38, 0, 1.1), (0.2, 0.3, 0.56), "pastel_lilac", rot=(math.radians(sx * -10), "Y"))
    return _fin(b, "Shake", mat, tilt=14)


def sparkle(mat):
    """Effects: one big gold four-point star and two small ones."""
    b = Builder()
    b.star((-0.1, 0, 0), 1.3, 0.44, 0.5, "fur_golden", points=4, rot=X)
    b.star((1.02, 0, 0.98), 0.56, 0.2, 0.4, "fur_golden", points=4, rot=X)
    b.star((-1.0, 0, -0.95), 0.4, 0.15, 0.4, "fur_golden", points=4, rot=X)
    return _fin(b, "Sparkle", mat)


def dice(mat):
    """Chance: a cream die showing one, two and three, the pips flat in the outline's ink."""
    b, k = Builder(), Builder()
    s = 1.8
    b.box((0, 0, s / 2), (s, s, s), "spa_cream")
    flat = Matrix.Identity(3)
    side = Matrix.Rotation(math.radians(90), 3, "Y")
    k.cyl((0, 0, s + 0.02), 0.26, 0.04, "coat_inky", segments=16, bevel=False, rot=flat)            # one, on top
    for d in (-1, 0, 1):                                                                             # three, front
        k.cyl((d * 0.48, -s / 2 - 0.02, s / 2 + d * 0.48), 0.2, 0.04, "coat_inky", segments=16, bevel=False, rot=X)
    for d in (-1, 1):                                                                                # two, the side
        k.cyl((-s / 2 - 0.02, d * 0.42, s / 2 + d * 0.42), 0.2, 0.04, "coat_inky", segments=16, bevel=False,
              rot=side)
    return _fin(b, "Dice", mat, ink=k)


def check(mat):
    """Done: a green badge with a white tick."""
    b = Builder()
    b.cyl((0, 0, 0), 1.15, 0.5, "rarity_uncommon", segments=28, rot=X)
    b.box((-0.44, -0.3, -0.2), (0.34, 0.16, 0.86), "foam", rot=(math.radians(-45), "Y"))
    b.box((0.2, -0.32, 0.06), (0.34, 0.16, 1.42), "foam", rot=(math.radians(40), "Y"))    # a hair in front of the
    # short arm, so the two fronts never share a plane where they cross
    return _fin(b, "Check", mat)


# --- the tiny pictures (#255): need chips and badges drawn at about 20 px, so one flat-on shape and a thicker outline ---

TINY_OUTLINE = 24                              # px at 512: about one pixel at 20 px, where the usual 13 is half of one
TINY_VIEW = (-8.0, 5.0)                        # almost flat on: a three-quarter tilt costs width these cannot spare


def wet(mat):
    """The Wet need: one fat water drop with a glint."""
    b = Builder()
    r, cz = 0.92, -0.32
    pts = [(0.0, 1.42)]
    for i in range(21):                              # the round bottom, anticlockwise from the upper left
        t = math.radians(148 + (392 - 148) * i / 20)
        pts.append((r * math.cos(t), cz + r * math.sin(t)))
    b.prism((0, 0, 0), pts, 0.5, "water", bevel=True, rot=X)
    b.cyl((-0.36, -0.26, -0.5), 0.2, 0.04, "foam", segments=12, bevel=False, rot=X, scale=(1, 1, 1.7))
    return _fin(b, "Wet", mat)


def mud(mat):
    """The Mud need: a brown splat with five uneven lobes and a wet highlight."""
    b = Builder()
    pts = []
    for i in range(40):
        t = 2 * math.pi * i / 40
        r = 0.98 + 0.22 * math.cos(5 * t + 0.5) + 0.07 * math.cos(3 * t)
        pts.append((r * math.cos(t), r * math.sin(t) * 0.92))
    b.prism((0, 0, 0), pts, 0.5, "mud", bevel=True, rot=X)
    b.cyl((-0.3, -0.26, 0.3), 0.26, 0.04, "mud_dust", segments=12, bevel=False, rot=X, scale=(1.5, 1, 0.8))
    return _fin(b, "Mud", mat)


def tangles(mat):
    """The Tangles need: a round ball of matted fur. Strands cross it in the outline's ink, three bowed one way and
    two the other, like a ball of wool, and one loose strand trails out low on the left, where the lock badge (low
    on the right) cannot cover it. Round on purpose: a spiky clump read as a star or a sun, too near Sparkle."""
    b, k = Builder(), Builder()
    b.cyl((0, 0, 0), 1.0, 0.5, "fur_orange", segments=28, rot=X)
    for si, (deg, bulge, offsets) in enumerate(((35, 0.3, (-0.72, -0.3, 0.12)), (120, 0.3, (-0.55, -0.08)))):
        ux, uz = math.cos(math.radians(deg)), math.sin(math.radians(deg))               # along the strand
        for off in offsets:
            n, pts = 18, []
            for i in range(n + 1):
                t = -1 + 2 * i / n
                w = off + bulge * (1 - t * t)                                            # bowed sideways
                pts.append((t * ux - w * uz, t * uz + w * ux))
            for (x0, z0), (x1, z1) in zip(pts, pts[1:]):
                mx, mz = (x0 + x1) / 2, (z0 + z1) / 2
                if math.hypot(mx, mz) > 0.85:                                            # cut off at the ball's edge
                    continue
                k.box((mx, -0.27 - 0.006 * si, mz), (0.17, 0.04, math.hypot(x1 - x0, z1 - z0) + 0.08), "coat_inky",
                      bevel=False, rot=(math.atan2(x1 - x0, z1 - z0), "Y"))
    cx, cz, mid, parts = -0.98, -0.6, 0.36, 6                                            # the loose strand: a hook
    for p in range(parts):                                                               # in short simple pieces
        f0, f1 = p / parts, (p + 1) / parts
        am = math.radians(15 - 215 * (f0 + f1) / 2)
        ox, oz = cx + mid * math.cos(am), cz + mid * math.sin(am)
        outer, inner = [], []
        for j in range(4):
            f = f0 + (f1 - f0) * j / 3
            t, w = math.radians(15 - 215 * f), 0.17 - 0.1 * f                            # it tapers
            outer.append((cx + (mid + w) * math.cos(t) - ox, cz + (mid + w) * math.sin(t) - oz))
            inner.append((cx + (mid - w) * math.cos(t) - ox, cz + (mid - w) * math.sin(t) - oz))
        b.prism((ox, 0.002 * (p % 2), oz), inner + outer[::-1], 0.4, "fur_orange", rot=X)
    end = math.radians(15 - 215)
    b.cyl((cx + mid * math.cos(end), 0.004, cz + mid * math.sin(end)), 0.07, 0.4, "fur_orange", segments=10, rot=X)
    return _fin(b, "Tangles", mat, ink=k)


def crown(mat):
    """A VIP: a yellow crown, three points and one pink gem."""
    b = Builder()
    b.box((0, 0, -0.45), (2.3, 0.5, 0.7), "fur_golden")                                  # the band
    for x, lean, tall in ((-0.82, -0.16, 0.9), (0.0, 0.0, 1.15), (0.82, 0.16, 0.9)):     # the points
        b.prism((x, 0, -0.12), [(-0.36, 0.0), (0.36, 0.0), (lean * 2.2, tall)], 0.5, "fur_golden", rot=X)
    b.cyl((0, -0.27, -0.45), 0.24, 0.06, "nose_bubblegum", segments=14, bevel=False, rot=X)   # the gem
    return _fin(b, "Crown", mat)


def lock(mat):
    """Not built yet: a blue grey padlock, a darker shackle, a keyhole in the outline's ink."""
    b, k = Builder(), Builder()
    b.box((0, 0, -0.4), (1.8, 0.6, 1.4), "fur_blue")                                     # the body
    for sx in (-1, 1):                                                                   # the shackle
        b.box((sx * 0.56, 0, 0.7), (0.28, 0.36, 0.9), "fur_slate")
    b.box((0, 0, 1.22), (1.4, 0.36, 0.3), "fur_slate")
    k.cyl((0, -0.32, -0.26), 0.2, 0.04, "coat_inky", segments=14, bevel=False, rot=X)    # the keyhole
    k.box((0, -0.32, -0.58), (0.16, 0.04, 0.44), "coat_inky", bevel=False)
    return _fin(b, "Lock", mat, ink=k)


def pointer(mat):
    """The tutorial's arrow: one fat yellow arrow pointing left, at the thing to tap. Yellow, like the warm ring the
    tutorial draws round that thing, and bright on the dimmed screen behind it."""
    b = Builder()
    pts = [(-1.4, 0.0), (-0.2, -1.15), (-0.2, -0.5), (1.35, -0.5), (1.35, 0.5), (-0.2, 0.5), (-0.2, 1.15)]
    b.prism((-0.5, 0, 0), [(x + 0.5, z) for x, z in pts], 0.6, "fur_golden", bevel=True, rot=X)
    b.cyl((0.6, -0.31, 0.22), 0.13, 0.04, "foam", segments=12, bevel=False, rot=X, scale=(2.6, 1, 1))   # a glint
    return _fin(b, "Pointer", mat)


def star(mat):
    """A star earned for a wash: one fat yellow five-point star with a white glint."""
    b = Builder()
    b.star((0, 0, 0), 1.35, 0.7, 0.6, "fur_golden", points=5, rot=X)
    b.cyl((-0.3, -0.31, 0.3), 0.15, 0.04, "foam", segments=12, bevel=False, rot=X, scale=(1.5, 1, 1))
    return _fin(b, "Star", mat)


def station(mat):
    """A station: the wash tub from the side. A blue roll-top bath with a round bottom, short gold feet, a gold tap
    at one end and white lather over the rim at the other. The tub is the bath water's deeper blue so the white
    lather and a white row behind it do not wash it out; round feet read as a cart's wheels, so these are blocks."""
    b = Builder()
    side = [(-1.35, 0.45), (-1.25, -0.1), (-1.0, -0.45), (-0.6, -0.6), (0.6, -0.6), (1.0, -0.45), (1.25, -0.1),
            (1.35, 0.45)]
    b.prism((0, 0, 0), side, 1.0, "water", bevel=True, rot=X)
    b.box((0, 0, 0.5), (3.0, 1.14, 0.24), "spa_sky")                                     # the rolled rim
    for sx in (-1, 1):                                                                   # the feet
        b.box((sx * 0.82, 0, -0.7), (0.4, 0.6, 0.3), "fur_golden", rot=(math.radians(sx * 20), "Y"))
    b.box((1.0, 0, 0.98), (0.2, 0.24, 0.72), "fur_golden")                               # the tap
    b.box((0.76, 0, 1.26), (0.68, 0.24, 0.2), "fur_golden")
    for x, z, r in ((-0.92, 0.84, 0.34), (-0.4, 0.98, 0.46), (0.14, 0.82, 0.32)):        # the lather
        b.sphere((x, 0.0, z), r, "foam", segments=12, rings=8)
    return _fin(b, "Station", mat)


# --- the menu buttons and cards of milestone 1 (#527): the same build as the button pictures above ---

def helpers(mat):
    """Helpers: Jo of the spa's staff (spa_staff.py), head and shoulders in the real uniform: the mint smock, the
    cream bib apron with its pink paw and straps, a ginger bob under the cream towelling headband with a pink paw.
    The headband and the apron are what say "works here"; the older Helper picture has neither."""
    blush = staff.LOOKS[0][4]
    skin, hair = "skin_light", "fur_ginger"
    b, k = Builder(), Builder()
    b.box((0, 0, 0.5), (2.2, 1.2, 0.68), "spa_mint")                                     # the smock's shoulders
    b.box((0, -0.6, 0.42), (1.2, 0.1, 0.56), "spa_cream")                                # the apron's bib
    for sx in (-1, 1):                                                                   # and its straps
        b.box((sx * 0.5, -0.02, 0.86), (0.24, 1.3, 0.1), "spa_cream")
    _paw(b, 0, -0.67, 0.4, 0.13, "nose_bubblegum", rot=Matrix.Rotation(math.radians(90), 3, "X"), depth=0.05)
    b.box((0, 0, 1.62), (1.5, 1.4, 1.5), skin)                                           # the head
    b.box((0, 0.02, 2.4), (1.7, 1.6, 0.36), hair)                                        # the bob: top,
    for sx in (-1, 1):
        b.box((sx * 0.8, 0.0, 1.5), (0.2, 1.56, 1.5), hair)                              # sides down to the jaw,
        b.box((sx * 0.6, -0.72, 1.92), (0.5, 0.16, 0.5), hair)                           # a fringe each side
    b.box((0, 0.78, 1.5), (1.7, 0.16, 1.5), hair)                                        # and the back
    b.box((0, 0, 2.2), (1.86, 1.76, 0.3), "spa_cream")                                   # the headband
    _paw(b, 0, -0.9, 2.19, 0.085, "nose_bubblegum", rot=Matrix.Rotation(math.radians(90), 3, "X"), depth=0.05)
    fy = -0.72
    for sx in (-1, 1):
        k.box((sx * 0.3, fy, 1.52), (0.19, 0.04, 0.34), "coat_inky", bevel=False)        # the eyes
        b.box((sx * 0.3 + 0.04, fy - 0.03, 1.62), (0.07, 0.04, 0.09), "foam", bevel=False)
        b.cyl((sx * 0.47, fy, 1.2), 0.1, 0.04, blush, segments=10, bevel=False, rot=X)    # round cheeks, as on the models (#776)
        k.box((sx * 0.21, fy, 1.17), (0.09, 0.04, 0.09), "coat_inky", bevel=False)       # the smile's corners
    k.box((0, fy, 1.08), (0.42, 0.04, 0.09), "coat_inky", bevel=False)                   # the smile
    return _fin(b, "Helpers", mat, ink=k)


def quests(mat):
    """Quests: a lilac clipboard with a gold clip, cream paper and one big green tick. A list of jobs to tick off."""
    b = Builder()
    b.box((0, 0, 1.25), (2.0, 0.26, 2.5), "velvet_lilac")                                # the board
    b.box((0, -0.15, 1.14), (1.6, 0.1, 1.94), "spa_cream")                               # the paper
    b.box((0, -0.2, 2.4), (0.96, 0.34, 0.42), "gold_mid")                                # the clip
    b.cyl((0, -0.2, 2.66), 0.22, 0.34, "gold_mid", segments=14, rot=X)
    b.box((-0.34, -0.25, 0.92), (0.3, 0.12, 0.72), "rarity_uncommon", rot=(math.radians(-45), "Y"))   # the tick
    b.box((0.18, -0.27, 1.16), (0.3, 0.12, 1.2), "rarity_uncommon", rot=(math.radians(40), "Y"))
    return _fin(b, "Quests", mat)


def shop(mat):
    """The shop: a little cream shopfront under a pink and white striped awning, a mint door and a sky window."""
    b = Builder()
    b.box((0, 0, 0.85), (2.2, 1.0, 1.7), "spa_cream")                                    # the front
    b.box((0, 0, 0.1), (2.4, 1.16, 0.2), "velvet_lilac")                                 # its step
    b.box((0.5, -0.5, 0.72), (0.62, 0.1, 1.06), "bow_mint")                              # the door
    b.box((-0.5, -0.5, 0.86), (0.72, 0.1, 0.62), "bow_sky")                              # the window
    for i in range(5):                                                                   # the awning: five stripes
        x, sw = (i - 2) * 0.5, ("nose_bubblegum", "foam")[i % 2]
        b.box((x, -0.34, 1.92), (0.5, 1.5, 0.3 + 0.006 * (i % 2)), sw, rot=(math.radians(-18), "X"))
        b.cyl((x, -1.0, 1.66), 0.21, 0.2 + 0.006 * (i % 2), sw, segments=12, rot=X)      # and a scallop on each
    b.box((0, 0.2, 2.16), (2.5, 0.8, 0.26), "velvet_lilac")                              # the sign board over it
    return _fin(b, "Shop", mat)


def pets(mat):
    """Pets: a lilac cat's head in a pink collar with a gold bell. A cat that is yours, not a customer's. The eyes
    are drawn flat in the outline's ink."""
    b, k = Builder(), Builder()
    b.sphere((0, 0, 1.1), 1.12, "coat_lilac", segments=16, rings=10, scale=(1.0, 0.72, 0.84))      # the head
    for sx in (-1, 1):
        b.prism((sx * 0.62, 0.0, 1.86), [(-0.42, -0.2), (0.42, -0.2), (sx * 0.14, 0.62)], 0.5, "coat_lilac",
                bevel=True, rot=X)                                                       # the ears
        b.prism((sx * 0.62, -0.26, 1.9), [(-0.2, -0.1), (0.2, -0.1), (sx * 0.08, 0.32)], 0.06, "nose_bubblegum",
                rot=X)
        k.box((sx * 0.4, -0.8, 1.2), (0.2, 0.04, 0.36), "coat_inky", bevel=False)        # the eyes
        b.cyl((sx * 0.72, -0.72, 0.86), 0.15, 0.05, "blush", segments=10, bevel=False, rot=X, scale=(1.3, 1, 1))
    b.box((0, -0.82, 0.92), (0.2, 0.06, 0.13), "nose_bubblegum")                         # the nose
    b.cyl((0, 0, 0.2), 0.8, 0.3, "bow_pink", segments=18, scale=(1.0, 0.72, 1.0))        # the collar
    b.sphere((0, -0.62, 0.02), 0.27, "eye_gold", segments=12, rings=8)                   # and its bell
    return _fin(b, "Pets", mat, ink=k)


def crate(mat):
    """The pet crate (crates.py, simplified): wooden slats in a lilac frame, a lilac lid with two cat ears and a
    gold paw latch on the front."""
    b = Builder()
    w, d, h = 2.2, 1.7, 1.5
    b.box((0, 0, h / 2), (w - 0.1, d - 0.1, h), "wood_light")                            # the slats
    for z in (0.5, 1.0):
        b.box((0, 0, z), (w - 0.06, d - 0.06, 0.07), "caramel_wood", bevel=False)        # the gaps between them
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.box((sx * (w / 2 - 0.12), sy * (d / 2 - 0.12), h / 2), (0.3, 0.3, h + 0.04), "pastel_lilac")   # posts
    b.box((0, 0, 0.1), (w + 0.08, d + 0.08, 0.2), "pastel_lilac")                        # the foot rail
    b.box((0, 0, h + 0.14), (w + 0.2, d + 0.2, 0.34), "velvet_lilac")                    # the lid
    for sx in (-1, 1):                                                                   # its ears
        b.prism((sx * 0.62, 0.1, h + 0.5), [(-0.36, -0.2), (0.36, -0.2), (sx * 0.1, 0.46)], 0.5, "velvet_lilac",
                bevel=True, rot=X)
    b.cyl((0, -d / 2 - 0.1, 1.02), 0.44, 0.12, "gold_mid", segments=18, rot=X)           # the latch
    _paw(b, 0, -d / 2 - 0.18, 1.0, 0.15, "spa_cream", rot=Matrix.Rotation(math.radians(90), 3, "X"), depth=0.05)
    return _fin(b, "Crate", mat)


def bow(mat):
    """The bow a washed cat wears: two fat pink loops, a knot and two tails."""
    b = Builder()
    for sx in (-1, 1):
        b.sphere((sx * 0.84, 0, 0.5), 0.86, "bow_pink", segments=14, rings=8, scale=(1.0, 0.5, 0.8),
                 rot=(math.radians(sx * -12), "Y"))                                      # the loops
        b.sphere((sx * 0.9, -0.3, 0.5), 0.4, "nose_bubblegum", segments=12, rings=6, scale=(1.0, 0.42, 0.74),
                 rot=(math.radians(sx * -12), "Y"))                                      # the fold inside each
        b.box((sx * 0.4, 0.06, -0.46), (0.5, 0.26, 0.96), "bow_pink", rot=(math.radians(sx * 24), "Y"))   # the tails
    b.box((0, -0.06, 0.5), (0.54, 0.62, 0.62), "nose_bubblegum")                         # the knot
    _twinkle(b, 1.3, -0.44, 1.02, 0.26)
    return _fin(b, "Bow", mat)


def staff_apron(mat):
    """Staff: the spa's work apron on its own, no person in it, so the Helpers button never looks like one helper
    (Derek, 2026-11-26, issue 929: "switch the helper icon to be something other then the first helper"). The cream
    bib apron of the uniform with its big pink paw, a pink neck loop, waistband, ties and hem, and a mint pocket with
    the yellow sponge and the sky brush standing in it."""
    b = Builder()
    up = Matrix.Rotation(math.radians(90), 3, "X")
    b.box((0, 0, 1.94), (0.9, 0.22, 0.96), "spa_cream")                                 # the bib, narrow: a T
    b.prism((0, 0, 0.78), [(-1.18, -0.72), (1.18, -0.72), (1.0, 0.72), (-1.0, 0.72)], 0.24, "spa_cream", bevel=True,
            rot=X)                                                                      # the skirt, flared
    b.box((0, 0, 1.46), (2.06, 0.32, 0.22), "nose_bubblegum")                           # the waistband
    b.box((0, 0, 0.1), (2.42, 0.3, 0.2), "nose_bubblegum")                              # the hem
    for sx in (-1, 1):
        b.box((sx * 1.38, 0.02, 1.3), (0.78, 0.15, 0.15), "nose_bubblegum", rot=(math.radians(sx * 34), "Y"))  # ties
        b.box((sx * 1.72, 0.02, 1.02), (0.22, 0.17, 0.22), "nose_bubblegum")                # and their ends
        b.box((sx * 0.38, 0.0, 2.68), (0.09, 0.1, 0.6), "nose_bubblegum", rot=(math.radians(sx * -24), "Y"))  # neck cord
    b.box((0, 0.0, 2.95), (0.42, 0.1, 0.09), "nose_bubblegum")
    _paw(b, 0, -0.13, 1.9, 0.16, "nose_bubblegum", rot=up, depth=0.05)
    b.box((0.42, -0.15, 0.62), (0.96, 0.1, 0.7), "spa_mint")                            # the pocket
    b.box((0.16, -0.12, 1.06), (0.5, 0.12, 0.5), "pastel_butter")                       # a big sponge in it
    b.box((0.66, -0.12, 1.2), (0.17, 0.1, 0.78), "spa_sky")                             # and a brush
    b.box((0.66, -0.12, 1.66), (0.46, 0.16, 0.26), "spa_sky")
    for dx in (-0.12, 0.0, 0.12):
        b.box((0.66 + dx, -0.12, 1.86), (0.06, 0.08, 0.16), "foam", bevel=False)       # its bristles
    return _fin(b, "Staff", mat)


def _heart_pts():
    """The usual heart curve, anticlockwise from the top notch, about 2.1 wide."""
    pts = []
    for i in range(28):
        t = -2 * math.pi * i / 28
        pts.append((16 * math.sin(t) ** 3 / 15.0,
                    (13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)) / 15.0))
    return pts


def heart_outline(mat):
    """The like how-to (#869): a heart in a soft grey with a paler inset, not yet pressed; pressed, it is the
    Heart icon. It replaced a thumbs up on 2026-11-27, so no picture in the how-to is a hand."""
    b = Builder()
    pts = _heart_pts()
    b.prism((0, 0, 0), pts, 0.6, "fur_grey", bevel=True, rot=X)
    b.prism((0, -0.3, 0.06), [(0.62 * x, 0.62 * y) for x, y in pts], 0.08, "fur_mist", bevel=False, rot=X)
    return _fin(b, "HeartOutline", mat)


def tap_dot(mat):
    """The like how-to (#869): where to tap, a soft round cream dot on a pink rim, no hand."""
    b = Builder()
    b.cyl((0, 0.06, 0), 1.0, 0.36, "spa_bubblegum", segments=32, rot=X)
    b.sphere((0, -0.1, 0), 0.74, "spa_cream", segments=24, rings=12, scale=(1, 0.45, 1))
    return _fin(b, "TapDot", mat)


def ring_puff(mat):
    """The like how-to (#869): a small ring burst where the finger taps, a pink ring and eight short butter rays."""
    b = Builder()
    b.ring((0, 0, 0), 0.82, 0.26, 0.4, "nose_bubblegum", segments=28, rot=X)
    for k in range(8):
        a = math.radians(45 * k + 22.5)
        c = (1.42 * math.cos(a), 0, 1.42 * math.sin(a))
        b.box(c, (0.46, 0.4, 0.2), "pastel_butter", rot=(-a, "Y"))
    return _fin(b, "RingPuff", mat)


BUILDERS = {                                       # name -> (builder, (yaw, pitch)[, outline px])
    "Index": (index, (22.0, 12.0)),
    "Settings": (settings, (-16.0, 8.0)),
    "Tools": (tools, (-24.0, 20.0)),
    "Helper": (helper, (-18.0, 10.0)),
    "Build": (build, (-14.0, 8.0)),
    "Camera": (camera, (-18.0, 12.0)),               # the small pictures (#251)
    "Paw": (paw, (-14.0, 8.0)),
    "Heart": (heart, (-14.0, 8.0)),
    "Gift": (gift, (-28.0, 22.0)),
    "Music": (music, (-14.0, 8.0)),
    "Speaker": (speaker, (-14.0, 8.0)),
    "Shake": (shake, (-14.0, 8.0)),
    "Sparkle": (sparkle, (-14.0, 8.0)),
    "Dice": (dice, (-30.0, 26.0)),
    "Check": (check, (-14.0, 8.0)),
    "Pointer": (pointer, (-10.0, 6.0)),
    "Star": (star, (-14.0, 8.0)),
    "Station": (station, (-14.0, 10.0)),
    "Quests": (quests, (-20.0, 12.0)),               # the menu buttons and cards of milestone 1 (#527)
    "Shop": (shop, (-22.0, 14.0)),
    "Pets": (pets, (-14.0, 8.0)),
    "Crate": (crate, (-28.0, 20.0)),
    "Bow": (bow, (-10.0, 6.0)),
    "Helpers": (helpers, (-18.0, 10.0)),
    "Staff": (staff_apron, (-18.0, 10.0)),          # the Helpers button with no face (#929)
    "HeartOutline": (heart_outline, (-14.0, 8.0)),   # the like how-to's pictures (#869), no hands
    "TapDot": (tap_dot, (-10.0, 6.0)),
    "RingPuff": (ring_puff, (0.0, 0.0)),             # the hand pictures were removed 2026-11-27
    "Crown": (crown, TINY_VIEW, TINY_OUTLINE),       # the tiny pictures (#255)
    "Lock": (lock, TINY_VIEW, TINY_OUTLINE),
    "Mud": (mud, TINY_VIEW, TINY_OUTLINE),
    "Tangles": (tangles, TINY_VIEW, TINY_OUTLINE),
    "Wet": (wet, TINY_VIEW, TINY_OUTLINE),
}


def _lights():
    """A bright, even studio light from the upper left front, and a white world so the colours stay true."""
    for name in ("_IconKey", "_IconFill"):
        ob = bpy.data.objects.get(name)
        if ob:
            bpy.data.objects.remove(ob, do_unlink=True)
    key = bpy.data.lights.new("_IconKey", "SUN")
    key.energy, key.angle = 2.6, math.radians(10)
    ko = bpy.data.objects.new("_IconKey", key)
    ko.rotation_euler = (math.radians(55), 0, math.radians(-30))
    bpy.context.scene.collection.objects.link(ko)
    fill = bpy.data.lights.new("_IconFill", "SUN")
    fill.energy = 0.8
    fo = bpy.data.objects.new("_IconFill", fill)
    fo.rotation_euler = (math.radians(70), 0, math.radians(40))
    bpy.context.scene.collection.objects.link(fo)
    w = bpy.context.scene.world or bpy.data.worlds.new("World")
    bpy.context.scene.world = w
    w.use_nodes = True
    bg = w.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (1, 1, 1, 1)
    bg.inputs["Strength"].default_value = 0.7


def _camera(objs, view):
    """Orthographic, looking at the model's front (-Y) turned `yaw` degrees about the up axis and tilted `pitch`
    degrees down, framing every vertex with PAD around."""
    yaw, pitch = view
    cd = bpy.data.cameras.get("_IconCam") or bpy.data.cameras.new("_IconCam")
    cam = bpy.data.objects.get("_IconCam") or bpy.data.objects.new("_IconCam", cd)
    if cam.name not in bpy.context.scene.collection.objects:
        bpy.context.scene.collection.objects.link(cam)
    cd.type = "ORTHO"
    cd.clip_start, cd.clip_end = 0.01, 100.0
    cam.rotation_euler = (math.radians(90 - pitch), 0, math.radians(yaw))
    bpy.context.view_layer.update()
    R = cam.rotation_euler.to_matrix()
    right, up, fwd = R @ Vector((1, 0, 0)), R @ Vector((0, 1, 0)), R @ Vector((0, 0, -1))
    pts = [ob.matrix_world @ v.co for ob in objs for v in ob.data.vertices]
    us, vs = [p.dot(right) for p in pts], [p.dot(up) for p in pts]
    cu, cv = (max(us) + min(us)) / 2, (max(vs) + min(vs)) / 2
    cd.ortho_scale = max(max(us) - min(us), max(vs) - min(vs)) * (1 + 2 * PAD)
    cam.location = right * cu + up * cv + fwd * (min(p.dot(fwd) for p in pts) - 10.0)
    bpy.context.scene.camera = cam


def _outline(path, colour, width):
    """Paint a solid outline of `width` pixels behind the picture, from its alpha."""
    img = bpy.data.images.load(path, check_existing=False)
    w, h = img.size
    px = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    px = px.reshape(h, w, 4)
    a = px[:, :, 3]
    grown = a.copy()
    for dy in range(-width, width + 1):
        for dx in range(-width, width + 1):
            if dx * dx + dy * dy <= width * width:
                grown = np.maximum(grown, np.roll(np.roll(a, dy, 0), dx, 1))
    out = np.empty_like(px)
    k = a[:, :, None]
    out[:, :, :3] = px[:, :, :3] * k + np.array(colour, dtype=np.float32) * (1 - k)
    out[:, :, 3] = grown
    img.pixels.foreach_set(out.ravel())
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)


def render_icon(name, mat, out, samples=64):
    build, view, *rest = BUILDERS[name]
    outline = rest[0] if rest else OUTLINE
    common.hide_all_meshes()
    objs = build(mat)
    common.show(objs)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = samples
    sc.cycles.use_denoising = True
    sc.render.resolution_x = sc.render.resolution_y = SIZE
    sc.render.resolution_percentage = 100
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    sc.view_settings.view_transform = "Standard"
    fl = bpy.data.objects.get("_PreviewFloor")
    if fl:
        fl.hide_render = True
    _lights()
    _camera(objs, view)
    os.makedirs(out, exist_ok=True)
    path = os.path.join(out, "CleanACat_Icon_Hud_" + name + ".png")
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    _outline(path, INK, outline)
    for ob in objs:
        bpy.data.objects.remove(ob, do_unlink=True)
    return path


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    out = argv[0]
    only = argv[argv.index("--only") + 1].split(",") if "--only" in argv else list(BUILDERS)
    common.reset_scene()
    png = os.path.join(HERE, "..", "exports", palette.TEXTURE_NAME + ".png")
    mat = common.palette_material(png)
    for name in only:
        print("icon:", render_icon(name, mat, out))


if __name__ == "__main__":
    main()
