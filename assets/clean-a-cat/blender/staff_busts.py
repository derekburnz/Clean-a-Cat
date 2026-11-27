"""Smooth head and shoulders busts of the spa staff, for their pictures only (#1036). Never exported to Roblox.

Derek's playtest, 2026-11-27: the helper pictures looked "blocky and mid" and the Extra Worker card showed Jo. The
game models (spa_staff.py) stay as they are; these busts are drawn for the Helpers screen and the shop, rounder and
softer than a Part model can be: every piece is a smoothed, subdivided shape. Each helper has a face and look of
their own, and the uniform keeps saying "works here": the mint smock and the cream bib apron with its pink paw. The
game model's headband is left off here so each hair style reads whole at a small size.

  Jo   light skin, a ginger bob with a full fringe, a bubblegum heart clip
  Sam  deep skin, short black curls, brows, the sky towel round the neck
  Lou  tan skin, a brown side ponytail with a butter scrunchie, a swept fringe, brows

No hands or arms (Review-QA's image gate), no lilac or gold on staff (those mean a special customer). The bust
stands with its front to -Y, the head's middle at HEAD.
"""

import math

import bmesh
import bpy
from mathutils import Matrix, Vector

import common

HEAD = Vector((0.0, 0.0, 1.62))
HR = Vector((1.0, 0.9, 0.96))           # the head's half sizes: a soft, slightly wide ball
SMOCK, CLOTH, PAW = "spa_mint", "spa_cream", "nose_bubblegum"
EYE, SHINE, CHEEK, MOUTH = "fur_ink", "milk", "blush", "choco"

LOOKS = {
    "Jo": dict(skin="skin_light", hair="fur_ginger", style="bob", accent="spa_bubblegum", brows=False),
    "Sam": dict(skin="skin_deep", hair="fur_black", style="curls", accent="spa_sky", brows=True),
    "Lou": dict(skin="skin_tan", hair="choco", style="ponytail", accent="pastel_butter", brows=True),
    # the builder (npc_builder.py) for the shop's second builder card: the game model's colours, a hard hat,
    # orange dungarees over a cream tee
    "Builder": dict(skin="skin_tan", hair="hair_brown", style="hardhat", accent="pastel_butter", brows=True,
                    top="offwhite", bib="fur_orange"),
}


def head_point(x, z, lift=0.0):
    """The point on the head's front at (x, z), pushed out by `lift` along the surface normal."""
    u, w = x / HR.x, (z - HEAD.z) / HR.z
    t = max(0.0, 1.0 - u * u - w * w)
    p = Vector((x, -HR.y * math.sqrt(t), z))
    n = Vector((u / HR.x, -math.sqrt(t) / HR.y, w / HR.z)).normalized()
    return p + n * lift, n


def _facing(n):
    """A rotation that turns local -Y to the normal n, so a flattened piece lies on the head."""
    return Vector((0, -1, 0)).rotation_difference(n).to_matrix()


def _torus(b, center, major, minor, swatch, rot=None, seg=28, ring=10, arc=1.0, scale=(1, 1, 1)):
    """A ring round local Z (arc < 1: only that share of it, centred on -Y). Smooth, no bevel."""
    m = Matrix.Translation(Vector(center)) @ (rot.to_4x4() if rot is not None else Matrix()) \
        @ Matrix.Diagonal((*scale, 1.0))
    bm, verts, rows = b.bm, [], []
    closed = arc >= 1.0
    n = seg if closed else seg + 1
    for i in range(n):
        a = -math.pi / 2 + (i / seg - (0 if closed else 0.5)) * 2 * math.pi * arc
        row = []
        for j in range(ring):
            c = 2 * math.pi * j / ring
            r = major + minor * math.cos(c)
            row.append(bm.verts.new(m @ Vector((r * math.cos(a), r * math.sin(a), minor * math.sin(c)))))
        rows.append(row)
    for i in range(n if closed else n - 1):
        r0, r1 = rows[i], rows[(i + 1) % n]
        for j in range(ring):
            bm.faces.new((r0[j], r1[j], r1[(j + 1) % ring], r0[(j + 1) % ring]))
    if not closed:
        for row in (rows[0], rows[-1]):
            bm.faces.new(row if row is rows[-1] else list(reversed(row)))
    for row in rows:
        verts.extend(row)
    return b._tag(verts, swatch, False)


