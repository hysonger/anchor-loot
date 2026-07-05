class_name ChestItem
extends Item
# 箱子：左移 + 小幅上下浮动。被锚击毁时原地生成一个随机掉落物。

const DAMAGE := 25
const SCORE := 10

const LOOT_TABLE: Array[Dictionary] = [
	{"scene": preload("res://scenes/aggressive_fish_item.tscn"),  "weight": 0.20},
	{"scene": preload("res://scenes/treasure_item_small.tscn"),   "weight": 0.50},
	{"scene": preload("res://scenes/treasure_item_large.tscn"),   "weight": 0.10},
]

var _spawn_y: float = 0.0
var _swing_time: float = 0.0

func _init_velocity() -> Vector2:
	_spawn_y = global_position.y
	_swing_time = randf_range(0.0, TAU)
	return Vector2(randf_range(Game.CHEST_VX_MIN, Game.CHEST_VX_MAX), 0.0)

func _post_move(delta: float) -> void:
	if _dying:
		return
	super._post_move(delta)
	_swing_time += delta
	global_position.y = _spawn_y + sin(_swing_time * Game.CHEST_SWING_FREQ) * Game.CHEST_SWING_AMP

func _on_killed() -> void:
	_dying = true
	$CollisionShape2D.set_deferred("disabled", true)
	$Sprite2D.texture = preload("res://res/item_chest open.png")
	velocity = Vector2(0.0, 40.0)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(queue_free)

	var scene: PackedScene = _pick_loot_scene()
	var item: Item = scene.instantiate()
	get_parent().call_deferred("add_child", item)
	item.setup(global_position)

func _pick_loot_scene() -> PackedScene:
	var roll := randf()
	var total := 0.0
	for entry in LOOT_TABLE:
		total += entry.weight
	for entry in LOOT_TABLE:
		var norm: float = entry.weight / total
		if roll <= norm:
			return entry.scene
		roll -= norm
	return LOOT_TABLE[-1].scene

func _get_damage() -> int:
	return DAMAGE

func _get_score() -> int:
	return SCORE
