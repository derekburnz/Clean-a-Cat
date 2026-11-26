# Coin flow and B8 recheck (2a34a8e)

- Build: main at 2a34a8e (PRs 654, 661, 662 and 663), built with rojo and opened as an unsaved local place, one client. Never saved or published. iPhone 13 frame, touch only, R15, real taps unless noted.
- Switches: every key in LiveFlags.OFF_BY_DEFAULT on except toolCursor, streetLoadTest, exampleFeature, openingReplay and benchGrow. That includes askQueue, landscapeLock, giftStand, visiting, friendBonus, staffRename, quests, checkinCard, crateShop, passes, starterPack, benchSave, lineReuse, tipJar, pets, petsWindow, crateWindow, workers and tubBuilds.
- Part 1: a fresh save with no seed, on the real play clock (the server's PlayerAdded time).
- Part 2: SaveSchema defaults edited in the local place only: play 11:40, 5 stars, 5,000 coins, 2 crates, Jo and Sam hired. Mock prices set on ReplicatedStorage by hand (passes, StarterPack 399, CrateOne 99, CrateFive 399).

## Part 1: fresh save
| Minute | Coins |
|---|---|
| 1:00 | 11 |
| 2:00 | 36 |
| 3:00 | 61 |
| 4:00 | 67 |
| 5:00 | 123 |
| 6:00 | 128 |
| 7:00 | 162 |
| 8:00 | 181 |
| 9:00 | 191 |
| 10:00 | 231 |

- Gains: stray +10 at 59.0; customer +19 at 117.7; customer +19 at 174.6; check-in +50 at 297.0; special visitor +28 at 366.4; stray +10 at 461.9; special visitor +28 at 569.3; window cats +1 or +2 every 10 s. No spends.
- First affordable: Bubble Soap (30) at 117.7, Second Tub (60) at 174.6, Pro Brush (120) at 297.0, Jo and the Silk bow (150) at 366.4.

| Play time | Ask | Stayed |
|---|---|---|
| 127.6 | Bubble "New soap!" | 6.0 s, by itself |
| 193.7 | Bubble "Let's build!" | 20.0 s untouched |
| 274.0 | Check-in card | claimed and closed at 296.9 |
| 383.7 | Bubble "Quests!" | 6.1 s, closed when the next wash began |
| 466.4 | Bubble "A gift for you!" | 20.0 s untouched |

- "Let's build!" came after the second customer (the fourth cat), at 3:14, earlier than the expected 5:30.
- The gift bubble waited for a wash that ran over 7:00 and came 4.6 s after it ended.

## Part 2: seeded save
| Check | Result |
|---|---|
| Second Tub buy | Tapped the "Build Second Tub" pill at 852.4: 5,012 to 4,952 (-60). Built 15 s later (Built true). Then 880 4,955, 940 4,960, 1000 4,971, 1060 4,971, 1120 4,978, 1180 4,988, 1240 4,992, 1300 4,995, 1360 5,005. Only worker wash coins came in, no other spends |
| #658 crate window height | PASS. The card is 701x301 at 24,18 in the 750x332 root (screen 390 with the 58 px top bar), so 31 px spare. Its top is 18 px below the top bar, its bottom 13 px above the screen edge (picture 01) |
| #658 X | PASS. Centre at 716,27, under nothing. One real tap closed the window |
| Crate text sizes | FAIL. On screen (TextSize times the 0.75 scale): "99 Robux" and "399 Robux" 12.7 px, "1 crate" and "5 crates" 13.5 px. Everything else 14.2 px or more (boosts, rarity tags and the footnote 14.2, names 15.7, chances 19.5) |
| #609 Uncommon in the crate list | FAIL. "Uncommon" is 89 px in an 85 px pill, 4 px over (about 2 px each side). "Legendary" 85 px in 82 px, 3 px over (picture 01) |
| #609 Uncommon on the queue card | FAIL. The chip shrinks the text to 18 but "Uncommon" is still 89 px in an 89 px pill. With the side room the words end 7.5 px past the pill and 4 px past the card edge (picture 05). No Uncommon customer stayed in the line (Jo and Sam took Patches and Tux), so I drew this card by sending the client a CustomerQueue list of Cotton, Tux and Patches |
| PR 654 rename field | PASS. Jo's pencil opens "Name Jo" with Jo as placeholder. Typing "Captain Bubbles the Great!!" kept "Captain Bubbles " (16). Enter saved "Captain Bubbles" (StaffName_Jo) and the Pets row changed. An empty box and Save went back to "Jo". Sam renamed to "Sudsy Sam" showed in the toasts ("+3 coins: Sudsy Sam washed Inky"). There is no toast for the rename itself, as the PR says |
| Rename card note | FAIL (small). "Up to 16 letters, numbers and spaces. Names are checked before anyone sees them." is cut after "Names are" (TextFits false, picture 02) |
| Spa sign | Not part of PR 654: the sign shows the player's own name, not a helper's |
| #571 worker takes | 12 clean takes (832 to 1332 s). In every one the taken customer is at place 3 (the door customer and the special stay). The taken figure goes, and the newcomer appears 3 to 5 ms later, so the line shows 2 for 1 frame. There is no extra figure any more, so none of (a), (b) or (c). LineLeaving was never set on a taken figure |
| Heart-bar leave (for contrast) | At 1353.0 the special (Vivi) left: LineLeaving true on her, the newcomer drawn first at the back (4 figures for 26 ms, two with place 3 at different spots) |
| #659 gift lamp | FAIL. Still a 0.4 stud neon cube with a light (range 9, brightness 1.1): about 4 px across at 28 studs from the spawn. PR 662 added a pink balloon on a string, 48x76 px from there, which is easy to see (picture 04) |
| New: the view from the spawn | FAIL. At the join on the seeded save the whole screen was light blue (picture 03). The camera sits inside CleanACat_Area_SpaPlot_Decor (0.18 x 3.5 x 3.5 studs, #a8d8f0, CanCollide false) on the wall behind the spawn, at (-5, 6.8, -0.09). The camera does not push in front of it because it does not collide. Walking forward fixes it |

## Console
Nothing new: only the known lines.
