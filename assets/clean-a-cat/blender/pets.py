"""The pets (issue #527; the game's #511 and #512, switch `pets`): the eight cats a crate holds, one model each.

    CleanACat_Pet_<Name>    Common Cozy and Scrubby, Uncommon Pebble and Pickle, Rare Koi and Bamboo, Epic Coral,
                            Legendary Nimbus (the names and rarities CrateRules.PETS lists; draft names)

A pet is the roster cat's body on all fours (cats.build_cat, body A) in a coat no customer's cat wears, with spa
pieces built on: a Common has one piece, an Uncommon two, a Rare two and a tail piece, the Epic a lit gem as well,
the Legendary a halo, wings and gems. The pieces are props.py pieces (PROPS, PROPS2, PIECES), registered here under
the pet's name, so they nest and follow exactly as a special cat's do.

The star up look (a pet fuses up to star 3): gold stars standing on the rump, two at star 2 and a third, taller one
with a small lit gem at star 3. They are the objects `_Star2` and `_Star3`, child Models with the attribute
`StarLevel`; the game removes every child Model whose StarLevel is above the pet's star. Every back piece keeps the
rump clear for them (BACK_END).

Root attributes: Pet true, PetId (the name), Rarity, PetScale (the game scales the model by it; a pet is a small
cat beside the player or a worker). Attachment `Burst` in the root's first part, over the head and its piece, where
the reveal's sparkle goes. Nothing collides (the game switches collision off on every part). No rules in the model.
"""
import math

from mathutils import Matrix, Vector

import cats
import props
from common import Builder
from props import GOLD, NEON_GOLD, NEON_SKY, _heart, _rx, _ry, _rz, _tail_axes

PREFIX = "CleanACat_Pet_"
PET_SCALE = 0.7
BUDGET = 2400
BACK_END = 0.28             # a back piece ends here at the latest (the back frame's y): the stars stand behind it
STAR_Y = 0.36               # where the stars' plate lies across the rump, against the tail's root

PETS = {
    # a sleepy peach kitten fresh from the bath, a folded towel on its head
    "Cozy":    dict(rarity="Common", fur="fur_peach", second="fur_peach", eyes="eye_sky", pattern="solid",
                    muzzle="spa_cream", socks="spa_cream", tip="spa_cream", nose="nose_bubblegum", lids=True,
                    inner_ear="fur_rose", eye_k=1.1),
    # butter yellow with sandy spots, a pink bath pom on its head
    "Scrubby": dict(rarity="Common", fur="pastel_butter", second="fur_sand", eyes="eye_mint", pattern="spots",
                    muzzle="coat_cotton", nose="nose_bubblegum", tip="fur_sand", eye_k=1.1),
    # a river stone: blue grey with slate and mist patches, warm spa stones stacked on its back, a leaf on its head
    "Pebble":  dict(rarity="Uncommon", fur="fur_puddle", second="fur_slate", third="fur_mist", eyes="eye_gold",
                    pattern="patches", muzzle="fur_mist", socks="fur_mist", tip="fur_slate", eye_k=1.1),
    # a cucumber: fern green with dark green stripes, a slice for a beret and slices standing down its back
    "Pickle":  dict(rarity="Uncommon", fur="fur_fern", second="leaf_dark", eyes="eye_gold", pattern="stripes",
                    muzzle="fur_vanilla", inner_ear="fur_vanilla", socks="fur_vanilla", eye_k=1.1),
    # a koi: white with red orange and marmalade patches, a lily pad hat with a bud, a back fin and a fan tail
    "Koi":     dict(rarity="Rare", fur="coat_cotton", second="fur_ginger", third="fur_marmalade", eyes="eye_sky",
                    pattern="patches", muzzle=None, nose="nose_bubblegum", tip="fur_ginger", ears="fur_ginger",
                    eye_k=1.1),
    # a panda: white with ink legs, ears and eye patches, a bamboo sprig, a cane across its shoulders
    "Bamboo":  dict(rarity="Rare", fur="coat_cotton", second="coat_inky", eyes="eye_mint", pattern="solid",
                    muzzle=None, nose="nose_dark", ears="coat_inky", legs="coat_inky", socks="coat_inky",
                    tip="coat_inky", inner_ear="fur_charcoal", eye_k=1.1,
                    face=((0.233, 0.0, 0.3, 0.37, "coat_inky", -12), (-0.233, 0.0, 0.3, 0.37, "coat_inky", 12))),
    # a mer-cat: pink at the head through lavender to aqua at the tail, a shell tiara with a lit pearl, coral
    # branches on its back, a tail fluke
    "Coral":   dict(rarity="Epic", fur="fur_strawberry", second="fur_lavender", third="eye_mint", eyes="eye_sky",
                    pattern="gradient", muzzle="pearl", nose="nose_bubblegum", socks="pearl", inner_ear="fur_rose",
                    eye_k=1.1),
    # a cloud: white fading to sky blue, long fur, a gold sun halo, sky blue cloud wings, a lit raindrop on its tail
    "Nimbus":  dict(rarity="Legendary", fur="coat_cotton", second="pastel_sky", third="spa_sky", eyes="eye_gold",
                    pattern="gradient", muzzle=None, nose="nose_bubblegum", fluffy=True, tail_thick=0.3,
                    inner_ear="spa_sky", eye_k=1.1),
}


