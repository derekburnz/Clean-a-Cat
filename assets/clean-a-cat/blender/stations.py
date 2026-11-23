"""Spa stations (issue #13 for the tub, #18 for the brush tables and the dryer).

  CleanACat_Station_Tub   the wash tub, the first thing a player sees: a low bath on four feet with a mint rim, a
                          shallow pool of water (_Water), foam (_Foam) and a tap at the back. It matches the
                          placeholder PH_Tub's seat height (1.2 studs) but is smaller (4.6 wide, 3.8 deep) so the cat
                          fills more of a phone screen; the design asks for the cat bigger than life at the tub.
                          Attachment `CatSeat` on the inner floor, facing the player (-Z in Roblox): put the sitting
                          cat's pivot there. The walls and body collide; water and foam do not.

  CleanACat_Station_BrushTable    the grooming table: a wooden table on four legs with a mint rubber mat, a towel on
                                  the shelf underneath. `CatSeat` on the mat.
  CleanACat_Station_BrushTableUp  its upgrade, same footprint, pivot and CatSeat: painted cream with round legs and
                                  bubblegum feet, a puffy cushion top and a mint brush rack at the back with three
                                  brushes and a bow. Swap one for the other in place.
  CleanACat_Station_Dryer         a hood dryer over a round stool: the hood hangs from an arm on a pole behind the
                                  stool. Its nozzle is a part named `Nozzle` under the hood, with an Attachment `Air`
                                  whose +Y points down at the cat, for Motion-FX's air puffs. `CatSeat` on the stool.

The brush tables and the dryer fit the 5 by 5 stud station pads (SpotStation2, SpotStation3 in the plot) and stand
inside them. The cat sits on them at ScaleTo(CatScale) (root attribute, 1.5, the same as at the tub). Their thin
legs and boards are too slim to collide, so an invisible `_Barrier` under each top keeps players from walking through
(CanQuery off: taps and the camera pass through it).

Pivot at the base centre on the floor, the front (where the player stands) at -Y in Blender, -Z in Roblox.
"""

import math

from mathutils import Matrix

from common import Builder

TUB_W, TUB_D = 4.6, 3.8          # outer footprint, studs
FOOT_H = 0.25                    # the tub stands on four feet
SEAT_Z = 1.2                     # inner floor top: where the cat sits (PH_Tub's base top)
RIM_Z = 1.6                      # top of the walls; a sitting cat (1.85 tall) shows above it from the chest up
WALL = 0.35                      # wall thickness
CORNER = 0.45                    # radius of the rounded corners
WATER_Z = 1.34                   # water surface (shallow: paws and belly in the water)


def _tub_shell(b):
    """Body, rounded walls and the mint rim, all solid."""
    w, d = TUB_W, TUB_D
    # Every piece below is staggered by a hundredth of a stud from its neighbours (E) so no two faces share a plane:
    # shared planes fight in the FBX and merge badly when the builder welds touching corners.
    E = 0.012
    # lower body under the floor, its sides tucked into the walls
    b.box_base((0, 0, FOOT_H + 2 * E), (w - 2 * WALL + 0.04, d - 2 * WALL + 0.04, SEAT_Z - FOOT_H - 5 * E), "spa_cream",
               bevel=False)
    # straight walls (front and back long, sides short), stopping inside the corner posts
    hw = RIM_Z - FOOT_H - 2 * E
    for sy in (1, -1):
        b.box_base((0, sy * (d / 2 - WALL / 2), FOOT_H + E), (w - 2 * CORNER, WALL, hw), "spa_cream", bevel=False)
    for sx in (1, -1):
        b.box_base((sx * (w / 2 - WALL / 2), 0, FOOT_H + E), (WALL, d - 2 * CORNER, hw), "spa_cream", bevel=False)
    # round corner posts
    for sx in (1, -1):
        for sy in (1, -1):
            b.cyl_base((sx * (w / 2 - CORNER), sy * (d / 2 - CORNER), FOOT_H), CORNER, RIM_Z - FOOT_H - E / 2,
                       "spa_cream", segments=10, bevel=False)
    # a mint band round the outside, a little proud of the walls
    band_z, band_h = FOOT_H + 0.45, 0.3
    for sy in (1, -1):
        b.box_base((0, sy * (d / 2 + 0.02), band_z), (w - 2 * CORNER - 2 * E, 0.06, band_h), "spa_mint", bevel=False)
    for sx in (1, -1):
        b.box_base((sx * (w / 2 + 0.02), 0, band_z), (0.06, d - 2 * CORNER - 2 * E, band_h), "spa_mint", bevel=False)
    for sx in (1, -1):
        for sy in (1, -1):
            b.cyl_base((sx * (w / 2 - CORNER), sy * (d / 2 - CORNER), band_z - E), CORNER + 0.03, band_h + 2 * E,
                       "spa_mint", segments=10, bevel=False)
    # rim cap: mint, slightly wider than the wall, so the top edge reads from the player's camera
    cap = 0.1
    for sy in (1, -1):
        b.box_base((0, sy * (d / 2 - WALL / 2), RIM_Z), (w - 2 * CORNER, WALL + 0.08, cap), "spa_mint", bevel=False)
    for sx in (1, -1):
        b.box_base((sx * (w / 2 - WALL / 2), 0, RIM_Z), (WALL + 0.08, d - 2 * CORNER, cap), "spa_mint", bevel=False)
    for sx in (1, -1):
        for sy in (1, -1):
            b.cyl_base((sx * (w / 2 - CORNER), sy * (d / 2 - CORNER), RIM_Z - 1.5 * E), CORNER + 0.04, cap + 2.5 * E,
                       "spa_mint", segments=10, bevel=False)   # a hair taller than the straight caps both ways
    # inner floor, a tile colour, just under the water
    b.box_base((0, 0, SEAT_Z - 0.02), (w - 2 * WALL - 0.02, d - 2 * WALL - 0.02, 0.02), "spa_tile", bevel=False)


