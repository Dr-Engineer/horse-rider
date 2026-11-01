"""Shared Blender toolkit: every model in the game is built with these helpers.

Conventions (see docs/TECH_ARCHITECTURE.md):
- Metres. Z up. Models face +Y, right is +X. After glTF export that is -Z forward in Godot.
- All faces sample one atlas (assets/atlas/atlas.png) through named cells or tiles.
- Rigs are built from data, poses are written as rotations in armature axes.
"""
import json
import math
import os

import bpy
from mathutils import Euler, Quaternion, Vector

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ATLAS_JSON = os.path.join(ROOT, "assets", "atlas", "atlas.json")
MODELS_DIR = os.path.join(ROOT, "assets", "models")
FPS = 30

# Seat contract shared by horse.py and rider.py (metres, horse space). The rider node hangs 0.9 below the
# saddle bone head, so the rider root sits at SADDLE_Z - 0.9 and its hip joint 0.92 above that.
SADDLE_Y = -0.03
SADDLE_Z = 1.36
STIRRUP_X = 0.36
STIRRUP_Y = 0.02
STIRRUP_Z = 0.64

with open(ATLAS_JSON) as _f:
    _ATLAS = json.load(_f)
_W, _H = _ATLAS["size"]


def cell_uv(name):
    """UV at the centre of a flat colour cell."""
    x, y, w, h = _ATLAS["cells"][name]
    return ((x + w * 0.5) / _W, 1.0 - (y + h * 0.5) / _H)


def tile_uv(name, u, v):
    """UV inside a painted tile. u right, v up, both 0..1. Inset by half a texel so nearest sampling never bleeds."""
    x, y, w, h = _ATLAS["tiles"][name]
    return ((x + 0.5 + u * (w - 1)) / _W, 1.0 - (y + 0.5 + (1.0 - v) * (h - 1)) / _H)


def has_cell(name):
    return name in _ATLAS["cells"]


def has_tile(name):
    return name in _ATLAS["tiles"]


def _as_weights(w):
    return {w: 1.0} if isinstance(w, str) else (dict(w) if w else {})


def lerp(a, b, t):
    return a + (b - a) * t


