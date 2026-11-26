# Issue 773: bows on the head's corner, new cat faces and the big spa's speed (main 2273557)

## Setup
- Build: main at 2273557 (PRs 770 and 772 included), built with rojo and opened as an unsaved local place, one client. Never saved or published.
- Device: iPhone 13 frame (844 x 390, a 749 x 388 view). Studio's simulator has no iPhone 12; the iPhone 13 has the same screen.
- Switches: every key in LiveFlags.OFF_BY_DEFAULT on except toolCursor, streetLoadTest, exampleFeature, openingReplay, benchGrow and cameraClear. That includes bigSpa and bowTiers. bigSpa was turned off for the speed comparison only.
- Seeds, edited in the local place only: play 11:40, 5 stars, 50,000 coins, Jo and Sam hired, the Garden and VIP Room built, and every bow tier bought.
- Walks used the qaWalk helper. Each wash took the cat with the E key and put it in the tub with E. The steps were finished with the Studio test step. The bow and photo were real taps.
- The bow tier on show was picked by setting the BowTier player attribute from the server before each bow tap. The client draws the look from that attribute.

## 1. Bows (PR 770)
| Check | Result |
|---|---|
| Plain bow, washed by hand (Patches) | PASS. The bow sits on the head's top front corner at the cat's left, tipped 30 degrees (BowSlot in head space at (-0.49, 0.50, -0.30)). It touches the left ear and the head, and the ear tip sits inside the loop, not through it (picture 01) |
| Double, washed by hand (Moonstag, a special with antlers and a moon) | PASS. Moonstag uses the old side spot (BowSlot at (-0.61, 0.50, -0.34), tipped 60), as the issue says for a special with a head piece. The bow hangs at the side of the head, clear of the antlers (picture 02) |
| Royal, washed by hand (Inky) | PASS. On the new corner, 30 degrees (picture 03) |
| Golden, washed by hand (Muffin) | PASS. On the new corner, 30 degrees (picture 04) |
| Royal on Rosette and Stardust | Both use the old side spot. Rosette: the bow's upper loop overlaps the right edge of the crown (it touches the crown's gem and prop parts), a mild clip (picture 06). Stardust: the loop touches the star crown's glow and prop parts at the corner, a mild clip (picture 07). Both cats were swapped into the tub on my client by re-sending CatReady, and the server knew nothing of them |
| Display window (a stray washed by hand with the Golden tier) | FAIL. At the tub the stray wore CleanACat_Bow_SkyGolden. On the window seat the same cat wears the plain CleanACat_Bow_Sky (picture 05). The plain bow is on the right corner. Cause: WindowController wears only the base bow id (SpaRules.BOWS) and never applies the tier look. A Gameplay fix, not a model one |
| The bow stays on while the cat walks out | FAIL (not shown). A customer's washed cat never walks out: about 6 s after Next cat it is removed from the tub, and nothing carries it out (Moments.CatReturned has no subscriber). So no bow is seen leaving. A stray goes to the window, as above |
| Recap | The recap card listed "Golden bow +12" even when the tier on show was Double. That is expected here: the server pays the best tier owned, and I changed only the look |

## 2. Faces (PR 772)
- Close-ups in the wash view, with the HUD hidden and a narrow camera on the head: Patches, Cotton, Toffee, Tux, Marble, Lilac Cloud, Suds (picture 10 onward). Also Moonstag, Inky, Muffin, Rosette and Stardust in the bow pictures.

| Check | Result |
|---|---|
| Round cheeks under the eyes | PASS. Every cat seen has two Cylinder cheek parts under the eyes and no bar at the eye |
| Toffee's mouth | PASS. Toffee has the same mouth as the others: no brown block under the nose (picture 12) |
| Flicker | PASS for the faces. A geometry check over all 21 sitting cat models found no face part flush with the head's front face. Only Rosette has two prop parts flush with a head face (her crown pieces), which can flicker; I didn't see it flicker |

## 3. Big spa (bigSpa)
- PC numbers. Studio caps at 240 fps on this PC, and the quality level read 21 (the PC's top level). Studio can't set the lowest graphics level from a script. Memory is Studio's whole process (client and server together), not a phone's.
- The parts below are all BaseParts. Six plots: SpaPlots 4,251 on and 4,054 off. Workspace: 5,056 on and 4,859 off.
- The seeded save skips the truck opening, so "join" below is the first 30 s after joining, not the opening scene.

| View | bigSpa on | bigSpa off |
|---|---|---|
| Spawn view | 241 fps, mean 4.17 ms, worst 6.95 ms, 105 draw calls, 212,225 triangles | 241 fps, mean 4.17 ms, worst 6.45 ms, 100 draw calls, 162,948 triangles |
| Garden door | 241 fps, mean 4.17 ms, worst 6.60 ms, 84 draw calls, 98,477 triangles | 241 fps, mean 4.17 ms, worst 7.00 ms, 83 draw calls, 100,434 triangles |
| VIP door | 239 fps, mean 4.18 ms, worst 13.76 ms, 93 draw calls, 94,329 triangles | 241 fps, mean 4.16 ms, worst 6.69 ms, 92 draw calls, 94,556 triangles |
| One hand wash (52 to 54 s) | 240 fps, mean 4.17 ms, worst 14.97 ms, 0 frames over 16.7 ms | 240 fps, mean 4.17 ms, worst 14.83 ms, 0 frames over 16.7 ms |
| First 30 s after join | mean 4.19 ms, worst 73 ms, 5 frames over 16.7 ms, 2 over 33 ms | mean 4.20 ms, worst 111 ms, 5 over 16.7 ms, 2 over 33 ms |
| Memory (Studio process) | about 3,190 to 3,215 MB | about 3,194 to 3,223 MB |

- There is no drop on this PC. The spawn view draws 30% more triangles with the big spa (212k against 163k) and 5 more draw calls, still far inside the example budget of 1,000 draw calls and 1,000,000 triangles.
- A real iPhone 12 at the lowest setting is still needed for the done-when line, because Studio can't show phone speed or memory.
- Street, backdrop and counter from the player's height: pictures 20 to 22. The counter's six mats sit at y 3.34, z -24.9, 3.2 studs apart. I couldn't measure the 0.24 clearance to the carriers' gates with cats on the mats in this run.

## Console
Only the known lines.
