"""Paints the small pixel icons used by the HUD and menus into assets/ui/icons/ (16x16 PNG, ink outlined).

Weapons, shield, ammo, silver coin, scarf and a few marks. Everything is drawn from primitives, so any of
them can be restyled by editing this file. Run: /usr/bin/python3 -I art/tools/make_ui_icons.py
"""
import os
import struct
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT_DIR = os.path.join(ROOT, "assets", "ui", "icons")

PAL = {
    "ink": "#17131A", "soot": "#2B2630", "charcoal": "#453D46", "slate": "#6B6570", "ash": "#9B9595",
    "bone": "#D9CDB2", "chalk": "#EFE6D2", "conch": "#FBF5E6",
    "vermilion": "#D63A22", "cinnabar": "#9E2418", "madder": "#7A1C22", "orpiment": "#F2B632", "gold": "#D9A227",
    "amber": "#C47A1A", "ochre": "#C9953F", "malachite": "#2E9E78", "turquoise": "#2FB7B0", "lapis": "#1F4FA8",
    "azure": "#4A8FD9", "saffron": "#E8871E", "coral": "#E0603F", "umber": "#5A3D2B", "sienna": "#8C5A33",
    "tan": "#B98D5A", "sand": "#D8BE8E", "skin": "#B97F54", "skin_light": "#D19A6E", "wood_light": "#A8743F",
    "wood_dark": "#6A4427", "iron": "#4F5560", "steel": "#A9B4BF", "silver": "#D6DDE3", "brass": "#C9A441",
    "leather": "#6E4526", "rock_grey": "#7D7A78", "snow": "#F6FBFF",
}


def rgb(name):
    h = PAL[name].lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


class Icon:
    def __init__(self, size=16):
        self.size = size
        self.px = {}

    def dot(self, x, y, c):
        if 0 <= x < self.size and 0 <= y < self.size:
            self.px[(int(x), int(y))] = rgb(c)

    def line(self, x0, y0, x1, y1, c, width=1):
        dx, dy = abs(x1 - x0), -abs(y1 - y0)
        sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
        err = dx + dy
        while True:
            self.dot(x0, y0, c)
            if width > 1:
                self.dot(x0 + 1, y0, c)
            if x0 == x1 and y0 == y1:
                break
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                x0 += sx
            if e2 <= dx:
                err += dx
                y0 += sy

    def rect(self, x, y, w, h, c):
        for j in range(h):
            for i in range(w):
                self.dot(x + i, y + j, c)

    def disc(self, cx, cy, r, c):
        for j in range(-r, r + 1):
            for i in range(-r, r + 1):
                if i * i + j * j <= r * r + r * 0.6:
                    self.dot(cx + i, cy + j, c)

    def outline(self, c="ink"):
        add = {}
        for (x, y) in self.px:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                p = (x + dx, y + dy)
                if p not in self.px and 0 <= p[0] < self.size and 0 <= p[1] < self.size:
                    add[p] = rgb(c)
        self.px.update(add)

    def bytes(self):
        out = bytearray(self.size * self.size * 4)
        for (x, y), col in self.px.items():
            o = (y * self.size + x) * 4
            out[o:o + 4] = bytes(col + (255,))
        return bytes(out)


def save_png(path, size, pixels):
    raw = bytearray()
    for y in range(size):
        raw.append(0)
        raw.extend(pixels[y * size * 4:(y + 1) * size * 4])

    def chunk(tag, data):
        body = tag + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)

    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0)))
        f.write(chunk(b"IDAT", zlib.compress(bytes(raw), 9)))
        f.write(chunk(b"IEND", b""))


def sword():
    i = Icon()
    i.line(6, 9, 13, 2, "steel", 2)
    i.line(7, 9, 13, 3, "silver")
    i.dot(14, 1, "silver")
    i.line(4, 8, 8, 12, "gold")
    i.line(5, 8, 8, 11, "brass")
    i.line(5, 11, 2, 14, "leather")
    i.line(6, 11, 3, 14, "wood_dark")
    i.dot(2, 14, "coral")
    return i


def knife():
    i = Icon()
    i.line(7, 8, 12, 3, "steel", 2)
    i.line(8, 8, 12, 4, "silver")
    i.line(5, 8, 9, 12, "brass")
    i.line(5, 11, 3, 13, "bone")
    i.line(6, 11, 4, 13, "chalk")
    return i


def pencase():
    i = Icon()
    i.line(3, 12, 11, 4, "iron", 2)
    i.line(4, 12, 11, 5, "steel")
    i.line(11, 4, 13, 2, "coral", 2)
    i.line(3, 12, 2, 13, "gold")
    return i


def whip():
    i = Icon()
    i.line(2, 13, 5, 10, "leather", 2)
    for (x, y) in ((6, 9), (7, 8), (8, 8), (9, 9), (10, 9), (11, 8), (12, 6), (12, 4), (11, 3), (10, 3)):
        i.dot(x, y, "tan")
    i.dot(10, 4, "umber")
    i.dot(9, 3, "umber")
    return i


def key():
    i = Icon()
    i.disc(11, 4, 3, "iron")
    i.disc(11, 4, 1, "ink")
    i.line(9, 6, 4, 11, "steel", 2)
    i.line(4, 11, 4, 14, "steel")
    i.line(5, 12, 7, 12, "steel")
    i.line(3, 3, 6, 6, "vermilion")
    i.dot(2, 2, "vermilion")
    return i


