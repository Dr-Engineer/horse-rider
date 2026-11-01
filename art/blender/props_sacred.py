"""Sacred sites and course furniture: mani wall, chorten, cairn, flags, gates, ramp, scarf, banner, target pole."""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import props_lib as L  # noqa: E402
import kit  # noqa: E402


def rope(b, p0, p1, r=0.035, cell="bone"):
    b.tube([p0, p1], [r, r], n=3, cell=cell)


def mani_wall():
    rng = random.Random(5)
    b = L.new("mani_wall")
    # Battered body in three courses, 12 m long along Y.
    courses = [("rock_grey", 0.0, 0.6), ("ash", 0.6, 1.1), ("rock_grey", 1.1, 1.5)]
    for k, (cell, z0, z1) in enumerate(courses):
        wb = 1.2 - 0.09 * k
        wt = 1.2 - 0.09 * (k + 1)
        L.slab(b, -wb, -6.0 + 0.1 * k, z0 - (0.2 if k == 0 else 0.0), wb, 6.0 - 0.1 * k, z1, cell=cell, inset=(wb - wt, 0.1))
    # Flat top of upright carved stones, each its own colour and height.
    cells = ["bone", "ash", "chalk", "rock_grey", "slate", "bone", "ash"]
    y = -5.6
    while y < 5.5:
        w = rng.uniform(0.55, 0.9)
        h = rng.uniform(0.25, 0.65)
        x = rng.uniform(-0.35, 0.35)
        cell = rng.choice(cells)
        L.slab(b, x - 0.5, y, 1.5, x + 0.5, y + w, 1.5 + h, cell=cell, inset=(0.06, 0.05))
        y += w + 0.04
    # End stones, taller.
    for yy in (-5.95, 5.35):
        L.slab(b, -0.9, yy, 1.5, 0.9, yy + 0.6, 2.35, cell="bone", inset=(0.12, 0.08))
    # Abstract carved marks on the flanks: little groups of three dots, nothing that reads as script.
    for yy in (-4.2, -1.2, 1.8, 4.2):
        for sx in (-1, 1):
            xs = sx * 1.12
            for dx, dz in ((0.0, 0.0), (0.0, 0.28), (0.0, -0.28)):
                L.slab(b, xs - 0.03 if sx < 0 else xs - 0.05, yy - 0.1 + dz * 0.0, 0.55 + dz + 0.25, xs + 0.05 if sx < 0 else xs + 0.03, yy + 0.1, 0.55 + dz + 0.45, cell="slate")
    return b


def chorten():
    b = L.new("chorten")
    L.slab(b, -2.8, -2.8, -0.3, 2.8, 2.8, 0.7, cell="chalk", inset=(0.15, 0.15))
    L.slab(b, -2.4, -2.4, 0.7, 2.4, 2.4, 1.4, cell="bone", inset=(0.15, 0.15))
    L.slab(b, -2.0, -2.0, 1.4, 2.0, 2.0, 2.1, cell="chalk", inset=(0.15, 0.15))
    L.slab(b, -2.02, -2.02, 1.0, 2.02, 2.02, 1.18, cell="vermilion")
    L.cyl(b, 0, 0, 2.1, 0.5, 1.65, n=8, cell="bone", r_top=1.75)
    L.cyl(b, 0, 0, 2.6, 1.6, 1.75, n=8, cell="chalk", r_top=1.35)
    L.cyl(b, 0, 0, 4.2, 0.25, 1.35, n=8, cell="madder", r_top=1.15)
    L.slab(b, -0.85, -0.85, 4.45, 0.85, 0.85, 5.35, cell="bone", inset=(0.0, 0.0))
    L.slab(b, -0.9, -0.9, 5.1, 0.9, 0.9, 5.3, cell="orpiment")
    r = 0.75
    z = 5.35
    for k in range(7):
        L.cyl(b, 0, 0, z, 0.32, r, n=8, cell="bone" if k % 2 == 0 else "chalk", r_top=r * 0.9)
        z += 0.32
        r *= 0.88
    L.cyl(b, 0, 0, z, 0.2, 0.7, n=8, cell="gold", r_top=0.5)
    L.cone_t(b, 0, 0, z + 0.2, z + 0.9, 0.3, n=6, cell="gold")
    L.scale_xyz(b, 0.82, 0.82, 0.82)
    return b


