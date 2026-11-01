extends Node
## Photographs course events from the chase camera height, with hazards, scenery and shaders as they appear in a race.
## Usage: Godot --path . res://tests/hazard_view.tscn -- <out_dir> <course> <season> <type>[,<type>...] [count]
## Takes one shot per event, named <type>_<index>.png, from 13 m short of the event at rider-chase height.

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "user://hazard_view"
	var ci: int = int(args[1]) if args.size() > 1 else 0
	var season: int = int(args[2]) if args.size() > 2 else 0
	var types: PackedStringArray = (args[3] if args.size() > 3 else "mud").split(",")
	var limit: int = int(args[4]) if args.size() > 4 else 3
	var back: float = float(args[5]) if args.size() > 5 else 13.0      # metres short of the event
	var cam_h: float = float(args[6]) if args.size() > 6 else 3.2      # camera height above the road
	var look_h: float = float(args[7]) if args.size() > 7 else 0.8     # height of the point looked at
	var tag: String = args[8] if args.size() > 8 else ""               # appended to file names
	var sim_secs: float = float(args[9]) if args.size() > 9 else 0.0   # seconds of hazard simulation before each shot (herds wake and walk)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var race := Race.new()
	race.auto_begin = false
	add_child(race)
	race.begin({"season": season, "seed": 11, "course_index": ci, "weapon_id": "sword", "ranged_id": ""})
	race.paused_for_ui = true
	await get_tree().process_frame
	var cam := Camera3D.new()
	cam.far = 3000.0
	cam.near = 0.15
	cam.fov = 66.0
	add_child(cam)
	cam.current = true
	if race.cam_rig != null:
		race.cam_rig.queue_free()
		race.cam_rig = null
	if race.hud != null:
		(race.hud as CanvasLayer).visible = false
	var counts := {}
	for t: String in types:
		counts[t] = 0
	var spots: Array[Dictionary] = []
	for e: Dictionary in race.hazards.statics:
		if counts.has(e["type"]) and int(counts[e["type"]]) < limit:
			spots.append({"type": e["type"], "s": e["s"], "d": e["d"], "i": counts[e["type"]]})
			counts[e["type"]] = int(counts[e["type"]]) + 1
	for m: Dictionary in race.hazards.movers:
		var k: String = m["kind"]
		if counts.has(k) and int(counts[k]) < limit:
			spots.append({"type": k, "s": m["s"], "d": m["d"], "i": counts[k]})
			counts[k] = int(counts[k]) + 1
	for st: Dictionary in race.hazards.stewards:
		if counts.has("steward") and int(counts["steward"]) < limit:
			spots.append({"type": "steward", "s": st["s"], "d": st["d"], "i": counts["steward"]})
			counts["steward"] = int(counts["steward"]) + 1
	for spot: Dictionary in spots:
		race.hazards.update_visuals()
		var s: float = float(spot["s"])
		var d: float = clampf(float(spot["d"]), -race.track.half_width_at(s), race.track.half_width_at(s))
		var pos := race.track.point(maxf(s - back, 1.0), d * 0.5, cam_h)
		var look := race.track.point(s, d, look_h)
		cam.look_at_from_position(pos, look, Vector3.UP)
		# movers and stewards get a few frames of simulation, so walkers show a stride
		if sim_secs > 0.0:
			# everyone stands short of the event, which wakes herds and sets caravans and sheep going
			for r: Rider in race.riders:
				r.s = maxf(s - 60.0, 1.0)
			if String(spot["type"]) == "steward":
				# a fallen rider a little way off sends the steward running
				race.riders[0].state = "down"
				race.riders[0].s = s + 14.0
				race.riders[0].d = 0.0
			var frames := int(sim_secs * 60.0)
			for k in frames:
				race.hazards.update(1.0 / 60.0, race.riders)
				race.hazards.update_visuals()
				await get_tree().process_frame
		for k in 6:
			race.hazards.update_visuals()
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path := "%s/%s%s_%d.png" % [out_dir, spot["type"], tag, spot["i"]]
		get_viewport().get_texture().get_image().save_png(path)
		print("shot ", path, " s=%.0f d=%.1f" % [s, d])
	get_tree().quit()
