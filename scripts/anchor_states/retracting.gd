class_name RetractingState
extends State
# Anchor being pulled back to the hole. When close enough, go Idle.

const ARRIVE_THRESHOLD := 6.0

func enter() -> void:
    anchor.chain.visible = true
    anchor.head.monitorable = true

func physics_process(delta: float) -> void:
    var hole := anchor._get_hole_global()
    var to_hole := hole - anchor.head.global_position
    var dist := to_hole.length()
    if dist <= ARRIVE_THRESHOLD:
        anchor.state_machine.change_to("Idle")
        return
    # Pull back at fixed px/s, but never overshoot the hole.
    var step := minf(dist, Game.ANCHOR_RETRACT_SPEED * delta)
    var direction := to_hole.normalized()
    anchor.head.global_position += direction * step
    anchor.head.rotation = direction.angle() + PI / 2
    anchor._update_chain()
