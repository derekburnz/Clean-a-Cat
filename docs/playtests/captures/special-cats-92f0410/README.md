# Special cats Prism and Stardust, plus queued rechecks, on 92f0410

Local unsaved build of 92f0410 (PR 489) on the iPhone 13 frame: an 844x390 picture with a 750x390 viewport.

## Prism and Stardust (pictures 1 to 4)
- Setup: I cloned ReplicatedStorage.Assets.CleanACat_Cat_Prism and CleanACat_Cat_Stardust on the client, scaled them to 1.5 like a washed cat, and put each on the tub's CatSeat (0, 2, -12) under the spa's normal lighting.
- Cameras:
  - Play: from (0, 6, -1.5), field of view 70, 10.9 studs away.
  - Wash: from (0, 7.84, -6.6), field of view 50, the wash scene's tub shot.
- Measure: luminance (0 to 1) of 3x3 pixel patches at each eye, the head and every Neon part, projected into the picture.

| Cat, camera | Eyes avg (min..max) | Head avg | Neon avg (max) | Neon vs head |
|---|---|---|---|---|
| Prism, play | 0.40 (0.13..0.60) | 0.17 | 0.32 (1.00) | 1.7:1 |
| Prism, wash | 0.48 (0.37..0.59) | 0.26 | 0.56 (1.00) | 2.0:1 |
| Stardust, play | 0.49 (0.38..0.68) | 0.20 | 0.47 (1.00) | 2.1:1 |
| Stardust, wash | 0.43 (0.30..0.54) | 0.30 | 0.93 (1.00) | 2.8:1 |

- Prism has 33 Neon parts (Glow and Rainbow_Glow in sky, rose, mint and cream). Stardust has 35 (Comet_Glow, Tail_Star_Glow and Glow, mostly cream #fff4b0).
- What I see:
  - The neon glows, and the white and cream pieces clip to pure white with a soft bloom halo. On Prism that is the horn and ear tips; on Stardust it is the star crown and diamonds.
  - The glow sits above the head. No eye pixel reaches white: the brightest eye patch is 0.68. The eyes stay brighter than the face round them, so the face and eyes read in all four pictures.
  - The weakest case is Stardust at the wash camera. Its crown is 0.93 on average, the brightest thing on screen, and its eyes are only 1.4:1 against the busy navy face with its star.
- Console: no new errors from the two cats.

## Queued rechecks
- PR 450, truck door: pass. The door was logged every frame against the truck.
  - It swings open to 84 degrees and holds near 75.
  - The close starts at 4.648 s and eases to shut at 4.934 s (0.29 s), building speed smoothly with no jump.
  - Two fading bounces follow: 2.3 degrees at 5.02 s, then 0.37 degrees at 5.22 s. It is still at 5.37 s, never past the frame.
- PR 453, stink smoke: pass. No stink emitter or CleanACat_Fx_Stink object appeared at any time, from the opening through Suds and a customer. There was no green-tinted particle emitter in the world at the end.
- #435, foam puffs: pass.
  - The puffs now appear as you swirl, with a wash bar (21% after the first part-circle, picture 5). They are PH_Suds models holding CleanACat_Prop_FoamPuff shapes.
  - Once the suds were swirled away, 0 puff models were left on the cat. They are destroyed now.
- #443, bow slabs: pass. The tap slabs are now 1.00x0.95x0.10 studs, and none overlaps another (picture 6):
  - Pink: x 99..201, y 169..224
  - Mint: x 132..220, y 228..273
  - Sky: x 158..235, y 275..312
  - Rays at Mint's top and bottom edges hit Mint.
- Side note: in both customer washes the claw step was skipped after the Bubble Bath (step 3 went straight to step 5). I didn't look into why.

## Console
No game errors. Only Studio's MemoryStore and DataStore lines, plus the 3 known "rbxassetid://203785492 asset type does not match" lines at the opening.
