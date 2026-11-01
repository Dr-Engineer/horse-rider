"""Shared helpers for the world props (props_*.py). Static props: no rig, weights are ignored.

Every prop: origin on the ground, +Y is the front, metres. Colours are atlas cell names only.
Run a props file with:
  "/Applications/Blender 5.2.app/Contents/MacOS/Blender" --background --factory-startup --python art/blender/props_nature.py
"""
import math
import os
import random
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import kit  # noqa: E402

TAU = math.pi * 2.0


def new(name):
    return kit.Builder(name)


# --- solids ------------------------------------------------------------------------------------------------------

def solid(b, pts, faces, cell="white", center=None):
    """A convex solid from points and index faces. Faces are wound outward automatically."""
    idx = [b.vert(p) for p in pts]
    vs = [Vector(p) for p in pts]
    c = Vector(center) if center is not None else sum(vs, Vector()) / len(vs)
    for i, f in enumerate(faces):
        cell_i = cell[i] if isinstance(cell, (list, tuple)) else cell
        fp = [vs[k] for k in f]
        n = Vector()
        for a in range(len(fp)):
            p, q = fp[a], fp[(a + 1) % len(fp)]
            n.x += (p.y - q.y) * (p.z + q.z)
            n.y += (p.z - q.z) * (p.x + q.x)
            n.z += (p.x - q.x) * (p.y + q.y)
        fc = sum(fp, Vector()) / len(fp)
        order = list(f)
        if n.dot(fc - c) < 0:
            order.reverse()
        b.face([idx[k] for k in order], cell=cell_i)
    return idx


def slab(b, x0, y0, z0, x1, y1, z1, cell="white", inset=(0.0, 0.0), top_cell=None, bottom=True):
    """Axis-aligned frustum: base rectangle at z0, top rectangle at z1 inset on each side by `inset` (x, y)."""
    ix, iy = inset
    pts = [(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0),
           (x0 + ix, y0 + iy, z1), (x1 - ix, y0 + iy, z1), (x1 - ix, y1 - iy, z1), (x0 + ix, y1 - iy, z1)]
    faces = [[4, 5, 6, 7], [0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7]]
    cells = [top_cell or cell, cell, cell, cell, cell]
    if bottom:
        faces.append([0, 1, 2, 3])
        cells.append(cell)
    return solid(b, pts, faces, cells)


def box_at(b, cx, cy, z0, sx, sy, sz, cell="white", inset=(0.0, 0.0), top_cell=None):
    return slab(b, cx - sx / 2, cy - sy / 2, z0, cx + sx / 2, cy + sy / 2, z0 + sz, cell, inset, top_cell)


def cone_t(b, cx, cy, z0, z1, r, n=7, cell="white", rot=0.0, r_top=0.0, cell_top=None):
    """Cone or frustum standing on z0 with radius r, tapering to r_top at z1."""
    pts = []
    for k in range(n):
        a = TAU * k / n + rot
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a), z0))
    if r_top > 0.0:
        for k in range(n):
            a = TAU * k / n + rot
            pts.append((cx + r_top * math.cos(a), cy + r_top * math.sin(a), z1))
        faces = [[k, (k + 1) % n, n + (k + 1) % n, n + k] for k in range(n)]
        faces.append(list(range(n)))
        faces.append([n + k for k in range(n)])
        cells = [cell] * n + [cell, cell_top or cell]
    else:
        pts.append((cx, cy, z1))
        faces = [[k, (k + 1) % n, n] for k in range(n)]
        faces.append(list(range(n)))
        cells = [cell] * (n + 1)
    return solid(b, pts, faces, cells)


def cyl(b, cx, cy, z0, h, r, n=8, cell="white", r_top=None, cell_top=None, rot=0.0):
    return cone_t(b, cx, cy, z0, z0 + h, r, n, cell, rot, r_top if r_top is not None else r, cell_top)


