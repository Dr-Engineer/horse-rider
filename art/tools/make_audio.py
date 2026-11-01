"""Synthesises every sound and music loop for Windhorse Rumble as 16-bit mono WAV files in assets/audio/.

Original synthesis only (noise shaping, additive and modal tones, Karplus-Strong plucks). No samples, no chanting,
no sacred music. Music is pentatonic: plucked lute, frame drum, cymbal and a low horn drone.
Run: "/Applications/Blender 5.2.app/Contents/Resources/5.2/python/bin/python3.13" -I art/tools/make_audio.py
Every loop is rendered with circular mixing and FFT filtering, so its seam is continuous by construction.
The script prints a level and seam report; nothing here can clip.
"""
import math
import os
import sys
import wave

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT_DIR = os.path.join(ROOT, "assets", "audio")
SR = 22050     # sound effects
MSR = 32000    # music
TAU = 2.0 * math.pi
REPORT = []


# ---------------------------------------------------------------- basics

def rng_for(name):
    return np.random.default_rng(abs(hash_str(name)) % (2 ** 32))


def hash_str(s):
    h = 2166136261
    for ch in s.encode():
        h = ((h ^ ch) * 16777619) & 0xFFFFFFFF
    return h


def ex(n, tau, sr):
    return np.exp(-np.arange(n) / sr / tau)


def fshape(x, fn, sr):
    spec = np.fft.rfft(x)
    f = np.maximum(np.fft.rfftfreq(len(x), 1.0 / sr), 1e-3)
    return np.fft.irfft(spec * fn(f), len(x))


def lp(x, fc, sr, order=2):
    return fshape(x, lambda f: 1.0 / np.sqrt(1.0 + (f / fc) ** (2 * order)), sr)


def hp(x, fc, sr, order=2):
    return fshape(x, lambda f: 1.0 / np.sqrt(1.0 + (fc / f) ** (2 * order)), sr)


def bp(x, lo, hi, sr, order=2):
    return hp(lp(x, hi, sr, order), lo, sr, order)


def peaking(x, f0, q, gain, sr):
    """Resonant bump of `gain` (linear) around f0, a cheap formant."""
    return fshape(x, lambda f: 1.0 + (gain - 1.0) / (1.0 + (q * (f / f0 - f0 / f)) ** 2), sr)


def unit(x):
    return x / (np.sqrt(np.mean(x * x)) + 1e-12)


def osc(freq, sr, phase=0.0):
    return np.sin(TAU * np.cumsum(freq) / sr + phase)


def fade(x, sr, fin=0.002, fout=0.01):
    x = x.copy()
    a, b = int(fin * sr), int(fout * sr)
    if a > 0:
        x[:a] *= np.linspace(0, 1, a)
    if b > 0:
        x[-b:] *= np.linspace(1, 0, b)
    return x


def mix_wrap(buf, sig, start, gain=1.0):
    """Adds sig into buf starting at `start`, wrapping around the end so loops stay seamless."""
    n = len(buf)
    pos = start % n
    i = 0
    while i < len(sig):
        k = min(len(sig) - i, n - pos)
        buf[pos:pos + k] += gain * sig[i:i + k]
        i += k
        pos = (pos + k) % n


def mix_at(buf, sig, start, gain=1.0):
    if start >= len(buf):
        return
    k = min(len(sig), len(buf) - start)
    buf[start:start + k] += gain * sig[:k]


def soft(x, drive=1.0):
    return np.tanh(x * drive) / np.tanh(drive) if drive != 1.0 else np.tanh(x)


def band_fractions(x, sr):
    spec = np.abs(np.fft.rfft(x)) ** 2
    f = np.fft.rfftfreq(len(x), 1.0 / sr)
    total = np.sum(spec) + 1e-12
    edges = (0, 250, 1000, 4000, sr)
    return [float(np.sum(spec[(f >= a) & (f < b)]) / total) for a, b in zip(edges[:-1], edges[1:])]


def save(name, x, sr, peak=0.85, loop=False, limit=True, norm=True):
    x = np.asarray(x, dtype=np.float64)
    x = x - np.mean(x) if loop else x
    if norm:
        top = np.max(np.abs(x)) + 1e-12
        x = x / top * peak
        if limit:
            x = np.tanh(x * 1.15) / np.tanh(1.15) * min(1.0, peak / 0.85)
    data = np.clip(x, -1.0, 1.0)
    pcm = (data * 32767.0).astype("<i2")
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(pcm.tobytes())
    rms = 20 * math.log10(np.sqrt(np.mean(data ** 2)) + 1e-12)
    pk = 20 * math.log10(np.max(np.abs(data)) + 1e-12)
    clipped = int(np.sum(np.abs(pcm) >= 32767))
    seam = ""
    if loop:
        step = np.percentile(np.abs(np.diff(data)), 99) + 1e-12
        seam = "%.2f" % (abs(data[0] - data[-1]) / step)
    REPORT.append((name, sr, len(x) / sr, pk, rms, clipped, os.path.getsize(path) / 1024.0, seam,
                   " ".join("%2d" % round(100 * b) for b in band_fractions(data, sr))))


# ---------------------------------------------------------------- instruments

