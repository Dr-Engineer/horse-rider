class_name HudCanvas
extends Control
## The full-screen surface the HUD paints on. All the drawing lives in Hud.paint().

var hud: Node


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _draw() -> void:
	if hud != null:
		hud.call("paint", self)
