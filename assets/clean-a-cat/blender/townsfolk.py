"""The customers (issue #446): cosy townsfolk, each with a face, hair and an outfit of its own, built to walk.

The owner on 2026-11-25: "rework customers to be much better can check asset library if needed", and what bothers him
most is how they look and how they walk in. Until now a customer was a bare Roblox R15 figure in body colours with one
accessory (customers.py), set down on its mat with no walk. These replace it. They are built on the customer builder of
the owner's own asset library (his earlier cafe game's townsfolk: `models/blender-generators/customers.py` there),
with new looks in our colours, cut at the joints so they can walk, and with a hand that holds the carrier.

  CleanACat_NPC_Customer_<Name>     Model, pivot on the floor between the feet, front -Y here (-Z in Roblox).
                                    4.9 to 5.4 studs to the top of the hair. Nothing collides.
      ..._Body                      the main object: torso, hips, skirt, neck, scarf, hood or backpack. Its biggest
                                    part is the PrimaryPart.
      ..._Head                      child Model, pivot at the top of the neck: face, hair, hat, glasses
      ..._ArmL, ..._ArmR            child Models, pivot at the shoulder. Both arms hang straight down (the left one
                                    with the look's tote bag when it has one). Derek on dev, 2026-11-26 (#874): the
                                    right arm built held out read as a splayed arm off the body. Code turns it out by
                                    `CarryArmDegrees` only while a carrier hangs from it.
      ..._LegL, ..._LegR            child Models, pivot at the hip: the leg and its shoe
                                    Each joint turns about its pivot's X axis (the side to side axis) for a step, a
                                    swing or a nod. Left and right are the customer's own.
  Attachments: `Grip` in the right hand (on the right arm's biggest part, so it follows the arm): put the carrier's
  own `Grip` there, the carrier facing the way the customer faces. `Overhead` over the head, clear of any hat, for a
  bubble or a timer.
  Attributes: `Look` (the name), `WalkSpeed` (studs a second for the walk in), `LegLength` (hip to floor: a step of
  A degrees each way covers 2 * LegLength * sin(A)), `CarryArmDegrees` (how far to turn the right arm out about the
  pivot's Z while it holds a carrier, so the carrier clears the leg and the floor; in Roblox that is
  rest * CFrame.Angles(0, 0, math.rad(CarryArmDegrees)), before the walk's swing), `ArmsStraight` = true (the right
  arm is built straight, #874; models built before it had the arm already turned out), `Height`.

The carrier (spa_props) was resized with them: its Grip is 1.95 up, so with the hand 2.0 or more above the floor it
swings just over the ground beside the leg.

LOOKS has the eight customers. A look is a dict of palette swatches and switches; `body` picks the build.

SPECIAL_LOOKS has the special customers (issue #476), who bring the special cats (cats.SPECIAL_CATS). The owner on
2026-11-25: special customers "that expire that only I can take their cats". A draft: same build, joints, Attachments
and attributes as the townsfolk, so the walk in and the carry work unchanged, plus a root attribute `Special` = true.
They are told from the townsfolk across a yard by one shared cue: lilac and gold (the game's prize colours), gold
shoes, a gold star, and a hat no townsperson wears (a beret, a crown, a wide feathered hat). No look in LOOKS wears
lilac or gold (#479), and none wears a mint top, dress or trousers: a mint outfit is the staff's (#484). They carry
`CleanACat_Prop_CarrierRoyal` (spa_props). Vivi is the rare visitor of #142 (busy_spa.VISITORS) on the new build.
"""

import math

from mathutils import Matrix, Vector

import rbx_export
import spa_props
from common import Builder
from stations import _tris

PREFIX = "CleanACat_NPC_Customer_"
FACE_INK = "fur_black"

CHEEK_X, CHEEK_Z, CHEEK_R = 0.5, 0.27, 0.1    # a cheek's middle out from the nose line and under the eye line, and its radius
ADULT = dict(leg=1.45, pelvis=0.35, torso=1.5, tw=1.4, td=0.8, arm=1.3, hw=1.5, hd=1.35, hh=1.45, speed=6.5)
TALL = dict(leg=1.68, pelvis=0.35, torso=1.6, tw=1.42, td=0.8, arm=1.42, hw=1.46, hd=1.32, hh=1.4, speed=7.0)
SMALL = dict(leg=1.35, pelvis=0.33, torso=1.45, tw=1.36, td=0.8, arm=1.2, hw=1.52, hd=1.36, hh=1.46, speed=6.0)

