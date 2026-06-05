extends Node
class_name MatchState

signal match_event(message: String)
signal reset_requested(team: int)

enum Team { HOME, AWAY }
enum Phase { CHECK_BALL, PLAYING, DEAD_BALL, QUARTER_END, GAME_OVER }

@export var quarter_length: float = 180.0
@export var shot_clock_length: float = 24.0
@export var max_quarters: int = 1
@export var dead_ball_delay: float = 1.25
@export var away_auto_delay: float = 1.0

var phase: Phase = Phase.CHECK_BALL
var possession: Team = Team.HOME
var pending_possession: Team = Team.HOME
var quarter := 1
var game_clock := 180.0
var shot_clock := 24.0
var home_score := 0
var away_score := 0
var last_event := "Home check ball"

var _dead_ball_timer := 0.0
var _away_timer := 0.0

func _ready() -> void:
	reset_match()

func reset_match() -> void:
	quarter = 1
	home_score = 0
	away_score = 0
	game_clock = quarter_length
	shot_clock = shot_clock_length
	possession = Team.HOME
	pending_possession = Team.HOME
	phase = Phase.CHECK_BALL
	_dead_ball_timer = 0.0
	_away_timer = 0.0
	last_event = "Home check ball"
	reset_requested.emit(Team.HOME)
	match_event.emit(last_event)

func tick(delta: float) -> void:
	match phase:
		Phase.PLAYING:
			_tick_live(delta)
		Phase.DEAD_BALL:
			_dead_ball_timer -= delta
			if _dead_ball_timer <= 0.0:
				_enter_check_ball(pending_possession, last_event)
		Phase.CHECK_BALL:
			if possession == Team.AWAY:
				_away_timer -= delta
				if _away_timer <= 0.0:
					away_empty_trip()

func begin_home_play() -> void:
	if phase != Phase.CHECK_BALL or possession != Team.HOME:
		return
	phase = Phase.PLAYING
	shot_clock = shot_clock_length
	last_event = "Home possession live"
	match_event.emit(last_event)

func manual_home_reset() -> void:
	possession = Team.HOME
	pending_possession = Team.HOME
	phase = Phase.CHECK_BALL
	shot_clock = shot_clock_length
	last_event = "Manual reset"
	reset_requested.emit(Team.HOME)
	match_event.emit(last_event)

func resolve_made_shot(points: int) -> void:
	points = clampi(points, 1, 3)
	if possession == Team.HOME:
		home_score += points
		pending_possession = Team.AWAY
		last_event = "Home made %d" % points
	else:
		away_score += points
		pending_possession = Team.HOME
		last_event = "Away made %d" % points
	_enter_dead_ball(last_event)

func resolve_turnover(reason: String) -> void:
	pending_possession = Team.AWAY if possession == Team.HOME else Team.HOME
	last_event = reason
	_enter_dead_ball(reason)

func resolve_out_of_bounds() -> void:
	resolve_turnover("%s out of bounds" % possession_name())

func away_empty_trip() -> void:
	possession = Team.HOME
	pending_possession = Team.HOME
	phase = Phase.CHECK_BALL
	shot_clock = shot_clock_length
	last_event = "Away possession skipped: AI not implemented"
	reset_requested.emit(Team.HOME)
	match_event.emit(last_event)

func can_player_control_ball() -> bool:
	return phase == Phase.PLAYING and possession == Team.HOME

func is_dead() -> bool:
	return phase == Phase.DEAD_BALL or phase == Phase.QUARTER_END or phase == Phase.GAME_OVER

func phase_name() -> String:
	match phase:
		Phase.CHECK_BALL:
			return "Check"
		Phase.PLAYING:
			return "Live"
		Phase.DEAD_BALL:
			return "Dead"
		Phase.QUARTER_END:
			return "Quarter End"
		Phase.GAME_OVER:
			return "Game Over"
	return "Unknown"

func possession_name() -> String:
	return "Home" if possession == Team.HOME else "Away"

func scoreboard_text() -> String:
	return "Q%d  %s  Home %d - Away %d" % [quarter, format_time(game_clock), home_score, away_score]

func clock_text() -> String:
	return "Phase: %s    Poss: %s    Shot: %02d" % [phase_name(), possession_name(), ceili(shot_clock)]

func format_time(seconds: float) -> String:
	var safe_seconds := maxi(0, int(ceil(seconds)))
	return "%d:%02d" % [safe_seconds / 60, safe_seconds % 60]

func _tick_live(delta: float) -> void:
	game_clock = maxf(game_clock - delta, 0.0)
	shot_clock = maxf(shot_clock - delta, 0.0)
	if game_clock <= 0.0:
		_enter_quarter_end()
	elif shot_clock <= 0.0:
		resolve_turnover("%s shot clock violation" % possession_name())

func _enter_dead_ball(reason: String) -> void:
	phase = Phase.DEAD_BALL
	_dead_ball_timer = dead_ball_delay
	shot_clock = shot_clock_length
	last_event = reason
	match_event.emit(reason)

func _enter_check_ball(team: Team, reason: String) -> void:
	possession = team
	phase = Phase.CHECK_BALL
	shot_clock = shot_clock_length
	if possession == Team.HOME:
		reset_requested.emit(Team.HOME)
	else:
		_away_timer = away_auto_delay
	last_event = "%s check ball" % possession_name()
	match_event.emit(last_event)

func _enter_quarter_end() -> void:
	if quarter >= max_quarters:
		phase = Phase.GAME_OVER
		last_event = "Game over"
	else:
		phase = Phase.QUARTER_END
		last_event = "Quarter %d ended" % quarter
	match_event.emit(last_event)
