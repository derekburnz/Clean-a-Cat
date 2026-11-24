"""Store art renders (issue #24): the raw 3D shots behind the icon and thumbnail options, from the real models.

    python3 assets/clean-a-cat/blender/store_art.py <out folder> [--final]

Each shot is a PNG with a see-through background and the models' shadows kept (the floor is a shadow catcher), so
`store_compose.py` (plain Python with Pillow) can lay it over a bright backdrop and add the words. Draft renders are
small; `--final` renders the picked options at 1024 (icon, scaled to 512) and 1920 by 1080.

Rules from the issue: show the action of the first minute (a muddy cat turning clean and fluffy under a sponge), only
Common cats a new player meets early, the cat never cropped, nothing uploaded. Nothing here is exported.
"""

import math
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

import common  # noqa: E402
import dirt  # noqa: E402
import palette  # noqa: E402
import props  # noqa: E402
import cats  # noqa: E402
import spa_props  # noqa: E402
import stations  # noqa: E402
import tools  # noqa: E402
from common import Builder  # noqa: E402

TUB_K = 1.5                       # the cat's ScaleTo at the tub
stations.DETAIL = {"ball": (24, 14), "mound": (24, 10)}   # a close picture: round balls, as Roblox draws them
_n = [0]


def _fresh(objs):
    """Give the objects unique names, so the next copy of a cat can be built (dirt finds pieces by name)."""
    _n[0] += 1
    for o in objs:
        o.name = f"A{_n[0]}_{o.name}"
    return objs


def _move(objs, offset, k=1.0, rot_z=0.0):
    r = Matrix.Rotation(math.radians(rot_z), 3, "Z")
    for o in objs:
        if k != 1.0:
            common.scale_mesh(o, k)
        o.location = r @ (o.location * k) + Vector(offset)
        o.rotation_euler.z += math.radians(rot_z)


def _centre(o):
    lo, hi = common.bounds([o])
    return (lo + hi) / 2


def _remove(o):
    bpy.data.objects.remove(o, do_unlink=True)


def cat_state(name, mat, body, state, at=(0, 0, 0), k=1.0, rot_z=0.0):
    """A roster cat: state 'dirty', 'half' (mud and tangles gone on its left, +X, where the fluff shows), 'clean'
    (fluffed) or 'plain' (no dirt, no fluff). Claws never show here."""
    objs, _, _ = dirt.build_dirty(name, mat, body)
    keep = []
    bpy.context.view_layer.update()
    for o in objs:
        n = o.name
        cleanside = _centre(o).x > 0.02
        if "_Claw" in n:
            _remove(o)
            continue
        if "_Mud" in n or "_Tangle" in n:
            if state in ("clean", "plain") or (state == "half" and cleanside):
                _remove(o)
                continue
        if "_Fluff" in n:
            if state == "clean" or (state == "half" and cleanside):
                o.hide_render = False
            else:
                _remove(o)
                continue
        keep.append(o)
    _move(keep, at, k, rot_z)
    return _fresh(keep)


def bubbles(mat, spots, seed=3):
    """Soap foam: at each spot (x, y, z, size) a tidy pile of round bubbles (stations.foam_pile, the game's foam),
    drawn finer and smooth for a picture. `seed` turns the piles differently from shot to shot."""
    rnd = random.Random(seed)
    b = Builder()
    for x, y, z, s in spots:
        stations.foam_pile(b, x, y, z - 0.45 * s, 0.6 * s, ring=4, turn=rnd.uniform(0, 6.28), segments=24, rings=14)
    return _fresh([common.shade_smooth(b.finalize("Foam", mat, bevel=0))])


def floating(mat, spots):
    """Loose soap bubbles (x, y, z, radius): clear, each with a white glint (stations.soap_bubble, the game's)."""
    b = Builder()
    for x, y, z, r in spots:
        stations.soap_bubble(b, x, y, z, r)
    return _fresh([common.shade_smooth(b.finalize("Bubbles", mat, bevel=0))])


SHOULDER_Z, ARM = 3.35, 1.75


