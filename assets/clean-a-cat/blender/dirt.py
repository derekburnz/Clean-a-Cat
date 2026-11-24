"""The dirty cat (issue #12): mud blobs, tangles and the wet coat, on every cat of the roster.

  CleanACat_Cat_<Name>_Dirty       the walking cat (A) as a customer brings it: in a carrier, at the door
  CleanACat_Cat_<Name>_Dirty_Sit   the sitting cat (B) as it sits in the tub or the stray box

A dirty model is the clean cat (same pieces, same pivots, same names after the asset name) plus:

  _Mud01 .. _Mud20      one mud splat each (one to three flat parts: a main patch, a second patch in the other
                        mud shade and a drip, as many as fit the face), its own child Model pivoted at the spot. The scrub removes a blob
                        by its name (find the child Model whose name ends in _MudNN and Destroy it). Blobs on the head,
                        tail or a leg are nested in that piece's Model, so they move with it; the rest sit on the Body.
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

Mud spots are found by casting rays at the built cat (deterministic, no randomness), so every coat and both bodies
get spots on their own surface, the eyes stay clear and no two splats touch. A splat is then fitted to its fur face
(#107): the biggest pattern that lies wholly on the face, so nothing hangs past an edge, and never a splat too small
to scrub. A spot with no room (a thin tail) is passed over for the next one.
"""

import math

import bpy
from mathutils import Matrix, Vector

import cats
import palette
from common import Builder

MUD = 20
TANGLES = 6
WET_DARKEN = 0.3
EYE_CLEAR = 0.3           # studs: no blob centre this close to an eye's centre
SPACING = 0.22            # studs between blob centres
TANGLE_SPACING = 0.3
FLUFF = 10
FLUFF_SPACING = 0.25
# Mud splats (#107). The cats are blocks with pixel faces, so mud is a pixel splat lying flat on a fur face, not a
# ball: a main patch, a second patch in the other mud shade that steps out of it at a corner, and a drip a gap away
# (below the patch on a side face). PIX is one mud pixel in studs before the cat's scale, about an eye's highlight.
# Patterns A, B and C: ((centre x, centre y, width, height) of the main and of the second patch, the drip's centre),
# in pixels, +Y up on a side face. No two edges line up, so no two side faces share a plane.
PIX = 0.09
PATTERNS = {
    "A": (((0.0, 0.0, 4.0, 3.0), (1.25, 1.25, 2.5, 2.5)), (-1.5, -2.5)),
    "B": (((0.0, 0.0, 4.0, 2.5), (-1.25, -1.0, 2.5, 2.5)), (1.5, -2.25)),
    "C": (((0.0, 0.0, 3.0, 3.0), (1.25, -0.75, 2.5, 2.5)), (-1.0, -2.75)),
    "W": (((0.0, 0.0, 5.0, 1.5), (1.0, 0.75, 2.5, 1.5)), (-1.5, -1.75)),     # a wide smear: a forehead, a back
    "T": (((0.0, 0.0, 1.5, 4.0), (0.75, -1.0, 1.5, 2.5)), (-0.25, -3.25)),    # a tall run: a leg
    "S": (((0.0, 0.0, 2.0, 2.0), (0.75, 0.75, 1.5, 1.5)), (-0.5, -1.75)),     # a small dab: a tail, a paw
}
SHAPE_ORDER = "ABACBACABC"
# How far the main patch, the second patch and the drip stand off the fur, and how far each reaches into it (all
# different, so no hidden faces meet). A splat may lie over the coat's pattern (a stripe, a patch, a point), which
# stands up to COVER proud of the fur. The splat then measures the highest and the lowest thing under it (_relief)
# and stands off the highest and reaches under the lowest, so mud is thin on plain fur and still covers a stripe.
COVER = 0.045
MUD_PROUD = (0.05, 0.024, 0.036)
MUD_SUNK = (0.02, 0.012, 0.016)
FIT_SCALES = (1.0, 0.9, 0.8, 0.7, 0.6, 0.5)
FIT_SHIFTS = sorted(((x, y) for x in range(-3, 4) for y in range(-3, 4)), key=lambda t: (t[0] ** 2 + t[1] ** 2, t))
# A splat must be big enough to see and to scrub. Its size is the main patch plus 0.6 of the second, in square
# pixels. The spots are tried at the first size; only if fewer than MUD fit does the next size get its turn.
FIT_SIZES = (8.0, 5.0, 3.0)
RIDES = ("Head", "Tail", "LegF1", "LegF2", "LegB1", "LegB2")   # pieces whose Model carries the blobs on them
ALLOWED = ("Body",) + RIDES

