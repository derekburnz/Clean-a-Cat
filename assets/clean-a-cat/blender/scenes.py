"""Scene pictures for the owner and for review: models from this folder posed together, next to a stand-in Roblox
avatar (a blocky R15 shape, 5 studs tall) for scale. Not assets: nothing here is exported.

    python3 assets/clean-a-cat/blender/scenes.py tub   docs/concepts/clean-a-cat/2026-11-23-tub-scene.png
    python3 assets/clean-a-cat/blender/scenes.py groom docs/concepts/clean-a-cat/2026-11-23-groom-sheet.png
    python3 assets/clean-a-cat/blender/scenes.py stations docs/concepts/clean-a-cat/2026-11-23-stations-sheet.png
    python3 assets/clean-a-cat/blender/scenes.py builder docs/concepts/clean-a-cat/2026-11-23-builder-kitten.png
    python3 assets/clean-a-cat/blender/scenes.py vip docs/concepts/clean-a-cat
    python3 assets/clean-a-cat/blender/scenes.py index docs/concepts/clean-a-cat/2026-11-23-cat-index-sheet.png
    python3 assets/clean-a-cat/blender/scenes.py later docs/concepts/clean-a-cat/2026-11-23-later-stations.png
    python3 assets/clean-a-cat/blender/scenes.py plot docs/concepts/clean-a-cat
    python3 assets/clean-a-cat/blender/scenes.py street docs/concepts/clean-a-cat
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


# Where our stand-in avatar has the R15 accessory Attachments (Blender axes; the avatar's left is +X)
AVATAR_ATT = {"HatAttachment": (0.0, 0.0, 4.75), "NeckAttachment": (0.0, 0.0, 3.6),
              "LeftShoulderAttachment": (1.0, 0.0, 3.6)}


def avatar(mat, at=(0.0, 0.0, 0.0), skin="skin_tan", shirt="shirt_green", pants="shirt_blue"):
    """A plain blocky avatar, R15 proportions: legs 2, torso 1.6, head 1.2 studs; front -Y."""
    b = Builder()
    for sx in (1, -1):
        b.box_base((sx * 0.5, 0, 0), (0.95, 0.95, 2.0), pants)
        b.box_base((sx * 1.5, 0, 2.0), (0.95, 0.95, 1.6), skin)
    b.box_base((0, 0, 2.0), (1.95, 0.95, 1.6), shirt)
    b.box_base((0, 0, 3.6), (1.15, 1.15, 1.15), skin)
    return b.finalize("Avatar", mat, location=at)


def customers_sheet(mat, out):
    """The four customers, each with its accessory and a carrier with a dirty cat at its feet; the stray box with a
    stray, the chance board and a queue mat."""
    import customers
    import spa_props
    allo = []
    n = [0]

    def fresh(objs):
        n[0] += 1
        for o in objs:
            o.name = f"C{n[0]}_{o.name}"
        return objs

    for i, (_name, skin, shirt, pants, acc) in enumerate(customers.LOOKS):
        x = i * 4.2
        allo += fresh([avatar(mat, (x, 0, 0), skin, shirt, pants)])
        a = Vector(AVATAR_ATT[customers.ATTACH[acc]]) + Vector((x, 0, 0))
        built = {"CleanACat_NPC_SunHat": customers.build_sun_hat, "CleanACat_NPC_Scarf": customers.build_scarf,
                 "CleanACat_NPC_ToteBag": customers.build_tote_bag}[acc](mat)
        _move(built, a)
        allo += fresh(built)
        car = spa_props.build_carrier(mat)
        _move(car, (x + 0.2, -2.2, 0))
        cat_name = ("Muffin", "Patches", "Toffee", "Marble")[i]
        c, _, _ = dirt.build_dirty(cat_name, mat, "walk")
        _move(c, (x + 0.2, -2.2 + 0.06, spa_props.TRAY_H), spa_props.CAT_SCALE)
        allo += fresh(car) + fresh(c)
    box = spa_props.build_stray_box(mat)
    _move(box, (17.5, -2.0, 0))
    s, _, _ = dirt.build_dirty("Inky", mat, "sit")
    _move(s, (17.5, -2.0, 0.31))
    allo += fresh(box) + fresh(s)
    board = spa_props.build_chance_board(mat)
    _move(board, (21.5, 0.5, 0))
    mat_ = spa_props.build_queue_mat(mat)
    _move(mat_, (21.5, -2.6, 0))
    allo += fresh(board) + fresh(mat_)
    common.render_preview(allo, out, res=(1600, 640), samples=24, azimuth=14, elevation=12)


def stations_sheet(mat, out):
    """#18: the brush table with a tangled cat, the upgraded table with a fluffed one, the dryer with a rinsed cat
    under the hood and the build pad with a stray watching; an avatar stands at the front of each, facing it."""
    import math

    import spa_props
    allo, n = [], [0]

    def fresh(objs):
        n[0] += 1
        for o in objs:
            o.name = f"T{n[0]}_{o.name}"
        return objs

    def cat(name, drop, at, k):
        objs, _, _ = dirt.build_dirty(name, mat, "sit")
        objs = _drop(objs, drop)
        for o in objs:
            o.hide_render = False
        _move(objs, at, k)
        return fresh(objs)

    k = stations.STATION_CAT_SCALE
    seat = (0.0, stations.TOP_Y - 0.03, stations.GROOM_Z)
    rows = [(stations.build_brush_table, ("Smudge", ["_Mud", "_Fluff"]), seat),
            (stations.build_brush_table_up, ("Cotton", ["_Mud", "_Tangle"]), seat),
            (stations.build_dryer, ("Muffin", ["_Mud", "_Tangle"]), (*stations.STOOL, stations.SEAT_DRYER)),
            (spa_props.build_build_pad, ("Inky", ["_Mud", "_Tangle", "_Fluff"]), (-1.2, -1.0, spa_props.PAD_H))]
    for i, (build, (cat_name, drop), at) in enumerate(rows):
        x = i * 7.4
        objs = [o for o in build(mat) if not o.name.endswith("_Barrier")]
        _move(objs, (x, 0, 0))
        allo += fresh(objs)
        allo += cat(cat_name, drop, (x + at[0], at[1], at[2]), k if i < 3 else 1.0)
        av = avatar(mat, (x - 3.3, -1.3, 0.0), ("skin_light", "skin_tan", "skin_deep", "skin_tan")[i],
                    ("spa_mint", "shirt_blue", "pastel_butter", "spa_bubblegum")[i])
        av.rotation_euler.z = math.radians(-60)          # turned to the station, three quarters to us
        allo += fresh([av])
    common.render_preview(allo, out, res=(1600, 600), samples=24, azimuth=10, elevation=18, margin=0.9)


def builder_sheet(mat, out, close=False):
    """#20: the builder kitten in its hard hat with the hammer in its right paw and the toolbox beside it, on a build
    pad at a locked station, an avatar beside it for scale. close=True: the kitten and its things alone, nearer."""
    import math

    import build_props
    import spa_props
    allo = []
    top, paw = build_props._kitten_points()
    kit = build_props.build_kitten(mat)
    hat = build_props.build_hard_hat(mat)
    _move(hat, top)
    ham = build_props.build_hammer(mat)
    _move(ham, paw)
    box = build_props.build_toolbox(mat)
    _move(box, (1.2, 0.15, 0.0))
    group = kit + hat + ham + box
    if close:
        common.render_preview(group, out, res=(900, 700), samples=24, azimuth=28, elevation=12)
        return
    pad = spa_props.build_build_pad(mat)
    _move(group, (-0.4, -0.6, spa_props.PAD_H))
    av = avatar(mat, (-3.4, -1.2, 0.0), "skin_tan", "spa_sky")
    av.rotation_euler.z = math.radians(-60)
    allo = group + pad + [av]
    common.render_preview(allo, out, res=(1200, 700), samples=24, azimuth=22, elevation=16, margin=0.95)


def vip_views(mat, out):
    """#21: the VIP Room before it is built, on the graybox plot. VipLocked seen from inside the spa, an avatar at
    the door, and VipBuilding from above the yard's back corner, the open side of the frame showing. `out` is a folder:
    the two pictures are 2026-11-23-vip-locked.png and 2026-11-23-vip-building.png in it."""
    import plot
    import vip
    F = plot.FLOOR
    x, y, _, _ = plot.SPOTS["SpotVipDoor"]
    paths = []
    for i, (build, view) in enumerate(((vip.build_vip_locked, dict(eye=(x - 9.0, y - 22.0, F + 10.0),
                                                                     target=(x, y + 2.0, F + 6.0), lens=22)),
                                       (vip.build_vip_building, dict(eye=(x - 24.0, y + 26.0, F + 22.0),
                                                                       target=(x, y + 4.0, F + 6.0), lens=24)))):
        common.reset_scene()
        mat = common.palette_material(os.path.join(HERE, "..", "exports", palette.TEXTURE_NAME + ".png"))
        objs = plot.build_plot(mat) + build(mat)
        for o in objs:
            if o.name.startswith("CleanACat_Area_Vip"):
                o.location = Vector((x, y, F))
        av = avatar(mat, (x - 1.5, y - 5.0, F), "skin_tan", "spa_mint")
        av.rotation_euler.z = 3.14159
        av2 = avatar(mat, (x + 10.0, y + 5.0, F), "skin_light", "spa_bubblegum")   # in the yard, by the site
        path = os.path.join(out, ("2026-11-23-vip-locked.png", "2026-11-23-vip-building.png")[i])
        shot(objs + [av, av2], path, view["eye"], view["target"], view["lens"], res=(900, 640),
             hide=("_Barrier",) + (("_Roof",) if i == 0 else ()))
        paths.append(path)


def index_sheet(mat, out):
    """#22: the first Cat Index in its order, each cat sitting on a tile in its rarity colour, clean in the front row and
    dirty behind; at 1600 px each column is about 160 px wide, an index card's size on a phone."""
    import coat_table
    t = coat_table.table()
    allo = []
    for i, name in enumerate(t["Order"]):
        x = (i - 4.5) * 2.6
        swatch = coat_table.RARITY_SWATCH[cats.ROSTER[name]["rarity"]]
        for row, dirty in ((0, False), (1, True)):
            y = row * 3.4
            b = Builder()
            b.box_base((0, 0, 0), (2.2, 2.2, 0.12), swatch)
            tile = b.finalize(f"Tile{i}_{row}", mat, location=(x, y, 0.0))
            if dirty:
                objs, _, _ = dirt.build_dirty(name, mat, "sit")
                objs = [o for o in objs if "_Fluff" not in o.name]
            else:
                objs = cats.build_cat(name, mat, body="sit")
            _move(objs, (x, y, 0.12))
            for o in objs:
                o.name = f"I{i}{row}_{o.name}"
            allo += [tile] + objs
    shot(allo, out, eye=(0.0, -40.0, 21.0), target=(0.0, 1.7, 1.1), lens=58, res=(1600, 600))


