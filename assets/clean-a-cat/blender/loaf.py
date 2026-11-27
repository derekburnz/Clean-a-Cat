"""The held loaf (issues #318, #324, #340, #353). The owner, 2026-11-24, on the opening: "we should pick him up out
of crate". The player lifts the muddy kitten out of the box and carries him to the tub. His clip of the hold ("here
is how the carrying should look"): the arms reach forward, down and in, and the load lies across them close against
the body with its head end at the carrier's left shoulder. After his dev test he sent six screenshots of the carry in
his own earlier game (the carried cat was "a little too small and in wrong pose"), and then a picture of the held cat
from ten angles: "this is what the cat in arms should be posing like shown from all angles". That picture is the pose
this module builds; the cat in it is not ours and Suds keeps his own look.

  CleanACat_Cat_Suds_Dirty_Loaf   the muddy stray as a loaf: no collar, legs tucked under, chin tucked on his paws
  CleanACat_Cat_Suds_Loaf         the same body clean, in his collar

A loaf is the walking body (A) with its legs taken away and everything lowered until the belly lies LOAF_LIFT over
the base, so the coat and the mud are the walking cat's own and the two bodies swap without a jump in the look. The
pieces keep A's names (`_Body`, `_Head`, `_Eye1`, `_Eye2`, `_EarL`, `_EarR`, `_Tail`, the clean one's `_Collar`) and
there is one more, `_Paws`. Pivot at the bottom middle, front at -Z in Roblox, like every cat.

The pose (#353), as in the owner's picture:
  - The body lies low and compact, belly down.
  - The head is tipped nose down about the neck (cats.LOAF_PITCH, 45 degrees): the crown faces forward and up, the
    chin is tucked down onto the paws and the head's back corner stands well above the back. The tip is in the mesh
    and the primitive log; the pieces keep rotation 0. The eyes, the ears, the mud on the head and the `Carry` and
    `BowSlot` Attachments ride the head and tip with it.
  - The front paws are short and tucked under the chin, their tips turned in and just showing past it.
  - The tail is curled up at the back (cats.loaf_tail): out of the rump at his right hip, up beside it and the tip
    hooked back in, all of it on his outer half so it clears the carrier's right arm. The muddy loaf's tail has a muddy tip.
  - The clean loaf's collar is its own: the band sits behind the head and the bell hangs at his right side. He lies
    across the arms with his front to the carrier's left, so his right side, the bell and the tail's curl face out.
  - Root attribute `CarryScale` (cats.LOAF_CARRY_SCALE, 1.4): his size in the arms. He is 1.0 in the box and 1.5
    at a station. `Effects/Carry.luau` scales him by it.

The muddy loaf is for carrying only. Its mud and tangles are the walking stray's, less what was on the legs and less
the drips that hung under the belly and the jaw, and they are not counted: there is no MudCount on it, and it has no
fluff and no claws. Wash him on `_Dirty_Sit`. Root attribute `Loaf` on both.
"""
import math

import bmesh
import bpy
from mathutils import Matrix, Vector

import cats
import common
import dirt
from common import PRIMS, Builder, scale_mesh

NAMES = ("Suds",)                  # the cats that have a loaf so far
LEG_PIECES = cats.LEGS["walk"]
HEAD_FAMILY = ("_Head",) + tuple("_" + p for p in cats.HEAD_PIECES)
PAW = (0.26, 0.46, 0.17)           # one front paw, unscaled: its width, its length and its height. Tucked under
                                   # the chin (#353): short, on the base, its tip just past the chin
PAW_X, PAW_OUT = 0.21, 0.17        # each paw's middle off the centre line, and in front of the chest
PAW_IN = 22.0                      # degrees each paw's tip is turned in toward the other
BELL_BACK = 0.44                   # the clean loaf's collar band behind the chest front: clear of the lowered head


def _corners_z(ob, m):
    M = ob.matrix_world @ m
    return [(M @ Vector((sx, sy, sz))).z for sx in (-0.5, 0.5) for sy in (-0.5, 0.5) for sz in (-0.5, 0.5)]


