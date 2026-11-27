"""One picture for every thing a player can buy (#1122). Pictures only, never exported.

    blender python: ui_renders.py <raw folder> --only shop_Build,shop_Tool,shop_Bow,shop_Crate,shop_Finish,shop_Coins

Derek, 2026-11-27: "I am seeing certain items to buy sharing same icon fix that". The Build window drew one hammer
for all eleven builds, one toolbox for both tools and one pink bow for every bow, the two coin passes were the same
heap with another number, and the passes and products on Roblox had no picture at all. Each buyable thing now has
its own, different in shape and colour at card size and never only by a small tag:

  shop_Build_<Id>     the build itself: the station's model, two, three or four tubs with the number, the Garden,
                      the Cat Hotel, and a hotel room in its own colour with its own sleeping cat and number
  shop_Tool_<Id>      the tool's own model
  shop_Bow_<Tier>     that tier's bow (Silk the double bow, Satin the royal bow, Golden the golden bow)
  shop_Coins2x        two stacks of coins and "2x"; shop_Coins3x a chest brimming with coins and "3x"
  shop_Crate1         one pet crate; shop_Crate5 a stack of five and "x5"
  shop_Finish<n>      a stopwatch in its tier's colour, the hand further round each tier, with the tier's time

No hands, no money signs (Review-QA's image gate). ui_compose.py trims each to 512 px and adds the ink outline.
"""

import math

import bpy
from mathutils import Matrix, Vector

import common
import shop_art
from shop_art import WHITE, STAR, sparkle, word

AZ = math.radians(shop_art.VIEW[0])
FACE = Matrix.Rotation(AZ, 3, "Z") @ Matrix.Rotation(math.pi / 2, 3, "X")     # a flat thing turned to the camera


def _model(makers, mat, name):
    built = makers[name][0](mat)
    objs = built[0] if isinstance(built, tuple) else built
    keep = []
    for ob in objs:
        if ob.name.endswith(("_Barrier", "_Star2", "_Star3", "_Star3_Glow")):
            bpy.data.objects.remove(ob, do_unlink=True)
        else:
            keep.append(ob)
    bpy.context.view_layer.update()
    return keep


def _move(objs, at=(0, 0, 0), turn=0.0, scale=1.0):
    m = Matrix.Translation(at) @ Matrix.Rotation(math.radians(turn), 4, "Z") @ Matrix.Scale(scale, 4)
    for ob in objs:
        ob.matrix_world = m @ ob.matrix_world
    bpy.context.view_layer.update()
    return objs


def _twinkles(objs, mat, spots, name="CleanACat_Twinkles"):
    """Sparkles in front of objs; spots are (across, up, size) as parts of the model's box."""
    lo, hi = common.bounds(objs)
    w, h = hi.x - lo.x, hi.z - lo.z
    b = common.Builder()
    for i, (fx, fz, k) in enumerate(spots):
        sparkle(b, (lo.x + fx * w, lo.y - 0.3, lo.z + fz * h), k * max(w, h), WHITE if i % 2 else STAR)
    return b.finalize(name, mat, bevel=0)


def station(name, turn=0.0):
    def make(mat, makers):
        return _move(_model(makers, mat, name), turn=turn)
    return make


def tubs(n):
    """Two, three or four tubs and the number, big, in front."""
    spots = {2: ((-0.55, 0.0), (0.55, 0.35)),
             3: ((-0.55, 1.0), (0.55, 1.0), (0.0, 0.0)),
             4: ((-0.55, 1.0), (0.55, 1.0), (-0.55, 0.0), (0.55, 0.0))}[n]

    def make(mat, makers):
        objs = []
        first = _model(makers, mat, "CleanACat_Station_Tub")
        lo, hi = common.bounds(first)
        w, d = hi.x - lo.x, hi.y - lo.y
        _move(first, at=(spots[0][0] * w * 1.08, spots[0][1] * d * 1.15, 0))
        objs += first
        for fx, fy in spots[1:]:
            objs += _move(_model(makers, mat, "CleanACat_Station_Tub"), at=(fx * w * 1.08, fy * d * 1.15, 0))
        lo, hi = common.bounds(objs)
        size = (hi.z - lo.z) * 1.25
        objs += word(str(n), size, ((lo.x + hi.x) / 2 + (hi.x - lo.x) * 0.32, lo.y - 0.5, lo.z + size * 0.1), mat)
        return objs
    return make


