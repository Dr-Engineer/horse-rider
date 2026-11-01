# Flies a camera along a course and saves frames.
# Args: <out_prefix> [course] [season] [fraction ...]   (fractions of the course length, default 5 spots)
# Special: pass "bench" as the first fraction to time 240 frames of a flythrough instead.
extends Node3D

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var prefix: String = args[0] if args.size() > 0 else "/tmp/track"
	var ci: int = int(args[1]) if args.size() > 1 else 0
	var season: int = int(args[2]) if args.size() > 2 else 0
	var spots: Array[Vector4] = []   # fraction, yaw degrees (+ right), pitch degrees, height
	var bench := false
	for i in range(3, args.size()):
		if args[i] == "bench":
			bench = true
		elif args[i] == "sun" or args[i] == "lineup" or args[i] == "yaw":
			break
		elif args[i] in ["nofar", "noink", "noshadow", "nodress"]:
			continue
		else:
			var parts: PackedStringArray = String(args[i]).split(":")
			spots.append(Vector4(float(parts[0]), float(parts[1]) if parts.size() > 1 else 0.0, float(parts[2]) if parts.size() > 2 else -6.0, float(parts[3]) if parts.size() > 3 else 2.8))
	if spots.is_empty():
		for f in [0.02, 0.2, 0.4, 0.6, 0.85]:
			spots.append(Vector4(f, 0.0, -6.0, 2.8))

	var t0 := Time.get_ticks_msec()
	var course := Courses.get_course(ci, season)
	var track := Track.new()
	track.build(course.segments, course.half_width)
	print(course.id, " length ", track.length, " clearance ", track.self_clearance())
	var world := Node3D.new()
	add_child(world)
	var t1 := Time.get_ticks_msec()
	var builder := TrackBuilder.new(track, course.biome)
	builder.build_into(world)
	var t2 := Time.get_ticks_msec()
	print("terrain ", t2 - t1, " ms, children ", world.get_child_count())
	var dressing_path := "res://scripts/race/track_dressing.gd"
	if ResourceLoader.exists(dressing_path):
		var rng := RandomNumberGenerator.new()
		rng.seed = 1
		var dress = load(dressing_path).new(track, course, rng)
		dress.build_into(world)
		print("dressing ", Time.get_ticks_msec() - t2, " ms")
	var made := ArtKit.make_world(self, course.env)
	if "nofar" in args:
		world.get_node("FarRange").visible = false
	if "noink" in args:
		made.ink.visible = false
	if "noshadow" in args:
		made.sun.shadow_enabled = false
	if "nodress" in args and world.has_node("Dressing"):
		world.get_node("Dressing").visible = false
	var cam := Camera3D.new()
	cam.far = 12000.0
	cam.fov = 62.0
	add_child(cam)

	if args.has("lineup"):
		# Props side by side on flat sand, front-on, for silhouette checks. Names follow "lineup".
		var names: Array[String] = []
		var seen := false
		for a in args:
			if a == "yaw":
				break
			if seen:
				names.append(a)
			elif a == "lineup":
				seen = true
		var x := 0.0
		var origin := track.point(300.0, 0.0, 0.0)
		var floor_mesh := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(400, 120)
		floor_mesh.mesh = plane
		var fm := StandardMaterial3D.new()
		fm.albedo_color = Color("d8be8e")
		floor_mesh.material_override = fm
		floor_mesh.position = origin + Vector3(0, -0.05, 0)
		add_child(floor_mesh)
		var total := 0.0
		for n in names:
			var node := ArtKit.prop(n)
			add_child(node)
			var box: AABB = (node.get_child(0) as MeshInstance3D).get_aabb() if node.get_child_count() > 0 and node.get_child(0) is MeshInstance3D else AABB(Vector3.ZERO, Vector3(4, 4, 4))
			var w := maxf(box.size.x, box.size.z)
			node.position = origin + Vector3(x + w * 0.5, 0.0, 0.0)
			node.rotation.y = deg_to_rad(float(args[args.find("yaw") + 1])) if args.has("yaw") else 0.0
			x += w + 1.5
			total = x
		cam.global_transform = Transform3D(Basis.looking_at(Vector3(0, -0.28, -1.0), Vector3.UP), origin + Vector3(total * 0.5, 9.0 + total * 0.18, total * 0.55 + 12.0))
		cam.fov = 40.0
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s_lineup.png" % prefix)
		get_tree().quit()
		return
	if args.has("sun"):
		var sun: DirectionalLight3D = made.sun
		var toward := sun.global_transform.basis.z.normalized()
		cam.global_transform = Transform3D(Basis.looking_at(toward, Vector3.UP), track.point(300.0, 0.0, 3.0))
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s_sun.png" % prefix)
		get_tree().quit()
		return
	if bench:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		var n := 0
		var vp := get_viewport().get_viewport_rid()
		RenderingServer.viewport_set_measure_render_time(vp, true)
		var gpu := 0.0
		var cpu := 0.0
		var start := Time.get_ticks_usec()
		var s := 40.0
		while n < 360:
			s = 40.0 + (track.length - 120.0) * float(n) / 360.0
			cam.global_transform = track.frame(s, 0.0, 2.8)
			cam.rotate_object_local(Vector3.RIGHT, deg_to_rad(-6.0))
			await get_tree().process_frame
			n += 1
			if n > 30:
				gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
				cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp)
		print("gpu ms ", gpu / float(n - 30), " cpu ms ", cpu / float(n - 30))
		var ms := (Time.get_ticks_usec() - start) / 1000.0 / n
		print("frame ms avg ", ms, " draw calls ", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), " prims ", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
		get_tree().quit()
		return

	for i in spots.size():
		var sp: Vector4 = spots[i]
		var s: float = sp.x * track.length
		var f := track.frame(s, 0.0, sp.w)
		cam.global_transform = f
		cam.rotate_object_local(Vector3.UP, deg_to_rad(-sp.y))
		cam.rotate_object_local(Vector3.RIGHT, deg_to_rad(sp.z))
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s_%d.png" % [prefix, i])
	get_tree().quit()
