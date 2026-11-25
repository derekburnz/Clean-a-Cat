"""The spa's two walk-up boards (issue #424): `CleanACat_Prop_ToolsBoard` and `CleanACat_Prop_BuildBoard`.

Until now both stood in the spa as plain slabs made in code (`PH_ToolsBoard`, brown, and `PH_BuildBoard`, blue, each
4 x 5 x 0.4 studs). These keep the slab's footprint, so they stand where the slabs stand: 4 studs wide between the
posts, 5.2 high (#461: the title faces grew from 0.36 to 0.56 so a title reads on a phone), the pivot on the floor at the middle, the front at -Z in Roblox (-Y here). No writing is baked in; the
words come from the UI. Like every `Prop_` they are walk-through unless the game sets CanCollide.

  CleanACat_Prop_ToolsBoard   a cream peg board in a mint frame on two wooden posts with a bubblegum header and three
                              wooden shelves. Children, each its own Model so code can hide one that is switched
                              off or already bought:
      ..._Display_BubbleSoap  top shelf: a bubblegum soap bottle with a mint pump and a butter sponge under a pile
                              of foam (the look of CleanACat_Tool_SpongeBubble, which the tool gives)
      ..._Display_ProBrush    second shelf: the fluffy brush stood on its head, tufts out (CleanACat_Tool_BrushFluffy),
                              beside a little pile of brushed out fluff
      ..._Decor               third shelf: a stack of folded towels, there until a third tool takes the shelf
      ..._Screen              the header's cream face, part name `Screen`, for a title
                              Attachments `Row1` to `Row3` at the front of each shelf, top to bottom
  CleanACat_Prop_BuildBoard   a builder's plan board in the builder kitten's colours (hard hat butter, toolbox
                              sky, hammer bubblegum): a sky sheet in a butter frame with dashed tape along the top
                              and bottom rails, five cream row cards with a colour chip each, a wooden title plank,
                              a hard hat hung on the left post and a gold bell on an arm off the right post
      ..._Bell                the bell, its pivot where it hangs, so it can be swung
      ..._Screen              the title plank's cream face, part name `Screen`
                              Attachments `Row1` to `Row5` at the front of each card, top to bottom, and `Bell`
"""

import math

from mathutils import Matrix, Vector

import rbx_export
from common import Builder
from stations import _tris

TOOLS = "CleanACat_Prop_ToolsBoard"
BUILD = "CleanACat_Prop_BuildBoard"

W, H = 4.0, 5.0                       # the slab both boards replace: wide (outer faces of the posts), high
POST = 0.24                           # a post's side
POST_X = W / 2 - POST / 2             # a post's middle
POST_Y = 0.06                         # the posts sit a little behind the middle, so the face is the front
FACE_Y = -0.07                        # the front of a board's face
ROW_Y = -0.62                         # where a row's prompt goes: just in front of the shelves

SHELVES = (3.35, 2.25, 1.2)           # the Tools board: each shelf's top
SHELF_D = 0.5
TOOL_ROWS = tuple(z + 0.45 for z in SHELVES)

CARD_Z = (4.08, 3.5, 2.92, 2.34, 1.76)                   # the builder board: each row card's middle
CARD_H = 0.46
CHIPS = ("spa_bubblegum", "spa_mint", "pastel_lilac", "fur_apricot", "fur_golden")   # one per row, the last the big build
BELL_AT = (W / 2 + 0.3, POST_Y, 4.3)  # where the bell hangs, off the right post
BELL_R = 0.2
HAT = 0.4                             # the hard hat's radius at the rim

# A board streams in whole, so its Screen, rows and displays are there whenever it is (as the chance board does).
for _suffix in ("_ToolsBoard", "_BuildBoard"):
    rbx_export.MODEL_PROPS[_suffix] = {"ModelStreamingMode": "Atomic"}


def _stand(b, top):
    """Two wooden posts with feet, the posts' outer faces W apart."""
    for sx in (1, -1):
        b.box_base((sx * POST_X, POST_Y, 0.02), (POST, POST, top - 0.02), "wood_light")
        b.box_base((sx * POST_X, 0.0, 0.0), (0.42, 1.1, 0.12), "wood_light", bevel=False)


SCREEN_H = 0.56     # a title face's height: at 0.36 the title was about 14 px on a phone, and the UI rule is 18 or more


def _screen(name, mat, z, w, h, y):
    s = Builder()
    s.box_base((0, y, z), (w, 0.06, h), "offwhite", bevel=False)
    return s.finalize(name + "_Screen", mat, bevel=0)


