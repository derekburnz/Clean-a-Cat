"""Hand tools (issue #13 for the sponges, #14 for the brush).

  CleanACat_Tool_Sponge        the starting sponge: butter yellow with a mint scrub top
  CleanACat_Tool_SpongeBubble  Bubble Soap (30 coins): a bigger sponge with a foam cluster on top, a wider scrub
  CleanACat_Tool_SpongeGolden  the Golden Sponge game pass: gold with a pale gold top and gold bubbles
  CleanACat_Tool_Brush         the grooming brush: a bubblegum back with cream bristles and a light wood handle

Each is one object, so the Part model is a Model of Parts whose biggest part is named `Handle` (rbx_export
RENAME_BIGGEST): the game moves the parts into a Roblox Tool and welds them to Handle. Pivot at the grip centre
(the middle of the sponge body), front -Y. Nothing collides. Sized to read in a player's hand on a phone: about
twice a real sponge.
"""

from common import Builder

SPONGES = {
    # name: (body swatch, top swatch, bubble swatch or None, scale)
    "CleanACat_Tool_Sponge": ("pastel_butter", "spa_mint", None, 1.0),
    "CleanACat_Tool_SpongeBubble": ("pastel_butter", "spa_mint", "foam", 1.2),
    "CleanACat_Tool_SpongeGolden": ("gold_mid", "gold_light", "gold_light", 1.2),
}


def build_sponge(name, mat):
    body, top, bubbles, k = SPONGES[name]
    b = Builder()
    b.box((0, 0, 0), (1.0 * k, 0.65 * k, 0.4 * k), body)
    b.box((0, 0, 0.26 * k), (1.04 * k, 0.69 * k, 0.16 * k), top)          # overlaps the body: no shared face
    for x, y in ((-0.25, -0.12), (0.2, 0.1), (0.05, -0.2), (-0.1, 0.18)):   # sponge holes on the front face
        b.box((x * k, -0.326 * k, (y - 0.02) * k * 0.6), (0.09 * k, 0.02, 0.09 * k), "wood_light" if body != "gold_mid"
              else "gold_dark", bevel=False)
    if bubbles:
        for x, y, z, r in ((-0.22, 0.0, 0.46, 0.17), (0.12, -0.08, 0.44, 0.14), (0.3, 0.12, 0.4, 0.1),
                           (-0.04, 0.12, 0.58, 0.12)):               # each sunk into the top or another bubble
            b.sphere((x * k, y * k, z * k), r * k, bubbles, segments=8, rings=5)
    return [b.finalize(name, mat)]


def build_brush(mat):
    """The brush, held by its handle: the pivot is the middle of the handle and the head points forward (-Y), the
    bristles down, so a stroke reads from the player's camera. The head is the biggest part, so it is `Handle`."""
    name = "CleanACat_Tool_Brush"
    b = Builder()
    b.box((0, 0, 0), (0.16, 0.6, 0.12), "wood_light")                          # handle, the grip
    b.box((0, -0.5, 0.02), (0.56, 0.44, 0.14), "spa_bubblegum")                # the back of the head
    for i, y in enumerate((-0.66, -0.5, -0.34)):                               # three rows of bristles
        b.box((0, y, -0.1), (0.48, 0.09, 0.14), "foam" if i != 1 else "spa_cream", bevel=False)
    return [b.finalize(name, mat)]


ASSETS = {n: (lambda mat, n=n: build_sponge(n, mat), 400) for n in SPONGES}
ASSETS["CleanACat_Tool_Brush"] = (build_brush, 200)
