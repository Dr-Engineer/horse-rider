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
    L.settle(b)
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


def smooth(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3.0 - 2.0 * t)


def scarf():
    """A silk festival scarf draped on the ground: a meandering ribbon with folds, a darker woven edge, a pinched end,
    one end lifted as if caught by the wind, and a short fringe. Slot A colours it (a1 light, a2 shade, a3 edge)."""
    b = L.new("scarf")
    nlen, nwid = 18, 5
    length, width = 2.3, 0.74
    grid = []
    for i in range(nlen + 1):
        t = i / nlen
        y = -length * 0.5 + t * length
        cx = 0.1 * math.sin(t * 5.2 + 0.4) + 0.04 * math.sin(t * 12.0 + 1.0)
        pinch = 1.0 - 0.4 * smooth((t - 0.76) / 0.24) - 0.2 * smooth((0.14 - t) / 0.14)
        row = []
        for j in range(nwid + 1):
            u = j / nwid * 2.0 - 1.0
            x = cx + u * width * 0.5 * pinch
            fold = 0.06 * math.sin(t * 12.0 + 0.9 + u * 0.9)
            lift = 0.46 * smooth((t - 0.78) / 0.22) ** 1.3 + 0.2 * smooth((0.12 - t) / 0.12) ** 1.2
            z = 0.05 + fold + 0.035 * u * u + lift + 0.02 * math.sin(u * 2.4 + t * 6.0)
            row.append((x, y, z))
        grid.append(row)

    def quad_both(p, cell):
        # Both sides get their own vertices, so Blender keeps the two faces.
        b.face([b.vert(q) for q in p], cell=cell)
        b.face([b.vert(q) for q in reversed(p)], cell=cell)

    for i in range(nlen):
        for j in range(nwid):
            p = [grid[i][j], grid[i][j + 1], grid[i + 1][j + 1], grid[i + 1][j]]
            # a painted sheen: faces tilted away from the viewer's end sit in a deeper tone, the rest are light
            dz = (p[2][2] + p[3][2]) - (p[0][2] + p[1][2])
            cell = "a1" if dz > -0.05 else "a2"
            if j in (0, nwid - 1):
                cell = "a2" if cell == "a1" else "a3"
            quad_both(p, cell)
    # Fringe at both ends, short tassels in the edge colour.
    for end, sgn in ((0, -1.0), (nlen, 1.0)):
        row = grid[end]
        for j in range(nwid * 2):
            u0 = j / (nwid * 2.0)
            xa = row[0][0] + (row[-1][0] - row[0][0]) * u0
            xb = row[0][0] + (row[-1][0] - row[0][0]) * (u0 + 0.5 / (nwid * 2.0))
            za = row[0][2] + (row[-1][2] - row[0][2]) * u0
            ya = row[0][1]
            drop = 0.05 if end == 0 else 0.16
            quad_both([(xa, ya, za), (xb, ya, za), (xb + 0.01, ya + sgn * 0.12, za - drop), (xa - 0.01, ya + sgn * 0.12, za - drop)], "a2")
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


BULL_Z = 2.4      # scripts/race/roadside.gd scores shots with these sizes
BULL_RINGS = ((1.05, "chalk"), (0.7, "vermilion"), (0.35, "orpiment"))


