extends Node
## Checks that things stand where they should: no prop model hovers above its own origin, and no scatter lands on the road,
## including on another stretch of it inside a tight bend.
## Usage: Godot --headless --path . --audio-driver Dummy res://tests/dressing_check.tscn

const MAX_HOVER := 0.06   # the lowest point of a prop that stands on the ground, in metres above its origin
## These are carried, hung or scattered flat, so their lowest point needn't touch the ground.
const OFF_THE_GROUND := ["flag_string", "banner", "start_gate", "finish_gate", "scarf", "mud_patch"]

var failures := 0


func _ready() -> void:
	_props()
	for index in Courses.count():
		for season: int in [0, 2]:
			_scatter(index, season)
	print("RESULT: %s (%d)" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(1 if failures > 0 else 0)


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("  FAIL: " + what)


func _lowest(node: Node, xf: Transform3D, low: float) -> float:
	var here := xf
	if node is Node3D:
		here = xf * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var box := (node as MeshInstance3D).mesh.get_aabb()
		for i in 8:
			low = minf(low, (here * box.get_endpoint(i)).y)
	for c in node.get_children():
		low = _lowest(c, here, low)
	return low


func _props() -> void:
	var dir := DirAccess.open("res://assets/models/props")
	var names: Array[String] = []
	for f in dir.get_files():
		if f.ends_with(".glb"):
			names.append(f.get_basename())
	names.sort()
	var worst := ""
	var worst_h := -INF
	for prop in names:
		var node := (load("res://assets/models/props/%s.glb" % prop) as PackedScene).instantiate()
		var low := _lowest(node, Transform3D.IDENTITY, INF)
		node.free()
		if prop in OFF_THE_GROUND:
			continue
		check(low <= MAX_HOVER, "%s hovers %.2f m above the ground" % [prop, low])
		if low > worst_h:
			worst_h = low
			worst = prop
	print("  %d props: the highest base is %s at %.2f m" % [names.size(), worst, worst_h])


func _scatter(index: int, season: int) -> void:
	var c := Courses.get_course(index, season)
	var t := Track.new()
	t.build(c["segments"], c["half_width"])
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var holder := Node3D.new()
	add_child(holder)
	var dressing := TrackDressing.new(t, c, rng)
	dressing.build_into(holder)
	var on_road := 0
	var example := ""
	var total: int = dressing.placed.size()
	for p: Dictionary in dressing.placed:
		var pos: Vector3 = p["pos"]
		var i := 0
		while i < t.count:
			var q := t.positions[i]
			var gap := Vector2(q.x - pos.x, q.z - pos.z).length()
			if gap < t.half_widths[i] + 0.5:
				on_road += 1
				example = "%s at %s" % [p["prop"], str(pos)]
				break
			# nothing can be nearer than the gap allows, so skip ahead
			i += maxi(int((gap - 10.0) / Track.STEP), 1)
	holder.queue_free()
	print("  %-24s S%d: %5d props placed, %d on the road" % [c["id"], season + 1, total, on_road])
	check(on_road == 0, "%s S%d: %d props on the road, such as %s" % [c["id"], season + 1, on_road, example])
