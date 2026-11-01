extends Node
## Autoload: persistent state, saving, scene flow, race results and the data lookups the menus need.
## Owned by the UI/meta agent. Prices and stats come from data/game_data.gd when it has them (loaded at run time, so
## a missing or half-written file never breaks the menus) and from scripts/ui/fallback_data.gd otherwise.

signal money_changed

const SAVE_PATH := "user://save.cfg"
const SETTINGS_PATH := "user://settings.cfg"
const SCENES := {
	"title": "res://scenes/title.tscn",
	"select": "res://scenes/rider_select.tscn",
	"story": "res://scenes/story.tscn",
	"league": "res://scenes/league.tscn",
	"prerace": "res://scenes/pre_race.tscn",
	"race": "res://scenes/race.tscn",
	"results": "res://scenes/results.tscn",
	"stable": "res://scenes/stable.tscn",
	"credits": "res://scenes/credits.tscn",
}
const START_MONEY := 150
const LOAN_BELOW := 20
const LOAN_AMOUNT := 60
const SCOOP_BASE := 10
const COURSES_PER_SEASON := 5
const SAVE_VERSION := 1

var player_id := "joru"
var season := 0
var course_index := 0
var money := START_MONEY
var horse_id := "old_tsampa"
var owned_horses: Array[String] = ["old_tsampa"]
var weapon_id := "fists"
var owned_weapons: Array[String] = ["fists"]
var ranged_id := ""
var has_shield := false
var saddle_level := 0
var armor_level := 0
var qualified: Array[bool] = [false, false, false, false, false]
var grudges: Dictionary = {}

# Career bookkeeping
var loans := 0
var loan_gossip := 0
var races_run := 0
var wins := 0
var finished_game := false

# Hand-offs between scenes
var last_result: Dictionary = {}
var race_log: Dictionary = {"knockdowns": {}}
var story_pages: Array = []
var story_next := "league"
var loan_notice := false
var save_path := SAVE_PATH     # tests point this somewhere else

# Settings
var music_volume := 0.8
var sfx_volume := 0.9
var fullscreen := false

var _gd: GDScript
var _courses: GDScript
var _fade_rect: ColorRect
var _changing := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	InputSetup.register()
	_load_settings()
	var layer := CanvasLayer.new()
	layer.layer = 120
	add_child(layer)
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0.09, 0.075, 0.1, 0.0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade_rect)
	_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## Everything Race needs to set up a race.
func race_config() -> Dictionary:
	return {
		"course_index": course_index,
		"season": season,
		"player_id": player_id,
		"horse_id": horse_id,
		"weapon_id": weapon_id,
		"ranged_id": ranged_id,
		"has_shield": has_shield,
		"saddle_level": saddle_level,
		"armor_level": armor_level,
		"grudges": grudges,
		"featured_rival": featured_rival().get("id", ""),
	}


# ------------------------------------------------------------------ scene flow

func go(key: String) -> void:
	var path: String = SCENES.get(key, key)
	if _changing:
		return
	if not ResourceLoader.exists(path):
		push_warning("Game.go: no scene at %s" % path)
		return
	_changing = true
	Sfx.stop_loops()
	var tw := create_tween()
	tw.tween_property(_fade_rect, "color:a", 1.0, 0.14)
	await tw.finished
	get_tree().paused = false
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("Game.go: could not open %s (%s)" % [path, error_string(err)])
	await get_tree().process_frame
	await get_tree().process_frame
	var tw2 := create_tween()
	tw2.tween_property(_fade_rect, "color:a", 0.0, 0.22)
	await tw2.finished
	_changing = false


func _input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo and (event as InputEventKey).keycode == KEY_F11:
		set_fullscreen(not fullscreen)


func start_race() -> void:
	race_log = {"knockdowns": {}}
	go("race")


func show_story(pages: Array, next_scene: String) -> void:
	story_pages = pages
	story_next = next_scene
	go("story")


func quit_game() -> void:
	save_settings()
	get_tree().quit()


# ------------------------------------------------------------------ settings

func _load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) == OK:
		music_volume = float(cf.get_value("audio", "music", music_volume))
		sfx_volume = float(cf.get_value("audio", "sfx", sfx_volume))
		fullscreen = bool(cf.get_value("video", "fullscreen", false))
	_apply_window()


func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("audio", "music", music_volume)
	cf.set_value("audio", "sfx", sfx_volume)
	cf.set_value("video", "fullscreen", fullscreen)
	cf.save(SETTINGS_PATH)


