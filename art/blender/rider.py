"""Rider: rig, wardrobe and animations. Exports assets/models/rider.glb.

Every wardrobe piece is its own skinned mesh on one rig; the game shows the pieces each rider wears.
Skin: each head comes in three tones (head_x, head_x_lt, head_x_dp). The neck and both hands live in the head mesh,
so one choice sets all bare skin. Bare skin on a body (knees) uses slot C (cell c1), so set slot_c to the same tone.
Hats and caps colour with slot B (b1 light, b2 mid, b3 dark) and keep fixed accents (fur, brass, red tassels).
"""
import importlib
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit  # noqa: E402

importlib.reload(kit)
from kit import Builder, Ring, lerp, mirror_x  # noqa: E402
from mathutils import Euler, Vector  # noqa: E402

HX = 0.11
ROOT_Z = kit.SADDLE_Z - 0.9   # rider root height in horse space (the rider node hangs 0.9 below the saddle bone)

BONES = [
    ("root", None, (0, 0, 0), (0, 0, 0.2)),
    ("hips", "root", (0, 0, 0.92), (0, 0, 1.05)),
    ("spine", "hips", (0, 0, 1.05), (0, 0, 1.25)),
    ("chest", "spine", (0, 0, 1.25), (0, 0, 1.45)),
    ("neck", "chest", (0, 0, 1.45), (0, 0, 1.54)),
    ("head", "neck", (0, 0, 1.54), (0, 0, 1.86)),
    ("braid1", "head", (0, -0.1, 1.68), (0, -0.14, 1.48)),
    ("braid2", "braid1", (0, -0.14, 1.48), (0, -0.16, 1.26)),
]
for s, sg in (("R", 1), ("L", -1)):
    BONES += [
        ("arm_u." + s, "chest", (sg * 0.235, 0, 1.415), (sg * 0.27, 0, 1.13)),
        ("arm_l." + s, "arm_u." + s, (sg * 0.27, 0, 1.13), (sg * 0.29, 0, 0.87)),
        ("hand." + s, "arm_l." + s, (sg * 0.29, 0, 0.87), (sg * 0.3, 0, 0.77)),
        ("grip." + s, "hand." + s, (sg * 0.3, 0.0, 0.79), (sg * 0.3, 0.15, 0.79)),
        ("thigh." + s, "hips", (sg * HX, 0, 0.92), (sg * HX, 0, 0.5)),
        ("shin." + s, "thigh." + s, (sg * HX, 0, 0.5), (sg * HX, 0, 0.1)),
        ("foot." + s, "shin." + s, (sg * HX, 0, 0.1), (sg * HX, 0.2, 0.03)),
    ]

SKIN = {"": "skin", "_lt": "skin_light", "_dp": "skin_deep"}
HEAD_ROWS = [
    (1.50, 0.052, 0.056), (1.565, 0.078, 0.086), (1.625, 0.108, 0.112), (1.70, 0.115, 0.12),
    (1.775, 0.11, 0.118), (1.835, 0.078, 0.086), (1.872, 0.03, 0.034),
]


def head_r(z):
    if z <= HEAD_ROWS[0][0]:
        return HEAD_ROWS[0][1], HEAD_ROWS[0][2]
    for (z0, a0, b0), (z1, a1, b1) in zip(HEAD_ROWS, HEAD_ROWS[1:]):
        if z <= z1:
            t = (z - z0) / (z1 - z0)
            return lerp(a0, a1, t), lerp(b0, b1, t)
    return HEAD_ROWS[-1][1], HEAD_ROWS[-1][2]


def retile(b, start, count, tile, reps=1):
    """Give `count` quads from face `start` the whole tile each (u along the ring, v up)."""
    for fi in range(start, start + count):
        if len(b.faces[fi]) != 4:
            continue
        b.loop_uvs[fi] = [kit.tile_uv(tile, 0, 0), kit.tile_uv(tile, reps, 0), kit.tile_uv(tile, reps, 1), kit.tile_uv(tile, 0, 1)]


# ---------------------------------------------------------------- heads --------------------------------------------
def add_hands(b, skin):
    def hand(side, sg):
        b.loft([
            Ring((sg * 0.29, 0, 0.89), 0.044, 0.05, up=(0, 1, 0)),
            Ring((sg * 0.297, 0.012, 0.83), 0.058, 0.066, up=(0, 1, 0)),
            Ring((sg * 0.3, 0.02, 0.77), 0.048, 0.06, up=(0, 1, 0)),
            Ring((sg * 0.3, 0.02, 0.735), 0.022, 0.034, up=(0, 1, 0)),
        ], n=6, cell=skin, w="hand." + side)

    mirror_x(hand)


def add_head(b, face, tone=""):
    skin = SKIN[tone]
    tile = "face_" + face + tone
    rings = [Ring((0, 0.008, z), rx, ry, up=(0, 1, 0)) for z, rx, ry in HEAD_ROWS]
    start_face = len(b.faces)
    b.loft(rings, n=10, cell=skin, w="head", axis=(0, 0, 1), up=(0, 1, 0))
    z0, z1, half = 1.575, 1.80, 0.112
    for fi in range(start_face, len(b.faces)):
        pts = [b.co[i] for i in b.faces[fi]]
        cy = sum(p.y for p in pts) / len(pts)
        cz = sum(p.z for p in pts) / len(pts)
        cx = sum(p.x for p in pts) / len(pts)
        if cy > 0.03 and z0 < cz < z1 and abs(cx) < half:
            b.loop_uvs[fi] = [
                kit.tile_uv(tile, max(0.0, min(1.0, 0.5 + p.x / (2 * half))), max(0.0, min(1.0, (p.z - z0) / (z1 - z0))))
                for p in pts
            ]
    b.box((0, 0.135, 1.665), (0.04, 0.05, 0.075), cell=skin, w="head", taper=(0.6, 0.55))
    mirror_x(lambda side, sg: b.box((sg * 0.118, 0.005, 1.685), (0.025, 0.045, 0.07), cell=skin, w="head"))
    b.loft([
        Ring((0, 0.0, 1.40), 0.064, 0.064, w="neck", up=(0, 1, 0)),
        Ring((0, 0.004, 1.51), 0.06, 0.062, w={"neck": 0.5, "head": 0.5}, up=(0, 1, 0)),
    ], n=8, cell=skin, axis=(0, 0, 1), up=(0, 1, 0), cap_start=False, cap_end=False)
    add_hands(b, skin)


# ---------------------------------------------------------------- bodies -------------------------------------------
def add_sleeves(b, sleeve_r="a1", sleeve_l="a1", cuff="b1", fat=1.0, flare=0.0, cuff_z=0.875, tile=None):
    def arm(side, sg):
        sleeve = sleeve_r if sg > 0 else sleeve_l
        k = fat
        start = len(b.faces)
        b.loft([
            Ring((sg * 0.225, 0, 1.44), 0.075 * k, 0.085 * k, up=(0, 1, 0), w="chest"),
            Ring((sg * 0.245, 0, 1.36), 0.082 * k, 0.09 * k, up=(0, 1, 0), w="arm_u." + side),
            Ring((sg * 0.268, 0, 1.15), 0.066 * k, 0.07 * k, up=(0, 1, 0), w="arm_u." + side),
        ], n=6, cell=sleeve, cap_start=False, cap_end=False)
        if tile:
            retile(b, start, 12, tile)
        b.loft([
            Ring((sg * 0.27, 0, 1.175), 0.066 * k, 0.07 * k, up=(0, 1, 0)),
            Ring((sg * 0.28, 0, 0.99), 0.062 * k + flare * 0.4, 0.065 * k + flare * 0.4, up=(0, 1, 0)),
            Ring((sg * 0.29, 0, 0.91), 0.072 * k + flare, 0.074 * k + flare, up=(0, 1, 0), cell=cuff),
            Ring((sg * 0.29, 0, cuff_z), 0.072 * k + flare, 0.074 * k + flare, up=(0, 1, 0), cell=cuff),
        ], n=6, cell=sleeve, w="arm_l." + side, cap_start=False)

    mirror_x(arm)


