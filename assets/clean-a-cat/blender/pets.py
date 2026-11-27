"""The pets (issue #527; the game's #511 and #512, switch `pets`): the eight cats a crate holds, one model each.

    CleanACat_Pet_<Name>    Common Clover and Ghost, Uncommon Ooze and Glitch, Rare Angler and Nebula, Epic Dragon,
                            Legendary Blaze (#883: Catch a Cat Cafe's secret cats and dragons; Design-Agent's names,
                            which CrateRules.PETS lists; they replaced Cozy, Scrubby, Pebble, Pickle, Koi, Bamboo,
                            Coral and Nimbus slot for slot)
    CleanACat_Pet_Starcoat  the gift stand's pet (#502, the game's #521), never in a crate: the roster's star coat
                            with a big pink present bow on its head and a small present on its back

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
from props import GOLD, NEON_GOLD, NEON_MINT, NEON_SKY, STAR, Pen, _heart, _rx, _ry, _rz, _tail_axes

PREFIX = "CleanACat_Pet_"
PET_SCALE = 0.7
BUDGET = 2400
BACK_END = 0.28             # a back piece ends here at the latest (the back frame's y): the stars stand behind it
STAR_Y = 0.36               # where the stars' plate lies across the rump, against the tail's root

PETS = {
    # Derek on dev, 2026-11-26 (#883): "make all the pet models really cool like dragon cat, phoenix cat, clover cat
    # ... the old secret cats from asset repo". Each grew from one of Catch a Cat Cafe's secret cats or dragons (his
    # own earlier game, Roblox-Asset-Library), in Bubble Pastel, and climbs in wow with its rarity: a Common wears
    # one piece with one small lit spot, an Uncommon two pieces, a Rare two with lit parts, the Epic and the
    # Legendary wings, lit parts and a tail piece. Names: Design-Agent, 2026-11-27.
    # a lucky mint green cat with cream spots and gold socks, a four leaf clover and a gold horseshoe on its head
    "Clover":  dict(rarity="Common", fur="eye_green", second="spa_mint", eyes="eye_gold", pattern="spots",
                    muzzle="spa_cream", socks="fur_golden", tip="spa_mint", nose="nose_dark", eye_k=1.1),
    # a pale lilac ghost cat fading to lavender, a curled tail, short legs, a crown of three little ghost flames
    "Ghost":   dict(rarity="Common", fur="coat_lilac_light", second="pastel_lilac", eyes="eye_sky", pattern="gradient",
                    muzzle=None, nose="nose_bubblegum", tip="pastel_lilac", curl=True, short_legs=True, lids=True,
                    inner_ear="fur_lavender", eye_k=1.12),
    # lime slime fading to mint, slime pooled on its head and dripping down, a jar of glowing slime on its back
    "Ooze":    dict(rarity="Uncommon", fur="eye_chartreuse", second="spa_mint", eyes="pastel_sky", pattern="gradient",
                    muzzle=None, nose="nose_dark", tip="spa_mint", socks="eye_green", eye_k=1.12),
    # mint with pink and ink pixel tiles, odd eyes, coming apart into pixels, a broken checker sprite on its back
    "Glitch":  dict(rarity="Uncommon", fur="eye_mint", second="fur_bubblegum", third="coat_inky", eyes="spa_bubblegum",
                    eyes2="eye_sky", pattern="solid", tiles=True, muzzle=None, nose="nose_dark", tip="fur_bubblegum",
                    toes=("fur_bubblegum", "coat_inky", "coat_inky", "fur_bubblegum"), eye_k=1.1),
    # from the deep end of the pool: sky to deep blue with lit mint spots, a lit lure over its brow and a sail fin
    "Angler":  dict(rarity="Rare", fur="pastel_sky", second="bow_sky", third="galaxy_blue", eyes="eye_mint",
                    pattern="gradient", muzzle=None, nose="nose_dark", socks="galaxy_blue", tip="eye_mint",
                    sprinkles=("eye_mint", "sparkle", "spa_sky", "eye_mint", "pearl"), eye_k=1.12),
    # its own little solar system: lilac and violet clouds with pink, a ringed planet orbiting its head, stars behind
    "Nebula":  dict(rarity="Rare", fur="velvet_lilac", second="aurora_violet", third="fur_bubblegum", eyes="eye_mint",
                    pattern="patches", sparkle=True, speck_out=(0.035, 0.035), muzzle=None, nose="nose_dark", tip="fur_bubblegum", eye_k=1.1),
    # a blossom dragon: bubblegum fading to pearl, pearl horns with blossoms, pink dragon wings, lit petal spines
    "Dragon":  dict(rarity="Epic", fur="fur_bubblegum", second="pearl", third="apron_pink", eyes="eye_violet",
                    pattern="gradient", sparkle=True, muzzle=None, nose="nose_bubblegum", socks="pearl", tip="pearl",
                    tail_thick=0.3, scale=1.08, eye_k=1.1),
    # the phoenix cat, the showpiece: butter fading to apricot and pink, long fur, a fan of flame feathers on its
    # head, wide wings of fire and a burning plume on its tail. Sunrise colours, so it never reads as the special
    # customer's red Phoenix
    "Blaze":   dict(rarity="Legendary", fur="pastel_butter", second="fur_apricot", third="fur_strawberry",
                    eyes="eye_gold", pattern="gradient", sparkle=True, speck_out=(0.045, 0.03), muzzle=None, nose="nose_bubblegum", fluffy=True,
                    tail_thick=0.3, socks="fur_apricot", tip="fur_strawberry", scale=1.12, eye_k=1.1),
}

# The gift stand's pet (gift.py, #502): no crate holds it. Gameplay-Engineer named it after the roster's Starcoat, so
# it wears that coat; the present bow and the present on its back say it is the gift and not a customer's cat.
# `pet_rarity` is what the model's `Rarity` attribute says: the game has the gift pet as Uncommon
# (`CrateRules.GIFT_PETS`), so a free pet does not outshine a crate's Legendary. The coat's own `rarity` stays the
# roster's, because the cat generator reads it for the star specks.
GIFT_PETS = {
    "Starcoat": dict(cats.ROSTER["Starcoat"], gift=True, pet_rarity="Uncommon"),
}
ALL = {**PETS, **GIFT_PETS}


def key(name):
    """The name a pet's pieces are listed under in props.py: never a cat's own name (Starcoat is a roster cat)."""
    return "Pet" + name


# ------------------------------------------------------------------------------------------- the pieces --
# Each grew from a piece of the matching Catch a Cat Cafe cat (Roblox-Asset-Library, models/blender-generators/
# props.py); nothing hangs in the air: every part sits on the cat or on another part (#874, Derek 2026-11-26).
def _arc(P, c, r, a0, a1, n, size, sw, plane="xz"):
    """n boxes round an arc of radius r about c, from a0 to a1 degrees, each turned along the arc and lapping the
    next so the arc reads as one bent bar."""
    c = Vector(c)
    for k in range(n):
        a = math.radians(a0 + (a1 - a0) * (k + 0.5) / n)
        off = Vector((r * math.cos(a), 0.0, r * math.sin(a))) if plane == "xz" else \
            Vector((r * math.cos(a), r * math.sin(a), 0.0))
        rot = _ry(-math.degrees(a)) if plane == "xz" else _rz(math.degrees(a))
        P.box(tuple(c + off), (size[0], size[1] + 0.006 * (k % 2), size[2]), sw, rot=rot)   # no shared faces


def _blossom(P, c, r, sw, heart="pastel_butter", rot=None):
    """A five petal blossom lying in its own XY plane (`rot` stands it up), a butter heart in the middle."""
    R = rot or Matrix.Identity(3)
    c = Vector(c)
    for k in range(5):
        a = math.radians(72 * k + 90)
        P.ico(tuple(c + R @ Vector((r * 0.55 * math.cos(a), r * 0.55 * math.sin(a), 0.0))), r * 0.48, sw,
              scale=(1.0, 1.0, 0.45), rot=R)
    P.ico(tuple(c + R @ Vector((0, 0, 0.02))), r * 0.3, heart)


def clover_crown(ctx):
    """Clover (Common): a four leaf clover lying low on its head between its ears, tipped toward the face like a hair
    clip, each leaf a heart of two lobes, a small lit gem at its heart (the object `_Glow`), and a gold horseshoe
    standing behind it, open end up. From Lucky Clover's clover_crown, without the coins that turned in the air.
    No stalk: a clover held up on a stem made a tall knob on a stick in the portrait's outline (image gate, 2026-11-27)."""
    P = ctx.pen("head")
    G = ctx.piece("Glow", "head", (0, 0.02, 0.4))
    c, tip = Vector((0, -0.04, 0.16)), _rx(45)                                          # low, its face tipped forward
    for k in range(4):
        a = math.radians(45 + 90 * k)
        at = c + tip @ Vector((0.1 * math.cos(a), 0.1 * math.sin(a), 0))
        for s in (-1, 1):
            b = math.radians(45 + 90 * k + s * 30)
            P.ico(tuple(at + tip @ Vector((0.075 * math.cos(b), 0.075 * math.sin(b), 0.008 * (2 * k + (s > 0))))),
                  0.11, ("leaf_green", "eye_green")[(k + (s > 0)) % 2], scale=(1, 1, 0.42), rot=tip)
    G.ico(tuple(c), 0.1, NEON_GOLD)                                                     # set in among the leaves
    _arc(P, (0, 0.2, 0.2), 0.2, 200, 340, 6, (0.12, 0.08, 0.08), GOLD)                  # the horseshoe, on the head


