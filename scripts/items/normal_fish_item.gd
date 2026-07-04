class_name NormalFishItem
extends Item
# 普通鱼：左移 + 垂直正弦摆动。摆动以 setup() 时的 y 为基准。

const DAMAGE := 10
const SCORE := 20

var _spawn_y: float = 0.0
var _swing_time: float = 0.0

func _ready():
	super()
	$AnimatedSprite2D.play()

func _init_velocity() -> Vector2:
	_spawn_y = global_position.y
	_swing_time = randf_range(0.0, TAU)
	return Vector2(randf_range(Game.FISH_VX_MIN, Game.FISH_VX_MAX), 0.0)

func _post_move(delta: float) -> void:
	super._post_move(delta)
	_swing_time += delta
	global_position.y = _spawn_y + sin(_swing_time * Game.FISH_SWING_FREQ) * Game.FISH_SWING_AMP

func _get_damage() -> int:
	return DAMAGE

func _get_score() -> int:
	return SCORE
