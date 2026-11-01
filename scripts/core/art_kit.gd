class_name ArtKit
extends RefCounted
## Shared materials and scene dressing helpers, so everything goes through the one look.

const CLASS_RIDER := 0.2
const CLASS_PROP := 0.5
const ATLAS_PATH := "res://assets/atlas/atlas.png"

static var _materials: Dictionary = {}
static var _props: Dictionary = {}

## Walk-cycle numbers per animal for shaders/toon_walker.gdshader. Model space (Godot): -Z is forward, +Y is up.
##   hip     height of the hip joint, just under the belly: everything below it swings
##   gait    0 four-beat walk, 1 diagonal trot        swing  leg angle in radians at full stride
##   bob     body rise in metres                      neck   (z, y) the head pivots about, nod radians
##   stride  metres walked per full cycle, so callers can turn distance into a phase
const WALKERS := {
	"yak": {"hip": 0.5, "gait": 0.0, "swing": 0.4, "bob": 0.03, "neck": Vector2(-1.1, 1.2), "nod": 0.12, "stride": 1.9},
	"mule": {"hip": 0.56, "gait": 0.8, "swing": 0.4, "bob": 0.035, "neck": Vector2(-0.95, 1.3), "nod": 0.14, "stride": 2.1},
	"mule_b": {"hip": 0.56, "gait": 0.8, "swing": 0.4, "bob": 0.035, "neck": Vector2(-0.95, 1.3), "nod": 0.14, "stride": 2.1},
	"sheep": {"hip": 0.3, "gait": 1.0, "swing": 0.6, "bob": 0.025, "neck": Vector2(-0.45, 0.6), "nod": 0.12, "stride": 0.85},
	"dog": {"hip": 0.34, "gait": 1.0, "swing": 0.55, "bob": 0.03, "neck": Vector2(-0.5, 0.6), "nod": 0.1, "stride": 1.2},
	"wolf": {"hip": 0.42, "gait": 1.0, "swing": 0.6, "bob": 0.035, "neck": Vector2(-0.6, 0.66), "nod": 0.12, "stride": 1.3},
	"kiang": {"hip": 0.72, "gait": 1.0, "swing": 0.45, "bob": 0.04, "neck": Vector2(-0.8, 1.25), "nod": 0.12, "stride": 2.1},
}
## The sky colours of the world last built by make_world, so puddles and the like can carry the sky.
static var sky_top_colour := Color("1f4fa8")
static var sky_horizon_colour := Color("bfe0e8")


static func toon(class_id: float = CLASS_PROP, rim: float = 0.0) -> ShaderMaterial:
	var key := "%f_%f" % [class_id, rim]
	if _materials.has(key):
		return _materials[key]
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/toon.gdshader")
	m.set_shader_parameter("atlas", load(ATLAS_PATH))
	m.set_shader_parameter("class_id", class_id)
	m.set_shader_parameter("rim_strength", rim)
	_materials[key] = m
	return m


## Put the toon material on every mesh under a node.
static func apply(node: Node, material: Material) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = material
	for child in node.get_children():
		apply(child, material)


## Instance a prop from assets/models/props/<prop>.glb with the toon material. Meshes named "flags*" get the
## waving flag material instead.
static func prop(prop_name: String) -> Node3D:
	var path := "res://assets/models/props/%s.glb" % prop_name
	if not _props.has(path):
		_props[path] = load(path) if ResourceLoader.exists(path) else null
	if _props[path] == null:
		push_warning("ArtKit.prop: no prop called '%s'" % prop_name)
		return Node3D.new()
	var node: Node3D = (_props[path] as PackedScene).instantiate()
	apply(node, toon(CLASS_PROP))
	_apply_flags(node)
	return node


