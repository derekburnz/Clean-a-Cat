"""Reward props (#125): what a wash pays, in the world and as the source of the recap card's icons.

  CleanACat_Prop_Coin       a chunky gold coin standing on edge, a paw print (a pad and four toes) on both faces. Pivot at its middle, so
                            the game can spin it and pop it out of a customer; a face to the front (-Y in Blender).
  CleanACat_Prop_Star       a fat five point star standing up, a paler star set into its front face. Pivot at its middle.
                            A wash's rating and the spa's stars.
  CleanACat_Prop_CoinStack  a small pile: stacks of five, three and two coins. Pivot at the base centre, on the floor.
                            The recap card's coins and a full tip jar's overflow.

Nothing here collides. The coin's golds are the palette's metal swatches, so they shine in Roblox; the star is flat
`rarity_legend`, the UI's gold, so a star in the world and a star on a card are one colour.
"""

import math

from common import Builder

COIN_R, COIN_T = 0.5, 0.16
_FACING = (math.radians(90), "X")           # a disc or a star stood up, its face to the front


def _paw(b, y, sw):
    """A paw print on a coin face at depth y: one pad and four toes in an arc, each proud of the face (three toes
    read as a crown, Review-QA on #135)."""
    b.box((0, y, -0.1), (0.3, 0.05, 0.2), sw, bevel=False)
    for x, z in ((-0.23, 0.06), (-0.08, 0.17), (0.08, 0.17), (0.23, 0.06)):
        b.box((x, y, z), (0.11, 0.05, 0.11), sw, bevel=False)


def build_coin(mat):
    b = Builder()
    b.cyl((0, 0, 0), COIN_R, COIN_T, "gold_mid", segments=14, rot=_FACING)                    # the rim
    for s in (-1, 1):
        b.cyl((0, s * (COIN_T / 2 + 0.005), 0), COIN_R - 0.08, 0.03, "gold_light", segments=14, rot=_FACING,
              bevel=False)                                                                    # a face, set in
        _paw(b, s * (COIN_T / 2 + 0.03), "gold_dark")
    return [b.finalize("CleanACat_Prop_Coin", mat)]


def build_star(mat):
    b = Builder()
    b.star((0, 0, 0), 0.6, 0.3, 0.22, "rarity_legend", rot=_FACING)
    b.star((0, -0.105, 0), 0.36, 0.18, 0.04, "sparkle", rot=_FACING)       # a paler star, proud of the front only
    return [b.finalize("CleanACat_Prop_Star", mat)]


def build_coin_stack(mat):
    b = Builder()
    # three piles side by side: piles that cross share the planes of their coins' tops and undersides (#160)
    for (x, y), n in (((-0.24, 0.16), 5), ((0.4, 0.06), 3), ((0.08, -0.46), 2)):
        for i in range(n):                                                # every other coin a hair smaller and paler
            odd = i % 2
            b.cyl_base((x + 0.02 * odd, y - 0.015 * odd, i * 0.1), 0.3 - 0.015 * odd, 0.102, "gold_light" if odd
                       else "gold_mid", segments=10, bevel=False)
    return [b.finalize("CleanACat_Prop_CoinStack", mat)]


ASSETS = {"CleanACat_Prop_Coin": (build_coin, 400), "CleanACat_Prop_Star": (build_star, 200),
          "CleanACat_Prop_CoinStack": (build_coin_stack, 400)}
EXTRAS = {}