def _feet(b):
    for sx in (1, -1):
        for sy in (1, -1):
            b.cyl_base((sx * (TUB_W / 2 - 0.6), sy * (TUB_D / 2 - 0.6), 0.0), 0.24, FOOT_H + 0.02, "spa_bubblegum",
                       segments=8, bevel=False)


def _tap(b):
    """A tap on the back rim, pointing in."""
    y = TUB_D / 2 - WALL / 2
    b.cyl_base((0, y, RIM_Z + 0.08), 0.14, 0.55, "metal", segments=10)     # sunk a little into the rim
    b.box((0, y - 0.32, RIM_Z + 0.6), (0.18, 0.75, 0.18), "metal")
    b.cyl((0, y - 0.66, RIM_Z + 0.5), 0.1, 0.16, "metal", segments=8)
    for sx in (1, -1):                                  # two knobs, hot pink and cool sky
        b.sphere((sx * 0.38, y, RIM_Z + 0.2), 0.13, "spa_bubblegum" if sx > 0 else "spa_sky", segments=8, rings=4)


def _water():
    b = Builder()
    b.box((0, 0, WATER_Z - 0.065), (TUB_W - 2 * WALL - 0.04, TUB_D - 2 * WALL - 0.04, 0.13), "spa_sky", bevel=False)
    return b


# Foam: clusters on the water by the walls and on two rim corners. (x, y, z, radius)
FOAM = [(-1.55, -1.05, WATER_Z + 0.06, 0.28), (-1.2, -1.2, WATER_Z + 0.04, 0.2), (1.55, 1.05, WATER_Z + 0.06, 0.3),
        (1.2, 1.2, WATER_Z + 0.04, 0.18), (1.6, -0.9, WATER_Z + 0.05, 0.22), (-1.6, 0.95, WATER_Z + 0.05, 0.24),
        (-1.85, -1.5, RIM_Z + 0.17, 0.22), (-1.55, -1.6, RIM_Z + 0.15, 0.15), (1.85, 1.5, RIM_Z + 0.16, 0.2)]


def _foam():
    b = Builder()
    for x, y, z, r in FOAM:
        b.sphere((x, y, z), r, "foam", segments=8, rings=4, scale=(1, 1, 0.7))
    return b


def _tris(ob):
    """Cylinder caps come out as n-gons; split them into triangles (Roblox does it anyway, the QA gate wants it)."""
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 4])
    bm.to_mesh(ob.data)
    bm.free()
    return ob


def build_tub(mat):
    name = "CleanACat_Station_Tub"
    b = Builder()
    _tub_shell(b)
    _feet(b)
    _tap(b)
    objs = [_tris(b.finalize(name, mat)),
            _water().finalize(name + "_Water", mat),
            _foam().finalize(name + "_Foam", mat)]
    return objs


