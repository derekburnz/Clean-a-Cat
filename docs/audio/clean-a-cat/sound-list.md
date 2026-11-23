# Clean a Cat sound list

Owner: Motion-FX-Agent (sound-designer). Issue #8. Built on the draft design (first session 0:00 to 1:00); rows change when the design changes. How sounds are made, sourced and wired: the `audio-pipeline` skill. Licenses: `assets/clean-a-cat/audio/README.md`.

## Taste
Soft, warm and short, like a cosy spa. The player's own action (scrub, brush) is the clearest sound; rewards are short and gentle, never a loud ding. Nothing harsh or scary. Most players are on phone speakers, so each sound carries its character between 1 and 4 kHz.

## Cues
Moments are the shared list in issue #3. Source: **synth** means made by `assets/clean-a-cat/audio/synth/make_sfx.py` (ours, no license questions); **library** means Derek's own sound code in derekburnz/Roblox-Asset-Library, re-rendered here with Clean a Cat names and uploaded fresh under Creampuff Games (old ids belong to the old uploads); **store** means a Roblox Creator Store sound, searched in Studio (free in experiences, inside Roblox only, no upload needed).

| Cue id | Moment | Bus | What it sounds like | Source | File or asset | Vol | Pitch | minGap | Voices | Preload | Status |
|---|---|---|---|---|---|---|---|---|---|---|---|
| scrubLoop | ScrubStart to ScrubStop | Sfx | gentle wet sponge rub, loops; speed follows drag | store | search: sponge, scrub, soap | 0.5 | 0.9 to 1.15 by drag speed | - | 1 | yes | to search |
| bubblePop | ScrubMove | Sfx | tiny soft pops | synth | CleanACat_Sfx_BubblePop_1..3 | 0.35 | 0.92 to 1.08 | 0.12 | 3 | yes | made, gate PASS |
| mudPlop | MudPatchCleared | Sfx | small wet plop, pitch rises as fewer patches remain | synth | CleanACat_Sfx_MudPlop | 0.5 | 0.9 + 0.02 per cleared patch, max 1.3 | 0.05 | 3 | yes | made, gate PASS |
| revealChime | CatClean | Sfx | two soft bright notes rising | synth | CleanACat_Sfx_RevealChime | 0.55 | 1.0 | 0.5 | 1 | yes | made, gate PASS |
| catShake | CatClean (with the shake-off) | Sfx | fur shake with a few droplets | store | search: dog shake, fur shake, water shake | 0.5 | 0.95 to 1.05 | 0.5 | 1 | no | to search |
| brushSwish | BrushSwipe | Sfx | soft brush swish, one step higher per stroke | synth | CleanACat_Sfx_BrushSwish_1..3 (stroke 1, 2, 3) | 0.45 | 0.97 to 1.03 | 0.1 | 2 | yes | made, gate PASS |
| purr | CatFluffed | Sfx | short content purr, about 1.5 s | library | Roblox-Asset-Library `purr()` in audio/synth/synth.py, re-rendered as CleanACat_Sfx_Purr | 0.5 | 0.95 to 1.05 | 1.0 | 1 | no | to port |
| bowPop | BowChosen | Sfx | light round pop | synth | CleanACat_Sfx_BowPop | 0.5 | 0.95 to 1.05 | 0.15 | 1 | no | made, gate PASS |
| camera | PhotoTaken | Ui | soft double shutter click | synth | CleanACat_Ui_Camera | 0.5 | 1.0 | 0.3 | 1 | no | made, gate PASS |
| uiClick | any button | Ui | short soft tick | synth | CleanACat_Ui_Click | 0.4 | 0.98 to 1.02 | 0.05 | 2 | yes | made, gate PASS |
| meow | customer arrives, window cat idle | Sfx (3D at the cat) | short friendly meow, 3 variants, never a hiss | library | Roblox-Asset-Library `cat_voice()` / `stray_call()` in audio/synth/synth.py, three new pitches as CleanACat_Sfx_Meow_1..3 | 0.45 | 0.9 to 1.15 | 4.0 | 2 | no | to port |
| spaMusicA / spaMusicB | spa floor | Music | see brief | library | Roblox-Asset-Library audio/synth/music.py with new tunes, so Clean a Cat does not share Cat Cafe's beds | 0.5 | 1.0 | - | 1 | no | to port |

Later, not in the first slice: coin and tip jar, build finished celebration, builder kitten hammer, door bell, window tips.

## Music brief
Calm and light, like a sunny spa or a cat cafe: soft keys, plucked guitar or marimba, light brushed drums, 80 to 100 BPM, major key, no vocals. Two tracks that alternate with a 2 second crossfade so no one loop plays all session. Starts only after the player's settings are read.

## Searching the Creator Store (store rows)
The Creator Store is Roblox's library of free sounds and music from Roblox's audio partners. It needs no upload, but its music may only be used inside Roblox, never in a video off the platform. The cloud threads cannot reach the Roblox search, so these searches run in Studio on the owner's PC (Sync-Agent, Studio search with free and verified creators only, audio type, the duration range below), returning two or three candidates per cue with name, creator, id and length:

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
