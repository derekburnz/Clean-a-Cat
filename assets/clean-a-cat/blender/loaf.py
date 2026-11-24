"""The held loaf (issues #318, #324). The owner, 2026-11-24, on the opening: "we should pick him up out of crate". The
player lifts the muddy kitten out of the box and carries him to the tub. His clip of the hold ("here is how the
carrying should look"): the arms reach forward, down and in, and the load lies across them close against the body
with its head end at the carrier's left shoulder.

  CleanACat_Cat_Suds_Dirty_Loaf   the muddy stray as a loaf: no collar, legs tucked under, two paw tips at the front
  CleanACat_Cat_Suds_Loaf         the same body clean, in his collar

A loaf is the walking body (A) with its legs taken away and everything lowered until the belly lies LOAF_LIFT over
the base, so the coat and the mud are the walking cat's own and the two bodies swap without a jump in the look. The
pieces keep A's names (`_Body`, `_Head`, `_Eye1`, `_Eye2`, `_EarL`, `_EarR`, `_Tail`, the clean one's `_Collar`) and
there is one more, `_Paws`. Pivot at the bottom middle, front at -Z in Roblox, like every cat.

He is made for that hold: lying across the arms, his front to the carrier's left, so his right side faces out.
  - The head is turned cats.LOAF_LOOK degrees to his right, so he looks out ahead over his shoulder. Its eyes, ears
    and mud turn with it about the neck. The pieces keep rotation 0: the turn is in the mesh and the primitive log.
  - The tail is not A's raised one: it lies on the base along his right side (cats.loaf_tail); the muddy loaf's
    tail has a muddy tip.

The muddy loaf is for carrying only. Its mud and tangles are the walking stray's, less what was on the legs and less
the drips that hung under the belly and the jaw (under a lowered head a drip reads as a third front leg), and they
are not counted: there is no MudCount on it, and it has no fluff and no claws. Wash him on `_Dirty_Sit`. Root
attribute `Loaf` on both.
"""
import math

import bmesh
import bpy
from mathutils import Matrix, Vector

import cats
import dirt
from common import PRIMS, Builder, scale_mesh

NAMES = ("Suds",)                  # the cats that have a loaf so far
LEG_PIECES = cats.LEGS["walk"]
HEAD_FAMILY = ("_Head",) + tuple("_" + p for p in cats.HEAD_PIECES)
PAW = (0.26, 0.24, 0.15)           # one paw tip, unscaled: its width, how far it reaches and its height
PAW_X, PAW_OUT = 0.2, 0.07         # each tip's middle off the centre line, and in front of the chest


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


def build_loaf(name, mat, dirty):
    """(objects, nest map for rbx_export, root attributes) of one cat's loaf."""
    spec = cats.spec_of(name)
    base = f"CleanACat_Cat_{name}{'_Dirty' if dirty else ''}_Loaf"
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
        gone = legs + ("_Tail",)                       # A's tail stands up: the loaf gets its own lying one below
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
    d = cats.dims(spec, "loaf")
    (cx, cy, _cz), (_sx, sy, _sz) = d["body"]
    front = cy - sy / 2
    b = Builder()                                      # the paw tips, on the base, half under the chest
    for sx in (1, -1):
        b.box_base((sx * PAW_X, -PAW_OUT, 0.0), PAW, cats.look(spec)["paw"])
    paws = b.finalize(f"{base}_Paws", mat, location=(cx * k, front * k, 0.0))
    if k != 1.0:
        scale_mesh(paws, k)
    out.append(paws)
    look = cats.look(spec)
    root, chain = cats.loaf_tail(spec)
    tail = cats._tail(look, chain).finalize(f"{base}_Tail", mat, location=tuple(v * k for v in root))
    if k != 1.0:
        scale_mesh(tail, k)
    out.append(tail)
    if dirty:                                          # the tip dipped in mud, as the walking stray's is
        tip, way, th = cats.tail_tip(chain)
        length = chain["seg"] * 0.5 + 0.06
        mid = tip + way * (0.06 - length / 2)
        heading = math.atan2(way.y, way.x)
        b = Builder()
        b.box(tuple(mid), (th + 0.05, length, th + 0.05), dirt._mud_for(look["tip"]), bevel=False,
              rot=(heading - math.pi / 2, "Z"))
        mud = b.finalize(f"{base}_Mud99", mat, location=tuple(v * k for v in root))   # numbered below
        if k != 1.0:
            scale_mesh(mud, k)
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
    look = Matrix.Rotation(math.radians(-cats.LOAF_LOOK), 4, "Z")
    for ob in out:                                     # he looks out over his right shoulder: the head and its riders
        suffix = ob.name[len(base):]
        if suffix in HEAD_FAMILY or nest.get(suffix) == "_Head":
            _turn(ob, neck, look)
    bpy.context.view_layer.update()
    low = min((ob.matrix_world @ v.co).z for ob in out for v in ob.data.vertices)
    if low < -1e-4:
        raise RuntimeError(f"{base}: a piece reaches {low:.3f} below the base; raise cats.LOAF_LIFT")
    attributes = {"Loaf": True}
    if dirty:
        attributes["Dirty"] = True
    return out, nest, attributes


ASSETS = {}
for _n in NAMES:
    ASSETS[f"CleanACat_Cat_{_n}_Loaf"] = (lambda mat, n=_n: build_loaf(n, mat, False), 1500)
    ASSETS[f"CleanACat_Cat_{_n}_Dirty_Loaf"] = (lambda mat, n=_n: build_loaf(n, mat, True), 2600)