def cairn_parts():
    rng = random.Random(9)
    b = L.new("cairn")
    L.blob(b, (0, 0, 0.55), (2.3, 2.1, 1.1), rng, segs=8, rings=4, cell="rock_grey", jitter=0.2, cut=0.3, cell_top="ash")
    L.blob(b, (0.1, 0, 1.55), (1.6, 1.5, 0.9), rng, segs=7, rings=4, cell="ash", jitter=0.2, cut=0.3, cell_top="bone")
    L.blob(b, (0, 0.1, 2.35), (1.0, 1.0, 0.75), rng, segs=6, rings=3, cell="rock_grey", jitter=0.2, cut=0.3, cell_top="chalk")
    L.shade_down(b, "rock_dark", thresh=-0.3)
    tops = []
    for k in range(5):
        a = k / 5.0 * math.tau + 0.3
        x, y = 0.5 * math.cos(a), 0.5 * math.sin(a)
        zt = 4.2 + (0.7 if k == 0 else rng.uniform(-0.4, 0.2))
        tx, ty = x * 1.6, y * 1.6
        b.tube([(x, y, 1.9), (x + (tx - x) * 0.5, y + (ty - y) * 0.5, 3.0), (tx, ty, zt)], [0.09, 0.07, 0.05], n=4, cell="wood_light")
        tops.append((tx, ty, zt))
    f = L.new("flags")
    hangs = []
    for (tx, ty, zt) in tops[1:]:
        a = math.atan2(ty, tx)
        anchor = (2.4 * math.cos(a), 2.4 * math.sin(a), 0.9)
        L.flag_row(f, hangs, (tx, ty, zt - 0.1), anchor, sag=0.1, w=0.42, h=0.6, gap=0.1)
    return b, f, hangs


def cairn():
    b, f, hangs = cairn_parts()
    L.export("cairn", [("cairn", b), ("flags", f, hangs)])


def flagpole():
    b = L.new("flagpole")
    L.cyl(b, 0, 0, -0.3, 9.9, 0.2, n=6, cell="wood_light", r_top=0.12)
    L.cone_t(b, 0, 0, 9.5, 10.5, 0.18, n=5, cell="gold")
    L.cyl(b, 0, 0, 9.6, 0.15, 0.3, n=6, cell="vermilion", r_top=0.25)
    rng = random.Random(2)
    for k in range(6):
        a = k / 6.0 * math.tau
        L.blob(b, (0.7 * math.cos(a), 0.7 * math.sin(a), 0.2), (0.5, 0.5, 0.4), rng, segs=5, rings=3, cell="rock_grey", cut=0.4, cell_top="ash")
    f = L.new("flags")
    hangs = []
    for sx in (-1, 1):
        top = (0.0, 0.0, 9.3)
        anchor = (sx * 5.5, 0.0, 1.3)
        rope(b, top, anchor)
        # Read left to right the flags always run blue, white, red, green, yellow, so the left string starts at its foot.
        p_a, p_b = (anchor, top) if sx < 0 else (top, anchor)
        L.flag_row(f, hangs, p_a, p_b, sag=0.2, w=0.55, h=0.8, gap=0.1)
    L.export("flagpole", [("flagpole", b), ("flags", f, hangs)])


def flag_string():
    b = L.new("flag_string")
    for x in (-4.6, 4.6):
        L.cyl(b, x, 0, -0.3, 4.7, 0.13, n=5, cell="wood_light", r_top=0.09)
        L.cone_t(b, x, 0, 4.3, 4.8, 0.1, n=4, cell="gold")
    rope(b, (-4.6, 0, 4.2), (4.6, 0, 4.2))
    f = L.new("flags")
    hangs = []
    L.flag_row(f, hangs, (-4.6, 0, 4.2), (4.6, 0, 4.2), sag=0.35, w=0.6, h=0.85, gap=0.1)
    L.export("flag_string", [("flag_string", b), ("flags", f, hangs)])


def scarf():
    b = L.new("scarf")
    pts = [(0, -1.1 + 0.55 * i, 0.04 + 0.035 * math.sin(i * 1.7)) for i in range(5)]
    b.strip(pts, [0.62, 0.7, 0.62, 0.7, 0.62], normal=(0, 0, 1), cell="a1", double=True)
    for y in (-1.15, 1.15):
        L.slab(b, -0.31, y - 0.06, 0.0, 0.31, y + 0.06, 0.08, cell="a2")
    return b


def banner():
    b = L.new("banner")
    L.cyl(b, 0, 0, -0.3, 6.8, 0.14, n=5, cell="wood_dark", r_top=0.1)
    L.slab(b, -1.4, -0.08, 6.3, 1.4, 0.08, 6.5, cell="wood_dark")
    L.cone_t(b, 0, 0, 6.8, 7.4, 0.2, n=5, cell="gold")
    f = L.new("flags_banner")
    hangs = []
    bands = [("orpiment", 0.0), ("vermilion", 1.2), ("chalk", 2.4), ("lapis", 3.0), ("chalk", 3.9), ("vermilion", 4.4), ("orpiment", 5.4)]
    top = 6.25
    heights = [0.3, 1.0, 0.6, 0.9, 0.5, 1.0, 0.3]
    z = top
    for (cell, _), h in zip(bands, heights):
        rows = 2
        idx = []
        for ri in range(rows + 1):
            zz = z - h * ri / rows
            kk = (top - zz) / 4.6
            row = []
            for x in (-1.15, 1.15):
                row.append(f.vert((x, 0.02, zz)))
                hangs.append(kk)
            idx.append(row)
        for ri in range(rows):
            f.face([idx[ri][0], idx[ri][1], idx[ri + 1][1], idx[ri + 1][0]], cell=cell)
        z -= h
    L.export("banner", [("banner", b), ("flags_banner", f, hangs)])


