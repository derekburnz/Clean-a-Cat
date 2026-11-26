# Uploaded portraits

Portrait pictures that are uploaded to the group and shown by id in the game, kept here so the upload workflow has
a file to take (`.github/workflows/upload-asset.yml`).

| File | Shown as | Made by |
|---|---|---|
| `CleanACat_UI_Portrait_Suds.png` | `Portraits.luau`, `Suds`: Suds's face on the HUD and in his help bubble | `ui_renders.py --only portrait` then `ui_compose.py` (the `portrait_Suds_ink` picture, 512 px, see-through) |
| `CleanACat_UI_Portrait_<Cat>.png` (20 cats) | `Portraits.luau`, `<Cat>`: the Cat Index, recap, bench card when clean | the same renders, `portrait_<Cat>_ink` (#794) |
| `CleanACat_UI_Portrait_<Cat>_Dirty1.png` to `_Dirty4.png` (20 cats, 80 files) | `Portraits.luau`, `<Cat>_Dirty1` to `<Cat>_Dirty4`: the bench card at the cat's dirt level | `portrait_<Cat>_Dirty<n>_ink` from Model-Agent's `faces-dirt-2026-11-26` renders, after the tangle and fluff rework (#791, PR 831) |

- All four dirt levels were rendered again on 2026-11-26 after the tangle and fluff rework (#791); level 1 replaces the first upload and needs new ids.
- Rendered again on 2026-11-26 with the round cheeks (#771, #784). The first upload (2026-11-24) had the cheek bars.
- Render, don't edit by hand. Upload under the Creampuff Games group and check the picture loads in the dev game.
