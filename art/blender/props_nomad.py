"""Animals, tents and nomad goods. Static low-poly bodies, no rigs (the game bobs them). +Y is the front."""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import props_lib as L  # noqa: E402
import kit  # noqa: E402
rope = L.rope


def barrel(b, ys, rxs, rzs, zcs, cell, n=8, x=0.0, cap_cell=None):
    rings = [kit.Ring((x, y, zc), rx, rz) for y, rx, rz, zc in zip(ys, rxs, rzs, zcs)]
    b.loft(rings, n=n, cell=cell, axis=(0, 1, 0), up=(0, 0, 1))


def leg(b, x, y, top, bottom, w, cell, hoof="soot", hoof_h=0.1):
    L.slab(b, x - w * 0.6, y - w * 0.6, bottom, x + w * 0.6, y + w * 0.6, top, cell=cell, inset=(-w * 0.35, -w * 0.35), bottom=False)
    L.slab(b, x - w * 0.75, y - w * 0.75, bottom - 0.02, x + w * 0.75, y + w * 0.95, bottom + hoof_h, cell=hoof, inset=(0.02, 0.02))


def yak():
    b = L.new("yak")
    barrel(b, [-1.5, -1.15, -0.4, 0.4, 0.95, 1.35], [0.4, 0.62, 0.72, 0.72, 0.64, 0.42], [0.5, 0.66, 0.7, 0.78, 0.74, 0.52],
           [1.15, 1.2, 1.25, 1.32, 1.38, 1.22], "yak_black", n=8)
    # Hair skirt hanging to the knees, flared and ragged.
    L.slab(b, -0.62, -1.35, 0.32, 0.62, 1.15, 1.0, cell="yak_black", inset=(0.2, 0.15))
    L.slab(b, -0.72, -1.2, 0.3, 0.72, 0.9, 0.55, cell="soot", inset=(0.1, 0.1))
    for (x, y) in ((-0.38, -1.0), (0.38, -1.0), (-0.4, 0.85), (0.4, 0.85)):
        leg(b, x, y, 0.5, 0.0, 0.17, "charcoal", "soot")
    # Head low and forward, wide horns up and out.
    L.slab(b, -0.3, 1.2, 0.85, 0.3, 1.9, 1.5, cell="yak_black", inset=(0.06, 0.12))
    L.slab(b, -0.22, 1.85, 0.8, 0.22, 2.25, 1.15, cell="soot", inset=(0.04, 0.05))
    L.slab(b, -0.34, 1.35, 1.4, -0.2, 1.55, 1.6, cell="yak_black")
    L.slab(b, 0.2, 1.35, 1.4, 0.34, 1.55, 1.6, cell="yak_black")
    for sx in (-1, 1):
        b.tube([(sx * 0.3, 1.45, 1.38), (sx * 0.62, 1.52, 1.5), (sx * 0.85, 1.6, 1.85), (sx * 0.78, 1.7, 2.2)], [0.1, 0.085, 0.06, 0.025], n=4, cell="bone")
    # Shoulder hump and tail.
    L.blob(b, (0, 0.85, 1.9), (0.5, 0.6, 0.35), random.Random(1), segs=6, rings=3, cell="yak_black", jitter=0.08)
    L.slab(b, -0.2, -1.65, 0.55, 0.2, -1.4, 1.35, cell="yak_black", inset=(0.0, 0.04))
    return b