def ks(freq, dur, sr, t60=1.5, bright=0.55, pos=0.18, seed=1):
    """Karplus-Strong plucked string with fractional delay, pluck-position comb and a decay time in seconds."""
    rng = np.random.default_rng(seed)
    n = int(dur * sr)
    period = sr / freq - 0.5
    li = int(period)
    frac = period - li
    m = li + 3
    exc = rng.uniform(-1, 1, m)
    a = 0.15 + 0.85 * bright
    for i in range(1, m):                # one-pole low-pass: softer excitation for low `bright`
        exc[i] = a * exc[i] + (1 - a) * exc[i - 1]
    k = max(1, int(pos * li))
    exc[k:] = exc[k:] - exc[:-k] * 0.9   # pluck position comb
    exc -= np.mean(exc)
    exc /= np.max(np.abs(exc)) + 1e-9
    y = np.zeros(n + m + li + 4)
    y[:m] = exc
    rho = 10 ** (-3.0 * (1.0 / freq) / t60)
    s = m
    while s < n + m:
        e = min(s + li, len(y))
        d0 = y[s - li:e - li]
        d1 = y[s - li - 1:e - li - 1]
        d2 = y[s - li - 2:e - li - 2]
        y[s:e] = rho * 0.5 * ((1 - frac) * (d0 + d1) + frac * (d1 + d2))
        s = e
    out = y[:n]
    return fade(out, sr, 0.001, 0.02)


def midi_hz(m):
    return 440.0 * 2 ** ((m - 69) / 12.0)


def hoof(sr, rng, pitch=1.0, soft_amt=0.0):
    n = int(0.16 * sr)
    t = np.arange(n) / sr
    f = 120 * pitch * (1 + 0.6 * np.exp(-t / 0.015))
    thud = osc(f, sr) * ex(n, 0.035, sr)
    tick = unit(bp(rng.standard_normal(n), 500 * pitch, 2600 * pitch, sr)) * ex(n, 0.009, sr)
    grit = unit(bp(rng.standard_normal(n), 2200, 7000, sr)) * ex(n, 0.022, sr)
    return 0.6 * thud + (1.1 - 0.5 * soft_amt) * tick + (0.55 - 0.35 * soft_amt) * grit


def hoof_loop(name, stride, beats, strides, soft_amt, pair_gap=0.014):
    rng = rng_for(name)
    n = int(round(stride * strides * SR))
    buf = np.zeros(n)
    for k in range(strides):
        for off, pitch, vel, pair in beats:
            at = int((k * stride + off * stride) * SR)
            v = vel * (1 + rng.uniform(-0.12, 0.12))
            mix_wrap(buf, hoof(SR, rng, pitch * (1 + rng.uniform(-0.04, 0.04)), soft_amt), at, v)
            if pair:
                mix_wrap(buf, hoof(SR, rng, pitch * 1.12, soft_amt), at + int(pair_gap * SR), v * 0.8)
    # dry body: a faint dusty low rumble that follows the same rhythm would blur it, so none.
    save(name, buf, SR, 0.8, loop=True)


def frame_drum(sr, pitch=95.0, dur=0.5, slap=0.0, rng=None):
    rng = rng or np.random.default_rng(7)
    n = int(dur * sr)
    t = np.arange(n) / sr
    f = pitch * (1 + 0.7 * np.exp(-t / 0.045))
    ph = np.cumsum(f) / sr
    body = np.sin(TAU * ph) * ex(n, 0.14 * (0.6 + pitch / 250.0), sr)
    body += 0.35 * np.sin(TAU * 1.59 * ph) * ex(n, 0.07, sr)
    body += 0.18 * np.sin(TAU * 2.14 * ph) * ex(n, 0.045, sr)
    skin = unit(bp(rng.standard_normal(n), 180, 1800, sr)) * ex(n, 0.02, sr) * 0.45
    out = body + skin
    if slap > 0:
        out += slap * unit(bp(rng.standard_normal(n), 1500, 6000, sr)) * ex(n, 0.01, sr) * 0.6
    return fade(out, sr, 0.001, 0.02)


def cymbal(sr, dur=1.2, tau=0.5, bright=1.0, seed=3):
    rng = np.random.default_rng(seed)
    n = int(dur * sr)
    t = np.arange(n) / sr
    hiss = unit(hp(rng.standard_normal(n), 4200 * bright, sr))
    ring = np.zeros(n)
    for fr in (3170, 4380, 5440, 6710, 7930, 9100):
        ring += np.sin(TAU * fr * t + rng.uniform(0, TAU)) * np.exp(-t / (tau * rng.uniform(0.7, 1.2)))
    out = (0.8 * hiss + 0.25 * unit(ring)) * ex(n, tau, sr) + 0.5 * hiss * ex(n, 0.012, sr)
    return fade(out, sr, 0.001, 0.03)


def bell_tone(sr, f0, dur, ratios=(1.0, 2.0, 2.76, 5.4, 8.93), amps=(1.0, 0.6, 0.5, 0.25, 0.12), tau=0.7):
    n = int(dur * sr)
    t = np.arange(n) / sr
    out = np.zeros(n)
    for r, a in zip(ratios, amps):
        if f0 * r < sr * 0.45:
            out += a * np.sin(TAU * f0 * r * t) * np.exp(-t / (tau / (0.6 + 0.4 * r)))
    return fade(out, sr, 0.001, 0.03)


