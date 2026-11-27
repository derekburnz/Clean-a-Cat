# Night checks 2026-11-27: 991, 884, 871 (counter and leave), 948

Unsaved local Studio places built with rojo from origin/main. Every off-by-default switch was on except toolCursor, streetLoadTest, exampleFeature and openingReplay. I used a seeded save with Jo and Sam hired, in the iphone_13 frame. I never touched dev or live.

## 991 recap, main 844315b: PASS
recap-991-nine-rows-iphone13-844315b.jpg shows 9 coin rows, two to a line. Next cat is 109 x 45 px, centre y 282.0, bottom 304.5. The total's centre is at y 282.0. The GUI area is 330 tall. The rows came from a PhotoPaid sent from the server with the uigate RecapRows values, after a real hand wash up to the photo step.

## 884 helpers fetch
- main 844315b: FAIL. helpers-884-fetch-lines-through-front-wall-844315b.jpg: every walk went to the server pivot of the CounterCat by the door, (-10, -35). Jo's straight line crossed ThirdTub.
- main 49f4f89 (PR 1009): helpers-884-route-49f4f89-lane-through-tools-board.jpg. Each stop is at its own place, 2.00 studs behind the cat, and the held cat stays on its mat (0.00 off it). The lane at x -6.0 crosses the CanCollide tools board (x -7.85 to -4.15, z -10.9, y 1.4 to 5.1). PR 1011 addresses this.

## 871 counter cats, main 208dc9d (PR 1008): PASS
counter-208dc9d-six-whole-cats.jpg shows every place at N of N parts on its mat. Newcomers showed 0 cat parts while walking in.

## 871 leave, main 7e033d1 (PR 1010): PASS
leave-7e033d1-kit-packed-cat-in-carrier.jpg: the PackedCat stays in the carrier, 1.47 studs from the leaving figure at every sample (Theo and Kit). On 208dc9d it was 16.4.

## 948 Stardust bows, main 208dc9d: PASS
Across 12 bow looks on Stardust_Sit and Stardust_Dirty_Sit, 0 bow parts overlap Prop or Prop2 (the wand).

## 884 close-out, main c2eeb78 (PR 1011): PASS
helpers-884-route-c2eeb78-clear.jpg: a top view with Jo in red and Sam in yellow. Both routes are (stand) > (x, -4.8) > (8.1, -4.8) > (8.1, -22.3) > (1.6, -22.3), with the lane between the player's tub and station 4. Each stop is at place 2's own spot: dX 0.00, dZ 2.60 behind the cat, 1.30 studs from the counter edge (z -23.60). Sweeping a 2 x 3.2 x 2 body box along every segment crossed nothing solid: no tools board, tub, stand or counter.

## 869 like how-to, main c2eeb78
like-howto-869-c2eeb78-desktop.jpg: after Like on the gift card, the how-to shows HeartOutline 98146759736466 (Thumb), TapDot 112847264343092 and the ring puff 113448726935917. All three report IsLoaded true and draw. A fresh PreloadAsync returns Failure while the account is suspended (403), so that result is NOT CONCLUSIVE. No hand images. The heart showed pink in every sample; I saw no grey phase.

## 883 Clover and Glitch portraits, main c2eeb78: PASS
portraits-883-pets-menu-c2eeb78.jpg and portraits-883-good-crate-c2eeb78.jpg: Clover 77963078642728 and Glitch 80341127367421 report IsLoaded true and FetchStatus Success in the Pets menu (73 px) and in the Good crate chances (62 px). Both draw in full colour. The save was seeded with one of each.

## 869 rerun, main fb23dab (PR 1013): PASS
HowTo.Art holds the frames Outline, Filled, Ring and Tap. No frame is named Hand, and all four images report IsLoaded true. Sampling every 0.1 s over 4.1 s gave grey 0.0 to 0.2, pink 0.3 to 1.4, grey 1.5 to 2.3, pink 2.4 to 3.5, grey 3.6 to 4.1. That is one loop of about 2.1 s with grey about 0.9 s and pink about 1.2 s, and exactly one heart showing at every sample (like-howto-869-fb23dab-loop.jpg). With the game's Less screen shake set On before tapping Like, all 31 samples were pink, and the tap dot and ring never moved (like-howto-869-fb23dab-reduced-motion.jpg).

