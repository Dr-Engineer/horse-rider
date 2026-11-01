"""Monuments and big landmarks: potala, chakpori_hill, gate_chorten, dzong, kumbum, monastery. Fronts face +Y.
All have their own footing so they sit on any ground. No script, no figures, no sacred images."""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import props_lib as L  # noqa: E402
import kit  # noqa: E402


def window_quads(b, x0, x1, z0, z1, y, cols, rows, w, h, cell="ink"):
    """Single-sided window quads facing +Y, laid out on a grid."""
    for r in range(rows):
        for c in range(cols):
            cx = x0 + (c + 0.5) * (x1 - x0) / cols
            cz = z0 + (r + 0.5) * (z1 - z0) / rows
            idx = [b.vert((cx - w / 2, y, cz - h / 2)), b.vert((cx - w / 2, y, cz + h / 2)), b.vert((cx + w / 2, y, cz + h / 2)), b.vert((cx + w / 2, y, cz - h / 2))]
            b.face(idx, cell=cell)


def window_quads_side(b, y0, y1, z0, z1, x, cols, rows, w, h, sign=1, cell="ink"):
    for r in range(rows):
        for c in range(cols):
            cy = y0 + (c + 0.5) * (y1 - y0) / cols
            cz = z0 + (r + 0.5) * (z1 - z0) / rows
            idx = [b.vert((x, cy - w / 2, cz - h / 2)), b.vert((x, cy + w / 2, cz - h / 2)), b.vert((x, cy + w / 2, cz + h / 2)), b.vert((x, cy - w / 2, cz + h / 2))]
            b.face(idx if sign > 0 else list(reversed(idx)), cell=cell)


def hill(b, c, r, seed, low_cells=("khaki", "grass_gold", "grass_green"), high_cells=("rock_grey", "ash", "rock_grey", "rock_dark"), segs=12, rings=5, split=0.28):
    rng = random.Random(seed)
    first = len(b.faces)
    L.blob(b, c, r, rng, segs=segs, rings=rings, cell="rock_grey", jitter=0.12, cut=0.5)
    zlo = c[2] - r[2] * 0.5
    zhi = c[2] + r[2]
    for i in range(first, len(b.faces)):
        zc = sum(b.co[k].z for k in b.faces[i]) / len(b.faces[i])
        t = (zc - zlo) / (zhi - zlo)
        pick = low_cells if t < split else high_cells
        b.loop_uvs[i] = [kit.cell_uv(pick[i % len(pick)])] * len(b.faces[i])
    return first


def hill_z(c, r, x, y):
    t = 1.0 - ((x - c[0]) / r[0]) ** 2 - ((y - c[1]) / r[1]) ** 2
    return c[2] + r[2] * math.sqrt(max(t, 0.0))


def crenels(b, x0, x1, y, z, n, cell, size=1.0, h=1.0):
    for i in range(n):
        x = x0 + (i + 0.5) * (x1 - x0) / n
        if i % 2 == 0:
            L.slab(b, x - size / 2, y - size / 2, z, x + size / 2, y + size / 2, z + h, cell=cell)


def gold_roof(b, x, y, z, w, d, h, cell="gold"):
    L.slab(b, x - w / 2, y - d / 2, z, x + w / 2, y + d / 2, z + h * 0.4, cell="madder")
    L.slab(b, x - w / 2 - 0.8, y - d / 2 - 0.8, z + h * 0.4, x + w / 2 + 0.8, y + d / 2 + 0.8, z + h, cell=cell, inset=(w * 0.32, d * 0.32))
    L.cone_t(b, x, y, z + h, z + h + 2.2, 0.35, n=4, cell="orpiment")


