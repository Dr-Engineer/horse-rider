class_name ResultsScreen
extends Screen
## Places, prize, bounties, whether you qualified, a word from a rival, and a white scarf for the winner.

var _r: Dictionary = {}
var _board: Control
var _shown := 0
var _clock := 0.0
var _ledger := 0
var _continue: WButton
var _stamp_t := -1.0


func build() -> void:
	Sfx.music("menu")
	var bd := Backdrop.new(3.3, 0.45)
	add_child(bd)
	move_child(bd, 0)
	_r = Game.last_result
	if bool(_r.get("loan", false)):
		Game.loan_notice = false   # the ledger tells you, so the league need not
	_board = Control.new()
	_board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(_board)
	_board.draw.connect(_paint)
	_continue = WButton.new("CONTINUE")
	_continue.custom_minimum_size = Vector2(118, 24)
	_continue.position = Vector2(508, 326)
	_continue.pressed.connect(_next)
	safe.add_child(_continue)
	var title := WButton.new("TITLE")
	title.custom_minimum_size = Vector2(80, 24)
	title.position = Vector2(420, 326)
	title.pressed.connect(func() -> void: Game.go("title"))
	safe.add_child(title)
	_continue.modulate.a = 0.0
	title.modulate.a = 0.0
	_continue.disabled = true
	title.disabled = true
	_continue.set_meta("pair", title)
	if _r.is_empty():
		_shown = 99
		_ledger = 99
		_enable()
	focus_later(_continue)


func _enable() -> void:
	_continue.disabled = false
	(_continue.get_meta("pair") as WButton).disabled = false
	var tw := create_tween()
	tw.tween_property(_continue, "modulate:a", 1.0, 0.15)
	tw.parallel().tween_property(_continue.get_meta("pair"), "modulate:a", 1.0, 0.15)
	_continue.grab_focus()


func _process(delta: float) -> void:
	if _r.is_empty():
		return
	_clock += delta
	var rows: Array = _r.get("rows", [])
	var n := rows.size()
	if _shown < n and _clock > 0.35 + 0.16 * _shown:
		_shown += 1
		Sfx.play("ui_move", -5.0, 0.9 + 0.04 * _shown)
		_board.queue_redraw()
		if _shown == n:
			var good := int(_r.get("place", 9)) <= 3
			Sfx.play("jingle_win" if good else "jingle_lose", -3.0)
	elif _shown >= n and _ledger < 6 and _clock > 0.35 + 0.16 * n + 0.4 + 0.22 * _ledger:
		_ledger += 1
		Sfx.play("coin" if _ledger < 5 else "bell", -6.0)
		_board.queue_redraw()
		if _ledger == 6:
			_stamp_t = 0.0
			_enable()
	if _stamp_t >= 0.0:
		_stamp_t += delta
		_board.queue_redraw()


func _row_name(s: String) -> String:
	var n := s.to_upper()
	return n if n.length() <= 22 else n.substr(0, 22)