def build_tools_board(mat):
    b = Builder()
    _stand(b, 4.6)
    b.box_base((0, 0.07, 0.95), (W - 0.3, 0.18, 3.7), "spa_mint")                          # the frame
    b.box_base((0, -0.02, 1.08), (W - 0.7, 0.1, 3.44), "spa_cream", bevel=False)           # the peg board
    for row in range(3):                                # peg holes in the gaps over each shelf, off the displays
        for i in range(5):
            b.box((-1.3 + 0.65 * i, FACE_Y - 0.005, SHELVES[row] + 0.92), (0.07, 0.03, 0.07), "wood_light", bevel=False)
    for z in SHELVES:
        b.box((0, -0.05 - SHELF_D / 2, z - 0.05), (W - 0.9, SHELF_D, 0.1), "wood_light")   # its back sunk in the board
        for sx in (1, -1):                              # a mint bracket under each end
            b.box((sx * 1.2, -0.2, z - 0.2), (0.1, 0.3, 0.22), "spa_mint", bevel=False)
    b.box_base((0, 0.02, 4.45), (2.6, 0.26, 0.72), "spa_bubblegum")                        # the header
    main = _tris(b.finalize(TOOLS, mat))

    y = -0.05 - SHELF_D / 2                             # the middle of a shelf, front to back
    s = Builder()                                       # Bubble Soap: the bottle, and what it does to a sponge
    z = SHELVES[0]
    s.cyl_base((-0.75, y, z), 0.23, 0.46, "spa_bubblegum", segments=10, bevel=False)
    s.cyl_base((-0.75, y, z + 0.45), 0.23, 0.12, "spa_bubblegum", segments=10, bevel=False, radius2=0.09)
    s.cyl_base((-0.75, y, z + 0.56), 0.07, 0.16, "spa_mint", segments=8, bevel=False)      # the pump's stem
    s.box((-0.75, y - 0.08, z + 0.74), (0.12, 0.32, 0.07), "spa_mint", bevel=False)        # its spout, to the front
    s.box((-0.75, y - 0.225, z + 0.24), (0.24, 0.03, 0.2), "spa_cream", bevel=False)       # a blank label
    s.box_base((0.45, y, z), (0.8, 0.42, 0.22), "pastel_butter")                           # the sponge
    s.box_base((0.45, y, z + 0.18), (0.84, 0.46, 0.1), "spa_mint", bevel=False)            # its scrub top
    for bx, by, bz, r in ((0.25, 0.0, 0.36, 0.16), (0.55, -0.04, 0.34, 0.14), (0.75, 0.05, 0.3, 0.1),
                          (0.42, 0.04, 0.5, 0.12), (-0.38, -0.1, 0.1, 0.1), (-0.5, -0.02, 0.24, 0.07)):
        s.sphere((bx, y + by, z + bz), r, "foam", segments=8, rings=5)                     # foam piled on it, two by the bottle
    soap = _tris(s.finalize(TOOLS + "_Display_BubbleSoap", mat))

    s = Builder()                                       # the Pro Brush: the fluffy brush stood on its head, tufts out
    z = SHELVES[1]
    s.box_base((-0.5, y, z), (0.56, 0.2, 0.5), "pastel_lilac")                             # the head, its back to the board
    s.box_base((-0.5, y, z + 0.47), (0.16, 0.12, 0.42), "spa_mint", bevel=False)           # the handle, up
    for ix in range(2):
        for iz in range(3):                             # six round tufts facing the player, in a check
            s.sphere((-0.5 + (ix - 0.5) * 0.26, y - 0.13, z + 0.1 + iz * 0.15), 1.0,
                     "foam" if (ix + iz) % 2 else "spa_bubblegum", segments=8, rings=4, scale=(0.13, 0.12, 0.09))
    for fx, fy, fz, r in ((0.45, 0.0, 0.13, 0.16), (0.7, -0.03, 0.1, 0.12), (0.57, 0.02, 0.27, 0.11)):
        s.sphere((fx, y + fy, z + fz), r, "fur_white", segments=8, rings=5)                # a little pile of brushed out fluff
    brush = _tris(s.finalize(TOOLS + "_Display_ProBrush", mat))

    s = Builder()                                       # folded towels on the last shelf
    z = SHELVES[2]
    for i, sw in enumerate(("spa_sky", "spa_cream", "spa_bubblegum")):
        s.box_base((0.0 + 0.03 * (i - 1), y, z + 0.16 * i - 0.005 * i), (0.95 - 0.06 * i, 0.4, 0.17), sw)
    decor = _tris(s.finalize(TOOLS + "_Decor", mat))
    return [main, soap, brush, decor, _screen(TOOLS, mat, 4.53, 2.3, SCREEN_H, -0.13)]


