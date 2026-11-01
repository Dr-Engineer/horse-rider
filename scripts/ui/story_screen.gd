class_name StoryScreen
extends Screen
## The old rider's telling: pages typed out one after another over a dusk landscape.

var _pages: Array = []
var _page := 0
var _label: Label
var _speaker: TextArt
var _counter: TextArt
var _hint: TextArt
var _chars := 0.0
var _t := 0.0
var _speed := SPEED
var _voiced := false
const SPEED := 70.0
const SLOWEST := 9.0


func build() -> void:
	Sfx.music("menu")
	var bd := Backdrop.new(0.7, 0.58)
	add_child(bd)
	move_child(bd, 0)
	_pages = Game.story_pages.duplicate()
	if _pages.is_empty():
		_pages = StoryText.intro_pages(Game.player_id)
		Game.story_next = "league"
	var panel := ThangkaPanel.new(true, 16, 13)
	panel.position = Vector2(40, 150)
	panel.custom_minimum_size = Vector2(560, 170)
	safe.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	var pb := PortraitBox.new(Game.player_id, 48, 2)
	pb.set_rival(Game.player_id, UI.INDIGO, Game.player_id.to_upper())
	row.add_child(pb)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	row.add_child(box)
	_speaker = TextArt.new("%s, %s, TELLS IT" % [StoryText.narrator(Game.player_id), StoryText.narrator_title(Game.player_id)], 1, UI.ORPIMENT)
	box.add_child(_speaker)
	_label = UI.wrapped("", 400.0, 1, UI.CONCH)
	_label.custom_minimum_size = Vector2(400, 90)
	box.add_child(_label)
	_counter = TextArt.new("", 1, UI.BONE, HORIZONTAL_ALIGNMENT_RIGHT)
	_counter.position = Vector2(500, 324)
	_counter.size = Vector2(96, 14)
	safe.add_child(_counter)
	_hint = TextArt.new("ENTER", 1, UI.ORPIMENT)
	_hint.position = Vector2(46, 324)
	safe.add_child(_hint)
	_start_page()


func _start_page() -> void:
	var page := str(_pages[_page])
	_label.text = page
	_label.visible_characters = 0
	_chars = 0.0
	_counter.set_text("%d/%d" % [_page + 1, _pages.size()])
	# With a voice, the words are typed out as they are spoken and the last one lands as the voice ends.
	var secs := Speak.text(StoryText.narrator(Game.player_id).to_lower(), page)
	_voiced = secs > 0.0
	_speed = SPEED
	if _voiced:
		_speed = clampf(float(page.length()) / maxf(secs - 0.2, 0.5), SLOWEST, SPEED)


func _process(delta: float) -> void:
	_t += delta
	if _label == null:
		return
	var total := _label.get_total_character_count()
	if _label.visible_characters < total:
		_chars += delta * _speed
		var n := mini(int(_chars), total)
		if n != _label.visible_characters:
			_label.visible_characters = n
			if n % 3 == 0 and not _voiced:
				Sfx.play("ui_move", -16.0, 1.5)
	_hint.visible = _label.visible_characters >= total and fmod(_t * 2.0, 2.0) < 1.4


func _advance() -> void:
	var total := _label.get_total_character_count()
	if _label.visible_characters < total:
		_label.visible_characters = total
		return
	Speak.stop()
	Sfx.play("ui_ok", -4.0)
	_page += 1
	if _page >= _pages.size():
		_finish()
	else:
		_start_page()


func _finish() -> void:
	Game.go(Game.story_next)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT):
		get_viewport().set_input_as_handled()
		_advance()
	elif event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_finish()


func back() -> void:
	_finish()
