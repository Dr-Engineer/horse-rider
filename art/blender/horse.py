"""Tibetan pony: mesh, rig, tack and gaits. Exports assets/models/horse.glb."""
import importlib
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit  # noqa: E402

importlib.reload(kit)
from kit import Builder, Ring, mirror_x  # noqa: E402


LZ = 0.9    # legs are 10% shorter than the old rig: a stocky highland pony
LT = 1.14   # and thicker
FX, RX = 0.17, 0.175


def zl(z):
    return z * LZ


BONES = [
    ("root", None, (0, 0, 0), (0, 0, 0.3)),
    ("body", "root", (0, 0, 0.91), (0, 0.3, 0.91)),
    ("hips", "body", (0, -0.25, 0.93), (0, -0.6, 0.96)),
    ("chest", "body", (0, 0.25, 0.93), (0, 0.5, 1.0)),
    ("saddle", "body", (0, kit.SADDLE_Y, kit.SADDLE_Z), (0, kit.SADDLE_Y, kit.SADDLE_Z + 0.18)),
    ("neck1", "chest", (0, 0.5, 1.07), (0, 0.68, 1.3)),
    ("neck2", "neck1", (0, 0.68, 1.3), (0, 0.84, 1.52)),
    ("head", "neck2", (0, 0.84, 1.52), (0, 1.16, 1.26)),
    ("tail1", "hips", (0, -0.72, 1.0), (0, -0.84, 0.88)),
    ("tail2", "tail1", (0, -0.84, 0.88), (0, -0.9, 0.64)),
    ("tail3", "tail2", (0, -0.9, 0.64), (0, -0.92, 0.38)),
]
for s_, sg in (("R", 1), ("L", -1)):
    BONES += [
        ("f_arm." + s_, "chest", (sg * FX, 0.4, zl(0.8)), (sg * FX, 0.43, zl(0.46))),
        ("f_can." + s_, "f_arm." + s_, (sg * FX, 0.43, zl(0.46)), (sg * FX, 0.42, zl(0.17))),
        ("f_hoof." + s_, "f_can." + s_, (sg * FX, 0.42, zl(0.17)), (sg * FX, 0.45, 0.0)),
        ("r_thigh." + s_, "hips", (sg * RX, -0.46, zl(0.92)), (sg * RX, -0.37, zl(0.62))),
        ("r_gas." + s_, "r_thigh." + s_, (sg * RX, -0.37, zl(0.62)), (sg * RX, -0.57, zl(0.42))),
        ("r_can." + s_, "r_gas." + s_, (sg * RX, -0.57, zl(0.42)), (sg * RX, -0.54, zl(0.17))),
        ("r_hoof." + s_, "r_can." + s_, (sg * RX, -0.54, zl(0.17)), (sg * RX, -0.51, 0.0)),
    ]

# Barrel rows: y, centre z, half width, half height, weight blend from hips to chest.
BARREL = [
    (-0.76, 1.0, 0.08, 0.08, 0.0), (-0.70, 0.99, 0.19, 0.2, 0.0), (-0.58, 0.96, 0.29, 0.31, 0.0),
    (-0.40, 0.93, 0.325, 0.36, 0.1), (-0.18, 0.91, 0.32, 0.37, 0.4), (0.05, 0.905, 0.335, 0.385, 0.6),
    (0.28, 0.92, 0.325, 0.385, 0.9), (0.46, 0.95, 0.28, 0.36, 1.0), (0.58, 0.97, 0.19, 0.27, 1.0),
    (0.655, 1.0, 0.07, 0.11, 1.0),
]
BACK_TOP = 0.905 + 0.385


def body_at(y):
    """Centre z, half width and half height of the barrel at y, for fitting tack to it."""
    rows = BARREL
    if y <= rows[0][0]:
        return rows[0][1:4]
    for r0, r1 in zip(rows, rows[1:]):
        if y <= r1[0]:
            t = (y - r0[0]) / (r1[0] - r0[0])
            return tuple(r0[i] + (r1[i] - r0[i]) * t for i in (1, 2, 3))
    return rows[-1][1:4]