ROOM = {3: ("spa_mint", "CleanACat_Cat_Tux_Loaf_Lite"), 4: ("pastel_butter", "CleanACat_Cat_Marble_Loaf_Lite")}


def hotel_room(n):
    """One hotel room: its arch and back wall in the room's own colour, a cat asleep on the bed and the number."""
    col, cat = ROOM[n]

    def make(mat, makers):
        b = common.Builder()
        b.box_base((0, 1.4, 0), (4.2, 0.2, 3.6), col, bevel=False)                    # back wall
        b.box_base((0, 0.0, -0.12), (4.6, 3.2, 0.12), "wood_light", bevel=False)      # floor
        for x in (-2.15, 2.15):
            b.box_base((x, -0.2, 0), (0.36, 0.36, 3.9), "offwhite", bevel=False)      # posts
        b.box((0, -0.2, 4.1), (4.9, 0.44, 0.6), col, bevel=False)                     # arch beam
        b.box_base((0, 0.2, 0.0), (2.8, 1.8, 0.07), "milk", bevel=False)              # mat
        objs = [b.finalize(f"CleanACat_RoomCard{n}", mat, bevel=0)]
        bed = _model(makers, mat, "CleanACat_Prop_Cushion")
        lo, hi = common.bounds(bed)
        k = 2.2 / (hi.x - lo.x)
        _move(bed, at=(0, 0.2, 0.07), scale=k)
        top = common.bounds(bed)[1].z
        puss = _model(makers, mat, cat)
        lo, hi = common.bounds(puss)
        _move(puss, at=(-(lo.x + hi.x) / 2 * 1.5, 0.2 - (lo.y + hi.y) / 2 * 1.5, top - 0.12 - lo.z * 1.5), scale=1.5)
        objs += bed + puss
        objs += word(str(n), 2.6, (1.25, -0.9, 2.2), mat)
        return objs
    return make


def bow(look, twinkle=0):
    def make(mat, makers):
        objs = _model(makers, mat, "CleanACat_Bow_Pink" + look)
        if twinkle:
            objs.append(_twinkles(objs, mat, ((-0.05, 0.95, 0.2), (1.02, 0.8, 0.15), (0.92, 0.1, 0.12))[:twinkle]))
        return objs
    return make


def tool(name, turn=0.0):
    def make(mat, makers):
        return _move(_model(makers, mat, name), turn=turn)
    return make


def coins2(mat, makers):
    """Two neat stacks of coins, one taller, and "2x"."""
    b = common.Builder()
    for x, y, n in ((-0.62, 0.15, 7), (0.62, 0.0, 10)):
        for j in range(n):
            shop_art._coin(b, (x + 0.03 * math.sin(j * 2.1), y + 0.03 * math.cos(j * 1.7), 0.08 + 0.17 * j), (0, 0), j * 0.7)
    objs = [b.finalize("CleanACat_CoinStacks", mat)]
    objs += word("2x", 1.25, (0.55, -0.95, 0.35), mat)
    s = common.Builder()
    sparkle(s, (-1.05, -0.3, 1.55), 0.26)
    sparkle(s, (1.3, -0.3, 1.95), 0.2, WHITE)
    objs.append(s.finalize("CleanACat_Sparkles", mat, bevel=0))
    return objs