# Ray directions, in the cat's own frame (front is -Y, the cat's left is +X, up is +Z), aimed at a target piece's
# centre. Listed best first: the faces a player sees at the tub (top, sides, chest), then the rest. The first MUD
# that land on fur, clear of the eyes and of each other, are used.
_D = [
    ("Body", (0.0, 0.0, 1.0)), ("Head", (0.0, -0.35, 1.0)), ("Head", (0.0, -1.0, 0.8)),          # the forehead (#107)
    ("Body", (0.85, -0.2, 0.5)), ("Body", (-0.85, -0.2, 0.5)),
    ("Body", (0.0, -1.0, 0.25)), ("Head", (0.9, -0.45, 0.25)), ("Head", (-0.9, -0.45, 0.25)), ("Body", (0.9, 0.5, 0.3)),
    ("Body", (-0.9, 0.5, 0.3)), ("LegF1", (0.3, -1.0, 0.0)), ("LegF2", (-0.3, -1.0, 0.0)), ("Tail", (0.0, 0.3, 1.0)),
    ("Body", (0.5, -0.9, -0.1)), ("Body", (-0.5, -0.9, -0.1)), ("Head", (0.5, 0.3, 1.0)), ("Head", (-0.5, 0.3, 1.0)),
    ("Body", (0.4, 0.8, 0.8)), ("Body", (-0.4, 0.8, 0.8)), ("Body", (1.0, -0.6, -0.2)), ("Body", (-1.0, -0.6, -0.2)),
    ("LegB1", (0.6, -0.8, 0.0)), ("LegB2", (-0.6, -0.8, 0.0)), ("Head", (0.0, -1.0, -0.6)), ("Body", (0.0, 1.0, 0.4)),
    ("Body", (1.0, 0.0, 0.0)), ("Body", (-1.0, 0.0, 0.0)), ("Tail", (1.0, 0.0, 0.3)), ("Tail", (-1.0, 0.0, 0.3)),
    ("Body", (0.7, 0.0, 0.9)), ("Body", (-0.7, 0.0, 0.9)), ("Body", (0.3, -0.5, 1.0)), ("Body", (-0.3, -0.5, 1.0)),
    # spares (#107): a splat needs room on its face, so a thin tail or leg may turn its spot down
    ("Head", (0.0, 1.0, 0.3)), ("Head", (0.9, 0.5, 0.2)), ("Head", (-0.9, 0.5, 0.2)), ("Body", (0.6, 0.9, 0.0)),
    ("Body", (-0.6, 0.9, 0.0)), ("Head", (0.6, -0.2, 1.0)), ("Head", (-0.6, -0.2, 1.0)), ("Body", (0.3, 0.9, 1.0)),
    ("Body", (-0.3, 0.9, 1.0)), ("Head", (1.0, 0.2, -0.3)), ("Head", (-1.0, 0.2, -0.3)), ("Body", (0.0, 0.6, 1.0)),
]
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


def _on_fur(clean, base, pt, nrm, piece, k):
    """True where pt, on a fur face with normal nrm, has that same face of `piece` under it, or the coat's pattern on
    that face: no ear, eye or other piece on top and no edge of the block passed. The face of the head keeps its
    drawing (muzzle, mouth, blaze), so there only the bare fur counts."""
    hit = _ray(clean, base, pt + nrm * 0.6 * k, -nrm)
    if hit is None:
        return False
    q, _n, got = hit
    face = piece == "Head" and nrm.y < -0.5
    return got == piece and abs((q - pt).dot(nrm)) < (0.012 if face else COVER) * k


