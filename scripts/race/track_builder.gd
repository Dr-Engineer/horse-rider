class_name TrackBuilder
extends RefCounted
## Turns a Track plus a biome definition into terrain, road, water and far-mountain meshes.
##
## Biome keys (all optional except colors): seed, half_width, rugged, mountain, mountain_start, mountain_end,
## right_drop, left_drop, drop_start, drop_end, bank_blend, snow_line, far_snow_line, horizon, rock_slope, fields,
## river {offset, width, depth}, lake {level}, ledges [{s0, s1, side, depth, start, end, noise}],
## notches [{s0, s1, depth}], road_tex (id of assets/atlas/road_<id>.png), road_skirt, colors {...}.

const CELL := 10.0
const CHUNK_CELLS := 16
const NEAR_RADIUS := 300.0
const FAR_CELL := 100.0
const FAR_MARGIN := 3600.0
const WATER_CELL := 3.5

var track: Track
var biome: Dictionary
var noise_a := FastNoiseLite.new()
var noise_b := FastNoiseLite.new()
var noise_c := FastNoiseLite.new()
var noise_far := FastNoiseLite.new()

var _dist: PackedFloat32Array
var _near_y: PackedFloat32Array
var _side: PackedFloat32Array
var _near_i: PackedInt32Array
var _heights: PackedFloat32Array
var _nx := 0
var _nz := 0
var _origin := Vector2.ZERO


func _init(p_track: Track, p_biome: Dictionary) -> void:
	track = p_track
	biome = p_biome
	var seed_value: int = biome.get("seed", 1)
	noise_a.seed = seed_value
	noise_a.frequency = 0.0022
	noise_a.fractal_octaves = 2
	noise_a.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	noise_b.seed = seed_value + 1
	noise_b.frequency = 0.018
	noise_b.fractal_octaves = 2
	noise_c.seed = seed_value + 2
	noise_c.frequency = 0.06
	noise_c.fractal_octaves = 1
	noise_far.seed = seed_value + 3
	noise_far.frequency = 0.0013
	noise_far.fractal_octaves = 3
	noise_far.fractal_type = FastNoiseLite.FRACTAL_RIDGED


# --- materials -----------------------------------------------------------------------------------------------

static func make_ground_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/ground.gdshader")
	return m


