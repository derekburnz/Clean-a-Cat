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
| `dirt.py` | the dirty cats (#12): mud blobs and tangles placed by casting rays at each built cat; root attributes for the scrub, brush and dryer |
| `props.py` | hook for things a cat wears (bows #14, the builder's hat #20); empty for now |

## Adding a model
1. Add a module with an `ASSETS` dict (name to `(builder(mat) -> objects, triangle budget)`), and add it to `all_assets()` in `build_all.py`.
2. Use only palette swatches. New colours go at the end of `palette.py` and in the style guide.
3. Rebuild, check `exports/gates.md`, run `python3 rbx_zfight.py`, look at the preview, and post the sheet in the PR.
