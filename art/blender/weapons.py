"""Weapons: one GLB each in assets/models/weapons/. Grip at the origin, the weapon points along +Y (-Z in Godot).

Everything is about 15% thicker than life so it reads at a gallop. Cells only, no painted tiles.
Quiver: long axis +Y with the opening and arrow ends at +Y, so attach it with a tilt. Shield: face and boss toward +Y.
"""
import importlib
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit  # noqa: E402

importlib.reload(kit)
from kit import Builder, Ring  # noqa: E402


def rod(b, rings, n=6, cell="white", cap_start=True, cap_end=True):
    """Loft along +Y. rings: (y, rx, ry[, cell]). rx is across X, ry across Z."""
    return b.loft([Ring((0, r[0], 0), r[1], r[2], cell=(r[3] if len(r) > 3 else None)) for r in rings], n=n, cell=cell,
                  axis=(0, 1, 0), up=(0, 0, 1), cap_start=cap_start, cap_end=cap_end)


def sword(b):
    # Trefoil pommel with a coral bead.
    for dx, dz in ((0, 0.036), (0.034, -0.02), (-0.034, -0.02)):
        b.sphere((dx, -0.125, dz), 0.03, cell="brass", segs=5, rings=3)
    b.sphere((0, -0.155, 0), 0.026, cell="coral", segs=5, rings=3)
    # Wire-wrapped grip.
    rod(b, [(-0.105, 0.026, 0.026, "leather"), (-0.06, 0.028, 0.028, "brass"), (-0.03, 0.027, 0.027, "leather"),
            (0.0, 0.028, 0.028, "brass"), (0.03, 0.027, 0.027, "leather"), (0.065, 0.028, 0.028)], n=5, cell="leather")
    # Cupped guard.
    rod(b, [(0.062, 0.05, 0.05, "brass"), (0.078, 0.07, 0.07, "gold"), (0.098, 0.05, 0.05, "brass"), (0.106, 0.026, 0.026)], n=8, cell="brass")
    # Straight single-edged blade: thick spine up, a bright edge strip below.
    rod(b, [(0.106, 0.012, 0.038, "steel"), (0.55, 0.012, 0.038, "steel"), (0.88, 0.011, 0.035, "steel"), (0.95, 0.008, 0.02, "steel"),
            (1.0, 0.003, 0.004)], n=6, cell="steel")
    b.box((0, 0.5, -0.04), (0.007, 0.78, 0.008), cell="silver")


def knife(b):
    rod(b, [(-0.11, 0.03, 0.03, "bone"), (-0.07, 0.034, 0.034, "bone"), (0.0, 0.03, 0.03, "bone"), (0.06, 0.034, 0.034, "brass"),
            (0.075, 0.04, 0.04)], n=6, cell="bone")
    b.sphere((0, -0.12, 0), 0.03, cell="brass", segs=5, rings=3)
    rod(b, [(0.075, 0.011, 0.03, "steel"), (0.17, 0.011, 0.034, "steel"), (0.26, 0.008, 0.02, "steel"), (0.31, 0.003, 0.004)], n=6, cell="steel")


def spear(b):
    # 3 m shaft with iron spiral bands (grip a third of the way up), iron head, butt spike, yak tuft and streamers.
    rings = [(-0.95, 0.024, 0.024, "wood_light")]
    for y in (-0.5, 0.15, 0.7, 1.25):
        rings += [(y, 0.024, 0.024, "iron"), (y + 0.07, 0.028, 0.028, "wood_light")]
    rings += [(1.85, 0.024, 0.024, "iron"), (1.95, 0.03, 0.03)]
    rod(b, rings, n=5, cell="wood_light")
    b.cone((0, -0.95, 0), (0, -1.06, 0), 0.026, n=5, cell="iron")
    rod(b, [(1.95, 0.04, 0.04, "iron"), (2.0, 0.036, 0.036, "steel"), (2.1, 0.012, 0.05, "steel"), (2.28, 0.01, 0.036, "steel"), (2.42, 0.002, 0.003)], n=4, cell="steel")
    # Yak-hair tuft under the head and silk streamers.
    rod(b, [(1.9, 0.02, 0.02, "vermilion"), (1.96, 0.075, 0.075, "vermilion"), (2.0, 0.085, 0.085, "cinnabar"), (1.84, 0.045, 0.045)], n=6, cell="vermilion", cap_start=False)
    for i, (cell, dz) in enumerate((("turquoise", 0.0), ("orpiment", 0.04), ("vermilion", -0.04))):
        b.strip([(0.0, 1.9, dz), (0.0, 1.76, dz - 0.07 + i * 0.03), (0.0, 1.6, dz - 0.15 + i * 0.05), (0.0, 1.46, dz - 0.2)], [0.07, 0.07, 0.06, 0.04], normal=(0, 0, 1) if i != 1 else (1, 0, 0), cell=cell)


