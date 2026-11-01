"""Pixel-painted character tiles for the atlas. Each builder returns an HxWx3 uint8 array.

APPEND ONLY: the packer places tiles in list order, and exported models bake in the positions.
Faces are drawn as ASCII strokes on a 32x32 grid, written for the left half and mirrored.
Everything uses palette names from atlas_palette.py, never raw hex.
"""
import math

import numpy as np

import atlas_palette

PAL = dict(atlas_palette.COLORS)


def solid(h, w, name, hx):
    img = np.zeros((h, w, 3), np.uint8)
    img[:, :] = hx(PAL[name])
    return img


def dot(img, x, y, name, hx):
    if 0 <= y < img.shape[0] and 0 <= x < img.shape[1]:
        img[y, x] = hx(PAL[name])


def rect(img, x0, y0, x1, y1, name, hx):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            dot(img, x, y, name, hx)


def disc(img, cx, cy, r, name, hx):
    for y in range(img.shape[0]):
        for x in range(img.shape[1]):
            if (x - cx) ** 2 + (y - cy) ** 2 <= r * r:
                dot(img, x, y, name, hx)


# ---------------------------------------------------------------- faces -------------------------------------------
# Skin tones: (base, shade, highlight). Variants are suffixed "" (mid), "_lt", "_dp".
TONES = {"": ("skin", "skin_deep", "skin_light"), "_lt": ("skin_light", "skin", "sand"), "_dp": ("skin_deep", "umber", "skin")}
FACE_KEY = {"b": "hair_black", "e": "ink", "w": "conch", "m": "madder", "r": "blush", "g": "bone", "k": "soot",
            "t": "conch", "n": "umber", "p": "cinnabar", "c": "charcoal"}

# (row, left column, text[, "once"]). Text is mirrored onto the right half unless "once".
FACES = {
    "young": [
        (7, 9, "bbbbbb"), (8, 6, "bbbbbbb"),
        (10, 7, "eeeeeee"), (11, 7, "wweeeww"), (12, 7, "wweeeww"), (13, 8, "sssss"),
        (17, 3, "rrrrrr"), (18, 3, "rrrrrr"), (19, 4, "rrrr"),
        (26, 8, "mm"), (27, 10, "mmmmmm"), (28, 12, "ss"),
    ],
    "old": [
        (2, 5, "ssssssss"), (4, 6, "sssssss"),
        (6, 9, "gggggg"), (7, 6, "gggggggg"), (8, 6, "gggggg"),
        (10, 7, "eeeeeee"), (11, 7, "wweeeww"), (12, 7, "sssssss"),
        (10, 3, "s"), (11, 3, "s"), (12, 3, "s"), (11, 4, "s"),
        (15, 8, "s"), (16, 8, "s"), (17, 9, "s"), (18, 9, "s"), (19, 10, "s"), (20, 10, "s"), (21, 10, "s"),
        (17, 4, "rrr"), (18, 4, "rrr"),
        (22, 9, "gggggg"), (23, 7, "gggggggg"), (24, 6, "ggggg"),
        (26, 11, "nnnnn"),
        (28, 12, "gggg"), (29, 11, "gggggg"), (30, 12, "gggg"),
    ],
    "woman": [
        (7, 8, "bbbbbb"), (8, 6, "bb"), (9, 6, "b"),
        (9, 5, "e"), (10, 6, "eeeeeeee"), (11, 7, "wweeeww"), (12, 7, "wweeeww"), (13, 8, "sssss"),
        (16, 3, "rrrrrr"), (17, 3, "rrrrrr"), (18, 4, "rrrr"),
        (26, 11, "pppp"), (27, 10, "pppppp"), (28, 11, "pppp"), (27, 15, "n"),
    ],
    "woman_old": [
        (3, 6, "ssssssss"),
        (7, 8, "gggggg"), (8, 6, "ggg"), (9, 6, "g"),
        (10, 7, "eeeeeee"), (11, 7, "wweeeww"), (12, 7, "wweeeww"), (13, 7, "sssssss"),
        (10, 3, "s"), (11, 3, "s"), (12, 3, "s"), (11, 4, "s"),
        (16, 3, "rrrrrr"), (17, 3, "rrrrrr"), (18, 4, "rrrr"),
        (19, 9, "s"), (20, 9, "s"), (21, 9, "s"), (22, 10, "s"),
        (26, 8, "mm"), (27, 10, "mmmmmm"), (28, 12, "ss"),
    ],
    "soot": [
        (5, 8, "bbbbbbb"), (6, 6, "bbbbb"),
        (9, 6, "kkkkkkkk"), (10, 5, "kk"), (10, 14, "k"), (11, 5, "kk"), (11, 14, "k"),
        (12, 5, "kk"), (12, 14, "k"), (13, 5, "kk"), (14, 6, "kkkkkkkk"), (15, 7, "kkkkkk"),
        (9, 5, "c"), (14, 5, "c"), (16, 4, "kk"), (17, 3, "kk"), (18, 3, "c"),
        (10, 7, "eeeeeee"), (11, 7, "wweeeww"), (12, 7, "wweeeww"), (13, 8, "wwwww"),
        (26, 10, "mmmmmm"), (27, 10, "tttttt"), (28, 11, "mmmmm"),
    ],
}


