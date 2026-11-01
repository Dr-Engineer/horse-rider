"""Houses, the cantilever bridge and the parked truck. Fronts face +Y, plinths run below the origin."""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import props_lib as L  # noqa: E402
import kit  # noqa: E402

rope = L.rope


def window(b, x, z, y_plane, w=0.95, h=1.25, d=0.12, frame="ink", pane="soot", sill=True):
    L.slab(b, x - w / 2, y_plane - 0.06, z, x + w / 2, y_plane + d, z + h, cell=frame, inset=(0.07, 0.0))
    L.slab(b, x - w / 2 + 0.14, y_plane + d - 0.02, z + 0.14, x + w / 2 - 0.14, y_plane + d + 0.02, z + h - 0.14, cell=pane, inset=(0.05, 0.0))
    if sill:
        L.slab(b, x - w / 2 - 0.14, y_plane - 0.06, z - 0.11, x + w / 2 + 0.14, y_plane + d + 0.07, z + 0.04, cell=frame)


def plane_y(half_d, z, z0, z1, inset):
    return half_d - inset * (z - z0) / (z1 - z0)


def facade_windows(b, half_w, half_d, z0, z1, inset, rows, cols_front, cols_side, w=0.95, h=1.25, frame="ink"):
    """Windows on all four walls of a battered box. rows is a list of z heights."""
    for angle, (half_across, half_depth, cols) in ((0, (half_w, half_d, cols_front)), (90, (half_d, half_w, cols_side)),
                                                    (180, (half_w, half_d, cols_front)), (-90, (half_d, half_w, cols_side))):
        start = len(b.co)
        spacing = (2.0 * half_across - 2.0) / max(cols, 1)
        for z in rows:
            py = plane_y(half_depth, z, z0, z1, inset)
            for c in range(cols):
                x = (c - (cols - 1) / 2.0) * spacing
                if angle == 0 and abs(x) < 0.01 and z < z0 + 2.0:
                    continue
                window(b, x, z, py, w, h, frame=frame)
        if angle != 0:
            L.rot_z(b, angle, start=start, end=len(b.co))


def house_white():
    b = L.new("house_white")
    W, D = 4.6, 4.0
    z0, z1, ins = 0.9, 7.2, 0.28
    L.slab(b, -W - 0.2, -D - 0.2, -1.8, W + 0.2, D + 0.2, z0, cell="bone")
    L.slab(b, -W, -D, z0, W, D, z1, cell="chalk", inset=(ins, ins))
    # Dark red frieze under the roofline, a hair proud of the wall.
    fz0, fz1 = 5.75, 6.55
    L.slab(b, -W + ins * (fz0 - z0) / (z1 - z0) - 0.07, -D + ins * (fz0 - z0) / (z1 - z0) - 0.07, fz0, W - ins * (fz0 - z0) / (z1 - z0) + 0.07, D - ins * (fz0 - z0) / (z1 - z0) + 0.07, fz1, cell="pema")
    L.slab(b, -W + ins - 0.12, -D + ins - 0.12, z1, W - ins + 0.12, D - ins + 0.12, z1 + 0.75, cell="chalk", inset=(0.08, 0.08), top_cell="slate")
    L.slab(b, -W + ins - 0.14, -D + ins - 0.14, z1 + 0.62, W - ins + 0.14, D - ins + 0.14, z1 + 0.82, cell="ink")
    # Door and windows.
    py = plane_y(D, 1.0, z0, z1, ins)
    L.slab(b, -0.55, py - 0.06, z0, 0.55, py + 0.12, z0 + 2.0, cell="ink", inset=(0.08, 0.0))
    L.slab(b, -0.75, py - 0.06, z0 + 2.0, 0.75, py + 0.14, z0 + 2.18, cell="wood_dark")
    facade_windows(b, W, D, z0, z1, ins, [2.5, 4.4], 3, 2)
    # A roof flagpole with a gold tip, nothing written on it.
    L.cyl(b, W - 1.0, D - 1.0, z1 + 0.7, 2.4, 0.06, n=4, cell="wood_light")
    L.cone_t(b, W - 1.0, D - 1.0, z1 + 3.0, z1 + 3.4, 0.09, n=4, cell="gold")
    return b