def add_boots(b, leg="a3", boot="felt_white", band="vermilion", sole="leather"):
    def leg_fn(side, sg):
        x = sg * HX
        b.loft([
            Ring((x, 0, 0.95), 0.085, 0.1, up=(0, 1, 0), w="thigh." + side),
            Ring((x, 0, 0.72), 0.08, 0.09, up=(0, 1, 0), w="thigh." + side),
            Ring((x + sg * 0.005, 0, 0.52), 0.066, 0.075, up=(0, 1, 0), w="thigh." + side),
        ], n=6, cell=leg, cap_start=False, cap_end=False)
        b.loft([
            Ring((x, 0, 0.52), 0.07, 0.08, up=(0, 1, 0), cell=band),
            Ring((x, 0, 0.46), 0.072, 0.082, up=(0, 1, 0)),
            Ring((x, 0, 0.26), 0.058, 0.066, up=(0, 1, 0)),
            Ring((x, 0, 0.16), 0.06, 0.07, up=(0, 1, 0), cell=band),
            Ring((x, 0.0, 0.1), 0.06, 0.08, up=(0, 1, 0)),
        ], n=6, cell=boot, w="shin." + side)
        # Foot with the upturned toe of a lham boot.
        b.loft([
            Ring((x, -0.06, 0.07), 0.055, 0.06, up=(0, 0, 1)),
            Ring((x, 0.04, 0.065), 0.062, 0.06, up=(0, 0, 1)),
            Ring((x, 0.14, 0.05), 0.05, 0.043, up=(0, 0, 1), cell=band),
            Ring((x, 0.21, 0.075), 0.022, 0.018, up=(0, 0, 1), cell=band),
            Ring((x, 0.235, 0.115), 0.006, 0.006, up=(0, 0, 1), cell=band),
        ], n=6, cell=boot, w="foot." + side, axis=None)
        b.box((x, 0.05, 0.012), (0.11, 0.27, 0.024), cell=sole, w="foot." + side)

    mirror_x(leg_fn)


def skirt_weights(x, t):
    """t 0 at the belt, 1 at the hem. The hem follows the thighs when seated."""
    side = "R" if x > 0 else "L"
    k = abs(x) / 0.2
    amount = min(1.0, k) * t
    return {"hips": 1.0 - amount, "thigh." + side: amount}


def add_robe(b, main="a1", shade="a2", trim="b1", sash="b2", collar_trim=True, hem_tile=None, fat=1.0, hem_z=0.5, flare=1.0):
    """Chuba: bloused above a sash with a flaring split skirt."""
    k = fat
    upper = [
        Ring((0, 0, 1.47), 0.06, 0.06, w="neck", up=(0, 1, 0)),
        Ring((0, 0.005, 1.445), 0.14 * k, 0.105 * k, w="chest", up=(0, 1, 0)),
        Ring((0, 0.0, 1.40), 0.25 * k, 0.135 * k, w="chest", up=(0, 1, 0)),
        Ring((0, 0.012, 1.28), 0.235 * k, 0.158 * k, w={"chest": 0.6, "spine": 0.4}, up=(0, 1, 0)),
        Ring((0, 0.02, 1.15), 0.225 * k, 0.165 * k, w={"spine": 0.8, "hips": 0.2}, up=(0, 1, 0)),
        Ring((0, 0.02, 1.06), 0.205 * k, 0.15 * k, w={"spine": 0.3, "hips": 0.7}, up=(0, 1, 0)),
    ]
    b.loft(upper, n=10, cell=main, axis=(0, 0, 1), up=(0, 1, 0), cap_end=False, cap_start=True)
    b.loft([
        Ring((0, 0.015, 1.09), 0.205 * k, 0.155 * k, w="hips", up=(0, 1, 0)),
        Ring((0, 0.015, 1.0), 0.215 * k, 0.16 * k, w="hips", up=(0, 1, 0)),
    ], n=10, cell=sash, axis=(0, 0, 1), up=(0, 1, 0), cap_start=True, cap_end=False)
    rows = [
        (1.0, 0.222, 0.165, 0.0),
        (lerp(1.0, hem_z, 0.36), 0.27 * flare, 0.2 * flare, 0.35),
        (lerp(1.0, hem_z, 0.76), 0.305 * flare, 0.235 * flare, 0.7),
        (hem_z, 0.325 * flare, 0.25 * flare, 1.0),
    ]
    n = 12
    idx = []
    for z, rx, ry, t in rows:
        row = []
        for kk in range(n):
            a = 2 * math.pi * kk / n
            x, y = math.cos(a) * rx, 0.01 + math.sin(a) * ry
            row.append(b.vert((x, y, z), skirt_weights(x, t)))
        idx.append(row)
    for i in range(len(rows) - 1):
        for kk in range(n):
            k2 = (kk + 1) % n
            b.face((idx[i + 1][kk], idx[i + 1][k2], idx[i][k2], idx[i][kk]), cell=main if i < len(rows) - 2 else shade)
    hem = []
    for z, grow in ((hem_z + 0.06, 1.03), (hem_z - 0.02, 1.05)):
        row = []
        for kk in range(n):
            a = 2 * math.pi * kk / n
            x, y = math.cos(a) * 0.325 * flare * grow, 0.01 + math.sin(a) * 0.25 * flare * grow
            row.append(b.vert((x, y, z), skirt_weights(x, 1.0)))
        hem.append(row)
    for kk in range(n):
        k2 = (kk + 1) % n
        quad = (hem[1][kk], hem[1][k2], hem[0][k2], hem[0][kk])
        if hem_tile:
            b.face(quad, uvs=[kit.tile_uv(hem_tile, 0, 0), kit.tile_uv(hem_tile, 1, 0), kit.tile_uv(hem_tile, 1, 1), kit.tile_uv(hem_tile, 0, 1)])
        else:
            b.face(quad, cell=trim)
    if collar_trim:
        b.loft([
            Ring((-0.075, 0.098, 1.44), 0.022, 0.012, up=(0, 1, 0)),
            Ring((0.02, 0.135, 1.34), 0.024, 0.012, up=(0, 1, 0)),
            Ring((0.145, 0.152, 1.2), 0.024, 0.012, up=(0, 1, 0)),
            Ring((0.19, 0.12, 1.09), 0.022, 0.012, up=(0, 1, 0)),
        ], n=4, cell=trim, w="chest")


def add_collar(b, cell="b1"):
    """A small stand collar: hides the neck join so the head sits chunky on the shoulders."""
    b.loft([
        Ring((0, 0.005, 1.435), 0.14, 0.115, w="chest", up=(0, 1, 0)),
        Ring((0, 0.005, 1.49), 0.088, 0.08, w="neck", up=(0, 1, 0)),
        Ring((0, 0.005, 1.525), 0.074, 0.072, w="neck", up=(0, 1, 0), cell="gold" if cell == "b1" else cell),
    ], n=10, cell=cell, axis=(0, 0, 1), up=(0, 1, 0), cap_start=False, cap_end=False)


def body_chuba(b):
    add_collar(b)
    add_robe(b, hem_tile="band_stair")
    add_sleeves(b)
    add_boots(b)


def body_oneoff(b):
    """Chuba with the right sleeve pulled off the shoulder: bright shirt arm and a sleeve tied at the waist."""
    add_collar(b, "b1")
    add_robe(b, hem_tile="band_dots", collar_trim=False)
    add_sleeves(b, sleeve_r="b1", sleeve_l="a1", cuff="b2")
    b.sphere((0.225, 0, 1.4), (0.105, 0.1, 0.09), cell="b1", w={"chest": 0.5, "arm_u.R": 0.5}, segs=7, rings=4)
    # Bare shoulder edge: the robe's collar cuts across the chest to the left.
    b.loft([
        Ring((0.13, 0.1, 1.44), 0.026, 0.014, up=(0, 1, 0)),
        Ring((0.03, 0.14, 1.33), 0.028, 0.014, up=(0, 1, 0)),
        Ring((-0.1, 0.155, 1.2), 0.028, 0.014, up=(0, 1, 0)),
        Ring((-0.19, 0.12, 1.09), 0.026, 0.014, up=(0, 1, 0)),
    ], n=4, cell="b2", w="chest")
    # Empty sleeve knotted at the waist, hanging over the right hip.
    b.loft([
        Ring((0.2, 0.1, 1.1), 0.05, 0.05, w="hips", up=(0, 0, 1)),
        Ring((0.27, 0.12, 0.98), 0.085, 0.07, w={"hips": 0.6, "thigh.R": 0.4}, up=(0, 0, 1)),
        Ring((0.31, 0.12, 0.8), 0.08, 0.06, w={"hips": 0.3, "thigh.R": 0.7}, up=(0, 0, 1), cell="b2"),
        Ring((0.31, 0.12, 0.74), 0.085, 0.065, w="thigh.R", up=(0, 0, 1)),
    ], n=6, cell="a1", axis=(0, 0, 1))
    add_boots(b, boot="sand", band="b1")