func _paint() -> void:
	var c := _board
	UI.text(c, Vector2(14, 10), "RESULTS", 2, UI.ORPIMENT)
	if _r.is_empty():
		UI.text(c, Vector2(14, 60), "NO RACE HAS BEEN RUN YET.", 1, UI.CONCH)
		return
	var info := Game.course_info(int(_r.get("course_index", 0)), int(_r.get("season", 0)))
	UI.text(c, Vector2(16, 36), "%s - %s" % [str(info.name), StoryText.SEASON_NAMES[clampi(int(_r.get("season", 0)), 0, 2)]], 1, UI.CONCH)

	# places
	var rows: Array = _r.get("rows", [])
	var n := rows.size()
	var panel := Rect2(10, 52, 366, 20 + n * 17 + 12)
	UI.draw_panel(c, panel, true)
	var y0 := panel.position.y + 14
	for i in n:
		var row: Dictionary = rows[i]
		if i < n - _shown:
			continue
		var y := y0 + i * 17.0
		var is_me: bool = row["is_player"]
		if is_me:
			c.draw_rect(Rect2(panel.position.x + 6, y - 2, panel.size.x - 12, 15), UI.ORPIMENT)
		var tc := UI.INK if is_me else UI.CONCH
		UI.text(c, Vector2(panel.position.x + 12, y), UI.ordinal(int(row["place"])), 1, tc, false)
		if int(row["place"]) == 1:
			var scarf := UI.icon("scarf")
			if scarf != null:
				c.draw_texture(scarf, Vector2(panel.position.x + 46, y - 4))
		UI.text(c, Vector2(panel.position.x + 66, y), _row_name(str(row["name"])), 1, tc, false)
		var tt := UI.time_text(float(row["time"]))
		UI.text_r(c, panel.end.x - 14, y, tt, 1, tc if is_me else UI.BONE, false)

	# ledger
	var lr := Rect2(388, 52, 242, 156)
	UI.draw_panel(c, lr, true)
	var lines: Array = [
		["PRIZE %s" % UI.ordinal(int(_r.place)) if int(_r.prize) > 0 else "NO PRIZE", "+%d" % int(_r.prize)],
		["KNOCKDOWNS X%d" % int(_r.knockdowns), "+%d" % int(_r.bounty)],
		["SCARVES AND BONUSES", "+%d" % int(_r.scoops)],
		["STEWARD FINES", "-%d" % int(_r.fine)],
	]
	var ly := lr.position.y + 15
	for i in lines.size():
		if _ledger > i:
			UI.text(c, Vector2(lr.position.x + 12, ly), str(lines[i][0]), 1, UI.CONCH, false)
			UI.text_r(c, lr.end.x - 14, ly, str(lines[i][1]), 1, UI.MALACHITE.lightened(0.3) if not str(lines[i][1]).begins_with("-") else UI.ROSE, false)
		ly += 15.0
	if _ledger > 4:
		c.draw_rect(Rect2(lr.position.x + 12, ly - 2, lr.size.x - 24, 1), UI.GOLD)
		var gain := int(_r.money_after) - int(_r.money_before)
		if bool(_r.get("loan", false)):
			gain -= Game.LOAN_AMOUNT
		UI.text(c, Vector2(lr.position.x + 12, ly + 4), "YOU NOW HAVE", 1, UI.BONE, false)
		UI.text_r(c, lr.end.x - 14, ly + 4, UI.srang(int(_r.money_after)), 1, UI.ORPIMENT, false)
		ly += 17.0
		if bool(_r.get("loan", false)):
			UI.text(c, Vector2(lr.position.x + 12, ly + 2), "AMA CHOEKYI LENT YOU %d." % Game.LOAN_AMOUNT, 1, UI.ROSE, false)

	# the stamp
	if _ledger >= 6:
		var ok: bool = _r.qualified
		var word := "QUALIFIED" if ok else "NOT QUALIFIED"
		var col := UI.MALACHITE.lightened(0.2) if ok else UI.VERMILION
		var k := 2
		var sc := 1.0 + maxf(0.0, 0.5 - _stamp_t * 3.0)
		var w := UI.text_width(word, k)
		c.draw_set_transform(Vector2(508, 232), -0.08, Vector2(sc, sc))
		var box := Rect2(Vector2(-w * 0.5 - 8, -12), Vector2(w + 16, 26))
		c.draw_rect(box, Color(UI.INK, 0.8))
		UI.rect_frame(c, box, col, 2.0)
		UI.text(c, Vector2(-w * 0.5, -10), word, k, col, false)
		c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if bool(_r.get("won_game", false)):
			UI.text_c(c, 508, 252, "THE FINAL IS YOURS!", 1, UI.ORPIMENT)
		elif bool(_r.get("season_cleared", false)):
			UI.text_c(c, 508, 252, "SEASON CLEARED!", 1, UI.ORPIMENT)
		elif not ok:
			UI.text_c(c, 508, 252, "NEEDED THE TOP %d" % int(_r.needed), 1, UI.BONE)

	# a word from a rival
	var rl: Dictionary = _r.get("rival_line", {})
	if _ledger >= 5 and str(rl.get("line", "")) != "":
		var qb := Rect2(10, 322 - 20, 392, 50)
		UI.text(c, Vector2(14, 268), str(rl.get("name", "")), 1, UI.ORPIMENT)
		var words := ("\"%s\"" % str(rl.line)).split(" ")
		var line := ""
		var yy := 282.0
		for w2 in words:
			var test: String = w2 if line == "" else line + " " + w2
			if UI.text_width(test) > 372.0:
				UI.text(c, Vector2(14, yy), line, 1, UI.CONCH, false)
				yy += 13.0
				line = w2
			else:
				line = test
		UI.text(c, Vector2(14, yy), line, 1, UI.CONCH, false)


func _next() -> void:
	if _r.is_empty():
		Game.go("league")
	elif bool(_r.get("won_game", false)):
		Game.show_story(StoryText.victory_pages(Game.player_id), "credits")
	elif bool(_r.get("season_cleared", false)):
		Game.show_story(StoryText.season_end_pages(Game.player_id, int(_r.get("season", 0))), "league")
	else:
		Game.go("league")


func back() -> void:
	if not _continue.disabled:
		_next()
