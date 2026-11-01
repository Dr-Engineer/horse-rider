class_name WButton
extends Button
## Menu button: hover and keyboard focus are the same gold highlight, with a snap and a bounce.

var quiet_first_focus := true
var _tween: Tween


func _init(label_text: String = "") -> void:
	text = label_text
	focus_mode = Control.FOCUS_ALL
	mouse_entered.connect(_on_hover)
	focus_entered.connect(_on_focus)
	pressed.connect(_on_pressed)
	resized.connect(_update_pivot)


func _update_pivot() -> void:
	pivot_offset = size * 0.5


func _on_hover() -> void:
	if not disabled and not has_focus():
		grab_focus()


func _on_focus() -> void:
	if quiet_first_focus:
		quiet_first_focus = false
	else:
		Sfx.play("ui_move", -6.0)
	bounce()


func _on_pressed() -> void:
	Sfx.play("ui_ok", -3.0)


func bounce() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	pivot_offset = size * 0.5
	scale = Vector2.ONE
	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector2(1.07, 1.07), 0.05)
	_tween.tween_property(self, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Pop in after `delay` seconds, as menus do on a 16-bit cabinet.
func snap_in(delay: float) -> void:
	modulate.a = 0.0
	pivot_offset = size * 0.5
	scale = Vector2(0.8, 0.8)
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_property(self, "modulate:a", 1.0, 0.04)
	tw.parallel().tween_property(self, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
