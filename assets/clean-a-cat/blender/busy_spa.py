"""Busy spa drafts (#124): the pieces of a queue the player picks from, a helper who washes too and a rare visitor.

  CleanACat_Station_WaitBench  where waiting cats sit in their carriers, three side by side, so the player sees who is
                               waiting and picks who is next. A cream top on mint legs, a mat for each carrier in its
                               own pastel, a number plate of one, two or three dots under each mat, and rolled and
                               folded towels on the shelf below. Attachments `Spot1` to `Spot3` (a carrier's pivot
                               goes here) and `Tag1` to `Tag3` above each spot for the mood or the name bubble.
  CleanACat_Station_FrontDesk  where a customer checks in: a cream desk with a bubblegum front and the spa's paw on it,
                               a mint top, a gold bell (Attachment `Bell`), an appointment book and a standing card
                               whose face is the part `Screen`. Attachment `TipJarSpot` on the top for the tip jar.
  CleanACat_NPC_Helper         a hired helper: the standing kitten body in a peach coat and a mint smock with a cream
                               hem and pocket. The smock wraps the whole chest and no customer's cat wears one, so it
                               reads as staff. Same pieces as the builder kitten, so it shares its motion. Attachments
                               `HatSlot` on the head and `ToolGrip` in its right paw (a sponge's or a brush's Handle
                               goes there). Attributes `Look` 1 and `Cap` (its cap's model name).
  CleanACat_NPC_Helper2        the second look: an ink coat with white muzzle and paws, a bubblegum smock. `Look` 2.
  CleanACat_NPC_Helper3        the third look: a custard coat with latte paws, a sky smock. `Look` 3.
  CleanACat_Prop_HelperCap     the first helper's bath cap: a puffy bubblegum cap with a cream frill, an ear shape over
                               each ear (the cap covers the ears) and a mint paw. Its pivot goes on `HatSlot`.
  CleanACat_Prop_HelperCap2    the second's: mint with a bubblegum paw
  CleanACat_Prop_HelperCap3    the third's: butter with a sky paw
  CleanACat_NPC_StarBeret      for the rare visitor: a lilac beret with a gold star pin        Attachment HatAttachment
  CleanACat_NPC_StarShades     for the rare visitor: violet shades with gold rims             Attachment FaceFrontAttachment
  CleanACat_Prop_StarPhoto     the keepsake the rare visitor leaves (#142): a gold framed photo for the spa wall with a
                               lilac rosette and a gold star. Its picture is the part `Screen`. Pivot on the wall.

The bench and the desk are named Station so they collide like the other furniture a player walks round (the bench
by an invisible `_Barrier` under its top, as its boards are too slim to collide themselves).
Both stand on the floor (pivot at the base centre, front -Y in Blender, -Z in Roblox). The visitor is a customer
(customers.py: Roblox's own R15 rig with body colours) wearing both accessories: VISITORS has the look. Original
characters only: no real person, brand or other game's character. Drafts, nothing wired.
"""

import math

from mathutils import Matrix, Vector

import build_props
import cats
import common
import stations
from common import Builder
from stations import _tris

# -- the waiting bench ---------------------------------------------------------------------------------------------
BENCH_W, BENCH_D, BENCH_H = 7.2, 3.0, 1.3        # the top is BENCH_H up: a carrier's door at a player's eye level
SPOTS = (-2.3, 0.0, 2.3)                         # each carrier spot's x
MATS = ("spa_bubblegum", "pastel_butter", "spa_sky")
MAT_TOP = BENCH_H + 0.06
TAG_Z = BENCH_H + 3.3                            # above a carrier's handle
BENCH = "CleanACat_Station_WaitBench"