LOOKS = {
    # a golden-haired gardener in a rose sundress and a straw sun hat (mint until #484: a mint outfit is the staff's)
    "Sunny": dict(body=ADULT, skin="skin_light", hair="fur_golden", style="long", sunhat="pastel_butter",
                  band="spa_bubblegum", top="fur_rose", skirt="fur_rose", legs="skin_light", shoes="offwhite",
                  patch="heart", patch_sw="offwhite"),
    # tall, in a striped butter jumper and a mint scarf
    "Mo": dict(body=TALL, skin="skin_deep", hair="fur_black", style="short", top="pastel_butter", stripes="offwhite",
               scarf="spa_mint", pants="pants_navy", shoes="offwhite", brows=True),
    # a student with a bob, a sky hoodie and a pink tote bag
    "Pip": dict(body=SMALL, skin="skin_tan", hair="choco", style="bob", top="spa_sky", hood=True, pocket="pastel_sky",
                pants="fur_puddle", shoes="offwhite", tote="spa_bubblegum"),
    # a ginger ponytail, denim dungarees over a pink tee
    "Rae": dict(body=ADULT, skin="skin_light", hair="fur_ginger", style="ponytail", tie="spa_mint",
                top="spa_bubblegum", overalls="fur_puddle", shoes="shirt_red", brows=True),
    # hair in two puffs, a peach hoodie and mint headphones (lilac until #479: lilac is the special customers')
    "Juno": dict(body=ADULT, skin="skin_deep", hair="choco", style="puffs", top="fur_peach", hood=True,
                 pocket="fur_apricot", pants="fur_ink", shoes="offwhite", phones="spa_mint"),
    # a granny with a silver bun, round glasses and a sage cardigan (lilac until #479)
    "Bea": dict(body=SMALL, skin="skin_light", hair="fur_silver", style="bun", glasses="brass", top="offwhite",
                cardigan="fur_fern", skirt="fur_puddle", legs="fur_ink", shoes="hair_brown", brows=True),
    # tall, russet curls and a beard, a sky jumper with a paw on it
    "Theo": dict(body=TALL, skin="skin_light", hair="fur_russet", style="curls", beard=True, top="pastel_sky",
                 patch="paw", patch_sw="offwhite", pants="fur_bramble", shoes="choco", brows=True),
    # a cat-ear beanie, a butter tee and a pink backpack
    "Kit": dict(body=ADULT, skin="skin_tan", hair="hair_brown", style="beanie", beanie="spa_mint", ears=True,
                top="pastel_butter", patch="paw", patch_sw="spa_bubblegum", pants="pants_navy", shoes="offwhite",
                backpack="spa_bubblegum", brows=True),
}

SPECIAL_LOOKS = {
    # the star visitor: a lilac beret with a gold star, gold rimmed violet shades, a lilac coat with gold buttons
    "Vivi": dict(body=ADULT, skin="skin_tan", hair="fur_black", style="bob", beret="velvet_lilac",
                 shades=("gold_mid", "aurora_violet"), top="velvet_lilac", buttons="gold_mid", pearls="pearl",
                 pants="pearl", shoes="gold_mid"),
    # a jolly king: a gold crown, a berry cape with a pearl collar, a silver beard, a gold star on a lilac tunic
    "Rex": dict(body=TALL, skin="skin_light", hair="fur_silver", style="short", beard=True, crown="gold_mid",
                cape=("royal_berry", "pearl"), top="velvet_lilac", patch="star", patch_sw="gold_mid",
                buttons="gold_mid", pants="pearl", shoes="gold_mid", brows=True),
    # a grand lady: a wide lilac hat with a gold band and a pink feather, pearls, gloves, a lilac dress
    "Pearl": dict(body=ADULT, skin="skin_deep", hair="choco", style="bob", sunhat="velvet_lilac", band="gold_mid",
                  feather="spa_bubblegum", top="pastel_lilac", skirt="velvet_lilac", pearls="pearl", gloves="pearl",
                  patch="star", patch_sw="gold_mid", legs="pearl", shoes="gold_mid"),
}
ALL_LOOKS = {**LOOKS, **SPECIAL_LOOKS}
_X90 = Matrix.Rotation(math.radians(90), 3, "X")       # stands a flat star up to face the front

for _n in ALL_LOOKS:                                    # a walker arrives whole, its arms and legs with it
    rbx_export.MODEL_PROPS["_Customer_" + _n] = {"ModelStreamingMode": "Atomic"}


def _ry(deg):
    return Matrix.Rotation(math.radians(deg), 3, "Y")


def _rz(deg):
    return Matrix.Rotation(math.radians(deg), 3, "Z")


class Piece:
    """One jointed piece. Shapes are given in the customer's own space, as if the piece hung straight; they are stored
    from the joint (the object's origin), turned about it by `tilt`."""

    def __init__(self, joint=(0.0, 0.0, 0.0), tilt=None):
        self.b = Builder()
        self.joint = Vector(joint)
        self.tilt = tilt

    def at(self, p):
        """Where a point of the straight piece is in the customer's space once the piece is tilted."""
        v = Vector(p) - self.joint
        return self.joint + (self.tilt @ v if self.tilt else v)

    def _c(self, c):
        v = Vector(c) - self.joint
        return tuple(self.tilt @ v) if self.tilt else tuple(v)

    def _r(self, rot):
        if isinstance(rot, tuple):
            rot = Matrix.Rotation(rot[0], 3, rot[1])
        if self.tilt is None:
            return rot
        return self.tilt @ rot if rot is not None else self.tilt

    def box(self, c, s, sw, bevel=True, rot=None):
        self.b.box(self._c(c), s, sw, bevel, self._r(rot))

    def box_base(self, c, s, sw, bevel=True, rot=None):
        self.box((c[0], c[1], c[2] + s[2] / 2), s, sw, bevel, rot)

    def wedge(self, c, s, sw, bevel=True, rot=None):
        self.b.wedge(self._c(c), s, sw, bevel, self._r(rot))

    def sphere(self, c, r, sw, segments=10, rings=6, scale=(1, 1, 1), rot=None):
        self.b.sphere(self._c(c), r, sw, segments, rings, scale, self._r(rot))

    def pyramid(self, c, size, h, sw, rot=None):
        self.b.pyramid(self._c(c), size, h, sw, rot=self._r(rot))

    def cyl(self, c, r, h, sw, segments=12, bevel=True, rot=None, radius2=None):
        self.b.cyl(self._c(c), r, h, sw, segments=segments, bevel=bevel, rot=self._r(rot), radius2=radius2)

    def star(self, c, outer, inner, h, sw, rot=None):
        self.b.star(self._c(c), outer, inner, h, sw, rot=self._r(rot))

    def finalize(self, name, mat):
        return _tris(self.b.finalize(name, mat, location=tuple(self.joint)))


