"""Reads the audio track out of a Godot Movie Maker .avi (uncompressed PCM) and measures it with pyloudnorm.

Run with the voice tools' Python (it has numpy, scipy, soundfile and pyloudnorm):
  <voice venv>\\Scripts\\python.exe tests/mix_check.py recording.avi [--from S] [--to S] [--wav out.wav] [--blocks 10]

Prints integrated loudness (LUFS, BS.1770 gated), the loudest 3 s short-term reading, loudness range, sample peak and
true peak (4x oversampled, in dBFS), and the integrated loudness of each block of --blocks seconds.
Targets from docs/INTERFACES.md: race about -20 LUFS, true peak under -1 dBFS, menus about -24 LUFS.
"""
import argparse
import mmap
import struct
import sys

import numpy as np
import pyloudnorm as pyln
import soundfile as sf
from scipy import signal


def read_avi_audio(path):
    """Returns (samples float64 shape (n, channels), rate)."""
    with open(path, "rb") as f:
        mm = mmap.mmap(f.fileno(), 0, access=mmap.ACCESS_READ)
        if mm[0:4] != b"RIFF" or mm[8:12] != b"AVI ":
            raise SystemExit("not an AVI file: %s" % path)
        fmt = None
        audio_stream = -1
        stream_i = -1
        chunks = []
        size = len(mm)

        def walk(pos, end):
            nonlocal fmt, audio_stream, stream_i
            while pos + 8 <= end:
                tag = bytes(mm[pos:pos + 4])
                n = struct.unpack("<I", mm[pos + 4:pos + 8])[0]
                body = pos + 8
                if tag == b"LIST":
                    kind = bytes(mm[body:body + 4])
                    if kind == b"movi":
                        # The size field can be stale if the recording was cut short, so walk to the end of the file.
                        walk_movi(body + 4, size)
                        return
                    walk(body + 4, min(end, body + n))
                elif tag == b"strh":
                    stream_i += 1
                    if bytes(mm[body:body + 4]) == b"auds":
                        audio_stream = stream_i
                elif tag == b"strf" and stream_i == audio_stream and audio_stream >= 0 and fmt is None:
                    tagf, ch, rate, _avg, _align, bits = struct.unpack("<HHIIHH", mm[body:body + 16])
                    fmt = (tagf, ch, rate, bits)
                pos = body + n + (n & 1)

        def walk_movi(pos, end):
            while pos + 8 <= end:
                tag = bytes(mm[pos:pos + 4])
                n = struct.unpack("<I", mm[pos + 4:pos + 8])[0]
                body = pos + 8
                if tag == b"idx1":
                    return
                if tag[2:4] == b"wb":
                    chunks.append((body, min(n, size - body)))
                pos = body + n + (n & 1)

        walk(12, size)
        if fmt is None or not chunks:
            raise SystemExit("no audio stream in %s (was it recorded with --write-movie?)" % path)
        _tag, ch, rate, bits = fmt
        raw = b"".join(bytes(mm[b:b + n]) for b, n in chunks)
        mm.close()
    if bits != 16:
        raise SystemExit("expected 16-bit PCM, got %d-bit" % bits)
    x = np.frombuffer(raw[: len(raw) // (2 * ch) * 2 * ch], dtype="<i2").astype(np.float64) / 32768.0
    return x.reshape(-1, ch), rate


def true_peak_db(x):
    up = signal.resample_poly(x, 4, 1, axis=0)
    return 20.0 * np.log10(np.max(np.abs(up)) + 1e-12)


def lufs(x, rate):
    if len(x) < int(0.5 * rate):
        return float("-inf")
    return pyln.Meter(rate).integrated_loudness(x)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("avi")
    ap.add_argument("--from", dest="t0", type=float, default=0.0)
    ap.add_argument("--to", dest="t1", type=float, default=0.0)
    ap.add_argument("--wav", default="")
    ap.add_argument("--blocks", type=float, default=10.0)
    ap.add_argument("--log", default="", help="the test's console log: its VOICE_AT lines are checked against the recording")
    ap.add_argument("--relative", action="store_true", help="voices over a busy mix: compare each line with the second before it")
    a = ap.parse_args()
    x, rate = read_avi_audio(a.avi)
    i0 = int(a.t0 * rate)
    i1 = int(a.t1 * rate) if a.t1 > 0 else len(x)
    x = x[i0:i1]
    if a.wav:
        sf.write(a.wav, x.astype(np.float32), rate, subtype="PCM_16")
    secs = len(x) / rate
    meter = pyln.Meter(rate)
    integ = lufs(x, rate)
    # Short-term loudness: 3 s windows, one reading a second.
    st = []
    for s in range(0, max(1, int(secs) - 2)):
        seg = x[s * rate:(s + 3) * rate]
        if len(seg) >= 3 * rate - 10:
            st.append(meter.integrated_loudness(seg))
    st = np.array([v for v in st if np.isfinite(v)])
    lra = float(np.percentile(st, 95) - np.percentile(st, 10)) if len(st) > 3 else float("nan")
    print("%s  %.1f s at %d Hz, %d ch" % (a.avi.replace("\\", "/").split("/")[-1], secs, rate, x.shape[1]))
    print("  integrated   %7.2f LUFS" % integ)
    if len(st):
        print("  short-term   max %.2f, median %.2f LUFS (3 s windows), range %.1f LU" % (st.max(), np.median(st), lra))
    print("  sample peak  %7.2f dBFS   true peak %7.2f dBFS" % (20 * np.log10(np.max(np.abs(x)) + 1e-12), true_peak_db(x)))
    print("  rms          %7.2f dBFS" % (20 * np.log10(np.sqrt(np.mean(x ** 2)) + 1e-12)))
    blocks = []
    step = int(a.blocks * rate)
    for s in range(0, len(x), step):
        seg = x[s:s + step]
        if len(seg) > int(1.0 * rate):
            blocks.append("%.1f" % lufs(seg, rate))
    print("  per %.0f s: %s" % (a.blocks, " ".join(blocks)))
    clipped = int(np.sum(np.abs(x) >= 0.9999))
    print("  samples at full scale: %d" % clipped)
    if a.log:
        check_voice_windows(x, rate, a.log, a.relative)


def check_voice_windows(x, rate, log_path, relative=False):
    """Each 'VOICE_AT start seconds label' line in the log says a voice began at that moment. The recording must be loud
    inside that window and quiet in the gaps between the lines."""
    import re
    windows = []
    for line in open(log_path, encoding="utf-8", errors="replace"):
        m = re.match(r"VOICE_AT ([\d.]+) ([\d.]+) (.*)", line.strip())
        if m:
            windows.append((float(m.group(1)), float(m.group(2)), m.group(3)))
    if not windows:
        print("  no VOICE_AT lines in the log")
        return
    mono = x.mean(axis=1)

    def rms_db(a, b):
        seg = mono[max(0, int(a * rate)):max(1, int(b * rate))]
        return 20 * np.log10(np.sqrt(np.mean(seg ** 2)) + 1e-9) if len(seg) else -120.0

    if relative:
        rises = []
        print("  voice lines over the mix: level in the line, level in the 1.2 s before it, rise")
        for start, dur, label in windows:
            inside = rms_db(start + 0.05, start + max(dur, 0.3))
            before = rms_db(max(0.0, start - 1.25), start - 0.05)
            rises.append(inside - before)
            print("    %7.2f s %5.2f s  %6.1f dB  %6.1f dB  %+5.1f  %s" % (start, dur, inside, before, inside - before, label[:60]))
        heard = sum(1 for r in rises if r > 1.0)
        print("  %d of %d lines raise the level by more than 1 dB; mean rise %+.1f dB" % (heard, len(rises), float(np.mean(rises))))
        return
    gaps = []
    for i in range(len(windows) - 1):
        a = windows[i][0] + windows[i][1] + 0.25
        b = windows[i + 1][0] - 0.05
        if b - a > 0.1:
            gaps.append(rms_db(a, b))
    quiet = float(np.median(gaps)) if gaps else -120.0
    print("  voice windows (rms dBFS inside the window; the gaps between lines are %.1f):" % quiet)
    bad = 0
    for start, dur, label in windows:
        level = rms_db(start + 0.05, start + max(dur, 0.2))
        ok = level > quiet + 15.0
        bad += 0 if ok else 1
        print("    %7.2f s %5.2f s  %7.1f dB  %s  %s" % (start, dur, level, "ok " if ok else "NOT HEARD", label))
    print("  %d of %d voice lines heard at the right time" % (len(windows) - bad, len(windows)))


if __name__ == "__main__":
    main()
