"""Per-asset quality gates for the Clean a Cat generators (written to exports/gates.md).

Idea borrowed from ozanzeng/blender-LPM-skill (gate_report.py): every asset gets a PASS/FAIL
line with numbers, so nobody has to eyeball budgets, pivots, materials or UVs. build_all.py
calls check() per asset, stores the result in manifest.json and writes the report with
write_report(). A FAIL makes the build exit non-zero, a WARN does not.

Checks (FAIL): budget, transforms applied, one palette material per object, every face UV'd to
a swatch center, naming (CleanACat_<Category>_<Name>, object names prefixed with the asset name),
qa (the blender-asset-qa skill's qa_check.py, roblox profile, UVs off because ours are checked
above: n-gons, flipped or inconsistent faces, open or non-manifold geometry, faces in one plane,
floating parts).
Checks (WARN): pivot (floor contact, wall back plane or ceiling hook per PIVOT_NOTES), centered
footprint (x and y bounds symmetric around the pivot), and any qa warning that is not in
QA_ACCEPTED below.

The qa check runs inside the build since issue #160 (2026-11-24): before that it was a step to
remember, and a day of models went out without it.
"""

import math
import os
import re
import sys

import palette

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", ".claude", "skills",
                                "blender-asset-qa", "scripts"))
import qa_check  # noqa: E402  (the vendored EL4CTEO/blender-skills script, see .claude/skills/THIRD_PARTY.md)

CATEGORIES = ("Cat", "NPC", "Station", "Tool", "Prop", "Bow", "Mud", "Area", "Street", "Decor")
FAIL_CHECKS = ("budget", "transforms", "material", "uv", "naming", "qa")
WARN_CHECKS = ("pivot", "centered", "qa_warn")
# qa warnings we accept, each with its reason (the skill: a warning is fixed or accepted with a reason). Anything
# else the script warns about shows as a WARN on the asset. No qa error is accepted.
QA_ACCEPTED = (
    ("back to back", r"hidden back-to-back faces",
     "A model is boxes that touch, and each box becomes one Roblox Part, so the faces where two boxes meet stay. "
     "They are never seen."),
    ("shared corners", r"duplicate verts",
     "Boxes that touch share corner positions. Welding them joins two boxes into one mesh island and flips faces, "
     "which is the n-gon and winding failure #160 fixed."),
    ("pivot off the floor", r"not resting on ground plane",
     "Held tools, hats, bows and wall props pivot where they are held or hung, not on the floor, and a few floor "
     "pieces sink a hair into it so no face lies in the floor's plane. The pivot gate lists each one."),
    ("enclosed parts", r"fully enclosed, not touching",
     "Pieces that sit inside an invisible barrier box or behind glass: shelf items inside a station's barrier, the "
     "tip jar's screen. Meant."),
)
EPS = 0.02           # studs, pivot and centering tolerance
UV_EPS = 1e-3        # distance from a swatch center in UV space
_SWATCH_CENTERS = [palette.uv_center(i) for i in range(palette.GRID * palette.ROWS)]


def _near_swatch(u, v):
    return any(abs(u - cu) < UV_EPS and abs(v - cv) < UV_EPS for cu, cv in _SWATCH_CENTERS)


