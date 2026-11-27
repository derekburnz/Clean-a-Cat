"""Pictures for the Robux shop's cards (#1030), and the helpers' portraits (#1036). Pictures only, never exported.

    blender python: ui_renders.py <raw folder> --only shop_,portrait_Staff_

Derek's playtest, 2026-11-27: the shop's pictures "kinda suck and suck at selling it". Each card's picture now shows
what the player gets, big and at once:

  shop_Coins2x       two stacks of gold coins (a star on each, no money sign) with a big "2x"; drawn by buy_art.py
  shop_Coins3x       a chest of coins with "3x"; buy_art.py too (#1122: the two heaps here read as one picture)
  shop_Builder2      the builder in his hard hat and dungarees with his toolbox, and "+1": a second build at once
  shop_GoldenSponge  the golden sponge with sparkles round it
  shop_ExtraWorker   Lou, the extra worker, with "+1" (never Jo's picture)
  shop_PetSlot2      two pets side by side with "+1": room for a second pet

The words are thick white letters with an ink rim, like the shop's new price text, so they read on any card. The
people are the smooth busts of staff_busts.py (no hands, Review-QA's image gate); the sponge, the toolbox and the
pets are the game's own models. ui_compose.py trims each to 512 px and grows the ink outline all round.
"""

import math
import os
import random

import bpy
from mathutils import Matrix, Vector

import common
import palette
import pets
import staff_busts

VIEW = (18, 14)                  # azimuth and elevation, degrees: nearly face on, so the words read straight
WHITE, RIM, STAR = "milk", "fur_ink", "pastel_butter"
FONTS = ("/usr/share/fonts/opentype/inter/Inter-ExtraBold.otf",       # a heavy face where the machine has one,
         "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf")       # else Blender's own


def _font():
    for path in FONTS:
        if os.path.exists(path):
            return bpy.data.fonts.load(path, check_existing=True)
    return None


def _swatch_uv(me, swatch):
    u, v = palette.uv_center(palette.idx(swatch))
    while me.uv_layers:                                # a text mesh comes with its own UVs: one map, one swatch
        me.uv_layers.remove(me.uv_layers[0])
    uv = me.uv_layers.new(name="UVMap")
    for loop in uv.data:
        loop.uv = (u, v)


def _text(s, size, swatch, mat, offset=0.0, depth=0.18, name="CleanACat_Word"):
    """Thick standing letters centred on the origin, facing -Y, as a mesh in one swatch."""
    cu = bpy.data.curves.new(name, "FONT")
    cu.body = s
    font = _font()
    if font:
        cu.font = font
    cu.size, cu.extrude, cu.offset = size, depth, offset
    cu.bevel_depth, cu.bevel_resolution = 0.03 * size, 2
    cu.align_x, cu.align_y = "CENTER", "CENTER"
    tmp = bpy.data.objects.new(name + "_tmp", cu)
    bpy.context.scene.collection.objects.link(tmp)
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(tmp.evaluated_get(dg))
    bpy.data.objects.remove(tmp, do_unlink=True)
    bpy.data.curves.remove(cu)
    me.transform(Matrix.Rotation(math.pi / 2, 4, "X"))                # stand up: the letters' front to -Y
    _swatch_uv(me, swatch)
    me.materials.append(mat)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def word(s, size, at, mat, turn=None):
    """White letters on a thicker ink copy of themselves, facing the camera, centred at `at`."""
    turn = math.radians(VIEW[0]) if turn is None else turn
    face = _text(s, size, WHITE, mat, name="CleanACat_Word_" + s)
    rim = _text(s, size, RIM, mat, offset=0.075 * size, depth=0.1, name="CleanACat_WordRim_" + s)
    rot = Matrix.Rotation(turn, 4, "Z")
    back = rot @ Vector((0, 1, 0))
    for ob, push in ((face, 0.0), (rim, 0.06 * size)):
        ob.matrix_world = Matrix.Translation(Vector(at) + back * push) @ rot
    return [face, rim]


