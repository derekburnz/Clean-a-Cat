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
| uiClick | not played: every HUD tap already opens a window or the tray, so a click on top would be noise (#800) | Ui | short soft tick | synth | CleanACat_Ui_Click | 0.4 | 0.98 to 1.02 | 0.05 | 2 | yes | uploaded to the group 2026-11-24, gate PASS |
| uiOpen | a window or the More tray opens (Audio/UiSounds, switch uiSounds, #800) | Ui | short soft rising pop | owner's Cat Cafe | CleanACat_Ui_Open (0.16 s) | 0.3 | 0.98 to 1.02 | 0.08 | 1 | yes | uploaded to the group 2026-11-26 (run 45894473203), gate PASS |
| uiClose | the last window or the More tray closes; an open in the same 0.03 s wins (#800) | Ui | short soft falling pop | owner's Cat Cafe | CleanACat_Ui_Close (0.16 s) | 0.25 | 0.98 to 1.02 | 0.08 | 1 | yes | uploaded to the group 2026-11-26 (run 45894473203), gate PASS |
| giftClaim | a Free Reward or the gift pet is claimed, after the server confirms it and only after a tap on the card (Effects/ClaimFx, switch claimFx, #802) | Ui | soft bright claim chime | owner's Cat Cafe | CleanACat_Sfx_GiftClaim (1.05 s) | 0.45 | - | 0.5 | 1 | no | uploaded to the group 2026-11-26 (run 45894473203), gate PASS |
| coinPop | the helper pay popup over the owner's own stand (HelperPopupController, switch helperPopFx, #801); with it on, workerDone is skipped on the owner's own plot so each finished cat sounds once | Sfx (2D, owner only) | a small bright coin pop | owner's Cat Cafe | CleanACat_Sfx_CoinPop (0.16 s) | 0.3 | 0.97 to 1.05 | 0.25 | 1 | no | uploaded to the group 2026-11-26 (run 45894473203), gate PASS |
| sudsMeow | Suds's speech bubble appears (Audio/SudsVoice, switch sudsVoice, #827) | Sfx (2D) | the meow files, quieter and a touch higher | synth (ours) | CleanACat_Sfx_Meow_1..3 | 0.28 | 1.0 to 1.15 | 60 | 1 | no | uses the meow ids already in the group |
| meow | customer arrives, window cat idle | Sfx (3D at the cat) | short friendly meow, 3 variants, never a hiss | library | CleanACat_Sfx_Meow_1..3 (mew, rising mew, trilled mrrp; ported from the library's cat_voice code) | 0.45 | 0.9 to 1.15 | 4.0 | 2 | no | uploaded to the group 2026-11-24, gate PASS |
| truckRumble | opening scene (#281), while the truck is in view | Sfx (3D at the truck) | a small friendly truck rolling by: soft low engine chug, light tyre hiss, a little rattle | synth | CleanACat_Sfx_TruckRumble (2 s seamless loop) | 0.4 | - | - | 1 | no | uploaded to the group 2026-11-24; waits on openingBox |
| truckHonk | opening scene, 0.4 s in | Sfx (3D at the truck) | one soft toot-toot, two round notes a third apart, so players look up | synth | CleanACat_Sfx_TruckHonk | 0.4 | - | 2.0 | 1 | no | uploaded to the group 2026-11-24; Derek to say honk or quiet (Design-Agent open point 3) |
| truckBump | opening scene, each axle over the bump | Sfx (3D at the truck) | rubbery thunk with a springy boing; the back wheels add a cargo rattle | synth | CleanACat_Sfx_TruckBump_1..2 (front, back) | 0.5 | - | 0.1 | 2 | no | uploaded to the group 2026-11-24 |
| truckDoor | opening scene, back wheels hit | Sfx (3D at the truck) | a latch clack and a light flap of the rear door | synth | CleanACat_Sfx_TruckDoor | 0.4 | - | 0.5 | 1 | no | uploaded to the group 2026-11-24 |
| boxThud | opening scene, the box lands (and pitched up for its small bounce) | Sfx (3D at the box) | hollow papery cardboard thud on pavement | synth | CleanACat_Sfx_BoxThud | 0.5 | 1.0, 1.25 on the bounce | 0.1 | 2 | no | uploaded to the group 2026-11-24 |
| boxRustle | opening scene, each wiggle of the box until it is tapped | Sfx (3D at the box) | two quick papery scrapes and a small bump from inside; the meow plays every other wiggle | synth | CleanACat_Sfx_BoxRustle | 0.4 | 0.95 to 1.05 | 0.5 | 1 | no | uploaded to the group 2026-11-24 |
| collarJingle | SudsNamed (switch sudsWash) | Sfx (3D at the collar) | a small gold bell shaken three times, bright and warm | synth | CleanACat_Sfx_CollarJingle | 0.5 | - | 1.0 | 1 | no | uploaded to the group 2026-11-24 |
| carryPurr | the player carries Suds from the box to the tub (Effects/Carry, switch openingBox) | Sfx (3D at the kitten, looped) | a contented purr in your arms, from Derek's library (Cat Cafe's carryPurr) | library | CleanACat_Sfx_CarryPurr | 0.45 | - | 1.0 | 1 | yes | uploaded to the group 2026-11-24, gate PASS |
| purr (reused) | SudsTapped (switch sudsMascot) | Sfx | the same purr as CatFluffed; minGap 1 s keeps fast taps from stacking | library | CleanACat_Sfx_Purr_1..2 | 0.5 | 0.95 to 1.05 | 1.0 | 1 | no | bound, waits on SudsTapped |
| foamSwell | BathFoamy ("so foamy", switch latherFoam) | Sfx (3D at the cat) | a soft cluster of rising bubbles over a faint airy shimmer | synth | CleanACat_Sfx_FoamSwell (0.85 s) | 0.45 | 0.97 to 1.03 | 1.0 | 1 | no | uploaded to the group 2026-11-25, gate PASS |
| rinseLoop | RinseSpray, stops 0.2 s after the last spray (switch washMeter) | Sfx (3D at the cat, looped) | a soft even shower hiss with tiny droplet ticks, never a blasting hose | synth | CleanACat_Sfx_RinseLoop (2 s seamless loop) | 0.3 | - | - | 1 | no | uploaded to the group 2026-11-25, gate PASS |
| foamDrop | ShakeOff "rinse": the last foam lands round the feet | Sfx (3D at the cat) | four soft muted plops, each a little lower | synth | CleanACat_Sfx_FoamDrop (0.7 s) | 0.45 | 0.97 to 1.03 | 0.5 | 1 | no | uploaded to the group 2026-11-25, gate PASS |
| stepChime | ShakeOff (any step's bar fills), with catShake | Sfx | three small soft notes stepping up and a faint sparkle, smaller than revealChime | synth | CleanACat_Sfx_StepChime (0.7 s) | 0.4 | - | 0.5 | 1 | no | uploaded to the group 2026-11-25, gate PASS |
| clawSnip | ClawSnipped | Sfx | one small soft clipper snip, never a crunch | synth | CleanACat_Sfx_ClawSnip (0.09 s) | 0.4 | 0.95 to 1.08 | 0.05 | 2 | no | uploaded to the group 2026-11-25, gate PASS |
| bubblePop (reused) | SudsPopped | Sfx | the scrub's tiny pops | synth | CleanACat_Sfx_BubblePop_1..3 | 0.35 | 0.92 to 1.08 | 0.12 | 3 | yes | bound 2026-11-25 |
| visitorChime | VisitorArrived (special customers; Moment to come) | Sfx (3D at the visitor) | a soft harp-like rising pentatonic run with a light shimmer, inviting, never a fanfare | synth | CleanACat_Sfx_VisitorChime (1.3 s) | 0.45 | - | 3.0 | 1 | no | uploaded to the group 2026-11-25, gate PASS; waits on the Moment |
| crateDrop | CrateDropped (the visitor's crate; Moment to come) | Sfx (3D at the crate) | a soft hollow wooden bonk, a small bounce, then a two-note twinkle | synth | CleanACat_Sfx_CrateDrop (0.8 s) | 0.5 | - | 0.5 | 1 | no | uploaded to the group 2026-11-25, gate PASS; waits on the Moment |
| bowTie | BowTied (the easy last step; Moment to come) | Sfx (3D at the cat) | a quick soft ribbon swish and a tiny two-note sparkle | synth | CleanACat_Sfx_BowTie (0.45 s) | 0.45 | 0.97 to 1.03 | 0.3 | 1 | no | uploaded to the group 2026-11-25, gate PASS; waits on the Moment |
| heartLow | HeartLow (a waiting cat's heart bar gets low; Moment to come) | Sfx (3D at the cat) | a soft two-note nudge stepping down, a reminder, never an alarm | synth | CleanACat_Sfx_HeartLow (0.6 s) | 0.35 | - | 4.0 | 1 | no | uploaded to the group 2026-11-25, gate PASS; waits on the Moment |
| catLeave | CatLeft (the bar is empty and the cat leaves; Moment to come) | Sfx (3D at the cat) | three gentle falling notes over a soft whoosh going away, kind to young players | synth | CleanACat_Sfx_CatLeave (1.0 s) | 0.4 | - | 1.5 | 1 | no | uploaded to the group 2026-11-25, gate PASS; waits on the Moment |
| crateOpen | CrateOpened (tap to open; Moment to come) | Sfx | a soft wooden knock, a puff of air and a short rising sparkle; the same for every pet, no near-miss build-up | synth | CleanACat_Sfx_CrateOpen (0.9 s) | 0.5 | - | 0.5 | 1 | no | uploaded to the group 2026-11-25, gate PASS; waits on the Moment |
| petReveal | PetRevealed (Moment to come) | Sfx | a warm major chord blooming up with a shimmer; one sound for every rarity | synth | CleanACat_Sfx_PetReveal (1.5 s) | 0.5 | - | 0.8 | 1 | no | uploaded to the group 2026-11-25, gate PASS; waits on the Moment |
| starUp | PetStarUp (three pets fuse; Moment to come) | Sfx | a soft rising swirl, a quick four-note climb and one bright held bell | synth | CleanACat_Sfx_StarUp (1.3 s) | 0.5 | - | 0.8 | 1 | no | uploaded to the group 2026-11-25, gate PASS; waits on the Moment |
| workerDone | WorkerFinished (Moment to come) | Sfx (3D at the cat) | one small soft ding and a bubble, quieter than the player's own reveal | synth | CleanACat_Sfx_WorkerDone (0.5 s) | 0.3 | 0.97 to 1.03 | 0.6 | 1 | no | uploaded to the group 2026-11-25, gate PASS; waits on the Moment |
| buildDone | BuildFinished (Moment to come) | Sfx (3D at the build) | two soft mallet taps, then a warm rising chord with a shimmer | synth | CleanACat_Sfx_BuildDone (1.4 s) | 0.5 | - | 1.0 | 1 | no | uploaded to the group 2026-11-25, gate PASS; waits on the Moment |
| questDone | QuestDone (Moment to come) | Ui | a small happy two-note ta-da with a tick of sparkle | synth | CleanACat_Ui_QuestDone (0.7 s) | 0.45 | - | 0.4 | 1 | no | uploaded to the group 2026-11-25, gate PASS; waits on the Moment |
| checkIn | CheckInClaimed (Moment to come) | Ui | three light bell taps like coins in a jar | synth | CleanACat_Ui_CheckIn (0.8 s) | 0.45 | - | 0.5 | 1 | no | uploaded to the group 2026-11-25, gate PASS; waits on the Moment |
| spaMusicA / spaMusicB | spa floor | Music | see brief | synth | CleanACat_Music_SpaA (Warm Bubbles, 92 BPM marimba) and CleanACat_Music_SpaB (Fluff and Fold, 80 BPM piano and flute), new songs from assets/clean-a-cat/audio/synth/music.py | 0.5 | 1.0 | - | 1 | no | uploaded to the group 2026-11-26 (SpaA rbxassetid://107621531888888, SpaB rbxassetid://89957079712346); plays only with the spaMusic switch; SpaA gate WARN on the seam (downbeat level, same as every phrase start), listen |

Later, not in the first slice: coin and tip jar, builder kitten hammer, door bell, window tips.

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
