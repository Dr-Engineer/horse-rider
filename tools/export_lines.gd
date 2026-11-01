extends SceneTree
## Writes every English line the menus speak (rival cards, narrator pages, odd lines, side bets) to art/tools/voice_lines_game.json,
## so art/tools/make_voices.py can voice exactly what the game shows.
## Run: Godot --headless --path . --script res://tools/export_lines.gd

func _init() -> void:
	var rivals := {}
	for id: String in GameData.RIVALS:
		var lines: Dictionary = GameData.RIVALS[id].get("lines", {})
		var fb: Dictionary = StoryText.RIVALS.get(id, {})
		var out: Array[String] = []
		for kind: String in ["intro", "grudge", "win"]:
			for t: String in lines.get(kind, []):
				if not out.has(t):
					out.append(t)
			if fb.has(kind) and not out.has(String(fb[kind])):
				out.append(String(fb[kind]))
		rivals[id] = out
	var narrator := {}
	for pid: String in ["joru", "yangkyi"]:
		var pages: Array[String] = []
		pages.append_array(StoryText.intro_pages(pid))
		pages.append_array(StoryText.season_end_pages(pid, 0))
		pages.append_array(StoryText.season_end_pages(pid, 1))
		pages.append_array(StoryText.victory_pages(pid))
		narrator[StoryText.narrator(pid).to_lower()] = pages
	# The side bet: what each rival says when offering it, paying it and collecting it, exactly as StoryText.wager_line picks them
	# (a rival without lines of their own gets one of the generic ones).
	var wager := {}
	for id: String in GameData.RIVALS:
		var wl: Array[String] = []
		for kind: String in ["offer", "won", "lost"]:
			var t := StoryText.wager_line(id, kind)
			if t != "" and not wl.has(t):
				wl.append(t)
		wager[id] = wl
	var data := {
		"rivals": rivals,
		"narrator": narrator,
		"lose": StoryText.LOSE_LINES,
		"loan": StoryText.LOAN_LINES,
		"wager": wager,
	}
	var f := FileAccess.open("res://art/tools/voice_lines_game.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "  "))
	f.close()
	print("wrote voice_lines_game.json")
	quit()