def ghost_flames(ctx):
    """Ghost (Common): a crown of three little ghost flames on a pale band round the head, lit sky blue at their
    hearts (the object `_Glow`). From Cafe Ghost and the library's wisps: a ghost's own will-o'-the-wisp."""
    P, w, d = ctx.pen("head"), ctx.hw, ctx.hd
    G = ctx.piece("Glow", "head", (0, 0, 0.2))
    P.box((0, 0, 0.03), (2 * w + 0.06, 2 * d + 0.06, 0.1), "pastel_lilac")             # the band
    for x, h, y in ((-0.3, 0.34, 0.02), (0.0, 0.46, -0.04), (0.3, 0.34, 0.02)):
        P.ico((x, y, 0.14), 0.13, "coat_lilac_light", scale=(1, 0.85, 1))               # each flame's bowl
        P.pyramid((x, y, 0.16), 0.2, h, "coat_lilac_light", rot=_rz(45))                # and its tip
        G.ico((x, y - 0.06, 0.16), 0.07, NEON_SKY)


def slime_cap(ctx):
    """Ooze (Uncommon): slime pooled on its head, running down its brow and sides in drips with a lit bead on each
    end, and a little crown of lit slime spikes standing in the pool (the object `_Glow`). From Ooze's
    slime_crown, without the bubbles that rose off it."""
    P, w, d = ctx.pen("head"), ctx.hw, ctx.hd
    G = ctx.piece("Glow", "head", (0, 0, 0.1))
    P.box((0, 0, 0.035), (2 * w + 0.08, 2 * d + 0.08, 0.09), "eye_green")
    for x, h in ((-0.34, 0.26), (-0.12, 0.14), (0.1, 0.22), (0.32, 0.12)):             # drips down the brow
        P.box((x, -(d + 0.03), -h / 2 + 0.05), (0.11, 0.06, h + 0.04), "eye_green")
        G.ico((x, -(d + 0.03), -h + 0.02), 0.06, "eye_chartreuse")
    for sx, drips in ((1, ((-0.12, 0.24), (0.16, 0.36))), (-1, ((-0.04, 0.3), (0.2, 0.16)))):   # and both sides
        for y, h in drips:
            P.box((sx * (w + 0.03), y, -h / 2 + 0.05), (0.06, 0.11, h + 0.04), "eye_green")
            G.ico((sx * (w + 0.03), y, -h + 0.02), 0.06, "eye_chartreuse")
    for k in range(5):                                                                  # the crown's spikes
        a = math.radians(72 * k + 18)
        G.pyramid((0.17 * math.cos(a), 0.17 * math.sin(a), 0.07), 0.12, 0.24, "eye_chartreuse")
    P.ring((0, 0, 0.1), 0.2, 0.06, 0.06, "spa_mint", segments=10)


