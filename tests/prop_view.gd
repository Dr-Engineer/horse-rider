extends Node3D
## Art check: props in a row on flat ground, through the real world look and ink pass. Walkers (yak, mule, sheep, dog,
## kiang) are shown at the given stride phases, so the walk cycle can be judged from stills.
## Usage: Godot --path . res://tests/prop_view.tscn -- <out_prefix> <cam> <phases or -> <props> [amp] [course] [season]
##   cam:    side | three | front | back | top, one shot per phase.
##           sheet = a flat orthographic side view with one row of props per phase, all in one shot (a contact sheet).
##   phases: comma list of radians, e.g. 0,1.6,3.2,4.8. A prop that cannot walk ignores them. "-" takes one still.
##   props:  comma list of prop names; a name may end in :<scale>.
## Writes <out_prefix>_<phase index>.png, or <out_prefix>_sheet.png.


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var prefix: String = args[0] if args.size() > 0 else "user://prop_view"
	var cam_mode: String = args[1] if args.size() > 1 else "side"
	var phases_arg: String = args[2] if args.size() > 2 else "-"
	var names: PackedStringArray = (args[3] if args.size() > 3 else "yak,mule,sheep,dog,kiang").split(",")
	var amp: float = float(args[4]) if args.size() > 4 else 1.0
	var ci: int = int(args[5]) if args.size() > 5 else 1
	var season: int = int(args[6]) if args.size() > 6 else 0
	var phases: Array[float] = []
	if phases_arg == "-":
		phases.append(0.0)
	else:
		for p in phases_arg.split(","):
			phases.append(float(p))
	var course := Courses.get_course(ci, season)
	ArtKit.make_world(self, course.env)
	var sheet := cam_mode == "sheet"
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(160, 160)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("d8be8e")
	gm.roughness = 0.85
	ground.material_override = gm
	if sheet:
		ground.position.y = -500.0
	add_child(ground)
	var rows := phases.size() if sheet else 1
	var row_h := 3.0
	var all_nodes: Array = []     # per row: Array of nodes
	var width := 0.0
	for r in rows:
		var nodes: Array[Node3D] = []
		var z := 0.0
		for entry in names:
			var parts := entry.split(":")
			var prop_name := parts[0]
			var k := float(parts[1]) if parts.size() > 1 else 1.0
			var n: Node3D = ArtKit.prop_walker(prop_name) if ArtKit.WALKERS.has(prop_name) else ArtKit.prop(prop_name)
			n.scale = Vector3.ONE * k
			add_child(n)
			var box := _aabb(n)
			var span := maxf(box.size.z, box.size.x) * k + 1.2
			n.position = Vector3(0, -float(r) * row_h, z - span * 0.5)
			z -= span
			nodes.append(n)
		width = -z
		all_nodes.append(nodes)
	var mid_z := -width * 0.5
	var cam := Camera3D.new()
	cam.near = 0.1
	cam.far = 800.0
	add_child(cam)
	var d := maxf(width * 1.1 + 2.0, 6.0)
	cam.fov = 30.0
	match cam_mode:
		"side":
			cam.look_at_from_position(Vector3(d, 1.2, mid_z), Vector3(0, 0.9, mid_z))
		"three":
			cam.look_at_from_position(Vector3(d * 0.8, 2.6, mid_z - d * 0.7), Vector3(0, 0.9, mid_z))
		"front":
			cam.look_at_from_position(Vector3(d * 0.3, 1.8, mid_z - d), Vector3(0, 0.9, mid_z))
		"back":
			cam.look_at_from_position(Vector3(d * 0.25, 2.4, mid_z + d), Vector3(0, 1.0, mid_z))
		"top":
			cam.look_at_from_position(Vector3(d * 0.3, d * 0.9, mid_z), Vector3(0, 0.0, mid_z))
		"sheet":
			cam.projection = Camera3D.PROJECTION_ORTHOGONAL
			var vp := get_viewport().get_visible_rect().size
			cam.size = maxf(float(rows) * row_h, (width + 1.5) * vp.y / vp.x)
			cam.look_at_from_position(Vector3(30.0, 1.4 - float(rows - 1) * row_h * 0.5, mid_z), Vector3(0, 1.4 - float(rows - 1) * row_h * 0.5, mid_z))
	if sheet:
		for r in rows:
			for n in all_nodes[r]:
				ArtKit.set_stride(n, phases[r], amp)
		await _shot("%s_sheet.png" % prefix)
	else:
		for i in phases.size():
			for n in all_nodes[0]:
				ArtKit.set_stride(n, phases[i], amp)
			await _shot("%s_%d.png" % [prefix, i])
	get_tree().quit()


func _shot(path: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("shot ", path)


func _aabb(n: Node) -> AABB:
	var box := AABB()
	var first := true
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		var b := mi.get_aabb()
		if first:
			box = b
			first = false
		else:
			box = box.merge(b)
	return box