def _cut_below(ob, z):
    """Take away every box of `ob` whose middle lies below z (asset space): a drip that hung under the belly. A
    piece that wraps the belly's edge has its middle above it and stays. The mesh and its primitive log stay in
    step."""
    def mid(zs):
        return (min(zs) + max(zs)) / 2

    keep = [p for p in PRIMS[ob.data.name] if mid(_corners_z(ob, p[1])) > z]
    if len(keep) == len(PRIMS[ob.data.name]):
        return
    PRIMS[ob.data.name] = keep
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    M = ob.matrix_world
    todo, gone = set(bm.verts), []
    while todo:                                        # one island at a time
        island, stack = set(), [todo.pop()]
        while stack:
            v = stack.pop()
            island.add(v)
            for e in v.link_edges:
                o = e.other_vert(v)
                if o in todo:
                    todo.discard(o)
                    stack.append(o)
        if mid([(M @ v.co).z for v in island]) <= z:
            gone += island
    bmesh.ops.delete(bm, geom=gone, context="VERTS")
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.update()


def _turn(ob, pivot, turn):
    """Turn a piece about a point of the asset: the mesh and its primitive log turn about the piece's own origin,
    and the origin swings round the point. The piece keeps rotation 0 (the transforms gate)."""
    ob.data.transform(turn)
    PRIMS[ob.data.name] = [(k, turn @ m, sw, extra) for k, m, sw, extra in PRIMS.get(ob.data.name, [])]
    ob.location = pivot + turn.to_3x3() @ (Vector(ob.location) - pivot)
    ob.data.update()


def build_loaf(name, mat, dirty, suffix="_Loaf"):
    """(objects, nest map for rbx_export, root attributes) of one cat's loaf."""
    spec = cats.spec_of(name)
    base = f"CleanACat_Cat_{name}{'_Dirty' if dirty else ''}{suffix}"
    if dirty:
        objs, nest, _attrs = dirt.build_dirty(name, mat, "walk", base=base)
    else:
        objs, nest = cats.build_cat(name, mat, base=base, body="walk"), {}
    bpy.context.view_layer.update()
    k = cats.scale_of(spec, "loaf")
    drop = cats.loaf_drop(spec)
    legs = tuple("_" + p for p in LEG_PIECES)
    out = []
    for ob in objs:                                    # the legs go, and with them what rode them; no fluff, no claws
        suffix = ob.name[len(base):]
        gone = legs + ("_Tail", "_Collar")             # A's tail stands up and its bell hangs where the head now lies
        if suffix in gone or nest.get(suffix) in gone or suffix.startswith(("_Fluff", "_Claw")):
            nest.pop(suffix, None)
            bpy.data.objects.remove(ob, do_unlink=True)
            continue
        out.append(ob)
    belly = drop + cats.LOAF_LIFT * k                  # the belly's height while the cat still stands
    head = [ob for ob in out if ob.name == base + "_Head"][0]
    jaw = min((head.matrix_world @ v.co).z for v in head.data.vertices)
    for ob in out:
        if "_Mud" in ob.name or "_Tangle" in ob.name:  # no drips under the belly, and none under the jaw
            _cut_below(ob, jaw if nest.get(ob.name[len(base):]) == "_Head" else belly)
        ob.location.z -= drop
        if ob.name[len(base):] in HEAD_FAMILY or nest.get(ob.name[len(base):]) == "_Head":
            ob.location.z -= cats.LOAF_HEAD_DROP * k   # the head lies low, chin on the paws (#340)
    d = cats.dims(spec, "loaf")
    (cx, cy, cz), (sx_, sy, sz) = d["body"]
    front = cy - sy / 2
    if spec.get("collar") and not dirty:               # the loaf's own collar: the bell hangs at his right side, which
        band, bell = spec["collar"]                    # faces out when he lies across the arms
        z, y = cz - drop / k, front + BELL_BACK
        at = (cx - sx_ / 2 - 0.14, y, z - 0.08)
        b = Builder()
        b.box((cx, y, z), (sx_ + 0.12, 0.18, sz + 0.12), band)
        b.box((at[0] + 0.1, y, at[2] + 0.17), (0.2, 0.12, 0.1), band, bevel=False)      # the tab the bell hangs from
        b.sphere(at, 0.17, bell, segments=8, rings=5)
        b.box((at[0] - 0.14, y, at[2] - 0.06), (0.07, 0.04, 0.1), "fur_brown", bevel=False)   # its slot
        collar = b.finalize(f"{base}_Collar", mat, location=(0.0, 0.0, 0.0))
        if k != 1.0:
            scale_mesh(collar, k)
        out.append(collar)
    b = Builder()                                      # the front paws, on the base, tucked under the chin, tips in
    for sx in (1, -1):
        b.box((sx * PAW_X, -PAW_OUT, PAW[2] / 2), PAW, cats.look(spec)["paw"], rot=(math.radians(-sx * PAW_IN), "Z"))
    paws = b.finalize(f"{base}_Paws", mat, location=(cx * k, front * k, 0.0))
    if k != 1.0:
        scale_mesh(paws, k)
    out.append(paws)
    look = cats.look(spec)
    root, chain = cats.loaf_tail(spec)
    up = Matrix.Rotation(math.radians(90), 4, "Z")     # the chain rises from +Y; a quarter turn makes it rise from -X
    at = Vector(tuple(v * k for v in root))
    tail = cats._tail(look, chain).finalize(f"{base}_Tail", mat, location=tuple(at))
    if k != 1.0:
        scale_mesh(tail, k)
    _turn(tail, at, up)
    out.append(tail)
    if dirty:                                          # the tip dipped in mud, as the walking stray's is
        tip, way, th = cats.tail_tip(chain)
        length = chain["seg"] * 0.5 + 0.06
        mid = tip + way * (0.06 - length / 2)
        b = Builder()
        b.box(tuple(mid), (th + 0.05, length, th + 0.05), dirt._mud_for(look["tip"]), bevel=False,
              rot=(math.atan2(way.z, way.y), "X"))
        mud = b.finalize(f"{base}_Mud99", mat, location=tuple(at))                    # numbered below
        if k != 1.0:
            scale_mesh(mud, k)
        _turn(mud, at, up)
        out.append(mud)
        nest["_Mud99"] = "_Tail"
    for kind in ("_Mud", "_Tangle"):                   # number what is left 01, 02, ... with no gaps
        left = sorted((ob for ob in out if ob.name[len(base):].startswith(kind)), key=lambda ob: ob.name)
        for i, ob in enumerate(left, start=1):
            old, new = ob.name[len(base):], f"{kind}{i:02d}"
            if old != new:
                ob.name = base + new
                if old in nest:
                    nest[new] = nest.pop(old)
    neck = Vector(cats.joints(spec, "loaf")["Head"])
    look = cats.loaf_look_matrix(4)
    for ob in out:                                     # the head is tipped nose down about the neck, with its riders
        suffix = ob.name[len(base):]
        if suffix in HEAD_FAMILY or nest.get(suffix) == "_Head":
            _turn(ob, neck, look)
    bpy.context.view_layer.update()
    low = min((ob.matrix_world @ v.co).z for ob in out for v in ob.data.vertices)
    if low < -1e-4:
        raise RuntimeError(f"{base}: a piece reaches {low:.3f} below the base; raise cats.LOAF_LIFT")
    attributes = {"Loaf": True, "CarryScale": {"Float64": cats.LOAF_CARRY_SCALE}}
    if dirty:
        attributes["Dirty"] = True
    return out, nest, attributes


