# Parked Studio checks on b9c0008 (#429, #432, #435, #443, effects, blur, #182)

Local unsaved build of b9c0008 (main on 2026-11-25).
- Device: the iPhone 13 frame (750x390) stands in for the iPhone 12, which has no Studio preset. The iPad is the 10th generation preset (1178x819).
- Switches: every switch in OFF_BY_DEFAULT on, except toolCursor, strays and the test-only ones. toolsBoard and builds were on.
- Save: fresh, with the Bubble Bath and Pawdicure built.

## #429 step pill and gold ring (pictures 01, 02)
- Pick step: the pill is 220x38 at GUI 265,6, top centre, ZIndex 9. The chip "1 / 3" is 58x23 in gold #ffd84d, text size 19. "Pick him up" is size 26. Both are the short-screen sizes and both fit.
- Wash step: the pill is 205x38, chip "2 / 3", "Wash him".
- Overlap: none. The pill sits between the Index and Settings buttons (x 16..128) and the coin counter, and above the play area. The cat is far below it at both steps.
- Contrast: the ink #45226b on the gold chip is about 9:1.
- Gold ring: the Spotlight's parts are in place: Ring stroke #ffd84d 5 px, Edge #45226b 4 px, Glow #ffd84d 8 px at 0.45 transparency.
  - Gold against the ink edge is about 9:1. On its own, gold against the cream UI would be about 1.3:1, so the ink edge is what makes it read.
  - No lit-button dim step came up in this run (opening, first customer and "Show me"), so I have no picture of the ring on a button.

## #432 Tools and builder boards (pictures 08 to 11)
- Positions:
  - CleanACat_Prop_ToolsBoard stands at (-6, 3, -12), facing -Z, 6 studs left of the tub.
  - CleanACat_Prop_BuildBoard stands at (-18.1, 3, -4), facing -Z, next to the VIP Room door.
- Prompts:
  - Tools board: Buy Bubble Soap at y 4.3 and Buy Pro Brush at y 3.2, on the shelf rows.
  - Build board: Brush Table 4.58, Blow Dryer 4.0, Bubble Bath 3.42 (off, already built), Pawdicure 2.84 (off, built), VIP Room 2.26.
  - "Tell me when it's done" sits by the bell at x -20.3.
  - The pills themselves don't show in Studio captures.
- Titles: "Tools" and "Builds" are TextScaled, bounds about 63x28 and 70x28 inside 184x29 and 176x29 at 80 px per stud.
  - From 6.9 studs the title line is about 14 px tall on the iPhone frame and about 30 px on the iPad. It reads on both, though it is small on the phone.
- Both shelf displays (Bubble Soap, Pro Brush) show while not owned. I didn't buy one, so I didn't check that a display hides once bought.
- The build board's five row cards are blank, as the PR says. The names and prices are only on the prompts.
- Overlap: from the front, the Build board stands in front of the wall frame. The Tools board stands in front of the VIP door and mirror, so the board reads against a busy wall. No part of either board clips into the tub or the door.

## #435 foam puffs (picture 05)
- The Bubble Bath shows 6 puffs (PH_Suds1..6, 3 shapes in turn) round the cat, each 8 parts.
- Size: 0.77..1.10 x 0.58..0.86 x 0.42..0.48 studs, about 47x45 to 62x81 px on the phone frame.
- Placement: every puff's front faces out. Their centres sit 0.45 to 0.75 studs out from the fur along their direction. With a depth of about 0.45, the back of each puff is roughly 0.2 to 0.5 studs off the fur, so they float a little and none is buried.
- Popping: real circular swirls on the cat popped all 6 and finished the step (12 studs of travel; it needs one unbroken press).
- Fail: the 6 puff models stay in the cat after popping, with 48 parts left at full transparency. They are hidden but not destroyed.
- Frame time: in the Bubble Bath with the puffs up it was the same as the wash below (capped at 240).

## Bow buttons (#443, merged; pictures 06, 07)
- The models show as round buttons with the bow on them. Their tap slabs (invisible, 1.1x1.1x0.4 studs) on the phone frame:
  - Pink: x 88..212, y 157..238
  - Mint: x 124..230, y 218..286
  - Sky: x 152..243, y 265..324
- All three are on screen, inside the 332 px tall GUI area.
- Problem: the tap slabs overlap each other by about 20 px vertically (Pink with Mint, Mint with Sky).
- Tapping Mint worn it on the cat as CleanACat_Bow_Mint, and the bowHearts emitter fired.

## Effects for #4, #6 and #7 (pictures 03, 04, 07)
- Foam (#4): foamTrail on the iPhone frame. The rate followed drag speed from 1 to 8, so the phone cap of 8 holds. It switched on and off 121 times during real scrubbing. Lifetime is 0.5 to 0.8 s and size 0.22.
- Mud chunks (#4), sparkles and droplets (#6): the pooled emitters exist and fire.
  - mudChunks: life 0.4 to 0.7, size 0.18.
  - revealSparkle: life 0.5 to 0.8, size 0.30.
  - shakeDroplets: life 0.3 to 0.6, size 0.12.
  - They use Emit, so I can't count the particles from a script.
- Fur puffs (#7): no furPuff emitter was ever created during 6 real brush strokes that finished the step. The fur puff never played on this build. The glow Highlight was gone before the step ended.
- Bow pop (#7): the bowHearts emitter fired on the pick.
- Mud and brush both finished with real drags on the phone frame. The suds needed a fresh, unbroken press.

## Phone blur frame time (wash scene, iPhone frame)
This PC's numbers, capped at 240 fps; use them only to compare builds.
- Blur on (FarIntensity 0.30): average 240.0 fps, 1% low 147.1 fps, worst frame 8.0 ms.
- Blur off (the same scene, effect disabled): 240.1 fps, 1% low 158.3 fps, worst frame 7.3 ms.

## For #182
Studio's numbers during the wash on the iPhone frame. They are not the phone's.
- Draw calls (FrameRateManager batches): 114. Triangles: 96,694.
- Instances: 73,528.
- Studio total memory: 2,886 MB. This is the whole Studio process, not a phone figure.
- All are well under Roblox's example budget of 1,000 draw calls and 1,000,000 triangles.

## Console
No game errors. Only Studio's MemoryStore and DataStore lines, plus 3 lines saying "rbxassetid://203785492 asset type does not match" at the opening.
