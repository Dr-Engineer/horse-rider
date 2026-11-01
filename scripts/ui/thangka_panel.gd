class_name ThangkaPanel
extends MarginContainer
## A content frame in the thangka style: ink panel, gold line, brocade silk top and bottom.

var brocade := true
var fill := UI.INK


func _init(with_brocade: bool = true, margin_x: int = 9, margin_y: int = 11) -> void:
	brocade = with_brocade
	add_theme_constant_override("margin_left", margin_x)
	add_theme_constant_override("margin_right", margin_x)
	add_theme_constant_override("margin_top", margin_y if with_brocade else margin_x)
	add_theme_constant_override("margin_bottom", margin_y if with_brocade else margin_x)
	mouse_filter = Control.MOUSE_FILTER_PASS


func _draw() -> void:
	UI.draw_panel(self, Rect2(Vector2.ZERO, size), brocade, fill)
