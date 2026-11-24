"""Things stuck in a cat's fur (#126), for the "pick it out" wash step: the player lifts each one off with the
tweezers or the comb.

  CleanACat_Prop_Burr   a round seed head, moss green with darker spikes on every side, 0.4 studs across
  CleanACat_Prop_Leaf   a small leaf lying flat: a tapered blade with a darker rib and a short stalk
  CleanACat_Prop_Twig   a forked twig with a small leaf at the end of each arm

All three are green or wear green, the one family no coat and no mud uses, so on any cat they read as "a plant thing
that does not belong here". Each is drawn for a scale 1 cat (ScaleTo it by the cat's Scale and the station's
CatScale). Pivot at the middle of the underside, where it touches the fur, +Z (Roblox +Y) out of the fur: put it on
a surface with its pivot on the surface and its up along the normal. Nothing collides. Drafts: no dirty cat model
carries them yet, and the scrub contract is untouched.
"""

import math

from mathutils import Matrix, Vector

from common import Builder

BURR_R = 0.13


def build_burr(mat):
    b = Builder()
    c = Vector((0, 0, BURR_R + 0.05))
    b.sphere(c, BURR_R, "fur_moss", segments=8, rings=5)
    long = 2 * BURR_R + 0.14                                           # a spike pair is one bar through the middle
    for axis in ((1, 0, 0), (0, 1, 0), (0, 0, 1)):
        size = tuple(long if a else 0.07 for a in axis)
        b.box(c, size, "leaf_dark", bevel=False)
    for i, (rz, rx) in enumerate(((45, 50), (135, 50), (45, -50), (135, -50))):          # and four slanted pairs
        rot = Matrix.Rotation(math.radians(rz), 3, "Z") @ Matrix.Rotation(math.radians(rx), 3, "X")
        b.box(c, (0.06, 0.06, long - 0.02 - 0.004 * i), "leaf_dark", bevel=False, rot=rot)
    return [b.finalize("CleanACat_Prop_Burr", mat)]


def _blade(b, at, rot, k=1.0, sw="leaf_green", bevel=True):
    """A leaf blade lying flat, its stalk end at `at` and its point toward local -Y: four boxes, widest a third of
    the way along. Returns its length."""
    y = 0.0
    for i, (w, d) in enumerate(((0.2, 0.09), (0.32, 0.2), (0.24, 0.14), (0.13, 0.12))):
        b.box(at + rot @ Vector((0, -(y + d * k / 2), 0)), (w * k, d * k + 0.02, 0.05 - 0.003 * i), sw, bevel=bevel, rot=rot)
        y += d * k
    return y


def build_leaf(mat):
    b = Builder()
    tilt = Matrix.Rotation(math.radians(10), 3, "X")                   # the point lifts off the fur a little
    at = Vector((0, 0.27, 0.06))
    n = _blade(b, at, tilt)
    b.box(at + tilt @ Vector((0, -n * 0.42, 0.024)), (0.04, n * 0.78, 0.02), "leaf_dark", bevel=False, rot=tilt)   # rib
    b.box(at + tilt @ Vector((0, 0.07, -0.004)), (0.05, 0.16, 0.035), "leaf_dark", bevel=False, rot=tilt)          # stalk
    return [b.finalize("CleanACat_Prop_Leaf", mat)]


def build_twig(mat):
    """A forked twig, a small leaf growing from the end of each arm so it reads as a plant, not a stick."""
    b = Builder()
    z = 0.04
    stem = Matrix.Rotation(math.radians(8), 3, "Z")
    b.box(Vector((0, 0.12, z)), (0.07, 0.42, 0.07), "fur_bramble", rot=stem)                              # the stem
    fork0 = Vector((0.02, -0.06, z))
    for i, deg in enumerate((34, -30)):                                                                   # two arms
        rot = Matrix.Rotation(math.radians(deg), 3, "Z")
        length = 0.26 - 0.04 * i
        b.box(fork0 + rot @ Vector((0, -length / 2, 0.003 * (i + 1))), (0.06, length + 0.04, 0.06), "fur_bramble",
              rot=rot)
        _blade(b, fork0 + rot @ Vector((0, -length + 0.02, 0.02 + 0.004 * i)), rot, k=0.62, bevel=False)
    return [b.finalize("CleanACat_Prop_Twig", mat)]


ASSETS = {"CleanACat_Prop_Burr": (build_burr, 250), "CleanACat_Prop_Leaf": (build_leaf, 250),
          "CleanACat_Prop_Twig": (build_twig, 400)}
EXTRAS = {}
