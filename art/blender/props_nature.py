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
    return b


def log():
    b = L.new("log")
    rings = [kit.Ring((0, -2.8, 0.34), 0.3, cell="wood_light"), kit.Ring((0, -2.0, 0.36), 0.34, cell="wood_dark"),
             kit.Ring((0, 0.0, 0.38), 0.37, cell="wood_dark"), kit.Ring((0, 2.0, 0.36), 0.35, cell="wood_dark"),
             kit.Ring((0, 2.8, 0.34), 0.31, cell="wood_dark"), kit.Ring((0, 2.9, 0.34), 0.3, cell="wood_dark")]
    b.loft(rings, n=7, cell="wood_dark", axis=(0, 1, 0))
    b.tube([(0.2, 0.4, 0.6), (0.7, 0.55, 1.0), (1.1, 0.6, 1.4)], [0.12, 0.09, 0.06], n=5, cell="wood_dark")
    L.shade_up(b, "wood_light", thresh=0.75)
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
    """A flat patch of churned mud, 11 m across and 17 m long, lying on the road. Single sided, so it only shows from above."""
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
        cell = "umber" if k % 3 else "wood_dark"
        b.face([centre, outer[(k + 1) % n], outer[k]], cell=cell)
    # Wet sheen: a few smaller lighter splashes on top.
    for (x, y, r) in ((-1.5, 2.0, 1.4), (1.8, -2.5, 1.2), (0.4, -5.0, 1.0), (-1.2, 5.2, 0.9)):
        c = b.vert((x, y, 0.085))
        ps = [b.vert((x + r * math.cos(a), y + r * 1.3 * math.sin(a), 0.08)) for a in (0, 1.57, 3.14, 4.71)]
        for k in range(4):
            b.face([c, ps[(k + 1) % 4], ps[k]], cell="sienna")
    return b


def run():
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