func set_fullscreen(on: bool) -> void:
	fullscreen = on
	_apply_window()
	save_settings()


func _apply_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)


# ------------------------------------------------------------------ new game, save, load

func new_game(pid: String) -> void:
	player_id = pid
	season = 0
	course_index = 0
	money = START_MONEY
	var start_horse := str(FallbackData.PLAYERS.get(pid, {}).get("horse", "old_tsampa"))
	horse_id = start_horse
	owned_horses = [start_horse]
	weapon_id = "fists"
	owned_weapons = ["fists"]
	ranged_id = ""
	has_shield = false
	saddle_level = 0
	armor_level = 0
	qualified = [false, false, false, false, false]
	grudges = {}
	loans = 0
	loan_gossip = 0
	races_run = 0
	wins = 0
	finished_game = false
	last_result = {}
	race_log = {"knockdowns": {}}
	loan_notice = false
	save_game()


func has_save() -> bool:
	return FileAccess.file_exists(save_path)


func save_game() -> void:
	var cf := ConfigFile.new()
	cf.set_value("game", "version", SAVE_VERSION)
	var keys := ["player_id", "season", "course_index", "money", "horse_id", "owned_horses", "weapon_id", "owned_weapons",
		"ranged_id", "has_shield", "saddle_level", "armor_level", "qualified", "grudges", "loans", "loan_gossip",
		"races_run", "wins", "finished_game"]
	for k: String in keys:
		cf.set_value("game", k, get(k))
	cf.save(save_path)


func load_game() -> bool:
	var cf := ConfigFile.new()
	if cf.load(save_path) != OK:
		return false
	player_id = str(cf.get_value("game", "player_id", "joru"))
	season = clampi(int(cf.get_value("game", "season", 0)), 0, 2)
	course_index = clampi(int(cf.get_value("game", "course_index", 0)), 0, COURSES_PER_SEASON - 1)
	money = int(cf.get_value("game", "money", START_MONEY))
	horse_id = str(cf.get_value("game", "horse_id", "old_tsampa"))
	owned_horses.assign(cf.get_value("game", "owned_horses", ["old_tsampa"]))
	weapon_id = str(cf.get_value("game", "weapon_id", "fists"))
	owned_weapons.assign(cf.get_value("game", "owned_weapons", ["fists"]))
	ranged_id = str(cf.get_value("game", "ranged_id", ""))
	has_shield = bool(cf.get_value("game", "has_shield", false))
	saddle_level = int(cf.get_value("game", "saddle_level", 0))
	armor_level = int(cf.get_value("game", "armor_level", 0))
	qualified.assign(cf.get_value("game", "qualified", [false, false, false, false, false]))
	while qualified.size() < COURSES_PER_SEASON:
		qualified.append(false)
	var g: Variant = cf.get_value("game", "grudges", {})
	grudges = g if g is Dictionary else {}
	loans = int(cf.get_value("game", "loans", 0))
	loan_gossip = int(cf.get_value("game", "loan_gossip", 0))
	races_run = int(cf.get_value("game", "races_run", 0))
	wins = int(cf.get_value("game", "wins", 0))
	finished_game = bool(cf.get_value("game", "finished_game", false))
	if owned_horses.is_empty():
		owned_horses = ["old_tsampa"]
	if owned_weapons.is_empty():
		owned_weapons = ["fists"]
	return true


func add_money(n: int) -> void:
	money = maxi(0, money + n)
	money_changed.emit()


## Aunt Ama Choekyi lends 60 srang when you are under 20. Returns true if she did.
func check_loan() -> bool:
	if money < LOAN_BELOW:
		money += LOAN_AMOUNT
		loans += 1
		loan_gossip = 3
		loan_notice = true
		money_changed.emit()
		save_game()
		return true
	return false


# ------------------------------------------------------------------ data lookups

func gd() -> GDScript:
	if _gd == null and ResourceLoader.exists("res://data/game_data.gd"):
		_gd = load("res://data/game_data.gd") as GDScript
	return _gd


func gd_const(const_name: String, fallback: Variant = null) -> Variant:
	var g := gd()
	if g != null:
		var m: Dictionary = g.get_script_constant_map()
		if m.has(const_name):
			return m[const_name]
	return fallback


func gd_call(func_name: String, args: Array, fallback: Variant = null) -> Variant:
	var g := gd()
	if g != null and g.has_method(func_name):
		return g.callv(func_name, args)
	return fallback


