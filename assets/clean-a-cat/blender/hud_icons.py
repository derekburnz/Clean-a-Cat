"""The HUD button pictures (#185): CleanACat_Icon_Hud_<Name>, 512 px, see-through, with a thick ink outline.

    python hud_icons.py <out folder> [--only Index,Coins]

Runs in Blender's Python (bpy). A draft of one of the two blends Derek is comparing (2026-11-24): our look mixed
with his library's HUD icons. Each picture is one bold object you can name at 48 px (ours), built fat with rounded
edges, soft light and a slight three-quarter tilt (his library's; the camera, the two lights and the outline pass are
ported from its icons.py), in Bubble Pastel colours with the UI's ink outline.

  Index     the Cat Index: a purple book with a cream cat's face on the cover and a pink bookmark
  Coins     two fat gold coins with a paw stamped on the top one and a white twinkle
  Settings  a blue grey gear with a cream middle
  Tools     the game's pink scrub brush with soap bubbles
  Helper    the first helper kitten's head in its bath cap
  Build     a blue hammer with a wooden handle and a white paw on its head

Nothing here is a game model and nothing is uploaded: the ui-designer decides what goes into the game.
"""

import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import bpy  # noqa: E402
import numpy as np  # noqa: E402
from mathutils import Euler, Matrix, Vector  # noqa: E402

import common  # noqa: E402
import palette  # noqa: E402
from common import Builder  # noqa: E402

SIZE, PAD = 512, 0.07
INK = (0x45 / 255, 0x22 / 255, 0x6B / 255)     # the UI's ink, #45226B
OUTLINE = 13                                   # px at 512: thick, so the shape holds at 48 px
SOFT = (0.1, 3)                                # bevel width and segments: rounder edges than a game model's
X = (math.radians(90), "X")                    # stands a flat shape up so it faces the camera (-Y)


def _ink_mat():
    """The outline's own colour as a flat, unlit material, for a detail drawn in ink (the book cat's eyes)."""
    m = bpy.data.materials.get("_HudInk")
    if m:
        return m
    m = bpy.data.materials.new("_HudInk")
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (*[palette.srgb_to_linear(c) for c in INK], 1.0)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(em.outputs["Emission"], out.inputs["Surface"])
    return m


def _fin(b, name, mat, tilt=0.0, ink=None):
    """One soft-edged mesh, leaned `tilt` degrees to the right (a tool held at an angle). `ink` is a second
    Builder holding what is drawn flat in the outline's colour."""
    old = common.BEVEL_SEGMENTS
    common.BEVEL_SEGMENTS = SOFT[1]
    try:
        objs = [b.finalize("CleanACat_IconArt_Hud_" + name, mat, bevel=SOFT[0])]
    finally:
        common.BEVEL_SEGMENTS = old
    if ink is not None:
        objs.append(ink.finalize("CleanACat_IconArt_Hud_" + name + "_Ink", _ink_mat(), bevel=0))
    for ob in objs:
        ob.rotation_euler = (0, math.radians(tilt), 0)
    bpy.context.view_layer.update()
    return objs


def _facing(view):
    """The turn that stands a flat shape square to the camera of `view`."""
    return Euler((math.radians(90 - view[1]), 0, math.radians(view[0]))).to_matrix()


def _paw(b, x, y, z, r, swatch, rot=None, depth=0.05):
    """A paw print lying flat at (x, y, z), toes toward +Y: one pad and three toes. `rot` turns it to face out."""
    m = rot or Matrix.Identity(3)
    for dx, dy, k, sc in ((0, -0.42, 1.0, (1.2, 0.9, 1)), (-0.95, 0.5, 0.46, (1, 1, 1)), (0, 0.98, 0.46, (1, 1, 1)),
                          (0.95, 0.5, 0.46, (1, 1, 1))):
        c = Vector((x, y, z)) + m @ Vector((dx * r, dy * r, 0))
        b.cyl(tuple(c), r * k, depth, swatch, segments=14, bevel=False, rot=rot, scale=sc)


