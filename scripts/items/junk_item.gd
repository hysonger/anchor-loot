class_name JunkItem
extends Item
# 垃圾：左移 + 上浮至水面即止（复用基类水线钳制），撞船扣耐久。

const DAMAGE := 20
const SCORE := 10

func _init_velocity() -> Vector2:
	return Vector2(randf_range(Game.JUNK_VX_MIN, Game.JUNK_VX_MAX),
					randf_range(Game.JUNK_VY_MIN, Game.JUNK_VY_MAX))

func _get_damage() -> int:
	return DAMAGE

func _get_score() -> int:
	return SCORE
