extends Node
## Hoof skate check. Measures, from the animation tracks of horse.glb, how far each gait loop carries the horse (the
## backward speed of a hoof, relative to the body, while it is on the ground), how far RiderVisual stretches the legs'
## swing to close the gap, and how much of the ground speed the feet then keep up with at the cadence the loop plays at.
## 1.00 means a hoof planted dead still. The old line is how the loops were played before: speed over a guessed reference.
##   Godot --headless --path . --audio-driver Dummy res://tests/gait_check.tscn
## Re-run it whenever horse.glb's animations change, and retune RiderVisual.GAIT_HZ and GAIT_TYPICAL.

const GAITS := ["walk", "trot", "canter", "gallop"]
const OLD_REF := {"gallop": 15.0, "canter": 9.0, "trot": 5.5, "walk": 1.7}

var failures := 0


func _ready() -> void:
	var horse: Node = (load("res://assets/models/horse.glb") as PackedScene).instantiate()
	var skel: Skeleton3D = horse.find_children("*", "Skeleton3D", true, false)[0]
	var ap: AnimationPlayer = horse.find_children("*", "AnimationPlayer", true, false)[0]
	var before: Dictionary = {}
	for g: String in GAITS:
		before[g] = RiderVisual.stride_ref(skel, ap.get_animation(g))
	RiderVisual.lengthen_strides(ap, skel)
	print("== what each loop carries the horse, as authored and now (speed_scale 1)")
	var refs: Dictionary = {}
	for g: String in GAITS:
		var an := ap.get_animation(g)
		var now := RiderVisual.stride_ref(skel, an)
		refs[g] = now
		var b: Dictionary = before[g]
		print("  %-7s cycle %.3f s, hoof down %2.0f%%: stride %.2f m -> %.2f m (swing x%.2f), no-skate ground speed %.2f -> %.2f m/s, lowest hoof %.3f -> %.3f m" % [
				g, an.length, 100.0 * float(now["stance"]), float(b["ref"]) * an.length, float(now["ref"]) * an.length, float(an.get_meta("swing_k", 1.0)),
				float(b["ref"]), float(now["ref"]), float(b["low"]), float(now["low"])])
		check(float(now["low"]) >= float(b["low"]) - 0.03, "%s: the hooves do not sink lower than they did (%.3f -> %.3f)" % [g, float(b["low"]), float(now["low"])])
	var worst := 1.0
	for horse_id: String in ["old_tsampa", "sertso_grey"]:
		var top: float = GameData.HORSES[horse_id]["speed"]
		print("== %s (top %.0f m/s): feet / ground speed at the slow end, middle and fast end of each gait" % [horse_id, top])
		for g: String in GAITS:
			var band := _band(g, top)
			var row := ""
			var old_row := ""
			for k in 3:
				var v := lerpf(band.x, band.y, float(k) * 0.5)
				var hz := RiderVisual.cadence(g, v, top)
				var keep := hz * float(refs[g]["ref"]) * ap.get_animation(g).length / maxf(v, 0.1)
				var old_scale := clampf(v / float(OLD_REF[g]), 0.5, 1.9)
				var old_keep := old_scale * float(before[g]["ref"]) / maxf(v, 0.1)
				row += "  %5.1f m/s %.1f Hz -> %.2f" % [v, hz, minf(keep, 9.0)]
				old_row += "  %4.2f" % old_keep
				if g != "walk":
					worst = minf(worst, keep)
			print("  %-7s%s   (before:%s)" % [g, row, old_row])
	print("worst grip above a walk: %.2f" % worst)
	check(worst >= 0.4, "above a walk the feet keep up with at least 40%% of the ground (%.2f)" % worst)
	horse.free()
	print("RESULT: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	get_tree().quit(0 if failures == 0 else 1)


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures += 1
		print("  FAIL: ", msg)


func _band(g: String, top: float) -> Vector2:
	var walk_top := maxf(0.12 * top, 2.5)
	match g:
		"walk":
			return Vector2(0.6, walk_top)
		"trot":
			return Vector2(walk_top, 0.4 * top)
		"canter":
			return Vector2(0.4 * top, 0.74 * top)
	return Vector2(0.74 * top, 1.18 * top)
