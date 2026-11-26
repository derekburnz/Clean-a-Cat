"""Where Roblox's camera comes to rest against the spa room's walls, what does it draw? (#670)

    python camera_rest_check.py                               the whole test, a summary and the worst places
    python camera_rest_check.py back 14.5 5.6 0 0             one place: wall, stud along it, height, turn, tilt

Roblox's camera pulls in by sweeping its near-plane rectangle back from the player's head until a corner meets a
part players collide with. The eye then rests 0.1 studs (the near plane) behind that point, so against a wall it
sits inside the wall, and it draws the first face turned to it from 0.1 studs on (faces turned away are never
drawn). A walk-through part with a back face in the room, or a deep one beside the camera, fills the screen.

This rebuilds the plot, rests a camera that way every quarter stud along the back, left and right walls at eight
heights, five turns and two tilts, and counts how much of a phone's screen is covered by a walk-through part, or
by the edge of a solid wall piece, within half a stud of the eye. A solid piece's own face does not count: the
camera in front of it sees it as it sees a wall. Solid here means the plot's main object and its `_Wall`,
`_Glass` and `_WallArt` objects, which is what rbx_export.py gives collision.
"""
import collections
import math
import os
import sys
import tempfile

import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

import common
import palette
import plot

NEAR, FOV, ASPECT = 0.1, math.radians(70), 2.16      # Roblox's near plane and field of view, a phone's screen
CLOSE = 0.5                                          # a face nearer the eye than this fills the view
REACH = 12.5                                         # the camera's own distance from the head
HEAD_GAP = 0.6                                       # a head is never nearer a wall than this
HEAD_OUT = 1.3                                       # the head's distance from the tested point on the wall
PROJ_Y = 2 * math.tan(FOV / 2)
PROJ_X = ASPECT * PROJ_Y
SOLID_END = ("_Wall", "_Glass", "_WallArt")
NAME = "CleanACat_Area_SpaPlot"
UP = Vector((0, 0, 1))


def _scene():
    common.reset_scene()
    png = os.path.join(tempfile.mkdtemp(), palette.TEXTURE_NAME + ".png")
    palette.write_palette_png(png)
    objs = plot.build_plot(common.palette_material(png))
    bpy.context.view_layer.update()
    verts, polys, owner, names, sverts, spolys = [], [], [], [], [], []
    for o in objs:
        if o.name.endswith("_Roof"):
            continue
        solid = o.name == NAME or o.name.endswith(SOLID_END)
        base = len(verts)
        verts += [o.matrix_world @ v.co for v in o.data.vertices]
        for p in o.data.polygons:
            polys.append([base + i for i in p.vertices])
            owner.append(len(names))
        if solid:
            base = len(sverts)
            sverts += [o.matrix_world @ v.co for v in o.data.vertices]
            spolys += [[base + i for i in p.vertices] for p in o.data.polygons]
        names.append((o.name, solid))
    return BVHTree.FromPolygons(verts, polys, epsilon=0.0), BVHTree.FromPolygons(sverts, spolys, epsilon=0.0), owner, names


ALL, SOLID, OWNER, NAMES = _scene()
X0, X1 = plot.ROOM_X
Y0, Y1 = plot.ROOM_Y
WALLS = {"back": (Vector((0, -1, 0)), lambda s: (s, Y1), (X0 + 0.5, X1 - 0.5)),
         "left": (Vector((1, 0, 0)), lambda s: (X0, s), (Y0 + 0.5, Y1 - 0.5)),
         "right": (Vector((-1, 0, 0)), lambda s: (X1, s), (Y0 + 0.5, Y1 - 0.5))}


def rest(focus, look):
    """The resting eye of a camera that looks along `look` at `focus`, its screen axes and the sweep's length."""
    right = look.cross(UP).normalized()
    up = right.cross(look).normalized()
    limit = REACH
    for sx in (-0.5, 0.5):
        for sy in (-0.5, 0.5):
            hit = SOLID.ray_cast(focus + NEAR * (right * sx * PROJ_X + up * sy * PROJ_Y), -look, REACH - NEAR)
            if hit[0] is not None:
                limit = min(limit, hit[3])
    return focus - look * (limit + NEAR), right, up, limit


