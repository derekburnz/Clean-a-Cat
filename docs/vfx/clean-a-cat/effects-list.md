# Clean a Cat effects list

Owner: Motion-FX-Agent (vfx-animator). Every effect is a row here before it is built. How: the `animation-vfx` skill. Sounds for the same moments: `docs/audio/clean-a-cat/sound-list.md`. Moments come from `Shared.Moments` (issue #3). Phone budgets are animation-vfx section 7; numbers below are starting values, measured on a phone profile before a row is marked done.

## Effects
| Moment | Effect | Where it plays | Preset | Phone budget | Reduce Motion | Issue | Status |
|---|---|---|---|---|---|---|---|
| (dirty cat in view) | 2 or 3 soft green stink wisps drift up from over the head, thinning as mud clears, gone when clean | the head's Carry attachment | stinkWisps | Rate 4 phone (bigger, more solid puffs), 5 PC, life 1.4 s, 2 cats phone, 4 PC, within 60 studs | halved | #122 | built, switch stinkEffects |
| ScrubMove | Foam bubbles at the sponge point, drift up and pop; rate follows drag speed | hit point on the cat | foamTrail | Rate 8, life 0.8 s | kept, halved | #4 | built, switch scrubEffects |
| ScrubMove (Bubble Soap) | Wider ring of bubbles | hit point | foamTrailWide | Rate 8, life 0.8 s | kept, halved | #4 | planned |
| ScrubMove (Golden Sponge pass) | Gold-tinted bubbles, same count | hit point | foamTrailGold | Rate 8, life 0.8 s | kept, halved | #4 | planned |
| MudPatchCleared | 4 to 6 brown flecks fall and fade; the patch fades over 0.15 s | patch position | mudChunks | Emit 4 phone, 6 PC | kept, halved | #4 | built, switch scrubEffects (patch fade by ScrubController) |
| CatClean | Dirty layer fades top to bottom over 0.4 s | the cat | revealWipe | 1 tween | instant fade | #6 | patches fade in ScrubController for now; full wipe waits on the dirty layer (#12) |
| CatClean | 8 sparkles in palette colours | around the cat | revealSparkle | Emit 6 phone, 8 PC | halved | #6 | built, switch revealEffects |
| CatClean | Water droplets on the shake-off | the cat | shakeDroplets | Emit 6 phone, 10 PC | halved | #6 | built, switch revealEffects; shake motion waits on the rig (#11) |
| BrushSwipe | Fur puffs in the coat colour along the stroke | brush point | furPuff | Emit 6 | kept | #7 | built, switch fluffEffects |
| BrushSwipe | Fur pieces fade in after the third stroke (Model-Agent's _Fluff01 to _Fluff10) | the cat | none, a tween | 1 tween per piece | kept | #7 | built by ScrubController (showFluff); the grow-per-stroke idea is dropped so no part gameplay moves is scaled |
| CatFluffed | Soft glow pulse, one Highlight destroyed after 0.6 s | the cat | glow | 1 Highlight, 2 max on phones | kept, no fade | #7 | built, switch fluffEffects |
| BowChosen | Bow pops in on its BowSlot (scale 0 to 1, Back Out 0.25 s) with 3 small hearts | the bow on the head | bowHearts, popIn | Emit 3, one ScaleTo per frame for 0.25 s | halved, no pop | #7 | built, switch fluffEffects |
| CatToWindow | Hop arc to the cushion, small dust puff on landing | window cushion | windowHop | Emit 4 | instant move | #7 | planned |
| DryStart to DryStop | Warm air wisps blow down from the nozzle onto the cat | the dryer's Air attachment | dryerAir | Rate 6 phone, 12 PC, life 0.4 s | halved | #18 | built, switch dryEffects; waits on DryStart and DryStop from the dry step |
| opening: truck wheels hit the bump, box lands | Small puff of road dust | the bump on the road, under the box | roadDust | Emit 5 phone, 9 PC, life 0.7 s | kept (no motion) | #281 | built, switch openingBox |
| SudsNamed | Sparkle burst at his new collar and the happy wiggle | the Collar piece (else the top of the cat) | revealSparkle | Emit 6 phone, 8 PC | wiggle skipped, sparkle halved | #285 | built, switch sudsWash |
| SudsTapped | A small 0.7 stud hop on his bed (local, put back exactly) and the happy wiggle | Suds on SpotMascot | - | one hop at a time per Suds | no hop, no wiggle (purr only) | #285 | built; binds once the moment lands (sudsMascot) |

## Opening scene (truck and box, #281)
Client only, code-driven curves (Effects/TruckDrop for the numbers, Effects/OpeningScene for the props, sounds and camera); no animation clip, so nothing to upload. Beats are Design-Agent's 2026-11-24 plan, all in TruckDrop.BEATS. Props from Model-Agent (#279, #278), PH_ stand-ins until they land.
| Beat | Time | Motion | Reduce Motion or Less shake | Sound |
|---|---|---|---|---|
| Truck enters from the left | 0.0 | drives at 32 studs a second, wheels roll | same | truckRumble (follows the truck) |
| Honk | 0.4 | - | same | truckHonk |
| Front wheels on the bump | 1.2 | lift 0.35 studs, nose up 5 degrees, dust puff | no jolt | truckBump 1 |
| Back wheels on the bump | 1.45 | nose down 4 degrees and a short rattle; rear door flaps up with an overshoot | no jolt, door opens straight | truckBump 2, truckDoor |
| Box out | 1.55 | arc from the tailgate, 3.5 studs high, a quarter tumble that ends flat | no tumble | - |
| Box lands | 2.25 | squash 22 percent, one 0.5 stud bounce, dust | squash kept, no tumble | boxThud, then a higher one on the bounce |
| Settled | 2.63 | the Open! prompt appears | same | - |
| Truck gone, camera back | 3.5 | shot camera follows the truck in and holds on the box | no shot, camera stays the player's | rumble stops |
| Box wiggles until tapped | every 1.6 s from 3.0 | two quick 7 degree rocks | no rock | boxRustle, meow every other one |
| Tap: flaps open, kitten peeks | 0.35 s | flaps swing 215 degrees with an overshoot, kitten's chest rises to the rim, then the shake-off and mud chunks | flaps open straight, no shake | meow, catShake |

## Motion (procedural first, on the cat rig)
Part names from Model-Agent (issue #11): Body, Head, Eye1, Eye2, EarL, EarR, Tail, LegF1, LegF2, LegB1, LegB2, each pivoted at its joint.
| Motion | When | Joints | Reduce Motion | Issue | Status |
|---|---|---|---|---|---|
| Idle breathing nod and tail sway | always, within 60 studs | Head, Tail | skipped (animation-vfx section 6) | #6 | built, switch catMotion |
| Blink (eyes squash shut 0.14 s every 2.5 to 6 s) | always, within 60 studs | Eye1, Eye2 | kept, it is tiny | #6 | built, switch catMotion |
| Ear twitch (one ear, 0.25 s, every 4 to 9 s) | always, within 60 studs | EarL, EarR | skipped | #6 | built, switch catMotion |
| Shake-off (head roll and tail whip, 0.5 s) | CatClean | Head, Tail, EarL, EarR | skipped | #6 | built, switch catMotion |
| Happy wiggle (tail wag, ears, head tilt, 0.8 s) | CatFluffed | Head, Tail, EarL, EarR | skipped | #7 | built, switch catMotion |

Body never moves, so mud on the body stays put and the server can still move the whole cat. Phone budget: 4 cats at 30 updates a second, half rate past 30 studs, none past 60. Still to measure on a phone profile in Studio.

## Measured
- 2026-11-23 ET, Sync-Agent on Derek's PC (PR #54, scrub and reveal effects on vs off): render CPU 1.27 vs 1.28 ms, GPU 0.35 vs 0.34 ms, 95th percentile frame 5.27 vs 5.31 ms, at most 4 emitters and 8 instances live, no console errors. Report: `Sync-Agent/studio-reports/pr54-effects-cost-2026-11-23.md` in the project files. Still owed: a phone run, the fluff and bow effects and cat motion.

## Requests to other lanes
| Need | Owner | Issue |
|---|---|---|
| Moment signals for scrub, reveal, fluff, bow, photo, window | Gameplay-Engineer | #3 |
| Cat rig with the part names above and a separate dirty layer that can fade | Model-Agent | #11 |
| Palette colours for foam, mud, sparkles and glow | Design-Agent (style guide) | to open once the style guide exists |

## Rules
Effects only listen. No more than three flashes a second, no full-screen flash, no camera shake. Every row that changes the first session ships behind a LiveFlags off switch. A capture of each finished effect goes in this folder.