class Frame:
    """A body's key heights and joints."""

    def __init__(self, body):
        self.d = body
        self.hip = body["leg"] + 0.1                    # the pelvis's bottom
        self.waist = self.hip + body["pelvis"]
        self.top = self.waist - 0.05 + body["torso"]    # the shoulders
        self.head0 = self.top + 0.1
        self.head1 = self.head0 + body["hh"]
        self.face = -body["hd"] / 2                     # the face's plane (-Y is the front)
        self.arm_x = body["tw"] / 2 + 0.2
        self.shoulder = self.top - 0.12                 # the arm's joint
        self.arm1 = self.top + 0.05                     # the sleeve's top
        self.arm0 = self.arm1 - body["arm"]             # the wrist
        self.hand = self.arm0 - 0.15                    # the hand's middle
        self.leg_joint = self.hip + 0.1


def carry_degrees(look):
    """How far the right arm is held out so the carrier clears the body and the floor."""
    f = Frame(look["body"])
    reach = f.shoulder - f.hand
    half = look["body"]["tw"] / 2 - 0.05                            # the hips
    if look.get("skirt"):
        half = (look["body"]["tw"] + 0.05) / 2 + SKIRT_FLARE
    out = half + spa_props.CAR_W / 2 + 0.04 - f.arm_x                 # how far out the hand must be
    a_body = math.degrees(math.asin(min(1.0, max(0.0, out / reach))))
    lift = spa_props.GRIP_H + 0.06                                    # the hand at least this high
    a_floor = math.degrees(math.acos(min(1.0, (f.shoulder - lift) / reach)))
    return round(max(a_body, a_floor, 18.0), 1)


SKIRT_FLARE = 0.14


def _legs(legs, f, look):
    d = f.d
    sw, shoes = look.get("legs") or look.get("pants") or look.get("overalls"), look["shoes"]
    toe = "offwhite" if shoes != "offwhite" else "fur_silver"
    for sx, p in zip((1, -1), legs):
        x = sx * 0.32
        p.box_base((x, 0.0, 0.25), (0.56, 0.6, f.leg_joint - 0.25), sw)
        if look.get("shorts"):
            p.box_base((x, 0.0, 0.3 + d["leg"] * 0.55), (0.6, 0.64, d["leg"] * 0.45 - 0.15), look["shorts"])
        p.box_base((x, -0.12, 0.0), (0.62, 0.9, 0.3), shoes)
        p.box((x, -0.58, 0.18), (0.5, 0.04, 0.12), toe, bevel=False)                  # a toe cap


def _lower(b, f, look):
    """Hips, and the skirt when there is one."""
    d = f.d
    if look.get("skirt"):
        lo, hi = f.hip - 0.4, f.waist + 0.05
        b.box_base((0, 0, lo), (d["tw"] + 0.05, d["td"] + 0.1, hi - lo), look["skirt"])
        for sx in (1, -1):                                                           # the flare
            b.wedge((sx * ((d["tw"] + 0.05) / 2 + SKIRT_FLARE / 2), 0, lo + (hi - lo) / 2),
                    (d["td"] + 0.06, SKIRT_FLARE, hi - lo - 0.02), look["skirt"], bevel=False, rot=_rz(90 * sx))
    else:
        b.box_base((0, 0, f.hip), (d["tw"] - 0.1, d["td"] - 0.04, d["pelvis"] + 0.05),
                   look.get("shorts") or look.get("pants") or look.get("overalls"))


def _patch(b, kind, sw, y, z, x=0.0):
    """A small picture on the chest: a paw print, a heart or a star, x to the wearer's left of the middle."""
    if x:
        b = _Shift(b, x)
    if kind == "star":                                   # one five pointed star (the special customers)
        b.star((0, y - 0.005, z + 0.02), 0.24, 0.105, 0.04, sw, rot=_X90)
    elif kind == "paw":
        b.box((0, y, z - 0.07), (0.26, 0.03, 0.18), sw, bevel=False)
        for dx, dz in ((-0.19, 0.06), (-0.065, 0.15), (0.065, 0.15), (0.19, 0.06)):
            b.box((dx, y, z + dz), (0.1, 0.03, 0.1), sw, bevel=False)
    else:                                                # a heart in four rows of blocks
        for sx in (1, -1):
            b.box((sx * 0.09, y, z + 0.11), (0.13, 0.03, 0.07), sw, bevel=False)
        for k, wd in enumerate((0.34, 0.22, 0.1)):
            b.box((0, y, z + 0.04 - 0.07 * k), (wd, 0.03, 0.07), sw, bevel=False)


class _Shift:
    """A builder that draws everything x to the side."""

    def __init__(self, b, x):
        self.b, self.x = b, x

    def box(self, c, *a, **k):
        self.b.box((c[0] + self.x, c[1], c[2]), *a, **k)

    def star(self, c, *a, **k):
        self.b.star((c[0] + self.x, c[1], c[2]), *a, **k)


