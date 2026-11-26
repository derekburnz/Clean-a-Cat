# Issue 782: bows beside the head pieces (PR 786) on main 2f58f41

## Setup
- Build: main at 2f58f41, built with rojo and opened as an unsaved local place, one client. Never saved or published.
- iPhone 13 frame. Every key in LiveFlags.OFF_BY_DEFAULT on except toolCursor, streetLoadTest, exampleFeature, openingReplay, benchGrow and cameraClear.
- Seeded save with every bow tier bought.
- Each cat was put in the tub on my client by re-sending CatReady, and the server knew nothing of it. After one test step the bow was put on with the game's own BowFit.wear, the same call the bow tap makes.
- Close-ups use a narrow camera from the front and from above, with the HUD hidden.
- The ten cats with a head piece all have the new BowSlot: (-0.45, 0.25, -0.23) in head space, tipped 75 degrees. Bathtile, Djinn, Jade, Moonstag, Phoenix, Prism, Rosette, Sherbet, Stardust and WhiteTiger.
- "Clear at N%" means the bow part stops touching that head piece part once it is shrunk to N% of its size. 90% is a graze; 40% is deep.

| Cat | Double | Royal | Result |
|---|---|---|---|
| Rosette (pictures 01, 02) | | grazes one 0.2-stud gold crown piece (clear at 90%) | PASS. The bow hangs beside the head, outside the crown rim from the front and from above |
| Stardust (pictures 03, 04) | | the wand's three thin gold rods (clear at 50 to 80%) and the blue glow tip (clear at 40%) sit inside the bow's loop | FAIL (small). From above the glow tip and rod end show through the loop |
| Bathtile (picture 06) | the shower cap's side (clear at 70 to 80%) | the cap and its band (clear at 50 to 90%) | FAIL (small). The loop cuts into the side of the cap |
| Djinn (picture 07) | three small gold trim pieces (clear at 90%) | the trim and the turban band (clear at 70 to 90%) | PASS, grazes only |
| Prism (picture 10) | none | one tiny glow (clear at 90%) | PASS |
| Moonstag, Jade, Phoenix, Sherbet, WhiteTiger (pictures 05, 08, 09, 11, 12) | none | none | PASS. The bow touches only the head block |

Every bow still reads as a bow on the side of the head, at the cat's left.

## Console
Only the known lines.
