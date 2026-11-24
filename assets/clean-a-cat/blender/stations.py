"""Spa stations (issue #13 for the tub, #18 for the brush tables and the dryer).

  CleanACat_Station_Tub   the wash tub, the first thing a player sees: the claw-foot bath of the store picture
                          (#157). A sky blue pill-shaped body that flares out, a gold band, a rolled white rim,
                          four gold claw feet, white bubbles painted on the front, a brass gooseneck tap on the
                          back rim and a striped mint towel over the front. Deep blue water (_Water) stands just
                          under the rim, with lather (_Foam), soap bubbles (_Bubbles) and the tap's stream
                          (_Stream). 4.6 wide and 3.5 deep, so the cat fills most of a phone screen; the design
                          asks for the cat bigger than life at the tub.
                          Attachment `CatSeat` 1.5 studs up, facing the player (-Z in Roblox): put the sitting
                          cat's pivot there. The body collides; the rim, water and foam do not.

  CleanACat_Station_BubbleBath    the wash tub's upgrade (#23, reworked by #172 to look the better bath of the two):
                                  a round bubblegum slipper bath on a cream and gold plinth, its back sweeping up
                                  behind the cat, lather heaped high and spilling over the front, and a gold bubble
                                  fountain whose mint mouth is the part `Spout` (Attachment `Bubbles`). `CatSeat`
                                  1.5 up, as at the tub.

  CleanACat_Station_BrushTable    the grooming table: a cream cabinet on a wooden foot with a brass band, a mint
                                  drawer and a towel on a brass bar, a wooden top with a mint rubber mat, and a
                                  brass post at the back corner with a brush hanging from it. `CatSeat` on the mat.
  CleanACat_Station_BrushTableUp  its upgrade, same footprint, pivot and CatSeat: the cabinet in bubblegum with a
                                  gold band, a puffy cushion top, two towels, and a mint brush rack at the back
                                  with three brushes and a bow. Swap one for the other in place.
  CleanACat_Station_Dryer         a hood dryer over a round pouf, both on one cream plinth: the hood hangs from an
                                  arm on a pole behind the pouf. Its nozzle is a part named `Nozzle` under the hood,
                                  with an Attachment `Air` whose +Y points down at the cat, for Motion-FX's air
                                  puffs. `CatSeat` on the pouf.
  CleanACat_Station_Pawdicure     a lilac cabinet with a gold band and a painted paw print, a cushion top, a tray
                                  of polish bottles and a brass lamp. `CatSeat` on the cushion.

Since #193 every station stands on a solid body (a cabinet, a pouf, a plinth), not on thin legs, so it reads at phone
size beside the two baths. The stations fit the 5 by 5 stud station pads (SpotStation2, SpotStation3 in the plot)
and stand inside them. The cat sits on them at ScaleTo(CatScale) (root attribute, 1.5, the same as at the tub). The
bodies collide; an invisible `_Barrier` inside each one stays for the game code that looks for it (CanQuery off:
taps and the camera pass through it).

Pivot at the base centre on the floor, the front (where the player stands) at -Y in Blender, -Z in Roblox.
"""

import math

from mathutils import Matrix

import common
from common import Builder

TUB_W, TUB_D = 4.6, 3.5          # outer footprint (the rolled rim), studs: a pill, two round ends
FOOT_H = 0.34                    # the body's underside: the tub stands on four gold claw feet
SEAT_Z = 1.5                     # where the cat sits (the CatSeat); it was 1.2 until #157 raised the water
WATER_Z = SEAT_Z + 0.27          # the water's surface: 0.27 up the cat is dirt.TUB_WATER at the tub's 1.5 scale
RIM_Z = WATER_Z + 0.06           # top of the rolled rim: the water stands just under it (Derek, #157)
FLOOR_Z = RIM_Z - 0.21           # top of the solid body. It is a little over the CatSeat: the cat's lowest 0.12 is
#                                  inside the body, under the water where nothing shows, and the rim needs one ring
END_R = TUB_D / 2                # the round ends' radius at the rim
HALF = TUB_W / 2 - END_R         # from the middle to the centre of a round end
RIM_W = 0.42                     # the rim's width
BODY_R = END_R - 0.13            # the body under the rim
TAP_X = -1.25                    # the tap stands off centre on the back rim, so its stream shows past the cat
E = 0.012                        # pieces are staggered by this so no two faces share a plane (the QA gate)


def _pill(b, z, h, r, swatch, segments=16):
    """A solid pill standing on height z: a block between two round ends, radius r. The three pieces differ a hair
    in height and the block is a hair slimmer than the ends, so no two faces share a plane."""
    b.cyl_base((HALF, 0, z), r, h, swatch, segments=segments, bevel=False)
    b.cyl_base((-HALF, 0, z + E / 2), r, h - E, swatch, segments=segments, bevel=False)
    # the block ends inside the round ends, each pill's at its own depth, so stacked pills share no end plane
    b.box_base((0, 0, z + E), (2 * HALF - 0.2 * (END_R - r), 2 * r - 0.03, h - 2 * E), swatch, bevel=False)


def _on_end(sx, deg, r):
    """A point on a round end (sx 1 right, -1 left) at `deg` from that end's tip, counted towards the back, at radius
    r from the end's centre: (x, y, the turn that faces a box's local +X outwards)."""
    t = math.radians(deg) if sx > 0 else math.pi - math.radians(deg)
    return sx * HALF + math.cos(t) * r, math.sin(t) * r, t


def _ring(b, z, h, r_out, width, swatch, n=6):
    """A hollow pill: two straight walls and `n` blocks round each end, their outer faces r_out from the end's
    centre. Neighbours differ a hair in height so the corners where they cross share no plane."""
    r = r_out - 0.03 - width / 2                       # block centres: the faces' middles 0.03 inside r_out, the
    w = 2 * (r_out - 0.03) * math.tan(math.pi / (2 * n)) + 0.03    # corners as far outside it
    k = 0
    for sx in (1, -1):
        for i in range(n):
            x, y, t = _on_end(sx, -90 + 180 * (i + 0.5) / n, r)
            b.box_base((x, y, z + 0.004 * (k % 3)), (width, w, h), swatch, rot=Matrix.Rotation(t, 3, "Z"))
            k += 1
    for sy in (1, -1):
        b.box_base((0, sy * r, z + 0.006 + 0.004 * (sy > 0)), (2 * HALF + 0.05, width, h - 0.004), swatch)


