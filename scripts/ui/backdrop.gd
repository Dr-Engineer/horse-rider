class_name Backdrop
extends Control
## Dusk mountains behind a menu screen.

var seed_value := 0.0
var horizon := 0.62


func _init(seed_v: float = 0.0, horizon_v: float = 0.62) -> void:
	seed_value = seed_v
	horizon = horizon_v
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	UI.draw_backdrop(self, Rect2(Vector2.ZERO, size), seed_value, horizon)
