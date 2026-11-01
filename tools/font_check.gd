# Finds text the headline font can't draw: every string the menus, the subtitles and the voice bank can show is checked against
# the glyphs in assets/fonts/headline.fnt. Prints each stray character with where it was found.
# Usage: Godot --headless --audio-driver Dummy --path . -s res://tools/font_check.gd
extends SceneTree

var glyphs: Dictionary = {}
var strays: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _load_glyphs() -> void:
	var f := FileAccess.open("res://assets/fonts/headline.fnt", FileAccess.READ)
	while not f.eof_reached():
		var line := f.get_line()
		if line.begins_with("char id="):
			glyphs[int(line.split(" ")[1].split("=")[1])] = true


func _scan(text: String, where: String) -> void:
	for i in text.length():
		var code := text.unicode_at(i)
		if not glyphs.has(code):
			var key := "%s (U+%04X)" % [String.chr(code), code]
			if not strays.has(key):
				strays[key] = []
			if (strays[key] as Array).size() < 3:
				(strays[key] as Array).append("%s: %s" % [where, text.substr(maxi(i - 12, 0), 26)])


func _walk(v: Variant, where: String) -> void:
	if v is String:
		_scan(v, where)
	elif v is Array:
		for x: Variant in v:
			_walk(x, where)
	elif v is Dictionary:
		for k: Variant in (v as Dictionary).keys():
			_walk((v as Dictionary)[k], where)


func _run() -> void:
	await process_frame
	_load_glyphs()
	var story := load("res://scripts/ui/story_text.gd") as GDScript
	var consts: Dictionary = story.get_script_constant_map()
	for k: String in consts:
		_walk(consts[k], "StoryText." + k)
	for pid in ["joru", "yangkyi"]:
		_walk(story.call("intro_pages", pid), "intro " + pid)
		_walk(story.call("season_end_pages", pid, 0), "season 0 " + pid)
		_walk(story.call("season_end_pages", pid, 1), "season 1 " + pid)
		_walk(story.call("victory_pages", pid), "victory " + pid)
	_walk(story.call("credits_lines"), "credits")
	var fb := load("res://scripts/ui/fallback_data.gd") as GDScript
	_walk(fb.get_script_constant_map(), "FallbackData")
	var bank := load("res://data/voice_bank.gd") as GDScript
	var bm: Dictionary = bank.get_script_constant_map()
	for k: String in bm:
		var v: Variant = bm[k]
		if k == "LINES":
			for sp: Variant in (v as Dictionary).keys():
				for cat: Variant in (v[sp] as Dictionary).keys():
					for ln: Variant in v[sp][cat]:
						_scan(str(ln.get("t", "")), "voice %s/%s t" % [sp, cat])
						_scan(str(ln.get("g", "")), "voice %s/%s g" % [sp, cat])
		else:
			_walk(v, "VoiceBank." + k)
	var gd := load("res://data/game_data.gd") as GDScript
	var gm: Dictionary = gd.get_script_constant_map()
	for k: String in ["RIVALS", "PLAYERS", "WEAPONS", "HORSES", "TACK"]:
		if gm.has(k):
			_walk(gm[k], "GameData." + k)
	if strays.is_empty():
		print("font check: every string can be drawn")
	for k: String in strays:
		print("STRAY ", k, " -> ", strays[k])
	quit()