def tub_rbx_extras():
    """CatSeat: the sitting cat's pivot, on the inner floor, facing the player."""
    return {"attachments": [("CleanACat_Station_Tub", "CatSeat", Matrix.Translation((0.0, 0.0, SEAT_Z)))],
            "attributes": {"SeatHeight": {"Float64": SEAT_Z}}}


# -- #18 brush tables and dryer ---------------------------------------------------------------------------------
STATION = 5.0             # the station pad's side; every station stays inside it
STATION_CAT_SCALE = 1.5   # the cat at a station, as big as at the tub (root attribute CatScale)
GROOM_Z = 1.8             # the brush tables' CatSeat: hip high on an avatar, so the cat's face is at the player's chest
TOP_W, TOP_D, TOP_Y = 3.4, 2.4, 0.2     # the table top, centred a little back so the player has room in front
LEG_X, LEG_Y = 1.45, 0.95               # leg centres from the top's centre


def _barrier(name, mat, size, at=(0.0, 0.0, 0.0)):
    """An invisible solid box (exported with Transparency 1 and CanCollide on) under a station's top."""
    b = Builder()
    b.box_base(at, size, "metal", bevel=False)
    ob = b.finalize(name + "_Barrier", mat, bevel=0)
    ob.hide_render = True
    return ob


def build_brush_table(mat):
    name = "CleanACat_Station_BrushTable"
    b = Builder()
    top_z = GROOM_Z - 0.1                                                           # the board's top; the mat on it
    b.box_base((0, TOP_Y, top_z - 0.16), (TOP_W, TOP_D, 0.16), "wood_light")        # the top board
    b.box_base((0, TOP_Y - 0.03, top_z - 0.01), (TOP_W - 0.5, TOP_D - 0.46, 0.11), "spa_mint")   # the rubber mat
    for sx in (1, -1):
        for sy in (1, -1):
            b.box_base((sx * LEG_X, TOP_Y + sy * LEG_Y, 0), (0.28, 0.28, top_z - 0.12), "wood_light")
    b.box_base((0, TOP_Y, 0.42), (2.62, 1.66, 0.12), "wood_light", bevel=False)     # the shelf between the legs
    b.box_base((-0.55, TOP_Y + 0.05, 0.53), (1.1, 0.8, 0.32), "spa_sky")            # a folded towel on it
    b.box_base((-0.55, TOP_Y + 0.05, 0.84), (1.0, 0.72, 0.03), "offwhite", bevel=False)   # its stripe
    b.cyl_base((0.7, TOP_Y - 0.1, 0.53), 0.2, 0.55, "spa_bubblegum", segments=8)    # a shampoo bottle
    b.cyl_base((0.7, TOP_Y - 0.1, 1.07), 0.08, 0.14, "spa_cream", segments=6, bevel=False)
    main = _tris(b.finalize(name, mat))
    return [main, _barrier(name, mat, (TOP_W - 0.62, TOP_D - 0.66, top_z - 0.3), (0, TOP_Y, 0.03))]


def _hanging_brush(b, x, y, z, head):
    """A brush hung by its handle from the rack rail at (x, y, z): handle up, bristles to the front."""
    b.box((x, y - 0.04, z - 0.3), (0.13, 0.1, 0.62), "wood_light", bevel=False)
    b.box((x, y - 0.06, z - 0.78), (0.44, 0.16, 0.46), head, bevel=False)
    b.box((x, y - 0.17, z - 0.78), (0.36, 0.08, 0.38), "foam", bevel=False)
    b.box((x, y - 0.03, z + 0.02), (0.07, 0.09, 0.12), "metal", bevel=False)      # the hook over the rail