def _tub_shell(b):
    """The claw-foot bath of the store picture (Derek chose it there, #157 brings it into the game): a sky blue
    body that flares out, a gold band at the flare, a rolled white rim, and white bubbles painted on the front."""
    flare = FOOT_H + 0.42
    _pill(b, FOOT_H, flare - FOOT_H + 0.05, BODY_R - 0.2, "pastel_sky")            # the foot of the body
    _pill(b, flare, FLOOR_Z - flare, BODY_R, "pastel_sky")                         # the body, solid to its floor
    _pill(b, flare - 0.03, 0.12, BODY_R + 0.035, "gold_mid")                       # the gold band at the flare
    _ring(b, FLOOR_Z - 0.03, RIM_Z - FLOOR_Z + 0.03, END_R, RIM_W, "offwhite")     # the rolled rim
    face = Matrix.Rotation(math.pi / 2, 3, "Y")
    for k, (sx, deg, z, r) in enumerate(((0, -0.3, 1.2, 0.2), (0, 0.25, 0.98, 0.12), (1, -62, 1.26, 0.15),
                                         (1, -38, 1.02, 0.1),                    # painted bubbles: white discs
                                         (2, 0.45, 1.18, 0.19), (2, -0.1, 0.98, 0.11))):   # and two on the back,
        if sx == 0:                                    # on the straight front: deg is x here   # seen first from
            x, y, t = deg, -BODY_R + 0.015, -math.pi / 2                                        # the spawn (#172)
        elif sx == 2:                                  # on the straight back
            x, y, t = deg, BODY_R - 0.015, math.pi / 2
        else:
            x, y, t = _on_end(sx, deg, BODY_R - 0.006)
        b.cyl((x, y, z), r, 0.04 + 0.004 * k, "offwhite" if k % 2 == 0 else "fish_belly", segments=8, bevel=False,
              rot=Matrix.Rotation(t, 3, "Z") @ face)


def _feet(b):
    """Four gold claw feet: an ankle under the body, a paw out on the floor and a darker row of toes."""
    for sx in (1, -1):
        for sy in (1, -1):
            x, y, t = _on_end(sx, sy * 50, (BODY_R - 0.2) * 0.8)
            ox, oy = math.cos(t), math.sin(t)
            b.box((x, y, FOOT_H - 0.04), (0.3, 0.3, 0.3), "gold_mid", bevel=False, rot=Matrix.Rotation(t, 3, "Z"))
            px, py = x + ox * 0.2, y + oy * 0.2
            b.sphere((px, py, 0.17), 0.24, "gold_mid", segments=8, rings=4, scale=(1.1, 1.1, 0.75))
            b.box((px + ox * 0.2, py + oy * 0.2, 0.065), (0.16, 0.4, 0.13), "gold_dark",    # the toes, one piece
                  bevel=False, rot=Matrix.Rotation(t, 3, "Z"))


def _tap_at():
    """Where the tap stands: on the middle of the back rim at TAP_X, which is on the left round end."""
    r = END_R - 0.03 - RIM_W / 2
    return TAP_X, math.sqrt(r * r - (TAP_X + HALF) ** 2)


def _tap(b):
    """A brass gooseneck tap on the back rim, arching in over the water, with a pink and a sky knob."""
    x, y = _tap_at()
    b.cyl_base((x, y, RIM_Z - 0.02), 0.19, 0.09, "brass", segments=10, bevel=False)       # the flange, in the rim
    b.cyl_base((x, y, RIM_Z + 0.03), 0.09, 0.9, "brass", segments=8, bevel=False)         # the riser
    top = RIM_Z + 0.9
    for dy, dz, deg in ((0.11, 0.1, 45), (0.34, 0.2, 90), (0.57, 0.1, 135)):              # the neck, three pieces
        b.cyl((x, y - dy, top + dz), 0.09, 0.38, "brass", segments=8, bevel=False,
              rot=Matrix.Rotation(math.radians(deg), 3, "X"))
    b.cyl((x, y - 0.68, top - 0.09), 0.13, 0.18, "brass", segments=8, bevel=False)        # the mouth
    tx, ty = -(y) / math.hypot(x + HALF, y), (x + HALF) / math.hypot(x + HALF, y)         # along the rim
    for sgn, sw in ((1, "spa_bubblegum"), (-1, "spa_sky")):                               # hot pink and cool sky
        b.sphere((x + sgn * tx * 0.36, y + sgn * ty * 0.36, RIM_Z + 0.1), 0.13, sw, segments=8, rings=4)


def _towel(b):
    """A striped mint towel hung over the front rim of the left end (the store picture's)."""
    width = 0.86
    x, y, t = _on_end(-1, -58, END_R - 0.03 - RIM_W / 2)
    rot = Matrix.Rotation(t, 3, "Z")
    b.box((x, y, RIM_Z + 0.03), (RIM_W + 0.16, width, 0.07), "spa_mint", rot=rot)          # over the rim
    hx, hy, _t = _on_end(-1, -58, END_R + 0.045)
    drop = 0.78
    b.box((hx, hy, RIM_Z + 0.05 - drop / 2), (0.07, width - 0.01, drop), "spa_mint", rot=rot)   # hanging outside
    sx_, sy_, _t = _on_end(-1, -58, END_R + 0.06)
    for dz in (0.5, 0.64):                                                                # two cream stripes
        b.box((sx_, sy_, RIM_Z - dz), (0.07, width + 0.004, 0.07), "spa_cream", bevel=False, rot=rot)


STREAM = (TAP_X, _tap_at()[1] - 0.68)              # where the tap's water lands


def water_shine(b, z, marks):
    """White shine marks on a water surface at height z: (x, y, length, turn in degrees) each, a hair proud and
    deep enough to stand in a water piece that lies a little lower (the tub's round ends)."""
    for x, y, length, turn in marks:
        b.box((x, y, z - 0.019), (length, 0.07, 0.09), "foam", bevel=False,
              rot=Matrix.Rotation(math.radians(turn), 3, "Z"))


