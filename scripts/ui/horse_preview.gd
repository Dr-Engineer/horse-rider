class_name HorsePreview
extends SubViewportContainer
## A small turntable of a horse (with your rider up) for the Stable. Drawn at the UI's pixel scale, so it's chunky.

var _vp: SubViewport
var _world: Node3D
var _stage: RiderStage
var _t := 0.0
var _cam: Camera3D


func _init(w: int = 200, h: int = 130) -> void:
	stretch = false
	custom_minimum_size = Vector2(w, h)
	size = Vector2(w, h)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vp = SubViewport.new()
	_vp.size = Vector2i(w, h)
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_DISABLED
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	_world = Node3D.new()
	_vp.add_child(_world)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("2a2a66")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.84, 0.86, 1.0)
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	_world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 35, 0)
	sun.light_energy = 1.0
	_world.add_child(sun)
	var floor_mesh := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 1.9
	disc.bottom_radius = 2.0
	disc.height = 0.12
	floor_mesh.mesh = disc
	var fm := ArtKit.toon(0.85).duplicate() as ShaderMaterial
	fm.set_shader_parameter("tint", Color("c9953f"))
	floor_mesh.material_override = fm
	floor_mesh.position.y = -0.06
	_world.add_child(floor_mesh)
	var ink := ArtKit.ink_pass()
	(ink.material_override as ShaderMaterial).set_shader_parameter("width_px", 1.0)
	_world.add_child(ink)
	_cam = Camera3D.new()
	_cam.fov = 34.0
	_cam.current = true
	_world.add_child(_cam)


func _ready() -> void:
	_cam.look_at_from_position(Vector3(0.0, 1.45, -4.5), Vector3(0.0, 1.0, 0.0))


## horse: {coat, mane, rug}. The rider is whoever you chose.
func show_horse(horse: Dictionary, wardrobe: Array, slot_a: Color, slot_b: Color) -> void:
	if _stage != null:
		_stage.queue_free()
	_stage = RiderStage.new()
	_world.add_child(_stage)
	_stage.build(wardrobe, slot_a, slot_b, horse, true)
	_stage.play("idle", "ride_slow", 0.8)


func _process(delta: float) -> void:
	_t += delta
	if _stage != null:
		_stage.rotation.y = _t * 0.7