def coins3(mat, makers):
    """A wooden chest, lid thrown back, heaped over the brim with coins, and "3x"."""
    b = common.Builder()
    W, D, H = 3.0, 1.9, 1.25
    b.box_base((0, 0, 0), (W, D, H), "caramel_wood", bevel=False)
    for x in (-W / 2 + 0.2, 0.0, W / 2 - 0.2):                                         # gold bands
        b.box_base((x, 0, -0.01), (0.3, D + 0.08, H + 0.03), "gold_mid", bevel=False)
    b.box((0, -D / 2 - 0.06, H * 0.72), (0.5, 0.1, 0.56), "gold_light", bevel=False)   # the lock plate
    lid = Matrix.Rotation(math.radians(-62), 3, "X")
    hinge = Vector((0, D / 2, H))
    for dx, sw, wide in ((0.0, "caramel_wood", W), (-W / 2 + 0.2, "gold_mid", 0.3), (W / 2 - 0.2, "gold_mid", 0.3)):
        up = 0.0 if sw == "caramel_wood" else 0.02
        b.box(tuple(hinge + lid @ Vector((dx, -D / 2, 0.22))), (wide, D + up * 3, 0.44 + up * 2), sw, bevel=False, rot=lid)
    heap = [(-0.95, -0.35, 0.05), (-0.3, -0.5, 0.12), (0.4, -0.45, 0.1), (1.0, -0.3, 0.04), (-0.65, 0.1, 0.3),
            (0.05, 0.0, 0.42), (0.7, 0.1, 0.3), (-0.2, 0.4, 0.3), (0.45, 0.45, 0.22), (-0.9, 0.45, 0.12),
            (1.05, 0.35, 0.1), (0.1, -0.2, 0.62)]
    for i, (x, y, z) in enumerate(heap):
        shop_art._coin(b, (x, y, H + 0.1 + z), (0.5 * math.sin(i * 1.3), 0.5 * math.cos(i * 2.1)), i * 0.9)
    for i, (x, z) in enumerate(((-1.9, 0.5), (1.95, 0.5), (-1.45, 0.16))):             # spilled in front
        shop_art._coin(b, (x, -D / 2 - 0.5, z) if z > 0.3 else (x, -D / 2 - 0.7, 0.09),
                       (math.pi / 2 - 0.25, 0) if z > 0.3 else (0, 0), AZ)
    fill = common.Builder()
    fill.sphere((0, 0, H), 1.0, "gold_mid", segments=20, rings=10, scale=(W * 0.44, D * 0.42, 0.55))
    objs = [b.finalize("CleanACat_CoinChest", mat, bevel=0), fill.finalize("CleanACat_CoinChestFill", mat, bevel=0)]
    objs += word("3x", 1.5, (0.95, -D / 2 - 0.9, 0.4), mat)
    s = common.Builder()
    sparkle(s, (-1.5, -D / 2, H + 1.35), 0.34)
    sparkle(s, (0.2, -D / 2, H + 1.7), 0.26, WHITE)
    sparkle(s, (1.75, -D / 2, H + 1.0), 0.22)
    objs.append(s.finalize("CleanACat_Sparkles", mat, bevel=0))
    return objs


def crates(n):
    def make(mat, makers):
        if n == 1:
            objs = _move(_model(makers, mat, "CleanACat_Prop_PetCrate"), turn=-16)
            objs.append(_twinkles(objs, mat, ((-0.04, 0.98, 0.14), (1.02, 0.7, 0.1))))
            return objs
        first = _model(makers, mat, "CleanACat_Prop_PetCrate")
        lo, hi = common.bounds(first)
        w, h = (hi.x - lo.x) * 1.04, (hi.z - lo.z) * 0.8
        spots = ((-w, 0, 0, -8), (0, 0, 0, 6), (w, 0, 0, -4), (-w / 2, 0.1, h, 5), (w / 2, 0.1, h, -7))
        objs = _move(first, at=spots[0][:3], turn=spots[0][3])
        for x, y, z, t in spots[1:]:
            objs += _move(_model(makers, mat, "CleanACat_Prop_PetCrate"), at=(x, y, z), turn=t)
        lo, hi = common.bounds(objs)
        objs += word("x5", (hi.z - lo.z) * 0.42, (hi.x - (hi.x - lo.x) * 0.2, lo.y - 0.5, lo.z + (hi.z - lo.z) * 0.1), mat)
        return objs
    return make


# tier: the stopwatch's colour, how far round the hand is, and the time left the tier covers
FINISH = {1: ("spa_mint", 60, "5m"), 2: ("pastel_sky", 130, "30m"), 3: ("pastel_lilac", 200, "2h"),
          4: ("spa_bubblegum", 270, "8h"), 5: ("gold_mid", 340, "8h+")}


