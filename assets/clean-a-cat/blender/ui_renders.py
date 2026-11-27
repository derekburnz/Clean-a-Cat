"""Pictures of the models for the screens (#127): cat portraits and item icons, on see-through backgrounds.

    python ui_renders.py <raw folder> [--only word,word]

Runs in Blender's Python (bpy). Writes one raw PNG per picture, twice the final size, then `ui_compose.py` (plain
Python with Pillow) trims them, adds the ink outline and writes the finals and the check sheet:

  portrait_<Cat>.png, portrait_<Cat>_Dirty.png   head and shoulders of every roster cat, sitting, clean and muddy
  portrait_Helper.png, _Helper2, _Helper3        each helper look in its bath cap, same crop as the cats
  portrait_Staff_<Name>.png                      each member of the human staff and the builder as a smooth bust
                                                 (staff_busts.py, #1036): the head whole, the apron down to its paw
  shop_<Item>.png                                the Robux shop's card pictures (shop_art.py, #1030)
  portrait_Pet_<Name>.png                        each crate pet's face with its head piece (#883)
  icon_<Model name without CleanACat_>.png       one three-quarter picture of each model in ICONS
  icon_Customer_<Name>.png, icon_Visitor_<Name>.png   head and shoulders of each customer and rare visitor look, on
                                                 the stand-in block figure (the game's customers are R15 rigs)

One camera rule for every icon (from the front right, a little above) and one light setup, so the set reads as a
family. The camera has no perspective, so a picture is framed exactly on its model. Nothing is uploaded: the
ui-designer decides what goes into `assets/clean-a-cat/ui/`.
"""

import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

import build_all  # noqa: E402
import busy_spa  # noqa: E402
import cats  # noqa: E402
import common  # noqa: E402
import crates  # noqa: E402
import customers  # noqa: E402
import dirt  # noqa: E402
import gift  # noqa: E402
import palette  # noqa: E402
import pets  # noqa: E402
import scenes  # noqa: E402
import shop_art  # noqa: E402
import staff_busts  # noqa: E402
import townsfolk  # noqa: E402