def later_stations_sheet(mat, out):
    """#23: the bubble bath with a cat in the foam and the pawdicure table with a cat showing its long claws, an avatar
    beside each."""
    import math
    allo = []
    k = stations.STATION_CAT_SCALE
    rows = [(stations.build_bubble_bath, "Marble", ["_Mud", "_Tangle", "_Fluff", "_Claw"],
             (0.0, 0.0, stations.BATH_SEAT + 0.02)),
            (stations.build_pawdicure, "Toffee", ["_Mud", "_Tangle", "_Fluff"], (0.0, 0.35, stations.PAW_Z))]
    for i, (build, name, drop, at) in enumerate(rows):
        x = i * 7.0
        objs = [o for o in build(mat) if not o.name.endswith("_Barrier")]
        _move(objs, (x, 0, 0))
        c, _, _ = dirt.build_dirty(name, mat, "sit")
        c = _drop(c, drop)
        for o in c:
            o.hide_render = False
        _move(c, (x + at[0], at[1], at[2]), k)
        av = avatar(mat, (x - 3.4, -1.2, 0.0), ("skin_deep", "skin_light")[i], ("spa_sky", "spa_bubblegum")[i])
        av.rotation_euler.z = math.radians(-60)
        for o in objs + c + [av]:
            o.name = f"L{i}_{o.name}"
        allo += objs + c + [av]
    common.render_preview(allo, out, res=(1200, 620), samples=24, azimuth=16, elevation=18, margin=0.9)


