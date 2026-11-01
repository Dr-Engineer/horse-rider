class_name Speak
extends RefCounted
## The menus' way into the voice side of Sfx, which Audio provides. A missing method, a missing sound file and a muted
## voice all read the same here: nothing plays, and the caller gets 0.0 or {}. Never call Sfx.say* from a screen directly.


## True when voices are turned up and Sfx can speak at all.
static func can_speak() -> bool:
	return Game.voice_volume > 0.001 and Sfx.has_method("say_text")


## Speaks a line the menu shows, word for word. Returns its length in seconds, or 0.0 when nothing played.
static func text(speaker: String, line: String, volume_db: float = 0.0) -> float:
	if speaker == "" or line == "" or not can_speak():
		return 0.0
	var secs: Variant = Sfx.call("say_text", speaker, line, volume_db)
	return float(secs) if secs != null else 0.0


## Speaks a random line of a category. Returns the line {f, t, g, l, d}, or {} when nothing played.
static func say(speaker: String, category: String, lang: String = "") -> Dictionary:
	if Game.voice_volume <= 0.001 or not Sfx.has_method("say"):
		return {}
	var out: Variant = Sfx.call("say", speaker, category, null, 0.0, lang)
	return out if out is Dictionary else {}


static func stop() -> void:
	if Sfx.has_method("stop_voice"):
		Sfx.call("stop_voice")


static func playing() -> bool:
	return Sfx.has_method("voice_playing") and bool(Sfx.call("voice_playing"))


## A constant from data/voice_bank.gd (LINES, SAYINGS, PHRASES), read at run time so a half-written or missing bank is harmless.
static func bank(const_name: String, fallback: Variant) -> Variant:
	if not ResourceLoader.exists("res://data/voice_bank.gd"):
		return fallback
	var s := load("res://data/voice_bank.gd") as GDScript
	if s == null:
		return fallback
	var m: Dictionary = s.get_script_constant_map()
	return m.get(const_name, fallback)


## The old rider's sayings, in the bank's own wording.
static func sayings() -> Array:
	var v: Variant = bank("SAYINGS", [])
	return v if v is Array else []


## One entry per distinct Tibetan phrase: {t, g, f, speaker}. Uses the bank's PHRASES, or builds the list from LINES.
static func phrases() -> Array:
	var v: Variant = bank("PHRASES", [])
	if v is Array and not (v as Array).is_empty():
		return v
	var lines: Variant = bank("LINES", {})
	var out: Array = []
	if not (lines is Dictionary):
		return out
	var best: Dictionary = {}     # phrase -> the entry to play, preferring a speaker whose recording exists
	var speakers: Array = (lines as Dictionary).keys()
	speakers.sort()
	for sp: Variant in speakers:
		var cats: Variant = (lines as Dictionary)[sp]
		if not (cats is Dictionary):
			continue
		for cat: Variant in (cats as Dictionary).keys():
			for ln: Variant in (cats as Dictionary)[cat]:
				if not (ln is Dictionary) or str((ln as Dictionary).get("l", "")) != "bo":
					continue
				var t := str((ln as Dictionary).get("t", ""))
				var f := str((ln as Dictionary).get("f", ""))
				if not best.has(t) or (not has_recording(str(best[t]["f"])) and has_recording(f)):
					best[t] = {"t": t, "g": (ln as Dictionary).get("g", ""), "f": f, "speaker": sp}
	for t: Variant in best.keys():
		out.append(best[t])
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a["t"]) < str(b["t"]))
	return out


static func has_recording(file_id: String) -> bool:
	return file_id != "" and ResourceLoader.exists("res://assets/audio/voice/%s.ogg" % file_id)


## Plays one voice file by id (a line's `f`). The phrasebook plays phrases, not whole categories.
## Returns the length in seconds, or 0.0 when there is nothing to hear.
static func file(file_id: String) -> float:
	if file_id == "" or Game.voice_volume <= 0.001 or not Sfx.has_method("say_file"):
		return 0.0
	var secs: Variant = Sfx.call("say_file", file_id, 0.0)
	return float(secs) if secs != null else 0.0