# ----------------------------------------------------------------------------------------------- helpers --
def _leaf(P, a, b, w, sw, up=(0, 0, 1), t=0.05):
    """A pointed leaf (a flattened ball) from point a to point b: w across, t thick along `up`."""
    a, b = Vector(a), Vector(b)
    d = b - a
    y = d.normalized()
    z = Vector(up)
    z = (z - y * z.dot(y)).normalized()
    R = Matrix((y.cross(z), y, z)).transposed()
    P.sphere(tuple((a + b) / 2), d.length / 2, sw, scale=(w / d.length, 1.0, t / d.length), rot=R, segments=8, rings=4)


def _slice(P, c, r, rot, seeds=False):
    """A cucumber slice: a dark rind, pale flesh proud of it on both faces and a green heart proud of that."""
    c = Vector(c)
    P.cyl(tuple(c), r, 0.07, "leaf_dark", rot=rot, segments=10)
    P.cyl(tuple(c), r * 0.8, 0.086, "fur_vanilla", rot=rot, segments=10)
    P.cyl(tuple(c), r * 0.3, 0.1, "fur_fern", rot=rot, segments=8)
    if seeds:                                            # on the upper face only: the other lies on the head
        for k in range(5):
            a = math.radians(72 * k + 20)
            at = c + rot @ Vector((r * 0.52 * math.cos(a), r * 0.52 * math.sin(a), 0.045))
            P.box(tuple(at), (0.045, 0.07, 0.02), "fur_fern", rot=rot @ _rz(72 * k + 110))


# ------------------------------------------------------------------------------------------- the pieces --
def onsen_towel(ctx):
    """Cozy: a sky blue towel folded on the head ahead of the ears, as bathers wear one in a hot spring, with butter
    stripes and a pink heart stitched on its front edge. The brow stays clear."""
    P = ctx.pen("head")
    y, hw = -0.2, ctx.hw
    P.box((0, y, 0.045), (2 * hw + 0.1, 0.32, 0.09), "spa_sky", bevel=True)             # across the head, side to side
    for sx in (-1, 1):                                                                  # its ends hang down the sides
        P.box((sx * (hw + 0.03), y, -0.07), (0.07, 0.3, 0.22), "spa_sky", bevel=True)
        P.box((sx * (hw + 0.032), y, -0.12), (0.076, 0.308, 0.05), "pastel_butter")
    top, turn = Vector((0.01, y + 0.005, 0.15)), _rz(5)
    P.box(tuple(top), (0.6, 0.27, 0.13), "spa_sky", rot=turn, bevel=True)               # the folded stack on top
    for sx in (-1, 1):
        P.box(tuple(top + turn @ Vector((sx * 0.2, 0, 0.008))), (0.06, 0.278, 0.13), "pastel_butter", rot=turn)
    _heart(P, (0.0, y - 0.155, 0.15), 0.075, "fur_strawberry", depth=0.035)