def body_fleece(b):
    """Long-sleeved lokbar: bulky, hem to the calf, sheepskin collar and wide hanging cuffs."""
    add_robe(b, main="a1", shade="a2", trim="sheepskin", sash="b2", collar_trim=False, hem_tile="band_wave", fat=1.14,
             hem_z=0.38, flare=1.1)
    add_sleeves(b, cuff="sheepskin", fat=1.12, flare=0.045, cuff_z=0.8)
    b.loft([
        Ring((0, 0.01, 1.53), 0.105, 0.105, w="neck", up=(0, 1, 0)),
        Ring((0, 0.01, 1.47), 0.15, 0.13, w="chest", up=(0, 1, 0)),
        Ring((0, 0.01, 1.4), 0.2, 0.15, w="chest", up=(0, 1, 0)),
    ], n=10, cell="sheepskin", axis=(0, 0, 1), up=(0, 1, 0), cap_start=False, cap_end=False)
    add_boots(b, boot="tan", band="b1")


def body_hide(b):
    """Hide robe hitched up to bare knees, rope belt, shaggy hem."""
    add_robe(b, main="a1", shade="a2", trim="yak_brown", sash="leather", collar_trim=False, fat=1.06, hem_z=0.68, flare=0.9)
    add_sleeves(b, cuff="yak_brown")
    # Bare knees come from the leg cell; shaggy hem tufts.
    n = 12
    for kk in range(n):
        a = 2 * math.pi * (kk + 0.5) / n
        x, y = math.cos(a) * 0.3, 0.01 + math.sin(a) * 0.23
        b.cone((x, y, 0.7), (x * 1.04, y * 1.04, 0.6), (0.045, 0.02), n=4, cell="yak_brown", w=skirt_weights(x, 1.0))
    # Rope belt with a knot and fur ruff at the collar.
    b.loft([
        Ring((0, 0.015, 1.12), 0.215, 0.165, w="hips", up=(0, 1, 0)),
        Ring((0, 0.015, 1.07), 0.222, 0.17, w="hips", up=(0, 1, 0)),
    ], n=10, cell="tan", axis=(0, 0, 1), up=(0, 1, 0), cap_start=False, cap_end=False)
    b.loft([
        Ring((0, 0.01, 1.5), 0.1, 0.1, w="neck", up=(0, 1, 0)),
        Ring((0, 0.01, 1.42), 0.17, 0.14, w="chest", up=(0, 1, 0)),
    ], n=10, cell="yak_brown", axis=(0, 0, 1), up=(0, 1, 0), cap_start=False, cap_end=False)
    add_boots(b, leg="c1", boot="yak_brown", band="tan")


def body_brocade(b):
    """Stiff court robe: square shoulders, tall collar, bell skirt in cloud brocade, gold belt."""
    tile = "brocade_cloud"
    start = len(b.faces)
    upper = [
        Ring((0, 0.005, 1.445), 0.15, 0.115, w="chest", up=(0, 1, 0)),
        Ring((0, 0.0, 1.40), 0.3, 0.15, w="chest", up=(0, 1, 0), exp=3.2),
        Ring((0, 0.01, 1.27), 0.27, 0.17, w={"chest": 0.6, "spine": 0.4}, up=(0, 1, 0), exp=3.0),
        Ring((0, 0.02, 1.13), 0.235, 0.172, w={"spine": 0.5, "hips": 0.5}, up=(0, 1, 0)),
    ]
    b.loft(upper, n=10, cell="a1", axis=(0, 0, 1), up=(0, 1, 0), cap_start=True, cap_end=False)
    retile(b, start, 30, tile)
    b.loft([
        Ring((0, 0.0, 1.55), 0.1, 0.1, w="neck", up=(0, 1, 0)),
        Ring((0, 0.005, 1.5), 0.115, 0.11, w="neck", up=(0, 1, 0)),
        Ring((0, 0.005, 1.44), 0.16, 0.125, w="chest", up=(0, 1, 0), cell="gold"),
        Ring((0, 0.005, 1.425), 0.17, 0.13, w="chest", up=(0, 1, 0)),
    ], n=10, cell="b1", axis=(0, 0, 1), up=(0, 1, 0), cap_start=False, cap_end=False)
    rows = [(1.05, 0.235, 0.172, 0.0), (0.82, 0.3, 0.22, 0.4), (0.62, 0.36, 0.27, 0.8), (0.42, 0.4, 0.3, 1.0)]
    n = 12
    idx = []
    for z, rx, ry, t in rows:
        row = []
        for kk in range(n):
            a = 2 * math.pi * kk / n
            x, y = math.cos(a) * rx, 0.01 + math.sin(a) * ry
            row.append(b.vert((x, y, z), skirt_weights(x, t)))
        idx.append(row)
    start = len(b.faces)
    for i in range(len(rows) - 1):
        for kk in range(n):
            k2 = (kk + 1) % n
            b.face((idx[i + 1][kk], idx[i + 1][k2], idx[i][k2], idx[i][kk]), cell="a1")
    retile(b, start, (len(rows) - 1) * n, tile)
    hem = []
    for z, grow in ((0.48, 1.0), (0.4, 1.03)):
        row = []
        for kk in range(n):
            a = 2 * math.pi * kk / n
            x, y = math.cos(a) * 0.4 * grow, 0.01 + math.sin(a) * 0.3 * grow
            row.append(b.vert((x, y, z), skirt_weights(x, 1.0)))
        hem.append(row)
    for kk in range(n):
        k2 = (kk + 1) % n
        b.face((hem[1][kk], hem[1][k2], hem[0][k2], hem[0][kk]), cell="b1")
    # Gold belt with coral plaques.
    b.loft([
        Ring((0, 0.02, 1.16), 0.238, 0.178, w={"spine": 0.4, "hips": 0.6}, up=(0, 1, 0)),
        Ring((0, 0.02, 1.07), 0.245, 0.182, w="hips", up=(0, 1, 0)),
    ], n=10, cell="gold", axis=(0, 0, 1), up=(0, 1, 0), cap_start=False, cap_end=False)
    for x in (-0.11, 0.0, 0.11):
        b.box((x, 0.2, 1.115), (0.07, 0.03, 0.08), cell="coral" if x == 0 else "brass", w="hips")
    add_sleeves(b, sleeve_r="a1", sleeve_l="a1", cuff="b1", fat=1.18, flare=0.06, cuff_z=0.82, tile=tile)
    add_boots(b, leg="a3", boot="soot", band="gold")


# ----------------------------------------------------------------- hair and hats -----------------------------------
def dome(b, z_front, z_back, z_top, scale=1.07, cell="d1", n=10, rows=4, w="head", cy=0.008, grow=0.0):
    """A cap that hugs the skull. The lower edge runs from z_front over the brow down to z_back at the nape."""
    idx = []
    for i in range(rows + 1):
        t = i / rows
        row = []
        for k in range(n):
            a = 2 * math.pi * k / n
            s = (math.sin(a) + 1.0) * 0.5
            z = lerp(lerp(z_back, z_front, s), z_top, t ** 0.8)
            rx, ry = head_r(z)
            sc = scale + grow * (1.0 - t)
            row.append(b.vert((math.cos(a) * rx * sc, cy + math.sin(a) * ry * sc, z), w))
        idx.append(row)
    for i in range(rows):
        for k in range(n):
            k2 = (k + 1) % n
            b.face((idx[i][k], idx[i][k2], idx[i + 1][k2], idx[i + 1][k]), cell=cell)
    b.face(idx[-1], cell=cell)


