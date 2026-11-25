# Customer carry, wash scene, tool on cat and the customer close-up (25eb648, 5a9e0f0, 542efbc)

Local unsaved builds, iPhone 13 frame (750x390; it stands in for the iPhone 12, which has no preset). Single client only. The iPad pass was not run.

Switches: every switch in LiveFlags.OFF_BY_DEFAULT on (the closest match to dev I could read from the repo). Off: toolCursor, streetLoadTest, exampleFeature and openingReplay. On 542efbc strays was also off, so that the first cat after Suds is a customer. carryShared was on and made no new warnings.

Studio's graphics tier on this PC was low for the effects, so the wash scene's depth-of-field blur was never created: there was no blur object in any frame. The frame rate is from a desktop GPU (about 240 fps average, worst frame 7 to 8 ms), not a mid-tier phone.

## Customer carry (542efbc)
- (1) Pass. After "Open the spa!" the camera eases back to the player: Custom, field of view 70, at 50.36 s. The front customer keeps the cat in the carrier, and "Take cat" is the only pick prompt.
- (2) Pass. "Take cat" (E within 10 studs; a click on the pill billboard did not register in the simulator) puts the cat in the arms and the customer leaves the line. The line refills to 3.
- (3) Pass with one problem. "Put in tub" starts the wash scene in the same frame (87.508 s: Scriptable, then easing to the shot), so there is no gap. The carried cat goes away and the new cat is in the tub 0.45 s later.
  - Problem: the last washed cat is never taken out of the tub. Suds (clean, with his bell) sits in the tub while he is also on his bed, and he stays there all the while the customer's cat is carried (picture 542efbc-02).
  - On 5a9e0f0 the stray Cotton stayed in the tub the same way. So there are two of the same cat on screen until the new cat lands.
- (4) Wash scene:
  - The cat fills 0.64 to 0.65 of the screen height (target 0.55), field of view 50.
  - The step line and Walk bar are clear, but the step pips sit over the cat's ears.
  - The field of view goes back to 70 on exit.
  - Blur: not created at this graphics tier.
- (5) Second customer. After the recap's Next cat, two "Wash next" pick prompts showed first. "Take cat" came about 19 s later. While carrying that cat, both "Wash next" prompts showed again next to "Put in tub".
- (6) Fail. A reset while carrying: the character still has the attributes CarryHeld=sit and CarryCat set, and "Put in tub" is still offered. But the client's CleanACat_CarriedCat model sits at the world origin (0,0,0), 9.4 studs from the player, not in the arms.
- (7) Console: no new game errors. Studio's own messages only (MemoryStore and DataStore not published), plus 3 lines saying "rbxassetid://203785492 asset type does not match" at the opening.

## Wash scene problems
- Pick a bow: BowPink sits at x -21, off the left edge of the screen. BowMint is at x 39 and BowSky at x 83, at the very edge (5a9e0f0-02).
- Trim the claws: the shot looks from the tub's front, but at the Pawdicure the cat faces sideways. A ray to each claw hits CleanACat_Station_Pawdicure first, so the paws can't be touched (542efbc-06). The claws were finished with the test hook.

## Tool on cat
- Pass. Sponge on the mud: on Suds (25eb648, normal close-up) it is 54x43 px; in the wash scene it is 101x79 to 122x92 px. The tool's lowest point is 0.02 to 0.04 studs off the fur along the surface normal, so it is neither sunk nor floating.
- Pass. Brush on tangles: 36x48 px on 25eb648. It went away as the step finished, while the finger was still down.
- Pass. Bubble sponge in the bubble bath (542efbc): about 135x120 px, and it goes away on lift.
- Clipper: 19x59 px on 25eb648. In the 542efbc wash scene it never showed, because the paws are behind the station.
- Pass. On the head the tool is see-through: LocalTransparencyModifier 0.60, and the face shows through (pictures 25eb648-02 and 542efbc-04).
- Pass. Sliding off the cat makes it go away (at touch 410,88 on 25eb648). Lift makes it go away.
- Pass. Bow and photo taps show no tool.
- Never blocks a stroke: the mud on Suds's front and the brush step on Suds finished with real drags. Twenty swirls did not finish the suds on the customer. I finished that step with the hook and did not pin down why.

## Customer close-up question
- 25eb648 (washView, no washScene):
  - After Suds's photo the camera eased out to a far Scriptable shot 38.2 studs from the tub. The cat filled 0.12 to 0.13 of the screen height there. The camera stayed on that shot, not on the player's view, until the next cat came (about 20 s).
  - The first customer's close-up then eased in from 38.2 to 7.4 studs in 0.6 s. Cat height share in the close-up: 0.36 to 0.40.
  - With the avatar hidden (1.00), this far shot after Suds may be what reads as "zoomed out".
- 542efbc (washScene): the normal player view is Custom, field of view 70, cat share 0.30 to 0.36. The scene is 0.64 to 0.65, with the avatar hidden.
- The camera stays on the player view while washView is off, while the player has stepped out (Walk), while the visit stage is "waiting" or "done", and with customerCarry until "Put in tub".
