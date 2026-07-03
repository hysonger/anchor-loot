class_name LaunchedState
extends State
# Anchor flying outward along fly_direction. Chain drawn from hole to head.
# Retract when: head reaches seabed OR chain length >= MAX_CHAIN_LEN.
# (Hazard collisions are handled by the Hazard's own area_entered — the head
# is an Area2D in group anchor_head; it does NOT stop on hit, so one shot can
# pass through multiple hazards.)

func enter() -> void:
	# Launch from the current hole position.
	anchor.head.global_position = anchor._get_hole_global()
	anchor.chain.visible = true
	anchor._update_chain()

func physics_process(delta: float) -> void:
	anchor.head.global_position += anchor.fly_direction * Game.ANCHOR_FIRE_SPEED * delta
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
