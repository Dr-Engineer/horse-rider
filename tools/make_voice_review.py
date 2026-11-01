"""Builds a single HTML page for listening to the voices and flagging problems, with the audio embedded in it.
It's for review by people: the game may be muted, and Claude can't hear. Run after art/tools/make_voices.py:
  python tools/make_voice_review.py <out.html>
"""
import base64
import html
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "art", "tools"))
import voice_script as VS  # noqa: E402

VOICE_DIR = os.path.join(ROOT, "assets", "audio", "voice")
WOMEN = {"pasang", "pema", "drukmo", "pamo", "diki", "ama", "yangkyi", "mola"}
READER = {"bod": "Central", "khg": "Kham", "adx": "Amdo"}
CHIP_ORDER = ["Central man", "Kham man", "Amdo man", "Central woman", "Kham woman", "Amdo woman"]
WHEN = {
    "pass_by": "a rival passing you", "passed": "a rival you just passed", "hit_you": "a rival after hitting you", "hurt": "a rival you just hit",
    "down": "a rival knocked down", "gloat": "a rival when you fall", "near": "a rival riding alongside", "hat": "a rider losing a hat", "cry": "a rival at the high pass",
    "win": "a rival finishing ahead of you", "start": "a rival on the start line", "scarf": "a rival scooping a scarf", "p_hurt": "your rider when hit", "p_down": "your rider falling",
    "p_knock": "your rider after a knockdown", "p_remount": "your rider getting back on", "p_wind": "your rider on Second Wind", "p_cry": "your rider at the high pass",
    "p_scarf": "your rider scooping a scarf", "p_win": "your rider winning", "p_lose": "your rider losing", "fine": "the steward handing out a fine", "quiet": "the steward on Quiet Ground",
    "ready": "the starter", "three": "the starter", "two": "the starter", "one": "the starter", "go": "the starter", "greet": "the old rider, on the title screen",
    "phrasebook": "the phrasebook only",
}
PAGE_REGION = {"wangyal": "Kham", "karma": "Kham", "sonam": "Changtang", "pasang": "Changtang", "samdup": "Kham", "temba": "Lhasa", "pema": "Tsang",
               "dukpa": "Bhutan", "thupden": "Golok", "drukmo": "Amdo", "genden": "Eastern plateau", "pamo": "Kham", "diki": "Lhasa", "chakri": "Lhasa",
               "serkhar": "Lhasa", "ama": "Kalimpong", "joru": "Kham, your rider", "yangkyi": "Amdo, your rider"}


def read_bank():
    lines = {}
    speaker = None
    phrases = []
    for raw in open(os.path.join(ROOT, "data", "voice_bank.gd"), encoding="utf-8"):
        m = re.match(r'^\t"(\w+)": \{$', raw)
        if m:
            speaker = m.group(1)
            lines[speaker] = {}
            continue
        m = re.match(r'^\t\t"(\w+)": \[(.*)\],$', raw)
        if m and speaker:
            rows = re.findall(r'\{"f": "(.*?)", "t": "(.*?)", "g": "(.*?)", "l": "(en|bo)", "d": ([0-9.]+)\}', m.group(2))
            lines[speaker][m.group(1)] = [{"f": r[0], "t": r[1], "g": r[2], "l": r[3], "d": float(r[4])} for r in rows]
            continue
        m = re.match(r'^\t\{"t": "(.*?)", "g": "(.*?)", "f": "(.*?)", "speaker": "(.*?)", "bo": "(.*?)", "d": ([0-9.]+)\},?$', raw)
        if m:
            phrases.append({"t": m.group(1), "g": m.group(2), "f": m.group(3), "speaker": m.group(4), "bo": m.group(5)})
    return lines, phrases


def read_notes():
    notes = {}
    for raw in open(os.path.join(ROOT, "docs", "VOICE_SCRIPT.md"), encoding="utf-8"):
        cells = [c.strip() for c in raw.strip().strip("|").split("|")]
        if len(cells) == 6 and cells[0] and re.search("[ༀ-࿿]", cells[0]):
            notes[cells[1]] = {"when": cells[3], "note": cells[5].replace("**doubtful**: ", "")}
    return notes


def voice_class(speaker):
    sp = VS.SPEAKERS.get(speaker, {})
    if "bo" not in sp:
        return ""
    return "%s %s" % (READER[sp["bo"][0]], "woman" if speaker in WOMEN else "man")