def avatar(mat, at, face_deg, skin="skin_tan", shirt="spa_bubblegum", pants="shirt_blue", reach=-100.0):
    """A blocky R15 shape (legs 2, torso 1.6, head 1.2 studs) facing `face_deg` (0 = -Y), its right arm (-X local)
    raised forward `reach` degrees about the shoulder. Returns (objects, hand position in world space)."""
    b = Builder()
    for sx in (1, -1):
        b.box_base((sx * 0.5, 0, 0), (0.95, 0.95, 2.0), pants)
    b.box_base((1.5, 0, 2.0), (0.95, 0.95, 1.6), skin)                        # the left arm hangs
    b.box_base((0, 0, 2.0), (1.95, 0.95, 1.6), shirt)
    b.box_base((0, 0, 3.6), (1.15, 1.15, 1.15), skin)
    sh = Vector((-1.5, 0, SHOULDER_Z))
    rot = Matrix.Rotation(math.radians(reach), 3, "X")
    down = rot @ Vector((0, 0, -1))
    b.box(tuple(sh + down * 0.8), (0.95, 0.95, 1.6), skin, rot=rot)           # the right arm reaches
    hand = sh + down * ARM
    ob = b.finalize("Avatar", mat)
    r = Matrix.Rotation(math.radians(face_deg), 3, "Z")
    ob.location = Vector(at)
    ob.rotation_euler.z = math.radians(face_deg)
    return _fresh([ob]), Vector(at) + r @ hand


def scrubber(mat, target, face_deg, **look):
    """An avatar standing on the floor whose right hand is at `target`."""
    reach = -math.degrees(math.acos(max(-1.0, min(1.0, (SHOULDER_Z - target.z) / ARM))))
    probe, hand = avatar(mat, (0, 0, 0), face_deg, reach=reach, **look)
    _remove(probe[0])
    off = hand.copy()
    off.z = 0.0
    return avatar(mat, Vector((target.x, target.y, 0.0)) - off, face_deg, reach=reach, **look)[0]


def sponge(mat, at, rot_z=0.0, tilt=0.0):
    sp = tools.build_sponge("CleanACat_Tool_Sponge", mat)
    for o in sp:
        o.rotation_euler.x += math.radians(tilt)
    _move(sp, at, 1.0, rot_z)
    return _fresh(sp)


# ------------------------------------------------------------------ framing and render
def render(show, focus, path, res, az, el, margin=1.1, lens=50, lift=0.0, samples=32):
    """Render `show` with the camera framed on `focus` (objects or a (lo, hi) box); see-through background with the
    shadows kept on a shadow catcher floor."""
    sc = bpy.context.scene
    common.render_preview(show[:1], path, res=(8, 8), samples=1)              # floor, lights and render settings
    fl = bpy.data.objects.get("_PreviewFloor")
    lo_all, _ = common.bounds([o for o in show if not o.hide_render or "_Fluff" in o.name])
    fl.location.z = min(0.0, lo_all.z) - 0.001
    fl.hide_render = False
    fl.is_shadow_catcher = True
    sc.render.film_transparent = True
    lo, hi = focus if isinstance(focus, tuple) else common.bounds(focus)
    centre = (lo + hi) / 2 + Vector((0, 0, lift))
    a, e = math.radians(az), math.radians(el)
    size = hi - lo
    half_w = (abs(size.x * math.cos(a)) + abs(size.y * math.sin(a))) / 2          # the box as the camera sees it
    depth = abs(size.y * math.cos(a)) + abs(size.x * math.sin(a))
    half_h = (size.z * math.cos(e) + depth * math.sin(e)) / 2
    cam = sc.camera
    cam.data.lens = lens
    cam.data.sensor_fit = "AUTO"
    aspect = res[0] / res[1]
    fov = cam.data.angle                                                            # across the longer side
    half = max(half_w, half_h * aspect) if aspect >= 1 else max(half_w / aspect, half_h)
    d = Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e)))
    dist = half * margin / math.tan(fov / 2) + depth / 2
    cam.location = centre + d * dist
    cam.rotation_euler = (centre - cam.location).to_track_quat("-Z", "Y").to_euler()
    cam.data.clip_end = max(dist * 4, 500.0)
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.cycles.samples = samples
    for ob in sc.objects:
        if ob.type == "MESH" and not ob.name.startswith("_"):
            ob.hide_render = ob not in show
    sc.render.filepath = path
    common.render_still()
    sc.render.film_transparent = False
    fl.is_shadow_catcher = False
    return path