PORTRAIT_RAW, ICON_RAW = 1024, 512
PORTRAIT_VIEW = (16, 6)            # azimuth and elevation, degrees: nearly face on, so both eyes show
ICON_VIEW = (35, 24)
# model -> (azimuth, elevation) where the family view hides what the thing is; None for the family view
# (the coin stack is seen a little lower than the family view so its tops stay gold and the tall pile stands
# clear; the dryer from the side so its hood, pole and stool sit side by side; the bench from above so its three
# mats show)
ICONS = {
    "CleanACat_Tool_Sponge": None, "CleanACat_Tool_SpongeBubble": None, "CleanACat_Tool_SpongeGolden": None,
    "CleanACat_Tool_Brush": None, "CleanACat_Tool_BrushFluffy": None, "CleanACat_Tool_BrushGolden": None,
    "CleanACat_Tool_ShowerRain": None, "CleanACat_Tool_ShowerGolden": None, "CleanACat_Prop_StarPhoto": (20, 12), "CleanACat_Tool_Shower": None, "CleanACat_Tool_Comb": (-62, 16),
    "CleanACat_Tool_Tweezers": None, "CleanACat_Tool_Towel": None, "CleanACat_Tool_Clipper": (-55, 18),
    "CleanACat_Tool_Dryer": (-50, 16), "CleanACat_Tool_Shampoo": (20, 14), "CleanACat_Station_BubbleBath": (28, 26),
    "CleanACat_Station_Tub": (28, 26), "CleanACat_Station_Pawdicure": (28, 26),
    "CleanACat_Station_WashStandJo": (-24, 26), "CleanACat_Station_WashStandSam": (-24, 26),
    "CleanACat_Station_WashStandLou": (-24, 26),
    "CleanACat_Station_BrushTable": (28, 26), "CleanACat_Station_BrushTableUp": (28, 26),
    "CleanACat_Station_Dryer": (60, 10), "CleanACat_Prop_Carrier": None,
    "CleanACat_Bow_Pink": (0, 20), "CleanACat_Bow_Mint": (0, 20), "CleanACat_Bow_Sky": (0, 20),
    "CleanACat_Bow_PinkDouble": (0, 20), "CleanACat_Bow_MintDouble": (0, 20), "CleanACat_Bow_SkyDouble": (0, 20),
    "CleanACat_Bow_PinkRoyal": (0, 20), "CleanACat_Bow_MintRoyal": (0, 20), "CleanACat_Bow_SkyRoyal": (0, 20),
    "CleanACat_Bow_PinkGolden": (0, 20), "CleanACat_Bow_MintGolden": (0, 20), "CleanACat_Bow_SkyGolden": (0, 20),
    "CleanACat_Prop_Coin": (18, 8), "CleanACat_Prop_Star": (14, 6), "CleanACat_Prop_CoinStack": (35, 20),
    "CleanACat_NPC_BuilderKitten": (18, 8), "CleanACat_NPC_Helper": (18, 8),
    "CleanACat_NPC_Helper2": (18, 8), "CleanACat_NPC_Helper3": (18, 8),
    "CleanACat_Station_WaitBench": (15, 55), "CleanACat_Station_FrontDesk": (28, 26),
    "CleanACat_Prop_Burr": None, "CleanACat_Prop_Leaf": (35, 55), "CleanACat_Prop_Twig": (35, 55),
    "CleanACat_Prop_PetCrate": (26, 20),
    **{pets.PREFIX + n: (27, 12) for n in pets.ALL},
    "CleanACat_Prop_GiftStand": (24, 14),       # a pet's card: the pet at star 1 (icon leaves the stars off)
}
STAR_OBJECTS = ("_Star2", "_Star3", "_Star3_Glow")
FACE_FRONT = (0.0, -0.575, 4.175)          # R15's FaceFrontAttachment on the stand-in figure (scenes.avatar)


def _camera():
    sc = bpy.context.scene
    cam = bpy.data.objects.get("_Cam")
    if cam is None:
        cam = bpy.data.objects.new("_Cam", bpy.data.cameras.new("_Cam"))
        sc.collection.objects.link(cam)
    sc.camera = cam
    return cam


def shot(objs, path, size, view, focus=None, pad=1.06, samples=48):
    """A square see-through picture of objs from `view`, framed on `focus` (a (low, high) box) or on all of objs."""
    sc = bpy.context.scene
    common.render_preview(objs[:1], path, res=(8, 8), samples=1, floor=False)        # lights and render settings
    az, el = (math.radians(v) for v in view)
    back = Vector((math.sin(az) * math.cos(el), -math.cos(az) * math.cos(el), math.sin(el)))   # toward the camera
    right = Vector((math.cos(az), math.sin(az), 0.0))
    up = back.cross(right)
    lo, hi = focus or common.bounds(objs)
    corners = [Vector((x, y, z)) for x in (lo.x, hi.x) for y in (lo.y, hi.y) for z in (lo.z, hi.z)]
    us, vs = [c.dot(right) for c in corners], [c.dot(up) for c in corners]
    centre = right * (min(us) + max(us)) / 2 + up * (min(vs) + max(vs)) / 2 + back * ((lo + hi) / 2).dot(back)
    cam = _camera()
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = max(max(us) - min(us), max(vs) - min(vs)) * pad
    cam.data.clip_start, cam.data.clip_end = 0.05, 400.0
    cam.location = centre + back * 60.0
    cam.rotation_euler = (-back).to_track_quat("-Z", "Y").to_euler()
    fl = bpy.data.objects.get("_PreviewFloor")
    if fl:
        fl.hide_render = True
    for ob in sc.objects:
        if ob.type == "MESH" and not ob.name.startswith("_"):
            ob.hide_render = ob not in objs
    sc.render.film_transparent = True
    sc.render.image_settings.color_mode = "RGBA"
    sc.render.resolution_x = sc.render.resolution_y = size
    sc.cycles.samples = samples
    sc.render.filepath = path
    common.render_still()
    sc.render.film_transparent = False
    cam.data.type = "PERSP"
    return path


