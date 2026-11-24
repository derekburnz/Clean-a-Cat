"""The spa plot (issue #15). The graybox came first (plain blocks, every gameplay spot in place); this is the real
build on the same layout, so every spot, wall and opening is where the graybox had it.

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
  SpotWindow1..4       the four cushions on the window seat (CleanACat_Prop_Cushion's pivot, on the seat top)
  SpotTipJar           the tip jar, at the right end of the window seat
  SpotSign             the spa's name sign, flat on the outside of the front wall right of the entrance, facing
                       the street
  SpotBuilder          where the builder kitten works
  SpotStation2, 3      the two locked station pads (the Brush Table, then the Blow Dryer)
  SpotStation4, 5      two more station pads on the tub's side of the room, against the left wall (#267): the Bubble
                       Bath beside the tub and a little behind it, and the Pawdicure in front of the bath
  SpotVipDoor          the middle of the VIP Room door, facing into the room
  SpotBoard            the chance board (CleanACat_Prop_ChanceBoard stands here), beside the entrance, facing in
  SpotMascot           the mascot's bed (CleanACat_Prop_SudsBed, #297), just inside the entrance between the door
                       and the chance board, turned to look across the room at the tub
  SpotOpening          where the player stands for the opening scene (#279): on the pavement in front of the
                       entrance, facing the street. The near pavement, not the far one: the houses stand 2 studs
                       behind the far pavement, so a follow camera there would sit inside a house
  SpotBox              where the box that falls off the truck comes to rest, 3.6 studs in front of SpotOpening, its
                       far side just short of the curb
  SpotBump             the speed bump (CleanACat_Prop_SpeedBump) across the near lane, on the road top; the truck
                       drives toward Roblox +X, the player's right

Every gap a player or the camera goes through is 6 studs or wider, but for one: the way round the tub's left to the
back of the room is about 5.5 studs at its narrowest, between the tub and the Bubble Bath once that is built. It is
the only way to the back that is not between two stations, so nothing else may stand in it.

The real build: a bubblegum shop front with a mint and white awning, cream side and back walls with a bubblegum band
outside and a mint band with a white cap rail inside, a checked tile floor with a bubblegum border, a mint roof with
a cream parapet, a round rug under the tub, three warm pendant lamps, a towel shelf, a clock, a paw poster, plants, a
flower box under the window, two lamp posts on the pavement apron and a grassy back yard with a low white fence. The
room pass (#214) added the floor check you can see, the cap rail and the wall decor: a mirror, a tool board, three
framed cats and a towel rail. Decor (`_Decor`, `_Glow`, `_Flowers`) does not
collide; the floors, walls, roof and window seat do.
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
    "SpotWindow1": (-14.0, -14.2, WINDOW_SEAT + 0.03, 0.0),
    "SpotWindow2": (-11.0, -14.2, WINDOW_SEAT + 0.03, 0.0),
    "SpotWindow3": (-8.0, -14.2, WINDOW_SEAT + 0.03, 0.0),
    "SpotWindow4": (-5.0, -14.2, WINDOW_SEAT + 0.03, 0.0),
    "SpotTipJar": (-2.4, -14.2, WINDOW_SEAT + 0.03, 0.0),
    "SpotSign": (13.5, ROOM_Y[0] - WALL_T, 6.0, 0.0),
    "SpotBuilder": (13.0, 6.0, 0.0, 0.0),
    "SpotStation2": (7.0, -1.0, 0.0, 0.0),
    "SpotStation3": (13.5, -1.0, 0.0, 0.0),
    "SpotStation4": (-15.2, 1.0, 0.0, 0.0),
    "SpotStation5": (-15.2, -6.6, 0.0, 0.0),
    "SpotVipDoor": (7.0, ROOM_Y[1] + WALL_T / 2, 0.0, 0.0),
    "SpotMascot": (10.25, -14.3, 0.0, 230.0),
    "SpotOpening": (5.0, -27.0, 0.0, 0.0),
    "SpotBox": (5.0, -30.6, 0.0, 0.0),
    "SpotBump": (1.0, -37.6, -0.28, 90.0),
    "SpotBoard": (13.5, ROOM_Y[0] + 1.4, 0.0, 180.0),
}
# Floor pads that show each spot in the graybox: (spot, size x, size y, swatch)
PADS = [("SpotTub", 5.4, 4.6, "spa_sky"), ("SpotSpawn", 2.4, 2.4, "shirt_green"),
        ("SpotQueue1", 2.4, 2.4, "spa_bubblegum"), ("SpotQueue2", 2.4, 2.4, "spa_bubblegum"),
        ("SpotQueue3", 2.4, 2.4, "spa_bubblegum"), ("SpotStray", 3.0, 3.0, "cardboard"),
        ("SpotBuilder", 3.0, 3.0, "pastel_butter"), ("SpotStation2", 5.0, 5.0, "metal"),
        ("SpotStation3", 5.0, 5.0, "metal"), ("SpotStation4", 5.0, 5.0, "metal"),
        ("SpotStation5", 5.0, 5.0, "metal"), ("SpotVipDoor", 8.0, 2.0, "spa_mint")]


def _walls(b):
    x0, x1 = ROOM_X
    y0, y1 = ROOM_Y
    t, h = WALL_T, WALL_H
    z = FLOOR - 0.05                                   # sunk a little into the slab: no shared face
    hz = h + 0.05
    # side walls run the full depth, overlapping the front and back walls at the corners
    for x in (x0 - t / 2, x1 + t / 2):                 # a hair lower and taller than the front and back pieces
        b.box_base((x, (y0 + y1) / 2, z - 0.03), (t, y1 - y0 + 2 * t - 0.02, hz + 0.05), "spa_cream", bevel=False)

    def span(y, a, c, z0, z1, sw="spa_cream"):
        """A wall piece from x a to c and z0 to z1 above the floor. Pieces that stop above the floor or below the top
        (sill, headers) reach 0.02 into their neighbours and stop 0.01 under the top, and the end pieces reach into the
        side walls, so no two faces share a plane."""
        part = z0 > 0 or z1 < h
        a2 = a - (0.5 if a == x0 else 0.02 if part else 0.0)
        c2 = c + (0.5 if c == x1 else 0.02 if part else 0.0)
        zb = FLOOR + z0 - (0.05 if z0 == 0 else 0)
        zt = FLOOR + z1 - (0.01 if part and z1 == h else 0)
        b.box_base(((a2 + c2) / 2, y, zb), (c2 - a2, t, zt - zb), sw, bevel=False)

    yf, yb = y0 - t / 2, y1 + t / 2
    # front: corner piece, window (sill under, header over), pillar, entrance (header), the right wall
    pink = "spa_bubblegum"                             # the shop front
    span(yf, x0, WINDOW[0], 0, h, pink)
    span(yf, WINDOW[0], WINDOW[1], 0, WINDOW_SEAT, pink)
    span(yf, WINDOW[0], WINDOW[1], 10.0, h, pink)
    span(yf, WINDOW[1], ENTRANCE[0], 0, h, pink)
    span(yf, ENTRANCE[0], ENTRANCE[1], DOOR_H, h, pink)
    span(yf, ENTRANCE[1], x1, 0, h, pink)
    # back: wall, back door (header), wall, VIP door (header), wall
    span(yb, x0, BACK_DOOR[0], 0, h)
    span(yb, BACK_DOOR[0], BACK_DOOR[1], DOOR_H, h)
    span(yb, BACK_DOOR[1], VIP_DOOR[0], 0, h)
    span(yb, VIP_DOOR[0], VIP_DOOR[1], DOOR_H, h)
    span(yb, VIP_DOOR[1], x1, 0, h)


def _floor(b):
    b.box_base((0, 0, 0), (PLOT_W, PLOT_D, FLOOR), "paving_light", bevel=False)
    x0, x1 = ROOM_X
    y0, y1 = ROOM_Y
    b.box_base(((x0 + x1) / 2, (y0 + y1) / 2, FLOOR - 0.03), (x1 - x0 - 0.03, y1 - y0 - 0.03, 0.05), "spa_tile",
               bevel=False)                            # the shop floor, a lighter tile


def _window_seat(b):
    a, c = WINDOW
    y0 = ROOM_Y[0]
    b.box_base(((a + c) / 2, y0 + SEAT_DEPTH / 2 - 0.02, FLOOR - 0.02), (c - a - 0.04, SEAT_DEPTH, WINDOW_SEAT + 0.05),
               "spa_cream", bevel=False)


def _trim(b):
    """A mint frame round the display window and the entrance, on the outside of the front wall."""
    y = ROOM_Y[0] - WALL_T - 0.1
    a, c = WINDOW
    for x0, x1, z0, z1 in ((a - 0.4, c + 0.4, WINDOW_SEAT - 0.4, WINDOW_SEAT), (a - 0.4, c + 0.4, 10.0, 10.4),
                           (a - 0.4, a, WINDOW_SEAT - 0.39, 10.39), (c, c + 0.4, WINDOW_SEAT - 0.39, 10.39),
                           (ENTRANCE[0] - 0.4, ENTRANCE[1] + 0.4, DOOR_H, DOOR_H + 0.4),
                           (ENTRANCE[0] - 0.4, ENTRANCE[0], 0.0, DOOR_H - 0.01), (ENTRANCE[1], ENTRANCE[1] + 0.4, 0.0, DOOR_H - 0.01)):
        side = (z1 - z0) > 1.0                         # the uprights sit a hair proud of the rails: no shared face
        if side:
            x0, x1 = x0 + 0.01, x1 - 0.01
        b.box_base(((x0 + x1) / 2, y - (0.01 if side else 0.0), FLOOR + z0), (x1 - x0, 0.22, z1 - z0), "spa_mint",
                   bevel=False)


def _glass(b):
    a, c = WINDOW
    b.box_base(((a + c) / 2, ROOM_Y[0] - WALL_T / 2, FLOOR + WINDOW_SEAT - 0.02), (c - a - 0.02, 0.3, 10.0 - WINDOW_SEAT + 0.04),
               "glass", bevel=False)


def _roof(b):
    x0, x1 = ROOM_X
    y0, y1 = ROOM_Y
    w, d = x1 - x0 + 2 * WALL_T + 1.0, y1 - y0 + 2 * WALL_T + 1.0
    z = FLOOR + WALL_H - 0.03
    b.box_base(((x0 + x1) / 2, (y0 + y1) / 2, z), (w, d, 0.8), "spa_mint", bevel=False)
    # a cream parapet round the edge, standing on the roof: front and back full width, the sides between them
    cy = (y0 + y1) / 2
    for y in (cy - d / 2 + 0.3, cy + d / 2 - 0.3):
        b.box_base(((x0 + x1) / 2, y, z + 0.78), (w + 0.04, 0.6, 1.0), "spa_cream", bevel=False)
    for x in (-w / 2 + 0.3, w / 2 - 0.3):
        b.box_base((x, cy, z + 0.77), (0.6, d - 1.18, 0.98), "spa_cream", bevel=False)


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


def _yard(b):
    """Grass in the back yard, from just behind the back wall to the plot's back edge, inside the side alleys."""
    y0 = ROOM_Y[1] + WALL_T + 0.02
    y1 = PLOT_D / 2 - 0.1
    b.box_base((0, (y0 + y1) / 2, FLOOR - 0.03), (PLOT_W - 0.2, y1 - y0, 0.07), "leaf_green", bevel=False)