def _torso(b, f, look):
    d = f.d
    w, dep, z0, z1 = d["tw"], d["td"], f.waist - 0.05, f.top
    fy = -dep / 2                                                                  # the chest's front
    main = look.get("cardigan") or look["top"]
    b.box_base((0, 0, z0), (w, dep, z1 - z0), main)
    if look.get("cardigan"):
        b.box((0, fy - 0.015, (z0 + z1) / 2 + 0.05), (0.42, 0.04, z1 - z0 - 0.15), look["top"], bevel=False)
        for z in (z0 + 0.35, z0 + 0.7, z0 + 1.05):
            b.box((0.27, fy - 0.01, z), (0.08, 0.04, 0.08), "offwhite", bevel=False)      # buttons
    if look.get("stripes"):
        for k in range(3):
            b.box((0, 0, z0 + 0.35 + 0.38 * k), (w + 0.03, dep + 0.03, 0.12), look["stripes"], bevel=False)
    if look.get("patch"):
        _patch(b, look["patch"], look["patch_sw"], fy - 0.012, z0 + (z1 - z0) * 0.56,
               0.36 if look.get("buttons") else 0.0)     # a medal on the chest's left when buttons run down the middle
    if look.get("buttons"):                              # a row of buttons down the front
        for k in range(3):
            b.box((0, fy - 0.01, z0 + 0.3 + 0.36 * k), (0.12, 0.05, 0.12), look["buttons"], bevel=False)
    if look.get("pearls"):                               # a string of pearls: a low arc on the chest
        for dx, dz in ((-0.34, 0.0), (-0.2, -0.1), (0.0, -0.15), (0.2, -0.1), (0.34, 0.0)):
            b.box((dx, fy - 0.01, z1 - 0.22 + dz), (0.11, 0.05, 0.11), look["pearls"], bevel=False)
    if look.get("cape"):
        cape, trim = look["cape"]
        # hangs flat on the back between the arms (its front 0.04 into the torso, so it never stands off the back);
        # below the hands it widens and flares back a little, so it shows beside the legs from the front; it ends at
        # mid thigh, where a leg swinging 26 degrees behind still passes under its hem
        top_z, hem_z, flare = z1 - 0.02, f.hip - 0.45, math.radians(14)
        split = f.arm0 - 0.4                              # just under the hanging hands
        yc = dep / 2 + 0.02                               # the upper length's middle: 0.12 deep, front 0.04 in
        b.box((0, yc, (split + top_z) / 2), (w - 0.06, 0.12, top_z - split), cape)
        # the lower length laps 0.08 over the upper, is thicker and tilted, so they join with no two faces in one plane
        hi = split + 0.08
        zc = (hem_z + hi) / 2
        b.box((0, yc + 0.01 + math.tan(flare) * (hi - zc), zc), (w + 0.34, 0.15, (hi - hem_z) / math.cos(flare)), cape,
              rot=Matrix.Rotation(flare, 3, "X"))
        b.box_base((0, 0.03, z1 - 0.13), (w + 0.1, dep + 0.16, 0.26), trim)                    # the collar
        for i, dx in enumerate((-0.48, -0.16, 0.16, 0.48)):                                   # its ermine specks
            b.box((dx, fy - 0.065, z1 - 0.01 + 0.03 * (i % 2)), (0.07, 0.03, 0.09), "fur_ink", bevel=False)
        b.box((0, fy - 0.07, z1 - 0.06), (0.16, 0.05, 0.16), "gold_mid", bevel=False, rot=_ry(45))   # the clasp
    if look.get("hood"):
        # the hood, down: a roll round the neck on the shoulders and the hood lying on the back under it, its front
        # 0.06 into the torso (a bevel's width), so from the side it is part of the top and never a block behind it
        b.box_base((0, 0.08, z1 - 0.12), (1.0, dep + 0.1, 0.22), look["top"])
        b.box((0, dep / 2 + 0.05, z1 - 0.32), (0.9, 0.22, 0.56), look["top"])
        b.box((0, fy - 0.015, z0 + 0.35), (0.8, 0.03, 0.4), look["pocket"], bevel=False)     # the pocket
        for x in (-0.15, 0.15):
            b.box((x, fy - 0.01, z1 - 0.32), (0.05, 0.04, 0.4), "offwhite", bevel=False)     # the strings
    if look.get("overalls"):
        ov = look["overalls"]
        b.box((0, fy - 0.015, z0 + 0.45), (0.8, 0.04, 0.8), ov, bevel=False)                 # the bib
        _patch(b, "paw", "offwhite", fy - 0.045, z0 + 0.52)
        for sx in (1, -1):
            b.box((sx * 0.3, fy - 0.015, z1 - 0.25), (0.14, 0.04, 0.55), ov, bevel=False)    # the straps
            b.box((sx * 0.3, dep / 2 + 0.015, z1 - 0.3), (0.14, 0.04, 0.6), ov, bevel=False)
            b.box((sx * 0.3, fy - 0.04, z0 + 0.82), (0.08, 0.02, 0.08), "brass", bevel=False)
    if look.get("scarf"):
        b.box_base((0, 0, z1 - 0.1), (0.95, dep - 0.05, 0.28), look["scarf"])
        b.box((0.3, fy - 0.04, z1 - 0.45), (0.28, 0.06, 0.6), look["scarf"], bevel=False, rot=_ry(-8))
    if look.get("backpack"):
        # its front 0.06 into the back (a bevel's width), so it sits on the back with no gap
        b.box((0, dep / 2 + 0.16, (z0 + z1) / 2 + 0.05), (w - 0.2, 0.44, z1 - z0 - 0.15), look["backpack"])
        b.box((0, dep / 2 + 0.39, (z0 + z1) / 2 - 0.05), (w - 0.5, 0.06, 0.4), "offwhite", bevel=False)
        for sx in (1, -1):
            b.box((sx * 0.33, fy - 0.015, (z0 + z1) / 2 + 0.1), (0.14, 0.04, z1 - z0 - 0.3), look["backpack"],
                  bevel=False)
    if look.get("toolbelt"):                             # the builder (#891): a belt, two pouches, a wrench
        belt, pouch = look["toolbelt"]
        b.box_base((0, 0, z0 - 0.12), (w + 0.08, dep + 0.08, 0.2), belt)
        for sx in (1, -1):                               # the pouches' backs 0.06 into the hips, so none floats
            b.box((sx * 0.42, fy, z0 - 0.22), (0.36, 0.16, 0.3), pouch)
        b.box((0.42, fy - 0.06, z0 + 0.0), (0.09, 0.08, 0.42), "fur_smoke_light")              # a wrench in one
        b.box((0.42, fy - 0.06, z0 + 0.24), (0.22, 0.09, 0.12), "fur_smoke_light")
    if look.get("apron"):
        _apron(b, f, look)
    b.box_base((0, 0, f.top - 0.05), (0.5, 0.5, 0.2), look["skin"], bevel=False)             # the neck


