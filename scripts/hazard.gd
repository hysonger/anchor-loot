class_name Hazard
extends Area2D
# A drifting (A) or floating (B) hazard. Self-dispatches collisions by group:
#  - hit by anchor_head (group): score + destroy self (anchor keeps flying).
#  - overlaps ship (group) AND self is FLOATER: damage ship + destroy self.

enum Kind { DRIFT, FLOATER }

@export var kind: Kind = Kind.DRIFT
var velocity: Vector2 = Vector2.ZERO

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	_apply_visual()

func setup(k: Kind, pos: Vector2) -> void:
	kind = k
	global_position = pos
	velocity.x = randf_range(Game.HAZARD_VX_MIN, Game.HAZARD_VX_MAX)
	if kind == Kind.FLOATER:
		velocity.y = randf_range(Game.FLOATER_VY_MIN, Game.FLOATER_VY_MAX)
	else:
		velocity.y = 0.0
	_apply_visual()

func _physics_process(delta: float) -> void:
	global_position += velocity * delta
	# Floaters stop rising at the waterline; then drift along the surface.
	if kind == Kind.FLOATER and velocity.y < 0.0 and global_position.y <= Game.WATERLINE_Y:
		global_position.y = Game.WATERLINE_Y
		velocity.y = 0.0
	# Cull when off the left edge.
	if global_position.x < -60.0:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("anchor_head"):
		Game.add_score(Game.SCORE_PER_KILL)
		queue_free()
	elif area.is_in_group("ship") and kind == Kind.FLOATER:
		Game.take_damage(Game.DAMAGE_PER_HIT)
		queue_free()

func _apply_visual() -> void:
	var body: Polygon2D = $Body
	if body == null:
		return
	if kind == Kind.DRIFT:
		body.color = Color(0.85, 0.6, 0.2, 1)   # amber block
		body.polygon = PackedVector2Array([Vector2(-12, -12), Vector2(12, -12), Vector2(12, 12), Vector2(-12, 12)])
	else:
		body.color = Color(0.2, 0.7, 0.5, 1)     # teal triangle
		body.polygon = PackedVector2Array([Vector2(0, -14), Vector2(12, 12), Vector2(-12, 12)])
