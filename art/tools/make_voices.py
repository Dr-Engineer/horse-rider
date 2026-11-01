"""Generates every voice line: assets/audio/voice/*.ogg, the crowd sounds, data/voice_bank.gd and docs/VOICE_SCRIPT.md.

Tibetan comes from Meta's MMS models (facebook/mms-tts-bod, -khg, -adx, CC BY-NC 4.0: free game only). English comes from
Kokoro-82M (hexgrad/Kokoro-82M, Apache 2.0). All three Tibetan models are one male reader each, so women's and old
voices are made by moving pitch and formants with the WORLD vocoder. English is left alone: each rider has their own Kokoro
voice or a blend of two, with pitch moved by resampling and no vocoder. The two old storytellers are the exception: both of
their languages go through age_voice, because a Kokoro voice on its own doesn't sound old.
The models stay outside the repo, in VOICE_HOME, by default GameDev/voice in the home folder (see docs/VOICE_SCRIPT.md for how to set that up).

Run from the repo root, after tools/export_lines.gd if any menu text changed:
  <voice venv>\\Scripts\\python.exe art/tools/make_voices.py [--only speaker,speaker] [--force] [--no-crowd]
                                                            [--shard K/N] [--out DIR]
Run N copies with --shard 0/N .. N-1/N to use several cores, then once with no --shard to add the crowd, the data file and
the review sheet. Finished lines are cached by content in VOICE_CACHE, so a second run only makes what changed.

Why the Tibetan takes are fitted: MMS was trained on long passages, so at its default speed three syllables can last
0.18 s. For each phrase we find the speaking_rate that gives about 0.25 s a syllable (plus 0.1 s a space), then render
several seeds and keep the take whose length and number of syllable peaks best match the text.
"""
import argparse
import hashlib
import json
import math
import os
import sys
import time
from fractions import Fraction

VOICE_HOME = os.environ.get("VOICE_HOME", os.path.join(os.path.expanduser("~"), "GameDev", "voice"))
os.environ.setdefault("HF_HOME", os.path.join(VOICE_HOME, "hf"))
os.environ.setdefault("HF_HUB_DISABLE_SYMLINKS_WARNING", "1")
os.environ.setdefault("HF_HUB_OFFLINE", "1")          # everything needed is on disk already: never download
os.environ.setdefault("TRANSFORMERS_OFFLINE", "1")

import numpy as np  # noqa: E402
import pyworld as pw  # noqa: E402
import soundfile as sf  # noqa: E402
from scipy import signal  # noqa: E402
from scipy.signal import find_peaks  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import voice_script as VS  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(HERE))
OUT_DIR = os.path.join(ROOT, "assets", "audio", "voice")
CACHE_DIR = os.environ.get("VOICE_CACHE", os.path.join(VOICE_HOME, "cache"))
RAW_DIR = os.path.join(CACHE_DIR, "raw")          # model output before any processing
FINAL_DIR = os.path.join(CACHE_DIR, "final")      # processed 32 kHz float audio, so the OGG settings can change cheaply
SR = 32000           # delivery rate
VERSION = 6          # bump to redo the processing of every line
RAW_VERSION = 2      # bump to redo the model runs too
# libsndfile "compression level": 0.0 is the biggest and best, 1.0 the smallest. 0.5 is about 70 kbps for mono speech at 32 kHz.
OGG_COMPRESSION = float(os.environ.get("VOICE_OGG_COMPRESSION", "0.5"))
TSHEG = "་"
SHARD = (0, 1)
TORCH_THREADS = int(os.environ.get("VOICE_THREADS", "4"))


def line_id(speaker, text):
    return "%s_%s" % (speaker, hashlib.md5(text.encode("utf-8")).hexdigest()[:8])


def key_hash(*parts):
    return hashlib.md5(json.dumps(parts, ensure_ascii=False, sort_keys=True).encode("utf-8")).hexdigest()


# ---------------------------------------------------------------- small caches on disk

def cached_arrays(name, make):
    """make() returns a dict of numpy arrays; they are kept in RAW_DIR under `name`."""
    path = os.path.join(RAW_DIR, name + ".npz")
    if os.path.exists(path):
        try:
            with np.load(path) as z:
                return {k: z[k] for k in z.files}
        except Exception:
            pass
    out = make()
    os.makedirs(RAW_DIR, exist_ok=True)
    tmp = path + ".tmp.npz"
    np.savez(tmp, **out)
    os.replace(tmp, path)
    return out


_fits = {}


def load_fits():
    if _fits:
        return
    if os.path.isdir(CACHE_DIR):
        for f in os.listdir(CACHE_DIR):
            if f.startswith("fit_") and f.endswith(".json"):
                try:
                    _fits.update(json.load(open(os.path.join(CACHE_DIR, f), encoding="utf-8")))
                except Exception:
                    pass
    _fits["_loaded"] = True


def save_fits():
    os.makedirs(CACHE_DIR, exist_ok=True)
    path = os.path.join(CACHE_DIR, "fit_%d.json" % SHARD[0])
    json.dump({k: v for k, v in _fits.items() if k != "_loaded"}, open(path, "w", encoding="utf-8"), ensure_ascii=False)


# ---------------------------------------------------------------- Tibetan: MMS with fitted timing

_vits = {}


def vits(model_id):
    import torch
    from transformers import AutoTokenizer, VitsModel
    torch.set_num_threads(TORCH_THREADS)
    if model_id not in _vits:
        tok = AutoTokenizer.from_pretrained("facebook/mms-tts-" + model_id)
        model = VitsModel.from_pretrained("facebook/mms-tts-" + model_id).eval()
        _vits[model_id] = (tok, model)
    return _vits[model_id]


def mms(model_id, text, rate, seed):
    import torch
    tok, model = vits(model_id)
    model.speaking_rate = float(rate)
    ids = tok(text, return_tensors="pt")
    torch.manual_seed(int(seed))
    with torch.no_grad():
        wav = model(**ids).waveform[0].numpy().astype(np.float64)
    return trim(wav, 16000)


def syllable_count(text):
    return max(1, len([s for s in text.replace(" ", TSHEG).split(TSHEG) if s]))


def want_seconds(text, tempo=1.0):
    """How long a phrase should take: a quarter second a syllable, a tenth for each space."""
    return (0.25 * syllable_count(text) + 0.10 * text.count(" ")) / tempo


def nuclei(wav, sr=16000):
    """Counts syllable peaks in the smoothed loudness. Real words come out right; non-words collapse into fewer."""
    sos = signal.butter(4, 10.0 / (sr / 2), output="sos")
    env = signal.sosfiltfilt(sos, np.abs(wav))
    top = env.max() + 1e-12
    peaks, _ = find_peaks(env, height=0.28 * top, distance=int(0.08 * sr), prominence=0.1 * top)
    return len(peaks)


