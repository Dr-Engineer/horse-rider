class_name StableScreen
extends Screen
## Buy and fit horses, weapons and tack. Stats are always shown against what you have now.

const TABS: Array[String] = ["HORSES", "MELEE", "RANGED", "TACK"]
const BONUS_COLOR := Color("5fd6a8")

var _tab := 0
var _sel := 0
var _items: Array[Dictionary] = []
var _rows: Array[WButton] = []
var _tabs: Array[WButton] = []
var _list: VBoxContainer
var _board: Control
var _msg := ""
var _msg_t := 0.0
var _msg_bad := false
var _preview: HorsePreview


func build() -> void:
	Sfx.music("menu")
	var bd := Backdrop.new(4.4, 0.42)
	add_child(bd)
	move_child(bd, 0)
	var head := TextArt.new("THE STABLE", 2, UI.ORPIMENT)
	head.position = Vector2(14, 8)
	safe.add_child(head)
	_board = Control.new()
	_board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(_board)
	_board.draw.connect(_paint)
	var x := 14.0
	for i in TABS.size():
		var b := WButton.new(TABS[i])
		b.custom_minimum_size = Vector2(76, 20)
		b.position = Vector2(x, 36)
		x += 80.0
		safe.add_child(b)
		_tabs.append(b)
		b.focus_entered.connect(func() -> void: _set_tab(i))
		b.pressed.connect(func() -> void:
			if _rows.size() > 0:
				_rows[0].grab_focus())
	_list = VBox_new()
	safe.add_child(_list)
	var back_btn := WButton.new("BACK")
	back_btn.custom_minimum_size = Vector2(98, 22)
	back_btn.position = Vector2(14, 326)
	back_btn.pressed.connect(back)
	safe.add_child(back_btn)
	_preview = HorsePreview.new(200, 130)
	_preview.position = Vector2(14, 184)
	safe.add_child(_preview)
	_set_tab(0, true)
	focus_later(_tabs[0])


func VBox_new() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.position = Vector2(14, 62)
	v.add_theme_constant_override("separation", 2)
	return v


func _owned_horse(id: String) -> bool:
	return Game.owned_horses.has(id)


func _make_items() -> void:
	_items.clear()
	match _tab:
		0:
			for id in Game.stable_horse_ids():
				var h := Game.horse(id)
				_items.append({"kind": "horse", "id": id, "name": str(h.name), "cost": int(h.get("cost", 0)), "owned": _owned_horse(id), "equipped": Game.horse_id == id})
		1:
			var ids: Array[String] = ["fists"]
			var melee := Game.weapon_ids("melee")
			melee.sort_custom(func(a: String, b: String) -> bool: return int(Game.weapon(a).get("cost", 0)) < int(Game.weapon(b).get("cost", 0)))
			ids.append_array(melee)
			for id in ids:
				var w := Game.weapon(id)
				_items.append({"kind": "melee", "id": id, "name": str(w.name), "cost": int(w.get("cost", 0)), "owned": Game.owned_weapons.has(id) or id == "fists", "equipped": Game.weapon_id == id})
		2:
			_items.append({"kind": "ranged", "id": "", "name": "NO RANGED WEAPON", "cost": 0, "owned": true, "equipped": Game.ranged_id == ""})
			var ranged := Game.weapon_ids("ranged")
			ranged.sort_custom(func(a: String, b: String) -> bool: return int(Game.weapon(a).get("cost", 0)) < int(Game.weapon(b).get("cost", 0)))
			for id in ranged:
				var w2 := Game.weapon(id)
				_items.append({"kind": "ranged", "id": id, "name": str(w2.name), "cost": int(w2.get("cost", 0)), "owned": Game.owned_weapons.has(id), "equipped": Game.ranged_id == id})
		3:
			var sh: Variant = Game.gd_const("SHIELD", null)
			var sh_cost := int(FallbackData.SHIELD.cost)
			if sh is Dictionary:
				sh_cost = int((sh as Dictionary).get("cost", sh_cost))
			_items.append({"kind": "shield", "id": "shield", "name": "ROUND SHIELD", "cost": sh_cost, "owned": Game.has_shield, "equipped": Game.has_shield, "desc": str(FallbackData.SHIELD.desc)})
			var sad := Game.saddles()
			for i in sad.size():
				var s: Dictionary = sad[i]
				_items.append({"kind": "saddle", "level": i, "name": str(s.get("name", "SADDLE")).to_upper(), "cost": int(s.get("cost", 0)), "owned": i <= Game.saddle_level, "equipped": i == Game.saddle_level, "desc": str(FallbackData.SADDLES[mini(i, 2)].desc), "cut": float(s.get("impact_cut", 0.0))})
			var arm := Game.armors()
			for i in arm.size():
				var a: Dictionary = arm[i]
				_items.append({"kind": "armor", "level": i, "name": str(a.get("name", "ARMOUR")).to_upper(), "cost": int(a.get("cost", 0)), "owned": i <= Game.armor_level, "equipped": i == Game.armor_level, "desc": str(FallbackData.ARMOR[mini(i, 2)].desc), "health": float(a.get("health", 0.0))})


