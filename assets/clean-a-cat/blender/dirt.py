"""The dirty cat (issue #12): mud blobs, tangles and the wet coat, on every cat of the roster.

  CleanACat_Cat_<Name>_Dirty       the walking cat (A) as a customer brings it: in a carrier, at the door
  CleanACat_Cat_<Name>_Dirty_Sit   the sitting cat (B) as it sits in the tub or the stray box

A dirty model is the clean cat (same pieces, same pivots, same names after the asset name) plus:

  _Mud01 .. _Mud20      one mud blob each, its own child Model pivoted at the blob's centre. The scrub removes a blob
                        by its name (find the child Model whose name ends in _MudNN and Destroy it). Blobs on the head,
                        tail or a leg are nested in that piece's Model, so they move with it; the rest sit on the Body.
  _Tangle01 .. _Tangle06  a spiky fur clump each, removed by the brush the same way.
  root attributes       Dirty = true, MudCount = 20, TangleCount = 6, WetDarken = 0.3. The wet coat is a colour shift,
                        not extra parts: while the cat is wet, the game darkens every coat part by WetDarken (multiply
                        its Color by 1 - WetDarken) and the dryer tweens it back. No extra parts, no z-fighting.

When the last blob and tangle are gone the model is exactly the clean cat, so nothing is swapped at the reveal.

Blob spots are found by casting rays at the built cat (deterministic, no randomness), so every coat and both bodies
get spots on their own surface, the eyes stay clear and no two blobs touch.
"""

import math

import bpy
from mathutils import Matrix, Vector

import cats
from common import Builder

MUD = 20
TANGLES = 6
WET_DARKEN = 0.3
EYE_CLEAR = 0.3           # studs: no blob centre this close to an eye's centre
SPACING = 0.22            # studs between blob centres
TANGLE_SPACING = 0.3
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


def _spots(objs, base, rays, n, spacing, eyes):
    pieces = {_piece(o, base): o for o in objs}
    out = []
    for target, d in rays:
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
        if any((p - q).length < spacing for q, _, _ in out):
            continue
        out.append((p, nrm, piece))
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
    for i, (p, nrm, piece) in enumerate(spots):
        swatch = "mud_wet" if i % 4 == 3 else "mud"
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
    attributes = {"Dirty": True, "MudCount": MUD, "TangleCount": TANGLES,
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
            lambda mat, n=_n, bd=_body: build_dirty(n, mat, bd), 2500)
