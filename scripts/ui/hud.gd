class_name Hud
extends CanvasLayer
## The in-race HUD. scenes/race.tscn adds one and calls hud.bind(race). Everything is read defensively from the Race
## and Rider fields listed in docs/INTERFACES.md, so a missing field just reads as a default.
## Also owns the countdown, announcements, pause menu and the hand-off to the results screen.

const PLATE_W := 156.0
const RIVAL_RANGE := 25.0
const RIVAL_LEAVE := 31.0
const CHEVRON_RANGE := 12.0
const FINISH_DELAY := 1.2
const BASE_HALF := 5.0
const SUB_W := 206.0          # the subtitle strip under the rival plate
const SUB_PAD := 8.0
const SUB_PORTRAIT := 24.0
const SUB_SIDE := 33.0        # the portrait, and room beside it, which the first two rows of text give up
const SUB_DROP := 3.0         # rows below the portrait start a little lower so they don't touch its frame
const SUB_MIN_SHOW := 0.7     # a line is on screen at least this long before the next one may replace it
const SUB_SLIDE := 0.2
const MAX_INFO_LINES := 3
const SIGHT_HIT_TIME := 0.3

var race: Node
var _canvas: HudCanvas
var _t := 0.0
var _p: Object
var _riders: Array = []
var _length := 1.0
var _zones: Array[Vector2] = []
var _announce: Array[Dictionary] = []
var _rival: Object
var _rival_slide := 0.0
var _quiet_alpha := 0.0
var _countdown_last := -1
var _go_until := -1.0
var _started := false
var _rest_initial := 0.0
var _prev_state := ""
var _prev_lungta := 0.0
var _finished := false
var _paused := false
var _last_hit: Dictionary = {}
var _pause_root: Control
var _pause_buttons: Array[WButton] = []
var _options: Control
var _vignette := 0.0
var _hint_age := 0.0
var _comic_i := 0
var _trail_hp := 1.0
var _hurt := 0.0
var _sight_hit := 0.0
var _prev_hp := 1.0
var _wname_cache: Dictionary = {}
var _sub: Dictionary = {}          # the subtitle on show, laid out when it arrived
var _sub_next: Dictionary = {}     # one waiting line; a newer one replaces it


func _init() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_canvas = HudCanvas.new()
	_canvas.hud = self
	add_child(_canvas)
	_take_pointer()
	if Input.mouse_mode == Input.MOUSE_MODE_CONFINED_HIDDEN:
		get_viewport().warp_mouse(get_viewport().get_visible_rect().size * Vector2(0.5, 0.4))
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_pause()


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## In a race the mouse is the sight, so the pointer is hidden and kept inside the window. Only while the game has focus, or
## it would trap the pointer of someone working elsewhere. Never in a test run: keeping the pointer in a window clips the
## real cursor on the real desktop, and tests must never touch that.
func _take_pointer() -> void:
	var grab := not Game.test_run and get_window().has_focus()
	Input.mouse_mode = Input.MOUSE_MODE_CONFINED_HIDDEN if grab else Input.MOUSE_MODE_VISIBLE


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_IN and not _paused and is_inside_tree():
		_take_pointer()
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func bind(r: Node) -> void:
	race = r
	_connect(r, "announcement", _on_announcement)
	_connect(r, "race_started", _on_race_started)
	_connect(r, "race_finished", _on_race_finished)
	_connect(r, "rider_hit", _on_rider_hit)
	_connect(r, "rider_crashed", _on_rider_crashed)
	_connect(r, "chatter", _on_chatter)
	Sfx.music("final" if Game.is_final(Game.season, Game.course_index) else "race")
	_cache_course()


func _connect(obj: Object, sig: String, cb: Callable) -> void:
	if obj != null and obj.has_signal(sig) and not obj.is_connected(sig, cb):
		obj.connect(sig, cb)


static func _g(o: Object, prop: String, default: Variant) -> Variant:
	if o == null or not is_instance_valid(o):
		return default
	var v: Variant = o.get(prop)
	return default if v == null else v


func _cache_course() -> void:
	_zones.clear()
	var course: Variant = _g(race, "course", {})
	if course is Dictionary:
		var events: Variant = (course as Dictionary).get("events", [])
		if events is Array:
			for e: Variant in events:
				if e is Dictionary and str((e as Dictionary).get("type", "")) == "quiet_zone":
					_zones.append(Vector2(float((e as Dictionary).get("s0", 0.0)), float((e as Dictionary).get("s1", 0.0))))
	var finish := float(_g(race, "finish_s", 0.0))
	var track: Variant = _g(race, "track", null)
	if finish > 10.0:
		_length = finish
	elif track is Object:
		_length = maxf(float(_g(track as Object, "length", 0.0)), 1.0)


# ------------------------------------------------------------------ signals

## The words of a readout without its numbers, so "STREAK X3" after "STREAK X2" is known for the same readout.
static func _readout_key(s: String) -> String:
	var out := s
	for ch in "0123456789+-":
		out = out.replace(ch, "")
	return " ".join(out.split(" ", false))