def tools_board_rbx_extras():
    return {"attachments": [(TOOLS, f"Row{i + 1}", Matrix.Translation((0.0, ROW_Y, z))) for i, z in enumerate(TOOL_ROWS)],
            "attributes": {"Rows": {"Float64": float(len(TOOL_ROWS))}}}


def build_build_board(mat):
    b = Builder()
    _stand(b, 4.5)
    b.box((0, POST_Y, 0.8), (W - 0.3, 0.16, 0.16), "wood_light", bevel=False)              # a low rail between the posts
    b.box_base((0, 0.07, 1.2), (W - 0.3, 0.18, 3.36), "pastel_butter")                     # the frame
    b.box_base((0, -0.02, 1.34), (W - 0.7, 0.1, 3.08), "spa_sky", bevel=False)             # the plan sheet
    n = 7
    step = (W - 0.7) / n
    for z in (4.49, 1.27):                              # dashed tape along the top and bottom rails, as on the build pad
        for i in range(n):
            if i % 2 == 0:
                b.box((-(W - 0.7) / 2 + step * (i + 0.5), -0.03, z), (step, 0.04, 0.1), "spa_bubblegum", bevel=False)
    for i, z in enumerate(CARD_Z):
        b.box((0.17, FACE_Y - 0.015, z), (2.74, 0.05, CARD_H), "spa_cream", bevel=False)   # a row card
        b.box((-1.4, FACE_Y - 0.02, z), (0.3, 0.06, 0.3), CHIPS[i], bevel=False)           # its colour chip
    b.box_base((0, 0.02, 4.5), (2.5, 0.22, 0.7), "wood_light")                             # the title plank
    hx, hz = -POST_X, 4.5                              # a hard hat hung on the left post
    b.sphere((hx, POST_Y, hz), HAT, "pastel_butter", segments=10, rings=5, scale=(1, 1, 0.62))
    b.cyl_base((hx, POST_Y - 0.03, hz - 0.03), HAT + 0.06, 0.05, "pastel_butter", segments=10, bevel=False)
    b.box((hx, POST_Y - HAT - 0.05, hz), (0.5, 0.2, 0.04), "pastel_butter", bevel=False,
          rot=Matrix.Rotation(math.radians(-12), 3, "X"))                                   # its peak
    b.box((hx, POST_Y, hz + HAT * 0.62 - 0.02), (0.1, 0.5, 0.07), "pastel_butter", bevel=False)   # its ridge
    bx, by, bz = BELL_AT                                # the arm the bell hangs from
    b.box(((POST_X + bx + 0.08) / 2, by, bz + 0.07), (bx + 0.08 - POST_X, 0.1, 0.1), "spa_mint", bevel=False)
    main = _tris(b.finalize(BUILD, mat))

    s = Builder()                                       # the bell, built round its own origin where it hangs
    s.cyl_base((0, 0, -0.1), 0.035, 0.14, "metal", segments=6, bevel=False)                # the loop, up into the arm
    s.sphere((0, 0, -0.1 - BELL_R * 0.8), BELL_R, "fur_golden", segments=10, rings=6, scale=(1, 1, 0.9))
    s.cyl_base((0, 0, -0.1 - BELL_R * 1.75), BELL_R + 0.04, 0.07, "fur_golden", segments=10, bevel=False)   # the lip
    s.sphere((0, 0, -0.1 - BELL_R * 1.9), 0.07, "fur_brown", segments=6, rings=4)          # the clapper
    bell = _tris(s.finalize(BUILD + "_Bell", mat, location=BELL_AT))
    return [main, bell, _screen(BUILD, mat, 4.57, 2.2, SCREEN_H, -0.12)]


def build_board_rbx_extras():
    bx, by, bz = BELL_AT
    rows = [(BUILD, f"Row{i + 1}", Matrix.Translation((0.0, ROW_Y + 0.3, z))) for i, z in enumerate(CARD_Z)]
    return {"attachments": rows + [(BUILD, "Bell", Matrix.Translation((bx, by - 0.3, bz - 0.1 - BELL_R)))],
            "attributes": {"Rows": {"Float64": float(len(CARD_Z))}}}


ASSETS = {TOOLS: (build_tools_board, 1800), BUILD: (build_build_board, 900)}
EXTRAS = {TOOLS: tools_board_rbx_extras, BUILD: build_board_rbx_extras}
