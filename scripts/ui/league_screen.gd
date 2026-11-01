class_name LeagueScreen
extends Screen
## The Season: five courses, which you have cleared, your silver, and the way to the Stable.

var _rows: Array[WButton] = []
var _detail: Control
var _focus_course := 0
var _modal: Control


func build() -> void:
	Sfx.music("menu")
	var bd := Backdrop.new(1.9, 0.5)
	add_child(bd)
	move_child(bd, 0)
	Game.check_loan()
	var season_name: String = StoryText.SEASON_NAMES[clampi(Game.season, 0, 2)]
	var head := TextArt.new(season_name, 2, UI.ORPIMENT)
	head.position = Vector2(14, 10)
	safe.add_child(head)
	var sub_text := "SEASON %d OF 3    %s" % [Game.season + 1, str(FallbackData.PLAYERS.get(Game.player_id, {}).get("name", "RIDER"))]
	if Game.finished_game and Game.season >= 2 and Game.all_qualified():
		sub_text = "CHAMPION OF THE WOOD HORSE YEAR"
	var sub := TextArt.new(sub_text, 1, UI.CONCH)
	sub.position = Vector2(16, 36)
	safe.add_child(sub)

	var board := Control.new()
	board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(board)
	board.draw.connect(func() -> void: _paint(board))

	var box := VBoxContainer.new()
	box.position = Vector2(14, 58)
	box.add_theme_constant_override("separation", 4)
	safe.add_child(box)
	for i in Game.course_count():
		var b := WButton.new("")
		b.custom_minimum_size = Vector2(306, 26)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		box.add_child(b)
		_rows.append(b)
		var info := Game.course_info(i)
		b.text = "%d  %s" % [i + 1, str(info.name)]
		var status := UI.label("", 1, UI.CONCH, HORIZONTAL_ALIGNMENT_RIGHT, false)
		status.name = "Status"
		status.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		status.offset_right = -6
		status.offset_top = 8
		b.add_child(status)
		b.focus_entered.connect(func() -> void:
			_focus_course = i
			board.queue_redraw()
			status.add_theme_color_override("font_color", UI.INK))
		b.focus_exited.connect(func() -> void:
			status.add_theme_color_override("font_color", UI.CONCH))
		b.pressed.connect(func() -> void:
			Game.course_index = i
			Game.go("prerace"))
		_set_status(status, i)
		b.snap_in(0.08 + 0.05 * i)

	var stable := WButton.new("STABLE")
	stable.custom_minimum_size = Vector2(98, 22)
	stable.position = Vector2(14, 292)
	stable.pressed.connect(func() -> void: Game.go("stable"))
	safe.add_child(stable)
	var title := WButton.new("TITLE")
	title.custom_minimum_size = Vector2(98, 22)
	title.position = Vector2(120, 292)
	title.pressed.connect(func() -> void: Game.go("title"))
	safe.add_child(title)
	var hint := TextArt.new(UI.hint("SELECT", "TITLE"), 1, UI.BONE)
	hint.position = Vector2(16, 326)
	safe.add_child(hint)
	for b in [stable, title]:
		b.focus_entered.connect(board.queue_redraw)
	_focus_course = Game.next_course()
	focus_later(_rows[_focus_course])
	if Game.loan_notice:
		Game.loan_notice = false
		_show_note("AUNT AMA CHOEKYI LENDS YOU %d SRANG. SHE WILL MENTION IT." % Game.LOAN_AMOUNT)


func _set_status(l: Label, i: int) -> void:
	if Game.qualified[i]:
		l.text = "CLEARED"
		l.add_theme_color_override("font_color", UI.MALACHITE.lightened(0.25))
	elif i == Game.next_course():
		l.text = "NEXT"
		l.add_theme_color_override("font_color", UI.ORPIMENT)
	elif Game.is_final(Game.season, i):
		l.text = "FINAL"
		l.add_theme_color_override("font_color", UI.ROSE)
	else:
		l.text = ""


func _paint(c: Control) -> void:
	# money plate, top right
	var plate := Rect2(448, 8, 178, 30)
	UI.draw_panel(c, plate, false)
	var coin := UI.icon("coin")
	if coin != null:
		c.draw_texture(coin, Vector2(plate.position.x + 8, plate.position.y + 7))
	UI.text_r(c, plate.end.x - 9, plate.position.y + 10, UI.srang(Game.money), 1, UI.ORPIMENT, false)
	# progress flags
	UI.text(c, Vector2(16, 214), "CLEARED %d OF 5" % Game.qualified_count(), 1, UI.BONE)
	UI.draw_flags(c, Vector2(18, 232), float(Game.qualified_count()))
	# equipment line
	var hname := str(Game.horse(Game.horse_id).get("name", ""))
	var wname := str(Game.weapon(Game.weapon_id).get("name", ""))
	UI.text(c, Vector2(150, 214), "HORSE   %s" % hname, 1, UI.BONE)
	UI.text(c, Vector2(150, 227), "WEAPON  %s" % wname, 1, UI.BONE)
	var rname := str(Game.weapon(Game.ranged_id).get("name", "")) if Game.ranged_id != "" else "NONE"
	UI.text(c, Vector2(150, 240), "RANGED  %s" % rname, 1, UI.BONE)
	UI.text(c, Vector2(150, 253), "SHIELD  %s" % ("YES" if Game.has_shield else "NO"), 1, UI.BONE)


func _wrap(c: Control, text: String, pos: Vector2, width: float, color: Color) -> void:
	var words := text.split(" ")
	var line := ""
	var y := pos.y
	for w in words:
		var test := w if line == "" else line + " " + w
		if UI.text_width(test) > width:
			UI.text(c, Vector2(pos.x, y), line, 1, color, false)
			y += 13.0
			line = w
		else:
			line = test
	if line != "":
		UI.text(c, Vector2(pos.x, y), line, 1, color, false)


func _show_note(message: String) -> void:
	var m := Control.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.04, 0.06, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.add_child(center)
	var panel := ThangkaPanel.new(true, 14, 14)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	box.add_child(UI.wrapped(message, 250.0, 1, UI.CONCH))
	var ok := WButton.new("OK")
	ok.custom_minimum_size = Vector2(100, 20)
	box.add_child(ok)
	add_child(m)
	_modal = m
	ok.pressed.connect(func() -> void:
		m.queue_free()
		_modal = null
		_rows[_focus_course].grab_focus.call_deferred())
	ok.grab_focus.call_deferred()


func back() -> void:
	if _modal == null:
		Game.go("title")
