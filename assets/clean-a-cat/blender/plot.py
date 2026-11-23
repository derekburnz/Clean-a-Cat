"""The spa plot (issue #15). Graybox first: plain blocks in flat colours, every gameplay spot in place, so the layout
can be walked, played and changed before anything is detailed.

  CleanACat_Area_SpaPlot   one player's spa on the street: a 44 by 48 stud plot with a front apron on the pavement,
                           the spa room (36 wide, 26 deep, walls 12 tall) and a back yard where the VIP Room is
                           built later (#21). The room has an open front: an 8 stud entrance with no door, and a big
                           display window with a window seat and four cushions. A back door (6 wide, open) leads to
                           the stray box, and an 8 stud opening in the back wall is the VIP Room door (the curtain
                           and countdown sign come with #21). No room or tub is made for avatars: only cats bathe.

Pivot at the plot's centre on the ground (z 0), the front (the street) at -Y in Blender, -Z in Roblox. The floor top
is at FLOOR studs. Gameplay spots are Attachments in the floor slab, each facing the way a player or a customer
faces there (the Attachment's LookVector), all at floor height:

  SpotTub              the tub's pivot (put CleanACat_Station_Tub here); the tub's front faces the entrance side
  SpotSpawn            where the player spawns, in front of the tub, facing it
  SpotQueue1..3        the customer queue: 1 just inside the entrance, 2 in the doorway, 3 on the apron
  SpotStray            the stray box, inside the back door
  SpotWindow1..4       the four cushions on the window seat (the cushion top, WINDOW_SEAT above the floor)
  SpotBuilder          where the builder kitten works
  SpotStation2, 3      the two locked station pads (the Brush Table, then the Blow Dryer)
  SpotVipDoor          the middle of the VIP Room door, facing into the room
  SpotBoard            the chance board, on the wall beside the entrance, facing in

Every gap a player or the camera goes through is 6 studs or wider.
"""

import math

from mathutils import Matrix

from common import Builder
from stations import _tris

PLOT_W, PLOT_D = 44.0, 48.0
FLOOR = 0.5                       # top of the floor slab (thick enough to collide: rbx_export.MIN_COLLIDE)
ROOM_X = (-18.0, 18.0)            # inner faces of the side walls
ROOM_Y = (-16.0, 10.0)            # front wall line and back wall line
WALL_H, WALL_T = 12.0, 1.0
ENTRANCE = (1.0, 9.0)             # x span of the open entrance
WINDOW = (-16.0, -1.0)            # x span of the display window
WINDOW_SEAT = 2.5                 # the seat's top above the floor
SEAT_DEPTH = 3.5
BACK_DOOR = (-15.0, -9.0)         # x span of the open back door
VIP_DOOR = (3.0, 11.0)            # x span of the VIP Room door
DOOR_H = 9.0                      # opening height for both doors and the entrance

SPOTS = {
    # name: (x, y, z above the floor, turn in degrees about the vertical; 0 faces the street, 180 faces the back)
    "SpotTub": (-5.0, -2.0, 0.0, 0.0),
    "SpotSpawn": (-5.0, -8.5, 0.0, 180.0),
    "SpotQueue1": (5.0, -13.0, 0.0, 180.0),
    "SpotQueue2": (5.0, -17.5, 0.0, 180.0),
    "SpotQueue3": (5.0, -21.5, 0.0, 180.0),
    "SpotStray": (-12.0, 7.0, 0.0, 0.0),
    "SpotWindow1": (-13.5, -14.2, WINDOW_SEAT + 0.35, 0.0),
    "SpotWindow2": (-10.0, -14.2, WINDOW_SEAT + 0.35, 0.0),
    "SpotWindow3": (-6.5, -14.2, WINDOW_SEAT + 0.35, 0.0),
    "SpotWindow4": (-3.0, -14.2, WINDOW_SEAT + 0.35, 0.0),
    "SpotBuilder": (13.0, 6.0, 0.0, 0.0),
    "SpotStation2": (7.0, -1.0, 0.0, 0.0),
    "SpotStation3": (13.5, -1.0, 0.0, 0.0),
    "SpotVipDoor": (7.0, ROOM_Y[1] + WALL_T / 2, 0.0, 0.0),
    "SpotBoard": (13.5, ROOM_Y[0] + WALL_T + 0.05, 4.0, 180.0),
}
# Floor pads that show each spot in the graybox: (spot, size x, size y, swatch)
PADS = [("SpotTub", 5.4, 4.6, "spa_sky"), ("SpotSpawn", 2.4, 2.4, "shirt_green"),
        ("SpotQueue1", 2.4, 2.4, "spa_bubblegum"), ("SpotQueue2", 2.4, 2.4, "spa_bubblegum"),
        ("SpotQueue3", 2.4, 2.4, "spa_bubblegum"), ("SpotStray", 3.0, 3.0, "cardboard"),
        ("SpotBuilder", 3.0, 3.0, "pastel_butter"), ("SpotStation2", 5.0, 5.0, "metal"),
        ("SpotStation3", 5.0, 5.0, "metal"), ("SpotVipDoor", 8.0, 2.0, "spa_mint")]