def house_tsang():
    rng = random.Random(14)
    b = L.new("house_tsang")
    W, D = 4.4, 3.9
    z0, z1, ins = 0.8, 6.9, 0.25
    L.slab(b, -W - 0.2, -D - 0.2, -1.8, W + 0.2, D + 0.2, z0, cell="slate")
    start = len(b.faces)
    L.slab(b, -W, -D, z0, W, D, 4.4, cell="rock_grey", inset=(ins * 0.7, ins * 0.7))
    L.checker(b, ["rock_grey", "ash", "slate", "rock_grey"], start=start, seed=3)
    # Upper floor with white and red vertical stripes.
    ub = 4.4
    iw = ins * 0.7
    L.slab(b, -W + iw, -D + iw, ub, W - iw, D - iw, z1, cell="chalk", inset=(ins * 0.5, ins * 0.5))
    for angle, (half_a, half_d) in ((0, (W, D)), (90, (D, W)), (180, (W, D)), (-90, (D, W))):
        s0 = len(b.co)
        n = 7 if half_a == W else 6
        for i in range(n):
            if i % 2 == 0:
                continue
            x0 = -half_a + 0.6 + i * (2 * half_a - 1.2) / n
            x1 = x0 + (2 * half_a - 1.2) / n
            py = half_d - iw - 0.12
            L.slab(b, x0, py - 0.05, ub + 0.1, x1, py + 0.08, z1 - 0.1, cell="madder")
        if angle:
            L.rot_z(b, angle, start=s0, end=len(b.co))
    L.slab(b, -W + 0.1, -D + 0.1, z1, W - 0.1, D - 0.1, z1 + 0.7, cell="madder", inset=(0.08, 0.08), top_cell="slate")
    py = plane_y(D, 1.0, z0, 4.4, ins * 0.7)
    L.slab(b, -0.55, py - 0.06, z0, 0.55, py + 0.12, z0 + 1.9, cell="ink", inset=(0.08, 0.0))
    for z in (1.9, 3.1):
        for x in (-2.4, 0.0, 2.4):
            if z < 2.0 and abs(x) < 0.1:
                continue
            window(b, x, z, plane_y(D, z, z0, 4.4, ins * 0.7), 0.8, 1.0)
    for x in (-2.6, 0.0, 2.6):
        window(b, x, 4.9, D - iw - ins * 0.5 * 0.4 + 0.08, 0.8, 1.0)
    L.slab(b, -1.0, -D - 0.1, z1 + 0.7, 1.0, -D + 0.8, z1 + 1.6, cell="slate")
    return b