def _clear():
    for ob in list(bpy.context.scene.objects):
        if ob.type == "MESH" and not ob.name.startswith("_"):
            me = ob.data
            bpy.data.objects.remove(ob, do_unlink=True)
            if me.users == 0:
                bpy.data.meshes.remove(me)
    common.PRIMS.clear()


def portrait(name, mat, out, dirty=False, level=None):
    """Head and shoulders: the whole head with its ears, and the chest down to a third of the head's height. With a
    dirt `level` (1 to dirt.LEVELS) the cat wears that level's mud and tangles (portrait_<Cat>_Dirty<level>.png)."""
    if dirty:
        skip = ("_Fluff", "_Claw") if level else ("_Tangle", "_Fluff", "_Claw")
        objs = [o for o in dirt.build_dirty(name, mat, "sit")[0] if not any(s in o.name for s in skip)]
        if level:
            objs = dirt.at_level(objs, level, "sit")
        for o in bpy.context.scene.objects:
            if o.type == "MESH" and o not in objs:
                o.hide_render = True
    else:
        objs = cats.build_cat(name, mat, body="sit")
    bpy.context.view_layer.update()
    head = [o for o in objs if o.name.endswith(("_Head", "_EarL", "_EarR", "_Eye1", "_Eye2"))]
    lo, hi = common.bounds(head)
    lo = Vector((lo.x, lo.y, lo.z - (hi.z - lo.z) * 0.34))
    worn = [o for o in objs if o.get("rides") == "Head"]      # a special cat's head piece is part of its picture,
    if worn:                                                  # so less chest shows and the face stays big
        wlo, whi = common.bounds(worn)
        lo = Vector((min(lo.x, wlo.x), min(lo.y, wlo.y), lo.z + (hi.z - lo.z) * 0.1))
        hi = Vector((max(hi.x, whi.x), max(hi.y, whi.y), max(hi.z, whi.z)))
    path = os.path.join(out, f"portrait_{name}{'_Dirty' if dirty else ''}{level or ''}.png")
    shot(objs, path, PORTRAIT_RAW, PORTRAIT_VIEW, focus=(lo, hi), pad=1.1)
    _clear()
    return path


def pet_portrait(name, mat, out):
    """A crate pet's face (#883): the head with its ears and its head piece whole, on the walk body it stands on,
    the chest down to a quarter of the head's height, the stars left off (portrait_Pet_<Name>.png)."""
    objs = [o for o in pets.build_pet(name, mat) if not o.name.endswith(STAR_OBJECTS)]
    bpy.context.view_layer.update()
    head = [o for o in objs if o.name.endswith(("_Head", "_EarL", "_EarR", "_Eye1", "_Eye2"))]
    lo, hi = common.bounds(head)
    lo = Vector((lo.x, lo.y, lo.z - (hi.z - lo.z) * 0.25))
    worn = [o for o in objs if o.get("rides") == "Head"]
    if worn:
        wlo, whi = common.bounds(worn)
        lo = Vector((min(lo.x, wlo.x), min(lo.y, wlo.y), lo.z))
        hi = Vector((max(hi.x, whi.x), max(hi.y, whi.y), max(hi.z, whi.z)))
    path = os.path.join(out, f"portrait_Pet_{name}.png")
    shot(objs, path, PORTRAIT_RAW, PORTRAIT_VIEW, focus=(lo, hi), pad=1.1)
    _clear()
    return path


