class_name OptionsPanel
extends Control
## Music and effects volume, fullscreen, and the controls list. Used from the title screen and the pause menu.

signal closed

var embedded := false
var _first: Control


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UI.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.04, 0.06, 0.78 if embedded else 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := ThangkaPanel.new(true, 14, 14)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	box.add_child(UI.label("OPTIONS", 2, UI.ORPIMENT, HORIZONTAL_ALIGNMENT_CENTER))
	var music := WStepper.new("MUSIC", roundi(Game.music_volume * 10.0))
	music.value_changed.connect(func(v: int) -> void:
		Sfx.set_music_volume(v / 10.0)
		Game.save_settings())
	box.add_child(music)
	var sfx := WStepper.new("EFFECTS", roundi(Game.sfx_volume * 10.0))
	sfx.value_changed.connect(func(v: int) -> void:
		Sfx.set_sfx_volume(v / 10.0)
		Sfx.play("hit_light", -4.0)
		Game.save_settings())
	box.add_child(sfx)
	var fs := WButton.new("FULLSCREEN: %s" % ("ON" if Game.fullscreen else "OFF"))
	fs.custom_minimum_size = Vector2(250, 20)
	fs.pressed.connect(func() -> void:
		Game.set_fullscreen(not Game.fullscreen)
		fs.text = "FULLSCREEN: %s" % ("ON" if Game.fullscreen else "OFF"))
	box.add_child(fs)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 1)
	var rows := [
		["", "KEYBOARD", "GAMEPAD"],
		["STEER", "A D", "LEFT STICK"],
		["URGE  REIN", "W  S", "RT  LT"],
		["WHIP", "SHIFT", "RB"],
		["LEAP", "SPACE", "A"],
		["STRIKE", "J L  OR  Q E", "X  B"],
		["KICK", "K", "Y"],
		["RANGED", "U HOLD", "DPAD UP"],
		["SHIELD", "I", "LB"],
		["SECOND WIND", "ENTER", "DPAD DOWN"],
		["PAUSE", "ESC", "START"],
	]
	for r in rows:
		for i in 3:
			var col := UI.ORPIMENT if r[0] == "" else (UI.CONCH if i == 0 else UI.BONE)
			var l := UI.label(r[i], 1, col, HORIZONTAL_ALIGNMENT_LEFT, false)
			l.custom_minimum_size = Vector2([86, 88, 76][i], 0)
			grid.add_child(l)
	box.add_child(grid)
	var close := WButton.new("BACK")
	close.custom_minimum_size = Vector2(250, 20)
	close.pressed.connect(_close)
	box.add_child(close)
	_first = music
	_first.grab_focus.call_deferred()


func _close() -> void:
	Game.save_settings()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		Sfx.play("ui_back", -3.0)
		_close()