## 773 dev look, main fb23dab
- Frame rate, iphone_13 (749 x 388), bigSpa and wideStreet on, standing behind counter place 3 with six customers: 235.1 fps average over 1411 frames (PC cap 240), worst frame 14.6 ms, 213 draw calls, 290,294 triangles, quality 21. A real phone is not tested.
- Bows on plain cats (BowFit.wear at scale 1.5): Muffin and Toffee with Pink, PinkDouble, PinkGolden, PinkRoyal, Mint and SkyRoyal. Every bow sits on the head's top corner: centre at x -0.56 to -0.67 against a head half width of 0.66, and y +0.35 to +0.63 against a half height of 0.74 to 0.82. None touches the eyes, body, legs or tail. The Golden and Royal looks are centred on the head's edge, so about half the bow overhangs the side of the head (dev-look-773-bows-muffin-golden-toffee-royal-fb23dab.jpg). Display window and walk-out: not tested in this run.
- Faces (dev-look-773-faces-toffee-dirty-moonstag-suds-fb23dab.jpg plus the bow picture): Muffin, Toffee, Toffee dirty, Suds and Moonstag (special) all show round pink cheeks. No bar at the eyes, and no brown block under Toffee's nose (Toffee has a white muzzle). Moonstag's blue stripe between the eyes is its coat marking.

## 40 and 531, fresh save, main fb23dab (desktop frame; the iphone_13 simulator mirrors every click, so taps were done at desktop size)
Times from the join:
- 0:18 the truck arrives and the box lands. The console logged "[Opening] truck moving 0.34 s after the join".
- 0:36 box opened with E, then "1/3 Pick him up"; Suds picked up.
- 0:48 walk to the tub (path, 4.1 s).
- 1:04 Suds in the tub, 3 steps. Scrub and brush were finished with the Studio test hook; the photo was a real click.
- 1:39 "Meet Suds!" (3 stars), Open the spa: Suds kept.
- 2:39 the first cat after Suds was the stray Muffin. Bow dragged, photo, it moved into the window (dev-look-773-window-bow-muffin-fb23dab.jpg).
- 3:20 first counter customer, Cotton, served. Recap +286, including the Grand opening gift +267 (loop-40-first-customer-recap-fb23dab.jpg).
- 4:00 Bubble Soap bought at the tools board, 30 coins.
- 4:11 Second Tub started from the build board, 60 coins.
- 5:04 customer Patches served. The wash now has 5 steps, the extra one from Bubble Soap.
- 6:11 customer Cotton served. Coins 279.

Not reached in a fresh save: Brush Table and dryer (not on this build board), the VIP Room (15000 coins and the Third Tub first). One Take attempt right after closing a recap found no prompt in reach; a retry worked. Rejoin, timers and DataStore are not testable in a local place.

Console (531) from our scripts: no errors. The only lines are local-place limits: ProfileStore and DataStore unavailable, and NotifyService line 54 "You must publish this place to use MemoryStoreService" (twice). Outside our scripts: "rbxassetid://203785492 failed due to: Asset type does not match requested type" (3 times). That id is not in the repo; it is most likely the Studio test avatar.

## 773 bow on, main fb23dab
In the display window, Muffin wears its bow on the head's top corner (WornBow under the head). During a served customer's walk-out I saw no PackedCat with a bow: served cats go home through the tub's going-home effect. Not conclusive for the carrier walk-out.

## 1021 noVisitBoard, main 1f2895a: PASS
no-visit-board-1021-1f2895a.jpg: the area by the build board and the gift stand, where the "Who might visit" board stood, now empty (0 ChanceBoard instances). Turning the switch off brings the board back within 2 s.