def _bands(b):
    """A bubblegum band round the outside of the cream side and back walls, a mint band on the inside of all three
    with a white cap rail."""
    x0, x1 = ROOM_X
    y0, y1 = ROOM_Y
    t = WALL_T
    z = FLOOR - 0.02
    band = 3.0
    for sx, x in ((-1, x0 - t), (1, x1 + t)):                                  # outside, the sides
        b.box_base((x + sx * 0.08, (y0 + y1) / 2 + 0.01, z), (0.2, y1 - y0 + 2 * t + 0.14, band), "spa_bubblegum",
                   bevel=False)
    yb = y1 + t + 0.08                                                          # outside, the back, between doors
    for a, c in ((x0 - t - 0.06, BACK_DOOR[0]), (BACK_DOOR[1], VIP_DOOR[0]), (VIP_DOOR[1], x1 + t + 0.06)):
        b.box_base(((a + c) / 2, yb, z + 0.004), (c - a, 0.2, band), "spa_bubblegum", bevel=False)
    for sx, x in ((-1, x0), (1, x1)):                                           # inside, the sides (behind the seat)
        b.box_base((x - sx * 0.08, (y0 + y1) / 2, z + 0.007), (0.2, y1 - y0 - 0.02, 2.5), "spa_mint", bevel=False)
    for a, c in ((x0 + 0.2, BACK_DOOR[0]), (BACK_DOOR[1], VIP_DOOR[0]), (VIP_DOOR[1], x1 - 0.2)):
        b.box_base(((a + c) / 2, y1 - 0.08, z + 0.012), (c - a, 0.2, 2.5), "spa_mint", bevel=False)
    # #214: a white cap rail along the top of the mint band, a little proud of it
    for sx, x in ((-1, x0), (1, x1)):
        b.box_base((x - sx * 0.12, (y0 + y1) / 2, FLOOR + 2.44), (0.3, y1 - y0 - 0.06, 0.26), "offwhite", bevel=False)
    for a, c in ((x0 + 0.28, BACK_DOOR[0] - 0.01), (BACK_DOOR[1] + 0.01, VIP_DOOR[0] - 0.01),
                 (VIP_DOOR[1] + 0.01, x1 - 0.28)):     # a hair short of each door edge, where the band ends
        b.box_base(((a + c) / 2, y1 - 0.12, FLOOR + 2.445), (c - a, 0.3, 0.26), "offwhite", bevel=False)


