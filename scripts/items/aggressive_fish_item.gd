class_name AggressiveFishItem
extends "res://scripts/items/normal_fish_item.gd"
# 攻击性鱼：继承普通鱼摆动。进入检测范围后转向朝向船，停顿后直线冲撞。

enum AggroState { PATROL, WINDUP, CHARGE }

const AGGRO_DAMAGE := 30
const AGGRO_SCORE := 40

var _aggro_state: AggroState = AggroState.PATROL
var _windup_timer: float = 0.0

func _post_move(delta: float) -> void:
	match _aggro_state:
		AggroState.PATROL:
			super._post_move(delta)
			if _distance_to_ship() <= Game.AGGRO_DETECT_DIST:
				_aggro_state = AggroState.WINDUP
				_windup_timer = 0.0
		AggroState.WINDUP:
			_windup_timer += delta
			_face_ship()
			if _windup_timer >= Game.AGGRO_WINDUP_TIME:
				_aggro_state = AggroState.CHARGE
				velocity = _dir_to_ship() * Game.AGGRO_CHARGE_SPEED
		AggroState.CHARGE:
			pass  # velocity set at transition; base _physics_process moves us

func _distance_to_ship() -> float:
	return global_position.distance_to(Vector2(Game.SHIP_X, Game.WATERLINE_Y))

func _dir_to_ship() -> Vector2:
	var d := Vector2(Game.SHIP_X, Game.WATERLINE_Y) - global_position
	if d.length_squared() < 0.0001:
		return Vector2.LEFT
	return d.normalized()

func _face_ship() -> void:
	rotation = _dir_to_ship().angle()

func _get_damage() -> int:
	return AGGRO_DAMAGE

func _get_score() -> int:
	return AGGRO_SCORE