def slime_jar(ctx):
    """Ooze's back piece: a round jar of lit slime strapped on its back (the object `_Jar_Glow` is the slime in it),
    a mint lid, and slime spilling down both flanks. From Ooze's toxic_barrel, made a spa jar."""
    P = ctx.pen("back")
    G = ctx.piece("Jar_Glow", "back", (0, 0.02, 0.2))
    hw = ctx.back_w / 2
    P.box((0, 0.02, 0.015), (2 * hw + 0.04, 0.12, 0.05), "spa_mint")                   # the strap
    P.cyl((0, 0.02, 0.2), 0.19, 0.34, "pearl", segments=12)                             # the jar
    G.cyl((0, 0.02, 0.17), 0.16, 0.26, "eye_chartreuse", segments=12)                   # the slime, proud of the glass
    P.cyl((0, 0.02, 0.4), 0.15, 0.08, "spa_mint", segments=12)                          # the lid
    P.ico((0, 0.02, 0.45), 0.06, "spa_mint")
    for sx, drips in ((1, ((-0.08, 0.2), (0.12, 0.3))), (-1, ((0.0, 0.26), (0.16, 0.14)))):
        for y, h in drips:
            G.box((sx * (hw + 0.025), y, -h / 2 + 0.04), (0.05, 0.1, h + 0.04), "eye_chartreuse")
            G.ico((sx * (hw + 0.025), y, -h + 0.02), 0.055, "eye_chartreuse")