def _apron(b, f, look):
    """The staff uniform over the smock: a bib apron with a big paw, a waistband tied in a bow at the back, straps
    that cross on the back, a collar, a towel and a pocket with a sponge and a brush. `apron` is (cloth, trim)."""
    d = f.d
    cloth, trim = look["apron"]
    w, dep, z0, z1 = d["tw"], d["td"], f.waist - 0.05, f.top
    fy, by = -dep / 2, dep / 2
    bib0, bib1 = z0 + 0.2, z1 - 0.3
    b.box((0, fy - 0.02, (bib0 + bib1) / 2), (0.98, 0.06, bib1 - bib0), cloth, bevel=False)          # the bib
    pz = (bib0 + bib1) / 2 - 0.02                                                                  # its paw
    b.box((0, fy - 0.045, pz - 0.12), (0.4, 0.03, 0.27), trim, bevel=False)
    for dx, dz in ((-0.29, 0.08), (-0.1, 0.22), (0.1, 0.22), (0.29, 0.08)):
        b.box((dx, fy - 0.045, pz + dz), (0.15, 0.03, 0.15), trim, bevel=False)
    b.box_base((0, 0, z0 + 0.02), (w + 0.08, dep + 0.08, 0.2), trim)                               # the waistband
    hem = f.hip - 0.5                                                                              # the skirt
    b.box((0, fy - 0.045, (hem + z0 + 0.06) / 2), (w - 0.04, 0.15, z0 + 0.06 - hem), cloth)
    b.box((0, fy - 0.05, hem + 0.05), (w - 0.01, 0.17, 0.14), trim, bevel=False)                   # its hem
    for sx in (1, -1):                                                                             # the straps
        b.box((sx * 0.37, fy - 0.015, (bib1 + z1) / 2 + 0.01), (0.16, 0.05, z1 - bib1 + 0.04), cloth, bevel=False)
        b.box((sx * 0.37, 0, z1 + 0.012), (0.16, dep + 0.07, 0.05), cloth, bevel=False)
    lo, hi = z0 + 0.22, z1 - 0.05                                                                  # they cross behind
    lean = math.degrees(math.atan2(0.74, hi - lo))
    ln = math.hypot(0.74, hi - lo)
    for sx, th, sunk in ((1, 0.05, 0.02), (-1, 0.09, 0.03)):   # one thicker and deeper, so no two faces share a plane
        b.box((0, by + th / 2 - sunk, (lo + hi) / 2), (0.15, th, ln), cloth, bevel=False, rot=_ry(lean * sx))
    b.box((0, by + 0.09, z0 + 0.12), (0.2, 0.14, 0.2), trim, bevel=False)                          # the bow's knot
    for sx in (1, -1):
        b.box((sx * 0.3, by + 0.08, z0 + 0.15), (0.46, 0.1, 0.3), trim, rot=_ry(-14 * sx))         # its loops
        b.box((sx * 0.13, by - 0.005, z0 - 0.2), (0.14, 0.07, 0.48), trim, bevel=False, rot=_ry(10 * sx))  # its tails
    b.box_base((0, 0, z1 - 0.08), (1.0, dep - 0.06, 0.2), cloth, bevel=False)                      # the collar
    if look.get("towel"):                                 # tucked in the waistband on the wearer's right
        tw_ = look["towel"]
        b.box((-0.42, fy - 0.135, z0 - 0.17), (0.36, 0.06, 0.62), tw_, bevel=False)
        for dz in (-0.36, -0.24):
            b.box((-0.42, fy - 0.14, z0 + dz), (0.37, 0.065, 0.05), "offwhite", bevel=False)
    if look.get("pocket_tools"):                          # a pocket on the left with a sponge and a brush in it
        b.box((0.36, fy - 0.135, z0 - 0.3), (0.44, 0.05, 0.34), trim, bevel=False)
        b.box((0.27, fy - 0.13, z0 - 0.08), (0.2, 0.045, 0.2), "pastel_butter", bevel=False)       # the sponge
        b.box((0.47, fy - 0.13, z0 - 0.02), (0.08, 0.045, 0.3), "spa_sky", bevel=False)            # the brush
        b.box((0.47, fy - 0.13, z0 + 0.17), (0.15, 0.05, 0.12), "offwhite", bevel=False)


