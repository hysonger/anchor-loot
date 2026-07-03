class_name StateMachine
extends Node
# Generic state machine for the anchor. Holds the current State and forwards
# _physics_process. State switching calls old.exit() then new.enter().

@onready var states: Dictionary = _collect_states()
var current: State

func _collect_states() -> Dictionary:
	var d := {}
	for child in get_children():
		if child is State:
			d[child.name] = child
	return d

func init(initial_state_name: String, anchor: Anchor) -> void:
	for s in states.values():
		s.anchor = anchor
	change_to(initial_state_name)

func change_to(state_name: String) -> void:
	if not states.has(state_name):
		push_error("StateMachine: unknown state '%s'" % state_name)
		return
	if current != null:
		current.exit()
	current = states[state_name]
	current.enter()

func _physics_process(delta: float) -> void:
	if current != null:
		current.physics_process(delta)
