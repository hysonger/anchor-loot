class_name IdleState
extends State
# Anchor resting at the ship's anchor hole, chain hidden.

func enter() -> void:
	anchor.combo_count = 0
	anchor.head.visible = true
	anchor.chain.visible = false
	anchor._snap_head_to_hole()

func physics_process(_delta: float) -> void:
	# While idle, keep the head pinned to the (possibly moving) hole.
	anchor._snap_head_to_hole()