def build_body(b):
    rings = []
    for y, z, rx, rz, t in BARREL:
        rings.append(Ring((0, y, z), rx, rz, w={"hips": 1.0 - t, "chest": t}, exp=2.3))
    b.loft(rings, n=12, cell="c1", axis=(0, 1, 0), up=(0, 0, 1))

    # Neck wedge: thick and short, strong crest.
    neck = [
        Ring((0, 0.40, 1.07), 0.17, 0.265, w="chest", up=(0, -0.6, 0.8)),
        Ring((0, 0.53, 1.19), 0.17, 0.27, w={"chest": 0.4, "neck1": 0.6}, up=(0, -0.6, 0.8)),
        Ring((0, 0.65, 1.33), 0.145, 0.22, w={"neck1": 0.6, "neck2": 0.4}, up=(0, -0.7, 0.7)),
        Ring((0, 0.76, 1.46), 0.115, 0.17, w="neck2", up=(0, -0.75, 0.65)),
        Ring((0, 0.84, 1.57), 0.095, 0.13, w={"neck2": 0.5, "head": 0.5}, up=(0, -0.8, 0.6)),
    ]
    b.loft(neck, n=8, cell="c1", cap_start=False, cap_end=False)

    # Big head: broad forehead, deep jaw, short muzzle.
    head = [
        Ring((0, 0.80, 1.62), 0.075, 0.062, up=(0, 0.75, 0.65)),
        Ring((0, 0.884, 1.566), 0.125, 0.14, up=(0, 0.75, 0.65)),
        Ring((0, 1.004, 1.44), 0.12, 0.14, up=(0, 0.75, 0.65)),
        Ring((0, 1.124, 1.308), 0.088, 0.105, up=(0, 0.75, 0.65)),
        Ring((0, 1.22, 1.206), 0.09, 0.1, up=(0, 0.75, 0.65)),
        Ring((0, 1.28, 1.14), 0.075, 0.075, up=(0, 0.75, 0.65), cell="c4"),
        Ring((0, 1.31, 1.104), 0.04, 0.04, up=(0, 0.75, 0.65)),
    ]
    b.loft(head, n=8, cell="c1", w="head")

    def ears_eyes(side, sg):
        b.cone((sg * 0.07, 0.83, 1.64), (sg * 0.09, 0.8, 1.79), (0.042, 0.03), n=5, cell="c2", w="head")
        b.box((sg * 0.12, 0.99, 1.485), (0.026, 0.07, 0.052), cell="ink", w="head", rot=(-42, 0, 0))
        b.box((sg * 0.133, 1.005, 1.5), (0.01, 0.02, 0.018), cell="conch", w="head", rot=(-42, 0, 0))
        b.box((sg * 0.062, 1.285, 1.16), (0.02, 0.036, 0.026), cell="ink", w="head", rot=(-42, 0, 0))

    mirror_x(ears_eyes)