def ring_points(r, z, count=14, cy=0.01, ry=None):
    ry = r if ry is None else ry
    return [(r * math.cos(2 * math.pi * i / count), cy + ry * math.sin(2 * math.pi * i / count), z) for i in range(count + 1)]


def hair_wound(b):
    """Khampa style: hair wound round the head in a thick coil, a top knot, red cord and a long red tassel."""
    dome(b, 1.79, 1.66, 1.86, scale=1.06, rows=3)
    pts = ring_points(0.132, 1.815, 10)
    b.tube(pts, [0.046] * len(pts), n=5, cell="d1", w="head", cap_start=False, cap_end=False)
    b.sphere((0, 0.01, 1.93), (0.085, 0.085, 0.075), cell="d1", w="head", segs=6, rings=3)
    b.loft([Ring((0, 0.01, 1.9), 0.1, 0.1, w="head"), Ring((0, 0.01, 1.87), 0.108, 0.108, w="head")], n=8, cell="vermilion", axis=(0, 0, 1),
           up=(0, 1, 0), cap_start=False, cap_end=False)
    b.loft([
        Ring((0.13, 0.05, 1.8), 0.012, 0.012, up=(0, 1, 0)),
        Ring((0.15, 0.07, 1.66), 0.026, 0.026, up=(0, 1, 0), cell="vermilion"),
        Ring((0.155, 0.075, 1.54), 0.055, 0.05, up=(0, 1, 0), cell="vermilion"),
        Ring((0.155, 0.075, 1.4), 0.04, 0.035, up=(0, 1, 0), cell="cinnabar"),
        Ring((0.155, 0.075, 1.34), 0.01, 0.01, up=(0, 1, 0)),
    ], n=6, cell="vermilion", w={"head": 0.6, "neck": 0.4})


def hair_plaits(b):
    """Two long plaits tied with red, hanging behind; they swing on the braid bones."""
    dome(b, 1.78, 1.64, 1.88, scale=1.06)
    for sg in (1, -1):
        pts = [(sg * 0.082, -0.1, 1.74), (sg * 0.09, -0.15, 1.62), (sg * 0.094, -0.17, 1.46), (sg * 0.096, -0.17, 1.32), (sg * 0.096, -0.165, 1.2), (sg * 0.096, -0.165, 1.14)]
        ws = ["head", {"head": 0.5, "braid1": 0.5}, "braid1", {"braid1": 0.5, "braid2": 0.5}, "braid2", "braid2"]
        cells = ["d1", "d2", "d1", "d2", "vermilion", "vermilion"]
        rings = [Ring(p, 0.04 if i < 4 else 0.036, 0.04 if i < 4 else 0.036, w=ws[i], cell=cells[i]) for i, p in enumerate(pts)]
        b.loft(rings, n=6, cell="d1", w="braid1", up=(0, 1, 0))
        b.loft([
            Ring((sg * 0.096, -0.165, 1.16), 0.02, 0.02, w="braid2", cell="vermilion"),
            Ring((sg * 0.096, -0.165, 1.06), 0.045, 0.04, w="braid2", cell="vermilion"),
            Ring((sg * 0.096, -0.165, 0.97), 0.014, 0.014, w="braid2", cell="cinnabar"),
        ], n=5, cell="vermilion", w="braid2")


def hair_mop(b):
    """Golok style: a big shaggy mop with ragged locks."""
    dome(b, 1.8, 1.52, 1.9, scale=1.2, cell="d1", grow=0.08)
    for i in range(14):
        a = 2 * math.pi * i / 14 + 0.2
        z = 1.74 + 0.07 * math.sin(i * 2.3)
        rx, ry = head_r(z)
        x, y = math.cos(a) * rx * 1.25, 0.01 + math.sin(a) * ry * 1.25
        b.cone((x, y, z), (x * 1.5, y * 1.5 - 0.01, z - 0.08 - 0.05 * (i % 3)), (0.04, 0.03), n=4, cell="d2" if i % 2 else "d1", w="head")
    b.cone((0, 0.0, 1.9), (0.02, -0.03, 2.05), (0.07, 0.06), n=5, cell="d1", w="head")


def hair_short(b):
    """Bhutanese bowl cut: a smooth cap with a straight cut line all round."""
    dome(b, 1.77, 1.6, 1.885, scale=1.075)
    mirror_x(lambda side, sg: b.box((sg * 0.118, 0.035, 1.7), (0.03, 0.05, 0.1), cell="d1", w="head"))


def hair_earlocks(b):
    """Dob-dob style: short hair and two horn-shaped locks standing up over the ears, bound with red."""
    dome(b, 1.78, 1.62, 1.88, scale=1.06)

    def lock(side, sg):
        pts = [(sg * 0.12, 0.0, 1.76), (sg * 0.16, 0.0, 1.84), (sg * 0.19, -0.02, 1.94), (sg * 0.19, -0.05, 2.04), (sg * 0.17, -0.08, 2.1)]
        b.tube(pts, [0.05, 0.046, 0.036, 0.024, 0.008], n=6, cell="d1", w="head", cap_start=False, cap_end=True)
        b.box((sg * 0.145, 0.0, 1.8), (0.1, 0.1, 0.03), cell="vermilion", w="head", rot=(0, sg * 25, 0))

    mirror_x(lock)


def hat(b, prof, n=10, sx=1.0, sy=1.0):
    b.revolve(prof, n=n, w="head", cy=0.01, sx=sx, sy=sy)


def hat_felt(b):
    hat(b, [
        (0.13, 1.742, "b2"), (0.235, 1.752, "b3"), (0.25, 1.79, "b1"), (0.15, 1.772, "b1"), (0.14, 1.8, "b3"),
        (0.142, 1.835, "b1"), (0.134, 1.9, "b1"), (0.108, 1.955, "b1"), (0.06, 1.99, "b1"), (0.02, 2.005, "b1"),
    ])


def hat_big(b):
    """Broad cone hat with a huge brim, brass finial and little bells all round the edge."""
    hat(b, [
        (0.13, 1.74, "b2"), (0.33, 1.715, "b3"), (0.345, 1.73, "b1"), (0.17, 1.82, "b1"), (0.1, 2.0, "b1"),
        (0.045, 2.13, "b1"), (0.018, 2.2, "b1"),
    ], n=12)
    b.sphere((0, 0.01, 2.225), 0.032, cell="brass", w="head", segs=6, rings=3)
    for i in range(8):
        a = 2 * math.pi * (i + 0.5) / 8
        b.sphere((math.cos(a) * 0.345, 0.01 + math.sin(a) * 0.345, 1.69), 0.028, cell="brass", w="head", segs=4, rings=2)


def hat_peak(b):
    """Amdo peaked hat: tall cone, thick white lambskin roll, red tassels down the crown."""
    hat(b, [
        (0.13, 1.742, "sheepskin"), (0.215, 1.745, "sheepskin"), (0.228, 1.8, "sheepskin"), (0.2, 1.835, "sheepskin"),
        (0.15, 1.845, "b1"), (0.125, 1.95, "b1"), (0.07, 2.12, "b1"), (0.03, 2.26, "b1"), (0.012, 2.3, "b1"),
    ])
    b.sphere((0, 0.01, 2.3), 0.04, cell="vermilion", w="head", segs=6, rings=3)
    for i in range(4):
        a = 2 * math.pi * i / 4 + 0.4
        cx, cy = math.cos(a), math.sin(a)
        pts = [(cx * 0.02, 0.01 + cy * 0.02, 2.27), (cx * 0.085, 0.01 + cy * 0.085, 2.11), (cx * 0.14, 0.01 + cy * 0.14, 1.93),
               (cx * 0.245, 0.01 + cy * 0.245, 1.8), (cx * 0.25, 0.01 + cy * 0.25, 1.62), (cx * 0.25, 0.01 + cy * 0.25, 1.5)]
        b.strip(pts, [0.03, 0.04, 0.05, 0.05, 0.05, 0.015], normal=(cx, cy, 0), cell="vermilion", w="head")


