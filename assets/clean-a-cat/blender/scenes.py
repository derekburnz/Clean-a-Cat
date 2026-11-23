"""Scene pictures for the owner and for review: models from this folder posed together, next to a stand-in Roblox
avatar (a blocky R15 shape, 5 studs tall) for scale. Not assets: nothing here is exported.

    python3 assets/clean-a-cat/blender/scenes.py tub   docs/concepts/clean-a-cat/2026-11-23-tub-scene.png
    python3 assets/clean-a-cat/blender/scenes.py groom docs/concepts/clean-a-cat/2026-11-23-groom-sheet.png
"""

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import bpy  # noqa: E402,F401
from mathutils import Vector  # noqa: E402

import cats  # noqa: E402
import common  # noqa: E402
import dirt  # noqa: E402
import palette  # noqa: E402
import props  # noqa: E402
import stations  # noqa: E402
import tools  # noqa: E402
from common import Builder  # noqa: E402


def avatar(mat, at=(0.0, 0.0, 0.0)):
    """A plain blocky avatar, R15 proportions: legs 2, torso 1.6, head 1.2 studs; front -Y."""
    b = Builder()
    for sx in (1, -1):
        b.box_base((sx * 0.5, 0, 0), (0.95, 0.95, 2.0), "shirt_blue")
        b.box_base((sx * 1.5, 0, 2.0), (0.95, 0.95, 1.6), "skin_tan")
    b.box_base((0, 0, 2.0), (1.95, 0.95, 1.6), "shirt_green")
    b.box_base((0, 0, 3.6), (1.15, 1.15, 1.15), "skin_tan")
    return b.finalize("Avatar", mat, location=at)


def _move(objs, offset, k=1.0):
    for o in objs:
        o.location = o.location * k + Vector(offset)
        if k != 1.0:
            common.scale_mesh(o, k)


def _drop(objs, suffixes):
    keep = []
    for o in objs:
        if any(s in o.name for s in suffixes):
            bpy.data.objects.remove(o, do_unlink=True)
        else:
            keep.append(o)
    return keep


def tub(mat, out):
    objs = stations.build_tub(mat)
    cat, _, _ = dirt.build_dirty("Smudge", mat, "sit")
    _move(cat, (0, 0, stations.SEAT_Z), 1.5)            # the game shows the cat at ScaleTo(1.5) at the tub
    sp = tools.build_sponge("CleanACat_Tool_Sponge", mat)
    _move(sp, (1.3, -1.3, 2.6))
    common.render_preview(objs + cat + sp, out, res=(900, 640), samples=24, azimuth=25, elevation=28)


def groom(mat, out, name="Smudge", close=False):
    """Left to right: an avatar, the rinsed cat with its tangles, fluffed after the brush, and with each bow."""
    spec = cats.ROSTER[name]
    k = cats.scale_of(spec, "sit")
    bow = Vector(cats.joints(spec, "sit")["Head"]) + Vector(cats.bow_at(spec, "sit")) * k
    allo = [] if close else [avatar(mat, (-2.2, 0.4, 0.0))]
    stages = [("tangled", None), ("fluffed", None)] + [("bow", n) for n in props.BOWS]
    for i, (stage, bow_name) in enumerate(stages):
        objs, _, _ = dirt.build_dirty(name, mat, "sit")
        objs = _drop(objs, ["_Mud"] + (["_Tangle"] if stage != "tangled" else ["_Fluff"]))
        for o in objs:
            o.hide_render = False                       # the fluff ships hidden
        if bow_name:
            b = props.build_bow(bow_name, mat)
            _move(b, bow, k)
            objs += b
        _move(objs, (i * 1.7, 0, 0))
        for o in objs:
            o.name = f"S{i}_{o.name}"                   # free the names for the next copy (dirt finds pieces by name)
        allo += objs
    tool = tools.build_brush(mat)
    _move(tool, (1.7 * 0.5, -1.0, 0.4))
    allo += tool
    common.render_preview(allo, out, res=(1400, 560) if not close else (1400, 420), samples=24, azimuth=12,
                          elevation=14)