def house_kham():
    rng = random.Random(15)
    b = L.new("house_kham")
    W, D = 4.8, 4.3
    # Stone ground floor.
    start = len(b.faces)
    L.slab(b, -W - 0.2, -D - 0.2, -2.0, W + 0.2, D + 0.2, 0.0, cell="rock_grey")
    L.slab(b, -W, -D, 0.0, W, D, 2.7, cell="rock_grey", inset=(0.3, 0.3))
    L.checker(b, ["rock_grey", "ash", "slate", "rock_grey", "rock_dark"], start=start, seed=5)
    py = D - 0.3 * 0.1
    L.slab(b, -0.6, py - 0.08, 0.0, 0.6, py + 0.1, 1.9, cell="ink", inset=(0.1, 0.0))
    for x in (-3.0, 3.0):
        L.slab(b, x - 0.3, py - 0.08, 1.2, x + 0.3, py + 0.08, 1.8, cell="ink")
    # Log upper floor set back, courses alternate red-ochre and dark.
    uw, ud = W - 0.55, D - 0.55
    z = 2.7
    for k in range(7):
        cell = "rock_red" if k % 2 == 0 else "sienna"
        L.slab(b, -uw, -ud, z, uw, ud, z + 0.42, cell=cell, inset=(0.02, 0.02))
        # Log ends poking out at the corners.
        for sx in (-1, 1):
            for sy in (-1, 1):
                L.slab(b, sx * uw - 0.14 * sx - 0.14, sy * ud - 0.14 * sy - 0.14, z, sx * uw - 0.14 * sx + 0.14 + 0.0, sy * ud - 0.14 * sy + 0.14, z + 0.4, cell="wood_light")
        z += 0.42
    top = z
    for x in (-2.6, 0.0, 2.6):
        window(b, x, 3.6, ud + 0.02, 0.8, 0.95, frame="ink", pane="soot")
    # Wooden gallery along the front with railing.
    L.slab(b, -uw + 0.4, ud, 2.7, uw - 0.4, ud + 1.3, 2.9, cell="wood_light")
    for i in range(9):
        x = -uw + 0.5 + i * (2 * uw - 1.0) / 8
        L.slab(b, x - 0.06, ud + 1.15, 2.9, x + 0.06, ud + 1.25, 3.7, cell="wood_dark")
    L.slab(b, -uw + 0.4, ud + 1.12, 3.6, uw - 0.4, ud + 1.28, 3.74, cell="wood_dark")
    for x in (-uw + 0.5, uw - 0.5):
        L.slab(b, x - 0.1, ud + 1.0, 0.0, x + 0.1, ud + 1.25, 2.9, cell="wood_dark")
    # Roof: low red parapet, a small top room in ochre, firewood stacked at the back.
    L.slab(b, -uw - 0.1, -ud - 0.1, top, uw + 0.1, ud + 0.1, top + 0.6, cell="rock_red", inset=(0.08, 0.08), top_cell="umber")
    L.slab(b, -2.2, -1.2, top + 0.6, 2.2, 1.6, top + 2.4, cell="rock_red", inset=(0.15, 0.15), top_cell="umber")
    window(b, -0.9, top + 1.0, 1.6 + 0.02, 0.7, 0.8)
    window(b, 0.9, top + 1.0, 1.6 + 0.02, 0.7, 0.8)
    for i in range(6):
        L.cyl(b, -3.4 + i * 0.28, -ud + 0.4, top + 0.6, 0.9, 0.12, n=4, cell="wood_light")
    L.cyl(b, uw - 0.6, ud - 0.6, top + 0.6, 3.2, 0.07, n=4, cell="wood_light")
    L.cone_t(b, uw - 0.6, ud - 0.6, top + 3.8, top + 4.2, 0.1, n=4, cell="gold")
    return b


def bridge_cant():
    b = L.new("bridge_cant")
    half_w = 11.5
    half_l = 14.0
    # Deck of cross planks, alternating light and dark.
    y = -half_l
    k = 0
    while y < half_l - 0.01:
        L.slab(b, -half_w, y, -0.5, half_w, min(y + 0.9, half_l), 0.07, cell="wood_light" if k % 2 == 0 else "tan", inset=(0.0, 0.0))
        y += 0.9
        k += 1
    # Stone abutments with cantilever log stacks stepping out toward the middle.
    for sy in (-1, 1):
        ya, yb = (half_l - 3.5, half_l + 0.5) if sy > 0 else (-half_l - 0.5, -half_l + 3.5)
        L.slab(b, -half_w - 0.6, ya, -9.0, half_w + 0.6, yb, -0.5, cell="rock_grey")
        for layer in range(4):
            reach = 3.0 + layer * 1.7
            y0, y1 = sorted((sy * half_l, sy * (half_l - reach)))
            L.slab(b, -half_w + 0.3, y0, -0.95 - layer * 0.5, half_w - 0.3, y1, -0.52 - layer * 0.5, cell="wood_dark" if layer % 2 == 0 else "umber")
    # Main beams and a centre prop pair for the lower deck.
    for x in (-half_w + 1.2, 0.0, half_w - 1.2):
        L.slab(b, x - 0.35, -half_l + 0.5, -1.45, x + 0.35, half_l - 0.5, -0.5, cell="wood_dark")
    # Railings.
    for sx in (-1, 1):
        x = sx * (half_w - 0.15)
        for i in range(10):
            yy = -half_l + 0.6 + i * (2 * half_l - 1.2) / 9
            L.slab(b, x - 0.12, yy - 0.12, 0.0, x + 0.12, yy + 0.12, 1.35, cell="wood_dark")
        L.slab(b, x - 0.1, -half_l + 0.4, 1.15, x + 0.1, half_l - 0.4, 1.35, cell="wood_light")
        L.slab(b, x - 0.08, -half_l + 0.4, 0.55, x + 0.08, half_l - 0.4, 0.7, cell="wood_light")
        # Tall prayer-flag posts at the ends.
        for sy in (-1, 1):
            L.cyl(b, x, sy * (half_l - 0.3), 0.0, 3.6, 0.1, n=4, cell="wood_light")
            L.cone_t(b, x, sy * (half_l - 0.3), 3.6, 4.0, 0.1, n=4, cell="gold")
    return b