def _water():
    """The water: deep blue to just under the rim, with shine marks where no foam lies. Three pieces fill the pill:
    the middle block's top is the surface and the two round ends lie 0.02 and 0.04 under it, far enough apart
    that nothing flickers. They are solid in the game (#176): see-through, the places where they cross showed from
    above as a seam and a darker wedge (Sync-Agent's Studio check of #171)."""
    b = Builder()
    r = END_R - RIM_W - 0.01
    z = FLOOR_Z + 0.004
    b.box_base((0, 0, z), (2 * HALF, 2 * r - 0.03, WATER_Z - z), "water", bevel=False)
    b.cyl_base((HALF, 0, z + 0.003), r, WATER_Z - z - 0.023, "water", segments=16, bevel=False)
    b.cyl_base((-HALF, 0, z + 0.006), r, WATER_Z - z - 0.046, "water", segments=16, bevel=False)
    water_shine(b, WATER_Z, [(-0.55, -1.05, 0.7, 0), (-1.2, -0.8, 0.34, 0), (0.15, -1.1, 0.3, 0),
                             (-1.6, 0.3, 0.36, 90), (0.45, 1.08, 0.5, 0)])
    return b


def _stream():
    """Water running from the tap into the tub: its own child Model (_Stream), so the game can turn the tap off."""
    b = Builder()
    top = RIM_Z + 0.74
    b.box((STREAM[0], STREAM[1], (top + WATER_Z) / 2 - 0.02), (0.12, 0.12, top - WATER_Z + 0.04), "water", bevel=False)
    return b


def foam_pile(b, x, y, z, r, ring=4, turn=0.0, segments=8, rings=5, swatch="foam"):
    """Soap foam as a tidy pile of round bubbles (#107), not loose puffs: one big bubble, `ring` smaller ones tucked
    round its foot (big and small in turn) and a little one on top. (x, y, z) is where the pile rests (the water or a
    rim); it sits a little into that surface. Every bubble is a Ball part in Roblox."""
    b.sphere((x, y, z + 0.55 * r), r, swatch, segments=segments, rings=rings)
    for j in range(ring):
        t = turn + 2 * math.pi * j / ring
        rr = r * (0.62 if j % 2 == 0 else 0.48)
        d = r * 0.92
        b.sphere((x + math.cos(t) * d, y + math.sin(t) * d, z + 0.6 * rr), rr, swatch, segments=segments, rings=rings)
    t = turn + math.pi / ring
    b.sphere((x + math.cos(t) * 0.5 * r, y + math.sin(t) * 0.5 * r, z + 1.32 * r), 0.4 * r, swatch,
             segments=segments, rings=rings)


# How finely a ball is drawn here: (segments, rings) of a ball and of a flattened mound. Roblox draws its own balls,
# so the game's models stay coarse; store_art.py raises these for a close picture.
DETAIL = {"ball": (8, 5), "mound": (8, 4)}


def foam_mound(b, x, y, z, r, flat=0.55):
    """A low white mound of lather lying on the water at (x, y, z) (#111): a flattened ball, half sunk."""
    seg, rings = DETAIL["mound"]
    b.sphere((x, y, z + 0.1 * r), r, "foam", segments=seg, rings=rings, scale=(1.0, 1.0, flat))


def foam_bubble(b, x, y, z, r, swatch="foam"):
    """One white ball of lather resting on a surface at (x, y, z)."""
    seg, rings = DETAIL["ball"]
    b.sphere((x, y, z + 0.7 * r), r, swatch, segments=seg, rings=rings)


GLINT = (-0.45, -0.6, 0.66)       # where the light catches a soap bubble: up, to the front and a little left


def soap_bubble(b, x, y, z, r):
    """A soap bubble centred at (x, y, z) (#111): a clear ball (swatch `bubble`, see-through in the game) and a small
    white square glint on its skin, the same pixel glint as in the cats' eyes."""
    seg, rings = DETAIL["ball"]
    b.sphere((x, y, z), r, "bubble", segments=seg, rings=rings)
    n = math.sqrt(sum(c * c for c in GLINT))
    g = [c / n * r * 0.74 for c in GLINT]
    b.box((x + g[0], y + g[1], z + g[2]), (0.4 * r, 0.4 * r, 0.4 * r), "foam", bevel=False)


# The tub's lather: low mounds round the right end and along the front, white balls on them, and a splash where the
# tap's water lands. The front by the tap stays open water. Mounds and balls: (x, y, radius).
FOAM_MOUNDS = [(1.3, 0.72, 0.5), (1.62, 0.0, 0.42), (1.32, -0.7, 0.48), (0.7, -1.02, 0.3), (-1.55, -0.3, 0.34)]
FOAM_BALLS = [(1.4, 0.88, 0.2), (1.1, 0.6, 0.16), (1.55, -0.55, 0.18), (1.05, -0.95, 0.15), (-1.62, -0.42, 0.13)]
# Soap bubbles: on the lather, one spilled on the rim and three drifting up. (x, y, z, radius), z the centre.
SOAP_BUBBLES = [(1.2, 0.68, WATER_Z + 0.52, 0.27), (1.7, 0.08, WATER_Z + 0.42, 0.19),
                (1.25, -0.68, WATER_Z + 0.5, 0.23), (-1.5, -0.26, WATER_Z + 0.36, 0.17),
                (1.72, -1.0, RIM_Z + 0.17, 0.19),
                (2.05, -0.5, 2.9, 0.22), (-2.05, 0.4, 3.35, 0.17), (-1.75, -1.3, 2.6, 0.13)]


def _foam():
    b = Builder()
    for x, y, r in FOAM_MOUNDS:
        foam_mound(b, x, y, WATER_Z, r)
    for x, y, r in FOAM_BALLS:
        foam_bubble(b, x, y, WATER_Z + 0.08, r)
    for j in range(3):                                  # the splash round the tap's stream
        t = 2 * math.pi * j / 3 + 0.4
        foam_bubble(b, STREAM[0] + math.cos(t) * 0.17, STREAM[1] + math.sin(t) * 0.17, WATER_Z - 0.06, 0.11 - 0.01 * j)
    return b


