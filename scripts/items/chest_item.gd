class_name ChestItem
extends Item
# 箱子：纯左移。被锚击毁时原地生成一个随机掉落物。

const DAMAGE := 25
const SCORE := 10

const LOOT_TABLE: Array[Dictionary] = [
	{"scene": preload("res://scenes/junk_item.tscn"),             "weight": 0.100},
	{"scene": preload("res://scenes/normal_fish_item.tscn"),      "weight": 0.050},
	{"scene": preload("res://scenes/aggressive_fish_item.tscn"),  "weight": 0.025},
	{"scene": preload("res://scenes/treasure_item_small.tscn"),   "weight": 0.020},
	{"scene": preload("res://scenes/treasure_item_large.tscn"),   "weight": 0.010},
]

func _init_velocity() -> Vector2:
	return Vector2(randf_range(Game.CHEST_VX_MIN, Game.CHEST_VX_MAX), 0.0)

func _on_killed() -> void:
	var scene: PackedScene = _pick_loot_scene()
	var item: Item = scene.instantiate()
	get_parent().add_child(item)
	item.setup(global_position)

func _pick_loot_scene() -> PackedScene:
	var roll := randf()
	var total := 0.0
	for entry in LOOT_TABLE:
		total += entry.weight
	for entry in LOOT_TABLE:
		var norm := entry.weight / total
		if roll <= norm:
			return entry.scene
		roll -= norm
	return LOOT_TABLE[-1].scene

func _get_damage() -> int:
	return DAMAGE

func _get_score() -> int:
	return SCORE
