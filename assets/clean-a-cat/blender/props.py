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

A special cat's built-in pieces (#486) are further down: every special cat (cats.SPECIAL_CATS) wears a Head piece
and a Back piece with lit parts, as the best cats in the owner's asset library do. The slot frames, `Pen`, `Ctx` and
`build` are ported from that library (Roblox-Asset-Library, models/blender-generators/props.py, 2026-11-25); the
pieces themselves are ours, and each one's docstring says which library piece it grew from.

  CleanACat_Cat_<Name>[_Dirty][_Sit]_Prop        the Head piece, a child Model inside the Head Model (a head turn
                                                 carries it). `..._Prop_Glass` holds its clear parts.
  ..._Prop2                                      the Back piece, a child Model of the cat (it rides the Body)
  ..._<Piece>_Glow, ..._Glow                     lit parts (Neon in Roblox), each inside the piece PIECES names
  ..._Tail_<Piece>                               a piece on the tail, inside the Tail Model
  Root attributes `PropSlot` = "Head" and `PropSlot2` = "Back"; every part of a piece carries `Follows` (Head, Body
  or Tail). Nothing collides. A wash can skip them all by name: anything under a Model whose name contains `_Prop`
  or ends in `_Glow`.

  Frames a piece is drawn in:
  head   origin on the head top centre, x the cat's left, y back, z up, in units of the sitting head (0.92 wide)
  face   origin on the face plane at eye height, y negative out of the face
  back   origin on the middle of the back: on the walking body its top (y to the tail, z up), on the sitting body
         the back of the chest (y runs down it, z is backwards)
  up     the same spot with the world's axes, for things that stand up (wings)
  tail   the Tail's own space (Ctx.piece with a host of "Tail")
