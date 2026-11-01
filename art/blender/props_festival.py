"""Festival crowds, tents and booths. People face +Y (toward the road when placed beside it)."""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import props_lib as L  # noqa: E402
import kit  # noqa: E402

ROBES = ["a1", "madder", "lapis", "malachite_dark", "saffron", "b1", "plum", "ochre", "a2", "cinnabar", "indigo"]
SKINS = ["skin", "skin_light", "skin_deep", "blush"]


def person(b, x, y, face_deg, rng, arms="down", scale=1.0, hat=None):
    start = len(b.co)
    s = scale
    robe = rng.choice(ROBES)
    skin = rng.choice(SKINS)
    L.cyl(b, x, y, 0.0, 1.1 * s, 0.3 * s, n=6, cell=robe, r_top=0.21 * s)
    L.cyl(b, x, y, 0.62 * s, 0.1 * s, 0.26 * s, n=6, cell=rng.choice(["vermilion", "orpiment", "b1", "chalk"]), r_top=0.25 * s)
    L.cyl(b, x, y, 1.1 * s, 0.27 * s, 0.14 * s, n=5, cell=skin, r_top=0.15 * s)
    hat = hat or rng.choice(["hair", "hair", "felt", "fox", "band", "hair"])
    if hat == "hair":
        L.cyl(b, x, y, 1.33 * s, 0.1 * s, 0.16 * s, n=5, cell="hair_black", r_top=0.14 * s)
    elif hat == "felt":
        L.cone_t(b, x, y, 1.33 * s, 1.52 * s, 0.34 * s, n=6, cell="felt_white", r_top=0.15 * s)
    elif hat == "fox":
        L.cyl(b, x, y, 1.33 * s, 0.17 * s, 0.22 * s, n=6, cell="fox_fur", r_top=0.2 * s)
    else:
        L.cyl(b, x, y, 1.32 * s, 0.1 * s, 0.17 * s, n=5, cell=rng.choice(["vermilion", "coral", "orpiment"]), r_top=0.16 * s)
    for sx in (-1, 1):
        sh = (x + sx * 0.25 * s, y, 0.98 * s)
        if arms == "up":
            b.tube([sh, (sh[0] + sx * 0.15 * s, y + 0.02, sh[2] + 0.3 * s), (sh[0] + sx * 0.22 * s, y + 0.04, sh[2] + 0.6 * s)], [0.07 * s, 0.06 * s, 0.05 * s], n=4, cell=robe)
            L.cyl(b, sh[0] + sx * 0.22 * s, y + 0.04, sh[2] + 0.58 * s, 0.1 * s, 0.06 * s, n=4, cell=skin)
        elif arms == "clap":
            b.tube([sh, (sh[0] * 0.5 + x * 0.5, y + 0.2 * s, sh[2] - 0.15 * s), (x + sx * 0.05 * s, y + 0.3 * s, sh[2] + 0.05 * s)], [0.07 * s, 0.06 * s, 0.05 * s], n=4, cell=robe)
        else:
            b.tube([sh, (sh[0] + sx * 0.05 * s, y, sh[2] - 0.3 * s), (sh[0] + sx * 0.04 * s, y + 0.05, sh[2] - 0.5 * s)], [0.07 * s, 0.07 * s, 0.06 * s], n=4, cell=robe)
    if face_deg:
        L.rot_z(b, face_deg, start=start, end=len(b.co), pivot=(x, y))


def crowd(name, seed, spots):
    rng = random.Random(seed)
    b = L.new(name)
    for (x, y, face, arms, scale) in spots:
        person(b, x, y, face, rng, arms, scale)
    return b


def crowd_a():
    return crowd("crowd_a", 1, [(-3.0, 0.2, 10, "up", 1.0), (-1.8, -0.6, -8, "down", 1.0), (-0.7, 0.4, 0, "clap", 0.95), (0.4, -0.3, 6, "up", 1.04),
                                 (1.4, 0.5, -10, "down", 0.66), (2.4, -0.2, 0, "up", 1.0), (3.4, 0.4, -12, "down", 0.98)])


def crowd_b():
    return crowd("crowd_b", 2, [(-2.6, 0.0, 8, "down", 0.95), (-1.4, 0.5, 0, "clap", 1.02), (-0.2, -0.3, -6, "up", 1.0), (1.0, 0.3, 10, "down", 0.7),
                                 (2.0, -0.2, 0, "up", 1.05), (3.0, 0.4, -8, "clap", 0.98)])


def crowd_c():
    return crowd("crowd_c", 3, [(-3.4, 0.2, 0, "up", 1.0), (-2.4, -0.5, 10, "down", 0.98), (-1.4, 0.3, -6, "clap", 1.0), (-0.4, -0.4, 0, "up", 0.68),
                                 (0.6, 0.2, 8, "down", 1.04), (1.6, -0.5, -4, "up", 1.0), (2.6, 0.3, 6, "clap", 0.97), (3.6, -0.2, -10, "down", 1.0)])