TILE = "tile_sky"                 # the check's second colour (#214): paler than the tub's sky blue


def _tiles(b):
    """Checked floor (#214): 4 by 4.33 stud tiles in a colour that shows from the play camera, and a bubblegum border
    round the room. The tiles stand 0.02 over the shop floor and the border 0.02 over the tiles."""
    x0, x1 = ROOM_X
    y0, y1 = ROOM_Y
    nx, ny = 9, 6
    w, d = (x1 - x0) / nx, (y1 - y0) / ny
    for i in range(nx):
        for j in range(ny):
            if (i + j) % 2:
                continue
            b.box_base((x0 + w * (i + 0.5), y0 + d * (j + 0.5), FLOOR - 0.01), (w - 0.02, d - 0.02, 0.05), TILE,
                       bevel=False)
    t = 0.6                                            # the border starts above the tiles' undersides: no shared face
    for x in (x0 + t / 2, x1 - t / 2):
        b.box_base((x, (y0 + y1) / 2, FLOOR + 0.005), (t, y1 - y0 - 0.04, 0.055), "spa_bubblegum", bevel=False)
    for y in (y0 + t / 2, y1 - t / 2):
        b.box_base(((x0 + x1) / 2, y, FLOOR + 0.005), (x1 - x0 - 2 * t - 0.02, t, 0.055), "spa_bubblegum", bevel=False)


