class_name CreditsScreen
extends Screen
## Credits roll, then the child asks "And then?", the narrator pours tea, and the end card tells the truth.

enum Phase { ROLL, ASK, CARD }

var _phase := Phase.ROLL
var _t := 0.0
var _board: Control
var _lines: Array[String] = []
var _speed := 22.0
var _roll_y := 0.0
var _card_panel: Control
var _prompt: TextArt
var _tea_played := false


func build() -> void:
	Sfx.music("menu")
	back_enabled = true
	var bd := Backdrop.new(5.1, 0.6)
	add_child(bd)
	move_child(bd, 0)
	_lines = StoryText.credits_lines()
	_roll_y = 372.0
	_board = Control.new()
	_board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(_board)
	_board.draw.connect(_paint)
	_prompt = TextArt.new("ENTER", 1, UI.ORPIMENT, HORIZONTAL_ALIGNMENT_CENTER)
	_prompt.position = Vector2(0, 338)
	_prompt.size = Vector2(640, 14)
	_prompt.visible = false
	safe.add_child(_prompt)


func _line_height(i: int) -> float:
	return 40.0 if i == 0 else (14.0 if _lines[i] != "" else 10.0)


func _paint() -> void:
	var c := _board
	match _phase:
		Phase.ROLL:
			var y := _roll_y
			for i in _lines.size():
				var l := _lines[i]
				if l != "":
					if i == 0:
						UI.text_c(c, 320, y, l, 3, UI.ORPIMENT)
					elif l.begins_with("-"):
						UI.text_c(c, 320, y, l, 1, UI.ORPIMENT)
					elif i == 1:
						UI.text_c(c, 320, y, l, 1, UI.CONCH)
					else:
						UI.text_c(c, 320, y, l, 1, UI.BONE)
				y += _line_height(i)
		Phase.ASK:
			c.draw_rect(Rect2(-400, -400, 1500, 1200), Color(UI.INK, 0.94))
			var a := clampf(_t / 0.6, 0.0, 1.0)
			UI.text_c(c, 320, 130, "AND THEN?", 3, UI.CONCH, true, a)
			if _t > 3.0:
				var b := clampf((_t - 3.0) / 0.8, 0.0, 1.0)
				UI.text_c(c, 320, 190, "%s POURS MORE TEA." % StoryText.narrator(Game.player_id), 1, UI.BONE, true, b)


func _process(delta: float) -> void:
	_t += delta
	match _phase:
		Phase.ROLL:
			_roll_y -= _speed * delta
			var total := 0.0
			for i in _lines.size():
				total += _line_height(i)
			if _roll_y + total < -10.0:
				_to_ask()
			_board.queue_redraw()
		Phase.ASK:
			if _t > 3.0 and not _tea_played:
				_tea_played = true
				Sfx.play("splash", -16.0, 1.3)
			if _t > 6.5:
				_to_card()
			_board.queue_redraw()
		Phase.CARD:
			_prompt.visible = fmod(_t * 2.0, 2.0) < 1.4 and _t > 2.0


func _to_ask() -> void:
	_phase = Phase.ASK
	_t = 0.0
	Sfx.stop_music()


func _to_card() -> void:
	_phase = Phase.CARD
	_t = 0.0
	_board.queue_redraw()
	var panel := ThangkaPanel.new(true, 18, 16)
	panel.position = Vector2(50, 40)
	panel.custom_minimum_size = Vector2(540, 250)
	safe.add_child(panel)
	var lab := UI.wrapped(StoryText.END_CARD, 500.0, 1, UI.CONCH)
	panel.add_child(lab)
	_card_panel = panel
	panel.modulate.a = 0.0
	create_tween().tween_property(panel, "modulate:a", 1.0, 0.8)
	Sfx.play("bell", -8.0)


func _unhandled_input(event: InputEvent) -> void:
	var pressed := event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel") or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed)
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	match _phase:
		Phase.ROLL:
			_to_ask()
		Phase.ASK:
			_to_card()
		Phase.CARD:
			if _t > 1.5:
				Game.go("title")


func back() -> void:
	pass
