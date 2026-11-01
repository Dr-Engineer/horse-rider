class_name PreRace
extends Screen
## The pre-race card: the course, a rival with something to say, and the rival's offer of a side bet. Grudges choose who talks.

var _rv: Dictionary = {}
var _stake := 0
var _bet_on := false
var _offer_head: TextArt
var _bet_btn: WButton
var _ride_btn: WButton


func build() -> void:
	Sfx.music("menu")
	Game.clear_wager()
	var bd := Backdrop.new(2.6, 0.45)
	add_child(bd)
	move_child(bd, 0)
	_rv = Game.featured_rival()
	var rv := _rv
	_stake = Game.wager_stake()
	var info := Game.course_info(Game.course_index)
	var panel_h := 292.0 if _stake > 0 else 262.0
	var panel := ThangkaPanel.new(true, 16, 14)
	panel.position = Vector2(30, 8)
	panel.custom_minimum_size = Vector2(580, panel_h)
	safe.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)
	col.add_child(TextArt.new("RACE %d OF 5    %s" % [Game.course_index + 1, StoryText.SEASON_NAMES[clampi(Game.season, 0, 2)]], 1, UI.ORPIMENT))
	col.add_child(TextArt.new(str(info.name), 2, UI.CONCH))
	col.add_child(TextArt.new(str(info.region), 1, UI.BONE))
	col.add_child(_rule(548.0))

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
	talk.add_theme_constant_override("separation", 3)
	row.add_child(talk)
	talk.add_child(TextArt.new(str(rv.name), 1, UI.ORPIMENT))
	var tag := "%s" % rv.region
	if str(rv.kind) == "grudge":
		tag = "GRUDGE - YOU KNOCKED THEM DOWN"
	elif str(rv.kind) == "loan":
		tag = "HEARD ABOUT YOUR LOAN"
	talk.add_child(TextArt.new(tag, 1, UI.ROSE if str(rv.kind) == "grudge" else UI.BONE))
	var quote := UI.wrapped("\"%s\"" % str(rv.line), 420.0, 1, UI.CONCH)
	quote.custom_minimum_size = Vector2(420, 28)
	talk.add_child(quote)
	var offer := StoryText.wager_line(str(rv.id), "offer")
	if _stake > 0:
		talk.add_child(_rule(420.0))
		_offer_head = TextArt.new("", 1, UI.ORPIMENT)
		talk.add_child(_offer_head)
		var offer_quote := UI.wrapped("\"%s\"" % offer, 420.0, 1, UI.CONCH)
		offer_quote.custom_minimum_size = Vector2(420, 28)
		talk.add_child(offer_quote)
		talk.add_child(_stake_row())

	var blurb := UI.wrapped(str(info.blurb), 548.0, 1, UI.BONE)
	col.add_child(blurb)
	var need := "FINISH IN THE TOP 3 TO QUALIFY."
	if Game.is_final(Game.season, Game.course_index):
		need = "THE FINAL. WIN TO CLEAR THE SEASON."
	col.add_child(TextArt.new(need, 1, UI.ORPIMENT))

	_ride_btn = WButton.new("RIDE!")
	_ride_btn.custom_minimum_size = Vector2(124, 24)
	_ride_btn.pressed.connect(_ride)
	var back_btn := WButton.new("BACK")
	back_btn.custom_minimum_size = Vector2(84, 24)
	back_btn.pressed.connect(back)
	var y := 8.0 + panel_h + 12.0
	if _stake > 0:
		_bet_btn = WButton.new("BET")
		_bet_btn.custom_minimum_size = Vector2(112, 24)
		_bet_btn.pressed.connect(func() -> void: _decide(true))
		var pass_btn := WButton.new("NO THANKS")
		pass_btn.custom_minimum_size = Vector2(112, 24)
		pass_btn.pressed.connect(func() -> void: _decide(false))
		var x := 640.0 * 0.5 - (112.0 + 112.0 + 124.0 + 84.0 + 24.0) * 0.5
		for b: WButton in [_bet_btn, pass_btn, _ride_btn, back_btn]:
			b.position = Vector2(x, y)
			x += b.custom_minimum_size.x + 8.0
			safe.add_child(b)
		UI.focus_chain([_bet_btn, pass_btn, _ride_btn, back_btn], false, false)
		_refresh_offer()
	else:
		_ride_btn.position = Vector2(640.0 * 0.5 - 124.0 - 4.0, y)
		back_btn.position = Vector2(640.0 * 0.5 + 4.0, y)
		safe.add_child(_ride_btn)
		safe.add_child(back_btn)
		UI.focus_chain([_ride_btn, back_btn], false, false)
	Sfx.play("horn", -8.0)
	focus_later(_ride_btn)

	var tw := create_tween()
	tw.tween_interval(0.9)
	tw.tween_callback(func() -> void: _speak(str(rv.id), str(rv.line), offer))


func _rule(width: float) -> ColorRect:
	var rule := ColorRect.new()
	rule.color = UI.CHARCOAL
	rule.custom_minimum_size = Vector2(width, 1)
	return rule


## Stake, and what each result pays, on one line.
func _stake_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var coin := UI.icon("coin")
	if coin != null:
		var tr := TextureRect.new()
		tr.texture = coin
		tr.custom_minimum_size = Vector2(coin.get_width(), coin.get_height())
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(tr)
	row.add_child(TextArt.new("STAKE %d" % _stake, 1, UI.ORPIMENT))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(10, 1)
	row.add_child(gap)
	row.add_child(TextArt.new("AHEAD OF THEM +%d" % _stake, 1, UI.MALACHITE.lightened(0.3)))
	row.add_child(TextArt.new("BEHIND -%d" % _stake, 1, UI.ROSE))
	return row


func _refresh_offer() -> void:
	var who := str(_rv.name)
	if _bet_on:
		_offer_head.set_text("BET PLACED WITH %s" % who)
		_offer_head.color = UI.MALACHITE.lightened(0.3)
		_bet_btn.text = "BET PLACED"
	else:
		_offer_head.set_text("%s OFFERS A SIDE BET" % who)
		_offer_head.color = UI.ORPIMENT
		_bet_btn.text = "BET"
	_offer_head.queue_redraw()


func _decide(on: bool) -> void:
	_bet_on = on
	_refresh_offer()
	if on:
		Sfx.play("coin", -4.0)
	_ride_btn.grab_focus.call_deferred()


func _ride() -> void:
	if _bet_on and _stake > 0:
		Game.place_wager(str(_rv.id), _stake)
	else:
		Game.clear_wager()
	Game.start_race()


## The rival says their piece, then makes the offer. Quietly nothing if there is no voice for either.
func _speak(rival_id: String, line: String, offer: String) -> void:
	var secs := Speak.text(rival_id, line)
	if _stake > 0 and offer != "":
		var tw := create_tween()
		tw.tween_interval(secs + 0.4 if secs > 0.0 else 0.0)
		tw.tween_callback(func() -> void: Speak.text(rival_id, offer))


func back() -> void:
	Game.clear_wager()
	Game.go("league")
