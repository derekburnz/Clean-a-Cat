# Clean a Cat sound list

Owner: Motion-FX-Agent (sound-designer). Issue #8. Built on the draft design (first session 0:00 to 1:00); rows change when the design changes. How sounds are made, sourced and wired: the `audio-pipeline` skill. Licenses: `assets/clean-a-cat/audio/README.md`.

## Taste
Soft, warm and short, like a cosy spa. The player's own action (scrub, brush) is the clearest sound; rewards are short and gentle, never a loud ding. Nothing harsh or scary. Most players are on phone speakers, so each sound carries its character between 1 and 4 kHz.

## Cues
Moments are the shared list in issue #3. Source: **synth** means made by `assets/clean-a-cat/audio/synth/make_sfx.py` (ours, no license questions); **library** means Derek's own sound code in derekburnz/Roblox-Asset-Library, re-rendered here with Clean a Cat names and uploaded fresh under Creampuff Games (old ids belong to the old uploads); **store** means a Roblox Creator Store sound, searched in Studio (free in experiences, inside Roblox only, no upload needed).

| Cue id | Moment | Bus | What it sounds like | Source | File or asset | Vol | Pitch | minGap | Voices | Preload | Status |
|---|---|---|---|---|---|---|---|---|---|---|---|
| scrubLoop | ScrubStart to ScrubStop | Sfx | gentle wet sponge rub, loops; speed follows drag | synth | CleanACat_Sfx_SpongeLoop (2 s seamless loop, four strokes, small squeaks) | 0.5 | 0.9 to 1.15 by drag speed | - | 1 | yes | uploaded to the group 2026-11-24, gate PASS, seam clean |
| bubblePop | ScrubMove | Sfx | tiny soft pops | synth | CleanACat_Sfx_BubblePop_1..3 | 0.35 | 0.92 to 1.08 | 0.12 | 3 | yes | uploaded to the group 2026-11-24, gate PASS |
| mudPlop | MudPatchCleared | Sfx | small wet plop, pitch rises as fewer patches remain | synth | CleanACat_Sfx_MudPlop | 0.5 | 0.9 + 0.02 per cleared patch, max 1.3 | 0.05 | 3 | yes | uploaded to the group 2026-11-24, gate PASS |
| revealChime | CatClean | Sfx | two soft bright notes rising | synth | CleanACat_Sfx_RevealChime | 0.55 | 1.0 | 0.5 | 1 | yes | uploaded to the group 2026-11-24, gate PASS |
| dryerHum | DryStart to DryStop | Sfx | soft rushing air over a low fan hum, loops, at the dryer | synth | CleanACat_Sfx_DryerHum (2 s seamless loop, 110 Hz hum, 3 Hz fan flutter) | 0.35 | - | - | 1 | no | uploaded to the group 2026-11-24, gate PASS; waits on DryStart and DryStop |
| catShake | CatClean (with the shake-off) | Sfx | fur shake with a few droplets | synth | CleanACat_Sfx_FurShake (four fur flaps and droplet ticks, 0.75 s) | 0.5 | 0.95 to 1.05 | 0.5 | 1 | no | uploaded to the group 2026-11-24, gate PASS |
| brushSwish | BrushSwipe | Sfx | soft brush swish, one step higher per stroke | synth | CleanACat_Sfx_BrushSwish_1..3 (stroke 1, 2, 3) | 0.45 | 0.97 to 1.03 | 0.1 | 2 | yes | uploaded to the group 2026-11-24, gate PASS |
| purr | CatFluffed | Sfx | short content purr, about 1.5 s | library | CleanACat_Sfx_Purr_1..2 (ported from the library's purr code into make_sfx.py) | 0.5 | 0.95 to 1.05 | 1.0 | 1 | no | uploaded to the group 2026-11-24, gate PASS |
| bowPop | BowChosen | Sfx | light round pop | synth | CleanACat_Sfx_BowPop | 0.5 | 0.95 to 1.05 | 0.15 | 1 | no | uploaded to the group 2026-11-24, gate PASS |
| camera | PhotoTaken | Ui | soft double shutter click | synth | CleanACat_Ui_Camera | 0.5 | 1.0 | 0.3 | 1 | no | uploaded to the group 2026-11-24, gate PASS |
| uiClick | any button | Ui | short soft tick | synth | CleanACat_Ui_Click | 0.4 | 0.98 to 1.02 | 0.05 | 2 | yes | uploaded to the group 2026-11-24, gate PASS |
| meow | customer arrives, window cat idle | Sfx (3D at the cat) | short friendly meow, 3 variants, never a hiss | library | CleanACat_Sfx_Meow_1..3 (mew, rising mew, trilled mrrp; ported from the library's cat_voice code) | 0.45 | 0.9 to 1.15 | 4.0 | 2 | no | uploaded to the group 2026-11-24, gate PASS |
| truckRumble | opening scene (#281), while the truck is in view | Sfx (3D at the truck) | a small friendly truck rolling by: soft low engine chug, light tyre hiss, a little rattle | synth | CleanACat_Sfx_TruckRumble (2 s seamless loop) | 0.4 | - | - | 1 | no | uploaded to the group 2026-11-24; waits on openingBox |
| truckHonk | opening scene, 0.4 s in | Sfx (3D at the truck) | one soft toot-toot, two round notes a third apart, so players look up | synth | CleanACat_Sfx_TruckHonk | 0.4 | - | 2.0 | 1 | no | uploaded to the group 2026-11-24; Derek to say honk or quiet (Design-Agent open point 3) |
| truckBump | opening scene, each axle over the bump | Sfx (3D at the truck) | rubbery thunk with a springy boing; the back wheels add a cargo rattle | synth | CleanACat_Sfx_TruckBump_1..2 (front, back) | 0.5 | - | 0.1 | 2 | no | uploaded to the group 2026-11-24 |
| truckDoor | opening scene, back wheels hit | Sfx (3D at the truck) | a latch clack and a light flap of the rear door | synth | CleanACat_Sfx_TruckDoor | 0.4 | - | 0.5 | 1 | no | uploaded to the group 2026-11-24 |
| boxThud | opening scene, the box lands (and pitched up for its small bounce) | Sfx (3D at the box) | hollow papery cardboard thud on pavement | synth | CleanACat_Sfx_BoxThud | 0.5 | 1.0, 1.25 on the bounce | 0.1 | 2 | no | uploaded to the group 2026-11-24 |
| boxRustle | opening scene, each wiggle of the box until it is tapped | Sfx (3D at the box) | two quick papery scrapes and a small bump from inside; the meow plays every other wiggle | synth | CleanACat_Sfx_BoxRustle | 0.4 | 0.95 to 1.05 | 0.5 | 1 | no | uploaded to the group 2026-11-24 |
| collarJingle | SudsNamed (switch sudsWash) | Sfx (3D at the collar) | a small gold bell shaken three times, bright and warm | synth | CleanACat_Sfx_CollarJingle | 0.5 | - | 1.0 | 1 | no | uploaded to the group 2026-11-24 |
| carryPurr | the player carries Suds from the box to the tub (Effects/Carry, switch openingBox) | Sfx (3D at the kitten, looped) | a contented purr in your arms, from Derek's library (Cat Cafe's carryPurr) | library | CleanACat_Sfx_CarryPurr | 0.45 | - | 1.0 | 1 | yes | gate PASS, not uploaded |
| purr (reused) | SudsTapped (switch sudsMascot) | Sfx | the same purr as CatFluffed; minGap 1 s keeps fast taps from stacking | library | CleanACat_Sfx_Purr_1..2 | 0.5 | 0.95 to 1.05 | 1.0 | 1 | no | bound, waits on SudsTapped |
| spaMusicA / spaMusicB | spa floor | Music | see brief | synth | CleanACat_Music_SpaA (Warm Bubbles, 92 BPM marimba) and CleanACat_Music_SpaB (Fluff and Fold, 80 BPM piano and flute), new songs from assets/clean-a-cat/audio/synth/music.py | 0.5 | 1.0 | - | 1 | no | made; SpaA gate WARN on the seam (downbeat level, same as every phrase start), listen |

Later, not in the first slice: coin and tip jar, build finished celebration, builder kitten hammer, door bell, window tips.

## Music brief
Calm and light, like a sunny spa or a cat cafe: soft keys, plucked guitar or marimba, light brushed drums, 80 to 100 BPM, major key, no vocals. Two tracks that alternate with a 2 second crossfade so no one loop plays all session. Starts only after the player's settings are read.

## Searching the Creator Store (store rows)
The Creator Store is Roblox's library of free sounds and music from Roblox's audio partners. It needs no upload, but its music may only be used inside Roblox, never in a video off the platform. Every cue now has a sound made from code, so no search is needed. A Creator Store search is only worth it if a listen says one of ours sounds wrong. It runs in Studio on the owner's PC (Sync-Agent, free and verified creators only, audio type, the duration range below), returning two or three candidates per cue with name, creator, id and length:

| Cue | Search words | Length |
|---|---|---|
| scrubLoop | sponge scrub, soap scrub, washing | 1 to 4 s, loopable |
| catShake | dog shake, fur shake, water shake | 0.4 to 1.2 s |

If nothing fits, the fallback is CC0 (Kenney audio packs, Freesound filtered to CC0) with a license row, uploaded under the Creampuff Games group after the owner's OK on the batch.

## Listening list (for the owner, once the Audio module is in)
1. Open the dev place in Studio, press Play.
2. Scrub the first cat: hear the sponge loop and small pops while dragging, a plop as each mud patch goes. Pops should be quiet under the sponge.
3. Finish the mud: a two-note chime and a shake. The chime should feel like a reward, not a ding.
4. Brush three times: each swish a little higher, then a purr.
5. Pick a bow: a light pop. The photo card: a soft click.
6. Note anything too loud, too quiet, too often or annoying after ten cats.

Synth sounds can also be heard now without Studio: open the `.ogg` files under `assets/clean-a-cat/audio/sfx` and `ui`.