def _bubbles(spots):
    b = Builder()
    for x, y, z, r in spots:
        soap_bubble(b, x, y, z, r)
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
    _towel(b)
    objs = [_tris(b.finalize(name, mat)),
            _water().finalize(name + "_Water", mat, bevel=0),
            common.shade_smooth(_foam().finalize(name + "_Foam", mat)),
            common.shade_smooth(_bubbles(SOAP_BUBBLES).finalize(name + "_Bubbles", mat, bevel=0)),
            _stream().finalize(name + "_Stream", mat, bevel=0)]
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


GROOM_FLARE = 0.5         # where a grooming cabinet's foot flares out to its body, with a metal band (as the tub's)
GROOM_FRONT = TOP_Y - 0.95   # the cabinet body's front face


def _groom_body(b, top_z, foot, body, band, face, knob):
    """What both brush tables stand on (#193): a solid cabinet in place of four thin legs, so the table reads at
    phone size beside the baths. A foot, a body that flares out over it, a metal band at the flare and a drawer
    with a round knob on the front. `top_z` is the top board's top."""
    under = top_z - 0.16
    b.box_base((0, TOP_Y, 0), (2.5, 1.5, GROOM_FLARE + 0.04), foot)
    b.box_base((0, TOP_Y, GROOM_FLARE), (2.9, 1.9, under - GROOM_FLARE + 0.02), body)
    b.box_base((0, TOP_Y, GROOM_FLARE - 0.04), (2.98, 1.98, 0.13), band, bevel=False)
    dz = (GROOM_FLARE + 0.1 + under) / 2
    b.box((-0.55, GROOM_FRONT - 0.02, dz), (1.4, 0.08, 0.5), face)                    # the drawer
    b.sphere((-0.55, GROOM_FRONT - 0.1, dz), 0.1, knob, segments=8, rings=4)          # its knob


def _towel_bar(b, top_z, metal, towels):
    """A towel bar on the front of the cabinet, right of the drawer, with a towel (or two) hung over it:
    (swatch, x, width, drop) each."""
    z = top_z - 0.42
    y = GROOM_FRONT - 0.16
    b.cyl((0.82, y, z), 0.045, 1.08, metal, segments=6, bevel=False, rot=Matrix.Rotation(math.pi / 2, 3, "Y"))
    for sx in (-1, 1):
        b.box((0.82 + sx * 0.5, y + 0.07, z), (0.07, 0.2, 0.09), metal, bevel=False)    # the brackets
    for k, (sw, x, w, drop) in enumerate(towels):
        b.box((x, y - 0.062 - 0.004 * k, z + 0.03 - drop / 2), (w, 0.06, drop), sw)    # the front fall
        b.box((x, y, z + 0.055 + 0.004 * k), (w - 0.01, 0.17, 0.05), sw, bevel=False)  # over the bar
        b.box((x, y - 0.066 - 0.004 * k, z - drop + 0.2), (w + 0.004, 0.06, 0.07), "offwhite", bevel=False)   # a stripe


def build_brush_table(mat):
    """The grooming table: a cream cabinet on a wooden foot with a brass band, a mint drawer and a towel on a
    brass bar; a wooden top with a mint rubber mat; and a brass post at the back right corner with a brush
    hanging from its arm, which says what the table is for."""
    name = "CleanACat_Station_BrushTable"
    b = Builder()
    top_z = GROOM_Z - 0.1                                                           # the board's top; the mat on it
    _groom_body(b, top_z, "wood_light", "spa_cream", "brass", "spa_mint", "brass")
    b.box_base((0, TOP_Y, top_z - 0.16), (TOP_W, TOP_D, 0.16), "wood_light")        # the top board
    b.box_base((0, TOP_Y - 0.03, top_z - 0.01), (TOP_W - 0.5, TOP_D - 0.46, 0.11), "spa_mint")   # the rubber mat
    _towel_bar(b, top_z, "brass", (("spa_sky", 0.82, 0.78, 0.72),))
    # the brush post: a brass post on a cream foot, an arm towards the middle and one brush on it
    px, py = TOP_W / 2 - 0.2, TOP_Y + TOP_D / 2 - 0.2
    post_top = top_z + 2.35
    b.cyl_base((px, py, top_z - 0.02), 0.19, 0.1, "spa_cream", segments=8, bevel=False)
    b.cyl_base((px, py, top_z + 0.03), 0.08, post_top - top_z, "brass", segments=8, bevel=False)
    b.sphere((px, py, post_top + 0.07), 0.13, "brass", segments=8, rings=4)
    b.cyl((px - 0.42, py, post_top - 0.12), 0.05, 0.9, "brass", segments=6, bevel=False,
          rot=Matrix.Rotation(math.pi / 2, 3, "Y"))
    _hanging_brush(b, px - 0.62, py, post_top - 0.12, "spa_bubblegum")
    # a shampoo bottle at the back left corner
    bx, by = -(TOP_W / 2 - 0.3), TOP_Y + TOP_D / 2 - 0.3
    b.cyl_base((bx, by, top_z - 0.02), 0.19, 0.52, "spa_bubblegum", segments=8)
    b.cyl_base((bx, by, top_z + 0.49), 0.08, 0.14, "spa_cream", segments=6, bevel=False)
    main = _tris(b.finalize(name, mat))
    return [main, _barrier(name, mat, (TOP_W - 0.62, TOP_D - 0.66, top_z - 0.3), (0, TOP_Y, 0.03))]


def _hanging_brush(b, x, y, z, head):
    """A brush hung by its handle from the rack rail at (x, y, z): handle up, bristles to the front."""
    b.box((x, y - 0.04, z - 0.3), (0.13, 0.1, 0.62), "wood_light", bevel=False)
    b.box((x, y - 0.06, z - 0.78), (0.44, 0.16, 0.46), head, bevel=False)
    b.box((x, y - 0.17, z - 0.78), (0.36, 0.08, 0.38), "foam", bevel=False)
    b.box((x, y - 0.03, z + 0.02), (0.07, 0.09, 0.12), "metal", bevel=False)      # the hook over the rail


