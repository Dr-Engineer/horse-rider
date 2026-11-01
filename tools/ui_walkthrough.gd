# Drives the menu flow with real input actions and saves a screenshot of each screen.
# Usage (needs a window, not --headless):
#   Godot --path . --resolution 1600x900 -s res://tools/ui_walkthrough.gd -- <out_dir> [screen ...]
# Screens: title select story league prerace results stable credits options race (default: all)
extends SceneTree

var out_dir := "/tmp/ui_shots"
var g: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred(args.slice(1))


## "frames" are 60ths of a second of real time, so the walkthrough is independent of the frame rate.
func _wait(frames: int) -> void:
	await create_timer(float(frames) / 60.0).timeout
	await process_frame


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png("%s/%s.png" % [out_dir, shot_name])
	print("shot ", shot_name)


func _press(action: String, settle: int = 3) -> void:
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


func _goto(key: String, frames: int = 70) -> void:
	g.go(key)
	await _wait(frames)


func _fake_results(player_place: int, kd: int) -> void:
	var names := ["PON WANGYAL DORJE", "KARMA TOBGYE", "SONAM PHURBA", "PASANG TSOMO", "LITHANG SAMDUP", "TEMBA TINLE", "PEMA YANGKEY", "JORU"]
	var ids := ["wangyal", "karma", "sonam", "pasang", "samdup", "temba", "pema", ""]
	var order: Array = []
	var others := [0, 1, 2, 3, 4, 5, 6]
	var oi := 0
	for place in range(1, 9):
		var e := {}
		if place == player_place:
			e = {"rider": {"display_name": "JORU", "rival_id": "", "is_player": true}, "place": place, "time": 141.37 + place * 1.9, "knockdowns": kd, "bounty": kd * 15, "scoops": 2, "silver": 16, "fines": 0, "crashed": 1}
		else:
			var k: int = others[oi]
			oi += 1
			e = {"rider": {"display_name": names[k], "rival_id": ids[k], "is_player": false}, "place": place, "time": 140.0 + place * 1.7, "knockdowns": 0, "bounty": 0, "scoops": 0, "silver": 0, "fines": 0, "crashed": 0}
		order.append(e)
	g.apply_race_result(order)