def hat_fox(b):
    """Changpa fox-fur hat: thick fur ring, cloth crown, ear flaps and two tails down the back."""
    hat(b, [
        (0.13, 1.742, "fox_fur"), (0.2, 1.742, "fox_fur"), (0.218, 1.8, "fox_fur"), (0.21, 1.87, "sheepskin"),
        (0.15, 1.905, "b1"), (0.13, 1.935, "b1"), (0.1, 1.99, "b1"), (0.04, 2.025, "b1"), (0.015, 2.03, "b1"),
    ], n=10)
    mirror_x(lambda side, sg: b.box((sg * 0.205, 0.0, 1.67), (0.05, 0.12, 0.15), cell="fox_fur", w="head", taper=(0.7, 0.8)))
    for sg in (1, -1):
        b.loft([
            Ring((sg * 0.07, -0.18, 1.86), 0.04, 0.04, cell="fox_fur", up=(0, 1, 0)),
            Ring((sg * 0.09, -0.24, 1.72), 0.055, 0.05, cell="fox_fur", up=(0, 1, 0)),
            Ring((sg * 0.1, -0.26, 1.56), 0.05, 0.045, cell="fox_fur", up=(0, 1, 0)),
            Ring((sg * 0.1, -0.26, 1.46), 0.028, 0.025, cell="soot", up=(0, 1, 0)),
            Ring((sg * 0.1, -0.26, 1.4), 0.006, 0.006, up=(0, 1, 0)),
        ], n=5, cell="fox_fur", w={"head": 0.7, "neck": 0.3})


def hat_basin(b):
    """Lhasa clerk's yellow basin hat: a big upturned bowl with a gold knob."""
    hat(b, [
        (0.13, 1.742, "b2"), (0.19, 1.745, "b3"), (0.21, 1.8, "b1"), (0.2, 1.88, "b1"), (0.15, 1.95, "b1"),
        (0.09, 1.985, "b1"), (0.04, 1.995, "b1"),
    ])
    b.sphere((0, 0.01, 2.01), 0.032, cell="gold", w="head", segs=6, rings=3)


def hat_disc(b):
    """Lhasa official's disc hat: dark fur band under a wide flat disc with a gold knob."""
    hat(b, [
        (0.13, 1.742, "yak_black"), (0.175, 1.745, "yak_black"), (0.19, 1.8, "yak_black"), (0.18, 1.855, "b3"),
        (0.335, 1.855, "gold"), (0.34, 1.89, "b1"), (0.18, 1.905, "b1"), (0.05, 1.92, "b1"),
    ], n=14)
    b.sphere((0, 0.01, 1.945), 0.036, cell="gold", w="head", segs=6, rings=3)


def hat_foreign(b):
    """Kalimpong-trader's felt hat: a pinched fedora with a wide brim and a bright feather."""
    hat(b, [
        (0.13, 1.742, "b2"), (0.28, 1.75, "b3"), (0.285, 1.772, "b1"), (0.15, 1.784, "vermilion"), (0.152, 1.812, "b1"),
        (0.146, 1.93, "b1"), (0.12, 1.96, "b1"), (0.07, 1.965, "b1"),
    ], n=10, sx=0.95, sy=1.12)
    b.box((0, 0.01, 1.968), (0.04, 0.2, 0.026), cell="b3", w="head")
    b.strip([(0.15, 0.04, 1.82), (0.19, 0.0, 1.9), (0.2, -0.05, 2.02)], [0.03, 0.05, 0.02], normal=(1, 0, 0), cell="turquoise", w="head")


# --------------------------------------------------------------------- extras --------------------------------------
def x_satchels(b):
    """Caravan guard's two leather satchels behind the hips on a crossing strap."""
    b.strip([(0.2, 0.02, 1.44), (0.1, 0.16, 1.3), (-0.05, 0.19, 1.15), (-0.2, 0.1, 1.0), (-0.3, -0.08, 0.96)],
            [0.055] * 5, normal=(0, 1, 0), cell="leather", w={"chest": 0.5, "spine": 0.5})
    for sg in (1, -1):
        x = sg * 0.33
        b.box((x, -0.1, 0.99), (0.13, 0.26, 0.22), cell="leather", w="hips")
        b.box((x, -0.1, 1.1), (0.14, 0.27, 0.05), cell="wood_dark", w="hips")
        b.box((x + sg * 0.07, -0.1, 1.0), (0.012, 0.1, 0.1), cell="brass", w="hips")


def x_backpanel(b):
    """Amdo women's heavy back panel: long cloth hung from the shoulders, rows of silver, shell and amber."""
    pts = [(0, -0.2, 1.44), (0, -0.215, 1.2), (0, -0.23, 0.96), (0, -0.22, 0.74)]
    ws = [{"chest": 1.0}, {"spine": 1.0}, {"hips": 1.0}, {"hips": 0.6, "thigh.R": 0.2, "thigh.L": 0.2}]
    b.strip(pts, [0.34] * 4, normal=(0, -1, 0), cell="b1", w=None, weights_per_point=ws)
    for sg in (1, -1):
        b.strip([(sg * 0.17, -0.205, 1.44), (sg * 0.17, -0.22, 1.2), (sg * 0.17, -0.235, 0.96), (sg * 0.17, -0.225, 0.74)],
                [0.04] * 4, normal=(0, -1, 0), cell="vermilion", weights_per_point=ws)
    cells = ["silver", "turquoise", "amber_bead", "coral"]
    for r, z in enumerate((1.34, 1.2, 1.06, 0.92, 0.8)):
        wz = {"chest": 1.0} if z > 1.25 else ({"spine": 1.0} if z > 1.0 else {"hips": 1.0})
        for c, x in enumerate((-0.095, 0.0, 0.095)):
            b.box((x, -0.225 - 0.012 * (1.34 - z), z), (0.05, 0.02, 0.05), cell=cells[(r + c) % 4], w=wz)


def x_casebell(b):
    """Wandering doctor: a brass medicine case on a strap and a bell on a bracket at his back."""
    b.strip([(0.2, 0.02, 1.44), (0.08, 0.17, 1.28), (-0.1, 0.19, 1.1), (-0.27, 0.1, 0.99)],
            [0.045] * 4, normal=(0, 1, 0), cell="leather", w={"chest": 0.5, "spine": 0.5})
    b.tube([(-0.3, 0.06, 0.96), (-0.3, 0.14, 0.99), (-0.3, 0.2, 1.01)], [0.055, 0.058, 0.055], n=6, cell="brass", w="hips")
    b.box((-0.3, 0.2, 1.01), (0.04, 0.02, 0.04), cell="iron", w="hips")
    b.box((0.0, -0.2, 1.3), (0.03, 0.03, 0.34), cell="iron", w="spine")
    b.box((0.0, -0.3, 1.47), (0.03, 0.2, 0.03), cell="iron", w="spine")
    b.revolve([(0.1, 1.28, "brass"), (0.105, 1.3, "brass"), (0.072, 1.38, "brass"), (0.04, 1.44, "brass"), (0.012, 1.46, "brass")],
              n=8, w="spine", cy=-0.38, cap_end=True)
    b.sphere((0, -0.38, 1.29), 0.02, cell="iron", w="spine", segs=5, rings=3)


def x_bale(b):
    """A great bale of wool (or salt bags) lashed to the back."""
    wb = {"chest": 0.5, "spine": 0.5}
    b.box((0, -0.3, 1.31), (0.44, 0.26, 0.38), cell="sheepskin", w=wb, taper=(0.92, 0.9))
    b.box((0, -0.3, 1.38), (0.45, 0.27, 0.05), cell="leather", w=wb)
    b.box((0, -0.3, 1.24), (0.45, 0.27, 0.05), cell="leather", w=wb)
    b.box((0, -0.3, 1.52), (0.34, 0.2, 0.04), cell="bone", w="chest")
    for sg in (1, -1):
        b.strip([(sg * 0.17, -0.2, 1.44), (sg * 0.2, -0.05, 1.42), (sg * 0.22, 0.0, 1.38)], [0.04] * 3, normal=(0, 0, 1), cell="leather", w="chest")