def vlerp(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def smoothstep(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3.0 - 2.0 * t)


class Ring:
    """One cross-section of a loft."""

    def __init__(self, c, rx, ry=None, w=None, cell=None, up=None, exp=2.0, twist=0.0):
        self.c = Vector(c)
        self.rx = rx
        self.ry = rx if ry is None else ry
        self.w = w
        self.cell = cell
        self.up = up
        self.exp = exp
        self.twist = twist


class Builder:
    """Accumulates vertices, faces, atlas UVs and bone weights for one mesh."""

    def __init__(self, name):
        self.name = name
        self.co = []
        self.weights = []
        self.faces = []
        self.loop_uvs = []

    # --- primitives -------------------------------------------------------
    def vert(self, co, w=None):
        self.co.append(Vector(co))
        self.weights.append(_as_weights(w))
        return len(self.co) - 1

    def face(self, idx, cell=None, uvs=None):
        idx = list(idx)
        self.faces.append(idx)
        if uvs is None:
            uv = cell_uv(cell or "white")
            uvs = [uv] * len(idx)
        self.loop_uvs.append(list(uvs))

    def quad_tile(self, pts, tile, w=None, uv_rect=(0, 0, 1, 1)):
        """A quad with a painted tile. pts: bottom-left, bottom-right, top-right, top-left."""
        u0, v0, u1, v1 = uv_rect
        idx = [self.vert(p, w) for p in pts]
        uvs = [tile_uv(tile, u0, v0), tile_uv(tile, u1, v0), tile_uv(tile, u1, v1), tile_uv(tile, u0, v1)]
        self.face(idx, uvs=uvs)

    def loft(self, rings, n=8, cell="white", w=None, cap_start=True, cap_end=True, axis=None, up=None, phase=0.0):
        """Skin consecutive rings. Ring frames follow the path unless axis is given."""
        count = len(rings)
        indices = []
        up_hint = Vector(up) if up else None
        for i, ring in enumerate(rings):
            if axis is not None:
                tangent = Vector(axis).normalized()
            else:
                prev_c = rings[max(0, i - 1)].c
                next_c = rings[min(count - 1, i + 1)].c
                tangent = (next_c - prev_c).normalized()
            hint = Vector(ring.up) if ring.up else (up_hint if up_hint else Vector((0, 0, 1)))
            if abs(tangent.dot(hint)) > 0.98:
                hint = Vector((0, 1, 0)) if abs(tangent.y) < 0.9 else Vector((1, 0, 0))
            side = hint.cross(tangent).normalized()
            upv = tangent.cross(side).normalized()
            row = []
            weights = ring.w if ring.w is not None else w
            for k in range(n):
                a = 2.0 * math.pi * (k + phase) / n + ring.twist
                ca, sa = math.cos(a), math.sin(a)
                if ring.exp != 2.0:
                    e = 2.0 / ring.exp
                    ca = math.copysign(abs(ca) ** e, ca)
                    sa = math.copysign(abs(sa) ** e, sa)
                row.append(self.vert(ring.c + side * (ring.rx * ca) + upv * (ring.ry * sa), weights))
            indices.append(row)
        for i in range(count - 1):
            ring_cell = rings[i].cell or cell
            for k in range(n):
                k2 = (k + 1) % n
                self.face((indices[i][k], indices[i][k2], indices[i + 1][k2], indices[i + 1][k]), cell=ring_cell)
        if cap_start:
            self.face(list(reversed(indices[0])), cell=rings[0].cell or cell)
        if cap_end:
            self.face(indices[-1], cell=rings[-2].cell or cell if count > 1 else cell)
        return indices

    def tube(self, points, radii, n=6, cell="white", w=None, cap_start=True, cap_end=True, up=None):
        """Loft through points with one radius (or rx, ry) per point."""
        rings = []
        for p, r in zip(points, radii):
            rx, ry = r if isinstance(r, (tuple, list)) else (r, r)
            rings.append(Ring(p, rx, ry))
        return self.loft(rings, n=n, cell=cell, w=w, cap_start=cap_start, cap_end=cap_end, up=up)

    def box(self, center, size, cell="white", w=None, rot=None, taper=None):
        """Axis-aligned box, optional Euler rot in degrees, taper=(sx, sy) scales the top face."""
        cx, cy, cz = center
        sx, sy, sz = (size[0] * 0.5, size[1] * 0.5, size[2] * 0.5)
        tx, ty = taper if taper else (1.0, 1.0)
        local = [
            (-sx, -sy, -sz), (sx, -sy, -sz), (sx, sy, -sz), (-sx, sy, -sz),
            (-sx * tx, -sy * ty, sz), (sx * tx, -sy * ty, sz), (sx * tx, sy * ty, sz), (-sx * tx, sy * ty, sz),
        ]
        rq = Euler(tuple(math.radians(a) for a in rot)).to_quaternion() if rot else None
        idx = []
        for p in local:
            v = Vector(p)
            if rq:
                v = rq @ v
            idx.append(self.vert((cx + v.x, cy + v.y, cz + v.z), w))
        for f in ((0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)):
            self.face([idx[i] for i in f], cell=cell)
        return idx

    def cone(self, base, tip, r, n=6, cell="white", w=None, up=None):
        base, tip = Vector(base), Vector(tip)
        tangent = (tip - base).normalized()
        hint = Vector(up) if up else Vector((0, 0, 1))
        if abs(tangent.dot(hint)) > 0.98:
            hint = Vector((0, 1, 0))
        side = hint.cross(tangent).normalized()
        upv = tangent.cross(side).normalized()
        rx, ry = r if isinstance(r, (tuple, list)) else (r, r)
        row = [
            self.vert(base + side * (rx * math.cos(2 * math.pi * k / n)) + upv * (ry * math.sin(2 * math.pi * k / n)), w)
            for k in range(n)
        ]
        t = self.vert(tip, w)
        for k in range(n):
            self.face((row[k], row[(k + 1) % n], t), cell=cell)
        self.face(list(reversed(row)), cell=cell)

    def sphere(self, c, r, cell="white", w=None, segs=8, rings=5):
        rx, ry, rz = r if isinstance(r, (tuple, list)) else (r, r, r)
        c = Vector(c)
        loft_rings = []
        for i in range(1, rings):
            a = math.pi * i / rings - math.pi / 2
            loft_rings.append(Ring((c.x, c.y, c.z + rz * math.sin(a)), rx * math.cos(a), ry * math.cos(a)))
        indices = self.loft(loft_rings, n=segs, cell=cell, w=w, cap_start=False, cap_end=False, axis=(0, 0, 1), up=(0, 1, 0))
        bottom = self.vert((c.x, c.y, c.z - rz), w)
        top = self.vert((c.x, c.y, c.z + rz), w)
        for k in range(segs):
            k2 = (k + 1) % segs
            self.face((indices[0][k2], indices[0][k], bottom), cell=cell)
            self.face((indices[-1][k], indices[-1][k2], top), cell=cell)

    def strip(self, points, widths, normal=(1, 0, 0), cell="white", w=None, double=True, weights_per_point=None):
        """A flat ribbon through points, width measured along normal x tangent. For banners, tassels, flags."""
        normal = Vector(normal).normalized()
        rows = []
        for i, p in enumerate(points):
            prev_p = Vector(points[max(0, i - 1)])
            next_p = Vector(points[min(len(points) - 1, i + 1)])
            tangent = (next_p - prev_p).normalized()
            side = normal.cross(tangent).normalized() * (widths[i] * 0.5)
            pw = weights_per_point[i] if weights_per_point else w
            rows.append((self.vert(Vector(p) - side, pw), self.vert(Vector(p) + side, pw)))
        dup = {}

        def twin(i):
            if i not in dup:
                dup[i] = self.vert(self.co[i], dict(self.weights[i]))
            return dup[i]

        for i in range(len(rows) - 1):
            a, b = rows[i]
            c, d = rows[i + 1]
            self.face((a, b, d, c), cell=cell)
            if double:
                self.face((twin(c), twin(d), twin(b), twin(a)), cell=cell)

    def revolve(self, prof, n=12, w=None, cy=0.0, sx=1.0, sy=1.0, cap_end=True, cap_start=False, cx=0.0, phase=0.0):
        """Spin a profile [(radius, z, cell), ...] about the vertical axis. Go bottom-inner, outward along the underside,
        up the outer edge, then inward over the top, so the normals face outward. cell paints the span that starts there."""
        rings = [Ring((cx, cy, z), r * sx, r * sy, cell=c) for (r, z, c) in prof]
        return self.loft(rings, n=n, w=w, axis=(0, 0, 1), up=(0, 1, 0), cap_start=cap_start, cap_end=cap_end, phase=phase)

    def tri_count(self):
        return sum(len(f) - 2 for f in self.faces)

    # --- whole-part operations -------------------------------------------
    def merge(self, other, offset=(0, 0, 0), scale=1.0, rot_z_deg=0.0, w=None):
        """Copy another builder into this one with a transform; optional single-bone override."""
        base = len(self.co)
        q = Quaternion((0, 0, 1), math.radians(rot_z_deg))
        off = Vector(offset)
        for co, weights in zip(other.co, other.weights):
            self.co.append(q @ (co * scale) + off)
            self.weights.append(_as_weights(w) if w else dict(weights))
        for f, uvs in zip(other.faces, other.loop_uvs):
            self.faces.append([i + base for i in f])
            self.loop_uvs.append(list(uvs))

    def to_object(self, rig=None, collection=None):
        mesh = bpy.data.meshes.new(self.name)
        mesh.from_pydata([tuple(c) for c in self.co], [], self.faces)
        mesh.update()
        uv_layer = mesh.uv_layers.new(name="UVMap")
        for poly, uvs in zip(mesh.polygons, self.loop_uvs):
            for li, uv in zip(poly.loop_indices, uvs):
                uv_layer.data[li].uv = uv
        mesh.materials.append(atlas_material())
        obj = bpy.data.objects.new(self.name, mesh)
        (collection or active_collection()).objects.link(obj)
        if rig is not None:
            obj.parent = rig
            mod = obj.modifiers.new("Armature", "ARMATURE")
            mod.object = rig
            groups = {}
            for vi, weights in enumerate(self.weights):
                total = sum(weights.values()) or 1.0
                for bone, value in weights.items():
                    if bone not in groups:
                        if bone not in rig.data.bones:
                            raise KeyError("Unknown bone %s in %s" % (bone, self.name))
                        groups[bone] = obj.vertex_groups.new(name=bone)
                    groups[bone].add([vi], value / total, "REPLACE")
        return obj


def mirror_x(fn):
    """Call fn(side, sign) for the right then left side, side is 'R' or 'L', sign is +1 or -1."""
    fn("R", 1.0)
    fn("L", -1.0)


def active_collection():
    return bpy.context.scene.collection


def atlas_material():
    mat = bpy.data.materials.get("toon_atlas")
    if mat is None:
        mat = bpy.data.materials.new("toon_atlas")
        mat.use_nodes = True
        nodes = mat.node_tree.nodes
        bsdf = next(n for n in nodes if n.type == "BSDF_PRINCIPLED")
        tex = nodes.new("ShaderNodeTexImage")
        tex.interpolation = "Closest"
        png = os.path.join(ROOT, "assets", "atlas", "atlas.png")
        img = bpy.data.images.get("atlas.png") or bpy.data.images.load(png)
        img.reload()
        tex.image = img
        mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        bsdf.inputs["Roughness"].default_value = 0.9
    return mat


def clear_scene():
    """Empty the file so each asset builds and exports on its own."""
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj)
    for block in (bpy.data.meshes, bpy.data.armatures, bpy.data.actions, bpy.data.lights, bpy.data.cameras):
        for item in list(block):
            block.remove(item)