def horn_tone(sr, f0, dur, att=0.4, rel=0.8, seed=5):
    """Low dungchen-like brass drone: slow lip attack, strong upper partials, a little breath."""
    rng = np.random.default_rng(seed)
    n = int(dur * sr)
    t = np.arange(n) / sr
    glide = 1 - 0.05 * np.exp(-t / 0.18)
    vib = 1 + 0.003 * np.sin(TAU * 4.3 * t) * np.minimum(1, t / 0.8)
    out = np.zeros(n)
    for det in (1.0, 1.0035):
        ph = np.cumsum(f0 * det * glide * vib) / sr
        for h in range(1, 15):
            if f0 * h > sr * 0.45:
                break
            formant = 1.0 + 1.6 * np.exp(-(((f0 * h) - 420.0) / 260.0) ** 2) + 0.7 * np.exp(-(((f0 * h) - 900.0) / 400.0) ** 2)
            out += formant * (1.0 / h ** 0.75) * np.sin(TAU * h * ph)
    out *= 0.5
    breath = unit(bp(rng.standard_normal(n), 300, 1500, sr)) * 0.04
    env = np.minimum(1, t / att) ** 1.5 * np.minimum(1, (dur - t) / rel) ** 1.2
    out = (out + breath) * env
    out = np.tanh(out * 0.9)
    return fade(out, sr, 0.005, 0.02)


def flute_tone(sr, f0, dur, att=0.06, rel=0.25, seed=2):
    rng = np.random.default_rng(seed)
    n = int(dur * sr)
    t = np.arange(n) / sr
    vib = 1 + 0.006 * np.sin(TAU * 5.0 * t) * np.minimum(1, t / 0.4)
    ph = np.cumsum(f0 * vib) / sr
    tone = np.sin(TAU * ph) + 0.35 * np.sin(TAU * 2 * ph) + 0.08 * np.sin(TAU * 3 * ph)
    breath = unit(bp(rng.standard_normal(n), f0 * 1.5, f0 * 6, sr)) * 0.07
    env = np.minimum(1, t / att) * np.minimum(1, np.maximum(0, (dur - t)) / rel)
    return fade((tone + breath) * env, sr, 0.003, 0.02)


# ---------------------------------------------------------------- sound effects