def bath_pom(ctx):
    """Scrubby: a pink bath pom on the head, ruffles in two pinks round a ball, and its mint cord in a loop behind."""
    P = ctx.pen("head")
    c = Vector((0.0, -0.13, 0.19))
    P.ico(tuple(c), 0.2, "spa_bubblegum")
    for i in range(6):
        a = math.radians(60 * i + 15)
        P.ico(tuple(c + Vector((0.17 * math.cos(a), 0.17 * math.sin(a), 0.03 * (-1) ** i))), 0.12,
              ("fur_strawberry", "spa_bubblegum")[i % 2])
    P.ico(tuple(c + Vector((0.0, 0.0, 0.17))), 0.11, "fur_strawberry")
    P.ring(tuple(c + Vector((0.02, 0.24, 0.1))), 0.13, 0.045, 0.045, "spa_mint", rot=_rz(12) @ _ry(90), segments=8)


def tanuki_leaf(ctx):
    """Pebble's head piece: one broad leaf lying on the crown, its stalk curling up at the back."""
    P = ctx.pen("head")
    R = _rz(24) @ _rx(-8)
    c = Vector((0.02, -0.08, 0.065))
    P.sphere(tuple(c), 0.33, "leaf_green", scale=(0.7, 1.0, 0.2), rot=R, segments=8, rings=4)
    P.box(tuple(c + R @ Vector((0, 0, 0.05))), (0.05, 0.54, 0.05), "leaf_dark", rot=R)
    P.bar(tuple(c + R @ Vector((0, 0.27, 0.02))), tuple(c + R @ Vector((0, 0.42, 0.2))), 0.06, 0.06, "leaf_dark")


def spa_stones(ctx):
    """Pebble's back piece: three warm massage stones stacked on its back, a pink blossom on the top one."""
    P = ctx.pen("back")
    P.sphere((0.0, 0.0, 0.085), 0.27, "fur_gunmetal", scale=(1.2, 0.85, 0.4), segments=10, rings=5)
    P.sphere((0.03, 0.01, 0.24), 0.2, "fur_dusty", scale=(1.15, 0.9, 0.42), segments=10, rings=5)
    P.sphere((-0.02, 0.0, 0.36), 0.14, "fur_charcoal", scale=(1.1, 0.95, 0.45), segments=8, rings=5)
    for k in range(5):
        a = math.radians(72 * k)
        P.ico((-0.02 + 0.06 * math.cos(a), 0.06 * math.sin(a), 0.435), 0.05, "fur_strawberry", scale=(1, 1, 0.6))
    P.ico((-0.02, 0.0, 0.455), 0.04, "pastel_butter")


def cucumber_beret(ctx):
    """Pickle's head piece: a cucumber slice worn flat on the head like a beret, tipped to one side."""
    P = ctx.pen("head")
    _slice(P, (0.06, -0.15, 0.05), 0.27, _ry(9) @ _rx(5), seeds=True)


def cucumber_plates(ctx):
    """Pickle's back piece: three slices standing down its back like a little dinosaur's plates, turned left and
    right in turn so they read from behind, from the side and from above."""
    P = ctx.pen("back")
    for i, (y, r) in enumerate(((-0.13, 0.21), (0.04, 0.18), (0.19, 0.15))):
        _slice(P, (0.0, y, r * 0.86), r, _rz(32 * (-1) ** i) @ _rx(90))