static func _apply_flags(node: Node) -> void:
	if node is MeshInstance3D and String(node.name).to_lower().begins_with("flags"):
		(node as MeshInstance3D).material_override = flag_material()
		(node as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	elif node is MeshInstance3D and String(node.name).to_lower().begins_with("crowd"):
		(node as MeshInstance3D).material_override = crowd_material()
		(node as MeshInstance3D).extra_cull_margin = 0.5
	for child in node.get_children():
		_apply_flags(child)


## Ground cover: toon bands, sway, no depth write (so no ink outline).
static func grass_material() -> ShaderMaterial:
	if _materials.has("grass"):
		return _materials["grass"]
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/grass.gdshader")
	m.set_shader_parameter("atlas", load(ATLAS_PATH))
	_materials["grass"] = m
	return m


static func flag_material() -> ShaderMaterial:
	if _materials.has("flag"):
		return _materials["flag"]
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/flag.gdshader")
	m.set_shader_parameter("atlas", load(ATLAS_PATH))
	m.set_shader_parameter("class_id", CLASS_PROP)
	_materials["flag"] = m
	return m


## The toon material with a little life in it for crowd props: people bob, hop and wave at their own phases.
static func crowd_material() -> ShaderMaterial:
	if _materials.has("crowd"):
		return _materials["crowd"]
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/toon_crowd.gdshader")
	m.set_shader_parameter("atlas", load(ATLAS_PATH))
	m.set_shader_parameter("class_id", CLASS_PROP)
	_materials["crowd"] = m
	return m


## The mud patch material (shaders/mud.gdshader). Terrain ink class, so no outline. Puddles pick up the sky colours.
static func mud_material() -> ShaderMaterial:
	if _materials.has("mud"):
		return _materials["mud"]
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/mud.gdshader")
	_materials["mud"] = m
	_tint_mud(m)
	return m


static func _tint_mud(m: ShaderMaterial) -> void:
	var lo := sky_top_colour.lerp(sky_horizon_colour, 0.55)
	m.set_shader_parameter("sky_lo", lo)
	m.set_shader_parameter("sky_hi", sky_horizon_colour.lerp(Color.WHITE, 0.25))
	m.set_shader_parameter("sky_mix", 0.0)


## The toon material with a walk cycle (shaders/toon_walker.gdshader).
static func walker_material() -> ShaderMaterial:
	if _materials.has("walker"):
		return _materials["walker"]
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/toon_walker.gdshader")
	m.set_shader_parameter("atlas", load(ATLAS_PATH))
	m.set_shader_parameter("class_id", CLASS_PROP)
	_materials["walker"] = m
	return m


## A prop whose legs can swing: yak, mule, sheep, dog or kiang. Any other name gives the plain prop, which ignores set_stride.
## Drive it with set_stride(node, phase, amp) each frame.
static func prop_walker(prop_name: String) -> Node3D:
	var node := prop(prop_name)
	if not WALKERS.has(prop_name):
		return node
	var cfg: Dictionary = WALKERS[prop_name]
	var neck: Vector2 = cfg["neck"]
	var meshes: Array = []
	var personal := fposmod(float(node.get_instance_id()) * 0.6180339, 1.0)
	for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = walker_material()
		mi.set_instance_shader_parameter("walk_cfg", Vector4(cfg["hip"], cfg["gait"], cfg["swing"], cfg["bob"]))
		mi.set_instance_shader_parameter("head_cfg", Vector4(neck.x, neck.y, cfg["nod"], personal))
		mi.extra_cull_margin = 0.6
		meshes.append(mi)
	node.set_meta("walker_meshes", meshes)
	node.set_meta("walker_stride", float(cfg["stride"]))
	return node


## Swings a prop_walker's legs. phase is in radians and should grow with the distance walked (TAU per stride, see
## walker_stride_length); amp runs 0 (standing, only the head nods) to 1 (full stride).
static func set_stride(node: Node, phase: float, amp: float) -> void:
	if node == null or not node.has_meta("walker_meshes"):
		return
	for mi: MeshInstance3D in node.get_meta("walker_meshes"):
		if is_instance_valid(mi):
			mi.set_instance_shader_parameter("stride_phase", phase)
			mi.set_instance_shader_parameter("stride_amp", amp)


## Metres a prop_walker covers per full cycle, so distance walked divided by this, times TAU, is the phase.
static func walker_stride_length(node: Node) -> float:
	return float(node.get_meta("walker_stride", 1.5)) if node != null else 1.5


## The first mesh in a prop's GLB, for MultiMesh scatter. Cached.
static func prop_mesh(prop_name: String) -> Mesh:
	var key := "mesh_" + prop_name
	if _props.has(key):
		return _props[key]
	var holder := prop(prop_name)
	var found: Mesh = null
	var stack: Array[Node] = [holder]
	while not stack.is_empty() and found == null:
		var n: Node = stack.pop_back()
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null and not String(n.name).to_lower().begins_with("flags"):
			found = (n as MeshInstance3D).mesh
		for c in n.get_children():
			stack.append(c)
	holder.free()
	_props[key] = found
	return found


## WorldEnvironment (flat ambient, linear tonemap, depth fog, banded sky), the sun with sharp shadows and the ink
## pass. Returns {environment, sun, ink}.
static func make_world(parent: Node3D, env: Dictionary) -> Dictionary:
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load("res://shaders/sky.gdshader")
	var horizon: Color = env.get("sky_horizon", Color("bfe0e8"))
	sky_top_colour = env.get("sky_top", Color("1f4fa8"))
	sky_horizon_colour = horizon
	_tint_mud(mud_material())
	sky_mat.set_shader_parameter("top_color", env.get("sky_top", Color("1f4fa8")))
	sky_mat.set_shader_parameter("horizon_color", horizon)
	var top: Color = env.get("sky_top", Color("1f4fa8"))
	var mid := top.lerp(horizon, 0.5)
	mid = Color.from_hsv(mid.h, minf(mid.s * 1.5, 1.0), mid.v)
	sky_mat.set_shader_parameter("mid_color", env.get("sky_mid", mid))
	sky_mat.set_shader_parameter("sun_color", env.get("sun_color", Color(1, 0.95, 0.8)).lerp(Color.WHITE, 0.35))
	sky_mat.set_shader_parameter("cloud_cover", env.get("cloud_cover", 0.5))
	sky_mat.set_shader_parameter("cloud_scale", env.get("cloud_scale", 1.1))
	sky_mat.set_shader_parameter("sun_size", env.get("sun_size", 0.03))
	sky_mat.set_shader_parameter("cloud_light", env.get("cloud_light", Color(1.0, 0.99, 0.95)))
	sky_mat.set_shader_parameter("cloud_shade", env.get("cloud_shade", horizon.lerp(Color("9db4de"), 0.55)))
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	sky.process_mode = Sky.PROCESS_MODE_QUALITY

	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = env.get("ambient", Color(0.85, 0.87, 1.0))
	e.ambient_light_energy = env.get("ambient_energy", 0.62)
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	e.fog_enabled = true
	e.fog_mode = Environment.FOG_MODE_DEPTH
	e.fog_light_color = env.get("fog_color", horizon)
	e.fog_light_energy = 1.0
	e.fog_density = env.get("fog_density", 0.9)
	e.fog_depth_begin = env.get("fog_begin", 60.0)
	e.fog_depth_end = env.get("fog_end", 3500.0)
	e.fog_depth_curve = env.get("fog_curve", 1.5)
	e.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.environment = e
	we.name = "WorldEnvironment"
	parent.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = env.get("sun_rot", Vector3(-42.0, -38.0, 0.0))
	sun.light_color = env.get("sun_color", Color(1.0, 0.94, 0.82))
	sun.light_energy = env.get("sun_energy", 0.5)
	sun.light_specular = 0.0
	sun.shadow_enabled = true
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	sun.light_angular_distance = 0.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_split_1 = 0.3
	sun.directional_shadow_max_distance = 150.0
	sun.directional_shadow_blend_splits = false
	parent.add_child(sun)

	var ink := ink_pass()
	parent.add_child(ink)
	return {"environment": we, "sun": sun, "ink": ink}


## Full-screen ink line pass. Add one to the scene.
static func ink_pass() -> MeshInstance3D:
	var quad := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(2, 2)
	quad.mesh = qm
	var im := ShaderMaterial.new()
	im.shader = load("res://shaders/ink.gdshader")
	im.render_priority = 100
	quad.material_override = im
	quad.extra_cull_margin = 16384.0
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	quad.name = "InkPass"
	return quad
