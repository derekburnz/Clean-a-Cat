"""Five of the six HUD button pictures (#185): CleanACat_Icon_Hud_<Name>, 512 px, see-through, with a thick ink
outline.

    python hud_icons.py <out folder> [--only Index,Tools]

Runs in Blender's Python (bpy). The blend the owner picked "for now" (2026-11-24): our look mixed with his
library's HUD icons. Each picture is one bold object you can name at 48 px (ours), built fat with rounded
edges, soft light and a slight three-quarter tilt (his library's; the camera, the two lights and the outline pass are
ported from its icons.py), in Bubble Pastel colours with the UI's ink outline.

  Index     the Cat Index: a purple book with a cream cat's face on the cover and a pink bookmark
  Settings  a blue grey gear with a cream middle
  Tools     a pink toolbox thrown open, a scrub brush standing in it and a soap bottle beside it (the owner asked
            for a toolbox in place of the scrub brush, whose soap bubbles "makes no sense"; shut, it could pass for a
            lunchbox)
  Helper    a member of the human staff: head and shoulders in the spa uniform, the first look in staff.py
  Build     a blue hammer with a wooden handle and a white paw on its head

There is no coin here on purpose. The owner picked his library's own coin picture for the HUD (2026-11-24: "use
library coin ... the other new coin doesn't look as good", the paw on it was done badly), then asked for it to be
re-outlined to match. hud_coin.py does that from the library's CatCafe_Icon_Coins.png; a rebuild here must not bring a
rendered coin back.

Nothing here is a game model and nothing is uploaded: the ui-designer decides what goes into the game.
"""

import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import bpy  # noqa: E402
import numpy as np  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

import common  # noqa: E402
import palette  # noqa: E402
import staff  # noqa: E402
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


def _paw(b, x, y, z, r, swatch, rot=None, depth=0.05):
    """A paw print lying flat at (x, y, z), toes toward +Y: one pad and three toes. `rot` turns it to face out."""
    m = rot or Matrix.Identity(3)
    for dx, dy, k, sc in ((0, -0.42, 1.0, (1.2, 0.9, 1)), (-0.95, 0.5, 0.46, (1, 1, 1)), (0, 0.98, 0.46, (1, 1, 1)),
                          (0.95, 0.5, 0.46, (1, 1, 1))):
        c = Vector((x, y, z)) + m @ Vector((dx * r, dy * r, 0))
        b.cyl(tuple(c), r * k, depth, swatch, segments=14, bevel=False, rot=rot, scale=sc)


def _twinkle(b, x, y, z, r):
    """The white four-point twinkle from the library's coin picture: the set's shared highlight."""
    b.star((x, y, z), r, r * 0.3, 0.07, "foam", points=4, rot=X)


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
    """The wash tools: a fat pink toolbox with its lid thrown open, a scrub brush standing in it with its white
    bristles to the front and a soap bottle with a pump beside it, a gold latch and a white paw. (The first draft was
    a scrub brush with soap bubbles; the owner: "the bubbles on the back of brush makes no sense ... a toolbox would
    be better". Shut, the toolbox could pass for a lunchbox at 48 px (Review-QA, #234), so #242 opened it. On a phone
    the button is about 36 pt, where a brush lying inside the box blurred into it, so #247 stood the brush up to
    break the outline.) Nothing may poke through the lid: it opens 50 degrees, so its front edge is behind the tools."""
    b = Builder()
    w, d = 2.4, 1.4
    b.box((0, 0, 0.62), (w, d, 1.24), "spa_bubblegum")                                   # the box
    up = Matrix.Rotation(math.radians(-50), 3, "X")                                      # the lid, hinged at the back
    hinge = Vector((0, d / 2 + 0.07, 1.26))

    def lid(c, size, swatch):
        b.box(tuple(hinge + up @ (Vector(c) - hinge)), size, swatch, rot=up)

    lid((0, 0, 1.54), (w + 0.14, d + 0.14, 0.56), "nose_bubblegum")
    for sx in (-1, 1):                                                                   # the handle, on the lid
        lid((sx * 0.62, 0, 2.0), (0.24, 0.3, 0.44), "spa_cream")
    lid((0, 0, 2.28), (1.7, 0.36, 0.26), "spa_cream")
    b.box((0, -d / 2 - 0.1, 0.9), (0.5, 0.14, 0.5), "gold_mid")                          # the latch
    _paw(b, 0, -d / 2 - 0.02, 0.36, 0.17, "foam", rot=Matrix.Rotation(math.radians(90), 3, "X"), depth=0.05)
    lean = Matrix.Rotation(math.radians(-20), 3, "Y") @ Matrix.Rotation(math.radians(10), 3, "X")
    foot = Vector((-0.72, -0.4, 0.9))                                                    # a scrub brush standing at

    def brush(c, size, swatch):                                                          # the left end, leaning out
        b.box(tuple(foot + lean @ Vector(c)), size, swatch, rot=lean)

    brush((0, 0, 0.7), (0.3, 0.26, 1.4), "spa_sky")                                      # its handle,
    brush((0, 0, 1.8), (0.86, 0.34, 1.0), "spa_sky")                                     # its back
    brush((0, -0.22, 1.8), (0.72, 0.2, 0.84), "foam")                                    # and its bristles
    b.cyl((0.6, -0.38, 1.75), 0.3, 1.1, "spa_mint", segments=14)                         # a soap bottle and its pump
    b.cyl((0.6, -0.38, 2.42), 0.12, 0.26, "spa_cream", segments=12)
    b.box((0.52, -0.46, 2.6), (0.42, 0.2, 0.14), "spa_cream")
    return _fin(b, "Tools", mat)


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


