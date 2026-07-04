class_name LaunchedState
extends State
# Anchor flying outward along fly_direction. Chain drawn from hole to head.
# Retract when: head reaches seabed OR chain length >= MAX_CHAIN_LEN.
# (Item collisions are handled by the Item's own area_entered — the head
# is an Area2D in group anchor_head; it does NOT stop on hit, so one shot can
# pass through multiple items.)

func enter() -> void:
	# Launch from the current hole position.
	anchor.head.global_position = anchor._get_hole_global()
	anchor.chain.visible = true
	anchor._update_chain()

func physics_process(delta: float) -> void:
	var speed_factor := Game.ANCHOR_SPEED_MIN_RATIO + (1.0 - Game.ANCHOR_SPEED_MIN_RATIO) * anchor.fly_direction.y
	var speed := Game.ANCHOR_FIRE_SPEED * speed_factor
	anchor.head.global_position += anchor.fly_direction * speed * delta
	anchor.head.rotation = anchor.fly_direction.angle() - PI / 2
	anchor._update_chain()
	# Seabed?
	if anchor.head.global_position.y >= Game.SEABED_Y:
		_retract()
		return
	# Chain too long?
	var hole := anchor._get_hole_global()
	if anchor.head.global_position.distance_to(hole) >= Game.MAX_CHAIN_LEN:
		_retract()

func _retract() -> void:
	anchor.state_machine.change_to("Retracting")