def build_brush_table_up(mat):
    name = "CleanACat_Station_BrushTableUp"
    b = Builder()
    top_z = GROOM_Z - 0.24                                                          # the board; the cushion on it
    b.box_base((0, TOP_Y, top_z - 0.16), (TOP_W, TOP_D, 0.16), "spa_cream")
    b.box_base((0, TOP_Y, top_z - 0.13), (TOP_W + 0.06, TOP_D + 0.06, 0.09), "spa_bubblegum", bevel=False)  # a band
    b.box_base((0, TOP_Y - 0.03, top_z - 0.02), (TOP_W - 0.42, TOP_D - 0.5, 0.2), "spa_bubblegum")         # cushion
    b.box_base((0, TOP_Y - 0.03, top_z + 0.15), (TOP_W - 0.82, TOP_D - 0.86, 0.09), "spa_bubblegum")       # its puff
    for sx in (1, -1):                                                              # round legs on ball feet
        for sy in (1, -1):
            x, y = sx * LEG_X, TOP_Y + sy * LEG_Y
            b.cyl_base((x, y, 0.2), 0.15, top_z - 0.3, "spa_cream", segments=8, bevel=False)
            b.sphere((x, y, 0.2), 0.22, "spa_bubblegum", segments=6, rings=4)
    b.box_base((0, TOP_Y, 0.52), (2.66, 1.62, 0.12), "spa_cream", bevel=False)      # the shelf
    for i, sw in enumerate(("spa_sky", "spa_mint")):                               # two folded towels
        b.box_base((-0.6, TOP_Y + 0.05, 0.63 + 0.25 * i), (1.0 - 0.08 * i, 0.74 - 0.06 * i, 0.26), sw)
    b.cyl_base((0.55, TOP_Y - 0.1, 0.63), 0.2, 0.55, "spa_bubblegum", segments=8)   # shampoo and conditioner
    b.cyl_base((0.98, TOP_Y + 0.1, 0.63), 0.17, 0.45, "spa_sky", segments=8)
    # the brush rack at the back: two posts off the back legs, a mint board, a rail with three brushes, a bow on top
    ry = TOP_Y + TOP_D / 2 + 0.11
    for sx in (1, -1):
        b.box_base((sx * 1.52, ry, top_z - 0.5), (0.22, 0.22, 2.95), "spa_mint")
    b.box_base((0, ry + 0.02, top_z + 0.45), (2.86, 0.1, 1.85), "spa_mint", bevel=False)
    b.box_base((0, ry + 0.01, top_z + 2.24), (3.34, 0.2, 0.24), "spa_bubblegum")     # the header
    rail_z = top_z + 1.95
    b.cyl((0, ry - 0.16, rail_z), 0.05, 2.9, "metal", segments=6, bevel=False, rot=Matrix.Rotation(math.pi / 2, 3, "Y"))
    for sx in (1, -1):
        b.box((sx * 1.445, ry - 0.08, rail_z), (0.08, 0.2, 0.12), "metal", bevel=False)   # the rail's brackets
    for x, head in ((-0.85, "spa_bubblegum"), (0.0, "spa_sky"), (0.85, "pastel_butter")):
        _hanging_brush(b, x, ry - 0.16, rail_z, head)
    kz = top_z + 2.6                                                                 # the bow on the header
    b.box((0, ry - 0.08, kz), (0.2, 0.17, 0.18), "bow_pink")
    for sx in (1, -1):
        b.sphere((sx * 0.27, ry - 0.08, kz), 0.22, "bow_pink", segments=8, rings=4, scale=(1.2, 0.5, 0.85))
    main = _tris(b.finalize(name, mat))
    return [main, _barrier(name, mat, (TOP_W - 0.62, TOP_D - 0.66, top_z - 0.3), (0, TOP_Y, 0.03))]


SEAT_DRYER = 1.2                  # the stool's top, as high as the tub's seat
STOOL = (0.0, -0.1)               # the stool's centre (x, y)
POLE_Y = 1.75                     # the dryer's pole, behind the stool
HOOD_Z = 4.45                     # the hood's lower rim: a 1.5 scale sitting cat's ears clear it by about 0.4
HOOD_R = 1.3


