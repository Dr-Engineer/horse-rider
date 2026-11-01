class_name SelectStage
extends Node3D
## Two riders side by side for the rider select, facing the camera. The chosen one walks in place.

var stages: Dictionary = {}
var cam: Camera3D
var _t := 0.0
var _focus := "joru"


func _ready() -> void:
	var env := {
		"sky_top": Color("1f4fa8"), "sky_horizon": Color("bfe0e8"), "sun_color": Color(1.0, 0.92, 0.75), "sun_energy": 0.85,
		"ambient": Color(0.78, 0.8, 1.0), "ambient_energy": 0.7, "sun_rot": Vector3(-38.0, 38.0, 0.0), "cloud_cover": 0.4,
		"fog_color": Color("d8e6e8"), "fog_density": 0.5, "fog_begin": 30.0, "fog_end": 220.0,
	}
	ArtKit.make_world(self, env)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(300, 300)
	ground.mesh = pm
	var gm := ArtKit.toon(0.85).duplicate() as ShaderMaterial
	gm.set_shader_parameter("tint", Color("d8be8e"))
	ground.material_override = gm
	add_child(ground)
	var players: Variant = Game.gd_const("PLAYERS", {})
	var xs := {"joru": 2.3, "yangkyi": -2.3}
	var yaw := {"joru": 0.42, "yangkyi": -0.42}
	for id: String in ["joru", "yangkyi"]:
		var st := RiderStage.new()
		add_child(st)
		var entry: Dictionary = {}
		if players is Dictionary and (players as Dictionary).has(id):
			entry = (players as Dictionary)[id]
		RiderStage.dress_from_data(st, entry, true, Game.gd_const("HORSES", {}))
		st.position = Vector3(xs[id], 0.0, 0.0)
		st.rotation.y = yaw[id]
		stages[id] = st
	cam = Camera3D.new()
	cam.fov = 38.0
	cam.current = true
	add_child(cam)
	focus_on("joru")


func focus_on(id: String) -> void:
	_focus = id
	for k: String in stages:
		var st: RiderStage = stages[k]
		if k == id:
			st.play("walk", "ride_slow", 1.0)
		else:
			st.play("idle", "ride_slow", 0.5)


func _process(delta: float) -> void:
	_t += delta
	var sway := sin(_t * 0.35) * 0.35
	cam.position = Vector3(sway, 1.9, -9.0)
	cam.look_at(Vector3(sway * 0.4, 1.35, 0.0))