def street_views(mat, out_dir):
    """#15: the street with six plots (the real plot, empty) from above the road and from the pavement."""
    import plot
    import street
    allo = [o for o in street.build_street(mat) if not o.name.endswith("_Barrier")]
    for s_ in range(1, street.SLOTS + 1):
        objs = plot.build_plot(mat)
        _move(objs, (street.slot_x(s_), 0, 0))
        for o in objs:
            o.name = f"P{s_}_{o.name}"
        allo += objs
    for i, x in enumerate((-3.0, 40.0, -50.0)):
        av = avatar(mat, (x, -28.0, plot.FLOOR), ("skin_tan", "skin_light", "skin_deep")[i],
                    ("spa_bubblegum", "spa_sky", "shirt_green")[i])
        av.name = f"W{i}_Avatar"
        allo.append(av)
    os.makedirs(out_dir, exist_ok=True)
    made = []
    for key, eye, target, lens in (("wide", (-22.0, -130.0, 120.0), (-22.0, -10.0, 0.0), 24),
                                   ("pavement", (30.0, -40.0, 9.0), (-30.0, -16.0, 5.0), 24)):
        path = os.path.join(out_dir, f"2026-11-23-street-{key}.png")
        shot(allo, path, eye, target, lens, res=(1600, 800), hide=("_Glass",))
        made.append(path)
    return made


