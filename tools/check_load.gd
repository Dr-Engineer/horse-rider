# Loads every UI/meta script with autoloads present, so compile errors show up. Usage:
#   Godot --headless --path . -s res://tools/check_load.gd [-- extra/res/paths.gd ...]
extends SceneTree


func _initialize() -> void:
	var paths: Array[String] = ["res://scripts/core/game.gd", "res://scripts/core/sfx.gd", "res://scripts/core/input_setup.gd"]
	var dir := DirAccess.open("res://scripts/ui")
	if dir != null:
		for f in dir.get_files():
			if f.ends_with(".gd"):
				paths.append("res://scripts/ui/" + f)
	for extra in OS.get_cmdline_user_args():
		paths.append(extra)
	var bad := 0
	for p in paths:
		var s := ResourceLoader.load(p, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as GDScript
		if s == null or not s.can_instantiate() and not s.is_abstract():
			print("FAILED: ", p)
			bad += 1
	print("checked %d scripts, %d failed" % [paths.size(), bad])
	quit()
