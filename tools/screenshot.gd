# Saves a rendered frame of a scene to a PNG so it can be reviewed.
# Usage: Godot --path <project> -s res://tools/screenshot.gd -- <scene.tscn> <out.png> [frames]
extends SceneTree


func _initialize() -> void:
	_capture()


func _capture() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("Usage: -- <scene.tscn> <out.png> [frames]")
		quit(2)
		return

	var packed := load(args[0]) as PackedScene
	if packed == null:
		push_error("Could not load scene: %s" % args[0])
		quit(3)
		return
	root.add_child(packed.instantiate())

	var frames := int(args[2]) if args.size() > 2 else 30
	for i in frames:
		await process_frame
	await RenderingServer.frame_post_draw

	var err := root.get_texture().get_image().save_png(args[1])
	if err != OK:
		push_error("Could not save %s: %s" % [args[1], error_string(err)])
	quit(0 if err == OK else 4)