def build():
    lines, phrases = read_bank()
    notes = read_notes()
    game = json.load(open(os.path.join(ROOT, "art", "tools", "voice_lines_game.json"), encoding="utf-8"))
    audio = set()

    def use(file):
        if os.path.exists(os.path.join(VOICE_DIR, file + ".ogg")):
            audio.add(file)
            return True
        return False

    by_phrase = {}
    for speaker, cats in lines.items():
        for rows in cats.values():
            for r in rows:
                if r["l"] == "bo":
                    by_phrase.setdefault(r["t"], {}).setdefault(voice_class(speaker), (r["f"], speaker))
    out_phrases = []
    for p in phrases:
        chips = []
        seen = set()
        if use(p["f"]):
            chips.append({"label": voice_class(p["speaker"]), "f": p["f"], "who": VS.SPEAKERS[p["speaker"]]["name"]})
            seen.add(voice_class(p["speaker"]))
        for cls in CHIP_ORDER:
            if cls in seen or cls not in by_phrase.get(p["t"], {}):
                continue
            f, speaker = by_phrase[p["t"]][cls]
            if use(f):
                chips.append({"label": cls, "f": f, "who": VS.SPEAKERS[speaker]["name"]})
                seen.add(cls)
        chips.sort(key=lambda c: CHIP_ORDER.index(c["label"]) if c["label"] in CHIP_ORDER else 99)
        n = notes.get(p["t"], {})
        when = "Said by " + "; ".join(WHEN.get(c.strip(), c.strip()) for c in n.get("when", "").split(",") if c.strip()) if n.get("when") else ""
        out_phrases.append({"bo": p["bo"], "t": p["t"], "g": p["g"], "when": when, "note": n.get("note", ""), "chips": chips})

    cast = []
    for speaker in ["joru", "yangkyi", "wangyal", "karma", "sonam", "pasang", "samdup", "temba", "pema", "dukpa", "thupden", "drukmo", "genden", "pamo", "diki", "chakri", "serkhar", "ama"]:
        rows = []
        for cat in ("pass_by", "hit_you", "hurt", "near", "p_knock", "p_down"):
            for r in lines.get(speaker, {}).get(cat, []):
                if r["l"] == "en" and use(r["f"]):
                    rows.append({"t": r["t"], "f": r["f"]})
                    break
            if len(rows) >= 3:
                break
        cast.append({"id": speaker, "name": VS.SPEAKERS[speaker]["name"], "region": PAGE_REGION.get(speaker, ""), "voice": VS.SPEAKERS[speaker]["en"][1].split(":")[0], "lines": rows})

    tellers = []
    import hashlib
    for speaker, title in (("pola", "Pola, the grandfather"), ("mola", "Mola, the grandmother")):
        rows = []
        for text in [game["narrator"][speaker][0]] + VS.SAYINGS[:4] + [VS.SAYINGS[14]]:
            f = "%s_%s" % (speaker, hashlib.md5(text.encode("utf-8")).hexdigest()[:8])
            if use(f):
                rows.append({"t": text, "f": f})
        tellers.append({"name": title, "lines": rows})

    start = []
    for cat in ("ready", "three", "two", "one", "go"):
        for r in lines.get("starter", {}).get(cat, []):
            if use(r["f"]):
                start.append({"t": r["t"], "g": r["g"], "f": r["f"]})
    crowd = []
    for name, label in (("cheer_kiki", "Crowd: Ki ki so so! Lha gyalo!"), ("cheer_lha", "Crowd: Lha gyalo!"), ("cheer_shuk", "Crowd: Shuk gyob!"), ("cheer_ala", "Crowd: A la la!")):
        if use(name):
            crowd.append({"t": label, "f": name})
    child = []
    for r in lines.get("child", {}).get("and_then", []):
        if use(r["f"]):
            child.append({"t": "The grandchild: " + r["t"], "f": r["f"]})

    blobs = {}
    for f in sorted(audio):
        with open(os.path.join(VOICE_DIR, f + ".ogg"), "rb") as fh:
            blobs[f] = base64.b64encode(fh.read()).decode("ascii")
    data = {"phrases": out_phrases, "cast": cast, "tellers": tellers, "start": start, "crowd": crowd + child}
    return data, blobs


