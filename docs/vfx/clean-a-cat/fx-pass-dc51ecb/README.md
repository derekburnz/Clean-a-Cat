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