func _on_announcement(text: String, kind: String) -> void:
	var up := text.to_upper()
	var short_big := kind == "big" and (up.is_valid_int() or up == "GO!")
	var key := "" if short_big else _readout_key(up)
	# The same readout again (a bigger streak, another near miss) refreshes the one on show instead of piling up beside it.
	if key != "":
		for x in _announce:
			if x["kind"] == kind and x["key"] == key:
				x["text"] = up
				x["age"] = 0.0
				return
	_comic_i += 1
	var a := {"text": up, "kind": kind, "key": key, "age": 0.0, "tilt": randf_range(-0.05, 0.05), "dx": randf_range(-36.0, 36.0), "dy": (-12.0 if _comic_i % 2 == 0 else 12.0) + randf_range(-2.0, 2.0)}
	match kind:
		"big":
			a["life"] = 0.95 if short_big else 1.8
			a["huge"] = short_big
			# one big word at a time: a new one takes the place of the last of its size
			var keep: Array[Dictionary] = []
			for x in _announce:
				if not (x["kind"] == "big" and bool(x.get("huge", false)) == short_big):
					keep.append(x)
			_announce = keep
		"info":
			a["life"] = 2.4
			var infos := 0
			for x in _announce:
				if x["kind"] == "info":
					infos += 1
			while infos >= MAX_INFO_LINES:
				for i in _announce.size():
					if _announce[i]["kind"] == "info":
						_announce.remove_at(i)
						break
				infos -= 1
		_:
			a["life"] = 0.58
			var comics := 0
			for x in _announce:
				if x["kind"] != "big" and x["kind"] != "info":
					comics += 1
			if comics >= 2:
				for i in _announce.size():
					if _announce[i]["kind"] != "big" and _announce[i]["kind"] != "info":
						_announce.remove_at(i)
						break
	_announce.append(a)


func _on_race_started() -> void:
	_started = true


func _on_rider_hit(attacker: Object, victim: Object, info: Dictionary) -> void:
	if attacker == _p and str(info.get("klass", "")) == "ranged" and not info.get("ignored", false):
		_sight_hit = SIGHT_HIT_TIME
	if victim != null and attacker != null and is_instance_valid(victim) and is_instance_valid(attacker):
		_last_hit[victim.get_instance_id()] = {"attacker": attacker, "t": _t}


func _on_rider_crashed(rider: Object, reason: String) -> void:
	if rider == null or not is_instance_valid(rider) or bool(_g(rider, "is_player", false)):
		return
	var rec: Variant = _last_hit.get(rider.get_instance_id())
	if rec is Dictionary and _t - float((rec as Dictionary)["t"]) < 3.0:
		var att: Object = (rec as Dictionary)["attacker"]
		if att != null and is_instance_valid(att) and bool(_g(att, "is_player", false)):
			Game.note_knockdown(str(_g(rider, "rival_id", "")))


func _on_race_finished(results: Array) -> void:
	if _finished:
		return
	_finished = true
	_sub = {}
	_sub_next = {}
	Game.apply_race_result(results)
	await get_tree().create_timer(FINISH_DELAY).timeout
	Game.go("results", true)


# ------------------------------------------------------------------ subtitles

## Race.chatter(rider, line): someone spoke. `line` is what Sfx.say returned (f, t, g, l, d) plus "speaker". rider may be
## null for the starter or a steward. One line shows at a time, and a new one waits for the last to have had its moment.
func _on_chatter(rider: Object, line: Dictionary) -> void:
	var entry := _make_subtitle(rider, line)
	if entry.is_empty():
		return
	if _sub.is_empty():
		_sub = entry
		_sub_next = {}
	else:
		_sub_next = entry


## Words flowed into rows. The first two rows sit beside the portrait when there is one, so they are narrower.
func _flow(text: String, first_row: int, has_portrait: bool, max_rows: int) -> Array[String]:
	var rows: Array[String] = []
	var cur := ""
	for word: String in text.split(" ", false):
		var room := SUB_W - 2.0 * SUB_PAD - (SUB_SIDE if has_portrait and first_row + rows.size() < 2 else 0.0)
		var test := word if cur == "" else cur + " " + word
		if cur != "" and UI.text_width(test) > room:
			rows.append(cur)
			cur = word
		else:
			cur = test
	if cur != "":
		rows.append(cur)
	if rows.size() > max_rows:
		rows.resize(max_rows)
		rows[max_rows - 1] = rows[max_rows - 1].rstrip(" .,!?") + "..."
	return rows


func _make_subtitle(rider: Object, line: Dictionary) -> Dictionary:
	var said := str(line.get("t", "")).strip_edges().to_upper()
	if said == "":
		return {}
	var gloss := str(line.get("g", "")).strip_edges().to_upper() if str(line.get("l", "en")) == "bo" else ""
	var who := ""
	var tex: Texture2D = null
	var has_rider := rider != null and is_instance_valid(rider)
	if has_rider:
		who = str(_g(rider, "display_name", ""))
		tex = UI.texture(str(_g(rider, "portrait", "")))
	if who == "":
		who = str(line.get("speaker", ""))
	var rows: Array = [{"s": _short_name(who, SUB_W - 2.0 * SUB_PAD - (SUB_SIDE if has_rider else 0.0)), "c": UI.ORPIMENT}]
	for r in _flow(said, 1, has_rider, 4):
		rows.append({"s": r, "c": UI.CONCH})
	if gloss != "":
		for r in _flow(gloss, rows.size(), has_rider, 2):
			rows.append({"s": r, "c": UI.ASH})
	var text_h := rows.size() * 12.0 + (SUB_DROP if has_rider and rows.size() > 2 else 0.0)
	var d := float(line.get("d", 0.0))
	return {
		"rows": rows, "tex": tex, "portrait": has_rider,
		"initial": who.substr(0, 1), "age": 0.0,
		"life": maxf(d, 0.035 * (said.length() + gloss.length() * 0.5)) + 1.0,
		"h": maxf(text_h, SUB_PORTRAIT if has_rider else 0.0) + 18.0,
	}