def bullseye():
    """A festival archery target: a round board on a wooden stand, painted in three rings with no marks of any kind, and a
    small red pennant on top. +Y faces the archer."""
    b = L.new("bullseye")
    # The board: a dark wooden back and rim, each ring standing a little proud of the last.
    b.loft([kit.Ring((0, -0.14, BULL_Z), 1.14), kit.Ring((0, 0.0, BULL_Z), 1.14)], n=18, cell="wood_dark", axis=(0, 1, 0), up=(0, 0, 1))
    for i, (r, cell) in enumerate(BULL_RINGS):
        y = 0.03 + i * 0.03
        b.loft([kit.Ring((0, y - 0.04, BULL_Z), r), kit.Ring((0, y, BULL_Z), r)], n=18, cell=cell, axis=(0, 1, 0), up=(0, 0, 1))
    # Two legs splayed behind the board so nothing crosses the rings, a back prop, a crossbar.
    for sx in (-1, 1):
        b.tube([(sx * 0.95, -0.2, -0.2), (sx * 0.12, -0.2, BULL_Z + 1.28)], [0.07, 0.05], n=5, cell="wood_light")
    b.tube([(0, -1.2, -0.2), (0, -0.28, BULL_Z + 0.8)], [0.06, 0.045], n=5, cell="wood_light")
    b.tube([(-0.72, -0.22, 0.95), (0.72, -0.22, 0.95)], [0.05, 0.05], n=4, cell="wood_dark")
    # A short pole and pennant, so it reads from far down the road.
    L.cyl(b, 0, -0.2, BULL_Z + 1.2, 0.8, 0.035, n=4, cell="wood_light")
    zt, zb, zm = BULL_Z + 2.0, BULL_Z + 1.62, BULL_Z + 1.81
    L.solid(b, [(0.02, -0.22, zt), (0.02, -0.22, zb), (0.6, -0.22, zm), (0.02, -0.18, zt), (0.02, -0.18, zb), (0.6, -0.18, zm)],
            [[0, 1, 2], [3, 5, 4], [0, 3, 4, 1], [1, 4, 5, 2], [2, 5, 3, 0]], "vermilion")
    return b


RAMP_W = 3.4
RAMP_Y0, RAMP_Y1 = -4.5, 4.5
RAMP_Z0, RAMP_Z1 = 0.02, 1.5


def ramp_z(y):
    """Height of the ramp's mean surface at y: rises from the road at the back to 1.5 m at the lip."""
    return RAMP_Z0 + (y - RAMP_Y0) / (RAMP_Y1 - RAMP_Y0) * (RAMP_Z1 - RAMP_Z0)


def ramp_course(b, ya, yb, riser, cell_top, cell_riser):
    """One course of rammed earth. The top follows the slope; the next course stands `riser` higher where it starts."""
    w = RAMP_W
    za, zb = ramp_z(ya), ramp_z(yb) - riser
    pts = [(-w, ya, -0.3), (w, ya, -0.3), (w, yb, -0.3), (-w, yb, -0.3), (-w, ya, za), (w, ya, za), (w, yb, zb), (-w, yb, zb)]
    faces = [[4, 5, 6, 7], [0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7], [0, 1, 2, 3]]
    L.solid(b, pts, faces, [cell_top, cell_riser, "sienna", cell_riser, "sienna", "umber"])