def build_wait_bench(mat):
    b = Builder()
    for sx in (1, -1):
        for sy in (1, -1):
            b.box_base((sx * (BENCH_W / 2 - 0.4), sy * (BENCH_D / 2 - 0.4), 0), (0.5, 0.5, BENCH_H - 0.2), "spa_mint")
    b.box_base((0, 0, 0.34), (BENCH_W - 0.5, BENCH_D - 0.5, 0.14), "spa_cream")                  # the shelf
    b.box_base((0, 0, BENCH_H - 0.25), (BENCH_W, BENCH_D, 0.25), "spa_cream")                    # the top
    b.box((0, -BENCH_D / 2 + 0.06, BENCH_H - 0.43), (BENCH_W - 0.3, 0.1, 0.34), "spa_mint", bevel=False)   # front rail
    for i, x in enumerate(SPOTS):
        b.box_base((x, 0, BENCH_H - 0.01), (2.0, 2.7, 0.07), MATS[i])                            # a carrier's mat
        b.box((x, -BENCH_D / 2, BENCH_H - 0.43), (1.15, 0.06, 0.3), "foam", bevel=False)         # its number plate
        for k in range(i + 1):                                                                   # one, two, three
            b.box((x + (k - i / 2) * 0.32, -BENCH_D / 2 - 0.03, BENCH_H - 0.43), (0.2, 0.03, 0.2), "bow_pink",
                  bevel=False)
    z = 0.48                                                    # on the shelf, with 0.57 of room under the top
    roll = (math.radians(90), "X")
    for x, sw in ((-2.75, "spa_sky"), (-2.2, "spa_bubblegum")):
        b.cyl((x, -0.3, z + 0.25), 0.25, 1.1, sw, segments=10, rot=roll)                         # rolled towels
    for i, sw in enumerate(("spa_mint", "spa_bubblegum")):                                       # folded towels
        b.box_base((2.4, -0.3, z + i * 0.2), (1.2 - 0.08 * i, 0.9 - 0.08 * i, 0.21), sw)
    b.box_base((0.0, -0.3, z), (0.9, 0.7, 0.34), "pastel_butter")                                # a basket
    b.box_base((0.0, -0.3, z + 0.3), (0.98, 0.78, 0.08), "wood_light", bevel=False)              # its rim
    for i, (x, sw) in enumerate(((-0.2, "spa_sky"), (0.2, "spa_bubblegum"))):                    # sponges in it
        b.box_base((x, -0.3, z + 0.29), (0.34, 0.5, 0.19 + 0.04 * i), sw)
    # the top and the shelf are too slim to collide, so an invisible wall under the top keeps players out (stations.py)
    wall = stations._barrier(BENCH, mat, (BENCH_W - 0.2, BENCH_D - 0.2, BENCH_H - 0.07), at=(0.0, 0.0, 0.02))
    return [_tris(b.finalize(BENCH, mat)), wall]


def wait_bench_rbx_extras():
    atts = []
    for i, x in enumerate(SPOTS):
        atts.append((BENCH, f"Spot{i + 1}", Matrix.Translation((x, 0.0, MAT_TOP))))
        atts.append((BENCH, f"Tag{i + 1}", Matrix.Translation((x, 0.0, TAG_Z))))
    return {"attachments": atts, "attributes": {"Spots": {"Float64": len(SPOTS)}}}


# -- the front desk ------------------------------------------------------------------------------------------------
DESK_W, DESK_D, DESK_H = 4.6, 1.8, 2.6           # the top is DESK_H up
DESK = "CleanACat_Station_FrontDesk"
BELL_AT = (1.75, -0.35)
JAR_AT = (0.75, 0.05)


