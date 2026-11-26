# B5 recheck: asks, landscape, crate rows, line and pets (2526f2b, 4c36fed, 7e1710e)

- Builds:
  - 2526f2b (PRs 621, 629, 630): landscape, side buttons, check-in, crate tap, quest toasts, saved pet at join.
  - 4c36fed (adds PRs 631, 632): crate rows, line leaves and takes, quest summary toast, the 10-minute ask log.
  - 7e1710e (adds PR 637): pets at join and after a reset.
- Each build was made with rojo and opened as an unsaved local place, one client. Never saved or published. iPhone 13 frame, touch only, R15, real taps.
- Switches: every key in LiveFlags.OFF_BY_DEFAULT on except toolCursor, streetLoadTest, exampleFeature, openingReplay and benchGrow. That includes askQueue, landscapeLock, quests, checkinCard, crateShop, passes, starterPack, benchSave, lineReuse, tipJar, pets, petsWindow, crateWindow and tubBuilds.
- Seeds were edits to the SaveSchema defaults in the local place only:
  - Returning-save runs: play 11:40, 5 stars, 5,000 coins, 2 normal crates, Jo hired, every quest at its goal minus 1, heart bars times 0.25.
  - Ask log: a fresh save with 1,500 coins.
  - Pets run: Nimbus (player), Koi (player2), Cozy (Jo1), the SecondPetSlot pass in save.passes, and Jo hired.
- Mock prices: ProductPrice_CrateOne 99, ProductPrice_CrateFive 399 and the pass prices were set on ReplicatedStorage by hand, because Studio reads none.

## Results
| Check | Result |
|---|---|
| landscapeLock, landscape | PASS. PlayerGui.ScreenOrientation is LandscapeSensor. LandscapeLeft and LandscapeRight both give a 750x390 view with nothing cut |
| landscapeLock, portrait frame | Studio's simulator forces portrait anyway (CurrentScreenOrientation Portrait, view 390x763), so the lock cannot be checked here. In that frame the side buttons run off the right edge (Settings and Starter cut), the coins are hidden and Suds's bubble is squeezed (picture 01). On a real phone the OS should keep landscape, so this needs a phone check |
| #625 side buttons in the wash | PASS. The whole SideButtons row (7 buttons, 16,14 to 434,64) is hidden during the wash, so the title "Step 1 of 4 · Scrub the mud" (271,6 to 479,25) is clear (picture 04) |
| #627 Day 2 | PASS. "Good crate" on one line (63x14 text in an 82x15 label, picture 05) |
| #623 tap through a window | PASS. With the crate window or check-in card open, ProximityPromptService is off and a tap where a board pill was fires nothing |
| #623 overlapping pills, no window open | FAIL. With the Tools board behind the crate, "Buy Pro Brush" (472,258) sits on "Look inside" (469,266). A tap on Look inside bought the Pro Brush (120 coins). On 4c36fed the Silk bow pill overlapped Look inside too |
| New: Take cat hidden by Look inside | FAIL. At the door with crates held, "Take cat" (enabled, 5.3 studs) showed no pill while "Look inside" (5.0 studs) did. Both use E. I had to step to (-7.3, -23.3) to get the Take cat pill |
| #624 toast queue (2526f2b) | PASS. "New in the Cat Index" showed 2.5 s, then "Quest done: Get 3 stars on 20 cats! +300 coins" 5 s |
| #624 one summary toast (4c36fed, PR 632) | PASS. A special visitor finishing 3 quests gave one toast: "2 quests done! +600 coins. Every weekly quest done! A crate is yours". It showed 2.6 s because another toast was waiting |
| #571 leaves (PR 632) | PASS. 6 heart-bar leaves: the leaver is the walk-off copy only, the line never shows fewer than 3, and the newcomer is drawn first (4 figures for a moment) |
| #571 worker takes | 7 of 8 takes swap in the same frame (3 to 3). One (Bea at 111.80) showed 2 for 1 frame (20 ms) before Theo appeared |
| #628 newcomer early (PR 632) | PASS. The newcomer waits at the back (z -39.5) until the step-up, 1.2 s after the leave. Then they walk in together, and line bodies never come closer than 1.63 studs |
| #570 copy vs line (bodies) | PASS. Min 1.69 studs |
| Crate rows (PR 631) | FAIL (text). Both rows show on one phone screen under "More crates" (card 702x322 in 750x332), beside the full chance list. But the price text is wider than its 68 px button: "399 Robux" is 81 px, "99 Robux" 67 px, and both run past the button edge (picture 02) |
| Crate rows, restricted | PASS. TestPaidRandomRestricted = true: CrateShop went to nil and the "More crates" rows vanished. The 8 chances and the footnote stayed (picture 03). Cleared: back to true |
| #634 saved pet at join (2526f2b) | FAIL there (Pet_player set, no pet). Fixed in PR 637, see below |
| Pets at join (7e1710e, PR 637) | PASS. Nimbus (player), Koi (player2) and Cozy (Jo1) all appeared 1.61 s after the client started, in the same frame as the character |
| Pets after a reset | PASS. The new character came 5.27 s after Health 0. Cozy was beside the new root at once, Nimbus 0.11 s later, Koi 0.16 s later, all within 5 studs |
| Pet positions | Nimbus right-behind (2.4, 1.2), Koi left-behind (-2.4, 1.2). Question: Jo's Cozy sits right behind the player (-0.1, 1.9), not by Jo's station. In this seed Jo has no station placed |

## askQueue, fresh save with 1,500 coins (client clock, play is about the same)
| Time | Ask | How long | Notes |
|---|---|---|---|
| 28.5 | Tip line "2 / 3 Wash him" | 3.7 s | tutorial |
| 50.6 | Recap "Meet Suds!" | 2.2 s | |
| 53.5 | Bubble "Let's open the spa!" | 2.9 s | |
| 56.4 | Bubble "First customer!" | 6 s | closed as the stray went in |
| 87.5 to 92.6 | Toasts: Cat Index, Resident stamp, "+10 coins" | 2.5 s each | queued, one at a time |
| 91.8 | Bubble "New soap!" (Show me) | 178 s | stays until tapped, and blocks the queue |
| 271.3 | Bubble "Let's build!" (Show me) | 25 s | came 1.1 s after I closed New soap. Stays until tapped |
| 297.7 | Check-in card | 17 s, closed with X | ready since about 3:45, it waited until the bubbles were gone, then came 1.7 s after the screen was free |
| 360.5 | Bubble "Quests!" | about 60 s | only 45 s after the check-in closed |
| 438 to 520 | Wash of a customer | | no ask during the wash |
| 523 | Recap card | left open | no ask over the recap |

- Never two modal asks at once: PASS (toasts overlapped a bubble, but toasts are not modal).
- Nothing covered the wash: PASS.
- FAIL: Suds's bubbles are not on the queue yet. A "Show me" bubble never times out, so an untouched "New soap!" held the check-in back for about 75 s past its ready time. The "Quests!" tip came 45 s after the check-in closed, inside the 60 s gap.

## Console
Nothing new: only the known lines.
