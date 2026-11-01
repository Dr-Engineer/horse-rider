class_name InputSetup
extends RefCounted
## Registers every game action in code, so controls live in one readable place.


static func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	return e


static func _mouse(button: MouseButton) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = button
	return e


static func _pad(button: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	return e


static func _axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = value
	return e


static func register() -> void:
	var map := {
		"steer_left": [_key(KEY_A), _key(KEY_LEFT), _axis(JOY_AXIS_LEFT_X, -1.0)],
		"steer_right": [_key(KEY_D), _key(KEY_RIGHT), _axis(JOY_AXIS_LEFT_X, 1.0)],
		"urge": [_key(KEY_W), _key(KEY_UP), _axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)],
		"rein": [_key(KEY_S), _key(KEY_DOWN), _axis(JOY_AXIS_TRIGGER_LEFT, 1.0)],
		"whip": [_key(KEY_SHIFT), _pad(JOY_BUTTON_RIGHT_SHOULDER)],
		"leap": [_key(KEY_SPACE), _pad(JOY_BUTTON_A)],
		"strike_left": [_key(KEY_J), _key(KEY_Q), _pad(JOY_BUTTON_X)],
		"strike_right": [_key(KEY_L), _key(KEY_E), _pad(JOY_BUTTON_B)],
		"mouse_a": [_mouse(MOUSE_BUTTON_LEFT)],    # what the mouse buttons do depends on the weapons: see PlayerControl
		"mouse_b": [_mouse(MOUSE_BUTTON_RIGHT)],
		"kick": [_key(KEY_K), _key(KEY_F), _pad(JOY_BUTTON_Y)],
		"ranged": [_key(KEY_U), _key(KEY_R), _pad(JOY_BUTTON_RIGHT_STICK), _pad(JOY_BUTTON_DPAD_UP)],
		"aim_left": [_axis(JOY_AXIS_RIGHT_X, -1.0)],
		"aim_right": [_axis(JOY_AXIS_RIGHT_X, 1.0)],
		"aim_up": [_axis(JOY_AXIS_RIGHT_Y, -1.0)],
		"aim_down": [_axis(JOY_AXIS_RIGHT_Y, 1.0)],
		"shield": [_key(KEY_I), _key(KEY_C), _pad(JOY_BUTTON_LEFT_SHOULDER)],
		"second_wind": [_key(KEY_ENTER), _key(KEY_CTRL), _pad(JOY_BUTTON_DPAD_DOWN)],
		"pause": [_key(KEY_ESCAPE), _pad(JOY_BUTTON_START)],
		"ui_confirm": [_key(KEY_ENTER), _key(KEY_SPACE), _pad(JOY_BUTTON_A)],
		"ui_back": [_key(KEY_ESCAPE), _pad(JOY_BUTTON_B)],
	}
	for action: String in map:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.3)
		for ev: InputEvent in map[action]:
			InputMap.action_add_event(action, ev)
