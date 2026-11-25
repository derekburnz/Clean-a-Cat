# Bug hunt passes A and B on b504978

- Build: main at b504978, built locally and opened in Studio as an unsaved place. One client.
- Devices: the iPhone 13 frame (844x390 picture, 750x390 viewport) stands in for the iPhone 12. The iPad is the 10th generation preset.
- Rigs: R15 first, then one R6 run of the carry steps.

## Switches
The repo does not record the dev copy's switch values: they live in the dev DataStore (flags workflow). So I copied LiveFlags.OFF_BY_DEFAULT exactly and turned every key on except four:
- Off for the whole run: exampleFeature, streetLoadTest, openingReplay and toolCursor.
- On: scrubPrototype, scrubEffects, revealEffects, fluffEffects, catMotion, dryEffects, toolsBoard, customers, strays, catIndex, builds, spaPlot, onboardingFunnel, scrubTurn, longBuildOffer, spaVisitors, stations, customerFigures, scrubFeel, comfortSettings, springUi, spawnView, queuePick, gameHud, recapCard, settingsCard, catIndexWindow, queueWindow, tutorialDim, tutorialTip, tutorialTrail, windowsHideControls, sudsWash, sudsMascot, bubbleBath, pawdicure, proBrush, openingBox, carryHold, skyDraft, worldBackdrop, photoCamera, washView, smallPrompts, autoTool, toolOnCat, customerCarry, washScene, carryShared, sudsBubble, recapSide, washChecklist, spaSign, placeAfterHop, latherFoam, trailLine, townsfolk, customerWalk, washMeter.
- Pass B ran on a second fresh save with two changes, so the customer has every step: strays off, and the save seeded with BubbleBath, Pawdicure, Dryer and BrushTable built, with needs mud, tangles, wet, smell and claws.

## Pass A, first 5 minutes, fresh join and fresh save (iPhone, R15)
Times are seconds from the client script start. Pass A ran on the first fresh save, with no stations built and strays on.

| Beat | Time | Result |
|---|---|---|
| Truck moving after join | 0.28 s (console) | PASS, no loading screen (picture 01) |
| Opening shot camera | 1.62 s | PASS, but the camera reads Custom for one frame at 1.59 s before the shot |
| "Open!" pill on the box | 5.95 s | PASS, opened by a touch tap (picture 02) |
| "Pick up" after the box opens | 1.1 s later | PASS, lifted by a touch tap |
| Carry and the "Wash him" pill | 0.7 s after the lift | PASS, with a trail line on the floor |
| Place in the tub | tap on "Wash him" | FAIL, see bug 1 |
| Taught steps: Scrub the mud, Brush the fur, Take the photo | real drags, no test hook | PASS. Mud took about 22 s of dragging, and the brush finished in the same press |
| "Meet Suds!" card | 3 s after the photo | PASS |
| "Open the spa!" | camera back to the player 0.6 s later | PASS. "Let's open the spa!" shows after the camera is back, not under the card |
| First customer walk-in at the door | as Suds sits in the tub | PASS, 3 figures in the line |
| First cat after Suds | 6 s after "Open the spa!" | A stray (strays on), straight to the tub with no carry, as designed for strays |
| First payout | 250 s (about 4:10 into the session) | PASS, coins 0 to 10 at the stray's photo |
| First customer's "Take cat" | 3 s after the payout | PASS, with the "First customer!" bubble 2 s later |

## Pass B, one full customer (iPhone, R15, seeded save)
Step list shown: 1 Scrub the mud, 2 Brush the fur, 3 Swirl the suds, 4 Trim the claws, 5 Pick a bow, 6 Take the photo.

