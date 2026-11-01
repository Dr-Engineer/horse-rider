"""Paints the repeating road textures: assets/atlas/road_<id>.png (stdlib only).

Each tile spans the whole road ribbon once across (u: dark verge, light dusty road with two soft hoof-beaten lanes and
their ruts, dark verge) and repeats along it (v). 384 px square, wraps vertically, so a pixel is about 7 to 10 cm on the
ground. Colours are palette names only (mixes of them for shading). No symbols, no marks that read as script: only dust,
gravel, pebbles with shadows, ruts and hoofprints.

  python3 art/tools/make_road.py
"""
import math
import os
import random
import struct
import sys
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import atlas_palette  # noqa: E402

PAL = {name: tuple(int(value.lstrip("#")[i:i + 2], 16) for i in (0, 2, 4)) for name, value in atlas_palette.COLORS}
SIZE = 384
VERGE = 54          # dark verge on each side, in px (about 14% of the width)
LANE_HALF = 20      # half width of a hoof-beaten lane, in px
BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]

COURSES = {
    # base: (name, weight) light colours; lane: darker trampled lane colours; light/dark: pebble colours; verge colours
    "tea": dict(base=[("sand", 14), ("bone", 4), ("tan", 1)], lane=[("tan", 5), ("sienna", 2), ("sand", 3)],
                light=["bone", "chalk"], dark=["rock_red", "umber", "sienna"],
                verge=[("umber", 5), ("sienna", 3), ("rock_red", 1)], fleck="khaki", seed=11),
    "grass": dict(base=[("bone", 10), ("sand", 5), ("chalk", 1)], lane=[("khaki", 5), ("tan", 2), ("sand", 3)],
                  light=["chalk", "bone"], dark=["rock_grey", "khaki", "umber"],
                  verge=[("grass_deep", 4), ("umber", 4), ("pine", 1)], fleck="grass_gold", seed=23),
    "pass": dict(base=[("bone", 14), ("sand", 5), ("ash", 1)], lane=[("ash", 3), ("tan", 2), ("bone", 4)],
                 light=["ash", "chalk"], dark=["rock_grey", "rock_dark", "slate"],
                 verge=[("rock_dark", 4), ("charcoal", 3), ("slate", 2)], fleck="ash", seed=37),
    "gyantse": dict(base=[("sand", 10), ("chalk", 4), ("bone", 2)], lane=[("tan", 4), ("ochre", 2), ("sand", 3)],
                    light=["conch", "bone"], dark=["umber", "rock_grey", "tan"],
                    verge=[("umber", 4), ("khaki", 2), ("sienna", 3)], fleck="barley", seed=41),
    "lhasa": dict(base=[("chalk", 8), ("bone", 6), ("sand", 2)], lane=[("sand", 5), ("tan", 2), ("bone", 3)],
                  light=["conch", "bone"], dark=["rock_grey", "ash", "slate"],
                  verge=[("rock_grey", 3), ("charcoal", 3), ("slate", 3)], fleck="khaki", seed=53),
}


class Noise:
    """Smooth value noise that wraps on both axes, so a texture built from it tiles."""

    def __init__(self, rng, nx, ny):
        self.nx, self.ny = nx, ny
        self.g = [[rng.random() for _ in range(nx)] for _ in range(ny)]

    def at(self, x, y):
        x0, y0 = math.floor(x), math.floor(y)
        fx, fy = x - x0, y - y0
        fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
        x0, y0 = int(x0) % self.nx, int(y0) % self.ny
        x1, y1 = (x0 + 1) % self.nx, (y0 + 1) % self.ny
        g = self.g
        a = g[y0][x0] + (g[y0][x1] - g[y0][x0]) * fx
        b = g[y1][x0] + (g[y1][x1] - g[y1][x0]) * fx
        return a + (b - a) * fy


def pick(rng, weighted):
    total = sum(w for _, w in weighted)
    r = rng.random() * total
    for name, w in weighted:
        r -= w
        if r <= 0:
            return PAL[name]
    return PAL[weighted[-1][0]]


def mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def tone_by(weighted, v):
    """Map v in 0..1 onto the weighted palette by cumulative weight, so common tones cover wide patches."""
    total = sum(w for _, w in weighted)
    acc = 0.0
    for name, w in weighted:
        acc += w / total
        if v <= acc:
            return PAL[name]
    return PAL[weighted[-1][0]]


