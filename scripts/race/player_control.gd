class_name PlayerControl
extends RefCounted
## Reads the real input actions into a Rider.Intent. Also used by the autoplay bot, which presses the same actions.

var intent := Rider.Intent.new()


func think(_dt: float) -> Rider.Intent:
	intent.clear_edges()
	intent.steer = Input.get_axis("steer_left", "steer_right")
	intent.throttle = Input.get_axis("rein", "urge")
	intent.whip = Input.is_action_pressed("whip")
	intent.ranged = Input.is_action_pressed("ranged")
	intent.shield = Input.is_action_pressed("shield")
	intent.leap = Input.is_action_just_pressed("leap")
	intent.strike_left = Input.is_action_just_pressed("strike_left")
	intent.strike_right = Input.is_action_just_pressed("strike_right")
	intent.kick = Input.is_action_just_pressed("kick")
	intent.second_wind = Input.is_action_just_pressed("second_wind")
	intent.mash = intent.leap or intent.strike_left or intent.strike_right or intent.kick or Input.is_action_just_pressed("urge") or Input.is_action_just_pressed("whip")
	return intent
