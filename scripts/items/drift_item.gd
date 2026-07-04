class_name DriftItem
extends Item
# 纯左移。vy=0，基类水线钳制天然不触发；接触船即扣血（基类行为）。

const DAMAGE := 25

func _init_velocity() -> Vector2:
	return Vector2(randf_range(Game.ITEM_VX_MIN, Game.ITEM_VX_MAX), 0.0)

func _get_damage() -> int:
	return DAMAGE

func _get_score() -> int:
	return Game.SCORE_PER_KILL
