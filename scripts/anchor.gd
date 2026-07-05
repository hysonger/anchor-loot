class_name Anchor
extends Node2D
# The anchor: owns a StateMachine, a Chain (Line2D) and a Head (Area2D).
# Ship owns all input and drives this via fire()/request_retract().

@onready var state_machine: StateMachine = $StateMachine
@onready var chain: Line2D = $Chain
@onready var head: Area2D = $Head

# Set by Main on _ready (Task 9). Tolerate null until then.
var ship: Node = null

# Current fly direction (normalized), valid while Launched.
var fly_direction: Vector2 = Vector2.ZERO

# Combo counter: incremented on each hit during one flight. Reset on Idle.
var combo_count: int = 0

# Called by Item on hit. Returns the multiplier for this hit (1, 2, 3...).
func register_hit() -> int:
    combo_count += 1
    return combo_count

func _ready() -> void:
    state_machine.init("Idle", self)
    Game.game_over.connect(_on_game_over)

func _on_game_over() -> void:
    state_machine.change_to("Idle")

# ---- Hole position (where the chain starts / head rests) ----
func _get_hole_global() -> Vector2:
    if ship != null:
        return ship.anchor_hole_global()
    return Vector2(Game.SHIP_X, Game.WATERLINE_Y)

func _snap_head_to_hole() -> void:
    head.global_position = _get_hole_global()
    chain.clear_points()

func _update_chain() -> void:
    chain.clear_points()
    chain.add_point(_get_hole_global())
    chain.add_point(head.global_position)

# ---- Public API driven by Ship ----
func can_fire() -> bool:
    return state_machine.current is IdleState

func fire(direction: Vector2) -> void:
    # direction must already be normalized + "never-up"-clamped by the Ship.
    if not can_fire():
        return
    fly_direction = direction
    state_machine.change_to("Launched")

func request_retract() -> void:
    if state_machine.current is LaunchedState:
        state_machine.change_to("Retracting")
