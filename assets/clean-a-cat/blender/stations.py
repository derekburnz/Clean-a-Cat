"""Spa stations (issue #13 for the tub; the brush table and dryer follow in #18).

  CleanACat_Station_Tub   the wash tub, the first thing a player sees: a low bath on four feet with a mint rim, a
                          shallow pool of water (_Water), foam (_Foam) and a tap at the back. It matches the
                          placeholder PH_Tub's seat height (1.2 studs) but is smaller (4.6 wide, 3.8 deep) so the cat
                          fills more of a phone screen; the design asks for the cat bigger than life at the tub.
                          Attachment `CatSeat` on the inner floor, facing the player (-Z in Roblox): put the sitting
                          cat's pivot there. The walls and body collide; water and foam do not.

Pivot at the base centre on the floor, the front (where the player stands) at -Y in Blender, -Z in Roblox.
"""

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


ASSETS = {"CleanACat_Station_Tub": (build_tub, 1500)}
EXTRAS = {"CleanACat_Station_Tub": tub_rbx_extras}