def roped_spear(b):
    rings = [(-0.5, 0.026, 0.026, "wood_light")]
    for y in (-0.15, 0.3, 0.7):
        rings += [(y, 0.026, 0.026, "iron"), (y + 0.06, 0.03, 0.03, "wood_light")]
    rings += [(0.98, 0.03, 0.03)]
    rod(b, rings, n=5, cell="wood_light")
    b.cone((0, -0.5, 0), (0, -0.58, 0), 0.028, n=5, cell="iron")
    rod(b, [(0.98, 0.04, 0.04, "iron"), (1.02, 0.036, 0.036, "steel"), (1.1, 0.012, 0.05, "steel"), (1.26, 0.01, 0.034, "steel"), (1.38, 0.002, 0.003)], n=4, cell="steel")
    # Coil of rope at the hand and a trailing end.
    pts = [(0.15 * math.cos(2 * math.pi * i / 10), -0.05, 0.15 * math.sin(2 * math.pi * i / 10)) for i in range(11)]
    b.tube(pts, [0.016] * 11, n=4, cell="tan", cap_start=False, cap_end=False)
    b.tube([(0.15, -0.05, 0.0), (0.2, -0.2, -0.05), (0.18, -0.34, -0.14), (0.12, -0.42, -0.26)], [0.016, 0.016, 0.014, 0.012], n=4, cell="tan")
    b.sphere((0.12, -0.42, -0.28), 0.03, cell="vermilion", segs=5, rings=3)


def key(b):
    """A big iron key swung on a long thong: it outreaches the sword."""
    b.tube([(0, -0.05, 0), (0.0, 0.2, 0.02), (0.0, 0.5, 0.0), (0.0, 0.78, 0.0)], [0.02, 0.014, 0.014, 0.014], n=4, cell="leather")
    b.sphere((0, -0.05, 0), 0.03, cell="vermilion", segs=5, rings=3)
    pts = [(0.075 * math.cos(2 * math.pi * i / 8), 0.86, 0.075 * math.sin(2 * math.pi * i / 8)) for i in range(9)]
    b.tube(pts, [0.026] * 9, n=4, cell="iron", cap_start=False, cap_end=False)
    rod(b, [(0.94, 0.03, 0.03, "iron"), (1.2, 0.034, 0.034, "iron"), (1.26, 0.03, 0.03)], n=5, cell="iron")
    b.box((0, 1.2, 0.07), (0.05, 0.08, 0.12), cell="iron")
    b.box((0, 1.12, 0.07), (0.05, 0.05, 0.1), cell="iron")


def whip(b):
    rod(b, [(-0.12, 0.028, 0.028, "wood_dark"), (0.0, 0.03, 0.03, "brass"), (0.12, 0.028, 0.028, "wood_dark"), (0.16, 0.03, 0.03)], n=5, cell="wood_dark")
    b.sphere((0, -0.13, 0), 0.032, cell="vermilion", segs=5, rings=3)
    pts = [(0.0, 0.16 + 0.1 * i, 0.03 * math.sin(i * 0.9)) for i in range(11)]
    cells = ["leather" if i % 2 == 0 else "tan" for i in range(11)]
    rings = [Ring(p, 0.02 - 0.0009 * i, 0.02 - 0.0009 * i, cell=cells[i]) for i, p in enumerate(pts)]
    b.loft(rings, n=4, cell="leather", up=(1, 0, 0))
    b.sphere((0, 1.2, 0.03 * math.sin(10 * 0.9)), 0.04, cell="iron", segs=5, rings=3)


def pencase(b):
    rod(b, [(-0.12, 0.034, 0.034, "iron"), (0.04, 0.036, 0.036, "brass"), (0.045, 0.045, 0.045, "brass"), (0.13, 0.046, 0.046, "gold"), (0.14, 0.03, 0.03)], n=6, cell="iron")
    b.sphere((0, -0.14, 0), 0.03, cell="brass", segs=5, rings=3)
    b.tube([(0, -0.14, 0), (0.0, -0.2, 0.05), (0.0, -0.28, 0.0)], [0.01, 0.01, 0.01], n=3, cell="leather")


def sling(b):
    for sgn in (-1, 1):
        b.strip([(0.0, -0.02, 0.0), (sgn * 0.012, -0.08, 0.0), (sgn * 0.016, -0.15, 0.0)], [0.035, 0.04, 0.02], normal=(1, 0, 0), cell="vermilion")
    b.tube([(0.0, -0.02, 0.02), (0.0, 0.3, 0.02), (0.0, 0.8, 0.012)], [0.012] * 3, n=3, cell="yak_brown")
    b.tube([(0.0, -0.02, -0.02), (0.0, 0.3, -0.02), (0.0, 0.5, -0.012)], [0.012] * 3, n=3, cell="yak_brown")
    b.strip([(0.0, 0.48, 0.0), (0.0, 0.64, 0.0), (0.0, 0.82, 0.0)], [0.012, 0.13, 0.012], normal=(0, 0, 1), cell="yak_black")
    b.sphere((0, 0.64, 0), 0.05, cell="rock_grey", segs=6, rings=3)


