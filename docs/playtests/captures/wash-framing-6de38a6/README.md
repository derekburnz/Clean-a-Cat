# Wash framing on 6de38a6 (#419)

Local unsaved build of 6de38a6 on the iPhone 13 frame (750x390), with washScene on and the same switches as the 5781142 pass.
- Fill: the cat's bounding box on screen, as a share of the screen height.
- Face angle: between his facing and the camera, flat on the floor.
- Dot gap: from the bottom of the step dots to the top of his ears.
- Paws: the bottom of his front legs and claws on screen.

| Station | Face angle | Fill | Dot gap | Paws bottom (GUI y) | Camera y | Within 0.5 studs | Ray to the cat hits |
|---|---|---|---|---|---|---|---|
| Tub, Suds | 2 | 0.53 | 25 px | 235 | 7.84 | none | Head |
| Tub, customer | 2 | 0.52 | 27 px | 240 | 7.84 | none | Head |
| Bubble Bath, with foam | 3 | 0.60 | 32 px | 242 | 7.85 | none | Head |
| Pawdicure | 0 | 0.55 | 30 px | 243 | 7.95 | none | Head |

- Every fill is within 0.5 to 0.6. The Bubble Bath is the highest because its 6 visible suds parts make his box 2.72 x 2.81 x 2.71 studs, against 2.24 x 2.83 x 1.87 in the tub. No fluff part was visible at the Bubble Bath in this run.
- With autoTool on there is no bottom bar. The paws are 89 to 97 px above the bottom of the GUI area (y 332).
- The camera now sits at y 7.84 to 7.95, higher than the 7.3 expected, but nothing is within 0.5 studs of it at any station.