def build_front_desk(mat):
    b = Builder()
    front = -DESK_D / 2
    b.box_base((0, 0.06, 0), (DESK_W - 0.24, DESK_D - 0.24, 0.24), "spa_mint", bevel=False)      # the toe kick
    b.box_base((0, 0, 0.2), (DESK_W, DESK_D, DESK_H - 0.38), "spa_cream")                        # the body
    b.box((0, front - 0.01, 1.3), (DESK_W - 0.7, 0.08, 1.5), "spa_bubblegum", bevel=False)       # the front panel
    py = front - 0.06                                                                            # the spa's paw on it
    b.box((0, py, 1.05), (0.72, 0.05, 0.5), "spa_cream", bevel=False)
    for x, z in ((-0.5, 1.42), (-0.17, 1.66), (0.17, 1.66), (0.5, 1.42)):
        b.box((x, py, z), (0.26, 0.05, 0.26), "spa_cream", bevel=False)
    b.box_base((0, -0.12, DESK_H - 0.2), (DESK_W + 0.4, DESK_D + 0.5, 0.2), "spa_mint")          # the top
    bx, by = BELL_AT                                                                             # the bell
    b.cyl_base((bx, by, DESK_H - 0.01), 0.32, 0.07, "gold_dark", segments=12, bevel=False)
    b.sphere((bx, by, DESK_H + 0.06), 0.27, "gold_mid", segments=10, rings=6, scale=(1, 1, 0.8))
    b.cyl_base((bx, by, DESK_H + 0.24), 0.06, 0.1, "gold_light", segments=8, bevel=False)
    turn = Matrix.Rotation(math.radians(10), 3, "Z")                                             # the appointment book
    b.box_base((-1.6, -0.3, DESK_H - 0.01), (0.95, 0.7, 0.11), "spa_sky", rot=turn)
    b.box_base((-1.6, -0.3, DESK_H + 0.08), (0.82, 0.58, 0.035), "foam", bevel=False, rot=turn)
    b.box_base((-1.24, -0.42, DESK_H + 0.1), (0.07, 0.45, 0.05), "bow_pink", bevel=False,
               rot=Matrix.Rotation(math.radians(-20), 3, "Z"))                                   # a pencil on it
    b.box_base((-0.35, 0.3, DESK_H - 0.01), (1.0, 0.3, 0.1), "spa_cream")                        # the card's foot
    main = _tris(b.finalize(DESK, mat))
    s = Builder()
    s.box_base((-0.35, 0.3, DESK_H + 0.07), (1.2, 0.08, 0.72), "foam", bevel=False)
    screen = s.finalize(DESK + "_Screen", mat, bevel=0)
    return [main, screen]


def front_desk_rbx_extras():
    bx, by = BELL_AT
    return {"attachments": [(DESK, "Bell", Matrix.Translation((bx, by, DESK_H + 0.34))),
                            (DESK, "TipJarSpot", Matrix.Translation((JAR_AT[0], JAR_AT[1], DESK_H)))]}


# -- the helpers ---------------------------------------------------------------------------------------------------
HELPER_NAME, CAP = "CleanACat_NPC_Helper", "CleanACat_Prop_HelperCap"
CAP_R = 0.42        # a little wider than the builder's hard hat: a bath cap puffs out
# Three looks on one body, so the Helpers screen's three spots show three different helpers that share one motion.
# Each differs in coat, smock and cap at once, the three things that still read at phone size.
# model, coat spec, cap model, cap cloth, the cap's paw
_BASE = dict(rarity="Common", pattern="solid", eye_k=1.08, scale=1.0)
HELPERS = [
    (HELPER_NAME, dict(_BASE, fur="fur_peach", second="fur_peach", eyes="eye_mint", muzzle="fur_vanilla",
                       socks="fur_vanilla", smock=("spa_mint", "spa_cream")),
     CAP, "spa_bubblegum", "spa_mint"),
    (HELPER_NAME + "2", dict(_BASE, fur="fur_ink", second="fur_ink", eyes="eye_sky", muzzle="fur_white",
                             socks="fur_white", smock=("spa_bubblegum", "spa_cream")),
     CAP + "2", "spa_mint", "spa_bubblegum"),
    (HELPER_NAME + "3", dict(_BASE, fur="fur_custard", second="fur_custard", eyes="eye_violet", muzzle="fur_white",
                             socks="fur_latte", smock=("spa_sky", "spa_cream")),
     CAP + "3", "pastel_butter", "spa_sky"),
]
HELPER = HELPERS[0][1]


def _helper(i):
    name, spec = HELPERS[i][0], HELPERS[i][1]
    return lambda mat: cats.build_cat(name.replace("CleanACat_NPC_", ""), mat, spec=spec, base=name, body="work",
                                      held=False)


build_helper = _helper(0)