def build_sfx():
    # ---- hooves, one loop per gait (stride patterns: walk 4-beat, trot 2-beat, canter 3-beat+gap, gallop 4-beat+gap).
    # Stride lengths equal the horse.glb animation cycles (walk 1.067 s, trot 0.533, canter 0.6, gallop 0.467).
    hoof_loop("hooves_walk", 1.0667, [(0.00, 0.95, 0.55, False), (0.25, 1.10, 0.50, False),
                                    (0.50, 0.95, 0.55, False), (0.75, 1.10, 0.50, False)], 2, 0.6)
    hoof_loop("hooves_trot", 0.5333, [(0.00, 1.0, 0.80, True), (0.50, 1.0, 0.75, True)], 4, 0.3)
    hoof_loop("hooves_canter", 0.60, [(0.00, 0.92, 0.75, False), (0.30, 1.0, 0.85, True), (0.61, 1.12, 0.80, False)], 4, 0.15)
    hoof_loop("hooves_gallop", 0.4667, [(0.00, 0.90, 0.80, False), (0.167, 0.95, 0.70, False),
                                      (0.405, 1.10, 0.85, False), (0.62, 1.15, 0.90, False)], 5, 0.0)

    # ---- wind: periodic noise with slow gusts
    rng = rng_for("wind")
    n = int(6.0 * SR)
    w = rng.standard_normal(n)
    w = fshape(w, lambda f: (1.0 / np.sqrt(1 + (f / 1500.0) ** 4)) / (1 + f / 150.0) ** 0.7 * np.sqrt(1 + (60.0 / f) ** 4) ** -1, SR)
    t = np.arange(n) / SR
    gust = 0.62 + 0.25 * np.sin(TAU * t / 6.0 + 1.0) + 0.18 * np.sin(TAU * 2 * t / 6.0 + 2.0) + 0.10 * np.sin(TAU * 3 * t / 6.0)
    whistle = unit(bp(rng.standard_normal(n), 700, 1100, SR)) * (0.5 + 0.5 * np.sin(TAU * 2 * t / 6.0 + 0.5)) * 0.25
    save("wind", unit(w) * gust + whistle * gust, SR, 0.7, loop=True)

    # ---- crowd: a murmur of formant-filtered noise with swells and a few cheers
    rng = rng_for("crowd")
    n = int(8.0 * SR)
    t = np.arange(n) / SR
    base = unit(bp(rng.standard_normal(n), 220, 3200, SR))
    base = peaking(base, 520, 1.2, 2.2, SR)
    base = peaking(base, 1350, 1.0, 1.8, SR)
    out = np.zeros(n)
    for k in range(5):
        voice = unit(bp(rng.standard_normal(n), 300 + 150 * k, 900 + 350 * k, SR))
        am = 0.55 + 0.45 * np.sin(TAU * (k + 1) * t / 8.0 + rng.uniform(0, TAU)) * np.sin(TAU * (2 * k + 3) * t / 8.0 + rng.uniform(0, TAU))
        out += voice * np.abs(am) * 0.45
    swell = 0.6 + 0.4 * np.sin(TAU * t / 8.0 - 1.0) + 0.2 * np.sin(TAU * 3 * t / 8.0)
    cheer = unit(bp(rng.standard_normal(n), 900, 2600, SR)) * np.maximum(0, np.sin(TAU * 2 * t / 8.0 + 0.7)) ** 3 * 0.9
    save("crowd", (base * 0.8 + out + cheer) * swell, SR, 0.7, loop=True)

    # ---- hits: short and dry
    r = rng_for("hit_light")
    n = int(0.16 * SR)
    t = np.arange(n) / SR
    thump = osc(200 * (1 + 0.8 * np.exp(-t / 0.02)), SR) * ex(n, 0.03, SR)
    slap = unit(bp(r.standard_normal(n), 900, 4500, SR)) * ex(n, 0.014, SR)
    save("hit_light", fade(0.7 * thump + 0.6 * slap, SR, 0.0005, 0.02), SR, 0.85)

    r = rng_for("hit_heavy")
    n = int(0.42 * SR)
    t = np.arange(n) / SR
    thump = osc(55 + 90 * np.exp(-t / 0.05), SR) * ex(n, 0.11, SR)
    body = unit(bp(r.standard_normal(n), 140, 1100, SR)) * ex(n, 0.05, SR)
    crack = unit(bp(r.standard_normal(n), 1600, 6000, SR)) * ex(n, 0.008, SR)
    save("hit_heavy", fade(soft(1.0 * thump + 0.5 * body + 0.4 * crack, 1.4), SR, 0.0005, 0.04), SR, 0.9)

    n = int(0.9 * SR)
    t = np.arange(n) / SR
    r = rng_for("clang")
    clang = bell_tone(SR, 780, 0.9, (1.0, 2.32, 3.61, 5.18, 6.97, 9.3), (1.0, 0.8, 0.6, 0.45, 0.3, 0.2), 0.35)
    clang += 0.6 * unit(bp(r.standard_normal(n), 2500, 9000, SR)) * ex(n, 0.012, SR)
    save("clang", clang, SR, 0.85)

    r = rng_for("whoosh")
    n = int(0.36 * SR)
    t = np.arange(n) / SR
    noise = r.standard_normal(n)
    out = np.zeros(n)
    centers = np.linspace(500, 3200, 5)
    for i, c in enumerate(centers):
        band = unit(bp(noise, c * 0.6, c * 1.5, SR))
        pos = i / (len(centers) - 1)
        out += band * np.exp(-((t / 0.36 - (0.25 + 0.5 * pos)) / 0.16) ** 2)
    out *= np.sin(np.pi * np.minimum(1, t / 0.36)) ** 1.2
    save("whoosh", fade(out, SR, 0.01, 0.05), SR, 0.7)

    r = rng_for("whip")
    n = int(0.3 * SR)
    t = np.arange(n) / SR
    pre = unit(bp(r.standard_normal(n), 1500, 6000, SR)) * np.exp(-((t - 0.07) / 0.035) ** 2) * 0.35
    crack = unit(bp(r.standard_normal(n), 2500, 9500, SR)) * np.where(t > 0.1, np.exp(-(t - 0.1) / 0.012), 0.0)
    save("whip", fade(pre + crack, SR, 0.002, 0.04), SR, 0.85)

    r = rng_for("bow_draw")
    n = int(0.75 * SR)
    t = np.arange(n) / SR
    creak = (2 * ((np.cumsum(80 + 70 * t / 0.75) / SR) % 1.0) - 1)
    stick = np.abs(unit(lp(r.standard_normal(n), 45, SR))) ** 1.5
    creak = bp(creak * stick, 180, 1800, SR) + 0.2 * unit(bp(r.standard_normal(n), 800, 2500, SR)) * stick * 0.4
    save("bow_draw", fade(unit(creak) * np.minimum(1, t / 0.15) * 0.5, SR, 0.02, 0.06), SR, 0.8)

    n = int(0.5 * SR)
    t = np.arange(n) / SR
    r = rng_for("bow_loose")
    string = ks(300, 0.5, SR, t60=0.35, bright=0.9, pos=0.4, seed=3)
    air = unit(bp(r.standard_normal(n), 1200, 5000, SR)) * ex(n, 0.04, SR)
    thump = osc(140 * (1 + 0.5 * np.exp(-t / 0.02)), SR) * ex(n, 0.03, SR)
    save("bow_loose", 0.9 * string + 0.5 * air + 0.5 * thump, SR, 0.8)

    r = rng_for("sling")
    n = int(0.8 * SR)
    t = np.arange(n) / SR
    rate = 7 + 12 * (t / 0.55)
    whirl = unit(bp(r.standard_normal(n), 300, 2400, SR)) * (0.5 + 0.5 * np.sin(TAU * np.cumsum(rate) / SR)) * np.where(t < 0.55, np.minimum(1, t / 0.2), 0)
    zip_ = unit(bp(r.standard_normal(n), 1800, 7000, SR)) * np.where(t >= 0.55, np.exp(-(t - 0.55) / 0.05), 0)
    save("sling", fade(0.7 * whirl + 0.8 * zip_, SR, 0.01, 0.05), SR, 0.7)

    r = rng_for("rope")
    n = int(0.55 * SR)
    t = np.arange(n) / SR
    swish = unit(bp(r.standard_normal(n), 400, 2800, SR)) * np.exp(-((t - 0.22) / 0.12) ** 2)
    creak = unit(bp(r.standard_normal(n), 600, 1400, SR)) * (0.5 + 0.5 * np.sin(TAU * 38 * t)) * np.exp(-((t - 0.3) / 0.2) ** 2) * 0.35
    thwip = unit(bp(r.standard_normal(n), 1500, 5000, SR)) * np.where(t > 0.34, np.exp(-(t - 0.34) / 0.02), 0) * 0.7
    save("rope", fade(swish + creak + thwip, SR, 0.01, 0.05), SR, 0.7)

    r = rng_for("crash")
    n = int(1.0 * SR)
    t = np.arange(n) / SR
    thump = osc(48 + 70 * np.exp(-t / 0.07), SR) * ex(n, 0.18, SR)
    rumble = unit(bp(r.standard_normal(n), 90, 2200, SR)) * ex(n, 0.2, SR)
    out = thump + 0.55 * rumble
    for _ in range(7):
        at = int(r.uniform(0.08, 0.7) * SR)
        tick = unit(bp(r.standard_normal(1200), 900 * r.uniform(0.6, 1.8), 4500, SR)) * ex(1200, 0.008, SR)
        mix_at(out, tick, at, r.uniform(0.1, 0.3))
    save("crash", fade(soft(out, 1.3), SR, 0.001, 0.08), SR, 0.9)

    r = rng_for("grunt")
    n = int(0.3 * SR)
    t = np.arange(n) / SR
    f0 = 150 - 60 * t / 0.3
    ph = np.cumsum(f0) / SR
    voice = sum(np.sin(TAU * h * ph) / h for h in range(1, 40) if h * 150 < SR * 0.45)
    voice = peaking(voice, 520, 1.4, 4.0, SR)
    voice = peaking(voice, 1050, 1.4, 3.0, SR)
    voice = lp(voice, 3000, SR)
    env = np.minimum(1, t / 0.02) * np.exp(-t / 0.11)
    save("grunt", fade((unit(voice) + 0.25 * unit(bp(r.standard_normal(n), 500, 2500, SR))) * env, SR, 0.002, 0.03), SR, 0.7)

    save("bell", bell_tone(SR, 660, 1.8, tau=1.1), SR, 0.7)
    save("drum_hit", frame_drum(SR, 85, 0.55, 0.15), SR, 0.9)
    save("cymbal", cymbal(SR, 1.6, 0.6), SR, 0.7)
    save("horn", horn_tone(SR, 62.0, 3.6, 0.45, 0.9), SR, 0.4)

    flag = np.zeros(int(0.8 * SR))
    mix_at(flag, ks(660, 0.7, SR, t60=0.9, bright=0.8, seed=11), 0, 0.8)
    mix_at(flag, ks(990, 0.6, SR, t60=0.9, bright=0.8, seed=12), int(0.09 * SR), 0.8)
    mix_at(flag, bell_tone(SR, 1980, 0.5, (1.0, 2.0), (0.4, 0.2), 0.3), int(0.09 * SR), 0.3)
    save("flag_up", flag, SR, 0.85)

    n = int(0.07 * SR)
    t = np.arange(n) / SR
    r = rng_for("ui_move")
    tick = np.sin(TAU * 1400 * t) * ex(n, 0.012, SR) + 0.5 * unit(bp(r.standard_normal(n), 2000, 6000, SR)) * ex(n, 0.004, SR)
    save("ui_move", fade(tick, SR, 0.0005, 0.01), SR, 0.6)

    ok = np.zeros(int(0.45 * SR))
    mix_at(ok, ks(523.25, 0.4, SR, t60=0.5, bright=0.8, seed=21), 0, 0.8)
    mix_at(ok, ks(783.99, 0.4, SR, t60=0.6, bright=0.8, seed=22), int(0.07 * SR), 0.9)
    save("ui_ok", ok, SR, 0.8)

    back = np.zeros(int(0.35 * SR))
    mix_at(back, ks(440, 0.3, SR, t60=0.4, bright=0.7, seed=23), 0, 0.8)
    mix_at(back, ks(329.63, 0.3, SR, t60=0.4, bright=0.7, seed=24), int(0.06 * SR), 0.8)
    save("ui_back", back, SR, 0.7)

    save("count", fade(bell_tone(SR, 587.33, 0.3, (1.0, 2.0, 3.0), (1.0, 0.4, 0.2), 0.12), SR, 0.001, 0.03), SR, 0.7)
    go = bell_tone(SR, 880, 0.7, (1.0, 2.0, 3.0, 4.2), (1.0, 0.5, 0.3, 0.2), 0.35)
    mix_at(go, cymbal(SR, 0.6, 0.25, seed=9), 0, 0.35)
    save("go", go, SR, 0.8)

    coin = np.zeros(int(0.5 * SR))
    mix_at(coin, bell_tone(SR, 1568, 0.4, (1.0, 2.0, 3.01), (1.0, 0.4, 0.2), 0.18), 0, 0.8)
    mix_at(coin, bell_tone(SR, 2093, 0.4, (1.0, 2.0, 3.01), (1.0, 0.4, 0.2), 0.2), int(0.07 * SR), 0.8)
    save("coin", coin, SR, 0.6)

    r = rng_for("second_wind")
    n = int(1.2 * SR)
    t = np.arange(n) / SR
    sweep = osc(180 * 2 ** (t / 0.5), SR) * np.minimum(1, t / 0.15) * np.minimum(1, (1.2 - t) / 0.4)
    shimmer = unit(hp(r.standard_normal(n), 3500, SR)) * (t / 1.2) * np.minimum(1, (1.2 - t) / 0.3)
    low = horn_tone(SR, 98.0, 1.2, 0.3, 0.5)
    save("second_wind", 0.4 * sweep + 0.25 * shimmer + 0.5 * low[:n], SR, 0.75)

    r = rng_for("splash")
    n = int(0.55 * SR)
    t = np.arange(n) / SR
    out = unit(lp(r.standard_normal(n), 1400, SR)) * ex(n, 0.12, SR)
    for _ in range(6):
        at = int(r.uniform(0.04, 0.4) * SR)
        m = int(0.05 * SR)
        tt = np.arange(m) / SR
        f = r.uniform(300, 700)
        mix_at(out, np.sin(TAU * (f + 900 * tt) * tt) * ex(m, 0.015, SR), at, r.uniform(0.15, 0.3))
    save("splash", fade(out, SR, 0.002, 0.06), SR, 0.7)

    n = int(0.25 * SR)
    t = np.arange(n) / SR
    r = rng_for("land")
    land = osc(90 * (1 + 0.8 * np.exp(-t / 0.03)), SR) * ex(n, 0.06, SR) + 0.4 * unit(bp(r.standard_normal(n), 200, 1500, SR)) * ex(n, 0.03, SR)
    save("land", fade(land, SR, 0.001, 0.03), SR, 0.7)


