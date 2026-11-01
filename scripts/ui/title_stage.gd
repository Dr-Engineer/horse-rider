class_name TitleStage
extends Node3D
## 3D backdrop for the title: a horse and rider gallop along a real course while the camera drifts around them.

var rider_stage: RiderStage
var cam: Camera3D
var rider_id := "joru"
var speed := 14.0
var track: Track
const START_S := 120.0
var _s := START_S
var _t := 0.0


func _ready() -> void:
	_build_country()
	_build_rider()
	cam = Camera3D.new()
	cam.fov = 42.0
	cam.far = 12000.0
	cam.current = true
	add_child(cam)
	_place_on_course()


## The real Grass Sea course, so the first thing anyone sees is the actual game world.
func _build_country() -> void:
	var course := Courses.get_course(1, 0)
	track = Track.new()
	track.build(course["segments"], course["half_width"])
	ArtKit.make_world(self, course.get("env", {}))
	var ground := ShaderMaterial.new()
	ground.shader = load("res://shaders/ground.gdshader")
	var road := ShaderMaterial.new()
	road.shader = load("res://shaders/road.gdshader")
	var tile_path := "res://assets/atlas/road_%s.png" % str(course.get("road", "grass"))
	if not ResourceLoader.exists(tile_path):
		tile_path = "res://assets/atlas/road_grass.png"
	road.set_shader_parameter("tile", load(tile_path))
	TrackBuilder.new(track, course["biome"]).build_into(self, ground, road)
	var rng := RandomNumberGenerator.new()
	rng.seed = 54
	TrackDressing.new(track, course, rng).build_into(self)


func _build_rider() -> void:
	rider_stage = RiderStage.new()
	add_child(rider_stage)
	var data: Variant = Game.gd_const("PLAYERS", {})
	var entry: Dictionary = {}
	if data is Dictionary and (data as Dictionary).has(rider_id):
		entry = (data as Dictionary)[rider_id]
	RiderStage.dress_from_data(rider_stage, entry, true, Game.gd_const("HORSES", {}))
	rider_stage.play("gallop", "ride")


func _place_on_course() -> void:
	rider_stage.transform = track.frame(_s, 2.5)
	var ang := sin(_t * 0.2) * 0.62 + 0.25
	var r := 6.4
	var local := Vector3(sin(ang) * r, 1.55 + 0.18 * sin(_t * 0.47), -cos(ang) * r)
	cam.global_position = rider_stage.transform * local
	cam.look_at(rider_stage.transform * Vector3(0.0, 1.3, 0.0))
	cam.h_offset = -1.5


func _process(delta: float) -> void:
	_t += delta
	_s += speed * delta
	if _s > track.length - 120.0:
		_s = START_S
	_place_on_course()