def build_legs(b):
    def leg(side, sg):
        fx, rx = sg * FX, sg * RX
        k = LT
        b.loft([
            Ring((fx, 0.37, zl(0.92)), 0.075 * k, 0.13 * k, up=(0, 1, 0)),
            Ring((fx, 0.40, zl(0.78)), 0.082 * k, 0.112 * k, up=(0, 1, 0)),
            Ring((fx, 0.42, zl(0.60)), 0.055 * k, 0.07 * k, up=(0, 1, 0)),
            Ring((fx, 0.43, zl(0.48)), 0.048 * k, 0.057 * k, up=(0, 1, 0)),
        ], n=6, cell="c1", w="f_arm." + side, cap_start=False, cap_end=False)
        b.loft([
            Ring((fx, 0.43, zl(0.51)), 0.05 * k, 0.062 * k, up=(0, 1, 0)),
            Ring((fx, 0.43, zl(0.43)), 0.052 * k, 0.066 * k, up=(0, 1, 0)),
            Ring((fx, 0.425, zl(0.32)), 0.034 * k, 0.042 * k, up=(0, 1, 0)),
            Ring((fx, 0.42, zl(0.2)), 0.038 * k, 0.044 * k, up=(0, 1, 0), cell="c3"),
            Ring((fx, 0.42, zl(0.155)), 0.054 * k, 0.064 * k, up=(0, 1, 0), cell="d2"),
        ], n=6, cell="c1", w="f_can." + side, cap_start=False)
        hoof(b, fx, 0.42, zl(0.17), "f_hoof." + side)
        b.loft([
            Ring((rx, -0.48, zl(1.02)), 0.09 * k, 0.2, up=(0, 1, 0)),
            Ring((rx, -0.45, zl(0.86)), 0.105 * k, 0.2, up=(0, 1, 0)),
            Ring((rx, -0.39, zl(0.68)), 0.08 * k, 0.13 * k, up=(0, 1, 0)),
            Ring((rx, -0.37, zl(0.59)), 0.06 * k, 0.09 * k, up=(0, 1, 0)),
        ], n=6, cell="c1", w="r_thigh." + side, cap_start=False, cap_end=False)
        b.loft([
            Ring((rx, -0.36, zl(0.64)), 0.06 * k, 0.09 * k, up=(0.0, 0.7, 0.7)),
            Ring((rx, -0.46, zl(0.53)), 0.052 * k, 0.07 * k, up=(0.0, 0.7, 0.7)),
            Ring((rx, -0.56, zl(0.43)), 0.042 * k, 0.05 * k, up=(0.0, 0.7, 0.7)),
        ], n=6, cell="c1", w="r_gas." + side, cap_start=False, cap_end=False)
        b.loft([
            Ring((rx, -0.585, zl(0.48)), 0.042 * k, 0.052 * k, up=(0, 1, 0)),
            Ring((rx, -0.575, zl(0.40)), 0.044 * k, 0.062 * k, up=(0, 1, 0)),
            Ring((rx, -0.55, zl(0.3)), 0.032 * k, 0.042 * k, up=(0, 1, 0)),
            Ring((rx, -0.54, zl(0.2)), 0.038 * k, 0.044 * k, up=(0, 1, 0), cell="c3"),
            Ring((rx, -0.54, zl(0.155)), 0.054 * k, 0.064 * k, up=(0, 1, 0), cell="d2"),
        ], n=6, cell="c1", w="r_can." + side, cap_start=False)
        hoof(b, rx, -0.54, zl(0.17), "r_hoof." + side)

    mirror_x(leg)


def hoof(b, x, y, z, bone):
    b.loft([
        Ring((x, y, z), 0.044, 0.05, up=(0, 1, 0)),
        Ring((x, y + 0.012, z - 0.065), 0.056, 0.066, up=(0, 1, 0), cell="soot"),
        Ring((x, y + 0.02, z - 0.12), 0.078, 0.092, up=(0, 1, 0), cell="soot"),
        Ring((x, y + 0.02, 0.0), 0.085, 0.1, up=(0, 1, 0), cell="soot"),
    ], n=6, cell="soot", w=bone, cap_start=False)