def helper_rbx_extras(i=0):
    spec = HELPERS[i][1]
    k = cats.scale_of(spec, "work")
    j = cats.joints(spec, "work")
    h = cats.dims(spec, "work")["head"]
    top = Vector(j["Head"]) + Vector((0.0, h["c"][1], h["top"])) * k
    paw = Vector(j["LegF2"]) + Vector((0.0, -0.01, cats.S_PAW_Z)) * k
    return {"attachments": [("_Head", "HatSlot", Matrix.Translation(top)),
                            ("_LegF2", "ToolGrip", Matrix.Translation(paw))],
            "attributes": {"Scale": {"Float64": spec["scale"]}, "Role": "Helper", "Look": {"Float64": i + 1},
                           "Cap": HELPERS[i][2]}}


def _cap(i):
    name, cloth, paw = HELPERS[i][2], HELPERS[i][3], HELPERS[i][4]

    def build(mat):
        """Drawn for a kitten at scale 0.8 and grown with it like the hard hat (build_props.FIT). Pivot at the head
        top."""
        b = Builder()
        b.sphere((0, 0, 0.05), CAP_R, cloth, segments=10, rings=5, scale=(1, 1, 0.7))            # the puff
        b.cyl_base((0, 0, -0.03), CAP_R + 0.04, 0.09, "spa_cream", segments=10, bevel=False)      # the frill
        for side in (1, -1):                           # the cap covers the ears, so it has an ear shape over each
            b.pyramid((side * 0.2, 0.045, 0.17), 0.3, 0.36, cloth, rot=Matrix.Rotation(math.radians(side * 12), 3, "Y"))
        lean = Matrix.Rotation(math.radians(-30), 3, "X")
        at = Vector((0, -CAP_R * 0.86, 0.17))
        b.box(at, (0.17, 0.04, 0.12), paw, bevel=False, rot=lean)                                 # a paw on the front
        for x in (-0.09, 0.0, 0.09):
            b.box(at + lean @ Vector((x, 0, 0.11 - 0.02 * abs(x) / 0.09)), (0.06, 0.04, 0.06), paw, bevel=False,
                  rot=lean)
        ob = _tris(b.finalize(name, mat))
        if build_props.FIT != 1.0:
            common.scale_mesh(ob, build_props.FIT)
        return [ob]
    return build


build_helper_cap = _cap(0)


# -- the rare visitor ----------------------------------------------------------------------------------------------
BERET, SHADES = "CleanACat_NPC_StarBeret", "CleanACat_NPC_StarShades"
ATTACH = {BERET: "HatAttachment", SHADES: "FaceFrontAttachment"}
# name, skin (head and arms), shirt (torso), trousers (legs), accessories: same fields as customers.LOOKS
VISITORS = [("Vivi", "skin_tan", "velvet_lilac", "pearl", (BERET, SHADES))]


def build_star_beret(mat):
    """Pivot at the top of the head. The beret sits a little to one side, its stalk up, a gold star at the front."""
    b = Builder()
    tilt = Matrix.Rotation(math.radians(-8), 3, "Y")
    b.cyl((0, 0, 0.04), 0.62, 0.12, "velvet_lilac", segments=12, bevel=False)                    # the band on the head
    b.cyl(Vector((0.1, 0.02, 0.22)), 0.86, 0.3, "velvet_lilac", segments=14, rot=tilt, radius2=0.7)   # the crown
    b.cyl(tilt @ Vector((0.1, 0.02, 0.42)), 0.06, 0.14, "velvet_lilac", segments=6, bevel=False, rot=tilt)   # stalk
    b.star((-0.22, -0.68, 0.22), 0.32, 0.15, 0.07, "rarity_legend", rot=Matrix.Rotation(math.radians(80), 3, "X"))
    return [b.finalize(BERET, mat)]


def build_star_shades(mat):
    """Pivot at the middle of the face (R15's FaceFrontAttachment, on the front of the head): gold rims, violet
    lenses proud of them, a bridge, and short arms back along the head."""
    b = Builder()
    z = 0.08                                                                                     # eye line
    for sx in (1, -1):
        b.box((sx * 0.3, -0.03, z), (0.52, 0.06, 0.38), "rarity_legend")                         # a rim
        b.box((sx * 0.3, -0.055, z), (0.42, 0.05, 0.28), "aurora_violet", bevel=False)           # its lens
        b.box((sx * 0.585, 0.2, z + 0.1), (0.08, 0.46, 0.07), "rarity_legend", bevel=False)      # an arm, into the rim
    b.box((0, -0.03, z + 0.08), (0.14, 0.05, 0.07), "rarity_legend", bevel=False)                # the bridge
    return [b.finalize(SHADES, mat)]


