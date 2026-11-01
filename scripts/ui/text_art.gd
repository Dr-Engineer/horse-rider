class_name TextArt
extends Control
## Outlined headline-font text as a control, for titles and big words. Size is whole multiples of the base font only.

var text := ""
var k := 1
var color := UI.CONCH
var align := HORIZONTAL_ALIGNMENT_LEFT
var outline := true


func _init(t: String = "", size_k: int = 1, col: Color = UI.CONCH, al: int = HORIZONTAL_ALIGNMENT_LEFT, outl: bool = true) -> void:
	text = t
	k = size_k
	color = col
	align = al as HorizontalAlignment
	outline = outl
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fit()


func _fit() -> void:
	custom_minimum_size = Vector2(UI.text_width(text, k) + 2.0 * k, 12.0 * k)


func set_text(t: String) -> void:
	text = t
	_fit()
	queue_redraw()


func _draw() -> void:
	var w := UI.text_width(text, k)
	var x := 0.0
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		x = (size.x - w) * 0.5
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		x = size.x - w - k
	UI.text(self, Vector2(x + k, 0), text, k, color, outline)