def spear():
    i = Icon()
    i.line(2, 14, 11, 5, "wood_light")
    i.line(3, 14, 11, 6, "wood_dark")
    i.line(10, 6, 14, 2, "steel", 2)
    i.line(11, 6, 14, 3, "silver")
    i.dot(13, 5, "vermilion")
    i.dot(12, 6, "vermilion")
    i.dot(11, 7, "vermilion")
    return i


def roped_spear():
    i = Icon()
    i.line(5, 11, 12, 4, "wood_light")
    i.line(11, 5, 14, 2, "steel", 2)
    i.dot(13, 5, "vermilion")
    for (x, y) in ((2, 10), (1, 12), (2, 14), (4, 14), (5, 13), (4, 11), (3, 10)):
        i.dot(x, y, "tan")
    return i


def sling():
    i = Icon()
    i.line(2, 3, 9, 7, "tan")
    i.line(2, 13, 9, 9, "tan")
    i.disc(11, 8, 2, "leather")
    i.dot(11, 8, "rock_grey")
    i.dot(12, 8, "ash")
    i.dot(1, 2, "vermilion")
    i.dot(1, 14, "vermilion")
    return i


def bow():
    i = Icon()
    for (x, y) in ((11, 1), (9, 2), (7, 3), (6, 5), (5, 7), (5, 8), (6, 10), (7, 12), (9, 13), (11, 14)):
        i.dot(x, y, "wood_light")
        i.dot(x + 1, y, "wood_dark")
    i.line(12, 2, 12, 13, "chalk")
    i.line(4, 8, 14, 8, "tan")
    i.dot(14, 8, "steel")
    return i


def shield():
    i = Icon()
    i.disc(8, 8, 6, "wood_light")
    i.disc(8, 8, 5, "tan")
    i.line(3, 8, 13, 8, "wood_dark")
    i.line(8, 3, 8, 13, "wood_dark")
    i.disc(8, 8, 2, "brass")
    i.dot(8, 8, "gold")
    return i


def fists():
    i = Icon()
    i.rect(4, 5, 9, 6, "skin_light")
    i.rect(4, 5, 9, 1, "skin")
    for x in (6, 8, 10):
        i.line(x, 6, x, 8, "skin")
    i.rect(5, 11, 7, 2, "skin")
    i.rect(3, 8, 2, 3, "skin_light")
    return i


def kick():
    i = Icon()
    i.rect(5, 2, 4, 8, "skin_light")
    i.rect(5, 8, 4, 2, "leather")
    i.rect(5, 10, 8, 3, "leather")
    i.rect(5, 12, 9, 1, "umber")
    i.rect(12, 10, 2, 2, "wood_dark")
    return i


def arrow():
    i = Icon()
    i.line(2, 13, 12, 3, "wood_light")
    i.line(11, 4, 14, 1, "steel", 2)
    i.line(2, 13, 4, 11, "vermilion")
    i.line(2, 11, 4, 13, "vermilion")
    return i


def stone():
    i = Icon()
    i.disc(8, 8, 4, "rock_grey")
    i.dot(6, 6, "ash")
    i.dot(7, 6, "ash")
    i.dot(10, 10, "slate")
    return i


def coin():
    i = Icon()
    i.disc(8, 8, 6, "orpiment")
    i.disc(8, 8, 4, "gold")
    i.rect(7, 7, 2, 2, "ink")
    i.dot(5, 5, "conch")
    i.dot(6, 4, "conch")
    return i


def scarf():
    i = Icon()
    for x in range(1, 15):
        y = 5 + (1 if (x // 3) % 2 else 0)
        i.dot(x, y, "conch")
        i.dot(x, y + 1, "conch")
        i.dot(x, y + 2, "chalk")
    for (x, y) in ((1, 9), (3, 10), (5, 9), (12, 9), (14, 10)):
        i.dot(x, y, "chalk")
    i.dot(0, 5, "chalk")
    return i


def flag_mark():
    i = Icon()
    i.line(3, 2, 3, 14, "wood_dark")
    i.rect(4, 3, 9, 7, "orpiment")
    i.line(12, 3, 12, 9, "gold")
    return i


def horse():
    i = Icon()
    i.rect(3, 6, 9, 5, "sienna")
    i.rect(10, 3, 3, 5, "sienna")
    i.rect(12, 4, 3, 3, "tan")
    i.dot(13, 4, "ink")
    i.rect(3, 11, 2, 3, "umber")
    i.rect(9, 11, 2, 3, "umber")
    i.line(9, 2, 10, 5, "ink")
    i.line(2, 6, 1, 10, "ink")
    return i


def lock():
    i = Icon()
    i.rect(4, 7, 8, 7, "gold")
    i.rect(5, 3, 1, 4, "steel")
    i.rect(10, 3, 1, 4, "steel")
    i.rect(5, 2, 6, 1, "steel")
    i.rect(7, 9, 2, 3, "ink")
    return i


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    icons = {
        "sword": sword, "knife": knife, "pencase": pencase, "whip": whip, "key": key, "spear": spear,
        "roped_spear": roped_spear, "sling": sling, "bow": bow, "shield": shield, "fists": fists, "kick": kick,
        "arrow": arrow, "stone": stone, "coin": coin, "scarf": scarf, "flag_mark": flag_mark, "horse": horse,
        "lock": lock,
    }
    for name, fn in icons.items():
        ic = fn()
        ic.outline("ink")
        save_png(os.path.join(OUT_DIR, name + ".png"), 16, ic.bytes())
    print("icons:", len(icons))


if __name__ == "__main__":
    main()