def helper_portrait(i, mat, out):
    """Helper look i in its cap, framed like a cat's portrait (the cap counts as part of the head)."""
    name, cap_name = busy_spa.HELPERS[i][0], busy_spa.HELPERS[i][2]
    objs = busy_spa.ASSETS[name][0](mat)
    cap = busy_spa.ASSETS[cap_name][0](mat)
    top = busy_spa.helper_rbx_extras(i)["attachments"][0][2].translation
    for o in cap:
        o.location = o.location + top
    bpy.context.view_layer.update()
    head = [o for o in objs if o.name.endswith(("_Head", "_EarL", "_EarR", "_Eye1", "_Eye2"))] + cap
    lo, hi = common.bounds(head)
    lo = Vector((lo.x, lo.y, lo.z - (hi.z - lo.z) * 0.3))
    path = os.path.join(out, f"portrait_{name.replace('CleanACat_NPC_', '')}.png")
    shot(objs + cap, path, PORTRAIT_RAW, PORTRAIT_VIEW, focus=(lo, hi), pad=1.1)
    _clear()
    return path


def staff_portrait(name, mat, out):
    """Head and shoulders of one member of staff (#1036): the smooth bust of staff_busts.py, not the Part model,
    the head whole and the chest cut at the apron's paw, so it reads in a small round frame."""
    objs = staff_busts.build_bust(name, mat)
    bpy.context.view_layer.update()
    path = os.path.join(out, f"portrait_Staff_{name}.png")
    shot(objs, path, PORTRAIT_RAW, PORTRAIT_VIEW, focus=staff_busts.bust_focus(name), pad=1.04)
    _clear()
    return path


def shop_picture(key, mat, out, makers):
    """One shop card's picture (#1030), framed on all of it."""
    objs = shop_art.SHOTS[key](mat, makers)
    bpy.context.view_layer.update()
    path = os.path.join(out, key + ".png")
    shot(objs, path, PORTRAIT_RAW, shop_art.VIEW, pad=1.04)
    _clear()
    return path


def person(kind, look, mat, out, makers):
    """Head and shoulders of one customer or visitor look on the stand-in figure, with what it wears."""
    name, skin, shirt, pants, worn = look
    worn = worn if isinstance(worn, (tuple, list)) else (worn,)
    objs = [scenes.avatar(mat, (0, 0, 0), skin, shirt, pants)]
    spots = dict(scenes.AVATAR_ATT, FaceFrontAttachment=FACE_FRONT)
    attach = {**customers.ATTACH, **busy_spa.ATTACH}
    b = common.Builder()                                   # a plain face, so the block head reads as a person
    fx, fy, fz = FACE_FRONT
    if not any(attach[a] == "FaceFrontAttachment" for a in worn):
        for sx in (-1, 1):
            b.box((sx * 0.24, fy - 0.01, fz + 0.1), (0.13, 0.03, 0.2), "choco", bevel=False)
    b.box((0, fy - 0.01, fz - 0.24), (0.36, 0.03, 0.07), "choco", bevel=False)
    for sx in (-1, 1):
        b.box((sx * 0.2, fy - 0.01, fz - 0.19), (0.07, 0.03, 0.07), "choco", bevel=False)
    objs.append(b.finalize("AvatarFace", mat, bevel=0))
    top = []
    for acc in worn:
        built = makers[acc][0](mat)
        for o in built:
            o.location = o.location + Vector(spots[attach[acc]])
        objs += built
        if attach[acc] in ("HatAttachment", "FaceFrontAttachment"):
            top += built
    bpy.context.view_layer.update()
    lo, hi = common.bounds(top) if top else (Vector((-0.6, -0.6, 3.6)), Vector((0.6, 0.6, 4.75)))
    lo = Vector((min(lo.x, -1.3), min(lo.y, -0.6), 2.9))
    hi = Vector((max(hi.x, 1.3), max(hi.y, 0.6), max(hi.z, 4.8)))
    path = os.path.join(out, f"icon_{kind}_{name}.png")
    shot(objs, path, ICON_RAW, (20, 10), focus=(lo, hi))
    _clear()
    return path