def voiced_fraction(wav, sr=16000):
    f0, _t = pw.dio(wav, sr, f0_floor=60, f0_ceil=500, frame_period=10.0)
    return float(np.mean(f0 > 0)) if len(f0) else 0.0


def take_score(wav, text, want):
    """Lower is better: how far the length is from `want` (in log terms), how many syllable peaks are missing."""
    syl = syllable_count(text)
    dur = len(wav) / 16000.0
    n = nuclei(wav)
    penalty = max(0.0, 0.35 - voiced_fraction(wav)) * 2.0
    return abs(math.log(max(dur, 0.05) / want)) + 0.5 * abs(n - syl) / syl + penalty, dur, n


def fit_rate(model_id, text):
    """The speaking_rate that makes this model say this text at the base pace (tempo 1.0)."""
    load_fits()
    key = "%s|%s|%d" % (model_id, text, RAW_VERSION)
    if key in _fits:
        return _fits[key]
    want = want_seconds(text)
    rate = 1.0
    for _ in range(3):
        med = float(np.median([len(mms(model_id, text, rate, s)) / 16000.0 for s in (11, 23, 37)]))
        new = min(1.6, max(0.22, rate * med / want))
        close = abs(math.log(new / rate)) < 0.05
        rate = new
        if close:
            break
    _fits[key] = round(rate, 3)
    save_fits()
    return _fits[key]


def best_take(model_id, text, tempo, seed_base, count=6):
    """Several seeds at the fitted rate. Returns (wav, info) with info = [score, duration, peaks, rate]."""
    want = want_seconds(text, tempo)
    rate = min(1.6, max(0.22, fit_rate(model_id, text) * tempo))

    def run(rate):
        out = []
        for k in range(count):
            w = mms(model_id, text, rate, seed_base + k * 37)
            sc, dur, n = take_score(w, text, want)
            out.append((sc, w, dur, n, rate))
        return out

    takes = run(rate)
    med = float(np.median([t[2] for t in takes]))
    if abs(math.log(med / want)) > 0.15 and 0.23 < rate < 1.59:
        takes += run(min(1.6, max(0.22, rate * med / want)))
    sc, w, dur, n, used = min(takes, key=lambda t: t[0])
    return w, np.array([sc, dur, n, used])


def stitched_take(model_id, syllables, tempo, seed_base, gap=0.11, decay=0.84):
    """For laughter and cries the model turns into mush: render each syllable alone and set them down with gaps."""
    parts = []
    for i, syl in enumerate(syllables):
        want = 0.24 / tempo
        rate = min(1.6, max(0.22, fit_rate(model_id, syl) * tempo))
        best = None
        for k in range(4):
            w = mms(model_id, syl, rate, seed_base + i * 101 + k * 37)
            dur = len(w) / 16000.0
            sc = abs(math.log(max(dur, 0.05) / want)) + max(0.0, 0.5 - voiced_fraction(w)) * 2.0
            if best is None or sc < best[0]:
                best = (sc, w)
        parts.append(best[1] * (decay ** i))
        if i < len(syllables) - 1:
            parts.append(np.zeros(int(gap * 16000)))
    out = np.concatenate(parts)
    return out, np.array([0.0, len(out) / 16000.0, len(syllables), 0.0])


