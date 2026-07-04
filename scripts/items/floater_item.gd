class_name FloaterItem
extends Item
# 左移 + 上浮；抵水面即止（基类通用规则），随后水面漂流，可撞船扣血。

const DAMAGE := 25

func _init_velocity() -> Vector2:
	return Vector2(randf_range(Game.ITEM_VX_MIN, Game.ITEM_VX_MAX),
					randf_range(Game.FLOATER_VY_MIN, Game.FLOATER_VY_MAX))

func _get_damage() -> int:
	return DAMAGE