PHOTO = "CleanACat_Prop_StarPhoto"
PHOTO_W, PHOTO_H = 1.7, 2.1


def build_star_photo(mat):
    """The keepsake a rare visitor leaves (#142): a framed photo for the spa wall. Pivot at the middle of its back,
    which goes on the wall; front -Y. The picture is the part `Screen` (a SurfaceGui or a Decal goes there); under
    it the mat carries a paw print and a signature line, and a lilac rosette with a gold star sits on the top
    corner, so it reads as a star's signed photo before any picture is set."""
    b = Builder()
    d = 0.14
    b.box((0, -d / 2, 0), (PHOTO_W, d, PHOTO_H), "gold_mid")                                     # the frame
    b.box((0, -d - 0.005, 0), (PHOTO_W - 0.3, 0.03, PHOTO_H - 0.3), "spa_cream", bevel=False)    # the mat
    y = -d - 0.03
    b.box((-0.38, y, -0.7), (0.2, 0.02, 0.12), "velvet_lilac", bevel=False)                      # a paw print: a pad
    for dx, dz in ((-0.15, 0.1), (-0.05, 0.16), (0.05, 0.16), (0.15, 0.1)):                      # and four toes
        b.box((-0.38 + dx, y, -0.7 + dz), (0.07, 0.02, 0.07), "velvet_lilac", bevel=False)
    b.box((0.2, y, -0.66), (0.62, 0.02, 0.05), "velvet_lilac", bevel=False)                      # the signature
    b.box((0.08, y, -0.56), (0.3, 0.02, 0.04), "velvet_lilac", bevel=False,
          rot=Matrix.Rotation(math.radians(12), 3, "Y"))
    rx, rz = PHOTO_W / 2 - 0.12, PHOTO_H / 2 - 0.12                                              # the rosette
    for a in (-25, 25):
        b.box((rx + math.sin(math.radians(a)) * 0.3, -d - 0.02, rz - 0.36), (0.16, 0.03 if a < 0 else 0.026,
              0.46), "velvet_lilac", bevel=False, rot=Matrix.Rotation(math.radians(-a), 3, "Y"))  # its two tails,
        # one a hair slimmer: they cross, and two faces in one plane flicker
    face = Matrix.Rotation(math.radians(90), 3, "X")
    b.cyl((rx, -d - 0.052, rz), 0.3, 0.056, "velvet_lilac", segments=10, bevel=False, rot=face)
    b.star((rx, -d - 0.1, rz), 0.22, 0.1, 0.04, "rarity_legend", rot=face)
    main = b.finalize(PHOTO, mat)
    s = Builder()
    s.box((0, -d - 0.03, 0.2), (PHOTO_W - 0.5, 0.02, PHOTO_H - 0.9), "pastel_lilac", bevel=False)
    return [main, s.finalize(PHOTO + "_Screen", mat, bevel=0)]


def _att(name):
    return lambda: {"attachments": [(name, ATTACH[name], Matrix.Identity(4))],
                    "attributes": {"Accessory": ATTACH[name]}}


ASSETS = {
    BENCH: (build_wait_bench, 1200),
    DESK: (build_front_desk, 1200),
    BERET: (build_star_beret, 400),
    SHADES: (build_star_shades, 200),
    PHOTO: (build_star_photo, 300),
}
EXTRAS = {BENCH: wait_bench_rbx_extras, DESK: front_desk_rbx_extras, BERET: _att(BERET), SHADES: _att(SHADES)}
for _i, _look in enumerate(HELPERS):
    ASSETS[_look[0]] = (_helper(_i), 1500)
    ASSETS[_look[2]] = (_cap(_i), 300)
    EXTRAS[_look[0]] = (lambda i=_i: helper_rbx_extras(i))