def paint(spec):
    rng = random.Random(spec["seed"])
    img = [[(0, 0, 0)] * SIZE for _ in range(SIZE)]

    def put(x, y, c):
        if 0 <= x < SIZE:
            img[y % SIZE][x] = c

    def get(x, y):
        return img[y % SIZE][max(0, min(SIZE - 1, x))]

    n_big = Noise(rng, 8, 8)       # patches about 3 m across
    n_mid = Noise(rng, 24, 24)     # clumps about 1 m
    n_fine = Noise(rng, 96, 96)    # grain about 25 cm
    n_gap = Noise(rng, 1, 12)      # along-the-road variation for ruts and lanes
    ph = [rng.random() * 6.28 for _ in range(4)]

    # Verge boundary wanders along the length, periodic so the tile wraps.
    def edge(y):
        return VERGE + int(round(5.0 * math.sin(2 * math.pi * y / SIZE * 2 + ph[0]) + 2.6 * math.sin(2 * math.pi * y / SIZE * 5 + ph[1])))

    # 1. light dusty base: broad patches of tone, clumped, with a little 1 px grain
    for y in range(SIZE):
        for x in range(SIZE):
            v = 0.5 * n_big.at(x / SIZE * 8, y / SIZE * 8) + 0.32 * n_mid.at(x / SIZE * 24, y / SIZE * 24) + 0.18 * n_fine.at(x / SIZE * 96, y / SIZE * 96)
            c = tone_by(spec["base"], min(0.999, max(0.0, (v - 0.22) * 1.9)))
            if rng.random() < 0.16:
                c = pick(rng, spec["base"])
            img[y][x] = c

    # 2. dust streaks along the length, slightly darker than the base
    for _ in range(170):
        x = rng.randrange(VERGE + 3, SIZE - VERGE - 3)
        y0 = rng.randrange(SIZE)
        shade = mix(PAL[spec["base"][0][0]], PAL["tan"], rng.uniform(0.18, 0.42))
        for k in range(rng.randrange(8, 44)):
            put(x, y0 + k, shade)

    # 3. two hoof-beaten lanes, dithered so their sides are soft, plus real ruts and hoofprints
    lane_pal = spec["lane"]
    lane_centres = (int(SIZE * 0.31), int(SIZE * 0.69))
    for li, cx in enumerate(lane_centres):
        wander = [rng.random() * 6.28 for _ in range(3)]

        def centre(y, cx=cx, wander=wander):
            return cx + 5.0 * math.sin(2 * math.pi * y / SIZE * 2 + wander[0]) + 3.0 * math.sin(2 * math.pi * y / SIZE * 4 + wander[1])

        for y in range(SIZE):
            c = centre(y)
            half = LANE_HALF + 3.2 * math.sin(2 * math.pi * y / SIZE * 3 + wander[2]) + 4.0 * (n_gap.at(0.0, y / SIZE * 12) - 0.5)
            for x in range(int(c - half) - 2, int(c + half) + 3):
                m = 1.0 - abs(x - c) / half
                if m <= 0.0:
                    continue
                thr = BAYER[y % 4][x % 4] / 16.0 * 0.9 + 0.05 + (rng.random() - 0.5) * 0.18
                if m * 1.25 > thr:
                    t = n_mid.at(x / SIZE * 24 + 3.0, y / SIZE * 24)
                    col = tone_by(lane_pal, min(0.999, t * 1.1))
                    if m > 0.72 and rng.random() < 0.35:
                        col = mix(col, PAL["umber"], 0.16)      # the compacted core is a little darker
                    # soft: the lane tints the dust under it instead of replacing it
                    put(x, y, mix(get(x, y), col, 0.42 + 0.3 * m))
        # ruts: two thin grooves in each lane, broken here and there, with a lighter lip on the outside
        for side in (-1, 1):
            off = side * LANE_HALF * 0.46
            wob = rng.random() * 6.28
            for y in range(SIZE):
                if n_gap.at(0.0, y / SIZE * 12 + (3.0 if side > 0 else 7.0)) > 0.7:
                    continue
                xr = int(round(centre(y) + off + 1.6 * math.sin(2 * math.pi * y / SIZE * 6 + wob)))
                base = get(xr, y)
                groove = mix(base, PAL["umber"], 0.34)
                put(xr, y, groove)
                put(xr + (1 if side > 0 else -1), y, mix(base, groove, 0.5))
                put(xr - side, y, mix(base, PAL["bone"], 0.22))
        # hoofprints: little shoes, open at the heel (toward lower y), in pairs where hooves landed
        for _ in range(16):
            y = rng.randrange(SIZE)
            c = centre(y)
            x = int(c + rng.uniform(-LANE_HALF * 0.7, LANE_HALF * 0.7))
            for (dy, dx) in ((0, 0), (9, 5 if rng.random() < 0.5 else -4)):
                shoe = [(0, 0), (0, 1), (0, 2), (1, 0), (1, 2), (2, 0), (2, 2), (3, 1)]
                dark = mix(PAL[lane_pal[0][0]], PAL["umber"], 0.5)
                for (sy, sx) in shoe:
                    put(x + dx + sx, y + dy + sy, dark)
                put(x + dx, y + dy - 1, mix(PAL[lane_pal[0][0]], PAL["bone"], 0.3))

    # 4. pebbles: light ones cast a dark pixel to the lower right, dark ones catch a light pixel at the top left
    for _ in range(760):
        x = rng.randrange(VERGE + 2, SIZE - VERGE - 2)
        y = rng.randrange(SIZE)
        w, h = rng.choice(((1, 1), (1, 1), (1, 1), (2, 1), (2, 1), (2, 2), (2, 2), (3, 2), (3, 3)))
        light = rng.random() < 0.6
        col = PAL[rng.choice(spec["light"] if light else spec["dark"])]
        for dx in range(w):
            for dy in range(h):
                put(x + dx, y + dy, col)
        shadow = mix(col, PAL["umber"], 0.52)
        for dy in range(1, h + 1):
            put(x + w, y + dy, shadow)
        for dx in range(1, w + 1):
            put(x + dx, y + h, shadow)
        if not light and w >= 2:
            put(x, y, mix(col, PAL["bone"], 0.5))
    # a few bigger stones, set into the road
    for _ in range(26):
        x = rng.randrange(VERGE + 6, SIZE - VERGE - 8)
        y = rng.randrange(SIZE)
        col = PAL[rng.choice(spec["dark"] + spec["light"])]
        for dx in range(5):
            for dy in range(3):
                if (dx in (0, 4)) and (dy in (0, 2)):
                    continue
                put(x + dx, y + dy, mix(col, PAL["bone"], 0.35) if dy == 0 else col)
        for dx in range(1, 6):
            put(x + dx, y + 3, mix(col, PAL["umber"], 0.55))
        put(x + 5, y + 1, mix(col, PAL["umber"], 0.55))
        put(x + 5, y + 2, mix(col, PAL["umber"], 0.55))

    # 5. verges: dark, mottled, with fleck tufts and stones, a ragged inner edge that blends in through a dithered band
    kerb = mix(PAL["umber"], PAL["soot"], 0.35)
    for y in range(SIZE):
        e = edge(y)
        for x in range(0, e):
            put(x, y, pick(rng, spec["verge"]))
            put(SIZE - 1 - x, y, pick(rng, spec["verge"]))
        for k in range(1, 9):
            # the road side of the verge: verge pixels thin out over a few px
            p = 1.0 - k / 9.0
            for side in (0, 1):
                if rng.random() < p * 0.8:
                    xx = e + k - 1
                    put(xx if side == 0 else SIZE - 1 - xx, y, pick(rng, spec["verge"]))
        for x in (e, e + 1):
            if rng.random() < 0.6:
                put(x, y, kerb)
            if rng.random() < 0.6:
                put(SIZE - 1 - x, y, kerb)
    for _ in range(190):
        side = rng.choice((0, 1))
        x = rng.randrange(0, VERGE - 2)
        x = x if side == 0 else SIZE - 1 - x
        y = rng.randrange(SIZE)
        fleck = PAL[spec["fleck"]]
        put(x, y, fleck)
        put(x, y + 1, mix(fleck, PAL["umber"], 0.4))
        if rng.random() < 0.4:
            put(x + 1, y, mix(fleck, PAL["umber"], 0.2))
    for _ in range(58):
        side = rng.choice((0, 1))
        x = rng.randrange(1, VERGE - 5)
        x = x if side == 0 else SIZE - 1 - x
        y = rng.randrange(SIZE)
        col = PAL[rng.choice(spec["dark"])]
        for dx in range(3):
            for dy in range(3):
                put(x + dx, y + dy, mix(col, PAL["soot"], 0.2))
        put(x, y, mix(col, PAL["bone"], 0.3))
    return img


def save_png(path, img):
    raw = b"".join(b"\x00" + b"".join(bytes(px) for px in row) for row in img)

    def chunk(tag, data):
        body = tag + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)

    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(chunk(b"IHDR", struct.pack(">IIBBBBB", SIZE, SIZE, 8, 2, 0, 0, 0)))
        f.write(chunk(b"IDAT", zlib.compress(raw, 9)))
        f.write(chunk(b"IEND", b""))


def main():
    out = os.path.join(ROOT, "assets", "atlas")
    os.makedirs(out, exist_ok=True)
    only = [a for a in sys.argv[1:] if a in COURSES]
    for name, spec in COURSES.items():
        if only and name not in only:
            continue
        save_png(os.path.join(out, "road_%s.png" % name), paint(spec))
        print("road_%s.png" % name)


if __name__ == "__main__":
    main()