def blob(b, c, r, rng, segs=7, rings=4, cell="white", jitter=0.18, cut=0.0, cell_top=None, up_thresh=0.6):
    """A lumpy ellipsoid. cut flattens the bottom (fraction of rz below the centre that is kept)."""
    rx, ry, rz = r if isinstance(r, (tuple, list)) else (r, r, r)
    cx, cy, cz = c
    rows = []
    for i in range(1, rings):
        a = math.pi * i / rings - math.pi / 2
        row = []
        for k in range(segs):
            t = TAU * k / segs + (0.3 if i % 2 else 0.0)
            j = 1.0 + rng.uniform(-jitter, jitter)
            x = cx + rx * math.cos(a) * math.cos(t) * j
            y = cy + ry * math.cos(a) * math.sin(t) * j
            z = cz + rz * math.sin(a) * (1.0 + rng.uniform(-jitter, jitter) * 0.5)
            if cut > 0.0:
                z = max(z, cz - rz * cut)
            row.append((x, y, z))
        rows.append(row)
    pts = [p for row in rows for p in row]
    bottom = (cx, cy, max(cz - rz, cz - rz * cut) if cut > 0.0 else cz - rz)
    top = (cx, cy, cz + rz)
    pts.append(bottom)
    pts.append(top)
    bi, ti = len(pts) - 2, len(pts) - 1
    faces = []
    for i in range(len(rows) - 1):
        for k in range(segs):
            k2 = (k + 1) % segs
            faces.append([i * segs + k, i * segs + k2, (i + 1) * segs + k2, (i + 1) * segs + k])
    for k in range(segs):
        k2 = (k + 1) % segs
        faces.append([k, k2, bi])
        faces.append([(len(rows) - 1) * segs + k, (len(rows) - 1) * segs + k2, ti])
    first = len(b.faces)
    solid(b, pts, faces, cell, center=(cx, cy, cz))
    if cell_top:
        shade_up(b, cell_top, thresh=up_thresh, start=first)


# --- recolouring and tweaks ------------------------------------------------------------------------------------

def face_normal(b, f):
    vs = [b.co[i] for i in f]
    n = Vector()
    for a in range(len(vs)):
        p, q = vs[a], vs[(a + 1) % len(vs)]
        n.x += (p.y - q.y) * (p.z + q.z)
        n.y += (p.z - q.z) * (p.x + q.x)
        n.z += (p.x - q.x) * (p.y + q.y)
    return n.normalized() if n.length > 1e-9 else Vector((0, 0, 1))


def shade_up(b, cell, thresh=0.6, start=0, end=None):
    """Faces looking up get this cell, which gives rocks and roofs a lighter top."""
    end = len(b.faces) if end is None else end
    uv = kit.cell_uv(cell)
    for i in range(start, end):
        if face_normal(b, b.faces[i]).z > thresh:
            b.loop_uvs[i] = [uv] * len(b.faces[i])


def shade_down(b, cell, thresh=-0.4, start=0, end=None):
    end = len(b.faces) if end is None else end
    uv = kit.cell_uv(cell)
    for i in range(start, end):
        if face_normal(b, b.faces[i]).z < thresh:
            b.loop_uvs[i] = [uv] * len(b.faces[i])


def set_cell(b, cell, start=0, end=None):
    end = len(b.faces) if end is None else end
    uv = kit.cell_uv(cell)
    for i in range(start, end):
        b.loop_uvs[i] = [uv] * len(b.faces[i])


def checker(b, cells, start=0, end=None, seed=0):
    """Scatter several cells over faces for mottled stone and foliage."""
    rng = random.Random(seed)
    end = len(b.faces) if end is None else end
    for i in range(start, end):
        b.loop_uvs[i] = [kit.cell_uv(rng.choice(cells))] * len(b.faces[i])


def sink(b, z, start=0):
    """Push everything below z up to z (keeps footings from poking through the floor of the mesh)."""
    for i in range(start, len(b.co)):
        if b.co[i].z < z:
            b.co[i].z = z


def settle(b, sink_z=0.15, start=0):
    """Sets whatever was built from `start` on down on the ground, with its lowest point a little under it. blob's cut flattens
    a bottom but leaves it above the origin, so a rock built that way hovers unless it's settled."""
    low = min(b.co[i].z for i in range(start, len(b.co)))
    shift(b, dz=-sink_z - low, start=start)


def shift(b, dx=0.0, dy=0.0, dz=0.0, start=0, end=None):
    end = len(b.co) if end is None else end
    for i in range(start, end):
        b.co[i] = Vector((b.co[i].x + dx, b.co[i].y + dy, b.co[i].z + dz))


def rot_z(b, deg, start=0, end=None, pivot=(0.0, 0.0)):
    end = len(b.co) if end is None else end
    c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
    for i in range(start, end):
        x, y, z = b.co[i].x - pivot[0], b.co[i].y - pivot[1], b.co[i].z
        b.co[i] = Vector((pivot[0] + x * c - y * s, pivot[1] + x * s + y * c, z))


def scale_xyz(b, sx, sy, sz, start=0, end=None):
    end = len(b.co) if end is None else end
    for i in range(start, end):
        b.co[i] = Vector((b.co[i].x * sx, b.co[i].y * sy, b.co[i].z * sz))