def _twinkle(b, x, y, z, r, rot=X):
    """The white four-point twinkle from the library's coin picture: the set's shared highlight."""
    b.star((x, y, z), r, r * 0.3, 0.07, "foam", points=4, rot=rot)


def index(mat):
    """The Cat Index: a closed book standing up, a cat's face on the cover so it is a cat collection and not just
    a book. The eyes are drawn flat in the outline's ink."""
    b, k = Builder(), Builder()
    w, h, d = 1.9, 2.4, 0.6
    b.box((0.1, 0.02, h / 2), (w - 0.14, d - 0.18, h - 0.2), "spa_cream")               # the pages
    b.box((0, d / 2 - 0.05, h / 2), (w, 0.1, h), "velvet_lilac")                        # the back cover
    b.box((0, -d / 2 + 0.05, h / 2), (w, 0.1, h), "velvet_lilac")                       # the front cover
    b.box((-w / 2 + 0.05, 0, h / 2), (0.26, d + 0.06, h + 0.04), "coat_lilac")          # the spine
    fy = -d / 2 - 0.02
    cx, cz = 0.18, 1.1
    b.cyl((cx, fy, cz), 0.64, 0.08, "spa_cream", segments=20, rot=X, scale=(1.0, 0.86, 1.0))   # the face
    for sx in (-1, 1):                                                                   # the ears
        b.prism((cx + sx * 0.38, fy + 0.01, cz + 0.44), [(-0.27, -0.12), (0.27, -0.12), (sx * 0.1, 0.46)], 0.08,
                "spa_cream", rot=X)
        b.prism((cx + sx * 0.37, fy - 0.02, cz + 0.47), [(-0.12, -0.06), (0.12, -0.06), (sx * 0.05, 0.22)], 0.04,
                "nose_bubblegum", rot=X)
        k.box((cx + sx * 0.26, fy - 0.05, cz + 0.05), (0.18, 0.04, 0.3), "coat_inky", bevel=False)   # the eyes
    b.box((cx, fy - 0.05, cz - 0.2), (0.17, 0.04, 0.11), "nose_bubblegum")               # the nose
    b.box((0.5, 0.08, -0.14), (0.26, 0.05, 0.5), "bow_pink")                             # the bookmark
    _twinkle(b, 0.82, fy - 0.02, 2.26, 0.34)
    return _fin(b, "Index", mat, ink=k)


VIEW_COINS = (-14.0, 46.0)


def coins(mat):
    """Two fat gold coins, a paw stamped on the top one."""
    b = Builder()
    for x, y, z in ((-0.22, 0.1, 0.0), (0.14, -0.06, 0.38)):
        b.cyl((x, y, z + 0.18), 1.0, 0.36, "gold_mid", segments=28)
        b.cyl((x, y, z + 0.37), 0.8, 0.04, "gold_light", segments=28, bevel=False)
    _paw(b, 0.14, -0.1, 0.78, 0.36, "gold_dark")
    _twinkle(b, 1.0, 0.5, 1.15, 0.4, rot=_facing(VIEW_COINS))
    return _fin(b, "Coins", mat)


def settings(mat):
    """A gear: eight square teeth, a darker hub and a cream middle."""
    b = Builder()
    b.cyl((0, 0, 0), 0.84, 0.44, "fur_blue", segments=24, rot=X)
    for i in range(8):
        a = math.radians(45 * i)
        b.box((0.94 * math.sin(a), 0, 0.94 * math.cos(a)), (0.46, 0.38, 0.44), "fur_blue", rot=(a, "Y"))
    b.cyl((0, -0.05, 0), 0.45, 0.44, "fur_slate", segments=20, rot=X)
    b.cyl((0, -0.09, 0), 0.22, 0.44, "spa_cream", segments=16, rot=X)
    return _fin(b, "Settings", mat)