def paint_face(name, tone, hx):
    base, shade, hi = TONES[tone]
    key = dict(FACE_KEY)
    key.update({".": base, "s": shade, "l": hi})
    grid = [["."] * 32 for _ in range(32)]
    for stroke in FACES[name]:
        row, col, text = stroke[0], stroke[1], stroke[2]
        once = len(stroke) > 3
        for i, ch in enumerate(text):
            if ch == " ":
                continue
            grid[row][col + i] = ch
            if not once:
                grid[row][31 - (col + i)] = ch
    img = np.zeros((32, 32, 3), np.uint8)
    for y in range(32):
        for x in range(32):
            img[y, x] = hx(PAL[key[grid[y][x]]])
    return img


# ----------------------------------------------------------- rug medallions ---------------------------------------
def frame(img, hx, outer="gold", inner="ink"):
    h, w = img.shape[:2]
    rect(img, 0, 0, w - 1, 0, outer, hx)
    rect(img, 0, h - 1, w - 1, h - 1, outer, hx)
    rect(img, 0, 0, 0, h - 1, outer, hx)
    rect(img, w - 1, 0, w - 1, h - 1, outer, hx)
    rect(img, 1, 1, w - 2, 1, inner, hx)
    rect(img, 1, h - 2, w - 2, h - 2, inner, hx)
    rect(img, 1, 1, 1, h - 2, inner, hx)
    rect(img, w - 2, 1, w - 2, h - 2, inner, hx)


def rug_lotus(hx):
    img = solid(32, 32, "indigo", hx)
    for y in range(32):
        for x in range(32):
            dx, dy = x - 15.5, y - 15.5
            r, a = math.hypot(dx, dy), math.atan2(dy, dx)
            petal = 12.5 * (0.5 + 0.5 * abs(math.cos(4 * a)))
            if r < petal:
                dot(img, x, y, "conch", hx)
            if r < petal * 0.62:
                dot(img, x, y, "vermilion", hx)
            if r < 4.2:
                dot(img, x, y, "orpiment", hx)
            if r < 1.9:
                dot(img, x, y, "turquoise", hx)
            if abs(math.cos(4 * a)) < 0.12 and 5 < r < 12.5:
                dot(img, x, y, "indigo", hx)
    frame(img, hx)
    return img