def build_hair(b):
    # Mane: big shaggy tufts along the crest, falling to both sides.
    crest = [(0.47, 1.22), (0.53, 1.29), (0.59, 1.36), (0.65, 1.43), (0.70, 1.5), (0.75, 1.56), (0.79, 1.62), (0.82, 1.66)]
    for i, (y, z) in enumerate(crest):
        sg = 1 if i % 2 == 0 else -1
        if y < 0.52:
            wm = {"chest": 0.5, "neck1": 0.5}
        elif y < 0.66:
            wm = "neck1"
        elif y < 0.74:
            wm = {"neck1": 0.5, "neck2": 0.5}
        else:
            wm = "neck2"
        b.loft([
            Ring((0, y, z + 0.05), 0.03, 0.09, up=(0, -0.8, 0.6)),
            Ring((sg * 0.075, y - 0.05, z - 0.08), 0.04, 0.095, up=(0, -0.7, 0.7)),
            Ring((sg * 0.14, y - 0.06, z - 0.27), 0.024, 0.05, up=(0, -0.7, 0.7)),
        ], n=5, cell="d1", w=wm)
    # Forelock falls between the eyes.
    b.loft([
        Ring((0, 0.82, 1.66), 0.04, 0.05, up=(0, 0.7, 0.7)),
        Ring((0, 0.92, 1.58), 0.06, 0.04, up=(0, 0.7, 0.7)),
        Ring((0.01, 1.0, 1.46), 0.03, 0.016, up=(0, 0.7, 0.7)),
    ], n=5, cell="d1", w="head")
    # Tail: full and broad so it flies well in a gallop.
    b.loft([
        Ring((0, -0.72, 1.04), 0.06, 0.065, w="tail1"),
        Ring((0, -0.81, 0.93), 0.09, 0.09, w="tail1"),
        Ring((0, -0.87, 0.78), 0.115, 0.1, w={"tail1": 0.3, "tail2": 0.7}),
        Ring((0, -0.9, 0.62), 0.125, 0.095, w="tail2"),
        Ring((0, -0.915, 0.44), 0.095, 0.075, w={"tail2": 0.3, "tail3": 0.7}),
        Ring((0, -0.92, 0.28), 0.03, 0.026, w="tail3"),
    ], n=6, cell="d1")


def rug_side(b, sg, y0, y1, x0, z0, x1, z1, field, edge, tile, out=0.004):
    """One hanging flap of a saddle rug: field colour, hem band and a painted medallion in the middle."""
    def quad(s0, s1, t0, t1, cell=None, tile_name=None, off=0.0):
        corners = [(s0, t0), (s1, t0), (s1, t1), (s0, t1)]
        if sg > 0:
            corners = [corners[0], corners[3], corners[2], corners[1]]
        idx, uvs = [], []
        for s_, t_ in corners:
            x = sg * (x0 + (x1 - x0) * t_) + sg * off
            idx.append(b.vert((x, y0 + (y1 - y0) * s_, z0 + (z1 - z0) * t_), "body"))
            if tile_name:
                uvs.append(kit.tile_uv(tile_name, s_, 1.0 - t_))
        if tile_name:
            b.face(idx, uvs=uvs)
        else:
            b.face(idx, cell=cell)

    quad(0, 1, 0, 1, field)
    quad(0, 1, 0.86, 1.0, edge, off=out)
    quad(0, 1, 0.0, 0.07, edge, off=out)
    quad(0.3, 0.7, 0.12, 0.84, tile_name=tile, off=out * 1.5)