def lily_pad(ctx):
    """Koi's head piece: a lily pad for a hat (the ears poke through it) with a pink bud standing on it."""
    P = ctx.pen("head")
    P.cyl((0.0, -0.06, 0.03), 0.3, 0.06, "leaf_green", segments=12)
    P.cyl((0.0, -0.06, 0.035), 0.12, 0.066, "leaf_dark", segments=8)
    c = Vector((-0.02, -0.14, 0.17))
    P.sphere(tuple(c), 0.12, "fur_strawberry", scale=(1, 1, 1.15), segments=8, rings=5)
    P.pyramid(tuple(c + Vector((0, 0, 0.16))), 0.15, 0.16, "fur_rose")
    for k in range(3):
        R = _rz(120 * k + 40) @ _rx(-32)
        P.box(tuple(c + R @ Vector((0, 0, 0.02)) + Vector((0, 0, -0.08))), (0.1, 0.04, 0.16), "fur_rose", rot=R)


def koi_fins(ctx):
    """Koi's back piece: a red orange back fin along the spine and a small fin out from each shoulder; on the tail
    a fan of two lobes with white tips (the object `_Tail_Fan`, riding the Tail)."""
    P = ctx.pen("back")
    chain = [(-0.22, 0.0), (-0.17, 0.2), (-0.03, 0.34), (0.11, 0.3), (0.2, 0.13), (0.23, 0.0)]
    P.fan((0.0, 0.0, -0.02), (0.0, 0.0), chain, 0.07, "fur_ginger", rot=_rz(90) @ _rx(90))
    P.box((0.0, 0.0, 0.02), (0.13, 0.42, 0.1), "fur_ginger", bevel=True)                 # the fin's root
    for sx in (-1, 1):
        P.box((sx * 0.5, -0.1, -0.2), (0.3, 0.2, 0.055), "fur_ginger", rot=_rz(-sx * 26) @ _ry(sx * 18))
    tip, d, _th, a, _b = _tail_axes(ctx)
    T = ctx.piece("Tail_Fan", "tail", tuple(tip))
    X = Vector((1.0, 0.0, 0.0))
    for sx in (-1, 1):
        u = (d * math.cos(math.radians(36)) + sx * X * math.sin(math.radians(36))).normalized()
        t = 0.06 + 0.012 * (sx > 0)                       # the lobes cross at the root: no two faces in one plane
        T.bar(tuple(tip - u * 0.06), tuple(tip + u * 0.32), 0.19, t, "fur_ginger", up=tuple(a))
        T.bar(tuple(tip + u * 0.28), tuple(tip + u * 0.4), 0.205, t + 0.03, "coat_cotton", up=tuple(a))


CANE, CANE_NODE = "eye_chartreuse", "leaf_dark"


def bamboo_sprig(ctx):
    """Bamboo's head piece: a short cane standing between the ears with three leaves fanned from its top."""
    P = ctx.pen("head")
    R = _ry(-10)
    base = Vector((0.0, -0.1, -0.02))
    top = base + R @ Vector((0, 0, 0.34))
    P.cyl(tuple((base + top) / 2), 0.065, 0.34, CANE, rot=R, segments=8)
    P.cyl(tuple(base + R @ Vector((0, 0, 0.17))), 0.08, 0.045, CANE_NODE, rot=R, segments=8)
    for k, (dx, dz, ln) in enumerate(((-0.3, 0.2, 0.36), (0.06, 0.34, 0.4), (0.34, 0.1, 0.36))):
        u = Vector((dx, -0.03 + 0.03 * k, dz)).normalized()
        _leaf(P, top - u * 0.03, top + u * ln, 0.15, "leaf_green", up=(0, 1, 0), t=0.05)