"""

import math

from mathutils import Matrix, Vector

import cats
from common import Builder
from stations import _tris

B_BACK_Y = cats.B_CHEST_C[1] + cats.B_CHEST_S[1] / 2      # the back face of B's chest
B_BACK_Z = 0.8                                           # the middle of B's back, above the haunches (0.56)


def _rx(deg):
    return Matrix.Rotation(math.radians(deg), 3, "X")


def _ry(deg):
    return Matrix.Rotation(math.radians(deg), 3, "Y")


def _rz(deg):
    return Matrix.Rotation(math.radians(deg), 3, "Z")


class Pen:
    """Builder primitives drawn in a slot frame: point p lands at T @ R @ (s * p), sizes scale by s."""

    def __init__(self, b, at, R, s):
        self.b, self.at, self.R, self.s = b, Vector(at), R, s

    def p(self, c):
        return tuple(self.at + self.R @ (Vector(c) * self.s))

    def _r(self, rot):
        return self.R @ rot if rot is not None else self.R.copy()

    def box(self, c, size, sw, rot=None, bevel=False):
        self.b.box(self.p(c), tuple(v * self.s for v in size), sw, bevel=bevel, rot=self._r(rot))

    def cyl(self, c, r, h, sw, rot=None, r2=None, segments=12, bevel=False):
        self.b.cyl(self.p(c), r * self.s, h * self.s, sw, segments=segments, bevel=bevel, rot=self._r(rot),
                   radius2=None if r2 is None else r2 * self.s)

    def sphere(self, c, r, sw, scale=(1, 1, 1), rot=None, segments=10, rings=6):
        self.b.sphere(self.p(c), r * self.s, sw, segments=segments, rings=rings, scale=scale, rot=self._r(rot))

    def ico(self, c, r, sw, scale=(1, 1, 1), rot=None):
        self.b.ico(self.p(c), r * self.s, sw, scale=scale, rot=self._r(rot))

    def pyramid(self, c, size, h, sw, rot=None):
        """Square pyramid centred on c (the Builder's pyramid turns about its middle)."""
        x, y, z = self.p(c)
        self.b.pyramid((x, y, z - h * self.s / 2), size * self.s, h * self.s, sw, rot=self._r(rot))

    def ring(self, c, r, t, h, sw, rot=None, segments=12):
        self.b.ring(self.p(c), r * self.s, t * self.s, h * self.s, sw, segments=segments, bevel=False, rot=self._r(rot))

    def star(self, c, outer, inner, h, sw, rot=None):
        self.b.star(self.p(c), outer * self.s, inner * self.s, h * self.s, sw, rot=self._r(rot))

    def fan(self, c, apex, chain, h, sw, rot=None):
        s = self.s
        self.b.fan(self.p(c), (apex[0] * s, apex[1] * s), [(x * s, y * s) for x, y in chain], h * s, sw, rot=self._r(rot))

    def bar(self, a, b, w, t, sw, up=(0, 0, 1)):
        """A strap or rod from point a to point b: width w across, thickness t along `up` (frame units)."""
        a, b = Vector(a), Vector(b)
        d = b - a
        y = d.normalized()
        z = Vector(up)
        z = (z - y * z.dot(y)).normalized()
        x = y.cross(z)
        R = Matrix((x, y, z)).transposed()
        self.box(tuple((a + b) / 2), (w, d.length, t), sw, rot=R)


class Ctx:
    """One prop drawing on one body: pens per frame on the prop's Builder and on its glass Builder, and the head's
    sizes in each frame's units."""

    def __init__(self, spec, body, d):
        self.body, self.spec, self.d = body, spec, d
        self.work = False               # body S (the working pose) draws on B's frames; set by build
        self.main, self.glass = Builder(), Builder()
        self.origin = Vector((0.0, 0.0, 0.0))        # the object's pivot in the ridden piece's space (pivot_at)
        self.extra = {}                              # suffix -> (Builder, pivot), extra objects (piece)
        h = d["head"]
        self.h = h
        hs, kf = h["s"][0] / 0.92, h["k"] / 1.05
        self._frames = {"head": ((0, h["c"][1], h["top"]), Matrix.Identity(3), hs),
                        "face": ((0, h["fy"], h["fz"]), Matrix.Identity(3), kf)}
        self._frames["tail"] = ((0.0, 0.0, 0.0), Matrix.Identity(3), 1.0)   # #2739 the Tail's own space (piece)
        if body == "walk":
            (x0, y0, z0), (sx, sy, sz) = d["body"]
            self.back_len, self.back_w = sy, sx
            self._frames["back"] = ((0, y0, z0 + sz / 2), Matrix.Identity(3), 1.0)
            self._frames["up"] = ((0, y0 - sy * 0.22, z0 + sz / 2), Matrix.Identity(3), 1.0)
        else:
            self.back_len, self.back_w = cats.B_CHEST_S[2], cats.B_CHEST_S[0]
            self._frames["back"] = ((0, B_BACK_Y, B_BACK_Z), _rx(-90), 1.0)
            self._frames["up"] = ((0, B_BACK_Y, 0.98), Matrix.Identity(3), 1.0)
        # the head in head-frame units (B: 0.46 half width, 0.37 to the front and back, 0.76 deep)
        self.hw, self.hd, self.hh = h["s"][0] / 2 / hs, h["s"][1] / 2 / hs, h["s"][2] / hs
        self.ear_x = h["ear_x"] / hs
        # the face in face-frame units: half width, depth to the back of the head, top and bottom, eyes
        self.fw, self.fd = h["s"][0] / 2 / kf, h["s"][1] / kf
        self.ftop, self.fbot = (h["top"] - h["fz"]) / kf, (h["c"][2] - h["s"][2] / 2 - h["fz"]) / kf
        self.eye_x = h["eye_dx"] * h["k"] / kf
        self.eye_hw, self.eye_hh = 0.1 * h["k"] / kf, cats.EYE_H / 2 * h["k"] / kf
        self.mouth_z = -0.2 * h["k"] / kf
        if body == "sit":
            (hx0, hy0, _hz0), (hsx, hsy, hsz) = d["haunch"]
            self.haunch_back, self.haunch_top = hy0 + hsy / 2, hsz

    def pen(self, frame):
        at, R, s = self._frames[frame]
        return Pen(self.main, Vector(at) - self.origin, R, s)

    def gpen(self, frame):
        at, R, s = self._frames[frame]
        return Pen(self.glass, Vector(at) - self.origin, R, s)

    def point(self, frame, c):
        """Point c of `frame` in the space of the piece the prop rides (the neck for Head and Face props)."""
        at, R, s = self._frames[frame]
        return Vector(at) + R @ (Vector(c) * s)

    def pivot_at(self, frame, c):
        """Pivot the prop's object at point c of `frame` (a hinge the animations turn it about) instead of at the
        joint it rides. Call before drawing."""
        assert not self.main.prims and not self.glass.prims, "pivot_at goes before the first primitive"
        self.origin = self.point(frame, c)

    def piece(self, suffix, frame, c):
        """A Pen for an extra object of this prop, `<name>_<suffix>`, pivoted at point c of `frame` (a bell that
        swings from it). It rides what the prop rides; PIECES names its host for the Roblox nesting."""
        at = self.point(frame, c)
        b = Builder()
        self.extra[suffix] = (b, at)
        _, R, s = self._frames[frame]
        return Pen(b, Vector(self._frames[frame][0]) - at, R, s)

    def back_frame_offset(self):
        """Back props are in the Body's space (pivot at the model origin), head props relative to the neck."""
        return self._frames["back"][0]



def _tail_axes(ctx):
    """The tail's tip, its last segment's direction and thickness, and two directions across it (Tail space)."""
    tip, d, th = cats.tail_tip(ctx.d["tail_chain"])
    a = d.cross(Vector((1.0, 0.0, 0.0)))
    a = (a if a.length > 1e-3 else d.cross(Vector((0.0, 0.0, 1.0)))).normalized()
    return tip, d, th, a, d.cross(a).normalized()


# ------------------------------------------------------------------------------- the special cats' pieces --
GOLD = "gold_mid"
# Neon is for small gems in a deep colour: a cream, white or pastel Neon part clips to white with a halo in game
# (#491, #496). A big shape that must keep its outline is solid (STAR is Stardust's pale yellow).
STAR, NEON_GOLD, NEON_SKY, NEON_MINT = "sparkle", "eye_gold", "eye_sky", "eye_mint"
BODY_SIT = "sit"


def _off_floor(ctx, c, reach):
    """Point c (Tail space) lifted so a tail piece reaching `reach` below it stays above the floor: a sitting cat's
    tail lies on the ground, and its tip piece must not dip under it (#486)."""
    c = Vector(c)
    low = ctx.d["pivots"]["Tail"][2] + c.z - reach
    return c + Vector((0.0, 0.0, max(0.0, 0.015 - low)))


def _heart(P, c, r, sw, lean=None, depth=0.05):
    """A flat heart facing the front, r its half width: two discs and a square on its corner, each a different
    depth so no two faces share a plane."""
    c = Vector(c)
    R = lean if lean is not None else Matrix.Identity(3)
    stand = R @ _rx(90)
    for k, sx in enumerate((-1, 1)):
        P.cyl(tuple(c + R @ Vector((sx * r * 0.5, 0, r * 0.3))), r * 0.56, depth + 0.01 * k, sw, rot=stand, segments=10)
    P.box(tuple(c + R @ Vector((0, 0, -r * 0.22))), (r * 1.0, depth + 0.02, r * 1.0), sw, rot=R @ _ry(45))


# Stardust ---------------------------------------------------------------------------------------------------
def star_tiara(ctx):
    """Stardust: a big pale star stands on a gold band between the ears with a lit gem on a stalk each side and a
    small lit gem at its heart. The star itself is solid: as cream Neon it clipped to white with a halo in game and
    lost its shape (#491). Grew from the library's tree_star and moon_antlers (a bright shape held high)."""
    P = ctx.pen("head")
    G = ctx.piece("Glow", "head", (0, -0.12, 0.1))
    y = -0.12
    P.box((0, y, 0.03), (0.6, 0.09, 0.09), GOLD)
    P.box((0, y, 0.17), (0.11, 0.07, 0.26), GOLD)
    P.star((0, y, 0.42), 0.31, 0.14, 0.09, STAR, rot=_rx(90))
    G.box((0, y, 0.415), (0.1, 0.13, 0.1), NEON_GOLD, rot=_ry(45))
    for sx, sw in ((-1, "neon_pink"), (1, "eye_sky")):
        a, b = Vector((sx * 0.26, y, 0.05)), Vector((sx * 0.55, y + 0.05, 0.34))
        P.bar(tuple(a), tuple(b), 0.055, 0.055, GOLD, up=(0, 1, 0))
        G.box(tuple(b + Vector((sx * 0.02, 0, 0.05))), (0.15, 0.08, 0.15), sw, rot=_ry(45))


def comet_back(ctx):
    """Stardust's back piece: a shooting star, a pale star on a violet saddle with three streamers sweeping back
    over the tail, a small lit gem on the end of each. Grew from the library's star_trail."""
    U = ctx.pen("up")
    G = ctx.piece("Comet_Glow", "up", (0, 0.2, 0.3))
    y0 = 0.13
    U.box((0, y0, 0.03), (0.34, 0.28, 0.1), "aurora_violet")
    c = Vector((0, y0 + 0.08, 0.5))
    U.bar((0, y0, 0.06), tuple(c - Vector((0, 0, 0.1))), 0.08, 0.08, GOLD, up=(0, 1, 0))
    U.star(tuple(c), 0.3, 0.13, 0.08, STAR, rot=_rx(70))
    for k, (dx, sw) in enumerate(((-0.2, "fur_bubblegum"), (0.0, "pastel_sky"), (0.2, "aurora_violet"))):
        a = c + Vector((dx * 0.5, 0.03, -0.05))
        b = c + Vector((dx * 1.4, 0.62 + 0.1 * (k == 1), -0.2 - 0.06 * (k == 1)))
        U.bar(tuple(a), tuple(b), 0.11, 0.05, sw, up=(0, 0, 1))
        G.box(tuple(b), (0.13, 0.08, 0.13), NEON_GOLD, rot=_rx(45))
    tip, d, th, _a, _b = _tail_axes(ctx)
    at = _off_floor(ctx, tip + d * 0.1, 0.2)
    T = ctx.piece("Tail_Star", "tail", tuple(tip))
    T.star(tuple(at), 0.2, 0.09, 0.08, STAR, rot=_rx(90))
    TG = ctx.piece("Tail_Star_Glow", "tail", tuple(tip))
    TG.box(tuple(at), (0.07, 0.11, 0.07), NEON_GOLD, rot=_ry(45))


# Sherbet ----------------------------------------------------------------------------------------------------
def sundae_top(ctx):
    """Sherbet: a swirl of whipped cream between the ears with a lit cherry, a wafer and sprinkles. Grew from the
    library's ice_cream_hat and candy_puff."""
    P = ctx.pen("head")
    G = ctx.piece("Cherry_Glow", "head", (0, -0.03, 0.4))
    for z, r, sq in ((0.07, 0.31, 0.5), (0.21, 0.23, 0.55), (0.33, 0.15, 0.6)):
        P.sphere((0, -0.03, z), r, "coat_cotton", scale=(1, 1, sq), segments=10, rings=5)
    G.ico((0, -0.03, 0.47), 0.105, "neon_pink")
    P.bar((0, -0.03, 0.55), (0.07, -0.01, 0.68), 0.03, 0.03, "leaf_dark")
    P.box((0.2, 0.04, 0.33), (0.17, 0.045, 0.4), "treat_tan", rot=_ry(-24))
    P.box((0.2, 0.012, 0.33), (0.11, 0.02, 0.3), "kibble", rot=_ry(-24))
    for i, (az, z, r) in enumerate(((-30, 0.1, 0.3), (40, 0.12, 0.29), (150, 0.1, 0.3), (-140, 0.11, 0.29),
                                    (-70, 0.25, 0.2), (100, 0.25, 0.2))):
        R = _rz(az)
        sw = ("spa_mint", "spa_sky", "pastel_butter", "neon_pink")[i % 4]
        P.box(tuple(R @ Vector((0, -r, z)) + Vector((0, -0.03, 0))), (0.1, 0.05, 0.04), sw, rot=R @ _ry(35 * (-1) ** i))


def heart_wings(ctx):
    """Sherbet's back piece: two mint heart wings with a lit pink heart on each. Grew from the library's
    sugar_wings and fairy_wings."""
    U = ctx.pen("up")
    G = ctx.piece("Wings_Glow", "up", (0, 0.1, 0.3))
    y0 = 0.1
    U.box((0, y0, 0.04), (0.3, 0.16, 0.12), "fur_strawberry")
    for sx in (-1, 1):
        lean = _rz(-sx * 22) @ _ry(-sx * 24)
        c = Vector((sx * 0.45, y0 + 0.1, 0.47))
        U.bar((sx * 0.1, y0, 0.08), tuple(c + Vector((-sx * 0.1, 0, -0.14))), 0.1, 0.05, "fur_strawberry", up=(0, 1, 0))
        _heart(U, c, 0.34, "spa_mint", lean, depth=0.05)
        _heart(G, c + lean @ Vector((0, -0.045, 0.0)), 0.15, "neon_pink", lean, depth=0.03)


# Rosette ----------------------------------------------------------------------------------------------------
def _rose(P, c, r, sw, heart):
    """A rose from above: a round of outer petals, a turned square of inner ones and a bud."""
    x, y, z = c
    P.sphere(c, r, sw, scale=(1, 1, 0.62), segments=8, rings=4)
    P.box((x, y, z + r * 0.42), (r * 1.05, r * 1.05, r * 0.42), heart, rot=_rz(45))
    P.box((x, y, z + r * 0.68), (r * 0.5, r * 0.5, r * 0.34), sw, rot=_rz(12))


def rose_crown(ctx):
    """Rosette: one bold gold crown with a berry velvet cap, a lit gem on each of its five points and a single rose
    on the front of the band. It stands back from the brow, so the face and its diamond stay in the clear (#486,
    Review-QA: three roses and leaves were clutter at 64 px). Grew from the library's queen_crown and flower_crown."""
    P = ctx.pen("head")
    G = ctx.piece("Gem_Glow", "head", (0, 0.02, 0.4))
    y0, r = 0.03, 0.3
    P.ring((0, y0, 0.07), r, 0.07, 0.15, GOLD, segments=10)
    P.sphere((0, y0, 0.12), r - 0.03, "royal_berry", scale=(1, 1, 0.75), segments=10, rings=5)   # the velvet cap
    for k in range(5):                                                   # one point to the front, four round
        a = math.radians(-90 + 72 * k)
        ht = 0.3 if k == 0 else 0.24
        x, y = r * math.cos(a), y0 + r * math.sin(a)
        P.pyramid((x, y, 0.13 + ht / 2), 0.17, ht, GOLD, rot=_rz(-90 + 72 * k))
        G.ico((x, y, 0.15 + ht), 0.07 if k == 0 else 0.055, NEON_MINT if k == 0 else NEON_GOLD)
    _rose(P, (0, y0 - r - 0.03, 0.09), 0.12, "fur_rose", "royal_berry")


def rose_fan(ctx):
    """Rosette's back piece: one scalloped rose fan standing behind the shoulders on a berry root, berry ribs to its
    five scallops and a lit pearl on each. Grew from the library's fire_wings (a fan from one root)."""
    U = ctx.pen("up")
    G = ctx.piece("Fan_Glow", "up", (0, 0.2, 0.3))
    y0 = 0.3 if ctx.body == "walk" else 0.12
    lean = _rx(-12)
    root = Vector((0, y0, 0.06))
    U.cyl(tuple(root), 0.2, 0.11, "royal_berry", rot=lean @ _rx(90), segments=10)
    n, L, dip = 5, 0.7, 0.57
    span = (20.0, 160.0)
    step = (span[1] - span[0]) / n
    chain = []
    for k in range(n + 1):
        a = math.radians(span[0] + step * k)
        chain.append((math.cos(a) * dip, math.sin(a) * dip))
        if 0 < k < n:                                                    # a berry rib to each dip
            U.bar(tuple(root), tuple(root + lean @ Vector((math.cos(a), 0, math.sin(a))) * (dip - 0.02)), 0.05, 0.075,
                  "royal_berry", up=(0, 1, 0))
        if k < n:
            am = math.radians(span[0] + step * (k + 0.5))
            chain.append((math.cos(am) * L, math.sin(am) * L))
            G.ico(tuple(root + lean @ Vector((math.cos(am), 0, math.sin(am))) * (L + 0.01)), 0.06, NEON_GOLD)
    U.fan(tuple(root), (0.0, 0.0), chain, 0.05, "fur_rose", rot=lean @ _rx(90))
    tip, d, th, _a, _b = _tail_axes(ctx)
    T = ctx.piece("Tail_Rose", "tail", tuple(tip))
    T.sphere(tuple(_off_floor(ctx, tip + d * 0.02, th * 0.76)), th * 0.95, "fur_rose", scale=(1, 1, 0.8), segments=8, rings=4)


# Prism ------------------------------------------------------------------------------------------------------
RAINBOW = ("neon_pink", "fur_marmalade", "pastel_butter", "spa_mint", "spa_sky", "aurora_violet")


def crystal_horn(ctx):
    """Prism: a lit crystal horn on the brow with rainbow rings, a small crystal each side. Grew from the
    library's unicorn_horn."""
    P = ctx.pen("head")
    R = _rx(14)
    base = Vector((0, -0.24, -0.02))
    d = R @ Vector((0, 0, 1))
    G = ctx.piece("Glow", "head", tuple(base))
    G.cyl(tuple(base + d * 0.3), 0.12, 0.6, "milk", r2=0.015, rot=R, segments=6)
    for f, r, sw in ((0.08, 0.11, "neon_pink"), (0.24, 0.092, "pastel_butter"), (0.4, 0.074, "spa_mint"),
                     (0.56, 0.056, "spa_sky")):
        P.cyl(tuple(base + d * (0.6 * f + 0.02)), r + 0.022, 0.045, sw, rot=R, segments=6)
    for sx, sw in ((-1, "spa_sky"), (1, "neon_pink")):
        Rs = _ry(sx * 28) @ _rx(8)
        b2 = Vector((sx * 0.2, -0.22, -0.02))
        G.cyl(tuple(b2 + Rs @ Vector((0, 0, 0.13))), 0.07, 0.26, sw, r2=0.01, rot=Rs, segments=6)


def rainbow_arc(ctx):
    """Prism's back piece: a rainbow arching over its back from a cloud at each side, lit. Grew from the library's
    rainbow_pot (a rainbow springing from the back)."""
    U = ctx.pen("up")
    G = ctx.piece("Rainbow_Glow", "up", (0, 0.2, 0.3))
    y0 = 0.3 if ctx.body == "walk" else 0.12
    half = ctx.back_w / 2 - 0.02
    n = 6
    for j, sw in enumerate(("neon_pink", "pastel_butter", "spa_mint", "spa_sky")):
        r = half + 0.3 - 0.08 * j
        ys = y0 + 0.012 * j                                # each band a hair behind the last: no shared planes
        pts = [Vector((r * math.cos(math.radians(180 * i / n)), ys, r * math.sin(math.radians(180 * i / n)) * 1.15 + 0.02))
               for i in range(n + 1)]
        for p0, p1 in zip(pts, pts[1:]):
            G.bar(tuple(p0), tuple(p1), 0.09, 0.07 + 0.006 * j, sw, up=(0, 1, 0))
    for sx in (-1, 1):
        for dx, dz, r in ((0.1, 0.05, 0.14), (0.0, 0.11, 0.185), (-0.15, 0.04, 0.15)):
            U.ico((sx * (half + 0.16 + dx), y0 + 0.02, dz), r, "milk", rot=_rz(17) @ _rx(11))


# Jade -------------------------------------------------------------------------------------------------------
def lotus_horns(ctx):
    """Jade: two gold horns with lit jade tips and a lotus in bloom between them, its heart lit. Grew from the
    library's ember_horns and petal_horns."""
    P = ctx.pen("head")
    G = ctx.piece("Glow", "head", (0, -0.1, 0.2))
    for sx in (-1, 1):
        pts = [Vector((sx * 0.2, 0.12, -0.02)), Vector((sx * 0.34, 0.2, 0.24)), Vector((sx * 0.3, 0.3, 0.44))]
        P.bar(tuple(pts[0]), tuple(pts[1]), 0.13, 0.13, GOLD, up=(0, 1, 0))
        P.bar(tuple(pts[1]), tuple(pts[2]), 0.095, 0.095, GOLD, up=(0, 1, 0))
        G.bar(tuple(pts[2] - Vector((0, 0.01, 0.02))), tuple(pts[2] + Vector((-sx * 0.08, 0.06, 0.17))), 0.065, 0.065,
              "eye_mint", up=(0, 1, 0))
    c = Vector((0, -0.14, 0.0))
    P.cyl(tuple(c + Vector((0, 0, 0.02))), 0.24, 0.04, "leaf_green", segments=10)          # the pad
    for k in range(6):                                                                     # outer petals
        R = _rz(60 * k) @ _rx(-48)
        P.box(tuple(c + R @ Vector((0, 0, 0.13)) + Vector((0, 0, 0.03))), (0.14, 0.045, 0.24), "fur_rose", rot=R)
    for k in range(3):                                                                     # inner petals
        R = _rz(120 * k + 30) @ _rx(-20)
        P.box(tuple(c + R @ Vector((0, 0, 0.13)) + Vector((0, 0, 0.04))), (0.11, 0.05, 0.24), "fur_strawberry", rot=R)
    G.ico(tuple(c + Vector((0, 0, 0.17))), 0.085, NEON_GOLD)


def dragon_back(ctx):
    """Jade's back piece: a row of jade spines with lit gold tips down its back and two small teal wings. Grew from
    the library's petal_spines and dragon_wings."""
    P = ctx.pen("back")
    G = ctx.piece("Spines_Glow", "back", (0, 0, 0.2))
    L = ctx.back_len
    for i, f in enumerate((-0.1, 0.11, 0.31, 0.47)):
        h = 0.34 - 0.06 * i
        P.pyramid((0, f * L, h / 2 - 0.01), 0.2 - 0.02 * i, h, "sign_teal", rot=_rx(-16))
        G.ico((0, f * L + h * 0.26, h * 0.92), 0.06, NEON_GOLD)
    U = ctx.pen("up")
    W = ctx.piece("Wings_Glow", "up", (0, 0.08, 0.3))
    y0 = 0.08
    ribs = ((68, 0.8), (42, 0.8), (16, 0.58))               # each rib: its angle up from level and its length
    for sx in (-1, 1):
        root = Vector((sx * 0.16, y0, 0.03))
        lean = _rz(sx * 20)                                  # swept back, clear of the head
        for k, (ang, Lw) in enumerate(ribs):
            a = math.radians(ang)
            dirv = lean @ Vector((sx * math.cos(a), 0, math.sin(a)))
            U.bar(tuple(root), tuple(root + dirv * Lw), 0.075, 0.07 + 0.008 * k, GOLD, up=(0, 1, 0))
            W.ico(tuple(root + dirv * (Lw + 0.02)), 0.055, NEON_GOLD)
        chain = []                                           # the skin between the ribs, scalloped between their tips
        for k, (ang, Lw) in enumerate(ribs):
            chain.append((sx * math.cos(math.radians(ang)) * Lw * 0.94, math.sin(math.radians(ang)) * Lw * 0.94))
            if k + 1 < len(ribs):
                am, Lm = math.radians((ang + ribs[k + 1][0]) / 2), (Lw + ribs[k + 1][1]) / 2 * 0.82
                chain.append((sx * math.cos(am) * Lm, math.sin(am) * Lm))
        U.fan(tuple(root), (0.0, 0.0), chain, 0.035, "spa_mint", rot=lean @ _rx(90))
    tip, d, th, _a, _b = _tail_axes(ctx)
    T = ctx.piece("Tail_Pearl_Glow", "tail", tuple(tip))
    T.ico(tuple(_off_floor(ctx, tip + d * 0.06, th * 0.8)), th * 0.8, NEON_GOLD)


# Bathtile ---------------------------------------------------------------------------------------------------
def shower_cap(ctx):
    """Bathtile: a pink shower cap with a mint frill and butter dots, a rubber duck riding it and soap bubbles on
    it. No white foam on the head: white foam is what the wash leaves to rinse, so it read as a cat not yet clean
    (#486, Review-QA). Grew from the library's rubber_duck."""
    P, C = ctx.pen("head"), ctx.gpen("head")
    G = ctx.piece("Duck_Glow", "head", (0, -0.04, 0.4))
    P.cyl((0, 0, 0.03), 0.43, 0.1, "spa_mint", segments=12)                               # the frill
    P.sphere((0, 0, 0.07), 0.41, "spa_bubblegum", scale=(1, 1, 0.62), segments=12, rings=6)  # the cap
    for az, el in ((-60, 38), (0, 30), (62, 40), (125, 34), (-130, 36), (180, 50)):
        a, e = math.radians(az), math.radians(el)
        P.ico((0.4 * math.cos(e) * math.sin(a), -0.4 * math.cos(e) * math.cos(a), 0.07 + 0.25 * math.sin(e)), 0.06,
              "pastel_butter", scale=(1, 1, 0.7))
    d0 = Vector((0.0, -0.02, 0.4))
    P.sphere(tuple(d0), 0.17, "pastel_butter", scale=(1, 1.25, 0.8), segments=8, rings=5)
    P.sphere(tuple(d0 + Vector((0, -0.13, 0.17))), 0.125, "pastel_butter", segments=8, rings=5)
    P.box(tuple(d0 + Vector((0, -0.27, 0.15))), (0.12, 0.1, 0.045), "fur_marmalade")
    P.box(tuple(d0 + Vector((0, 0.21, 0.08))), (0.12, 0.1, 0.1), "pastel_butter", rot=_rx(-30))
    for sx in (-1, 1):
        P.box(tuple(d0 + Vector((sx * 0.085, -0.2, 0.21))), (0.035, 0.035, 0.045), "fur_black")
    G.ico(tuple(d0 + Vector((0, -0.13, 0.33))), 0.05, NEON_SKY)                              # a lit water drop on its head
    for x, y, z, r in ((-0.33, 0.12, 0.22, 0.12), (0.3, 0.2, 0.22, 0.1)):
        C.sphere((x, y, z), r, "bubble", segments=8, rings=5)


def bubble_trail(ctx):
    """Bathtile's back piece: a bar of pink soap on a mint sponge with a stack of bubbles rising off it, a lit
    drop on the top one. Grew from the library's wave_back (bubbles drifting over the back)."""
    U, C = ctx.pen("up"), ctx.gpen("up")
    G = ctx.piece("Bubbles_Glow", "up", (0, 0.3, 0.4))
    y0 = 0.3 if ctx.body == "walk" else 0.14
    U.box((0.0, y0, 0.06), (0.44, 0.34, 0.17), "spa_mint", rot=_rz(-8), bevel=True)          # the sponge
    U.box((0.0, y0, 0.2), (0.3, 0.2, 0.12), "spa_bubblegum", rot=_rz(18), bevel=True)
    U.box((0.0, y0, 0.265), (0.16, 0.09, 0.02), "fur_rose", rot=_rz(18))
    at, r = Vector((0.05, y0 + 0.02, 0.36)), 0.16
    for k, (dx, dy) in enumerate(((0.12, 0.05), (-0.13, 0.08), (0.1, 0.1))):
        if k != 1:                                       # see-through bubbles never touch each other (#176):
            C.sphere(tuple(at), r, "bubble", segments=8, rings=5)
        else:                                            # a solid sky blue one sits between every two
            U.ico(tuple(at), r, "pastel_sky")
        nxt = at + Vector((dx, dy, 0.0))
        r2 = r * 0.86
        nxt.z = at.z + math.sqrt(max(0.0, ((r + r2) * 0.78) ** 2 - dx * dx - dy * dy))
        at, r = nxt, r2
    U.ico(tuple(at), r, "pastel_sky")                # the top bubble is solid too; only its glint is lit (#496)
    G.ico(tuple(at + Vector((0.07, 0.02, r * 0.8))), 0.07, NEON_SKY)


PROPS = {"Stardust": ("Head", star_tiara), "Sherbet": ("Head", sundae_top), "Rosette": ("Head", rose_crown),
         "Prism": ("Head", crystal_horn), "Jade": ("Head", lotus_horns), "Bathtile": ("Head", shower_cap)}
PROPS2 = {"Stardust": ("Back", comet_back), "Sherbet": ("Back", heart_wings), "Rosette": ("Back", rose_fan),
          "Prism": ("Back", rainbow_arc), "Jade": ("Back", dragon_back), "Bathtile": ("Back", bubble_trail)}
# Extra objects a piece draws (Ctx.piece): cat -> {suffix: the object it hangs from, or "Tail"}.
PIECES = {"Stardust": {"Glow": "Prop", "Comet_Glow": "Prop2", "Tail_Star": "Tail", "Tail_Star_Glow": "Tail"},
          "Sherbet": {"Cherry_Glow": "Prop", "Wings_Glow": "Prop2"},
          "Rosette": {"Gem_Glow": "Prop", "Fan_Glow": "Prop2", "Tail_Rose": "Tail"},
          "Prism": {"Glow": "Prop", "Rainbow_Glow": "Prop2"},
          "Jade": {"Glow": "Prop", "Spines_Glow": "Prop2", "Wings_Glow": "Prop2", "Tail_Pearl_Glow": "Tail"},
          "Bathtile": {"Duck_Glow": "Prop", "Bubbles_Glow": "Prop2"}}
SPECIAL_BUDGET = 2100       # a special cat with two pieces (a roster cat has 1,500)


for _asset, (_fn, _budget) in list(cats.ASSETS.items()):
    if cats.parse(_asset)[0] in PROPS2:
        cats.ASSETS[_asset] = (_fn, max(_budget, SPECIAL_BUDGET))


def build(name, spec, body, d):
    """{object suffix: (Builder, pivot)} for one cat's pieces on one body: "Prop", plus "Prop_Glass" when it has clear
    parts, "Prop2" for the second piece and any extra pieces (PIECES). Head and Face pieces are drawn relative to the
    neck (the Head's pivot), Back pieces in the model's space."""
    out = {}
    for key, table in (("Prop", PROPS), ("Prop2", PROPS2)):
        if name not in table:
            continue
        ctx = Ctx(spec, "sit" if body == "work" else body, d)
        ctx.work = body == "work"
        table[name][1](ctx)
        out[key] = (ctx.main, tuple(ctx.origin))
        if ctx.glass.prims:
            out[key + "_Glass"] = (ctx.glass, tuple(ctx.origin))
        for suffix, (b, at) in ctx.extra.items():
            assert PIECES.get(name, {}).get(suffix) in (key, "Tail"), f"{name}: list {suffix} in PIECES"
            out[suffix] = (b, tuple(at))
    return out


def head_top(name, spec, body, d):
    """How high a cat's head piece stands, relative to the neck and unscaled, or None with no head piece. The Carry
    Attachment goes just above it, so a carried thing or a name tag never lands inside the piece (#486)."""
    if slot(name) not in ("Head", "Face"):
        return None
    top = None
    for suffix, (b, at) in build(name, spec, body, d).items():
        if piece_follows(name, suffix) == "Head":
            for v in b.bm.verts:
                top = max(top, v.co.z + at[2]) if top is not None else v.co.z + at[2]
    return top


BOW_TIP = 60.0      # degrees a bow leans out on a cat with a head piece


def bow_corner(spec, body):
    """Where a bow sits on a cat whose crown is taken by a head piece (#486): on the front corner of the head at the
    cat's left, tipped BOW_TIP degrees out over the edge, beside the ear. Relative to the neck and unscaled, with the
    turn the Attachment carries. Every special cat's head piece keeps this corner clear."""
    h = cats.dims(spec, body)["head"]
    return (round(h["s"][0] / 2 - 0.03, 4), round(h["fy"] + 0.13, 4), round(h["top"] - 0.03, 4)), _ry(BOW_TIP)


def slot(name):
    return PROPS[name][0] if name in PROPS else None


def slot2(name):
    return PROPS2[name][0] if name in PROPS2 else None


def piece_slot(name, suffix):
    """The slot of one of a cat's piece objects ("Prop", "Prop_Glass", "Prop2" or an extra piece's suffix)."""
    suffix = PIECES.get(name, {}).get(suffix, suffix)
    return slot2(name) if suffix.startswith("Prop2") else slot(name)


def piece_follows(name, suffix):
    """What one of a cat's piece objects rides: a piece hosted by the Tail rides the Tail, the rest what their
    piece's slot rides."""
    if PIECES.get(name, {}).get(suffix) == "Tail":
        return "Tail"
    return follows(piece_slot(name, suffix))


def follows(slot_):
    """What a piece in this slot rides: Back pieces the Body, Head and Face pieces the Head."""
    return "Body" if slot_ == "Back" else "Head"


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


# Bow tiers (#501; the owner on 2026-11-25: "make better bow upgrades that add money"). A better bow is bought with
# coins and worn by every cat the player washes by hand from then on. Each tier changes shape and size as well as
# trim, like the tool tiers (Review-QA, #142): tier 2 `Double` is wider with a second, cream bow layered behind and above the first, tier 3
# `Royal` is that and wider again, with gold rims, a gold knot with a small lit gem and a crown of three gold points. Each
# comes in the three colours, so the player keeps the colour pick. Same pivot and `BowSlot` as the plain bow.
# Tier 4 `Golden` (the game's tuning has four tiers; asked for by Gameplay-Engineer and Review-QA after PR 559) turns
# the scheme round, so it is not a Royal with more trim: the loops are gold, the knot and a tall fan of five rays
# behind it are the player's colour, and the tails are gold with tips in the colour. The fan nearly doubles its height.
TIERS = ("Double", "Royal", "Golden")
BOW_TIERS = {f"{n}{t}": (sw, t) for n, sw in BOWS.items() for t in TIERS}
BOW_GEM = {"bow_pink": "eye_sky", "bow_mint": "neon_pink", "bow_sky": "neon_pink"}   # deep colours only (#491)
TIER_BUDGET = 520


def _ry_deg(a):
    return Matrix.Rotation(math.radians(a), 3, "Y")


def _tier_bow(b, g, sw, tier, c=(0.0, 0.0, 0.0), k=1.0, face=False):
    """Draw a tier bow with its knot's base at `c`, scaled by `k`. `face` False is the bow as worn: loops up, tails
    lying back over the crown. `face` True is the bow stood on a button's face: the same loops, tails hanging down
    and everything flat to the front. `g` is the builder for the lit gem (None: no gem)."""
    royal = tier == "Royal"
    cx, cy, cz = c
    r = (0.23 if royal else 0.2) * k                       # the big loops: wider than the plain bow's 0.18
    off = (0.27 if royal else 0.235) * k
    lz = cz + (0.13 if royal else 0.115) * k
    for sx in (1, -1):
        tip = _ry_deg(-18 * sx)
        if royal:                                          # a gold rim: the same loop, bigger and thinner, behind it
            b.sphere((cx + sx * off, cy + 0.035 * k, lz), r * 1.13, GOLD, segments=8, rings=4, scale=(1.0, 0.3, 0.74),
                     rot=tip)
        b.sphere((cx + sx * off, cy, lz), r, sw, segments=8, rings=4, scale=(1.0, 0.5, 0.72), rot=tip)
        b.sphere((cx + sx * (off - 0.01 * k), cy + 0.08 * k, lz + 0.085 * k), r * 1.04, "spa_cream", segments=8,
                 rings=4, scale=(1.0, 0.4, 0.74), rot=_ry_deg(-24 * sx))    # a second, cream loop behind and above
    kn = (0.17 * k, 0.15 * k, 0.15 * k)
    b.box_base((cx, cy, cz), kn, GOLD if royal else sw)                                    # the knot
    if not royal:
        b.box((cx, cy - kn[1] / 2 - 0.004 * k, cz + kn[2] / 2), (0.075 * k, 0.03 * k, 0.075 * k), "spa_cream",
              bevel=False, rot=_ry_deg(45))                                                # a cream button on it
    if royal:
        for dx, up, w in ((0.0, 0.05, 0.085), (-0.07, 0.015, 0.065), (0.07, 0.015, 0.065)):   # a crown of three
            b.box((cx + dx * k, cy + (0.01 + abs(dx) * 0.1) * k, cz + kn[2] + up * k), (w * k, 0.05 * k, w * k), GOLD,
                  bevel=False, rot=_ry_deg(45))                                             # points: boxes on edge
        if g is not None:                                                                  # the gem, proud of the knot
            g.box((cx, cy - kn[1] / 2 - 0.012 * k, cz + kn[2] / 2), (0.075 * k, 0.04 * k, 0.075 * k), BOW_GEM[sw],
                  bevel=False, rot=_ry_deg(45))
    ln = (0.34 if royal else 0.3) * k                      # the tails, longer than the plain bow's 0.24
    for sx in (1, -1):
        if face:
            rot = _ry_deg(-34 * sx)
            d = rot @ Vector((0, 0, -1))
            at = Vector((cx + sx * 0.06 * k, cy + (0.02 + 0.006 * sx) * k, cz + 0.04 * k))    # no shared planes
            b.box(tuple(at + d * ln / 2), (0.11 * k, 0.05 * k, ln), sw, bevel=False, rot=rot)
            b.box(tuple(at + d * (ln + 0.03 * k)), (0.12 * k, 0.056 * k, 0.07 * k), GOLD if royal else "spa_cream",
                  bevel=False, rot=rot)
        else:
            rot = Matrix.Rotation(math.radians(22 * sx), 3, "Z")
            d = rot @ Vector((0, 1, 0))
            at = Vector((cx + sx * 0.075 * k, cy + 0.02 * k, cz + (0.03 + 0.005 * sx) * k))   # no shared planes
            b.box(tuple(at + d * ln / 2), (0.1 * k, ln, 0.035 * k), sw, bevel=False, rot=rot)
            b.box(tuple(at + d * (ln + 0.025 * k)), (0.11 * k, 0.06 * k, 0.041 * k), GOLD if royal else "spa_cream",
                  bevel=False, rot=rot)                                                     # a tip in the trim colour


GOLDEN_RAYS = ((0, 0.4), (-27, 0.34), (27, 0.34), (-54, 0.26), (54, 0.26))    # degrees from upright, length


def _golden_bow(b, g, sw, c=(0.0, 0.0, 0.0), k=1.0, face=False, f=None):
    """Draw the Golden bow with its knot's base at `c`, scaled by `k`; `face` and `g` as in `_tier_bow`. The fan is
    drawn on `f` when given: on a cat it is its own object `_Fan`, so the game can leave it off a cat whose head
    piece it would cross (Review-QA on PR 597)."""
    f = f or b
    cx, cy, cz = c
    r, off, lz = 0.24 * k, 0.28 * k, cz + 0.135 * k
    for sx in (1, -1):
        tip = _ry_deg(-18 * sx)
        b.sphere((cx + sx * off, cy, lz), r, GOLD, segments=8, rings=4, scale=(1.0, 0.5, 0.72), rot=tip)
        b.sphere((cx + sx * (off + 0.015 * k), cy - 0.035 * k, lz + 0.01 * k), r * 0.5, "gold_light", segments=8,
                 rings=4, scale=(1.0, 0.5, 0.72), rot=tip)                     # a pale heart in each loop: its shine
    kn = (0.18 * k, (0.22 if face else 0.15) * k, 0.16 * k)
    b.box_base((cx, cy, cz), kn, sw)                                            # the knot, in the player's colour
    for j, (deg, ln) in enumerate(GOLDEN_RAYS):                                 # the fan behind, longest in the middle
        rot = _ry_deg(deg)
        d = rot @ Vector((0, 0, 1))
        at = Vector((cx, cy + (0.07 + 0.012 * j) * k, cz + 0.1 * k)) + d * (0.1 + ln / 2) * k
        f.box(tuple(at), (0.085 * k, (0.045 - 0.003 * j) * k, ln * k), sw, bevel=False, rot=rot)
    if g is not None:                                                           # the gem, proud of the knot
        g.box((cx, cy - kn[1] / 2 - 0.012 * k, cz + kn[2] / 2), (0.085 * k, 0.04 * k, 0.085 * k), BOW_GEM[sw],
              bevel=False, rot=_ry_deg(45))
    ln = 0.36 * k
    for sx in (1, -1):
        if face:
            rot = _ry_deg(-34 * sx)
            d = rot @ Vector((0, 0, -1))
            at = Vector((cx + sx * 0.06 * k, cy + (0.02 + 0.006 * sx) * k, cz + 0.04 * k))
            b.box(tuple(at + d * ln / 2), (0.11 * k, 0.05 * k, ln), GOLD, bevel=False, rot=rot)
            b.box(tuple(at + d * (ln + 0.03 * k)), (0.12 * k, 0.056 * k, 0.07 * k), sw, bevel=False, rot=rot)
        else:
            rot = Matrix.Rotation(math.radians(22 * sx), 3, "Z")
            d = rot @ Vector((0, 1, 0))
            at = Vector((cx + sx * 0.075 * k, cy + 0.02 * k, cz + (0.03 + 0.005 * sx) * k))
            b.box(tuple(at + d * ln / 2), (0.1 * k, ln, 0.035 * k), GOLD, bevel=False, rot=rot)
            b.box(tuple(at + d * (ln + 0.025 * k)), (0.11 * k, 0.06 * k, 0.041 * k), sw, bevel=False, rot=rot)


GEM_TIERS = ("Royal", "Golden")


def build_tier_bow(name, mat):
    sw, tier = BOW_TIERS[name]
    b, g, f = Builder(), Builder(), Builder()
    if tier == "Golden":
        _golden_bow(b, g, sw, f=f)
    else:
        _tier_bow(b, g, sw, tier)
    objs = [b.finalize(name, mat)]
    if tier in GEM_TIERS:
        objs.append(g.finalize(name + "_Gem_Glow", mat))
    if tier == "Golden":                                 # the fan: a child Model the game may leave off (BowFit)
        objs.append(f.finalize(name + "_Fan", mat))
    return objs


def bow_rbx_extras(name):
    return lambda: {"attachments": [(name, "BowSlot", Matrix.Identity(4))]}


BUTTONS = {"CleanACat_Prop_BowButton" + n.rsplit("_", 1)[1]: sw for n, sw in BOWS.items()}
BUTTON_R = 0.55          # the rim's radius: 1.1 across
_FACING = (math.radians(90), "X")           # a disc stood up, its face to the front


TIER_BUTTONS = {"CleanACat_Prop_BowButton" + n[len("CleanACat_Bow_"):]: v for n, v in BOW_TIERS.items()}
TIER_FIT = {"Double": 1.0, "Royal": 0.86, "Golden": 0.74}        # the bow's size on the button, so each fills the face alike
TIER_FACE = {"Double": "pastel_lilac", "Royal": "velvet_lilac", "Golden": "fur_indigo"}   # lilac faces (tier 2 is lilac on the tools too): the
                                                                  # bow's cream layer would vanish on a cream face


def build_tier_bow_button(name, mat):
    """A tier bow's button (#501): the plain button's disc with that tier's bow stood on its face. A Royal button has
    a gold rim and the faces are lilac, pale then deep, so the three tiers' buttons differ at a glance as well."""
    sw, tier = TIER_BUTTONS[name]
    b, g = Builder(), Builder()
    b.cyl((0, 0.03, 0), BUTTON_R, 0.16, GOLD if tier in GEM_TIERS else sw, segments=16, rot=_FACING)   # the rim
    b.cyl((0, -0.06, 0), BUTTON_R - 0.09, 0.06, TIER_FACE[tier], segments=16, rot=_FACING, bevel=False)  # the face
    if tier == "Golden":
        _golden_bow(b, g, sw, c=(0.0, -0.17, -0.1), k=TIER_FIT[tier], face=True)
    else:
        _tier_bow(b, g, sw, tier, c=(0.0, -0.17, -0.04), k=TIER_FIT[tier], face=True)
    objs = [_tris(b.finalize(name, mat))]
    if tier in GEM_TIERS:
        objs.append(g.finalize(name + "_Gem_Glow", mat))
    return objs


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
ASSETS.update({n: (lambda mat, n=n: build_tier_bow(n, mat), TIER_BUDGET) for n in BOW_TIERS})
ASSETS.update({n: (lambda mat, n=n: build_bow_button(n, mat), 450) for n in BUTTONS})
ASSETS.update({n: (lambda mat, n=n: build_tier_bow_button(n, mat), 450 + TIER_BUDGET) for n in TIER_BUTTONS})
EXTRAS = {n: bow_rbx_extras(n) for n in list(BOWS) + list(BOW_TIERS)}
EXTRAS.update({n: bow_button_rbx_extras(n) for n in list(BUTTONS) + list(TIER_BUTTONS)})