func _tick_subtitle(delta: float) -> void:
	if _sub.is_empty():
		return
	_sub["age"] = float(_sub["age"]) + delta
	var age := float(_sub["age"])
	if age >= float(_sub["life"]) or (not _sub_next.is_empty() and age >= SUB_MIN_SHOW):
		_sub = _sub_next
		_sub_next = {}


# ------------------------------------------------------------------ per-frame state

func _process(delta: float) -> void:
	_t += delta
	if race == null or not is_instance_valid(race):
		return
	_riders = _g(race, "riders", []) as Array
	_p = _g(race, "player", null) as Object
	if _p == null:
		for r: Variant in _riders:
			if r is Object and bool(_g(r as Object, "is_player", false)):
				_p = r
				break
	if _length <= 1.0:
		_cache_course()
	if not _paused:
		_update(delta)
	_canvas.queue_redraw()


func _update(delta: float) -> void:
	var alive: Array[Dictionary] = []
	for a in _announce:
		a["age"] = float(a["age"]) + delta
		if float(a["age"]) < float(a["life"]):
			alive.append(a)
	_announce = alive
	_tick_subtitle(delta)

	var cd := float(_g(race, "countdown", 0.0))
	if cd > 0.0 or _t < 0.05:
		_hint_age = 0.0
	else:
		_hint_age += delta

	if _p == null:
		return
	var state := str(_g(_p, "state", "ride"))
	if state == "down" or state == "rest":
		_rest_initial = maxf(_rest_initial, float(_g(_p, "rest_left", 0.0)))
	else:
		_rest_initial = 0.0
	_prev_state = state

	var hp_now := float(_g(_p, "health", 100.0)) / maxf(float(_g(_p, "max_health", 100.0)), 1.0)
	if hp_now < _prev_hp - 0.002:
		_hurt = 0.28
	_prev_hp = hp_now
	_hurt = maxf(_hurt - delta, 0.0)
	_sight_hit = maxf(_sight_hit - delta, 0.0)
	_trail_hp = hp_now if hp_now >= _trail_hp else move_toward(_trail_hp, hp_now, delta * 0.35)
	var lungta := float(_g(_p, "lungta", 0.0))
	if floorf(lungta) > floorf(_prev_lungta) and lungta > 0.0:
		Sfx.play("flag_up", -3.0)
	_prev_lungta = lungta

	# The rival plate: the nearest rider within range, kept until it is clearly gone.
	var ps := float(_g(_p, "s", 0.0))
	var pd := float(_g(_p, "d", 0.0))
	var best: Object = null
	var best_dist := 1e9
	for r: Variant in _riders:
		if not (r is Object) or r == _p or not is_instance_valid(r as Object):
			continue
		var d2 := Vector2(float(_g(r as Object, "s", 0.0)) - ps, float(_g(r as Object, "d", 0.0)) - pd).length()
		if d2 < best_dist:
			best_dist = d2
			best = r
	var limit := RIVAL_LEAVE if (_rival != null and best == _rival) else RIVAL_RANGE
	if best != null and best_dist <= limit:
		_rival = best
		_rival_slide = minf(_rival_slide + delta * 5.0, 1.0)
	else:
		_rival_slide = maxf(_rival_slide - delta * 5.0, 0.0)
		if _rival_slide <= 0.0:
			_rival = null

	var in_quiet := false
	for z in _zones:
		if ps >= z.x - 8.0 and ps <= z.y:
			in_quiet = true
	_quiet_alpha = move_toward(_quiet_alpha, 1.0 if in_quiet else 0.0, delta * 3.0)

	_vignette = move_toward(_vignette, 1.0 if (state == "down" or state == "rest") else 0.0, delta * 4.0)


# ------------------------------------------------------------------ pause