def target_pole():
    b = L.new("target_pole")
    L.cyl(b, 0, 0, -0.3, 3.6, 0.1, n=5, cell="wood_light", r_top=0.07)
    rng = random.Random(6)
    L.blob(b, (0, 0, 2.9), (0.5, 0.5, 0.55), rng, segs=6, rings=3, cell="vermilion", jitter=0.1)
    for k in range(4):
        a = k / 4.0 * math.tau
        x, y = 0.4 * math.cos(a), 0.4 * math.sin(a)
        L.solid(b, [(x - 0.1, y, 2.8), (x + 0.1, y, 2.8), (x, y + 0.1, 2.8), (x * 1.2, y * 1.2, 1.95)], [[0, 1, 3], [1, 2, 3], [2, 0, 3]], "cinnabar", center=(x, y, 2.4))
    L.cone_t(b, 0, 0, 3.3, 3.9, 0.14, n=4, cell="orpiment")
    return b


def ramp():
    rng = random.Random(7)
    b = L.new("ramp")
    w = 3.4
    pts = [(-w, -4.5, -0.3), (w, -4.5, -0.3), (w, 4.5, -0.3), (-w, 4.5, -0.3), (-w, -4.5, 0.02), (w, -4.5, 0.02), (w, 4.5, 1.5), (-w, 4.5, 1.5)]
    faces = [[4, 5, 6, 7], [0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7], [0, 1, 2, 3]]
    L.solid(b, pts, faces, ["tan", "sienna", "sienna", "umber", "sienna", "umber"])
    for sx in (-1, 1):
        for k in range(4):
            y = -3.4 + k * 2.3
            z = 0.2 + (y + 4.5) / 9.0 * 1.5
            L.blob(b, (sx * (w + 0.05), y, z), (0.8, 0.9, 0.55), rng, segs=6, rings=3, cell="rock_grey", jitter=0.18, cut=0.3, cell_top="ash")
    return b


def gate_common(name, post_cell, band_cell, chequer):
    b = L.new(name)
    half = 17.0
    for sx in (-1, 1):
        x = sx * half
        L.cyl(b, x, 0, -0.4, 9.2, 0.55, n=6, cell=post_cell, r_top=0.45)
        L.cyl(b, x, 0, 3.0, 0.4, 0.62, n=6, cell=band_cell, r_top=0.62)
        L.cyl(b, x, 0, 8.7, 0.5, 0.7, n=6, cell="orpiment", r_top=0.85)
        L.cone_t(b, x, 0, 9.3, 10.4, 0.5, n=6, cell="gold")
        for k in range(5):
            a = k / 5.0 * math.tau
            L.blob(b, (x + 1.0 * math.cos(a), 1.0 * math.sin(a), 0.15), (0.6, 0.6, 0.45), random.Random(k), segs=5, rings=3, cell="rock_grey", cut=0.4, cell_top="ash")
    L.slab(b, -half - 0.8, -0.45, 8.0, half + 0.8, 0.45, 9.0, cell="wood_dark", inset=(0.0, 0.05))
    L.slab(b, -half - 0.9, -0.5, 8.9, half + 0.9, 0.5, 9.2, cell=band_cell)
    L.slab(b, -half - 0.8, -0.35, 9.2, half + 0.8, 0.35, 9.5, cell="orpiment")
    return b, half


def start_gate():
    b, half = gate_common("start_gate", "vermilion", "lapis", False)
    f = L.new("flags")
    hangs = []
    L.flag_row(f, hangs, (-half, 0.6, 7.9), (half, 0.6, 7.9), sag=0.9, w=0.8, h=1.1, gap=0.15)
    L.flag_row(f, hangs, (-half, -0.6, 7.9), (half, -0.6, 7.9), sag=0.9, w=0.8, h=1.1, gap=0.15)
    L.export("start_gate", [("start_gate", b), ("flags", f, hangs)])


def finish_gate():
    b, half = gate_common("finish_gate", "lapis", "vermilion", True)
    f = L.new("flags_banner")
    hangs = []
    cols = 36
    cw = (2 * half - 0.8) / cols
    for r in range(3):
        for c in range(cols):
            x0 = -half + 0.4 + c * cw
            z0 = 7.95 - r * 0.75
            cell = "chalk" if (r + c) % 2 == 0 else "ink"
            k = r / 3.0
            idx = [f.vert((x0, 0.0, z0)), f.vert((x0 + cw, 0.0, z0)), f.vert((x0 + cw, 0.0, z0 - 0.75)), f.vert((x0, 0.0, z0 - 0.75))]
            hangs.extend([k, k, k + 1 / 3.0, k + 1 / 3.0])
            f.face(idx, cell=cell)
    L.export("finish_gate", [("finish_gate", b), ("flags_banner", f, hangs)])


def run():
    L.single("mani_wall", mani_wall())
    L.single("chorten", chorten())
    cairn()
    flagpole()
    flag_string()
    L.single("scarf", scarf())
    banner()
    L.single("target_pole", target_pole())
    L.single("ramp", ramp())
    start_gate()
    finish_gate()


run()