def pixel_crown(ctx):
    """Glitch (Uncommon): it is coming apart into pixels. A broken row of cubes sits along the top of its head, each a
    little higher or lower than the next and the end ones slipping off past the ears (lit pink ones in the object
    `_Glow`), and two bright slices of its head have slid out sideways like a torn scanline. From Glitch's
    glitch_pixels. Low and wide on purpose: a stair of cubes climbing off one ear read as a raised finger in the
    portrait's outline (image gate, 2026-11-27)."""
    P, w, d = ctx.pen("head"), ctx.hw, ctx.hd
    G = ctx.piece("Glow", "head", (0, 0, 0.1))
    P.box((0.01, 0.0, 0.0), (2 * w + 0.2, 0.11, 0.05), "coat_inky")                    # the torn scanline they sit on
    for k, (x, z, sz, sw) in enumerate(((-w - 0.04, 0.02, 0.13, "fur_bubblegum"), (-0.24, 0.11, 0.2, "eye_mint"),
                                        (0.0, 0.06, 0.16, "coat_inky"), (0.22, 0.12, 0.2, "fur_bubblegum"),
                                        (w + 0.06, 0.04, 0.14, "eye_mint"))):
        (G if sw == "fur_bubblegum" else P).box((x, 0.02 * (-1) ** k, z), (sz, sz, sz), sw)
    for sx, z, edge, y in ((1, -0.2, "fur_bubblegum", -0.05), (-1, -0.44, "eye_sky", 0.05)):
        P.box((sx * (w + 0.05), y, z), (0.16, 2 * d - 0.08, 0.12), "eye_mint")          # a slice, slid out
        G.box((sx * (w + 0.15), y, z), (0.05, 2 * d - 0.08, 0.12), edge)                # its bright torn edge


def error_sprite(ctx):
    """Glitch's back piece: a broken sprite on a stalk over its back, the pink and ink checker of a missing texture
    (lit pink squares in `_Sprite_Glow`), two pixels dropping off it down a thread to the coat."""
    P = ctx.pen("back")
    G = ctx.piece("Sprite_Glow", "back", (0, 0, 0.3))
    P.box((0, 0.0, 0.1), (0.06, 0.06, 0.24), "coat_inky")                              # its stalk
    for i in range(3):
        for j in range(3):
            pink = (i + j) % 2 == 0
            (G if pink else P).box((0, -0.14 + 0.14 * i, 0.28 + 0.14 * j), (0.07 + 0.006 * pink, 0.14, 0.14),
                                   "fur_bubblegum" if pink else "coat_inky")
    P.bar((0, 0.18, 0.3), (0.0, 0.42, 0.02), 0.025, 0.025, "coat_inky")
    G.box((0, 0.26, 0.2), (0.09, 0.09, 0.09), "fur_bubblegum")
    P.box((0, 0.35, 0.1), (0.07, 0.07, 0.07), "eye_mint")


def angler_lure(ctx):
    """Angler (Rare): a lure on a long stalk arching over its brow with a lit bulb hanging in front of its face, lit
    beads up the stalk (the object `_Glow`), and a finned frill at each cheek. From Abyss's angler_lure."""
    P, w = ctx.pen("head"), ctx.hw
    G = ctx.piece("Glow", "head", (0, -0.5, 0.3))
    pts = [Vector((0, 0.1, -0.04)), Vector((0, 0.06, 0.34)), Vector((0, -0.2, 0.56)), Vector((0, -0.52, 0.5)),
           Vector((0, -0.66, 0.26))]
    for a, b in zip(pts, pts[1:]):
        P.bar(tuple(a), tuple(b), 0.06, 0.06, "galaxy_blue")
    tip = pts[-1] + Vector((0, 0, -0.1))
    P.bar(tuple(pts[-1]), tuple(tip), 0.04, 0.04, "galaxy_blue", up=(0, 1, 0))      # straight down: up must not be Z
    G.ico(tuple(tip + Vector((0, 0, -0.06))), 0.13, NEON_MINT)
    G.ico(tuple(tip + Vector((0, -0.06, -0.06))), 0.07, STAR)
    for p in pts[1:4]:
        G.ico(tuple(p), 0.045, NEON_MINT)
    for sx in (-1, 1):                                                     # the cheek frills: three fin rays each
        for dz, L in ((0.12, 0.3), (-0.08, 0.36), (-0.28, 0.28)):
            a = Vector((sx * (w - 0.04), 0.12, -0.3 + dz * 0.4))
            b = a + Vector((sx * L, 0.1, dz))
            P.bar(tuple(a), tuple(b), 0.13, 0.03, "bow_sky", up=(0, 1, 0))
            G.bar(tuple(a + (b - a) * 0.3), tuple(b + (b - a) * 0.06), 0.035, 0.04, NEON_MINT, up=(0, 1, 0))