# ---------------------------------------------------------------- music

class Song:
    def __init__(self, name, bpm, bars, root, scale, seed):
        self.name, self.bpm, self.bars = name, bpm, bars
        self.root, self.scale = root, scale
        self.step = 60.0 / bpm / 4.0
        self.n = int(round(bars * 16 * self.step * MSR))
        self.buf = np.zeros(self.n)
        self.rng = np.random.default_rng(seed)
        self.cache = {}

    def at(self, step, jitter=0.0):
        return int(round((step * self.step + (self.rng.uniform(-jitter, jitter) if jitter else 0.0)) * MSR))

    def note_midi(self, idx):
        octave, deg = divmod(idx, 5)
        return self.root + 12 * octave + self.scale[deg]

    def pluck(self, midi, t60=1.3, bright=0.6, pos=0.18, variant=0):
        key = (midi, t60, bright, pos, variant)
        if key not in self.cache:
            dur = min(2.2, t60 * 1.15)
            self.cache[key] = ks(midi_hz(midi), dur, MSR, t60, bright, pos, seed=midi * 7 + variant)
        return self.cache[key]

    def lute(self, step, idx, gain=0.5, t60=1.2, bright=0.6, jitter=0.006, midi=None):
        m = midi if midi is not None else self.note_midi(idx)
        v = int(self.rng.integers(0, 3))
        mix_wrap(self.buf, self.pluck(m, t60, bright, 0.18, v), self.at(step, jitter), gain * self.rng.uniform(0.9, 1.1))

    def drum(self, step, pitch, gain, slap=0.0, dur=0.45):
        key = ("d", pitch, slap, dur)
        if key not in self.cache:
            self.cache[key] = frame_drum(MSR, pitch, dur, slap, np.random.default_rng(int(pitch * 10)))
        mix_wrap(self.buf, self.cache[key], self.at(step, 0.003), gain * self.rng.uniform(0.9, 1.08))

    def cym(self, step, gain, dur=0.25, tau=0.07, seed=3):
        key = ("c", dur, tau, seed)
        if key not in self.cache:
            self.cache[key] = cymbal(MSR, dur, tau, 1.0, seed)
        mix_wrap(self.buf, self.cache[key], self.at(step, 0.002), gain)

    def horn(self, step, midi, dur, gain):
        mix_wrap(self.buf, horn_tone(MSR, midi_hz(midi), dur, 0.5, 1.2), self.at(step), gain)

    def flute(self, step, idx, dur_steps, gain=0.35):
        d = dur_steps * self.step + 0.2
        mix_wrap(self.buf, flute_tone(MSR, midi_hz(self.note_midi(idx)), d, 0.07, 0.25), self.at(step), gain)

    def pad(self, midis, gain, periods):
        t = np.arange(self.n) / MSR
        out = np.zeros(self.n)
        for k, m in enumerate(midis):
            f = midi_hz(m)
            # whole cycles per loop keep the seam continuous
            f = round(f * self.n / MSR) * MSR / self.n
            lfo = 0.6 + 0.4 * np.sin(TAU * periods * (k + 1) * t / (self.n / MSR) + k)
            out += (np.sin(TAU * f * t) + 0.3 * np.sin(TAU * 2 * f * t + 0.5) + 0.12 * np.sin(TAU * 3 * f * t + 1.0)) * lfo
        self.buf += gain * out / len(midis)

    def finish(self, echo_steps=3, echo=0.22, lowpass=9000, target_rms=0.13):
        x = self.buf
        d = int(round(echo_steps * self.step * MSR))
        x = x + echo * np.roll(x, d) + echo * 0.5 * np.roll(x, 2 * d)
        x = lp(x, lowpass, MSR, 2)
        x = hp(x, 35, MSR, 2)
        x -= np.mean(x)
        x = x / (np.sqrt(np.mean(x ** 2)) + 1e-9) * target_rms
        x = np.tanh(x / 0.9) * 0.9
        save(self.name, x, MSR, loop=True, norm=False)