## 1022 counterSlim on iphone_13 (749 x 388), main 1f2895a: FAIL on size from the normal camera
Camera held at the default follow position: 12.5 studs behind the player, 20 degrees up, FOV 70, facing the counter. Each bar's edges were projected with WorldToViewportPoint.
- From the spawn (-5, -7): bars measure 16.8 to 21.6 px wide and 3.2 to 4.1 px tall, with gaps of 2.0 to 7.7 px (counter-slim-1022-from-spawn-iphone13.jpg).
- From the door line (-6.3, -22.5), looking along the counter: bars measure 19.2 to 36.0 px wide and 3.7 to 6.9 px tall. Neighbours overlap on screen by 15.7 to 21.0 px, because the row runs away from the camera (counter-slim-1022-from-door-line-iphone13.jpg, with the bars drawn in pink).

## 1024 rewardPop, main b92db46, iphone_13
reward-pop-1024-crate-nebula-iphone13-b92db46.jpg: opening a good crate shows "You got Nebula!" in the middle, with the Nebula portrait on gold rays, "Rare, +12% on your tips" and "Tap to close". The screen is dimmed behind it, and it closes by itself within a few seconds. Two look notes: the dim covers only the area below the 58 px top inset, so the top strip stays bright; and the tutorial hint card ("Bring the cat to the tub") and the starter ad draw on top of the dim, with the hint card covering the area under "Tap to close".

## 1040 bigger spa, main b92db46 (the sha published to dev at 12:16 UTC, with bigSpa on in dev)
big-spa-1040-room-wide-b92db46.jpg, roof hidden. I checked this in a local place built from that sha, not on a dev server. CleanACat_Area_SpaPlotBig is placed. The walls give an inside room of 48 x 32 studs: walls at x -29.5 and 19.5, z -26.5 and 6.5. The player's tub (CleanACat_Station_Tub) is 1.30x its pre-PR-922 size (rbx model bounds 4.49 -> 5.84 wide). The wash stands are Jo 1.35x (5.89 -> 7.96), Sam 1.35x (4.00 -> 5.40) and Lou 1.35x (4.55 -> 6.14). The counter window (CleanACat_Area_SpaPlotBig_Counter, 20.8 x 2.8 x 4.1) is there, with six customers at it.

## 1039 and 1043, main 6f4569d
- Reward popup layer, PASS (reward-pop-layer-1039-ooze-iphone13-6f4569d.jpg): RewardPopLayer is its own ScreenGui with DisplayOrder 45 (the HUD is 0) and IgnoreGuiInset true. The dim now covers the whole screen, top strip included, and the hint card and starter ad sit under it.
- menuOnly: there are no Hire, Takes, Buy or Build prompts in the world, and no hire pads. The only live prompts are Free gift, Look inside and Take cat. The Build window has every build and upgrade with its Build or Buy button (menu-only-1043-build-window-6f4569d.jpg). RISK: with no helper hired yet, the HUD's Helpers button is hidden (SideButtons shows it only once a WorkerLevel_ attribute exists), and the More tray and the Build window have no hire either. So the only way to the Helpers window is the one-time hireJo guide card. If that card is closed or missed, a new player cannot hire Jo.

## 1046 Helpers button once Jo is affordable, main 79d7c5b (menuOnly and joPrice on, no helper hired)
- At 250 coins: HelpersOpen nil and the Helpers button hidden. PASS.
- After two hand washes, coins 273 and then 318 (Jo costs 300): HelpersOpen true and the Helpers button showing. PASS.
- In the Helpers window (helpers-1046-window-no-hire-button-79d7c5b.jpg): FAIL. Jo's and Sam's rows read only "Washes cats for you", with no price and no Hire button, so Jo cannot be hired. It is the same after closing and opening the window again. HelperViewRules marks the row with hire = true, but HelpersWindow.luau never reads row.hire or hireText, so no button is drawn.

