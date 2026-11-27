"""Store art renders (issue #24): the raw 3D shots behind the icon and thumbnail options, from the real models.

    python3 assets/clean-a-cat/blender/store_art.py <out folder> [--final]

Each shot is a PNG with a see-through background and the models' shadows kept (the floor is a shadow catcher), so
`store_compose.py` (plain Python with Pillow) can lay it over a bright backdrop and add the words. Draft renders are
small; `--final` renders the picked options at 1024 (icon, scaled to 512) and 1920 by 1080.

Rules from the issue: show the action of the first minute (a muddy cat turning clean and fluffy under a sponge), only
Common cats a new player meets early, the cat never cropped, nothing uploaded. Nothing here is exported.

The second set (#106, after the design was locked on 2026-11-25): drafts for the owner to pick alternates from. These
also show what the locked design added: the special visitors' cats, the three workers at their wash stands and the
stray in his box from the opening. No crate, price or Robux item is in any picture.
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
from common import RB, Builder  # noqa: E402

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


TUFTS = False     # no tangle clumps and no fluff puffs in store art. The owner, 2026-11-26, on icon E: "fix the sides
                  # of E having orange sticking out the side of the model", then on thumbnail 3: "the cats still have
                  # the random skin sticking out their sides". At picture size both read as flaps, not fur.


def cat_state(name, mat, body, state, at=(0, 0, 0), k=1.0, rot_z=0.0):
    """A roster cat: state 'dirty', 'half' (mud gone on its left, +X), 'clean' or 'plain' (no dirt). With TUFTS on,
    a dirty side also has its tangles and a clean side its fluff ('plain' never has fluff). Claws never show here."""
    objs, _, _ = dirt.build_dirty(name, mat, body)
    keep = []
    bpy.context.view_layer.update()
    for o in objs:
        n = o.name
        cleanside = _centre(o).x > 0.02
        if "_Claw" in n:
            _remove(o)
            continue
        if not TUFTS and ("_Tangle" in n or "_Fluff" in n):
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
    tub = _fresh(stations.build_tub(mat, grow=False))
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


# ------------------------------------------------------------------ the claw-foot bath (store art only)
# Derek's own Bathtub Sofa from his asset library (Roblox-Asset-Library, crate_decor.build_bathtub_sofa), the tub of
# the ad picture he picked as the look (2026-11-23), filled as a bath: the same sky blue tub with a gold band,
# painted bubbles, a rolled white rim and gold claw feet, the brass tap, the rain shower, the rubber duck and the
# striped towel over the front. Its three cushions hang as towels on a brass rail behind and its bolster is a
# rolled towel on the rim. Roblox axes (RB): x across, y up, -z the front.
BATH_K = 1.3                      # the tub drawn this much bigger, so a 1.5 times cat sits in it with room
BATH_CX, BATH_RIM, BATH_WATER = 0.9, 1.96, 1.99


def _stadium(b, cx, y0, y1, r, sw, segments=20):
    """A tub-shaped slab from y0 to y1: a box between two round ends centred at x = +-cx. The box keeps a hair
    inside the ends all round, so no two faces share a plane."""
    b.span((-cx, y0 + 0.002, -r + 0.003), (cx, y1 - 0.002, r - 0.003), sw)
    for sx in (-1, 1):
        b.cyl((sx * cx, (y0 + y1) / 2, 0), r, y1 - y0, sw, segments=segments)


def _limb(b, p0, p1, r0, r1, sw, segments=8):
    a, c = Vector(p0), Vector(p1)
    d = c - a
    turn = Vector((0, 1, 0)).rotation_difference(d.normalized()).to_matrix()
    b.b.cyl(RB.p(*((a + c) / 2)), r0, d.length, sw, segments=segments, bevel=False, rot=RB._rot(turn), radius2=r1)


def _arc(b, cx, cy, z, r, a0, a1, n, w, d, sw):
    step = math.radians(abs(a1 - a0) / n)
    length = 2 * r * math.sin(step / 2) * 1.06
    for k in range(n):
        t = math.radians(a0 + (a1 - a0) * (k + 0.5) / n)
        b.box((cx + r * math.cos(t), cy + r * math.sin(t), z), (length, w, d), sw,
              rot=Matrix.Rotation(t + math.pi / 2, 3, "Z"))


def _rubber_duck(b, x, y, z, s, sw):
    """A rubber duck sitting on y, looking toward -Z."""
    b.ball((x, y + 0.2 * s, z + 0.03 * s), 0.27 * s, sw, scale=(1.0, 0.75, 1.2))
    b.ball((x, y + 0.46 * s, z - 0.12 * s), 0.17 * s, sw)
    b.box((x, y + 0.43 * s, z - 0.3 * s), (0.15 * s, 0.06 * s, 0.12 * s), "fur_orange")
    for sx in (-1, 1):
        b.cyl((x + sx * 0.075 * s, y + 0.51 * s, z - 0.28 * s), 0.03 * s, 0.03 * s, "fur_black", axis="Z", segments=6)
    b.ball((x, y + 0.33 * s, z + 0.33 * s), 0.08 * s, sw, scale=(1.0, 1.3, 1.0))


def _hung(b, x0, x1, rail_y, z, drop, sw, stripes=None):
    """A towel folded over a rail or a rim at height rail_y and depth z: a long front fall and a short back one."""
    b.span((x0, rail_y, z - 0.07), (x1, rail_y + 0.04, z + 0.07), sw)
    b.span((x0, rail_y - drop, z - 0.07), (x1, rail_y, z - 0.03), sw)
    b.span((x0, rail_y - drop * 0.45, z + 0.03), (x1, rail_y, z + 0.07), sw)
    for k in (stripes or ()):
        a, c = x0 + (x1 - x0) * k / 5, x0 + (x1 - x0) * (k + 1) / 5
        b.span((a, rail_y - drop - 0.004, z - 0.078), (c, rail_y + 0.035, z - 0.03), "offwhite")
        b.span((a, rail_y + 0.035, z - 0.078), (c, rail_y + 0.048, z + 0.078), "offwhite")


def clawfoot_bath(mat):
    """The bath of the ad picture, scaled by BATH_K: (objects, the water's height in studs)."""
    b, wat, duck = RB(), RB(), RB()
    CX = BATH_CX
    _stadium(b, CX, 0.45, 1.0, 0.76, "pastel_sky")                                       # the tub, flaring out
    _stadium(b, CX, 0.98, 1.84, 0.85, "pastel_sky")
    _stadium(b, CX, 0.96, 1.04, 0.87, "gold_mid")                                         # a gold band at the flare
    _stadium(b, CX, 1.82, BATH_RIM, 0.93, "offwhite")                                     # the rolled rim
    for k, (x, y, r) in enumerate(((0.28, 1.48, 0.12), (0.52, 1.24, 0.07), (0.7, 1.6, 0.08), (0.42, 1.74, 0.05),
                                   (0.8, 1.3, 0.06), (1.05, 1.52, 0.09), (-0.95, 1.36, 0.1), (-1.2, 1.62, 0.06))):
        b.cyl((x, y, -0.86), r, 0.03, ("offwhite", "fish_belly")[k % 2], axis="Z", segments=16)   # painted bubbles
    for sx in (-1, 1):                                                                     # claw feet
        for sz in (-1, 1):
            b.span((sx * 1.12 - 0.12, 0.5, sz * 0.62 - 0.1), (sx * 1.12 + 0.12, 0.72, sz * 0.62 + 0.1), "gold_mid")
            _limb(b, (sx * 1.12, 0.55, sz * 0.62), (sx * 1.3, 0.2, sz * 0.72), 0.08, 0.06, "gold_mid")
            b.ball((sx * 1.32, 0.13, sz * 0.74), 0.15, "gold_mid", scale=(1.15, 0.9, 1.15))
            for k in (-1, 0, 1):                                                           # three toes
                a = math.atan2(sz * 0.74, sx * 1.32) + 0.5 * k
                b.cyl((sx * 1.32 + 0.15 * math.cos(a), 0.06, sz * 0.74 + 0.15 * math.sin(a)), 0.05, 0.12,
                      "gold_dark", segments=6)
    _stadium(wat, CX, BATH_RIM - 0.02, BATH_WATER, 0.79, "water")                         # full to the brim
    _hung(b, -0.95, -0.05, BATH_RIM, -0.86, 0.72, "mint", stripes=(1, 3))                 # the striped towel
    for k in range(6):                                                                    # its fringe
        x = -0.95 + 0.08 + k * (0.9 - 0.16) / 5
        b.span((x - 0.025, BATH_RIM - 0.84, -0.935), (x + 0.025, BATH_RIM - 0.71, -0.915), "offwhite")
    b.cyl((-1.5, BATH_RIM + 0.2, 0.0), 0.2, 0.7, "sign_teal", axis="Z", segments=16)      # a rolled towel on the rim
    for sz in (-1, 1):
        b.cyl((-1.5, BATH_RIM + 0.2, sz * 0.36), 0.15, 0.02, "offwhite", axis="Z", segments=16)
    # the brass gooseneck tap on the rim and its two handles
    tx = 1.72
    b.cyl((tx, 1.99, 0), 0.12, 0.06, "brass", segments=12)
    b.cyl((tx, 2.35, 0), 0.06, 0.72, "brass", segments=10)
    _arc(b, tx - 0.2, 2.7, 0, 0.2, 0, 180, 7, 0.1, 0.1, "brass")
    b.cyl((tx - 0.4, 2.62, 0), 0.055, 0.16, "brass", segments=10)
    for sz, cap in ((-1, "shirt_blue"), (1, "shirt_red")):
        b.cyl((tx, 2.2, sz * 0.12), 0.04, 0.14, "brass", axis="Z", segments=6)
        b.box((tx, 2.2, sz * 0.2), (0.22, 0.04, 0.04), "brass")
        b.box((tx, 2.2, sz * 0.2), (0.04, 0.22, 0.04), "brass")
        b.cyl((tx, 2.2, sz * 0.23), 0.04, 0.03, cap, axis="Z", segments=6)
    # the rain shower: a brass stand behind the tap end, its rose over the bath
    lx, lz = 1.7, 1.05
    b.cyl((lx, 0.04, lz), 0.2, 0.08, "brass", segments=12)
    top = 3.62                                                                            # shorter than the sofa's lamp
    b.cyl((lx, top / 2 + 0.02, lz), 0.055, top - 0.04, "brass", segments=10)
    b.ball((lx, top, lz), 0.08, "brass")
    _limb(b, (lx, top, lz), (1.5, top - 0.04, 0.12), 0.055, 0.05, "brass")
    b.cyl((1.5, top - 0.16, 0.12), 0.06, 0.2, "brass", segments=10)
    b.cyl((1.5, top - 0.3, 0.12), 0.36, 0.1, "brass", r2=0.12, segments=20)
    # a brass towel rail behind the tub with three towels (the ad picture's cushions)
    ry, rz = 3.05, 1.12
    for x in (0.3, -1.95):
        b.cyl((x, 0.04, rz), 0.16, 0.08, "brass", segments=12)
        b.cyl((x, ry / 2, rz), 0.05, ry, "brass", segments=10)
        b.ball((x, ry + 0.02, rz), 0.08, "brass")
    b.cyl((-0.825, ry, rz), 0.045, 2.25, "brass", axis="X", segments=10)
    for x, sw in ((-0.2, "mint"), (-0.85, "pastel_butter"), (-1.5, "blush")):
        _hung(b, x - 0.29, x + 0.29, ry + 0.045, rz, 0.95, sw)
    _rubber_duck(duck, 0, 0, 0, 0.55, "pastel_butter")
    objs = [b.finalize("StoreBath", mat), wat.finalize("StoreBath_Water", mat),
            duck.finalize("StoreBath_Duck", mat, location=(1.25, BATH_WATER - 0.03, -0.3))]
    for o in objs:
        common.scale_mesh(o, BATH_K)
        o.location = o.location * BATH_K
    return _fresh(objs), BATH_WATER * BATH_K


def spa_scene(mat, name="Muffin"):
    """The store art's scene (Derek 2026-11-23): the bath of his ad picture with a clean Muffin sitting in it: the
    claw-foot tub, the striped towel over the rim, towels on a rail, the duck, lather and soap bubbles. The cat is
    plain (no fluff, no bow), so its ears and face read at a glance. No mud. `name` puts another cat in the bath
    (#106: a special visitor's cat). Returns (objects, the cat, the water's height)."""
    tub, wz = clawfoot_bath(mat)
    cx = -0.3                                             # the cat sits left of the middle, as in the ad picture
    cat = cat_state(name, mat, "sit", "plain", (cx, 0.12, wz - 0.48), TUB_K)
    objs = tub + cat
    lo, hi = common.bounds(cat)
    fm = Builder()                                        # lather round the cat, the water open in front of it
    for x, y, r in ((cx - 0.95, 0.45, 0.4), (cx + 0.95, 0.4, 0.46), (cx + 0.8, -0.4, 0.3), (cx - 0.8, -0.35, 0.28),
                    (1.55, 0.25, 0.42), (cx + 1.5, -0.05, 0.34)):
        stations.foam_mound(fm, x, y, wz - 0.02, r)
    for x, y, z, r in ((cx - 0.9, 0.5, 0.2, 0.2), (cx + 1.0, 0.45, 0.22, 0.22), (cx + 0.75, -0.35, 0.14, 0.15),
                       (1.5, 0.3, 0.2, 0.2), (cx + 1.45, 0.0, 0.16, 0.16), (cx - 0.72, -0.32, 0.14, 0.13)):
        stations.foam_bubble(fm, x, y, wz + z, r)
    objs += _fresh([common.shade_smooth(fm.finalize("Foam", mat, bevel=0))])
    objs += floating(mat, [(cx - 0.3, lo.y - 0.28, wz + 0.2, 0.2), (cx + 0.35, lo.y - 0.4, wz + 0.15, 0.14),      # on the water
                           (-1.1, -0.75, wz + 0.2, 0.17), (1.3, -0.5, wz + 0.22, 0.2),
                           (cx + 1.55, lo.y - 0.2, hi.z - 1.1, 0.24),   # drifting up
                           (cx + 1.15, lo.y - 0.3, hi.z + 0.1, 0.15), (2.1, -0.6, hi.z - 0.2, 0.2),
                           (1.9, -0.7, hi.z - 1.6, 0.13)])
    return objs, cat, wz


def thumb_spa_close(mat, out, res, name="Prism"):
    """The bath close, the whole frame (#106): the cat on the right two thirds up the frame, the tub's rim, tap, duck
    and lather round it and the tub running out of the frame's foot and right edge. The title goes on the left."""
    objs, cat, wz = spa_scene(mat, name)
    lo, hi = common.bounds(cat)
    cx = (lo.x + hi.x) / 2
    top = hi.z + 0.15
    focus = (Vector((cx - 5.0, lo.y, top - 4.2)), Vector((cx + 2.4, lo.y + 0.4, top)))
    return render(objs, focus, out, res, az=14, el=13, margin=0.9, lens=55)


def thumb_spa(mat, out, res, name="Muffin"):
    """The store thumbnail: the whole bath, blown up."""
    objs, _cat, _wz = spa_scene(mat, name)
    focus = [o for o in objs if "Bubbles" not in o.name]     # the drifting bubbles may leave the frame
    return render(objs, focus, out, res, az=20, el=20, margin=1.06, lens=55)


def icon_spa(mat, out, res, name="Muffin"):
    """The store icon: the same scene, close on the cat, so its face fills about half the square at search size
    (Review-QA on #116: icons win clicks on a face, not on a scene). The tub's rim, the lather and the bubbles
    frame it. A special cat's head piece makes it taller, so its picture starts higher, at the lather (#106)."""
    objs, cat, wz = spa_scene(mat, name)
    lo, hi = common.bounds(cat)
    low = wz - 0.5 if name in cats.ROSTER else wz + 0.15
    focus = (Vector((lo.x - 0.3, lo.y, low)), Vector((hi.x + 0.3, lo.y + 0.4, hi.z + 0.05)))
    return render(objs, focus, out, res, az=12, el=14, margin=1.0, lens=60)


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


def _face_mud(mat, cat):
    """Mud on the muddy half of the face, for the split thumbnail only (Review-QA on #500). In the game mud stays
    off the face so the cat reads while it is washed; in this picture a clean face weakens the split. Flat stepped
    splats in the model's two mud shades on the cat's right (-X) half: over the brow, down the temple beside the eye,
    across the cheek under it, and a smear on the ear. The eye stays clear. No two patches overlap."""
    part = {k: next(o for o in cat if o.name.endswith(k)) for k in ("_Head", "_Eye2", "_EarR")}
    (hlo, hhi), (elo, ehi), (rlo, rhi) = (common.bounds([part[k]]) for k in ("_Head", "_Eye2", "_EarR"))
    y, t = hlo.y - 0.012, 0.035                           # just proud of the face
    b = Builder()

    def patch(x0, x1, z0, z1, sw="mud", proud=0.0):
        b.box(((x0 + x1) / 2, y - proud, (z0 + z1) / 2), (x1 - x0, t, z1 - z0), sw, bevel=False)

    xe, top, bot = hlo.x + 0.012, hhi.z - 0.015, hlo.z + 0.02    # the face's outer edge, top and bottom
    c = 0.07                                               # one step of a splat
    patch(xe, -0.07, top - c, top)                                         # the brow: three steps in from the corner
    patch(xe, -0.14, top - 2 * c, top - c)
    patch(xe, elo.x - 0.03, top - 3 * c, top - 2 * c)
    patch(-0.21, -0.15, top - 2 * c - 0.09, top - 2 * c)                   # a short drip over the eye
    patch(xe, elo.x - 0.035, elo.z + 0.03, top - 3 * c)                    # down the temple beside the eye
    patch(xe, elo.x + 0.02, elo.z - 0.05, elo.z + 0.03)                    # round under its corner
    patch(xe, ehi.x - 0.05, bot + c, elo.z - 0.05)                         # the cheek: two steps
    patch(elo.x + 0.02, ehi.x - 0.05, elo.z - 0.05, elo.z - 0.012)         # and up to the eye, over the round cheek (#771)
    patch(xe + 0.05, ehi.x + 0.02, bot, bot + c)
    patch(xe + 0.07, xe + 0.22, top - 0.115, top - 0.05, "mud_wet", 0.006)  # wet shine
    patch(xe + 0.06, xe + 0.18, bot + 0.075, bot + 0.125, "mud_wet", 0.006)
    ex = (rlo.x + rhi.x) / 2                              # outer edge; its outline stays a cat's ear
    b.box((ex - 0.075, rlo.y - 0.008, rlo.z + 0.14), (0.1, 0.03, 0.2), "mud", bevel=False)    # a smear up the ear's
    return _fresh([b.finalize("FaceMud", mat, bevel=0)])


BOW_K = 0.85        # the split's bow is a little smaller than the game's, so all of it clears the dividing line


def _split(mat, out, res, state):
    """One half of the split thumbnail (#500): Muffin sitting, seen straight on and close, with the camera on its
    middle line. `state` 'dirty' is the whole cat muddy, 'clean' the whole cat clean with a bow by its ear, lather
    at its foot and a few bubbles. Both use the same camera (framed on a fixed box round the cat), so
    `store_compose.py` takes the left half of the picture from one and the right half from the other and they meet on
    the cat's middle line. Things that belong to one half only are built on that half: the cat's left (+X) is the
    picture's right."""
    cat = cat_state("Muffin", mat, "sit", state)
    # The owner, 2026-11-26, on the icon made from these halves: "fix the sides of E having orange sticking out the
    # side of the model". Those were the tufts: the matted tangles on the muddy half and the fluff on the clean half
    # stand out past the head's outline and read as stray orange lumps at this crop. The split shows the cat's own
    # outline only; mud, the bow, lather and bubbles tell the two halves apart.
    for o in [o for o in cat if "_Tangle" in o.name or "_Fluff" in o.name]:
        cat.remove(o)
        _remove(o)
    body = [o for o in cat if "_Mud" not in o.name]
    lo, hi = common.bounds(body)
    half = max(-lo.x, hi.x) + 0.5
    focus = (Vector((-half, lo.y, 0.0)), Vector((half, hi.y, hi.z + 0.4)))
    objs = list(cat)
    if state == "dirty":
        objs += _face_mud(mat, cat)
    if state == "clean":
        spec = cats.ROSTER["Muffin"]
        k = cats.scale_of(spec, "sit")
        # The owner, 2026-11-26: "angle the bow to the top right of head so it doesn't get cutoff by line". It sat by
        # the ear and the line cut its inner loop. Now it sits on the head's top corner on the clean half, a little
        # smaller and tipped so its outer loop drops past the corner, all of it on the clean half.
        bow_spot, bow_tip = cats.bow_side(spec, "sit")              # the game's own spot and tip (#764)
        at = Vector(cats.joints(spec, "sit")["Head"]) + Vector(bow_spot) * k
        bow = props.build_bow(list(props.BOWS)[0], mat)
        turn = (Matrix.Translation(at) @ Matrix.Rotation(math.radians(bow_tip), 4, "Y")
                @ Matrix.Rotation(math.radians(-8), 4, "Z") @ Matrix.Scale(BOW_K, 4))
        for o in bow:
            o.matrix_world = turn @ o.matrix_basis
        objs += _fresh(bow)
        fm = Builder()
        for x, y, r in ((hi.x + 0.12, -0.3, 0.24), (hi.x + 0.3, 0.05, 0.2)):
            stations.foam_mound(fm, x, y, -0.02, r)
        stations.foam_bubble(fm, hi.x + 0.16, -0.25, 0.2, 0.14)
        objs += _fresh([common.shade_smooth(fm.finalize("Foam", mat, bevel=0))])
        objs += floating(mat, [(hi.x + 0.28, -0.5, 0.62, 0.13), (hi.x + 0.2, -0.4, 1.35, 0.09)])
    return render(objs, focus, out, res, az=0, el=6, margin=1.0, lens=70)


def split_dirty(mat, out, res):
    """The split thumbnail's muddy half (#500)."""
    return _split(mat, out, res, "dirty")


def split_clean(mat, out, res):
    """The split thumbnail's clean half (#500)."""
    return _split(mat, out, res, "clean")


SHOTS = {
    "icon-a": (icon_scrub, (512, 512), (1024, 1024)),
    "icon-b": (icon_face, (512, 512), (1024, 1024)),
    "icon-c": (icon_clean, (512, 512), (1024, 1024)),
    "thumb-1": (thumb_scrub, (960, 540), (1920, 1080)),
    "thumb-2": (thumb_before_after, (960, 540), (1920, 1080)),
    "thumb-3": (thumb_queue, (960, 540), (1920, 1080)),
    "thumb-spa": (thumb_spa, (900, 900), (1600, 1600)),
    "icon-spa": (icon_spa, (512, 512), (1024, 1024)),
    "split-dirty": (split_dirty, (700, 860), (1400, 1720)),
    "split-clean": (split_clean, (700, 860), (1400, 1720)),
}


# ------------------------------------------------------------------ the second set (#106)
def box_scene(mat, lift=0.72):
    """The opening's hook: the muddy stray (Suds, before his wash) looking out of the plain brown box that fell off
    the truck, its flaps open. `lift` is how far over the box's floor he is held. Returns (objects, the cat, the
    box's rim height)."""
    import opening
    box = opening.build_box(mat)
    bpy.context.view_layer.update()
    for o in box:
        for kind, (axis, sign) in opening.FLAP_TURN.items():
            if o.name.endswith("_Flap" + kind):
                o.matrix_world = o.matrix_world @ Matrix.Rotation(math.radians(sign * opening.FLAP_OPEN), 4, axis)
    cat = cat_state("Suds", mat, "sit", "dirty", (0, 0.1, opening.BOX_SEAT + lift))
    return _fresh(box) + cat, cat, opening.RIM


def icon_box(mat, out, res):
    """Icon: the muddy stray's face over the rim of his box. He stands higher than in the thumbnail and the camera
    is low, so his dark head is against the backdrop and not the box's shaded inside, and the face is about half the
    square (Review-QA on #106)."""
    objs, cat, rim = box_scene(mat, lift=1.12)
    lo, hi = common.bounds([o for o in cat if "_Mud" not in o.name and "_Tangle" not in o.name])
    focus = (Vector((lo.x - 0.08, lo.y, rim - 0.22)), Vector((hi.x + 0.08, lo.y + 0.4, hi.z + 0.06)))
    return render(objs, focus, out, res, az=12, el=7, margin=1.0, lens=60)


def thumb_box(mat, out, res):
    """Thumbnail: the stray in his box, close and to the right, the whole frame: the box runs out of the frame's
    foot and its left flap lies under the title."""
    objs, cat, rim = box_scene(mat)
    lo, hi = common.bounds([o for o in cat if "_Mud" not in o.name and "_Tangle" not in o.name])
    focus = (Vector((-3.3, -1.2, rim - 0.6)), Vector((1.35, 1.2, hi.z + 0.15)))
    return render(objs, focus, out, res, az=16, el=17, margin=0.86, lens=55)


LINEUP = ("Rosette", "Prism", "Phoenix", "Sherbet", "Bathtile")
LINEUP_AT = ((-3.25, 1.3, 1.0), (-1.72, 0.55, 1.14), (0.0, -0.35, 1.34), (1.72, 0.55, 1.14), (3.25, 1.3, 1.0))   # x, y, scale


def thumb_lineup(mat, out, res):
    """Thumbnail: five special visitors' cats in a wedge, the middle one in front and biggest, each a step back and
    smaller to the sides, bubbles drifting over them. The collection, at a glance."""
    objs = []
    for name, (x, y, k) in zip(LINEUP, LINEUP_AT):
        objs += cat_state(name, mat, "sit", "plain", (x, y, 0), k, rot_z=-5 * x)
    lo, hi = common.bounds(objs)
    drift = floating(mat, [(-4.4, 0.4, 2.3, 0.2), (4.5, 0.5, 2.6, 0.18), (-2.5, -0.4, 0.35, 0.14),
                           (2.55, -0.4, 0.3, 0.15), (4.7, 0.2, 0.5, 0.17), (-4.75, 0.2, 0.7, 0.15),
                           (-0.95, -1.0, 0.22, 0.12), (1.0, -1.0, 0.2, 0.11)])
    focus = (Vector((lo.x - 0.3, lo.y, 0.0)), Vector((hi.x + 0.3, hi.y, hi.z + 0.1)))
    return render(objs + drift, focus, out, res, az=0, el=8, margin=1.0, lens=70)


BUSY = (("Lou", "Cotton", "dirty"), ("Sam", "Muffin", "half"), ("Jo", "Sherbet", "plain"))


def _stand_no_pole(ws, who, mat):
    """A wash stand without a standing shower. Jo's shower pole read as a long rod held up beside a person, and the
    image gate fails any long rounded shape (Review-QA, 2026-11-27), so the store art leaves it out. The plant and
    the shelf stay."""
    look = ws.LOOKS[who]
    keep = look["tall"]
    if keep != "shower":
        return ws.build_stand(who, mat, grow=False)
    ws.TALLS["_none"] = lambda _b, _top_b, _sw: None
    look["tall"] = "_none"
    try:
        return ws.build_stand(who, mat, grow=False)
    finally:
        look["tall"] = keep
        del ws.TALLS["_none"]


def _staff_sleeved(spa_staff, who, mat):
    """The staff for the store art: arms hanging straight at their sides in long smock sleeves that cover the hands,
    so no hand and no bare forearm shows (image gate: no hands and no skin tone blobs, Review-QA 2026-11-27). The
    game's staff keep their short sleeves and hands."""
    import townsfolk
    look = dict(spa_staff.LOOKS[who], short_sleeves=None, gloves=spa_staff.SMOCK)
    return townsfolk.build_figure(spa_staff.PREFIX + who, look, mat, carry=False)


def thumb_busy(mat, out, res):
    """Thumbnail: the busy spa. The three wash stands in front, each with a cat a step further along: a muddy one,
    one half washed and one clean. No bow on the clean cat: the owner, 2026-11-26, on a sky Royal bow tried there,
    "remove the giant blue bow that appeared on pink cats head". The workers stand behind and between the stands,
    facing the camera, so the cats are the biggest things in the frame (Review-QA on #106: with the staff beside the
    cats it read as a game about people)."""
    import spa_staff
    import worker_stations as ws
    objs = []
    for i, (who, cat, state) in enumerate(BUSY):
        x = (i - 1) * 4.7
        stand = [o for o in _stand_no_pole(ws, who, mat) if not o.name.endswith("_Barrier")]
        _move(stand, (x, 0, 0))
        objs += _fresh(stand)
        objs += cat_state(cat, mat, "sit", state, (x + ws.BX, ws.BY, ws.SEAT), TUB_K)
        staff = _staff_sleeved(spa_staff, who, mat)
        _move(staff, (x + 2.25, 3.4, 0), 1.0, -6 * (i - 1))
        objs += _fresh(staff)
    lo, hi = common.bounds(objs)
    drift = floating(mat, [(-6.6, -1.6, 3.4, 0.22), (-2.4, -2.2, 3.9, 0.18), (2.3, -2.2, 4.2, 0.2),
                           (6.6, -1.4, 1.6, 0.2), (-2.5, -2.4, 0.9, 0.16), (2.2, -2.4, 0.8, 0.15)])
    focus = (Vector((lo.x + 0.2, -2.0, 0.0)), Vector((hi.x - 0.9, 1.0, hi.z - 0.15)))
    return render(objs + drift, focus, out, res, az=4, el=11, margin=1.0, lens=38)


SHOTS.update({
    "icon-box": (icon_box, (512, 512), (1024, 1024)),
    "thumb-box": (thumb_box, (1280, 720), (1920, 1080)),
    "thumb-lineup": (thumb_lineup, (1500, 620), (3000, 1240)),
    "thumb-busy": (thumb_busy, (1500, 700), (3000, 1400)),
})
# the same bath with a special visitor's cat in it, one icon and one thumbnail a cat
for _name in cats.SPECIAL_CATS:
    SHOTS[f"icon-spa-{_name}"] = (lambda mat, out, res, n=_name: icon_spa(mat, out, res, n), (512, 512), (1024, 1024))
    SHOTS[f"thumb-spa-{_name}"] = (lambda mat, out, res, n=_name: thumb_spa(mat, out, res, n), (900, 900), (1600, 1600))
    SHOTS[f"thumb-close-{_name}"] = (lambda mat, out, res, n=_name: thumb_spa_close(mat, out, res, n), (1280, 720),
                                     (1920, 1080))


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
