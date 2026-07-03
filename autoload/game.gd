extends Node
# Game singleton — global flow state, durability, score, signals, and tunable constants.

# ---- Flow state machine (enum + match; too simple for State classes) ----
enum FlowState { READY, PLAYING, GAME_OVER }

signal durability_changed(current: int, maxv: int)
signal score_changed(score: int)
signal game_over()
signal flow_changed(state: FlowState)

var flow_state: FlowState = FlowState.READY
var durability: int = MAX_DURABILITY
var max_durability: int = MAX_DURABILITY
var score: int = 0

# ---- Tunable constants (one place to tweak balance) ----
const VIEWPORT_W := 1152
const VIEWPORT_H := 648
const WATERLINE_Y := 180
const SEABED_Y := 600
const SPAWN_X := 1170
const SPAWN_Y_MIN := 220
const SPAWN_Y_MAX := 560
const SHIP_X := 150

const MAX_DURABILITY := 100
const SCORE_PER_KILL := 10
const DAMAGE_PER_HIT := 5

const HAZARD_VX_MIN := -180.0
const HAZARD_VX_MAX := -90.0
const FLOATER_VY_MIN := -70.0
const FLOATER_VY_MAX := -25.0

const MAX_CHAIN_LEN := 460.0
const ANCHOR_FIRE_SPEED := 650.0
const ANCHOR_RETRACT_SPEED := 900.0
# No FIRE_ANGLE_MAX_DEG: the only aim constraint is "never up" (dir.y >= 0); horizontal is the max.

func is_playing() -> bool:
	return flow_state == FlowState.PLAYING

func take_damage(n: int) -> void:
	if flow_state != FlowState.PLAYING:
		return
	durability = max(0, durability - n)
	durability_changed.emit(durability, max_durability)
	if durability <= 0:
		game_over.emit()
		_set_flow(FlowState.GAME_OVER)

func add_score(n: int) -> void:
	score += n
	score_changed.emit(score)

func reset() -> void:
	durability = MAX_DURABILITY
	score = 0
	durability_changed.emit(durability, max_durability)
	score_changed.emit(score)

func on_start_button_pressed() -> void:
	match flow_state:
		FlowState.READY:
			_set_flow(FlowState.PLAYING)
		FlowState.GAME_OVER:
			reset()
			_set_flow(FlowState.PLAYING)
		FlowState.PLAYING:
			pass  # ignored

func _set_flow(s: FlowState) -> void:
	flow_state = s
	flow_changed.emit(s)
