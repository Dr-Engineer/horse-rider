# Renders every rider's head and shoulders from the real rider.glb and the wardrobe in data/game_data.gd, through the
# toon and ink shaders, into assets/ui/portraits/<id>.png (48x48, pixel-art scale). Needs a window, not --headless.
# Usage: tools/make_portraits.sh   (or: Godot --path . -s res://tools/make_portraits.gd -- [id ...])
extends SceneTree

const OUT_DIR := "res://assets/ui/portraits/"
const SIZE := 48
const SUPER := 4


func _initialize() -> void:
	_run.call_deferred()


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	await _wait(5)
	var game: Node = root.get_node("Game")
	var only: Array = OS.get_cmdline_user_args()
	var entries: Dictionary = {}
	for table in ["PLAYERS", "RIVALS"]:
		var t: Variant = game.gd_const(table, {})
		if t is Dictionary:
			for k: Variant in (t as Dictionary).keys():
				entries[str(k)] = (t as Dictionary)[k]
	if entries.is_empty():
		push_error("make_portraits: data/game_data.gd has no PLAYERS or RIVALS")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	var vp := SubViewport.new()
	vp.size = Vector2i(SIZE * SUPER, SIZE * SUPER)
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var world := Node3D.new()
	vp.add_child(world)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("2a2a66")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.82, 0.84, 1.0)
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-30, 150, 0)
	sun.light_energy = 1.0
	sun.shadow_enabled = false
	world.add_child(sun)
	var ink := ArtKit.ink_pass()
	(ink.material_override as ShaderMaterial).set_shader_parameter("width_px", 1.25 * SUPER)
	world.add_child(ink)
	var cam := Camera3D.new()
	cam.fov = 28.0
	cam.current = true
	world.add_child(cam)

	var made := 0
	for id: String in entries.keys():
		if not only.is_empty() and not only.has(id):
			continue
		var stage := RiderStage.new()
		world.add_child(stage)
		RiderStage.dress_from_data(stage, entries[id], false, {})
		stage.pose("idle", "stand", 0.0)
		await _wait(4)
		var head := Vector3(0, 1.5, 0)
		var skels := stage.rider_root.find_children("*", "Skeleton3D", true, false)
		if skels.size() > 0:
			var skel: Skeleton3D = skels[0]
			var bi := skel.find_bone("head")
			if bi >= 0:
				head = (skel.global_transform * skel.get_bone_global_pose(bi)).origin
		cam.position = head + Vector3(0.4, 0.12, -1.95)
		cam.look_at(head + Vector3(0.0, 0.03, 0.0))
		await _wait(3)
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
		img.save_png(ProjectSettings.globalize_path(OUT_DIR + id + ".png"))
		print("portrait ", id)
		made += 1
		stage.queue_free()
		await _wait(1)
	print("portraits made: ", made)
	quit()