def potala():
    b = L.new("potala")
    hill(b, (0, 6, 8), (125, 52, 34), 3)
    # White palace, two stepped tiers across the whole hill.
    L.slab(b, -108, -13, 12, 108, 13, 44, cell="chalk", inset=(6, 3))
    L.slab(b, -112, -14, 41.5, 112, 14, 44, cell="pema")
    L.slab(b, -90, -11, 44, 90, 11, 62, cell="chalk", inset=(5, 2))
    L.slab(b, -93, -12, 59.5, 93, 12, 62, cell="pema")
    window_quads(b, -102, 102, 22, 40, 11.2, 30, 3, 2.4, 3.4)
    window_quads(b, -84, 84, 47, 58, 9.4, 26, 2, 2.4, 3.2)
    window_quads_side(b, -12, 12, 22, 40, 108 - 5.4, 5, 3, 2.4, 3.4, 1)
    window_quads_side(b, -12, 12, 22, 40, -108 + 5.4, 5, 3, 2.4, 3.4, -1)
    crenels(b, -108, 108, 0, 44.0, 52, "chalk", 1.8, 1.4)
    # Red palace in the middle, rising in three steps, with gold roofs.
    L.slab(b, -38, -19, 38, 38, 19, 70, cell="madder", inset=(3, 2), top_cell="cinnabar")
    L.slab(b, -31, -15, 70, 31, 15, 88, cell="pema", inset=(3, 2))
    L.slab(b, -22, -12, 88, 22, 12, 104, cell="madder", inset=(2, 2))
    L.slab(b, -40, -20, 36, 40, 20, 41, cell="chalk")
    L.slab(b, -42, -20.5, 62.5, 42, 20.5, 64, cell="chalk")
    window_quads(b, -33, 33, 45, 66, 19.0, 11, 3, 2.2, 3.6)
    window_quads(b, -27, 27, 73, 85, 14.6, 9, 2, 2.2, 3.4)
    window_quads(b, -17, 17, 91, 101, 11.6, 6, 2, 2.2, 3.4)
    for (x, z, w) in ((-16, 104, 12), (0, 104, 18), (16, 104, 12)):
        gold_roof(b, x, 0, z, w, 10, 7)
    for x in (-24, 24):
        gold_roof(b, x, 0, 88, 10, 8, 5)
    for x in (-36, 36):
        gold_roof(b, x, 0, 70, 9, 8, 4.5)
    for (x, z) in ((-95, 62), (95, 62), (-64, 44), (64, 44)):
        gold_roof(b, x, 0, z, 9, 7, 4.5)
    # Long zig-zag white stair up the front and a wall along the foot.
    pts = [(-72, 40, 1), (-40, 36, 10), (-70, 30, 16), (-30, 22, 26), (-62, 16, 34)]
    b.strip(pts, [5, 5, 5, 5, 5], normal=(0, 0, 1), cell="chalk", double=False)
    pts2 = [(72, 40, 1), (40, 36, 10), (70, 30, 16), (30, 22, 26), (62, 16, 34)]
    b.strip(pts2, [5, 5, 5, 5, 5], normal=(0, 0, 1), cell="chalk", double=False)
    return b


def chakpori_hill():
    b = L.new("chakpori_hill")
    hill(b, (0, 0, 20), (88, 58, 52), 5, segs=10, rings=5)
    # A small whitewashed college on the summit.
    for (x, y, w, d, h, z) in ((0, 0, 24, 14, 10, 68), (-20, 2, 14, 10, 7, 64), (20, -2, 14, 10, 7, 64)):
        L.slab(b, x - w / 2, y - d / 2, z, x + w / 2, y + d / 2, z + h, cell="chalk", inset=(1.2, 0.8))
        L.slab(b, x - w / 2 - 0.4, y - d / 2 - 0.4, z + h - 2.2, x + w / 2 + 0.4, y + d / 2 + 0.4, z + h - 0.8, cell="pema")
        L.slab(b, x - w / 2 - 0.6, y - d / 2 - 0.6, z + h, x + w / 2 + 0.6, y + d / 2 + 0.6, z + h + 1.0, cell="chalk", top_cell="slate")
        window_quads(b, x - w / 2 + 2, x + w / 2 - 2, z + 2, z + h - 3.4, y + d / 2 - 0.5, max(2, int(w / 4)), 1, 1.6, 2.2)
    gold_roof(b, 0, 0, 79, 8, 6, 4)
    L.slab(b, -26, 22, 4, 26, 24, 14, cell="chalk", inset=(0, 0.4))
    return b


