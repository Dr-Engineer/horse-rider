"""Plants, rocks, logs and field props. Run in Blender background mode (see props_lib)."""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import props_lib as L  # noqa: E402
import kit  # noqa: E402
from mathutils import Vector  # noqa: E402


def spruce():
    b = L.new("spruce")
    L.cyl(b, 0, 0, -0.3, 2.7, 0.4, n=5, cell="wood_dark", r_top=0.25)
    for k in range(5):
        z0 = 1.4 + k * 1.95
        r = 2.9 - k * 0.5
        L.cone_t(b, 0, 0, z0, z0 + 2.9, r, n=7, cell="pine" if k % 2 == 0 else "juniper", rot=0.45 * k)
    return b


def juniper():
    rng = random.Random(4)
    b = L.new("juniper")
    kit_tube = [(0, 0, -0.2), (0.15, 0.1, 0.9), (0.0, 0.0, 1.8)]
    b.tube(kit_tube, [0.32, 0.26, 0.2], n=5, cell="wood_dark")
    for (x, y, z, rx, rz) in [(0, 0, 2.5, 1.7, 1.35), (1.1, 0.5, 1.6, 1.1, 0.9), (-1.0, -0.5, 1.7, 1.0, 0.85), (0.1, -0.2, 3.5, 1.0, 0.9)]:
        L.blob(b, (x, y, z), (rx, rx * 0.95, rz), rng, segs=6, rings=3, cell="juniper", jitter=0.12, cell_top="pine", up_thresh=0.5)
    return b


def bush():
    rng = random.Random(8)
    b = L.new("bush")
    for (x, y, z, rx, rz) in [(0, 0, 0.45, 0.9, 0.6), (0.7, 0.35, 0.3, 0.6, 0.42), (-0.6, -0.3, 0.32, 0.6, 0.4)]:
        L.blob(b, (x, y, z), (rx, rx, rz), rng, segs=6, rings=3, cell="grass_deep", jitter=0.12, cell_top="grass_green", up_thresh=0.45)
    return b


def blade(b, x, y, h, lx, ly, w, cell):
    base = [(x + w, y, 0.0), (x - w * 0.5, y + w * 0.87, 0.0), (x - w * 0.5, y - w * 0.87, 0.0)]
    tip = (x + lx, y + ly, h)
    L.solid(b, base + [tip], [[0, 1, 3], [1, 2, 3], [2, 0, 3]], cell, center=(x, y, h * 0.3))


def grass_tuft():
    rng = random.Random(3)
    b = L.new("grass_tuft")
    cells = ["grass_green", "grass_deep", "grass_gold", "barley", "grass_green", "grass_deep", "grass_gold", "grass_green", "pine"]
    for i in range(9):
        a = i / 9.0 * math.tau + rng.uniform(-0.3, 0.3)
        r = rng.uniform(0.0, 0.2)
        x, y = r * math.cos(a), r * math.sin(a)
        blade(b, x, y, rng.uniform(0.7, 1.25), math.cos(a) * rng.uniform(0.15, 0.4), math.sin(a) * rng.uniform(0.15, 0.4), 0.13, cells[i])
    return b


def rock_cluster(name, seed, mains, extras, side="rock_grey", top="ash", segs=7, rings=4):
    rng = random.Random(seed)
    b = L.new(name)
    for (x, y, z, rx, ry, rz) in mains + extras:
        L.blob(b, (x, y, z), (rx, ry, rz), rng, segs=segs, rings=rings, cell=side, jitter=0.2, cut=0.3, cell_top=top, up_thresh=0.55)
    L.shade_down(b, "rock_dark", thresh=-0.3)
    L.settle(b)
    return b


def rock_a():
    return rock_cluster("rock_a", 11, [(0, 0, 0.55, 1.5, 1.3, 1.0)], [(1.5, 0.7, 0.28, 0.7, 0.6, 0.5), (-1.3, -0.8, 0.24, 0.6, 0.55, 0.42)])


def rock_b():
    return rock_cluster("rock_b", 12, [(0, 0, 0.35, 2.1, 1.5, 0.65)], [(-1.9, 0.9, 0.2, 0.9, 0.7, 0.4), (1.2, -1.2, 0.2, 0.8, 0.6, 0.35)], segs=8)


def rock_c():
    return rock_cluster("rock_c", 13, [(0, 0, 1.2, 0.95, 0.85, 2.0)], [(1.0, 0.5, 0.35, 0.7, 0.6, 0.6), (-0.8, 0.8, 0.4, 0.55, 0.5, 0.8)], segs=6, rings=5)