def _front(point, normal):
    """True for the room-facing face of a piece on one of the three walls."""
    return ((point.x < X0 + 0.3 and normal.x > 0.9) or (point.x > X1 - 0.3 and normal.x < -0.9)
            or (point.y > Y1 - 0.3 and normal.y < -0.9))


def covered(eye, look, right, up, nx=24, ny=12):
    """The share of the screen whose first drawn face is a close walk-through part or a solid piece's edge."""
    count, what = 0, collections.Counter()
    for i in range(nx):
        for j in range(ny):
            d = (look + right * ((i + 0.5) / nx - 0.5) * PROJ_X + up * ((j + 0.5) / ny - 0.5) * PROJ_Y).normalized()
            t = NEAR / d.dot(look)
            origin = eye + d * t
            for _ in range(24):
                if t >= CLOSE:
                    break
                hit = ALL.ray_cast(origin, d, CLOSE - t + 0.001)
                if hit[0] is None:
                    break
                t += hit[3]
                if hit[1].dot(d) < 0:                              # turned to the eye: this is what is drawn
                    name, solid = NAMES[OWNER[hit[2]]]
                    if not solid or (name.endswith("_WallArt") and not _front(hit[0], hit[1])):
                        count += 1
                        what[(name.replace(NAME, ""), tuple(round(c, 1) for c in hit[0]))] += 1
                    break
                origin = hit[0] + d * 1e-4
                t += 1e-4
    return count / (nx * ny), what


def case(wall, along, height, turn, tilt):
    """One resting camera: None when a head could not stand there or nothing stops the camera."""
    normal, at, _ = WALLS[wall]
    look = Matrix.Rotation(math.radians(turn), 3, "Z") @ normal
    look = (Matrix.Rotation(math.radians(tilt), 3, look.cross(UP).normalized()) @ look).normalized()
    if look.z > 0:
        look.z = -look.z
    x, y = at(along)
    spot = Vector((x, y, plot.FLOOR + height))
    focus = spot + look * HEAD_OUT
    if not (X0 + HEAD_GAP <= focus.x <= X1 - HEAD_GAP and Y0 + HEAD_GAP <= focus.y <= Y1 - HEAD_GAP):
        return None
    eye, right, up, limit = rest(focus, look)
    if limit >= REACH - 0.1:
        return None
    share, what = covered(eye, look, right, up)
    return share, round((eye - spot).dot(normal), 3), what


def main():
    if len(sys.argv) > 2:
        wall, rest_of = sys.argv[1], [float(a) for a in sys.argv[2:6]]
        got = case(wall, *rest_of)
        print("nothing to test there" if got is None else "covered %.0f%%, eye %.3f studs off the wall" % (got[0] * 100, got[1]))
        for (name, point), n in (got[2].most_common(8) if got else ()):
            print("   %3d screen cells: %s at %s" % (n, name or "(main)", point))
        return
    tested, found = 0, []
    for wall, (_, _, (a, c)) in WALLS.items():
        along = a
        while along <= c + 1e-6:
            for height in (4.4, 5.0, 5.6, 6.3, 7.0, 7.8, 9.0, 10.0):
                for turn in (0, -25, 25, -45, 45):
                    for tilt in (0, -20):
                        got = case(wall, along, height, turn, tilt)
                        if got is None:
                            continue
                        tested += 1
                        if got[0] > 0.02:
                            found.append((got[0], wall, round(along, 2), height, turn, tilt, got[1]))
            along += 0.25
    found.sort(reverse=True)
    print("camera rests tested: %d" % tested)
    for label, lo, hi in (("up to 8 studs high", 0, 8), ("9 and 10 studs high", 8.5, 99)):
        rows = [f for f in found if lo <= f[3] <= hi]
        print("%s: over a quarter of the screen covered %d, over half %d, worst %.0f%%" % (
            label, len([f for f in rows if f[0] > 0.25]), len([f for f in rows if f[0] > 0.5]),
            100 * max([f[0] for f in rows] or [0])))
        for f in rows[:6]:
            print("   %.0f%% %s wall, %s along, height %s, turn %s, tilt %s, eye %s off the wall" % (f[0] * 100, *f[1:]))
    low = [f for f in found if f[3] <= 8]
    print("PASS" if not [f for f in low if f[0] > 0.5] else "FAIL: a view up to 8 studs high is more than half covered")


if __name__ == "__main__":
    main()