func weapon(id: String) -> Dictionary:
	var out: Dictionary = (FallbackData.WEAPONS.get(id, {}) as Dictionary).duplicate()
	var all: Variant = gd_const("WEAPONS", {})
	if all is Dictionary and (all as Dictionary).has(id):
		out.merge((all as Dictionary)[id], true)
	if out.is_empty():
		out = {"name": id.to_upper().replace("_", " "), "klass": "melee", "damage": 0, "impact": 0, "reach": 0.0, "swing": 0.0, "cost": 0, "ammo": 0, "desc": ""}
	out["id"] = id
	out["name"] = str(out.get("name", id)).to_upper()
	return out


func weapon_ids(klass: String) -> Array[String]:
	var ids: Array[String] = []
	var seen: Dictionary = {}
	var all: Variant = gd_const("WEAPONS", {})
	var sources: Array = []
	if all is Dictionary:
		sources.append((all as Dictionary).keys())
	sources.append(FallbackData.WEAPONS.keys())
	for src: Array in sources:
		for k: Variant in src:
			var id := str(k)
			if seen.has(id):
				continue
			seen[id] = true
			if str(weapon(id).get("klass", "")) == klass:
				ids.append(id)
	return ids


func horse(id: String) -> Dictionary:
	var out: Dictionary = (FallbackData.HORSES.get(id, {}) as Dictionary).duplicate()
	var all: Variant = gd_const("HORSES", {})
	if all is Dictionary and (all as Dictionary).has(id):
		out.merge((all as Dictionary)[id], true)
	if out.is_empty():
		out = {"name": id.to_upper().replace("_", " "), "cost": 0, "speed": 20.0, "accel": 6.5, "handling": 3.0, "stamina": 80.0, "bulk": 1.0, "desc": ""}
	out["id"] = id
	out["name"] = str(out.get("name", id)).to_upper()
	return out


## Horses on sale in the Stable, cheapest first. Rivals' own horses are not for sale.
func stable_horse_ids() -> Array[String]:
	var ids: Array[String] = FallbackData.HORSE_ORDER.duplicate()
	var all: Variant = gd_const("HORSES", {})
	if all is Dictionary:
		for k: Variant in (all as Dictionary).keys():
			var id := str(k)
			var h: Dictionary = (all as Dictionary)[k]
			if not ids.has(id) and h.has("cost") and int(h.get("cost", 0)) > 0 and not bool(h.get("rival_only", false)) and h.get("for_sale", true):
				ids.append(id)
	ids.sort_custom(func(a: String, b: String) -> bool: return int(horse(a).get("cost", 0)) < int(horse(b).get("cost", 0)))
	return ids


func saddles() -> Array:
	var t: Variant = gd_const("TACK", null)
	if t is Dictionary and (t as Dictionary).get("saddle") is Array and not ((t as Dictionary)["saddle"] as Array).is_empty():
		return (t as Dictionary)["saddle"]
	return FallbackData.SADDLES


func armors() -> Array:
	var t: Variant = gd_const("TACK", null)
	if t is Dictionary and (t as Dictionary).get("armor") is Array and not ((t as Dictionary)["armor"] as Array).is_empty():
		return (t as Dictionary)["armor"]
	return FallbackData.ARMOR


func prize_for(season_idx: int, place: int) -> int:
	var v: Variant = gd_call("prize", [season_idx, place], null)
	if v != null:
		return int(v)
	var row: Array = FallbackData.PRIZES[clampi(season_idx, 0, 2)]
	return int(row[place - 1]) if place >= 1 and place <= 3 else 0


func bounty_rate(season_idx: int) -> int:
	var v: Variant = gd_call("bounty", [season_idx], null)
	return int(v) if v != null else int(FallbackData.BOUNTY[clampi(season_idx, 0, 2)])


func fine_rate(season_idx: int) -> int:
	var v: Variant = gd_call("fine", [season_idx], null)
	return int(v) if v != null else int(FallbackData.FINE[clampi(season_idx, 0, 2)])


func scoop_value(season_idx: int) -> int:
	return SCOOP_BASE * (season_idx + 1)


func course_count() -> int:
	return COURSES_PER_SEASON