def icon(asset, mat, out, makers):
    # the gift stand's card leaves the balloon off: 7 studs of string would shrink the present to a speck
    built = gift.build_gift_stand(mat, balloon=False) if asset == gift.NAME else makers[asset][0](mat)
    objs = built[0] if isinstance(built, tuple) else built
    objs = [o for o in objs if not o.name.endswith("_Barrier")]          # a station's invisible wall is not drawn
    if asset.startswith(pets.PREFIX):
        objs = [o for o in objs if not o.name.endswith(STAR_OBJECTS)]
    bpy.context.view_layer.update()
    path = os.path.join(out, "icon_" + asset.replace("CleanACat_", "") + ".png")
    shot(objs, path, ICON_RAW, ICONS[asset] or ICON_VIEW)
    _clear()
    return path


def crate_open_icon(mat, out, makers):
    """The pet crate with its lid open (icon_Prop_PetCrateOpen.png): the lid turned LidOpenDegrees on its hinge, as
    the game opens it."""
    objs = makers[crates.NAME][0](mat)
    bpy.context.view_layer.update()
    lid = next(o for o in objs if o.name.endswith("_Lid_Swing"))
    lid.matrix_world = lid.matrix_world @ Matrix.Rotation(math.radians(-crates.LID_OPEN), 4, "X")
    bpy.context.view_layer.update()
    path = os.path.join(out, "icon_Prop_PetCrateOpen.png")
    shot(objs, path, ICON_RAW, (26, 30))
    _clear()
    return path


def main(argv):
    out = os.path.abspath(argv[0])
    only = []
    if "--only" in argv:
        only = [w.strip().lower() for w in argv[argv.index("--only") + 1].split(",") if w.strip()]
    os.makedirs(out, exist_ok=True)
    common.reset_scene()
    mat = common.palette_material(os.path.join(HERE, "..", "exports", palette.TEXTURE_NAME + ".png"))
    makers = build_all.all_assets()
    want = lambda n: not only or any(w in n.lower() for w in only)   # noqa: E731
    # the mascot too: clean in his collar, and as the muddy stray; and the special customers' cats
    for name in (*cats.ROSTER, *cats.EXTRA_CATS, *cats.SPECIAL_CATS):
        for dirty in (False, True):
            if want(f"portrait_{name}{'_dirty' if dirty else ''}"):
                print("ui:", portrait(name, mat, out, dirty))
        if name not in cats.EXTRA_CATS:                # a picture per dirt level for the pick menu's cards
            for level in range(1, dirt.LEVELS + 1):
                if want(f"portrait_{name}_dirty{level}"):
                    print("ui:", portrait(name, mat, out, True, level))
    for i, look in enumerate(busy_spa.HELPERS):
        if want("portrait_" + look[0].replace("CleanACat_NPC_", "")):
            print("ui:", helper_portrait(i, mat, out))
    for name in staff_busts.LOOKS:
        if want("portrait_Staff_" + name):
            print("ui:", staff_portrait(name, mat, out))
    for key in shop_art.SHOTS:
        if want(key):
            print("ui:", shop_picture(key, mat, out, makers))
    for name in {**pets.PETS, **pets.STARTER_PETS}:
        if want("portrait_Pet_" + name):
            print("ui:", pet_portrait(name, mat, out))
    for asset in ICONS:
        if asset in makers and want("icon_" + asset):
            print("ui:", icon(asset, mat, out, makers))
    if want("icon_Prop_PetCrateOpen"):
        print("ui:", crate_open_icon(mat, out, makers))
    for kind, looks in (("Customer", customers.LOOKS), ("Visitor", busy_spa.VISITORS)):
        for look in looks:
            if want(f"icon_{kind}_{look[0]}"):
                print("ui:", person(kind, look, mat, out, makers))


if __name__ == "__main__":
    main(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:])
