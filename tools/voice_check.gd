# Walks the spoken menus against a fake Sfx (tools/fake_sfx.gd) and checks what each one asked to be spoken: the story
# narrator and its typing speed, the title greeting once per launch, the rival on the pre-race card and the results, the
# saying on the league screen, the child at the end of the credits, and the sample line in the options. Needs no sound.
# Usage: Godot --headless --audio-driver Dummy --path . -s res://tools/voice_check.gd
extends SceneTree

var g: Node
var sfx: Node
var failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	if not ok:
		failed += 1
		print("FAIL: ", what)


func _wait(sec: float) -> void:
	await create_timer(sec).timeout
	await process_frame


func _press(action: String, settle: float = 0.15) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await process_frame
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await _wait(settle)


func _calls(prefix: String) -> int:
	var n := 0
	for l: String in sfx.log:
		if l.begins_with(prefix):
			n += 1
	return n


func _run() -> void:
	await _wait(0.3)
	g = root.get_node("Game")
	sfx = root.get_node("Sfx")
	sfx.set_script(load("res://tools/fake_sfx.gd"))
	g.save_path = "user://voice_check_save.cfg"
	g.settings_path = "user://voice_check_settings.cfg"
	g.voice_volume = 0.85
	g.voice_language = 0

	# the title greets once per launch, in the voice of the saved ride's narrator
	g.new_game("yangkyi")
	g.go("title")
	await _wait(2.2)
	_check(_calls("say mola greet") == 1, "title should greet with mola once, log: %s" % str(sfx.log))
	g.go("title")
	await _wait(2.2)
	_check(_calls("say mola greet") == 1, "title should not greet a second time")

	# the story: the narrator speaks each page, the typing is fitted to the voice, and advancing stops it
	g.new_game("joru")
	sfx.log.clear()
	var pages: Array = StoryText.intro_pages("joru")
	g.show_story(pages, "league")
	await _wait(1.0)
	var story := current_scene
	_check(story != null and story.get_script() != null and str(story.get("_voiced")) == "true", "story page should be voiced")
	_check(_calls("say_text pola") == 1, "narrator pola should speak page one, log: %s" % str(sfx.log))
	var expect := clampf(float(str(pages[0]).length()) / (3.0 - 0.2), 9.0, 70.0)
	_check(absf(float(story.get("_speed")) - expect) < 0.01, "typing speed should fit the voice: %f vs %f" % [float(story.get("_speed")), expect])
	var stops := _calls("stop_voice")
	await _press("ui_accept")      # finishes the typing, the voice carries on
	_check(_calls("stop_voice") == stops, "completing the text should not stop the voice")
	await _press("ui_accept")      # on to page two
	_check(_calls("stop_voice") == stops + 1, "advancing should stop the voice")
	_check(_calls("say_text pola") == 2, "narrator should speak page two, log: %s" % str(sfx.log))
	g.voice_volume = 0.0
	await _press("ui_accept")
	await _press("ui_accept")
	_check(_calls("say_text pola") == 2, "a muted game should not ask the narrator to speak")
	g.voice_volume = 0.85

	# the pre-race card: the rival speaks, then makes the offer
	g.new_game("joru")
	g.course_index = 0
	sfx.log.clear()
	g.go("prerace")
	await _wait(1.6)
	_check(_calls("say_text karma") >= 1, "the featured rival should speak on the card, log: %s" % str(sfx.log))
	await _wait(3.8)
	_check(_calls("say_text karma") == 2, "the rival should then make the offer, log: %s" % str(sfx.log))
	g.money = 30
	sfx.log.clear()
	g.go("prerace")
	await _wait(2.5)
	_check(_calls("say_text karma") == 1, "with no offer the rival only speaks their line, log: %s" % str(sfx.log))

	# the results: the rival's word is spoken once the ledger reaches it
	g.new_game("joru")
	g.course_index = 1
	g.place_wager("wangyal", 25)
	var order: Array = []
	var ids := ["wangyal", "karma", "sonam", "pasang", "samdup", "temba", "pema"]
	var oi := 0
	for place in range(1, 9):
		if place == 1:
			order.append({"rider": {"display_name": "JORU", "rival_id": "", "is_player": true}, "place": 1, "time": 140.0, "knockdowns": 0, "bounty": 0, "scoops": 0, "silver": 0, "fines": 0})
		else:
			order.append({"rider": {"display_name": str(ids[oi]).to_upper(), "rival_id": ids[oi], "is_player": false}, "place": place, "time": 141.0, "knockdowns": 0, "bounty": 0, "scoops": 0, "silver": 0, "fines": 0})
			oi += 1
	g.apply_race_result(order)
	sfx.log.clear()
	g.go("results")
	await _wait(1.0)
	_check(_calls("say_text wangyal") == 0, "the rival should wait for the ledger")
	await _wait(5.0)
	_check(_calls("say_text wangyal") == 1, "the rival should speak once the ledger reaches them, log: %s" % str(sfx.log))

	# the league: one saying, once per race run
	g.new_game("yangkyi")
	g.races_run = 2
	g.course_index = 1
	sfx.log.clear()
	g.go("league")
	await _wait(2.0)
	_check(_calls("say_text mola") == 1, "mola should speak a saying, log: %s" % str(sfx.log))
	g.go("stable")
	await _wait(1.0)
	g.go("league")
	await _wait(2.0)
	_check(_calls("say_text mola") == 1, "the saying should not repeat on coming back from the stable")

	# the credits: the child asks "and then?"
	sfx.log.clear()
	g.go("credits")
	await _wait(1.0)
	await _press("ui_accept")
	await _wait(0.5)
	_check(_calls("say child and_then") == 1, "the child should ask at the end of the credits, log: %s" % str(sfx.log))

	# the phrasebook: Enter plays the chosen phrase by its file id, and a muted game plays nothing
	sfx.log.clear()
	g.go("phrasebook")
	await _wait(1.0)
	await _press("ui_down")
	await _press("ui_accept")
	_check(_calls("say_file ") == 1, "the phrasebook should play the chosen phrase, log: %s" % str(sfx.log))
	g.voice_volume = 0.0
	await _press("ui_accept")
	_check(_calls("say_file ") == 1, "a muted phrasebook should play nothing")
	g.voice_volume = 0.85

	# the options: a sample on change, after a short pause
	g.new_game("joru")
	g.go("title")
	await _wait(1.5)
	sfx.log.clear()
	current_scene.call("_options")
	await _wait(0.5)
	await _press("ui_down")
	await _press("ui_down")
	await _press("ui_left")
	await _wait(0.8)
	_check(_calls("say starter ready") == 1, "changing the voices should play one sample, log: %s" % str(sfx.log))
	_check(_calls("voice_volume") >= 1, "the voice volume should reach Sfx")
	await _press("ui_down")
	await _press("ui_right")
	await _wait(0.8)
	_check(_calls("say starter ready") == 2, "changing the language should play a sample, log: %s" % str(sfx.log))

	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://voice_check_save.cfg"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://voice_check_settings.cfg"))
	print("voice check: %s" % ("all good" if failed == 0 else "%d FAILED" % failed))
	quit()