func course_info(index: int, season_idx: int = -1) -> Dictionary:
	var fb: Dictionary = StoryText.course_fallback(index)
	var out := {"name": fb["name"], "region": fb["region"], "blurb": fb["blurb"]}
	if _courses == null and ResourceLoader.exists("res://data/courses.gd"):
		_courses = load("res://data/courses.gd") as GDScript
	if _courses != null and _courses.has_method("get_course"):
		var c: Variant = _courses.call("get_course", index, season if season_idx < 0 else season_idx)
		if c is Dictionary:
			var cd: Dictionary = c
			if cd.has("name"):
				out["name"] = str(cd["name"]).to_upper()
			if cd.has("region"):
				out["region"] = str(cd["region"]).to_upper()
			if cd.has("blurb"):
				out["blurb"] = str(cd["blurb"]).to_upper()
	return out


## The qualifying place for a course: top 3, except the final race of the final season, which must be won.
func needed_place(season_idx: int, index: int) -> int:
	return 1 if (season_idx >= 2 and index >= COURSES_PER_SEASON - 1) else 3


func is_final(season_idx: int, index: int) -> bool:
	return season_idx >= 2 and index >= COURSES_PER_SEASON - 1


func all_qualified() -> bool:
	for q in qualified:
		if not q:
			return false
	return true


func qualified_count() -> int:
	var n := 0
	for q in qualified:
		if q:
			n += 1
	return n


func next_course() -> int:
	for i in qualified.size():
		if not qualified[i]:
			return i
	return clampi(course_index, 0, COURSES_PER_SEASON - 1)


# ------------------------------------------------------------------ rivals

func _pick(v: Variant, salt: int) -> String:
	if v is Array and not (v as Array).is_empty():
		return str((v as Array)[abs(salt) % (v as Array).size()])
	if v is String:
		return v
	return ""


func rival(id: String) -> Dictionary:
	var fb: Dictionary = StoryText.RIVALS.get(id, {})
	var data: Dictionary = {}
	var all: Variant = gd_const("RIVALS", {})
	if all is Dictionary and (all as Dictionary).has(id):
		data = (all as Dictionary)[id]
	var lines: Dictionary = data.get("lines", {}) if data.get("lines") is Dictionary else {}
	var salt := season * 5 + course_index + races_run
	return {
		"id": id,
		"name": str(data.get("name", fb.get("name", id.to_upper()))).to_upper(),
		"region": str(data.get("region", fb.get("region", ""))).to_upper(),
		"intro": _pick(lines.get("intro"), salt) if _pick(lines.get("intro"), salt) != "" else str(fb.get("intro", "")),
		"grudge": _pick(lines.get("grudge"), salt) if _pick(lines.get("grudge"), salt) != "" else str(fb.get("grudge", "")),
		"win": _pick(lines.get("win"), salt) if _pick(lines.get("win"), salt) != "" else str(fb.get("win", "")),
	}


func active_rival_ids(season_idx: int) -> Array[String]:
	var ids: Array[String] = []
	var all: Variant = gd_const("RIVALS", {})
	if all is Dictionary and not (all as Dictionary).is_empty():
		for k: Variant in (all as Dictionary).keys():
			var d: Dictionary = (all as Dictionary)[k]
			var seasons: Variant = d.get("seasons", [0, 1, 2])
			if seasons is Array and (seasons as Array).has(season_idx):
				ids.append(str(k))
	if ids.is_empty():
		for k: String in StoryText.RIVALS.keys():
			if int(StoryText.RIVALS[k].get("from", 0)) <= season_idx:
				ids.append(k)
	return ids


## The rival who talks to you on the pre-race card: whoever you've wronged most, else the course's own.
func featured_rival() -> Dictionary:
	var ids := active_rival_ids(season)
	var best := ""
	var best_n := 0
	for k: Variant in grudges.keys():
		var n := int(grudges[k])
		if n > best_n and ids.has(str(k)):
			best_n = n
			best = str(k)
	var kind := "intro"
	if best != "":
		kind = "grudge"
	else:
		var pref: String = StoryText.COURSE_RIVAL[clampi(course_index, 0, 4)]
		if is_final(season, course_index):
			pref = "wangyal"
		best = pref if ids.has(pref) else (ids[0] if not ids.is_empty() else "wangyal")
	var r := rival(best)
	var line := str(r.get(kind, ""))
	if loan_gossip > 0 and kind == "intro":
		kind = "loan"
		line = StoryText.LOAN_LINES[(loans + course_index) % StoryText.LOAN_LINES.size()]
	r["kind"] = kind
	r["line"] = line
	r["grudge_count"] = best_n
	return r


func note_knockdown(rival_id: String) -> void:
	if rival_id == "":
		return
	var kd: Dictionary = race_log.get("knockdowns", {})
	kd[rival_id] = int(kd.get(rival_id, 0)) + 1
	race_log["knockdowns"] = kd


