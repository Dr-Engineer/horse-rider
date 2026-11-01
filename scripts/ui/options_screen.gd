class_name OptionsPanel
extends Control
## Music, effects and voice volume, the voice language, fullscreen, the phrasebook and the controls list. Used from the title
## screen and the pause menu (where there is no phrasebook, as leaving would end the race).

signal closed

const LANGUAGES: Array[String] = ["BOTH", "TIBETAN", "ENGLISH"]
const SAMPLE_DELAY := 0.3

var embedded := false
var _first: Control
var _caption: Label
var _sample_in := -1.0


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
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 18)
	box.add_child(cols)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 4)
	cols.add_child(left)

	var music := WStepper.new("MUSIC", roundi(Game.music_volume * 10.0))
	music.value_changed.connect(func(v: int) -> void:
		Sfx.set_music_volume(v / 10.0)
		Game.save_settings())
	left.add_child(music)
	var sfx := WStepper.new("EFFECTS", roundi(Game.sfx_volume * 10.0))
	sfx.value_changed.connect(func(v: int) -> void:
		Sfx.set_sfx_volume(v / 10.0)
		Sfx.play("hit_light", -4.0)
		Game.save_settings())
	left.add_child(sfx)
	var voices := WStepper.new("VOICES", roundi(Game.voice_volume * 10.0))
	voices.value_changed.connect(func(v: int) -> void:
		Game.set_voice_volume(v / 10.0)
		Game.save_settings()
		_set_caption("")
		_sample_in = SAMPLE_DELAY)
	left.add_child(voices)
	var lang := WChoice.new("LANGUAGE", LANGUAGES, Game.voice_language)
	lang.value_changed.connect(func(i: int) -> void:
		Game.set_voice_language(i)
		Game.save_settings()
		_sample_in = SAMPLE_DELAY)
	left.add_child(lang)
	_caption = UI.wrapped("", 250.0, 1, UI.BONE)
	_caption.custom_minimum_size = Vector2(250, 26)
	left.add_child(_caption)
	_set_caption("")

	var fs := WButton.new("FULLSCREEN: %s" % ("ON" if Game.fullscreen else "OFF"))
	fs.custom_minimum_size = Vector2(250, 20)
	fs.pressed.connect(func() -> void:
		Game.set_fullscreen(not Game.fullscreen)
		fs.text = "FULLSCREEN: %s" % ("ON" if Game.fullscreen else "OFF"))
	left.add_child(fs)
	var focusable: Array = [music, sfx, voices, lang, fs]
	if not embedded:
		var book := WButton.new("PHRASEBOOK")
		book.custom_minimum_size = Vector2(250, 20)
		book.pressed.connect(func() -> void:
			Game.save_settings()
			Game.go("phrasebook"))
		left.add_child(book)
		focusable.append(book)
	var close := WButton.new("BACK")
	close.custom_minimum_size = Vector2(250, 20)
	close.pressed.connect(_close)
	left.add_child(close)
	focusable.append(close)
	UI.focus_chain(focusable)

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
		["STRIKE", "J L  LEFT CLICK", "X  B"],
		["KICK", "K", "Y"],
		["AIM", "MOUSE", "RIGHT STICK"],
		["DRAW, LOOSE", "RIGHT CLICK  U", "DPAD UP"],
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
	cols.add_child(grid)
	_first = music
	_first.grab_focus.call_deferred()


func _process(delta: float) -> void:
	if _sample_in < 0.0:
		return
	_sample_in -= delta
	if _sample_in < 0.0:
		_sample_in = -1.0
		_play_sample()


## What the line under the settings says. Voices at zero always say so, in the danger colour.
func _set_caption(message: String) -> void:
	var muted := Game.voice_volume <= 0.001
	_caption.text = "VOICES ARE OFF." if muted else message
	_caption.add_theme_color_override("font_color", UI.ROSE if muted else UI.BONE)


## A short line in the current voice and language, with what it says, so a change can be heard (and read) at once.
func _play_sample() -> void:
	var line := Speak.say("starter", "ready")
	if line.is_empty():
		_set_caption("")
	elif str(line.get("g", "")) != "":
		_set_caption("%s\n(%s)" % [str(line["t"]), str(line["g"])])
	else:
		_set_caption(str(line.get("t", "")))


func _close() -> void:
	Game.save_settings()
	Speak.stop()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		Sfx.play("ui_back", -3.0)
		_close()
