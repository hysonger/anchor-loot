class_name TreasureItem
extends Item
# 宝藏：仅从箱子掉落。缓慢向下坠落至海底销毁。大小由 treasure_size export 区分。

enum Size { SMALL, LARGE }
@export var treasure_size: Size = Size.SMALL

const DAMAGE := 0

func _init_velocity() -> Vector2:
	var vy := Game.TREASURE_FALL_SPEED_SMALL if treasure_size == Size.SMALL else Game.TREASURE_FALL_SPEED_LARGE
	return Vector2(0.0, vy)

func _post_move(_delta: float) -> void:
	super._post_move(_delta)
	if not _dying and global_position.y >= Game.SEABED_Y:
		_dying = true
		var tween := create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 0.3).set_trans(Tween.TRANS_QUAD)
		tween.tween_callback(queue_free)

func _get_damage() -> int:
	return DAMAGE

func _get_score() -> int:
	return 100 if treasure_size == Size.SMALL else 500
