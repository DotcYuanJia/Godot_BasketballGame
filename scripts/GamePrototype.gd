extends Node3D
class_name GamePrototype

const COURT_MIN := Vector3(-7.5, 0.0, -12.0)
const COURT_MAX := Vector3(7.5, 0.0, 12.0)
const BALL_HELD := 0
const BALL_FREE := 1
const BALL_SHOT := 2
const MATCH_STATE := preload("res://scripts/MatchState.gd")

@export var pickup_distance: float = 1.1
@export var rim_position: Vector3 = Vector3(0.0, 3.05, -10.2)
@export var three_point_radius: float = 6.25

@onready var player = $Player
@onready var ball = $Basketball
@onready var camera: Camera3D = $CameraRig/Camera3D
@onready var camera_rig: Node3D = $CameraRig
@onready var hud_label: Label = $HUD/MarginContainer/PanelContainer/VBoxContainer/Status
@onready var score_label: Label = $HUD/MarginContainer/PanelContainer/VBoxContainer/Score
@onready var help_label: Label = $HUD/MarginContainer/PanelContainer/VBoxContainer/Help

var match_state
var attempts := 0
var _last_ball_above_rim := false
var _last_shot_points := 2
var _shot_active := false
var _last_event := "Home check ball"

func _ready() -> void:
	_make_court()
	match_state = MATCH_STATE.new()
	match_state.name = "MatchState"
	add_child(match_state)
	match_state.reset_requested.connect(_on_match_reset_requested)
	match_state.match_event.connect(_on_match_event)
	player.court_min = COURT_MIN
	player.court_max = COURT_MAX
	player.shoot_requested.connect(_on_player_shoot_requested)
	player.pickup_requested.connect(_try_pickup)
	player.hand_changed.connect(_update_hud)
	ball.mode_changed.connect(_on_ball_mode_changed)
	help_label.text = "Move: WASD/Arrows    Sprint: Shift    Shoot/Pickup: J    Change hand: K    Reset: Space"
	reset_ball_to_player(false)
	match_state.reset_match()
	_update_hud()

func _process(delta: float) -> void:
	match_state.tick(delta)
	if Input.is_action_just_pressed("reset_ball"):
		match_state.manual_home_reset()
	if match_state.can_player_control_ball() and not player.has_ball and ball.can_pickup_by(player, pickup_distance):
		_try_pickup()
	_check_out_of_bounds()
	_check_score()
	_update_camera(delta)
	_update_hud()

func reset_ball_to_player(start_live: bool = true) -> void:
	player.global_position = Vector3(0.0, 0.0, 6.0)
	player.velocity = Vector3.ZERO
	player.has_ball = true
	ball.global_position = player.hand_socket_position()
	ball.attach_to(player)
	_last_ball_above_rim = false
	_shot_active = false
	if start_live and match_state:
		match_state.begin_home_play()
	_update_hud()

func _on_player_shoot_requested() -> void:
	if not match_state.can_player_control_ball():
		return
	if not player.has_ball:
		_try_pickup()
		return
	attempts += 1
	var release: Vector3 = player.hand_socket_position() + Vector3(0.0, 0.18, 0.0)
	_last_shot_points = _shot_value_from_position(release)
	_shot_active = true
	ball.release_shot(release, rim_position, 2.7, 1.08)
	_last_ball_above_rim = false

func _try_pickup() -> void:
	if not match_state.can_player_control_ball():
		return
	if ball.can_pickup_by(player, pickup_distance):
		ball.attach_to(player)

func _on_ball_mode_changed(_mode: int) -> void:
	_update_hud()

func _on_match_reset_requested(team: int) -> void:
	if team == 0:
		reset_ball_to_player(true)

func _on_match_event(message: String) -> void:
	_last_event = message

func _check_score() -> void:
	if not _shot_active or ball.mode != BALL_SHOT or match_state.is_dead():
		return
	var rim_flat := Vector2(rim_position.x, rim_position.z)
	var ball_flat := Vector2(ball.global_position.x, ball.global_position.z)
	if ball.global_position.y > rim_position.y + 0.25:
		_last_ball_above_rim = true
	elif _last_ball_above_rim and ball.global_position.y <= rim_position.y and ball_flat.distance_to(rim_flat) < 0.44:
		_shot_active = false
		_last_ball_above_rim = false
		match_state.resolve_made_shot(_last_shot_points)
		ball.release_near(rim_position + Vector3(0.0, -2.4, 0.25))

