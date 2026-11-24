"""The dirty cat (issue #12): the mud coat, tangles and the wet coat, on every cat of the roster.

  CleanACat_Cat_<Name>_Dirty       the walking cat (A) as a customer brings it: in a carrier, at the door
  CleanACat_Cat_<Name>_Dirty_Sit   the sitting cat (B) as it sits in the tub or the stray box

A dirty model is the clean cat (same pieces, same pivots, same names after the asset name) plus:

  _Mud01 .. _Mud20      one piece of the mud coat each (one to four boxes: a wrap round an edge or a corner of one
                        of the cat's blocks and the drips running from it), its own child Model pivoted at its
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


def _mud_for(fur, wet=False):
    """#22: brown mud on light fur, dusty dried mud on dark fur (Inky, Tux, the black and grey patches), whichever
    stands out more from the fur under the blob, so the scrub's reveal reads on every coat."""
    pairs = (("mud", "mud_wet"), ("mud_dust", "mud_dust_wet"))
    if fur is None:
        return pairs[0][wet]
    hexes = dict(palette.SWATCHES)
    best = max(pairs, key=lambda pr: _contrast(hexes[pr[0]], hexes[fur]))
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
# reaches a face of the block (0 or 1) comes out of that face; its other sides are cut inside the block. Fractions
# snap to the block's mud pixels. The first box is the wrap and must fit; a later box (a drip) that would touch the
# face's drawing or come too near an eye is left out on that cat.
HEAD_COAT = [
    ("Head", [(0, 0.0, 0.1, 0.125, 1.0, 0.0, 0.5), (0, 0.0, 0.1, 0.375, 0.75, 0.5, 0.75),       # the right cheek
              (0, 0.1, 0.4, 0.875, 1.0, 0.0, 0.375), (0, 0.0, 0.2, 0.0, 0.125, 0.0, 0.125)]),
    ("Head", [(0, 0.9, 1.0, 0.25, 0.875, 0.5, 0.875), (0, 0.9, 1.0, 0.5, 0.75, 0.25, 0.5),      # the left temple
              (0, 0.9, 1.0, 0.375, 0.625, 0.875, 1.0)]),
    ("Head", [(0, 0.5, 0.8, 0.0, 0.25, 0.875, 1.0), (0, 0.6, 0.7, 0.0, 0.125, 0.75, 0.875)]),   # a splat on the brow
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
        ("Body", [(0, 0.3, 0.7, 0.0, 0.1, 0.0, 0.6)]),                                               # the chest
        ("Body", [(0, 0.55, 1.0, 0.3, 0.7, 0.6, 1.0), (0, 0.89, 1.0, 0.36, 0.55, 0.3, 0.6)]),        # saddle, left
        ("Body", [(0, 0.1, 0.6, 0.8, 1.0, 0.5, 1.0), (0, 0.2, 0.35, 0.9, 1.0, 0.15, 0.5)]),          # the rump
        ("Body", [(0, 0.0, 0.11, 0.2, 0.75, 0.15, 0.7), (0, 0.0, 0.3, 0.1, 0.3, 0.83, 1.0)]),        # right flank
        ("Body", [(0, 0.6, 1.0, 0.45, 0.9, 0.0, 0.33)]),                                             # belly, left
        ("Body", [(0, 0.1, 0.45, 0.35, 0.6, 0.83, 1.0)]),                                            # the shoulders
        ("Body", [(0, 0.89, 1.0, 0.05, 0.3, 0.2, 0.7)]),                                             # left flank
        ("Body", [(0, 0.0, 0.4, 0.6, 0.95, 0.0, 0.17)]),                                             # belly, right
        ("LegF1", [("paw", 0, 1, 0, 1, 0, 1), (0, 0, 1, 0, 1, 0.0, 0.5), (0, 0.67, 1.0, 0.0, 0.67, 0.5, 0.75)]),
        ("LegF2", [("paw", 0, 1, 0, 1, 0, 1), (0, 0, 1, 0, 1, 0.0, 0.25), (0, 0.0, 0.33, 0.0, 0.67, 0.25, 0.5)]),
        ("LegB1", [("paw", 0, 1, 0, 1, 0, 1), (0, 0, 1, 0, 1, 0.0, 0.25), (0, 0.67, 1.0, 0.33, 1.0, 0.25, 0.5)]),
        ("LegB2", [("paw", 0, 1, 0, 1, 0, 1), (0, 0, 1, 0, 1, 0.0, 0.5), (0, 0.0, 0.33, 0.33, 1.0, 0.5, 0.75)]),
        ("Tail", [(-1, 0, 1, 0.4, 1.0, 0, 1)]),                                                      # the tip, dipped
        ("Tail", [(0, 0, 1, 0.2, 0.7, 0.5, 1.0)]),
    ],
}


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
            i1 = min(n[a], i0 + 1)
            i0 = i1 - 1
        span.append((i0, i1))
    return span, n


