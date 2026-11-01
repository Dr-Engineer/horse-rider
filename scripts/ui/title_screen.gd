class_name TitleScreen
extends Screen
## Title: the name, the tall-tale line, a horse galloping in place, and the way in.

var _buttons: Array[WButton] = []
var _modal: Control = null


func build() -> void:
	back_enabled = false
	Sfx.music("menu")
	var stage := TitleStage.new()
	add_child(stage)
	move_child(stage, 0)

	var grad := Gradient.new()
	grad.set_color(0, Color(UI.INK, 0.9))
	grad.set_color(1, Color(UI.INK, 0.0))
	grad.set_offset(0, 0.0)
	grad.set_offset(1, 1.0)
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 0)
	gt.width = 128
	gt.height = 4
	var shade := TextureRect.new()
	shade.texture = gt
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.anchor_right = 0.7
	shade.anchor_bottom = 1.0
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	move_child(shade, 1)

	var flags := FlagString.new()
	add_child(flags)
	flags.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	flags.custom_minimum_size = Vector2(0, 26)
	flags.offset_bottom = 26
	var t1 := TextArt.new("WINDHORSE", 4, UI.ORPIMENT)
	t1.position = Vector2(20, 30)
	safe.add_child(t1)
	var t2 := TextArt.new("RUMBLE", 4, UI.VERMILION.lightened(0.15))
	t2.position = Vector2(20, 78)
	safe.add_child(t2)
	var sub := TextArt.new("A TALL TALE OF THE WOOD HORSE YEAR", 1, UI.CONCH)
	sub.position = Vector2(22, 130)
	safe.add_child(sub)
	var rule := ColorRect.new()
	rule.color = UI.GOLD
	rule.position = Vector2(22, 146)
	rule.size = Vector2(250, 1)
	safe.add_child(rule)

	var labels: Array = []
	if Game.has_save():
		labels.append("CONTINUE")
	labels.append_array(["NEW GAME", "OPTIONS", "QUIT"])
	_buttons = button_column(safe, labels, 150.0, Vector2(22, 158))
	var i := 0
	if Game.has_save():
		_buttons[i].pressed.connect(_continue)
		i += 1
	_buttons[i].pressed.connect(_new_game)
	_buttons[i + 1].pressed.connect(_options)
	_buttons[i + 2].pressed.connect(Game.quit_game)

	if Game.has_save():
		var info := "%s  -  SEASON %d  -  %d SRANG" % [str(FallbackData.PLAYERS.get(Game.player_id, {}).get("name", "RIDER")), Game.season + 1, Game.money]
		var cont := TextArt.new(info, 1, UI.BONE)
		cont.position = Vector2(22, 266)
		cont.name = "ContinueInfo"
		safe.add_child(cont)
	var foot := TextArt.new(StoryText.TALL_TALE_LINE, 1, UI.BONE, HORIZONTAL_ALIGNMENT_CENTER)
	foot.position = Vector2(0, 340)
	foot.size = Vector2(640, 14)
	safe.add_child(foot)
	focus_later(_buttons[0])


func _continue() -> void:
	if Game.load_game():
		Game.go("league")


func _new_game() -> void:
	if Game.has_save():
		_ask("START OVER? YOUR SAVED RIDE WILL BE REPLACED.", func() -> void: Game.go("select"))
	else:
		Game.go("select")


func _options() -> void:
	var o := OptionsPanel.new()
	add_child(o)
	_modal = o
	o.closed.connect(func() -> void:
		o.queue_free()
		_modal = null
		_buttons[_buttons.size() - 2].grab_focus.call_deferred())


func _ask(message: String, on_yes: Callable) -> void:
	var m := Control.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_STOP
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
	box.add_child(UI.wrapped(message, 260.0, 1, UI.CONCH))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	var yes := WButton.new("YES")
	yes.custom_minimum_size = Vector2(100, 20)
	var no := WButton.new("NO")
	no.custom_minimum_size = Vector2(100, 20)
	row.add_child(yes)
	row.add_child(no)
	add_child(m)
	_modal = m
	var close := func() -> void:
		m.queue_free()
		_modal = null
		_buttons[0].grab_focus.call_deferred()
	yes.pressed.connect(func() -> void:
		close.call()
		on_yes.call())
	no.pressed.connect(close)
	no.grab_focus.call_deferred()
