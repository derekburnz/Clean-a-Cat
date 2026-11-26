"""Does a worn bow cut into a cat's own head piece? Measured on the Part-built models (assets/clean-a-cat/rbx), as the
game puts them together: the bow's `BowSlot` Attachment on the head's `BowSlot` (Spa/BowFit.luau), the bow at the
cat's `Scale` attribute times its `BowScale` (#845), its `_Fan` left off a cat with a head piece.

A look in Blender is not enough (#782): a loop is an eight sided ball there and a smooth one in Roblox, a sitting cat
is built at 0.95 while its bow comes at 1.0, and a thin rod can sit whole inside a loop with no two faces crossing.
So this reads the Parts and measures the gap between each bow part and each piece on the head (the head piece, its
lit and glass parts, the ears) twice:

  seen    by the shape Roblox draws: a ball for a SpecialMesh Sphere, a Cylinder, a Ball, else the block
  query   by the shape a part query in Studio sees: the block for a SpecialMesh part (Sync-Agent's part check)

A gap is the widest clear space between the two shapes over 900 directions (both are convex, so that is their
distance); under zero is how deep they overlap. `head` is the same for the head itself: every bow should touch it
(at or under zero) and not be buried. `ear` is the cat's ears: since #845 these cats wear the bow on the head's top
corner like every other cat, in front of the left ear's base, so up to EAR_OK into an ear is the look. On Bathtile
and Djinn (PINNED) the head piece covers the whole top, so the bow is pinned to its front corner instead: it must
touch the piece, at most PIN_DEEP into it, and need not touch the head.

  python3 rbx_bowfit.py [--only Stardust,Bathtile] [--all]

Prints one row per cat model and bow tier (the worst of the three colours, which share their shapes) and ends with
exit code 1 when a seen gap is under zero. `--all` lists every model; without it, twins with the same numbers fold
into one row. Needs numpy.
"""

import argparse
import glob
import json
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
RBX = os.path.join(HERE, "..", "rbx")
TIERS = ("", "Double", "Royal", "Golden")
COLOURS = ("Pink", "Mint", "Sky")
ON_HEAD = ("_Prop", "_Glow", "_Glass", "_Ear")        # Models under the Head whose parts a bow must clear
BURIED = -0.09                                        # a bow sunk further than this into the head is lost in it
EAR_OK = -0.09         # every cat's corner bow stands in front of its left ear's base, about 0.08 into it (#845)
PINNED = {"Bathtile", "Djinn"}   # the cap and the turban cover the whole top: the bow is pinned to the piece's front
PIN_DEEP = -0.065      # corner (#845), touching it and at most this far into it


def _cframe(props):
    c = props["CFrame"]
    c = c.get("CFrame", c)
    m = np.eye(4)
    m[:3, :3] = np.array(c["orientation"])
    m[:3, 3] = c["position"]
    return m


def parts(node, path="", out=None):
    """Every Part under `node` with its place, size, Attachments and the two shapes it has (seen, query)."""
    out = [] if out is None else out
    name = node.get("name") or ""
    if node.get("className") == "Part":
        p = node["properties"]
        kids = node.get("children", [])
        atts = {c["name"]: _cframe(c["properties"]) for c in kids if c.get("className") == "Attachment"}
        mesh = [c for c in kids if c.get("className") == "SpecialMesh"]
        query = {"Cylinder": "cyl", "Ball": "ball"}.get(p.get("Shape"), "box")
        seen = "ell" if mesh and mesh[0]["properties"].get("MeshType") == "Sphere" else query
        out.append(dict(path=path, name=name, m=_cframe(p), size=np.array(p["Size"], dtype=float), atts=atts,
                        seen=seen, query=query))
    for c in node.get("children", []):
        parts(c, path + "/" + name if node.get("className") == "Model" else path, out)
    return out


def _directions(n=900):
    i = np.arange(n) + 0.5
    ph, th = np.arccos(1 - 2 * i / n), np.pi * (1 + 5 ** 0.5) * i
    return np.stack([np.cos(th) * np.sin(ph), np.sin(th) * np.sin(ph), np.cos(ph)], 1)


DIRS = _directions()


def _reach(m, size, kind, d):
    """How far the shape reaches from its middle along each direction in `d`."""
    loc, h = d @ m[:3, :3], size / 2
    if kind == "box":
        return np.abs(loc) @ h
    if kind == "ell":
        return np.sqrt(((loc * h) ** 2).sum(1))
    if kind == "ball":
        return np.full(len(d), h.min())
    return h[0] * np.abs(loc[:, 0]) + h[1] * np.sqrt(loc[:, 1] ** 2 + loc[:, 2] ** 2)      # a Cylinder lies along its X


def gap(a, ma, b, mb, mode):
    """The gap between parts `a` and `b` placed at `ma` and `mb`: over zero apart, under zero the least overlap."""
    d = np.vstack([DIRS, ma[:3, :3].T, mb[:3, :3].T])
    between = np.abs(d @ (mb[:3, 3] - ma[:3, 3]))
    return float(np.max(between - _reach(ma, a["size"], a[mode], d) - _reach(mb, b["size"], b[mode], d)))


