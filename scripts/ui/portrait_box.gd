class_name PortraitBox
extends Control
## A framed rival portrait at a whole-number scale. Falls back to a colour block with the first letter.

var rival_id := ""
var fallback_color := UI.CHARCOAL
var initial := "?"
var scale_k := 2
var frame := true


func _init(id: String = "", px: int = 48, k: int = 2) -> void:
	rival_id = id
	scale_k = k
	custom_minimum_size = Vector2(px * k + 4, px * k + 4)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_rival(id: String, color: Color, name_text: String) -> void:
	rival_id = id
	fallback_color = color
	initial = name_text.substr(0, 1) if name_text.length() > 0 else "?"
	queue_redraw()


func _draw() -> void:
	var inner := Rect2(Vector2(2, 2), size - Vector2(4, 4))
	draw_rect(Rect2(Vector2.ZERO, size), UI.INK)
	var tex := UI.portrait(rival_id) if rival_id != "" else null
	if tex != null:
		draw_texture_rect(tex, inner, false)
	else:
		draw_rect(inner, fallback_color)
		draw_rect(Rect2(inner.position + Vector2(inner.size.x * 0.3, inner.size.y * 0.18), Vector2(inner.size.x * 0.4, inner.size.y * 0.4)), fallback_color.lightened(0.35))
		draw_rect(Rect2(inner.position + Vector2(inner.size.x * 0.14, inner.size.y * 0.62), Vector2(inner.size.x * 0.72, inner.size.y * 0.4)), fallback_color.darkened(0.25))
		UI.text_c(self, size.x * 0.5, size.y * 0.5 - 14.0 * 0.5 * scale_k, initial, scale_k + 1, UI.CONCH)
	if frame:
		UI.rect_frame(self, Rect2(Vector2.ZERO, size), UI.GOLD, 1.0)