def build_brush_table_up(mat):
    """The upgraded grooming table: the same cabinet in bubblegum on a cream foot with a gold band, a cream top
    with a puffy cushion, two towels on a gold bar, and a mint brush rack at the back with three brushes and a
    bow. Same footprint, pivot and CatSeat as the first table."""
    name = "CleanACat_Station_BrushTableUp"
    b = Builder()
    top_z = GROOM_Z - 0.24                                                          # the board; the cushion on it
    _groom_body(b, top_z, "spa_cream", "spa_bubblegum", "gold_mid", "spa_cream", "gold_mid")
    b.box_base((0, TOP_Y, top_z - 0.16), (TOP_W, TOP_D, 0.16), "spa_cream")
    b.box_base((0, TOP_Y, top_z - 0.13), (TOP_W + 0.06, TOP_D + 0.06, 0.09), "gold_mid", bevel=False)      # a band
    b.box_base((0, TOP_Y - 0.03, top_z - 0.02), (TOP_W - 0.42, TOP_D - 0.5, 0.2), "spa_bubblegum")         # cushion
    b.box_base((0, TOP_Y - 0.03, top_z + 0.15), (TOP_W - 0.82, TOP_D - 0.86, 0.09), "spa_bubblegum")       # its puff
    _towel_bar(b, top_z, "gold_mid", (("spa_sky", 0.58, 0.5, 0.74), ("spa_mint", 1.1, 0.46, 0.6)))
    # the brush rack at the back: two posts, a mint board, a rail with three brushes, a bow on top
    ry = TOP_Y + TOP_D / 2 + 0.11
    for sx in (1, -1):
        b.box_base((sx * 1.52, ry, top_z - 0.5), (0.22, 0.22, 2.95), "spa_mint")
    b.box_base((0, ry + 0.02, top_z + 0.45), (2.86, 0.1, 1.85), "spa_mint", bevel=False)
    b.box_base((0, ry, top_z + 2.24), (3.34, 0.26, 0.24), "spa_bubblegum")     # the header, 0.02 proud of the
    #                                                                                  posts front and back
    rail_z = top_z + 1.95
    b.cyl((0, ry - 0.16, rail_z), 0.05, 2.9, "gold_mid", segments=6, bevel=False, rot=Matrix.Rotation(math.pi / 2, 3, "Y"))
    for sx in (1, -1):
        b.box((sx * 1.445, ry - 0.08, rail_z), (0.08, 0.2, 0.12), "gold_mid", bevel=False)   # the rail's brackets
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
    """The hood dryer (#193 made it solid): a butter pouf with a bubblegum cushion and a gold band, where the cat
    sits, and behind it a cream pole with brass collars and a mint control box, both on one cream plinth. An arm
    from the pole holds the hood over the cat: a cream dome with a butter rim, sky vents and a brass knuckle."""
    name = "CleanACat_Station_Dryer"
    b = Builder()
    sx_, sy_ = STOOL
    # one plinth under the pouf and the pole: two discs and a bridge between them
    b.cyl_base((sx_, sy_, -0.02), 1.3, 0.2, "spa_cream", segments=16, bevel=False)
    b.cyl_base((0, POLE_Y, -0.014), 0.7, 0.2, "spa_cream", segments=12, bevel=False)
    b.box_base((0, (sy_ + POLE_Y) / 2, -0.008), (1.1, POLE_Y - sy_, 0.18), "spa_cream", bevel=False)
    # the pouf: a drum narrower than its cushion, a gold band round its foot
    b.cyl_base((sx_, sy_, 0.14), 0.9, SEAT_DRYER - 0.36, "pastel_butter", segments=14, bevel=False)
    b.cyl_base((sx_, sy_, 0.16), 0.94, 0.14, "gold_mid", segments=14, bevel=False)
    b.cyl_base((sx_, sy_, SEAT_DRYER - 0.24), 1.0, 0.18, "spa_bubblegum", segments=14, bevel=False)   # the seat
    b.cyl_base((sx_, sy_, SEAT_DRYER - 0.07), 0.94, 0.07, "spa_bubblegum", segments=14, radius2=0.8,
               bevel=False)                                                          # its puffed top
    # the pole, its collars and the control box with two dials
    b.cyl_base((0, POLE_Y, 0.15), 0.17, HOOD_Z + 1.0, "spa_cream", segments=8, bevel=False)
    b.cyl_base((0, POLE_Y, 0.16), 0.3, 0.3, "brass", segments=10, bevel=False)
    b.cyl_base((0, POLE_Y, 3.3), 0.22, 0.14, "brass", segments=8, bevel=False)
    b.box((0, POLE_Y - 0.17, 2.2), (0.62, 0.3, 0.8), "spa_mint")
    for i, sw in enumerate(("spa_bubblegum", "spa_sky")):
        b.cyl((0.13 - 0.26 * i, POLE_Y - 0.33, 2.33 - 0.24 * i), 0.1, 0.07, sw, segments=8, bevel=False,
              rot=Matrix.Rotation(math.pi / 2, 3, "X"))
    hy = STOOL[1] + 0.25                                                             # the hood, a little back
    arm_z = HOOD_Z + 1.25
    b.box((0, (POLE_Y + hy) / 2, arm_z), (0.3, POLE_Y - hy + 0.1, 0.3), "spa_cream", bevel=False)   # the arm
    b.cyl_base((0, POLE_Y, HOOD_Z + 1.06), 0.24, 0.4, "brass", segments=8, bevel=False)            # the arm's collar
    b.sphere((0, hy, arm_z + 0.02), 0.26, "brass", segments=8, rings=4)                            # the knuckle
    b.cyl_base((0, hy, HOOD_Z), HOOD_R, 0.75, "spa_cream", segments=14, radius2=HOOD_R - 0.38, bevel=False)
    b.sphere((0, hy, HOOD_Z + 0.73), HOOD_R - 0.4, "spa_cream", segments=14, rings=6, scale=(1, 1, 0.55))
    b.cyl_base((0, hy, HOOD_Z - 0.06), HOOD_R + 0.07, 0.28, "pastel_butter", segments=14, bevel=False)   # the rim
    for i in range(5):                                                               # vent slots round the dome
        t = math.radians(-90 + 45 * (i - 2))
        b.box((math.cos(t) * (HOOD_R - 0.17), hy + math.sin(t) * (HOOD_R - 0.17), HOOD_Z + 0.45), (0.14, 0.12, 0.36),
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
# The bubble bath is the wash tub's upgrade, so it has to look like the better bath beside the claw-foot tub (#172):
# rounder and deeper than the tub (4.6 across on its plinth), a slipper back that sweeps up behind the cat, a gold
# band and plinth step, lather heaped high and spilling over the front, and a gold bubble fountain over the top.
BATH_R = 2.2                      # the bath's outer radius at the rim: 4.4 across, inside the 5 stud pad
BATH_PLINTH = 2.3                 # the cream plinth it stands on: 4.6 across
BATH_SEAT = SEAT_Z                # the CatSeat, as high as the wash tub's: one camera and one reach for both baths
BATH_WATER = BATH_SEAT + 0.27     # the water's surface, as far up the cat as in the tub
BATH_RIM = BATH_WATER + 0.06      # top of the rim at the front: the water stands just under it (Derek, #157)
BATH_FLOOR = BATH_RIM - 0.21      # top of the solid body, as in the tub
BATH_WALL = 0.42                  # the wall's width
BATH_BACK = 1.3                   # how far the slipper back rises over the front rim
BATH_N = 16                       # blocks in the wall's ring
BATH_BODY = BATH_R - 0.05         # the body under the wall
SPOUT_Z = BATH_SEAT + 3.1         # the fountain's mouth: over the top of a 1.5 scale cat's ears (4.27)
FOUNT_DEG = 56.25                 # the fountain stands on the back wall right of the cat, not behind its head,
#                                   so from the front it does not look like it grows out of the cat
FOUNT_REACH = 0.78                # how far its neck arches in towards the cat


def _bath_at(deg, r):
    """A point round the bath at `deg` (0 right, 90 the back, -90 the front where the player stands) and radius r:
    (x, y, the turn that faces a box's local +X outwards)."""
    t = math.radians(deg)
    return math.cos(t) * r, math.sin(t) * r, t


def _bath_rise(deg):
    """How far the wall stands over the front rim at `deg`: nothing round the front, sweeping up to the back."""
    u = max(0.0, (math.sin(math.radians(deg)) + 0.2) / 1.2)
    return BATH_BACK * u ** 1.6


def _fountain_at(reach=0.0):
    """Where the fountain stands on the wall (x, y), or with `reach` a point that far in towards the middle."""
    x, y, _t = _bath_at(FOUNT_DEG, BATH_R - 0.03 - BATH_WALL / 2 - reach)
    return x, y


SPOUT_X, SPOUT_Y = _fountain_at(FOUNT_REACH)       # the fountain's mouth, behind the cat's left ear


def _bath_shell(b):
    """Plinth, foot, body, gold band, then the wall: a ring of blocks with a cream rolled rim that climbs to the
    slipper back. Neighbours differ a hair in height so their crossing corners share no plane."""
    b.cyl_base((0, 0, -0.02), BATH_PLINTH, 0.22, "spa_cream", segments=16, bevel=False)          # the plinth
    b.cyl_base((0, 0, 0.14), BATH_PLINTH - 0.24, 0.16, "gold_mid", segments=16, bevel=False)     # its gold step
    flare = 0.82
    b.cyl_base((0, 0, 0.24), BATH_BODY - 0.36, flare - 0.2, "spa_bubblegum", segments=16, bevel=False)   # the foot
    b.cyl_base((0, 0, flare), BATH_BODY, BATH_FLOOR - flare, "spa_bubblegum", segments=16, bevel=False)  # the body
    b.cyl_base((0, 0, flare - 0.04), BATH_BODY + 0.04, 0.13, "gold_mid", segments=16, bevel=False)       # gold band
    r = BATH_R - 0.03 - BATH_WALL / 2
    w = 2 * (BATH_R - 0.03) * math.tan(math.pi / BATH_N) + 0.03
    cap = 0.17
    for i in range(BATH_N):
        deg = 360.0 * (i + 0.5) / BATH_N - 90.0
        x, y, t = _bath_at(deg, r)
        rot = Matrix.Rotation(t, 3, "Z")
        top = BATH_RIM + _bath_rise(deg) + 0.004 * (i % 2)
        z0 = BATH_FLOOR - 0.03 - 0.003 * (i % 2)
        b.box_base((x, y, z0), (BATH_WALL, w, top - cap + 0.02 - z0), "spa_bubblegum", bevel=False, rot=rot)
        b.box_base((x, y, top - cap), (BATH_WALL + 0.09, w + 0.02, cap), "spa_cream", rot=rot)   # the rolled rim
    # a paw print painted on the front and one on the back: a white pad and three toes
    face = Matrix.Rotation(math.pi / 2, 3, "Y")
    for side in (-90, 90):
        for k, (deg, z, rad) in enumerate(((0, 1.13, 0.23), (-7.4, 1.4, 0.105), (0, 1.5, 0.11), (7.4, 1.4, 0.105))):
            x, y, t = _bath_at(side + deg, BATH_BODY - 0.006)
            b.cyl((x, y, z), rad, 0.04 + 0.004 * k, "offwhite", segments=8, bevel=False,
                  rot=Matrix.Rotation(t, 3, "Z") @ face)


def _bath_duck(b):
    """A rubber duck on the rim at the front right."""
    x, y, _t = _bath_at(-38, BATH_R - 0.03 - BATH_WALL / 2)
    z = BATH_RIM + _bath_rise(-38)
    b.sphere((x, y, z + 0.14), 0.21, "pastel_butter", segments=8, rings=4, scale=(1.2, 1, 0.8))
    b.sphere((x - 0.08, y - 0.12, z + 0.34), 0.14, "pastel_butter", segments=8, rings=4)
    b.box((x - 0.12, y - 0.28, z + 0.32), (0.1, 0.12, 0.05), "spa_bubblegum", bevel=False)


def _bath_fountain(b):
    """A gold bubble fountain: it stands on the slipper back and arches in over the cat. Its mouth is the mint
    `_Spout` part, built apart."""
    x, y = _fountain_at()
    foot = BATH_RIM + _bath_rise(FOUNT_DEG)
    top = SPOUT_Z + 0.26
    turn = Matrix.Rotation(math.radians(FOUNT_DEG) - math.pi / 2, 3, "Z")       # the neck points at the middle
    b.cyl_base((x, y, foot - 0.02), 0.22, 0.1, "gold_mid", segments=10, bevel=False)             # the flange
    b.cyl_base((x, y, foot + 0.04), 0.12, top - foot - 0.04, "gold_mid", segments=8, bevel=False)   # the riser
    b.sphere((x, y, foot + 0.5), 0.2, "gold_light", segments=8, rings=4)                         # a bead on it
    for d, dz, deg in ((0.13, 0.115, 45), (0.39, 0.23, 90), (0.65, 0.115, 135)):                 # the neck
        nx, ny = _fountain_at(d)
        b.cyl((nx, ny, top + dz), 0.12, 0.44, "gold_mid", segments=8, bevel=False,
              rot=turn @ Matrix.Rotation(math.radians(deg), 3, "X"))
    b.cyl((SPOUT_X, SPOUT_Y, SPOUT_Z + 0.17), 0.19, 0.16, "gold_mid", segments=8, bevel=False)    # the collar


# The bath's lather. Mounds lie on the water round the cat, (degrees, distance out, radius); white balls sit on them;
# two tidy piles stand high against the slipper back; and at the front left the lather spills over the rim and down
# the side to a puddle on the plinth. The front middle stays open water.
BATH_MOUNDS = [(128, 1.22, 0.5), (52, 1.22, 0.5), (178, 1.3, 0.42), (2, 1.3, 0.42), (226, 1.28, 0.44),
               (-52, 1.3, 0.36), (90, 1.3, 0.46)]
BATH_BALLS = [(186, 1.4, 0.17), (-6, 1.4, 0.17), (236, 1.36, 0.19), (-44, 1.38, 0.15), (214, 1.3, 0.16)]
BATH_PILES = [(146, 1.34, 0.34), (34, 1.34, 0.32)]
BATH_SPILL = [(-128, -0.2, 0.0, 0.3), (-112, -0.22, -0.02, 0.2), (-143, -0.2, -0.03, 0.22),    # on the rim
              (-129, 0.02, -0.34, 0.26), (-123, 0.05, -0.74, 0.19), (-133, 0.07, -1.08, 0.14)]  # down the side
#               (degrees, distance out from the rim's edge, height from the rim's top, radius)


def _bath_foam():
    f = Builder()
    for deg, d, r in BATH_MOUNDS:
        x, y, _t = _bath_at(deg, d)
        foam_mound(f, x, y, BATH_WATER, r)
    for deg, d, r in BATH_BALLS:
        x, y, _t = _bath_at(deg, d)
        foam_bubble(f, x, y, BATH_WATER + 0.08, r)
    for k, (deg, d, r) in enumerate(BATH_PILES):
        x, y, _t = _bath_at(deg, d)
        foam_pile(f, x, y, BATH_WATER + 0.1, r, ring=3, turn=0.5 + 2.2 * k, segments=DETAIL["ball"][0],
                  rings=DETAIL["ball"][1])
    for deg, d, dz, r in BATH_SPILL:
        x, y, _t = _bath_at(deg, BATH_R + d)
        foam_bubble(f, x, y, BATH_RIM + dz - 0.45 * r, r)
    x, y, _t = _bath_at(-130, BATH_R + 0.02)                                       # the puddle on the plinth
    foam_mound(f, x, y, 0.2, 0.3)
    return f


def _bath_bubbles():
    spots = []
    for deg, d, lift, r in ((128, 1.18, 0.55, 0.27), (52, 1.18, 0.52, 0.23), (226, 1.22, 0.5, 0.24),
                            (2, 1.26, 0.44, 0.19), (-52, 1.26, 0.4, 0.16)):         # on the lather
        x, y, _t = _bath_at(deg, d)
        spots.append((x, y, BATH_WATER + lift, r))
    x, y, _t = _bath_at(-12, BATH_R - 0.24)
    spots.append((x, y, BATH_RIM + _bath_rise(-12) + 0.17, 0.19))                   # one on the rim
    spots += [(SPOUT_X + 0.42, SPOUT_Y - 0.2, SPOUT_Z - 0.42, 0.15), (SPOUT_X + 0.1, SPOUT_Y - 0.5, SPOUT_Z + 0.3, 0.12),
              (-2.15, -0.5, 3.0, 0.24), (2.2, -0.7, 3.45, 0.19), (-1.75, -1.2, 3.85, 0.14)]   # from the fountain, adrift
    return _bubbles(spots)


def build_bubble_bath(mat):
    """The bubble bath: a round bubblegum slipper bath on a cream and gold plinth (see the notes above). Deep blue
    water (_Water) stands just under the front rim, heaped with lather (_Foam) and soap bubbles (_Bubbles); the
    fountain's mint mouth is `_Spout`."""
    name = "CleanACat_Station_BubbleBath"
    b = Builder()
    _bath_shell(b)
    _bath_duck(b)
    _bath_fountain(b)
    main = _tris(b.finalize(name, mat))
    w_ = Builder()
    z = BATH_FLOOR + 0.004
    w_.cyl_base((0, 0, z), BATH_R - BATH_WALL - 0.01, BATH_WATER - z, "water", segments=16, bevel=False)
    water_shine(w_, BATH_WATER, [(0.25, -1.4, 0.7, 0), (0.85, -1.2, 0.3, 0), (-0.45, -1.52, 0.34, 0),
                                 (-1.0, -0.95, 0.3, 0)])
    water = _tris(w_.finalize(name + "_Water", mat, bevel=0))
    foam = common.shade_smooth(_bath_foam().finalize(name + "_Foam", mat))
    bubbles = common.shade_smooth(_bath_bubbles().finalize(name + "_Bubbles", mat, bevel=0))
    s_ = Builder()                                                                # the fountain's mouth, a bell
    s_.cyl((0, 0, 0), 0.25, 0.2, "spa_mint", segments=10, bevel=False)
    spout = _tris(s_.finalize(name + "_Spout", mat, bevel=0, location=(SPOUT_X, SPOUT_Y, SPOUT_Z)))
    barrier = _barrier(name, mat, (2.9, 2.9, BATH_FLOOR - 0.3), (0, 0, 0.04))
    return [main, water, foam, bubbles, spout, barrier]


def bubble_bath_rbx_extras():
    return {"attachments": [("CleanACat_Station_BubbleBath", "CatSeat", Matrix.Translation((0.0, 0.0, BATH_SEAT))),
                            ("CleanACat_Station_BubbleBath_Spout", "Bubbles",
                             Matrix.Translation((SPOUT_X, SPOUT_Y, SPOUT_Z - 0.1)))],
            "attributes": {"SeatHeight": {"Float64": BATH_SEAT}, "CatScale": {"Float64": STATION_CAT_SCALE}}}


PAW_Z = 1.6                       # the pawdicure table's cushion top, the CatSeat


def build_pawdicure(mat):
    """The pawdicure (#193 made it solid): a lilac cabinet on a cream foot with a gold band and a white paw print
    painted on the front; a cream top with a bubblegum cushion and a mint paw rest at the front; a tray of three
    polish bottles and a nail file at the side; and a brass lamp at the back corner shining down on the paws."""
    name = "CleanACat_Station_Pawdicure"
    b = Builder()
    tw, td, ty = 2.8, 2.2, 0.2
    top = PAW_Z - 0.22
    under = top - 0.14
    flare = 0.46
    b.box_base((0, ty, 0), (tw - 0.74, td - 0.64, flare + 0.04), "spa_cream")              # the foot
    b.box_base((0, ty, flare), (tw - 0.4, td - 0.3, under - flare + 0.02), "pastel_lilac")  # the body
    b.box_base((0, ty, flare - 0.04), (tw - 0.32, td - 0.22, 0.13), "gold_mid", bevel=False)   # the gold band
    b.box_base((0, ty, under), (tw, td, 0.14), "spa_cream")                      # the top
    front = ty - (td - 0.3) / 2
    turn = Matrix.Rotation(math.pi / 2, 3, "X")
    for k, (dx, z, rad) in enumerate(((0, 0.82, 0.19), (-0.24, 1.04, 0.085), (0, 1.12, 0.09), (0.24, 1.04, 0.085))):
        b.cyl((dx, front - 0.004, z), rad, 0.04 + 0.004 * k, "offwhite", segments=8, bevel=False, rot=turn)   # paw print
    b.box_base((0, ty + 0.15, top - 0.02), (tw - 0.9, td - 0.9, 0.24), "spa_bubblegum")      # the cushion
    b.box_base((0, ty - td / 2 + 0.3, top - 0.012), (1.2, 0.5, 0.112), "spa_mint")  # the paw rest at the front edge
    # the tray at the cat's left front corner (+X, -Y): three bottles and a file
    tx, tyy = tw / 2 - 0.38, ty - td / 2 + 0.42
    b.box_base((tx, tyy, top - 0.008), (0.64, 0.66, 0.05), "gold_mid", bevel=False)
    for i, (dx, dy, sw) in enumerate(((-0.15, 0.15, "spa_bubblegum"), (0.14, 0.13, "spa_sky"), (0.0, -0.15, "bow_mint"))):
        b.cyl_base((tx + dx, tyy + dy, top + 0.03), 0.11, 0.28, sw, segments=8, bevel=False)
        b.cyl_base((tx + dx, tyy + dy, top + 0.3), 0.05, 0.12, "offwhite", segments=6, bevel=False)
    b.box((tx - 0.02, tyy - 0.02, top + 0.08), (0.08, 0.52, 0.025), "pastel_butter", bevel=False,
          rot=Matrix.Rotation(math.radians(30), 3, "Z"))                          # the nail file
    # the lamp at the back left corner: a brass post, a neck arching forward and a butter shade over the paws
    lx, ly = -(tw / 2 - 0.25), ty + td / 2 - 0.25
    lamp_top = top + 1.7
    b.cyl_base((lx, ly, top - 0.02), 0.2, 0.1, "brass", segments=8, bevel=False)
    b.cyl_base((lx, ly, top + 0.03), 0.07, lamp_top - top, "brass", segments=8, bevel=False)
    for dy, dz, deg in ((0.1, 0.09, 45), (0.3, 0.17, 90), (0.5, 0.09, 135)):
        b.cyl((lx, ly - dy, lamp_top + dz), 0.07, 0.3, "brass", segments=8, bevel=False,
              rot=Matrix.Rotation(math.radians(deg), 3, "X"))
    b.cyl((lx, ly - 0.62, lamp_top - 0.1), 0.3, 0.3, "pastel_butter", segments=10, bevel=False, radius2=0.13)   # shade
    b.cyl((lx, ly - 0.62, lamp_top - 0.27), 0.2, 0.06, "lamp_warm", segments=8, bevel=False)                   # bulb
    main = _tris(b.finalize(name, mat))
    return [main, _barrier(name, mat, (tw - 0.84, td - 0.8, top - 0.35), (0, ty, 0.03))]


def pawdicure_rbx_extras():
    return {"attachments": [("CleanACat_Station_Pawdicure", "CatSeat", Matrix.Translation((0.0, 0.35, PAW_Z)))],
            "attributes": {"SeatHeight": {"Float64": PAW_Z}, "CatScale": {"Float64": STATION_CAT_SCALE}}}


# The two baths carry round foam and soap bubbles (#107, #111). Each is a Ball part in Roblox, which the engine draws
# itself, so its triangles here are only the preview mesh: 64 a ball and 12 more for a soap bubble's glint. That is
# 1,376 of the tub's 3,384 triangles and 2,564 of the bubble bath's 4,472. The game loads the Parts, never this
# mesh, so the baths' budgets follow what they need (#157, #172); the other stations keep 1,200.
ASSETS = {"CleanACat_Station_Tub": (build_tub, 3400),   # 2500 until #157: the game loads its Parts, not this mesh
          "CleanACat_Station_BrushTable": (build_brush_table, 1200),
          "CleanACat_Station_BrushTableUp": (build_brush_table_up, 1200),
          "CleanACat_Station_Dryer": (build_dryer, 1200),
          "CleanACat_Station_BubbleBath": (build_bubble_bath, 4600),   # 2500 until #172, as the tub
          "CleanACat_Station_Pawdicure": (build_pawdicure, 1200)}
EXTRAS = {"CleanACat_Station_Tub": tub_rbx_extras,
          "CleanACat_Station_BrushTable": brush_table_rbx_extras("CleanACat_Station_BrushTable"),
          "CleanACat_Station_BrushTableUp": brush_table_rbx_extras("CleanACat_Station_BrushTableUp"),
          "CleanACat_Station_Dryer": dryer_rbx_extras,
          "CleanACat_Station_BubbleBath": bubble_bath_rbx_extras,
          "CleanACat_Station_Pawdicure": pawdicure_rbx_extras}
