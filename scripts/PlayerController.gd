extends CharacterBody3D
class_name PlayerController

signal shoot_requested
signal pickup_requested
signal hand_changed

@export var walk_speed: float = 4.0
@export var sprint_multiplier: float = 1.55
@export var acceleration: float = 16.0
@export var turn_speed: float = 12.0
@export var court_min: Vector3 = Vector3(-7.5, 0.0, -12.0)
@export var court_max: Vector3 = Vector3(7.5, 0.0, 12.0)

var has_ball := true
var ball_hand := 1
var move_input := Vector2.ZERO
var move_direction := Vector3.FORWARD
var is_sprinting := false

func _physics_process(delta: float) -> void:
	move_input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	is_sprinting = Input.is_action_pressed("sprint")
	var desired_velocity := Vector3.ZERO
	if move_input.length_squared() > 0.001:
		desired_velocity = Vector3(move_input.x, 0.0, move_input.y).normalized() * walk_speed
		if is_sprinting:
			desired_velocity *= sprint_multiplier
		move_direction = desired_velocity.normalized()
		var target_basis := Basis.looking_at(move_direction, Vector3.UP)
		basis = basis.slerp(target_basis, clamp(turn_speed * delta, 0.0, 1.0))

	velocity.x = move_toward(velocity.x, desired_velocity.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, desired_velocity.z, acceleration * delta)
	velocity.y = 0.0
	move_and_slide()
	global_position.x = clamp(global_position.x, court_min.x, court_max.x)
	global_position.z = clamp(global_position.z, court_min.z, court_max.z)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("shoot_pickup"):
		if has_ball:
			shoot_requested.emit()
		else:
			pickup_requested.emit()
	elif event.is_action_pressed("change_hand") and has_ball:
		ball_hand *= -1
		hand_changed.emit()

func hand_socket_position() -> Vector3:
	var side := global_transform.basis.x.normalized() * 0.48 * float(ball_hand)
	var forward := -global_transform.basis.z.normalized() * 0.18
	return global_position + side + forward + Vector3(0.0, 1.08, 0.0)

func dribble_floor_position() -> Vector3:
	var side := global_transform.basis.x.normalized() * 0.42 * float(ball_hand)
	var forward := -global_transform.basis.z.normalized() * 0.30
	return global_position + side + forward + Vector3(0.0, 0.29, 0.0)

func speed_ratio() -> float:
	return clamp(Vector2(velocity.x, velocity.z).length() / (walk_speed * sprint_multiplier), 0.0, 1.0)
