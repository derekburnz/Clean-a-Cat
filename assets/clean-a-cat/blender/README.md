# Clean a Cat Blender generators

Owner: asset-artist (Model-Agent). Read `docs/art/style-guide.md` and the `asset-pipeline` skill first.

Every model is built from the Python in this folder; nothing is hand-modelled. A style change is a code edit and a rebuild. The framework is ported from Derek's asset library (derekburnz/Roblox-Asset-Library, `models/blender-generators`, the Cat Cafe generators) on 2026-11-23.

## Run it

Headless, with no Blender install (Python 3.13):

```sh
python3 -m venv .venv && .venv/bin/pip install bpy==5.2.4   # .venv is gitignored
.venv/bin/python assets/clean-a-cat/blender/build_all.py --render
```

On the PC with Blender 5.2: `blender -b -P assets/clean-a-cat/blender/build_all.py -- --render`.

Flags: `--only Smudge,Tux` (name fragments; a partial build leaves the manifest and gate report alone), `--render` (previews and sheets), `--no-fbx`.

## Files

| file | what |
|---|---|
| `build_all.py` | builds every asset: FBX, Part model, manifest, gates, previews; exits 1 on a gate FAIL |
| `palette.py` | every swatch (style guide section 2), the palette texture writer and `CLEAR_SWATCHES`, the swatches drawn see-through (a soap bubble, #111) |
| `common.py` | `Builder` primitives tagged with a swatch, FBX export, previews (library port); `render_still` draws objects of soap bubbles see-through in pictures only |
| `rbx_export.py` | Part-built `.model.json` from the Builder's log; Clean a Cat's collision, tag and naming tables at the top |
| `rbx_zfight.py` | finds and fixes faces that would flicker in the Part models; `python3 rbx_zfight.py` reports |
| `gates.py` | PASS or FAIL per asset: budget, transforms, material, UVs, naming, and the `blender-asset-qa` skill's `qa_check.py` (roblox profile) |
| `contact_sheet.py` | tiles previews into sheets |
| `cats.py` | the cat bodies (A walking, B sitting) from the library and Clean a Cat's roster of ten coats (`ROSTER`) |
| `dirt.py` | the dirty cats (#12): the mud coat (#113: 20 pieces that wrap the cat's own blocks, listed once per body), tangles and the hidden fluffed look (#14) placed by casting rays at each built cat, and the hidden long claws (#23); root attributes for the scrub, brush and dryer |
| `stations.py` | the spa stations: the wash tub (#13), the brush table, its upgrade and the hood dryer with its `Nozzle` (#18), the bubble bath with its `Spout` and the pawdicure (#23), each with a `CatSeat` attachment |
| `tools.py` | hand tools: the three sponges (#13), the brush (#14) with its fluffy and golden upgrades and the rain and golden showers (#142), and drafts for the other wash steps (#123: shower, comb, tweezers, towel, nail clipper, hand dryer, shampoo), each with a `Handle` part |
| `plot.py` | the spa plot (#15): the real build on the graybox layout, every gameplay spot an Attachment (`SPOTS`) |
| `street.py` | the street (#15): ground, pavements, road, houses, hedges, trees and edge barriers round six plots, with `PlotSlot1` to `PlotSlot6` |
| `spa_props.py` | the carrier, stray box, chance board and queue mat (#16); the window cushion, tip jar and spa sign (#17); the build pad for a locked station (#18) |
| `build_props.py` | the builder kitten (#20): the kitten in its own coat with `HatSlot` and `HammerGrip`, the hard hat, the hammer pivoted at its grip and the toolbox with `CountdownAnchor` |
| `rewards.py` | reward props (#125): the paw coin, the star and the coin stack, pivoted at their middles for spinning and popping |
| `burrs.py` | things stuck in the fur (#126): the burr, the leaf and the forked twig, pivoted at the underside with up out of the fur |
| `busy_spa.py` | a busy spa (#124): the waiting bench with `Spot1..3` and `Tag1..3`, the front desk with `Bell`, `TipJarSpot` and a `Screen` card, three helper kittens in smocks with `HatSlot` and `ToolGrip`, their bath caps, the rare visitor's beret and shades, and the framed star photo the visitor leaves (#142) |
| `ui_renders.py`, `ui_compose.py` | pictures of the models for the screens (#127): see-through cat portraits and model icons rendered from the real models, then trimmed, outlined in the UI's ink and laid out on a check sheet at 128, 64 and 32 px |
| `hud_icons.py` | five of the HUD's six button pictures (#185): settings, Cat Index, tools, helper and build, 512 px with a thick ink outline, in a blend of our look and the library's HUD icons. The coin is the library's own picture, not rendered here. Render only, not in `build_all.py` |
| `vip.py` | the VIP Room before it is built (#21): the locked look (door, sign `Screen`, tarp over scaffold) and the building look (frame half up) at `SpotVipDoor` |
| `coat_table.py` | the coat table (#22): `rbx/CleanACat_CoatTable.json`, read in game as `ReplicatedStorage.Assets.CleanACat_CoatTable` (rarity, index order, colours and model names per cat) |
| `store_art.py` | store art (#24): the raw icon and thumbnail shots from the real models, with a see-through background and shadows (`store_art.py <folder> [names] [--final]`); `thumb-spa` is the picked thumbnail and uses a store-art-only claw-foot bath ported from Derek's Bathtub Sofa (#116) |
| `store_compose.py` | store art (#24), plain Python with Pillow: backdrops, the game's name as the only words, the 512 icon and 1280 or 1920 thumbnails, and the draft sheet with 150 and 48 px checks; `compose_spa` makes the picked look (stacked title, bubble backdrop; title font Lilita One, OFL, via `TITLE_FONT`) |
| `customers.py` | the customers' accessories for the R15 rig and the four looks (`LOOKS`, #16) |
| `props.py` | the three bows (#14) with their `BowSlot` attachment, and the hook for props built into a cat (the builder's hat, #20) |
| `scenes.py` | scene pictures for review, with a stand-in avatar for scale (`scenes.py tub <out.png>`, `groom`, `groom-close`, `plot <folder>` for the five plot views, `street <folder>`, or `customers`, `later` for the #23 stations, `mud <out.png>` and `foam <out.png>` for the #107 close-ups); exports nothing |

## Adding a model
1. Add a module with an `ASSETS` dict (name to `(builder(mat) -> objects, triangle budget)`), and add it to `all_assets()` in `build_all.py`.
2. Use only palette swatches. New colours go at the end of `palette.py` and in the style guide.
3. Rebuild, check `exports/gates.md` (it now holds the QA skill's result too: a `qa` FAIL names the two objects whose faces share a plane), run `python3 rbx_zfight.py`, look at the preview, and post the sheet in the PR.