def sparkle(b, at, size, swatch=STAR, turn=None):
    """A four point twinkle standing up toward the camera."""
    turn = math.radians(VIEW[0]) if turn is None else turn
    rot = Matrix.Rotation(turn, 3, "Z") @ Matrix.Rotation(math.pi / 2, 3, "X")
    b.star(at, size, size * 0.3, size * 0.16, swatch, points=4, rot=rot)


def _coin(b, at, tilt=(0.0, 0.0), yaw=0.0):
    """One thick gold coin with a raised pale face and a star on it. No money sign: Review-QA's gate (#1030)
    keeps real-money symbols off a Robux card's picture."""
    rot = Matrix.Rotation(yaw, 3, "Z") @ Matrix.Rotation(tilt[0], 3, "X") @ Matrix.Rotation(tilt[1], 3, "Y")
    c = Vector(at)
    up = rot @ Vector((0, 0, 1))
    b.cyl(tuple(c), 0.5, 0.16, "gold_mid", segments=28, rot=rot)
    b.cyl(tuple(c + up * 0.085), 0.4, 0.02, "gold_light", segments=28, bevel=False, rot=rot)
    b.star(tuple(c + up * 0.105), 0.27, 0.12, 0.03, "gold_dark", rot=rot)


def coins(mat, mult):
    """A mound of coins, bigger for 3x, and the multiplier in front of it."""
    rng = random.Random(7 * mult)
    R, H, n = (1.5, 0.9, 48) if mult == 2 else (1.9, 1.35, 84)
    b = common.Builder()
    objs = []
    placed = []
    for i in range(n * 4):
        if len(placed) >= n:
            break
        r, a = R * math.sqrt(rng.random()), rng.random() * 2 * math.pi
        x, y = r * math.cos(a), r * math.sin(a) * 0.8
        z = H * max(0.0, 1 - (r / R) ** 2) * rng.uniform(0.75, 1.0) + 0.08
        if any((x - px) ** 2 + (y - py) ** 2 + 4 * (z - pz) ** 2 < 0.2 for px, py, pz in placed):
            continue
        placed.append((x, y, z))
        slope = 2 * H * r / (R * R)
        tilt = (math.atan(slope) * math.sin(a) * -0.8 + rng.uniform(-0.15, 0.15),
                math.atan(slope) * math.cos(a) * 0.8 + rng.uniform(-0.15, 0.15))
        _coin(b, (x, y, z), tilt, rng.random() * math.pi)
    fill = common.Builder()                            # the heap's inside, so no gap shows between the coins
    fill.sphere((0, 0, 0.0), 1.0, "gold_mid", segments=24, rings=12, scale=(R * 0.8, R * 0.64, H * 0.85))
    for x in (-0.95 * R, 0.95 * R):                     # two coins standing on edge, faces to the camera
        _coin(b, (x, -R * 0.55, 0.5), (math.pi / 2 - 0.25, 0.0), math.radians(VIEW[0]) + rng.uniform(-0.2, 0.2))
    if mult == 3:                                      # 3x: two tall stacks behind the heap as well
        for x, k in ((-R * 0.55, 7), (R * 0.6, 9)):
            for j in range(k):
                _coin(b, (x + rng.uniform(-0.04, 0.04), R * 0.45, 0.1 + 0.17 * j), (0.0, 0.0), rng.random() * math.pi)
    objs += [b.finalize("CleanACat_Coins", mat), fill.finalize("CleanACat_CoinsFill", mat, bevel=0)]
    objs += word(f"{mult}x", 1.6 if mult == 2 else 1.8, (R * 0.5, -R - 0.2, 0.5), mat)
    s = common.Builder()
    sparkle(s, (-R * 0.7, -0.4, H + 0.7), 0.32)
    sparkle(s, (R * 0.25, -0.2, H + 0.45), 0.22, WHITE)
    objs.append(s.finalize("CleanACat_Sparkles", mat, bevel=0))
    return objs


