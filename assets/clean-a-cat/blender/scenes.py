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
    python3 assets/clean-a-cat/blender/scenes.py plot-built docs/concepts/clean-a-cat
    python3 assets/clean-a-cat/blender/scenes.py street docs/concepts/clean-a-cat
"""

import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import bpy  # noqa: E402,F401
from mathutils import Matrix, Vector  # noqa: E402

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


# The owner's hold (his clip, 2026-11-24: "here is how the carrying should look"): the arms reach forward, down and
# in from the shoulders, so the hands end near the hips in front of the belly, and the kitten lies across them close
# against the body with his head end at the carrier's left shoulder. The game's arms are Effects/Carry.luau
# (Motion-FX); these are a stand-in with an elbow, so the picture reads on the avatars most players wear.
HOLD_UPPER = 12.0                  # degrees the upper arm goes forward of straight down
HOLD_IN, HOLD_DOWN = 50.0, 22.0    # degrees the forearm turns in toward the middle, and slopes down to the hand
HOLD_SEAT = (0.2, -1.25, 2.42)     # the held loaf's base in the avatar's space: to its left, ahead, and up. 0.2
                                   # lower since #353: his tipped head stands higher and must stay under the chin
HOLD_ROLL = 5.0                    # degrees his head end is raised


def held_at():
    """The held loaf's place in the avatar's space: across the arms, his front to the carrier's left, at his
    carried size (cats.LOAF_CARRY_SCALE)."""
    return (Matrix.Translation(HOLD_SEAT) @ Matrix.Rotation(math.radians(90), 4, "Z")
            @ Matrix.Rotation(math.radians(-HOLD_ROLL), 4, "X") @ Matrix.Scale(cats.LOAF_CARRY_SCALE, 4))


def suds_on_bed(mat):
    """Sitting Suds, moved to his seat in the basket (its CatSeat is off the middle); place him at the bed's spot
    with lift BED_SEAT and scale BED_CAT_SCALE."""
    import spa_props
    objs = cats.build_cat("Suds", mat, body="sit")
    for o in objs:
        o.location += Vector((*spa_props.BED_SIT, 0.0)) / spa_props.BED_CAT_SCALE
    return objs


def avatar(mat, at=(0.0, 0.0, 0.0), skin="skin_tan", shirt="shirt_green", pants="shirt_blue", arms="down"):
    """A plain blocky avatar, R15 proportions: legs 2, torso 1.6, head 1.2 studs; front -Y. `arms` "hold" is the
    owner's carry hold (HOLD_FWD, HOLD_IN): the arms reach forward, down and in, and a loaf lies across them at
    held_at()."""
    b = Builder()
    for sx in (1, -1):
        b.box_base((sx * 0.5, 0, 0), (0.95, 0.95, 2.0), pants)
        if arms == "hold":
            def limb(start, way, back, length, thick):
                side = Vector((0, 1, 0)).cross(-way).normalized()
                rot = Matrix((side, (-way).cross(side), -way)).transposed()
                b.box(tuple(start + way * (length / 2 - back)), (thick, thick, length), skin, rot=rot)

            up, turn, down = (math.radians(a) for a in (HOLD_UPPER, HOLD_IN, HOLD_DOWN))
            shoulder = Vector((sx * 1.5, 0, 3.35))
            way = Vector((-sx * 0.09, -math.sin(up), -math.cos(up))).normalized()
            limb(shoulder, way, 0.25, 1.1, 0.95)                                          # shoulder to elbow
            elbow = shoulder + way * 0.8
            way = Vector((-sx * math.sin(turn) * math.cos(down), -math.cos(turn) * math.cos(down), -math.sin(down)))
            limb(elbow, way, 0.3, 1.45, 0.86)                                             # elbow to hand
        else:
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
    rows = (("Muffin", stations.build_tub, stations.TUB_SEAT), ("Cotton", stations.build_bubble_bath, stations.BATH_SEAT))
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
    _move(cat, (0, 0, stations.TUB_SEAT), 1.5)            # the game shows the cat at ScaleTo(1.5) at the tub
    sp = tools.build_sponge("CleanACat_Tool_Sponge", mat)
    _move(sp, (1.3, -1.3, 2.6))
    common.render_preview(objs + cat + sp, out, res=(900, 640), samples=24, azimuth=25, elevation=28)


def groom(mat, out, name="Smudge", close=False):
    """Left to right: an avatar, the rinsed cat with its tangles, fluffed after the brush, and with each bow."""
    spec = cats.ROSTER[name]
    k = cats.scale_of(spec, "sit")
    bow_spot, bow_tip = cats.bow_side(spec, "sit")
    bow = (Matrix.Translation(Vector(cats.joints(spec, "sit")["Head"]) + Vector(bow_spot) * k)
           @ Matrix.Rotation(math.radians(bow_tip), 4, "Y") @ Matrix.Scale(k, 4))
    allo = [] if close else [avatar(mat, (-2.2, 0.4, 0.0))]
    stages = [("tangled", None), ("fluffed", None)] + [("bow", n) for n in props.BOWS]
    for i, (stage, bow_name) in enumerate(stages):
        objs, _, _ = dirt.build_dirty(name, mat, "sit")
        objs = _drop(objs, ["_Mud"] + (["_Tangle"] if stage != "tangled" else ["_Fluff"]))
        for o in objs:
            o.hide_render = False                       # the fluff ships hidden
        if bow_name:
            b = props.build_bow(bow_name, mat)
            for o in b:
                o.matrix_world = bow @ o.matrix_basis
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


def plot_views(mat, out_dir, stem="plot-real", date="2026-11-23", built=False):
    """`built` adds every station on its spot (the Brush Table, the Blow Dryer, the Bubble Bath and the Pawdicure),
    a stand-in for the Tools board the game puts right of the tub, and two more views. Without it:
    The plot (#15; the graybox until the real build) dressed with the tub, a cat in it, the player at the spawn, three customers in the queue
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
    allo += fresh(place(cat, "SpotTub", lift=stations.TUB_SEAT, k=1.5))
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
    if built:
        for spot, build in (("SpotStation2", stations.build_brush_table), ("SpotStation3", stations.build_dryer),
                            ("SpotStation4", stations.build_bubble_bath), ("SpotStation5", stations.build_pawdicure)):
            allo += fresh(place(build(mat), spot))
        for spot, lift, who in (("SpotStation4", stations.BATH_SEAT, "Toffee"), ("SpotStation5", stations.PAW_Z, "Muffin")):
            c = cats.build_cat(who, mat, body="sit")
            if spot == "SpotStation5":
                for o in c:
                    o.location += Vector((0.0, 0.35 / 1.5, 0.0))       # the pawdicure's CatSeat is 0.35 back
            allo += fresh(place(c, spot, lift=lift, k=stations.STATION_CAT_SCALE))
        allo += fresh(place(spa_props.build_suds_bed(mat), "SpotMascot"))          # the mascot at home (#297)
        allo += fresh(place(suds_on_bed(mat), "SpotMascot", lift=spa_props.BED_SEAT, k=spa_props.BED_CAT_SCALE))
        tb = Builder()                                                 # the game's placeholder Tools board
        tb.box_base((1.0, -2.0, F), (3.0, 0.5, 4.0), "wood_light", bevel=False)
        allo += fresh([tb.finalize("ToolsBoardStandIn", mat, bevel=0)])
        back = avatar(mat, skin="skin_deep", shirt="spa_sky", pants="pants_navy")   # the spawnView spawn, facing the street
        back.location = Vector((0.0, 3.0, F))
        allo += fresh([back])
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
    if built:
        views = {"top": views["top"], "player": views["player"],
                 "left": dict(eye=(4.0, -11.0, F + 10.0), target=(-13.0, -3.0, F + 1.5), lens=20),
                 "back": dict(eye=(0.0, 9.3, F + 8.0), target=(-4.0, -6.0, F + 1.5), lens=18),
                 # the mascot from the queue side (#333), at the follow camera's distance, the line full
                 "mascot": dict(eye=(1.5, -3.0, F + 7.5), target=(9.3, -14.0, F + 1.3), lens=26)}
    made = []
    only = os.environ.get("ONLY", "")
    for key, v in views.items():
        if only and key != only:
            continue
        path = os.path.join(out_dir, f"{date}-{stem}-{key}.png")
        hide = ("_Roof",) if key in ("top", "player", "entrance", "left", "back") else ("_Glass",)   # Roblox draws the glass 0.6 clear
        shot(allo, path, v["eye"], v["target"], v["lens"], hide=hide)
        made.append(path)
    del math
    return made


def opening_board(mat, out_dir, only=""):
    """The opening as the owner described it (2026-11-24), in eight frames for the ui-designer's storyboard (#279,
    #297): a delivery truck jolts over a bump outside the spa, a plain brown box falls out of the back and lands in
    front of the player, a muddy stray is inside, the player washes him, and he becomes Suds the mascot.
    a1 and a2 are the quick intro shot (a low road camera, then the box at the player's feet); a to f are from a play
    camera. Poses are stand-ins for Motion-FX's motion: the cats have a walking and a sitting body only."""
    import math
    import opening
    import plot
    import spa_props
    import street
    from mathutils import Matrix
    F, ROADZ = plot.FLOOR, 0.22
    rad = math.radians
    n = [0]

    def fresh(objs):
        n[0] += 1
        for o in objs:
            o.name = f"O{n[0]}_{o.name}"
        return objs

    def xf(objs, M):
        bpy.context.view_layer.update()                # a new object's matrix_world lags its location until now
        for o in objs:
            o.matrix_world = M @ o.matrix_world
        return objs

    def T(x, y, z):
        return Matrix.Translation((x, y, z))

    def R(deg, axis):
        return Matrix.Rotation(rad(deg), 4, axis)

    def at_spot(objs, spot, lift=0.0, k=1.0):
        x, y, z, turn = plot.SPOTS[spot]
        return xf(objs, T(x, y, F + z + lift) @ R(turn, "Z") @ Matrix.Scale(k, 4))

    def turn_about(objs, suffixes, pivot, M):
        """Turn the pieces whose names end in `suffixes` about `pivot` (a pose: a head roll, a tail whip)."""
        P = Matrix.Translation(pivot)
        bpy.context.view_layer.update()
        xf([o for o in objs if o.name.endswith(suffixes)], P @ M @ P.inverted())

    HEAD = ("_Head", "_Eye1", "_Eye2", "_EarL", "_EarR")

    # -- the world: the street, the player's spa in slot 1 and its two neighbours, empty
    world = [o for o in street.build_street(mat) if not o.name.endswith("_Barrier")]
    for slot in (1, 2, 3):
        objs = plot.build_plot(mat)
        _move(objs, (street.slot_x(slot), 0, 0))
        for o in objs:
            o.name = f"P{slot}_{o.name}"
        world += objs
    world += fresh(at_spot(stations.build_tub(mat), "SpotTub"))
    world += fresh(at_spot(spa_props.build_chance_board(mat), "SpotBoard"))
    world += fresh(at_spot(spa_props.build_window_sign(mat), "SpotSign"))
    world += fresh(at_spot(spa_props.build_tip_jar(mat), "SpotTipJar"))
    for i in range(1, 5):
        world += fresh(at_spot(spa_props.build_cushion(mat), f"SpotWindow{i}"))
    bump_x, lane = plot.SPOTS["SpotBump"][0], plot.SPOTS["SpotBump"][1]         # the near lane's middle
    world += fresh(at_spot(opening.build_pothole(mat), "SpotBump"))               # the pothole, since #343

    def truck(x, pitch=0.0, door=0.0):
        """The truck in the near lane, nose toward -X (the player's right), its middle at x."""
        objs = opening.build_truck(mat)
        bpy.context.view_layer.update()
        axle = (0.0, opening.WHEELS["BL"][1], opening.AXLE_Z)
        M = T(x, lane, ROADZ) @ R(-90, "Z") @ T(*axle) @ R(-pitch, "X") @ T(*axle).inverted()
        for o in objs:
            if o.name.endswith("_Door"):
                o.matrix_world = o.matrix_world @ R(door, "X")
        return fresh(xf(objs, M))

    def box(M, open_=0.0):
        objs = opening.build_box(mat)
        bpy.context.view_layer.update()
        for o in objs:
            for kind, (axis, sign) in opening.FLAP_TURN.items():
                if o.name.endswith("_Flap" + kind):
                    o.matrix_world = o.matrix_world @ R(sign * open_, axis)
        return fresh(xf(objs, M))

    def player(x, y, turn=0.0, z=F, arms="down"):
        return fresh(xf([avatar(mat, skin="skin_tan", shirt="spa_sky", pants="pants_navy", arms=arms)],
                        T(x, y, z) @ R(turn, "Z")))

    def loaf():
        """The stray held: the loaf body (loaf.py, #318), its belly on the base."""
        import loaf as loaf_body
        return loaf_body.build_loaf("Suds", mat, True)[0]

    def stray(body="sit", keep_mud=True):
        objs = dirt.build_dirty("Suds", mat, body)[0]
        if not keep_mud:
            objs = _drop(objs, [f"_Mud{i:02d}" for i in range(1, 21, 2)] + ["_Tangle01", "_Tangle03", "_Tangle05"])
        return objs

    PX, PY = plot.SPOTS["SpotOpening"][0], plot.SPOTS["SpotOpening"][1]       # the player, on the pavement
    BX, BY = plot.SPOTS["SpotBox"][0], plot.SPOTS["SpotBox"][1]               # where the box comes to rest
    jolt = bump_x - opening.WHEELS["FL"][1]                                   # the truck's middle, front wheels in the pothole
    tail = jolt + opening.T_L / 2
    frames = {}

    # a1: the jolt, from a low camera on the road behind the truck: the nose drops into the pothole
    tr = truck(jolt, pitch=-4.0, door=58.0)
    air = box(T(tail - 1.6, lane + 0.3, 3.4) @ R(28, "Y") @ R(-24, "X") @ R(15, "Z") @ T(0, 0, -0.9))
    frames["a1-truck-jolt"] = dict(objs=tr + air + player(PX, PY), eye=(tail + 13.5, -47.0, 1.5),
                                   target=(jolt - 3.0, -35.5, 3.9), lens=24, hide=("_Glass",))
    # a2: the box bouncing on the pavement at the player's feet, the truck driving off
    far = truck(jolt - 21.0, door=20.0)
    bounce = box(T(BX + 0.4, BY - 0.2, F + 0.75) @ R(-22, "Y") @ R(14, "X") @ T(0, 0, -0.2))
    frames["a2-box-bounce"] = dict(objs=far + bounce + player(PX, PY), eye=(PX + 6.5, BY - 3.8, 1.5),
                                   target=(BX + 0.6, BY + 0.6, 2.3), lens=28, hide=("_Glass",))
    # a: a beat later from the play camera: the back wheels cross the bump, the box is out and falling
    on = bump_x - opening.WHEELS["BL"][1]
    tr2 = truck(on, pitch=-3.0, door=42.0)
    air2 = box(T(on + opening.T_L / 2 + 2.6, lane + 2.6, 3.3) @ R(30, "Y") @ R(-20, "X") @ R(25, "Z") @ T(0, 0, -0.9))
    cam = dict(eye=(PX + 1.0, PY + 10.5, F + 7.6), target=(on + 2.5, -35.0, 2.2), lens=22, hide=("_Glass", "_Roof"))
    frames["a-truck-passes"] = dict(objs=tr2 + air2 + player(PX, PY), **cam)
    # b: the box landed, rocking
    rock = box(T(BX, BY, F) @ R(18, "Z") @ T(-1.2, 0, 0) @ R(7, "Y") @ T(1.2, 0, 0))
    near = dict(eye=(PX + 11.5, PY + 3.6, F + 6.4), target=(BX - 1.2, BY + 1.6, F + 2.1), lens=30, hide=("_Glass", "_Roof"))
    frames["b-box-landed"] = dict(objs=rock + player(PX, PY), **near)
    # c: the box open, the muddy stray looking out
    Mb = T(BX, BY, F) @ R(18, "Z")
    opened = box(Mb, open_=opening.FLAP_OPEN)
    peek = fresh(xf(stray("sit"), Mb @ R(160, "Z") @ T(0, 0, opening.BOX_SEAT + 0.72)))
    frames["c-stray-peeks"] = dict(objs=opened + peek + player(PX - 2.4, BY + 1.6, turn=-35),
                                   eye=(BX + 0.8, BY + 6.4, F + 4.6), target=(BX, BY, F + 1.6), lens=34,
                                   hide=("_Glass", "_Roof"))
    # c2: the player lifts him out and carries him to the spa door (owner 2026-11-24: "we should pick him up out of
    # crate"). Seen from the front: from behind, the player's own body hides him.
    cx, cy = PX - 1.5, BY + 4.4
    empty = box(Mb, open_=opening.FLAP_OPEN)
    held = fresh(xf(loaf(), T(cx, cy, F) @ R(180, "Z") @ held_at()))
    frames["c2-carry"] = dict(objs=empty + held + player(cx, cy, turn=180, arms="hold"),
                              eye=(cx - 1.5, cy + 8.4, F + 5.0), target=(cx + 1.0, cy, F + 3.0), lens=30,
                              hide=("_Glass", "_Roof"))
    # d: in the tub, still muddy, in the close wash view: the sponge beside him and foam on one side
    wash = fresh(at_spot(stray("sit"), "SpotTub", lift=stations.TUB_SEAT, k=1.5))
    sp = tools.build_sponge("CleanACat_Tool_Sponge", mat)
    tx, ty = plot.SPOTS["SpotTub"][0], plot.SPOTS["SpotTub"][1]
    fresh(xf(sp, T(tx - 1.2, ty - 1.15, F + 4.15) @ R(-18, "Y") @ R(24, "Z")))
    fb = Builder()
    for x, y, z, r in ((1.5, -0.9, 3.5, 0.3), (1.9, -0.3, 3.55, 0.26), (1.45, 0.4, 3.5, 0.3), (1.75, -1.25, 3.6, 0.22),
                       (1.2, -1.3, 3.45, 0.24), (1.6, -0.5, 3.95, 0.2), (2.0, -1.0, 4.7, 0.14), (2.3, -0.5, 5.2, 0.11)):
        fb.sphere((tx + x, ty + y, F + z), r, "foam", segments=8, rings=5)
    foam = fresh([fb.finalize("Lather", mat)])
    # the close wash view (owner 2026-11-24: once he is in the tub the view switches to the close-up wash view): no
    # avatar in it
    tubcam = dict(eye=(tx + 4.5, ty - 9.3, F + 9.2), target=(tx + 0.1, ty - 0.1, F + 2.5), lens=40, hide=("_Roof",))
    frames["d-scrub"] = dict(objs=wash + sp + foam, **tubcam)
    # e: clean, collar on, shaking off
    clean = cats.build_cat("Suds", mat, body="sit")
    k = cats.scale_of(cats.spec_of("Suds"), "sit")
    j = cats.joints(cats.spec_of("Suds"), "sit")
    turn_about(clean, HEAD, j["Head"], R(20, "Y") @ R(-8, "X"))
    turn_about(clean, ("_Tail",), j["Tail"], R(35, "Z"))
    shake = fresh(at_spot(clean, "SpotTub", lift=stations.TUB_SEAT, k=1.5))
    sb = Builder()
    X = (rad(90), "X")
    for x, z, r in ((-1.7, 4.9, 0.34), (1.6, 5.3, 0.3), (-1.2, 3.2, 0.22), (1.9, 3.6, 0.24), (0.2, 6.0, 0.26)):
        sb.star((tx + x, ty - 0.9, F + z), r, r * 0.42, 0.1, "fur_golden", points=4, rot=X)
    for x, y, z in ((-1.5, -0.6, 4.2), (1.3, -0.7, 4.6), (-0.9, -0.4, 5.6), (1.0, 0.2, 5.8), (-2.0, 0.1, 3.7), (2.2, -0.2, 4.4)):
        sb.sphere((tx + x, ty + y, F + z), 0.11, "water", segments=6, rings=4)
    spark = fresh([sb.finalize("Sparkles", mat)])
    frames["e-suds-clean"] = dict(objs=shake + spark, **tubcam)
    # f: Suds in his bed by the entrance
    bed = fresh(at_spot(spa_props.build_suds_bed(mat), "SpotMascot"))
    home = fresh(at_spot(suds_on_bed(mat), "SpotMascot", lift=spa_props.BED_SEAT, k=spa_props.BED_CAT_SCALE))
    mx, my = plot.SPOTS["SpotMascot"][0], plot.SPOTS["SpotMascot"][1]
    frames["f-suds-home"] = dict(objs=bed + home + player(mx + 3.0, my + 3.8, turn=137),
                                 eye=(mx - 5.5, my + 7.5, F + 5.4), target=(mx + 0.6, my + 0.6, F + 2.7), lens=30,
                                 hide=("_Roof",))
    os.makedirs(out_dir, exist_ok=True)
    made = []
    for key, f in frames.items():
        if only and not any(w in key for w in only.split(",")):
            continue
        path = os.path.join(out_dir, f"2026-11-24-opening-{key}.png")
        shot(world + f["objs"], path, f["eye"], f["target"], f["lens"], res=(1280, 720), samples=32, hide=f["hide"])
        made.append(path)
    del math
    return made


if __name__ == "__main__":
    which, out = sys.argv[-2], sys.argv[-1]
    common.reset_scene()
    png = os.path.join(HERE, "..", "exports", palette.TEXTURE_NAME + ".png")
    mat = common.palette_material(png)
    {"plot-built": lambda m, o: plot_views(m, o, stem="plot-built", date="2026-11-24", built=True),
     "opening": lambda m, o: opening_board(m, o, os.environ.get("ONLY", "")),
     "tub": tub, "groom": groom, "groom-close": lambda m, o: groom(m, o, close=True), "plot": plot_views,
     "customers": customers_sheet, "stations": stations_sheet,
     "builder": builder_sheet, "vip": vip_views, "index": index_sheet, "street": street_views, "mud": mud_close,
     "foam": foam_close, "later": later_stations_sheet,
     "builder-close": lambda m, o: builder_sheet(m, o, close=True)}[which](mat, out)
