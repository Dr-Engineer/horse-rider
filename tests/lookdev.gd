# Art check: shows horse and rider through the real shaders and saves a strip of frames.
# Args after --: <out_prefix> <horse_anim> <rider_anim> <cam: side|chase|front|close|face|back> [count] [pieces] [weapon]
# pieces: comma list of rider meshes to show, default body_chuba,head_young,hat_felt. weapon: name in assets/models/weapons.
extends Node3D

var toon_shader := preload("res://shaders/toon.gdshader")
var ink_shader := preload("res://shaders/ink.gdshader")
var atlas := preload("res://assets/atlas/atlas.png")


func make_mat(cls: float, rim: float = 0.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = toon_shader
	m.set_shader_parameter("atlas", atlas)
	m.set_shader_parameter("class_id", cls)
	m.set_shader_parameter("rim_strength", rim)
	return m


func apply_mat(n: Node, m: Material) -> void:
	if n is MeshInstance3D:
		(n as MeshInstance3D).material_override = m
	for c in n.get_children():
		apply_mat(c, m)


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var prefix: String = args[0] if args.size() > 0 else "/tmp/lookdev"
	var horse_anim: String = args[1] if args.size() > 1 else "gallop"
	var rider_anim: String = args[2] if args.size() > 2 else "ride"
	var cam_mode: String = args[3] if args.size() > 3 else "side"
	var count: int = int(args[4]) if args.size() > 4 else 1
	var show: PackedStringArray = (args[5] if args.size() > 5 else "body_chuba,head_young,hat_felt").split(",")
	var weapon: String = args[6] if args.size() > 6 else ""

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("bfe0e8")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.74, 0.76, 0.95)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -38, 0)
	sun.light_energy = 0.45
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 40.0
	add_child(sun)

	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(200, 200)
	ground.mesh = pm
	var gm := make_mat(0.85)
	gm.set_shader_parameter("tint", Color("d8be8e"))
	ground.material_override = gm
	add_child(ground)

	var horse: Node3D = load("res://assets/models/horse.glb").instantiate()
	add_child(horse)
	apply_mat(horse, make_mat(0.2, 0.25))
	var hap: AnimationPlayer = horse.find_children("*", "AnimationPlayer", true, false)[0]
	var skel: Skeleton3D = horse.find_children("*", "Skeleton3D", true, false)[0]
	var att := BoneAttachment3D.new()
	att.bone_name = "saddle"
	skel.add_child(att)
	var rider: Node3D = load("res://assets/models/rider.glb").instantiate()
	if horse_anim == "none":
		# Solo mode: rider on the ground for the off-horse animations.
		horse.visible = false
		add_child(rider)
		horse_anim = "idle"
	else:
		att.add_child(rider)
		rider.position = Vector3(0.0, -0.9, 0.0)
	var rider_mat := make_mat(0.2, 0.25)
	apply_mat(rider, rider_mat)
	for piece_mi: MeshInstance3D in rider.find_children("*", "MeshInstance3D", true, false):
		piece_mi.visible = String(piece_mi.name) in show
	if weapon != "":
		var rskel: Skeleton3D = rider.find_children("*", "Skeleton3D", true, false)[0]
		var gatt := BoneAttachment3D.new()
		gatt.bone_name = "grip.R"
		rskel.add_child(gatt)
		var wnode: Node3D = load("res://assets/models/weapons/%s.glb" % weapon).instantiate()
		gatt.add_child(wnode)
		apply_mat(wnode, rider_mat)
	var rap: AnimationPlayer = rider.find_children("*", "AnimationPlayer", true, false)[0]
	for mi: MeshInstance3D in horse.find_children("*", "MeshInstance3D", true, false):
		mi.set_instance_shader_parameter("slot_c", Color("8c5a33"))
		mi.set_instance_shader_parameter("slot_d", Color("211c1f"))
		mi.set_instance_shader_parameter("slot_b", Color("d63a22"))
	for mi: MeshInstance3D in rider.find_children("*", "MeshInstance3D", true, false):
		mi.set_instance_shader_parameter("slot_a", Color("7a1c22"))
		mi.set_instance_shader_parameter("slot_b", Color("f2b632"))
	hap.get_animation(horse_anim).loop_mode = Animation.LOOP_LINEAR
	rap.get_animation(rider_anim).loop_mode = Animation.LOOP_LINEAR
	hap.play(horse_anim)
	rap.play(rider_anim)
	hap.pause()
	rap.pause()

	var cam := Camera3D.new()
	add_child(cam)
	match cam_mode:
		"side":
			cam.look_at_from_position(Vector3(5.0, 1.5, 0.0), Vector3(0, 1.25, 0))
		"chase":
			cam.look_at_from_position(Vector3(0.6, 2.7, 5.2), Vector3(0, 1.5, -2.0))
		"front":
			cam.look_at_from_position(Vector3(-2.4, 1.6, -4.2), Vector3(0, 1.3, 0))
		"close":
			cam.look_at_from_position(Vector3(2.4, 2.1, -1.6), Vector3(0, 1.9, 0))
		"face":
			cam.look_at_from_position(Vector3(-0.9, 2.3, -1.6), Vector3(0, 2.15, 0))
		"back":
			cam.look_at_from_position(Vector3(0.0, 2.3, 4.5), Vector3(0, 1.9, 0))
		"waist":
			cam.look_at_from_position(Vector3(0.9, 1.0, -1.5), Vector3(0, 0.95, 0))
		"soloback":
			cam.look_at_from_position(Vector3(-2.0, 1.4, 3.0), Vector3(0, 0.95, 0))
		"portrait":
			cam.look_at_from_position(Vector3(-0.35, 1.78, -1.05), Vector3(0, 1.7, 0))
		"sidesolo":
			cam.look_at_from_position(Vector3(3.2, 1.2, -0.5), Vector3(0, 1.0, -0.5))
		"back34":
			cam.look_at_from_position(Vector3(2.0, 2.3, 3.2), Vector3(0, 1.6, 0))
		"solo":
			cam.look_at_from_position(Vector3(2.6, 1.5, -3.0), Vector3(0, 0.9, 0))
		"tack":
			cam.look_at_from_position(Vector3(2.4, 1.7, -0.9), Vector3(0, 1.25, 0))
		"bhead":
			cam.look_at_from_position(Vector3(0.9, 2.55, 2.3), Vector3(0, 2.1, 0))
	cam.fov = 45.0

	var quad := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(2, 2)
	quad.mesh = qm
	var im := ShaderMaterial.new()
	im.shader = ink_shader
	im.render_priority = 100
	quad.material_override = im
	quad.extra_cull_margin = 16384.0
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(quad)

	var hlen: float = hap.get_animation(horse_anim).length
	var rlen: float = rap.get_animation(rider_anim).length
	for i in count:
		var t: float = float(i) / float(count)
		hap.seek(t * hlen, true)
		rap.seek(t * rlen, true)
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path := "%s_%d.png" % [prefix, i]
		get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()