def gate_chorten():
    b = L.new("gate_chorten")
    half = 17.0
    for sx in (-1, 1):
        x0, x1 = (half, half + 14.0) if sx > 0 else (-half - 14.0, -half)
        L.slab(b, x0, -9, -3, x1, 9, 15, cell="chalk", inset=(1.4, 1.2))
        L.slab(b, x0 - 0.3, -9.3, 11.5, x1 + 0.3, 9.3, 13.5, cell="pema")
        window_quads(b, x0 + 2, x1 - 2, 3, 9, 8.8, 2, 1, 1.8, 3.0)
    # Lintel across the passage and the chorten that sits on it.
    L.slab(b, -half - 14.4, -9.5, 15, half + 14.4, 9.5, 24, cell="bone", inset=(1.2, 1.0))
    L.slab(b, -half - 14.6, -9.8, 18.2, half + 14.6, 9.8, 19.6, cell="vermilion")
    L.slab(b, -half - 14.6, -9.8, 14.4, half + 14.6, 9.8, 15.4, cell="pema")
    L.slab(b, -13, -8, 24, 13, 8, 27, cell="chalk", inset=(1, 1))
    L.slab(b, -10, -6, 27, 10, 6, 30, cell="bone", inset=(1, 1))
    L.cyl(b, 0, 0, 30, 3.5, 7.0, n=10, cell="chalk", r_top=7.6)
    L.cyl(b, 0, 0, 33.5, 9.5, 7.6, n=10, cell="chalk", r_top=5.6)
    L.cyl(b, 0, 0, 43, 1.2, 5.6, n=10, cell="madder", r_top=5.0)
    L.slab(b, -3.6, -3.6, 44.2, 3.6, 3.6, 49, cell="bone")
    L.slab(b, -3.8, -3.8, 47.6, 3.8, 3.8, 48.6, cell="orpiment")
    r, z = 3.3, 49.0
    for k in range(8):
        L.cyl(b, 0, 0, z, 1.6, r, n=10, cell="bone" if k % 2 == 0 else "chalk", r_top=r * 0.9)
        z += 1.6
        r *= 0.88
    L.cyl(b, 0, 0, z, 1.2, 2.6, n=10, cell="gold", r_top=1.8)
    L.cone_t(b, 0, 0, z + 1.2, z + 5.0, 1.2, n=6, cell="gold")
    # Low white walls running out from both sides, with crenellated tops.
    for sx in (-1, 1):
        x0, x1 = (half + 14.0, half + 74.0) if sx > 0 else (-half - 74.0, -half - 14.0)
        L.slab(b, x0, -2.2, -2, x1, 2.2, 7.5, cell="chalk", inset=(0, 0.5))
        L.slab(b, x0, -2.4, 5.8, x1, 2.4, 6.8, cell="pema")
        crenels(b, x0, x1, 0, 7.5, 30, "chalk", 1.4, 1.1)
    # Flag strings from the spire to the ends of the walls.
    f = L.new("flags")
    hangs = []
    top = (0.0, 0.0, z + 0.5)
    for sx in (-1, 1):
        end = (sx * (half + 72.0), 0.0, 8.5)
        L.rope(b, top, end, r=0.1)
        p_a, p_b = (end, top) if sx < 0 else (top, end)
        L.flag_row(f, hangs, p_a, p_b, sag=1.2, w=1.5, h=2.2, gap=0.5, rows=2, cols=1)
    L.export("gate_chorten", [("gate_chorten", b), ("flags", f, hangs)])


def dzong():
    b = L.new("dzong")
    hill(b, (0, 0, 24), (100, 55, 50), 8, segs=11, rings=6, split=0.2)
    base = 62
    # Massive battered walls: white lower, rust-red upper, corner towers, a tall keep.
    L.slab(b, -62, -22, base - 8, 62, 22, base + 20, cell="chalk", inset=(5, 3))
    L.slab(b, -58, -19, base + 20, 58, 19, base + 34, cell="rock_red", inset=(3, 2))
    L.slab(b, -56, -18, base + 33, 56, 18, base + 36, cell="pema")
    crenels(b, -58, 58, 18.5, base + 36, 40, "rock_red", 2.2, 1.8)
    for sx in (-1, 1):
        for sy in (-1, 1):
            L.cyl(b, sx * 60, sy * 20, base - 8, 52, 7.5, n=8, cell="chalk", r_top=6.0)
            L.cyl(b, sx * 60, sy * 20, base + 44, 8, 6.4, n=8, cell="rock_red", r_top=6.4)
            L.cone_t(b, sx * 60, sy * 20, base + 52, base + 58, 7.0, n=8, cell="madder")
    L.slab(b, -20, -14, base + 34, 20, 14, base + 62, cell="rock_red", inset=(3, 2))
    L.slab(b, -22, -15, base + 56, 22, 15, base + 59, cell="pema")
    gold_roof(b, 0, 0, base + 62, 20, 14, 8)
    L.slab(b, -44, -12, base + 34, -22, 12, base + 48, cell="chalk", inset=(2, 2))
    L.slab(b, 22, -12, base + 34, 44, 12, base + 48, cell="chalk", inset=(2, 2))
    window_quads(b, -54, 54, base - 2, base + 16, 22.2 - 3.0, 22, 2, 2.4, 3.6)
    window_quads(b, -50, 50, base + 22, base + 30, 18.4 - 2.0, 18, 1, 2.2, 3.2)
    window_quads(b, -16, 16, base + 38, base + 54, 11.6 - 0.4, 5, 3, 2.0, 3.2)
    # Long wall zig-zagging down the hillside.
    pts = [(-60, 20, 44), (-86, 30, 30), (-56, 36, 16), (-94, 40, 6)]
    for (a, c) in zip(pts[:-1], pts[1:]):
        mx, my, mz = (a[0] + c[0]) / 2, (a[1] + c[1]) / 2, (a[2] + c[2]) / 2
        L.slab(b, min(a[0], c[0]) - 1.5, min(a[1], c[1]) - 1.5, min(a[2], c[2]) - 4, max(a[0], c[0]) + 1.5, max(a[1], c[1]) + 1.5, max(a[2], c[2]) + 4, cell="chalk", inset=(0.6, 0.6))
    return b