def build_tack(b):
    zt = BACK_TOP + 0.012
    # Paired rugs: a long one underneath, a short one on top, both in the team trim colour.
    for sg in (1, -1):
        # Lower rug: top panel plus a flap on each side.
        top = [b.vert((sg * 0.0, y, zt), "body") for y in (-0.31, 0.31)] + [b.vert((sg * 0.27, y, zt - 0.1), "body") for y in (-0.31, 0.31)]
        b.face([top[0], top[2], top[3], top[1]] if sg > 0 else [top[0], top[1], top[3], top[2]], cell="b1")
        rug_side(b, sg, -0.31, 0.31, 0.27, zt - 0.1, 0.375, zt - 0.4, "b1", "b2", "rug_lotus")
        # Upper rug, smaller, in the deeper shade with a different medallion.
        zu = zt + 0.014
        top = [b.vert((sg * 0.0, y, zu), "body") for y in (-0.22, 0.22)] + [b.vert((sg * 0.25, y, zu - 0.09), "body") for y in (-0.22, 0.22)]
        b.face([top[0], top[2], top[3], top[1]] if sg > 0 else [top[0], top[1], top[3], top[2]], cell="b2")
        rug_side(b, sg, -0.22, 0.22, 0.25, zu - 0.09, 0.335, zu - 0.31, "b2", "b3", "rug_diamond", out=0.008)
    # Saddle tree: low seat between tall brass-plated arches.
    zs = zt + 0.04
    b.loft([
        Ring((0, -0.2, zs), 0.13, 0.04, up=(0, 0, 1)),
        Ring((0, -0.05, zs - 0.006), 0.16, 0.04),
        Ring((0, 0.1, zs - 0.006), 0.16, 0.04),
        Ring((0, 0.22, zs), 0.12, 0.04),
    ], n=6, cell="wood_dark", w="body", axis=(0, 1, 0))
    for y, sgy in ((0.275, 1), (-0.265, -1)):
        h = 0.34
        xb, xt = 0.165, 0.115
        z0 = zs + 0.02
        b.box((0, y - sgy * 0.03, z0 + h * 0.5), (0.3, 0.035, h), cell="wood_dark", w="body", taper=(0.76, 1.0))
        face_y = y + sgy * 0.0
        pts = [(xb, face_y, z0), (-xb, face_y, z0), (-xt, face_y, z0 + h), (xt, face_y, z0 + h)]
        if sgy < 0:
            pts = [(-xb, face_y, z0), (xb, face_y, z0), (xt, face_y, z0 + h), (-xt, face_y, z0 + h)]
        b.quad_tile(pts, "saddle_pierced", w="body")
        b.sphere((0, y - sgy * 0.012, z0 + h + 0.02), 0.03, cell="brass", w="body", segs=6, rings=3)
    # Girth under the belly.
    gz, grx, grz = body_at(0.19)
    b.loft([Ring((0, 0.16, gz), grx + 0.012, grz + 0.012), Ring((0, 0.225, gz), grx + 0.012, grz + 0.012)], n=12, cell="leather", w="chest",
           axis=(0, 1, 0), cap_start=False, cap_end=False)
    # Breast band: a leather hoop across the chest front, with brass bells hanging from it.
    half = []
    for y in (0.3, 0.46, 0.58, 0.64):
        zc, rx, _ = body_at(y)
        half.append((rx * 1.1, y, zc - 0.03))
    path = [(-x, y, z) for (x, y, z) in half] + [(0.0, 0.672, body_at(0.655)[0] - 0.03)] + [(x, y, z) for (x, y, z) in reversed(half)]
    b.tube(path, [0.03] * len(path), n=4, cell="leather", w="chest", cap_start=False, cap_end=False)
    for x, y, z in ((-0.17, 0.62, 0.78), (0.0, 0.7, 0.76), (0.17, 0.62, 0.78), (-0.27, 0.5, 0.85), (0.27, 0.5, 0.85)):
        b.sphere((x, y, z), 0.04, cell="brass", w="chest", segs=6, rings=3)
        b.box((x, y, z + 0.045), (0.012, 0.012, 0.05), cell="leather", w="chest")
    # Long red throat tassel: cord, full head, tapering tail.
    b.loft([
        Ring((0, 0.8, 1.38), 0.016, 0.016, up=(0, 1, 0)),
        Ring((0, 0.84, 1.26), 0.07, 0.07, up=(0, 1, 0), cell="vermilion"),
        Ring((0, 0.86, 1.0), 0.06, 0.06, up=(0, 1, 0), cell="vermilion"),
        Ring((0, 0.86, 0.72), 0.05, 0.05, up=(0, 1, 0), cell="cinnabar"),
        Ring((0, 0.86, 0.52), 0.012, 0.012, up=(0, 1, 0)),
    ], n=6, cell="vermilion", w={"neck1": 0.7, "neck2": 0.3})
    # Bridle: brass browband, leather noseband, poll plume.
    b.loft([Ring((0, 0.932, 1.536), 0.1325, 0.1525, up=(0, 0.75, 0.65)), Ring((0, 0.95, 1.512), 0.1325, 0.1525, up=(0, 0.75, 0.65))],
           n=8, cell="brass", w="head", cap_start=False, cap_end=False)
    b.loft([Ring((0, 1.184, 1.278), 0.0975, 0.1125, up=(0, 0.75, 0.65)), Ring((0, 1.208, 1.254), 0.0975, 0.1125, up=(0, 0.75, 0.65))],
           n=8, cell="leather", w="head", cap_start=False, cap_end=False)
    b.loft([
        Ring((0, 0.86, 1.66), 0.014, 0.014, up=(0, 1, 0)),
        Ring((0, 0.86, 1.77), 0.05, 0.05, up=(0, 1, 0), cell="d1"),
        Ring((0, 0.84, 1.88), 0.014, 0.014, up=(0, 1, 0), cell="d1"),
    ], n=5, cell="d1", w="head")
    # Crupper strap over the croup to the tail root, with a red drop each side.
    cz = [body_at(y) for y in (-0.27, -0.45, -0.58, -0.7, -0.76)]
    b.tube([(0, -0.27, zt + 0.0), (0, -0.45, cz[1][0] + cz[1][2] + 0.01), (0, -0.58, cz[2][0] + cz[2][2] + 0.01),
            (0, -0.7, cz[3][0] + cz[3][2] + 0.01), (0, -0.76, cz[4][0] + cz[4][2] + 0.01)], [0.016] * 5, n=4, cell="leather", w="hips")
    for sg in (1, -1):
        b.box((sg * 0.1, -0.5, body_at(-0.5)[0] + body_at(-0.5)[2] - 0.03), (0.02, 0.03, 0.12), cell="vermilion", w="hips")
        b.sphere((sg * 0.1, -0.5, body_at(-0.5)[0] + body_at(-0.5)[2] - 0.1), 0.026, cell="brass", w="hips", segs=5, rings=3)
    # Stirrups: leather strap, iron arch and tread.

    def stirrup(side, sg):
        x = sg * kit.STIRRUP_X
        y = kit.STIRRUP_Y
        b.box((sg * 0.285, y, 1.07), (0.03, 0.02, 0.5), cell="leather", w="body", rot=(0, -sg * 19, 0))
        b.box((x, y, kit.STIRRUP_Z + 0.012), (0.15, 0.07, 0.024), cell="iron", w="body")
        for dx in (-0.066, 0.066):
            b.box((x + dx, y, kit.STIRRUP_Z + 0.115), (0.02, 0.04, 0.2), cell="iron", w="body")
        b.box((x, y, kit.STIRRUP_Z + 0.215), (0.15, 0.04, 0.026), cell="iron", w="body")

    mirror_x(stirrup)


