class_name Spawner
extends Node2D
# Periodically spawns items on the right edge at a random depth while playing.

@export var spawn_interval := 1.2

const SPAWN_TABLE: Array[Dictionary] = [
    {"scene": preload("res://scenes/junk_item.tscn"),             "weight": 0.25},
    {"scene": preload("res://scenes/normal_fish_item.tscn"),      "weight": 0.30},
    {"scene": preload("res://scenes/aggressive_fish_item.tscn"),  "weight": 0.20},
    {"scene": preload("res://scenes/chest_item.tscn"),            "weight": 0.25},
]

var _timer := 0.0

func _physics_process(delta: float) -> void:
    if not Game.is_playing():
        return
    _timer += delta
    if _timer >= spawn_interval:
        _timer = 0.0
        _spawn_one()

func _spawn_one() -> void:
    var scene: PackedScene = _pick_spawn_scene()
    var item: Item = scene.instantiate()
    add_child(item)
    var y_min := Game.SPAWN_Y_MIN
    var y_max := Game.SPAWN_Y_MAX
    if item is ChestItem:
        y_min = Game.CHEST_SPAWN_Y_MIN
        y_max = Game.CHEST_SPAWN_Y_MAX
    var y := randf_range(y_min, y_max)
    item.setup(Vector2(Game.SPAWN_X, y))

func _pick_spawn_scene() -> PackedScene:
    return Game.spawn_compensator.pick_and_record()

func clear_all() -> void:
    for c in get_children():
        if c is Item:
            c.queue_free()