def make_rig(name, spec):
    """spec: list of (bone, parent, head, tail)."""
    data = bpy.data.armatures.new(name)
    rig = bpy.data.objects.new(name, data)
    active_collection().objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    rig.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    for bone, parent, head, tail in spec:
        eb = data.edit_bones.new(bone)
        eb.head, eb.tail = head, tail
        eb.roll = 0.0
        if parent:
            eb.parent = data.edit_bones[parent]
            eb.use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    rig.animation_data_create()
    for pb in rig.pose.bones:
        pb.rotation_mode = "QUATERNION"
    return rig


def _rest_quat(pb):
    return pb.bone.matrix_local.to_quaternion()


def set_pose(rig, pose, loc=None):
    """pose: bone -> (rx, ry, rz) degrees about armature axes. Bones left out go to rest."""
    loc = loc or {}
    for pb in rig.pose.bones:
        rest = _rest_quat(pb)
        euler = pose.get(pb.name, (0.0, 0.0, 0.0))
        q = Euler((math.radians(euler[0]), math.radians(euler[1]), math.radians(euler[2])), "XYZ").to_quaternion()
        pb.rotation_quaternion = rest.inverted() @ q @ rest
        offset = Vector(loc.get(pb.name, (0.0, 0.0, 0.0)))
        pb.location = rest.inverted() @ offset