def mule():
    b = L.new("mule")
    barrel(b, [-1.0, -0.65, 0.0, 0.6, 0.95], [0.26, 0.36, 0.38, 0.36, 0.3], [0.36, 0.48, 0.5, 0.48, 0.38], [1.0, 1.05, 1.08, 1.08, 1.05], "sienna", n=8)
    L.shade_down(b, "sand", thresh=-0.45)
    for (x, y) in ((-0.2, -0.72), (0.2, -0.72), (-0.2, 0.62), (0.2, 0.62)):
        leg(b, x, y, 0.75, 0.0, 0.1, "umber", "soot")
    b.tube([(0, 0.85, 1.15), (0, 1.15, 1.45), (0, 1.38, 1.62)], [0.22, 0.18, 0.15], n=6, cell="sienna")
    L.slab(b, -0.15, 1.3, 1.35, 0.15, 1.75, 1.72, cell="umber", inset=(0.02, 0.04))
    L.slab(b, -0.11, 1.72, 1.35, 0.11, 1.85, 1.55, cell="sand")
    for sx in (-1, 1):
        L.cone_t(b, sx * 0.1, 1.38, 1.7, 2.1, 0.06, n=4, cell="umber")
    L.slab(b, -0.04, -1.1, 0.65, 0.04, -0.98, 1.2, cell="soot")
    # Pack: red cloth over the back, two bales slung on either side, a roll on top.
    L.slab(b, -0.45, -0.5, 1.3, 0.45, 0.5, 1.45, cell="vermilion")
    for sx in (-1, 1):
        L.slab(b, sx * 0.62 - 0.22, -0.45, 0.8, sx * 0.62 + 0.22, 0.45, 1.55, cell="chalk", inset=(0.03, 0.05))
        L.slab(b, sx * 0.62 - 0.225, -0.1, 0.78, sx * 0.62 + 0.225, 0.1, 1.5, cell="bone")
    L.slab(b, -0.3, -0.5, 1.45, 0.3, 0.5, 1.85, cell="khaki", inset=(0.05, 0.05))
    L.slab(b, -0.31, -0.08, 1.44, 0.31, 0.08, 1.8, cell="bone")
    return b


def sheep():
    rng = random.Random(3)
    b = L.new("sheep")
    L.blob(b, (0, 0, 0.62), (0.42, 0.62, 0.4), rng, segs=7, rings=4, cell="sheepskin", jitter=0.1, cell_top="felt_white", up_thresh=0.5)
    for (x, y) in ((-0.16, -0.32), (0.16, -0.32), (-0.16, 0.32), (0.16, 0.32)):
        leg(b, x, y, 0.4, 0.0, 0.06, "charcoal", "soot", 0.06)
    L.slab(b, -0.14, 0.5, 0.52, 0.14, 0.8, 0.88, cell="soot", inset=(0.02, 0.04))
    L.slab(b, -0.22, 0.58, 0.8, -0.14, 0.72, 0.86, cell="soot")
    L.slab(b, 0.14, 0.58, 0.8, 0.22, 0.72, 0.86, cell="soot")
    return b


def dog():
    b = L.new("dog")
    barrel(b, [-0.6, -0.3, 0.2, 0.55], [0.2, 0.25, 0.28, 0.23], [0.28, 0.33, 0.36, 0.3], [0.62, 0.66, 0.68, 0.66], "soot", n=7)
    for (x, y) in ((-0.15, -0.38), (0.15, -0.38), (-0.17, 0.36), (0.17, 0.36)):
        leg(b, x, y, 0.45, 0.0, 0.09, "tan", "soot", 0.05)
    L.slab(b, -0.2, 0.5, 0.55, 0.2, 0.92, 0.95, cell="soot", inset=(0.02, 0.04))
    L.slab(b, -0.12, 0.88, 0.5, 0.12, 1.1, 0.78, cell="tan")
    L.slab(b, -0.1, 1.08, 0.58, 0.1, 1.15, 0.72, cell="ink")
    for sx in (-1, 1):
        L.slab(b, sx * 0.2 - 0.04, 0.58, 0.82, sx * 0.2 + 0.04, 0.7, 1.0, cell="soot")
    L.cyl(b, 0, 0.42, 0.55, 0.12, 0.3, n=6, cell="vermilion", rot=0.0)
    b.tube([(0, -0.6, 0.8), (0, -0.8, 0.95), (0, -0.78, 1.15)], [0.06, 0.05, 0.03], n=4, cell="soot")
    return b


def kiang():
    b = L.new("kiang")
    barrel(b, [-0.95, -0.6, 0.0, 0.6, 0.9], [0.22, 0.3, 0.32, 0.3, 0.24], [0.34, 0.44, 0.46, 0.44, 0.34], [1.15, 1.2, 1.22, 1.22, 1.2], "tan", n=8)
    L.shade_down(b, "chalk", thresh=-0.4)
    for (x, y) in ((-0.17, -0.65), (0.17, -0.65), (-0.17, 0.62), (0.17, 0.62)):
        leg(b, x, y, 0.85, 0.0, 0.08, "sand", "soot", 0.08)
    b.tube([(0, 0.8, 1.3), (0, 1.1, 1.65), (0, 1.3, 1.85)], [0.2, 0.16, 0.13], n=6, cell="tan")
    L.slab(b, -0.13, 1.22, 1.62, 0.13, 1.72, 1.98, cell="tan", inset=(0.0, 0.0))
    L.slab(b, -0.11, 1.55, 1.65, 0.11, 1.75, 1.9, cell="chalk")
    L.slab(b, -0.03, 0.9, 1.5, 0.03, 1.3, 1.95, cell="umber")
    L.slab(b, -0.03, -0.9, 1.1, 0.03, 0.8, 1.32, cell="umber")
    b.tube([(0, -0.95, 1.15), (0, -1.1, 0.85), (0, -1.1, 0.5)], [0.05, 0.05, 0.06], n=4, cell="umber")
    return b