def _arm(p, f, look, sx):
    sleeve = look.get("cardigan") or look["top"]
    x = sx * f.arm_x
    if look.get("short_sleeves"):                        # the staff: a short sleeve with a cuff, the forearm bare
        cut = f.arm1 - 0.58
        p.box_base((x, 0, cut), (0.42, 0.46, f.arm1 - cut), sleeve)
        p.box_base((x, 0, cut - 0.04), (0.47, 0.51, 0.14), look["short_sleeves"])
        p.box_base((x, 0, f.arm0), (0.36, 0.4, cut - f.arm0 + 0.02), look["skin"], bevel=False)
    else:
        p.box_base((x, 0, f.arm0), (0.42, 0.46, f.arm1 - f.arm0), sleeve)
    if look.get("stripes"):
        for k in range(2):
            p.box((x, 0, f.arm0 + 0.3 + 0.38 * k), (0.45, 0.49, 0.12), look["stripes"], bevel=False)
    p.box_base((x, 0, f.arm0 - 0.32), (0.4, 0.42, 0.34), look.get("gloves") or look["skin"])   # the hand
    if look.get("cardigan"):
        p.box_base((x, 0, f.arm0 - 0.02), (0.45, 0.49, 0.1), sleeve)                         # a cuff
    if sx == 1 and look.get("tote"):                     # the left hand carries a tote bag by its handles
        hand = f.hand
        p.box_base((x, 0, hand - 1.05), (0.26, 0.9, 0.82), look["tote"])
        for dy in (-0.2, 0.2):
            p.box_base((x, dy, hand - 0.24), (0.08, 0.08, 0.3), look["tote"], bevel=False)
        yb, zb = 0.0, hand - 0.62                                                            # a paw print on it
        p.box((x + 0.14, yb, zb - 0.06), (0.02, 0.22, 0.16), "offwhite", bevel=False)
        for dy, dz in ((-0.16, 0.05), (-0.055, 0.13), (0.055, 0.13), (0.16, 0.05)):
            p.box((x + 0.14, yb + dy, zb + dz), (0.02, 0.085, 0.085), "offwhite", bevel=False)


def _face(h, f, look):
    d = f.d
    y = f.face
    ez = f.head0 + d["hh"] * 0.47
    for sx in (1, -1):
        # every mark is 0.03 thick and set 0.01 into the face, so it touches the head and stands 0.02 proud
        h.box((sx * 0.32, y - 0.005, ez), (0.17, 0.03, 0.28), FACE_INK, bevel=False)             # eyes
        h.box((sx * 0.32 - 0.03, y - 0.025, ez + 0.06), (0.06, 0.01, 0.07), "milk", bevel=False)
        # a round cheek under the eye's outer half (#776): it was a bar 0.24 wide and 0.1 tall, the people's version
        # of the strips the owner could not read on the cats; ten sides, a true Cylinder as a Part
        h.cyl((sx * CHEEK_X, y - 0.005, ez - CHEEK_Z), CHEEK_R, 0.03, "blush", segments=10, bevel=False,
              rot=(math.radians(90), "X"))
        if look.get("brows"):
            h.box((sx * 0.33, y - 0.005, ez + 0.27), (0.24, 0.03, 0.06), look["hair"], bevel=False)
    mz = ez - 0.33
    h.box((0, y - 0.005, mz), (0.16, 0.03, 0.05), "nose_brick", bevel=False)                     # a smile
    for sx in (1, -1):
        h.box((sx * 0.105, y - 0.005, mz + 0.03), (0.05, 0.03, 0.07), "nose_brick", bevel=False)
    if look.get("beard"):                     # under the smile and along the jaw, clear of the mouth and cheeks
        hb = look["hair"]
        h.box((0, y - 0.03, f.head0 + 0.13), (0.62, 0.06, 0.28), hb, bevel=False)
        for sx in (1, -1):
            h.box((sx * 0.49, y - 0.03, f.head0 + 0.17), (0.36, 0.06, 0.36), hb, bevel=False)
            h.box((sx * (d["hw"] / 2 - 0.03), y + 0.2, f.head0 + 0.42), (0.14, 0.5, 0.66), hb, bevel=False)
    if look.get("shades"):                    # gold rims, the lenses proud of them, over the eyes
        rim, lens = look["shades"]
        for sx in (1, -1):
            h.box((sx * 0.33, y - 0.03, ez + 0.02), (0.56, 0.06, 0.42), rim, bevel=False)
            h.box((sx * 0.33, y - 0.055, ez + 0.02), (0.44, 0.05, 0.3), lens, bevel=False)
            h.box((sx * (d["hw"] / 2 + 0.02), y + 0.3, ez + 0.12), (0.06, 0.62, 0.07), rim, bevel=False)   # an arm
        h.box((0, y - 0.03, ez + 0.1), (0.14, 0.05, 0.07), rim, bevel=False)                      # the bridge
    if look.get("glasses"):
        g = look["glasses"]
        for sx in (1, -1):
            cx = sx * 0.32
            for dz in (-0.2, 0.2):
                h.box((cx, y - 0.025, ez + dz), (0.4, 0.05, 0.05), g, bevel=False)
            for dx in (-0.18, 0.18):
                h.box((cx + dx, y - 0.025, ez), (0.05, 0.05, 0.35), g, bevel=False)
        h.box((0, y - 0.025, ez + 0.05), (0.23, 0.05, 0.05), g, bevel=False)


