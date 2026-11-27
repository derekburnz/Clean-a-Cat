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