def mud_close(mat, out):
    """#107: the mud up close on a light coat, a grey coat and a dark coat: Muffin sitting, Smudge walking, Inky
    sitting, with no tangles or fluff."""
    allo = []
    for i, (name, body) in enumerate((("Muffin", "sit"), ("Smudge", "walk"), ("Inky", "sit"))):
        c, _, _ = dirt.build_dirty(name, mat, body)
        c = _drop(c, ["_Tangle", "_Fluff", "_Claw"])
        _move(c, (i * 1.9, 0, 0))
        for o in c:
            o.name = f"M{i}_{o.name}"
        allo += c
    common.render_preview(allo, out, res=(1500, 640), samples=32, azimuth=-18, elevation=18, margin=0.72)


def foam_close(mat, out):
    """#107: the foam up close: the wash tub and the bubble bath, each with a rinsed cat at the stations' scale."""
    allo = []
    rows = (("Muffin", stations.build_tub, stations.SEAT_Z), ("Cotton", stations.build_bubble_bath, stations.BATH_SEAT))
    for i, (name, build, seat) in enumerate(rows):
        x = i * 6.0
        st = [o for o in build(mat) if not o.name.endswith("_Barrier")]
        _move(st, (x, 0, 0))
        c = cats.build_cat(name, mat, body="sit")
        _move(c, (x, 0, seat + 0.02), stations.STATION_CAT_SCALE)
        for o in st + c:
            o.name = f"F{i}_{o.name}"
        allo += st + c
    common.render_preview(allo, out, res=(1500, 700), samples=32, azimuth=-14, elevation=24, margin=0.8)


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
    common.render_still()
    del math


def plot_views(mat, out_dir, stem="plot-real"):
    """The plot (#15; the graybox until the real build) dressed with the tub, a cat in it, the player at the spawn, three customers in the queue
    with cats, a stray in its box and cats on the window cushions: from the entrance, the player's spot, outside
    on the street and top-down."""
    import math
    import plot
    import spa_props
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
    allo += fresh(place(spa_props.build_stray_box(mat), "SpotStray"))
    s, _, _ = dirt.build_dirty("Inky", mat, "sit")
    allo += fresh(place(s, "SpotStray", lift=0.31))
    allo += fresh(place(spa_props.build_chance_board(mat), "SpotBoard"))
    for i in range(1, 4):
        allo += fresh(place(spa_props.build_queue_mat(mat), f"SpotQueue{i}", lift=0.0))
    for i, name in enumerate(("Cotton", "Marble", "LilacCloud", "Tux"), start=1):
        allo += fresh(place(spa_props.build_cushion(mat), f"SpotWindow{i}"))
        allo += fresh(place(cats.build_cat(name, mat, body="sit"), f"SpotWindow{i}", lift=spa_props.CUSHION_H - 0.03,
                            k=spa_props.WINDOW_CAT_SCALE))
    allo += fresh(place(spa_props.build_tip_jar(mat), "SpotTipJar"))
    allo += fresh(place(spa_props.build_window_sign(mat), "SpotSign"))
    walker = avatar(mat, skin="skin_light", shirt="spa_bubblegum", pants="pants_navy")
    walker.location = Vector((-9.0, -27.0, 0.0))        # a passer-by on the street, looking in at the window
    allo += fresh([walker])
    os.makedirs(out_dir, exist_ok=True)
    views = {
        "entrance": dict(eye=(11.0, -12.0, F + 9.5), target=(-4.0, 2.0, F + 1.0), lens=20),
        "player": dict(eye=(-5.0, -16.0, F + 8.5), target=(-5.0, -2.0, F + 1.5), lens=22),
        "street": dict(eye=(-14.0, -46.0, F + 9.0), target=(-2.0, -12.0, F + 4.0), lens=28),
        "top": dict(eye=(0.0, -6.0, 80.0), target=(0.0, -0.5, 0.0), lens=30),
        "window": dict(eye=(-34.0, -40.0, F + 7.0), target=(-8.0, -15.0, F + 3.0), lens=35),
    }
    made = []
    for key, v in views.items():
        path = os.path.join(out_dir, f"2026-11-23-{stem}-{key}.png")
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
    {"tub": tub, "groom": groom, "groom-close": lambda m, o: groom(m, o, close=True), "plot": plot_views,
     "customers": customers_sheet, "stations": stations_sheet,
     "builder": builder_sheet, "vip": vip_views, "index": index_sheet, "street": street_views, "mud": mud_close,
     "foam": foam_close, "later": later_stations_sheet,
     "builder-close": lambda m, o: builder_sheet(m, o, close=True)}[which](mat, out)
