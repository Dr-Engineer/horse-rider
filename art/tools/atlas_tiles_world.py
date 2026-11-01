"""Pixel-painted world tiles (flags, walls, stone). Append new tiles to the end of the list.

Prayer flags: always in order blue, white, red, green, yellow, each printed with one abstract wind-horse block print
and no text, no corner animals, no deity.
"""
import numpy as np

import atlas_palette

PAL = dict(atlas_palette.COLORS)

# One abstract wind-horse in a 12 x 11 block, with a single jewel dot above its back. Drawn by hand, nothing written.
HORSE = [
    "......##....",
    ".....####...",
    "..#..#####..",
    ".###.#####..",
    ".##########.",
    ".##########.",
    "..########..",
    "...##..##...",
    "...##..##...",
    "..##....##..",
    "..#......#..",
]
JEWEL = (5, 0)


def _flag(hx, base, ink_mix):
    w, h = 16, 22
    img = np.zeros((h, w, 3), np.uint8)
    base_rgb = np.array(hx(PAL[base]), dtype=float)
    ink_rgb = np.array(hx(PAL["ink"]), dtype=float)
    img[:, :] = base_rgb.astype(np.uint8)
    # A slightly darker hem line and a lighter top edge where the cloth is stitched to the string.
    img[0:2, :] = (base_rgb * 0.82).astype(np.uint8)
    img[h - 1, :] = (base_rgb * 0.88).astype(np.uint8)
    print_rgb = (base_rgb * (1.0 - ink_mix) + ink_rgb * ink_mix).astype(np.uint8)
    ox, oy = 2, 6
    for y, row in enumerate(HORSE):
        for x, ch in enumerate(row):
            if ch == "#":
                img[oy + y, ox + x] = print_rgb
    img[oy - 3, ox + JEWEL[0] + 3] = print_rgb
    img[oy - 3, ox + JEWEL[0] + 4] = print_rgb
    return img


def build(hex_rgb):
    tiles = []
    for name, base, mix in (("flag_blue", "lapis", 0.62), ("flag_white", "chalk", 0.8), ("flag_red", "vermilion", 0.7),
                            ("flag_green", "malachite", 0.7), ("flag_yellow", "orpiment", 0.78)):
        tiles.append((name, _flag(hex_rgb, base, mix)))
    return tiles