def finish(tier):
    col, sweep, label = FINISH[tier]

    def at(u, v, d=0.0):                       # across, up and toward the camera, for a watch facing it
        return tuple(Matrix.Rotation(AZ, 3, "Z") @ Vector((u, -d, v)))

    def make(mat, makers):
        b = common.Builder()
        b.cyl(at(0, 0), 1.3, 0.5, col, segments=32, rot=FACE)
        b.cyl(at(0, 0, 0.26), 1.06, 0.04, "milk", segments=32, bevel=False, rot=FACE)
        b.box(at(0, 1.5), (0.5, 0.36, 0.44), col, bevel=False, rot=Matrix.Rotation(AZ, 3, "Z"))          # the crown
        b.box(at(0, 1.78), (0.8, 0.4, 0.2), "gold_mid", bevel=False, rot=Matrix.Rotation(AZ, 3, "Z"))
        for i in range(sweep // 10 + 1):                                                                    # time gone
            a = math.radians(i * 10)
            b.cyl(at(0.5 * math.sin(a), 0.5 * math.cos(a), 0.285 + 0.0006 * i), 0.5, 0.02, col, segments=12, bevel=False, rot=FACE)
        for k in range(12):                                                                                 # ticks
            a = math.radians(k * 30)
            b.cyl(at(0.92 * math.sin(a), 0.92 * math.cos(a), 0.3), 0.06, 0.03, "fur_ink", segments=8, bevel=False, rot=FACE)
        a = math.radians(sweep)
        hand = Matrix.Rotation(AZ, 3, "Z") @ Matrix.Rotation(-a, 3, "Y")
        b.box(at(0.42 * math.sin(a), 0.42 * math.cos(a), 0.33), (0.14, 0.05, 0.9), "fur_ink", bevel=False, rot=hand)
        b.cyl(at(0, 0, 0.34), 0.14, 0.06, "fur_ink", segments=12, bevel=False, rot=FACE)
        objs = [b.finalize(f"CleanACat_Stopwatch{tier}", mat, bevel=0)]
        objs += word(label, 1.0 if len(label) < 3 else 0.82, at(0.55, -1.15, 0.9), mat)
        return objs
    return make


SHOTS = {
    "shop_Build_BrushTable": station("CleanACat_Station_BrushTable"),
    "shop_Build_Dryer": station("CleanACat_Station_Dryer"),
    "shop_Build_BubbleBath": station("CleanACat_Station_BubbleBath"),
    "shop_Build_Pawdicure": station("CleanACat_Station_Pawdicure"),
    "shop_Build_SecondTub": tubs(2),
    "shop_Build_ThirdTub": tubs(3),
    "shop_Build_FourthTub": tubs(4),
    "shop_Build_Garden": station("CleanACat_Area_Garden"),
    "shop_Build_CatHotel": station("CleanACat_Area_Hotel"),
    "shop_Build_HotelRoom3": hotel_room(3),
    "shop_Build_HotelRoom4": hotel_room(4),
    "shop_Tool_BubbleSoap": tool("CleanACat_Tool_SpongeBubble"),
    "shop_Tool_ProBrush": tool("CleanACat_Tool_BrushFluffy"),
    "shop_Bow_Silk": bow("Double"),
    "shop_Bow_Satin": bow("Royal", 1),
    "shop_Bow_Golden": bow("Golden", 3),
    "shop_Coins2x": coins2,
    "shop_Coins3x": coins3,
    "shop_Crate1": crates(1),
    "shop_Crate5": crates(5),
    **{f"shop_Finish{t}": finish(t) for t in FINISH},
}

# a view of its own where the shop's low one hides the thing: (azimuth, elevation) in degrees
VIEWS = {
    "shop_Build_SecondTub": (18, 26), "shop_Build_ThirdTub": (18, 34), "shop_Build_FourthTub": (18, 34),
    "shop_Build_Garden": (28, 36), "shop_Build_CatHotel": (24, 34),
    "shop_Build_BrushTable": (24, 22), "shop_Build_Dryer": (24, 22), "shop_Build_BubbleBath": (24, 26),
    "shop_Build_Pawdicure": (24, 22), "shop_Crate5": (18, 20), "shop_Crate1": (18, 22),
    "shop_Tool_BubbleSoap": (24, 24), "shop_Tool_ProBrush": (24, 24),
}