def gallop_leg(p, stance, amp, flex):
    """Returns swing angle and joint flex for a leg at phase p."""
    p = p % 1.0
    if p < stance:
        s = p / stance
        return amp * (1.0 - 2.0 * s), 0.0
    s = (p - stance) / (1.0 - stance)
    e = s * s * (3.0 - 2.0 * s)
    return amp * (-1.0 + 2.0 * e), flex * math.sin(math.pi * s) ** 1.2


def make_gait(name, frames, offs, stance, fore_amp, hind_amp, fore_flex, hind_flex, bob, pitch, neck, tail, lean=0.0):
    two_pi = 2.0 * math.pi

    def fn(t):
        pose, loc = {}, {}
        for bone_side, key in (("R", "fr"), ("L", "fl")):
            a, f = gallop_leg(t - offs[key], stance, fore_amp, fore_flex)
            pose["f_arm." + bone_side] = (a + f * 0.35, 0, 0)
            pose["f_can." + bone_side] = (-f, 0, 0)
            pose["f_hoof." + bone_side] = (-f * 0.5 + max(0.0, -a) * 0.7, 0, 0)
        for bone_side, key in (("R", "hr"), ("L", "hl")):
            a, f = gallop_leg(t - offs[key], stance, hind_amp, hind_flex)
            pose["r_thigh." + bone_side] = (a - f * 0.28, 0, 0)
            pose["r_gas." + bone_side] = (-f * 0.7, 0, 0)
            pose["r_can." + bone_side] = (f * 1.15, 0, 0)
            pose["r_hoof." + bone_side] = (-f * 0.5 + max(0.0, -a) * 0.8, 0, 0)
        wave = math.sin(two_pi * t)
        wave2 = math.sin(two_pi * t + 1.1)
        pose["body"] = (pitch * wave, 0, lean * math.sin(two_pi * t))
        pose["chest"] = (-pitch * 0.25 * wave, 0, 0)
        pose["hips"] = (pitch * 0.35 * wave2, 0, 0)
        pose["neck1"] = (lean * 0.0 + 8.0 - neck * wave2, 0, 0)
        pose["neck2"] = (-neck * 0.6 * math.sin(two_pi * t + 2.0), 0, 0)
        pose["head"] = (neck * 0.5 * math.sin(two_pi * t + 2.6) - 6.0, 0, 0)
        pose["tail1"] = (-tail - tail * 0.25 * math.sin(two_pi * t + 0.4), 0, 0)
        pose["tail2"] = (-tail * 0.35 + tail * 0.35 * math.sin(two_pi * t + 1.3), 0, 0)
        pose["tail3"] = (tail * 0.3 * math.sin(two_pi * t + 2.2) - tail * 0.15, 0, 0)
        loc["body"] = (0, 0, bob * math.sin(two_pi * t + 0.6))
        return pose, loc

    return name, frames, fn