def helper(mat):
    """The helper: a person on the spa's staff. The owner, 2026-11-24: "helpers are likely going to be staff like
    humans", then a split: human staff do the washing and the kitten stays as the mascot. A chunky head and shoulders
    of the first staff look in staff.py, in the same uniform as the staff portraits (mint smock, cream collar, paw
    name badge, no hat). The kitten head this button had before is in git history (#211)."""
    _, skin, hair, _, blush = staff.LOOKS[0]
    b, k = Builder(), Builder()
    b.box((0, 0, 0.5), (2.2, 1.2, 0.68), staff.SMOCK)                                    # the smock's shoulders
    b.box((0, 0, 0.86), (1.8, 1.3, 0.12), staff.TRIM)                                    # its collar and two points
    for sx in (-1, 1):
        b.prism((sx * 0.3, -0.62, 0.6), [(-0.28, 0.2), (0.0, -0.22), (0.28, 0.2)], 0.08, staff.TRIM, rot=X)
    b.box((0.76, -0.61, 0.47), (0.48, 0.06, 0.36), staff.TRIM)                           # the name badge
    _paw(b, 0.76, -0.65, 0.46, 0.11, staff.BADGE_PAW, rot=Matrix.Rotation(math.radians(90), 3, "X"), depth=0.04)
    b.box((0, 0, 1.62), (1.5, 1.4, 1.5), skin)                                           # the head
    b.box((0, 0, 2.36), (1.7, 1.6, 0.42), hair)                                          # hair: top, swept fringe,
    b.prism((0, -0.79, 2.12), [(-0.9, 0.22), (-0.9, -0.3), (0.9, -0.02), (0.9, 0.22)], 0.14, hair, rot=X)
    for sx in (-1, 1):                                                                   # a lock each side, sides,
        b.box((sx * 0.72, -0.7, 1.5), (0.3, 0.24, 1.1), hair)
        b.box((sx * 0.8, 0.08, 1.58), (0.14, 1.46, 1.26), hair)
    b.box((0, 0.78, 1.6), (1.7, 0.14, 1.3), hair)                                        # back
    b.sphere((0, 0.4, 2.62), 0.44, hair, segments=10, rings=6)                           # and a bun
    fy = -0.72
    for sx in (-1, 1):
        k.box((sx * 0.3, fy, 1.6), (0.19, 0.04, 0.34), "coat_inky", bevel=False)         # the eyes
        b.box((sx * 0.3 + 0.04, fy - 0.03, 1.7), (0.07, 0.04, 0.09), "foam", bevel=False)
        b.box((sx * 0.44, fy, 1.27), (0.2, 0.04, 0.11), blush, bevel=False)              # the cheeks
        k.box((sx * 0.21, fy, 1.24), (0.09, 0.04, 0.09), "coat_inky", bevel=False)       # the smile's corners
    k.box((0, fy, 1.15), (0.42, 0.04, 0.09), "coat_inky", bevel=False)                   # the smile
    return _fin(b, "Helper", mat, ink=k)


BUILDERS = {                                       # name -> (builder, (yaw, pitch))
    "Index": (index, (22.0, 12.0)),
    "Settings": (settings, (-16.0, 8.0)),
    "Tools": (tools, (-24.0, 20.0)),
    "Helper": (helper, (-18.0, 10.0)),
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
