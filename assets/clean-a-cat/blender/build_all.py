"""Build every Clean a Cat model: FBX exports, Part-built Roblox models, the manifest, the gate report and sheets.

Run headless with the bpy pip module (no Blender install needed; Python 3.13, `pip install bpy==5.2.4`):

    python3 assets/clean-a-cat/blender/build_all.py                 # every asset
    python3 assets/clean-a-cat/blender/build_all.py --only Smudge   # name fragments, comma separated
    python3 assets/clean-a-cat/blender/build_all.py --render        # plus previews and sheets in docs/concepts

or inside Blender: blender -b -P assets/clean-a-cat/blender/build_all.py -- --render

Writes:
  assets/clean-a-cat/exports/<Name>.fbx     the mesh version (one palette material, UVs on swatch centres)
  assets/clean-a-cat/rbx/<Name>.model.json  the Part-built model Rojo syncs into ReplicatedStorage.Assets
  assets/clean-a-cat/exports/manifest.json  sizes, triangles, joints and coats per asset
  assets/clean-a-cat/exports/gates.md       PASS or FAIL per asset (exit 1 on a FAIL)
  docs/concepts/clean-a-cat/previews/       with --render: one preview per asset and the sheets

The framework (common, palette, rbx_export, rbx_zfight, gates, contact_sheet, cats) is ported from Derek's asset
library, derekburnz/Roblox-Asset-Library, models/blender-generators (the Cat Cafe generators), 2026-11-23.
"""

import argparse
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import bpy  # noqa: E402,F401  (bpy first: it makes bmesh and mathutils importable)
from mathutils import Matrix, Vector  # noqa: E402

import build_props  # noqa: E402
import cats  # noqa: E402
import common  # noqa: E402
import contact_sheet  # noqa: E402
import customers  # noqa: E402
import dirt  # noqa: E402
import stations  # noqa: E402
import tools  # noqa: E402
import gates  # noqa: E402
import palette  # noqa: E402
import plot  # noqa: E402
import props  # noqa: E402
import spa_props  # noqa: E402
import rbx_export  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
SLUG = "clean-a-cat"


def all_assets():
    """name -> (builder(mat) -> objects, triangle budget, module name)."""
    out = {}
    for name, (fn, budget) in cats.ASSETS.items():
        out[name] = (fn, budget, "cats")
    for name, (fn, budget) in dirt.ASSETS.items():
        out[name] = (fn, budget, "dirt")
    for module in (stations, tools, props, plot, spa_props, customers, build_props):
        for name, (fn, budget) in module.ASSETS.items():
            out[name] = (fn, budget, module.__name__)
    return out


def cat_rbx_extras(name):
    """A cat's Part model carries Rarity and Scale attributes, a Carry Attachment in its Head part (where a carried
    thing or a name tag rests, above the ears) and a BowSlot Attachment there (where a bow goes, #14), so the game
    needs no manifest at runtime."""
    cat, _gold, body = cats.parse(name)
    spec = cats.ROSTER[cat]
    k = cats.scale_of(spec, body)
    joints = cats.joints(spec, body)
    carry = Vector(joints["Head"]) + Vector(cats.carry_at(spec, body)) * k
    bow = Vector(joints["Head"]) + Vector(cats.bow_at(spec, body)) * k
    return {"attachments": [("_Head", "Carry", Matrix.Translation(carry)), ("_Head", "BowSlot", Matrix.Translation(bow))],
            "attributes": {"Scale": {"Float64": float(spec.get("scale", 1.0))}, "Rarity": spec["rarity"],
                           "Cat": cat}}


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    p = argparse.ArgumentParser()
    p.add_argument("--out", default=os.path.join(ROOT, "assets", SLUG, "exports"))
    p.add_argument("--rbx", default=os.path.join(ROOT, "assets", SLUG, "rbx"))
    p.add_argument("--docs", default=os.path.join(ROOT, "docs", "concepts", SLUG))
    p.add_argument("--only", default="", help="comma list of name fragments to build")
    p.add_argument("--render", action="store_true", help="render a preview per asset and the sheets")
    p.add_argument("--samples", type=int, default=16)
    p.add_argument("--no-fbx", action="store_true", help="skip the FBX exports")
    return p.parse_args(argv)