def _scaled(m, k, about):
    """`m` after the model is scaled by `k` about the point `about` (Model:ScaleTo keeps the turn)."""
    out = m.copy()
    out[:3, 3] = about + (m[:3, 3] - about) * k
    return out


def worn(cat_parts, bow_parts, scale):
    """The gaps of one bow on one cat: {mode: (piece gap, piece name, head gap)}, or None when a BowSlot is missing."""
    head = next((p for p in cat_parts if "BowSlot" in p["atts"]), None)
    base = next((p for p in bow_parts if "BowSlot" in p["atts"]), None)
    if head is None or base is None:
        return None
    slot = head["m"] @ head["atts"]["BowSlot"]
    own = base["m"] @ base["atts"]["BowSlot"]
    fit = slot @ np.linalg.inv(own)
    pieces = [p for p in cat_parts if p is not head and any(k in p["path"] for k in ON_HEAD) and "_Prop2" not in p["path"]]
    out = {}
    for mode in ("seen", "query"):
        worst, where, on_head, ear = 9.0, "", 9.0, 9.0
        for b in bow_parts:
            bb = dict(b, size=b["size"] * scale)
            mb = fit @ _scaled(b["m"], scale, own[:3, 3])
            on_head = min(on_head, gap(bb, mb, head, head["m"], mode))
            for c in pieces:
                g = gap(bb, mb, c, c["m"], mode)
                if "_Ear" in c["path"]:
                    ear = min(ear, g)
                elif g < worst:
                    worst, where = g, c["path"].rsplit("_", 1)[-1] + " " + "x".join(f"{s:.2f}" for s in c["size"])
        out[mode] = (worst, where, on_head, ear)
    return out


def _load(name):
    with open(os.path.join(RBX, name + ".model.json"), encoding="utf-8") as f:
        return json.load(f)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--only", default="", help="cat names, separated by commas")
    ap.add_argument("--all", action="store_true", help="list every model, not one row per set of twins")
    args = ap.parse_args()
    only = [s for s in args.only.split(",") if s]
    bows = {}
    for tier in TIERS:
        for colour in COLOURS:
            tree = _load(f"CleanACat_Bow_{colour}{tier}")
            bows[(tier, colour)] = [p for p in parts(tree) if "_Fan" not in p["path"] and "_Fan" not in p["name"]]
    bad, rows, seen_rows = 0, 0, set()
    for path in sorted(glob.glob(os.path.join(RBX, "CleanACat_Cat_*.model.json"))):
        name = os.path.basename(path)[:-len(".model.json")]
        tree = _load(name)
        attrs = tree.get("attributes") or {}
        if not attrs.get("HeadPiece") or (only and attrs.get("Cat") not in only):
            continue
        scale = attrs.get("Scale", 1.0)
        scale = scale.get("Float64", 1.0) if isinstance(scale, dict) else float(scale)
        own = attrs.get("BowScale", 1.0)               # a head piece cat wears a smaller bow (#845, BowFit.luau)
        scale *= own.get("Float64", 1.0) if isinstance(own, dict) else float(own)
        cat_parts = parts(tree)
        cells, key = [], [attrs.get("Cat")]
        for tier in TIERS:
            res = [worn(cat_parts, bows[(tier, colour)], scale) for colour in COLOURS]
            if any(r is None for r in res):
                cells.append(f"{tier or 'Plain'}: no BowSlot")
                bad += 1
                continue
            s = min(res, key=lambda r: r["seen"][0])["seen"]
            q = min(res, key=lambda r: r["query"][0])["query"]
            flag = ""
            pinned = attrs.get("Cat") in PINNED
            if pinned and not PIN_DEEP <= s[0] <= 0.004:
                flag, bad = " NOT PINNED " + s[1], bad + 1
            elif not pinned and s[0] < 0:
                flag, bad = " CUTS " + s[1], bad + 1
            elif s[3] < EAR_OK:
                flag, bad = " CUTS THE EAR", bad + 1
            elif not pinned and s[2] > 0.004:
                flag, bad = " OFF THE HEAD", bad + 1
            elif s[2] < BURIED:
                flag, bad = " BURIED", bad + 1
            cells.append(f"{tier or 'Plain'} seen {s[0]:+.3f} query {q[0]:+.3f} head {s[2]:+.3f} ear {s[3]:+.3f}{flag}")
            key.append((round(s[0], 3), round(q[0], 3), round(s[2], 3)))
        rows += 1
        if not args.all and tuple(key) in seen_rows:
            continue
        seen_rows.add(tuple(key))
        print(f"{name[len('CleanACat_Cat_'):]:<22} " + " | ".join(cells))
    print(f"{rows} cat models with a head piece, {len(TIERS)} tiers in {len(COLOURS)} colours: "
          + ("every bow clears the head piece (Bathtile and Djinn: pinned to it) and touches the head" if not bad else f"{bad} to fix"))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