def check(objs, name, budget, tris, lo, hi, pivot_note=None, mat=None):
    """Return {"pass": bool, "failed": [..], "warnings": [..], "checks": {check: detail}}."""
    checks = {}
    pivot_note = pivot_note or "base center"

    checks["budget"] = (tris <= budget, f"{tris}/{budget} tris")

    bad = [o.name for o in objs
           if any(abs(s - 1) > 1e-6 for s in o.scale) or any(abs(r) > 1e-6 for r in o.rotation_euler)]
    checks["transforms"] = (not bad, "scale 1, rotation 0" if not bad else "unapplied: " + ", ".join(bad))

    want = mat.name if mat is not None else palette.TEXTURE_NAME
    bad = [o.name for o in objs if len(o.data.materials) != 1 or o.data.materials[0] is None
           or o.data.materials[0].name != want]
    checks["material"] = (not bad, f"one material ({want})" if not bad else "not one palette material: " + ", ".join(bad))

    uv_bad, faces = [], 0
    for o in objs:
        layer = o.data.uv_layers.active
        if layer is None:
            uv_bad.append(f"{o.name}: no UV layer")
            continue
        data = layer.data
        off = 0
        for p in o.data.polygons:
            faces += 1
            uvs = [tuple(data[li].uv) for li in p.loop_indices]
            first = uvs[0]
            if any(abs(u - first[0]) > 1e-6 or abs(v - first[1]) > 1e-6 for u, v in uvs) or not _near_swatch(*first):
                off += 1
        if off:
            uv_bad.append(f"{o.name}: {off} faces off swatch centers")
    checks["uv"] = (not uv_bad, f"{faces} faces on swatch centers" if not uv_bad else "; ".join(uv_bad))

    parts = name.split("_")
    ok_name = len(parts) >= 3 and parts[0] == "CleanACat" and parts[1] in CATEGORIES
    bad = [o.name for o in objs if not (o.name == name or o.name.startswith(name + "_"))]
    checks["naming"] = (ok_name and not bad,
                        "CleanACat_<Category>_<Name>" if ok_name and not bad else
                        ("bad asset name" if not ok_name else "objects not prefixed: " + ", ".join(bad)))

    if "ceiling" in pivot_note:
        ok = abs(hi.z) <= 0.05
        detail = f"hook at z={hi.z:.2f} (want 0)"
    elif "wall" in pivot_note:
        ok = abs(hi.y) <= EPS
        detail = f"back plane at y={hi.y:.2f} (want 0)"
    else:
        ok = abs(lo.z) <= EPS
        detail = f"floor at z={lo.z:.2f} (want 0)"
    checks["pivot"] = (ok, detail)

    cx, cy = (lo.x + hi.x) / 2, (lo.y + hi.y) / 2
    ok = abs(cx) <= EPS * 2.5 and ("wall" in pivot_note or abs(cy) <= EPS * 2.5)
    checks["centered"] = (ok, f"footprint center x={cx:.2f} y={cy:.2f}")

    q = qa_check.run(objects=[o.name for o in objs], profile="roblox", uv=False)
    errors = [e.replace(name, "") for e in q.get("errors", [])]
    checks["qa"] = (not errors, "blender-asset-qa clean" if not errors else "; ".join(errors))
    accepted, other = {}, []
    for w in q.get("warnings", []):
        kind = next((k for k, pattern, _why in QA_ACCEPTED if re.search(pattern, w)), None)
        if kind:
            accepted[kind] = accepted.get(kind, 0) + 1
        else:
            other.append(w.replace(name, ""))
    checks["qa_warn"] = (not other, "no qa warning outside the accepted kinds" if not other else "; ".join(other))

    failed = [k for k in FAIL_CHECKS if not checks[k][0]]
    warnings = [k for k in WARN_CHECKS if not checks[k][0]]
    return {"pass": not failed, "failed": failed, "warnings": warnings, "qa_accepted": accepted,
            "checks": {k: v[1] for k, v in checks.items()}}


def write_report(path, manifest, root):
    """exports/gates.md from the manifest entries that carry a "gates" result."""
    entries = [e for e in manifest if "gates" in e]
    n_fail = sum(1 for e in entries if not e["gates"]["pass"])
    n_warn = sum(1 for e in entries if e["gates"]["pass"] and e["gates"]["warnings"])
    lines = [
        "# Asset gates",
        "",
        f"Generated by `build_all.py` (no build time, so parallel model PRs don't conflict on this line). "
        f"{len(entries)} assets: {len(entries) - n_fail} PASS ({n_warn} with warnings), {n_fail} FAIL. "
        "FAIL checks: budget, transforms, material, uv, naming, qa, WARN checks: pivot, centered, qa_warn. "
        "Fix a FAIL in the generator module and rebuild; a WARN needs a look at the asset's preview in "
        "`docs/concepts/clean-a-cat/previews/` (build with --render).",
        "",
        "`qa` is the `blender-asset-qa` skill's `qa_check.py` (roblox profile, UVs off) run on every asset's "
        "meshes: n-gons, flipped faces, open geometry, faces in one plane and floating parts fail the build. "
        "The warnings it gives that we accept, each with its reason and the number of assets that have it:",
        "",
    ] + [f"- **{kind}** ({sum(1 for e in entries if kind in e['gates'].get('qa_accepted', {}))} assets): {why}"
         for kind, _pattern, why in QA_ACCEPTED] + [
        "",
        "| asset | result | tris / budget | size (studs) | failed | warnings |",
        "|---|---|---|---|---|---|",
    ]
    for e in entries:
        g = e["gates"]
        s = e["size_studs"]
        lines.append(f"| {e['name']} | {'PASS' if g['pass'] else 'FAIL'} | {e['triangles']} / {e['budget']} | "
                     f"{s['x']} x {s['y']} x {s['z']} | {', '.join(g['failed']) or ''} | {', '.join(g['warnings']) or ''} |")
    problems = [e for e in entries if e["gates"]["failed"] or e["gates"]["warnings"]]
    if problems:
        lines += ["", "## Details", ""]
        for e in problems:
            g = e["gates"]
            lines.append(f"- **{e['name']}**: " + "; ".join(
                f"{k} {'FAIL' if k in g['failed'] else 'WARN'}: {g['checks'][k]}" for k in g["failed"] + g["warnings"]))
    lines.append("")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write("\n".join(lines))
    return path
