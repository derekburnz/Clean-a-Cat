"""Where Roblox's camera comes to rest in any room, read from the Part models in ../rbx (#670, the wider check).

    python camera_rest_parts.py                       the spa room with each back door look, and inside the VIP Room
    python camera_rest_parts.py <model.json> [--add <model.json> x y z] [--box x0 x1 z0 z1] [--floor y] [--top N]

camera_rest_check.py rebuilds the spa plot in Blender and tests its three walls. This one reads the exported
`.model.json` files, so it tests what the game loads, any model, and several models placed together (a door or the
VIP Room at its spot on the plot). Axes are Roblox's: Y up.

A head stands on a grid over the floor at two heights and looks twelve ways, level and tilted 20 degrees down. The
camera sweeps back from the head the way Roblox's does, until a corner of its near plane meets a part with
CanCollide, and the eye rests 0.1 studs behind that. Counted: the share of a phone's screen whose first drawn face,
within half a stud of the eye, belongs to a part players walk through. Two counts:

  from inside a solid part   the ray starts inside a wall or another solid part, so the face is the back of a
                             walk-through piece on that wall. This is #670: the screen fills with one flat colour.
                             The check FAILS when such a view covers more than half the screen.
  beside                     the camera rests in the open next to a walk-through piece (a shelf, a door leaf, a
                             plant) and sees it close up, as it would see solid furniture. Reported, never a fail.

Limits: a wedge, ball or cylinder counts as its box, so round pieces read a little worse than they are. Every part
with CanCollide stops the camera here, see-through ones too. Roblox's own camera module decides that in the game,
so a Studio look is still the last word.
"""
import argparse
import collections
import json
import math
import os

import bpy  # noqa: F401  (loads mathutils)
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

NEAR, FOV, ASPECT = 0.1, math.radians(70), 2.16      # Roblox's near plane and field of view, a phone's screen
CLOSE, REACH, HEAD_GAP = 0.5, 12.5, 0.6              # as camera_rest_check.py
PROJ_Y = 2 * math.tan(FOV / 2)
PROJ_X = ASPECT * PROJ_Y
UP = Vector((0, 1, 0))
FACES = ((0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3))
RBX = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "rbx")
PLOT = "CleanACat_Area_SpaPlot"
VIP_AT, GARDEN_AT = (-7.0, 0.5, 10.5), (12.0, 0.5, 10.5)       # the plot's SpotVipDoor and SpotGardenDoor
SPA_BOX = (-18.0, 18.0, -16.0, 10.0)                           # the spa room's inner faces (plot.ROOM_X, ROOM_Y)
VIP_BOX = (-15.4, 1.4, 11.0, 22.9)                             # the VIP Room's floor, on the plot


def _file(name):
    return name if name.endswith(".json") else os.path.join(RBX, name + ".model.json")


def parts(node, offset=Vector((0, 0, 0)), out=None):
    """Every Part and WedgePart under `node`: (name, middle, turn, size, collides, transparency)."""
    out = [] if out is None else out
    if node.get("className") in ("Part", "WedgePart"):
        p = node["properties"]
        cf = p["CFrame"]["CFrame"]
        out.append((node.get("name", ""), Vector(cf["position"]) + offset, Matrix(cf["orientation"]),
                    Vector(p["Size"]), bool(p.get("CanCollide", True)), float(p.get("Transparency", 0.0))))
    for child in node.get("children", ()):
        parts(child, offset, out)
    return out


