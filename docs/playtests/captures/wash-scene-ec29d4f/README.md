# Wash scene tune and carry fixes on ec29d4f

Local unsaved build of ec29d4f, which includes the 161ec50 wash scene tune and #414. iPhone 13 frame (750x390), single client. Switches as in the 542efbc pass: every switch in OFF_BY_DEFAULT on except toolCursor, the test-only switches and strays.

## Carry fixes
- (1) Pass. Reset while carrying: 10 s after the reset the cat is back in the arms, 1.2 studs from the new root, the same as before the reset. It was missing for 0.3 s during the respawn.
- (2) Pass. The tub is empty once the next customer's cat is at the door. Clean Suds left the tub when "Take cat" appeared, and so did the customer's cat before the second "Take cat".
- (3) Pass during the carry: no "Wash next" prompt at any point between "Take cat" and the cat landing in the tub. Before the second customer, two "Wash next" prompts showed for about 13 s, from just after the photo until "Take cat" appeared. That is the queue pick, outside the carry.
- "Put in tub": the hop takes 0.45 s. Then for about 40 ms (2 frames) no cat is either carried or in the tub, before the new cat appears.

## Wash scene (iPhone 13)
Fill is measured from the cat's bounding box, the same way as the earlier runs. Pips are the step dots; the claw check casts a ray from the camera to each claw.

| Station | Fill | Pips vs ears | Claws | Within 0.5 studs of camera |
|---|---|---|---|---|
| Tub, scrub (Suds and customer) | 0.54 | clear, 14 px gap | (under the rim, not a claw step) | none |
| Bubble Bath | 0.61 | overlap 33x8 px | - | none |
| Pawdicure | 0.59 | overlap 29x8 px | nothing in front of either claw (the station is behind them) | none |
| Tub, Pick a bow | 0.56 | clear, 14 px gap | - | none |

- The camera sits at y 7.6 to 7.7. A ray from the camera to the cat hits the cat's head first at every station. No ceiling, lamp or sign is in the way.
- Bows at "Pick a bow", in GUI space: BowPink 166,184, BowMint 190,241, BowSky 209,286. All three are on screen and each ray hits the bow itself (picture 4).
- With autoTool on there is no bottom bar and there are no turn buttons. Nothing covers the paws (paws are at 350..400 x 172..227).
- The Bubble Bath and Pawdicure shots look from the tub's front direction, while the cat faces sideways. You see his side and back (pictures 2 and 3).

## Blur
- Effects/Tier.luau gives the "low" tier to every touch-only device. WashCamera makes no blur on "low", so no phone or tablet preset ever shows the blur, at any graphics level.
- With the device simulator off (desktop, keyboard, SavedQualityLevel 10) the blur is made: FarIntensity 0.50, InFocusRadius 3, FocusDistance 6.8 (picture 5).