def fin_sail(ctx):
    """Angler's back piece: a tall sail fin down its back on lit ribs (the object `_Sail_Glow`), with lit pearls
    of light along both flanks. From Abyss's fin_sail."""
    P = ctx.pen("back")
    G = ctx.piece("Sail_Glow", "back", (0, 0, 0.2))
    n, L = 9, min(ctx.back_len * 0.86, 2 * (BACK_END + 0.3))
    y0 = BACK_END - L
    for k in range(n):
        f = k / (n - 1)
        y = y0 + L * f
        h = 0.14 + 0.44 * math.sin(math.pi * (0.12 + 0.8 * f)) ** 1.5
        P.box((0, y, h / 2 - 0.02), (0.04, L / (n - 1) + 0.012, h), ("bow_sky", "galaxy_blue")[k % 2])
        if k % 2 == 0:
            G.box((0, y, h / 2 + 0.02), (0.056, 0.03, h + 0.06), NEON_MINT)
    for sx in (-1, 1):
        for k in range(3):
            G.ico((sx * (ctx.back_w / 2 - 0.02), y0 + L / 4 + L / 4 * k, -0.04), 0.05, NEON_MINT)


def orbit_ring(ctx):
    """Nebula (Rare): its own little solar system. A tilted lit ring round its head, lapping the head at one side
    (the object `_Glow`), a ringed pink planet and a pearl moon riding it, and a lit crescent moon standing between
    the ears. From Nebula's orbit_ring, the ring brought in to touch the head."""
    P, w, d = ctx.pen("head"), ctx.hw, ctx.hd
    G = ctx.piece("Glow", "head", (0, 0, 0.1))
    tilt = _ry(16) @ _rx(-8)
    R = max(w, d) + 0.02                               # its inside laps the head's sides
    c = Vector((0, 0.0, -0.12))
    G.ring(tuple(c), R, 0.07, 0.05, "eye_mint", rot=tilt, segments=16)   # mint: it reads on the lilac
    for ang, r, sw, belt in ((205, 0.11, "fur_bubblegum", "pastel_butter"), (25, 0.075, "pearl", None)):
        a = math.radians(ang)
        at = c + tilt @ Vector((R * math.cos(a), R * math.sin(a), 0))
        P.ico(tuple(at), r, sw)
        if belt:                                                           # the planet's own ring
            P.ring(tuple(at), r + 0.05, 0.03, 0.018, belt, rot=_ry(-25) @ _rx(20), segments=10)
    m = Vector((0.06, 0.04, 0.0))                                          # the crescent: its lower horn on the head
    for k in range(7):
        a = math.radians(-78 + 26 * k)
        t = 0.11 - 0.022 * abs(k - 3)
        G.box(tuple(m + Vector((-0.19 * math.cos(a) + 0.07, 0.005 * (k % 2), 0.19 + 0.19 * math.sin(a)))), (t, 0.07, 0.1), STAR,
              rot=_ry(math.degrees(-a)))


def star_trail(ctx):
    """Nebula's back piece: a constellation over its back, three lit stars joined by lit lines (the object
    `_Stars_Glow`), on a lilac thread down to the coat. From Nebula's star_trail."""
    P = ctx.pen("back")
    G = ctx.piece("Stars_Glow", "back", (0, 0, 0.3))
    pts = [Vector((-0.16, -0.22, 0.26)), Vector((0.1, 0.0, 0.42)), Vector((-0.04, 0.2, 0.3))]
    for a, b in zip(pts, pts[1:]):
        G.bar(tuple(a), tuple(b), 0.03, 0.03, "aurora_violet")
    for p in (pts[0], pts[2]):
        P.box((p.x, p.y, p.z / 2 - 0.02), (0.035, 0.035, p.z + 0.06), "pastel_lilac")      # threads into the coat
    for p, r in zip(pts, (0.13, 0.17, 0.12)):
        G.star(tuple(p), r, r * 0.45, 0.05, STAR, rot=_rx(90))