func _build_pause() -> void:
	_pause_root = Control.new()
	_pause_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_root.theme = UI.theme()
	_pause_root.visible = false
	_pause_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_pause_root)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.04, 0.06, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_root.add_child(center)
	var panel := ThangkaPanel.new(true, 14, 14)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	var title := UI.label("PAUSED", 3, UI.ORPIMENT, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(title)
	box.add_child(Control.new())
	var labels := ["RESUME", "RESTART", "OPTIONS", "QUIT TO TITLE"]
	for l in labels:
		var b := WButton.new(l)
		b.custom_minimum_size = Vector2(150, 20)
		box.add_child(b)
		_pause_buttons.append(b)
	_pause_buttons[0].pressed.connect(func() -> void: _set_paused(false))
	_pause_buttons[1].pressed.connect(_restart)
	_pause_buttons[2].pressed.connect(_open_options)
	_pause_buttons[3].pressed.connect(_quit_to_title)


func _set_paused(on: bool) -> void:
	if on == _paused:
		return
	_paused = on
	_pause_root.visible = on
	if _options != null:
		_options.queue_free()
		_options = null
	get_tree().paused = on
	if on:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		_take_pointer()
	Sfx.duck(on)
	if race != null and is_instance_valid(race):
		race.set("paused_for_ui", on)
	if on:
		Sfx.stop_loops()
		Sfx.play("ui_ok", -4.0)
		_pause_buttons[0].grab_focus.call_deferred()


func _restart() -> void:
	_set_paused(false)
	Game.start_race()


func _quit_to_title() -> void:
	_set_paused(false)
	Game.go("title")


func _open_options() -> void:
	if _options != null:
		return
	_options = OptionsPanel.new()
	_options.set("embedded", true)
	_options.connect("closed", func() -> void:
		_options.queue_free()
		_options = null
		_pause_buttons[2].grab_focus.call_deferred())
	_pause_root.add_child(_options)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if _paused and _options == null:
			get_viewport().set_input_as_handled()
			_set_paused(false)
		elif not _paused and not _finished and race != null:
			get_viewport().set_input_as_handled()
			_set_paused(true)


# ------------------------------------------------------------------ painting

func _short_name(s: String, max_w: float) -> String:
	var n := s.to_upper()
	if UI.text_width(n) <= max_w:
		return n
	var words := n.split(" ")
	if words.size() >= 2:
		var two := "%s %s" % [words[0], words[1]]
		if UI.text_width(two) <= max_w:
			return two
	return words[0]


func paint(c: Control) -> void:
	if race == null:
		return
	var w := c.size.x
	var h := c.size.y
	if _vignette > 0.01:
		c.draw_rect(Rect2(0, 0, w, h), Color(0.09, 0.07, 0.1, 0.38 * _vignette))
	_paint_player_plate(c)
	_paint_rival_plate(c, w)
	_paint_subtitle(c, w)
	_paint_place(c, w)
	_paint_equipment(c, w, h)
	_paint_speed(c, w, h)
	_paint_chevrons(c, w, h)
	_paint_quiet(c, w)
	_paint_rest(c, w, h)
	_paint_announcements(c, w, h)
	_paint_countdown(c, w, h)
	_paint_sight(c, w, h)


func _flash(rate: float = 6.0) -> bool:
	return fmod(_t * rate, 2.0) < 1.0


func _bar_row(c: Control, x: float, y: float, label: String, label_w: float, bar_w: float, frac: float, col: Color, label_col: Color = UI.CONCH, trail: float = -1.0) -> void:
	UI.text(c, Vector2(x, y), label, 1, label_col, false)
	UI.bar(c, Rect2(x + label_w, y + 1, bar_w, 8), frac, col, UI.SOOT, trail)


func _paint_player_plate(c: Control) -> void:
	var r := Rect2(4, 4, PLATE_W, 64)
	UI.draw_panel(c, r, true, Color(UI.INK, 0.88), 3)
	if _hurt > 0.0:
		UI.rect_frame(c, r, UI.VERMILION if _flash(16.0) else UI.CONCH, 2.0)
	var p := _p
	var x := r.position.x + 9
	var y := r.position.y + 10
	var hp := float(_g(p, "health", 100.0)) / maxf(float(_g(p, "max_health", 100.0)), 1.0)
	var shake := float(_g(p, "shake", 0.0))
	var stam := float(_g(p, "stamina", 100.0)) / maxf(float(_g(p, "max_stamina", 100.0)), 1.0)
	var label_w := 58.0
	var bar_w := r.size.x - 18.0 - label_w
	_bar_row(c, x, y, "HEALTH", label_w, bar_w, hp, UI.VERMILION, UI.CONCH, _trail_hp)
	var teeter := shake > 70.0
	var shake_col := UI.CONCH if (teeter and _flash()) else UI.SAFFRON
	_bar_row(c, x, y + 11, "SHAKE", label_w, bar_w, shake / 100.0, shake_col, UI.ORPIMENT if teeter else UI.CONCH)
	_bar_row(c, x, y + 22, "STAMINA", label_w, bar_w, stam, UI.MALACHITE)
	var lungta := float(_g(p, "lungta", 0.0))
	var full := lungta >= 4.99
	UI.draw_flags(c, Vector2(x, y + 36), lungta, full and _flash(8.0))
	var name := str(_g(p, "display_name", Game.player_id)).to_upper()
	UI.text(c, Vector2(x + 68, y + 37), _short_name(name, 74.0), 1, UI.CONCH)
	var wy := r.end.y + 4.0
	if teeter:
		UI.text(c, Vector2(r.position.x + 2, wy), "TEETERING!", 1, UI.VERMILION if _flash() else UI.ORPIMENT)
		wy += 13.0
	if full:
		UI.text(c, Vector2(r.position.x + 2, wy), "SECOND WIND!", 1, UI.ORPIMENT if _flash(5.0) else UI.CONCH)
		UI.text(c, Vector2(r.position.x + 2, wy + 12), "PRESS ENTER", 1, UI.BONE)


func _paint_rival_plate(c: Control, w: float) -> void:
	if _rival == null or _rival_slide <= 0.0:
		return
	var rw := 178.0
	var ease_v := 1.0 - pow(1.0 - _rival_slide, 3.0)
	var rr := Rect2(w - rw - 4 + (1.0 - ease_v) * (rw + 12), 4, rw, 68)
	UI.draw_panel(c, rr, true, Color(UI.INK, 0.88), 3)
	var rv := _rival
	var px := rr.position.x + 9
	var py := rr.position.y + 9
	var path := str(_g(rv, "portrait", ""))
	var tex: Texture2D = UI.texture(path)
	var box := Rect2(px, py, 48, 48)
	c.draw_rect(Rect2(box.position - Vector2(1, 1), box.size + Vector2(2, 2)), UI.INK)
	if tex != null:
		c.draw_texture_rect(tex, box, false)
	else:
		c.draw_rect(box, UI.CHARCOAL)
		UI.text_c(c, box.position.x + 17, box.position.y + 11, "?", 1, UI.ASH, false)
	UI.rect_frame(c, Rect2(box.position - Vector2(1, 1), box.size + Vector2(2, 2)), UI.GOLD, 1.0)
	if _is_bet_rival(rv):
		var coin := UI.icon("coin")
		if coin != null:
			c.draw_texture(coin, box.end - Vector2(12, 12))
	var tx := px + 56
	UI.text(c, Vector2(tx, py), _short_name(str(_g(rv, "display_name", "RIVAL")), rr.end.x - tx - 9), 1, UI.CONCH)
	var hp := float(_g(rv, "health", 100.0)) / maxf(float(_g(rv, "max_health", 100.0)), 1.0)
	UI.text(c, Vector2(tx, py + 13), "HEALTH", 1, UI.ASH, false)
	UI.bar(c, Rect2(tx, py + 23, rr.end.x - tx - 9, 7), hp, UI.VERMILION)
	UI.text(c, Vector2(tx, py + 31), "SHAKE", 1, UI.ASH, false)
	var sh := float(_g(rv, "shake", 0.0))
	UI.bar(c, Rect2(tx, py + 41, rr.end.x - tx - 9, 7), sh / 100.0, UI.CONCH if (sh > 70.0 and _flash()) else UI.SAFFRON)


## True for the rider the player has a side bet with.
func _is_bet_rival(r: Object) -> bool:
	return Game.wager > 0 and Game.wager_rival != "" and str(_g(r, "rival_id", "")) == Game.wager_rival


## The strip under the rival plate: who spoke, what they said and, for Tibetan, what it means. It slides in from the right,
## takes the plate's place if no rival is near, and goes before the player's rider or the place counter could be covered.
func _paint_subtitle(c: Control, w: float) -> void:
	if _sub.is_empty():
		return
	var age := float(_sub["age"])
	var life := float(_sub["life"])
	var slide := minf(minf(age / SUB_SLIDE, 1.0), clampf((life - age) / SUB_SLIDE, 0.0, 1.0))
	var ease_v := 1.0 - pow(1.0 - slide, 3.0)
	var plate_ease := 1.0 - pow(1.0 - _rival_slide, 3.0)
	var r := Rect2(w - SUB_W - 4.0 + (1.0 - ease_v) * (SUB_W + 12.0), lerpf(4.0, 76.0, plate_ease), SUB_W, float(_sub["h"]))
	UI.draw_panel(c, r, true, Color(UI.INK, 0.78), 3)
	var x0 := r.position.x + SUB_PAD
	var y0 := r.position.y + 9.0
	var text_x := x0
	if bool(_sub["portrait"]):
		var box := Rect2(x0, y0, SUB_PORTRAIT, SUB_PORTRAIT)
		c.draw_rect(box.grow(1.0), UI.INK)
		var tex: Texture2D = _sub["tex"]
		if tex != null:
			c.draw_texture_rect(tex, box, false)
		else:
			c.draw_rect(box, UI.CHARCOAL)
			UI.text_c(c, box.position.x + 12.0, box.position.y + 6.0, str(_sub["initial"]), 1, UI.ASH, false)
		UI.rect_frame(c, box.grow(1.0), UI.GOLD, 1.0)
		text_x = x0 + SUB_SIDE
	var rows: Array = _sub["rows"]
	for i in rows.size():
		var row: Dictionary = rows[i]
		var below := bool(_sub["portrait"]) and i >= 2
		UI.text(c, Vector2(x0 if below else text_x, y0 + i * 12.0 + (SUB_DROP if below else 0.0)), str(row["s"]), 1, row["c"], false)


func _place_of_player() -> int:
	var place := int(_g(_p, "place", 0))
	if place <= 0 and race != null and race.has_method("standings"):
		var order: Variant = race.call("standings")
		if order is Array:
			for i in (order as Array).size():
				if (order as Array)[i] == _p:
					return i + 1
	return maxi(place, 1)


func _paint_place(c: Control, w: float) -> void:
	var total := maxi(_riders.size(), 1)
	var place := _place_of_player()
	var col := UI.ORPIMENT if place == 1 else (UI.CONCH if place <= 3 else UI.ROSE)
	# Sits on its own plate: the sky behind it can be any colour, and it must always read.
	var place_text := "%s/%d" % [UI.ordinal(place), total]
	var plate_w := UI.text_width(place_text, 2) + 12.0
	var plate := Rect2(w * 0.5 - plate_w * 0.5, 0.0, plate_w, 23.0)
	c.draw_rect(plate, UI.INK)
	c.draw_rect(Rect2(plate.position.x, plate.end.y - 1.0, plate.size.x, 1.0), UI.ORPIMENT)
	UI.text_c(c, w * 0.5, 2, place_text, 2, col)
	# Progress thread: every rider a dot, the player in gold.
	var tw := 190.0
	var tx := w * 0.5 - tw * 0.5
	var ty := 29.0
	c.draw_rect(Rect2(tx - 1, ty, tw + 2, 5), UI.INK)
	c.draw_rect(Rect2(tx, ty + 2, tw, 1), UI.BONE)
	c.draw_rect(Rect2(tx - 3, ty - 1, 3, 7), UI.CONCH)
	c.draw_rect(Rect2(tx + tw, ty - 1, 3, 7), UI.VERMILION)
	for r: Variant in _riders:
		if not (r is Object) or r == _p or not is_instance_valid(r as Object):
			continue
		var f := clampf(float(_g(r as Object, "s", 0.0)) / _length, 0.0, 1.0)
		if _is_bet_rival(r as Object):   # the one you have a wager with: a red bead, drawn over the rest
			continue
		c.draw_rect(Rect2(tx + f * tw - 2, ty, 4, 5), UI.INK)
		c.draw_rect(Rect2(tx + f * tw - 1, ty + 1, 2, 3), UI.ASH)
	for r: Variant in _riders:
		if r is Object and r != _p and is_instance_valid(r as Object) and _is_bet_rival(r as Object):
			var fb := clampf(float(_g(r as Object, "s", 0.0)) / _length, 0.0, 1.0)
			c.draw_rect(Rect2(tx + fb * tw - 3, ty - 2, 6, 9), UI.INK)
			c.draw_rect(Rect2(tx + fb * tw - 2, ty - 1, 4, 7), UI.VERMILION)
	if _p != null:
		var fp := clampf(float(_g(_p, "s", 0.0)) / _length, 0.0, 1.0)
		c.draw_rect(Rect2(tx + fp * tw - 3, ty - 2, 6, 9), UI.INK)
		c.draw_rect(Rect2(tx + fp * tw - 2, ty - 1, 4, 7), UI.ORPIMENT)


func _weapon_name(id: String) -> String:
	if id == "":
		return ""
	if not _wname_cache.has(id):
		_wname_cache[id] = str(Game.weapon(id).get("name", id)).to_upper()
	return _wname_cache[id]


func _paint_equipment(c: Control, w: float, h: float) -> void:
	var pw := 232.0
	var r := Rect2(w * 0.5 - pw * 0.5, h - 33, pw, 29)
	UI.draw_panel(c, r, false, Color(UI.INK, 0.86))
	var wid := str(_g(_p, "weapon_id", Game.weapon_id))
	var rid := str(_g(_p, "ranged_id", Game.ranged_id))
	var x := r.position.x + 7
	var y := r.position.y + 6
	var ic := UI.icon(wid if wid != "" else "fists")
	if ic != null:
		c.draw_texture(ic, Vector2(x, y))
	UI.text(c, Vector2(x + 19, y + 3), _weapon_name(wid if wid != "" else "fists"), 1, UI.CONCH, false)
	var x2 := r.position.x + 128
	c.draw_rect(Rect2(x2 - 6, r.position.y + 5, 1, 19), UI.CHARCOAL)
	if rid != "":
		var ric := UI.icon(rid)
		if ric != null:
			c.draw_texture(ric, Vector2(x2, y))
		var ammo := int(_g(_p, "ammo", 0))
		var drawing := bool(_g(_p, "drawing", false))
		var ammo_text := "x%d" % ammo
		if rid == "roped_spear":
			ammo_text = ""
		UI.text(c, Vector2(x2 + 19, y + 3), ammo_text, 1, UI.ORPIMENT if drawing else UI.CONCH, false)
		if drawing:
			var da := clampf(float(_g(_p, "draw_amount", 0.0)), 0.0, 1.0)
			UI.bar(c, Rect2(x2 + 19, y + 14, 34, 4), da, UI.ORPIMENT)
	else:
		UI.text(c, Vector2(x2 + 19, y + 3), "NONE", 1, UI.SLATE, false)
	var x3 := r.end.x - 26
	c.draw_rect(Rect2(x3 - 6, r.position.y + 5, 1, 19), UI.CHARCOAL)
	var sh := UI.icon("shield")
	var has_shield := bool(_g(_p, "has_shield", Game.has_shield))
	if sh != null:
		var mod := Color(1, 1, 1, 1.0) if has_shield else Color(1, 1, 1, 0.22)
		c.draw_texture(sh, Vector2(x3, y), mod)
	if bool(_g(_p, "blocking", false)):
		UI.rect_frame(c, Rect2(x3 - 2, y - 2, 20, 20), UI.ORPIMENT, 1.0)


## Speed in km/h, the horse's gait, and how far into a wind trail the rider is.
func _paint_speed(c: Control, w: float, h: float) -> void:
	if _p == null:
		return
	var r := Rect2(w - 94.0, h - 47.0, 90.0, 43.0)
	UI.draw_panel(c, r, false, Color(UI.INK, 0.86))
	var state := str(_g(_p, "state", "ride"))
	var riding := state == "ride" or state == "airborne" or state == "finished"
	var kmh := roundi(float(_g(_p, "speed", 0.0)) * 3.6) if riding else 0
	var whip := bool(_g(_p, "whip_on", false))
	var digits := str(kmh)
	var dx := r.end.x - 41.0 - UI.text_width(digits, 2)
	UI.text(c, Vector2(dx, r.position.y + 3.0), digits, 2, UI.ORPIMENT if whip else UI.CONCH, false)
	UI.text(c, Vector2(r.end.x - 36.0, r.position.y + 12.0), "KM/H", 1, UI.BONE, false)
	if riding and _p.has_method("gait"):
		UI.text_c(c, r.position.x + r.size.x * 0.5, r.position.y + 23.0, str(_p.call("gait")).to_upper(), 1, UI.SLATE, false)
	var draft := clampf(float(_g(_p, "draft", 0.0)), 0.0, 1.0) if riding else 0.0
	UI.bar(c, Rect2(r.position.x + 7.0, r.position.y + 35.0, r.size.x - 14.0, 4.0), draft, UI.TURQUOISE)
	if draft > 0.5 and riding:
		UI.text_c(c, w * 0.5, h - 46.0, "IN THE WIND TRAIL", 1, UI.CONCH if draft > 0.75 else UI.TURQUOISE, true)
	# just slammed someone: hit them now and it lands harder
	if float(_g(_p, "shoved_t", 0.0)) > 0.0 and riding:
		var shoved: Object = _g(_p, "shoved", null) as Object
		if shoved != null and bool(shoved.call("is_riding")):
			UI.text_c(c, w * 0.5, h - 59.0, "HIT THEM NOW  x%.1f" % Race.SLAM_DAMAGE, 1, UI.ORPIMENT if _flash(8.0) else UI.CONCH, true)


## The sight for a ranged weapon. It goes where the mouse goes, nothing aims for you. While a shot is drawn it closes up as
## the draw comes on, and the marks below it show where a shot will really fall at 15, 30 and 45 metres: put the right mark on
## the target, or just aim above it. It flashes when a shot lands.
func _paint_sight(c: Control, w: float, h: float) -> void:
	if _p == null or race == null:
		return
	var rid := str(_g(_p, "ranged_id", ""))
	var state := str(_g(_p, "state", "ride"))
	if rid == "" or int(_g(_p, "ammo", 0)) == 0 or (state != "ride" and state != "airborne"):
		return
	var at := (_g(race, "aim_screen", Vector2(0.5, 0.4)) as Vector2) * Vector2(w, h)
	var drawing := bool(_g(_p, "drawing", false))
	var draw := clampf(float(_g(_p, "draw_amount", 0.0)), 0.0, 1.0)
	var col := UI.CONCH if not drawing else (UI.ORPIMENT if draw >= 1.0 else UI.CONCH)
	var a := 1.0 if drawing else 0.45
	if _sight_hit > 0.0:
		col = UI.VERMILION
		a = 1.0
		var out := 4.0 + 5.0 * _sight_hit / SIGHT_HIT_TIME
		for sx: float in [-1.0, 1.0]:
			for sy: float in [-1.0, 1.0]:
				_sight_line(c, at + Vector2(sx, sy) * out, at + Vector2(sx, sy) * (out + 4.0), col, a)
	var gap := lerpf(12.0, 3.0, draw) if drawing else 7.0
	var tick := 6.0
	c.draw_rect(Rect2(at - Vector2(2.0, 2.0), Vector2(4.0, 4.0)), Color(UI.INK, 0.75 * a))
	c.draw_rect(Rect2(at - Vector2(1.0, 1.0), Vector2(2.0, 2.0)), Color(col, a))
	_sight_line(c, at + Vector2(-gap - tick, 0.0), at + Vector2(-gap, 0.0), col, a)
	_sight_line(c, at + Vector2(gap, 0.0), at + Vector2(gap + tick, 0.0), col, a)
	_sight_line(c, at + Vector2(0.0, -gap - tick), at + Vector2(0.0, -gap), col, a)
	if not drawing:
		_sight_line(c, at + Vector2(0.0, gap), at + Vector2(0.0, gap + tick), col, a)
		return
	# the drop at each range, for the launch speed this draw would give right now
	var muzzle: float = Race.launch_speed(rid, draw)
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var px_per_tan := h * 0.5 / tan(deg_to_rad(cam.fov * 0.5))
	var reach := float(Game.weapon(rid).get("reach", 45.0))
	var bottom := at.y
	for i in 3:
		var range_m := 15.0 * float(i + 1)
		if range_m > reach + 3.0:
			break
		var t := range_m / muzzle
		var drop := 0.5 * Projectile.GRAVITY * t * t
		var y := at.y + drop / (range_m + 6.0) * px_per_tan
		y = maxf(y, bottom + 3.0)
		bottom = y
		var half := 5.0 - float(i)
		_sight_line(c, Vector2(at.x - half, y), Vector2(at.x + half, y), col, a)
	_sight_line(c, at + Vector2(0.0, gap), Vector2(at.x, bottom), col, 0.55)


func _sight_line(c: Control, from: Vector2, to: Vector2, col: Color, alpha: float) -> void:
	c.draw_line(from, to, Color(UI.INK, 0.75 * alpha), 3.0)
	c.draw_line(from, to, Color(col, alpha), 1.0)


func _chevron(c: Control, x: float, y: float, dir: float, n: int, col: Color) -> void:
	for i in n:
		var ox := x + dir * i * 4.0 - (4.0 if dir < 0.0 else 0.0)
		for yy: float in [y + i * 3.0, y + (2.0 * (n - 1) - i) * 3.0]:
			c.draw_rect(Rect2(ox - 1, yy - 1, 6, 5), UI.INK)
		for yy: float in [y + i * 3.0, y + (2.0 * (n - 1) - i) * 3.0]:
			c.draw_rect(Rect2(ox, yy, 4, 3), col)


## Arrows on the screen edge when someone is close behind and to one side.
func _paint_chevrons(c: Control, w: float, h: float) -> void:
	if _p == null:
		return
	var ps := float(_g(_p, "s", 0.0))
	var pd := float(_g(_p, "d", 0.0))
	var left := 0.0
	var right := 0.0
	for r: Variant in _riders:
		if not (r is Object) or r == _p or not is_instance_valid(r as Object):
			continue
		var ds := float(_g(r as Object, "s", 0.0)) - ps
		if ds > 0.5 or ds < -CHEVRON_RANGE:
			continue
		var dd := float(_g(r as Object, "d", 0.0)) - pd
		if absf(dd) > 7.0:
			continue
		var near := 1.0 - clampf(-ds / CHEVRON_RANGE, 0.0, 1.0)
		if dd >= 0.0:
			right = maxf(right, near)
		else:
			left = maxf(left, near)
	var y := h * 0.5 - 12.0
	var pulse := 0.65 + 0.35 * sin(_t * 14.0)
	if left > 0.0:
		_chevron(c, 4.0 + 4.0 * pulse, y, 1.0, 3 + int(left * 3.0), Color(UI.VERMILION, 0.55 + 0.45 * left))
	if right > 0.0:
		_chevron(c, w - 4.0 - 4.0 * pulse, y, -1.0, 3 + int(right * 3.0), Color(UI.VERMILION, 0.55 + 0.45 * right))


func _paint_quiet(c: Control, w: float) -> void:
	if _quiet_alpha <= 0.01:
		return
	var s := "QUIET GROUND - HANDS DOWN"
	var tw := UI.text_width(s, 1) + 24.0
	var rect := Rect2(w * 0.5 - tw * 0.5, 40.0, tw, 17.0)
	var a := _quiet_alpha
	c.draw_rect(rect, Color(UI.CONCH, 0.8 * a))
	UI.rect_frame(c, rect, Color(UI.LAPIS, a), 1.0)
	UI.rect_frame(c, Rect2(rect.position + Vector2(2, 2), rect.size - Vector2(4, 4)), Color(UI.TURQUOISE, a), 1.0)
	UI.text_c(c, w * 0.5, rect.position.y + 4, s, 1, UI.LAPIS_DEEP, false, a)


func _paint_rest(c: Control, w: float, h: float) -> void:
	if _p == null:
		return
	var state := str(_g(_p, "state", "ride"))
	if state == "rest":
		UI.text_c(c, w * 0.5, h * 0.17, "RESTING", 2, UI.CONCH)
		var left := float(_g(_p, "rest_left", 0.0))
		UI.text_c(c, w * 0.5, h * 0.24, "%d" % ceili(left), 3, UI.ORPIMENT)
		if _rest_initial >= 5.0:
			var col := UI.ORPIMENT if _flash(5.0) else UI.CONCH
			UI.text_c(c, w * 0.5, h * 0.34, "TAP TO GET UP FASTER", 1, col)
	elif state == "run":
		UI.text_c(c, w * 0.5, h * 0.2, "RUN TO YOUR HORSE!", 1, UI.CONCH)


func _paint_announcements(c: Control, w: float, h: float) -> void:
	var info_y := 60.0
	for a in _announce:
		var age := float(a["age"])
		var life := float(a["life"])
		var fade := clampf((life - age) / 0.25, 0.0, 1.0)
		var text: String = a["text"]
		match str(a["kind"]):
			"big":
				var k := 3
				if bool(a.get("huge", false)):
					k = 5
				if UI.text_width(text, k) > w - 2.0 * (SUB_W + 8.0):     # clear of the subtitle strip
					k = 2
				var col := UI.ORPIMENT
				if text == "1":
					col = UI.VERMILION
				UI.text_c(c, w * 0.5, h * (0.15 if bool(a.get("huge", false)) else 0.2), text, k, col, true, fade)
			"info":
				UI.text_c(c, w * 0.5, info_y, text, 1, UI.CONCH, true, fade)
				info_y += 13.0
			_:
				# Up in the sky above the road, where it doesn't cover the riders or the sight.
				var k := 2
				var col := UI.ORPIMENT if str(a["kind"]) == "good" else UI.VERMILION
				var tw := UI.text_width(text, k)
				if tw > w - 80.0:   # a long readout is made smaller, not cut off
					k = 1
					tw = UI.text_width(text, k)
				var pos := Vector2(clampf(w * 0.5 + float(a["dx"]), minf(tw * 0.5 + 8.0, w * 0.5), maxf(w - tw * 0.5 - 8.0, w * 0.5)), h * 0.27 + float(a["dy"]))
				c.draw_set_transform(pos, float(a["tilt"]), Vector2.ONE)
				UI.text(c, Vector2(-tw * 0.5, -BASE_HALF * k), text, k, col, true, fade)
				c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _paint_countdown(c: Control, w: float, h: float) -> void:
	var cd := float(_g(race, "countdown", 0.0))
	if cd > 0.0 or (_started and _hint_age < 4.0):
		var hint := "A D STEER    W S SPEED    SHIFT WHIP    SPACE LEAP    J L STRIKE    I SHIELD    ESC PAUSE"
		var fade := 1.0 if cd > 0.0 else clampf(4.0 - _hint_age, 0.0, 1.0)
		UI.text_c(c, w * 0.5, h - 54, hint, 1, UI.CONCH, true, fade)
		if str(_g(_p, "ranged_id", "")) != "":
			UI.text_c(c, w * 0.5, h - 67, "MOUSE AIMS    HOLD RIGHT BUTTON TO DRAW, LET GO TO LOOSE    AIM ABOVE A FAR TARGET", 1, UI.ORPIMENT, true, fade)