## 1035 petSingles, main 5873817: PASS
pet-singles-1035-5873817.jpg: a save seeded with Clover (1 star) twice and Glitch (2 stars) shows three tiles, one per pet. The two Clovers are separate tiles with no stars, and Glitch shows two stars.

## 1041 expansionDoor, main eafb264
- The unlock logic passes. "Unlock · 1500 coins" (object text "Back door", hold 0.3 s, reach 10) sits at (7, 3.5, 6.5). Holding it took coins from 60000 to 58500, set ExpansionUnlocked true, and removed the prompt.
- FAIL, models missing. The console says "[StationService] CleanACat_Area_BackDoorLocked is missing from ReplicatedStorage.Assets", and CleanACat_Area_BackDoorOpen is missing too. While "locked" the doorway is a plain open gap with no caution tape or barrier (expansion-door-1041-locked-but-open-eafb264.jpg), and a path from inside the spa to behind the door computes as Success, so a player can walk through without paying.
- Not tested: the Garden showing only behind the open door, and an old save with the Garden built counting as unlocked.

## 1034 stand-ins, main 69b9548 (PR 1054): FAIL, every picture is swapped for its stand-in
stand-ins-1054-every-icon-swapped-69b9548.jpg: the HUD and Pets window show emoji stand-ins (a store, a hammer, a person, a cat, plain coin circles) in place of the real pictures, and Clover's portrait is a cat emoji. PlayerGui holds 0 ImageLabels with an rbxassetid image, even though GetAssetFetchStatus for Clover's id reads Success. Cause: Icons.onFail calls ContentProvider:PreloadAsync({ image }) with the bare id string. For image ids that always reports Failure (I saw this on every id this morning: string form Failure, ImageLabel form Success), so every picture is marked failed and swapped. Fix: preload the label itself (PreloadAsync({ label })) or watch label.IsLoaded. The empty pet slots' green "+" badges show and work as designed.

## 1056 Hire button and 1057 back door, main cbdcdb6
- Hire (menuOnly, no helper hired, 60000 coins), PASS (hire-button-1056-cbdcdb6.jpg): Jo's row shows "Hire · 300" and Sam's "Hire · 1200". Tapping Jo's took coins from 60000 to 59700 and set WorkerLevel_Jo 1. The row turned into "Takes: First in line" and "Level up · 200", and Jo stands in the world. (The emoji stand-ins in the picture are PR 1054's bug.)
- Back door locked look, PASS (back-door-locked-1057-cbdcdb6.jpg): BackDoor holds 81 parts (caution tape X, sawhorse, planks, paint pots). CleanACat_Area_BackDoorLocked_Barrier (5.5 x 12.0 x 2.9, CanCollide true) fills the doorway, and a ray through the doorway hits it. The shortest path from inside to behind the door is 119 studs round the outside, not through the doorway. Smallest gap from the building site to the stray box spot is 7.20 studs, and to Sam's stand spot (1, 0.5, 2.5) 3.43 studs.

## Revert 1059 (main a7da269) and PR 1060 head 880d0cb2
- Revert, PASS (revert-1059-pictures-back-a7da269.jpg): real HUD art again, with 105 rbxassetid ImageLabels in PlayerGui after 30 s.
- PR 1060 at 880d0cb2, PASS. Real ids stay pictures: 105 rbxassetid ImageLabels after 30 s, and Shop, Build and Helpers keep their images (pr1060-880d0cb-real-icons.jpg). With Icons.IMAGES.Build set to rbxassetid://1 in the local copy (fetch status Failure), only Build swaps to its 🔨 stand-in. Shop and Helpers stay pictures, with 98 rbxassetid ImageLabels left (pr1060-880d0cb-bad-build-id-stand-in.jpg).