def boulder():
    rng = random.Random(21)
    b = L.new("boulder")
    L.blob(b, (0, 0, 1.15), (2.0, 1.9, 1.7), rng, segs=8, rings=5, cell="rock_grey", jitter=0.14, cut=0.35, cell_top="ash", up_thresh=0.5)
    L.shade_down(b, "rock_dark", thresh=-0.3)
    L.settle(b)
    return b


def stub(b, base, direction, length, r):
    """A sawn-off branch stub: dark bark, a pale cut face."""
    base = Vector(base)
    d = Vector(direction).normalized()
    pts = [base - d * 0.05, base + d * length * 0.5, base + d * length, base + d * (length + 0.015)]
    rings = [kit.Ring(pts[0], r, cell="wood_dark"), kit.Ring(pts[1], r * 0.9, cell="wood_dark"), kit.Ring(pts[2], r * 0.85, cell="wood_light"), kit.Ring(pts[3], r * 0.85, cell="wood_light")]
    b.loft(rings, n=5, axis=tuple(d), up=(0, 0, 1))


def log():
    """A felled trunk lying along Y, 5.7 m: ridged bark in bands, a little taper, pale sawn ends with annual rings and
    a pith, and a few branch stubs. The model is 1.5 m wide with its stubs and 5.7 m long."""
    rng = random.Random(23)
    b = L.new("log")
    ys = [-2.85, -2.8, -2.45, -1.95, -1.4, -0.8, -0.25, 0.35, 0.95, 1.5, 2.05, 2.5, 2.8, 2.85]
    bark = ["wood_light", "wood_dark", "umber", "wood_dark", "leather", "wood_dark", "umber", "wood_dark", "leather", "wood_dark", "umber", "wood_dark", "wood_light", "wood_light"]
    rings = []
    for i, (y, c) in enumerate(zip(ys, bark)):
        t = (y + 2.85) / 5.7
        r = 0.4 - 0.1 * t                                    # fat at the butt, slimmer at the top
        r *= 1.0 + (0.035 if i % 2 == 0 else -0.02)         # ridged bark: every other ring bulges
        rings.append(kit.Ring((0, y, r * 0.98), r, r * 0.96, cell=c))
    b.loft(rings, n=8, axis=(0, 1, 0), up=(0, 0, 1))
    L.shade_up(b, "wood_light", thresh=0.82)
    # Annual rings and the pith on both sawn ends.
    for y, sgn, r in ((-2.855, -1.0, 0.4), (2.855, 1.0, 0.3)):
        zc = r * 0.98
        b.loft([kit.Ring((0, y, zc), r * 0.7, r * 0.68, cell="wood_dark"), kit.Ring((0, y + sgn * 0.007, zc), r * 0.7, r * 0.68, cell="wood_dark")], n=8, axis=(0, 1, 0), up=(0, 0, 1), cap_start=True, cap_end=True)
        b.loft([kit.Ring((0, y + sgn * 0.01, zc), r * 0.45, r * 0.44, cell="sand"), kit.Ring((0, y + sgn * 0.017, zc), r * 0.45, r * 0.44, cell="sand")], n=8, axis=(0, 1, 0), up=(0, 0, 1), cap_start=True, cap_end=True)
        b.loft([kit.Ring((0, y + sgn * 0.02, zc), r * 0.2, r * 0.2, cell="wood_dark"), kit.Ring((0, y + sgn * 0.027, zc), r * 0.2, r * 0.2, cell="wood_dark")], n=6, axis=(0, 1, 0), up=(0, 0, 1), cap_start=True, cap_end=True)
    # Branch stubs, mostly up and out, one down against the ground side.
    for (y, ang, ln, r) in ((-1.5, 70, 0.55, 0.075), (-0.2, 105, 0.6, 0.085), (0.9, 62, 0.5, 0.07), (1.9, 118, 0.42, 0.06), (-2.1, 150, 0.3, 0.06)):
        a = math.radians(ang)
        d = (math.cos(a), 0.18, math.sin(a))
        zc = 0.37
        stub(b, (math.cos(a) * 0.33, y, zc + math.sin(a) * 0.33), d, ln, r)
    return b


def willow():
    rng = random.Random(31)
    b = L.new("willow")
    b.tube([(0, 0, -0.2), (0.3, 0.1, 1.2), (0.1, -0.1, 2.6), (0.5, 0.2, 3.6)], [0.5, 0.4, 0.33, 0.25], n=6, cell="wood_dark")
    L.blob(b, (0.3, 0.1, 4.6), (3.3, 3.1, 1.7), rng, segs=8, rings=3, cell="grass_green", jitter=0.12, cell_top="grass_gold", up_thresh=0.55)
    for k in range(9):
        a = k / 9.0 * math.tau
        x, y = 0.3 + 3.0 * math.cos(a), 0.1 + 2.8 * math.sin(a)
        zt = 4.3 + rng.uniform(-0.2, 0.2)
        pts = [(x - 0.45, y, zt), (x + 0.45, y, zt), (x, y + 0.4, zt), (x + rng.uniform(-0.2, 0.2), y + rng.uniform(-0.2, 0.2), rng.uniform(1.6, 2.4))]
        L.solid(b, pts, [[0, 1, 3], [1, 2, 3], [2, 0, 3]], "grass_green" if k % 2 else "grass_gold", center=(x, y, zt - 1.0))
    return b


