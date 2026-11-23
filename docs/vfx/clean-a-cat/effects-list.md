# Clean a Cat effects list

Owner: Motion-FX-Agent (vfx-animator). Every effect is a row here before it is built. How: the `animation-vfx` skill. Sounds for the same moments: `docs/audio/clean-a-cat/sound-list.md`. Moments come from `Shared.Moments` (issue #3). Phone budgets are animation-vfx section 7; numbers below are starting values, measured on a phone profile before a row is marked done.

## Effects
| Moment | Effect | Where it plays | Preset | Phone budget | Reduce Motion | Issue | Status |
|---|---|---|---|---|---|---|---|
| ScrubMove | Foam bubbles at the sponge point, drift up and pop; rate follows drag speed | hit point on the cat | foamTrail | Rate 8, life 0.8 s | kept, halved | #4 | built, switch scrubEffects |
| ScrubMove (Bubble Soap) | Wider ring of bubbles | hit point | foamTrailWide | Rate 8, life 0.8 s | kept, halved | #4 | planned |
| ScrubMove (Golden Sponge pass) | Gold-tinted bubbles, same count | hit point | foamTrailGold | Rate 8, life 0.8 s | kept, halved | #4 | planned |
| MudPatchCleared | 4 to 6 brown flecks fall and fade; the patch fades over 0.15 s | patch position | mudChunks | Emit 4 phone, 6 PC | kept, halved | #4 | built, switch scrubEffects (patch fade by ScrubController) |
| CatClean | Dirty layer fades top to bottom over 0.4 s | the cat | revealWipe | 1 tween | instant fade | #6 | patches fade in ScrubController for now; full wipe waits on the dirty layer (#12) |
| CatClean | 8 sparkles in palette colours | around the cat | revealSparkle | Emit 6 phone, 8 PC | halved | #6 | built, switch revealEffects |
| CatClean | Water droplets on the shake-off | the cat | shakeDroplets | Emit 6 phone, 10 PC | halved | #6 | built, switch revealEffects; shake motion waits on the rig (#11) |
| BrushSwipe | Fur puffs in the coat colour along the stroke | brush point | furPuff | Emit 6 | kept | #7 | built, switch fluffEffects |
| BrushSwipe | Cat grows about 3 percent per stroke (Back Out, 0.2 s) | the cat | fluffScale | 1 tween | skipped | #7 | waits on the cat model (#11), so it never scales a part gameplay moves |
| CatFluffed | Soft glow pulse, one Highlight destroyed after 0.6 s | the cat | glow | 1 Highlight, 2 max on phones | kept, no fade | #7 | built, switch fluffEffects |
| BowChosen | Bow pops in (scale 0 to 1, Back Out 0.25 s) with 3 small hearts | above the cat | bowHearts | Emit 3 | halved | #7 | hearts built, switch fluffEffects; bow scale pop waits on the bow model (#14) |
| CatToWindow | Hop arc to the cushion, small dust puff on landing | window cushion | windowHop | Emit 4 | instant move | #7 | planned |

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

## Requests to other lanes
| Need | Owner | Issue |
|---|---|---|
| Moment signals for scrub, reveal, fluff, bow, photo, window | Gameplay-Engineer | #3 |
| Cat rig with the part names above and a separate dirty layer that can fade | Model-Agent | #11 |
| Palette colours for foam, mud, sparkles and glow | Design-Agent (style guide) | to open once the style guide exists |

## Rules
Effects only listen. No more than three flashes a second, no full-screen flash, no camera shake. Every row that changes the first session ships behind a LiveFlags off switch. A capture of each finished effect goes in this folder.
