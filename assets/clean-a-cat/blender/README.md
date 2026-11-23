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
| `palette.py` | every swatch (style guide section 2) and the palette texture writer |
| `common.py` | `Builder` primitives tagged with a swatch, FBX export, previews (library port) |
| `rbx_export.py` | Part-built `.model.json` from the Builder's log; Clean a Cat's collision, tag and naming tables at the top |
| `rbx_zfight.py` | finds and fixes faces that would flicker in the Part models; `python3 rbx_zfight.py` reports |
| `gates.py` | PASS or FAIL per asset: budget, transforms, material, UVs, naming |
| `contact_sheet.py` | tiles previews into sheets |
| `cats.py` | the cat bodies (A walking, B sitting) from the library and Clean a Cat's roster of ten coats (`ROSTER`) |
| `dirt.py` | the dirty cats (#12): mud blobs, tangles and the hidden fluffed look (#14) placed by casting rays at each built cat; root attributes for the scrub, brush and dryer |
| `stations.py` | the spa stations: the wash tub (#13), the brush table, its upgrade and the hood dryer with its `Nozzle` (#18), each with a `CatSeat` attachment |
| `tools.py` | hand tools: the three sponges (#13) and the brush (#14), each with a `Handle` part |
| `plot.py` | the spa plot (#15): today the graybox with every gameplay spot as an Attachment (`SPOTS`) |
| `spa_props.py` | the carrier, stray box, chance board and queue mat (#16); the window cushion, tip jar and spa sign (#17); the build pad for a locked station (#18) |
| `customers.py` | the customers' accessories for the R15 rig and the four looks (`LOOKS`, #16) |
| `props.py` | the three bows (#14) with their `BowSlot` attachment, and the hook for props built into a cat (the builder's hat, #20) |
| `scenes.py` | scene pictures for review, with a stand-in avatar for scale (`scenes.py tub <out.png>`, `groom`, `groom-close`, `plot <folder>` for the five plot views, or `customers`); exports nothing |

## Adding a model
1. Add a module with an `ASSETS` dict (name to `(builder(mat) -> objects, triangle budget)`), and add it to `all_assets()` in `build_all.py`.
2. Use only palette swatches. New colours go at the end of `palette.py` and in the style guide.
3. Rebuild, check `exports/gates.md`, run `python3 rbx_zfight.py`, look at the preview, and post the sheet in the PR.