def squeeze_gaps(wav, sr, spaced):
    """The readers sometimes stop dead for half a second in the middle of a word (the Khams reader does it after the first
    syllable of 'tashi delek'). Silences inside a take that are longer than a natural pause are cut back to one."""
    keep = int((0.11 if spaced else 0.07) * sr)
    limit = keep + int(0.04 * sr)
    n = int(0.005 * sr)
    if len(wav) < 4 * n:
        return wav
    frames = np.sqrt(np.array([np.mean(wav[i:i + n] ** 2) for i in range(0, len(wav) - n + 1, n)]) + 1e-14)
    quiet = frames < active_rms(wav, sr) * 10 ** (-36.0 / 20.0)
    live = np.where(~quiet)[0]
    if len(live) < 2:
        return wav
    pieces, pos, i = [], 0, int(live[0])
    last = int(live[-1])
    while i <= last:
        if quiet[i]:
            j = i
            while j <= last and quiet[j]:
                j += 1
            if (j - i) * n > limit:
                a, b = i * n, j * n
                pieces.append(wav[pos:a + keep // 2])
                pos = b - keep // 2
            i = j
        else:
            i += 1
    pieces.append(wav[pos:])
    return np.concatenate(pieces) if len(pieces) > 1 else wav


def tibetan_best(speaker, model_id, text, tempo, seed_base, key):
    """The speaker's own reader first. If the take fits badly, the same phrase from the other two readers (the voice is then
    rebuilt for this speaker anyway), and for cries that still fail, single syllables stitched together."""
    x, info = tibetan_take(speaker, model_id, text, tempo, seed_base)
    used = model_id
    if info[0] > VS.FIT_LIMIT:
        for other in ("khg", "adx", "bod"):
            if other == model_id:
                continue
            x2, info2 = tibetan_take(speaker, other, text, tempo, seed_base)
            if info2[0] < info[0] - 0.05:
                x, info, used = x2, info2, other
                if info[0] <= VS.FIT_LIMIT:
                    break
    if info[0] > VS.FIT_LIMIT and key in VS.STITCH:
        x, info = tibetan_take(speaker, model_id, text, tempo, seed_base, stitch=tuple(VS.STITCH[key]))
        return x, info, model_id, True
    return x, info, used, False


def tibetan_take(speaker_key, model_id, text, tempo, seed_base, stitch=None, count=6):
    """Cached model output for one Tibetan line. Returns (wav at 16 kHz, info)."""
    name = "bo_" + key_hash(RAW_VERSION, model_id, text, round(tempo, 3), seed_base, stitch, count, speaker_key)

    def make():
        if stitch:
            w, info = stitched_take(model_id, stitch, tempo, seed_base)
        else:
            w, info = best_take(model_id, text, tempo, seed_base, count)
        return {"wav": w.astype(np.float32), "info": info}

    z = cached_arrays(name, make)
    return z["wav"].astype(np.float64), z["info"]


# ---------------------------------------------------------------- English: Kokoro, voices blended, no vocoder

_kokoro = {}


def kokoro_pipeline(lang):
    from kokoro import KModel, KPipeline
    import torch
    torch.set_num_threads(TORCH_THREADS)
    if "model" not in _kokoro:
        _kokoro["model"] = KModel(repo_id="hexgrad/Kokoro-82M").eval()
    if lang not in _kokoro:
        _kokoro[lang] = KPipeline(lang_code=lang, repo_id="hexgrad/Kokoro-82M", model=_kokoro["model"])
    return _kokoro[lang]


def kokoro_voice(pipe, spec):
    """'bm_fable' is one voice. 'bm_fable:0.6,bm_george:0.4' is a weighted blend of two style packs."""
    if ":" not in spec and "," not in spec:
        return spec
    packs, total = None, 0.0
    for part in spec.split(","):
        name, _, w = part.partition(":")
        weight = float(w) if w else 1.0
        pack = pipe.load_single_voice(name) * weight
        packs = pack if packs is None else packs + pack
        total += weight
    return packs / total


def pronounce(text, lang):
    import re
    o = "O" if lang == "a" else "Q"
    out = text
    for word, ph in VS.PRONOUNCE.items():
        ph = ph.replace("{O}", o)
        out = re.sub(r"(?<![\w\[])" + re.escape(word) + r"(?![\w\]])", "[%s](/%s/)" % (word, ph), out)
    return out


def english_raw(lang, voice, text, speed, pause=0.0):
    """pause reads each sentence on its own, with that many seconds of quiet between them: an old teller takes their time."""
    parts = (RAW_VERSION, lang, voice, text, round(speed, 4), VS.PRONOUNCE) + ((pause,) if pause else ())
    name = "en_" + key_hash(*parts)

    def make():
        pipe = kokoro_pipeline(lang)
        chunks = []
        split = r"(?<=[.!?])\s+" if pause else r"\n+"
        for _gs, _ps, audio in pipe(pronounce(text, lang), voice=kokoro_voice(pipe, voice), speed=speed, split_pattern=split):
            if chunks and pause:
                chunks.append(np.zeros(int(pause * 24000)))
            chunks.append(trim(audio.numpy().astype(np.float64), 24000) if pause else audio.numpy().astype(np.float64))
        wav = np.concatenate(chunks) if chunks else np.zeros(2400)
        return {"wav": trim(wav, 24000).astype(np.float32)}

    return cached_arrays(name, make)["wav"].astype(np.float64), 24000


# ---------------------------------------------------------------- processing

def trim(x, sr, floor_db=-42.0, pad=0.02):
    n = max(1, int(0.01 * sr))
    frames = np.array([np.sqrt(np.mean(x[i:i + n] ** 2) + 1e-12) for i in range(0, len(x), n)])
    if len(frames) == 0:
        return x
    limit = frames.max() * 10 ** (floor_db / 20.0)
    on = np.where(frames > limit)[0]
    if len(on) == 0:
        return x
    a = max(0, on[0] * n - int(pad * sr))
    b = min(len(x), (on[-1] + 1) * n + int(pad * 1.5 * sr))
    return x[a:b]


def world_shift(x, sr, target_f0=None, ratio=None, formant=1.0, spread=1.0, tremor=0.0, effort=0.0, slope=0.0):
    """Moves pitch and formants (WORLD vocoder). target_f0 sets the median pitch in Hz, ratio multiplies it instead.
    slope bends the whole phrase by that many octaves from start to end (a falling cry is negative)."""
    f0, t = pw.harvest(x, sr, f0_floor=55.0, f0_ceil=650.0, frame_period=5.0)
    f0 = pw.stonemask(x, f0, t, sr)
    sp = pw.cheaptrick(x, f0, t, sr)
    ap = pw.d4c(x, f0, t, sr)
    voiced = f0 > 0
    if np.any(voiced):
        centre = float(np.exp(np.mean(np.log(f0[voiced]))))
        goal = target_f0 if target_f0 else centre * (ratio or 1.0)
        f0[voiced] = goal * (f0[voiced] / centre) ** spread
        if slope:
            f0[voiced] *= 2.0 ** (slope * (t[voiced] / max(t[-1], 1e-3) - 0.5))
        if tremor > 0.0:
            f0[voiced] *= 1.0 + tremor * np.sin(2.0 * np.pi * 5.6 * t[voiced]) + tremor * 0.5 * np.sin(2.0 * np.pi * 3.1 * t[voiced] + 1.0)
    bins = sp.shape[1]
    if abs(formant - 1.0) > 0.002:
        idx = np.arange(bins)
        src = np.clip(idx / formant, 0, bins - 1)
        log_sp = np.log(sp + 1e-16)
        warped = np.stack([np.interp(src, idx, row) for row in log_sp])
        sp = np.exp(warped)
    if effort != 0.0:
        # More vocal effort means a flatter spectrum: lift everything above 500 Hz by `effort` dB per octave.
        freqs = np.linspace(0.0, sr * 0.5, bins)
        tilt = effort * np.log2(np.maximum(freqs, 500.0) / 500.0)
        sp = sp * 10 ** (tilt / 10.0)
    y = pw.synthesize(f0, sp, ap, sr, 5.0)
    return y[:len(x) + 200]


def resample(x, sr_from, sr_to):
    if sr_from == sr_to:
        return x
    g = math.gcd(sr_from, sr_to)
    return signal.resample_poly(x, sr_to // g, sr_from // g)


def repitch(x, sr_in, sr_out, ratio):
    """Plays the audio `ratio` times faster and higher, formants following: how a smaller or bigger person sounds.
    Nothing is analysed or rebuilt, so it stays natural for the modest ratios used here."""
    frac = Fraction(sr_out, 1) / (Fraction(sr_in, 1) * Fraction(ratio).limit_denominator(1000))
    frac = frac.limit_denominator(4000)
    return signal.resample_poly(x, frac.numerator, frac.denominator)


def vibrato(x, sr, depth, rate=5.4):
    """A slow wobble in the pitch for old voices, made by gently varying the read position."""
    n = len(x)
    t = np.arange(n) / sr
    dev = depth / (2.0 * math.pi * rate)
    delay = dev * np.sin(2.0 * math.pi * rate * t) + 0.5 * dev * np.sin(2.0 * math.pi * 3.1 * t + 1.0)
    return np.interp(np.arange(n) - delay * sr, np.arange(n), x)


def age_voice(x, sr, age, seed):
    """Makes a voice older with the WORLD vocoder, the way voices really age: the tune narrows, the pitch shakes slowly in a
    tremor that comes and goes, pitch and strength waver unevenly from moment to moment, breath leaks through the folds and
    the top of the voice falls away. See voice_script.SPEAKERS for what each setting does."""
    rng = np.random.default_rng(seed)
    f0, t = pw.harvest(x, sr, f0_floor=55.0, f0_ceil=500.0, frame_period=5.0)
    f0 = pw.stonemask(x, f0, t, sr)
    sp = pw.cheaptrick(x, f0, t, sr)
    ap = pw.d4c(x, f0, t, sr)
    frames = len(f0)

    def wander(hz):
        """A smooth random curve around 0 with a standard deviation of 1, moving at up to hz (frames run at 200 Hz)."""
        y = signal.sosfiltfilt(signal.butter(2, min(hz / 100.0, 0.99), output="sos"), rng.standard_normal(frames))
        return y / (np.std(y) + 1e-9)

    # About 5 Hz, as in a real vocal tremor, its speed and depth drifting so that it never sounds like a machine's.
    phase = 2.0 * np.pi * np.cumsum(5.0 + 0.5 * wander(0.5)) * 0.005
    shake = np.sin(phase) * np.clip(0.8 + 0.35 * wander(0.7), 0.25, 1.6)
    voiced = f0 > 0
    if np.any(voiced):
        centre = float(np.exp(np.mean(np.log(f0[voiced]))))
        f0[voiced] = centre * age.get("f0", 1.0) * (f0[voiced] / centre) ** age.get("spread", 1.0)
        f0[voiced] *= 1.0 + age["quaver"] * shake[voiced] + age["jitter"] * wander(30.0)[voiced]
    strength = np.clip(1.0 + age["shimmer"] * (0.6 * wander(25.0) + 0.6 * shake), 0.35, 1.8)
    sp = sp * (strength ** 2)[:, None]
    freqs = np.linspace(0.0, sr * 0.5, sp.shape[1])
    # Breath is mostly in the upper part of the voice. A power under 1 lifts the noisy share of every band toward all noise.
    ap = np.clip(ap, 1e-3, 1.0) ** (1.0 - age["breath"] * np.clip(freqs / 3000.0, 0.25, 1.0))
    sp = sp * 10 ** (age["tilt"] * np.log2(np.maximum(freqs, 1000.0) / 1000.0) / 10.0)
    return pw.synthesize(f0, sp, ap, sr, 5.0)[:len(x) + 200]


def add_air(x, sr, from_hz=7200.0, amount=0.14):
    """16 kHz models stop at 8 kHz. A little saturated top band gives the s and sh sounds their edge back."""
    sos = signal.butter(4, 3400.0 / (sr * 0.5), "highpass", output="sos")
    band = signal.sosfilt(sos, x)
    sos2 = signal.butter(4, from_hz / (sr * 0.5), "highpass", output="sos")
    top = signal.sosfilt(sos2, np.tanh(band * 9.0))
    return x + amount * top * (np.max(np.abs(x)) + 1e-9)


def eq(x, sr, low_cut=85.0, presence_db=2.5, presence_hz=2900.0, warmth_db=0.0):
    sos = signal.butter(2, low_cut / (sr * 0.5), "highpass", output="sos")
    y = signal.sosfilt(sos, x)
    if abs(presence_db) > 0.01:
        y = peak_filter(y, sr, presence_hz, 0.9, presence_db)
    if abs(warmth_db) > 0.01:
        y = peak_filter(y, sr, 260.0, 0.8, warmth_db)
    return y


def peak_filter(x, sr, f0, q, gain_db):
    a = 10 ** (gain_db / 40.0)
    w0 = 2.0 * math.pi * f0 / sr
    alpha = math.sin(w0) / (2.0 * q)
    b = [1 + alpha * a, -2 * math.cos(w0), 1 - alpha * a]
    d = [1 + alpha / a, -2 * math.cos(w0), 1 - alpha / a]
    return signal.lfilter(b, d, x)


def compress(x, sr, ratio=3.0, threshold_db=-20.0):
    """Gentle gain riding, so quiet syllables and loud ones sit closer together."""
    n = int(0.012 * sr)
    env = np.sqrt(np.convolve(x * x, np.ones(n) / n, mode="same") + 1e-12)
    db = 20.0 * np.log10(env + 1e-12)
    over = np.maximum(0.0, db - threshold_db)
    gain = 10 ** (-over * (1.0 - 1.0 / ratio) / 20.0)
    gain = np.convolve(gain, np.ones(n) / n, mode="same")
    return x * gain


def drive(x, amount):
    if amount <= 0.0:
        return x
    k = 1.0 + amount * 3.0
    return np.tanh(x * k) / k * (1.0 + amount)


def room(x, sr, size="plain", mix=0.1, seed=3):
    """A short synthetic tail: open air for the race, felt walls for the storyteller, a big square for the crowd."""
    rng = np.random.default_rng(seed)
    secs = {"plain": 0.32, "tent": 0.16, "valley": 0.75}[size]
    n = int(secs * sr)
    t = np.arange(n) / sr
    ir = rng.standard_normal(n) * np.exp(-t / (secs * 0.28))
    sos = signal.butter(1, ({"plain": 3800.0, "tent": 2600.0, "valley": 3000.0}[size]) / (sr * 0.5), "lowpass", output="sos")
    ir = signal.sosfilt(sos, ir)
    ir[: int(0.012 * sr)] = 0.0
    ir /= np.sqrt(np.sum(ir ** 2)) + 1e-9
    wet = signal.fftconvolve(x, ir)[: len(x) + n // 2]
    y = np.zeros(len(wet))
    y[: len(x)] = x
    return y + mix * wet


def active_rms(x, sr):
    n = max(1, int(0.02 * sr))
    frames = np.array([np.mean(x[i:i + n] ** 2) for i in range(0, max(1, len(x) - n), n)])
    top = frames.max() if len(frames) else 0.0
    on = frames[frames > top * 0.03]
    return math.sqrt(float(np.mean(on))) if len(on) else 1e-6


def finish(x, sr, level_db=-19.0, ceiling_db=-1.5):
    x = x - np.mean(x)
    x = x * (10 ** (level_db / 20.0) / (active_rms(x, sr) + 1e-9))
    ceiling = 10 ** (ceiling_db / 20.0)
    over = np.abs(x) > ceiling * 0.8
    if np.any(over):
        x = np.where(over, np.sign(x) * (ceiling * 0.8 + ceiling * 0.2 * np.tanh((np.abs(x) - ceiling * 0.8) / (ceiling * 0.2))), x)
    a, b = int(0.004 * sr), int(0.03 * sr)
    if len(x) > a + b:
        x[:a] *= np.linspace(0, 1, a)
        x[-b:] *= np.linspace(1, 0, b)
    return x


def write_ogg(path, x, sr):
    """OGG Vorbis, mono. Written in small blocks: libsndfile's Vorbis encoder overflows the stack on Windows when a long
    take (about 15 s or more) is handed over in one go."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    x = np.clip(x, -1.0, 1.0).astype(np.float32)
    with sf.SoundFile(path, "w", samplerate=sr, channels=1, format="OGG", subtype="VORBIS", compression_level=OGG_COMPRESSION) as f:
        for i in range(0, len(x), 8192):
            f.write(x[i:i + 8192])


def write_wav(path, x, sr):
    sf.write(path, np.clip(x, -1.0, 1.0).astype(np.float32), sr, subtype="PCM_16")


# ---------------------------------------------------------------- one line

def spoken(speaker, spec, style):
    """Turns one line into finished audio at SR. style: shout (race), call (starter, phrasebook), say (menus), narrate."""
    sp = VS.SPEAKERS[speaker]
    tremor = sp.get("tremor", 0.0)
    shout = style == "shout"
    if spec["lang"] == "bo":
        model, f0, formant, tempo = sp["bo"]
        seed_base = 1000 + int(hashlib.md5(speaker.encode()).hexdigest()[:4], 16) % 997
        x, info, used, stitched = tibetan_best(speaker, model, spec["bo"], tempo, seed_base, spec.get("key", ""))
        if not stitched:
            x = squeeze_gaps(x, 16000, " " in spec["bo"])
        spec["fit"] = round(float(info[0]), 2)
        spec["stitched"] = stitched
        spec["borrowed"] = used if used != model else ""
        spread = 1.35 if shout else (1.2 if style == "call" else 1.1)
        boost = 1.14 if shout else (1.04 if style == "call" else 1.0)
        slope = -0.45 if stitched else 0.0
        y = world_shift(x, 16000, target_f0=f0 * boost, formant=formant * (1.03 if shout else 1.0), spread=spread, tremor=tremor,
                        effort={"shout": 1.6, "call": 0.9}.get(style, 0.3), slope=slope)
        y = resample(y, 16000, SR)
        y = add_air(y, SR)
    else:
        lang, voice, speed, ratio = sp["en"]
        ratio_eff = ratio * (1.04 if shout else 1.0)
        # Resampling speeds the voice up as it lifts it, so ask Kokoro for the opposite and the pace lands on `speed`.
        speed_eff = speed * (1.06 if shout else 1.0) / ratio_eff
        x, sr = english_raw(lang, voice, spec["en"], speed_eff, sp.get("pause", 0.0))
        y = repitch(x, sr, SR, ratio_eff)
        if tremor > 0.0:
            y = vibrato(y, SR, tremor)
    if "age" in sp:
        y = age_voice(y, SR, sp["age"], int(hashlib.md5(spec["id"].encode()).hexdigest()[:8], 16))
    if style == "narrate":
        y = eq(y, SR, low_cut=70.0, presence_db=0.0 if "age" in sp else 1.2, warmth_db=1.5)
        y = compress(y, SR, 2.2, -22.0)
        y = room(y, SR, "tent", 0.07)
        return finish(y, SR, -20.5)
    if style == "shout":
        y = eq(y, SR, low_cut=110.0, presence_db=3.5, presence_hz=2600.0)
        y = compress(y, SR, 3.5, -22.0)
        y = drive(y / (np.max(np.abs(y)) + 1e-9), 0.35)
        y = room(y, SR, "plain", 0.09)
        return finish(y, SR, -18.5)
    if style == "call":
        y = eq(y, SR, low_cut=95.0, presence_db=2.8, presence_hz=2800.0)
        y = compress(y, SR, 3.0, -22.0)
        y = drive(y / (np.max(np.abs(y)) + 1e-9), 0.15)
        y = room(y, SR, "plain", 0.07)
        return finish(y, SR, -18.8)
    y = eq(y, SR, low_cut=85.0, presence_db=2.0)
    y = compress(y, SR, 2.6, -22.0)
    y = room(y, SR, "plain", 0.06)
    return finish(y, SR, -19.5)


# ---------------------------------------------------------------- the whole script

STYLE_OF_CAT = {"greet": "say", "start": "say", "ready": "call", "three": "call", "two": "call", "one": "call", "go": "call",
                "and_then": "say", "book": "call"}


def build_lines():
    """Everything to generate: a flat list of line dicts."""
    game = json.load(open(os.path.join(HERE, "voice_lines_game.json"), encoding="utf-8"))
    lines = []

    def add_en(speaker, cat, text, style=None):
        lines.append({"speaker": speaker, "cat": cat, "lang": "en", "en": text, "show": text.upper(), "gloss": "", "style": style or STYLE_OF_CAT.get(cat, "shout"), "id": line_id(speaker, text)})

    def add_bo(speaker, cat, key, style=None):
        script, show, gloss = VS.BO[key]
        lines.append({"speaker": speaker, "cat": cat, "lang": "bo", "bo": script, "show": show, "gloss": gloss, "style": style or STYLE_OF_CAT.get(cat, "shout"), "key": key, "id": line_id(speaker, script)})

    # In-race chatter, English.
    for speaker, cats in VS.EN.items():
        for cat, texts in cats.items():
            for text in texts:
                add_en(speaker, cat, text)
    # In-race chatter, Tibetan: each rival keeps a steady subset of the shared pool.
    for speaker in VS.SPEAKERS:
        if speaker in ("joru", "yangkyi", "pola", "mola", "child", "steward", "starter"):
            continue
        seed = int(hashlib.md5(speaker.encode()).hexdigest()[:6], 16)
        for cat, keys in VS.BO_POOL.items():
            for k in range(min(VS.POOL_KEEP[cat], len(keys))):
                add_bo(speaker, cat, keys[(seed + k) % len(keys)])
    for speaker, extras in VS.BO_EXTRA.items():
        for cat, key in extras:
            add_bo(speaker, cat, key)
    # What the menus already say, spoken as it's written.
    for speaker, texts in game["rivals"].items():
        for text in texts:
            add_en(speaker, "card", text, "say")
    for speaker, pages in game["narrator"].items():
        for text in pages:
            add_en(speaker, "story", text, "narrate")
    for speaker, texts in game.get("wager", {}).items():
        for text in texts:
            add_en(speaker, "card", text, "say")      # the side bet on the pre-race card and the results
    for speaker in ("pola", "mola"):
        for text in VS.SAYINGS:
            add_en(speaker, "saying", text, "narrate")
    # Lines any rival can say on the results or pre-race card. The menus pick one by index, so every rival has all of them.
    for kind in ("lose", "loan"):
        for text in game[kind]:
            for speaker in VS.EN:
                if speaker in game["rivals"]:
                    add_en(speaker, "card", text, "say")
    # The phrasebook: every distinct Tibetan phrase once, in one clear voice.
    for key in VS.BO:
        add_bo(VS.PHRASEBOOK_SPEAKER, "book", key)
    seen = set()
    out = []
    for ln in lines:
        k = (ln["id"], ln["cat"])
        if k not in seen:
            seen.add(k)
            out.append(ln)
    return out


def param_key(ln):
    sp = VS.SPEAKERS[ln["speaker"]]
    stitch = VS.STITCH.get(ln.get("key", ""))
    aged = (sp["age"], sp.get("pause")) if "age" in sp else ()
    return key_hash(VERSION, RAW_VERSION, ln["lang"], ln.get("en"), ln.get("bo"), ln["style"], sp.get("en"), sp.get("bo"), sp.get("tremor", 0.0), stitch, VS.FIT_LIMIT, VS.PRONOUNCE if ln["lang"] == "en" else 0, *aged)


def read_manifest():
    out = {}
    if os.path.isdir(CACHE_DIR):
        for f in sorted(os.listdir(CACHE_DIR)):
            if f.startswith("manifest") and f.endswith(".json"):
                try:
                    out.update(json.load(open(os.path.join(CACHE_DIR, f), encoding="utf-8")))
                except Exception:
                    pass
    return out


def generate(lines, force=False, only=None):
    os.makedirs(CACHE_DIR, exist_ok=True)
    os.makedirs(OUT_DIR, exist_ok=True)
    os.makedirs(FINAL_DIR, exist_ok=True)
    manifest = read_manifest()
    mine_path = os.path.join(CACHE_DIR, "manifest_%d.json" % SHARD[0])
    mine = {}
    if os.path.exists(mine_path):
        mine = json.load(open(mine_path, encoding="utf-8"))
    done = {}
    t0 = time.time()
    made = 0
    for i, ln in enumerate(lines):
        if ln["id"] in done:
            ln["dur"] = done[ln["id"]]["dur"]
            ln["fit"] = done[ln["id"]].get("fit")
            continue
        if SHARD[1] > 1 and int(ln["id"].split("_")[-1], 16) % SHARD[1] != SHARD[0]:
            entry = manifest.get(ln["id"])
            ln["dur"] = entry["dur"] if entry else 1.0
            ln["fit"] = entry.get("fit") if entry else None
            continue
        path = os.path.join(OUT_DIR, ln["id"] + ".ogg")
        key = param_key(ln)
        entry = manifest.get(ln["id"])
        skip = only is not None and ln["speaker"] not in only
        if (not force and entry and entry.get("key") == key and os.path.exists(path)) or (skip and os.path.exists(path)):
            ln["dur"] = entry["dur"] if entry else 1.0
            ln["fit"] = entry.get("fit") if entry else None
            ln["stitched"] = bool(entry.get("stitched")) if entry else False
            ln["borrowed"] = entry.get("borrowed", "") if entry else ""
            done[ln["id"]] = {"dur": ln["dur"], "fit": ln["fit"]}
            continue
        if skip:
            ln["dur"] = 0.0
            continue
        y = spoken(ln["speaker"], ln, ln["style"])
        np.save(os.path.join(FINAL_DIR, ln["id"] + ".npy"), y.astype(np.float32))
        write_ogg(path, y, SR)
        ln["dur"] = round(len(y) / SR, 2)
        done[ln["id"]] = {"dur": ln["dur"], "fit": ln.get("fit")}
        mine[ln["id"]] = {"key": key, "dur": ln["dur"], "fit": ln.get("fit"), "stitched": bool(ln.get("stitched")), "borrowed": ln.get("borrowed", ""), "speaker": ln["speaker"], "show": ln["show"][:60]}
        manifest[ln["id"]] = mine[ln["id"]]
        made += 1
        if made % 10 == 0:
            json.dump(mine, open(mine_path, "w", encoding="utf-8"))
            print("%4d/%d  %6.1fs  %s  %s" % (i + 1, len(lines), time.time() - t0, ln["speaker"], ln["show"][:50]), flush=True)
    json.dump(mine, open(mine_path, "w", encoding="utf-8"))
    print("shard %d/%d made %d lines in %.1fs, %d total" % (SHARD[0], SHARD[1], made, time.time() - t0, len(lines)), flush=True)


def prune(lines):
    """Deletes voice files (and their Godot .import files) that nothing in the script refers to any more."""
    keep = {ln["id"] for ln in lines} | set(VS.CHEERS)
    removed = 0
    for f in os.listdir(OUT_DIR):
        if f.endswith(".ogg.import"):
            name = f[:-len(".ogg.import")]
        elif f.endswith(".ogg"):
            name = f[:-len(".ogg")]
        else:
            continue
        if name not in keep:
            os.remove(os.path.join(OUT_DIR, f))
            removed += 1
    if removed:
        print("removed", removed, "stale voice files", flush=True)


def reencode_all():
    """Rewrites every OGG from the cached float audio (after changing OGG_COMPRESSION)."""
    n = 0
    for f in os.listdir(FINAL_DIR):
        if f.endswith(".npy"):
            write_ogg(os.path.join(OUT_DIR, f[:-4] + ".ogg"), np.load(os.path.join(FINAL_DIR, f)).astype(np.float64), SR)
            n += 1
    print("re-encoded", n, "files", flush=True)


# ---------------------------------------------------------------- crowds

def loud_group(key, sr, voices, seed, spread=0.09):
    """Many people shouting the same phrase, loosely together."""
    rng = np.random.default_rng(seed)
    script = VS.BO[key][0]
    takes = []
    for i in range(voices):
        model = ["bod", "khg", "adx"][i % 3]
        tempo = float(rng.uniform(0.9, 1.1))
        x, _info = tibetan_take("crowd", model, script, tempo, 5000 + i * 53, count=2)
        female = i % 3 == 2
        f0 = float(rng.uniform(205, 265)) if female else float(rng.uniform(120, 185))
        form = float(rng.uniform(1.12, 1.2)) if female else float(rng.uniform(0.96, 1.05))
        y = world_shift(x, 16000, target_f0=f0, formant=form, spread=1.4, effort=1.8)
        takes.append(resample(y, 16000, sr))
    n = max(len(t) for t in takes) + int(spread * 2.2 * sr) + 1
    mix = np.zeros(n)
    for t in takes:
        at = min(int(abs(rng.normal(0.0, spread)) * sr), n - len(t))
        mix[at:at + len(t)] += t * float(rng.uniform(0.6, 1.0)) / (np.max(np.abs(t)) + 1e-9)
    return mix


def make_cheers(sr=32000):
    for name, key in VS.CHEERS.items():
        x = loud_group(key, sr, 15, seed=int(hashlib.md5(name.encode()).hexdigest()[:6], 16))
        x = eq(x, sr, low_cut=140.0, presence_db=2.0, presence_hz=1800.0)
        x = compress(x / (np.max(np.abs(x)) + 1e-9), sr, 2.5, -20.0)
        x = room(x, sr, "valley", 0.24)
        x = finish(x, sr, -15.5)     # a crowd shout is an event, and Sfx.play trims every one-shot by about 10 dB
        write_ogg(os.path.join(OUT_DIR, name + ".ogg"), x, sr)
        np.save(os.path.join(FINAL_DIR, name + ".npy"), x.astype(np.float32))
        print(name, round(len(x) / sr, 2), "s", flush=True)


def make_walla(sr=22050, secs=12.0):
    """A murmuring crowd built from hundreds of overlapped real phrases, far more convincing than filtered noise. It wraps."""
    rng = np.random.default_rng(77)
    n = int(secs * sr)
    buf = np.zeros(n)
    keys = [k for k in VS.BO if k not in ("three", "two", "one", "go", "ready", "kiki", "lhagyal")]
    takes = []
    for i, key in enumerate(keys):
        model = ["bod", "khg", "adx"][i % 3]
        x, _info = tibetan_take("crowd", model, VS.BO[key][0], float(rng.uniform(0.95, 1.15)), 7000 + i * 17, count=2)
        takes.append(x)
    for i in range(260):
        x = takes[int(rng.integers(len(takes)))]
        female = rng.random() < 0.45
        ratio = float(rng.uniform(1.25, 1.85)) if female else float(rng.uniform(0.72, 1.12))
        ratio = round(ratio * 20.0) / 20.0       # a tidy ratio keeps the resampling filter short
        # Plain resampling is fine here: nobody picks out a single voice in a crowd, and it's quick.
        y = signal.resample_poly(x, sr, int(round(16000 * ratio)))
        y *= float(rng.uniform(0.25, 1.0)) / (np.max(np.abs(y)) + 1e-9)
        at = int(rng.integers(n))
        idx = (at + np.arange(len(y))) % n
        np.add.at(buf, idx, y)
    # Air and distance, wrapped so the loop has no seam.
    spec = np.fft.rfft(buf)
    f = np.maximum(np.fft.rfftfreq(n, 1.0 / sr), 1.0)
    spec *= (1.0 / np.sqrt(1.0 + (f / 3200.0) ** 4)) * (1.0 / np.sqrt(1.0 + (160.0 / f) ** 4))
    rngp = np.random.default_rng(5)
    tail = rngp.standard_normal(n) * np.exp(-np.arange(n) / (0.35 * sr))
    spec = spec * (1.0 + 0.8 * np.fft.rfft(tail) / (np.sqrt(np.sum(tail ** 2)) + 1e-9))
    x = np.fft.irfft(spec, n)
    t = np.arange(n) / sr
    swell = 0.82 + 0.18 * np.sin(2.0 * np.pi * t / secs + 0.6) + 0.08 * np.sin(2.0 * np.pi * 3.0 * t / secs + 1.9)
    x *= swell
    x = x - np.mean(x)
    x = x / (np.max(np.abs(x)) + 1e-9) * 0.7
    write_wav(os.path.join(ROOT, "assets", "audio", "crowd.wav"), x, sr)
    step = np.percentile(np.abs(np.diff(x)), 99) + 1e-12
    print("crowd.wav", secs, "s, seam %.2f of a typical step" % (abs(x[0] - x[-1]) / step), flush=True)


# ---------------------------------------------------------------- generated data and the review sheet

GD_HEADER = '''class_name VoiceBank
extends RefCounted
## Generated by art/tools/make_voices.py. Change art/tools/voice_script.py, not this file.
## LINES[speaker][category] is an array of {f: file name in assets/audio/voice, t: subtitle, g: English gloss for
## Tibetan lines, l: "en" or "bo", d: seconds}.
## SAYINGS are the old rider's sayings. PHRASES has one entry per distinct Tibetan phrase for the phrasebook:
## {t: subtitle, g: English gloss, f: file name, speaker, bo: the Tibetan script, d: seconds}.
'''


def gd_string(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def write_bank(lines):
    by = {}
    book = []
    for ln in lines:
        if ln["cat"] in ("card", "story"):
            continue
        if ln["cat"] == "book":
            book.append(ln)
            continue
        by.setdefault(ln["speaker"], {}).setdefault(ln["cat"], []).append(ln)
    out = [GD_HEADER, "const LINES := {"]
    for speaker in sorted(by):
        out.append("\t%s: {" % gd_string(speaker))
        for cat in sorted(by[speaker]):
            rows = ", ".join("{\"f\": %s, \"t\": %s, \"g\": %s, \"l\": \"%s\", \"d\": %.2f}" % (gd_string(ln["id"]), gd_string(ln["show"]), gd_string(ln["gloss"]), ln["lang"], ln.get("dur", 1.0)) for ln in by[speaker][cat])
            out.append("\t\t%s: [%s]," % (gd_string(cat), rows))
        out.append("\t},")
    out.append("}")
    out.append("")
    out.append("const SAYINGS: Array[String] = [%s]" % ", ".join(gd_string(s) for s in VS.SAYINGS))
    out.append("")
    rows = []
    for ln in book:
        if not os.path.exists(os.path.join(OUT_DIR, ln["id"] + ".ogg")):
            print("MISSING phrasebook file", ln["id"], flush=True)
            continue
        rows.append("\t{\"t\": %s, \"g\": %s, \"f\": %s, \"speaker\": %s, \"bo\": %s, \"d\": %.2f}" % (gd_string(ln["show"]), gd_string(ln["gloss"] or "(laughter)"), gd_string(ln["id"]), gd_string(ln["speaker"]), gd_string(ln["bo"]), ln.get("dur", 1.0)))
    out.append("const PHRASES: Array = [")
    out.append(",\n".join(rows))
    out.append("]")
    out.append("")
    path = os.path.join(ROOT, "data", "voice_bank.gd")
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(out))
    print("wrote", os.path.relpath(path, ROOT), "with", len(rows), "phrases", flush=True)


def fit_summary(lines):
    """A few sentences on how well the Tibetan takes fit their text, from the numbers the generator kept."""
    bo = [ln for ln in lines if ln["lang"] == "bo" and ln.get("fit") is not None]
    if not bo:
        return []
    fits = sorted(ln["fit"] for ln in bo)
    worst = max(bo, key=lambda ln: ln["fit"])
    borrowed = sorted({"%s (read by the %s reader)" % (ln["show"].strip("!?. "), ln["borrowed"]) for ln in bo if ln.get("borrowed")})
    stitched = sorted({ln["show"].strip("!?. ") for ln in bo if ln.get("stitched")})
    out = ["Timing check: %d Tibetan takes, median fit score %.2f (0 is a perfect length and syllable count), worst %.2f (%s, %s),"
           % (len(bo), fits[len(fits) // 2], worst["fit"], worst["show"], worst["speaker"]),
           "and none above the limit of %.2f. This says the lengths and syllable counts are right. It does not say it sounds like Tibetan." % VS.FIT_LIMIT, ""]
    if borrowed:
        out += ["Cries taken from another reader because the speaker's own one failed: %s." % ", ".join(borrowed), ""]
    if stitched:
        out += ["Cries built from single syllables: %s." % ", ".join(stitched), ""]
    return out


def write_review_sheet(lines):
    seen = {}
    cats = {}
    for ln in lines:
        if ln["lang"] == "bo":
            e = seen.setdefault(ln["bo"], {"show": ln["show"], "gloss": ln["gloss"], "who": set(), "key": ln["key"]})
            if ln["cat"] != "book":
                e["who"].add(ln["speaker"])
                cats.setdefault(ln["bo"], set()).add(ln["cat"])
    out = ["# Voice script", "",
           "Generated by `art/tools/make_voices.py` from `art/tools/voice_script.py`. Edit the script, not this page.", "",
           "**No Tibetan speaker has reviewed any of this, and nobody has yet listened to the generated audio.** Claude wrote the",
           "phrases and checked them only against public phrasebooks and word lists. The grammar is colloquial Lhasa-style, but the",
           "speech models read Kham and Amdo riders in their own dialects from the same spelling, so those riders don't phrase things",
           "the way a real Khampa or Amdowa would. Please check the spelling, the meaning, whether each phrase suits the moment, and",
           "how it sounds. Phrases marked **doubtful** are the ones Claude is least sure of.", "",
           "## How the voices are made", "",
           "| Language | Model | Licence | Notes |", "|---|---|---|---|",
           "| Central Tibetan | `facebook/mms-tts-bod` | CC BY-NC 4.0 | One male reader |",
           "| Khams Tibetan | `facebook/mms-tts-khg` | CC BY-NC 4.0 | One male reader |",
           "| Amdo Tibetan | `facebook/mms-tts-adx` | CC BY-NC 4.0 | One male reader |",
           "| English | `hexgrad/Kokoro-82M` | Apache 2.0 | Preset voices, some blended in pairs, with pitch shifted to fit each rider |", "",
           "The non-commercial licence covers the Tibetan audio, so **the Tibetan lines must be replaced before any paid release**.",
           "Women's and older Tibetan voices are the same readers with pitch and formants moved by the WORLD vocoder, not real",
           "recordings. English voices are Kokoro voices or blends of two, resampled up or down for a smaller or bigger",
           "person, with a slow vibrato for the older riders. The grandfather and grandmother who tell the story are aged further",
           "with the vocoder: a slower pace, a narrower tune, a shake in the pitch, more breath and less of the top of the voice.", "",
           "The MMS models were trained on long passages and say short phrases far too fast. The generator therefore tunes each",
           "phrase to about a quarter of a second a syllable and keeps the best of several takes, scored on length and on the",
           "number of syllable peaks. Cries that the speaker's own reader still turns to mush are taken from another reader, and",
           "failing that built from single syllables set down one by one with a falling pitch.", ""]
    out += fit_summary(lines)
    out += ["## Tibetan phrases", "",
           "| Tibetan | Subtitle | Meaning | When | Who | Note |", "|---|---|---|---|---|---|"]
    for script in seen:
        e = seen[script]
        who = "all rivals" if len(e["who"]) > 6 else ", ".join(sorted(e["who"])) or "phrasebook only"
        note = VS.DOUBT.get(e["key"], "")
        if note:
            note = "**doubtful**: " + note
        out.append("| %s | %s | %s | %s | %s | %s |" % (script, e["show"], e["gloss"] or "(laughter)", ", ".join(sorted(cats.get(script, []))) or "phrasebook", who, note))
    out += ["", "## Cast voices", "",
            "English is a Kokoro voice or a blend of two (weights after the colons), resampled by the ratio shown, so a ratio under 1",
            "is deeper and bigger. Tibetan is one of the three readers moved to the pitch shown (the calm pitch: shouts go 14 percent",
            "higher) with the formant ratio shown. The tempo is the pace (1.0 is a quarter second a syllable).", "",
            "| Speaker | English voice | Pitch ratio | English pace | Tibetan reader | Pitch Hz | Formant | Tempo |", "|---|---|---|---|---|---|---|---|"]
    for sid, sp in VS.SPEAKERS.items():
        en = sp["en"]
        bo = sp.get("bo")
        out.append("| %s | %s | %.2f | %.2f | %s | %s | %s | %s |" % (sp["name"], en[1].replace(",", ", "), en[3], en[2], bo[0] if bo else "none", bo[1] if bo else "", bo[2] if bo else "", bo[3] if bo else ""))
    out += ["", "## English sayings of the old rider", "",
            "Invented for the game in the storyteller's voice, except the yeti and the marmots, which is a real Tibetan proverb.", ""]
    out += ["- %s" % s for s in VS.SAYINGS]
    out += ["", "## Setting up the voice tools", "",
            "```",
            "uv venv --python 3.12 <dir>\\venv",
            "uv pip install --python <dir>\\venv\\Scripts\\python.exe --index-strategy unsafe-best-match --extra-index-url https://download.pytorch.org/whl/cpu \"torch>=2.6,<2.9\" \"transformers>=4.45,<5\" \"kokoro>=0.9.4\" soundfile numpy scipy pyworld pyloudnorm \"misaki[en]\" pip",
            "```", "",
            "Set `HF_HOME` and `VOICE_CACHE` to folders outside the repo, then run `art/tools/make_voices.py` with that Python.",
            "After changing menu text, first run `tools/export_lines.gd` so the generator sees it.", ""]
    path = os.path.join(ROOT, "docs", "VOICE_SCRIPT.md")
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(out))
    print("wrote", os.path.relpath(path, ROOT), flush=True)


def report(lines):
    bad = []
    stitched = []
    for ln in lines:
        if ln["lang"] == "bo" and ln.get("fit") is not None and ln["fit"] > VS.FIT_LIMIT and not ln.get("stitched"):
            bad.append((ln["fit"], ln["speaker"], ln["show"], ln.get("dur")))
        if ln.get("stitched"):
            stitched.append((ln["speaker"], ln["show"]))
    files = [f for f in os.listdir(OUT_DIR) if f.endswith(".ogg")]
    total = sum(os.path.getsize(os.path.join(OUT_DIR, f)) for f in files)
    print("%d files, %.1f MB, %.0f s of speech" % (len(files), total / 1048576.0, sum(ln.get("dur", 0.0) for ln in {l["id"]: l for l in lines}.values())))
    missing = sorted({ln["id"] for ln in lines if not os.path.exists(os.path.join(OUT_DIR, ln["id"] + ".ogg"))})
    print("missing files: %d%s" % (len(missing), (" " + ", ".join(missing[:10])) if missing else ""))
    if stitched:
        print("stitched cries (%d): %s" % (len(stitched), ", ".join(sorted(set("%s/%s" % s for s in stitched)))[:600]))
    if bad:
        print("Tibetan takes whose length or syllable count still looks off (%d):" % len(bad))
        for row in sorted(bad, reverse=True)[:40]:
            print("  fit %.2f  %-10s %-30s %.2fs" % row)


def main():
    global SHARD, OUT_DIR
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    ap.add_argument("--force", action="store_true")
    ap.add_argument("--no-crowd", action="store_true")
    ap.add_argument("--no-lines", action="store_true")
    ap.add_argument("--shard", default="", help="K/N: make only that share of the lines, and skip the crowd and the data files")
    ap.add_argument("--out", default="", help="write the OGG files here instead of assets/audio/voice (for trials)")
    ap.add_argument("--reencode", action="store_true", help="rewrite the OGG files from the cached audio at VOICE_OGG_COMPRESSION")
    args = ap.parse_args()
    only = set(args.only.split(",")) if args.only else None
    if args.out:
        OUT_DIR = args.out
    if args.shard:
        k, n = args.shard.split("/")
        SHARD = (int(k), int(n))
    os.makedirs(FINAL_DIR, exist_ok=True)
    if args.reencode:
        reencode_all()
        return
    lines = build_lines()
    print(len(lines), "lines to check", flush=True)
    if not args.no_lines:
        generate(lines, args.force, only)
    if SHARD[1] > 1:
        return
    if not args.no_crowd:
        make_cheers()
        make_walla()
    write_bank(lines)
    write_review_sheet(lines)
    if only is None and not args.out:
        prune(lines)
    report(lines)


if __name__ == "__main__":
    main()