def _wall_decor(b):
    """#214: things to look at on the walls, none of them near the floor or behind the cat in the tub as the play
    camera sees it. Back wall: a round mirror with a shelf (right of the tub) and a tool board under the clock.
    Left wall: three framed cats over the stray box. Right wall: a rail of hanging towels."""
    F = FLOOR
    x0, x1 = ROOM_X
    y1 = ROOM_Y[1]
    rx = Matrix.Rotation(math.pi / 2, 3, "X")
    # the mirror: a gold frame, a pale glass (solid, never see-through: #176) and two glints
    mx, mz = 0.0, F + 6.3
    b.cyl((mx, y1 - 0.09, mz), 1.75, 0.18, "gold_mid", segments=20, bevel=False, rot=rx)
    b.cyl((mx, y1 - 0.16, mz), 1.48, 0.12, "pastel_sky", segments=20, bevel=False, rot=rx)
    tilt = Matrix.Rotation(math.radians(35), 3, "Y")
    b.box((mx - 0.45, y1 - 0.23, mz + 0.3), (0.2, 0.04, 1.3), "foam", bevel=False, rot=tilt)
    b.box((mx - 0.05, y1 - 0.235, mz - 0.15), (0.12, 0.04, 0.8), "foam", bevel=False, rot=tilt)
    b.box((mx, y1 - 0.42, mz - 2.5), (3.2, 0.8, 0.18), "wood_light", bevel=False)                  # its shelf
    b.cyl_base((mx - 1.0, y1 - 0.45, mz - 2.41), 0.24, 0.8, "spa_bubblegum", segments=8, bevel=False)
    b.cyl_base((mx - 0.4, y1 - 0.45, mz - 2.41), 0.2, 0.6, "spa_mint", segments=8, bevel=False)
    b.box_base((mx + 0.8, y1 - 0.45, mz - 2.41), (1.0, 0.62, 0.42), "offwhite")                    # a folded towel
    # the tool board: a wooden board with a cream face and three tools hung on it
    tx, tz = 14.5, F + 5.9
    b.box((tx, y1 - 0.08, tz), (5.0, 0.16, 3.0), "wood_light", bevel=False)
    b.box((tx, y1 - 0.14, tz), (4.6, 0.1, 2.6), "spa_cream", bevel=False)
    b.box((tx - 1.5, y1 - 0.26, tz + 0.2), (1.0, 0.16, 0.56), "spa_bubblegum", bevel=False)        # a brush
    b.box((tx - 1.5, y1 - 0.26, tz - 0.36), (0.9, 0.14, 0.5), "offwhite", bevel=False)
    b.box((tx, y1 - 0.25, tz + 0.3), (0.4, 0.14, 1.5), "spa_sky", bevel=False)                     # a comb
    b.box((tx + 0.42, y1 - 0.25, tz + 0.0), (0.5, 0.12, 0.9), "offwhite", bevel=False)
    b.box((tx + 1.5, y1 - 0.3, tz), (1.1, 0.24, 0.8), "pastel_butter")                             # a sponge
    b.box((tx + 1.5, y1 - 0.3, tz + 0.5), (1.14, 0.28, 0.24), "spa_mint", bevel=False)
    # three framed cats on the left wall, over the stray box
    turn = Matrix.Rotation(math.radians(45), 3, "X")
    for k, (y, card, coat) in enumerate(((2.4, "spa_sky", "fur_orange"), (5.2, "spa_bubblegum", "fur_charcoal"),
                                         (8.0, "pastel_butter", "fur_grey"))):
        z = F + 6.9 + (0.25 if k == 1 else 0.0)
        b.box((x0 + 0.08, y, z), (0.16, 2.2, 2.6), "wood_light", bevel=False)
        b.box((x0 + 0.13, y, z), (0.1, 1.8, 2.2), card, bevel=False)
        b.sphere((x0 + 0.2, y, z - 0.25), 0.62, coat, segments=8, rings=5, scale=(0.22, 1, 0.9))
        for sy in (-1, 1):
            b.box((x0 + 0.22, y + sy * 0.36, z + 0.22), (0.1, 0.36, 0.36), coat, bevel=False, rot=turn)
    # a rail of three towels on the right wall, between the chance board and the stations
    b.box((x1 - 0.14, -7.0, F + 6.6), (0.28, 5.2, 0.24), "wood_light", bevel=False)
    for y, sw in ((-8.7, "spa_bubblegum"), (-7.0, "spa_sky"), (-5.3, "spa_mint")):
        b.box((x1 - 0.2, y, F + 5.45), (0.2, 1.3, 2.3), sw)