def x_armcloth(b):
    """Dob-dob's red cloth tied round the left upper arm, ends fluttering."""
    b.loft([
        Ring((-0.256, 0, 1.32), 0.1, 0.105, w="arm_u.L", up=(0, 1, 0)),
        Ring((-0.261, 0, 1.2), 0.1, 0.105, w="arm_u.L", up=(0, 1, 0)),
    ], n=8, cell="vermilion", axis=(0, 0, 1), cap_start=False, cap_end=False)
    b.strip([(-0.33, 0.0, 1.24), (-0.4, -0.02, 1.08), (-0.42, -0.05, 0.9)], [0.07, 0.07, 0.05], normal=(0, 1, 0), cell="vermilion", w="arm_u.L")
    b.strip([(-0.33, 0.02, 1.26), (-0.37, 0.08, 1.12), (-0.37, 0.12, 0.98)], [0.05, 0.06, 0.04], normal=(0, 1, 0), cell="cinnabar", w="arm_u.L")


def x_scarf(b):
    """Bhutanese shoulder scarf: over the left shoulder, across the chest, one end at the right hip, one down the back."""
    ws = [{"chest": 1.0}, {"chest": 1.0}, {"chest": 0.6, "spine": 0.4}, {"spine": 1.0}, {"hips": 1.0}, {"hips": 1.0}]
    pts = [(-0.2, -0.01, 1.46), (-0.15, 0.1, 1.455), (-0.06, 0.18, 1.34), (0.06, 0.19, 1.19), (0.17, 0.16, 1.05), (0.2, 0.15, 0.86)]
    b.strip(pts, [0.11] * 6, normal=(0, 1, 0), cell="b1", weights_per_point=ws)
    b.strip([(p[0], p[1] + 0.006, p[2]) for p in pts], [0.03] * 6, normal=(0, 1, 0), cell="conch", weights_per_point=ws)
    wb = [{"chest": 1.0}, {"chest": 1.0}, {"spine": 1.0}, {"hips": 1.0}]
    back = [(-0.2, -0.01, 1.46), (-0.2, -0.17, 1.36), (-0.19, -0.2, 1.1), (-0.16, -0.21, 0.9)]
    b.strip(back, [0.11] * 4, normal=(0, -1, 0), cell="b1", weights_per_point=wb)
    b.strip([(p[0], p[1] - 0.006, p[2]) for p in back], [0.03] * 4, normal=(0, -1, 0), cell="conch", weights_per_point=wb)


# ---------------------------------------------------------------- seat and poses ------------------------------------
def _seat_leg(sg):
    """Two-bone fit of the leg from the hip down to the stirrup tread. Returns Euler degrees for thigh, shin, foot."""
    hip = Vector((sg * HX, 0.0, 0.92))
    ankle = Vector((sg * kit.STIRRUP_X, kit.STIRRUP_Y - kit.SADDLE_Y, kit.STIRRUP_Z + 0.03 + 0.1 - ROOT_Z))
    l1, l2 = 0.42, 0.40
    d = ankle - hip
    dist = min(d.length, l1 + l2 - 0.003)
    ell = d.normalized()
    ankle = hip + ell * dist
    ang = math.acos(max(-1.0, min(1.0, (l1 * l1 + dist * dist - l2 * l2) / (2 * l1 * dist))))
    pole = Vector((sg * 0.55, 1.0, 0.0))
    p = (pole - ell * pole.dot(ell)).normalized()
    knee = hip + (ell * math.cos(ang) + p * math.sin(ang)) * l1
    d1 = (knee - hip).normalized()
    q1 = Euler((math.asin(max(-1.0, min(1.0, d1.y))), math.atan2(-d1.x, -d1.z), 0.0), "XYZ").to_quaternion()
    q2w = Vector((0, 0, -1)).rotation_difference((ankle - knee).normalized())
    q2 = q1.inverted() @ q2w
    qf = Euler((math.radians(10), 0.0, math.radians(-8 * sg)), "XYZ").to_quaternion()
    q3 = q2w.inverted() @ qf

    def deg(q):
        return tuple(round(math.degrees(a), 1) for a in q.to_euler("XYZ"))

    return deg(q1), deg(q2), deg(q3)


def _build_seated():
    out = {}
    for side, sg in (("R", 1), ("L", -1)):
        t, s, f = _seat_leg(sg)
        out["thigh." + side], out["shin." + side], out["foot." + side] = t, s, f
    return out


SEATED = _build_seated()
REINS = {
    "arm_u.R": (26, -5, 0), "arm_l.R": (52, 0, -8), "hand.R": (8, 0, 0),
    "arm_u.L": (26, 5, 0), "arm_l.L": (52, 0, 8), "hand.L": (8, 0, 0),
}


def pose(*parts, **extra):
    out = {}
    for part in parts:
        out.update(part)
    out.update({k.replace("_R", ".R").replace("_L", ".L"): v for k, v in extra.items()})
    return out


