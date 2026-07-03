class_name Ship
extends Area2D
# Ship: floats at the waterline, is an Area2D in group "ship" (for B-type collisions),
# reports its anchor-hole position, and drives the anchor via mouse clicks.

var anchor: Node = null  # set by Main on _ready (Task 9)

# Aim a direction so the anchor never fires upward: clamp y to >= 0, then normalize.
# Input `dir` = (mouse_global - hole_global). If dir is zero/degenerate, fire straight down.
static func clamp_aim(dir: Vector2) -> Vector2:
	var d := dir
	d.y = maxf(0.0, d.y)   # never up; horizontal is the max angle
	if d.length_squared() < 0.0001:
		return Vector2.DOWN
	return d.normalized()

func anchor_hole_global() -> Vector2:
	# The anchor hole sits at the waterline, at the ship's x.
	return Vector2(Game.SHIP_X, Game.WATERLINE_Y)

func _unhandled_input(event: InputEvent) -> void:
	if not Game.is_playing():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var hole := anchor_hole_global()
		var dir := clamp_aim(event.global_position - hole)
		if anchor != null:
			if anchor.can_fire():
				anchor.fire(dir)
			else:
				anchor.request_retract()