PAGE = r"""<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>Windhorse Voice Check</title>
<meta name="claude:viewport-fit-sides" content="cover">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Alegreya+Sans:wght@400;500;700&family=Jomolhari&family=Silkscreen&display=swap">
<style>
/* Layout: a ledger on a thangka mount. Brocade strips close the page top and bottom, phrases sit in ruled rows you can refer to by number. */
:root {
  color-scheme: dark;
  --ink: #17131A; --soot: #231E28; --rule: #453D46; --conch: #FBF5E6; --bone: #D9CDB2; --ash: #A9A3A5;
  --orpiment: #F2B632; --gold: #D9A227; --madder: #7A1C22; --vermilion: #F0765F; --azure: #8DBEEE;
  --display: "Silkscreen", ui-monospace, "Cascadia Mono", monospace;
  --body: "Alegreya Sans", "Segoe UI", system-ui, sans-serif;
  --tibetan: "Jomolhari", "Noto Serif Tibetan", "Microsoft Himalaya", serif;
}
body { background: var(--ink); color: var(--conch); font: 17px/1.5 var(--body); }
body::before { content: ""; position: fixed; inset: 0 0 auto; height: env(safe-area-inset-top, 0px); z-index: 10; background: var(--ink); }
.mount { max-width: 1060px; margin: 0 auto; padding-block: 16px 56px; padding-left: max(16px, env(safe-area-inset-left, 0px)); padding-right: max(16px, env(safe-area-inset-right, 0px)); }
.brocade { height: 12px; background: var(--madder) url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='16' height='12'%3E%3Cpath d='M8 1l5 5-5 5-5-5z' fill='%23D9A227'/%3E%3Crect x='7' y='5' width='2' height='2' fill='%23D63A22'/%3E%3C/svg%3E") repeat-x; border-block: 1px solid var(--gold); }
h1, h2 { font-family: var(--display); font-weight: 400; text-wrap: balance; margin: 0; letter-spacing: 0.01em; }
h1 { font-size: clamp(1.7rem, 4.6vw, 2.7rem); color: var(--orpiment); line-height: 1.15; margin-top: 22px; }
h2 { font-size: 1.25rem; color: var(--orpiment); margin-top: 44px; }
p { margin: 10px 0 0; max-width: 68ch; }
.lede { font-size: 1.12rem; }
.warn { color: var(--bone); }
.small { color: var(--ash); font-size: 0.92rem; }
.bar { position: sticky; top: env(safe-area-inset-top, 0px); z-index: 5; display: flex; flex-wrap: wrap; align-items: center; gap: 10px 18px; margin-top: 22px; padding: 10px 12px; background: var(--soot); border: 1px solid var(--gold); }
.bar label { display: flex; align-items: center; gap: 8px; font-size: 0.95rem; }
.bar input[type=range] { width: 130px; accent-color: var(--orpiment); }
button { font: 500 0.95rem var(--body); color: var(--conch); background: transparent; border: 1px solid var(--gold); padding: 5px 11px; cursor: pointer; }
button:hover { background: #3A2F28; }
button:focus-visible, input:focus-visible { outline: 2px solid var(--orpiment); outline-offset: 2px; }
button.on { background: var(--orpiment); border-color: var(--orpiment); color: var(--ink); }
.count { margin-left: auto; font-variant-numeric: tabular-nums; color: var(--bone); font-size: 0.95rem; }
.row { display: grid; grid-template-columns: 2.4rem minmax(0, 1.25fr) minmax(0, 1fr) minmax(0, 1.5fr); gap: 6px 16px; padding: 14px 0; border-bottom: 1px solid var(--rule); align-items: start; }
.num { font-family: var(--display); font-size: 0.85rem; color: var(--ash); font-variant-numeric: tabular-nums; padding-top: 4px; }
.bo { font-family: var(--tibetan); font-size: 1.5rem; line-height: 1.45; }
.ph { font-family: var(--display); font-size: 0.86rem; color: var(--azure); overflow-wrap: anywhere; }
.g { font-weight: 500; overflow-wrap: anywhere; }
.when { color: var(--ash); font-size: 0.92rem; }
.doubt { color: var(--vermilion); font-size: 0.92rem; margin-top: 4px; }
.doubt b { font-weight: 700; }
.chips { display: flex; flex-wrap: wrap; gap: 6px; }
.flag { display: flex; flex-wrap: wrap; align-items: center; gap: 8px; margin-top: 8px; font-size: 0.92rem; color: var(--bone); }
.flag label { display: flex; align-items: center; gap: 6px; cursor: pointer; }
.flag input[type=checkbox] { accent-color: var(--vermilion); }
.flag input[type=text] { flex: 1 1 180px; min-width: 0; background: var(--ink); color: var(--conch); border: 1px solid var(--rule); padding: 3px 7px; font: inherit; }
.line { display: grid; grid-template-columns: auto minmax(0, 1fr); gap: 10px; align-items: baseline; padding: 5px 0; }
.who { display: grid; grid-template-columns: minmax(0, 13rem) minmax(0, 1fr); gap: 4px 18px; padding: 12px 0; border-bottom: 1px solid var(--rule); }
.name { font-weight: 700; }
.line .t { overflow-wrap: anywhere; }
textarea { width: 100%; min-height: 8rem; margin-top: 10px; background: var(--ink); color: var(--conch); border: 1px solid var(--gold); padding: 8px; font: inherit; box-sizing: border-box; }
.foot { margin-top: 40px; }
@media (max-width: 720px) {
  .row { grid-template-columns: 2rem minmax(0, 1fr); }
  .row > .mean, .row > .voices { grid-column: 2; }
  .who { grid-template-columns: minmax(0, 1fr); }
  .count { margin-left: 0; }
}
@media (prefers-reduced-motion: no-preference) { button { transition: background-color 80ms linear; } }
</style>
<div class="mount">
  <div class="brocade"></div>
  <h1>Windhorse voice check</h1>
  <p class="lede">Every Tibetan phrase in the game and a sample of the English cast. Press a voice to hear it. Flag anything that sounds wrong, then copy your notes and paste them to Claude.</p>
  <p class="warn">These voices come from speech models, and nobody has listened to them yet. Claude can't hear audio, and no Tibetan speaker has checked the phrases. The women's Tibetan voices are male readers with their pitch shifted, so expect those to sound the most artificial. Claude wrote the phrases and is least sure of the ones marked <b style="color:var(--vermilion)">check this</b>.</p>
  <div class="bar" role="group" aria-label="Playback">
    <label for="vol">Volume <input id="vol" type="range" min="0" max="1" step="0.05" value="0.6"></label>
    <button id="playall" type="button">Play all phrases</button>
    <button id="stop" type="button">Stop</button>
    <button id="copy" type="button">Copy my notes</button>
    <span class="count" id="count" aria-live="polite">0 flagged</span>
  </div>
  <textarea id="fallback" hidden aria-label="Your notes"></textarea>
  <h2>Tibetan phrases</h2>
  <p class="small">Each voice button is named for the dialect model and who it's meant to sound like. Hover over one to see the rider.</p>
  <div id="phrases"></div>
  <h2>The start line and the crowd</h2>
  <div id="start"></div>
  <h2>The cast in English</h2>
  <p class="small">Three sample lines for each rider, as they're shouted in a race.</p>
  <div id="cast"></div>
  <h2>The old rider</h2>
  <p class="small">The storyteller, spoken close and warm. The sayings are invented for the game, apart from the yeti and the marmots, a real Tibetan proverb.</p>
  <div id="tellers"></div>
  <div class="foot"><div class="brocade"></div><p class="small">Tibetan voices: Meta MMS-TTS, CC BY-NC 4.0, non-commercial use only. English voices: Kokoro-82M, Apache 2.0.</p></div>
</div>
<script>
const DATA = /*DATA*/;
const AUDIO = /*AUDIO*/;
const $ = (s) => document.getElementById(s);
const el = (tag, cls, text) => { const e = document.createElement(tag); if (cls) e.className = cls; if (text !== undefined) e.textContent = text; return e; };
const store = { get(k) { try { return localStorage.getItem(k); } catch (e) { return null; } }, set(k, v) { try { localStorage.setItem(k, v); } catch (e) {} } };
const player = new Audio();
let current = null, queue = [];
function setVolume() { player.volume = parseFloat($("vol").value); store.set("vol", $("vol").value); }
function clearOn() { if (current) { current.classList.remove("on"); current = null; } }
function play(file, button) {
  if (current === button && !player.paused) { stopAll(); return; }
  clearOn();
  player.src = "data:audio/ogg;base64," + AUDIO[file];
  setVolume();
  if (button) { button.classList.add("on"); current = button; }
  player.play().catch(() => { clearOn(); });
}
function stopAll() { queue = []; player.pause(); clearOn(); $("playall").classList.remove("on"); }
player.addEventListener("ended", () => {
  clearOn();
  if (queue.length) { const b = queue.shift(); b.scrollIntoView({ block: "nearest" }); setTimeout(() => play(b.dataset.f, b), 350); } else { $("playall").classList.remove("on"); }
});
function voiceButton(label, file, title) {
  const b = el("button", "v", label); b.type = "button"; b.dataset.f = file;
  if (title) b.title = title;
  b.addEventListener("click", () => { queue = []; $("playall").classList.remove("on"); play(file, b); });
  return b;
}
const flags = [];
function flagBox(key, describe) {
  const wrap = el("div", "flag");
  const label = el("label");
  const box = el("input"); box.type = "checkbox"; box.id = "flag-" + key;
  label.append(box, document.createTextNode("Sounds wrong"));
  const note = el("input"); note.type = "text"; note.id = "note-" + key; note.placeholder = "What's wrong? Which voice?"; note.hidden = true;
  note.setAttribute("aria-label", "Note for " + describe);
  const saved = store.get("flag-" + key);
  if (saved !== null) { box.checked = true; note.hidden = false; note.value = saved; }
  const save = () => { note.hidden = !box.checked; if (box.checked) store.set("flag-" + key, note.value); else { try { localStorage.removeItem("flag-" + key); } catch (e) {} } updateCount(); };
  box.addEventListener("change", save);
  note.addEventListener("input", save);
  flags.push({ box, note, describe });
  wrap.append(label, note);
  return wrap;
}
function updateCount() { const n = flags.filter((f) => f.box.checked).length; $("count").textContent = n + " flagged"; }
const firstVoices = [];
DATA.phrases.forEach((p, i) => {
  const row = el("article", "row"); row.id = "p" + (i + 1);
  row.append(el("div", "num", String(i + 1).padStart(2, "0")));
  const say = el("div", "say");
  const bo = el("div", "bo", p.bo); bo.lang = "bo";
  say.append(bo, el("div", "ph", p.t));
  const mean = el("div", "mean");
  mean.append(el("div", "g", p.g || "(laughter)"));
  if (p.when) mean.append(el("div", "when", p.when));
  if (p.note) { const d = el("div", "doubt"); const b = el("b", "", "Check this: "); d.append(b, document.createTextNode(p.note)); mean.append(d); }
  const voices = el("div", "voices");
  const chips = el("div", "chips");
  p.chips.forEach((c, k) => { const b = voiceButton(c.label, c.f, c.who); chips.append(b); if (k === 0) firstVoices.push(b); });
  voices.append(chips, flagBox("p" + (i + 1), "phrase " + (i + 1) + " " + p.t));
  row.append(say, mean, voices);
  $("phrases").append(row);
});
function lineRow(line, key, who) {
  const box = el("div");
  const l = el("div", "line");
  l.append(voiceButton("Play", line.f, who), el("div", "t", line.t + (line.g ? "  (" + line.g + ")" : "")));
  box.append(l);
  return box;
}
function groupRow(title, sub, rows, key) {
  const w = el("article", "who");
  const head = el("div");
  head.append(el("div", "name", title));
  if (sub) head.append(el("div", "when", sub));
  const list = el("div");
  rows.forEach((r) => list.append(lineRow(r, key, title)));
  list.append(flagBox(key, title));
  w.append(head, list);
  return w;
}
$("start").append(groupRow("The starter", "Tibetan countdown", DATA.start, "starter"));
$("start").append(groupRow("The crowd", "Many voices shouting together", DATA.crowd, "crowd"));
DATA.cast.forEach((c) => $("cast").append(groupRow(c.name, c.region, c.lines, c.id)));
DATA.tellers.forEach((t, i) => $("tellers").append(groupRow(t.name, "", t.lines, "teller" + i)));
const savedVol = store.get("vol");
if (savedVol !== null) $("vol").value = savedVol;
$("vol").addEventListener("input", setVolume);
$("stop").addEventListener("click", stopAll);
$("playall").addEventListener("click", () => {
  stopAll();
  queue = firstVoices.slice();
  $("playall").classList.add("on");
  const b = queue.shift();
  play(b.dataset.f, b);
});
$("copy").addEventListener("click", () => {
  const picked = flags.filter((f) => f.box.checked);
  const text = picked.length ? "Voice check notes:\n" + picked.map((f) => "- " + f.describe + (f.note.value ? ": " + f.note.value : "")).join("\n") : "Voice check notes: everything sounded fine.";
  const done = () => { $("copy").textContent = "Copied"; setTimeout(() => { $("copy").textContent = "Copy my notes"; }, 1600); };
  const showBox = () => { const t = $("fallback"); t.hidden = false; t.value = text; t.focus(); t.select(); };
  if (navigator.clipboard && navigator.clipboard.writeText) navigator.clipboard.writeText(text).then(done, showBox); else showBox();
});
updateCount();
</script>
"""


def main():
    out = sys.argv[1]
    data, blobs = build()
    page = PAGE.replace("/*DATA*/", json.dumps(data, ensure_ascii=False)).replace("/*AUDIO*/", json.dumps(blobs))
    with open(out, "w", encoding="utf-8", newline="\n") as f:
        f.write(page)
    print("%s: %.1f MB, %d sounds, %d phrases" % (out, os.path.getsize(out) / 1048576.0, len(blobs), len(data["phrases"])))
    print("chips per phrase:", [len(p["chips"]) for p in data["phrases"]])


if __name__ == "__main__":
    main()