def build_actions(rig):
    two_pi = 2 * math.pi

    def ride_fn(amount, lean):
        def fn(t):
            w = math.sin(two_pi * t)
            w2 = math.sin(two_pi * t + 1.0)
            body = dict(SEATED)
            body.update(REINS)
            body["spine"] = (lean + 3.0 * amount * w, 0, 0)
            body["chest"] = (lean * 0.4 + 2.0 * amount * w2, 0, 0)
            body["neck"] = (-lean * 0.7, 0, 0)
            body["head"] = (-lean * 0.4 - 2.0 * amount * w2, 0, 0)
            body["arm_u.R"] = (26 + 5 * amount * w2, -5, 0)
            body["arm_u.L"] = (26 + 5 * amount * w2, 5, 0)
            body["braid1"] = (-28 - 12 * amount * w, 0, 0)
            body["braid2"] = (-10 - 12 * amount * w2, 0, 0)
            return body, {"hips": (0, 0, 0.018 * amount * w)}

        return fn

    kit.bake_fn(rig, "ride", 14, ride_fn(1.0, 10.0))
    kit.bake_fn(rig, "ride_slow", 30, ride_fn(0.35, 3.0))

    def sprint(t):
        pz, loc = ride_fn(1.4, 22.0)(t)
        w = math.sin(two_pi * t)
        pz["arm_u.R"] = (40 + 40 * w, -28, 0)
        pz["arm_l.R"] = (50 + 22 * w, 0, 0)
        pz["hand.R"] = (-20 * w, 0, 0)
        return pz, loc

    kit.bake_fn(rig, "ride_whip", 14, sprint)

    def wobble(t):
        w = math.sin(two_pi * t)
        w2 = math.sin(two_pi * t + 1.3)
        return pose(SEATED, {
            "spine": (5, 18 * w, 0), "chest": (0, 10 * w2, 0), "head": (0, -12 * w, 8 * w2),
            "arm_u.R": (22 + 18 * w2, -68 + 22 * w, 0), "arm_l.R": (22, 0, 0),
            "arm_u.L": (22 - 18 * w2, 68 + 22 * w, 0), "arm_l.L": (22, 0, 0),
            "braid1": (-30, 18 * w, 0),
        }), {"hips": (0.03 * w, 0, 0)}

    kit.bake_fn(rig, "wobble", 20, wobble)

    base = pose(SEATED, REINS, spine=(8, 0, 0))

    def strike(name, windup, hit, rec, wind_frames=5, hit_frame=8, end=17):
        kit.bake_keys(rig, name, [
            (0, base, None, "out"),
            (wind_frames, pose(base, windup), None, "in"),
            (hit_frame, pose(base, hit), None, "out"),
            (hit_frame + 3, pose(base, rec), None, "smooth"),
            (end, base, None),
        ])

    strike("swing_R",
           {"spine": (4, 12, -32), "chest": (0, 8, -14), "head": (0, 0, 22), "arm_u.R": (118, -46, -18), "arm_l.R": (68, 0, 20), "hand.R": (-40, 0, 0)},
           {"spine": (10, -18, 28), "chest": (0, -10, 12), "head": (0, 0, -30), "arm_u.R": (64, -84, 0), "arm_l.R": (8, 0, 0), "hand.R": (30, 0, 0)},
           {"spine": (10, -20, 34), "chest": (0, -12, 14), "head": (0, 0, -30), "arm_u.R": (44, -66, 8), "arm_l.R": (24, 0, 0), "hand.R": (50, 0, 0)})
    strike("swing_L",
           {"spine": (4, -10, 34), "chest": (0, -8, 18), "head": (0, 0, -18), "arm_u.R": (96, 34, 30), "arm_l.R": (96, 0, 48), "hand.R": (-20, 0, 0)},
           {"spine": (10, 22, -30), "chest": (0, 12, -14), "head": (0, 0, 32), "arm_u.R": (74, 78, -6), "arm_l.R": (16, 0, 0), "hand.R": (10, 0, 0)},
           {"spine": (10, 22, -34), "chest": (0, 14, -14), "head": (0, 0, 32), "arm_u.R": (58, 88, -10), "arm_l.R": (34, 0, 0), "hand.R": (30, 0, 0)})
    strike("fist_R",
           {"spine": (4, 8, -18), "arm_u.R": (70, -30, -10), "arm_l.R": (108, 0, 16)},
           {"spine": (8, -14, 18), "head": (0, 0, -22), "arm_u.R": (86, -82, 0), "arm_l.R": (6, 0, 0)},
           {"spine": (8, -14, 20), "head": (0, 0, -22), "arm_u.R": (70, -72, 0), "arm_l.R": (22, 0, 0)},
           wind_frames=3, hit_frame=6, end=13)
    strike("fist_L",
           {"spine": (4, -8, 18), "arm_u.L": (70, 30, 10), "arm_l.L": (108, 0, -16)},
           {"spine": (8, 14, -18), "head": (0, 0, 22), "arm_u.L": (86, 82, 0), "arm_l.L": (6, 0, 0)},
           {"spine": (8, 14, -20), "head": (0, 0, 22), "arm_u.L": (70, 72, 0), "arm_l.L": (22, 0, 0)},
           wind_frames=3, hit_frame=6, end=13)
    strike("thrust_R",
           {"spine": (6, 6, -30), "arm_u.R": (34, -24, -30), "arm_l.R": (86, 0, 26), "hand.R": (0, 0, -30)},
           {"spine": (10, -10, 26), "head": (0, 0, -30), "arm_u.R": (84, -52, 0), "arm_l.R": (4, 0, 0), "hand.R": (0, 0, -60)},
           {"spine": (10, -10, 24), "head": (0, 0, -30), "arm_u.R": (76, -50, 0), "arm_l.R": (18, 0, 0), "hand.R": (0, 0, -60)},
           wind_frames=7, hit_frame=10, end=22)
    strike("thrust_L",
           {"spine": (6, -6, 30), "arm_u.R": (64, 30, 22), "arm_l.R": (78, 0, 34), "hand.R": (0, 0, 60)},
           {"spine": (10, 12, -26), "head": (0, 0, 30), "arm_u.R": (88, 64, 0), "arm_l.R": (8, 0, 0), "hand.R": (0, 0, 80)},
           {"spine": (10, 12, -24), "head": (0, 0, 30), "arm_u.R": (80, 60, 0), "arm_l.R": (20, 0, 0), "hand.R": (0, 0, 80)},
           wind_frames=7, hit_frame=10, end=22)
    strike("kick_R",
           {"spine": (2, 16, 0), "thigh.R": (84, -8, 0), "shin.R": (-118, 0, 0)},
           {"spine": (-6, 24, 0), "chest": (0, 8, 0), "thigh.R": (48, -74, 0), "shin.R": (-10, 0, 0), "foot.R": (-24, 0, 0)},
           {"spine": (-4, 20, 0), "thigh.R": (52, -66, 0), "shin.R": (-26, 0, 0)},
           wind_frames=4, hit_frame=7, end=16)
    strike("kick_L",
           {"spine": (2, -16, 0), "thigh.L": (84, 8, 0), "shin.L": (-118, 0, 0)},
           {"spine": (-6, -24, 0), "chest": (0, -8, 0), "thigh.L": (48, 74, 0), "shin.L": (-10, 0, 0), "foot.L": (-24, 0, 0)},
           {"spine": (-4, -20, 0), "thigh.L": (52, 66, 0), "shin.L": (-26, 0, 0)},
           wind_frames=4, hit_frame=7, end=16)
    bow_ready = pose(SEATED, {"spine": (6, 0, 34), "head": (0, 0, -30), "arm_u.L": (88, 40, 34), "arm_l.L": (6, 0, 0), "arm_u.R": (88, -24, 30), "arm_l.R": (20, 0, 20)})
    bow_full = pose(SEATED, {"spine": (2, 0, 42), "head": (0, 0, -40), "arm_u.L": (92, 44, 42), "arm_l.L": (0, 0, 0), "arm_u.R": (92, -56, 34), "arm_l.R": (138, 0, 0), "hand.R": (0, 0, 10)})
    kit.bake_keys(rig, "bow_draw", [(0, base, None, "out"), (6, bow_ready, None), (16, bow_full, None)])
    kit.bake_keys(rig, "bow_hold", [(0, bow_full, None), (6, bow_full, None)])
    kit.bake_keys(rig, "bow_loose", [
        (0, bow_full, None, "out"),
        (2, pose(bow_full, {"arm_l.R": (70, 0, 0), "arm_u.R": (78, -80, 40)}), None),
        (12, base, None),
    ])
    kit.bake_keys(rig, "block", [
        (0, base, None, "out"),
        (4, pose(SEATED, {"spine": (8, -4, -10), "head": (6, 0, 6), "arm_u.L": (48, 46, 12), "arm_l.L": (80, 0, -60), "arm_u.R": (26, -5, 0), "arm_l.R": (52, 0, -8)}), None),
    ])
    kit.bake_keys(rig, "throw", [
        (0, base, None, "out"),
        (6, pose(base, {"spine": (-10, 10, -22), "arm_u.R": (150, -30, 0), "arm_l.R": (70, 0, 0)}), None, "in"),
        (9, pose(base, {"spine": (16, -6, 14), "arm_u.R": (70, -20, 0), "arm_l.R": (8, 0, 0)}), None),
        (18, base, None),
    ])
    kit.bake_keys(rig, "hit_R", [
        (0, base, None, "out"),
        (3, pose(SEATED, {"spine": (-8, 22, 12), "chest": (0, 14, 6), "head": (-10, 18, 16), "arm_u.R": (10, -46, 0), "arm_l.R": (30, 0, 0), "arm_u.L": (30, 48, 0), "arm_l.L": (30, 0, 0)}), {"hips": (-0.05, 0, 0)}),
        (14, base, None),
    ])
    kit.bake_keys(rig, "hit_L", [
        (0, base, None, "out"),
        (3, pose(SEATED, {"spine": (-8, -22, -12), "chest": (0, -14, -6), "head": (-10, -18, -16), "arm_u.L": (10, 46, 0), "arm_l.L": (30, 0, 0), "arm_u.R": (30, -48, 0), "arm_l.R": (30, 0, 0)}), {"hips": (0.05, 0, 0)}),
        (14, base, None),
    ])
    flail = {
        "spine": (34, 0, 0), "chest": (24, 0, 0), "head": (20, 0, 0),
        "arm_u.R": (110, -60, 0), "arm_l.R": (70, 0, 0), "arm_u.L": (130, 50, 0), "arm_l.L": (50, 0, 0),
        "thigh.R": (82, -20, 0), "shin.R": (-110, 0, 0), "thigh.L": (42, 20, 0), "shin.L": (-70, 0, 0),
    }

    def tumble(t):
        w = math.sin(two_pi * t)
        p = dict(flail)
        p["arm_u.R"] = (110 + 30 * w, -60, 0)
        p["arm_u.L"] = (130 - 30 * w, 50, 0)
        p["thigh.R"] = (82 - 24 * w, -20, 0)
        p["thigh.L"] = (42 + 24 * w, 20, 0)
        return p, {}

    kit.bake_fn(rig, "tumble", 16, tumble)
    lying = {
        "spine": (4, 0, 0), "head": (-14, 0, 12), "arm_u.R": (6, -40, 0), "arm_l.R": (12, 0, 0),
        "arm_u.L": (10, 52, 0), "arm_l.L": (34, 0, 0), "thigh.R": (6, -10, 0), "thigh.L": (22, 12, 0), "shin.L": (-34, 0, 0),
    }
    kit.bake_keys(rig, "lie", [(0, lying, None), (6, lying, None)])
    kit.bake_keys(rig, "getup", [
        (0, lying, {"root": (0, 0, 0)}, "out"),
        (10, {"spine": (46, 0, 0), "chest": (20, 0, 0), "head": (-30, 0, 0), "arm_u.R": (40, -30, 0), "arm_l.R": (10, 0, 0), "arm_u.L": (40, 30, 0), "arm_l.L": (10, 0, 0), "thigh.R": (96, -16, 0), "shin.R": (-122, 0, 0), "thigh.L": (66, 16, 0), "shin.L": (-122, 0, 0)}, None),
        (20, {"spine": (28, 0, 0), "head": (-16, 0, 0), "arm_u.R": (14, -20, 0), "arm_u.L": (14, 20, 0), "thigh.R": (76, -8, 0), "shin.R": (-96, 0, 0), "thigh.L": (58, 8, 0), "shin.L": (-90, 0, 0)}, None),
        (28, {}, None),
    ])

    def run(t):
        w = math.sin(two_pi * t)
        c = math.cos(two_pi * t)
        return {
            "spine": (14, 0, 6 * w), "chest": (4, 0, 6 * w), "head": (-12, 0, -6 * w),
            "arm_u.R": (-46 * w + 8, -14, 0), "arm_l.R": (70, 0, 0),
            "arm_u.L": (46 * w + 8, 14, 0), "arm_l.L": (70, 0, 0),
            "thigh.R": (46 * w + 26, 0, 0), "shin.R": (-30 + 40 * c - 30, 0, 0),
            "thigh.L": (-46 * w + 26, 0, 0), "shin.L": (-30 - 40 * c - 30, 0, 0),
            "braid1": (-20 + 16 * c, 0, 0),
        }, {"hips": (0, 0, -0.06 + 0.035 * abs(c))}

    kit.bake_fn(rig, "run", 18, run)
    kit.bake_keys(rig, "mount", [
        (0, {"spine": (10, 0, 0), "arm_u.R": (120, -8, 0), "arm_u.L": (120, 8, 0), "thigh.L": (60, 0, 0), "shin.L": (-90, 0, 0)}, {"root": (-0.5, 0, -0.42)}, "smooth"),
        (6, {"spine": (24, 0, 0), "arm_u.R": (70, -8, 0), "arm_u.L": (70, 8, 0), "thigh.R": (-24, -70, 0), "thigh.L": (60, 0, 0), "shin.L": (-70, 0, 0)}, {"root": (-0.28, 0, -0.1)}),
        (12, pose(SEATED, REINS), None),
    ])

    def rest(t):
        w = math.sin(two_pi * t)
        return {
            "root": (0, 0, 0),
            "spine": (26, 0, 0), "chest": (12 + 2 * w, 0, 0), "head": (-14 + 3 * w, 0, 0),
            "arm_u.R": (40, -8, 0), "arm_l.R": (84 + 4 * w, 0, -14), "hand.R": (10, 0, 0),
            "arm_u.L": (46, 8, 0), "arm_l.L": (70, 0, 12),
            "thigh.R": (92, -30, 0), "shin.R": (-124, 0, 0), "foot.R": (20, 0, 0),
            "thigh.L": (92, 30, 0), "shin.L": (-124, 0, 0), "foot.L": (20, 0, 0),
        }, {"root": (0, 0, -0.76)}

    kit.bake_fn(rig, "rest_sit", 60, rest)

    def victory(t):
        w = math.sin(two_pi * t)
        return pose(SEATED, {
            "spine": (-6, 0, 0), "head": (-14, 0, 0),
            "arm_u.R": (168 + 8 * w, -12, 0), "arm_l.R": (16 + 10 * w, 0, 0),
            "arm_u.L": (26, 5, 0), "arm_l.L": (52, 0, 8),
            "braid1": (-40, 0, 0),
        }), {"hips": (0, 0, 0.04 * abs(w))}

    kit.bake_fn(rig, "victory", 24, victory)
    kit.bake_keys(rig, "stand", [(0, {"arm_u.R": (4, -5, 0), "arm_u.L": (4, 5, 0), "arm_l.R": (10, 0, 0), "arm_l.L": (10, 0, 0)}, None),
                                 (6, {"arm_u.R": (4, -5, 0), "arm_u.L": (4, 5, 0), "arm_l.R": (10, 0, 0), "arm_l.L": (10, 0, 0)}, None)])

    # Stunt: hang down the side of the horse and scoop something off the ground, then haul back up.
    def scoop(side, sg):
        reach = pose(SEATED, REINS, {
            "spine": (-6, sg * 78, 0), "chest": (8, sg * 70, 0), "neck": (0, -sg * 60, 0), "head": (14, -sg * 60, 0),
            "arm_u." + side: (14, sg * -158, 0), "arm_l." + side: (24, 0, 0), "hand." + side: (-10, 0, 0),
            "braid1": (-60, 0, 0),
        })
        loc = {"hips": (sg * 0.2, 0, -0.52), "spine": (sg * 0.05, 0, -0.05)}
        dip = pose(SEATED, REINS, {
            "spine": (6, sg * 40, 0), "chest": (6, sg * 32, 0), "head": (6, -sg * 30, 0),
            "arm_u." + side: (30, sg * -80, 0), "arm_l." + side: (30, 0, 0),
        })
        kit.bake_keys(rig, "scoop_" + side, [
            (0, base, None, "out"),
            (6, dip, {"hips": (sg * 0.07, 0, -0.18)}, "out"),
            (11, reach, loc, "hold"),
            (16, reach, loc, "in"),
            (20, pose(base, {"spine": (14, sg * 30, 0), "chest": (6, sg * 20, 0), "arm_u." + side: (40, sg * -50, 0)}), {"hips": (sg * 0.03, 0, -0.1)}),
            (30, base, None),
        ])

    mirror_x(scoop)
    kit.reset_pose(rig)


