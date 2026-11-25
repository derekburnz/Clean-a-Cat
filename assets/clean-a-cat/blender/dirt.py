"""The dirty cat (issue #12): the mud coat, tangles and the wet coat, on every cat of the roster.

  CleanACat_Cat_<Name>_Dirty       the walking cat (A) as a customer brings it: in a carrier, at the door
  CleanACat_Cat_<Name>_Dirty_Sit   the sitting cat (B) as it sits in the tub or the stray box

A dirty model is the clean cat (same pieces, same pivots, same names after the asset name) plus:

  _Mud01 .. _Mud20      one piece of the mud coat each (one to four boxes: a wrap round an edge or a corner of one
                        of the cat's blocks and the drips running from it, plus one thin box of ragged edge,
                        #155), its own child Model pivoted at its
                        middle. The scrub removes a piece by its name (find the child Model whose name ends in
                        _MudNN and Destroy it). Pieces on the head, the tail or a leg are nested in that piece's
                        Model, so they move with it; the rest sit on the Body.
  _Tangle01 .. _Tangle06  a spiky fur clump each, removed by the brush the same way.
  _Fluff01 .. _Fluff10  the fluffed look (#14): coat-coloured puffs on the cheeks, crown, chest, flanks, back and
                        tail, each its own child Model (riding Head or Tail like the mud). They ship see-through
                        (Transparency 1, CanQuery off, no shadow): after the third brush swipe the game tweens every
                        part under a _FluffNN Model to Transparency 0 (and turns CastShadow on), with a small
                        ScaleTo pop if it likes. They stay through the bow and the walk out.
  root attributes       Dirty = true, MudCount = 20, TangleCount = 6, FluffCount = 10, WetDarken = 0.3. The wet coat is a colour shift,
                        not extra parts: while the cat is wet, the game darkens every coat part by WetDarken (multiply
                        its Color by 1 - WetDarken) and the dryer tweens it back. No extra parts, no z-fighting.

  dirt levels           one model serves four levels of dirt: every _MudNN and _TangleNN Model carries the attribute
                        DirtLevel (1 to 4), the lowest level at which it shows, and the root says how many pieces
                        each level has (DirtLevels, MudAtLevel1 .. 4, TanglesAtLevel1 .. 4). See MUD_LEVEL below.

When the last blob and tangle are gone the model is the clean cat (plus the hidden fluff), so nothing is swapped at
the reveal.

The mud is a coat, not stains stuck on (Derek 2026-11-23: "built into their fur or like coated in it"): every
piece is a slice of one of the cat's own blocks, a hair bigger than the block, so it wraps the block's edges and
corners and lies flush like the coat's own stripes and patches. The pieces are listed once per body (COAT) in
fractions of each block, so every coat and both bodies wear the same coat on their own shapes; the eyes and the
drawing of the face stay clear. Tangles and fluff are placed by casting rays at the built cat (no randomness).
"""

import math

import bpy
from mathutils import Matrix, Vector

import cats
import palette
from common import PRIMS, Builder

MUD = 20
TANGLES = 6
WET_DARKEN = 0.3
EYE_CLEAR = 0.3           # studs: nothing is placed this close to an eye's centre (mud keeps three quarters of it)
TANGLE_SPACING = 0.3
FLUFF = 10
FLUFF_SPACING = 0.25
# The mud coat. Mud is part of the cat's look, not something stuck on it: every piece is a slice of one of the
# cat's own blocks (the head, the chest, a leg, a paw, the tail), a hair bigger than the block, so it wraps the
# block's edges and corners and lies flush like the coat's own stripes and patches. The cat reads as coated: socks of
# mud up the legs, a caked rump and flanks, a cap over the brow, the tail tip dipped. A piece is one to four boxes
# (a wrap and the drips running from it), all on a grid of mud pixels so they meet without overlapping. PIX is one
# mud pixel in studs before the cat's scale, about an eye's highlight.
PIX = 0.09
# A piece stands MUD_PROUD off the fur, just past the z-fight gap. Where it lies over the coat's own relief (a
# stripe, a patch, a fringe: up to RELIEF_MAX proud of the block) it stands that much off the highest thing under
# each of its faces instead, so nothing of the coat pokes through.
MUD_PROUD = 0.02
RELIEF_MAX = 0.11
FACE_BARE = 0.012                  # on the front of the head mud lies on bare fur only: the face keeps its drawing
# A special cat's brow is painted (cats.py `face` and `mark`). There the mud lies over the paint like over any other
# coat relief, from this far above the eyes' middles (before the cat's scale): a filthy special cat hides its marks
# and the wash brings them back. Set by build_dirty for the cat being built; the roster's faces are as they were.
BROW_PAINT = [False]
BROW_FROM = 0.15
# The scrub counts a rub within the sponge's radius (0.9 studs) of the piece's middle, with the cat at 1.5 times at
# a station, so no part of a piece is further than this from its middle (before the station's scale).
SCRUB_REACH = 0.6
# In the wash tub the water stands this high on a sitting cat (stations: the water over the seat, at the cat's 1.5
# times). Every piece of the sitting coat shows at least WATER_CLEAR above it, so none is washed out of sight.
TUB_WATER = 0.18
WATER_CLEAR = 0.1
RIDES = ("Head", "Tail", "LegF1", "LegF2", "LegB1", "LegB2")   # pieces whose Model carries the blobs on them
ALLOWED = ("Body",) + RIDES

# Ray directions, in the cat's own frame (front is -Y, the cat's left is +X, up is +Z), aimed at a target piece's
# centre, for the tangles and the fluff.
# Tangles: on the back, the tail and the cheeks, where a brush stroke goes.
_T = [
    ("Body", (0.0, 0.4, 1.0)), ("Tail", (0.0, 0.5, 1.0)), ("Head", (1.0, -0.2, 0.0)), ("Head", (-1.0, -0.2, 0.0)),
    ("Body", (0.8, 0.3, 0.7)), ("Body", (-0.8, 0.3, 0.7)), ("Body", (0.0, -0.4, 1.0)), ("Body", (0.6, 0.8, 0.5)),
]


