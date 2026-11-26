# B2 rerun, tub builds and tutorial bench (bf82547, 118475e, fba23bb)

- Builds: main at bf82547 for a first look, 118475e for the B2 checks and tub builds, and fba23bb (PR 583) for the tutorial bench and the returning save. Each was built locally with rojo and opened in Studio as an unsaved place. One client. Never saved or published.
- Device: iPhone 13 frame (844x390), touch only (TouchEnabled true, KeyboardEnabled false). R15.
- Switches: every key in LiveFlags.OFF_BY_DEFAULT on except toolCursor, streetLoadTest, exampleFeature, openingReplay and (on fba23bb) benchGrow. That includes dirtLevels, heartBar, promptFocus, bowTiers, workers, specialVisitors, barSpacing, boardKeys, lineSwap, pets, crateWindow, tubBuilds and tutorialBench.
- Seeds: the 118475e run set save.playSeconds to 700 and coins to 30,000 (SaveSchema defaults read workspace attributes). The returning save run on fba23bb set playSeconds 700 and stars 5. The tutorial bench run seeded nothing.
- The test hook CleanACat_TestStep finished the drag steps. Taps were real touch taps where noted.

## Results
| Check | Result |
|---|---|
| barSpacing, fresh save, line unpauses at the first serve | PASS. Front-but-one drains first; the bar behind starts about 5 s later. The two leavers hit 0 at 399.9 s and 415.0 s: 15.1 s apart |
| barSpacing, returning save (stars 5, play 11:40) | PASS. Hit zero at 164.6, 179.6 and 194.6 s: 15.0 s apart each |
| Late joiners' first bar | Question: Pearl 0.76 and Rae 0.22 on arrival (Rae left 26 s later); Bea, Rex and Theo arrived at 0.96 to 1.00 |
| Front customer's bar | Question: the customer at the door (LinePlace 1) showed HeartFill 1.00 the whole time in every run (over 4 minutes) |
| boardKeys, keys | PASS. Build board: Second Tub E/X, Third Tub R/Y, Fourth Tub F/LB, VIP Room T/RB, Garden Y/LT, bell U/D-pad up. Tools board: Bubble Soap E/X, Pro Brush R/Y, Silk bow F/LB |
| boardKeys, every pill shows on touch | PASS. All rows show a pill at once (130 to 166 x 44 px) |
| boardKeys, each pill its own tap | FAIL. On the Build board the pills stack 11 to 14 px apart but are 44 px tall, so they overlap. Taps at the centres of Garden and VIP Room fired Build Fourth Tub; the Fourth Tub centre fired Third Tub. Same at 5, 7 and 9 studs from the board |
| lineSwap | FAIL. On every leave (5 seen): 1 frame with the leaver twice (line figure and walk-off copy), then 2, 0, 1, 2, 3 figures over the next 4 to 5 frames (about 40 ms at Studio's frame rate) |
| Walk-off sideways (PR 576) | Partial. The copy now walks sideways (x -10 to -17.6, z fixed), but the next customer steps into the copy's spot at once: the two bodies (3.3 studs wide) overlap for about 0.9 s |
| Second Tub (touch) | PASS. 90 coins, 0:15 counting down, "Building the Second Tub", then a tub at the old station spot (-12, -11) and "Second Tub is ready!" |
| Tub recap bonus | PASS. Before: no stations line. With 1 tub: "Spa stations bonus +2" |
| Second build refused | PASS. "Wait for the Second Tub to finish" (and "Wait for the Third Tub to finish" later) |
| Old stations | PASS. Gone from the board and the plot (Stations: SecondTub, ThirdTub, FourthTub, BuilderKitten, Toolbox, VipRoom) |
| Third Tub | 1,000 coins, timer read 29:57 a few seconds in. Finish now is not on the board or anywhere in the client |
| Crates and pets | Crate from the special visitor (Stardust). "Look inside" opens the crate window: 8 pets, chances 25+25+13+13+8+8+6+2 = 100. Text: chances 19 px, names 18 to 19 px, boost 17 px label with 19 px text, footnote 2 lines. Open crate gave "You got Scrubby! Common, +5% on your tips". No pet model shows: ReplicatedStorage.Assets has no CleanACat_Pet_* models yet, and no console error |
| Tutorial bench | FAIL, see below |
| Gentle tutorial line | "1 / 3 Pick him up" at the top centre (265, 6, 220x42 px), from 11.4 s to 12.9 s of the client. It sits above the wash steps area and covers nothing |
| Suds bubbles | By design (BubbleRules): "New soap!" when Bubble Soap is affordable, "It's ready!" after a build, "Before you go" when a long build starts. None opened after a recap in these runs |

## Tutorial bench (fba23bb, fresh save, no seed)
The clock is the server's PlayerAdded time (play starts at 0 for a fresh save). The line count is the figures in SpaPlots.Plot1.Customers, sampled every 0.1 s.

| Play time | Figures | BenchSize |
|---|---|---|
| 0:18 | 1 (first figure) | 1 |
| 0:30, 1:00 | 1 | 1 |
| 1:25 | 2 | 1 |
| 1:59, 2:01 | 2 | 2 from about 2:00 |
| 2:44 | 2 | 2 |
| 2:46 | 2 | 3 from 2:46 |
| 3:30 | 2 | 3 |
| 4:00 | 3, right after I took the front cat | 3 |

So the second customer came 35 s early (1:25, just after the stray's wash), and the bench did not fill after 2:45 until a cat was taken.

## Not run
- A worker take (lineSwap): I did not hire a worker.
- Gamepad buttons were read from the prompts, not pressed.

## Notes on method
- In Studio's phone frame a keyboard E still reaches the game. With boardKeys a press of E fires every pill bound to E, so my E at the door bought Bubble Soap once (bf82547 run). A phone has no keyboard, so this is a test artefact, not a game bug.
- Pills are not drawn in Studio captures, so the board overlap has no picture; the numbers above come from the prompt projections and the tap results.
