class_name PlayerControl
extends RefCounted
## Reads the real input actions into a Rider.Intent, and moves the sight with the mouse or the right stick. Also used by the
## autoplay bot, which presses the same actions.

const STICK_SPEED := 0.75     # of the screen per second, with the stick right over

var intent := Rider.Intent.new()
var rider: Rider
var race: Race
var _last_mouse := Vector2(-1.0, -1.0)


func _init(p_rider: Rider, p_race: Race) -> void:
	rider = p_rider
	race = p_race


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
	_mouse_buttons()
	intent.mash = intent.leap or intent.strike_left or intent.strike_right or intent.kick or Input.is_action_just_pressed("urge") or Input.is_action_just_pressed("whip") or Input.is_action_just_pressed("mouse_b")
	if rider.drawing or intent.ranged:
		race.update_sight(rider)
	return intent


## With a ranged weapon the right button draws and looses, and the left one strikes whoever is nearest. With none,
## the two buttons strike left and right.
func _mouse_buttons() -> void:
	if rider.ranged_id == "":
		intent.strike_left = intent.strike_left or Input.is_action_just_pressed("mouse_a")
		intent.strike_right = intent.strike_right or Input.is_action_just_pressed("mouse_b")
		return
	intent.ranged = intent.ranged or Input.is_action_pressed("mouse_b")
	if Input.is_action_just_pressed("mouse_a"):
		var near := race.nearest_rival(rider, 6.0)
		var right := near.d > rider.d if near != null else race.aim_screen.x > 0.5
		intent.strike_right = intent.strike_right or right
		intent.strike_left = intent.strike_left or not right


## Called every frame, so the sight stays with the mouse.
func move_sight(dt: float) -> void:
	if race.aim_held:
		return
	var vp := race.get_viewport()
	var mouse := vp.get_mouse_position() / vp.get_visible_rect().size
	if mouse != _last_mouse:
		if _last_mouse.x >= 0.0:
			race.aim_screen = mouse.clamp(Vector2.ZERO, Vector2.ONE)
		_last_mouse = mouse
	var stick := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	if stick != Vector2.ZERO:
		race.aim_screen = (race.aim_screen + stick * STICK_SPEED * dt).clamp(Vector2.ZERO, Vector2.ONE)