# Fluff puffs: (target piece, ray direction, radius before the cat's scale). Cheek ruffs and a crown tuft on the
# head, a chest ruff, the flanks and the back, the tail. Ten land on every cat on both bodies.
_F = [
    ("Head", (1.0, -0.3, -0.35), 0.17), ("Head", (-1.0, -0.3, -0.35), 0.17), ("Head", (0.0, 0.7, 1.0), 0.15),
    ("Body", (0.0, -1.0, 0.1), 0.2), ("Body", (1.0, 0.25, 0.2), 0.18), ("Body", (-1.0, 0.25, 0.2), 0.18),
    ("Body", (0.0, 0.6, 1.0), 0.18), ("Tail", (0.0, 0.3, 1.0), 0.16), ("Body", (0.7, 0.8, 0.3), 0.16),
    ("Body", (-0.7, 0.8, 0.3), 0.16), ("Body", (0.0, 1.0, 0.0), 0.16), ("Tail", (1.0, 0.0, 0.2), 0.14),
    ("Body", (0.8, -0.7, 0.1), 0.15), ("Body", (-0.8, -0.7, 0.1), 0.15),
]


def _piece(ob, base):
    return ob.name[len(base) + 1:]


def _centre(ob):
    return sum((ob.matrix_world @ Vector(c) for c in ob.bound_box), Vector()) / 8


def _ray(objs, base, origin, direction):
    """Nearest hit on the cat from origin along direction: (point, normal, piece) in asset space, or None."""
    dg = bpy.context.evaluated_depsgraph_get()
    best = None
    for ob in objs:
        inv = ob.matrix_world.inverted()
        o_l = inv @ origin
        d_l = (inv.to_3x3() @ direction).normalized()
        ok, loc, nrm, _ = ob.ray_cast(o_l, d_l, distance=20.0, depsgraph=dg)
        if not ok:
            continue
        loc_w = ob.matrix_world @ loc
        dist = (loc_w - origin).length
        if best is None or dist < best[0]:
            nrm_w = (ob.matrix_world.to_3x3().inverted().transposed() @ nrm).normalized()
            best = (dist, loc_w, nrm_w, _piece(ob, base))
    return None if best is None else best[1:]


def _swatch_at(ob, point):
    """The palette swatch of the face of `ob` nearest `point` (asset space), from its UV (faces sit on swatch
    centres), so a puff on a white chest is white and one on a ginger patch is ginger."""
    ok, _loc, _n, face = ob.closest_point_on_mesh(ob.matrix_world.inverted() @ point)
    if not ok:
        return None
    me = ob.data
    loop = me.polygons[face].loop_indices[0]
    u, v = me.uv_layers.active.data[loop].uv
    best = min(range(len(palette.SWATCHES)), key=lambda i: (palette.uv_center(i)[0] - u) ** 2 + (palette.uv_center(i)[1] - v) ** 2)
    return palette.SWATCHES[best][0]


