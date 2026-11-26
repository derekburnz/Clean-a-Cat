# Shop, Starter pack, pets, benchSave and Robux crate on 82d508a

- Build: main at 82d508a (PRs 616 to 620 merged), built with rojo and opened as an unsaved local place, one client. Never saved or published.
- Devices: iPhone 13 frame (844x390, touch only) and the iPad 10th generation preset. R15.
- Switches: every key in LiveFlags.OFF_BY_DEFAULT on except toolCursor, streetLoadTest, exampleFeature, openingReplay and benchGrow. That includes passes, starterPack, crateShop, benchSave, pets, petsWindow, crateWindow, quests, checkinCard, lineReuse and tipJar.
- Seeds, made in the local place only:
  - SaveSchema defaults: play time 11:40, 5 stars, 5,000 coins.
  - One pet: Nimbus, star 3, beside the player.
  - starterEndsAt set to now + 150 s for the timer run.
  - A saved bench for the benchSave run.
- Mock prices: Studio reads no pass prices here, so I set the ReplicatedStorage attributes by hand. PassPrice_GoldenSponge 199, SecondPetSlot 149, DoubleCoins 249, SecondBuilder 299, Lou 399, and ProductPrice_StarterPack 399.
- Not run: the fixes for issues 623 to 628 were not on main, so the crate-window tap recheck (623) and the rechecks of 571, 609, 624, 625, 626, 627 and 628 were skipped.

## Results
| Check | Result |
|---|---|
| Starter saving | PASS. Items 199 + 149 + 249 = 597 Robux, pack 399. The window shows "597" struck through and "Bundle · save 33%": (597 - 399) / 597 = 33.2%, shown as 33% |
| Starter window, iPhone 13 (picture 03) | Fits: card 570x255 at 90,44 in 750x332. Prices "199 Robux" etc. are 78 to 82 px wide in 135 px boxes. "399 Robux · Get pack" is 181 px in a 225x48 button. Nothing clipped |
| Starter window, iPad (picture 02) | FAIL. Card 828x486, fits, prices fit. But each item's description is cut to one line ("Gold bubbles, +20% on", "One more pet for you and", "Double coins on cats you") |
| Starter timer | PASS for real time and gone at zero. StarterEndsAt counted down 1 s per second, and at 0 the Starter button disappeared and stayed gone (watched 20 s more). A fresh offer is 72 h from first join (259,128 s left at join) |
| Starter timer text | Question. The window shows "Ends in 1m" or "Ends in 2d 23h", with no seconds, although StarterViewRules says seconds only inside the window. The HUD chip shows "3d 0h" while the window shows "2d 23h" (picture 02), and the chip shows "1m" right down to 1 s left |
| Never restarts | Not testable here: a local place cannot rejoin the same save |
| Shop, iPhone 13 (picture 01) | FAIL. Card 702x252 fits. Prices fit: 78 to 82 px wide in 120x44 buttons. But the descriptions are cut to two lines: "Double coins on cats you wash by" (no "hand"), "Gold sponge, +20% on hand" (no "washes"), "A third helper with his own" (no "stand"). Names are 14 px |
| Shop, iPad (picture 04) | PASS. Card 994x385, every description whole, prices fit |
| Side buttons | Seven now (Index, Pets, Gifts, Quests, Shop, Settings, Starter), reaching x 480 on the phone, so they cover more of the wash step title (issue 625) |
| Pets at 0.7 scale (pictures 05 and 06) | PASS. Nimbus star 3 beside the player, 1.25 x 1.55 x 1.45 studs, about 74x96 px on screen at the default camera. Glow pieces are tiny gold neon (0.07 to 0.11 studs, #f2b53a). The tail drop is sky neon 0.25 x 0.30 studs (#5ebeff), about 25 px wide close up. No light or particles. The face is not washed out |
| Pet shown at join | FAIL. With the pet already in the save, Pet_player = "Nimbus:3" was set but no pet appeared beside the player. It appeared as soon as the attribute changed (cleared and set again from the server). A returning player may not see their pet until something changes it |
| benchSave (PR 618), seeded save | PASS for the restore path. A save with bench Tux (dirt 3), Bathtile (special), Patches (dirt 2), Smudge (dirt 1) came back as Tux, Patches, Smudge in that order. The special was not kept. Same kinds, dirt drops and step counts on the cards (4, 3 and 2 steps, picture 07). All bars at 1.00 at the join, the second starting about 15 s and the third about 21 s in |
| benchSave real rejoin | Not testable: no DataStore in a local place, so I could not leave and rejoin |
| Robux crate policy (PR 617) | Server side PASS: CrateShop was true; with TestPaidRandomRestricted = true it went to nil, and back to true when cleared. But no client code reads CrateShop yet: the crate window has no buy row to show or hide, so the row test could not run. Odds text as before (chances 19 px, footnote 2 lines) |

## Console
Nothing new: only the known lines.