def petal_horns(ctx):
    """Dragon (Epic): two curved pearl dragon horns sweeping back, a pink blossom at each base and a lit pink gem
    between them (the object `_Glow`). From Petal Dragon's petal_horns."""
    P = ctx.pen("head")
    for sx in (-1, 1):
        at, a = Vector((sx * 0.15, -0.06, -0.03)), -25
        for r1, r2, hgt, turn in ((0.1, 0.07, 0.22, 0), (0.07, 0.0, 0.26, -32)):
            a += turn
            Rm = _ry(sx * 18) @ _rx(a)
            dv = Rm @ Vector((0, 0, 1))
            P.cyl(tuple(at + dv * hgt / 2), r1, hgt, "pearl", r2=r2, rot=Rm, segments=8)
            at = at + dv * (hgt - 0.03)
        _blossom(P, (sx * 0.24, -0.16, 0.02), 0.13, "apron_pink", rot=_rx(60))
    G = ctx.piece("Glow", "head", (0, -0.26, 0.04))
    G.ico((0, -0.26, 0.04), 0.06, "neon_pink", scale=(1.0, 0.6, 1.3))


def blossom_wings(ctx):
    """Dragon's back piece: two bat dragon wings from the shoulders, pink membranes on pearl bones with a pearl claw
    on each tip; a ridge of lit petal spines down the back (the object `_Spines_Glow`); a lit pink gem on the tail
    (`_Tail_Gem_Glow`, riding the Tail). From Eclipse's dragon_wings and Petal Dragon's petal_spines."""
    U = ctx.pen("up")
    lean = _rx(-30)
    edge = [(0.12, 0.42), (0.22, 0.3), (0.38, 0.4), (0.44, 0.2), (0.56, 0.22), (0.54, 0.05), (0.62, 0.0), (0.4, -0.04)]
    tips = [(0.12, 0.42), (0.38, 0.4), (0.56, 0.22), (0.62, 0.0)]
    for sx in (-1, 1):
        W = Pen(U.b, U.at, U.R @ lean, U.s * 1.4)
        root = Vector((sx * 0.08, 0.05, 0.05))
        W.fan(tuple(root), (0.0, 0.0), [(sx * x, z) for x, z in edge], 0.03 + 0.004 * (sx > 0), "fur_bubblegum",
              rot=_rx(90))
        for i, (x, z) in enumerate(tips):                 # each bone a little thicker than the last: no shared faces
            fy = -0.024 - 0.004 * i
            W.bar(tuple(root + Vector((0, fy, 0))), tuple(root + Vector((sx * x, fy, z))), 0.045, 0.04 + 0.005 * i,
                  "pearl", up=(0, 1, 0))
            W.ico(tuple(root + Vector((sx * x, fy, z))), 0.04, "pearl")
    U.box((0, 0.05, 0.05), (0.28, 0.12, 0.14), "apron_pink")
    P = ctx.pen("back")
    L = ctx.back_len
    P.box((0, 0.0, 0.012), (0.06, L * 0.7, 0.03), "pearl")
    G = ctx.piece("Spines_Glow", "back", (0, 0, 0.05))
    for k in range(5):
        y = -L * 0.3 + k * min(L * 0.6, BACK_END + L * 0.3) / 4
        h = 0.16 - 0.015 * abs(k - 2)
        G.ico((0, y, h / 2 - 0.01), 0.065, ("apron_pink", "fur_bubblegum")[k % 2], scale=(0.5, 1.0, h / 0.12))
    tip, dv, th, _a, _b = _tail_axes(ctx)
    T = ctx.piece("Tail_Gem_Glow", "tail", tuple(tip))
    T.ico(tuple(tip + dv * 0.04), th * 0.7, "neon_pink", scale=(1, 1, 1.3))


