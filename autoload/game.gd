extends Node
# Game singleton — global flow state, durability, score, signals, and tunable constants.

# ---- Flow state machine (enum + match; too simple for State classes) ----
enum FlowState { READY, PLAYING, GAME_OVER }

signal durability_changed(current: int, maxv: int)
signal score_changed(score: int)
signal game_over()
signal flow_changed(state: FlowState)
signal score_popup(points: int, multiplier: int, at_position: Vector2)

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

# ---- 垃圾（JunkItem）----
const JUNK_VX_MIN := -180.0
const JUNK_VX_MAX := -90.0
const JUNK_VY_MIN := -70.0
const JUNK_VY_MAX := -25.0

# ---- 箱子（ChestItem）----
const CHEST_VX_MIN := -150.0
const CHEST_VX_MAX := -80.0

# ---- 鱼（NormalFish / AggressiveFish 巡逻态）----
const FISH_VX_MIN    := -150.0
const FISH_VX_MAX    := -80.0
const FISH_SWING_AMP  := 35.0
const FISH_SWING_FREQ := 2.5

# ---- 攻击性鱼（AggressiveFish）----
const AGGRO_DETECT_DIST   := 576.0
const AGGRO_WINDUP_TIME   := 0.5
const AGGRO_CHARGE_SPEED  := 300.0

# ---- 宝藏（TreasureItem）----
const TREASURE_FALL_SPEED_SMALL := 25
const TREASURE_FALL_SPEED_LARGE := 100

const SPAWN_PROTECTION_TIME := 0.5

const MAX_CHAIN_LEN := 650
const ANCHOR_FIRE_SPEED := 800.0
const ANCHOR_RETRACT_SPEED := 900.0
# Anchor speed curve: horizontal shots run at this fraction of vertical speed.
# 0.0 = motionless at horizontal, 1.0 = no compensation (all directions equal).
const ANCHOR_SPEED_MIN_RATIO := 0.8125   # horizontal speed / vertical speed (650 / 800)
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