def build_dryer(mat):
    name = "CleanACat_Station_Dryer"
    b = Builder()
    sx_, sy_ = STOOL
    b.cyl_base((sx_, sy_, 0), 0.75, 0.16, "spa_cream", segments=12)                 # the stool's foot
    b.cyl_base((sx_, sy_, 0.12), 0.16, SEAT_DRYER - 0.3, "metal", segments=8, bevel=False)    # its post
    b.cyl_base((sx_, sy_, 0.42), 0.55, 0.07, "metal", segments=10, bevel=False)      # a foot ring
    b.cyl_base((sx_, sy_, SEAT_DRYER - 0.24), 1.0, 0.18, "spa_bubblegum", segments=14, bevel=False)   # the seat
    b.cyl_base((sx_, sy_, SEAT_DRYER - 0.07), 0.94, 0.07, "spa_bubblegum", segments=14, radius2=0.8,
               bevel=False)                                                          # its puffed top
    b.cyl_base((0, POLE_Y, 0), 0.62, 0.2, "spa_cream", segments=12)                  # the pole's heavy base
    b.cyl_base((0, POLE_Y, 0.15), 0.12, HOOD_Z + 1.0, "metal", segments=8, bevel=False)   # the pole
    b.box((0, POLE_Y - 0.12, 2.2), (0.42, 0.24, 0.6), "spa_mint")                    # a control box with two dials
    for i, sw in enumerate(("spa_bubblegum", "spa_sky")):
        b.cyl((0.1 - 0.2 * i, POLE_Y - 0.25, 2.25 - 0.14 * i), 0.07, 0.06, sw, segments=8, bevel=False,
              rot=Matrix.Rotation(math.pi / 2, 3, "X"))
    hy = STOOL[1] + 0.25                                                             # the hood, a little back
    arm_z = HOOD_Z + 1.25
    b.box((0, (POLE_Y + hy) / 2, arm_z), (0.24, POLE_Y - hy + 0.1, 0.24), "metal", bevel=False)   # the arm
    b.cyl_base((0, POLE_Y, HOOD_Z + 1.1), 0.18, 0.3, "spa_mint", segments=8, bevel=False)          # the arm's collar
    b.cyl_base((0, hy, HOOD_Z), HOOD_R, 0.75, "spa_cream", segments=14, radius2=HOOD_R - 0.38, bevel=False)
    b.sphere((0, hy, HOOD_Z + 0.73), HOOD_R - 0.4, "spa_cream", segments=14, rings=6, scale=(1, 1, 0.55))
    b.cyl_base((0, hy, HOOD_Z - 0.04), HOOD_R + 0.06, 0.22, "spa_mint", segments=14, bevel=False)  # the rim band
    for i in range(5):                                                               # vent slots round the dome
        t = math.radians(-90 + 45 * (i - 2))
        b.box((math.cos(t) * (HOOD_R - 0.17), hy + math.sin(t) * (HOOD_R - 0.17), HOOD_Z + 0.42), (0.12, 0.12, 0.34),
              "spa_sky", bevel=False, rot=Matrix.Rotation(t + math.pi / 2, 3, "Z"))
    main = _tris(b.finalize(name, mat))
    n = Builder()                                                                    # the nozzle, under the hood
    n.cyl_base((0, 0, -0.32), 0.26, 0.36, "metal", segments=10, bevel=False)
    nozzle = _tris(n.finalize(name + "_Nozzle", mat, bevel=0, location=(0, hy, HOOD_Z)))
    barrier = _barrier(name, mat, (1.3, 1.3, SEAT_DRYER - 0.35), (sx_, sy_, 0.02))
    return [main, nozzle, barrier]


def brush_table_rbx_extras(asset):
    return lambda: {"attachments": [(asset, "CatSeat", Matrix.Translation((0.0, TOP_Y - 0.03, GROOM_Z)))],
                    "attributes": {"SeatHeight": {"Float64": GROOM_Z}, "CatScale": {"Float64": STATION_CAT_SCALE}}}


def dryer_rbx_extras():
    hy = STOOL[1] + 0.25
    air = Matrix.Translation((0.0, hy, HOOD_Z - 0.33)) @ Matrix.Rotation(math.pi, 4, "X")   # +Z (Roblox +Y) down
    return {"attachments": [("CleanACat_Station_Dryer", "CatSeat", Matrix.Translation((STOOL[0], STOOL[1], SEAT_DRYER))),
                            ("CleanACat_Station_Dryer_Nozzle", "Air", air)],
            "attributes": {"SeatHeight": {"Float64": SEAT_DRYER}, "CatScale": {"Float64": STATION_CAT_SCALE}}}


# -- #23 later stations ------------------------------------------------------------------------------------------
BATH_R = 1.95                     # the bubble bath's outer radius: 3.9 across, inside the 5 stud pad
BATH_SEAT = 1.3                   # its inner floor, where the cat sits in the water
BATH_RIM = 1.7


