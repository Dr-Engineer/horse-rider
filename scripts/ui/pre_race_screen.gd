class_name PreRace
extends Screen
## The pre-race card: the course, and a rival with something to say. Grudges choose who talks.


func build() -> void:
	Sfx.music("menu")
	var bd := Backdrop.new(2.6, 0.45)
	add_child(bd)
	move_child(bd, 0)
	var rv := Game.featured_rival()
	var info := Game.course_info(Game.course_index)
	var panel := ThangkaPanel.new(true, 16, 14)
	panel.position = Vector2(50, 22)
	panel.custom_minimum_size = Vector2(540, 270)
	safe.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 5)
	panel.add_child(col)
	col.add_child(TextArt.new("RACE %d OF 5    %s" % [Game.course_index + 1, StoryText.SEASON_NAMES[clampi(Game.season, 0, 2)]], 1, UI.ORPIMENT))
	col.add_child(TextArt.new(str(info.name), 2, UI.CONCH))
	col.add_child(TextArt.new(str(info.region), 1, UI.BONE))
	var rule := ColorRect.new()
	rule.color = UI.CHARCOAL
	rule.custom_minimum_size = Vector2(500, 1)
	col.add_child(rule)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	col.add_child(row)
	var pb := PortraitBox.new(str(rv.id), 48, 2)
	var rdata: Variant = Game.gd_const("RIVALS", {})
	var tint := UI.CHARCOAL
	if rdata is Dictionary and (rdata as Dictionary).has(rv.id):
		tint = (rdata as Dictionary)[rv.id].get("slot_a", tint)
	pb.set_rival(str(rv.id), tint, str(rv.name))
	row.add_child(pb)
	var talk := VBoxContainer.new()
	talk.add_theme_constant_override("separation", 4)
	row.add_child(talk)
	talk.add_child(TextArt.new(str(rv.name), 1, UI.ORPIMENT))
	var tag := "%s" % rv.region
	if str(rv.kind) == "grudge":
		tag = "GRUDGE - YOU KNOCKED THEM DOWN"
	elif str(rv.kind) == "loan":
		tag = "HEARD ABOUT YOUR LOAN"
	talk.add_child(TextArt.new(tag, 1, UI.ROSE if str(rv.kind) == "grudge" else UI.BONE))
	var quote := UI.wrapped("\"%s\"" % str(rv.line), 360.0, 1, UI.CONCH)
	quote.custom_minimum_size = Vector2(360, 54)
	talk.add_child(quote)

	var blurb := UI.wrapped(str(info.blurb), 500.0, 1, UI.BONE)
	col.add_child(blurb)
	var need := "FINISH IN THE TOP 3 TO QUALIFY."
	if Game.is_final(Game.season, Game.course_index):
		need = "THE FINAL. WIN TO CLEAR THE SEASON."
	col.add_child(TextArt.new(need, 1, UI.ORPIMENT))

	var go_btn := WButton.new("RIDE!")
	go_btn.custom_minimum_size = Vector2(120, 24)
	go_btn.position = Vector2(220, 304)
	go_btn.pressed.connect(func() -> void: Game.start_race())
	safe.add_child(go_btn)
	var back_btn := WButton.new("BACK")
	back_btn.custom_minimum_size = Vector2(90, 24)
	back_btn.position = Vector2(350, 304)
	back_btn.pressed.connect(back)
	safe.add_child(back_btn)
	Sfx.play("horn", -8.0)
	focus_later(go_btn)


func back() -> void:
	Game.go("league")
