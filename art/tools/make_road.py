"""Paints the small repeating road textures: assets/atlas/road_<id>.png (stdlib only).

Each tile spans the whole road ribbon once across (u: dark verge, light dusty road with two hoof-beaten lanes, dark
verge) and repeats along it (v). Wraps vertically. Colours are palette names only. No symbols, no marks that read as
script: only dust, stones and hoof dots.

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
SIZE = 192
VERGE = 27

COURSES = {
    # base: (name, weight) light colours; lane: darker trampled lane colours; stones_light/dark; verge colours
    "tea": dict(base=[("sand", 14), ("bone", 3), ("tan", 1)], lane=[("tan", 5), ("sienna", 2), ("sand", 3)],
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


def paint(spec):
    rng = random.Random(spec["seed"])
    K = SIZE / 128.0
    img = [[(0, 0, 0)] * SIZE for _ in range(SIZE)]

    def put(x, y, c):
        if 0 <= x < SIZE:
            img[y % SIZE][x] = c

    # Verge boundary wanders along the length, periodic so the tile wraps.
    ph = [rng.random() * 6.28 for _ in range(3)]

    def edge(y):
        return VERGE + int(round(3.0 * math.sin(2 * math.pi * y / SIZE * 2 + ph[0]) + 1.6 * math.sin(2 * math.pi * y / SIZE * 5 + ph[1])))

    # 1. light dusty base in 2x2 clumps with 1 px grain
    clump = [[pick(rng, spec["base"]) for _ in range(SIZE // 2)] for _ in range(SIZE // 2)]
    for y in range(SIZE):
        for x in range(SIZE):
            c = clump[y // 2][x // 2]
            if rng.random() < 0.18:
                c = pick(rng, spec["base"])
            img[y][x] = c

    # 2. dust streaks along the length, slightly darker than the base
    for _ in range(int(46 * K)):
        x = rng.randrange(VERGE + 2, SIZE - VERGE - 2)
        y0 = rng.randrange(SIZE)
        length = rng.randrange(6, 30)
        shade = mix(PAL[spec["base"][0][0]], PAL["tan"], rng.uniform(0.25, 0.5))
        for k in range(length):
            put(x, y0 + k, shade)

    # 3. two hoof-beaten lanes, mottled darker, with ragged sides
    lanes = (int(SIZE * 0.31), int(SIZE * 0.69))
    for cx in lanes:
        wander = [rng.random() * 6.28 for _ in range(2)]
        for y in range(SIZE):
            centre = cx + 2.2 * math.sin(2 * math.pi * y / SIZE * 2 + wander[0]) + 1.3 * math.sin(2 * math.pi * y / SIZE * 4 + wander[1])
            half = int(K * 7) + int(round(1.5 * math.sin(2 * math.pi * y / SIZE * 3 + wander[0])))
            for x in range(int(centre) - half - 1, int(centre) + half + 2):
                dist = abs(x - centre)
                if dist > half + rng.choice((0, 1)):
                    continue
                inner = dist < half - 4
                if inner or rng.random() < 0.55:
                    put(x, y, pick(rng, spec["lane"]))
        # hoof dots: pairs of dark pixels with a gap, in and around the lane
        for _ in range(int(16 * K)):
            x = cx + rng.randrange(-11, 12)
            y = rng.randrange(SIZE)
            dark = mix(PAL[spec["lane"][0][0]], PAL["umber"], 0.3)
            put(x, y, dark)
            put(x + 2, y, dark)
            put(x, y + 1, dark)
            put(x + 2, y + 1, dark)

    # 4. stones: light ones with a dark shadow pixel, dark ones with a light top pixel
    for _ in range(int(64 * K)):
        x = rng.randrange(VERGE + 1, SIZE - VERGE - 1)
        y = rng.randrange(SIZE)
        w = rng.choice((1, 1, 2, 2, 3))
        h = rng.choice((1, 1, 2))
        light = rng.random() < 0.62
        col = PAL[rng.choice(spec["light"] if light else spec["dark"])]
        for dx in range(w):
            for dy in range(h):
                put(x + dx, y + dy, col)
        put(x + w, y + h, mix(col, PAL["umber"], 0.5))

    # 5. verges: dark, mottled, with fleck tufts and stones, ragged inner edge
    for y in range(SIZE):
        e = edge(y)
        for x in range(0, e):
            put(x, y, pick(rng, spec["verge"]))
            put(SIZE - 1 - x, y, pick(rng, spec["verge"]))
        # a dark kerb line one pixel inside the verge so the road edge always reads
        for x in (e, e + 1):
            if rng.random() < 0.65:
                put(x, y, mix(PAL["umber"], PAL["soot"], 0.35))
            if rng.random() < 0.65:
                put(SIZE - 1 - x, y, mix(PAL["umber"], PAL["soot"], 0.35))
    for _ in range(int(40 * K)):
        side = rng.choice((0, 1))
        x = rng.randrange(0, VERGE - 1)
        x = x if side == 0 else SIZE - 1 - x
        y = rng.randrange(SIZE)
        fleck = PAL[spec["fleck"]]
        put(x, y, fleck)
        put(x, y + 1, mix(fleck, PAL["umber"], 0.4))
    for _ in range(int(14 * K)):
        side = rng.choice((0, 1))
        x = rng.randrange(1, VERGE - 3)
        x = x if side == 0 else SIZE - 1 - x
        y = rng.randrange(SIZE)
        col = PAL[rng.choice(spec["dark"])]
        for dx in range(2):
            for dy in range(2):
                put(x + dx, y + dy, mix(col, PAL["soot"], 0.2))
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
    for name, spec in COURSES.items():
        save_png(os.path.join(out, "road_%s.png" % name), paint(spec))
        print("road_%s.png" % name)


if __name__ == "__main__":
    main()