def build_bubble_bath(mat):
    """A round bubblegum bath on a cream foot, a ring of rim blocks, sky water heaped with foam, a rubber duck and a
    bubble spout arching over from the back."""
    name = "CleanACat_Station_BubbleBath"
    b = Builder()
    b.cyl_base((0, 0, -0.02), BATH_R - 0.3, 0.2, "spa_cream", segments=12, bevel=False)        # the foot
    b.cyl_base((0, 0, 0.15), BATH_R, BATH_SEAT - 0.17, "spa_bubblegum", segments=14, bevel=False)   # the body
    n = 12
    for i in range(n):                                                             # the wall, a ring of blocks
        t = 2 * math.pi * (i + 0.5) / n
        r = BATH_R - 0.17
        w = 2 * BATH_R * math.sin(math.pi / n) + 0.04
        b.box_base((math.cos(t) * r, math.sin(t) * r, BATH_SEAT - 0.05 + 0.003 * (i % 2)), (0.36, w, BATH_RIM - BATH_SEAT),
                   "spa_bubblegum", bevel=False, rot=Matrix.Rotation(t, 3, "Z"))
        b.box_base((math.cos(t) * r, math.sin(t) * r, BATH_RIM - 0.06 + 0.004 * (i % 2)), (0.46, w + 0.02, 0.14),
                   "spa_cream", bevel=False, rot=Matrix.Rotation(t, 3, "Z"))      # the cream rim cap
    b.cyl_base((0, 0, BATH_SEAT - 0.03), BATH_R - 0.3, 0.03, "spa_tile", segments=14, bevel=False)   # inner floor
    # a rubber duck on the rim
    dx, dy = math.cos(math.radians(-40)) * (BATH_R - 0.17), math.sin(math.radians(-40)) * (BATH_R - 0.17)
    b.sphere((dx, dy, BATH_RIM + 0.26), 0.2, "pastel_butter", segments=8, rings=4, scale=(1.2, 1, 0.8))
    b.sphere((dx - 0.08, dy - 0.12, BATH_RIM + 0.45), 0.13, "pastel_butter", segments=8, rings=4)
    b.box((dx - 0.12, dy - 0.27, BATH_RIM + 0.43), (0.1, 0.12, 0.05), "spa_bubblegum", bevel=False)
    # the spout's pipe: up from behind the bath and over the rim
    py = BATH_R + 0.18
    b.cyl_base((0, py, -0.02), 0.13, SPOUT_Z + 0.2, "metal", segments=8, bevel=False)
    b.box((0, (py + SPOUT_Y) / 2, SPOUT_Z + 0.12), (0.18, py - SPOUT_Y + 0.12, 0.18), "metal", bevel=False)
    main = _tris(b.finalize(name, mat))
    w_ = Builder()
    w_.cyl_base((0, 0, BATH_SEAT), BATH_R - 0.32, 0.12, "spa_sky", segments=14, bevel=False)
    water = _tris(w_.finalize(name + "_Water", mat))
    f = Builder()
    for i in range(11):                                                          # foam heaped round the edge
        t = 2 * math.pi * i / 11 + 0.3
        r = BATH_R - 0.62 - 0.08 * (i % 3)
        size = 0.45 + 0.07 * (i % 3)
        f.sphere((math.cos(t) * r, math.sin(t) * r, BATH_SEAT + 0.2 + 0.05 * (i % 2)), size, "foam", segments=6,
                 rings=4, scale=(1, 1, 0.75))
    for i, (x, y) in enumerate(((-1.4, 1.2), (1.3, 1.35), (-1.5, -1.0))):        # and spilling over the rim
        f.sphere((x, y, BATH_RIM + 0.15), 0.26 - 0.03 * i, "foam", segments=6, rings=4, scale=(1, 1, 0.7))
    foam = f.finalize(name + "_Foam", mat)
    s_ = Builder()                                                                # the spout's mouth
    s_.cyl((0, 0, 0), 0.17, 0.2, "spa_mint", segments=8, bevel=False)
    spout = _tris(s_.finalize(name + "_Spout", mat, bevel=0, location=(0, SPOUT_Y, SPOUT_Z)))
    barrier = _barrier(name, mat, (2.4, 2.4, BATH_SEAT - 0.25), (0, 0, 0.04))
    return [main, water, foam, spout, barrier]


SPOUT_Y, SPOUT_Z = 1.2, 4.7       # the spout's mouth, over the back of the bath above a 1.5 scale cat's ears