def marmot():
    rng = random.Random(2)
    b = L.new("marmot")
    L.blob(b, (0, 0, 0.32), (0.26, 0.24, 0.34), rng, segs=6, rings=3, cell="khaki", jitter=0.08, cell_top="tan")
    L.shade_down(b, "sand", thresh=-0.2)
    L.blob(b, (0, 0.1, 0.78), (0.16, 0.2, 0.15), rng, segs=6, rings=3, cell="tan", jitter=0.05)
    L.slab(b, -0.06, 0.28, 0.72, 0.06, 0.35, 0.82, cell="ink")
    for sx in (-1, 1):
        L.slab(b, sx * 0.12 - 0.02, 0.02, 0.88, sx * 0.12 + 0.02, 0.1, 0.96, cell="umber")
        L.slab(b, sx * 0.2 - 0.03, 0.15, 0.3, sx * 0.2 + 0.03, 0.25, 0.5, cell="umber")
    return b


def crane():
    b = L.new("crane")
    barrel(b, [-0.5, -0.2, 0.2, 0.5], [0.15, 0.22, 0.22, 0.14], [0.2, 0.28, 0.28, 0.2], [1.0, 1.05, 1.08, 1.12], "ash", n=7)
    L.shade_up(b, "chalk", thresh=0.55)
    for sx in (-1, 1):
        L.slab(b, sx * 0.1 - 0.02, -0.02, 0.05, sx * 0.1 + 0.02, 0.02, 0.85, cell="charcoal")
    b.tube([(0, 0.4, 1.12), (0, 0.55, 1.6), (0, 0.65, 1.95)], [0.07, 0.05, 0.05], n=5, cell="ink")
    L.slab(b, -0.05, 0.6, 1.9, 0.05, 0.75, 2.02, cell="ink")
    L.slab(b, -0.03, 0.74, 1.93, 0.03, 0.98, 1.97, cell="bone")
    L.slab(b, -0.04, 0.6, 2.0, 0.04, 0.7, 2.04, cell="vermilion")
    L.slab(b, -0.1, -0.7, 1.0, 0.1, -0.4, 1.1, cell="ink")
    return b


def dung_stack():
    b = L.new("dung_stack")
    cells = ["umber", "sienna", "umber", "wood_dark"]
    for row in range(5):
        z = row * 0.32
        inset = row * 0.1
        for i in range(6):
            x0 = -1.5 + inset + i * (3.0 - 2 * inset) / 6.0
            x1 = -1.5 + inset + (i + 1) * (3.0 - 2 * inset) / 6.0
            L.slab(b, x0 + 0.02, -0.8 + inset, z, x1 - 0.02, 0.8 - inset, z + 0.3, cell=cells[(i + row) % 4], inset=(0.02, 0.02))
    L.slab(b, -1.0, -0.4, 1.6, 1.0, 0.4, 1.78, cell="sand", inset=(0.1, 0.05))
    return b


def churn():
    b = L.new("churn")
    L.cyl(b, 0, 0, -0.1, 1.4, 0.4, n=8, cell="wood_light", r_top=0.3)
    L.cyl(b, 0, 0, 0.3, 0.08, 0.41, n=8, cell="brass", r_top=0.41)
    L.cyl(b, 0, 0, 0.9, 0.08, 0.34, n=8, cell="brass", r_top=0.34)
    L.cyl(b, 0, 0, 1.3, 0.1, 0.34, n=8, cell="wood_dark", r_top=0.3)
    L.cyl(b, 0, 0, 1.3, 1.2, 0.05, n=4, cell="wood_dark")
    L.cyl(b, 0, 0, 2.3, 0.1, 0.22, n=6, cell="wood_dark", r_top=0.22)
    return b