def _decor(b):
    """Inside: the tub rug, a towel shelf, a clock, a paw poster, two plants, three pendant lamps and the wall
    decor of #214. Outside: the
    flower box under the window, two pots at the entrance, two lamp posts and the yard fence. None of it collides."""
    F = FLOOR
    x0, x1 = ROOM_X
    y0, y1 = ROOM_Y
    tx, ty, _, _ = SPOTS["SpotTub"]
    b.cyl_base((tx, ty - 0.6, F + 0.03), 3.4, 0.035, "spa_bubblegum", segments=16, bevel=False, scale=(1.3, 1, 1))
    # a towel shelf on the left wall, between the window seat and the stray box
    sx = x0 + 0.7
    for z in (4.6, 7.0):
        b.box((sx, -4.0, F + z), (1.2, 6.0, 0.2), "wood_light", bevel=False)
        for k, (yy, sw) in enumerate(((-6.0, "spa_sky"), (-4.9, "spa_bubblegum"), (-3.8, "spa_mint"))):
            if z > 5 and k == 2:
                continue
            b.box_base((sx, yy, F + z + 0.1), (0.9, 0.9, 0.5 + 0.12 * (k % 2)), sw)
        if z > 5:
            for k, yy in enumerate((-2.6, -1.9)):
                b.cyl_base((sx, yy, F + z + 0.1), 0.22, 0.75 - 0.1 * k, "spa_sky" if k else "spa_bubblegum",
                           segments=8, bevel=False)
    # a clock on the back wall right of the VIP Room door, and a paw poster on the right wall
    rx = Matrix.Rotation(math.pi / 2, 3, "X")
    cx, cz = 14.5, F + 9.5
    b.cyl((cx, y1 - 0.12, cz), 1.0, 0.16, "offwhite", segments=16, bevel=False, rot=rx)
    b.cyl((cx, y1 - 0.2, cz), 1.2, 0.1, "spa_mint", segments=16, bevel=False, rot=rx)
    b.box((cx, y1 - 0.24, cz + 0.25), (0.12, 0.04, 0.6), "fur_charcoal", bevel=False)
    b.box((cx + 0.2, y1 - 0.26, cz + 0.01), (0.5, 0.04, 0.1), "fur_charcoal", bevel=False)   # not in line with the other hand's end
    _wall_decor(b)
    px = x1 - 0.12
    b.box((px, 2.0, F + 7.0), (0.12, 4.0, 3.0), "spa_sky", bevel=False)
    b.box((px - 0.05, 2.0, F + 7.0), (0.1, 3.4, 2.4), "offwhite", bevel=False)
    b.sphere((px - 0.12, 2.0, F + 6.7), 0.55, "spa_bubblegum", segments=8, rings=4, scale=(0.3, 1, 0.85))
    for dy, dz in ((-0.65, 0.65), (-0.22, 0.95), (0.22, 0.95), (0.65, 0.65)):
        b.sphere((px - 0.12, 2.0 + dy, F + 6.7 + dz), 0.22, "spa_bubblegum", segments=6, rings=4, scale=(0.3, 1, 1))
    # plants in two corners
    for x, y in ((x1 - 1.4, y1 - 1.4), (x0 + 1.4, -10.4)):
        b.cyl_base((x, y, F - 0.006), 0.7, 1.4, "terracotta", segments=10, bevel=False, radius2=0.85)
        b.sphere((x, y, F + 2.2), 1.1, "leaf_green", segments=8, rings=6)
        b.sphere((x + 0.3, y - 0.2, F + 3.0), 0.7, "leaf_dark", segments=8, rings=5)
    # pendant lamp cords and shades (the bulbs glow, in _glow)
    for x, y in LAMPS:
        b.cyl((x, y, F + WALL_H - 1.0), 0.05, 2.0, "fur_charcoal", segments=6, bevel=False)
        b.cyl_base((x, y, F + WALL_H - 2.6), 0.9, 0.6, "spa_mint", segments=12, bevel=False, radius2=0.35)
    # the strays sign over the back door
    bx = (BACK_DOOR[0] + BACK_DOOR[1]) / 2
    b.box((bx, y1 - 0.12, F + DOOR_H + 1.3), (3.6, 0.1, 1.4), "cardboard", bevel=False)
    b.sphere((bx, y1 - 0.2, F + DOOR_H + 1.2), 0.38, "spa_cream", segments=8, rings=4, scale=(1, 0.3, 0.85))
    for dx, dz in ((-0.45, 0.42), (0.0, 0.58), (0.45, 0.42)):
        b.sphere((bx + dx, y1 - 0.2, F + DOOR_H + 1.2 + dz), 0.15, "spa_cream", segments=6, rings=4,
                 scale=(1, 0.3, 1))
    # outside: the flower box under the window, pots by the entrance, lamp posts on the apron
    yo = y0 - WALL_T
    a, c = WINDOW
    b.box_base(((a + c) / 2, yo - 0.7, F - 0.01), (c - a - 1.0, 1.2, 1.3), "wood_light", bevel=False)
    for x in (ENTRANCE[0] - 1.4, ENTRANCE[1] + 1.4):
        b.cyl_base((x, yo - 1.2, F - 0.01), 0.75, 1.5, "terracotta", segments=10, bevel=False, radius2=0.9)
        b.sphere((x, yo - 1.2, F + 2.3), 1.15, "leaf_green", segments=8, rings=6)
    for x in (-PLOT_W / 2 + 1.6, PLOT_W / 2 - 1.6):
        b.cyl_base((x, -PLOT_D / 2 + 1.6, F - 0.01), 0.22, 7.0, "fur_charcoal", segments=8, bevel=False)
        b.box((x, -PLOT_D / 2 + 1.6, F + 7.1), (0.9, 0.9, 0.25), "fur_charcoal", bevel=False)
    # a low white fence round the yard: posts and two rails, inside the plot edge so neighbours never overlap
    fy0, fy1 = y1 + WALL_T + 0.6, PLOT_D / 2 - 0.5
    fx = PLOT_W / 2 - 0.5
    for x in (-fx, fx):
        for k in range(4):
            y = fy0 + (fy1 - fy0) * k / 3
            b.box_base((x, y, F - 0.01), (0.3, 0.3, 2.4), "offwhite", bevel=False)
        for z in (0.9, 1.9):
            b.box((x, (fy0 + fy1) / 2, F + z), (0.12, fy1 - fy0, 0.22), "offwhite", bevel=False)
    for k in range(1, 8):
        x = -fx + 2 * fx * k / 8
        b.box_base((x, fy1, F - 0.01), (0.3, 0.3, 2.4), "offwhite", bevel=False)
    for z in (0.92, 1.92):
        b.box((0, fy1, F + z), (2 * fx - 0.02, 0.12, 0.22), "offwhite", bevel=False)


