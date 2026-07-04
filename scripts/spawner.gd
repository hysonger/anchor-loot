class_name Spawner
extends Node2D
# Periodically spawns items on the right edge at a random depth while playing.

@export var spawn_interval := 1.4
const DRIFT_ITEM_SCENE   := preload("res://scenes/drift_item.tscn")
const FLOATER_ITEM_SCENE := preload("res://scenes/floater_item.tscn")

var _timer := 0.0

func _physics_process(delta: float) -> void:
	if not Game.is_playing():
		return
	_timer += delta
	if _timer >= spawn_interval:
		_timer = 0.0
		_spawn_one()

func _spawn_one() -> void:
	var scene: PackedScene = DRIFT_ITEM_SCENE if randf() < 0.5 else FLOATER_ITEM_SCENE
	var item: Item = scene.instantiate()
	add_child(item)
	var y := randf_range(Game.SPAWN_Y_MIN, Game.SPAWN_Y_MAX)
	item.setup(Vector2(Game.SPAWN_X, y))

func clear_all() -> void:
	for c in get_children():
		if c is Item:
			c.queue_free()