def _hair(h, f, look):
    d = f.d
    hw, hd, top, h0 = d["hw"], d["hd"], f.head1, f.head0
    fy, hc = f.face, look["hair"]
    style = look["style"]
    if style in ("bob", "short", "bun", "curls", "puffs", "long", "ponytail"):
        h.box_base((0, 0, top - 0.3), (hw + 0.12, hd + 0.12, 0.42 if style != "short" else 0.36), hc)     # crown
        drop = {"bob": 0.95, "short": 0.45, "bun": 0.6, "curls": 0.6, "puffs": 0.55, "long": 1.1,
                "ponytail": 0.5}[style]
        h.box_base((0, hd / 2 - 0.05, top - 0.1 - drop), (hw + 0.07, 0.24, drop), hc)                      # back
        for sx in (1, -1):                                                                                # sides
            h.box_base((sx * (hw / 2 + 0.03), 0.12, top - 0.1 - drop * 0.85), (0.12, hd - 0.2, drop * 0.85), hc)
        if style not in ("short", "bun"):
            h.box((0, fy - 0.05, top - 0.22), (hw - 0.1, 0.12, 0.26), hc)                                 # fringe
    if style == "bob":
        h.box((0, hd / 2 + 0.02, top - 1.0), (hw + 0.16, 0.28, 0.12), hc)                                 # its hem
        for sx in (1, -1):
            h.box((sx * (hw / 2 + 0.05), 0.1, top - 1.0), (0.16, hd - 0.1, 0.12), hc)
    if style == "long":                                    # down the back to the shoulder blades
        # lying on the back (its front 0.02 into the torso's back), not standing off it behind the deeper head
        lo = h0 - 0.55
        back = d["td"] / 2 - 0.02
        h.box_base((0, back + 0.13, lo), (hw + 0.04, 0.26, top - 0.1 - 1.1 - lo + 0.02), hc)
    if style == "ponytail":
        # the tail's front 0.07 into the back hair, the tie wrapped round its top, so it hangs from the head
        h.box_base((0, hd / 2 + 0.15, h0 + 0.05), (0.36, 0.3, top - 0.45 - h0 - 0.05), hc)                # the tail
        h.box((0, hd / 2 + 0.15, top - 0.45), (0.42, 0.38, 0.2), look["tie"], bevel=False)                 # the tie
    if style == "bun":
        h.sphere((0, hd / 2 - 0.05, top - 0.05), 0.4, hc, segments=10, rings=6)
    if style == "curls":
        for x, y, z in ((-0.5, -0.2, 0.18), (0.0, -0.3, 0.22), (0.5, -0.2, 0.18), (-0.35, 0.35, 0.2),
                        (0.35, 0.35, 0.2)):
            h.sphere((x, y, top + z), 0.3, hc, segments=8, rings=5)
    if style == "puffs":
        for sx in (1, -1):
            h.sphere((sx * 0.62, 0.1, top + 0.18), 0.42, hc, segments=10, rings=6)
    if style == "beanie":
        bn = look["beanie"]
        h.box_base((0, 0.06, h0 + 0.35), (hw + 0.1, hd - 0.06, 0.6), hc)                                  # hair below
        h.box_base((0, 0, top - 0.38), (hw + 0.14, hd + 0.14, 0.62), bn)
        h.box_base((0, 0, top - 0.42), (hw + 0.2, hd + 0.2, 0.2), bn)                                     # its fold
        if look.get("ears"):                                                                              # cat ears
            for sx in (1, -1):
                h.pyramid((sx * 0.5, 0.0, top + 0.2), 0.46, 0.42, bn, rot=_ry(-10 * sx))
                h.pyramid((sx * 0.5, -0.13, top + 0.21), 0.24, 0.26, "spa_bubblegum", rot=_ry(-10 * sx))
        else:
            h.sphere((0, 0, top + 0.36), 0.24, "offwhite", segments=8, rings=5)                           # pom-pom
    if look.get("sunhat"):                                                  # sits on the hair's crown
        h.box_base((0, 0, top + 0.11), (2.3, 2.2, 0.07), look["sunhat"])                                  # brim
        h.box_base((0, 0, top + 0.18), (hw + 0.06, hd + 0.06, 0.26), look["sunhat"])
        h.box_base((0, 0, top + 0.2), (hw + 0.1, hd + 0.1, 0.1), look["band"], bevel=False)               # its band
        yf = -(hd + 0.1) / 2
        if look.get("feather"):                                             # a plume standing off the band
            at = Vector((0.5, 0.12, top + 0.34))                            # its foot, inside the hat's crown
            # a plume that curls over: each length thinner than the last, so no two share a front or a back plane
            for deg, ln, wd, th in ((12, 0.56, 0.42, 0.15), (38, 0.4, 0.34, 0.12), (66, 0.3, 0.24, 0.09)):
                lean = _ry(deg)
                h.box(tuple(at + lean @ Vector((0, 0, ln / 2))), (wd, th, ln), look["feather"], rot=lean)
                at = at + lean @ Vector((0, 0, ln - 0.12))
            h.box((0.6, yf - 0.02, top + 0.25), (0.2, 0.04, 0.2), "gold_light", bevel=False, rot=_ry(45))   # its pin
        else:
            h.box((0.42, yf - 0.02, top + 0.25), (0.24, 0.04, 0.24), "offwhite", bevel=False, rot=_ry(45))    # a daisy
            h.box((0.42, yf - 0.05, top + 0.25), (0.1, 0.02, 0.1), "pastel_butter", bevel=False)
    if look.get("beret"):                                                   # worn to one side, a gold star in front
        bt = look["beret"]
        tilt = _ry(-9)
        h.cyl((0, 0, top + 0.16), 0.7, 0.12, bt, segments=12, bevel=False)                                # its band
        h.cyl((0.14, 0.03, top + 0.36), 1.0, 0.32, bt, segments=14, rot=tilt, radius2=0.82)               # the crown
        h.cyl((0.18, 0.03, top + 0.58), 0.07, 0.14, bt, segments=6, bevel=False, rot=tilt)                # the stalk
        h.star((-0.3, -0.84, top + 0.4), 0.3, 0.14, 0.07, "gold_mid", rot=Matrix.Rotation(math.radians(80), 3, "X"))
    if look.get("crown"):                                                   # a band, five points, three jewels
        cr = look["crown"]
        cw, cd = hw - 0.3, hd - 0.3
        h.box_base((0, 0, top + 0.1), (cw, cd, 0.26), cr)
        for dx, dy in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
            h.pyramid((dx * (cw / 2 - 0.13), dy * (cd / 2 - 0.13), top + 0.36), 0.26, 0.3, cr)
        h.pyramid((0, -(cd / 2 - 0.13), top + 0.36), 0.3, 0.42, cr)
        for dx, sw in ((-0.36, "spa_sky"), (0.0, "royal_berry"), (0.36, "spa_mint")):
            h.box((dx, -cd / 2 - 0.01, top + 0.23), (0.13, 0.04, 0.13), sw, bevel=False, rot=_ry(45))
    if look.get("hardhat"):                               # the builder (#891): a hard hat with a peak and a ridge
        hh = look["hardhat"]
        h.box_base((0, 0, top - 0.12), (hw + 0.2, hd + 0.2, 0.2), hh)                                    # the rim
        h.box_base((0, 0, top), (hw + 0.04, hd + 0.04, 0.42), hh)                                         # the dome
        h.box_base((0, -hd / 2 - 0.12, top - 0.1), (hw - 0.1, 0.36, 0.12), hh)                            # the peak
        h.box_base((0, 0, top + 0.38), (0.32, hd + 0.1, 0.14), hh)                                        # the ridge
    if look.get("headband"):                              # the staff: a towelling band round the hair, a paw in front
        band, mark = look["headband"]
        h.box_base((0, 0, top - 0.28), (hw + 0.3, hd + 0.3, 0.25), band)       # its top just under the head's
        yb = -(hd + 0.3) / 2 - 0.012
        h.box((0, yb, top - 0.19), (0.22, 0.03, 0.14), mark, bevel=False)
        for dx, dz in ((-0.16, -0.03), (-0.055, 0.05), (0.055, 0.05), (0.16, -0.03)):
            h.box((dx, yb, top - 0.11 + dz), (0.08, 0.03, 0.08), mark, bevel=False)
    if look.get("phones"):
        h.box_base((0, 0, top + 0.1), (hw + 0.36, 0.22, 0.14), "fur_ink", bevel=False)                    # the band
        for sx in (1, -1):
            h.box_base((sx * (hw / 2 + 0.11), 0, h0 + 0.55), (0.14, 0.22, top + 0.1 - h0 - 0.55), "fur_ink",
                       bevel=False)
            h.box((sx * (hw / 2 + 0.17), 0, h0 + 0.6), (0.24, 0.5, 0.5), look["phones"])                  # the cups