def bow(b):
    """Limbs along Z, belly toward the archer (-Y), string tight between the tips."""
    pts, radii = [], []
    for i in range(9):
        z = -0.64 + 0.16 * i
        pts.append((0.0, -0.13 * (z / 0.64) ** 2, z))
        radii.append(0.036 - 0.018 * abs(z) / 0.64 if abs(z) > 0.1 else 0.036)
    b.tube(pts, radii, n=5, cell="wood_light", up=(1, 0, 0))
    rod(b, [(-0.05, 0.04, 0.09, "leather"), (0.05, 0.04, 0.09)], n=6, cell="leather")
    for sg in (1, -1):
        b.sphere((0, -0.13, sg * 0.64), 0.03, cell="bone", segs=5, rings=3)
    b.tube([(0, -0.13, -0.64), (0, -0.13, 0.0), (0, -0.13, 0.64)], [0.006] * 3, n=3, cell="chalk")
    b.box((0, -0.13, 0.0), (0.02, 0.02, 0.05), cell="orpiment")


def arrow(b):
    rod(b, [(-0.46, 0.01, 0.01, "bone"), (-0.44, 0.014, 0.014, "wood_light"), (0.4, 0.014, 0.014, "wood_light"), (0.42, 0.02, 0.02)], n=4, cell="wood_light")
    rod(b, [(0.42, 0.024, 0.024, "iron"), (0.46, 0.022, 0.022, "steel"), (0.5, 0.005, 0.045, "steel"), (0.57, 0.002, 0.003)], n=4, cell="steel")
    for k, cell in enumerate(("conch", "vermilion", "conch")):
        a = 2 * math.pi * k / 3
        b.strip([(0.0, -0.44, 0.0), (math.cos(a) * 0.04, -0.4, math.sin(a) * 0.04), (math.cos(a) * 0.04, -0.3, math.sin(a) * 0.04), (0.0, -0.26, 0.0)],
                [0.02, 0.03, 0.03, 0.02], normal=(math.sin(a), 0, -math.cos(a)), cell=cell)


def quiver(b):
    rod(b, [(-0.32, 0.05, 0.05, "leather"), (-0.2, 0.075, 0.075, "leather"), (0.1, 0.085, 0.085, "leather"), (0.2, 0.088, 0.088, "brass"), (0.215, 0.07, 0.07)], n=8, cell="leather", cap_end=True)
    rod(b, [(-0.05, 0.088, 0.088, "vermilion"), (0.0, 0.09, 0.09)], n=8, cell="vermilion", cap_start=False, cap_end=False)
    for k, (dx, dz) in enumerate(((0.0, 0.0), (0.04, 0.02), (-0.04, 0.025), (0.02, -0.04), (-0.025, -0.035))):
        b.cone((dx, 0.21, dz), (dx * 1.5, 0.5 + 0.03 * (k % 3), dz * 1.5), 0.012, n=4, cell="wood_light")
        b.box((dx * 1.5, 0.52 + 0.03 * (k % 3), dz * 1.5), (0.045, 0.1, 0.012), cell=("conch", "vermilion", "conch", "turquoise", "orpiment")[k])
    b.strip([(0.0, -0.1, 0.085), (0.1, -0.1, 0.2), (0.2, -0.1, 0.1)], [0.04] * 3, normal=(0, 1, 0), cell="leather")


def shield(b):
    """Round woven cane shield, boss and face toward +Y, handle behind the boss at the grip."""
    start = len(b.faces)
    n = 12
    rod(b, [(-0.03, 0.2, 0.2, "wood_dark"), (-0.02, 0.4, 0.4, "leather"), (0.01, 0.41, 0.41, "leather"), (0.025, 0.37, 0.37, "tan"),
            (0.05, 0.16, 0.16, "tan"), (0.075, 0.1, 0.1, "brass"), (0.1, 0.085, 0.085, "brass"), (0.125, 0.03, 0.03)], n=n, cell="tan")
    # Alternate cane colours around the woven face for a basket look.
    for ring in (3, 4):
        for k in range(n):
            fi = start + ring * n + k
            if fi < len(b.faces):
                b.loop_uvs[fi] = [kit.cell_uv("khaki" if k % 2 else "tan")] * len(b.faces[fi])
    b.box((0, -0.045, 0.0), (0.05, 0.03, 0.26), cell="iron")
    b.box((0, -0.045, 0.0), (0.26, 0.03, 0.05), cell="wood_dark")


WEAPONS = [("sword", sword), ("knife", knife), ("spear", spear), ("roped_spear", roped_spear), ("key", key), ("whip", whip),
           ("pencase", pencase), ("sling", sling), ("bow", bow), ("arrow", arrow), ("quiver", quiver), ("shield", shield)]


def main():
    for name, fn in WEAPONS:
        kit.clear_scene()
        b = Builder("weapon_" + name)
        fn(b)
        obj = b.to_object()
        print(name, b.tri_count())
        kit.export_glb("weapons/" + name, [obj], animations=False)


if __name__ == "__main__":
    main()