def bamboo_yoke(ctx):
    """Bamboo's back piece: a bamboo cane carried across the shoulders, a pair of leaves at each end; on the tail
    two leaves (the object `_Tail_Leaf`, riding the Tail)."""
    U = ctx.pen("up")
    y, z = 0.14, 0.075
    U.cyl((0.0, y, z), 0.075, 1.16, CANE, rot=_ry(90), segments=8)
    for x in (-0.42, -0.14, 0.14, 0.42):
        U.cyl((x, y, z), 0.09, 0.045, CANE_NODE, rot=_ry(90), segments=8)
    for sx in (-1, 1):
        end = Vector((sx * 0.56, y, z))
        _leaf(U, end, end + Vector((sx * 0.2, 0.1, 0.24)), 0.14, "leaf_green", up=(0, 1, 0))
        _leaf(U, end, end + Vector((sx * 0.26, 0.16, -0.06)), 0.13, "leaf_dark", up=(0, 0, 1))
    tip, d, _th, a, _b = _tail_axes(ctx)
    T = ctx.piece("Tail_Leaf", "tail", tuple(tip))
    X = Vector((1.0, 0.0, 0.0))
    for sx, sw in ((-1, "leaf_green"), (1, "leaf_dark")):
        u = (d * math.cos(math.radians(40)) + sx * X * math.sin(math.radians(40))).normalized()
        _leaf(T, tip - u * 0.06, tip + u * 0.3, 0.15, sw, up=tuple(a), t=0.055 + 0.01 * (sx > 0))


def shell_tiara(ctx):
    """Coral's head piece: a scallop shell standing between the ears on a gold band, a smaller pale shell on its
    face and one small lit pearl at its foot (the object `_Glow`)."""
    P = ctx.pen("head")
    G = ctx.piece("Glow", "head", (0, -0.14, 0.1))
    y = -0.12

    def scallop(r, sw, yy, depth, a0, step, n):       # the two shells' ribs at different angles: no shared planes
        pts = []
        for k in range(n):
            a = math.radians(a0 + step * k)
            rr = r * (1.0 if k % 2 else 0.9)
            pts.append((rr * math.cos(a), rr * math.sin(a)))
        P.fan((0.0, yy, 0.03), (0.0, 0.0), pts, depth, sw, rot=_rx(90))

    P.box((0, y, 0.035), (0.52, 0.1, 0.09), GOLD)
    scallop(0.4, "fur_rose", y, 0.07, 18, 24, 7)
    for k, deg in enumerate((38, 64, 90, 116, 142)):   # the ribs, proud of the shell's face
        u = Vector((math.cos(math.radians(deg)), 0.0, math.sin(math.radians(deg))))
        a = Vector((0.0, y - 0.03 - 0.003 * k, 0.05))
        P.bar(tuple(a + u * 0.08), tuple(a + u * 0.36), 0.05, 0.03, "fur_strawberry", up=(0, 1, 0))
    G.ico((0.0, y - 0.075, 0.1), 0.065, NEON_SKY)


def coral_branches(ctx):
    """Coral's back piece: two branching corals growing from the shoulders, pale buds on their tips; on the tail a
    wide aqua fluke (the object `_Tail_Fluke`, riding the Tail)."""
    U = ctx.pen("up")
    y0 = 0.13
    U.box((0, y0, 0.04), (0.42, 0.2, 0.12), "eye_mint", bevel=True)
    for sx in (-1, 1):
        a = Vector((sx * 0.13, y0, 0.05))
        b = Vector((sx * 0.33, y0 + 0.05, 0.36))
        U.bar(tuple(a), tuple(b), 0.1, 0.1, "neon_pink", up=(0, 1, 0))
        tips = [b + Vector((sx * 0.2, 0.05, 0.2)), b + Vector((-sx * 0.1, 0.02, 0.24)),
                (a + b) / 2 + Vector((sx * 0.24, 0.07, 0.04))]
        for k, t in enumerate(tips):
            U.bar(tuple((b if k < 2 else (a + b) / 2) - Vector((0, 0, 0.02))), tuple(t), 0.075, 0.075 + 0.006 * k,
                  "neon_pink", up=(0, 1, 0))
            U.ico(tuple(t), 0.062, "fur_rose")
    tip, d, _th, a_, _b = _tail_axes(ctx)
    T = ctx.piece("Tail_Fluke", "tail", tuple(tip))
    X = Vector((1.0, 0.0, 0.0))
    T.box(tuple(tip - d * 0.01), (0.2, 0.2, 0.1), "sign_teal", rot=Matrix((X, a_, d)).transposed())
    for sx in (-1, 1):
        u = (d * 0.45 + sx * X * 0.9).normalized()
        _leaf(T, tip - u * 0.04, tip + u * 0.4, 0.24, "eye_mint", up=tuple(a_), t=0.07 + 0.01 * (sx > 0))