def tools(mat):
    """The wash tools: the game's pink scrub brush made fat, with soap bubbles coming off it."""
    b = Builder()
    b.box((0, 0, 1.3), (2.1, 1.3, 0.62), "spa_bubblegum")                                # the back
    for i in (-1, 0, 1):                                                                 # three tufts of bristles
        b.box((i * 0.66, 0, 0.47), (0.56, 1.06, 0.96), "foam")
    b.cyl((1.5, 0, 1.3), 0.36, 0.95, "caramel_wood", segments=14, rot=(math.radians(90), "Y"))   # the handle
    for x, z, r in ((-1.15, 2.3, 0.46), (-0.3, 2.62, 0.28), (0.3, 2.2, 0.18)):           # the bubbles
        b.sphere((x, -0.2, z), r, "spa_sky", segments=14, rings=8)
        b.sphere((x - r * 0.38, -0.2 - r * 0.8, z + r * 0.38), r * 0.26, "foam", segments=8, rings=5)
    return _fin(b, "Tools", mat, tilt=-14)


def build(mat):
    """Build mode: a fat hammer with a wooden handle, a flat face one side, a claw the other and a white paw on
    it."""
    b = Builder()
    b.box((0, 0, 0.8), (0.6, 0.6, 1.6), "caramel_wood")                                  # the handle
    b.box((0, 0, 2.1), (1.5, 0.9, 1.0), "bow_sky")                                       # the head
    b.box((-0.95, 0, 2.1), (0.38, 1.06, 1.2), "bow_sky")                                 # its flat face
    b.prism((1.05, 0, 2.1), [(-0.3, 0.5), (-0.3, -0.5), (0.42, -0.42), (0.42, -0.1)], 0.84, "bow_sky",
            rot=X)                                                                       # the claw
    _paw(b, 0.05, -0.47, 2.06, 0.21, "foam", rot=Matrix.Rotation(math.radians(90), 3, "X"), depth=0.05)
    return _fin(b, "Build", mat, tilt=22)


CAP_ICON = "nose_bubblegum"      # one step deeper than the model's cap cloth, so cap and face part at 48 px (#185)


def helper(mat):
    """The helper: the first helper kitten's own head in its bath cap, so the button shows who you hire."""
    import busy_spa
    look = busy_spa.HELPERS[0]
    objs = busy_spa.ASSETS[look[0]][0](mat)
    busy_spa.HELPERS[0] = look[:3] + (CAP_ICON,) + look[4:]
    try:
        cap = busy_spa._cap(0)(mat)
    finally:
        busy_spa.HELPERS[0] = look
    top = busy_spa.helper_rbx_extras(0)["attachments"][0][2].translation
    for o in cap:
        o.location = o.location + top
    bpy.context.view_layer.update()
    lo, _ = common.bounds([o for o in objs if o.name.endswith("_Head")])
    keep = []
    for o in objs:
        if common.bounds([o])[0].z >= lo.z - 0.02:
            keep.append(o)
        else:
            bpy.data.objects.remove(o, do_unlink=True)
    return keep + cap


BUILDERS = {                                       # name -> (builder, (yaw, pitch))
    "Index": (index, (22.0, 12.0)),
    "Coins": (coins, VIEW_COINS),
    "Settings": (settings, (-16.0, 8.0)),
    "Tools": (tools, (-24.0, 18.0)),
    "Helper": (helper, (-18.0, 8.0)),
    "Build": (build, (-14.0, 8.0)),
}


def _lights():
    """A bright, even studio light from the upper left front, and a white world so the colours stay true."""
    for name in ("_IconKey", "_IconFill"):
        ob = bpy.data.objects.get(name)
        if ob:
            bpy.data.objects.remove(ob, do_unlink=True)
    key = bpy.data.lights.new("_IconKey", "SUN")
    key.energy, key.angle = 2.6, math.radians(10)
    ko = bpy.data.objects.new("_IconKey", key)
    ko.rotation_euler = (math.radians(55), 0, math.radians(-30))
    bpy.context.scene.collection.objects.link(ko)
    fill = bpy.data.lights.new("_IconFill", "SUN")
    fill.energy = 0.8
    fo = bpy.data.objects.new("_IconFill", fill)
    fo.rotation_euler = (math.radians(70), 0, math.radians(40))
    bpy.context.scene.collection.objects.link(fo)
    w = bpy.context.scene.world or bpy.data.worlds.new("World")
    bpy.context.scene.world = w
    w.use_nodes = True
    bg = w.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (1, 1, 1, 1)
    bg.inputs["Strength"].default_value = 0.7


