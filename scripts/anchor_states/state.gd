class_name State
extends Node
# Base class for anchor states. The StateMachine forwards _physics_process;
# input is NOT forwarded — the Ship owns all mouse input and drives the
# anchor via anchor.fire()/request_retract().

var anchor: Anchor  # back-reference to the Anchor node (set by anchor.gd on _ready)

func enter() -> void:
	pass

func exit() -> void:
	pass

func physics_process(_delta: float) -> void:
	pass