def build_sleep(name, mat):
    """A customer cat asleep (#1050, the Cat Hotel's guests), `CleanACat_Cat_<Name>_Loaf_Lite`: the loaf (legs tucked
    under, chin on its paws) with both eyes shut, built light as cats.build_cat_lite builds the VIP residents, since
    a sleeping guest lies still in a bed and every player on a server draws every plot's guests. Same pivot (under
    its middle, on what it lies on), pieces and Attachments as a loaf. One for each cat in cats.ROSTER. Root
    attributes `Loaf`, `Sleeping` and `Lite`."""
    def small(obj, kind, matrix, swatch, extra):
        if obj.endswith("_Head") and (swatch == "blush" or swatch.startswith("nose_")):
            return False
        if obj.endswith(cats.LITE_EYES):
            return False
        a, b, _c = common.prim_size(kind, matrix, extra)
        return math.sqrt(a * b) < cats.LITE_MIN

    common.LITE, cats.SLEEP = small, True
    try:
        objs, nest, attributes = build_loaf(name, mat, False, suffix=cats.SLEEP_SUFFIX)
    finally:
        common.LITE, cats.SLEEP = None, False
    kept = [o for o in objs if len(o.data.polygons)]
    for o in objs:
        if o not in kept:
            bpy.data.objects.remove(o, do_unlink=True)
    del attributes["CarryScale"]
    return kept, nest, attributes


ASSETS = {}
for _n in cats.ROSTER:
    ASSETS[f"CleanACat_Cat_{_n}{cats.SLEEP_SUFFIX}"] = (lambda mat, n=_n: build_sleep(n, mat), 1500)
for _n in NAMES:
    ASSETS[f"CleanACat_Cat_{_n}_Loaf"] = (lambda mat, n=_n: build_loaf(n, mat, False), 1500)
    ASSETS[f"CleanACat_Cat_{_n}_Dirty_Loaf"] = (lambda mat, n=_n: build_loaf(n, mat, True), 2600)
