# Checks the side bet's money rules and the voice settings, with no window: stakes, wins and losses, never a negative purse,
# never a loan caused by the bet, and nothing left over for the next race. Saves and settings go to scratch files.
# Usage: Godot --headless --audio-driver Dummy --path . -s res://tools/wager_check.gd
extends SceneTree

var g: Node
var failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	if not ok:
		failed += 1
		print("FAIL: ", what)


func _results(player_place: int, extra: Dictionary = {}) -> Array:
	var ids := ["wangyal", "karma", "sonam", "pasang", "samdup", "temba", "pema"]
	var out: Array = []
	var oi := 0
	for place in range(1, 9):
		if place == player_place:
			var e := {"rider": {"display_name": "JORU", "rival_id": "", "is_player": true}, "place": place, "time": 140.0, "knockdowns": 0, "bounty": 0, "scoops": 0, "silver": 0, "fines": 0, "crashed": 0}
			e.merge(extra, true)
			out.append(e)
		else:
			out.append({"rider": {"display_name": str(ids[oi]).to_upper(), "rival_id": ids[oi], "is_player": false}, "place": place, "time": 141.0, "knockdowns": 0, "bounty": 0, "scoops": 0, "silver": 0, "fines": 0, "crashed": 0})
			oi += 1
	return out


func _run() -> void:
	await process_frame
	g = root.get_node("Game")
	g.save_path = "user://wager_check_save.cfg"
	g.settings_path = "user://wager_check_settings.cfg"

	# the stake: about 15 percent in steps of 5, 20 to 200, and none when the bet could cost you your aunt's loan
	var cases := {39: 0, 40: 20, 45: 20, 100: 20, 150: 25, 200: 30, 400: 60, 1000: 150, 1333: 200, 5000: 200}
	for m: int in cases:
		g.money = m
		_check(int(g.wager_stake()) == int(cases[m]), "stake at %d should be %d, got %d" % [m, int(cases[m]), int(g.wager_stake())])

	# a lost bet never takes you under the loan line, whatever you hold, and a won one adds exactly the stake
	for m in range(40, 1500, 7):
		g.new_game("joru")
		g.money = m
		var stake: int = g.wager_stake()
		g.place_wager("wangyal", stake)
		g.apply_race_result(_results(8))
		_check(int(g.money) == m - stake, "lost bet at %d: money %d" % [m, int(g.money)])
		_check(int(g.money) >= int(g.LOAN_BELOW), "lost bet at %d caused a loan line breach: %d" % [m, int(g.money)])
		_check(not bool(g.last_result["loan"]), "lost bet at %d triggered a loan" % m)
		_check(int(g.loans) == 0, "loans counted after a lost bet at %d" % m)
		_check(int(g.wager) == 0 and str(g.wager_rival) == "", "bet left over after the race at %d" % m)
		g.new_game("joru")
		g.money = m
		g.place_wager("wangyal", stake)
		g.apply_race_result(_results(1))
		_check(int(g.money) == m + stake + int(g.prize_for(0, 1)), "won bet at %d: money %d" % [m, int(g.money)])

	# a bet is judged against the rival you bet with, not the field
	g.new_game("joru")
	g.money = 150
	g.place_wager("karma", 25)
	g.apply_race_result(_results(2))   # wangyal first, then the player, then karma: ahead of karma
	_check(bool(g.last_result["wager_won"]) and int(g.last_result["wager"]) == 25, "ahead of karma should win the bet")
	_check(str(g.last_result["rival_line"]["id"]) == "karma", "karma should answer a bet she was in")
	g.new_game("joru")
	g.money = 150
	g.place_wager("pema", 25)
	g.apply_race_result(_results(8))   # pema is seventh, the player last
	_check(not bool(g.last_result["wager_won"]), "behind pema should lose the bet")

	# no bet, no change; a rival who isn't in the field voids it
	g.new_game("joru")
	g.money = 150
	g.apply_race_result(_results(3))
	_check(int(g.last_result["wager"]) == 0, "no bet placed but a wager was recorded")
	g.new_game("joru")
	g.money = 150
	g.place_wager("serkhar", 25)
	g.apply_race_result(_results(3))
	_check(int(g.last_result["wager"]) == 0 and int(g.money) == 150 + int(g.prize_for(0, 3)), "a bet with a rider who didn't run should be void")

	# money never goes negative even with a big fine on top of a lost bet
	g.new_game("joru")
	g.money = 60
	g.place_wager("wangyal", int(g.wager_stake()))
	g.apply_race_result(_results(8, {"fines": 500}))
	_check(int(g.money) >= 0, "money went negative: %d" % int(g.money))

	# the bet is not saved, and loading clears one
	g.new_game("joru")
	g.money = 150
	g.place_wager("karma", 25)
	g.save_game()
	var cf := ConfigFile.new()
	cf.load("user://wager_check_save.cfg")
	_check(not cf.has_section_key("game", "wager"), "the bet should not be in the save")
	g.load_game()
	_check(int(g.wager) == 0, "loading should clear a bet")

	# the fun stats reach the results rows
	g.new_game("joru")
	g.apply_race_result(_results(4, {"hats": 3, "near_misses": 4, "overtakes": 6, "best_streak": 2}))
	var lr: Dictionary = g.last_result
	_check(int(lr["hats"]) == 3 and int(lr["near_misses"]) == 4 and int(lr["overtakes"]) == 6 and int(lr["best_streak"]) == 2, "fun stats missing from the result")

	# the voice settings: a muted player stays muted, a new player gets the default
	var path := "user://wager_check_settings.cfg"
	var old := ConfigFile.new()
	old.set_value("audio", "music", 0.0)
	old.set_value("audio", "sfx", 0.0)
	old.save(path)
	g.voice_volume = 0.5
	g.call("_load_settings")
	_check(is_zero_approx(float(g.voice_volume)), "muted file with no voice key should load voices at 0, got %f" % float(g.voice_volume))
	var old2 := ConfigFile.new()
	old2.set_value("audio", "music", 0.8)
	old2.set_value("audio", "sfx", 0.9)
	old2.save(path)
	g.voice_volume = 0.1
	g.call("_load_settings")
	_check(is_equal_approx(float(g.voice_volume), 0.85), "unmuted file with no voice key should load voices at 0.85, got %f" % float(g.voice_volume))
	var old3 := ConfigFile.new()
	old3.set_value("audio", "music", 0.0)
	old3.set_value("audio", "sfx", 0.0)
	old3.set_value("audio", "voice", 0.6)
	old3.set_value("audio", "voice_language", 2)
	old3.save(path)
	g.call("_load_settings")
	_check(is_equal_approx(float(g.voice_volume), 0.6) and int(g.voice_language) == 2, "a saved voice setting should win, got %f / %d" % [float(g.voice_volume), int(g.voice_language)])
	g.voice_volume = 0.3
	g.voice_language = 1
	g.save_settings()
	var back := ConfigFile.new()
	back.load(path)
	_check(is_equal_approx(float(back.get_value("audio", "voice", -1.0)), 0.3) and int(back.get_value("audio", "voice_language", -1)) == 1, "voice settings were not saved")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://wager_check_save.cfg"))

	print("wager check: %s" % ("all good" if failed == 0 else "%d FAILED" % failed))
	quit()