func _run(only: Array) -> void:
	await _wait(10)
	g = root.get_node("Game")
	g.save_path = "user://walkthrough_save.cfg"
	var want := func(n: String) -> bool: return only.is_empty() or only.has(n)
	if want.call("title"):
		g.new_game("joru")
		await _goto("title", 150)
		await _shot("01_title")
		await _press("ui_down")
		await _press("ui_down")
		await _press("ui_accept", 20)
		await _shot("01b_title_options")
		await _press("ui_cancel", 10)
	if want.call("select"):
		await _goto("select", 100)
		await _shot("02_select")
		await _press("ui_right", 30)
		await _shot("02b_select_yangkyi")
	if want.call("story"):
		g.new_game("joru")
		g.show_story(StoryText.intro_pages("joru"), "league")
		await _wait(150)
		await _shot("03_story")
	if want.call("league"):
		g.new_game("joru")
		g.qualified[0] = true
		g.qualified[1] = true
		g.money = 135
		g.horse_id = "old_tsampa"
		await _goto("league", 80)
		await _shot("04_league")
		await _press("ui_down")
		await _press("ui_down", 10)
		await _shot("04b_league_course3")
	if want.call("prerace"):
		g.new_game("joru")
		g.grudges = {"wangyal": 2}
		g.course_index = 2
		await _goto("prerace", 80)
		await _shot("05_prerace")
	if want.call("results"):
		g.new_game("joru")
		g.course_index = 1
		_fake_results(2, 2)
		await _goto("results", 30)
		await _wait(300)
		await _shot("06_results")
	if want.call("stable"):
		g.new_game("joru")
		g.money = 730
		await _goto("stable", 80)
		await _shot("07_stable_horses")
		await _press("ui_down")
		await _press("ui_down", 10)
		await _shot("07b_stable_horse_row2")
		await _press("ui_up")
		await _press("ui_up")
		await _press("ui_up")
		await _press("ui_right", 12)
		await _press("ui_down")
		await _press("ui_down")
		await _press("ui_down", 10)
		await _shot("07c_stable_melee")
		await _press("ui_accept", 14)
		await _shot("07d_stable_bought")
		await _press("ui_up")
		await _press("ui_up")
		await _press("ui_up")
		await _press("ui_up")
		await _press("ui_up")
		await _press("ui_right", 12)
		await _press("ui_right", 12)
		await _shot("07e_stable_tack")
	if want.call("credits"):
		g.new_game("yangkyi")
		await _goto("credits", 120)
		await _shot("08_credits_roll")
		await _press("ui_accept", 120)
		await _shot("08b_credits_ask")
		await _wait(260)
		await _shot("08c_credits_ask2")
		await _press("ui_accept", 120)
		await _shot("08d_endcard")
	if want.call("race"):
		g.new_game("joru")
		g.weapon_id = "sword"
		g.ranged_id = "bow"
		g.has_shield = true
		g.start_race()
		await _wait(110)
		await _shot("09_race_countdown")
		await _wait(200)
		await _shot("09b_race_go")
		for i in 8:
			await _press("urge", 20)
		await _wait(300)
		await _shot("09c_race_run")
		await _press("pause", 20)
		await _shot("09d_pause")
	if want.call("flow"):
		# a real race, ended early, through results into the league
		g.new_game("yangkyi")
		g.course_index = 0
		g.start_race()
		await _wait(420)
		var race_node: Node = current_scene
		print("race node: ", race_node)
		if race_node != null and race_node.has_method("_end_race"):
			race_node.call("_end_race")
		await _wait(380)
		await _shot("10_flow_results")
		await _wait(900)
		await _shot("10b_flow_results_done")
		await _press("ui_accept", 120)
		await _shot("10c_flow_after_results")
	if want.call("season"):
		g.new_game("joru")
		for i in 4:
			g.qualified[i] = true
		g.course_index = 4
		_fake_results(1, 3)
		await _goto("results", 30)
		await _wait(420)
		await _shot("11_season_cleared_results")
		await _press("ui_accept", 400)
		await _shot("11b_season_end_story")
		await _press("ui_accept", 60)
		await _press("ui_accept", 60)
		await _wait(300)
		await _shot("11c_story_page3")
		print("season now ", g.season, " qualified ", g.qualified)
		g.new_game("yangkyi")
		g.season = 2
		for i in 4:
			g.qualified[i] = true
		g.course_index = 4
		_fake_results(1, 1)
		await _goto("results", 30)
		await _wait(420)
		await _shot("12_final_results")
		await _press("ui_accept", 400)
		await _shot("12b_victory_story")
	if want.call("loan"):
		g.new_game("joru")
		g.money = 6
		await _goto("league", 90)
		await _shot("13_loan_note")
		await _press("ui_accept", 30)
		g.money = 90
		await _goto("stable", 60)
		await _press("ui_down")
		await _press("ui_accept", 20)
		await _shot("13b_not_enough")
	if want.call("keys"):
		# the whole front end with nothing but keyboard actions
		g.new_game("joru")
		g.save_path = "user://walkthrough_none.cfg"
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://walkthrough_none.cfg"))
		await _goto("title", 100)
		print("1 ", current_scene.name)
		await _press("ui_accept", 100)
		print("2 ", current_scene.name)
		await _press("ui_accept", 100)
		print("3 ", current_scene.name)
		for i in 8:
			await _press("ui_accept", 90)
			if current_scene.name != "StoryScreen":
				break
		print("4 ", current_scene.name)
		await _wait(60)
		await _press("ui_accept", 100)
		print("5 ", current_scene.name)
		await _press("ui_accept", 100)
		print("6 ", current_scene.name)
		await _wait(300)
		await _shot("14_keys_race")
		g.save_path = "user://walkthrough_save.cfg"
	quit()
