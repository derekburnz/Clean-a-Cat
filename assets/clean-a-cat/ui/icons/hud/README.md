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

## Menu pictures (issue 527)

Six more in the button pictures' build, for the menu buttons and cards of milestone 1: `CleanACat_Icon_Hud_`
Quests (a clipboard with a tick), Shop (a shopfront under a striped awning), Pets (a cat's head in a collar with a
bell), Crate (the pet crate), Bow (the bow a washed cat wears) and Helpers (Jo of the staff in the headband and the
bib apron, for the HUD's Helpers button; the older `Helper` picture has neither). `.png`, 512 px, see-through, made
by `hud_icons.py`. Checked down to 36 px; the sheet is `docs/concepts/clean-a-cat/2026-11-26-menu-icons.png`.
Uploaded under the group like the rest once Review-QA has passed them.

## Round cheeks (issue 784)

`Helper` and `Helpers` were rendered again on 2026-11-26: the staff's cheeks are round, as on the models (#776), where
they were small bars. Nothing else in the two pictures changed. They are uploaded again as new assets; the ids in
`HUD/Icons.luau` are Design-Agent's to swap.

## Staff apron (issue 929)

`CleanACat_Icon_Hud_Staff.png`, for the Helpers button and the Helpers window badge. Derek, 2026-11-26: "switch the
helper icon to be something other then the first helper". The staff's cream bib apron on its own, no person and no
face, so the button never looks like one helper: a big pink paw on the bib, a pink neck loop, waistband, ties and hem,
and a mint pocket with the yellow sponge and the sky brush standing in it. Review-QA found the first draft read as a tote bag at 36 px under the Shop button, so the bib is narrow for a T, the neck loop is a thin cord, the waist ties stand out at the sides and the sponge and brush are bigger. Made by `hud_icons.py` (`Staff`), checked at
48 and 36 px beside Shop, Pets and Quests. `Helpers` (Jo) stays for anything that means Jo herself.

## The like how-to pictures (issue 869)

Pictures for Design-Agent's two second loop that shows how to like the game (Growth-Agent's spec, 2026-11-26).
`CleanACat_Icon_Hud_HeartOutline.png` is a heart in a soft grey with a pale inset, not yet pressed; pressed, the loop
shows the `Heart` icon. `CleanACat_Icon_Hud_TapDot.png` is a soft round cream dot on a pink rim, where the tap lands.
`CleanACat_Icon_Hud_RingPuff.png` is a pink ring with eight short butter rays, the burst where it taps. Made by
`hud_icons.py` (`HeartOutline`, `TapDot`, `RingPuff`) and checked at 48 px.

No picture here is a hand. The first set (2026-11-26) used a thumbs up and a hand pointing up with one finger, and
Open Cloud answered "User is moderated" minutes after they were uploaded; a fist with one tall raised digit can read
as a rude gesture to an image check at icon size. Roblox moderation misread the pressed thumbs up and
suspended Derek's account. All three were removed on 2026-11-27, and their sha256s are on
`.github/upload-blocked.txt`, so the upload workflow refuses them under any name. Draw no hand, finger or gesture in
any picture; use hearts, dots and rings instead.
