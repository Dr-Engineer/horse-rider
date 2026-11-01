"""Draws audio files as a labelled spectrogram PNG, so generated speech can be checked by eye for glitches.
Usage: spectrogram.py [--scale N] [--f0] out.png a.ogg b.ogg ...   (needs numpy, scipy and soundfile from the voice tools)

Each file gets a waveform strip over a spectrogram (frequency on a square-root scale, so the formants get room).
--scale N draws everything N times larger. --f0 also prints the median pitch of the voiced frames (needs pyworld) and
the fraction of frames that are voiced, which is how women's and men's voices are checked for the right range.
"""
import os
import struct
import sys
import zlib

import numpy as np
import soundfile as sf
from scipy import signal

H = 140
PX_PER_SEC = 180


def spec(path):
    x, sr = sf.read(path, dtype="float64")
    if x.ndim > 1:
        x = x.mean(axis=1)
    f, t, s = signal.spectrogram(x, sr, nperseg=512, noverlap=512 - int(sr / PX_PER_SEC), window="hann", mode="magnitude")
    db = 20.0 * np.log10(s + 1e-9)
    db = np.clip((db + 90.0) / 70.0, 0.0, 1.0)
    fy = (np.linspace(0, 1, H) ** 2) * (sr * 0.5)
    rows = np.stack([np.interp(fy, f, db[:, i]) for i in range(db.shape[1])], axis=1)
    return rows[::-1], x, sr


def pitch(x, sr):
    import pyworld as pw
    f0, _t = pw.harvest(x.astype(np.float64), sr, f0_floor=60.0, f0_ceil=700.0, frame_period=10.0)
    voiced = f0 > 0
    return (float(np.median(f0[voiced])) if voiced.any() else 0.0), float(np.mean(voiced))


def main():
    args = sys.argv[1:]
    scale = 1
    want_f0 = False
    while args and args[0].startswith("--"):
        if args[0] == "--scale":
            scale = int(args[1])
            args = args[2:]
        elif args[0] == "--f0":
            want_f0 = True
            args = args[1:]
        else:
            raise SystemExit("unknown option " + args[0])
    out = args[0]
    panels = []
    for p in args[1:]:
        rows, x, sr = spec(p)
        wave_h = 30
        w = rows.shape[1]
        wave = np.zeros((wave_h, w))
        step = max(1, len(x) // w)
        for i in range(w):
            seg = x[i * step:(i + 1) * step]
            if len(seg):
                a = int(np.max(np.abs(seg)) * (wave_h // 2 - 1))
                wave[wave_h // 2 - a:wave_h // 2 + a + 1, i] = 1.0
        panel = np.vstack([wave, rows, np.full((4, w), 0.15)])
        panels.append(panel)
        line = "%-40s %5.2fs  peak %.2f  rms %.3f" % (os.path.basename(p), len(x) / sr, np.max(np.abs(x)), np.sqrt(np.mean(x ** 2)))
        if want_f0:
            med, voiced = pitch(x, sr)
            line += "  median F0 %4.0f Hz  voiced %3.0f%%" % (med, voiced * 100)
        print(line)
    width = max(p.shape[1] for p in panels)
    img = np.vstack([np.pad(p, ((0, 0), (0, width - p.shape[1]))) for p in panels])
    if scale > 1:
        img = np.kron(img, np.ones((scale, scale)))
    rgb = np.stack([np.clip(img * 1.6, 0, 1), np.clip(img * 1.3 - 0.2, 0, 1), np.clip(img * 0.8, 0, 1)], axis=2)
    data = (rgb * 255).astype(np.uint8)
    raw = b"".join(b"\x00" + bytes(row) for row in data)

    def chunk(tag, body):
        return struct.pack(">I", len(body)) + tag + body + struct.pack(">I", zlib.crc32(tag + body) & 0xFFFFFFFF)

    with open(out, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(chunk(b"IHDR", struct.pack(">IIBBBBB", data.shape[1], data.shape[0], 8, 2, 0, 0, 0)))
        f.write(chunk(b"IDAT", zlib.compress(raw, 6)))
        f.write(chunk(b"IEND", b""))


if __name__ == "__main__":
    main()