# ------------------------------------------------------------------ race results

func _prop(o: Variant, prop: String, default: Variant) -> Variant:
	if o is Object and is_instance_valid(o as Object):
		var v: Variant = (o as Object).get(prop)
		return default if v == null else v
	if o is Dictionary:
		return (o as Dictionary).get(prop, default)
	return default


## Race.race_finished(results) -> money, qualification, grudges, autosave. Returns (and stores) the summary the results
## screen shows. Safe to call with odd or partial results.
func apply_race_result(results: Array) -> Dictionary:
	var rows: Array[Dictionary] = []
	var idx := 0
	for e: Variant in results:
		idx += 1
		var rider: Variant = _prop(e, "rider", null)
		rows.append({
			"place": int(_prop(e, "place", _prop(rider, "place", idx))),
			"name": str(_prop(rider, "display_name", "RIDER %d" % idx)).to_upper(),
			"rival_id": str(_prop(rider, "rival_id", "")),
			"is_player": bool(_prop(rider, "is_player", false)),
			"time": float(_prop(e, "time", 0.0)),
			"knockdowns": int(_prop(e, "knockdowns", 0)),
			"crashed": int(_prop(e, "crashed", 0)),
			"scoops": int(_prop(e, "scoops", 0)),
			"bounty": int(_prop(e, "bounty", 0)),
			"fines": int(_prop(e, "fines", 0)),
			"silver": int(_prop(e, "silver", -1)),
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["place"]) < int(b["place"]))
	var prow: Dictionary = {}
	for r in rows:
		if r["is_player"]:
			prow = r
	var n := maxi(rows.size(), 8)
	if prow.is_empty():
		prow = {"place": n, "name": "YOU", "rival_id": "", "is_player": true, "time": 0.0, "knockdowns": 0, "crashed": 0, "scoops": 0, "bounty": 0, "fines": 0, "silver": 0}
	var place := int(prow["place"])
	var season_before := season
	var course_done := course_index
	var money_before := money

	var prize := prize_for(season, place) if place >= 1 and place <= 3 else 0
	var kd := int(prow["knockdowns"])
	var bounty := int(prow["bounty"])
	if bounty <= kd and kd > 0:
		bounty = kd * bounty_rate(season)
	var scoop_count := int(prow["scoops"])
	var scoop_silver := int(prow["silver"]) if int(prow["silver"]) >= 0 else scoop_count * scoop_value(season)
	var fine := int(prow["fines"])
	var gained := prize + bounty + scoop_silver
	money = maxi(0, money + gained - fine)

	var needed := needed_place(season, course_index)
	var ok := place >= 1 and place <= needed
	if ok:
		qualified[course_index] = true
	races_run += 1
	if place == 1:
		wins += 1

	var kdl: Dictionary = race_log.get("knockdowns", {})
	for k: Variant in kdl.keys():
		grudges[str(k)] = mini(int(grudges.get(str(k), 0)) + int(kdl[k]), 5)
	if loan_gossip > 0:
		loan_gossip -= 1
	race_log = {"knockdowns": {}}

	var cleared := false
	var won := false
	if ok and all_qualified():
		if season >= 2:
			if not finished_game:
				won = true
			finished_game = true
		else:
			cleared = true
			season += 1
			qualified = [false, false, false, false, false]
			course_index = 0
	var loan_given := check_loan()

	var line := {"name": "", "line": "", "id": ""}
	for r in rows:
		if not r["is_player"] and r["rival_id"] != "":
			var beat_player: bool = int(r["place"]) < place
			if beat_player or (place == 1 and int(r["place"]) == 2):
				var info := rival(str(r["rival_id"]))
				var text: String = info["win"]
				if not beat_player:
					text = info["grudge"] if int(grudges.get(info["id"], 0)) > 0 else StoryText.LOSE_LINES[(races_run + int(r["place"])) % StoryText.LOSE_LINES.size()]
				line = {"name": info["name"], "line": text, "id": info["id"]}
				break
	last_result = {
		"rows": rows, "place": place, "field": n, "time": float(prow["time"]),
		"course_index": course_done, "season": season_before,
		"prize": prize, "bounty": bounty, "knockdowns": kd, "scoop_count": scoop_count, "scoops": scoop_silver, "fine": fine,
		"qualified": ok, "needed": needed, "money_before": money_before, "money_after": money,
		"loan": loan_given, "season_cleared": cleared, "won_game": won, "rival_line": line,
	}
	save_game()
	money_changed.emit()
	return last_result