def _walls(b):
    x0, x1 = ROOM_X
    y0, y1 = ROOM_Y
    t, h = WALL_T, WALL_H
    z = FLOOR - 0.05                                   # sunk a little into the slab: no shared face
    hz = h + 0.05
    # side walls run the full depth, overlapping the front and back walls at the corners
    for x in (x0 - t / 2, x1 + t / 2):                 # a hair lower and taller than the front and back pieces
        b.box_base((x, (y0 + y1) / 2, z - 0.03), (t, y1 - y0 + 2 * t - 0.02, hz + 0.05), "offwhite", bevel=False)

    def span(y, a, c, z0, z1):
        """A wall piece from x a to c and z0 to z1 above the floor. Pieces that stop above the floor or below the top
        (sill, headers) reach 0.02 into their neighbours and stop 0.01 under the top, and the end pieces reach into the
        side walls, so no two faces share a plane."""
        part = z0 > 0 or z1 < h
        a2 = a - (0.5 if a == x0 else 0.02 if part else 0.0)
        c2 = c + (0.5 if c == x1 else 0.02 if part else 0.0)
        zb = FLOOR + z0 - (0.05 if z0 == 0 else 0)
        zt = FLOOR + z1 - (0.01 if part and z1 == h else 0)
        b.box_base(((a2 + c2) / 2, y, zb), (c2 - a2, t, zt - zb), "offwhite", bevel=False)

    yf, yb = y0 - t / 2, y1 + t / 2
    # front: corner piece, window (sill under, header over), pillar, entrance (header), the right wall
    span(yf, x0, WINDOW[0], 0, h)
    span(yf, WINDOW[0], WINDOW[1], 0, WINDOW_SEAT)
    span(yf, WINDOW[0], WINDOW[1], 10.0, h)
    span(yf, WINDOW[1], ENTRANCE[0], 0, h)
    span(yf, ENTRANCE[0], ENTRANCE[1], DOOR_H, h)
    span(yf, ENTRANCE[1], x1, 0, h)
    # back: wall, back door (header), wall, VIP door (header), wall
    span(yb, x0, BACK_DOOR[0], 0, h)
    span(yb, BACK_DOOR[0], BACK_DOOR[1], DOOR_H, h)
    span(yb, BACK_DOOR[1], VIP_DOOR[0], 0, h)
    span(yb, VIP_DOOR[0], VIP_DOOR[1], DOOR_H, h)
    span(yb, VIP_DOOR[1], x1, 0, h)


def _floor(b):
    b.box_base((0, 0, 0), (PLOT_W, PLOT_D, FLOOR), "metal", bevel=False)
    x0, x1 = ROOM_X
    y0, y1 = ROOM_Y
    b.box_base(((x0 + x1) / 2, (y0 + y1) / 2, FLOOR - 0.03), (x1 - x0 - 0.02, y1 - y0 - 0.02, 0.05), "spa_tile",
               bevel=False)                            # the shop floor, a lighter tile


def _window_seat(b):
    a, c = WINDOW
    y0 = ROOM_Y[0]
    b.box_base(((a + c) / 2, y0 + SEAT_DEPTH / 2 - 0.02, FLOOR - 0.02), (c - a - 0.04, SEAT_DEPTH, WINDOW_SEAT + 0.05),
               "spa_cream", bevel=False)


def _cushions(b):
    for i in range(1, 5):
        x, y, z, _ = SPOTS[f"SpotWindow{i}"]
        b.cyl_base((x, y, FLOOR + WINDOW_SEAT - 0.02), 1.2, 0.37, "bow_pink", segments=12, bevel=False)


def _glass(b):
    a, c = WINDOW
    b.box_base(((a + c) / 2, ROOM_Y[0] - WALL_T / 2, FLOOR + WINDOW_SEAT - 0.02), (c - a - 0.02, 0.3, 10.0 - WINDOW_SEAT + 0.04),
               "glass", bevel=False)


def _roof(b):
    x0, x1 = ROOM_X
    y0, y1 = ROOM_Y
    b.box_base(((x0 + x1) / 2, (y0 + y1) / 2, FLOOR + WALL_H - 0.03), (x1 - x0 + 2 * WALL_T + 1.0, y1 - y0 + 2 * WALL_T + 1.0, 0.8),
               "fur_grey", bevel=False)


def _canopy(b):
    """A striped awning over the whole shop front, out over the apron."""
    x0, x1 = ROOM_X
    y = ROOM_Y[0] - WALL_T
    n = 12
    w = (x1 - x0 + 2 * WALL_T) / n
    for i in range(n):
        x = x0 - WALL_T + w * (i + 0.5)
        rot = Matrix.Rotation(math.radians(18), 3, "X")          # the outer edge lower
        b.box((x, y - 1.6, FLOOR + 10.6), (w + 0.01 * (i % 2), 3.4, 0.25 + 0.08 * (i % 2)),
              "spa_mint" if i % 2 else "offwhite", bevel=False, rot=rot)


def _pads(b):
    for spot, sx, sy, sw in PADS:
        x, y, z, _ = SPOTS[spot]
        b.box_base((x, y, FLOOR - 0.01), (sx, sy, 0.07), sw, bevel=False)


def build_plot(mat):
    name = "CleanACat_Area_SpaPlot"
    parts = [("", lambda b: (_floor(b),)), ("_Wall", _walls), ("_WindowSeat", _window_seat), ("_Glass", _glass),
             ("_Roof", _roof), ("_Canopy", _canopy), ("_Decor", lambda b: (_cushions(b), _pads(b)))]
    objs = []
    for suffix, fn in parts:
        b = Builder()
        fn(b)
        objs.append(_tris(b.finalize(name + suffix, mat, bevel=0)))
    return objs


def plot_rbx_extras():
    atts = []
    for spot, (x, y, z, turn) in SPOTS.items():
        M = Matrix.Translation((x, y, FLOOR + z)) @ Matrix.Rotation(math.radians(turn), 4, "Z")
        atts.append(("CleanACat_Area_SpaPlot", spot, M))
    return {"attachments": atts, "attributes": {"FloorHeight": {"Float64": FLOOR}}}


ASSETS = {"CleanACat_Area_SpaPlot": (build_plot, 25000)}
EXTRAS = {"CleanACat_Area_SpaPlot": plot_rbx_extras}
