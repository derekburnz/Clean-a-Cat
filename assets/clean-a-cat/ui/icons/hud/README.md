# HUD button pictures (issue 185)

The six HUD button pictures Derek picked on 2026-11-24 ("go with B for now"): our ink outline and Bubble Pastel
colours on the chunky 3D look of his asset library's coin. 512 px, see-through.

| File | Button |
|---|---|
| `CleanACat_Icon_Hud_Coins.png` | coin counter: Derek's library coin (Cat Cafe `CatCafe_Icon_Coins`) with its outline redrawn in our ink, his calls on 2026-11-24 |
| `CleanACat_Icon_Hud_Index.png` | Cat Index |
| `CleanACat_Icon_Hud_Tools.png` | Tools (an open toolbox with its handle up, a brush and a soap bottle, Derek 2026-11-24; shut, it read as a lunchbox at phone size) |
| `CleanACat_Icon_Hud_Helper.png` | Helpers (a staff head: helpers are human staff; a placeholder until Derek's staff ideas) |
| `CleanACat_Icon_Hud_Build.png` | Build |
| `CleanACat_Icon_Hud_Settings.png` | Settings (in the menu, not on the HUD) |

- Made by `assets/clean-a-cat/blender/hud_icons.py` (Model-Agent), except the coin, which `assets/clean-a-cat/blender/hud_coin.py` makes from the library file by redrawing only its outline. Change the generator and re-render; don't edit
  these by hand.
- Never shown below 48 px (design size). `../../screens/hud.html` uses them at 52 px on the tray and 48 px on the coins.
- Not uploaded yet. When they are, upload under the Creampuff Games group and check that they load in the live game.
  Settle on one ink first: these six use #45226B, and the older `_ink` model icons use #3B2D45.
- In Luau the asset ids live in one lookup table, so swapping the set later is a one-place change ("for now").
- The flat two-tone set Derek didn't pick (A) and the comparison sheet are in the project's shared folder,
  `Design-Agent/icon-blends-2026-11-24/`. The comparison is also at `docs/concepts/clean-a-cat/2026-11-24-icon-blends.png`.

## Small pictures

Eighteen smaller pictures in the same style for spots that would otherwise show an emoji: `CleanACat_Icon_Hud_`
Camera, Paw, Heart, Gift, Music, Speaker, Shake, Sparkle, Dice, Check, Crown, Lock, Mud, Tangles, Wet, Pointer, Star and
Station (`.png`, 512 px). Model-Agent drew them and Review-QA passed them down to 28 px (#253, #257, #261), so unlike
the six button pictures above they may show from 28 px up. They are uploaded under the group like the rest.