def barley_patch():
    b = L.new("barley_patch")
    L.slab(b, -2.6, -2.6, -0.15, 2.6, 2.6, 0.05, cell="umber")
    cells = ["barley", "grass_gold", "barley", "orpiment", "barley", "grass_gold"]
    for i in range(6):
        y = -2.1 + i * 0.84
        L.slab(b, -2.4, y - 0.36, 0.0, 2.4, y + 0.36, 0.75, cell=cells[i], inset=(0.15, 0.22))
    return b


def drying_rack():
    b = L.new("drying_rack")
    for x in (-2.0, 2.0):
        L.cyl(b, x, 0, -0.2, 3.2, 0.14, n=5, cell="wood_dark")
    L.slab(b, -2.2, -0.12, 2.6, 2.2, 0.12, 2.8, cell="wood_light")
    L.slab(b, -2.2, -0.12, 1.5, 2.2, 0.12, 1.7, cell="wood_light")
    for i in range(7):
        x = -1.7 + i * 0.57
        L.slab(b, x - 0.2, -0.18, 1.7, x + 0.2, 0.18, 2.6, cell="barley" if i % 2 == 0 else "grass_gold", inset=(0.08, 0.08))
        L.slab(b, x - 0.2, -0.18, 0.5, x + 0.2, 0.18, 1.5, cell="grass_gold" if i % 2 == 0 else "barley", inset=(0.08, 0.08))
    return b


def survey_stake():
    b = L.new("survey_stake")
    L.cyl(b, 0, 0, -0.2, 2.5, 0.07, n=4, cell="wood_light", r_top=0.05)
    L.slab(b, -0.05, -0.05, 2.0, 0.55, 0.05, 2.45, cell="vermilion")
    L.slab(b, -0.03, -0.03, 1.5, 0.03, 0.03, 1.55, cell="chalk")
    return b


def mud_patch():
    """A flat patch of churned mud, 11 m across and 17 m long, lying on the road. Single sided, so it only shows from above.
    The game paints its mud with shaders/mud.gdshader instead; this model is no longer used, and is kept in mid browns."""
    rng = random.Random(41)
    b = L.new("mud_patch")
    n = 14
    ring = []
    for k in range(n):
        a = math.tau * k / n
        j = rng.uniform(0.82, 1.0)
        ring.append((5.5 * math.cos(a) * j, 8.5 * math.sin(a) * j))
    centre = b.vert((0, 0, 0.07))
    outer = [b.vert((x, y, 0.045)) for (x, y) in ring]
    for k in range(n):
        cell = "sienna" if k % 3 else "wood_light"
        b.face([centre, outer[(k + 1) % n], outer[k]], cell=cell)
    # Wet sheen: a few smaller lighter splashes on top.
    for (x, y, r) in ((-1.5, 2.0, 1.4), (1.8, -2.5, 1.2), (0.4, -5.0, 1.0), (-1.2, 5.2, 0.9)):
        c = b.vert((x, y, 0.085))
        ps = [b.vert((x + r * math.cos(a), y + r * 1.3 * math.sin(a), 0.08)) for a in (0, 1.57, 3.14, 4.71)]
        for k in range(4):
            b.face([c, ps[(k + 1) % 4], ps[k]], cell="azure")
    return b


def milestone():
    """A road marker of stacked flat stones with a strip of red cloth tied round the middle, 1.3 m tall. No marks on it."""
    rng = random.Random(51)
    b = L.new("milestone")
    z = -0.05
    specs = [(0.62, 0.5, 0.26, "rock_grey"), (0.52, 0.42, 0.22, "ash"), (0.46, 0.4, 0.2, "rock_grey"), (0.36, 0.3, 0.2, "bone"), (0.3, 0.26, 0.18, "ash"), (0.2, 0.18, 0.16, "bone")]
    centres = []
    for (rx, ry, h, cell) in specs:
        ox, oy = rng.uniform(-0.05, 0.05), rng.uniform(-0.05, 0.05)
        L.blob(b, (ox, oy, z + h * 0.55), (rx, ry, h * 0.55), rng, segs=6, rings=3, cell=cell, jitter=0.1, cell_top="chalk", up_thresh=0.5)
        centres.append((ox, oy, z + h * 0.55))
        z += h * 0.82
    cx, cy, cz = centres[3]
    b.loft([kit.Ring((cx, cy, cz - 0.05), 0.4, 0.34, cell="vermilion"), kit.Ring((cx, cy, cz + 0.07), 0.4, 0.34, cell="vermilion")], n=7, axis=(0, 0, 1), cap_start=False, cap_end=False)
    b.strip([(cx + 0.36, cy, cz + 0.02), (cx + 0.5, cy + 0.05, cz - 0.15), (cx + 0.55, cy + 0.08, cz - 0.4)], [0.1, 0.09, 0.06], normal=(0, 1, 0), cell="vermilion", double=True)
    return b