def _lum(hex_):
    c = [int(hex_[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    c = [x / 12.92 if x <= 0.03928 else ((x + 0.055) / 1.055) ** 2.4 for x in c]
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]


def _contrast(a, b):
    la, lb = sorted((_lum(a), _lum(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)


PALE = 0.5                # fur brighter than this (white, cream, pale grey, lilac, gold) gets the drab mud
DARK_FUR_MUD = ("mud_dust_wet", "mud_drab")   # the mud on fur too dark for the brown, and its every third piece (#326)


def _mud_for(fur, wet=False):
    """#22: brown mud on light fur, dusty dried mud on dark fur (Inky, Tux, the black and grey patches), whichever
    stands out more from the fur under the blob, so the scrub's reveal reads on every coat. #155: on pale fur the
    brown read as a brown patched coat (a dirty Cotton looked like Patches), so pale fur gets a duller, greyer mud
    that no coat uses. #326: on dark fur the pale dust read as tan patches of a calico coat at phone size, so dark
    fur gets the darker wet dust, and its every third piece the drab: dirt on a black cat, not a second coat."""
    pairs = (("mud", "mud_wet"), ("mud_dust", "mud_dust_wet"))
    if fur is None:
        return pairs[0][wet]
    hexes = dict(palette.SWATCHES)
    best = max(pairs, key=lambda pr: _contrast(hexes[pr[0]], hexes[fur]))
    if best[0] == "mud" and _lum(hexes[fur]) > PALE:
        best = ("mud_drab", "mud_drab_wet")
    elif best[0] == "mud_dust":
        best = DARK_FUR_MUD
    return best[1] if wet else best[0]


def _snap(n):
    """The axis direction nearest a normal."""
    i = max(range(3), key=lambda a: abs(n[a]))
    v = Vector((0.0, 0.0, 0.0))
    v[i] = 1.0 if n[i] > 0 else -1.0
    return v


def _align(normal):
    """3x3 turning local +Z onto normal (local X kept as level as it can be)."""
    z = normal.normalized()
    x = Vector((0, 0, 1)).cross(z)
    if x.length < 1e-4:
        x = Vector((1, 0, 0))
    x.normalize()
    y = z.cross(x)
    return Matrix((x, y, z)).transposed()


def _spots(objs, base, rays, n, spacing, eyes, keep_index=False):
    pieces = {_piece(o, base): o for o in objs}
    out = []
    for j, (target, d) in enumerate(rays):
        if len(out) == n:
            break
        if target not in pieces:
            continue                                   # a sitting cat has no back legs
        c = _centre(pieces[target])
        d = Vector(d).normalized()
        hit = _ray(objs, base, c + d * 4.0, -d)
        if hit is None:
            continue
        p, nrm, piece = hit
        nrm = _snap(nrm)                               # the cats are blocks: lie flat on the face, not across a bevel
        if piece not in ALLOWED:
            continue                                   # an eye, an ear or the nose: keep the face readable
        if any((p - e).length < EYE_CLEAR for e in eyes):
            continue
        if any((o[0] - p).length < spacing for o in out):
            continue
        out.append((p, nrm, piece, j) if keep_index else (p, nrm, piece))
    return out


# The coat's pieces, one list per body. A piece: (the cat piece it rides, its boxes). A box: (which block of that
# piece, x0, x1, y0, y1, z0, z1) in fractions of the block along its own axes: x from the cat's right to its left,
# y from the front to the back (along a tail segment, root to tip), z from the bottom to the top. A box that
# reaches a face of the block (0 or 1) comes out of that face; its other sides are cut inside the block. A box may
# run past the block (below 0 or over 1): a drip hanging off the jaw or the belly, past the cat's outline, which
# is what tells mud from a coat's own pattern. Fractions snap to the block's mud pixels. The first box is the wrap and must fit; a later box (a drip) that would touch the
# face's drawing or come too near an eye is left out on that cat.
HEAD_COAT = [
    ("Head", [(0, 0.0, 0.1, 0.125, 1.0, 0.0, 0.5), (0, 0.0, 0.1, 0.375, 0.75, 0.5, 0.625),       # the right cheek
              (0, 0.1, 0.4, 0.875, 1.0, 0.0, 0.375), (0, 0.0, 0.1, 0.125, 0.25, -0.25, 0.0)]),   # a drip off the jaw
    ("Head", [(0, 0.9, 1.0, 0.25, 0.875, 0.5, 0.875), (0, 0.9, 1.0, 0.5, 0.75, 0.25, 0.5),      # the left temple,
              (0, 0.9, 1.0, 0.375, 0.625, 0.875, 1.0), (0, 0.9, 1.0, 0.125, 0.375, 0.0, 0.25)]),
    ("Head", [(0, 0.5, 0.8, 0.0, 0.25, 0.875, 1.0), (0, 0.6, 0.7, 0.0, 0.125, 0.75, 0.875),    # a splat on the brow,
              (0, 0.4, 0.6, 0.0, 0.125, 0.75, 0.875)]),                                         # smeared down the forehead
    ("Head", [(0, 0.4, 0.6, 0.5, 1.0, 0.875, 1.0), (0, 0.4, 0.6, 0.875, 1.0, 0.5, 0.875),       # the crown, running
              (0, 0.3, 0.4, 0.875, 1.0, 0.625, 0.875)]),                                        # down the back
    ("Head", [(0, 0.6, 1.0, 0.875, 1.0, 0.0, 0.375), (0, 0.7, 0.9, 0.875, 1.0, 0.375, 0.625)]),  # the back, low left
    ("Head", [(0, 0.0, 0.2, 0.0, 0.25, 0.75, 1.0), (0, 0.0, 0.1, 0.25, 0.375, 0.625, 1.0)]),    # the right brow corner
]
COAT = {
    "sit": HEAD_COAT + [
        ("Body", [(1, 0.375, 0.625, 0.0, 0.17, 0.375, 0.625), (1, 0.5, 0.625, 0.0, 0.17, 0.125, 0.375),   # the bib
                  (1, 0.375, 0.5, 0.0, 0.17, 0.625, 0.75)]),
        ("Body", [(1, 0.875, 1.0, 0.0, 0.83, 0.3, 0.7), (1, 0.875, 1.0, 0.17, 0.5, 0.1, 0.3)]),      # left shoulder
        ("Body", [(1, 0.125, 0.75, 0.83, 1.0, 0.375, 0.75), (1, 0.25, 0.5, 0.83, 1.0, 0.125, 0.375),   # the back
                  (1, 0.75, 1.0, 0.83, 1.0, 0.5, 0.9)]),
        ("Body", [(1, 0.0, 0.125, 0.0, 0.5, 0.15, 0.55), (1, 0.0, 0.125, 0.5, 0.83, 0.3, 0.45)]),    # right side
        ("Body", [(1, 0.0, 0.125, 0.5, 1.0, 0.6, 0.9)]),                                             # right shoulder
        ("Body", [(0, 0.78, 1.0, 0.3, 1.0, 0.0, 0.8), (0, 0.89, 1.0, 0.45, 0.75, 0.8, 1.0)]),        # left haunch
        ("Body", [(0, 0.2, 0.7, 0.7, 1.0, 0.6, 1.0), (0, 0.3, 0.45, 0.86, 1.0, 0.2, 0.6)]),          # the rump
        ("Body", [(0, 0.0, 0.11, 0.15, 0.7, 0.2, 0.8), (0, 0.0, 0.22, 0.7, 1.0, 0.0, 0.4)]),         # right haunch
        ("Body", [("pawL", 0, 1, 0, 1, 0, 1), (0, 0.78, 1.0, 0.0, 0.3, 0.0, 0.8)]),                  # left back paw
        ("Body", [("pawR", 0, 1, 0, 1, 0, 1), (0, 0.0, 0.22, 0.0, 0.15, 0.0, 0.8)]),                 # right back paw
        ("LegF1", [("paw", 0, 1, 0, 1, 0, 1), (0, 0, 1, 0, 1, 0.0, 0.5), (0, 0.5, 1.0, 0.0, 0.5, 0.5, 0.67)]),
        ("LegF2", [("paw", 0, 1, 0, 1, 0, 1), (0, 0, 1, 0, 1, 0.0, 0.33), (0, 0.0, 0.5, 0.0, 0.5, 0.33, 0.5)]),
        ("LegF1", [(0, 0.0, 0.5, 0.0, 1.0, 0.75, 0.92)]),
        ("LegF2", [(0, 0.5, 1.0, 0.0, 1.0, 0.6, 0.8)]),
    ],
    "walk": HEAD_COAT + [
        ("Body", [(0, 0.3, 0.7, 0.0, 0.1, 0.0, 0.6), (0, 0.4, 0.5, 0.0, 0.1, -0.33, 0.0)]),          # the chest, dripping
        ("Body", [(0, 0.55, 1.0, 0.3, 0.7, 0.6, 1.0), (0, 0.89, 1.0, 0.36, 0.55, 0.3, 0.6)]),        # saddle, left
        ("Body", [(0, 0.1, 0.6, 0.8, 1.0, 0.5, 1.0), (0, 0.2, 0.35, 0.9, 1.0, 0.15, 0.5)]),          # the rump
        ("Body", [(0, 0.0, 0.11, 0.2, 0.75, 0.15, 0.7), (0, 0.0, 0.3, 0.1, 0.3, 0.83, 1.0)]),        # right flank
        ("Body", [(0, 0.6, 1.0, 0.45, 0.9, 0.0, 0.33), (0, 0.89, 1.0, 0.55, 0.65, -0.33, 0.0)]),     # belly, left
        ("Body", [(0, 0.1, 0.45, 0.35, 0.6, 0.83, 1.0)]),                                            # the shoulders
        ("Body", [(0, 0.89, 1.0, 0.05, 0.3, 0.2, 0.7)]),                                             # left flank
        ("Body", [(0, 0.0, 0.4, 0.6, 0.95, 0.0, 0.17), (0, 0.0, 0.11, 0.7, 0.8, -0.33, 0.0)]),       # belly, right
        ("LegF1", [("paw", 0, 1, 0, 1, 0, 1), (0, 0, 1, 0, 1, 0.0, 0.5), (0, 0.67, 1.0, 0.0, 0.67, 0.5, 0.75)]),
        ("LegF2", [("paw", 0, 1, 0, 1, 0, 1), (0, 0, 1, 0, 1, 0.0, 0.25), (0, 0.0, 0.33, 0.0, 0.67, 0.25, 0.5)]),
        ("LegB1", [("paw", 0, 1, 0, 1, 0, 1), (0, 0, 1, 0, 1, 0.0, 0.25), (0, 0.67, 1.0, 0.33, 1.0, 0.25, 0.5)]),
        ("LegB2", [("paw", 0, 1, 0, 1, 0, 1), (0, 0, 1, 0, 1, 0.0, 0.5), (0, 0.0, 0.33, 0.33, 1.0, 0.5, 0.75)]),
        ("Tail", [(-1, 0, 1, 0.4, 1.0, 0, 1)]),                                                      # the tip, dipped
        ("Tail", [(0, 0, 1, 0.2, 0.7, 0.5, 1.0)]),
    ],
}


# Dirt levels (the owner 2026-11-25: "the cats look dirtier in their pictures the more dirty they are and take more
# steps to clean"). One dirty model serves every level: each mud piece and tangle has the lowest level at which it
# shows, in the order of COAT and of the tangles, and its child Model carries that number as the attribute
# `DirtLevel`. A cat at level L keeps the pieces with DirtLevel <= L; the game destroys the rest when the cat
# arrives. The levels are chosen for the card picture (head and shoulders, down to 64 px), where each adds mud in a
# place of its own, so the four pictures differ in shape and not only in amount (#478: a level that only thickened
# the one below could not be told from it on a small card). As the picture shows them: 1 is muddy paws and one
# smudge on the top left corner of the brow, 2 adds the lower left (a cheek with its drip) and the bib, 3 the top
# of the head (a splat on the brow, the crown, the back), 4 the whole right side (the temple and the shoulder under
# it), the back and every tangle. What a level means in steps or pay is the game's.
LEVELS = 4
LEVEL_NAMES = ("a little muddy", "muddy", "very muddy", "filthy")
MUD_LEVEL = {
    #       cheek temple brow crown back corner | the body's fourteen, in COAT's order
    "sit":  [2, 4, 3, 3, 3, 1,   2, 4, 4, 3, 4, 3, 4, 4, 1, 1, 1, 1, 2, 3],
    "walk": [2, 4, 3, 3, 3, 1,   2, 4, 4, 3, 3, 4, 3, 4, 1, 1, 1, 1, 2, 4],
}
TANGLE_LEVEL = [2, 2, 3, 3, 4, 4]
assert all(len(v) == MUD for v in MUD_LEVEL.values()) and len(TANGLE_LEVEL) == TANGLES
MODEL_ATTRS = {}          # asset name -> {child Model suffix: {"DirtLevel": n}}, filled by build_dirty for build_all


def level_of(name, body):
    """The dirt level of a mud piece or a tangle by its object name; None for any other object."""
    tail = name.rsplit("_", 1)[-1]
    if tail.startswith("Mud") and tail[3:].isdigit():
        return MUD_LEVEL[body][int(tail[3:]) - 1]
    if tail.startswith("Tangle") and tail[6:].isdigit():
        return TANGLE_LEVEL[int(tail[6:]) - 1]
    return None


def at_level(objs, level, body):
    """The objects of a dirty cat as it looks at a dirt level: the cat, and the mud and tangles of that level."""
    return [o for o in objs if (level_of(o.name, body) or 0) <= level]


def _boxes(ob):
    """The piece's boxes in asset space, in the order they were built: (centre, 3x3 of unit axes, size)."""
    out = []
    for kind, m, _sw, _extra in PRIMS[ob.data.name]:
        if kind == "box":
            M = ob.matrix_world @ m
            cols = [M.col[i].to_3d() for i in range(3)]
            out.append((M.translation.copy(), Matrix([c.normalized() for c in cols]).transposed(),
                        Vector([c.length for c in cols])))
    return out


def _block(ob, which, k):
    """One block of a piece: its number in build order (-1 the last: the tail's tip), a leg's "paw", or the sitting
    body's back paws "pawL" (the cat's left, +X) and "pawR"."""
    boxes = _boxes(ob)
    if isinstance(which, int):
        return boxes[which]
    paws = [b for b in boxes[1:] if abs(b[2].z - 0.11 * k) < 0.004 * k and b[2].x > 0.2 * k]
    if which == "paw":
        return paws[0]
    return (max if which == "pawL" else min)(paws, key=lambda b: b[0].x)


def _cells(block, frac, k):
    """The box's span in the block's mud pixels: ((first, end) on each axis, the pixel counts)."""
    n = [max(1, round(block[2][a] / (PIX * k))) for a in range(3)]
    span = []
    for a in range(3):
        i0, i1 = round(frac[2 * a] * n[a]), round(frac[2 * a + 1] * n[a])
        if i1 <= i0:
            i1 = min(n[a], i0 + 1) if i0 >= 0 else i0 + 1
            i0 = i1 - 1
        span.append((i0, i1))
    return span, n


BOXES = [0]                        # counts the mud boxes of the cat being built, see STAGGER
STAGGER = 0.0013                   # studs: each mud box stands this much prouder than the one before, twelve steps
# round. Two boxes on one edge (a leg's and its paw's, a piece's and its drip's) would otherwise end in one plane,
# and two faces in one plane flicker (#160, the blender-asset-qa check). Far too small to see.
FLOOR_INSET = 0.02                 # an underside that would reach the floor stops this far up inside the block
CUT_SHIFT = 0.0017                 # studs: the sides of a mud box cut inside the block lie this far off the mud
# pixel grid, all the same way, so boxes still meet edge to edge. The coat's own patches end on that grid, and a
# mud side ending in the plane of a stripe's end flickers (#160).
DRIP_TUCK = 0.002                  # a drip hanging under a block: slimmer by this on its cut sides, and this far up
# into the block, so it shares no plane with the box it hangs from


def _shell(ob, block, span, n, k, eyes, head):
    """The mud box for a span of a block: (centre, axes, size, its outer sides) in asset space, or None when it would lie on the
    face's drawing or too near an eye. Each side that reaches the block's surface comes out of it by MUD_PROUD over
    the highest thing of the coat under it; an underside stops at the floor."""
    c, R, size = block
    inv = ob.matrix_world.inverted()
    dg = bpy.context.evaluated_depsgraph_get()
    lo = [-size[a] / 2 + size[a] * span[a][0] / n[a] for a in range(3)]
    hi = [-size[a] / 2 + size[a] * span[a][1] / n[a] for a in range(3)]
    under = span[2][0] < 0                             # a drip hanging under the block
    out_lo = [lo[a] - CUT_SHIFT + (DRIP_TUCK if under and a != 2 else 0.0) for a in range(3)]
    out_hi = [hi[a] - CUT_SHIFT - (DRIP_TUCK if under and a != 2 else 0.0) for a in range(3)]
    if under:
        out_hi[2] = hi[2] + DRIP_TUCK
    out = set()                                        # the sides that come out of the block: (axis, sign)
    for a in range(3):
        u, v = [i for i in range(3) if i != a]
        for sign, edge, reaches in ((-1, lo, span[a][0] == 0 < span[a][1]), (1, hi, span[a][0] < n[a] == span[a][1])):
            if not reaches:
                continue
            nrm = R.col[a] * sign
            down = (c + R @ Vector([edge[i] if i == a else 0.0 for i in range(3)])).z if nrm.z < -0.9 else None
            relief = 0.0
            for fu in (0.02, 0.15, 0.3, 0.5, 0.7, 0.85, 0.98):
                for fv in (0.02, 0.15, 0.3, 0.5, 0.7, 0.85, 0.98):
                    q = [0.0, 0.0, 0.0]
                    q[a], q[u], q[v] = edge[a], lo[u] + (hi[u] - lo[u]) * fu, lo[v] + (hi[v] - lo[v]) * fv
                    p = c + R @ Vector(q)
                    if head and any((p - e).length < EYE_CLEAR * 0.75 for e in eyes):
                        return None
                    ok, loc, _n, _f = ob.ray_cast(inv @ (p + nrm * 0.6 * k), (inv.to_3x3() @ -nrm).normalized(),
                                                  distance=2.0, depsgraph=dg)
                    if ok:
                        z = (ob.matrix_world @ loc - p).dot(nrm)
                        brow = BROW_PAINT[0] and eyes and p.z > max(e.z for e in eyes) + BROW_FROM * k
                        if head and nrm.y < -0.5 and z > FACE_BARE * k and not brow:
                            return None
                        if z <= RELIEF_MAX * k:
                            relief = max(relief, z)
            step = STAGGER * (BOXES[0] % 12)
            grow = relief + MUD_PROUD * k + step
            if down is not None and grow > down - 0.004:
                # An underside never goes below the floor the cat stands on. It stops inside the block, where
                # nothing sees it and it shares a plane with no other underside. Not an outer side: its edges
                # stay square.
                grow = -(FLOOR_INSET + step)
            else:
                out.add((a, sign))
            if sign < 0:
                out_lo[a] = lo[a] - grow
            else:
                out_hi[a] = hi[a] + grow
    BOXES[0] += 1
    mid = Vector([(out_lo[a] + out_hi[a]) / 2 for a in range(3)])
    return c + R @ mid, R, Vector([out_hi[a] - out_lo[a] for a in range(3)]), out


# The ragged edge (#155). A coat's own patches are clean blocks, so clean blocks of mud read as a coat. Every piece
# gets FRINGE_MAX more box, one mud pixel wide and in the piece's own shade: the longest drip running down from its
# lower edge on a side of the cat, or the longest tooth out of it on a top. It lies flush like the piece itself.
# One and not more (Review-QA, #155): the edge reads from about twice phone size, and every box is a part on a
# phone.
FRINGE_MAX = 1
DRIPS = (2, 0, 3, 1, 0, 2, 1, 0)   # lengths in mud pixels, column after column along an edge
TEETH = (1, 0, 2, 0, 1, 1, 0, 2)


def _fringe(i, got):
    """Candidate ragged-edge boxes for piece i, longest first: (block key, block, span, n)."""
    cands = []
    for key, block, span, n, shell in got:
        if block[1].col[2].z < 0.95:
            continue                                   # a tail segment lying over: down is not along the block
        for a, sign in sorted(shell[3]):
            if a == 2 and sign > 0:                    # a top: teeth out of each edge of the box
                top = n[2] - 1
                for u, v in ((0, 1), (1, 0)):
                    for s in (-1, 1):
                        for t, w in enumerate(range(*span[v])):
                            ln = TEETH[(i * 3 + t + (2 * u + (s > 0)) * 3) % len(TEETH)]
                            lo, hi = (span[u][0] - ln, span[u][0]) if s < 0 else (span[u][1], span[u][1] + ln)
                            lo, hi = max(lo, 0), min(hi, n[u])
                            if hi > lo:
                                sp = [None, None, (top, top + 1)]
                                sp[u], sp[v] = (lo, hi), (w, w + 1)
                                cands.append((hi - lo, len(cands), key, block, sp, n))
            elif a != 2:                               # a side: drips down from the lower edge
                ca, u, z0 = (n[a] - 1 if sign > 0 else 0), 1 - a, span[2][0]
                for t, w in enumerate(range(*span[u])):
                    ln = min(DRIPS[(i * 3 + t + a) % len(DRIPS)], z0)
                    if ln > 0:
                        sp = [None, None, (z0 - ln, z0)]
                        sp[a], sp[u] = (ca, ca + 1), (w, w + 1)
                        cands.append((ln, len(cands), key, block, sp, n))
    return [c[2:] for c in sorted(cands, key=lambda c: (-c[0], c[1]))]


def _seen(objs, base, piece, shell, k):
    """True when the box's outer faces can be seen: nothing else of the cat stands in front of them."""
    c, R, s, sides = shell
    for a, sign in sides:
        nrm = R.col[a] * sign
        p = c + nrm * s[a] / 2
        hit = _ray(objs, base, p + nrm * 3.0, -nrm)
        if hit is None or hit[2] != piece or (hit[0] - p).dot(nrm) > (RELIEF_MAX + MUD_PROUD) * k + 0.01:
            return False
    return True


def _reach(shells):
    corners = [c + R @ Vector((sx * s.x, sy * s.y, sz * s.z)) / 2 for c, R, s, _o in shells
               for sx in (1, -1) for sy in (1, -1) for sz in (1, -1)]
    lo = Vector([min(p[a] for p in corners) for a in range(3)])
    hi = Vector([max(p[a] for p in corners) for a in range(3)])
    return lo, hi


# Settling (#160). The blender-asset-qa check fails a model when two faces that look the same way lie within a
# millimetre of one plane and overlap, because they flicker. The stagger and the cut shift keep most mud faces
# clear, but a cat has hundreds of faces and a mud side still lands on one now and then: a stripe's end, another
# piece's box where the head overhangs the body. So every side of every mud box is tested against the cat's own
# faces and the mud boxes before it, the way the check tests them, and a side that lands in a taken plane moves
# out by SETTLE_STEP until it is clear.
SETTLE_EPS = 0.0012                # studs: a hair over the check's own millimetre
SETTLE_STEP = 0.0016
# where the check samples a face, as fractions of the rectangle: both ways it can be cut into two triangles
_SAMPLES = [(u, v) for a, b in ((2 / 3, 1 / 3), (0.267, 0.133), (0.867, 0.133), (0.867, 0.733))
            for u, v in ((a, b), (b, a), (1 - a, b), (1 - b, a))]


def _facing(objs):
    """The cat's faces that look along an axis: {(axis, sign): [(plane, the points the check samples, corners)]}."""
    out = {(a, sg): [] for a in range(3) for sg in (-1, 1)}
    for ob in objs:
        M, N = ob.matrix_world, ob.matrix_world.to_3x3()
        me = ob.data
        me.calc_loop_triangles()
        for t in me.loop_triangles:
            nrm = (N @ t.normal).normalized()
            for a in range(3):
                if abs(nrm[a]) > 0.999:
                    v = [M @ me.vertices[j].co for j in t.vertices]
                    cen = (v[0] + v[1] + v[2]) / 3
                    out[(a, 1 if nrm[a] > 0 else -1)].append((cen[a], [cen] + [cen.lerp(q, 0.6) for q in v], v))
    return out


def _in_tri(p, tri, u, v):
    d = [(tri[j][u] - tri[j - 1][u]) * (p[1] - tri[j - 1][v]) - (tri[j][v] - tri[j - 1][v]) * (p[0] - tri[j - 1][u])
         for j in range(3)]
    return all(x >= -1e-9 for x in d) or all(x <= 1e-9 for x in d)


def _settle(objs, pieces):
    """The pieces' boxes with every side clear of the cat's faces and of each other: same shape as `pieces`."""
    faces = _facing(objs)
    flat = [(pi, bi) for pi, boxes in enumerate(pieces) for bi in range(len(boxes))]
    square = {}                                        # only boxes that stand square to the asset are settled:
    for pi, bi in flat:                                # a tail segment's lie in no plane of anything else
        c, R, s, _sides = pieces[pi][bi]
        if all(abs(R[r][q] - (1.0 if r == q else 0.0)) < 1e-6 for r in range(3) for q in range(3)):
            square[(pi, bi)] = [list(c - s / 2), list(c + s / 2)]
    order = [key for key in flat if key in square]
    for _round in range(40):
        moved = False
        for at, key in enumerate(order):
            lo, hi = square[key]
            for a in range(3):
                u, v = [q for q in range(3) if q != a]
                for sign in (-1, 1):
                    plane = hi[a] if sign > 0 else lo[a]
                    pts = [(lo[u] + (hi[u] - lo[u]) * fu, lo[v] + (hi[v] - lo[v]) * fv) for fu, fv in _SAMPLES]
                    hit = any(abs(pl - plane) < SETTLE_EPS
                              and (any(lo[u] < q[u] < hi[u] and lo[v] < q[v] < hi[v] for q in own)
                                   or any(_in_tri(q, tri, u, v) for q in pts))
                              for pl, own, tri in faces[(a, sign)])
                    for other in order[:at]:
                        if hit:
                            break
                        lo2, hi2 = square[other]
                        hit = (abs((hi2[a] if sign > 0 else lo2[a]) - plane) < SETTLE_EPS
                               and min(hi[u], hi2[u]) - max(lo[u], lo2[u]) > 1e-4
                               and min(hi[v], hi2[v]) - max(lo[v], lo2[v]) > 1e-4)
                    if hit:
                        moved = True
                        if sign > 0:
                            hi[a] += SETTLE_STEP
                        else:
                            lo[a] -= SETTLE_STEP
        if not moved:
            break
    out = []
    for pi, boxes in enumerate(pieces):
        row = []
        for bi, (c, R, s, sides) in enumerate(boxes):
            if (pi, bi) in square:
                lo, hi = (Vector(q) for q in square[(pi, bi)])
                c, s = (lo + hi) / 2, hi - lo
            row.append((c, R, s, sides))
        out.append(row)
    return out


def _coat(objs, base, body, k, eyes, mat):
    """The MUD pieces of the coat for a built cat: [(object, the cat piece it rides)]."""
    pieces = {_piece(o, base): o for o in objs}
    BOXES[0] = 0
    taken = {}                                         # (piece, block): the mud pixels already used
    placed = []
    for i, (piece, boxes) in enumerate(COAT[body]):    # first every piece's own boxes, so a ragged edge never
        ob = pieces[piece]                             # takes the pixels a later piece is listed with
        got = []
        for j, (which, *frac) in enumerate(boxes):
            block = _block(ob, which, k)
            span, n = _cells(block, frac, k)
            cells = {(x, y, z) for x in range(*span[0]) for y in range(*span[1]) for z in range(*span[2])}
            key = (piece, which if which != -1 else len(_boxes(ob)) - 1)
            used = taken.setdefault(key, set())
            shell = None if cells & used else _shell(ob, block, span, n, k, eyes, piece == "Head")
            if shell is None:
                if j == 0:
                    raise RuntimeError(f"{base}: mud piece {i + 1} does not fit (its first box)")
                continue
            used |= cells
            got.append((key, block, span, n, shell))
        placed.append((ob, piece, got))
    out, ready = [], []
    for i, (ob, piece, got) in enumerate(placed):
        shells = [g[4] for g in got]
        fringe = []
        for key, block, span, n in _fringe(i, got):
            if len(fringe) == FRINGE_MAX:
                break
            cells = {(x, y, z) for x in range(*span[0]) for y in range(*span[1]) for z in range(*span[2])}
            if cells & taken[key]:
                continue
            shell = _shell(ob, block, span, n, k, eyes, piece == "Head")
            if shell is None or not _seen(objs, base, piece, shell, k):
                continue
            lo, hi = _reach(shells + fringe + [shell])
            if (hi - lo).length / 2 > SCRUB_REACH:
                continue
            taken[key] |= cells
            fringe.append(shell)
        lo, hi = _reach(shells + fringe)
        if (hi - lo).length / 2 > SCRUB_REACH:
            raise RuntimeError(f"{base}: mud piece {i + 1} is too big to scrub ({(hi - lo).length / 2:.2f})")
        if body == "sit" and hi.z < TUB_WATER + WATER_CLEAR * k:
            raise RuntimeError(f"{base}: mud piece {i + 1} would sit under the tub's water")
        ready.append((ob, piece, shells + fringe))
    for i, ((ob, piece, _b), boxes) in enumerate(zip(ready, _settle(objs, [r[2] for r in ready]))):
        lo, hi = _reach(boxes)
        at = (lo + hi) / 2
        probe = []
        c0, R0, s0, _o = boxes[0]                      # the fur under the wrap picks the mud's shade
        for a in range(3):
            for sign in (1, -1):
                probe.append(_swatch_at(ob, c0 + R0.col[a] * sign * s0[a] / 2))
        furs = [f for f in probe if f]
        fur = max(dict.fromkeys(furs), key=furs.count) if furs else None    # on a tie the fur probed first wins
        tone = _mud_for(fur, wet=i % 3 == 2)           # every third piece the wet shade
        b = Builder()
        for c, R, s, sides in boxes:
            verts = b.box(tuple(c - at), tuple(s), tone, bevel=False, rot=R)
            for e in {e for v in verts for e in v.link_edges}:      # soften the edges that wrap an edge of the block,
                p = R.transposed() @ ((e.verts[0].co + e.verts[1].co) / 2 - (c - at))   # as the block's own are
                on = [(a, 1 if p[a] > 0 else -1) for a in range(3) if abs(p[a]) > s[a] / 4]
                e[b.bev] = 1 if len(on) == 2 and all(f in sides for f in on) else 0
        out.append((b.finalize(f"{base}_Mud{i + 1:02d}", mat, location=tuple(at)), piece))
    return out


def _tangle(k, swatch, swatch2):
    b = Builder()
    for j, (ax, tilt) in enumerate(((0.3, 25), (2.4, -30), (4.5, 20))):   # turned off square so no side lies on a fur face
        rot = Matrix.Rotation(ax, 3, "Z") @ Matrix.Rotation(math.radians(tilt), 3, "X")
        b.box((0, 0, 0.06 * k), (0.08 * k, 0.08 * k, 0.26 * k), swatch if j != 1 else swatch2, bevel=False, rot=rot)
    return b


def build_dirty(name, mat, body, base=None):
    """The dirty model of a roster cat: (objects, nest map for rbx_export, root attributes). `base` overrides the
    asset name (loaf.py builds the held loaf from the walking stray)."""
    spec = cats.spec_of(name)
    own = base is None                                 # the held loaf renumbers its mud: it carries no levels
    base = base or f"CleanACat_Cat_{name}_Dirty{cats.SUFFIX[body]}"
    objs = cats.build_cat(name, mat, spec={**spec, "collar": None}, base=base, body=body)   # a stray wears no collar
    worn = [o for o in objs if o.get("rides")]         # a special cat's built-in pieces (props.py): no mud, no
    objs = [o for o in objs if o not in worn]          # tangles and no fluff on them; they join again at the end
    bpy.context.view_layer.update()
    k = cats.scale_of(spec, body)
    eyes = [_centre(o) for o in objs if o.name.endswith(("_Eye1", "_Eye2"))]
    look = cats.look(spec)
    nest = {}
    cat_objs = list(objs)
    BROW_PAINT[0] = bool(spec.get("face") or spec.get("mark"))
    for ob, piece in _coat(cat_objs, base, body, k, eyes, mat):
        objs.append(ob)
        if piece in RIDES:
            nest[ob.name[len(base):]] = "_" + piece
    tspots = _spots(objs[:len(objs) - MUD], base, _T, TANGLES, TANGLE_SPACING * k, eyes)
    if len(tspots) < TANGLES:
        raise RuntimeError(f"{base}: only {len(tspots)} tangle spots found, need {TANGLES}")
    for i, (p, nrm, piece) in enumerate(tspots):
        part = f"Tangle{i + 1:02d}"
        ob = _tangle(k, look["fur"], look["second"]).finalize(f"{base}_{part}", mat, location=tuple(p))
        ob.matrix_world = Matrix.Translation(ob.location) @ _align(nrm).to_4x4()
        _apply_rotation(ob)
        objs.append(ob)
        if piece in RIDES:
            nest["_" + part] = "_" + piece
    clean = objs[:len(objs) - MUD - TANGLES]
    fspots = _spots(clean, base, [(t, d) for t, d, _ in _F], FLUFF, FLUFF_SPACING * k, [], keep_index=True)
    if len(fspots) < FLUFF:
        raise RuntimeError(f"{base}: only {len(fspots)} fluff spots found, need {FLUFF}")
    for i, (p, nrm, piece, j) in enumerate(fspots):
        part = f"Fluff{i + 1:02d}"
        r = _F[j][2] * k
        sw = _swatch_at([o for o in clean if _piece(o, base) == piece][0], p) or look["fur"]
        b = Builder()                                  # a cloud: a big puff and a smaller one beside it, a little up
        b.sphere((0, 0, 0), 1.0, sw, segments=8, rings=4, scale=(r, r * 0.9, r * 0.62))
        b.sphere((0.62 * r, 0.25 * r, 0.12 * r), 1.0, sw, segments=6, rings=3, scale=(r * 0.68, r * 0.62, r * 0.5))
        ob = b.finalize(f"{base}_{part}", mat, location=tuple(p + nrm * 0.4 * r))
        # turned about the normal, a different way each; a cat's `fluff_twist` turns all of its puffs a little more
        # when the gate finds one of them lying flat on a mud face
        twist = Matrix.Rotation(math.radians(17 + 31 * i + spec.get("fluff_twist", 0)), 4, "Z")
        ob.matrix_world = Matrix.Translation(ob.location) @ _align(nrm).to_4x4() @ twist   # time: no face lies flat on fur
        _apply_rotation(ob)
        ob.hide_render = True                          # the previews show the cat as it arrives
        objs.append(ob)
        if piece in RIDES:
            nest["_" + part] = "_" + piece
    for leg in ("LegF1", "LegF2"):                     # #23: long claws, hidden until a customer's cat needs the
        paw = [o for o in clean if _piece(o, base) == leg][0]   # pawdicure; four on each front paw, riding the leg
        for j, (p, tilt) in enumerate(_claw_spots(paw, k)):
            part = f"Claw{len([o for o in objs if '_Claw' in o.name]) + 1:02d}"
            b = Builder()
            b.box((0, -0.05 * k, -0.01 * k), (0.045 * k, 0.12 * k, 0.04 * k), "pearl", bevel=False)
            ob = b.finalize(f"{base}_{part}", mat, location=tuple(p))
            ob.matrix_world = Matrix.Translation(ob.location) @ Matrix.Rotation(math.radians(tilt), 4, "X")
            _apply_rotation(ob)
            ob.hide_render = True
            objs.append(ob)
            nest["_" + part] = "_" + leg
    attributes = {"Dirty": True, "MudCount": MUD, "TangleCount": TANGLES, "FluffCount": FLUFF,
                  "ClawCount": 2 * CLAWS_PER_PAW, "WetDarken": {"Float64": WET_DARKEN}, "DirtLevels": LEVELS}
    for lv in range(1, LEVELS + 1):                    # how many pieces a cat of each level arrives with
        attributes[f"MudAtLevel{lv}"] = sum(1 for n in MUD_LEVEL[body] if n <= lv)
        attributes[f"TanglesAtLevel{lv}"] = sum(1 for n in TANGLE_LEVEL if n <= lv)
    if own:
        MODEL_ATTRS[base] = {o.name[len(base):]: {"DirtLevel": level_of(o.name, body)} for o in objs
                             if level_of(o.name, body)}
    return objs + worn, nest, attributes


CLAWS_PER_PAW = 4


def _claw_spots(paw_ob, k):
    """Four points along the front edge of a front paw (the lowest 0.11 studs of the leg), a little in from its
    sides and just above the floor, each with a downward tilt in degrees, staggered so no two claws line up."""
    M = paw_ob.matrix_world
    vs = [M @ v.co for v in paw_ob.data.vertices]
    floor = min(v.z for v in vs)
    low = [v for v in vs if v.z < floor + 0.11 * k]
    x0, x1 = min(v.x for v in low), max(v.x for v in low)
    front = min(v.y for v in low)
    out = []
    for i in range(CLAWS_PER_PAW):
        x = x0 + (x1 - x0) * (i + 0.5) / CLAWS_PER_PAW
        out.append((Vector((x, front + 0.02 * k, floor + (0.065 + 0.004 * i) * k)), 18 + 4 * (i % 2)))
    return out


def _apply_rotation(ob):
    """Bake the rotation into the mesh so the object keeps only its location (the gates want rotation 0)."""
    R = ob.matrix_world.to_3x3()
    ob.data.transform(R.to_4x4())
    ob.matrix_world = Matrix.Translation(ob.matrix_world.translation)
    ob.data.update()
    PRIMS[ob.data.name] = [(kind, R.to_4x4() @ m, sw, extra) for kind, m, sw, extra in PRIMS[ob.data.name]]


ASSETS = {}
for _n in (*cats.ROSTER, *cats.EXTRA_CATS, *cats.SPECIAL_CATS):
    for _body in cats.BUILT_BODIES:   # 3,200: the long claws (#23) put the fluffiest coat a little over 3,000
        ASSETS[f"CleanACat_Cat_{_n}_Dirty{cats.SUFFIX[_body]}"] = (
            lambda mat, n=_n, bd=_body: build_dirty(n, mat, bd), 3200 + (1100 if _n in cats.SPECIAL_CATS else 0))
