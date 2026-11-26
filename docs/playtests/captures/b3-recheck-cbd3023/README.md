# B3 recheck on cbd3023 (PR 596 merged)

- Build: main at cbd3023 (merge of PR 596), built locally with rojo and opened in Studio as an unsaved place. One client. Never saved or published.
- Device: iPhone 13 frame (844x390), touch only. R15. Taps are real touch taps unless noted.
- Switches: every key in LiveFlags.OFF_BY_DEFAULT on except toolCursor, streetLoadTest, exampleFeature, openingReplay and benchGrow. That includes lineReuse, tipJar, tutorialBench, tubBuilds, barSpacing, boardKeys, lineSwap, pets, petsWindow, crateWindow, workers and specialVisitors.
- Four runs:
  - A: fresh save, no seed (tutorial bench).
  - B: returning save, play 11:40, 5 stars, 30,000 coins (worker takes).
  - C: the same with 500 coins, Jo hired in the save and the jar last stamped 2 hours ago (tip jar, board taps).
  - D: the same as C without Jo, with heart bars cut to a quarter (Common 37 s) and the first special's bar 60 s, to get 5 heart-bar leaves quickly.
- How the seeds were made: the SaveSchema defaults and HeartRules numbers were edited in the local place only.
- The clock for the line counts is the server's PlayerAdded time (play 0 on a fresh save), sampled every 0.1 s.

## Results
| Check | Result |
|---|---|
| #574 Build board taps | PASS. At 5.8, 6.7 and 8.2 studs (the pad blocks standing further back) every visible pill fired only its own row: Garden, VIP Room, Second Tub. No two pills overlap (the closest gap was 18 px, VIP to Garden) |
| Pill rects at 5.8 studs | Second Tub 342,6 to 508,50; VIP Room 344,197 to 493,241; Garden 343,259 to 473,303 (px, mouse space) |
| PillStep direction | Rows spread out from the middle at 1.15 pill heights (51 px) per row: Second Tub moved up 127 px, VIP Room down 25 px, Garden down 76 px. Third and Fourth Tub were hidden until the Second Tub was built |
| While a build runs | PASS. Only "Building Second Tub" stayed. There was no bell, because this was a short build. No Finish now (no product in Studio) |
| Refused taps | Garden (25,000) and VIP Room (15,000) with 560 coins: each fired its own row, coins unchanged |
| #571 leaver shows twice | FAIL (small). On every heart-bar leave (Bea, Kit, Sunny, Mo, Pip, Rae) the leaver's line figure and the walk-off copy were both there for 1 frame (about 4 ms in Studio) |
| #571 line count never dips | FAIL (small). The line dropped to 2 figures for 1 frame (2 frames once) on each leave and each worker take, then the newcomer appeared |
| Step-up after a leave | PASS. The next customer starts moving 0.80 s after the leave, every time |
| #570 copy and next customer overlap (top view) | FAIL. Using each model's bounding box seen from above, the copy and the stepping-up customer overlap by 0.48 to 0.73 studs, from 0.92 s to about 1.2 s after the leave, on all 5 leaves. The boxes include arms and carriers, so the bodies may only brush |
| Bars end 15 s apart (run D) | PASS. Hit zero at 745.2, 760.2, 805.4, 820.4, 840.5, 855.6 and 877.6 s |
| Newcomers' first bar | PASS. Every newcomer arrived at 1.00 in runs A, B and D |
| Door customer's bar | Question: on a returning save the door customer stays at 1.00 the whole time. After a fresh save's first serve the front customer drained normally |
| #595 tutorial bench | FAIL, see below |
| Tip jar | PASS. Jo hired, jar stamped 2 hours ago: "Collect tips / 60 coins" on the window jar (30 an hour). A tap took coins from 500 to 560. A second tap did nothing (prompt off), and a direct RequestCollectJar left 560 |
| Hire Jo by tap | PASS. 150 coins. Jo then took customers from the line, and the next customer stepped up 0.80 s later |
| Pets window | Fits the frame: card 24,7 to 726,331 in a 750x332 root. Titles 19 px; "No pet yet" and "Comes when ... is hired" 14 px; the X hangs 8 px above the root's top (picture 02) |
| Who's next? cards (PR 586, 589) | Heart bars show on all cards (141x18 px). The special card is lilac with a gold rim and "Only you can wash" (14 px). The "Uncommon" tag runs past the card's right edge on both Uncommon cards (picture 01) |
| Crate window | Not measured again: no special visitor was washed in these runs. On 118475e: chances 19 px, names 18 to 19 px, boost 17 px tall with 19 px text, footnote 2 lines |

## Tutorial bench (#595), run A, fresh save, no seed
Figures include the door customer.

| Play time | Figures | BenchSize |
|---|---|---|
| 0:18 | 1 (first figure) | 1 |
| 0:30, 1:00, 1:59 | 1 | 1 |
| 2:01 | 1 | 2 |
| 2:44 | 1 | 2 |
| 2:46, 3:30, 4:00 | 1 | 3 |
| 4:26 | 3, as soon as I took the door customer's cat | 3 |

So the line never grows past the door customer while that customer still holds their cat. It fills only when the cat is taken.

## Console
One new client error, in run D at the join with a seeded save: `UI.SudsBubble:112: invalid argument #3 to 'clamp' (max must be greater than or equal to min)` (span, from BubbleController.check). This looks like the bubble's width sum when the screen width is not known yet. Everything else was on the known list.