# ------------------------------------------------------------------- wardrobe --------------------------------------
FACES = ("young", "old", "woman", "woman_old", "soot")
BODIES = [("body_chuba", body_chuba), ("body_oneoff", body_oneoff), ("body_fleece", body_fleece), ("body_hide", body_hide), ("body_brocade", body_brocade)]
HAIR = [("hair_wound", hair_wound), ("hair_plaits", hair_plaits), ("hair_mop", hair_mop), ("hair_short", hair_short), ("hair_earlocks", hair_earlocks)]
HATS = [("hat_felt", hat_felt), ("hat_big", hat_big), ("hat_peak", hat_peak), ("hat_fox", hat_fox), ("hat_basin", hat_basin), ("hat_disc", hat_disc), ("hat_foreign", hat_foreign)]
EXTRAS = [("x_satchels", x_satchels), ("x_backpanel", x_backpanel), ("x_casebell", x_casebell), ("x_bale", x_bale), ("x_armcloth", x_armcloth), ("x_scarf", x_scarf)]


def build_wardrobe(rig, only=None):
    pieces = []
    report = []

    def piece(name, fn):
        if only and name not in only:
            return
        b = Builder(name)
        fn(b)
        pieces.append(b.to_object(rig))
        report.append("%s:%d" % (name, b.tri_count()))

    for name, fn in BODIES + HAIR + HATS + EXTRAS:
        piece(name, fn)
    for face in FACES:
        for tone in ("", "_lt", "_dp"):
            piece("head_" + face + tone, lambda b, f=face, t=tone: add_head(b, f, t))
    print("wardrobe", " ".join(report))
    return pieces


def main():
    only = None
    try:
        only = BMCP_ARGS.get("only", "").split(",") if BMCP_ARGS.get("only") else None  # noqa: F821
    except NameError:
        pass
    kit.clear_scene()
    rig = kit.make_rig("rider_rig", BONES)
    objs = build_wardrobe(rig, only)
    build_actions(rig)
    print("seat", {k: v for k, v in SEATED.items()})
    print("actions", len(kit.bpy.data.actions))
    kit.export_glb("rider", [rig] + objs, animations=True)


if __name__ == "__main__":
    main()
