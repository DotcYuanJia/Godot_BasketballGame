extends Node3D
class_name Basketball

enum BallMode { HELD, FREE, SHOT }

signal mode_changed(mode: int)

@export var radius: float = 0.24
@export var gravity: float = 9.8
@export var bounce_damping: float = 0.58
@export var ground_y: float = 0.24
@export var pickup_cooldown: float = 0.35

var mode: BallMode = BallMode.HELD
var velocity := Vector3.ZERO
var holder
var _pickup_timer := 0.0
var _dribble_clock := 0.0

@onready var mesh: MeshInstance3D = $Mesh

func _physics_process(delta: float) -> void:
	_pickup_timer = maxf(_pickup_timer - delta, 0.0)
	match mode:
		BallMode.HELD:
			_follow_holder(delta)
		BallMode.FREE, BallMode.SHOT:
			_integrate_free_ball(delta)
	_update_spin(delta)

func attach_to(new_holder) -> void:
	holder = new_holder
	mode = BallMode.HELD
	velocity = Vector3.ZERO
	_pickup_timer = 0.0
	if holder:
		holder.has_ball = true
	mode_changed.emit(mode)

func release_shot(origin: Vector3, target: Vector3, arc_height: float = 3.2, flight_time: float = 1.05) -> void:
	if holder:
		holder.has_ball = false
	global_position = origin
	holder = null
	mode = BallMode.SHOT
	_pickup_timer = pickup_cooldown
	var horizontal := Vector3(target.x - origin.x, 0.0, target.z - origin.z)
	velocity.x = horizontal.x / flight_time
	velocity.z = horizontal.z / flight_time
	var peak_y := maxf(origin.y, target.y) + arc_height
	var up_time := flight_time * 0.48
	velocity.y = (peak_y - origin.y + 0.5 * gravity * up_time * up_time) / up_time
	mode_changed.emit(mode)

func release_near(position: Vector3) -> void:
	if holder:
		holder.has_ball = false
	holder = null
	mode = BallMode.FREE
	global_position = position
	velocity = Vector3.ZERO
	_pickup_timer = pickup_cooldown
	mode_changed.emit(mode)

func can_pickup_by(player, distance: float) -> bool:
	return _pickup_timer <= 0.0 and mode != BallMode.HELD and global_position.distance_to(player.global_position) <= distance

func _follow_holder(delta: float) -> void:
	if holder == null:
		mode = BallMode.FREE
		return
	_dribble_clock += delta * lerpf(3.0, 6.8, holder.speed_ratio())
	var moving: bool = holder.move_input.length_squared() > 0.01
	var t := 0.0
	if moving:
		t = (sin(_dribble_clock * TAU) + 1.0) * 0.5
		t = smoothstep(0.12, 0.92, t)
	var target: Vector3 = holder.hand_socket_position().lerp(holder.dribble_floor_position(), t)
	global_position = global_position.lerp(target, clamp(18.0 * delta, 0.0, 1.0))

func _integrate_free_ball(delta: float) -> void:
	velocity.y -= gravity * delta
	global_position += velocity * delta
	if global_position.y < ground_y:
		global_position.y = ground_y
		if absf(velocity.y) > 1.0:
			velocity.y = -velocity.y * bounce_damping
			velocity.x *= 0.82
			velocity.z *= 0.82
		else:
			velocity.y = 0.0
			velocity.x = move_toward(velocity.x, 0.0, 2.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 2.0 * delta)
			if mode == BallMode.SHOT:
				mode = BallMode.FREE
				mode_changed.emit(mode)

func _update_spin(delta: float) -> void:
	var planar_speed := Vector2(velocity.x, velocity.z).length()
	if mode == BallMode.HELD and holder:
		planar_speed = maxf(holder.speed_ratio() * 6.0, 1.0)
	mesh.rotate_object_local(Vector3.RIGHT, planar_speed * delta * 2.6)