def golden_sponge(mat, makers):
    objs = makers["CleanACat_Tool_SpongeGolden"][0](mat)
    bpy.context.view_layer.update()
    lo, hi = common.bounds(objs)
    w, h = hi.x - lo.x, hi.z - lo.z
    s = common.Builder()
    for (fx, fz, k, sw) in ((-0.62, 0.95, 0.34, WHITE), (0.66, 0.78, 0.26, STAR), (0.52, 0.05, 0.2, WHITE),
                            (-0.5, 0.15, 0.16, STAR), (0.05, 1.18, 0.18, STAR)):
        sparkle(s, ((lo.x + hi.x) / 2 + fx * w, lo.y - 0.2, lo.z + fz * h), k * max(w, h) * 0.6, sw)
    return objs + [s.finalize("CleanACat_Sparkles", mat, bevel=0)]


def person(mat, name, extra=None):
    """A bust with "+1" at its shoulder: one more of them."""
    objs = staff_busts.build_bust(name, mat)
    objs += word("+1", 1.4, (1.6, -1.3, 0.15), mat)
    return objs + (extra or [])


def builder(mat, makers):
    box = makers["CleanACat_Prop_Toolbox"][0](mat)
    bpy.context.view_layer.update()
    for ob in box:
        ob.matrix_world = Matrix.Translation((-1.15, -1.25, -0.6)) @ Matrix.Rotation(math.radians(-14), 4, "Z") \
            @ Matrix.Scale(1.5, 4)
    return person(mat, "Builder", box)


def pet_slot(mat, makers):
    objs = []
    for name, at, turn in (("Clover", (-0.8, 0.0, 0.0), 14), ("Ghost", (0.85, 0.5, 0.0), -10)):
        built = pets.build_pet(name, mat)
        bpy.context.view_layer.update()               # each part's own place first, then the turn and move
        for ob in built:
            if ob.name.endswith(("_Star2", "_Star3", "_Star3_Glow")):      # the rarity stars stay off
                bpy.data.objects.remove(ob, do_unlink=True)
                continue
            ob.matrix_world = Matrix.Translation(at) @ Matrix.Rotation(math.radians(turn), 4, "Z") @ ob.matrix_world
            objs.append(ob)
    bpy.context.view_layer.update()
    lo, hi = common.bounds(objs)
    objs += word("+1", 1.0, (hi.x - 0.1, lo.y - 0.4, lo.z + 0.35), mat)
    return objs


def starter_pet(mat, makers):
    """The starter pack's card (#1090): Midas whole, wings out, with a burst of four point sparkles round him."""
    objs = []
    for ob in pets.build_pet("Midas", mat):
        if ob.name.endswith(("_Star2", "_Star3", "_Star3_Glow")):
            bpy.data.objects.remove(ob, do_unlink=True)
            continue
        objs.append(ob)
    bpy.context.view_layer.update()
    for ob in objs:
        ob.matrix_world = Matrix.Rotation(math.radians(-22), 4, "Z") @ ob.matrix_world
    bpy.context.view_layer.update()
    lo, hi = common.bounds(objs)
    b = common.Builder()
    w, h = hi.x - lo.x, hi.z - lo.z
    y = lo.y - 0.25
    for fx, fz, r in ((-0.02, 0.98, 0.34), (0.98, 0.9, 0.26), (1.04, 0.3, 0.2), (-0.08, 0.36, 0.22), (0.5, 1.1, 0.16)):
        c = (lo.x + w * fx, y, lo.z + h * fz)
        b.box(c, (r * 2, 0.06, r * 0.36), WHITE, bevel=False)
        b.box((c[0], c[1] + 0.004, c[2]), (r * 0.36, 0.06, r * 2), WHITE, bevel=False)
        b.box((c[0], c[1] - 0.02, c[2]), (r * 0.62, 0.06, r * 0.62), "gold_light", bevel=False,
              rot=Matrix.Rotation(math.radians(45), 4, "Y"))
    objs.append(b.finalize("StarterSparkles", mat, bevel=0))
    return objs


SHOTS = {
    "shop_StarterPet": starter_pet,
    "shop_Coins2x": lambda mat, makers: coins(mat, 2),
    "shop_Coins3x": lambda mat, makers: coins(mat, 3),
    "shop_Builder2": builder,
    "shop_GoldenSponge": golden_sponge,
    "shop_ExtraWorker": lambda mat, makers: person(mat, "Lou"),
    "shop_PetSlot2": pet_slot,
}