| Check | Result |
|---|---|
| Door: "Take cat" | PASS by touch tap. The customer leaves the line and the line refills to 3 |
| Carry the carrier's cat to the tub | PASS by touch tap, once standing about 1 stud nearer the tub (see bug 1) |
| Tub and scene | PASS. The step starts in the same frame, and the tub was empty before (the old cat was removed) |
| Scrub the mud and the wash meter | PASS, real drags. The meter read 100% at the start, then "Squeaky clean!" at 100% (picture 04); see note 3 |
| Brush the fur | PASS, real drags (5 strokes) |
| Swirl the suds (Bubble Bath) | PASS, real circular drags in one press |
| PR 492, claws after the bath | PASS, see below |
| Each paw clips after a new press | PASS. A 1.5 s press on each front paw clipped all 8 claws (8 to 0 visible) |
| Rinse, shake-off and dry | Not seen as separate steps. There was no rinse or dry step and no dryer view, although the cat had the "wet" need and the Dryer was built. The recap reads "Washed and dried". See note 4 |
| Pick a bow (Mint) | PASS by tap |
| Photo | PASS by tap |
| Recap pay lines | PASS. Washed and dried +10, Happy owner tip +2, Spa stations bonus +30: total +42. Coins went 0 to 42 (picture 06) |
| XP | The card shows "+1 star". I found no XP value on the player or in the HUD to check against |

PR 492:
- My input was still held down when the bath ended. I swirled in one press, and the step changed to "Trim the claws" while the finger was down.
- I did not fire CleanACat_TestStep at the claws step.
- While still held, all 8 claws stayed (none clipped) and the meter read 0% (picture 05).
- Moving the held finger 90 px after the step change turned the camera 0.0 degrees and moved it 0.00 studs.
- I could not make out a ring on a paw at this picture size, and found no Highlight or ring object to measure.

The test hook CleanACat_TestStep was used only where noted:
- for Suds's mud and brush in the seeded run and the R6 run (Pass A used real drags);
- for nothing in Pass B.

## iPad 10th generation (R15, picture 10)
- "Take cat" worked by a touch tap.
- I could not place the "Put in tub" pill exactly on the scaled iPad view (taps at x 604, 636 and 667 missed), so I placed the cat with E. This is a limit of my tap placement, not a game result.
- The wash scene, tick list and meter fit the screen.

## R6 run (iPhone)
- Suds lift by tap: PASS (picture 11).
- Carry and "Wash him" by tap: PASS.
- Customer "Take cat" by tap: PASS (picture 12).
- Reset while carrying: PASS. The cat is back in the arms 5.4 s after the reset.
- "Put in tub" by tap: PASS.

## Special cats (wash camera: tub seat, scale 1.5, normal spa lighting, field of view 50, 844x390)
- Stardust (PR 495, picture 07): PASS. Solid cream stars keep their shape. Neon is only small deep gems: rose, gold and sky, 0.11 to 0.23 studs at scale 1. The brightest neon reads 0.93 luminance with no white blob. Eyes against the plain navy face: 4.5:1.
- Sherbet (PR 497, picture 08): PASS.
  - Neon is deep pink #ff6b81: wing hearts with parts 0.15 to 0.17 studs on their largest side, plus the cherry at 0.23.
  - The brightest neon is 0.72, with no white blob. Eyes against the pink face: 7.6:1.
  - The 0.3 stud heart size in the brief looks like the heart's overall size; each part measured 0.17 or less.
- Jade (PR 497, picture 09): PASS.
  - Neon is deep gold #f2b53a: tail pearl 0.35 studs (the largest), spines 0.12, wing tips 0.11, plus two mint 0.24 parts.
  - The brightest is 0.93: the tail pearl reads as a solid gold disc, not white. Eyes against the green face: 3.6:1.

## Bugs and notes
1. S3: the prompt pill shows the wrong prompt at the tub. Standing 4.8 studs from the tub with "Wash him" enabled, the single prompt pill showed "Buy Bubble Soap" (the Tools board, 6.7 studs away). It did the same with "Put in tub". One stud nearer, it showed the right prompt.
   - On touch only, the player must step closer to find the tub's pill.
   - Prompt pills are not drawn in Studio captures, so picture 03 only shows where I stood.
2. S4: one frame of the player camera (1.59 s) between the join and the opening shot (1.62 s).
3. S4, question: the wash meter reads 100% at the start of Scrub the mud and 100% "Squeaky clean!" at the end, but 0% at the start of Trim the claws. "Squeaky clean!" and the bar sit over the top of the cat's ears in the scene (picture 04).
4. Question: no rinse, shake-off or dry step appeared for a cat with the "wet" need and the Dryer built.
5. The claw step was in the list this time (step 4). The skip I reported on 92f0410 did not happen here.

## Console
No new lines. Everything matched the known list: Studio's MemoryStore and DataStore lines, and the 3 "rbxassetid://203785492 asset type does not match" lines at the opening.