def _fit_splat(clean, base, p, nrm, piece, i, k, eyes, placed, size):
    """Lay pattern i at p so that every patch lies wholly on its fur face, clear of the eyes and of the splats
    already placed on that face. Tries every pattern, with and without its second patch, mirrored, moved up to three
    pixels and smaller, the biggest splat first, and nothing under `size` square pixels. Returns (local rectangles
    (cx, cy, w, h), the drip's centre or None, the scale used), all in studs in the face's frame, or None when
    nothing that big fits here."""
    R = _align(nrm)
    ax, ay = R.col[0], R.col[1]
    nkey = tuple(round(c) for c in nrm)
    plane = p.dot(nrm)

    def world(x, y):
        return p + ax * x + ay * y

    def box2(x, y, w, h):
        c = world(x, y)
        u, v = c.dot(ax), c.dot(ay)
        return (u - w / 2, u + w / 2, v - h / 2, v + h / 2)

    def free(x, y, w, h):
        a = box2(x, y, w, h)
        for key, d, b in placed:
            if key == nkey and abs(d - plane) < 0.05 * k:
                if a[0] < b[1] + 0.01 and b[0] < a[1] + 0.01 and a[2] < b[3] + 0.01 and b[2] < a[3] + 0.01:
                    return False
        return True

    seen = {}

    def fur(x, y):
        key = (round(x, 4), round(y, 4))
        if key not in seen:
            w = world(x, y)
            seen[key] = (all((w - eye).length >= EYE_CLEAR * 0.75 for eye in eyes)
                         and _on_fur(clean, base, w, nrm, piece, k))
        return seen[key]

    def lies(x, y, w, h):
        e = 0.008 * k
        pts = [(x + sx * (w / 2 - e), y + sy * (h / 2 - e)) for sx in (0, 1, -1) for sy in (0, 1, -1)]
        return free(x, y, w, h) and all(fur(*t) for t in pts)

    want = SHAPE_ORDER[i % len(SHAPE_ORDER)]
    flips = (1, -1) if i % 2 == 0 else (-1, 1)
    tries = []                                         # every way to lay a pattern here, the biggest splat first
    for key, ((main, second), drip) in PATTERNS.items():
        for both in (True, False):
            for scale in FIT_SCALES:
                area = (main[2] * main[3] + (second[2] * second[3] * 0.6 if both else 0.0)) * scale * scale
                if area < size:
                    continue
                for f, flip in enumerate(flips):
                    for dx, dy in FIT_SHIFTS:
                        cost = 0.2 * (dx * dx + dy * dy) + (0.0 if key == want else 1.5) + 0.1 * f
                        tries.append((-(area - cost), key, both, scale, flip, dx, dy))
    tries.sort()
    for _score, key, both, scale, flip, dx, dy in tries:
        (main, second), drip = PATTERNS[key]
        u = PIX * k * scale
        rects = [((cx * flip + dx) * u, (cy + dy) * u, w * u, h * u)
                 for cx, cy, w, h in ((main, second) if both else (main,))]
        if not all(lies(*r) for r in rects):
            continue
        d = ((drip[0] * flip + dx) * u, (drip[1] + dy) * u)
        if not lies(d[0], d[1], u, u):
            d = None
        for r in rects + ([(d[0], d[1], u, u)] if d else []):
            placed.append((nkey, plane, box2(*r)))
        return rects, d, scale
    return None


