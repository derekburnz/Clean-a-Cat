# Uploaded portraits

Portrait pictures that are uploaded to the group and shown by id in the game, kept here so the upload workflow has
a file to take (`.github/workflows/upload-asset.yml`).

| File | Shown as | Made by |
|---|---|---|
| `CleanACat_UI_Portrait_Suds.png` | `Portraits.luau`, `Suds`: Suds's face on the HUD and in his help bubble | `ui_renders.py --only portrait` then `ui_compose.py` (the `portrait_Suds_ink` picture, 512 px, see-through) |
| `CleanACat_UI_Portrait_<Cat>.png`, `..._<Cat>_Dirty1.png` (20 cats) | `Portraits.luau`, `<Cat>` and `<Cat>_Dirty1`: the Cat Index, recap, bench card (dirt level 1 and up) | the same renders, `portrait_<Cat>_ink` and `portrait_<Cat>_Dirty1_ink` (#794) |

- Dirt levels 2 to 4 wait for the tangle and fluff rework (#791); until then the bench card shows level 1 for them.
- Rendered again on 2026-11-26 with the round cheeks (#771, #784). The first upload (2026-11-24) had the cheek bars.
- Render, don't edit by hand. Upload under the Creampuff Games group and check the picture loads in the dev game.
