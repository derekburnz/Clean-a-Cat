"""The dirty cat (issue #12): mud blobs, tangles and the wet coat, on every cat of the roster.

  CleanACat_Cat_<Name>_Dirty       the walking cat (A) as a customer brings it: in a carrier, at the door
  CleanACat_Cat_<Name>_Dirty_Sit   the sitting cat (B) as it sits in the tub or the stray box

A dirty model is the clean cat (same pieces, same pivots, same names after the asset name) plus:

  _Mud01 .. _Mud20      one mud blob each, its own child Model pivoted at the blob's centre. The scrub removes a blob
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

Blob spots are found by casting rays at the built cat (deterministic, no randomness), so every coat and both bodies
get spots on their own surface, the eyes stay clear and no two blobs touch.
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
# Blob shapes A, B and C (the model list's three): (half width, half length, half thickness) in studs, before the
# cat's scale. Big flat smears; the centre sits just off the fur, so about 0.05 studs stands proud of the coat.
SHAPES = {"A": (0.2, 0.18, 0.05), "B": (0.26, 0.15, 0.05), "C": (0.15, 0.14, 0.045)}
SHAPE_ORDER = "ABACBACABC"
RIDES = ("Head", "Tail", "LegF1", "LegF2", "LegB1", "LegB2")   # pieces whose Model carries the blobs on them
ALLOWED = ("Body",) + RIDES

# Ray directions, in the cat's own frame (front is -Y, the cat's left is +X, up is +Z), aimed at a target piece's
# centre. Listed best first: the faces a player sees at the tub (top, sides, chest), then the rest. The first MUD
# that land on fur, clear of the eyes and of each other, are used.
_D = [
    ("Body", (0.0, 0.0, 1.0)), ("Head", (0.0, -0.35, 1.0)), ("Body", (0.85, -0.2, 0.5)), ("Body", (-0.85, -0.2, 0.5)),
    ("Body", (0.0, -1.0, 0.25)), ("Head", (0.9, -0.45, 0.25)), ("Head", (-0.9, -0.45, 0.25)), ("Body", (0.9, 0.5, 0.3)),
    ("Body", (-0.9, 0.5, 0.3)), ("LegF1", (0.3, -1.0, 0.0)), ("LegF2", (-0.3, -1.0, 0.0)), ("Tail", (0.0, 0.3, 1.0)),
    ("Body", (0.5, -0.9, -0.1)), ("Body", (-0.5, -0.9, -0.1)), ("Head", (0.5, 0.3, 1.0)), ("Head", (-0.5, 0.3, 1.0)),
    ("Body", (0.4, 0.8, 0.8)), ("Body", (-0.4, 0.8, 0.8)), ("Body", (1.0, -0.6, -0.2)), ("Body", (-1.0, -0.6, -0.2)),
    ("LegB1", (0.6, -0.8, 0.0)), ("LegB2", (-0.6, -0.8, 0.0)), ("Head", (0.0, -1.0, -0.6)), ("Body", (0.0, 1.0, 0.4)),
    ("Body", (1.0, 0.0, 0.0)), ("Body", (-1.0, 0.0, 0.0)), ("Tail", (1.0, 0.0, 0.3)), ("Tail", (-1.0, 0.0, 0.3)),
    ("Body", (0.7, 0.0, 0.9)), ("Body", (-0.7, 0.0, 0.9)), ("Body", (0.3, -0.5, 1.0)), ("Body", (-0.3, -0.5, 1.0)),
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


def _blob(i, k, mud_swatch):
    sx, sy, sz = SHAPES[SHAPE_ORDER[i % len(SHAPE_ORDER)]]
    b = Builder()
    b.sphere((0, 0, 0), 1.0, mud_swatch, segments=8, rings=4, scale=(sx * k, sy * k, sz * k))
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
    spots = _spots(objs, base, _D, MUD, SPACING * k, eyes)
    if len(spots) < MUD:
        raise RuntimeError(f"{base}: only {len(spots)} mud spots found, need {MUD}")
    nest = {}
    by_piece = {o.name[len(base) + 1:]: o for o in objs}
    for i, (p, nrm, piece) in enumerate(spots):
        swatch = _mud_for(_swatch_at(by_piece[piece], p), wet=i % 4 == 3)
        part = f"Mud{i + 1:02d}"
        ob = _blob(i, k, swatch).finalize(f"{base}_{part}", mat, location=tuple(p + nrm * 0.008 * k))
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
    attributes = {"Dirty": True, "MudCount": MUD, "TangleCount": TANGLES, "FluffCount": FLUFF,
                  "WetDarken": {"Float64": WET_DARKEN}}
    return objs, nest, attributes


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
    for _body in cats.BUILT_BODIES:
        ASSETS[f"CleanACat_Cat_{_n}_Dirty{cats.SUFFIX[_body]}"] = (
            lambda mat, n=_n, bd=_body: build_dirty(n, mat, bd), 3000)
