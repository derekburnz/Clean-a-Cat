# Studio QA passes on ff433b1 (with earlier results on 34efa64 and fa51ded)

- Build: main at ff433b1, built locally with rojo and opened in Studio as an unsaved place. One client. Never saved or published.
- Device: the iPhone 13 frame (844x390) stands in for the iPhone 12. Rigs: R15, plus one R6 run for issue 540.
- Switches: every key in LiveFlags.OFF_BY_DEFAULT on (dirtLevels, heartBar and promptFocus included) except toolCursor, streetLoadTest, exampleFeature and openingReplay.
- Play time was seeded to 340 s at the join (SaveSchema playSeconds), so 10:00 of play falls at about 260 s into each run. For Pass C the save was seeded with 400 coins.
- The test hook CleanACat_TestStep finished the drag steps. Bow and photo were real taps.

## Results
| Check | Result |
|---|---|
| Issue 540, R15, carrying Suds | PASS. "E Wash him" at 4.4 to 6.4 studs all round the tub, with board prompts 1.9 to 7.8 studs away |
| Issue 540, R15, carrying a customer cat | PASS. "E Put in tub" at 18 spots 4.2 to 6.7 studs round the tub, board prompts as near as 2.0 studs |
| Issue 540, R6, both carries | PASS. Same walk, same pills, board prompts as near as 0.4 studs |
| Boards after the drop | PASS. "E Buy Pro Brush" at 1.9 studs from the Tools board |
| Wash meter at 0 for each new cat | PASS. Suds, Inky, Smudge and Inky each start Scrub the mud at 0%. Later steps open at 100% for 1.3 s, then 0% |
| Moods (PR 536) | PASS. Ears follow the bar: 0 deg while happy, -11 at fill 0.40, -22 at 0.28 and under, -34 at 0. A cat in the tub has no mood |
| Walk-off (PR 552) | One at a time: Kit, Theo then Sunny, 9 and 21 s apart. See bugs 1 and 2 |
| Pass C builds | Brush Table 10 s and Blow Dryer 60 s count down and finish. Builder kitten Building=true while building. Recap shows "Spa stations bonus +7" (picture 01) |
| Pass E menus | PASS. Index, Settings and Who's next? each open and close with X. The touch controls hide while a window is open. Nothing opened by itself in 60 s |
| Pass H, PC only | Busy wash, 3 carriers in view: 0 of 100 frames over 14 ms, mean 4.2 ms, worst 6.2 ms (Studio quality 10). 24 draw calls, 29,385 triangles. Studio memory 2972 MB at 1 min, 3027 MB at 13 min |

## Bugs and questions
1. S3, walk-off clipping: the leaving copy walks back down the line (-Z) through the place the next customer steps into. Theo's copy walked from z -27.5 to -33.7 while Sunny stepped up from -32 to -28.
2. S4, line flicker: when a customer leaves, the whole line is rebuilt. For 1 frame the leaving customer is there twice (the copy and the real figure), then the line is empty for 1 to 3 frames (about 0.04 s).
3. Question: the front customer's bar stayed at 1.000 for over 6 minutes while the two behind drained.
4. Question: customers who join after the first serve arrive part drained (0.20, 0.78 and 0.86 on arrival), and the 0.20 one left about 20 s later.
5. Question: the two customers whose bars started together hit 0 and left in the same second (Pip and Rae). The release stagger only covers bars held on the sliver at 10:00.
6. Question: at the Build board only one pill shows, and from where I stood the scripted camera never got "Build Brush Table" or "Build Blow Dryer" on it (it showed VIP Room, Pawdicure or Bubble Bath). I fired RequestBuild for the builds. A person should check this on a phone.
7. Note: "Before you go" (long build offer) opened by itself right after a recap (picture 02).

## Not run
- Pass G and Pass F need the Studio Test tab or the Roblox player, which need screen control.
- Pass D and the visitor arrival effect: not on main.
- Finish now: not on main. Bubble Bath and Pawdicure were not used (10 min and 900 coins).