def kumbum():
    b = L.new("kumbum")
    z = 0.0
    size = 34.0
    heights = [9, 8, 7.5, 7, 6.5, 6, 5.5, 5, 4.5]
    for i, h in enumerate(heights):
        L.slab(b, -size, -size, z, size, size, z + h, cell="chalk", inset=(1.5, 1.5))
        L.slab(b, -size - 0.6, -size - 0.6, z + h - 1.6, size + 0.6, size + 0.6, z + h - 0.3, cell="pema")
        L.slab(b, -size - 1.0, -size - 1.0, z + h - 0.3, size + 1.0, size + 1.0, z + h + 0.5, cell="bone", top_cell="slate")
        window_quads(b, -size + 3, size - 3, z + 1.5, z + h - 2.4, size - 1.4, max(3, int(size / 5)), 1, 1.6, 2.2)
        # Small golden roofs at the corners of the lower tiers.
        if i < 6:
            for sx in (-1, 1):
                for sy in (-1, 1):
                    gold_roof(b, sx * (size - 2.5), sy * (size - 2.5), z + h + 0.5, 4, 4, 2.4)
        z += h + 0.5
        size -= 3.4
    L.cyl(b, 0, 0, z, 4.5, size + 1.5, n=10, cell="chalk", r_top=size + 2.5)
    L.cyl(b, 0, 0, z + 4.5, 7.5, size + 2.5, n=10, cell="chalk", r_top=size - 1.0)
    z += 12.0
    L.slab(b, -4, -4, z, 4, 4, z + 4.5, cell="gold")
    r = 3.4
    zz = z + 4.5
    for k in range(7):
        L.cyl(b, 0, 0, zz, 1.5, r, n=8, cell="gold", r_top=r * 0.9)
        zz += 1.5
        r *= 0.86
    L.cone_t(b, 0, 0, zz, zz + 4.0, 1.2, n=6, cell="orpiment")
    return b


def monastery():
    rng = random.Random(21)
    b = L.new("monastery")
    mc, mr = (0, 0, 8), (104, 56, 30)
    hill(b, mc, mr, 12, segs=11, rings=5, split=0.3)
    # Main assembly hall: tall white block, red band, golden roof ornaments.
    L.slab(b, -26, -18, 30, 26, 18, 52, cell="chalk", inset=(2, 1.5))
    L.slab(b, -27, -19, 44, 27, 19, 50, cell="madder", inset=(1.5, 1.2))
    L.slab(b, -28, -19.5, 50, 28, 19.5, 53, cell="bone", top_cell="slate")
    window_quads(b, -22, 22, 33, 42, 17.0, 10, 1, 1.8, 3.0)
    gold_roof(b, -14, 0, 53, 12, 12, 6)
    gold_roof(b, 14, 0, 53, 12, 12, 6)
    gold_roof(b, 0, 0, 53, 16, 14, 8)
    # Terraced white residences stepping down the hill on both sides.
    for sx in (-1, 1):
        for k in range(6):
            x = sx * (38 + k * 11)
            y = rng.uniform(-8, 8)
            z0 = hill_z(mc, mr, x, y) - 2.0
            w, d, h = rng.uniform(9, 13), rng.uniform(8, 12), rng.uniform(7, 10)
            L.slab(b, x - w / 2, y - d / 2, z0, x + w / 2, y + d / 2, z0 + h, cell="chalk", inset=(0.9, 0.8))
            L.slab(b, x - w / 2 - 0.3, y - d / 2 - 0.3, z0 + h - 2.0, x + w / 2 + 0.3, y + d / 2 + 0.3, z0 + h - 0.6, cell="pema")
            L.slab(b, x - w / 2 - 0.4, y - d / 2 - 0.4, z0 + h, x + w / 2 + 0.4, y + d / 2 + 0.4, z0 + h + 0.8, cell="chalk", top_cell="slate")
            window_quads(b, x - w / 2 + 1.5, x + w / 2 - 1.5, z0 + 1.8, z0 + h - 3.2, y + d / 2 - 0.2, 2, 1, 1.3, 1.8)
    # Perimeter wall at the foot.
    L.slab(b, -84, 50, -1, 84, 52.5, 6, cell="chalk", inset=(0, 0.5))
    crenels(b, -84, 84, 51.2, 6, 44, "chalk", 1.6, 1.1)
    return b


def run():
    L.single("potala", potala())
    L.single("chakpori_hill", chakpori_hill())
    gate_chorten()
    L.single("dzong", dzong())
    L.single("kumbum", kumbum())
    L.single("monastery", monastery())


run()
