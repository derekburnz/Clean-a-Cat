"""Foam puffs for the Bubble Bath step (issue #431): `CleanACat_Prop_FoamPuff`, `..._FoamPuff2`, `..._FoamPuff3`.

In the Bubble Bath the suds on the cat stood in as six plain white balls made in code (`PH_Suds1` to `PH_Suds6`).
These are three shapes of the same thing, so six puffs round a cat do not look alike: a low heap of white foam
lobes with one clear soap bubble on it.

How a puff sits. It is built against a wall, not on the floor: the pivot is the middle of its back, the back lies in
the plane through the pivot and the puff bulges to the front (-Y here, -Z in Roblox). So the code's own placement
(turn about the cat, then step out along -Z) faces every puff outward with no extra turn. A puff is about half as
deep as it is wide, and its lobes dip a little behind the back plane, into the fur, so it reads as lying on the coat.
About 1.1 studs wide at scale 1; the game scales it to the cat. Tried on a walking cat at 1.5: scale 0.36 of his reach
(the longer of his box's width and length), the pivot 0.8 of the way from his middle to his box's face in that
direction. That gives about the box the six balls gave (1.88 x 2.24 x 2.19 against 1.97 x 2.21 x 2.06).

  CleanACat_Prop_FoamPuff<n>           the foam lobes (swatch `foam`): Ball parts, the flattened ones sphere meshes
  CleanACat_Prop_FoamPuff<n>_Bubbles   one soap bubble with its glint (see-through, taps and rays pass: rbx_export)

Like every `Prop_` a puff is walk-through. Its foam parts still take raycasts by default, so the scrub code turns
CanQuery off on a clone, as it did on the balls.
"""

from common import Builder, shade_smooth
from stations import DETAIL, _tris, soap_bubble

NAME = "CleanACat_Prop_FoamPuff"

# Each shape: the foam lobes (x, z, how far its middle stands out from the back, radius, front-to-back squash) and
# its soap bubble (x, out, z, radius). x is across, z is up, both from the pivot.
SHAPES = {
    NAME: ([(0.0, 0.0, 0.2, 0.36, 0.72), (-0.31, -0.1, 0.14, 0.24, 0.8), (0.31, -0.08, 0.14, 0.26, 0.8),
            (0.13, 0.25, 0.16, 0.22, 0.8), (-0.18, 0.23, 0.15, 0.19, 0.8), (0.02, -0.14, 0.34, 0.19, 1.0)],
           (0.33, 0.33, 0.2, 0.12)),                                                    # a round heap
    NAME + "2": ([(-0.2, -0.02, 0.18, 0.3, 0.72), (0.22, 0.0, 0.17, 0.28, 0.72), (-0.5, -0.06, 0.12, 0.19, 0.8),
                  (0.5, -0.09, 0.12, 0.18, 0.8), (0.02, 0.2, 0.15, 0.2, 0.8), (0.0, -0.12, 0.31, 0.17, 1.0)],
                 (-0.36, 0.32, 0.17, 0.11)),                                            # a wide, low drift
    NAME + "3": ([(0.0, -0.1, 0.2, 0.33, 0.72), (0.05, 0.22, 0.17, 0.26, 0.76), (-0.02, 0.46, 0.14, 0.18, 0.8),
                  (-0.27, -0.16, 0.13, 0.2, 0.8), (0.28, -0.14, 0.13, 0.21, 0.8), (0.1, 0.0, 0.34, 0.16, 1.0)],
                 (0.2, 0.3, 0.42, 0.1)),                                                # a tall dollop
}


def _build(name):
    def build(mat):
        lobes, (bx, bout, bz, br) = SHAPES[name]
        seg, rings = DETAIL["ball"]
        f = Builder()
        for x, z, out, r, squash in lobes:
            f.sphere((x, -out, z), r, "foam", segments=seg, rings=rings, scale=(1.0, squash, 1.0))
        s = Builder()
        soap_bubble(s, bx, -bout, bz, br)
        return [shade_smooth(_tris(f.finalize(name, mat))),
                shade_smooth(_tris(s.finalize(name + "_Bubbles", mat, bevel=0)))]
    return build


ASSETS = {name: (_build(name), 600) for name in SHAPES}
EXTRAS = {}