def tea_brick_stack():
    b = L.new("tea_brick_stack")
    cells = ["umber", "wood_dark", "sienna"]
    for row in range(5):
        for col in range(3):
            for dep in range(2):
                x = -0.9 + col * 0.62 + (0.15 if row % 2 else 0.0)
                L.slab(b, x, -0.6 + dep * 0.62, row * 0.28, x + 0.58, -0.04 + dep * 0.62, row * 0.28 + 0.26, cell=cells[(col + dep + row) % 3], inset=(0.02, 0.02))
    L.slab(b, -0.95, -0.62, 0.0, 0.95, 0.6, 0.02, cell="khaki")
    return b


def wool_bale():
    b = L.new("wool_bale")
    for (x, y, z, rot) in ((-0.65, 0.0, 0.0, 0), (0.65, 0.0, 0.0, 0), (0.0, 0.0, 0.8, 0)):
        L.slab(b, x - 0.55, y - 0.4, z, x + 0.55, y + 0.4, z + 0.78, cell="chalk", inset=(0.04, 0.04))
        for k in (-0.3, 0.3):
            L.slab(b, x - 0.56 + 0.0, y + k - 0.04, z - 0.01, x + 0.56, y + k + 0.04, z + 0.79, cell="bone", inset=(0.0, 0.0))
    return b


def tent_black():
    b = L.new("tent_black")
    xw, yl, zr, ze = 2.3, 3.0, 2.1, 1.05
    # Roof strips, black and charcoal, over each slope.
    edges = [0.0, 0.8, 1.55, xw]
    cells = ["soot", "charcoal", "soot"]
    for s in (-1, 1):
        for j in range(3):
            xa, xb = edges[j], edges[j + 1]
            za = zr - (xa / xw) * (zr - ze)
            zb = zr - (xb / xw) * (zr - ze)
            pts = [(s * xa, -yl, za), (s * xb, -yl, zb), (s * xb, yl, zb), (s * xa, yl, za),
                   (s * xa, -yl, za - 0.08), (s * xb, -yl, zb - 0.08), (s * xb, yl, zb - 0.08), (s * xa, yl, za - 0.08)]
            faces = [[0, 1, 2, 3], [4, 5, 6, 7], [0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7]]
            L.solid(b, pts, faces, cells[j])
    L.slab(b, -0.12, -yl + 0.2, zr - 0.02, 0.12, yl - 0.2, zr + 0.05, cell="bone")
    # Eave skirts and the dark opening at the front.
    for s in (-1, 1):
        L.slab(b, s * xw - 0.05, -yl, 0.0, s * xw + 0.05, yl, ze, cell="charcoal")
    L.slab(b, -xw, yl - 0.05, 0.0, xw, yl + 0.05, ze, cell="soot")
    L.slab(b, -0.7, yl - 0.02, 0.0, 0.7, yl + 0.1, 1.2, cell="ink")
    L.slab(b, -xw, -yl - 0.05, 0.0, xw, -yl + 0.05, ze, cell="soot")
    # Poles at the ends and guy ropes to pegs.
    for y in (-yl, yl):
        L.cyl(b, 0, y * 1.05, -0.1, zr + 0.5, 0.07, n=4, cell="wood_dark")
    for (x, y) in ((-xw, -yl), (xw, -yl), (-xw, yl), (xw, yl), (0, -yl), (0, yl)):
        ox, oy = (x * 1.9, y * 1.0) if abs(x) > 0 else (0, y * 1.9)
        rope(b, (x, y, ze if abs(x) > 0 else zr + 0.3), (ox, oy, 0.1), r=0.03, cell="bone")
        L.cyl(b, ox, oy, -0.1, 0.4, 0.05, n=3, cell="wood_dark")
    return b


def run():
    L.single("yak", yak())
    L.single("mule", mule())
    L.single("sheep", sheep())
    L.single("dog", dog())
    L.single("kiang", kiang())
    L.single("marmot", marmot())
    L.single("crane", crane())
    L.single("dung_stack", dung_stack())
    L.single("churn", churn())
    L.single("tea_brick_stack", tea_brick_stack())
    L.single("wool_bale", wool_bale())
    L.single("tent_black", tent_black())


run()