## 1041 unlock, 1057 open look and 1056 Reset my game, main a7da269
- Unlock, PASS with every window closed. Standing 6.0 studs from SpotGardenDoor, E on "Unlock · 1500 coins" took coins from 60007 to 58507 and set ExpansionUnlocked true. On cbdcdb6 it would not fire while the Helpers window was still open, because the HUD hides prompts under an open window.
- Open look, PASS (back-door-open-1057-a7da269.jpg): BackDoor now holds CleanACat_Area_BackDoorOpen. A ray through the doorway hits nothing, and the path from inside to behind the door is 13.0 studs straight through (it was 119 studs round the outside while locked). The door leaf (5.9 x 8.9 x 0.4) stands at (12.9, 5.0, 7.1), swung about 180 degrees flat against the yard side of the wall, clear of the doorway.
- Reset my game, PASS (reset-confirm-1056-a7da269.jpg): the red "Reset my game" button at the bottom of Settings turns into "Tap again to wipe it all" on the first tap, with coins unchanged. The second tap shows "Resetting..." and the server drops the player (Players 0).
- Not tested: the Garden behind the open door, and an old save with the Garden built.

## 1062 right arm out at the counter, main 41da07f (desktop, seeded save, every switch on)
arm-out-1062-from-behind-41da07f.jpg: the three customers standing at the counter, after setting their crates down, all hold the right arm out while the left hangs straight.
| figure | ArmsStraight | CarryArmDegrees | CarryArmOut | CarrierHidden | carrier parts showing | ArmR off vertical | ArmL off vertical |
|---|---|---|---|---|---|---|---|
| Sunny | true | 32.4 | 32.4 | true | 0/188 | 32.4 | 0.0 |
| Mo | true | 19.6 | 19.6 | true | 0/213 | 19.6 | 0.0 |
| Pip | true | 27.1 | 27.1 | true | 0/193 | 27.1 | 0.0 |
The carrier is hidden and CarrierHidden is true, yet ArmR stays turned out by exactly CarryArmOut. CustomerMotion.armIn should turn it back in by that much, so it is not being applied on this client.

## PR 1064 (issue 1062), main f701af9: FAIL, arms still out
customerWalk is on (CustomerMotion enabled) and the ArmR joint is recognised. Sampled every 0.2 s for 150 s, 18 customer figures at most at once.
- Standing customers with no carrier showing (CarrierHidden true), near (8 to 59 studs) and far (60 to 95): Sunny's ArmR stays at 32.4 degrees, Rae's at 21.5 and Juno's at 21.5. That is exactly their CarryArmOut, never 0. 2139 failing samples.
- Walking customers with a carrier showing, 67 to 76 studs away: Juno at 21.5 degrees and Pearl at 32.4, so the arm stays out there as it should. The arm-to-leg gap measured -0.47 and -0.70 studs (my sideways estimate, so they may touch).
- Not reached: a leave with a PackedCat (no heart ran out in the window), and a figure-budget effect (the arms are out for every figure anyway).

## 1063 noVipRoom, VIP door fill and tape, main 61dff0a (seeded save with stations.VipRoom = true)
- The VIP doorway at SpotVipDoor (-12, 0.5, 6.5) is filled by CleanACat_Area_VipDoorFill (8 x 9.05 x 1, 11 parts). From inside (vip-door-fill-1063-inside-61dff0a.jpg and the room view) it reads as plain wall with the teal dado, the pink skirting and a framed paw print. From outside (vip-door-fill-1063-outside-61dff0a.jpg) it is plain grey wall over the pink band. The back wall shows only the expansion door.
- The VIP Room is gone from the Build window (Second Tub, Third Tub, Fourth Tub and Garden under Builds; Bubble Soap, Pro Brush and Silk bow under Upgrades). No VIP prompt or VIP text remains in the world.
- The back door tape and building site have no pink. The visible part colours are #fff6ec, #fff9f2, #f2c14e, #f09640, #a8e6cf, #8fd3fe, #f6dfa0, #363c4c, #e3c49c, #a9afb8 and #c98a4b (0 pinkish parts).
- Refund: coins went from 60000 to 75003 at join (+15000, plus 3 from Jo). The notice had gone by the time I read the GUI, so I did not see its text. A second join cannot be tested here, since a local place has no DataStore.