def _camera(objs, view):
    """Orthographic, looking at the model's front (-Y) turned `yaw` degrees about the up axis and tilted `pitch`
    degrees down, framing every vertex with PAD around."""
    yaw, pitch = view
    cd = bpy.data.cameras.get("_IconCam") or bpy.data.cameras.new("_IconCam")
    cam = bpy.data.objects.get("_IconCam") or bpy.data.objects.new("_IconCam", cd)
    if cam.name not in bpy.context.scene.collection.objects:
        bpy.context.scene.collection.objects.link(cam)
    cd.type = "ORTHO"
    cd.clip_start, cd.clip_end = 0.01, 100.0
    cam.rotation_euler = (math.radians(90 - pitch), 0, math.radians(yaw))
    bpy.context.view_layer.update()
    R = cam.rotation_euler.to_matrix()
    right, up, fwd = R @ Vector((1, 0, 0)), R @ Vector((0, 1, 0)), R @ Vector((0, 0, -1))
    pts = [ob.matrix_world @ v.co for ob in objs for v in ob.data.vertices]
    us, vs = [p.dot(right) for p in pts], [p.dot(up) for p in pts]
    cu, cv = (max(us) + min(us)) / 2, (max(vs) + min(vs)) / 2
    cd.ortho_scale = max(max(us) - min(us), max(vs) - min(vs)) * (1 + 2 * PAD)
    cam.location = right * cu + up * cv + fwd * (min(p.dot(fwd) for p in pts) - 10.0)
    bpy.context.scene.camera = cam


def _outline(path, colour, width):
    """Paint a solid outline of `width` pixels behind the picture, from its alpha."""
    img = bpy.data.images.load(path, check_existing=False)
    w, h = img.size
    px = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    px = px.reshape(h, w, 4)
    a = px[:, :, 3]
    grown = a.copy()
    for dy in range(-width, width + 1):
        for dx in range(-width, width + 1):
            if dx * dx + dy * dy <= width * width:
                grown = np.maximum(grown, np.roll(np.roll(a, dy, 0), dx, 1))
    out = np.empty_like(px)
    k = a[:, :, None]
    out[:, :, :3] = px[:, :, :3] * k + np.array(colour, dtype=np.float32) * (1 - k)
    out[:, :, 3] = grown
    img.pixels.foreach_set(out.ravel())
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)


def render_icon(name, mat, out, samples=64):
    build, view = BUILDERS[name]
    common.hide_all_meshes()
    objs = build(mat)
    common.show(objs)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = samples
    sc.cycles.use_denoising = True
    sc.render.resolution_x = sc.render.resolution_y = SIZE
    sc.render.resolution_percentage = 100
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    sc.view_settings.view_transform = "Standard"
    fl = bpy.data.objects.get("_PreviewFloor")
    if fl:
        fl.hide_render = True
    _lights()
    _camera(objs, view)
    os.makedirs(out, exist_ok=True)
    path = os.path.join(out, "CleanACat_Icon_Hud_" + name + ".png")
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    _outline(path, INK, OUTLINE)
    for ob in objs:
        bpy.data.objects.remove(ob, do_unlink=True)
    return path


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    out = argv[0]
    only = argv[argv.index("--only") + 1].split(",") if "--only" in argv else list(BUILDERS)
    common.reset_scene()
    png = os.path.join(HERE, "..", "exports", palette.TEXTURE_NAME + ".png")
    mat = common.palette_material(png)
    for name in only:
        print("icon:", render_icon(name, mat, out))


if __name__ == "__main__":
    main()