func _set_tab(i: int, force: bool = false) -> void:
	if i == _tab and not force:
		return
	_tab = i
	_sel = 0
	_preview.visible = i == 0
	_rebuild()


func _rebuild(keep_focus: int = -1) -> void:
	_make_items()
	for r in _rows:
		r.queue_free()
	_rows.clear()
	for i in _items.size():
		var it: Dictionary = _items[i]
		var b := WButton.new(str(it.name))
		b.custom_minimum_size = Vector2(306, 20)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_list.add_child(b)
		_rows.append(b)
		var tag := UI.label("", 1, UI.CONCH, HORIZONTAL_ALIGNMENT_RIGHT, false)
		tag.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tag.offset_right = -6
		tag.offset_top = 5
		b.add_child(tag)
		_style_tag(tag, it)
		b.quiet_first_focus = true
		b.focus_entered.connect(func() -> void:
			_sel = i
			tag.add_theme_color_override("font_color", UI.INK)
			_update_preview()
			_board.queue_redraw())
		b.focus_exited.connect(func() -> void: _style_tag(tag, it))
		b.pressed.connect(func() -> void: _activate(i))
	if keep_focus >= 0 and keep_focus < _rows.size():
		_rows[keep_focus].grab_focus.call_deferred()
		_sel = keep_focus
	_update_preview()
	_board.queue_redraw()


func _update_preview() -> void:
	if _tab != 0 or _sel >= _items.size():
		return
	var h := Game.horse(str(_items[_sel].id))
	var pdata: Variant = Game.gd_const("PLAYERS", {})
	var entry: Dictionary = {}
	if pdata is Dictionary and (pdata as Dictionary).has(Game.player_id):
		entry = (pdata as Dictionary)[Game.player_id]
	_preview.show_horse(h, entry.get("wardrobe", ["body_chuba", "head_young", "hair_wound"]), entry.get("slot_a", Color("7a1c22")), entry.get("slot_b", Color("f2b632")))


func _style_tag(tag: Label, it: Dictionary) -> void:
	if bool(it.equipped):
		tag.text = "EQUIPPED"
		tag.add_theme_color_override("font_color", BONUS_COLOR)
	elif bool(it.owned):
		tag.text = "OWNED"
		tag.add_theme_color_override("font_color", UI.BONE)
	else:
		tag.text = "%d" % int(it.cost)
		tag.add_theme_color_override("font_color", UI.ORPIMENT if int(it.cost) <= Game.money else UI.ROSE)
	tag.add_theme_color_override("font_outline_color", UI.INK)


func _say(text: String, bad: bool = false) -> void:
	_msg = text
	_msg_bad = bad
	_msg_t = 2.4
	_board.queue_redraw()


func _activate(i: int) -> void:
	var it: Dictionary = _items[i]
	var kind := str(it.kind)
	if bool(it.equipped) and kind != "ranged":
		_say("ALREADY EQUIPPED.")
		return
	if not bool(it.owned):
		if int(it.cost) > Game.money:
			Sfx.play("ui_back", -2.0)
			_say("NOT ENOUGH SRANG. YOU NEED %d MORE." % (int(it.cost) - Game.money), true)
			return
		Game.add_money(-int(it.cost))
		Sfx.play("coin")
		_say("BOUGHT: %s" % str(it.name))
	else:
		Sfx.play("ui_ok")
		_say("EQUIPPED: %s" % str(it.name))
	match kind:
		"horse":
			if not Game.owned_horses.has(str(it.id)):
				Game.owned_horses.append(str(it.id))
			Game.horse_id = str(it.id)
		"melee":
			if not Game.owned_weapons.has(str(it.id)):
				Game.owned_weapons.append(str(it.id))
			Game.weapon_id = str(it.id)
		"ranged":
			if str(it.id) != "" and not Game.owned_weapons.has(str(it.id)):
				Game.owned_weapons.append(str(it.id))
			Game.ranged_id = str(it.id)
		"shield":
			Game.has_shield = true
		"saddle":
			Game.saddle_level = int(it.level)
		"armor":
			Game.armor_level = int(it.level)
	Game.save_game()
	_rebuild(i)