def flame_fan(ctx):
    """Blaze (Legendary): a fan of seven flame feathers standing on its head, apricot outside, gold inside and white
    hot at the heart (lit in the object `_Glow`), and a lit gold gem on its brow. From Phoenix's flame_crest,
    spread into a crown so it never reads as the special customer's swept back crest."""
    P = ctx.pen("head")
    G = ctx.piece("Glow", "head", (0, 0.05, 0.3))
    P.box((0, 0.04, 0.03), (0.5, 0.2, 0.1), "fur_apricot")                              # the root on the crown
    for k in range(7):
        ang = -60 + 20 * k
        h = 0.62 - 0.05 * abs(k - 3)
        Rm = _ry(ang)
        base = Vector((0, 0.04 + 0.004 * (k % 2), 0.02))
        P.pyramid(tuple(base), 0.17, h, "fur_apricot", rot=Rm)
        G.pyramid(tuple(base + Rm @ Vector((0, -0.04, 0.08))), 0.11, h * 0.7, "fur_golden", rot=Rm)
        G.pyramid(tuple(base + Rm @ Vector((0, -0.07, 0.12))), 0.05, h * 0.42, STAR, rot=Rm)
    G.box((0, -0.3, -0.02), (0.13, 0.06, 0.13), NEON_GOLD, rot=_ry(45))


def sun_wings(ctx):
    """Blaze's back piece: two wide wings of flame feathers fanned from the shoulders, apricot at the root, gold
    then white hot at the tips (lit in `_Wings_Glow`), and a plume of three flame feathers on the tail
    (`_Tail_Plume_Glow`, riding the Tail). From Phoenix's fire_wings, in sunrise colours."""
    U = ctx.pen("up")
    G = ctx.piece("Wings_Glow", "up", (0, 0.05, 0.05))
    lean = _rx(-24)
    U.box((0, 0.05, 0.05), (0.28, 0.12, 0.14), "fur_apricot")
    for sx in (-1, 1):
        for k in range(6):
            ang = math.radians(78 - 17 * k)
            L = 0.8 + 0.16 * math.sin(k / 5 * math.pi) + 0.07 * k
            root = Vector((sx * 0.08, 0.05 + 0.004 * k, 0.06))
            dv = lean @ Vector((sx * math.cos(ang), 0, math.sin(ang)))
            U.bar(tuple(root), tuple(root + dv * L * 0.62), 0.14, 0.036, "fur_apricot", up=(0, 1, 0))
            G.bar(tuple(root + dv * L * 0.5), tuple(root + dv * L * 0.92), 0.12, 0.042, "fur_golden", up=(0, 1, 0))
            G.bar(tuple(root + dv * L * 0.86), tuple(root + dv * L * 1.1), 0.08, 0.048, STAR, up=(0, 1, 0))
    tip, dv, th, a_, _b = _tail_axes(ctx)
    T = ctx.piece("Tail_Plume_Glow", "tail", tuple(tip))
    X = Vector((1.0, 0.0, 0.0))
    for k, sx in enumerate((-1, 0, 1)):
        u = (dv * math.cos(math.radians(28 * abs(sx))) + sx * X * math.sin(math.radians(28))).normalized()
        T.bar(tuple(tip - u * 0.04), tuple(tip + u * (0.42 + 0.08 * (sx == 0))), 0.13, 0.05 + 0.006 * k,
              ("fur_golden", STAR, "fur_golden")[k], up=tuple(a_))


def present_bow(ctx):
    """Starcoat the gift pet: a big pink present bow tied on the head, a paler heart in each loop and a small gold
    heart on the knot. Wider than any bow a customer's cat wears and in the middle of the head."""
    P = ctx.pen("head")
    y = -0.12
    for sx in (1, -1):
        tip = _ry(-18 * sx)
        P.sphere((sx * 0.31, y, 0.2), 0.3, "fur_strawberry", scale=(1.0, 0.5, 0.72), rot=tip, segments=8, rings=4)
        P.sphere((sx * 0.33, y - 0.06, 0.21), 0.15, "fur_rose", scale=(1.0, 0.5, 0.72), rot=tip, segments=8, rings=4)
    P.box((0, y, 0.11), (0.2, 0.2, 0.22), "fur_strawberry", bevel=True)
    _heart(P, (0.0, y - 0.105, 0.13), 0.065, GOLD, depth=0.03)