def ramp():
    """A mud-and-rock jump: six rammed-earth courses climbing 1.5 m, a dry-stone kerb down each side, a log across the
    lip held by stakes, and a small red cloth pennant on a pole at each end. 8.4 wide x 9 long, lip 1.5 m."""
    rng = random.Random(7)
    b = L.new("ramp")
    w = RAMP_W
    edges = [RAMP_Y0 + k * (RAMP_Y1 - RAMP_Y0) / 6.0 for k in range(7)]
    tops = ["tan", "sienna", "tan", "sienna", "tan", "sienna"]
    for k in range(6):
        ramp_course(b, edges[k], edges[k + 1], 0.09 if k < 5 else 0.0, tops[k], "umber" if k % 2 == 0 else "sienna")
    first_courses = len(b.faces)
    # A few loose stones on the surface and the dark band where the hooves have thrown the mud up.
    for (x, y) in ((-1.9, -2.6), (1.5, -0.9), (-1.2, 2.3)):
        L.blob(b, (x, y, ramp_z(y) + 0.02), (0.24, 0.28, 0.15), rng, segs=5, rings=3, cell="rock_grey", jitter=0.18, cut=0.35, cell_top="ash")
    # Dry-stone kerb: a lower course of big stones bedded against each flank and a lighter row of capstones above.
    for sx in (-1, 1):
        for k in range(6):
            y = -3.75 + k * 1.5 + rng.uniform(-0.12, 0.12)
            zs = ramp_z(y)
            L.blob(b, (sx * (w + 0.36), y, 0.1 + zs * 0.5), (0.68, 0.84, 0.52 + zs * 0.3), rng, segs=6, rings=3, cell="rock_grey", jitter=0.2, cut=0.3, cell_top="ash")
        for k in range(5):
            y = -3.3 + k * 1.75 + rng.uniform(-0.1, 0.1)
            zs = ramp_z(y)
            L.blob(b, (sx * (w + 0.05), y, zs + 0.12), (0.5, 0.72, 0.38), rng, segs=5, rings=3, cell="ash", jitter=0.18, cut=0.3, cell_top="chalk")
    L.shade_down(b, "rock_dark", thresh=-0.35, start=first_courses)
    # The log across the lip, its cut ends proud of the stones, and the stakes behind it that hold it.
    zl = RAMP_Z1 + 0.14
    yl = RAMP_Y1 - 0.4
    xs = [-3.78, -3.74, -2.4, -0.9, 0.6, 2.1, 3.74, 3.78]
    rs = [0.3, 0.3, 0.31, 0.29, 0.31, 0.3, 0.3, 0.3]
    cl = ["wood_light", "wood_dark", "umber", "wood_dark", "leather", "wood_dark", "wood_light", "wood_light"]
    b.loft([kit.Ring((x, yl, zl), r, cell=c) for x, r, c in zip(xs, rs, cl)], n=7, axis=(1, 0, 0))
    for sx in (-1, 1):
        # annual rings on the cut ends
        b.loft([kit.Ring((sx * 3.8, yl, zl), 0.2, cell="wood_dark"), kit.Ring((sx * 3.806, yl, zl), 0.2, cell="wood_dark")], n=7, axis=(1, 0, 0), cap_start=True, cap_end=True)
    for x in (-2.7, 0.0, 2.7):
        L.cyl(b, x, yl - 0.55, ramp_z(yl - 0.55) - 0.2, 1.0, 0.07, n=4, cell="wood_dark", r_top=0.06)
        L.cone_t(b, x, yl - 0.55, ramp_z(yl - 0.55) + 0.8, ramp_z(yl - 0.55) + 0.9, 0.06, n=4, cell="wood_light")
    # Marker poles with a small red cloth pennant each, outside the kerb so they never stand in the line.
    f = L.new("flags")
    hangs = []
    for sx in (-1, 1):
        px, py = sx * 3.95, 3.3
        zb = ramp_z(py) * 0.55
        L.cyl(b, px, py, zb, 3.1 - zb, 0.07, n=5, cell="wood_light", r_top=0.045)
        L.cone_t(b, px, py, 3.08, 3.3, 0.06, n=4, cell="vermilion")
        cols, top, h, wl = 3, 3.0, 0.5, 0.85
        grid = []
        for ri in range(2):
            row = []
            for ci in range(cols + 1):
                t = ci / cols
                row.append(f.vert((px - sx * (0.05 + wl * t), py, top - h * ri * (1.0 - 0.45 * t))))
                hangs.append(t)
            grid.append(row)
        for ci in range(cols):
            f.face([grid[0][ci], grid[0][ci + 1], grid[1][ci + 1], grid[1][ci]] if sx < 0 else [grid[1][ci], grid[1][ci + 1], grid[0][ci + 1], grid[0][ci]], cell="vermilion" if ci % 2 == 0 else "cinnabar")
    return b, f, hangs


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
    L.single("bullseye", bullseye())
    rb, rf, rh = ramp()
    L.export("ramp", [("ramp", rb), ("flags", rf, rh)])
    start_gate()
    finish_gate()


run()
