class_name RiderSelect
extends Screen
## Pick Joru or Yangkyi.

var _stage: SelectStage
var _name: TextArt
var _tag: TextArt
var _look: Label
var _buttons: Array[WButton] = []
const IDS: Array[String] = ["joru", "yangkyi"]


func build() -> void:
	Sfx.music("menu")
	_stage = SelectStage.new()
	add_child(_stage)
	move_child(_stage, 0)
	var head := TextArt.new("CHOOSE YOUR RIDER", 2, UI.ORPIMENT, HORIZONTAL_ALIGNMENT_CENTER)
	head.position = Vector2(0, 14)
	head.size = Vector2(640, 26)
	safe.add_child(head)

	var panel := ThangkaPanel.new(true, 12, 12)
	panel.position = Vector2(120, 258)
	panel.custom_minimum_size = Vector2(400, 80)
	safe.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	panel.add_child(box)
	_name = TextArt.new("", 2, UI.CONCH)
	box.add_child(_name)
	_tag = TextArt.new("", 1, UI.ORPIMENT)
	box.add_child(_tag)
	_look = UI.wrapped("", 370.0, 1, UI.BONE)
	box.add_child(_look)

	var left := WButton.new("JORU")
	left.custom_minimum_size = Vector2(120, 22)
	left.position = Vector2(30, 150)
	var right := WButton.new("YANGKYI")
	right.custom_minimum_size = Vector2(120, 22)
	right.position = Vector2(490, 150)
	safe.add_child(left)
	safe.add_child(right)
	_buttons = [left, right]
	for i in 2:
		var id: String = IDS[i]
		_buttons[i].focus_entered.connect(func() -> void: _show(id))
		_buttons[i].pressed.connect(func() -> void: _choose(id))
	left.focus_neighbor_right = right.get_path()
	right.focus_neighbor_left = left.get_path()
	left.focus_neighbor_left = left.get_path()
	right.focus_neighbor_right = right.get_path()
	left.focus_neighbor_top = left.get_path()
	left.focus_neighbor_bottom = left.get_path()
	right.focus_neighbor_top = right.get_path()
	right.focus_neighbor_bottom = right.get_path()
	var hint := TextArt.new(UI.hint("CHOOSE", "BACK"), 1, UI.BONE, HORIZONTAL_ALIGNMENT_CENTER)
	hint.position = Vector2(0, 344)
	hint.size = Vector2(640, 14)
	safe.add_child(hint)
	_show("joru")
	focus_later(left)


func _show(id: String) -> void:
	var info: Dictionary = FallbackData.PLAYERS[id]
	var data: Variant = Game.gd_const("PLAYERS", {})
	var region: String = str(info.region)
	if data is Dictionary and (data as Dictionary).has(id):
		region = str((data as Dictionary)[id].get("region", region)).to_upper()
	_name.set_text(str(info.name))
	_tag.set_text("%s  -  %s" % [region, info.tag])
	_look.text = str(info.look)
	_stage.focus_on(id)


func _choose(id: String) -> void:
	Game.new_game(id)
	Game.show_story(StoryText.intro_pages(id), "league")


func back() -> void:
	Game.go("title")