def bubble_bath_rbx_extras():
    return {"attachments": [("CleanACat_Station_BubbleBath", "CatSeat", Matrix.Translation((0.0, 0.0, BATH_SEAT + 0.02))),
                            ("CleanACat_Station_BubbleBath_Spout", "Bubbles",
                             Matrix.Translation((0.0, SPOUT_Y, SPOUT_Z - 0.1)))],
            "attributes": {"SeatHeight": {"Float64": BATH_SEAT + 0.02}, "CatScale": {"Float64": STATION_CAT_SCALE}}}


PAW_Z = 1.6                       # the pawdicure table's cushion top, the CatSeat


def build_pawdicure(mat):
    """A small padded table: mint legs, a cream top with a bubblegum cushion and a paw rest at the front, and a tray of
    three polish bottles and a nail file at the side."""
    name = "CleanACat_Station_Pawdicure"
    b = Builder()
    tw, td, ty = 2.8, 2.2, 0.2
    top = PAW_Z - 0.22
    b.box_base((0, ty, top - 0.14), (tw, td, 0.14), "spa_cream")                 # the top
    for sx in (1, -1):
        for sy in (1, -1):
            b.box_base((sx * (tw / 2 - 0.28), ty + sy * (td / 2 - 0.28), 0), (0.26, 0.26, top - 0.12), "spa_mint")
    b.box_base((0, ty + 0.15, top - 0.02), (tw - 0.9, td - 0.9, 0.24), "spa_bubblegum")      # the cushion
    b.box_base((0, ty - td / 2 + 0.3, top - 0.02), (1.2, 0.5, 0.12), "spa_mint")  # the paw rest at the front edge
    # the tray at the cat's left front corner (+X, -Y): three bottles and a file
    tx, tyy = tw / 2 - 0.38, ty - td / 2 + 0.42
    b.box_base((tx, tyy, top - 0.02), (0.6, 0.62, 0.06), "metal", bevel=False)
    for i, (dx, dy, sw) in enumerate(((-0.14, 0.14, "spa_bubblegum"), (0.13, 0.12, "spa_sky"), (0.0, -0.14, "bow_mint"))):
        b.cyl_base((tx + dx, tyy + dy, top + 0.03), 0.09, 0.22, sw, segments=8, bevel=False)
        b.cyl_base((tx + dx, tyy + dy, top + 0.24), 0.045, 0.1, "offwhite", segments=6, bevel=False)
    b.box((tx - 0.02, tyy - 0.02, top + 0.08), (0.08, 0.52, 0.025), "pastel_butter", bevel=False,
          rot=Matrix.Rotation(math.radians(30), 3, "Z"))                          # the nail file
    b.box_base((0, ty, 0.5), (tw - 0.8, td - 0.8, 0.1), "spa_cream", bevel=False)  # a shelf with a towel
    b.box_base((0.3, ty + 0.1, 0.59), (0.9, 0.7, 0.24), "spa_sky")
    main = _tris(b.finalize(name, mat))
    return [main, _barrier(name, mat, (tw - 0.74, td - 0.74, top - 0.35), (0, ty, 0.03))]


def pawdicure_rbx_extras():
    return {"attachments": [("CleanACat_Station_Pawdicure", "CatSeat", Matrix.Translation((0.0, 0.35, PAW_Z)))],
            "attributes": {"SeatHeight": {"Float64": PAW_Z}, "CatScale": {"Float64": STATION_CAT_SCALE}}}


ASSETS = {"CleanACat_Station_Tub": (build_tub, 1500),
          "CleanACat_Station_BrushTable": (build_brush_table, 1200),
          "CleanACat_Station_BrushTableUp": (build_brush_table_up, 1200),
          "CleanACat_Station_Dryer": (build_dryer, 1200),
          "CleanACat_Station_BubbleBath": (build_bubble_bath, 1200),
          "CleanACat_Station_Pawdicure": (build_pawdicure, 1200)}
EXTRAS = {"CleanACat_Station_Tub": tub_rbx_extras,
          "CleanACat_Station_BrushTable": brush_table_rbx_extras("CleanACat_Station_BrushTable"),
          "CleanACat_Station_BrushTableUp": brush_table_rbx_extras("CleanACat_Station_BrushTableUp"),
          "CleanACat_Station_Dryer": dryer_rbx_extras,
          "CleanACat_Station_BubbleBath": bubble_bath_rbx_extras,
          "CleanACat_Station_Pawdicure": pawdicure_rbx_extras}
