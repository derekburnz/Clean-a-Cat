# Issue 782 recheck: Bathtile, Stardust and Djinn get their own bow spot (PR 789), main 86b06fc

## Setup
- Fresh local place from 86b06fc, iPhone 13 frame, the same switches and seed as the first run.
- Each cat was put in the tub on my client by re-sending CatReady. The bow went on with the game's BowFit.wear.
- Close-ups from the front and from above, with the HUD hidden.
- New spots in head space:
  - Bathtile (-0.47, 0.25, -0.23), tipped 90 degrees;
  - Stardust (-0.47, 0.10, -0.22), tipped 90 degrees;
  - Djinn (-0.48, 0.25, -0.22), tipped 75 degrees.
  - Rosette, Moonstag and Prism keep (-0.45, 0.25, -0.23) at 75 degrees.

| Cat | Bow | Part check | Picture | Result |
|---|---|---|---|---|
| Stardust | Double | no contact with any head piece part | beside the head, below the wand (21) | PASS |
| Stardust | Royal | no contact (was the rods at 50 to 80% and the glow at 40%) | beside the head, under the right rod and glow, nothing through the loop from the front or above (22, 23) | PASS |
| Bathtile | Double | the cap block at 90% (the block's empty corner, as Model-Agent said) | beside the cap, clear of the dome from the front and above (24, 25) | PASS by the picture |
| Bathtile | Royal | the cap block and band ring at 80 to 90% | the loop sits just outside the cap's edge; no visible cut from the front or above (26, 27) | PASS by the picture |
| Djinn | Royal | two small gold trim discs at 80 and 90% (was 70 to 90%) | beside the turban, no visible cut (28, 29) | PASS, grazes only |
| Rosette | Royal | one 0.2-stud crown piece at 90%, the same as before | unchanged (30) | PASS, no change |
| Moonstag | Royal | none | unchanged (31) | PASS, no change |
| Prism | Royal | one tiny glow at 90%, the same as before | unchanged (32) | PASS, no change |

Console: only the known lines.