## 1038 windowClear and 1065 round fills, main e0ebe2f
- Badge rects (GUI px, measured on each window while shown):
  - iphone_13 (749 x 388): Helpers band (52,58 645x38), badge (61,62 28x28), first row at y 98. Shop band (24,91 700x42), badge (33,95 33x33), first at y 139. Pets band (24,58 700x42), badge (33,62 33x33), first at y 106. Settings band (37,58 675x42), badge (46,62 33x33), first at y 104.
  - ipad_10th_generation (1179 x 819): Helpers band (175,221 829x66), badge (186,227 55x55), first at y 300. Shop band (92,292 995x66), badge (103,298 55x55), first at y 373. Pets band (83,150 1013x66), badge (94,156 55x55), first at y 231. Settings band (304,217 570x54), badge (314,222 45x45), first at y 280.
  - In every case the badge sits inside the band and clears the first row.
- HUD: with a window open, Shop, Build, Helpers and More are all hidden. They come back when it closes (checked on Helpers and Check in on iphone_13, and Helpers on the iPad).
- 1065: the Settings fills have UICorner 0.5 and full round ends at Music 5% (22 x 17 px fill, radius 8.3) and Sounds 92% (422 x 17 px). The Cat Index bar at 10% is 8 x 15 px with UICorner 0.5, so its ends are round too.
- Pictures: window-clear-1038-helpers-iphone13, window-clear-1038-checkin-iphone13, window-clear-1038-helpers-ipad and sliders-1065-ipad-5-and-92-percent (all -e0ebe2f.jpg).

## 1062 arms on PR 1082 (3f41199), 2026-11-27

- `1082-line-behind-arms-straight.jpg`: the line from behind with each carrier hidden (CarrierHidden). Every right arm hangs straight.
- `1082-counter-follow-cam.jpg`: the follow camera at the counter, where the client numbers were taken.
- Client numbers (sampled every 0.1 s for about 5 minutes):
  - Every customer reads MotionRig "rig ArmL ArmR Head LegL LegR".
  - ArmR stays at 0 to 2 degrees while hidden, apart from the 0.7 s crate reach.
  - Walking with a carrier, the arm stays out at CarryArmOut.
  - LegL swings 0 to 26 degrees on walk-ins.
  - PackedCat leaves FAIL. Bea's arm turned out only 15.2 of 35.5 degrees. Theo's stayed at 0 of 19.6.

## Starter pack HUD card (1069, 1080) on main 29e9249, iphone_13, 2026-11-27

- `1080-card-see-the-pack-iphone13.jpg`: the dark plum card with no price known locally. It shows one big sponge on a gold glow, the round "i" and no time chip.
- `1080-card-199-robux-iphone13.jpg`: with ProductPrice_StarterPack set to 199 by hand, the price reads "199 Robux" in light green. Contrast is 7.8 against the top of the plum and 11.3 against the bottom.
- `1080-info-window-new-player-offer.jpg`: the "i" opens the Spa Starter Pack window, and its band says "New player offer".

## Menu contrast, menuContrast2 (issue 1029) on main 52dfced, iphone_13, 2026-11-27

`1029-<window>-iphone13.jpg` covers Shop, Build, Helpers, Check in, Pets, Cat Index, Settings, Quests, Crate and the Starter window, each opened by a tap.
- Every window has the panel DCC8F2, white cards and ink edges (45226B).
- No INK_SOFT text and no plain cream fills are left.
- Body text is ink: 8.0 to 1 on the panel and 12.4 to 1 on white.

## Cat Hotel and side Garden (1049, 1050, 1051) on main 1f4f9c1, desktop frame, 2026-11-27

The `hotel-*.jpg` pictures show the side Garden's three looks (locked, building, built) next to the hotel at the back door, on the normal plot and with bigSpa:
- `normal-garden-pets` shows the three pen pets in the built Garden.
- `normal-hotel-inside-room2-booked` shows room 2 with a guest booked, its 59m bubble showing.
- `big-hotel-roof-join` shows where the hotel roof meets the big spa's roof eave.