def rug_diamond(hx):
    img = solid(32, 32, "indigo", hx)
    bands = [(3.2, "orpiment"), (6.2, "vermilion"), (9.2, "conch"), (12.2, "turquoise"), (15.2, "lapis")]
    for y in range(32):
        for x in range(32):
            d = abs(x - 15.5) + abs(y - 15.5)
            for limit, name in bands:
                if d < limit * 1.4:
                    dot(img, x, y, name, hx)
                    break
            else:
                if (x // 3 + y // 3) % 2 == 0 and d > 22:
                    dot(img, x, y, "madder", hx)
    rect(img, 15, 15, 16, 16, "conch", hx)
    frame(img, hx, outer="orpiment", inner="indigo")
    return img


def rug_cloud(hx):
    img = solid(32, 32, "madder", hx)
    for y in range(32):
        for x in range(32):
            dx, dy = x - 15.5, y - 15.5
            r, a = math.hypot(dx, dy), math.atan2(dy, dx)
            wave = 1.6 * math.sin(8 * a)
            if r < 13.5 + wave:
                dot(img, x, y, "ink", hx)
            if r < 12.0 + wave:
                dot(img, x, y, "turquoise", hx)
            if r < 8.8 + wave * 0.6:
                dot(img, x, y, "turquoise_light", hx)
            if r < 6.4:
                dot(img, x, y, "lapis_deep", hx)
            if r < 4.2:
                dot(img, x, y, "orpiment", hx)
            if r < 1.8:
                dot(img, x, y, "coral", hx)
    frame(img, hx, outer="orpiment", inner="ink")
    return img


# ------------------------------------------------------------------ trim bands ------------------------------------
def band_stair(hx):
    img = solid(8, 32, "lapis_deep", hx)
    rect(img, 0, 0, 31, 0, "conch", hx)
    rect(img, 0, 7, 31, 7, "conch", hx)
    for x in range(32):
        p = x % 16
        level = min(p, 15 - p) // 2
        rect(img, x, 5 - level, x, 6, "vermilion", hx)
        dot(img, x, 5 - level, "orpiment", hx)
    return img


def band_wave(hx):
    img = solid(8, 32, "turquoise", hx)
    for x in range(32):
        y = 3.5 + 2.2 * math.sin(x * 2 * math.pi / 16)
        for yy in range(8):
            if abs(yy - y) < 0.9:
                dot(img, x, yy, "conch", hx)
            elif yy > y + 0.9:
                dot(img, x, yy, "lapis", hx)
    rect(img, 0, 0, 31, 0, "ink", hx)
    rect(img, 0, 7, 31, 7, "ink", hx)
    return img


def band_dots(hx):
    img = solid(8, 32, "ink", hx)
    rect(img, 0, 1, 31, 1, "gold", hx)
    rect(img, 0, 6, 31, 6, "gold", hx)
    for k in range(4):
        cx = 4 + k * 8
        for dx, dy in ((0, 0), (-1, 0), (1, 0), (0, -1), (0, 1)):
            dot(img, cx + dx, 3 + dy, "conch", hx)
        dot(img, cx, 3, "vermilion", hx)
        dot(img, cx + 4, 3, "orpiment", hx)
        dot(img, cx + 4, 4, "orpiment", hx)
    return img


def band_lotus(hx):
    img = solid(8, 32, "malachite_dark", hx)
    rect(img, 0, 0, 31, 0, "orpiment", hx)
    rect(img, 0, 7, 31, 7, "orpiment", hx)
    for k in range(4):
        cx = 4 + k * 8
        for dy in range(5):
            half = (1, 1, 2, 2, 1)[dy]
            rect(img, cx - half, 1 + dy, cx + half, 1 + dy, "rose", hx)
        dot(img, cx, 5, "vermilion", hx)
        dot(img, cx, 4, "conch", hx)
        dot(img, cx + 4, 3, "malachite", hx)
        dot(img, cx + 3, 4, "malachite", hx)
        dot(img, cx + 5, 4, "malachite", hx)
    return img


# --------------------------------------------------------------- brocade, pierced brass ---------------------------
def brocade_cloud(hx):
    """Diamond lattice with cloud-head trefoils in every cell. Seamless both ways. No creatures."""
    img = solid(32, 32, "lapis_deep", hx)
    for y in range(32):
        for x in range(32):
            if (x + y) % 16 == 0 or (x - y) % 16 == 0:
                dot(img, x, y, "gold", hx)
    for tx, ty in ((0, 8), (0, 24), (8, 0), (8, 16), (16, 8), (16, 24), (24, 0), (24, 16)):
        for ox in (-32, 0, 32):
            for oy in (-32, 0, 32):
                cx, cy = tx + ox, ty + oy
                for lx, ly in ((cx - 2.0, cy + 0.8), (cx + 2.0, cy + 0.8), (cx, cy - 1.6)):
                    disc(img, lx, ly, 1.7, "orpiment", hx)
                dot(img, int(cx), int(cy), "conch", hx)
    for tx, ty in ((8, 8), (24, 24), (8, 24), (24, 8)):
        dot(img, tx, ty, "turquoise", hx)
        dot(img, tx + 1, ty, "turquoise", hx)
    return img


def saddle_pierced(hx):
    """Brass plate with pierced scrollwork: dark holes show the wood behind. A coral bead in the middle."""
    img = solid(32, 32, "brass", hx)
    frame(img, hx, outer="gold", inner="wood_dark")
    for cx, cy, r in ((15.5, 8, 2.6), (15.5, 23, 2.6), (8, 15.5, 2.6), (23, 15.5, 2.6),
                      (9, 9, 1.6), (22, 9, 1.6), (9, 22, 1.6), (22, 22, 1.6)):
        disc(img, cx, cy, r, "ink", hx)
    disc(img, 15.5, 15.5, 4.2, "gold", hx)
    disc(img, 15.5, 15.5, 2.8, "coral", hx)
    dot(img, 14, 14, "conch", hx)
    return img


def build(hex_rgb):
    tiles = []
    # Order matters, append only. Mid-tone faces first (they are the default heads).
    for face in ("young", "old", "woman", "woman_old", "soot"):
        tiles.append(("face_" + face, paint_face(face, "", hex_rgb)))
    tiles += [
        ("rug_lotus", rug_lotus(hex_rgb)), ("rug_diamond", rug_diamond(hex_rgb)), ("rug_cloud", rug_cloud(hex_rgb)),
        ("band_stair", band_stair(hex_rgb)), ("band_wave", band_wave(hex_rgb)),
        ("band_dots", band_dots(hex_rgb)), ("band_lotus", band_lotus(hex_rgb)),
        ("brocade_cloud", brocade_cloud(hex_rgb)),
        ("saddle_pierced", saddle_pierced(hex_rgb)),
    ]
    for tone in ("_lt", "_dp"):
        for face in ("young", "old", "woman", "woman_old", "soot"):
            tiles.append(("face_" + face + tone, paint_face(face, tone, hex_rgb)))
    return tiles