def clear(mat):
    for ob in list(bpy.context.scene.objects):
        if ob.type == "MESH" and not ob.name.startswith("_"):
            _remove(ob)


# ------------------------------------------------------------------ the shots
def tub_scene(mat, name="Smudge", state="half", with_sponge=True, foam=True):
    """The wash tub with a 1.5 scale cat in it, a sponge on its clean cheek and foam on the clean side."""
    tub = _fresh(stations.build_tub(mat))
    cat = cat_state(name, mat, "sit", state, (0, 0, stations.SEAT_Z), TUB_K)
    objs = tub + cat
    lo, hi = common.bounds(cat)
    head_z = hi.z - 0.55
    if with_sponge:
        objs += sponge(mat, (hi.x - 0.5, lo.y - 0.12, head_z - 0.7), rot_z=-25, tilt=-15)
    if foam:
        objs += bubbles(mat, [(hi.x - 0.35, lo.y + 0.1, head_z - 1.25, 0.45),
                              (hi.x - 0.1, lo.y + 0.5, head_z + 0.35, 0.3),
                              (0.4, lo.y + 0.25, stations.SEAT_Z + 0.95, 0.5),
                              (1.0, lo.y + 0.1, stations.SEAT_Z + 0.75, 0.42)])
        objs += floating(mat, [(hi.x + 0.45, lo.y - 0.3, head_z + 0.4, 0.2),
                               (hi.x + 0.75, lo.y - 0.1, head_z + 1.0, 0.14),
                               (hi.x + 0.3, lo.y - 0.5, head_z + 1.45, 0.1)])
    return objs, cat, tub


def icon_scrub(mat, out, res):
    """Icon A: close on the cat in the tub, half muddy, the sponge on its clean cheek, foam."""
    objs, cat, _ = tub_scene(mat)
    lo, hi = common.bounds(cat)
    focus = (Vector((lo.x - 0.25, lo.y, hi.z - 2.3)), Vector((hi.x + 0.25, lo.y + 0.3, hi.z + 0.1)))
    return render(objs, focus, out, res, az=-10, el=12, margin=1.08, lens=60)


def icon_face(mat, out, res):
    """Icon B: the cat's head and chest filling the frame, straight on, half muddy and half clean, the sponge."""
    cat = cat_state("Muffin", mat, "sit", "half")
    lo, hi = common.bounds(cat)
    sp = sponge(mat, (0, 0, 0), rot_z=-30, tilt=-15)
    for o in sp:
        common.scale_mesh(o, 0.6)
    _move(sp, (hi.x - 0.12, lo.y + 0.05, hi.z - 0.62))
    objs = cat + sp
    objs += bubbles(mat, [(hi.x - 0.2, lo.y + 0.1, hi.z - 0.95, 0.22)], seed=5)
    objs += floating(mat, [(hi.x + 0.2, lo.y - 0.2, hi.z - 0.25, 0.1), (hi.x + 0.32, lo.y - 0.1, hi.z + 0.05, 0.07)])
    return render(objs, objs, out, res, az=-8, el=8, margin=1.06, lens=70)


def icon_clean(mat, out, res):
    """Icon C: the whole cat, clean and fluffy with a bow, sitting in a pile of foam in the tub, bubbles rising."""
    objs, cat, tub = tub_scene(mat, name="Cotton", state="clean", with_sponge=False, foam=False)
    spec = cats.ROSTER["Cotton"]
    k = cats.scale_of(spec, "sit")
    bow = props.build_bow(list(props.BOWS)[0], mat)
    at = Vector(cats.joints(spec, "sit")["Head"]) + Vector(cats.bow_at(spec, "sit")) * k
    _move(bow, Vector((0, 0, stations.SEAT_Z)) + at * TUB_K, TUB_K)
    objs += _fresh(bow)
    lo, hi = common.bounds(cat)
    top = stations.SEAT_Z + 0.9
    objs += bubbles(mat, [(-0.9, lo.y + 0.2, top, 0.5), (0.9, lo.y + 0.2, top, 0.5),
                          (0.0, lo.y - 0.05, top - 0.1, 0.45),
                          (-1.3, 0.3, top + 0.05, 0.45), (1.3, 0.3, top + 0.05, 0.45)], seed=7)
    objs += floating(mat, [(-1.4, lo.y - 0.3, hi.z - 0.4, 0.22), (1.5, lo.y - 0.2, hi.z - 0.1, 0.18),
                           (1.15, lo.y - 0.4, hi.z + 0.5, 0.12), (-1.1, lo.y - 0.2, hi.z + 0.45, 0.13)])
    tlo, thi = common.bounds(tub)
    focus = (Vector((lo.x - 0.9, lo.y, thi.z - 0.6)), Vector((hi.x + 0.9, lo.y + 0.4, hi.z + 0.5)))
    return render(objs, focus, out, res, az=-10, el=14, margin=1.14, lens=55)