def shot(objs, path, eye, target, lens=24, res=(960, 600), samples=24, hide=()):
    """Render objs from a camera at `eye` looking at `target` (Blender coordinates), lit like the previews."""
    import math
    sc = bpy.context.scene
    common.render_preview(objs[:1], path, res=(8, 8), samples=1)   # sets up the floor, lights and render settings
    cam = sc.camera
    cam.data.lens = lens
    cam.location = Vector(eye)
    cam.rotation_euler = (Vector(target) - Vector(eye)).to_track_quat("-Z", "Y").to_euler()
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.cycles.samples = samples
    for ob in sc.objects:
        if ob.type == "MESH" and not ob.name.startswith("_"):
            ob.hide_render = ob not in objs or any(h in ob.name for h in hide)
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    del math


def plot_views(mat, out_dir):
    """The graybox plot (#15) dressed with the tub, a cat in it, the player at the spawn, three customers in the queue
    with cats, a stray in its box and cats on the window cushions: from the entrance, the player's spot, outside
    on the street and top-down."""
    import math
    import plot
    from mathutils import Matrix
    allo = plot.build_plot(mat)
    F = plot.FLOOR

    def at(spot):
        x, y, z, turn = plot.SPOTS[spot]
        return Vector((x, y, F + z)), turn

    def place(objs, spot, lift=0.0, k=1.0, turn=None):
        p, t = at(spot)
        t = t if turn is None else turn
        R = Matrix.Rotation(math.radians(t), 4, "Z")
        for o in objs:
            o.matrix_world = Matrix.Translation(p + Vector((0, 0, lift))) @ R @ Matrix.Scale(k, 4) @ o.matrix_world
        return objs

    n = [0]

    def fresh(objs):                                   # free the names so the next copy builds clean
        n[0] += 1
        for o in objs:
            o.name = f"V{n[0]}_{o.name}"
        return objs

    allo += fresh(place(stations.build_tub(mat), "SpotTub"))
    cat, _, _ = dirt.build_dirty("Smudge", mat, "sit")
    allo += fresh(place(cat, "SpotTub", lift=stations.SEAT_Z, k=1.5))
    allo += fresh(place([avatar(mat)], "SpotSpawn"))
    for i, name in enumerate(("Muffin", "Patches", "Toffee"), start=1):
        allo += fresh(place([avatar(mat)], f"SpotQueue{i}"))
        c, _, _ = dirt.build_dirty(name, mat, "walk")
        for o in c:
            o.location += Vector((0.0, -0.9, 0.0))     # held out in front, at the chest
        allo += fresh(place(c, f"SpotQueue{i}", lift=2.4))
    s, _, _ = dirt.build_dirty("Inky", mat, "sit")
    allo += fresh(place(s, "SpotStray"))
    for i, name in enumerate(("Cotton", "Marble", "LilacCloud", "Tux"), start=1):
        allo += fresh(place(cats.build_cat(name, mat, body="sit"), f"SpotWindow{i}"))
    os.makedirs(out_dir, exist_ok=True)
    views = {
        "entrance": dict(eye=(11.0, -12.0, F + 9.5), target=(-4.0, 2.0, F + 1.0), lens=20),
        "player": dict(eye=(-5.0, -16.0, F + 8.5), target=(-5.0, -2.0, F + 1.5), lens=22),
        "street": dict(eye=(-14.0, -46.0, F + 9.0), target=(-2.0, -12.0, F + 4.0), lens=28),
        "top": dict(eye=(0.0, -6.0, 80.0), target=(0.0, -0.5, 0.0), lens=30),
    }
    made = []
    for key, v in views.items():
        path = os.path.join(out_dir, f"2026-11-23-plot-graybox-{key}.png")
        hide = ("_Roof",) if key in ("top", "player", "entrance") else ("_Glass",)   # Roblox draws the glass 0.6 clear
        shot(allo, path, v["eye"], v["target"], v["lens"], hide=hide)
        made.append(path)
    del math
    return made


if __name__ == "__main__":
    which, out = sys.argv[-2], sys.argv[-1]
    common.reset_scene()
    png = os.path.join(HERE, "..", "exports", palette.TEXTURE_NAME + ".png")
    mat = common.palette_material(png)
    {"tub": tub, "groom": groom, "groom-close": lambda m, o: groom(m, o, close=True), "plot": plot_views}[which](mat, out)