LAMPS = ((-5.0, -2.0), (10.0, -1.0), (-10.0, 4.0))   # pendant lamps over the tub, the stations and the stray side


def _glow(b):
    """The warm bulbs: under the pendant shades and on the lamp posts (Neon)."""
    F = FLOOR
    for x, y in LAMPS:
        b.sphere((x, y, F + WALL_H - 2.65), 0.32, "lamp_warm", segments=8, rings=5)
    for x in (-PLOT_W / 2 + 1.6, PLOT_W / 2 - 1.6):
        b.box((x, -PLOT_D / 2 + 1.6, F + 7.6), (0.6, 0.6, 0.75), "lamp_warm", bevel=False)


def _flowers(b):
    """Flowers in the window box."""
    a, c = WINDOW
    yo = ROOM_Y[0] - WALL_T - 0.7
    for k in range(7):
        x = a + 1.0 + (c - a - 2.0) * k / 6
        sw = ("spa_bubblegum", "pastel_butter", "spa_sky")[k % 3]
        b.sphere((x, yo, FLOOR + 1.45 + 0.06 * (k % 2)), 0.55, sw, segments=8, rings=5)
        b.sphere((x + 0.45, yo + 0.2, FLOOR + 1.35), 0.4, "leaf_green", segments=6, rings=4)


def _pads(b):
    for spot, sx, sy, sw in PADS:
        x, y, z, _ = SPOTS[spot]
        b.box_base((x, y, FLOOR - 0.01), (sx, sy, 0.07), sw, bevel=False)


def build_plot(mat):
    name = "CleanACat_Area_SpaPlot"
    parts = [("", lambda b: (_floor(b), _yard(b))), ("_Wall", _walls), ("_WindowSeat", _window_seat),
             ("_Glass", _glass), ("_Roof", _roof), ("_Canopy", _canopy), ("_Trim", _trim), ("_Bands", _bands),
             ("_Tiles", _tiles), ("_Decor", _decor), ("_Glow", _glow), ("_Flowers", _flowers)]
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