def _shell(ob, block, span, n, k, eyes, head):
    """The mud box for a span of a block: (centre, axes, size, its outer sides) in asset space, or None when it would lie on the
    face's drawing or too near an eye. Each side that reaches the block's surface comes out of it by MUD_PROUD over
    the highest thing of the coat under it; an underside stops at the floor."""
    c, R, size = block
    inv = ob.matrix_world.inverted()
    dg = bpy.context.evaluated_depsgraph_get()
    lo = [-size[a] / 2 + size[a] * span[a][0] / n[a] for a in range(3)]
    hi = [-size[a] / 2 + size[a] * span[a][1] / n[a] for a in range(3)]
    out_lo, out_hi = list(lo), list(hi)
    out = set()                                        # the sides that come out of the block: (axis, sign)
    for a in range(3):
        u, v = [i for i in range(3) if i != a]
        for sign, edge, reaches in ((-1, lo, span[a][0] == 0), (1, hi, span[a][1] == n[a])):
            if not reaches:
                continue
            nrm = R.col[a] * sign
            down = (c + R @ Vector([edge[i] if i == a else 0.0 for i in range(3)])).z if nrm.z < -0.9 else None
            relief = 0.0
            for fu in (0.08, 0.3, 0.5, 0.7, 0.92):
                for fv in (0.08, 0.3, 0.5, 0.7, 0.92):
                    q = [0.0, 0.0, 0.0]
                    q[a], q[u], q[v] = edge[a], lo[u] + (hi[u] - lo[u]) * fu, lo[v] + (hi[v] - lo[v]) * fv
                    p = c + R @ Vector(q)
                    if head and any((p - e).length < EYE_CLEAR * 0.75 for e in eyes):
                        return None
                    ok, loc, _n, _f = ob.ray_cast(inv @ (p + nrm * 0.6 * k), (inv.to_3x3() @ -nrm).normalized(),
                                                  distance=2.0, depsgraph=dg)
                    if ok:
                        z = (ob.matrix_world @ loc - p).dot(nrm)
                        if head and nrm.y < -0.5 and z > FACE_BARE * k:
                            return None
                        if z <= RELIEF_MAX * k:
                            relief = max(relief, z)
            grow = relief + MUD_PROUD * k
            if down is not None:                       # an underside never goes below the floor the cat stands on
                grow = max(0.0, min(grow, down))
            out.add((a, sign))
            if sign < 0:
                out_lo[a] = lo[a] - grow
            else:
                out_hi[a] = hi[a] + grow
    mid = Vector([(out_lo[a] + out_hi[a]) / 2 for a in range(3)])
    return c + R @ mid, R, Vector([out_hi[a] - out_lo[a] for a in range(3)]), out


def _coat(objs, base, body, k, eyes, mat):
    """The MUD pieces of the coat for a built cat: [(object, the cat piece it rides)]."""
    pieces = {_piece(o, base): o for o in objs}
    taken = {}                                         # (piece, block): the mud pixels already used
    out = []
    for i, (piece, boxes) in enumerate(COAT[body]):
        ob = pieces[piece]
        shells, probe = [], []
        for j, (which, *frac) in enumerate(boxes):
            block = _block(ob, which, k)
            span, n = _cells(block, frac, k)
            cells = {(x, y, z) for x in range(*span[0]) for y in range(*span[1]) for z in range(*span[2])}
            used = taken.setdefault((piece, which if which != -1 else len(_boxes(ob)) - 1), set())
            shell = None if cells & used else _shell(ob, block, span, n, k, eyes, piece == "Head")
            if shell is None:
                if j == 0:
                    raise RuntimeError(f"{base}: mud piece {i + 1} does not fit (its first box)")
                continue
            used |= cells
            shells.append(shell)
        corners = [c + R @ Vector((sx * s.x, sy * s.y, sz * s.z)) / 2 for c, R, s, _o in shells
                   for sx in (1, -1) for sy in (1, -1) for sz in (1, -1)]
        lo = Vector([min(p[a] for p in corners) for a in range(3)])
        hi = Vector([max(p[a] for p in corners) for a in range(3)])
        if (hi - lo).length / 2 > SCRUB_REACH:
            raise RuntimeError(f"{base}: mud piece {i + 1} is too big to scrub ({(hi - lo).length / 2:.2f})")
        if body == "sit" and hi.z < TUB_WATER + WATER_CLEAR * k:
            raise RuntimeError(f"{base}: mud piece {i + 1} would sit under the tub's water")
        at = (lo + hi) / 2
        c0, R0, s0, _o = shells[0]                     # the fur under the wrap picks the mud's shade
        for a in range(3):
            for sign in (1, -1):
                probe.append(_swatch_at(ob, c0 + R0.col[a] * sign * s0[a] / 2))
        furs = [f for f in probe if f]
        fur = max(set(furs), key=furs.count) if furs else None
        tone = _mud_for(fur, wet=i % 3 == 2)           # every third piece the wet shade
        b = Builder()
        for c, R, s, sides in shells:
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


def build_dirty(name, mat, body):
    """The dirty model of a roster cat: (objects, nest map for rbx_export, root attributes)."""
    spec = cats.ROSTER[name]
    base = f"CleanACat_Cat_{name}_Dirty{cats.SUFFIX[body]}"
    objs = cats.build_cat(name, mat, base=base, body=body)
    bpy.context.view_layer.update()
    k = cats.scale_of(spec, body)
    eyes = [_centre(o) for o in objs if o.name.endswith(("_Eye1", "_Eye2"))]
    look = cats.look(spec)
    nest = {}
    cat_objs = list(objs)
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
        twist = Matrix.Rotation(math.radians(17 + 31 * i), 4, "Z")   # turned about the normal, a different way each
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
                  "ClawCount": 2 * CLAWS_PER_PAW, "WetDarken": {"Float64": WET_DARKEN}}
    return objs, nest, attributes


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
for _n in cats.ROSTER:
    for _body in cats.BUILT_BODIES:   # 3,200: the long claws (#23) put the fluffiest coat a little over 3,000
        ASSETS[f"CleanACat_Cat_{_n}_Dirty{cats.SUFFIX[_body]}"] = (
            lambda mat, n=_n, bd=_body: build_dirty(n, mat, bd), 3200)