def top_of(look):
    """The highest point of a look: the hair, or its hat."""
    f = Frame(look["body"])
    extra = 0.12
    if look.get("sunhat"):
        extra = 1.2 if look.get("feather") else 0.44
    elif look.get("crown"):
        extra = 0.8
    elif look.get("beret"):
        extra = 0.68
    elif look["style"] == "beanie":
        extra = 0.62
    elif look["style"] in ("puffs", "curls"):
        extra = 0.6
    elif look.get("hardhat"):
        extra = 0.52
    elif look.get("phones"):
        extra = 0.24
    return f.head1 + extra


def grip_at(look, carry=False):
    """The middle of the right hand in the customer's space, where the carrier's Grip goes (`carry`: with the arm
    turned out by `carry_degrees`)."""
    f = Frame(look["body"])
    tilt = _ry(carry_degrees(look)) if carry else None
    p = Piece((-f.arm_x, 0, f.shoulder), tilt)
    return p.at((-f.arm_x, 0, f.hand))


def build_customer(name, mat, carry=False):
    """The customer's six objects: Body first (the main object), then Head, ArmL, ArmR, LegL, LegR. `carry` True
    builds the right arm turned out as it holds a carrier (pictures only)."""
    return build_figure(PREFIX + name, ALL_LOOKS[name], mat, carry)


def build_figure(asset, look, mat, carry=False):
    """Any figure on this body (the customers here, the staff in spa_staff.py): six objects named from `asset`."""
    f = Frame(look["body"])
    body = Piece()
    _lower(body, f, look)
    _torso(body, f, look)
    head = Piece((0, 0, f.head0))
    head.box_base((0, 0, f.head0), (f.d["hw"], f.d["hd"], f.d["hh"]), look["skin"])
    _face(head, f, look)
    _hair(head, f, look)
    arm_l = Piece((f.arm_x, 0, f.shoulder))
    arm_r = Piece((-f.arm_x, 0, f.shoulder), _ry(carry_degrees(look)) if carry else None)
    _arm(arm_l, f, look, 1)
    _arm(arm_r, f, look, -1)
    legs = [Piece((0.32, 0, f.leg_joint)), Piece((-0.32, 0, f.leg_joint))]
    _legs(legs, f, look)
    pieces = (("_Body", body), ("_Head", head), ("_ArmL", arm_l), ("_ArmR", arm_r), ("_LegL", legs[0]),
              ("_LegR", legs[1]))
    return [p.finalize(asset + sfx, mat) for sfx, p in pieces]


def customer_rbx_extras(name):
    look = ALL_LOOKS[name]
    f = Frame(look["body"])
    return {"attachments": [("_ArmR", "Grip", Matrix.Translation(grip_at(look))),
                            ("_Body", "Overhead", Matrix.Translation((0.0, 0.0, top_of(look) + 0.6)))],
            "attributes": {"Look": {"String": name}, "WalkSpeed": {"Float64": look["body"]["speed"]},
                           "LegLength": {"Float64": round(f.leg_joint, 3)},
                           "CarryArmDegrees": {"Float64": carry_degrees(look)},
                           "ArmsStraight": {"Bool": True},      # built with the right arm straight (#874)
                           "Height": {"Float64": round(top_of(look), 3)},
                           **({"Special": {"Bool": True}} if name in SPECIAL_LOOKS else {})}}


ASSETS = {PREFIX + n: ((lambda mat, n=n: build_customer(n, mat)), 1600) for n in ALL_LOOKS}
EXTRAS = {PREFIX + n: (lambda n=n: customer_rbx_extras(n)) for n in ALL_LOOKS}