def _ball(b, center, r, swatch, scale=(1, 1, 1), rot=None, seg=24, rings=14):
    return b.sphere(tuple(center), r, swatch, segments=seg, rings=rings, scale=scale, rot=rot)


def _cut(b, verts, keep):
    """Drop the vertices of one piece that `keep` refuses, leaving an open shell (hair caps, the bob)."""
    gone = [v for v in verts if not keep(v.co)]
    bmesh.ops.delete(b.bm, geom=gone, context="VERTS")


def _shell(b, center, r, swatch, scale, keep, seg=32, rings=18):
    """A ball cut open by `keep`, thickened so it has an inside (a cap of hair over the head)."""
    verts = _ball(b, center, r, swatch, scale, seg=seg, rings=rings)
    _cut(b, verts, keep)
    live = [v for v in verts if v.is_valid]
    faces = list({f for v in live for f in v.link_faces})
    res = bmesh.ops.solidify(b.bm, geom=faces, thickness=0.06)
    new = [g for g in res["geom"] if isinstance(g, bmesh.types.BMVert)]
    return b._tag(live + new, swatch, False)


def _paw(b, center, n, size, swatch):
    """A paw print lying on a surface with normal n: a pad and three toes."""
    rot = _facing(n)
    up, right = rot @ Vector((0, 0, 1)), rot @ Vector((1, 0, 0))
    c = Vector(center)
    _ball(b, c - up * size * 0.15, size * 0.42, swatch, (1.15, 0.35, 0.95), rot, seg=16, rings=8)
    for k in (-1, 0, 1):
        _ball(b, c + right * k * size * 0.42 + up * size * (0.42 + (0.08 if k == 0 else 0)), size * 0.17, swatch,
              (1, 0.4, 1.15), rot, seg=12, rings=6)


def _heart(b, center, n, size, swatch):
    rot = _facing(n)
    up, right = rot @ Vector((0, 0, 1)), rot @ Vector((1, 0, 0))
    c = Vector(center)
    for sx in (-1, 1):
        _ball(b, c + right * sx * size * 0.28 + up * size * 0.12, size * 0.34, swatch, (1, 0.45, 1), rot, 14, 8)
    _ball(b, c - up * size * 0.2, size * 0.3, swatch, (1.0, 0.45, 1.25), rot @ Matrix.Rotation(0, 3, "Y"), 14, 8)


def _body(b, look):
    """Shoulders in the mint smock, the collar and the cream bib apron with its paw (the builder: a cream tee and
    orange dungarees with butter buttons)."""
    top = look.get("top", SMOCK)
    _ball(b, (0, 0.08, -0.18), 1.0, top, (1.5, 0.82, 0.92), seg=36, rings=18)        # wide, low: never a capsule
    _ball(b, (0, 0.0, 0.62), 0.36, look["skin"], (1, 1, 1.1), seg=18, rings=10)           # the neck, mostly hidden
    if "bib" in look:
        _torus(b, (0, 0.02, 0.7), 0.44, 0.1, top, scale=(1.1, 1.0, 1.0))
        bib = look["bib"]
        _shell(b, (0, 0.08, -0.18), 1.0, bib, (1.52, 0.84, 0.94),           # the dungarees over the tee
               lambda v: v.z < -0.12 or (v.y < -0.3 and abs(v.x) < 0.56 and v.z < 0.3))
        # two butter buttons at the bib's top corners; no straps, which read as arms in a small picture
        for sx in (-1, 1):
            _ball(b, (sx * 0.4, -0.66, 0.22), 0.1, look["accent"], (1, 0.5, 1), seg=12, rings=6)
        _ball(b, (0, -0.86, -0.02), 0.22, "fur_orange_dark", (1.25, 0.2, 0.9), seg=16, rings=8)  # the pocket
        return
    if look["style"] == "curls":                       # Sam: the sky towel rolled round the neck
        _torus(b, (0, 0.02, 0.66), 0.46, 0.17, look["accent"], scale=(1.12, 1.0, 1.0))
        _ball(b, (0.34, -0.42, 0.42), 0.2, look["accent"], (1, 0.7, 1.5), seg=14, rings=8)
    else:
        _torus(b, (0, 0.02, 0.7), 0.44, 0.1, SMOCK, scale=(1.1, 1.0, 1.0))
    _ball(b, (0, -0.66, -0.2), 0.62, CLOTH, (1.0, 0.26, 1.05), seg=28, rings=14)          # the bib
    _paw(b, (0, -0.83, -0.12), Vector((0, -1, 0.12)).normalized(), 0.42, PAW)


