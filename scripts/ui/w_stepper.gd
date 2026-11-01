class_name WStepper
extends Control
## A labelled segmented meter for volume-style settings: left and right change it, click sets it.

signal value_changed(value: int)

var caption := ""
var steps := 10
var value := 5:
	set(v):
		value = clampi(v, 0, steps)
		queue_redraw()


func _init(caption_text: String = "", start: int = 5, step_count: int = 10) -> void:
	caption = caption_text
	steps = step_count
	value = start
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size = Vector2(250, 20)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	mouse_entered.connect(_on_hover)


func _on_hover() -> void:
	if not has_focus():
		grab_focus()
		Sfx.play("ui_move", -6.0)


func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left"):
		_change(-1)
		accept_event()
	elif event.is_action_pressed("ui_right"):
		_change(1)
		accept_event()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_set_from_x((event as InputEventMouseButton).position.x)
		accept_event()
	elif event is InputEventMouseMotion and (event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT != 0:
		_set_from_x((event as InputEventMouseMotion).position.x)
		accept_event()


func _bar_rect() -> Rect2:
	var w := steps * 10.0
	return Rect2(size.x - w - 6.0, 4.0, w, size.y - 8.0)


func _set_from_x(x: float) -> void:
	var r := _bar_rect()
	var v := clampi(int(ceil((x - r.position.x) / 10.0)), 0, steps)
	if v != value:
		value = v
		value_changed.emit(value)
		Sfx.play("ui_move", -6.0)


func _change(d: int) -> void:
	var nv := clampi(value + d, 0, steps)
	if nv != value:
		value = nv
		value_changed.emit(value)
		Sfx.play("ui_move", -6.0)


func _draw() -> void:
	var focused := has_focus()
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, UI.ORPIMENT if focused else UI.SOOT)
	UI.rect_frame(self, r, UI.CONCH if focused else UI.OCHRE, 1.0)
	UI.text(self, Vector2(6, 4), caption, 1, UI.INK if focused else UI.CONCH, false)
	var br := _bar_rect()
	for i in steps:
		var seg := Rect2(br.position.x + i * 10.0, br.position.y, 8.0, br.size.y)
		var on := i < value
		var c: Color
		if focused:
			c = UI.INK if on else UI.GOLD.darkened(0.2)
		else:
			c = UI.ORPIMENT if on else UI.CHARCOAL
		draw_rect(seg, c)