func _check_out_of_bounds() -> void:
	if match_state.is_dead() or ball.mode == BALL_HELD:
		return
	var p: Vector3 = ball.global_position
	if p.x < COURT_MIN.x - 0.7 or p.x > COURT_MAX.x + 0.7 or p.z < COURT_MIN.z - 0.7 or p.z > COURT_MAX.z + 0.7:
		_shot_active = false
		match_state.resolve_out_of_bounds()

func _shot_value_from_position(pos: Vector3) -> int:
	var flat_pos := Vector2(pos.x, pos.z)
	var flat_rim := Vector2(rim_position.x, rim_position.z)
	return 3 if flat_pos.distance_to(flat_rim) >= three_point_radius else 2

func _update_camera(delta: float) -> void:
	var ball_weight := 0.28 if not player.has_ball else 0.12
	var focus: Vector3 = player.global_position.lerp(ball.global_position, ball_weight)
	focus = focus.lerp(rim_position, 0.10)
	camera_rig.global_position = camera_rig.global_position.lerp(focus, clamp(6.5 * delta, 0.0, 1.0))
	camera.look_at(focus + Vector3(0.0, 1.1, 0.0), Vector3.UP)

func _update_hud() -> void:
	var ball_state := "Held" if ball.mode == BALL_HELD else ("Shot" if ball.mode == BALL_SHOT else "Loose")
	var hand := "Right" if player.ball_hand > 0 else "Left"
	hud_label.text = "%s    Ball: %s    Hand: %s" % [match_state.clock_text() if match_state else "Phase: Boot", ball_state, hand]
	score_label.text = "%s    Attempts: %d    Last: %s" % [match_state.scoreboard_text() if match_state else "Q1 0:00 Home 0 - Away 0", attempts, _last_event]

func _make_court() -> void:
	var court_root := Node3D.new()
	court_root.name = "GeneratedCourt"
	add_child(court_root)
	_add_box(court_root, "Floor", Vector3(0, -0.03, 0), Vector3(16.5, 0.06, 25.5), Color(0.18, 0.48, 0.42))
	_add_line(court_root, Vector3(-7.5, 0.012, -12), Vector3(7.5, 0.012, -12), Color.WHITE)
	_add_line(court_root, Vector3(-7.5, 0.012, 12), Vector3(7.5, 0.012, 12), Color.WHITE)
	_add_line(court_root, Vector3(-7.5, 0.012, -12), Vector3(-7.5, 0.012, 12), Color.WHITE)
	_add_line(court_root, Vector3(7.5, 0.012, -12), Vector3(7.5, 0.012, 12), Color.WHITE)
	_add_line(court_root, Vector3(-7.5, 0.014, 0), Vector3(7.5, 0.014, 0), Color(0.92, 0.92, 0.82))
	_add_arc(court_root, Vector3(0, 0.018, -10.2), three_point_radius, deg_to_rad(28), deg_to_rad(152), Color(0.96, 0.92, 0.70))
	_add_box(court_root, "Paint", Vector3(0, 0.005, -8.2), Vector3(4.9, 0.025, 3.8), Color(0.22, 0.58, 0.52, 0.55))
	_add_box(court_root, "Backboard", Vector3(0, 3.25, -10.85), Vector3(2.1, 1.15, 0.10), Color(0.88, 0.93, 0.94))
	_add_box(court_root, "Rim", rim_position, Vector3(0.9, 0.08, 0.9), Color(0.95, 0.33, 0.12))
	_add_box(court_root, "Stanchion", Vector3(0, 1.45, -11.3), Vector3(0.16, 2.9, 0.16), Color(0.18, 0.20, 0.22))

func _add_box(parent: Node, name: String, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = pos
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	node.material_override = material
	parent.add_child(node)
	return node

func _add_line(parent: Node, a: Vector3, b: Vector3, color: Color) -> void:
	var mid := (a + b) * 0.5
	var length := a.distance_to(b)
	var node := _add_box(parent, "Line", mid, Vector3(0.07, 0.025, length), color)
	var dir := (b - a).normalized()
	node.rotation.y = atan2(dir.x, dir.z)

func _add_arc(parent: Node, center: Vector3, radius: float, start: float, stop: float, color: Color) -> void:
	var previous := center + Vector3(cos(start) * radius, 0, sin(start) * radius)
	var steps := 36
	for i in range(1, steps + 1):
		var t := lerpf(start, stop, float(i) / steps)
		var next := center + Vector3(cos(t) * radius, 0, sin(t) * radius)
		_add_line(parent, previous, next, color)
		previous = next