def _face(b, look):
    for sx in (-1, 1):
        p, n = head_point(sx * 0.36, HEAD.z - 0.04, -0.02)
        rot = _facing(n)
        _ball(b, p, 0.19, EYE, (0.82, 0.42, 1.12), rot, seg=18, rings=10)
        s, _ = head_point(sx * 0.36 + 0.06, HEAD.z + 0.05, 0.05)
        _ball(b, s, 0.055, SHINE, (1, 0.6, 1), rot, seg=10, rings=6)
        c, cn = head_point(sx * 0.6, HEAD.z - 0.3, -0.01)
        _ball(b, c, 0.14, CHEEK, (1.15, 0.35, 0.8), _facing(cn), seg=14, rings=8)
        e, en = head_point(sx * 0.97, HEAD.z - 0.08, -0.1)             # small ears
        _ball(b, e, 0.17, look["skin"], (0.55, 0.9, 1.1), seg=14, rings=8)
        if look["brows"]:
            w, wn = head_point(sx * 0.38, HEAD.z + 0.27, 0.0)
            _ball(b, w, 0.13, look["hair"], (1.25, 0.35, 0.38),
                  _facing(wn) @ Matrix.Rotation(sx * 0.15, 3, "Y"), seg=12, rings=6)
    m, mn = head_point(0.0, HEAD.z - 0.36, -0.03)                      # a small smile
    _torus(b, m, 0.11, 0.032, MOUTH, _facing(mn) @ Matrix.Rotation(math.pi / 2, 3, "X"), seg=16, ring=8,
           arc=0.42)
    no, nn = head_point(0.0, HEAD.z - 0.18, 0.0)
    _ball(b, no, 0.06, look["skin"], (1.2, 0.8, 0.8), _facing(nn), seg=10, rings=6)


def _hair(b, look):
    h, s = look["hair"], look["style"]
    cz = HEAD.z
    if s == "bob":
        # a round bob to the jaw, open over the face, and a full fringe
        _shell(b, HEAD + Vector((0, 0.06, 0.04)), 1.0, h, (1.12, 1.06, 1.06),
               lambda v: not (v.y < -0.2 and v.z < cz + 0.42 and abs(v.x) < 0.98) and v.z > cz - 0.78)
        for i, x in enumerate((-0.62, -0.31, 0.0, 0.31, 0.62)):
            p, n = head_point(x, cz + 0.5 - 0.06 * abs(x), 0.06)
            _ball(b, p, 0.26, h, (1.25, 0.6, 0.85), _facing(n), seg=16, rings=8)
        for sx in (-1, 1):                             # the bob's ends turn in at the jaw
            _ball(b, (sx * 0.96, 0.08, cz - 0.7), 0.26, h, (0.75, 1.35, 0.55), seg=16, rings=8)
        p, n = head_point(0.74, cz + 0.36, 0.14)
        _heart(b, p, n, 0.46, "nose_bubblegum")
    elif s == "curls":
        # close cut: a snug cap and a crown of soft round curls
        _shell(b, HEAD + Vector((0, 0.04, 0.06)), 1.0, h, (1.05, 0.98, 1.0),
               lambda v: v.z > cz + 0.36 - 0.55 * max(0.0, v.y) and not (v.y < -0.3 and v.z < cz + 0.5))
        for ring_z, rr, k, r in ((cz + 0.62, 0.78, 9, 0.24), (cz + 0.86, 0.48, 6, 0.22), (cz + 0.98, 0.0, 1, 0.22)):
            for i in range(k):
                a = 2 * math.pi * i / k + 0.3 * ring_z
                _ball(b, (rr * math.cos(a) * 1.05, rr * math.sin(a) * 0.98 + 0.05, ring_z), r, h, seg=14, rings=8)
    elif s == "ponytail":
        # a cap, a fringe swept to one side and a high ponytail with a scrunchie
        _shell(b, HEAD + Vector((0, 0.06, 0.05)), 1.0, h, (1.07, 1.02, 1.02),
               lambda v: not (v.y < -0.22 and v.z < cz + 0.44 and abs(v.x) < 0.9) and v.z > cz - 0.45)
        for x, z, r in ((-0.5, cz + 0.52, 0.3), (-0.12, cz + 0.56, 0.3), (0.26, cz + 0.52, 0.27), (0.6, cz + 0.4, 0.22)):
            p, n = head_point(x, z, 0.06)
            _ball(b, p, r, h, (1.35, 0.55, 0.75), _facing(n) @ Matrix.Rotation(-0.35, 3, "Y"), seg=16, rings=8)
        # a side ponytail, high on her left (+X), swinging out past the head so it shows face on
        top = Vector((0.8, 0.26, cz + 0.64))
        _torus(b, top, 0.17, 0.12, look["accent"], Matrix.Rotation(-0.8, 3, "Y"), seg=18, ring=8)
        _ball(b, top + Vector((0.4, 0.06, -0.12)), 0.42, h, (1.05, 0.95, 1.0), seg=20, rings=12)
        _ball(b, top + Vector((0.5, 0.06, -0.5)), 0.3, h, (1.0, 0.9, 1.0), seg=18, rings=10)


