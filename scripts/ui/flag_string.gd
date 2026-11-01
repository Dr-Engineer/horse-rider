class_name FlagString
extends Control
## A string of prayer flags across the top of a screen, swaying in the wind. Blue, white, red, green, yellow, in that
## order, each with a small abstract horse block print and no writing.

var _t := 0.0
const HORSE: Array[String] = ["..##.", ".####", "####.", "#.#.."]


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var n := int(w / 22.0) + 2
	var prev := Vector2(-4, 0)
	var step := w / float(n - 1)
	for i in range(n):
		var x := i * step
		var sag := sin(float(i) / float(n - 1) * PI) * 7.0
		var y := 3.0 + sag
		var p := Vector2(x, y)
		draw_line(prev, p, UI.BONE, 1.0)
		prev = p
	for i in range(n - 1):
		var x0 := i * step
		var u := (float(i) + 0.5) / float(n - 1)
		var sag := sin(u * PI) * 7.0
		var fx := x0 + step * 0.5 - 6.0
		var fy := 4.0 + sag
		var sway := roundf(sin(_t * 2.1 + i * 0.7) * 1.5)
		var col: Color = UI.LUNGTA_COLORS[i % 5]
		draw_rect(Rect2(fx - 1, fy - 1, 13, 15), UI.INK)
		draw_rect(Rect2(fx, fy, 11, 13), col)
		draw_rect(Rect2(fx + 9 + sway * 0.0, fy + 11, 2, 2), UI.INK)
		for r in 4:
			var row: String = HORSE[r]
			for c in 5:
				if row[c] == "#":
					draw_rect(Rect2(fx + 3 + c + sway * 0.5, fy + 4 + r, 1, 1), col.darkened(0.55))
