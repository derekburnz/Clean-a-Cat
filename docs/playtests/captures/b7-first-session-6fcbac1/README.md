# First session and B6/B7 rechecks (b5c4240, 6fcbac1)

- Builds:
  - b5c4240 (PRs 638 and 640 to 644): #609, #626, #635 phone Shop, #636, worker takes, staff rename.
  - 6fcbac1 (adds PRs 645, 647, 651, 652 and 653): the first-session timeline, gift stand, #648, #650, wash stands, iPad Starter.
- Each build was made with rojo and opened as an unsaved local place, one client. Never saved or published. iPhone 13 frame (and the iPad 10th generation preset), touch only, R15, real taps unless noted.
- Switches: every key in LiveFlags.OFF_BY_DEFAULT on except toolCursor, streetLoadTest, exampleFeature, openingReplay and benchGrow. That includes askQueue, landscapeLock, giftStand, visiting, friendBonus, staffRename, quests, checkinCard, crateShop, passes, starterPack, benchSave, lineReuse, tipJar, pets, petsWindow, crateWindow, workers and tubBuilds.
- First-session run: a fresh save with no seed, on the real play clock (the server's PlayerAdded time).
- Other runs: SaveSchema defaults edited in the local place only:
  - play 11:40, 5 stars, 5,000 coins, 2 crates;
  - on b5c4240 also Jo and Sam hired, bars times 0.5, and a starter end 200 s away.
- Mock prices: the pass prices, StarterPack 399, CrateOne 99 and CrateFive 399, set on ReplicatedStorage by hand.

## First session, fresh save (6fcbac1)
| Play time | Event | Stayed | Notes |
|---|---|---|---|
| 10.5 | Tip line "1 / 3 Pick him up" | 1.4 s | |
| 12.9 | Tip line "2 / 3 Wash him" | 3.6 s | |
| 23.2 to 32.0 | Suds's wash | | side buttons show (no step title here) |
| 35.0 | "Meet Suds!" card | 2.2 s | |
| 37.9 | Bubble "Let's open the spa!" | 6.0 s | goes by itself |
| 43.9 to 70.5 | Stray's wash, coins 0 to 10 | | |
| 70.5 to 75.6 | Toasts: Cat Index, Resident stamp, +10 coins | 2.5 s each | queued |
| 74.7 | Bubble "First customer!" (Show me) | 34 s | left when the customer's cat went in the tub, not after 20 s |
| 108.8 to 123.2 | First customer's wash, coins 35 | | Bubble Soap affordable from here |
| 126.2 | Recap card | 14 s | |
| 140.2 | Bubble "New soap!" (Show me) | 6.0 s | went by itself, 17 s after its reason (behind the recap) |
| 225 | Check-in ready | | waited for the wash and recap |
| 256.8 | Check-in card | 26 s, closed with X | 1.8 s after the recap closed |
| 360.1 | Quests button appears | | |
| 362.4 | Bubble "Quests!" | 20 s | 79 s after the check-in closed |
| 420.1 | Gift stand lit (GiftLit true) | | 7:00 |
| 442.9 | Bubble "A gift for you!" (Show me) | over 57 s, until I tapped Show me at 500 | 60.5 s after "Quests!" went |
| 500.4 | Gift card (from Show me) | | |

- Asks were always at least 60 s apart: PASS.
- No ask over a wash or a recap: PASS.
- New soap and Let's open went by themselves: PASS.
- FAIL: "First customer!" stayed 34 s and "A gift for you!" more than 57 s (picture 02). Bubbles with a "Show me" button still stay until something else ends them.
- "Let's build!" never came: coins reached 90 only at 8:20.
- The opening's two bubbles did not come together: "Let's open the spa!" at 37.9 s, "First customer!" at 74.7 s after the stray.

## Results
| Check | Result |
|---|---|
| Gift stand (6fcbac1) | On SpotGift at (-21.4, -21.8), by the side wall near the door, on the far side from the line. Stand 3.5 x 7.3 x 2.8 studs. Starcoat on the cushion at scale 1.00, 1.44 x 2.13 x 2.0 studs (full size) |
| Gift stand lamp | PASS for gold. Unlit at 6:50: SmoothPlastic #f2b53a, no light. Lit at 7:00 (GiftLit at 420.1): Neon #f2b53a plus a PointLight (#ffd696, brightness 1.0, range 9) |
| Lamp from the spawn | FAIL: about 3 px across on the phone frame from the spawn (picture 04), too small to read as lit |
| Gift card (picture 05) | Card 570x280 at 90,32, fits. Starcoat, Uncommon, three steps (Favourite, Join Creampuff Games shows "Done, welcome!" for the Studio account, Like) and a "Get Starcoat" button. Lines are 14 px |
| Gift claim without the favourite | The button is greyed with "One step to go". A tap gave no notice and no pet (no Pet_ attribute) |
| Gift claim with both | Not run: it needs a real favourite on the owner's account, which I did not do. The group step already showed done |
| #648 crate and pills (6fcbac1) | PASS. The held crate sits at (5, -18.5), right of the spawn (-5, -7). "Look inside" is on R, "Take cat" on E at the door. At 7 spots between the Tools board, the crate and the door, no two pills overlapped, and "Take cat" always showed near the door |
| #648 10 taps on Look inside | PASS. 10 triggers, all "Look inside". Coins 5,000 before and after |
| #650 crate prices | PASS. "99 Robux" 71 px and "399 Robux" 81 px text, inside 127x44 buttons |
| New: crate window taller than the phone | FAIL. With the rows the card is 702x360 in a 332 px root: its top is 11 px under the top bar and its bottom 17 px past the screen. The X's centre is at y -2, under Roblox's top bar (picture 03) |
| #609 Uncommon chip (b5c4240) | FAIL. "Uncommon" is 89 px of text in an 89 px pill. The text runs 7 px past the pill and 4 px past the card edge (picture 01) |
| #626 bubble with the strip (b5c4240) | PASS. "It's ready!" showed at y 151 to 226 while the recap strip was up (top 248), 22 px above it, and the strip stayed (picture 06) |
| #635 Shop on the phone (b5c4240) | PASS. All five descriptions whole, in 120x66 boxes (text 38 to 57 px tall, all fit) (picture 07) |
| #635 Starter on the iPad (6fcbac1) | PASS. All three descriptions whole, in two lines (197x38) (picture 08) |
| #636 chip and window | PASS. At the 3:00 boundary both turned within 0.1 s. In the last 95 s both read "1m" and both went at 0 (button gone, window closed) |
| #571 worker takes (b5c4240) | FAIL. With Jo and Sam working, 12 of 14 takes showed 2 figures for 1 frame (3 to 5 ms in Studio) |
| Wash stands (6fcbac1) | PASS. Hiring Jo (150 coins, tap) put CleanACat_Station_WashStandJo on SpotWorkerJo (-6, -3.5) and Jo's figure at (-7.5, -4.2). Jo took Muffin onto the stand at once and finished about 52 s later ("+3 coins: Pebble washed Muffin") |
| Staff rename | PASS on the server. RequestRenameStaff: "Bubbles  the   Great" became "Bubbles the Grea" (spaces collapsed, cut at 16). "" went back to the default. A renamed Jo showed in the toast as "Pebble washed Muffin". Studio's filter let "damn" through, so the filter cannot be judged locally. There is no rename field in the client yet |
| Visiting | Not drivable: it needs two clients. Server side locally: VisitorsAllowed = true, FriendsHere = 0 |

## Console
Nothing new: only the known lines.