def _relief(ob, p, nrm, boxes, k):
    """The highest and the lowest point of `ob`'s surface under the splat's boxes ((cx, cy, w, h) in the face's
    frame at p), measured along nrm from p, sampled every third of a pixel."""
    R = _align(nrm)
    ax, ay = R.col[0], R.col[1]
    inv = ob.matrix_world.inverted()
    d_l = (inv.to_3x3() @ -nrm).normalized()
    dg = bpy.context.evaluated_depsgraph_get()
    hi, lo = 0.0, 0.0
    step = PIX * k / 3
    for cx, cy, w, h in boxes:
        nx, ny = max(2, math.ceil(w / step) + 1), max(2, math.ceil(h / step) + 1)
        for a in range(nx):
            for b in range(ny):
                pt = p + ax * (cx - w / 2 + w * a / (nx - 1)) + ay * (cy - h / 2 + h * b / (ny - 1))
                ok, loc, _n, _f = ob.ray_cast(inv @ (pt + nrm * 0.6 * k), d_l, distance=2.0, depsgraph=dg)
                if ok:
                    z = (ob.matrix_world @ loc - p).dot(nrm)
                    if abs(z) <= COVER * k:            # past a bevel the ray lands on another face: not under the mud
                        hi, lo = max(hi, z), min(lo, z)
    return hi, lo


def _blob(i, k, swatches, rects, drip, scale, hi=0.0, lo=0.0):
    """The splat's boxes in the face's frame (z out of the fur): main patch, second patch, drip. The main patch's
    height steps a little with i, so two splats that end up side by side never share a top plane. hi and lo are the
    relief under the splat (_relief)."""
    b = Builder()
    tones = (swatches[0], swatches[1], swatches[0])
    boxes = [(r, j) for j, r in enumerate(rects)]
    if drip:
        boxes.append(((drip[0], drip[1], PIX * k * scale, PIX * k * scale), 2))
    for (cx, cy, w, h), j in boxes:
        top = hi + (MUD_PROUD[j] + (0.004 * (i % 4) if j == 0 else 0.0)) * k
        bottom = lo - MUD_SUNK[j] * k
        b.box((cx, cy, (top + bottom) / 2), (w, h, top - bottom), tones[j], bevel=False)
    return b


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
    spots = _spots(objs, base, _D, len(_D), SPACING * k, eyes)
    nest = {}
    by_piece = {o.name[len(base) + 1:]: o for o in objs}
    cat_objs = list(objs)
    placed = []
    fits = {}                                          # spot number: its splat
    for size in FIT_SIZES:                             # the big splats first, on the faces a player sees first
        for j, (p, nrm, piece) in enumerate(spots):
            if j not in fits and len(fits) < MUD:
                fit = _fit_splat(cat_objs, base, p, nrm, piece, j, k, eyes, placed, size)
                if fit:
                    fits[j] = fit
    if len(fits) < MUD:
        raise RuntimeError(f"{base}: only {len(fits)} mud splats fit, need {MUD}")
    for i, j in enumerate(sorted(fits)):
        p, nrm, piece = spots[j]
        rects, drip, scale = fits[j]
        fur = _swatch_at(by_piece[piece], p)
        tones = (_mud_for(fur), _mud_for(fur, wet=True))
        if i % 4 == 3:                                 # every fourth splat the other way round
            tones = tones[::-1]
        part = f"Mud{i + 1:02d}"
        u = PIX * k * scale
        hi, lo = _relief(by_piece[piece], p, nrm, rects + ([(drip[0], drip[1], u, u)] if drip else []), k)
        ob = _blob(i, k, tones, rects, drip, scale, hi, lo).finalize(f"{base}_{part}", mat, bevel=0, location=tuple(p))
        ob.matrix_world = Matrix.Translation(ob.location) @ _align(nrm).to_4x4()
        _apply_rotation(ob)
        objs.append(ob)
        if piece in RIDES:
            nest["_" + part] = "_" + piece
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
    from common import PRIMS                           # the Part export reads the primitive log: turn it too
    ob.data.update()
    PRIMS[ob.data.name] = [(kind, R.to_4x4() @ m, sw, extra) for kind, m, sw, extra in PRIMS[ob.data.name]]


ASSETS = {}
for _n in cats.ROSTER:
    for _body in cats.BUILT_BODIES:   # 3,200: the long claws (#23) put the fluffiest coat a little over 3,000
        ASSETS[f"CleanACat_Cat_{_n}_Dirty{cats.SUFFIX[_body]}"] = (
            lambda mat, n=_n, bd=_body: build_dirty(n, mat, bd), 3200)