func _process(delta: float) -> void:
	if _msg_t > 0.0:
		_msg_t -= delta
		if _msg_t <= 0.0:
			_msg = ""
		_board.queue_redraw()


# ------------------------------------------------------------------ painting

func _bar_line(c: Control, x: float, y: float, label: String, value: float, maxv: float, cur: float, fmt: String, lower_better: bool = false) -> void:
	UI.text(c, Vector2(x, y), label, 1, UI.BONE, false)
	UI.bar(c, Rect2(x + 78, y + 1, 110, 8), value / maxv, UI.OCHRE if value >= cur else UI.CINNABAR)
	UI.text(c, Vector2(x + 194, y), fmt % value, 1, UI.CONCH, false)
	var d := value - cur
	if absf(d) > 0.001:
		var good := (d < 0.0) if lower_better else (d > 0.0)
		var s := ("+" if d > 0.0 else "") + (fmt % d)
		UI.text_r(c, x + 270, y, s, 1, BONUS_COLOR if good else UI.ROSE, false)


func _paint() -> void:
	var c := _board
	var plate := Rect2(448, 8, 178, 30)
	UI.draw_panel(c, plate, false)
	var coin := UI.icon("coin")
	if coin != null:
		c.draw_texture(coin, Vector2(plate.position.x + 8, plate.position.y + 7))
	UI.text_r(c, plate.end.x - 9, plate.position.y + 10, UI.srang(Game.money), 1, UI.ORPIMENT, false)
	var r := Rect2(332, 62, 294, 252)
	UI.draw_panel(c, r, true)
	if _items.is_empty() or _sel >= _items.size():
		return
	var it: Dictionary = _items[_sel]
	var x := r.position.x + 12
	var y := r.position.y + 14
	UI.text(c, Vector2(x, y), str(it.name), 1, UI.ORPIMENT)
	y += 14
	var kind := str(it.kind)
	var desc := ""
	match kind:
		"horse":
			var h := Game.horse(str(it.id))
			desc = str(h.get("desc", ""))
			var cur := Game.horse(Game.horse_id)
			for pair: Array in [["coat", 12.0], ["mane", 30.0], ["rug", 48.0]]:
				var col: Color = h.get(pair[0], UI.CHARCOAL)
				c.draw_rect(Rect2(r.end.x - 70 + float(pair[1]) - 12, y - 14, 14, 10), UI.INK)
				c.draw_rect(Rect2(r.end.x - 70 + float(pair[1]) - 11, y - 13, 12, 8), col)
			y += 4
			desc = desc.to_upper()
			y = _wrapped(c, desc, x, y, 270.0, UI.CONCH) + 6
			var mx := FallbackData.HORSE_MAX
			_bar_line(c, x, y, "SPEED", float(h.speed), float(mx.speed), float(cur.speed), "%.1f")
			_bar_line(c, x, y + 14, "ACCEL", float(h.accel), float(mx.accel), float(cur.accel), "%.1f")
			_bar_line(c, x, y + 28, "HANDLING", float(h.handling), float(mx.handling), float(cur.handling), "%.1f")
			_bar_line(c, x, y + 42, "STAMINA", float(h.stamina), float(mx.stamina), float(cur.stamina), "%.0f")
			_bar_line(c, x, y + 56, "BULK", float(h.bulk), float(mx.bulk), float(cur.bulk), "%.1f")
			y += 76
			UI.text(c, Vector2(x, y), "BULK SHOVES AND RESISTS SHOVING.", 1, UI.BONE, false)
			y += 14
		"melee", "ranged":
			var w := Game.weapon(str(it.id)) if str(it.id) != "" else {}
			var cur_id := Game.weapon_id if kind == "melee" else Game.ranged_id
			var cur_w := Game.weapon(cur_id) if cur_id != "" else {"damage": 0.0, "impact": 0.0, "reach": 0.0, "swing": 0.0}
			if str(it.id) == "":
				desc = "RIDE WITH FREE HANDS."
				y = _wrapped(c, desc, x, y + 4, 270.0, UI.CONCH) + 6
			else:
				desc = str(w.get("desc", "")).to_upper()
				y = _wrapped(c, desc, x, y + 4, 270.0, UI.CONCH) + 6
				var ranged := kind == "ranged"
				var dmax := 15.0 if ranged else 25.2
				var imax := 12.0 if ranged else 38.0
				var rmax := 45.0 if ranged else 4.0
				_bar_line(c, x, y, "DAMAGE", float(w.damage), dmax, float(cur_w.damage), "%.0f")
				_bar_line(c, x, y + 14, "IMPACT", float(w.impact), imax, float(cur_w.impact), "%.0f")
				_bar_line(c, x, y + 28, "REACH M", float(w.reach), rmax, float(cur_w.reach), "%.1f")
				_bar_line(c, x, y + 42, "SWING S", float(w.swing), 1.2, float(cur_w.swing), "%.2f", true)
				y += 62
				if ranged:
					var ammo := int(w.get("ammo", 0))
					UI.text(c, Vector2(x, y), "AMMO %s" % ("PLENTIFUL" if ammo >= 90 else ("NONE NEEDED" if ammo < 0 or str(it.id) == "roped_spear" else str(ammo))), 1, UI.BONE, false)
					y += 13
					UI.text(c, Vector2(x, y), "RANGED NEVER UNSEATS ON ITS OWN.", 1, UI.BONE, false)
					y += 14
				else:
					UI.text(c, Vector2(x, y), "UNDER 1.5 M, KEYS AND SPEARS LOSE HALF.", 1, UI.BONE, false)
					y += 14
			var ic := UI.icon(str(it.id)) if str(it.id) != "" else null
			if ic != null:
				c.draw_texture_rect(ic, Rect2(r.end.x - 52, r.position.y + 10, 32, 32), false)
		"shield":
			y = _wrapped(c, str(it.desc), x, y + 4, 270.0, UI.CONCH) + 8
			var ic2 := UI.icon("shield")
			if ic2 != null:
				c.draw_texture_rect(ic2, Rect2(r.end.x - 52, r.position.y + 10, 32, 32), false)
		"saddle":
			y = _wrapped(c, str(it.desc), x, y + 4, 270.0, UI.CONCH) + 8
			UI.text(c, Vector2(x, y), "IMPACT TAKEN -%d%%" % roundi(float(it.cut) * 100.0), 1, UI.BONE, false)
			y += 14
		"armor":
			y = _wrapped(c, str(it.desc), x, y + 4, 270.0, UI.CONCH) + 8
			UI.text(c, Vector2(x, y), "MAX HEALTH %d" % (100 + roundi(float(it.health))), 1, UI.BONE, false)
			y += 14
	# action line
	var ay := r.end.y - 40
	var status := ""
	var scol := UI.CONCH
	if bool(it.equipped) and kind != "ranged":
		status = "EQUIPPED"
		scol = BONUS_COLOR
	elif bool(it.equipped):
		status = "EQUIPPED"
		scol = BONUS_COLOR
	elif bool(it.owned):
		status = "OWNED - ENTER TO EQUIP"
		scol = UI.ORPIMENT
	elif int(it.cost) <= Game.money:
		status = "ENTER TO BUY FOR %d SRANG" % int(it.cost)
		scol = UI.ORPIMENT
	else:
		status = "COSTS %d SRANG - YOU HAVE %d" % [int(it.cost), Game.money]
		scol = UI.ROSE
	UI.text(c, Vector2(x, ay), status, 1, scol)
	if _msg != "":
		UI.text(c, Vector2(x, ay + 14), _msg, 1, UI.ROSE if _msg_bad else UI.CONCH)


func _wrapped(c: Control, text: String, x: float, y: float, width: float, color: Color) -> float:
	var words := text.split(" ")
	var line := ""
	for w in words:
		var test: String = w if line == "" else line + " " + w
		if UI.text_width(test) > width:
			UI.text(c, Vector2(x, y), line, 1, color, false)
			y += 13.0
			line = w
		else:
			line = test
	if line != "":
		UI.text(c, Vector2(x, y), line, 1, color, false)
		y += 13.0
	return y


func back() -> void:
	Game.go("league")
