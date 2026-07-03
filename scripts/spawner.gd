class_name Spawner
extends Node2D
# Periodically spawns hazards on the right edge at a random depth while playing.

@export var spawn_interval := 1.4
const HAZARD_SCENE := preload("res://scenes/hazard.tscn")

var _timer := 0.0

func _physics_process(delta: float) -> void:
	if not Game.is_playing():
		return
	_timer += delta
	if _timer >= spawn_interval:
		_timer = 0.0
		_spawn_one()

func _spawn_one() -> void:
	var h: Hazard = HAZARD_SCENE.instantiate()
	add_child(h)
	var k: Hazard.Kind = Hazard.Kind.DRIFT if randf() < 0.5 else Hazard.Kind.FLOATER
	var y := randf_range(Game.SPAWN_Y_MIN, Game.SPAWN_Y_MAX)
	h.setup(k, Vector2(Game.SPAWN_X, y))

func clear_all() -> void:
	for c in get_children():
		if c is Hazard:
			c.queue_free()