class Scene:
    def __init__(self, ps):
        self.ps = ps
        drawn_v, drawn_p, self.owner, solid_v, solid_p = [], [], [], [], []
        for i, (_name, pos, rot, size, collide, clear) in enumerate(ps):
            corners = [pos + rot @ Vector((sx * size.x / 2, sy * size.y / 2, sz * size.z / 2))
                       for sx in (-1, 1) for sy in (-1, 1) for sz in (-1, 1)]
            if clear < 0.99:
                base = len(drawn_v)
                drawn_v += corners
                for f in FACES:
                    drawn_p.append([base + k for k in f])
                    self.owner.append(i)
            if collide:
                base = len(solid_v)
                solid_v += corners
                solid_p += [[base + k for k in f] for f in FACES]
        self.drawn = BVHTree.FromPolygons(drawn_v, drawn_p, epsilon=0.0)
        self.solid = BVHTree.FromPolygons(solid_v, solid_p, epsilon=0.0)
        self.boxes = [(pos, rot.transposed(), size / 2) for _n, pos, rot, size, collide, _c in ps if collide]

    def in_solid(self, point):
        for pos, inv, half in self.boxes:
            q = inv @ (point - pos)
            if abs(q.x) < half.x and abs(q.y) < half.y and abs(q.z) < half.z:
                return True
        return False

    def covered(self, eye, look, right, up, nx, ny):
        """Screen cells whose first drawn face is a close walk-through part: all, those seen from inside a solid."""
        count, inside, what = 0, 0, collections.Counter()
        for i in range(nx):
            for j in range(ny):
                d = (look + right * ((i + 0.5) / nx - 0.5) * PROJ_X + up * ((j + 0.5) / ny - 0.5) * PROJ_Y).normalized()
                t = NEAR / d.dot(look)
                start = origin = eye + d * t
                for _ in range(24):
                    if t >= CLOSE:
                        break
                    hit = self.drawn.ray_cast(origin, d, CLOSE - t + 0.001)
                    if hit[0] is None:
                        break
                    t += hit[3]
                    if hit[1].dot(d) < 0:                          # turned to the eye: this is what is drawn
                        name, pos, _rot, size, collide, _clear = self.ps[self.owner[hit[2]]]
                        if not collide:
                            count += 1
                            inside += self.in_solid(start)
                            what["%s at (%.1f, %.1f, %.1f) size (%.2f, %.2f, %.2f)" % (
                                name.replace("CleanACat_Area_", ""), *pos, *size)] += 1
                        break
                    origin = hit[0] + d * 1e-4
                    t += 1e-4
        return count / (nx * ny), inside / (nx * ny), what

    def run(self, box, floor, step=0.75, heights=(4.5, 5.6), tilts=(0, -20)):
        tested, beside, wall = 0, [], []
        x = box[0] + HEAD_GAP
        while x <= box[1] - HEAD_GAP + 1e-6:
            z = box[2] + HEAD_GAP
            while z <= box[3] - HEAD_GAP + 1e-6:
                for height in heights:
                    focus = Vector((x, floor + height, z))
                    near = self.solid.find_nearest(focus)
                    if near[0] is not None and near[3] < HEAD_GAP:
                        continue
                    for k in range(12):
                        for tilt in tilts:
                            yaw = math.radians(k * 30)
                            look = Vector((math.cos(yaw), 0, math.sin(yaw)))
                            right = look.cross(UP).normalized()
                            look = (Matrix.Rotation(math.radians(tilt), 3, right) @ look).normalized()
                            if look.y > 0:
                                look.y = -look.y
                            up = right.cross(look).normalized()
                            limit = REACH
                            for sx in (-0.5, 0.5):
                                for sy in (-0.5, 0.5):
                                    hit = self.solid.ray_cast(focus + NEAR * (right * sx * PROJ_X + up * sy * PROJ_Y),
                                                              -look, REACH - NEAR)
                                    if hit[0] is not None:
                                        limit = min(limit, hit[3])
                            if limit >= REACH - 0.1:
                                continue
                            tested += 1
                            eye = focus - look * (limit + NEAR)
                            if self.covered(eye, look, right, up, 8, 4)[0] == 0:
                                continue
                            share, inside, what = self.covered(eye, look, right, up, 24, 12)
                            row = (round(x, 2), round(z, 2), height, k * 30, tilt, what.most_common(2))
                            if share > 0.02:
                                beside.append((share,) + row)
                            if inside > 0.02:
                                wall.append((inside,) + row)
                z += step
            x += step
        beside.sort(key=lambda f: -f[0])
        wall.sort(key=lambda f: -f[0])
        return tested, beside, wall


def load(model, adds=()):
    ps = parts(json.load(open(_file(model))))
    for name, x, y, z in adds:
        ps += parts(json.load(open(_file(name))), Vector((float(x), float(y), float(z))))
    return ps


def report(label, tested, beside, wall, top=3):
    def over(rows, share):
        return len([f for f in rows if f[0] > share])
    print("%s: %d camera rests" % (label, tested))
    print("   from inside a solid part: over a quarter of the screen %d, over half %d, worst %.0f%%" % (
        over(wall, 0.25), over(wall, 0.5), 100 * max([f[0] for f in wall] or [0])))
    for f in wall[:top]:
        print("      %.0f%% head at x %s z %s, height %s, yaw %s, tilt %s: %s" % (f[0] * 100, *f[1:]))
    print("   close walk-through parts of any kind: over a quarter %d, over half %d, worst %.0f%%" % (
        over(beside, 0.25), over(beside, 0.5), 100 * max([f[0] for f in beside] or [0])))
    for f in beside[:top]:
        print("      %.0f%% head at x %s z %s, height %s, yaw %s, tilt %s: %s" % (f[0] * 100, *f[1:]))
    return over(wall, 0.5) == 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("model", nargs="?")
    ap.add_argument("--add", nargs=4, action="append", default=[], metavar=("MODEL", "X", "Y", "Z"))
    ap.add_argument("--box", type=float, nargs=4)
    ap.add_argument("--floor", type=float)
    ap.add_argument("--step", type=float, default=0.75)
    ap.add_argument("--top", type=int, default=3)
    a = ap.parse_args()
    if a.model:
        ps = load(a.model, a.add)
        _n, pos, _r, size, _c, _t = ps[0]                      # the first part is the biggest: the floor
        box = a.box or (pos.x - size.x / 2, pos.x + size.x / 2, pos.z - size.z / 2, pos.z + size.z / 2)
        floor = a.floor if a.floor is not None else pos.y + size.y / 2
        ok = report(a.model, *Scene(ps).run(box, floor, a.step), top=a.top)
    else:
        ok = True
        for door, at in (("VipLocked", VIP_AT), ("VipBuilding", VIP_AT), ("VipRoom", VIP_AT),
                         ("GardenLocked", GARDEN_AT), ("GardenBuilding", GARDEN_AT), ("Garden", GARDEN_AT)):
            scene = Scene(load(PLOT, [("CleanACat_Area_" + door, *at)]))
            ok &= report("spa room, with %s at its door" % door, *scene.run(SPA_BOX, 0.5, a.step), top=a.top)
        scene = Scene(load(PLOT, [("CleanACat_Area_VipRoom", *VIP_AT)]))
        ok &= report("inside the VIP Room", *scene.run(VIP_BOX, 0.58, a.step), top=a.top)
    print("PASS" if ok else "FAIL: a view from inside a solid part is more than half covered")


if __name__ == "__main__":
    main()