def grass_tall():
    """A clump of tall seeding grass, 1.2 to 1.8 m, in golds and greens. Ground cover: drawn without ink and sways."""
    rng = random.Random(5)
    b = L.new("grass_tall")
    cells = ["grass_gold", "barley", "grass_green", "grass_gold", "grass_deep", "barley", "grass_green", "grass_gold"]
    for i in range(8):
        a = i / 8.0 * math.tau + rng.uniform(-0.3, 0.3)
        r = rng.uniform(0.0, 0.25)
        x, y = r * math.cos(a), r * math.sin(a)
        h = rng.uniform(1.1, 1.8)
        lx, ly = math.cos(a) * rng.uniform(0.25, 0.6), math.sin(a) * rng.uniform(0.25, 0.6)
        blade(b, x, y, h, lx, ly, 0.1, cells[i])
        if i % 2 == 0:
            L.slab(b, x + lx - 0.04, y + ly - 0.04, h - 0.1, x + lx + 0.04, y + ly + 0.04, h + 0.12, cell="orpiment" if i % 4 == 0 else "barley", inset=(0.01, 0.01))
    return b


def flowers():
    """Short grass with a few blue poppies and meadow flowers on thin stems. Ground cover like grass_tuft."""
    rng = random.Random(8)
    b = L.new("flowers")
    for i in range(5):
        a = i / 5.0 * math.tau + rng.uniform(-0.3, 0.3)
        blade(b, 0.12 * math.cos(a), 0.12 * math.sin(a), rng.uniform(0.3, 0.5), math.cos(a) * 0.15, math.sin(a) * 0.15, 0.1, "grass_green" if i % 2 else "grass_deep")
    heads = ["azure", "azure", "rose", "orpiment", "chalk", "azure", "orpiment"]
    for i, cell in enumerate(heads):
        a = i / len(heads) * math.tau + rng.uniform(-0.3, 0.3)
        r = rng.uniform(0.12, 0.42)
        x, y = r * math.cos(a), r * math.sin(a)
        h = rng.uniform(0.3, 0.55)
        L.cone_t(b, x, y, 0.0, h, 0.018, n=3, cell="grass_green")
        L.cone_t(b, x, y, h, h + 0.09, 0.1, n=5, cell=cell, rot=rng.random())
        L.cyl(b, x, y, h + 0.08, 0.035, 0.035, n=4, cell="orpiment" if cell != "orpiment" else "vermilion")
    return b


def dust_plume():
    """A far column of dust drifting off to one side, for the third Season: a stack of pale blobs 100 m tall that widen as
    they rise and lean downwind. Meant to be seen from a kilometre or more away, in the haze."""
    rng = random.Random(61)
    b = L.new("dust_plume")
    cells = ["tan", "khaki", "sand", "tan", "khaki", "sand", "bone"]
    z = 0.0
    x = 0.0
    for k in range(7):
        r = 7.0 + k * 2.8
        h = 22.0 + k * 2.0
        L.blob(b, (x, 0, z + h * 0.5), (r, r * 0.85, h * 0.62), rng, segs=7, rings=3, cell=cells[k], jitter=0.22, cell_top="sand", up_thresh=0.5)
        z += h * 0.78
        x += 4.0 + k * 1.8
    return b


def run():
    L.single("milestone", milestone())
    L.single("grass_tall", grass_tall())
    L.single("flowers", flowers())
    L.single("dust_plume", dust_plume())
    L.single("mud_patch", mud_patch())
    L.single("spruce", spruce())
    L.single("juniper", juniper())
    L.single("bush", bush())
    L.single("grass_tuft", grass_tuft())
    L.single("rock_a", rock_a())
    L.single("rock_b", rock_b())
    L.single("rock_c", rock_c())
    L.single("boulder", boulder())
    L.single("log", log())
    L.single("willow", willow())
    L.single("barley_patch", barley_patch())
    L.single("drying_rack", drying_rack())
    L.single("survey_stake", survey_stake())


run()