def build_actions(rig):
    gallop = {"hr": 0.0, "hl": 0.13, "fr": 0.42, "fl": 0.56}
    canter = {"hr": 0.0, "hl": 0.32, "fr": 0.32, "fl": 0.62}
    trot = {"hr": 0.0, "hl": 0.5, "fr": 0.5, "fl": 0.0}
    walk = {"hr": 0.0, "hl": 0.5, "fr": 0.25, "fl": 0.75}
    gaits = [
        make_gait("gallop", 14, gallop, 0.3, 34.0, 32.0, 62.0, 56.0, 0.055, 4.0, 7.0, 44.0),
        make_gait("canter", 18, canter, 0.36, 28.0, 28.0, 52.0, 48.0, 0.05, 3.5, 7.0, 28.0),
        make_gait("trot", 16, trot, 0.45, 20.0, 19.0, 44.0, 40.0, 0.03, 1.0, 3.0, 12.0),
        make_gait("walk", 32, walk, 0.62, 14.0, 13.0, 30.0, 26.0, 0.012, 0.6, 2.5, 4.0),
    ]
    for name, frames, fn in gaits:
        kit.bake_fn(rig, name, frames, fn)
    kit.bake_fn(rig, "idle", 60, lambda t: ({
        "neck1": (2.0 * math.sin(2 * math.pi * t), 0, 0),
        "head": (-3.0 + 3.0 * math.sin(2 * math.pi * t + 1.0), 0, 2.5 * math.sin(2 * math.pi * t)),
        "tail1": (5.0, 0, 7.0 * math.sin(4 * math.pi * t)),
        "tail2": (0, 0, 9.0 * math.sin(4 * math.pi * t + 0.8)),
    }, {"body": (0, 0, 0.006 * math.sin(2 * math.pi * t))}))
    tuck = {
        "f_arm.R": (42, 0, 0), "f_can.R": (-85, 0, 0), "f_arm.L": (50, 0, 0), "f_can.L": (-90, 0, 0),
        "r_thigh.R": (-18, 0, 0), "r_gas.R": (-30, 0, 0), "r_can.R": (50, 0, 0),
        "r_thigh.L": (-10, 0, 0), "r_gas.L": (-34, 0, 0), "r_can.L": (56, 0, 0),
        "tail1": (58, 0, 0), "tail2": (16, 0, 0), "neck1": (-10, 0, 0), "head": (-6, 0, 0),
    }
    kit.bake_keys(rig, "leap", [
        (0, {"body": (14, 0, 0), "f_arm.R": (40, 0, 0), "f_arm.L": (46, 0, 0), "r_thigh.R": (-24, 0, 0), "r_thigh.L": (-28, 0, 0), "tail1": (40, 0, 0)}, None, "out"),
        (5, dict(tuck, body=(6, 0, 0)), None, "smooth"),
        (11, dict(tuck, body=(-8, 0, 0)), None, "in"),
        (16, {"body": (-14, 0, 0), "f_arm.R": (20, 0, 0), "f_arm.L": (-8, 0, 0), "r_thigh.R": (-34, 0, 0), "r_thigh.L": (-30, 0, 0), "r_gas.R": (-20, 0, 0), "r_can.R": (34, 0, 0), "tail1": (64, 0, 0)}, None),
    ])
    kit.bake_keys(rig, "rear", [
        (0, {}, None, "out"),
        (8, {"body": (36, 0, 0), "chest": (6, 0, 0), "neck1": (-22, 0, 0), "head": (-12, 0, 0), "f_arm.R": (66, 0, 0), "f_can.R": (-108, 0, 0), "f_arm.L": (38, 0, 0), "f_can.L": (-96, 0, 0), "r_thigh.R": (-34, 0, 0), "r_thigh.L": (-28, 0, 0), "r_gas.R": (16, 0, 0), "r_gas.L": (16, 0, 0), "tail1": (-6, 0, 0)}, {"body": (0, -0.1, -0.05)}),
        (13, {"body": (40, 0, 0), "chest": (6, 0, 0), "neck1": (-14, 0, 0), "head": (-20, 0, 0), "f_arm.R": (40, 0, 0), "f_can.R": (-84, 0, 0), "f_arm.L": (62, 0, 0), "f_can.L": (-108, 0, 0), "r_thigh.R": (-34, 0, 0), "r_thigh.L": (-28, 0, 0), "r_gas.R": (16, 0, 0), "r_gas.L": (16, 0, 0), "tail1": (-6, 0, 0)}, {"body": (0, -0.1, -0.05)}),
        (24, {}, None),
    ])
    kit.bake_keys(rig, "stumble", [
        (0, {}, None, "out"),
        (6, {"body": (-16, 8, 6), "neck1": (20, 0, -8), "head": (10, 0, 12), "f_arm.R": (-20, 0, 0), "f_can.R": (-30, 0, 0), "f_arm.L": (24, 0, 0), "f_can.L": (-60, 0, 0), "tail1": (40, 0, 0)}, {"body": (0, 0, -0.08)}),
        (12, {"body": (6, -6, -4), "neck1": (-10, 0, 8), "head": (-8, 0, -6), "f_arm.R": (26, 0, 0), "f_can.R": (-50, 0, 0), "tail1": (20, 0, 0)}, None),
        (20, {}, None),
    ])
    kit.reset_pose(rig)


def main():
    kit.clear_scene()
    rig = kit.make_rig("horse_rig", BONES)
    b = Builder("horse_mesh")
    build_body(b)
    build_legs(b)
    build_hair(b)
    build_tack(b)
    obj = b.to_object(rig)
    build_actions(rig)
    print("horse tris", b.tri_count())
    kit.export_glb("horse", [rig, obj], animations=True)
    return rig, obj


if __name__ == "__main__":
    main()