def sun_halo(ctx):
    """Nimbus's head piece: a gold halo held over the head on a stalk from the back of the crown, short sun rays
    round it and one small lit gem at its front (the object `_Glow`)."""
    P = ctx.pen("head")
    G = ctx.piece("Glow", "head", (0, 0.0, 0.5))
    z, r = 0.5, 0.3
    P.bar((0.0, 0.3, -0.04), (0.0, r + 0.02, z), 0.06, 0.06, GOLD, up=(0, 1, 0))
    P.ring((0.0, 0.0, z), r, 0.085, 0.07, GOLD, segments=12)
    for k in range(8):
        a = math.radians(45 * k + 22.5)
        P.box(((r + 0.05) * math.cos(a), (r + 0.05) * math.sin(a), z), (0.14, 0.075, 0.05), "gold_light",
              rot=_rz(45 * k + 22.5))
    G.ico((0.0, -r + 0.03, z + 0.01), 0.07, NEON_GOLD)


def cloud_wings(ctx):
    """Nimbus's back piece: two wings of sky blue cloud puffs with a small lit gold gem on each tip (the object
    `_Wings_Glow`); on the tail a lit raindrop (`_Tail_Drop_Glow`, riding the Tail). The puffs are blue, never
    white: white puffs on a cat read as foam not yet rinsed."""
    U = ctx.pen("up")
    G = ctx.piece("Wings_Glow", "up", (0, 0.14, 0.3))
    y0 = 0.14
    U.box((0, y0, 0.04), (0.36, 0.2, 0.12), "spa_sky", bevel=True)
    for sx in (-1, 1):
        puffs = ((0.26, 0.0, 0.2, 0.2, "pastel_sky"), (0.5, 0.06, 0.34, 0.18, "pastel_sky"),
                 (0.72, 0.13, 0.46, 0.14, "pastel_sky"), (0.5, 0.05, 0.14, 0.14, "spa_sky"),
                 (0.74, 0.12, 0.27, 0.11, "spa_sky"))
        for dx, dy, dz, r, sw in puffs:
            U.sphere((sx * dx, y0 + dy, dz), r, sw, segments=8, rings=5)
        G.ico((sx * 0.84, y0 + 0.16, 0.56), 0.055, NEON_GOLD)
    tip, d, th, _a, _b = _tail_axes(ctx)
    T = ctx.piece("Tail_Drop_Glow", "tail", tuple(tip))
    T.ico(tuple(tip + d * 0.05), th * 0.62, NEON_SKY, scale=(1, 1, 1.2))


HEAD = {"Cozy": onsen_towel, "Scrubby": bath_pom, "Pebble": tanuki_leaf, "Pickle": cucumber_beret,
        "Koi": lily_pad, "Bamboo": bamboo_sprig, "Coral": shell_tiara, "Nimbus": sun_halo}
BACK = {"Pebble": spa_stones, "Pickle": cucumber_plates, "Koi": koi_fins, "Bamboo": bamboo_yoke,
        "Coral": coral_branches, "Nimbus": cloud_wings}
EXTRA = {"Koi": {"Tail_Fan": "Tail"}, "Bamboo": {"Tail_Leaf": "Tail"},
         "Coral": {"Glow": "Prop", "Tail_Fluke": "Tail"},
         "Nimbus": {"Glow": "Prop", "Wings_Glow": "Prop2", "Tail_Drop_Glow": "Tail"}}
for _n in PETS:                                         # the pets' pieces are props.py pieces under the pet's name
    assert _n not in props.PROPS and _n not in cats.ROSTER and _n not in cats.SPECIAL_CATS, _n
    props.PROPS[_n] = ("Head", HEAD[_n])
    if _n in BACK:
        props.PROPS2[_n] = ("Back", BACK[_n])
    if _n in EXTRA:
        props.PIECES[_n] = EXTRA[_n]