def key_all(rig, frame):
    for pb in rig.pose.bones:
        pb.keyframe_insert("rotation_quaternion", frame=frame)
        pb.keyframe_insert("location", frame=frame)


def blend_pose(a, b, t):
    out = {}
    for bone in set(a) | set(b):
        pa = a.get(bone, (0.0, 0.0, 0.0))
        pb = b.get(bone, (0.0, 0.0, 0.0))
        out[bone] = tuple(lerp(pa[i], pb[i], t) for i in range(3))
    return out


def new_action(rig, name):
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    rig.animation_data.action = act
    return act


def bake_keys(rig, name, keys, length=None):
    """keys: list of (frame, pose, loc, ease). Poses are interpolated and written on every frame.

    ease is 'smooth' (default), 'in', 'out' or 'hold' and shapes the span after that key.
    """
    new_action(rig, name)
    keys = sorted(keys, key=lambda k: k[0])
    last = length if length is not None else keys[-1][0]
    for frame in range(keys[0][0], last + 1):
        k0 = keys[0]
        k1 = keys[-1]
        for i in range(len(keys) - 1):
            if keys[i][0] <= frame <= keys[i + 1][0]:
                k0, k1 = keys[i], keys[i + 1]
                break
        span = max(1, k1[0] - k0[0])
        t = max(0.0, min(1.0, (frame - k0[0]) / span))
        ease = k0[3] if len(k0) > 3 else "smooth"
        if ease == "smooth":
            t = t * t * (3.0 - 2.0 * t)
        elif ease == "in":
            t = t * t
        elif ease == "out":
            t = 1.0 - (1.0 - t) * (1.0 - t)
        elif ease == "hold":
            t = 0.0
        pose = blend_pose(k0[1] or {}, k1[1] or {}, t)
        loc0 = (k0[2] if len(k0) > 2 and k0[2] else {})
        loc1 = (k1[2] if len(k1) > 2 and k1[2] else {})
        loc = blend_pose(loc0, loc1, t)
        set_pose(rig, pose, loc)
        key_all(rig, frame)
    return rig.animation_data.action


def bake_fn(rig, name, frames, fn):
    """Sample fn(t) -> (pose, loc) for frames in 0..frames with t in 0..1, for cycles."""
    new_action(rig, name)
    for frame in range(frames + 1):
        pose, loc = fn(frame / frames)
        set_pose(rig, pose, loc)
        key_all(rig, frame)
    return rig.animation_data.action


def reset_pose(rig):
    if rig.animation_data:
        rig.animation_data.action = None
    set_pose(rig, {})


def export_glb(path, objects, animations=False):
    """Export exactly these objects to assets/models/<path>.glb."""
    target = path if os.path.isabs(path) else os.path.join(MODELS_DIR, path + ".glb")
    os.makedirs(os.path.dirname(target), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.export_scene.gltf(
        filepath=target,
        export_format="GLB",
        use_selection=True,
        export_apply=False,
        export_yup=True,
        export_skins=True,
        export_animations=animations,
        export_animation_mode="ACTIONS",
        export_force_sampling=True,
        export_frame_step=1,
        export_optimize_animation_size=False,
        export_materials="PLACEHOLDER",
        export_image_format="NONE",
        export_tangents=False,
        export_morph=False,
    )
    tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objects if o.type == "MESH")
    print("exported %s tris=%d" % (os.path.relpath(target, ROOT), tris))
    return target