def mirror_x_copy(b, start=0, end=None):
    """Append a mirrored (x -> -x) copy of faces from start..end."""
    end = len(b.faces) if end is None else end
    remap = {}
    for fi in range(start, end):
        f = b.faces[fi]
        new_idx = []
        for vi in f:
            if vi not in remap:
                p = b.co[vi]
                remap[vi] = b.vert((-p.x, p.y, p.z))
            new_idx.append(remap[vi])
        b.face(list(reversed(new_idx)), uvs=list(reversed(b.loop_uvs[fi])))


def rope(b, p0, p1, r=0.035, cell="bone"):
    b.tube([p0, p1], [r, r], n=3, cell=cell)


# --- flags ------------------------------------------------------------------------------------------------------

FLAG_CELLS = ["lapis", "chalk", "vermilion", "malachite", "orpiment"]  # blue, white, red, green, yellow, always in order
FLAG_TILES = ["flag_blue", "flag_white", "flag_red", "flag_green", "flag_yellow"]


def flag_row(b, hangs, p0, p1, sag=0.25, w=0.55, h=0.8, gap=0.12, cells=None, rows=3, cols=2, flag_tile=None):
    """A row of prayer flags hanging from a sagging string between p0 and p1. hangs collects UV2 hang values.
    Returns the number of flags. Order is always blue, white, red, green, yellow."""
    use_tiles = cells is None and kit.has_tile(FLAG_TILES[0])
    cells = cells or FLAG_CELLS
    p0, p1 = Vector(p0), Vector(p1)
    span = (p1 - p0).length
    n = max(1, int((span - gap) / (w + gap)))
    d = (p1 - p0).normalized()
    side = Vector((-d.y, d.x, 0.0))
    if side.length < 1e-6:
        side = Vector((1, 0, 0))
    side.normalize()
    for fi in range(n):
        t0 = (gap + fi * (w + gap) + 0.0) / span
        t1 = (gap + fi * (w + gap) + w) / span
        cell = cells[fi % len(cells)]
        grid = []
        for ri in range(rows + 1):
            row = []
            for ci in range(cols + 1):
                t = t0 + (t1 - t0) * ci / cols
                base = p0.lerp(p1, t)
                base.z -= sag * 4.0 * t * (1.0 - t)
                k = ri / rows
                pt = Vector((base.x, base.y, base.z - h * k))
                i = b.vert(pt)
                hangs.append(k)
                row.append(i)
            grid.append(row)
        for ri in range(rows):
            for ci in range(cols):
                quad = [grid[ri][ci], grid[ri][ci + 1], grid[ri + 1][ci + 1], grid[ri + 1][ci]]
                if use_tiles:
                    tile = FLAG_TILES[fi % len(FLAG_TILES)]
                    u0, u1 = ci / cols, (ci + 1) / cols
                    vt, vb = 1.0 - ri / rows, 1.0 - (ri + 1) / rows
                    b.face(quad, uvs=[kit.tile_uv(tile, u0, vt), kit.tile_uv(tile, u1, vt), kit.tile_uv(tile, u1, vb), kit.tile_uv(tile, u0, vb)])
                else:
                    b.face(quad, cell=cell)
    return n


def add_hang_uv2(obj, hangs):
    mesh = obj.data
    layer = mesh.uv_layers.new(name="UV2")
    for poly in mesh.polygons:
        for li in poly.loop_indices:
            v = mesh.loops[li].vertex_index
            h = hangs[v] if v < len(hangs) else 0.0
            layer.data[li].uv = tuple(h) if isinstance(h, (tuple, list)) else (h, 0.0)


# --- export -----------------------------------------------------------------------------------------------------

def wanted(name):
    """PROPS_ONLY=ramp,scarf limits a props script to those exports (every other one is skipped)."""
    only = os.environ.get("PROPS_ONLY", "").strip()
    return not only or name in [n.strip() for n in only.split(",")]


def export(name, parts):
    """parts: list of (object_name, builder) or (object_name, builder, hangs). Exports props/<name>.glb."""
    if not wanted(name):
        return
    kit.clear_scene()
    objs = []
    for part in parts:
        obj_name, b = part[0], part[1]
        b.name = obj_name
        obj = b.to_object()
        obj.name = obj_name
        obj.data.name = obj_name
        if len(part) > 2 and part[2] is not None:
            add_hang_uv2(obj, part[2])
        objs.append(obj)
    kit.export_glb("props/" + name, objs)


def single(name, b):
    export(name, [(name, b)])