def thumb_spa(mat, out, res):
    """The store thumbnail Derek picked the look of (2026-11-23): the whole tub, a clean fluffy Muffin with a bow in a
    pile of foam, a striped towel over the rim, the sponge on the rim and bubbles rising. No mud."""
    objs, cat, tub = tub_scene(mat, name="Muffin", state="clean", with_sponge=False, foam=False)
    spec = cats.ROSTER["Muffin"]
    k = cats.scale_of(spec, "sit")
    bow = props.build_bow(list(props.BOWS)[0], mat)
    at = Vector(cats.joints(spec, "sit")["Head"]) + Vector(cats.bow_at(spec, "sit")) * k
    _move(bow, Vector((0, 0, stations.SEAT_Z)) + at * TUB_K, TUB_K)
    objs += _fresh(bow)
    lo, hi = common.bounds(cat)
    tlo, thi = common.bounds(tub)
    top = stations.SEAT_Z + 0.9
    # lather hugging the cat's sides and back, the water left open in front of it
    objs += bubbles(mat, [(1.3, lo.y + 0.5, top, 0.5), (1.5, 0.55, top + 0.05, 0.45)], seed=11)
    wz = stations.WATER_Z
    objs += floating(mat, [(-0.7, lo.y - 0.3, wz + 0.2, 0.24), (0.1, lo.y - 0.4, wz + 0.14, 0.16),      # on the water
                           (0.75, lo.y - 0.15, wz + 0.3, 0.26), (-1.55, -0.6, wz + 0.2, 0.2),
                           (-2.6, lo.y - 0.9, hi.z - 1.6, 0.3), (2.1, lo.y - 0.2, hi.z - 0.3, 0.28),    # drifting up
                           (1.5, lo.y - 0.4, hi.z + 0.7, 0.18), (-1.4, lo.y - 0.2, hi.z + 0.5, 0.22),
                           (0.4, lo.y - 0.3, hi.z + 1.1, 0.15), (-2.4, 0.2, hi.z + 0.1, 0.16)])
    rim = stations.RIM_Z + 0.14                           # the top of the rim's cap
    tw = Builder()                                        # a mint towel with white stripes over the front rim
    x, w = 1.25, 1.0
    tw.box((x, tlo.y + 0.25, rim + 0.05), (w, 0.62, 0.08), "spa_mint", bevel=False)
    tw.box((x, tlo.y - 0.03, rim - 0.52), (w, 0.08, 1.22), "spa_mint", bevel=False)
    for dx in (-0.26, 0.26):
        tw.box((x + dx, tlo.y - 0.08, rim - 0.52), (0.12, 0.04, 1.22), "offwhite", bevel=False)
    objs += _fresh([tw.finalize("Towel", mat, bevel=0)])
    objs += bubbles(mat, [(tlo.x + 0.4, tlo.y + 0.4, rim + 0.2, 0.4)], seed=13)
    focus = cat + [o for o in tub if not o.name.endswith("_Bubbles")]     # the drifting bubbles may leave the frame
    return render(objs, focus, out, res, az=-20, el=21, margin=1.1, lens=55)


def thumb_scrub(mat, out, res):
    """Thumbnail 1: an avatar at the tub scrubbing a half muddy cat with the sponge, foam and bubbles."""
    objs, cat, tub = tub_scene(mat, with_sponge=False)
    lo, hi = common.bounds(cat)
    target = Vector((hi.x + 0.05, lo.y + 0.35, hi.z - 1.1))
    objs += scrubber(mat, target, -90) + sponge(mat, target, rot_z=-30, tilt=-15)
    return render(objs, objs, out, res, az=-18, el=12, margin=1.0, lens=50)