# --------------------------------------------------------------------------------------------- the stars --
def _stars(spec):
    """The star up look in the Body's space: {suffix: (Builder, pivot)}. `_Star2` is a gold plate across the rump
    against the tail's root with a star standing at each end, turned a little outward; `_Star3` a taller star on a
    stem between them, and `_Star3_Glow` the small lit gem at its heart."""
    (_x0, y0, z0), (_sx, _sy, sz) = cats.dims(spec, "walk")["body"]
    at = Vector((0.0, y0 + STAR_Y, z0 + sz / 2))
    two, three, glow = Builder(), Builder(), Builder()
    two.box((0, 0, 0.0225), (0.66, 0.12, 0.095), GOLD)           # its underside below every coat mark's
    for sx in (-1, 1):
        R = _rz(-sx * 24) @ _rx(78)
        two.star((sx * 0.25, 0.0, 0.215), 0.2, 0.09, 0.07, GOLD, rot=R)
    lean = _rx(78)
    c = Vector((0.0, 0.03, 0.5))
    three.box((0, 0.02, 0.17), (0.09, 0.05, 0.3), GOLD, rot=_rx(-12))
    three.star(tuple(c), 0.26, 0.115, 0.075, "gold_light", rot=lean)
    glow.box(tuple(c + lean @ Vector((0, 0, 0.0))), (0.1, 0.1, 0.1), NEON_GOLD, rot=lean @ _rz(45))
    return {"Star2": (two, at), "Star3": (three, at), "Star3_Glow": (glow, at)}


def build_pet(name, mat):
    spec = PETS[name]
    base = PREFIX + name
    objs = cats.build_cat(name, mat, spec=spec, base=base, body="walk")
    k = cats.scale_of(spec, "walk")
    for suffix, (b, at) in _stars(spec).items():
        ob = b.finalize(f"{base}_{suffix}", mat, location=tuple(v * k for v in at))
        if k != 1.0:
            cats.scale_mesh(ob, k)
        ob["rides"] = "Body"
        objs.append(ob)
    return objs


def pet_rbx_extras(name):
    def make():
        spec = PETS[name]
        d = cats.dims(spec, "walk")
        k = cats.scale_of(spec, "walk")
        neck = Vector(cats.joints(spec, "walk")["Head"])
        top = props.head_top(name, spec, "walk", d)
        burst = neck + Vector((0.0, d["head"]["c"][1], (top if top is not None else d["head"]["top"]) + 0.2)) * k
        attributes = {"Pet": True, "PetId": name, "Rarity": spec["rarity"], "PetScale": {"Float64": PET_SCALE},
                      "PropSlot": props.slot(name)}
        part_attributes = {"_Prop": {"Follows": "Head"}, "_Prop_Glass": {"Follows": "Head"}}
        nest = {"_Prop": "_Head", "_Prop_Glass": "_Head", "_Star3_Glow": "_Star3"}
        if props.slot2(name):
            attributes["PropSlot2"] = props.slot2(name)
            part_attributes["_Prop2"] = {"Follows": "Body"}
        for piece, host in props.PIECES.get(name, {}).items():      # lit and tail pieces: inside their host's Model
            nest["_" + piece] = "_" + host
            part_attributes["_" + piece] = {"Follows": props.piece_follows(name, piece)}
        for sfx in ("_Star2", "_Star3", "_Star3_Glow"):
            part_attributes[sfx] = {"Follows": "Body"}
        return {"attachments": [("_Body", "Burst", Matrix.Translation(burst))], "attributes": attributes,
                "nest": nest, "part_attributes": part_attributes,
                "model_attributes": {"_Star2": {"StarLevel": 2}, "_Star3": {"StarLevel": 3},
                                     "_Star3_Glow": {"StarLevel": 3}}}
    return make


ASSETS = {PREFIX + n: (lambda mat, n=n: build_pet(n, mat), BUDGET) for n in PETS}
EXTRAS = {PREFIX + n: pet_rbx_extras(n) for n in PETS}