static func make_road_material(p_biome: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/road.gdshader")
	var id: String = p_biome.get("road_tex", "tea")
	var path := "res://assets/atlas/road_%s.png" % id
	var tex := load(path) as Texture2D
	if tex != null:
		# Mipmaps stop the pixel texture shimmering at distance; the import default has none.
		var img := tex.get_image()
		if img != null:
			img.generate_mipmaps()
			tex = ImageTexture.create_from_image(img)
		m.set_shader_parameter("tile", tex)
	return m


static func make_water_material(cell_scale: float = 1.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/water.gdshader")
	m.set_shader_parameter("cell", cell_scale)
	return m


# --- build ---------------------------------------------------------------------------------------------------

func build_into(parent: Node3D, ground_mat: Material = null, road_mat: Material = null) -> void:
	if ground_mat == null:
		ground_mat = make_ground_material()
	if road_mat == null:
		road_mat = make_road_material(biome)
	elif road_mat is ShaderMaterial and biome.has("road_tex"):
		# Callers pass their own road material; the course decides which texture it wears.
		var tex: Variant = make_road_material(biome).get_shader_parameter("tile")
		if tex != null:
			(road_mat as ShaderMaterial).set_shader_parameter("tile", tex)
	prepare()
	_build_near_chunks(parent, ground_mat)
	_build_far_range(parent, ground_mat)
	_build_road(parent, road_mat)
	_build_water(parent)


## Rasterises distance to the course. Called by build_into; call it yourself to query heights without building.
func prepare() -> void:
	if _nx > 0:
		return
	_rasterise_distance()


func _rasterise_distance() -> void:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in track.positions:
		lo = lo.min(Vector2(p.x, p.z))
		hi = hi.max(Vector2(p.x, p.z))
	lo -= Vector2.ONE * (NEAR_RADIUS + CELL)
	hi += Vector2.ONE * (NEAR_RADIUS + CELL)
	_origin = lo
	_nx = int(ceil((hi.x - lo.x) / CELL)) + 1
	_nz = int(ceil((hi.y - lo.y) / CELL)) + 1
	var total := _nx * _nz
	_dist = PackedFloat32Array()
	_dist.resize(total)
	_dist.fill(1e9)
	_near_y = PackedFloat32Array()
	_near_y.resize(total)
	_side = PackedFloat32Array()
	_side.resize(total)
	_near_i = PackedInt32Array()
	_near_i.resize(total)
	_heights = PackedFloat32Array()
	_heights.resize(total)
	_heights.fill(NAN)
	var radius_cells := int(NEAR_RADIUS / CELL) + 1
	for i in range(0, track.count, 3):
		var p := track.positions[i]
		var r := track.rights[i]
		var cx := int((p.x - lo.x) / CELL)
		var cz := int((p.z - lo.y) / CELL)
		for gz in range(maxi(cz - radius_cells, 0), mini(cz + radius_cells + 1, _nz)):
			var wz := lo.y + gz * CELL
			var dz := wz - p.z
			var row := gz * _nx
			for gx in range(maxi(cx - radius_cells, 0), mini(cx + radius_cells + 1, _nx)):
				var wx := lo.x + gx * CELL
				var dx := wx - p.x
				var dd := dx * dx + dz * dz
				var k := row + gx
				if dd < _dist[k]:
					_dist[k] = dd
					_near_y[k] = p.y
					_near_i[k] = i
					_side[k] = dx * r.x + dz * r.z


# --- terrain height ------------------------------------------------------------------------------------------

## River shape at a track sample: {offset, width, depth, drop_end}. With a "narrow" stretch (metres) the river squeezes
## in under the ledge there and opens out into a visible valley elsewhere.
func river_at(idx: int) -> Dictionary:
	var rv: Dictionary = biome.river
	var narrow := 1.0
	if rv.has("narrow"):
		narrow = 0.0
		if idx >= 0:
			var s := float(idx) * Track.STEP
			var n: Array = rv.narrow
			narrow = smoothstep(float(n[0]) - 70.0, float(n[0]) + 70.0, s) * (1.0 - smoothstep(float(n[1]) - 70.0, float(n[1]) + 70.0, s))
	return {
		"offset": lerpf(float(rv.get("open_offset", rv.offset)), float(rv.offset), narrow),
		"width": lerpf(float(rv.get("open_width", rv.width)), float(rv.width), narrow),
		"depth": lerpf(float(rv.get("open_depth", rv.depth)), float(rv.depth), narrow),
		"drop_end": lerpf(float(rv.get("open_end", biome.get("drop_end", 60.0))), float(biome.get("drop_end", 60.0)), narrow),
	}


## Height of the land relative to the nearest road point: d_signed is metres right of the road, idx the nearest
## track sample (or -1 when unknown, which skips the stretches of ledge and notch).
func land_offset(x: float, z: float, d_signed: float, idx: int = -1) -> float:
	var d := absf(d_signed)
	var rugged: float = biome.get("rugged", 18.0)
	var mountain: float = biome.get("mountain", 160.0)
	var a := noise_a.get_noise_2d(x, z)
	var b := noise_b.get_noise_2d(x, z)
	var c := noise_c.get_noise_2d(x, z)
	var near_fade := 1.0 - smoothstep(170.0, 270.0, d)
	var h := b * rugged * smoothstep(30.0, 130.0, d) * near_fade
	h += c * 0.6 * smoothstep(20.0, 60.0, d) * near_fade
	h += (a * 0.5 + 0.5) * mountain * smoothstep(biome.get("mountain_start", 90.0), biome.get("mountain_end", 700.0), d)
	var drop_start: float = biome.get("drop_start", 18.0)
	var drop_end: float = biome.get("drop_end", 60.0)
	var right_drop: float = biome.get("right_drop", 0.0)
	var left_drop: float = biome.get("left_drop", 0.0)
	if right_drop != 0.0 and d_signed > 0.0:
		h = lerpf(h, -right_drop, smoothstep(drop_start, drop_end, d))
	if left_drop != 0.0 and d_signed < 0.0:
		h = lerpf(h, -left_drop, smoothstep(drop_start, drop_end, d))
	if biome.has("river") and d_signed > 0.0:
		var rv := river_at(idx)
		var half_w: float = rv.width * 0.5
		var valley := smoothstep(drop_start, rv.drop_end, d) - smoothstep(rv.offset + half_w + 6.0, rv.offset + half_w + 70.0, d)
		h = lerpf(h, -rv.depth + b * 1.5, clampf(valley, 0.0, 1.0))
	if idx >= 0 and biome.has("ledges"):
		var s := float(idx) * Track.STEP
		for led: Dictionary in biome.ledges:
			var side: float = led.get("side", 0)
			if side != 0.0 and signf(d_signed) != side:
				continue
			var win := smoothstep(float(led.s0) - 70.0, float(led.s0) + 70.0, s) * (1.0 - smoothstep(float(led.s1) - 70.0, float(led.s1) + 70.0, s))
			if win > 0.0:
				var target := -float(led.depth) + b * float(led.get("noise", 0.0))
				h = lerpf(h, target, win * smoothstep(float(led.get("start", 14.0)), float(led.get("end", 40.0)), d))
	return h


func _height_at_grid(gx: int, gz: int) -> float:
	var k := gz * _nx + gx
	var cached := _heights[k]
	if not is_nan(cached):
		return cached
	var wx := _origin.x + gx * CELL
	var wz := _origin.y + gz * CELL
	var d2 := _dist[k]
	var out: float
	if d2 > 1e8:
		var far_s := _nearest_far(wx, wz)
		out = far_s.y + _far_offset(wx, wz, far_s.x)
	else:
		var d := sqrt(d2)
		var idx := _near_i[k]
		var off := land_offset(wx, wz, _side[k], idx)
		var flat_edge: float = biome.get("half_width", 11.0) + 7.0
		var t := smoothstep(flat_edge, flat_edge + biome.get("bank_blend", 12.0), d)
		# The ground is sunk under the road so that, on a steep grade, no facet can poke up through the ribbon.
		var hw_k: float = biome.get("half_width", 11.0)
		var dep := lerpf(0.95, 0.18, smoothstep(hw_k + 2.0, hw_k + 9.0, d))
		out = _near_y[k] - dep + off * t
		if biome.has("notches"):
			var s := float(idx) * Track.STEP
			var hw: float = biome.get("half_width", 11.0)
			for n: Dictionary in biome.notches:
				var win := smoothstep(float(n.s0) - 12.0, float(n.s0), s) * (1.0 - smoothstep(float(n.s1), float(n.s1) + 12.0, s))
				out -= float(n.depth) * win * smoothstep(hw + 1.5, hw + 6.0, d)
	_heights[k] = out
	return out


## Terrain height at a world position, matching the triangles of the near mesh.
func ground_y(x: float, z: float) -> float:
	prepare()
	var gx := int(floor((x - _origin.x) / CELL))
	var gz := int(floor((z - _origin.y) / CELL))
	if gx < 0 or gz < 0 or gx >= _nx - 1 or gz >= _nz - 1:
		var far_s := _nearest_far(x, z)
		return far_s.y + _far_offset(x, z, far_s.x)
	var fx := (x - (_origin.x + gx * CELL)) / CELL
	var fz := (z - (_origin.y + gz * CELL)) / CELL
	var h00 := _height_at_grid(gx, gz)
	var h10 := _height_at_grid(gx + 1, gz)
	var h01 := _height_at_grid(gx, gz + 1)
	var h11 := _height_at_grid(gx + 1, gz + 1)
	if (gx + gz) % 2 == 0:
		if fx >= fz:
			return h00 + (h10 - h00) * fx + (h11 - h10) * fz
		return h00 + (h11 - h01) * fx + (h01 - h00) * fz
	if fx + fz <= 1.0:
		return h00 + (h10 - h00) * fx + (h01 - h00) * fz
	return h11 + (h01 - h11) * (1.0 - fx) + (h10 - h11) * (1.0 - fz)


## World position at (s, d) with s allowed past either end of the track (it extends straight).
func world_point(s: float, d: float = 0.0) -> Vector3:
	if s > track.length:
		var end_dir := track.tangent_at(track.length)
		var flat := Vector3(end_dir.x, 0.0, end_dir.z).normalized()
		return track.point(track.length, d) + flat * (s - track.length)
	if s < 0.0:
		var start_dir := track.tangent_at(0.0)
		var flat0 := Vector3(start_dir.x, 0.0, start_dir.z).normalized()
		return track.point(0.0, d) + flat0 * s
	return track.point(s, d)


## Terrain height at (s, d).
func height_at(s: float, d: float) -> float:
	var p := world_point(s, d)
	return ground_y(p.x, p.z)


## A lower bound on the distance from a world position to the nearest stretch of road.
func dist_to_road(x: float, z: float) -> float:
	prepare()
	var gx := int(floor((x - _origin.x) / CELL))
	var gz := int(floor((z - _origin.y) / CELL))
	if gx < 0 or gz < 0 or gx >= _nx - 1 or gz >= _nz - 1:
		return 1e9
	var k := gz * _nx + gx
	var m := minf(minf(_dist[k], _dist[k + 1]), minf(_dist[k + _nx], _dist[k + _nx + 1]))
	if m > 1e8:
		return 1e9
	return maxf(0.0, sqrt(m) - CELL * 0.72)


## Index of the track sample nearest to a world position (from the raster, so approximate).
func nearest_index(x: float, z: float) -> int:
	prepare()
	var gx := clampi(int(floor((x - _origin.x) / CELL)), 0, _nx - 1)
	var gz := clampi(int(floor((z - _origin.y) / CELL)), 0, _nz - 1)
	return _near_i[gz * _nx + gx]


## Rough nearest track point for places outside the corridor. Returns (signed d, road height).
func _nearest_far(wx: float, wz: float) -> Vector2:
	var best := 1e12
	var best_i := 0
	for i in range(0, track.count, 40):
		var p := track.positions[i]
		var dd := (p.x - wx) * (p.x - wx) + (p.z - wz) * (p.z - wz)
		if dd < best:
			best = dd
			best_i = i
	var q := track.positions[best_i]
	var r := track.rights[best_i]
	var signed_d := (wx - q.x) * r.x + (wz - q.z) * r.z
	var d := sqrt(best)
	return Vector2(d if signed_d >= 0.0 else -d, q.y)


# --- colours -----

## Layered rock: horizontal bands of three colours that wrap around the hills.
func _strata_colour(y_abs: float, x: float, z: float) -> Color:
	var band := int(floor(y_abs / 15.0 + 0.4 * sin(x * 0.011 + z * 0.014)))
	var mid: Color = biome.colors.get("rock_mid", (biome.colors.rock as Color).lerp(biome.colors.verge, 0.4))
	match posmod(band, 4):
		0, 2:
			return biome.colors.rock
		1:
			return biome.colors.rock_dark
	return mid


func _colour_for(h_off: float, slope: float, x: float, z: float, d: float, y_abs: float = 0.0) -> Color:
	var n := noise_b.get_noise_2d(x * 1.15, z * 1.15)
	var snow_line: float = biome.get("snow_line", 150.0)
	if h_off + n * 18.0 > snow_line:
		return biome.colors.snow_shade if slope > 0.8 else biome.colors.snow
	if slope > biome.get("rock_slope", 0.62):
		# Strata: bands of rock colour stacked by height, so cliffs read as layered stone instead of confetti.
		return _strata_colour(y_abs, x, z)
	var hw: float = biome.get("half_width", 11.0)
	var patch: float = biome.get("patch", 0.22)
	if d < hw + 14.0 and n > patch:
		return biome.colors.verge
	if biome.get("fields", false) and d > hw + 16.0 and h_off < 14.0 and slope < 0.25:
		# Patchwork of rotated plots, one colour each.
		var u := x * 0.9063 + z * 0.4226
		var v := -x * 0.4226 + z * 0.9063
		var hsh := fposmod(sin(floorf(u / 44.0) * 12.9898 + floorf(v / 31.0) * 78.233) * 43758.5453, 1.0)
		if hsh < 0.34:
			return biome.colors.grass_a
		elif hsh < 0.66:
			return biome.colors.grass_b
		elif hsh < 0.86:
			return biome.colors.grass_c
		return biome.colors.verge
	# Big soft patches of meadow colour, wider than the facets, so the ground reads as areas and not confetti.
	var np := noise_b.get_noise_2d(x * 0.42 + 91.0, z * 0.42 - 37.0)
	if np > patch:
		return biome.colors.grass_b
	if np < -patch:
		return biome.colors.grass_c
	return biome.colors.grass_a


func _build_near_chunks(parent: Node3D, mat: Material) -> void:
	var near_cut := (NEAR_RADIUS + CELL * 2.0) * (NEAR_RADIUS + CELL * 2.0)
	var active := PackedByteArray()
	active.resize(_nx * _nz)
	for k in _nx * _nz:
		active[k] = 1 if _dist[k] < near_cut else 0
	for gz in _nz:
		for gx in _nx:
			if active[gz * _nx + gx] == 1:
				_height_at_grid(gx, gz)
	for cz in range(0, _nz - 1, CHUNK_CELLS):
		for cx in range(0, _nx - 1, CHUNK_CELLS):
			_build_chunk(parent, mat, cx, cz, active)


## Repeatable offset for a grid corner. Moving corners and shuffling diagonals hides the regular grid.
func _jitter(gx: int, gz: int, amount: float) -> Vector2:
	var a := sin(float(gx) * 12.9898 + float(gz) * 78.233) * 43758.5453
	var b := sin(float(gx) * 39.346 + float(gz) * 11.135) * 24634.6345
	return Vector2(a - floor(a) - 0.5, b - floor(b) - 0.5) * amount


func _near_point(gx: int, gz: int, k: int) -> Vector3:
	var half_w: float = biome.get("half_width", 11.0)
	var fade := smoothstep(half_w + 22.0, half_w + 60.0, sqrt(_dist[k]))
	var j := _jitter(gx, gz, CELL * 0.75 * fade)
	return Vector3(_origin.x + gx * CELL + j.x, _heights[k], _origin.y + gz * CELL + j.y)


func _build_chunk(parent: Node3D, mat: Material, cx: int, cz: int, active: PackedByteArray) -> void:
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	var white_uv: Vector2 = biome.get("white_uv", Vector2(0.003, 0.05))
	for gz in range(cz, mini(cz + CHUNK_CELLS, _nz - 1)):
		for gx in range(cx, mini(cx + CHUNK_CELLS, _nx - 1)):
			var k00 := gz * _nx + gx
			var k10 := k00 + 1
			var k01 := k00 + _nx
			var k11 := k01 + 1
			if active[k00] == 0 or active[k10] == 0 or active[k01] == 0 or active[k11] == 0:
				continue
			var x0 := _origin.x + gx * CELL
			var z0 := _origin.y + gz * CELL
			var p00 := _near_point(gx, gz, k00)
			var p10 := _near_point(gx + 1, gz, k10)
			var p01 := _near_point(gx, gz + 1, k01)
			var p11 := _near_point(gx + 1, gz + 1, k11)
			var flip := _jitter(gx, gz, 1.0).x > 0.0
			var tris := [[p00, p10, p11], [p00, p11, p01]] if flip else [[p00, p10, p01], [p10, p11, p01]]
			var ref_y := _near_y[k00]
			var d := sqrt(_dist[k00])
			for tri: Array in tris:
				var a: Vector3 = tri[0]
				var b: Vector3 = tri[1]
				var c: Vector3 = tri[2]
				var n := (c - a).cross(b - a).normalized()
				var slope := 1.0 - absf(n.y)
				var center := (a + b + c) / 3.0
				var col := _colour_for(center.y - ref_y, slope * 2.2, center.x, center.z, d, center.y)
				verts.append(a)
				verts.append(b)
				verts.append(c)
				for i in 3:
					cols.append(col)
					uvs.append(white_uv)
	if verts.is_empty():
		return
	var mi := _mesh_instance(verts, cols, uvs, mat, "Terrain_%d_%d" % [cx, cz])
	parent.add_child(mi)


func _mesh_instance(verts: PackedVector3Array, cols: PackedColorArray, uvs: PackedVector2Array, mat: Material, node_name: String) -> MeshInstance3D:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	if cols.size() > 0:
		arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	normals.fill(Vector3.UP)
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.name = node_name
	return mi


func _build_far_range(parent: Node3D, mat: Material) -> void:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in track.positions:
		lo = lo.min(Vector2(p.x, p.z))
		hi = hi.max(Vector2(p.x, p.z))
	lo -= Vector2.ONE * FAR_MARGIN
	hi += Vector2.ONE * FAR_MARGIN
	var nx := int((hi.x - lo.x) / FAR_CELL) + 1
	var nz := int((hi.y - lo.y) / FAR_CELL) + 1
	var heights := PackedFloat32Array()
	heights.resize(nx * nz)
	var horizon: float = biome.get("horizon", 620.0)
	var mountain: float = biome.get("mountain", 160.0)
	for gz in nz:
		for gx in nx:
			var x := lo.x + gx * FAR_CELL
			var z := lo.y + gz * FAR_CELL
			var near := _nearest_far(x, z)
			var d := absf(near.x)
			var h := near.y + _far_offset(x, z, near.x)
			h += (noise_far.get_noise_2d(x, z) * 0.5 + 0.5) * horizon * smoothstep(700.0, 2600.0, d)
			# Sits well below the near terrain inside the corridor, which hides it, and comes up to meet it at the rim.
			if d < NEAR_RADIUS - 60.0:
				h = near.y - 60.0
			elif d < NEAR_RADIUS + 70.0:
				h = lerpf(near.y - 60.0, h, smoothstep(NEAR_RADIUS - 60.0, NEAR_RADIUS + 70.0, d))
			heights[gz * nx + gx] = h
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	var white_uv: Vector2 = biome.get("white_uv", Vector2(0.003, 0.05))
	var snow_line: float = biome.get("far_snow_line", 420.0)
	var base_y := track.positions[track.count / 2].y
	for gz in nz - 1:
		for gx in nx - 1:
			var x0 := lo.x + gx * FAR_CELL
			var z0 := lo.y + gz * FAR_CELL
			var k00 := gz * nx + gx
			var far_j := FAR_CELL * 0.7
			var j00 := _jitter(gx, gz, far_j)
			var j10 := _jitter(gx + 1, gz, far_j)
			var j01 := _jitter(gx, gz + 1, far_j)
			var j11 := _jitter(gx + 1, gz + 1, far_j)
			var p00 := Vector3(x0 + j00.x, heights[k00], z0 + j00.y)
			var p10 := Vector3(x0 + FAR_CELL + j10.x, heights[k00 + 1], z0 + j10.y)
			var p01 := Vector3(x0 + j01.x, heights[k00 + nx], z0 + FAR_CELL + j01.y)
			var p11 := Vector3(x0 + FAR_CELL + j11.x, heights[k00 + nx + 1], z0 + FAR_CELL + j11.y)
			var flip := _jitter(gx, gz, 1.0).x > 0.0
			var tris := [[p00, p10, p11], [p00, p11, p01]] if flip else [[p00, p10, p01], [p10, p11, p01]]
			for tri: Array in tris:
				var a: Vector3 = tri[0]
				var b: Vector3 = tri[1]
				var c: Vector3 = tri[2]
				var n := (c - a).cross(b - a).normalized()
				var center := (a + b + c) / 3.0
				var alt := center.y - base_y
				var col: Color
				var nv := noise_b.get_noise_2d(center.x * 0.2, center.z * 0.2)
				if alt + nv * 90.0 > snow_line:
					col = biome.colors.snow if absf(n.y) > 0.72 else biome.colors.snow_shade
				elif absf(n.y) < 0.8:
					col = _strata_colour(center.y, center.x, center.z)
				else:
					col = biome.colors.grass_c if nv > 0.0 else biome.colors.rock
				verts.append(a)
				verts.append(b)
				verts.append(c)
				for i in 3:
					cols.append(col)
					uvs.append(white_uv)
	var mi := _mesh_instance(verts, cols, uvs, mat, "FarRange")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


## The smooth part of the land shape, which the coarse far range can represent without aliasing.
func _far_offset(x: float, z: float, d_signed: float) -> float:
	var d := absf(d_signed)
	var mountain: float = biome.get("mountain", 160.0)
	var a := noise_a.get_noise_2d(x, z)
	var h := (a * 0.5 + 0.5) * mountain * smoothstep(biome.get("mountain_start", 90.0), biome.get("mountain_end", 700.0), d)
	var drop_start: float = biome.get("drop_start", 18.0)
	var drop_end: float = biome.get("drop_end", 60.0)
	var right_drop: float = biome.get("right_drop", 0.0)
	if right_drop != 0.0 and d_signed > 0.0:
		h = lerpf(h, -right_drop, smoothstep(drop_start, drop_end, d))
	if biome.has("river") and d_signed > 0.0:
		var rv := river_at(-1)
		var half_w: float = rv.width * 0.5
		var valley := smoothstep(drop_start, rv.drop_end, d) - smoothstep(rv.offset + half_w + 6.0, rv.offset + half_w + 70.0, d)
		h = lerpf(h, -rv.depth, clampf(valley, 0.0, 1.0))
	return h


# --- road ----------------------------------------------------------------------------------------------------

func _build_road(parent: Node3D, mat: Material) -> void:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	var skirt: float = biome.get("road_skirt", 4.5)
	var hw0: float = biome.get("half_width", 11.0)
	# The texture spans the whole ribbon once across and repeats along it; one tile is as long as it is wide, so
	# pixels stay square on the ground.
	var tile_len: float = biome.get("road_tile", (hw0 + skirt) * 2.0)
	var step := 2
	var i := 0
	while i < track.count - step:
		var j := i + step
		var w0 := track.half_widths[i]
		var w1 := track.half_widths[j]
		var s0 := float(i) * Track.STEP
		var s1 := float(j) * Track.STEP
		var offsets0 := [-w0 - skirt, -w0, w0, w0 + skirt]
		var offsets1 := [-w1 - skirt, -w1, w1, w1 + skirt]
		var drops := [-0.75, 0.0, 0.0, -0.75]
		# Edge of road and verge as fractions of the texture width, so the dark verge sits on the skirt.
		var f0 := skirt / (2.0 * (w0 + skirt))
		var f1 := skirt / (2.0 * (w1 + skirt))
		var us0 := [0.0, f0, 1.0 - f0, 1.0]
		var us1 := [0.0, f1, 1.0 - f1, 1.0]
		for q in 3:
			var a := track.positions[i] + track.rights[i] * float(offsets0[q]) + Vector3.UP * (0.02 + float(drops[q]))
			var b := track.positions[i] + track.rights[i] * float(offsets0[q + 1]) + Vector3.UP * (0.02 + float(drops[q + 1]))
			var c := track.positions[j] + track.rights[j] * float(offsets1[q]) + Vector3.UP * (0.02 + float(drops[q]))
			var d := track.positions[j] + track.rights[j] * float(offsets1[q + 1]) + Vector3.UP * (0.02 + float(drops[q + 1]))
			var v0 := s0 / tile_len
			var v1 := s1 / tile_len
			for v in [a, c, b, b, c, d]:
				verts.append(v)
				cols.append(Color.WHITE)
			uvs.append(Vector2(float(us0[q]), v0))
			uvs.append(Vector2(float(us1[q]), v1))
			uvs.append(Vector2(float(us0[q + 1]), v0))
			uvs.append(Vector2(float(us0[q + 1]), v0))
			uvs.append(Vector2(float(us1[q]), v1))
			uvs.append(Vector2(float(us1[q + 1]), v1))
		i = j
	var mi := _mesh_instance(verts, cols, uvs, mat, "Road")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


# --- water ---------------------------------------------------------------------------------------------------

func _build_water(parent: Node3D) -> void:
	if biome.has("river"):
		_build_river(parent, biome.river)
	if biome.has("lake"):
		_build_lake(parent, biome.lake)


func _build_river(parent: Node3D, rv: Dictionary) -> void:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var lift: float = rv.get("lift", 1.1)
	var i := 0
	var step := 4
	while i < track.count - step:
		var j := i + step
		var pa := track.positions[i]
		var pb := track.positions[j]
		var ra := track.rights[i]
		var rb := track.rights[j]
		var qa := river_at(i)
		var qb := river_at(j)
		var oa: float = qa.offset
		var wa: float = qa.width
		var ob: float = qb.offset
		var wb: float = qb.width
		var a: Vector3 = pa + ra * (oa - wa * 0.5)
		var b: Vector3 = pa + ra * (oa + wa * 0.5)
		var c: Vector3 = pb + rb * (ob - wb * 0.5)
		var d: Vector3 = pb + rb * (ob + wb * 0.5)
		a.y = pa.y - float(qa.depth) - 0.18 + lift
		b.y = a.y
		c.y = pb.y - float(qb.depth) - 0.18 + lift
		d.y = c.y
		var v0: float = float(i) * Track.STEP / WATER_CELL
		var v1: float = float(j) * Track.STEP / WATER_CELL
		var ua0: float = -wa * 0.5 / WATER_CELL
		var ua1: float = wa * 0.5 / WATER_CELL
		var ub0: float = -wb * 0.5 / WATER_CELL
		var ub1: float = wb * 0.5 / WATER_CELL
		for v in [a, c, b, b, c, d]:
			verts.append(v)
		uvs.append(Vector2(ua0, v0))
		uvs.append(Vector2(ub0, v1))
		uvs.append(Vector2(ua1, v0))
		uvs.append(Vector2(ua1, v0))
		uvs.append(Vector2(ub0, v1))
		uvs.append(Vector2(ub1, v1))
		i = j
	var mi := _mesh_instance(verts, PackedColorArray(), uvs, make_water_material(1.0), "River")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


func _build_lake(parent: Node3D, lake: Dictionary) -> void:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in track.positions:
		lo = lo.min(Vector2(p.x, p.z))
		hi = hi.max(Vector2(p.x, p.z))
	lo -= Vector2.ONE * (FAR_MARGIN + 600.0)
	hi += Vector2.ONE * (FAR_MARGIN + 600.0)
	var y: float = track.positions[0].y + float(lake.level)
	var verts := PackedVector3Array([Vector3(lo.x, y, lo.y), Vector3(hi.x, y, lo.y), Vector3(lo.x, y, hi.y), Vector3(hi.x, y, lo.y), Vector3(hi.x, y, hi.y), Vector3(lo.x, y, hi.y)])
	var uvs := PackedVector2Array()
	for v in verts:
		uvs.append(Vector2(v.x, v.z) / WATER_CELL)
	var mi := _mesh_instance(verts, PackedColorArray(), uvs, make_water_material(1.0), "Lake")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
