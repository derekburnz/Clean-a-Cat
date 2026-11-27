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
  SpotStray            the stray box, in the back left corner beside the back door, facing the room
  SpotWindow1..4       the four cushions on the window seat (CleanACat_Prop_Cushion's pivot, on the seat top)
  SpotTipJar           the tip jar, at the right end of the window seat
  SpotSign             the spa's name sign, flat on the outside of the front wall right of the entrance, facing
                       the street
  SpotBuilder          where the builder kitten works
  SpotStation2, 3      the two locked station pads (the Brush Table, then the Blow Dryer)
  SpotStation4, 5      two more station pads on the tub's side of the room, against the left wall (#267): the Bubble
                       Bath beside the tub and a little behind it, and the Pawdicure in front of the bath
  SpotVipDoor          the middle of the VIP Room door, facing into the room
  SpotGardenDoor       the middle of the back door, facing into the room: the Garden's three looks (garden.py)
  SpotWorkerJo, Sam, Lou   the three workers' wash stands (worker_stations.py, #527): Sam and Lou on the back wall
                           between the doors, Jo right of the VIP door (#878)
                           facing the entrance side
  SpotBoard            the chance board (CleanACat_Prop_ChanceBoard stands here), beside the entrance, facing in
  SpotMascot           the mascot's bed (CleanACat_Prop_SudsBed, #297), just inside the entrance between the door
                       and the chance board, turned to look across the room at the tub
  SpotOpening          where the player stands for the opening scene (#279): on the pavement in front of the
                       entrance, facing the street. The near pavement, not the far one: the houses stand 2 studs
                       behind the far pavement, so a follow camera there would sit inside a house
  SpotBox              where the box that falls off the truck comes to rest: 3.6 studs out from SpotOpening and 5
                       to the player's right (Roblox +X), its far side just short of the curb. To the side because
                       straight ahead the player's own avatar hides the box from the follow camera on a phone, and 5
                       because at 3 an arm half hid the kitten. It was on the player's left until the owner asked
                       for the pothole "closer to being right infront of you": the box rolls past in front of the
                       player and stops here (#343, Motion-FX's numbers)
  SpotBump             the pothole (CleanACat_Prop_Pothole; the speed bump until #343) in the near lane, on the road
                       top; the truck drives toward Roblox +X, the player's right. It lies 2.5 studs before the
                       player on the truck's way and 7.5 before SpotBox: the box keeps the truck's speed, lands on
                       its edge and rolls one whole turn, about 8 studs

Every gap a player or the camera goes through is 6 studs or wider, but for one: the way round the tub's left to the
back of the room is about 5.5 studs at its narrowest, between the tub and the Bubble Bath once that is built. It is
the only way to the back that is not between two stations, so nothing else may stand in it.

The real build: a bubblegum shop front with a mint and white awning, cream side and back walls with a bubblegum band
outside and a mint band with a white cap rail inside, a checked tile floor with a bubblegum border, a mint roof with
a cream parapet, a round rug under the tub, three warm pendant lamps, a towel shelf, a clock, a paw poster, plants, a
flower box under the window, two lamp posts on the pavement apron and a grassy back yard with a low white fence. The
room pass (#214) added the floor check you can see, the cap rail and the wall decor: a mirror, a tool board, three
framed cats and a towel rail. Decor (`_Decor`, `_Glow`, `_Flowers`) does not
collide; the floors, walls, roof and window seat do, and so do the back plates of what hangs on the walls
(`_WallArt`, #670), so the camera stops in front of a picture instead of inside it.
"""

import math

from mathutils import Matrix

from common import Builder
from stations import _tris

PLOT_W, PLOT_D = 44.0, 48.0
PLOT_X = (-PLOT_W / 2, PLOT_W / 2)   # the plot's edges; the pivot is the middle of the small plot
PLOT_Y = (-PLOT_D / 2, PLOT_D / 2)   # front edge (the pavement side) and back edge
NAME = "CleanACat_Area_SpaPlot"
FLOOR = 0.5                       # top of the floor slab (thick enough to collide: rbx_export.MIN_COLLIDE)
ROOM_X = (-18.0, 18.0)            # inner faces of the side walls
ROOM_Y = (-16.0, 10.0)            # front wall line and back wall line
WALL_H, WALL_T = 12.0, 1.0
ENTRANCE = (1.0, 9.0)             # x span of the open entrance
WINDOW = (-16.0, -1.0)            # x span of the display window
WINDOW_SEAT = 2.5                 # the seat's top above the floor
WINDOW_TOP = 10.0                 # the top of the window's opening above the floor
SEAT_DEPTH = 3.5
COUNTER = False                   # the bigger plot (#746): WINDOW is an open counter window, no glass (see BIG)
DISPLAY = None                    # the bigger plot: x span of a second, glazed display window right of the entrance
DISPLAY_SEAT, DISPLAY_TOP = 2.5, 6.6
TOWELS_Y = -7.0                   # where the towel rail hangs along the right wall
FRAME_SHIFT = 0.0                 # how far back the left wall's three frames move with the stray box
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
    # Beside the back door, against the left wall and turned to face the room like the two stations on that wall.
    # It stood at (-12, 7), 3 studs in front of the door, until the Garden went in behind it (#579): there it sat in
    # the walking line to the Garden's gate.
    "SpotStray": (-16.4, 7.6, 0.0, 90.0),
    "SpotWindow1": (-14.0, -14.2, WINDOW_SEAT + 0.03, 0.0),
    "SpotWindow2": (-11.0, -14.2, WINDOW_SEAT + 0.03, 0.0),
    "SpotWindow3": (-8.0, -14.2, WINDOW_SEAT + 0.03, 0.0),
    "SpotWindow4": (-5.0, -14.2, WINDOW_SEAT + 0.03, 0.0),
    "SpotTipJar": (-2.4, -14.2, WINDOW_SEAT + 0.03, 0.0),
    "SpotSign": (13.5, ROOM_Y[0] - WALL_T, 6.0, 0.0),
    "SpotBuilder": (16.0, 3.5, 0.0, 270.0),          # on the right wall facing the room; Jo's stand took (13, 6) (#878)
    "SpotStation2": (7.0, -1.0, 0.0, 0.0),
    "SpotStation3": (13.5, -1.0, 0.0, 0.0),
    "SpotStation4": (-15.2, 1.0, 0.0, 90.0),     # a quarter turn: these two stand against the side wall and face
    "SpotStation5": (-15.2, -6.6, 0.0, 90.0),    # the room, so the cat on them faces the player (#298)
    "SpotVipDoor": (7.0, ROOM_Y[1] + WALL_T / 2, 0.0, 0.0),
    # the Garden once the Cat Hotel has the back door (#1050): the side looks' pivot (garden.SIDE_NAMES), on the wall
    # where the VIP door was; the way in is the hotel's side doorway
    "SpotGardenSide": (7.0, ROOM_Y[1] + WALL_T / 2, 0.0, 0.0),
    "SpotMascot": (10.25, -14.3, 0.0, 230.0),
    "SpotOpening": (5.0, -27.0, 0.0, 0.0),
    "SpotBox": (0.0, -30.6, 0.0, 0.0),
    "SpotBump": (7.5, -37.6, -0.28, 90.0),
    "SpotBoard": (13.5, ROOM_Y[0] + 1.4, 0.0, 180.0),
    # The workers' wash stands (#527). Grown to 5.4 wide (#878), two fill the 12 studs of back wall between the doors
    # (BACK_DOOR's end to VIP_DOOR's start) and Jo, the first hire, stands alone right of the VIP door, so each hire
    # pad reads as its own spot (Design-Agent: pad centres at least 5 studs apart).
    "SpotWorkerJo": (14.5, 6.5, 0.0, 0.0),
    "SpotWorkerSam": (-6.0, 6.5, 0.0, 0.0),
    "SpotWorkerLou": (0.0, 6.5, 0.0, 0.0),
    # The gift stand (#502): against the right wall near the front, between the towel rail and the corner plant, facing
    # across the room. Clear of the door, the queue, station 3 and the walk from the door to the stations.
    "SpotGift": (16.4, -11.8, 0.0, 270.0),
    # The Garden (#579): the middle of the back door's opening, as SpotVipDoor is the VIP door's. The three garden
    # looks (garden.py) pivot here and fill the yard behind.
    "SpotGardenDoor": ((BACK_DOOR[0] + BACK_DOOR[1]) / 2, ROOM_Y[1] + WALL_T / 2, 0.0, 0.0),
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
    span(yf, WINDOW[0], WINDOW[1], 0, WINDOW_SEAT - (0.2 if COUNTER else 0.0), pink)   # under the counter's top
    span(yf, WINDOW[0], WINDOW[1], WINDOW_TOP, h, pink)
    span(yf, WINDOW[1], ENTRANCE[0], 0, h, pink)
    span(yf, ENTRANCE[0], ENTRANCE[1], DOOR_H, h, pink)
    if DISPLAY:                                        # the bigger plot's display window, right of the entrance
        span(yf, ENTRANCE[1], DISPLAY[0], 0, h, pink)
        span(yf, DISPLAY[0], DISPLAY[1], 0, DISPLAY_SEAT, pink)
        span(yf, DISPLAY[0], DISPLAY[1], DISPLAY_TOP, h, pink)
        span(yf, DISPLAY[1], x1, 0, h, pink)
    else:
        span(yf, ENTRANCE[1], x1, 0, h, pink)
    # back: wall, back door (header), wall, VIP door (header), wall
    span(yb, x0, BACK_DOOR[0], 0, h)
    span(yb, BACK_DOOR[0], BACK_DOOR[1], DOOR_H, h)
    span(yb, BACK_DOOR[1], VIP_DOOR[0], 0, h)
    span(yb, VIP_DOOR[0], VIP_DOOR[1], DOOR_H, h)
    span(yb, VIP_DOOR[1], x1, 0, h)


def _floor(b):
    b.box_base(((PLOT_X[0] + PLOT_X[1]) / 2, (PLOT_Y[0] + PLOT_Y[1]) / 2, 0),
               (PLOT_X[1] - PLOT_X[0], PLOT_Y[1] - PLOT_Y[0], FLOOR), "paving_light", bevel=False)
    x0, x1 = ROOM_X
    y0, y1 = ROOM_Y
    b.box_base(((x0 + x1) / 2, (y0 + y1) / 2, FLOOR - 0.03), (x1 - x0 - 0.03, y1 - y0 - 0.03, 0.05), "spa_tile",
               bevel=False)                            # the shop floor, a lighter tile


def _window_seat(b):
    a, c = DISPLAY if DISPLAY else WINDOW
    seat = DISPLAY_SEAT if DISPLAY else WINDOW_SEAT
    y0 = ROOM_Y[0]
    b.box_base(((a + c) / 2, y0 + SEAT_DEPTH / 2 - 0.02, FLOOR - 0.02), (c - a - 0.04, SEAT_DEPTH, seat + 0.05),
               "spa_cream", bevel=False)


# -- the counter window of the bigger plot (#746) ------------------------------------------------------------------
COUNTER_Y = (-17.7, -13.6)        # the counter top: 0.7 out over the pavement, 2.4 into the room
COUNTER_T = 0.36                  # the top's thickness: thick enough to collide (rbx_export.MIN_COLLIDE)
PLACES = 6                        # waiting places along the counter (the line's longest, SpaRules MAX_QUEUE)
PLACE_PITCH = 3.2
PLACE_X1 = -3.4                   # place 1, nearest the entrance; the others go away from it
# The owner, 2026-11-26, after the counter: customers "walk up with the cats in their cat crate place them [on] the
# table and have the cats walk out and sit then the crate dissapear slowly". The carrier (spa_props, 2.0 long) is set
# down on the counter's outer part, its back just inside the counter's outer edge and its gate toward the room; the
# cat walks out of the gate onto its mat, which lies clear of the gate (a sitting cat at 0.8 is 0.48 behind its pivot).
CRATE_Y = -16.62                  # where a set down carrier's pivot goes: its back at -17.62, its gate at -15.62
CAT_Y = -14.9                     # where a waiting cat sits: 0.24 clear of that gate (it was -15.6, in the wall's line)
STAND_Y = -19.4                   # where its customer stands on the pavement, straight behind both
MAT = (1.9, 1.7, 0.09)            # a place's mat; its top is 0.08 over the counter


def place_x(i):
    """Blender x of counter place `i` (1 is nearest the entrance)."""
    return PLACE_X1 - PLACE_PITCH * (i - 1)


def _counter(b):
    """The counter in the open window: a cream body inside the room under a mint top that goes through the wall
    and out over the pavement, so a customer outside sets a cat down on it and the player inside takes it. All of
    it is solid."""
    a, c = WINDOW
    y0 = ROOM_Y[0]
    top = FLOOR + WINDOW_SEAT
    b.box_base(((a + c) / 2, (y0 - 0.02 + COUNTER_Y[1] - 0.3) / 2, FLOOR - 0.02),
               (c - a - 0.04, COUNTER_Y[1] - 0.3 - y0 + 0.02, WINDOW_SEAT - 0.28), "spa_cream", bevel=False)
    b.box_base(((a + c) / 2, (COUNTER_Y[0] + COUNTER_Y[1]) / 2, top - COUNTER_T),
               (c - a - 0.03, COUNTER_Y[1] - COUNTER_Y[0], COUNTER_T), "spa_mint", bevel=False)


def _counter_decor(b):
    """The counter's bubblegum front panel inside the room and a desk bell at its far end. Walk-through."""
    a, c = WINDOW
    b.box(((a + c) / 2, COUNTER_Y[1] - 0.3 + 0.0, FLOOR + 1.2), (c - a - 1.6, 0.09, 1.5), "spa_bubblegum", bevel=False)
    bx, by, bz = a + 0.75, -14.5, FLOOR + WINDOW_SEAT
    b.cyl_base((bx, by, bz - 0.01), 0.32, 0.07, "gold_dark", segments=12, bevel=False)
    b.sphere((bx, by, bz + 0.06), 0.27, "gold_mid", segments=10, rings=6, scale=(1, 1, 0.8))
    b.cyl_base((bx, by, bz + 0.24), 0.06, 0.1, "gold_light", segments=8, bevel=False)


def _counter_mat(i):
    def build(b):
        b.box_base((place_x(i), CAT_Y, FLOOR + WINDOW_SEAT - 0.01), MAT, "spa_cream", bevel=False)
    return build


def _counter_barrier(b):
    """An invisible solid block over the whole counter top, up to the ceiling (an invisible blocker stands 12 studs
    off the floor or reaches a ceiling, #741), so nobody hops onto the counter or out through the window. CanQuery
    is off (rbx_export.NO_QUERY_BARRIERS): the camera, taps and prompts pass, and the waiting cats sit inside it."""
    a, c = WINDOW
    z0 = FLOOR + WINDOW_SEAT + 0.02
    b.box_base(((a + c) / 2, (COUNTER_Y[0] + COUNTER_Y[1]) / 2 + 0.005, z0),
               (c - a - 0.06, COUNTER_Y[1] - COUNTER_Y[0] - 0.02, FLOOR + WALL_H + 0.4 - z0), "metal", bevel=False)


def _trim(b):
    """A mint frame round the display window and the entrance, on the outside of the front wall."""
    y = ROOM_Y[0] - WALL_T - 0.1
    a, c = WINDOW
    wt = WINDOW_TOP
    rails = [(a - 0.4, c + 0.4, WINDOW_SEAT - 0.4, WINDOW_SEAT), (a - 0.4, c + 0.4, wt, wt + 0.4),
             (a - 0.4, a, WINDOW_SEAT - 0.39, wt + 0.39), (c, c + 0.4, WINDOW_SEAT - 0.39, wt + 0.39),
             (ENTRANCE[0] - 0.4, ENTRANCE[1] + 0.4, DOOR_H, DOOR_H + 0.4),
             (ENTRANCE[0] - 0.4, ENTRANCE[0], 0.0, DOOR_H - 0.01), (ENTRANCE[1], ENTRANCE[1] + 0.4, 0.0, DOOR_H - 0.01)]
    if COUNTER:                                        # the counter's top is the sill: no rail under the opening,
        rails[0] = (a - 0.4, c + 0.4, WINDOW_SEAT - 0.8, WINDOW_SEAT - 0.4)   # one under the top's outer edge
        rails[2] = (a - 0.4, a, WINDOW_SEAT - 0.79, wt + 0.39)
        rails[3] = (c, c + 0.4, WINDOW_SEAT - 0.79, wt + 0.39)
    if DISPLAY:
        d0, d1 = DISPLAY
        rails += [(d0 - 0.4, d1 + 0.4, DISPLAY_SEAT - 0.4, DISPLAY_SEAT), (d0 - 0.4, d1 + 0.4, DISPLAY_TOP, DISPLAY_TOP + 0.4),
                  (d0 - 0.4, d0, DISPLAY_SEAT - 0.39, DISPLAY_TOP + 0.39), (d1, d1 + 0.4, DISPLAY_SEAT - 0.39, DISPLAY_TOP + 0.39)]
    for x0, x1, z0, z1 in rails:
        side = (z1 - z0) > 1.0                         # the uprights sit a hair proud of the rails: no shared face
        if side:
            x0, x1 = x0 + 0.01, x1 - 0.01
        b.box_base(((x0 + x1) / 2, y - (0.01 if side else 0.0), FLOOR + z0), (x1 - x0, 0.22, z1 - z0), "spa_mint",
                   bevel=False)


def _glass(b):
    a, c = DISPLAY if DISPLAY else WINDOW              # the counter window has none
    seat, top = (DISPLAY_SEAT, DISPLAY_TOP) if DISPLAY else (WINDOW_SEAT, WINDOW_TOP)
    b.box_base(((a + c) / 2, ROOM_Y[0] - WALL_T / 2, FLOOR + seat - 0.02), (c - a - 0.02, 0.3, top - seat + 0.04),
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
    n = 2 * round((x1 - x0 + 2 * WALL_T) / 6.3)        # stripes about 3.2 wide: 12 on the small plot
    w = (x1 - x0 + 2 * WALL_T) / n
    for i in range(n):
        x = x0 - WALL_T + w * (i + 0.5)
        rot = Matrix.Rotation(math.radians(18), 3, "X")          # the outer edge lower
        b.box((x, y - 1.6, FLOOR + 10.6), (w + 0.01 * (i % 2), 3.4, 0.25 + 0.08 * (i % 2)),
              "spa_mint" if i % 2 else "offwhite", bevel=False, rot=rot)


def _yard(b):
    """Grass in the back yard, from just behind the back wall to the plot's back edge, inside the side alleys."""
    y0 = ROOM_Y[1] + WALL_T + 0.02
    y1 = PLOT_Y[1] - 0.1
    b.box_base(((PLOT_X[0] + PLOT_X[1]) / 2, (y0 + y1) / 2, FLOOR - 0.03), (PLOT_X[1] - PLOT_X[0] - 0.2, y1 - y0, 0.07),
               "leaf_green", bevel=False)


def _bands(b):
    """A bubblegum band round the outside of the cream side and back walls, a mint band on the inside of all three
    with a white cap rail. The inside bands' backs and ends are inside the walls (#670, see `_wall_art`)."""
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
        b.box_base((x - sx * 0.08, (y0 + y1) / 2, z + 0.007), (0.2, y1 - y0 + 0.06, 2.5), "spa_mint", bevel=False)
    for a, c in ((x0 + 0.2, BACK_DOOR[0]), (BACK_DOOR[1], VIP_DOOR[0]), (VIP_DOOR[1], x1 - 0.2)):
        b.box_base(((a + c) / 2, y1 - 0.08, z + 0.012), (c - a, 0.2, 2.5), "spa_mint", bevel=False)
    # #214: a white cap rail along the top of the mint band, a little proud of it
    for sx, x in ((-1, x0), (1, x1)):
        b.box_base((x - sx * 0.12, (y0 + y1) / 2, FLOOR + 2.44), (0.3, y1 - y0 + 0.07, 0.26), "offwhite", bevel=False)
    for a, c in ((x0 + 0.28, BACK_DOOR[0] - 0.01), (BACK_DOOR[1] + 0.01, VIP_DOOR[0] - 0.01),
                 (VIP_DOOR[1] + 0.01, x1 - 0.28)):     # a hair short of each door edge, where the band ends
        b.box_base(((a + c) / 2, y1 - 0.12, FLOOR + 2.445), (c - a, 0.3, 0.26), "offwhite", bevel=False)


TILE = "tile_sky"                 # the check's second colour (#214): paler than the tub's sky blue


def _tiles(b):
    """Checked floor (#214): 4 by 4.33 stud tiles in a colour that shows from the play camera, and a bubblegum border
    round the room. The tiles stand 0.02 over the shop floor and the border 0.02 over the tiles."""
    x0, x1 = ROOM_X
    y0, y1 = ROOM_Y
    nx, ny = round((x1 - x0) / 4.0), round((y1 - y0) / 4.4)      # 9 by 6 on the small plot
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


SINK = 0.03                       # how far the back of anything on an inside wall reaches into the wall (#670)


def _wall_box(b, wall, along, z, size, front, swatch, k=0, **kw):
    """A box on an inside wall ("back", "left" or "right"): `size` is (width along the wall, height), its face
    stands `front` studs off the wall and its back is SINK inside the wall, a hair deeper for each `k`, so no two
    backs that overlap share a plane. Nothing on a wall has a back face in the room (#670)."""
    s = SINK + 0.004 * k
    w, h = size
    if wall == "back":
        return b.box((along, ROOM_Y[1] + (s - front) / 2, z), (w, front + s, h), swatch, **kw)
    sx = -1 if wall == "left" else 1
    x = (ROOM_X[0] if wall == "left" else ROOM_X[1]) + sx * (s - front) / 2
    return b.box((x, along, z), (front + s, w, h), swatch, **kw)


def _wall_disc(b, x, z, radius, front, swatch, k=0, segments=20):
    """A disc flat on the back wall, its back sunk like `_wall_box`."""
    s = SINK + 0.004 * k
    b.cyl((x, ROOM_Y[1] + (s - front) / 2, z), radius, front + s, swatch, segments=segments, bevel=False,
          rot=Matrix.Rotation(math.pi / 2, 3, "X"))


PLATE = 0.2                       # how far the solid face of every wall piece stands off the wall
RELIEF = 0.045                    # the most a walk-through detail stands over that face
SHELF_MIN = 8.2                   # the lowest a walk-through shelf hangs over the floor: over a resting camera


def _wall_art(b):
    """The solid back plate of everything that hangs flat on a wall inside: the mirror's frame, the tool board, the
    three picture frames, the poster, the clock, the strays sign and the towels on their rail. Its own object,
    `_WallArt` (#670).

    Roblox's camera stops only at parts a player collides with, and it stops with its near plane on the part's
    face: the eye itself rests about 0.1 studs behind that face, inside the wall or the plate, and draws every
    face turned to it from 0.1 studs on. While the wall pieces were walk-through decor, a camera pushed back to
    the wall looked at the back of the mirror's pale glass and the whole screen went light blue. With solid plates
    it stopped on the plate, and then drew the backs of the tools and glints that stood in front of the plate: a
    grey haze. Rules for anything new on a wall:
    (1) the piece's big flat faces are solid and the front one stands PLATE (0.2 studs) off the wall: the frame
        and, a hair in front of it, the glass, card or board face. So the camera stops on the piece's own face, a
        character pressed to it still reaches the wall and Roblox never reads it as a ladder rung;
    (2) the small things on that face stay in `_wall_decor`, walk-through, and stand at most RELIEF over it, so
        their edges are too low to fill the view of a camera resting beside them;
    (3) every part of the piece, plate and details alike, has its back SINK inside the wall (`_wall_box`), and a
        round detail has its middle behind the plate's face, so nothing has a back for the camera to look at.
    A shelf is too deep for a plate and stays walk-through (solid, players would stand on it): its board and what
    stands on it reach into the wall the same way (3), and it hangs SHELF_MIN or more over the floor. A camera
    behind a player who backs into a wall rests between head height and about 7 studs up, and a shelf's ends and
    underside would fill its view from there."""
    F = FLOOR
    rim = PLATE - 0.02                                             # a frame, just behind the face it frames
    _wall_disc(b, 0.0, F + 6.3, 1.75, rim, "gold_mid")                                           # the mirror's frame
    _wall_disc(b, 0.0, F + 6.3, 1.48, PLATE, "pastel_sky", k=1)    # and its pale glass (never see-through: #176)
    _wall_box(b, "back", 14.5, F + 5.9, (5.0, 3.0), rim, "wood_light", bevel=False)              # the tool board
    _wall_box(b, "back", 14.5, F + 5.9, (4.6, 2.6), PLATE, "spa_cream", k=1, bevel=False)        # and its cream face
    for k, (y, sw) in enumerate(zip(FRAMES_Y, FRAME_CARDS)):                                     # three frames
        y += FRAME_SHIFT
        z = F + 6.9 + (0.25 if k == 1 else 0.0)
        _wall_box(b, "left", y, z, (2.2, 2.6), rim, "wood_light", bevel=False)
        _wall_box(b, "left", y, z, (1.8, 2.2), PLATE, sw, k=1, bevel=False)                      # and their cards
    _wall_box(b, "right", 2.0, F + 7.0, (4.0, 3.0), rim, "spa_sky", bevel=False)                 # the paw poster
    _wall_box(b, "right", 2.0, F + 7.0, (3.4, 2.4), PLATE, "offwhite", k=1, bevel=False)         # and its white card
    _wall_disc(b, 14.5, F + 9.5, 1.2, PLATE, "spa_mint", segments=16)                            # the clock
    bx = (BACK_DOOR[0] + BACK_DOOR[1]) / 2
    _wall_box(b, "back", bx, F + DOOR_H + 1.3, (3.6, 1.4), PLATE, "cardboard", bevel=False)      # the strays sign
    # a rail of three towels on the right wall, between the chance board and the stations: the towels are their
    # own plates and hang over the rail
    _wall_box(b, "right", TOWELS_Y, F + 6.6, (5.2, 0.24), PLATE - 0.04, "wood_light", bevel=False)
    for y, sw in ((TOWELS_Y - 1.7, "spa_bubblegum"), (TOWELS_Y, "spa_sky"), (TOWELS_Y + 1.7, "spa_mint")):
        _wall_box(b, "right", y, F + 5.45, (1.55, 2.3), PLATE, sw, k=1)   # 0.15 apart: no room for a camera between


FRAMES_Y = (2.4, 5.2, 8.0)        # the three framed cats on the left wall
FRAME_CARDS = ("spa_sky", "spa_bubblegum", "pastel_butter")


def _jar(b, wall, along, z, w, h, swatch, k):
    """A square jar with a cream lid, pushed to the wall at the back of a shelf: its back is in the wall too."""
    _wall_box(b, wall, along, z + h / 2, (w, h), w + 0.02, swatch, k=k)
    _wall_box(b, wall, along, z + h + 0.06, (w + 0.08, 0.12), w + 0.06, "spa_cream", k=k + 1, bevel=False)


def _wall_decor(b):
    """#214: things to look at on the walls, none of them near the floor or behind the cat in the tub as the play
    camera sees it. Back wall: a round mirror under a shelf (right of the tub), a tool board under the clock and
    the strays sign over the back door. Left wall: three framed cats over the stray box. Right wall: a paw poster
    (and the towels, which are solid). Each piece's solid faces are in `_wall_art`; this is the low relief on
    them, every part of it with its back inside the wall (the rules are in `_wall_art`)."""
    F = FLOOR
    x0, x1 = ROOM_X
    y1 = ROOM_Y[1]
    low, mid, top = PLATE + 0.015, PLATE + 0.03, PLATE + RELIEF
    # the mirror's two glints
    mx, mz = 0.0, F + 6.3
    tilt = Matrix.Rotation(math.radians(35), 3, "Y")
    _wall_box(b, "back", mx - 0.45, mz + 0.3, (0.2, 1.3), low, "foam", k=2, bevel=False, rot=tilt)
    _wall_box(b, "back", mx - 0.05, mz - 0.15, (0.12, 0.8), low + 0.004, "foam", k=3, bevel=False, rot=tilt)
    # a shelf over the mirror with two jars and a folded towel. A shelf is deep and walk-through, so it hangs
    # above SHELF_MIN, over the heights a camera rests at when a player backs into the wall
    sz = F + SHELF_MIN + 0.09
    _wall_box(b, "back", mx, sz, (3.2, 0.18), 0.82, "wood_light", k=4, bevel=False)
    _jar(b, "back", mx - 1.0, sz + 0.09, 0.46, 0.62, "spa_bubblegum", 5)
    _jar(b, "back", mx - 0.4, sz + 0.09, 0.38, 0.44, "spa_mint", 7)
    _wall_box(b, "back", mx + 0.8, sz + 0.3, (1.0, 0.42), 0.76, "offwhite", k=9)                   # a folded towel
    # the three tools hung on the tool board
    tx, tz = 14.5, F + 5.9
    _wall_box(b, "back", tx - 1.5, tz + 0.2, (1.0, 0.56), top, "spa_bubblegum", k=2, bevel=False)   # a brush
    _wall_box(b, "back", tx - 1.5, tz - 0.36, (0.9, 0.5), mid, "offwhite", k=3, bevel=False)
    _wall_box(b, "back", tx, tz + 0.3, (0.4, 1.5), top, "spa_sky", k=4, bevel=False)                # a comb
    _wall_box(b, "back", tx + 0.42, tz + 0.0, (0.5, 0.9), mid, "offwhite", k=5, bevel=False)
    _wall_box(b, "back", tx + 1.5, tz, (1.1, 0.8), mid, "pastel_butter", k=6, bevel=False)          # a sponge
    _wall_box(b, "back", tx + 1.5, tz + 0.5, (1.14, 0.24), top, "spa_mint", k=7, bevel=False)
    # the clock's hands, on its mint face
    cx, cz = 14.5, F + 9.5
    _wall_box(b, "back", cx, cz + 0.25, (0.12, 0.6), low, "fur_charcoal", k=1, bevel=False)
    _wall_box(b, "back", cx + 0.2, cz + 0.01, (0.5, 0.1), mid, "fur_charcoal", k=2, bevel=False)    # not in line with the other hand's end
    # the three framed cats on the left wall, over the stray box: a cat's face on each frame's card. A face is a
    # flat lens whose middle is just behind the card's face
    turn = Matrix.Rotation(math.radians(45), 3, "X")
    lens = PLATE - 0.01
    for k, (y, coat) in enumerate(zip(FRAMES_Y, ("fur_orange", "fur_charcoal", "fur_grey"))):
        y += FRAME_SHIFT
        z = F + 6.9 + (0.25 if k == 1 else 0.0)
        b.sphere((x0 + lens, y, z - 0.25), 0.62, coat, segments=8, rings=5, scale=((top - lens) / 0.62, 1, 0.9))
        for j, sy in enumerate((-1, 1)):
            _wall_box(b, "left", y + sy * 0.36, z + 0.22, (0.36, 0.36), mid, coat, k=2 + j, bevel=False, rot=turn)
    # the paw poster's paw, pads as flat lenses the same way
    b.sphere((x1 - lens, 2.0, F + 6.7), 0.55, "spa_bubblegum", segments=8, rings=4,
             scale=((top - lens) / 0.55, 1, 0.85))
    for dy, dz in ((-0.65, 0.65), (-0.22, 0.95), (0.22, 0.95), (0.65, 0.65)):
        b.sphere((x1 - lens, 2.0 + dy, F + 6.7 + dz), 0.22, "spa_bubblegum", segments=6, rings=4,
                 scale=((mid - lens) / 0.22, 1, 1))
    # the strays sign's paw, the same way
    bx = (BACK_DOOR[0] + BACK_DOOR[1]) / 2
    b.sphere((bx, y1 - lens, F + DOOR_H + 1.2), 0.38, "spa_cream", segments=8, rings=4,
             scale=(1, (top - lens) / 0.38, 0.85))
    for dx, dz in ((-0.45, 0.42), (0.0, 0.58), (0.45, 0.42)):
        b.sphere((bx + dx, y1 - lens, F + DOOR_H + 1.2 + dz), 0.15, "spa_cream", segments=6, rings=4,
                 scale=(1, (mid - lens) / 0.15, 1))


def _decor(b):
    """Inside: the tub rug, a towel shelf, two plants, three pendant lamps and the wall decor of #214. Outside:
    the flower box under the window, two pots at the entrance, two lamp posts and the yard fence. None of it
    collides. The wall pieces' back plates are `_wall_art`, which does (#670)."""
    F = FLOOR
    x0, x1 = ROOM_X
    y0, y1 = ROOM_Y
    tx, ty, _, _ = SPOTS["SpotTub"]
    b.cyl_base((tx, ty - 0.6, F + 0.03), 3.4, 0.035, "spa_bubblegum", segments=16, bevel=False, scale=(1.3, 1, 1))
    # a towel shelf on the left wall, between the window seat and the stray box
    # (#670: the boards, the towels and the jars all reach into the wall and hang above SHELF_MIN, see `_wall_art`)
    for z in (SHELF_MIN + 0.1, SHELF_MIN + 2.1):
        _wall_box(b, "left", -4.0, F + z, (6.0, 0.2), 1.3, "wood_light", bevel=False)
        for k, (yy, sw) in enumerate(((-6.0, "spa_sky"), (-4.9, "spa_bubblegum"), (-3.8, "spa_mint"))):
            if z > SHELF_MIN + 1 and k == 2:
                continue
            hh = 0.5 + 0.12 * (k % 2)
            _wall_box(b, "left", yy, F + z + 0.1 + hh / 2, (0.9, hh), 1.15, sw, k=1)
        if z > SHELF_MIN + 1:
            for k, yy in enumerate((-2.6, -1.9)):
                _jar(b, "left", yy, F + z + 0.1, 0.44, 0.62 - 0.1 * k, "spa_sky" if k else "spa_bubblegum", 2)
    _wall_decor(b)
    # Plants in two corners: the back right one, and a smaller one in the front right corner beside the chance board.
    # The front one stood by the left wall in front of the window seat until the Studio playtest (#298): there it
    # filled the follow camera on the walk back from the Bubble Bath.
    plants = [(x1 - 1.4, y1 - 1.4, 1.0), (x1 - 1.25, ROOM_Y[0] + 1.25, 0.85)]
    if DISPLAY:                                        # the display window's seat fills the front right corner
        plants.pop()
    for x, y, k in plants:
        b.cyl_base((x, y, F - 0.006), 0.7 * k, 1.4 * k, "terracotta", segments=10, bevel=False, radius2=0.85 * k)
        b.sphere((x, y, F + 2.2 * k), 1.1 * k, "leaf_green", segments=8, rings=6)
        b.sphere((x + 0.3 * k, y - 0.2 * k, F + 3.0 * k), 0.7 * k, "leaf_dark", segments=8, rings=5)
    # pendant lamp cords and shades (the bulbs glow, in _glow)
    for x, y in LAMPS:
        b.cyl((x, y, F + WALL_H - 1.0), 0.05, 2.0, "fur_charcoal", segments=6, bevel=False)
        b.cyl_base((x, y, F + WALL_H - 2.6), 0.9, 0.6, "spa_mint", segments=12, bevel=False, radius2=0.35)
    # outside: the flower box under the window, pots by the entrance, lamp posts on the apron
    yo = y0 - WALL_T
    a, c = DISPLAY if DISPLAY else WINDOW              # the flower box: under the glazed window, never where
    if not COUNTER or DISPLAY:                         # customers stand at the counter
        b.box_base(((a + c) / 2, yo - 0.7, F - 0.01), (c - a - 1.0, 1.2, 1.3), "wood_light", bevel=False)
    # the pots: one each side of the entrance; with a counter the left one stands past the counter's far end
    for x in ((WINDOW[0] - 1.7) if COUNTER else (ENTRANCE[0] - 1.4), ENTRANCE[1] + 1.4):
        b.cyl_base((x, yo - 1.2, F - 0.01), 0.75, 1.5, "terracotta", segments=10, bevel=False, radius2=0.9)
        b.sphere((x, yo - 1.2, F + 2.3), 1.15, "leaf_green", segments=8, rings=6)
    for x in (PLOT_X[0] + 1.6, PLOT_X[1] - 1.6):
        b.cyl_base((x, PLOT_Y[0] + 1.6, F - 0.01), 0.22, 7.0, "fur_charcoal", segments=8, bevel=False)
        b.box((x, PLOT_Y[0] + 1.6, F + 7.1), (0.9, 0.9, 0.25), "fur_charcoal", bevel=False)
    # a low white fence round the yard: posts and two rails, inside the plot edge so neighbours never overlap
    fy0, fy1 = y1 + WALL_T + 0.6, PLOT_Y[1] - 0.5
    fx = PLOT_X[1] - 0.5
    for x in (-fx, fx):
        for k in range(4):
            y = fy0 + (fy1 - fy0) * k / 3
            b.box_base((x, y, F - 0.01), (0.3, 0.3, 2.4), "offwhite", bevel=False)
        for z in (0.9, 1.9):
            b.box((x, (fy0 + fy1) / 2, F + z), (0.12, fy1 - fy0, 0.22), "offwhite", bevel=False)
    posts = round(2 * fx / 5.4)                        # 8 gaps on the small plot
    for k in range(1, posts):
        x = -fx + 2 * fx * k / posts
        b.box_base((x, fy1, F - 0.01), (0.3, 0.3, 2.4), "offwhite", bevel=False)
    for z in (0.92, 1.92):
        b.box((0, fy1, F + z), (2 * fx - 0.02, 0.12, 0.22), "offwhite", bevel=False)


LAMPS = ((-5.0, -2.0), (10.0, -1.0), (-10.0, 4.0))   # pendant lamps over the tub, the stations and the stray side


def _glow(b):
    """The warm bulbs: under the pendant shades and on the lamp posts (Neon)."""
    F = FLOOR
    for x, y in LAMPS:
        b.sphere((x, y, F + WALL_H - 2.65), 0.32, "lamp_warm", segments=8, rings=5)
    for x in (PLOT_X[0] + 1.6, PLOT_X[1] - 1.6):
        b.box((x, PLOT_Y[0] + 1.6, F + 7.6), (0.6, 0.6, 0.75), "lamp_warm", bevel=False)


def _flowers(b):
    """Flowers in the window box."""
    if COUNTER and not DISPLAY:
        return
    a, c = DISPLAY if DISPLAY else WINDOW
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
    name = NAME
    parts = [("", lambda b: (_floor(b), _yard(b))), ("_Wall", _walls), ("_WindowSeat", _window_seat),
             ("_Glass", _glass), ("_Roof", _roof), ("_Canopy", _canopy), ("_Trim", _trim), ("_Bands", _bands),
             ("_Tiles", _tiles), ("_Decor", _decor), ("_WallArt", _wall_art), ("_Glow", _glow), ("_Flowers", _flowers)]
    if COUNTER:
        parts += [("_Counter", _counter), ("_Counter_Decor", _counter_decor), ("_Counter_Barrier", _counter_barrier)]
        parts += [("_CounterMat%d" % i, _counter_mat(i)) for i in range(1, PLACES + 1)]
    objs = []
    for suffix, fn in parts:
        b = Builder()
        fn(b)
        ob = _tris(b.finalize(name + suffix, mat, bevel=0))
        ob.hide_render = suffix.endswith("_Barrier")
        objs.append(ob)
    return objs


def plot_rbx_extras():
    atts = []
    for spot, (x, y, z, turn) in SPOTS.items():
        M = Matrix.Translation((x, y, FLOOR + z)) @ Matrix.Rotation(math.radians(turn), 4, "Z")
        atts.append((NAME, spot, M))
    return {"attachments": atts, "attributes": {"FloorHeight": {"Float64": FLOOR}}}


# -- the bigger plot (#746) ----------------------------------------------------------------------------------------
# The owner, 2026-11-26: make the base spa building bigger, and give customers "an open window from desk where they
# put their cats on the table while waiting so grabbing them is easy". CleanACat_Area_SpaPlotBig is that plot, a
# second model beside the small one so the game's switch (bigSpa) picks which stands on the street:
#
#   the room   48 by 32 studs inside (36 by 26), walls 12 tall as before. The plot is 56 wide and 54 deep: the front
#              edge stays 24 in front of the pivot, the back edge is 30 behind it, and the pivot is still the middle
#              of the front edge's length. Plots stand 56 apart (street.py's StreetBig).
#   unchanged  the front wall's line, the entrance and everything in front of the building: the queue mats, the
#              opening scene's spots, the spawn, the first tub and stations 2 and 3 keep their numbers.
#   moved      what stands on the back wall is 6 further back, what stands on a side wall 6 further out.
#   the counter  the display window left of the entrance (Roblox: on the tub's side, right behind the spawn) is an
#              open window with a counter through the wall, PLACES places PLACE_PITCH apart, place 1 nearest the
#              entrance. SpotCounterCat<i> is on the counter top (the cat faces the player inside), SpotCounter<i>
#              on the pavement straight behind it (the customer faces in). SpotCounterCrate<i> is on the counter
#              top between them, where a customer sets their carrier down with its gate toward the room, so the
#              cat walks out of it onto its mat. Each place has a mat, its own part
#              `_CounterMat<i>`, so the game can tint it to match its customer. `_Counter_Barrier` keeps players
#              off the counter and from hopping out through the window.
#   the display window  the residents' cushions (SpotWindow1 to 4) move to a new, lower glazed window right of the
#              entrance, with the spa's sign on the wall over it. The chance board and the gift stand move along
#              the right wall to make room for its seat; the tip jar stands on the counter's entrance end.
BIG_NAME = "CleanACat_Area_SpaPlotBig"
BIG_ROOM_X, BIG_ROOM_Y = (-24.0, 24.0), (-16.0, 16.0)
BIG_WINDOW = (-21.6, -0.8)
BIG_DISPLAY = (12.4, 23.0)
BIG_SEAT = 2.8                    # the counter top above the floor


def _big_spots():
    s = dict(SPOTS)
    grow_x, grow_y = BIG_ROOM_X[1] - ROOM_X[1], BIG_ROOM_Y[1] - ROOM_Y[1]

    def move(name, dx=0.0, dy=0.0):
        x, y, z, turn = s[name]
        s[name] = (x + dx, y + dy, z, turn)

    for name in ("SpotVipDoor", "SpotGardenSide", "SpotGardenDoor", "SpotWorkerJo", "SpotWorkerSam", "SpotWorkerLou", "SpotBuilder"):
        move(name, dy=grow_y)
    move("SpotStray", -grow_x, grow_y)
    move("SpotStation4", -grow_x)
    move("SpotStation5", -grow_x)
    # along the right wall, both facing across the room: the gift stand clear of the display seat, the chance board
    # behind it (it stood by the entrance, where the seat is now)
    s["SpotWorkerJo"] = (17.5, BIG_ROOM_Y[1] - 3.5, 0.0, 0.0)            # right of the VIP door (#878)
    s["SpotBuilder"] = (BIG_ROOM_X[1] - 1.5, 5.0, 0.0, 270.0)            # on the right wall, clear of Jo's stand
    s["SpotGift"] = (BIG_ROOM_X[1] - 1.6, -9.5, 0.0, 270.0)
    s["SpotBoard"] = (BIG_ROOM_X[1] - 0.9, -3.5, 0.0, 270.0)
    d0, d1 = BIG_DISPLAY
    s["SpotSign"] = ((d0 + d1) / 2, ROOM_Y[0] - WALL_T, 8.2, 0.0)     # on the wall over the display window
    for i in range(4):                                # the cushions, 1 furthest from the entrance as before
        s["SpotWindow%d" % (i + 1)] = (d1 - 1.3 - 2.6 * i, -14.2, DISPLAY_SEAT + 0.03, 0.0)
    s["SpotTipJar"] = (-1.5, -15.0, BIG_SEAT, 0.0)                    # the counter's entrance end
    for i in range(1, PLACES + 1):
        s["SpotCounter%d" % i] = (place_x(i), STAND_Y, 0.0, 180.0)
        s["SpotCounterCat%d" % i] = (place_x(i), CAT_Y, BIG_SEAT + MAT[2] - 0.01, 180.0)
        s["SpotCounterCrate%d" % i] = (place_x(i), CRATE_Y, BIG_SEAT, 180.0)
    return s


BIG = {
    "NAME": BIG_NAME, "ROOM_X": BIG_ROOM_X, "ROOM_Y": BIG_ROOM_Y, "PLOT_X": (-28.0, 28.0), "PLOT_Y": (-24.0, 30.0),
    "WINDOW": BIG_WINDOW, "WINDOW_SEAT": BIG_SEAT, "WINDOW_TOP": 9.0, "COUNTER": True, "DISPLAY": BIG_DISPLAY,
    "TOWELS_Y": 8.0, "FRAME_SHIFT": 6.0, "SPOTS": _big_spots(),
    # pendant lamps: the tub, the stations, the counter's far end and two over the deeper back of the room
    "LAMPS": ((-5.0, -2.0), (10.0, -1.0), (-15.0, -8.0), (-14.0, 9.0), (15.0, 9.0)),
}


class big_layout:
    """`with big_layout():` builds with the bigger plot's numbers: every builder above reads the module's names
    when it runs, so swapping them for the length of a build is the whole change. Other modules that imported the
    small plot's numbers keep them."""

    def __enter__(self):
        self.old = {k: globals()[k] for k in BIG}
        globals().update(BIG)

    def __exit__(self, *exc):
        globals().update(self.old)


def build_plot_big(mat):
    with big_layout():
        return build_plot(mat)


def plot_big_rbx_extras():
    with big_layout():
        return plot_rbx_extras()


ASSETS = {"CleanACat_Area_SpaPlot": (build_plot, 25000), BIG_NAME: (build_plot_big, 25000)}
EXTRAS = {"CleanACat_Area_SpaPlot": plot_rbx_extras, BIG_NAME: plot_big_rbx_extras}