def truck():
    b = L.new("truck")
    # A plain 1950s lorry: cab, flat bed with canvas hoops, big dark tyres. No marks anywhere.
    L.slab(b, -1.35, -3.4, 0.7, 1.35, 3.2, 1.2, cell="pine")
    L.slab(b, -1.3, 1.2, 1.2, 1.3, 3.0, 2.6, cell="pine", inset=(0.08, 0.35))
    L.slab(b, -1.0, 2.6, 1.7, 1.0, 3.05, 2.35, cell="ink", inset=(0.05, 0.0))
    L.slab(b, -1.4, 3.0, 0.5, 1.4, 3.6, 1.3, cell="pine", inset=(0.1, 0.2))
    for i in range(4):
        y = -3.0 + i * 1.3
        L.slab(b, -1.45, y, 1.2, 1.45, y + 0.1, 2.6 + (0.0 if i in (1, 2) else -0.25), cell="wood_dark", inset=(0.55 if i in (0, 3) else 0.3, 0.0))
    L.slab(b, -1.4, -3.3, 2.0, 1.4, 1.0, 2.9, cell="khaki", inset=(0.45, 0.0))
    L.slab(b, -1.4, -3.4, 1.2, 1.4, 1.0, 1.7, cell="wood_light")
    for (x, y) in ((-1.25, -2.2), (1.25, -2.2), (-1.25, 2.2), (1.25, 2.2)):
        L.slab(b, x - 0.28, y - 0.75, 0.0, x + 0.28, y + 0.75, 1.5, cell="soot", inset=(0.0, 0.18))
    L.slab(b, -0.7, 3.55, 0.7, 0.7, 3.7, 1.1, cell="steel")
    return b


def wall_white():
    b = L.new("wall_white")
    # A whitewashed battered wall 12 m long along Y with a dark red frieze and a slate coping.
    L.slab(b, -0.75, -6.0, -0.6, 0.75, 6.0, 2.5, cell="chalk", inset=(0.28, 0.0))
    L.slab(b, -0.62, -6.02, 1.7, 0.62, 6.02, 2.25, cell="pema", inset=(0.1, 0.0))
    L.slab(b, -0.75, -6.1, 2.5, 0.75, 6.1, 2.85, cell="slate", inset=(0.05, 0.0))
    for y in (-6.0, -2.0, 2.0, 6.0):
        L.slab(b, -0.95, y - 0.35, -0.6, 0.95, y + 0.35, 2.7, cell="chalk", inset=(0.3, 0.1))
        L.slab(b, -0.97, y - 0.37, 2.7, 0.97, y + 0.37, 3.0, cell="bone", top_cell="slate")
    return b


def wall_stone():
    rng = random.Random(33)
    b = L.new("wall_stone")
    y = -6.0
    while y < 5.8:
        w = rng.uniform(0.9, 1.7)
        h = rng.uniform(1.15, 1.6)
        start = len(b.faces)
        L.slab(b, -0.55, y, -0.4, 0.55, min(y + w, 6.0), h, cell="rock_grey", inset=(0.14, 0.04), top_cell="ash")
        L.checker(b, ["rock_grey", "ash", "slate", "rock_grey"], start=start, end=start + 5, seed=int(y * 10) + 100)
        y += w - 0.04
    return b


def run():
    L.single("wall_white", wall_white())
    L.single("wall_stone", wall_stone())
    L.single("house_white", house_white())
    L.single("house_tsang", house_tsang())
    L.single("house_kham", house_kham())
    L.single("bridge_cant", bridge_cant())
    L.single("truck", truck())


run()