def thumb_before_after(mat, out, res):
    """Thumbnail 2: the same cat muddy on the left and clean, fluffy and bowed on the right, sponge and brush between
    (the arrow and the words go on in store_compose.py)."""
    left = cat_state("Muffin", mat, "sit", "dirty", (-1.9, 0, 0), 1.0, rot_z=-12)
    right = cat_state("Muffin", mat, "sit", "clean", (1.9, 0, 0), 1.0, rot_z=12)
    spec = cats.ROSTER["Muffin"]
    k = cats.scale_of(spec, "sit")
    at = Vector(cats.joints(spec, "sit")["Head"]) + Vector(cats.bow_at(spec, "sit")) * k
    bow = props.build_bow(list(props.BOWS)[1], mat)
    _move(bow, Matrix.Rotation(math.radians(12), 3, "Z") @ at + Vector((1.9, 0, 0)), 1.0, 12)
    objs = left + right + _fresh(bow)
    sp = sponge(mat, (-0.25, -0.6, 0.12), rot_z=20)
    br = tools.build_brush(mat)
    _move(br, (0.35, -0.75, 0.08), 1.0, -30)
    objs += sp + _fresh(br)
    objs += floating(mat, [(0.0, -0.4, 1.0, 0.12), (0.25, -0.5, 1.35, 0.08)])
    return render(objs, objs, out, res, az=0, el=10, margin=1.15, lens=50)


def thumb_queue(mat, out, res):
    """Thumbnail 3: the spa at work: the player scrubbing a half clean cat at the tub, two customers lined up on queue
    mats to the left with Common cats in carriers at their feet."""
    objs, cat, tub = tub_scene(mat, with_sponge=False)
    lo, hi = common.bounds(cat)
    target = Vector((hi.x + 0.05, lo.y + 0.35, hi.z - 1.1))
    objs += scrubber(mat, target, -90) + sponge(mat, target, rot_z=-30, tilt=-15)
    looks = (("Inky", "skin_light", "spa_mint"), ("Cotton", "skin_deep", "spa_sky"))
    for i, (cat_name, skin, shirt) in enumerate(looks):
        x, y = -5.0 - 3.4 * i, -1.6 - 0.4 * i
        qm = spa_props.build_queue_mat(mat)
        _move(qm, (x, y, 0))
        cu, _ = avatar(mat, (x, y, 0), 80, skin=skin, shirt=shirt, pants="shirt_blue", reach=0)
        car = spa_props.build_carrier(mat)
        _move(car, (x + 0.2, y - 1.9, 0))
        c = cat_state(cat_name, mat, "walk", "dirty", (x + 0.2, y - 1.9 + 0.06, spa_props.TRAY_H), spa_props.CAT_SCALE)
        objs += _fresh(qm) + cu + _fresh(car) + c
    return render(objs, objs, out, res, az=4, el=12, margin=0.98, lens=45)


SHOTS = {
    "icon-a": (icon_scrub, (512, 512), (1024, 1024)),
    "icon-b": (icon_face, (512, 512), (1024, 1024)),
    "icon-c": (icon_clean, (512, 512), (1024, 1024)),
    "thumb-1": (thumb_scrub, (960, 540), (1920, 1080)),
    "thumb-2": (thumb_before_after, (960, 540), (1920, 1080)),
    "thumb-3": (thumb_queue, (960, 540), (1920, 1080)),
    "thumb-spa": (thumb_spa, (900, 900), (1600, 1600)),
}


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    final = "--final" in args
    args = [a for a in args if a != "--final"]
    out_dir = args[0]
    only = args[1].split(",") if len(args) > 1 else list(SHOTS)
    os.makedirs(out_dir, exist_ok=True)
    common.reset_scene()
    png = os.path.join(HERE, "..", "exports", palette.TEXTURE_NAME + ".png")
    mat = common.palette_material(png)
    for key in only:
        fn, draft, big = SHOTS[key]
        clear(mat)
        fn(mat, os.path.join(out_dir, f"raw-{key}.png"), big if final else draft)
        print("SHOT", key)
