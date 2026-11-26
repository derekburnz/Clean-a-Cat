# Motion-FX pass on dc51ecb (PR 719 included)

- Build: main at dc51ecb, built with rojo and opened as an unsaved local place, one client. Never saved or published. iPhone 13 frame, real taps unless noted.
- Switches: every key in LiveFlags.OFF_BY_DEFAULT on except toolCursor, streetLoadTest, exampleFeature, openingReplay, benchGrow and cameraClear. The effects switches scrubEffects, revealEffects, fluffEffects and dryEffects are all on.
- Seeds, edited in the local place only: play 11:40, 5 stars, 50,000 coins, 14 crates, Jo and Sam hired, quests seeded, heart bars cut to a quarter. For the Garden run the Garden and VIP Room were also built.
- Effects tier: Studio picks the "low" preset table, so the counts below are the low tier.
- Logging: Audio.play and Effects.burst, stream, glow and popIn were patched in the local place to log each call. Each sound was also checked 1.2 s after it started: IsLoaded, TimeLength and volume.

## Sounds
| Cue | Result |
|---|---|
| scrubLoop, bubblePop, mudPlop | PLAYS. Now and then one bubblePop logged loaded false; the next ones loaded |
| revealChime, catShake, stepChime | PLAYS |
| brushSwish, purr, bowPop, camera | PLAYS |
| heartLow | PLAYS, vol 0.35 |
| catLeave | PLAYS, vol 0.40 |
| crateOpen, petReveal | PLAYS |
| starUp | PLAYS on a real Fuse tap |
| workerDone, visitorChime | PLAYS |
| buildDone | NOT. AudioController listens for Moments.BuildFinished, but Moments has no BuildFinished signal. Only the BuildFinished remote exists, and it goes to BubbleController and BuildBoardController. A tapped Second Tub build and a seeded VIP Room build both finished with no cue |
| questDone | NOT. Same cause: no Moments.QuestDone signal anywhere |
| checkIn | NOT. Same cause: no Moments.CheckInClaimed signal. The claim itself worked |

- Every sound that played had loaded, all through the Sfx or Ui groups. No cue was louder than 0.45 before the group volume.
- Console: only the known lines (ContentId 203785492, MemoryStore and DataStore on a local place). No 'failed to load' for any cue.

## #4 Scrub feel (picture 01)
| Check | Result |
|---|---|
| Foam that follows the sponge | NOT. Effects.stream("foamTrail") was never called while scrubbing to 89% |
| Mud flecks | PLAYS, 4 per patch (low tier; high is 6). The 0.15 s fade was not measured |
| Sounds | PLAYS |

## #6 Reveal (picture 02)
| Check | Result |
|---|---|
| Sparkles | revealSparkle 6 (low tier; high is 8) |
| Water drops | shakeDroplets 6 (low tier; high is 10), shakeFlecks 8 three times |
| Dirt fade, top to bottom over 0.4 s | Not measured |
| Flashes | 4 sparkle bursts in 0.36 s at CatFluffed, so more than 3 a second |

## #7 Fluff and bow (pictures 03 and 04)
| Check | Result |
|---|---|
| Fur puffs | NOT, by design. Derek asked for a top to bottom shine instead (BrushShine.sweep), which plays |
| Glow pulse | PLAYS |
| Bow pop | PLAYS: popIn over 0.25 s and 3 hearts |
| Hop to the window cushion | NOT. ScrubController fires Moments.CatToWindow, but nothing listens to it |

## Other moments
| Check | Result |
|---|---|
| Pet reveal pop (picture 05) | PLAYS. Scale 0.04 to 0.78 to 0.70 in 0.45 s, and the head and tail stay on the body. No wiggle after it |
| Visitor star and sparkles | PLAYS, with the highlight |
| Gift stand beacon | PLAYS, a sparkle every 4.5 s |
| Worker take | PLAYS, with workerDone |
| Mood (picture 06) | A customer at 0.14 heart fill had their head down 6 degrees. The foot tap was not measured |
| Walk-off | PLAYS. A quarter turn (89 degrees) in 0.4 s, then a walk sideways at 3.2 studs a second. The fade starts at 2.0 s and the copy is gone at 2.6 s. heartLow, then catLeave |
| Garden ambience (picture 07) | PLAYS. One petal emitter at rate 1 (low tier), lifetime 3.5 to 5 s, so about 5 petals at a time. The 4 blossom clouds rise and settle 0.12 studs in all, as written (0.06 each way) |

## Peak particle counts (low tier)
- Scrub: 4 mud flecks a patch, no foam.
- Reveal: 6 sparkles, 6 drops and 8 flecks three times.
- Fluff and bow: 3 hearts.
- Garden: about 5 petals.

## Recheck on 4954d9c (PR 722)
- Place: the same local place, with every file that changed between dc51ecb and 4954d9c copied in: EffectsController, Effects/init, Crate, Hop (new), WorkerService and WorkerRules. A fresh save with 14 crates. Switches as above. iPhone 13 frame. The first stray's wash started with the E key, and the later steps were finished with the Studio test step. The bow and photo were real taps.
- Effects.stream was hooked again, this time keeping every call with its drag speed, the raw rate and the rate set.

| Check | Result |
|---|---|
| Foam, slow rub | PLAYS. 14 calls at drag speeds 0.17 to 2.29. The raw rate rounded to 0 on 13 of them, so on dc51ecb the foam was called but stayed at 0. With PR 722's floor the rate set was 3 on every call |
| Foam, fast rub | PLAYS. 1,031 calls at speeds 0.02 to 158. Rate set 3 to 8 (8 is the low-tier cap), 3.05 on average |
| Fluff flashes | PASS. At the fluff, 2 sparkle bursts of 6 at the same moment (the shake's one burst and the brush's sparkle), then nothing until the photo 21 s later. Before: 4 in 0.36 s |
| Reveal | 1 sparkle burst (6), 6 drops and 8 flecks three times, 0.18 s apart |
| Stray hop | PLAYS. 1.6 s after the photo the stray rose 0.60 studs in the tub and landed with a dust puff of 5. It then shows on the window seat (a separate window copy). The hop happens in the tub, not onto the cushion |
| Pet reveal wiggle | PLAYS. After the pop (scale 0.78 to 0.70), the pet turns side to side from 0.51 s to 0.71 s, -4.6 to +7.6 degrees. The head and ears turn with the body and stay on it |
| Console | Only the known lines |

Peak particle counts (low tier): foam 3 a second on a slow rub, up to 8 on a fast one; 12 sparkles at the fluff; 5 dust at the hop; 6 sparkles twice at the pet reveal.