def present_pack(ctx):
    """Starcoat the gift pet's back piece: a small pink present with a gold ribbon and a gold knot, as on the stand."""
    P = ctx.pen("back")
    R = _rz(8)
    c = Vector((0.0, -0.02, 0.0))
    P.box(tuple(c + Vector((0, 0, 0.16))), (0.44, 0.4, 0.34), "spa_bubblegum", rot=R, bevel=True)
    P.box(tuple(c + Vector((0, 0, 0.168))), (0.12, 0.42, 0.352), GOLD, rot=R)
    P.box(tuple(c + Vector((0, 0, 0.174))), (0.46, 0.12, 0.36), GOLD, rot=R)
    for sx in (-1, 1):
        P.ico(tuple(c + R @ Vector((sx * 0.1, 0, 0.4))), 0.09, GOLD, scale=(1.2, 0.7, 0.8))
    P.ico(tuple(c + Vector((0, 0, 0.39))), 0.06, "gold_light")


HEAD = {"Starcoat": present_bow, "Clover": clover_crown, "Ghost": ghost_flames, "Ooze": slime_cap, "Glitch": pixel_crown,
        "Angler": angler_lure, "Nebula": orbit_ring, "Dragon": petal_horns, "Blaze": flame_fan}
BACK = {"Starcoat": present_pack, "Ooze": slime_jar, "Glitch": error_sprite, "Angler": fin_sail, "Nebula": star_trail,
        "Dragon": blossom_wings, "Blaze": sun_wings}
EXTRA = {"Clover": {"Glow": "Prop"}, "Ghost": {"Glow": "Prop"},
         "Ooze": {"Glow": "Prop", "Jar_Glow": "Prop2"}, "Glitch": {"Glow": "Prop", "Sprite_Glow": "Prop2"},
         "Angler": {"Glow": "Prop", "Sail_Glow": "Prop2"}, "Nebula": {"Glow": "Prop", "Stars_Glow": "Prop2"},
         "Dragon": {"Glow": "Prop", "Spines_Glow": "Prop2", "Tail_Gem_Glow": "Tail"},
         "Blaze": {"Glow": "Prop", "Wings_Glow": "Prop2", "Tail_Plume_Glow": "Tail"}}
for _n in ALL:                                          # the pets' pieces are props.py pieces under key(name)
    assert key(_n) not in props.PROPS and key(_n) not in cats.ROSTER and key(_n) not in cats.SPECIAL_CATS, _n
    props.PROPS[key(_n)] = ("Head", HEAD[_n])
    if _n in BACK:
        props.PROPS2[key(_n)] = ("Back", BACK[_n])
    if _n in EXTRA:
        props.PIECES[key(_n)] = EXTRA[_n]


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
    spec = ALL[name]
    base = PREFIX + name
    objs = cats.build_cat(key(name), mat, spec=spec, base=base, body="walk")
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
        spec = ALL[name]
        d = cats.dims(spec, "walk")
        k = cats.scale_of(spec, "walk")
        neck = Vector(cats.joints(spec, "walk")["Head"])
        top = props.head_top(key(name), spec, "walk", d)
        burst = neck + Vector((0.0, d["head"]["c"][1], (top if top is not None else d["head"]["top"]) + 0.2)) * k
        attributes = {"Pet": True, "PetId": name, "Rarity": spec.get("pet_rarity", spec["rarity"]), "PetScale": {"Float64": PET_SCALE},
                      "PropSlot": props.slot(key(name))}
        if spec.get("gift"):                             # the gift stand's pet: no crate holds it
            attributes["Gift"] = True
        part_attributes = {"_Prop": {"Follows": "Head"}, "_Prop_Glass": {"Follows": "Head"}}
        nest = {"_Prop": "_Head", "_Prop_Glass": "_Head", "_Star3_Glow": "_Star3"}
        if props.slot2(key(name)):
            attributes["PropSlot2"] = props.slot2(key(name))
            part_attributes["_Prop2"] = {"Follows": "Body"}
        for piece, host in props.PIECES.get(key(name), {}).items():   # lit and tail pieces: inside their host's Model
            nest["_" + piece] = "_" + host
            part_attributes["_" + piece] = {"Follows": props.piece_follows(key(name), piece)}
        for sfx in ("_Star2", "_Star3", "_Star3_Glow"):
            part_attributes[sfx] = {"Follows": "Body"}
        return {"attachments": [("_Body", "Burst", Matrix.Translation(burst))], "attributes": attributes,
                "nest": nest, "part_attributes": part_attributes,
                "model_attributes": {"_Star2": {"StarLevel": 2}, "_Star3": {"StarLevel": 3},
                                     "_Star3_Glow": {"StarLevel": 3}}}
    return make


ASSETS = {PREFIX + n: (lambda mat, n=n: build_pet(n, mat), BUDGET) for n in ALL}
EXTRAS = {PREFIX + n: pet_rbx_extras(n) for n in ALL}