def race_pattern(song, final=False):
    """Driving festival tune. Sections of 8 bars: hook, higher hook, breakdown, everything."""
    major = song.scale[1] == 2
    roots = [0, 0, 3, 3, 4, 4, 3, 3] if major else [0, 0, 2, 2, 1, 1, 3, 3]
    arp = [0, 2, 3, 2, 5, 3, 2, 3]
    hooks = {   # eighth-note slots over two bars -> scale index
        "A1": {0: 5, 2: 6, 3: 7, 5: 8, 6: 7, 8: 6, 10: 7, 11: 6, 12: 5, 14: 3},
        "A2": {0: 3, 2: 5, 3: 6, 5: 7, 6: 6, 8: 5, 9: 6, 10: 5, 11: 3, 13: 2, 15: 0},
        "B1": {0: 8, 2: 8, 3: 9, 4: 8, 5: 7, 7: 6, 8: 7, 10: 8, 11: 7, 12: 6, 13: 5},
        "B2": {0: 6, 1: 5, 2: 6, 3: 7, 5: 6, 6: 5, 7: 3, 8: 5, 10: 6, 11: 5, 12: 3, 14: 5},
    }
    for bar in range(song.bars):
        sec, b8 = divmod(bar, 8)
        b0 = bar * 16
        r = roots[b8]
        bm = song.note_midi(r) - 24
        calm = sec == 2 and b8 < 4
        song.lute(b0, 0, 0.55, 1.0, 0.25, 0.003, midi=bm)
        song.lute(b0 + 8, 0, 0.45, 0.9, 0.25, 0.003, midi=bm)
        if not calm:
            song.lute(b0 + 14, 0, 0.3, 0.6, 0.25, 0.003, midi=bm + 12)
        if not (sec == 2 and b8 < 2):
            for i, a in enumerate(arp):
                song.lute(b0 + i * 2, r + a, 0.34 if sec == 2 else 0.40, 0.9, 0.5)
        if b8 % 2 == 0:
            if sec == 3:
                pair = ("A1", "B1") if b8 < 4 else ("B2", "A2")
            elif sec == 1:
                pair = ("B1", "B2")
            else:
                pair = ("A1", "A2")
            name = pair[(b8 // 2) % 2]
            for slot, idx in hooks[name].items():
                song.lute(b0 + slot * 2, idx - (5 if sec == 2 else 0), 0.9, 1.1, 0.8)
        if b8 >= 6 and sec != 2:
            for i in range(0, 16, 2):
                song.lute(b0 + i + 1, r + 5 + (0, 2, 3)[(i // 2) % 3], 0.14, 0.5, 0.9)
        low = {0: 1.0, 3: 0.55, 8: 0.9, 11: 0.5} if not calm else {0: 0.9, 8: 0.7}
        for s_, g in low.items():
            song.drum(b0 + s_, 82 if s_ % 8 == 0 else 100, 0.55 * g)
        for s_ in ((4, 12) if not calm else (12,)):
            song.drum(b0 + s_, 150, 0.40, slap=0.8, dur=0.22)
        if not calm:
            for s_ in (6, 14):
                song.drum(b0 + s_, 125, 0.22, slap=0.2, dur=0.2)
        if sec >= 1 and not calm:
            for s_ in (2, 6, 10, 14):
                song.cym(b0 + s_, 0.20 if sec < 3 else 0.28, 0.22, 0.05, seed=3 + s_)
        if sec == 3:
            for s_ in (0, 4, 8, 12):
                song.cym(b0 + s_ + 1, 0.10, 0.12, 0.03, seed=40 + s_)
        if b8 == 0:
            song.cym(b0, 0.55, 1.6, 0.6, seed=77)
        if final and b8 % 4 == 0:
            song.horn(b0, bm, 8 * 60.0 / song.bpm, 0.25)
    return song


def menu_pattern(song):
    """Warm and unhurried: low drone, a slow lute figure, a flute line, soft frame drum, a bell now and then."""
    roots = [0, 0, 3, 3, 4, 4, 3, 2, 0, 0, 3, 3, 4, 4, 3, 0, 0, 0, 3, 3, 2, 2, 3, 0]
    song.pad([song.root - 24, song.root - 17, song.root - 12], 0.22, 1)
    melody = {   # bar within 8 -> {step: (scale index, length in steps)}
        0: {0: (5, 8), 8: (7, 6)}, 1: {0: (6, 8), 8: (5, 6)},
        2: {0: (7, 8), 8: (8, 6)}, 3: {0: (7, 6), 6: (6, 2), 8: (5, 8)},
        4: {0: (5, 8), 8: (7, 4), 12: (8, 4)}, 5: {0: (9, 8), 8: (8, 8)},
        6: {0: (7, 8), 8: (6, 6)}, 7: {0: (5, 12)},
    }
    arp = [0, 2, 3, 5, 3, 2, 3, 2]
    for bar in range(song.bars):
        b0 = bar * 16
        r = roots[bar % len(roots)]
        for i, a in enumerate(arp):
            song.lute(b0 + i * 2, r + a, 0.42, 1.8, 0.45, 0.01)
        song.lute(b0, 0, 0.55, 1.6, 0.2, 0.004, midi=song.note_midi(r) - 12)
        song.drum(b0, 78, 0.40)
        song.drum(b0 + 8, 92, 0.30)
        if bar % 2 == 1:
            song.drum(b0 + 14, 110, 0.18, slap=0.2, dur=0.2)
        if bar % 4 == 0:
            song.cym(b0, 0.22, 1.0, 0.45, seed=71)
        m = melody.get(bar % 8)
        if m and bar >= 2:
            for st, (idx, d) in m.items():
                song.flute(b0 + st, idx, d, 0.30)
        if bar % 3 == 2:
            mix_wrap(song.buf, bell_tone(MSR, midi_hz(song.root + 24 + song.scale[(bar // 3) % 5]), 2.0, tau=1.2), song.at(b0 + 12), 0.10)
    return song


def build_music():
    maj = [0, 2, 4, 7, 9]
    mino = [0, 3, 5, 7, 10]
    race = race_pattern(Song("music_race", 144, 32, 62, maj, 101))        # D major pentatonic, 53 s
    race.finish(3, 0.20, 9500, 0.135)
    final = race_pattern(Song("music_final", 156, 32, 64, mino, 202), final=True)   # E minor pentatonic, 49 s
    final.finish(3, 0.22, 9500, 0.14)
    menu = menu_pattern(Song("music_menu", 84, 24, 60, maj, 303))         # C major pentatonic, 69 s
    menu.finish(3, 0.28, 7500, 0.11)


def build_jingles():
    maj = [0, 2, 4, 7, 9]
    s = Song("jingle_win", 120, 2, 60, maj, 404)
    for st, idx, g in ((0, 0, 0.8), (2, 2, 0.8), (4, 3, 0.8), (6, 4, 0.8), (8, 5, 0.9), (12, 4, 0.7), (14, 5, 1.0)):
        s.lute(st, idx + 5, g, 1.0, 0.8, 0.0)
    s.drum(0, 80, 0.8)
    s.drum(8, 80, 0.7)
    s.cym(14, 0.6, 1.4, 0.5, seed=5)
    x = s.buf.copy()
    x = x + 0.2 * np.roll(x, int(0.2 * MSR))
    save("jingle_win", x, MSR, 0.8)
    l = np.zeros(int(2.2 * MSR))
    for k, m in enumerate((67, 64, 60)):
        mix_at(l, ks(midi_hz(m), 1.4, MSR, 1.0, 0.45, 0.2, seed=60 + k), int(k * 0.34 * MSR), 0.8)
    mix_at(l, frame_drum(MSR, 70, 0.6), int(0.9 * MSR), 0.6)
    save("jingle_lose", l, MSR, 0.7)


def check_pitch():
    """Karplus-Strong tuning check: reports the worst deviation in cents over a range of notes."""
    worst = 0.0
    for midi in (38, 45, 50, 57, 62, 69, 74, 81, 86):
        f = midi_hz(midi)
        x = ks(f, 0.6, MSR, 3.0, 0.5, 0.1, seed=1)
        x = x * np.hanning(len(x))
        spec = np.abs(np.fft.rfft(x, 1 << 19))
        freqs = np.fft.rfftfreq(1 << 19, 1.0 / MSR)
        win = (freqs > f * 0.8) & (freqs < f * 1.2)
        k = np.argmax(np.where(win, spec, 0))
        cents = 1200 * math.log2(freqs[k] / f)
        worst = max(worst, abs(cents))
    return worst


def main():
    only = sys.argv[1:]
    build_sfx()
    build_music()
    build_jingles()
    print("%-16s %6s %6s %7s %7s %5s %7s %5s  bands %%: <250 <1k <4k >4k" % ("name", "sr", "sec", "peak", "rms", "clip", "KB", "seam"))
    total = 0.0
    for name, sr, dur, pk, rms, clip, kb, seam, bands in REPORT:
        total += kb
        print("%-16s %6d %6.2f %7.1f %7.1f %5d %7.0f %5s  %s" % (name, sr, dur, pk, rms, clip, kb, seam, bands))
    print("total %.1f MB in %d files; karplus-strong worst pitch error %.1f cents" % (total / 1024.0, len(REPORT), check_pitch()))


if __name__ == "__main__":
    main()