def main():
    args = parse_args()
    common.reset_scene()
    os.makedirs(args.out, exist_ok=True)
    png = os.path.join(args.out, palette.TEXTURE_NAME + ".png")
    palette.write_palette_png(png)
    mat = common.palette_material(png)
    wanted = [w.strip().lower() for w in args.only.split(",") if w.strip()]
    manifest, failed = [], []
    for name, (fn, budget, module) in all_assets().items():
        if wanted and not any(w in name.lower() for w in wanted):
            continue
        common.hide_all_meshes()
        built = fn(mat)
        objs, dnest, dattrs = built if isinstance(built, tuple) else (built, {}, {})
        extra = cat_rbx_extras(name) if name.startswith("CleanACat_Cat_") else {}
        if name in stations.EXTRAS:
            extra = stations.EXTRAS[name]()
        if name in props.EXTRAS:
            extra = props.EXTRAS[name]()
        for maker in (plot, spa_props, customers, build_props):
            if name in maker.EXTRAS:
                extra = maker.EXTRAS[name]()
        if dnest or dattrs:                           # a dirty cat: blobs and tangles ride their piece (dirt.py)
            extra["nest"] = {**extra.get("nest", {}), **dnest}
            extra["attributes"] = {**extra.get("attributes", {}), **dattrs}
        _rbx_path, parts = rbx_export.write_model(objs, name, args.rbx, **extra)
        if not args.no_fbx:
            common.export_asset(objs, name, args.out, glb=False)
        tris = common.tri_count(objs)
        lo, hi = common.bounds(objs)
        size = [round(v, 2) for v in (hi - lo)]
        entry = {
            "name": name, "category": name.split("_")[1], "module": module,
            "objects": [o.name for o in objs], "triangles": tris, "budget": budget, "parts": parts,
            "size_studs": {"x": size[0], "y": size[1], "z": size[2]},
            "size_roblox": [size[0], size[2], size[1]],
            "pivot": "base center (floor contact)", "front": "-Z in Roblox, the LookVector (Blender -Y)",
        }
        if name.startswith("CleanACat_Cat_"):
            cat, _g, body = cats.parse(name)
            spec = cats.ROSTER[cat]
            entry.update(rarity=spec["rarity"], body=body, pattern=spec["pattern"], dirty="_Dirty" in name)
            if dnest or dattrs:
                entry["dirt"] = {"attributes": {k: (v["Float64"] if isinstance(v, dict) else v) for k, v in dattrs.items()},
                                 "rides": {k.lstrip("_"): v.lstrip("_") for k, v in dnest.items()}}
            entry["coat"] = {f: {"swatch": sw, "hex": palette.SWATCHES[palette.idx(sw)][1]}
                             for f, sw in cats.coat(spec).items()}
            joints = cats.joints(spec, body)
            entry["joints_roblox"] = {j: common.to_roblox(p) for j, p in joints.items() if j != "Body"}
        g = gates.check(objs, name, budget, tris, lo, hi, mat=mat)
        entry["gates"] = g
        if not g["pass"]:
            failed.append(name)
        if args.render:
            path = os.path.join(args.docs, "previews", name + ".png")
            os.makedirs(os.path.dirname(path), exist_ok=True)
            common.render_preview(objs, path, res=(480, 480), samples=args.samples)
            entry["preview"] = os.path.relpath(path, ROOT)
        manifest.append(entry)
        print(f"{name}: {tris} tris, {parts} parts, {'PASS' if g['pass'] else 'FAIL ' + ', '.join(g['failed'])}")
    manifest.sort(key=lambda e: e["name"])
    if not wanted:                                    # a partial build never rewrites the shared reports
        with open(os.path.join(args.out, "manifest.json"), "w") as f:
            json.dump(manifest, f, indent=1)
            f.write("\n")
        gates.write_report(os.path.join(args.out, "gates.md"), manifest, ROOT)
        if args.render:
            for made in contact_sheet.build_sheets(args.docs, [dict(e, preview=e["preview"]) for e in manifest]):
                print("sheet:", made)
    if failed:
        print("FAIL:", ", ".join(failed))
        sys.exit(1)


if __name__ == "__main__":
    main()