def _hard_hat(b, look):
    """A butter hard hat: a dome with a ridge over the top and a peak to the front, sat a little back."""
    c = HEAD + Vector((0, 0.04, 0.3))
    hat = look["accent"]
    verts = _ball(b, c, 1.0, hat, (1.1, 1.06, 0.92), seg=36, rings=18)
    _cut(b, verts, lambda v: v.z > c.z - 0.02)
    _torus(b, c + Vector((0, 0, 0.0)), 1.08, 0.08, hat, scale=(1.02, 0.98, 1.0), seg=36)          # the rim
    _ball(b, c + Vector((0, -0.98, -0.04)), 0.5, hat, (1.25, 0.75, 0.2), seg=20, rings=10,
          rot=Matrix.Rotation(-0.25, 3, "X"))                                                # the peak
    over = Matrix(((0, 0, 1), (-1, 0, 0), (0, -1, 0)))           # local Z to X, local -Y (the arc's middle) up
    _torus(b, c, 0.9, 0.11, hat, over, seg=30, arc=0.5, scale=(1.06, 1.0, 1.0))             # the ridge
    _ball(b, c + Vector((0, -0.4, 0.62)), 0.18, "fur_orange", (1, 0.5, 1), seg=12, rings=6)    # a badge


def build_bust(name, mat):
    """The bust of one member of staff as one smooth object, named CleanACat_Bust_<Name>."""
    look = dict(LOOKS[name])
    b = common.Builder()
    _ball(b, HEAD, 1.0, look["skin"], tuple(HR), seg=40, rings=22)
    _face(b, look)
    if look["style"] == "hardhat":
        _shell(b, HEAD + Vector((0, 0.05, 0.02)), 1.0, look["hair"], (1.05, 0.99, 1.0),
               lambda v: v.z > HEAD.z - 0.1 - 0.4 * max(0.0, v.y) and not (v.y < -0.3 and v.z < HEAD.z + 0.5))
        _hard_hat(b, look)
    else:
        _hair(b, look)
    _body(b, look)
    ob = b.finalize("CleanACat_Bust_" + name, mat, bevel=0)
    for p in ob.data.polygons:
        p.use_smooth = True
    sub = ob.modifiers.new("Smooth", "SUBSURF")
    sub.levels = sub.render_levels = 2
    return [ob]


def bust_focus(name):
    """The (low, high) box a portrait frames: the head whole with its hair, the shoulders cut at the bib's paw."""
    top = HEAD.z + {"curls": 1.32, "hardhat": 1.3}.get(LOOKS[name]["style"], 1.2)
    return Vector((-1.25, -1.0, -0.35)), Vector((1.25, 1.0, top))