def tri_double(b, p0, p1, p2, cell):
    # The back face gets its own vertices so Blender keeps both faces.
    b.face([b.vert(p0), b.vert(p1), b.vert(p2)], cell=cell)
    b.face([b.vert(p2), b.vert(p1), b.vert(p0)], cell=cell)


def festival_tent():
    b = L.new("festival_tent")
    hx, hy, ze, zr = 4.0, 3.2, 2.1, 4.2
    # Walls and roof, white with blue trim.
    L.slab(b, -hx, -hy, 0.0, hx, hy, ze, cell="chalk")
    pts = [(-hx - 0.3, -hy - 0.3, ze), (hx + 0.3, -hy - 0.3, ze), (hx + 0.3, hy + 0.3, ze), (-hx - 0.3, hy + 0.3, ze), (0, -hy - 0.3, zr), (0, hy + 0.3, zr)]
    L.solid(b, pts, [[0, 1, 4], [3, 2, 5], [0, 4, 5, 3], [1, 2, 5, 4], [0, 1, 2, 3]], ["lapis", "lapis", "chalk", "chalk", "bone"], center=(0, 0, ze + 0.5))
    # Stepped blue band on the eaves and a scalloped valance, safe cloth motifs.
    for sx in (-1, 1):
        L.slab(b, sx * (hx + 0.3) - 0.05, -hy - 0.3, ze - 0.02, sx * (hx + 0.3) + 0.05, hy + 0.3, ze + 0.28, cell="lapis")
        n = 10
        for i in range(n):
            y0 = -hy - 0.3 + i * (2 * hy + 0.6) / n
            y1 = y0 + (2 * hy + 0.6) / n
            tri_double(b, (sx * (hx + 0.3), y0, ze), (sx * (hx + 0.3), y1, ze), (sx * (hx + 0.3), (y0 + y1) / 2, ze - 0.55), "azure" if i % 2 else "lapis")
    for sy in (-1, 1):
        L.slab(b, -hx - 0.3, sy * (hy + 0.3) - 0.04, 0.0, hx + 0.3, sy * (hy + 0.3) + 0.04, ze, cell="chalk") if sy < 0 else None
    # Open front: dark inside showing through, with two poles.
    L.slab(b, -hx + 0.4, hy - 0.05, 0.0, hx - 0.4, hy + 0.12, ze - 0.1, cell="soot")
    for sx in (-1, 1):
        L.cyl(b, sx * (hx - 0.4), hy + 0.35, 0.0, ze + 0.5, 0.09, n=4, cell="wood_light")
    L.cyl(b, 0, hy + 0.3, 0.0, zr + 0.4, 0.07, n=4, cell="wood_light")
    L.cone_t(b, 0, 0, zr, zr + 0.6, 0.12, n=5, cell="gold")
    for (x, y) in ((-hx - 1.6, -hy - 1.4), (hx + 1.6, -hy - 1.4), (-hx - 1.6, hy + 1.4), (hx + 1.6, hy + 1.4)):
        L.rope(b, (x * 0.7, y * 0.7, ze), (x, y, 0.1))
    return b


def food_booth():
    b = L.new("food_booth")
    # Posts, counter, striped awning, and goods, with no lettering.
    for sx in (-1, 1):
        for sy in (-1, 1):
            L.cyl(b, sx * 1.6, sy * 0.9, -0.1, 2.9 if sy > 0 else 3.5, 0.09, n=4, cell="wood_dark")
    L.slab(b, -1.7, 0.5, 0.0, 1.7, 1.1, 1.0, cell="wood_light", inset=(0.0, 0.0))
    L.slab(b, -1.75, 0.45, 1.0, 1.75, 1.15, 1.1, cell="wood_dark")
    for i in range(8):
        cell = "vermilion" if i % 2 == 0 else "chalk"
        x0 = -1.9 + i * 0.475
        pts = [(x0, -1.1, 3.4), (x0 + 0.475, -1.1, 3.4), (x0 + 0.475, 1.4, 2.7), (x0, 1.4, 2.7)]
        b.face([b.vert(p) for p in pts], cell=cell)
        b.face([b.vert(p) for p in reversed(pts)], cell=cell)
    L.slab(b, -1.8, -1.0, 0.0, 1.8, -0.9, 3.2, cell="soot")
    for i in range(5):
        L.cyl(b, -1.2 + i * 0.6, 0.8, 1.1, 0.25, 0.17, n=6, cell=["bone", "orpiment", "malachite", "rose", "chalk"][i], r_top=0.14)
    L.cyl(b, 1.2, 0.8, 1.1, 0.4, 0.25, n=7, cell="iron", r_top=0.2)
    L.slab(b, -0.9, 0.62, 1.1, -0.1, 0.98, 1.4, cell="umber")
    L.slab(b, -0.85, 0.65, 1.4, -0.15, 0.95, 1.6, cell="sienna")
    return b


def run():
    L.single("crowd_a", crowd_a())
    L.single("crowd_b", crowd_b())
    L.single("crowd_c", crowd_c())
    L.single("festival_tent", festival_tent())
    L.single("food_booth", food_booth())


run()
