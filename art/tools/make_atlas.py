"""Paints assets/atlas/atlas.png and writes atlas.json with every cell and tile.

Run with Blender's bundled Python (it has numpy):
  "/Applications/Blender 5.2.app/Contents/Resources/5.2/python/bin/python3.13" -I art/tools/make_atlas.py
"""
import json
import os
import struct
import sys
import zlib

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import atlas_palette  # noqa: E402
import atlas_tiles  # noqa: E402
import atlas_tiles_world  # noqa: E402

SIZE = 1024
CELL = 32
# Character tiles fill from below the palette, world tiles from here. Separate regions mean that adding a
# tile in one module can't shift the other's UVs, which are baked into exported models.
WORLD_TILES_Y = 576
OUT_DIR = os.path.join(ROOT, "assets", "atlas")


def hex_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def save_png(path, img):
    height, width, _ = img.shape
    raw = b"".join(b"\x00" + img[y].tobytes() for y in range(height))

    def chunk(tag, data):
        body = tag + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)

    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)))
        f.write(chunk(b"IDAT", zlib.compress(raw, 9)))
        f.write(chunk(b"IEND", b""))


def main():
    img = np.zeros((SIZE, SIZE, 4), dtype=np.uint8)
    img[:, :] = (255, 255, 255, 255)
    cells = {}

    # Row 0: team slots, grey values multiplied by per-instance colours in the shader.
    for col, (name, grey) in enumerate(atlas_palette.TEAM_CELLS):
        x, y = col * CELL, 0
        img[y:y + CELL, x:x + CELL] = (grey, grey, grey, 255)
        cells[name] = [x, y, CELL, CELL]

    # Rows 1+: named palette colours.
    col, row = 0, 1
    for name, value in atlas_palette.COLORS:
        x, y = col * CELL, row * CELL
        r, g, b = hex_rgb(value)
        img[y:y + CELL, x:x + CELL] = (r, g, b, 255)
        cells[name] = [x, y, CELL, CELL]
        col += 1
        if col >= SIZE // CELL:
            col, row = 0, row + 1

    # Shelf-pack painted tiles below the palette. Append new tiles to the end of a module's list.
    tiles = {}
    used = 0
    for builder, start_y, limit_y in (
        (atlas_tiles, (row + 1) * CELL, WORLD_TILES_Y),
        (atlas_tiles_world, WORLD_TILES_Y, SIZE),
    ):
        shelf_y, shelf_x, shelf_h = start_y, 0, 0
        for name, painted in builder.build(hex_rgb):
            height, width = painted.shape[:2]
            if shelf_x + width + 2 > SIZE:
                shelf_x = 0
                shelf_y += shelf_h + 2
                shelf_h = 0
            if shelf_y + height > limit_y:
                raise RuntimeError("Atlas region is full at tile " + name)
            rgba = np.zeros((height, width, 4), dtype=np.uint8)
            rgba[:, :, :3] = painted[:, :, :3]
            rgba[:, :, 3] = 255
            img[shelf_y:shelf_y + height, shelf_x:shelf_x + width] = rgba
            tiles[name] = [shelf_x, shelf_y, width, height]
            shelf_x += width + 2
            shelf_h = max(shelf_h, height)
        used = shelf_y + shelf_h

    os.makedirs(OUT_DIR, exist_ok=True)
    save_png(os.path.join(OUT_DIR, "atlas.png"), img)
    with open(os.path.join(OUT_DIR, "atlas.json"), "w") as f:
        json.dump({"size": [SIZE, SIZE], "cell": CELL, "cells": cells, "tiles": tiles}, f, indent=0)
    print("atlas: %d cells, %d tiles, used to y=%d of %d" % (len(cells), len(tiles), used, SIZE))


if __name__ == "__main__":
    main()
