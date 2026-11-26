# B4 recheck on a5e02a1, with quests, check-in and crate on b210775

- Builds: main at b210775 (check-in card, quest book, crate window, quests after 6:00), then main at a5e02a1 for the B4 recheck. a5e02a1 has PRs 604, 610, 611, 612 and 613. Each was built with rojo and opened as an unsaved local place, one client. Never saved or published.
- Device: iPhone 13 frame (844x390), touch only, R15. Real touch taps unless noted.
- Switches: every key in LiveFlags.OFF_BY_DEFAULT on except toolCursor, streetLoadTest, exampleFeature, openingReplay and benchGrow. That includes quests, checkinCard, lineReuse, tipJar, tutorialBench, tubBuilds, petsWindow, crateWindow, finishNow, workers, specialVisitors, and on a5e02a1 also passes.
- Seeds were made by editing, in the local place only:
  - SaveSchema defaults: play time, coins, stars, Jo hired, jar stamp.
  - HeartRules: bar lengths times 0.25 for the leave runs.
  - QuestRules.refresh: every open quest set to its goal minus 1 for the quests runs.
- Clock: the server's PlayerAdded time plus the seeded play seconds, sampled every 0.1 s.

## B4 recheck (a5e02a1)
| Check | Result |
|---|---|
| #595 tutorial bench, fresh save, no seed | PASS. 1 figure at 0:30, 1:00 and 1:59 (Sunny from 0:18). Mo drawn at 2:00.4, so 2 at 2:01 and 2:44. Pip drawn at 2:45.6, so 3 at 2:46, 3:30 and 4:00. The door customer still held their cat the whole time |
| #570 bodies (torso and head parts, from above) | PASS. Min separation between the walk-off copy and any line figure: 1.69 to 1.97 studs on 4 leaves (Vivi, Kit, Pip, Rae), and 2.15 to 2.32 on the rest. Bounding boxes never overlapped either (min box gap +0.24) |
| #570 step-up delay | PASS. The next customer moves 1.2 s after the leaver leaves the line (for example Pip out at 282.74, Rae moves at 283.94) |
| New: newcomer walks into the waiting customer | FAIL (small). The newcomer reaches the third place while the customer there has not stepped up yet. Juno reached z -31.6 while Rae was still at -31.4: pivots 0.2 studs apart for about 0.1 s, so the bodies overlap |
| #571 leaver shows once | PASS. On 5 heart-bar leaves (Vivi, Kit, Sunny, Pip, Rae) the leaver is the copy only. Never in the line and the copy at once |
| #571 line never counts one short | FAIL (small). On each of the 5 leaves the line shows 2 figures for 1 frame (7 to 11 ms in Studio) before the newcomer appears |
| #571 worker takes | PASS for "never short" on 3 takes (Bea, Theo, Mo). The newcomer is drawn first, so the line shows 4 figures for 1 to 3 frames, then 3 |
| #608 clamp error at a seeded join | PASS. Gone on a5e02a1 (it was still there on b210775) |
| #609 Uncommon tag | FAIL (small). The pill now ends 4 px inside the card, but the word "Uncommon" (89 px) is wider than its pill. It overflows the pill by 7 px and the card edge by 3 px (picture 01) |
| Golden bow fan (PR 604) | PASS by a client check. I could not wash a Rosette or Stardust cat in time, so I called BowFit.wear on fresh copies. Rosette and Stardust (HeadPiece true) with Pink and Mint Golden: 0 fan pieces worn (the asset has 6). Muffin (no head piece): all 6 |
| Console | Nothing new: only the known lines |

## Quests (b210775, then a5e02a1)
| Check | Result |
|---|---|
| Before 6:00 a wash counts nothing | PASS. Play seeded to 4:00 on a5e02a1. A customer washed by 5:17. At 6:15 the book still read 3/4, 4/5, 19/20, 1/2, 9/10, the seeded values, and no "Quest done" showed |
| Quests button | Appears at 6:00 of play (client log 359.9 s), at 200,14, 49x49 px, after Check in. Appears once. A tap opens the book |
| Suds's tip | "Quests!" / "Coins every day, a crate each week." Title 19 px, line 15 px, bubble 420x75 at 168,245 (bottom middle). It came about 31 s after 6:00: after I tapped the recap strip's Next cat and the "Let's build!" bubble timed out. It closes by itself after 6 s or with the X |
| Counting after 6:00 | PASS. Each hand-washed customer's cat moved the matching quests (for example "Take 2 cats early" 1 to 2, "Put a bow on 3 cats" done) |
| "Quest done" toast | "Quest done: Take 2 cats early! +40 coins". Toast label 600x40 at 75,70 (top middle), 18 px text, shows 5 s, covers a strip at the top of the view. Coins paid at once (1000 to 1071 with the recap's +31) |
| Several quests done by one cat | FAIL. A special visitor at dirt level 4 finished 3 quests at once (dirt 3 or 4, 2 specials, 10 at dirt 4). All three paid (+300, +300, +60), but only the last "Quest done" toast was seen |
| All weekly quests done | PASS for the crate: "Every weekly quest done! A crate is yours", Crates_normal 1 to 2. FAIL (small) for the toast: "Quest done: Get 3 stars on 20 cats! +300 coins" showed for only 1 frame before the crate toast replaced it |
| Quest book layout (picture 04) | Card 660x247 at 45,48 in the 750x332 root. Titles 19 px, quest lines 14 px, counts and amounts 19 px. Rows fit, nothing is cut on screen. The X closes it, and nothing opened by itself |

## Check-in card (b210775)
| Check | Result |
|---|---|
| When | On a save past 3:45 it opened 2.3 s after the first bubble closed, by itself, once |
| Size and place | Card 675x252 at 38,46 (root 750x332), centred, the view dimmed behind it |
| Text | Day 1 to 7 labels 19 px, rewards 19 px, note 19 px |
| "Good crate" | FAIL. Day 2's reward shows only "Good": the label is 15 px tall and the dice icon sits where "crate" would wrap (picture 02) |
| Claim | "Claim 50 coins" paid +50 (CheckinDays 0 to 1). The card closed by itself 7 s later |
| Reopen | The Check in button reopens it with "Day 2 waits for the next day you play." and no Claim. The X closes it |

## Crate window and Pets window (b210775)
| Check | Result |
|---|---|
| Crate window (picture 05) | Card 702x318 at 24,10. Chances 19 px. Pet names 19 px text in 18 px labels. Rarity tags 19 px. Boost 19 px text in 17 px labels. Footnote 2 lines (38 px). Nothing is cut on screen. The X sits 5 px above the top edge |
| "Look inside" tap | FAIL. With the Tools board behind the crate, the "Buy Pro Brush" pill sat on top of "Look inside" (centres 4 px apart). A tap on Look inside bought the Pro Brush (120 coins). The second tap opened the crate window |
| Pets window | Card 702x324 at 24,7, fits. Titles 19 px, "No pet yet" and "Comes when ... is hired" lines 14 px, X 8 px above the top edge |

## Other notes
- Side buttons cover the wash step title. With five side buttons (Index, Pets, Gifts, Quests, Settings) the Settings button sits on "Step 5 of 6 · Pick a bow" at the top of the wash view (picture 03).
- The compact recap strip ("+1 star, +31, Next cat") stays until it is tapped, and Suds's bubbles wait behind it.
- On a seeded save the "First customer!" bubble shows at the join and again later. That is a seeding artefact (BubblesSeen starts empty).
