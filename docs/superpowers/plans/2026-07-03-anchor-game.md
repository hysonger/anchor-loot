# Anchor Game Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Godot 2D side-scrolling game where a ship floats on water, hazards drift/float in from the right, the ship fires an anchor (mouse-aimed) to destroy hazards for score, and B-type floaters damage the ship's durability until Game Over.

**Architecture:** Godot 4.6 project. A mixed state-machine strategy: the anchor uses a formal State-class inheritance pattern (Idle/Launched/Retracting + a generic StateMachine node); game flow uses an enum `match` (READY/PLAYING/GAME_OVER) in a `Game` autoload singleton; hazards use a `Kind` enum. All cross-node state (durability, score, flow) lives in the `Game` autoload which broadcasts signals. Collision is decoupled via groups (`ship`, `anchor_head`). Mouse-aimed anchor firing with a "never-up" direction clamp. Pure geometric visuals (Polygon2D/ColorRect/Line2D), zero external assets.

**Tech Stack:** Godot 4.6.stable (accessed via the godot MCP server), GDScript, 2D nodes (Node2D, Area2D, ColorRect, Line2D, CanvasLayer, Button, ProgressBar). No external assets, no addons.

## Global Constraints

- Engine: Godot 4.6.stable (MCP `get_godot_version`). Project at `/Users/songer/ownCloud/Projects/anchor-game`.
- Viewport: `1152 x 648`, stretch disabled (disabled stretch mode — fixed window). All coordinate constants live in `game.gd` (Autoload registered as `Game`).
- Coordinate system: origin top-left, x→right, y→down. Water at `WATERLINE_Y=180`, seabed at `SEABED_Y=600`, ship x at `SHIP_X=150`, spawn x at `SPAWN_X=1170`, spawn y in `[220,560]`.
- Visuals: pure geometry only — `ColorRect`, `Polygon2D`, `Line2D`. No textures, no audio, no particles.
- State machine rule: anchor = State class hierarchy; game flow = enum `match`; hazard = `Kind` enum. No extra flags for "can't refire" — it's enforced by states.
- Input: mouse left-click fires/retracts the anchor (direction = mouse→anchor-hole, clamped "never-up": `dir.y = max(0, dir.y)`). Space key is bound as a `Shortcut` on the StartButton only (start/restart). No keyboard controls for the anchor.
- Scoring: A and B both destructible by anchor (+`SCORE_PER_KILL`=10). Only B (FLOATER) damages ship (`DAMAGE_PER_HIT`=5, `MAX_DURABILITY`=100). B floats up but stops at waterline (`y ≤ WATERLINE_Y` zeroes `vy`).
- Collision is via `Area2D.area_entered`, dispatched by group membership. Hazards self-destruct in their own callback.
- No git repo is initialized; commits in this plan are skipped — replace `git add/commit` steps with a verification note. (If a repo is later initialized, commits should be added.)
- Testing reality: Godot has no built-in unit test runner in this project and no GUT addon installed. Verification is via `run_project` (MCP) + debug output, plus isolated checks of pure functions. Treat each task's "verify" step as the test cycle.

---

## File Structure

| File | Responsibility |
|---|---|
| `project.godot` | Engine config: viewport size, disable stretch, register `Game` autoload, main scene. |
| `autoload/game.gd` | `Game` singleton: `FlowState` enum + `match` transitions, durability/score vars, `take_damage/add_score/on_start_button_pressed/reset/is_playing`, signals `durability_changed/score_changed/game_over/flow_changed`, all tunable `const`. |
| `scripts/state_machine.gd` | Generic `StateMachine` node: holds current `State`, `init(initial)`, `change_to(name)`, forwards `_physics_process`. |
| `scripts/anchor_states/state.gd` | `State` base class: `anchor` ref, `enter/exit/physics_process`. |
| `scripts/anchor_states/idle.gd` | Idle state: head at anchor hole, chain hidden; nothing in physics. |
| `scripts/anchor_states/launched.gd` | Launched state: head flies along direction, chain drawn, retract on seabed/chain-len/collision-crossed. |
| `scripts/anchor_states/retracting.gd` | Retracting state: head moves to hole, → Idle on arrival. |
| `scripts/anchor.gd` | Anchor root: holds `ship` ref, exposes `can_fire/fire(direction)/request_retract`, drives StateMachine, owns Chain/Head. |
| `scripts/ship.gd` | Ship: `Area2D` in `ship` group, draws hull, `anchor_hole_global()`, mouse-click handling → `anchor.fire/request_retract` with direction clamp. |
| `scripts/hazard.gd` | Hazard: `Area2D`, `Kind` enum DRIFT/FLOATER, `setup(kind,pos)`, move+waterline clamp, collision dispatch. |
| `scripts/spawner.gd` | Spawner: timer-based instantiation on right edge, `clear_all()`. |
| `scripts/main.gd` | Main: scene assembly wiring, HUD signal binding, MessageLabel text updates, reset coordination. |
| `scenes/anchor.tscn` | Anchor scene: Anchor(Node2D) > StateMachine(Node, with Idle/Launched/Retracting State children) + Chain(Line2D) + Head(Area2D > CollisionShape2D + Polygon2D). |
| `scenes/ship.tscn` | Ship scene: Ship(Area2D > CollisionShape2D + Polygon2D hull + sail Polygon2D). |
| `scenes/hazard.tscn` | Hazard scene: Hazard(Area2D > CollisionShape2D + Body Polygon2D). |
| `scenes/main.tscn` | Root scene: Main > Background/Water/Seabed ColorRects + Spawner + Ship + Anchor + HUD(CanvasLayer). |

Build order: project config + autoload → anchor state machine (most complex, isolated) → ship + mouse firing → hazard + spawner → main assembly + HUD + flow. The anchor and game-flow are the load-bearing pieces; visuals/hazards are simpler and built later.

---

## Task 1: Project scaffold, autoload, and constants

**Files:**
- Create: `project.godot` (via MCP `get_project_info` then manual edits / recreate)
- Create: `autoload/game.gd`
- Modify: `project.godot` (register autoload, main scene, viewport)

**Interfaces:**
- Produces: `Game` autoload singleton with all `const` (viewport, water, seabed, spawn, ship, speeds, scoring), `FlowState` enum, `flow_state` var, `durability/max_durability/score` vars, signals, and stub methods `on_start_button_pressed/take_damage/add_score/reset/is_playing` that will be implemented in this task.

- [ ] **Step 1: Confirm Godot version via MCP**

Run MCP `get_godot_version`. Expected: `4.6.3.stable...`.

- [ ] **Step 2: Write `autoload/game.gd` with constants + flow enum + state methods**

Create `autoload/game.gd`:

```gdscript
extends Node
# Game singleton — global flow state, durability, score, signals, and tunable constants.

# ---- Flow state machine (enum + match; too simple for State classes) ----
enum FlowState { READY, PLAYING, GAME_OVER }

signal durability_changed(current: int, maxv: int)
signal score_changed(score: int)
signal game_over()
signal flow_changed(state: FlowState)

var flow_state: FlowState = FlowState.READY
var durability: int = MAX_DURABILITY
var max_durability: int = MAX_DURABILITY
var score: int = 0

# ---- Tunable constants (one place to tweak balance) ----
const VIEWPORT_W := 1152
const VIEWPORT_H := 648
const WATERLINE_Y := 180
const SEABED_Y := 600
const SPAWN_X := 1170
const SPAWN_Y_MIN := 220
const SPAWN_Y_MAX := 560
const SHIP_X := 150

const MAX_DURABILITY := 100
const SCORE_PER_KILL := 10
const DAMAGE_PER_HIT := 5

const HAZARD_VX_MIN := -180.0
const HAZARD_VX_MAX := -90.0
const FLOATER_VY_MIN := -70.0
const FLOATER_VY_MAX := -25.0

const MAX_CHAIN_LEN := 460.0
const ANCHOR_FIRE_SPEED := 650.0
const ANCHOR_RETRACT_SPEED := 900.0
# No FIRE_ANGLE_MAX_DEG: the only aim constraint is "never up" (dir.y >= 0); horizontal is the max.

func is_playing() -> bool:
	return flow_state == FlowState.PLAYING

func take_damage(n: int) -> void:
	if flow_state != FlowState.PLAYING:
		return
	durability = max(0, durability - n)
	durability_changed.emit(durability, max_durability)
	if durability <= 0:
		game_over.emit()
		_set_flow(FlowState.GAME_OVER)

func add_score(n: int) -> void:
	score += n
	score_changed.emit(score)

func reset() -> void:
	durability = MAX_DURABILITY
	score = 0
	durability_changed.emit(durability, max_durability)
	score_changed.emit(score)

func on_start_button_pressed() -> void:
	match flow_state:
		FlowState.READY:
			_set_flow(FlowState.PLAYING)
		FlowState.GAME_OVER:
			reset()
			_set_flow(FlowState.PLAYING)
		FlowState.PLAYING:
			pass  # ignored

func _set_flow(s: FlowState) -> void:
	flow_state = s
	flow_changed.emit(s)
```

- [ ] **Step 3: Create the Godot project via MCP and register the autoload**

Run MCP `get_project_info` with `projectPath="/Users/songer/ownCloud/Projects/anchor-game"`. If it reports no project, create one:

Use MCP `list_projects` on `/Users/songer/ownCloud/Projects` (non-recursive) to confirm none exists. Then manually write `project.godot`:

```ini
config_version=5

[application]
config/name="Anchor Game"
run/main_scene="res://scenes/main.tscn"
config/features=PackedStringArray("4.6", "GL Compatibility")

[autoload]
Game="*res://autoload/game.gd"

[display]
window/size/viewport_width=1152
window/size/viewport_height=648
window/stretch/mode="disabled"

[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
```

Note: `main.tscn` doesn't exist yet — the engine will warn if run before Task 9 creates it. That's expected and fine; do not run the project yet.

- [ ] **Step 4: Verify the project is recognized**

Run MCP `get_project_info` with the projectPath. Expected: it recognizes the project (name "Anchor Game"). If it errors, double-check `project.godot` path and `config_version=5`.

**Verification (test cycle):** `Game` autoload loads without parse errors. Since we can't run yet (no main scene), instead launch the editor via MCP `launch_editor` and check `get_debug_output` for parse errors in `game.gd`. Expect: no errors. Close the editor via MCP `stop_project`.

---

## Task 2: Generic StateMachine + State base class

**Files:**
- Create: `scripts/state_machine.gd`
- Create: `scripts/anchor_states/state.gd`

**Interfaces:**
- Consumes: nothing
- Produces: `class_name StateMachine` (Node) with `var current: State`, `func init(initial: State)`, `func change_to(state_name: String)`, `_physics_process(delta)`. `class_name State` (Node) with `var anchor`, `enter()/exit()/physics_process(delta)`.

- [ ] **Step 1: Write `scripts/anchor_states/state.gd`**

```gdscript
class_name State
extends Node
# Base class for anchor states. The StateMachine forwards _physics_process;
# input is NOT forwarded — the Ship owns all mouse input and drives the
# anchor via anchor.fire()/request_retract().

var anchor: Node  # back-reference to the Anchor node (set by anchor.gd on _ready)

func enter() -> void:
	pass

func exit() -> void:
	pass

func physics_process(_delta: float) -> void:
	pass
```

- [ ] **Step 2: Write `scripts/state_machine.gd`**

```gdscript
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

func init(initial_state_name: String, anchor: Node) -> void:
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
```

- [ ] **Step 3: Verify syntax**

Launch editor via MCP, run `get_debug_output`. Expected: no parse errors for `state.gd` / `state_machine.gd`. The classes reference `Node`/`State` which exist. Close editor.

**Verification:** No build errors. (StateMachine can't be exercised until the anchor scene wires it — that's Task 3.)

---

## Task 3: Anchor scene + anchor.gd + Idle state (anchor rests at hole)

This is the first deliverable that's independently observable: the anchor appears at the ship's anchor hole and does nothing (Idle). Ship doesn't exist yet, so anchor.gd tolerates a null `ship` ref for now and uses a fallback hole position `(SHIP_X, WATERLINE_Y)` from `Game`.

**Files:**
- Create: `scripts/anchor_states/idle.gd`
- Create: `scripts/anchor.gd`
- Create: `scenes/anchor.tscn` (via MCP: create_scene + add_node chain; then manual @onready wiring)

**Interfaces:**
- Consumes: `StateMachine`, `State`, `Game` constants (`SHIP_X`, `WATERLINE_Y`).
- Produces: `Anchor` (Node2D) with `var ship`, `func can_fire() -> bool`, `func fire(direction: Vector2)`, `func request_retract()`, `func _get_hole_global() -> Vector2`. Idle state exists and is the initial state.

- [ ] **Step 1: Write `scripts/anchor_states/idle.gd`**

```gdscript
class_name IdleState
extends State
# Anchor resting at the ship's anchor hole, chain hidden.

func enter() -> void:
	anchor.head.visible = true
	anchor.chain.visible = false
	anchor._snap_head_to_hole()

func physics_process(_delta: float) -> void:
	# While idle, keep the head pinned to the (possibly moving) hole.
	anchor._snap_head_to_hole()
```

- [ ] **Step 2: Write `scripts/anchor.gd`**

```gdscript
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

func _ready() -> void:
	state_machine.init("Idle", self)

# ---- Hole position (where the chain starts / head rests) ----
func _get_hole_global() -> Vector2:
	if ship != null:
		return ship.anchor_hole_global()
	return Vector2(Game.SHIP_X, Game.WATERLINE_Y)

func _snap_head_to_hole() -> void:
	head.global_position = _get_hole_global()
	chain.clear_points()

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
```

Note: references `LaunchedState` and `RetractingState` which don't exist yet — Task 4/5 add them. The anchor won't compile-check cleanly until then, which is expected; defer the compile check to after Task 5.

- [ ] **Step 3: Write the complete `scenes/anchor.tscn`**

Do NOT use the MCP `create_scene`/`add_node` tools for this — write the entire file in one go with the Write tool. (The MCP add_node calls described in some skills are an alternative path, but a single Write produces a cleaner, complete scene file.) Use exactly this content:

```ini
[gd_scene load_steps=4 format=3]

[ext_resource type="Script" path="res://scripts/anchor.gd" id="1_anchor"]
[ext_resource type="Script" path="res://scripts/state_machine.gd" id="2_sm"]
[ext_resource type="Script" path="res://scripts/anchor_states/idle.gd" id="3_idle"]

[sub_resource type="RectangleShape2D" id="RectangleShape2D_1"]
size = Vector2(16, 16)

[node name="Anchor" type="Node2D"]
script = ExtResource("1_anchor")

[node name="StateMachine" type="Node" parent="."]
script = ExtResource("2_sm")

[node name="Idle" type="Node" parent="StateMachine"]
script = ExtResource("3_idle")

[node name="Chain" type="Line2D" parent="."]
default_color = Color(0.35, 0.35, 0.4, 1)
width = 3.0

[node name="Head" type="Area2D" parent="."]
groups = ["anchor_head"]

[node name="CollisionShape2D" type="CollisionShape2D" parent="Head"]
shape = SubResource("RectangleShape2D_1")

[node name="Polygon2D" type="Polygon2D" parent="Head"]
polygon = PackedVector2Array(0, -8, 10, 8, -10, 8)
color = Color(0.3, 0.3, 0.3, 1)
```

Notes: `Head` carries the `anchor_head` group (so hazards detect it). `load_steps=4` = 3 ext_resources + 1 sub_resource. The `Launched`/`Retracting` state nodes are added in Tasks 4 and 5 by rewriting this same file.

```ini
[gd_scene load_steps=4 format=3]

[ext_resource type="Script" path="res://scripts/anchor.gd" id="1_anchor"]
[ext_resource type="Script" path="res://scripts/state_machine.gd" id="2_sm"]
[ext_resource type="Script" path="res://scripts/anchor_states/idle.gd" id="3_idle"]

[sub_resource type="RectangleShape2D" id="RectangleShape2D_1"]
size = Vector2(16, 16)

[node name="Anchor" type="Node2D"]
script = ExtResource("1_anchor")

[node name="StateMachine" type="Node" parent="."]
script = ExtResource("2_sm")

[node name="Idle" type="Node" parent="StateMachine"]
script = ExtResource("3_idle")

[node name="Chain" type="Line2D" parent="."]
default_color = Color(0.35, 0.35, 0.4, 1)
width = 3.0

[node name="Head" type="Area2D" parent="."]
groups = ["anchor_head"]

[node name="CollisionShape2D" type="CollisionShape2D" parent="Head"]
shape = SubResource("RectangleShape2D_1")

[node name="Polygon2D" type="Polygon2D" parent="Head"]
polygon = PackedVector2Array(0, -8, 10, 8, -10, 8)
color = Color(0.3, 0.3, 0.3, 1)
```

- [ ] **Step 4: Verify the anchor scene loads**

Launch editor via MCP `launch_editor`, then `get_debug_output`. Expected: scene loads, `IdleState` is the initial state. No errors. The head sits at `(SHIP_X, WATERLINE_Y)` because `ship` is null. Close editor.

**Verification:** Anchor is instantiated-able and enters Idle with the head at the fallback hole. Confirm via `get_debug_output` (no errors). Full visual confirmation comes in Task 9 once the anchor is in `main.tscn`.

---

## Task 4: Launched state (anchor flies, chain draws, retracts on seabed/length)

**Files:**
- Create: `scripts/anchor_states/launched.gd`
- Modify: `scenes/anchor.tscn` (add Launched state node)

**Interfaces:**
- Consumes: `Anchor.fly_direction`, `Anchor.chain`, `Anchor.head`, `Anchor._get_hole_global()`, `Game` constants `SEABED_Y`, `MAX_CHAIN_LEN`, `ANCHOR_FIRE_SPEED`, `Game.MAX_CHAIN_LEN`.
- Produces: `class_name LaunchedState`. Transitions to `Retracting` (Task 5) on seabed/length hit. On entering, sets head to hole and gives it `fly_direction * ANCHOR_FIRE_SPEED`. Chain drawn hole→head each frame.

- [ ] **Step 1: Write `scripts/anchor_states/launched.gd`**

```gdscript
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
```

- [ ] **Step 2: Add `_update_chain` helper to `anchor.gd`**

Modify `scripts/anchor.gd` — add this method (place after `_snap_head_to_hole`):

```gdscript
func _update_chain() -> void:
	chain.clear_points()
	chain.add_point(_get_hole_global())
	chain.add_point(head.global_position)
```

- [ ] **Step 3: Add the Launched state node to `scenes/anchor.tscn`**

Edit the `.tscn`: add an ext_resource for the launched script and a child node under StateMachine. Updated file:

```ini
[gd_scene load_steps=5 format=3]

[ext_resource type="Script" path="res://scripts/anchor.gd" id="1_anchor"]
[ext_resource type="Script" path="res://scripts/state_machine.gd" id="2_sm"]
[ext_resource type="Script" path="res://scripts/anchor_states/idle.gd" id="3_idle"]
[ext_resource type="Script" path="res://scripts/anchor_states/launched.gd" id="4_launched"]

[sub_resource type="RectangleShape2D" id="RectangleShape2D_1"]
size = Vector2(16, 16)

[node name="Anchor" type="Node2D"]
script = ExtResource("1_anchor")

[node name="StateMachine" type="Node" parent="."]
script = ExtResource("2_sm")

[node name="Idle" type="Node" parent="StateMachine"]
script = ExtResource("3_idle")

[node name="Launched" type="Node" parent="StateMachine"]
script = ExtResource("4_launched")

[node name="Chain" type="Line2D" parent="."]
default_color = Color(0.35, 0.35, 0.4, 1)
width = 3.0

[node name="Head" type="Area2D" parent="."]
groups = ["anchor_head"]

[node name="CollisionShape2D" type="CollisionShape2D" parent="Head"]
shape = SubResource("RectangleShape2D_1")

[node name="Polygon2D" type="Polygon2D" parent="Head"]
polygon = PackedVector2Array(0, -8, 10, 8, -10, 8)
color = Color(0.3, 0.3, 0.3, 1)
```

- [ ] **Step 4: Verify**

Launch editor, `get_debug_output`. Expected: no errors. (Cannot visually fly yet — needs a Ship to call `fire()` and the Retracting state to exist. The compile must pass though: `LaunchedState` references `Retracting` only via string `"Retracting"`, so `change_to` will push_error at runtime if Retracting missing — but that path isn't hit in a static check.) Close editor.

**Verification:** Scene + scripts parse. Full fly behavior verified in Task 6 (after Retracting exists and Ship drives it).

---

## Task 5: Retracting state + the Idle→Launched→Retracting→Idle loop is structurally complete

**Files:**
- Create: `scripts/anchor_states/retracting.gd`
- Modify: `scenes/anchor.tscn` (add Retracting state node)

**Interfaces:**
- Consumes: `Anchor.head`, `Anchor._get_hole_global()`, `Game.ANCHOR_RETRACT_SPEED`.
- Produces: `class_name RetractingState`. On enter records nothing needed; physics moves head toward hole; on arrival transitions to `Idle`.

- [ ] **Step 1: Write `scripts/anchor_states/retracting.gd`**

```gdscript
class_name RetractingState
extends State
# Anchor being pulled back to the hole. When close enough, go Idle.

const ARRIVE_THRESHOLD := 6.0

func enter() -> void:
	anchor.chain.visible = true

func physics_process(delta: float) -> void:
	var hole := anchor._get_hole_global()
	var to_hole := hole - anchor.head.global_position
	var dist := to_hole.length()
	if dist <= ARRIVE_THRESHOLD:
		anchor.state_machine.change_to("Idle")
		return
	# Pull back at fixed px/s, but never overshoot the hole.
	var step := minf(dist, Game.ANCHOR_RETRACT_SPEED * delta)
	anchor.head.global_position += to_hole.normalized() * step
	anchor._update_chain()
```

- [ ] **Step 2: Add Retracting node to `scenes/anchor.tscn`**

Add ext_resource `id="5_retract"` for `retracting.gd` and the node. `load_steps` becomes 6. The new tree under StateMachine: Idle, Launched, Retracting. Write the final complete file:

```ini
[gd_scene load_steps=6 format=3]

[ext_resource type="Script" path="res://scripts/anchor.gd" id="1_anchor"]
[ext_resource type="Script" path="res://scripts/state_machine.gd" id="2_sm"]
[ext_resource type="Script" path="res://scripts/anchor_states/idle.gd" id="3_idle"]
[ext_resource type="Script" path="res://scripts/anchor_states/launched.gd" id="4_launched"]
[ext_resource type="Script" path="res://scripts/anchor_states/retracting.gd" id="5_retract"]

[sub_resource type="RectangleShape2D" id="RectangleShape2D_1"]
size = Vector2(16, 16)

[node name="Anchor" type="Node2D"]
script = ExtResource("1_anchor")

[node name="StateMachine" type="Node" parent="."]
script = ExtResource("2_sm")

[node name="Idle" type="Node" parent="StateMachine"]
script = ExtResource("3_idle")

[node name="Launched" type="Node" parent="StateMachine"]
script = ExtResource("4_launched")

[node name="Retracting" type="Node" parent="StateMachine"]
script = ExtResource("5_retract")

[node name="Chain" type="Line2D" parent="."]
default_color = Color(0.35, 0.35, 0.4, 1)
width = 3.0

[node name="Head" type="Area2D" parent="."]
groups = ["anchor_head"]

[node name="CollisionShape2D" type="CollisionShape2D" parent="Head"]
shape = SubResource("RectangleShape2D_1")

[node name="Polygon2D" type="Polygon2D" parent="Head"]
polygon = PackedVector2Array(0, -8, 10, 8, -10, 8)
color = Color(0.3, 0.3, 0.3, 1)
```

- [ ] **Step 3: Verify**

Launch editor, `get_debug_output`. Expected: no errors. The full state loop is now structurally present (Idle/Launched/Retracting all exist), so `anchor.fire()` would walk the whole loop if invoked. No invocation yet — Task 6 adds the Ship driver.

**Verification:** All three anchor states compile and the scene instantiates. Anchor state machine is structurally complete.

---

## Task 6: Ship scene + mouse-aimed firing direction clamp (the aim logic, isolated-tested first)

The anchor's `fire(direction)` requires a ship to call it. The core reusable logic here is the **direction clamp** (`d.y = max(0, d.y)`, normalize, "never up"). This is pure math and is the highest-risk piece — test it in isolation before wiring the ship. Since there's no unit-test runner, verify with a tiny throwaway print in a `_ready`, then remove it.

**Files:**
- Create: `scripts/ship.gd`
- Create: `scenes/ship.tscn`
- (throwaway) verify the clamp logic

**Interfaces:**
- Consumes: `Game.SHIP_X`, `Game.WATERLINE_Y`, `Anchor.can_fire/fire/request_retract`.
- Produces: `class_name Ship` (Area2D, group `ship`) with `var anchor`, `func anchor_hole_global() -> Vector2`, `_unhandled_input(event)` driving the anchor, and a static-ish helper `static func clamp_aim(dir: Vector2) -> Vector2`.

- [ ] **Step 1: Write `scripts/ship.gd` with the clamp helper**

```gdscript
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
```

- [ ] **Step 2: Verify the clamp logic in isolation**

Temporarily add at the end of `ship.gd._ready()` (which doesn't exist yet — add a `_ready`):

```gdscript
func _ready() -> void:
	# throwaway self-check of clamp_aim (remove after verifying)
	print("aim down   : ", clamp_aim(Vector2(0, 100)))      # expect (0,1)
	print("aim right  : ", clamp_aim(Vector2(100, 100)))    # expect normalized (0.707,0.707)
	print("aim up     : ", clamp_aim(Vector2(50, -100)))    # expect (1,0)  [clamped to horizontal]
	print("aim horiz  : ", clamp_aim(Vector2(-100, -5)))    # expect (-1,0) [clamped to horizontal]
	print("aim zero   : ", clamp_aim(Vector2(0,0)))         # expect (0,1)
```

To run this without a full game: temporarily instantiate a Ship. Easiest path — create `scenes/ship.tscn` (Step 3) and a throwaway `scenes/_aimtest.tscn` whose root is a Node2D with a Ship child, set as main scene in `project.godot` temporarily, run via MCP `run_project`, read `get_debug_output` for the print lines. Then revert the main scene and delete `_aimtest.tscn`.

Expected printed vectors:
- down: `(0, 1)`
- right: `(0.707107, 0.707107)`
- up (50,-100) clamped → `(1, 0)`
- horiz (-100,-5) clamped → `(-1, 0)`
- zero → `(0, 1)`

If any differs, fix `clamp_aim` (the clamp is `maxf(0, d.y)`; note `clamp_aim(Vector2(-100,-5))` gives `d=(-100,0)` → normalized `(-1,0)` ✓).

- [ ] **Step 3: Create `scenes/ship.tscn`**

Write the file directly:

```ini
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/ship.gd" id="1_ship"]

[sub_resource type="RectangleShape2D" id="RectangleShape2D_1"]
size = Vector2(90, 40)

[node name="Ship" type="Area2D"]
groups = ["ship"]
position = Vector2(150, 160)
script = ExtResource("1_ship")

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("RectangleShape2D_1")

[node name="Hull" type="Polygon2D" parent="."]
polygon = PackedVector2Array(-45, -10, 45, -10, 40, 10, -40, 10)
color = Color(0.55, 0.35, 0.2, 1)

[node name="Sail" type="Polygon2D" parent="."]
polygon = PackedVector2Array(0, -50, 0, -10, -20, -10)
color = Color(0.9, 0.9, 0.9, 1)
```

The ship sits at x=150 (matching `SHIP_X`) and y=160 so the hull bottom (y+10=170) sits just above the waterline (180); the anchor hole `anchor_hole_global()` returns y=WATERLINE_Y=180 regardless of the visual hull, so the hole is at the waterline as designed.

- [ ] **Step 4: Run the throwaway aim test**

Create `scenes/_aimtest.tscn`:

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="PackedScene" path="res://scenes/ship.tscn" id="1_ship"]

[node name="AimTest" type="Node2D"]

[node name="Ship" parent="." instance=ExtResource("1_ship")]
```

Temporarily set `project.godot` `[application] run/main_scene="res://scenes/_aimtest.tscn"`. Run MCP `run_project`, then immediately `stop_project`, then `get_debug_output`. Check the 5 printed lines match expected. Revert `project.godot` main_scene to `res://scenes/main.tscn`. Delete `scenes/_aimtest.tscn`. Remove the throwaway `_ready` print block from `ship.gd`, leaving:

```gdscript
func _ready() -> void:
	pass
```

(Then delete `_ready` entirely in Task 9 if Main wires things — but a no-op `_ready` is harmless.)

- [ ] **Step 5: Verify**

Re-launch editor after cleanup, `get_debug_output`. Expected: no errors, ship scene loads.

**Verification:** The aim-clamp math is proven correct (the print test). Ship scene exists and is in the `ship` group. Anchor is not yet wired to the ship — that's Task 9.

---

## Task 7: Hazard scene + movement + waterline clamp + collision dispatch

**Files:**
- Create: `scripts/hazard.gd`
- Create: `scenes/hazard.tscn`

**Interfaces:**
- Consumes: `Game` constants (`WATERLINE_Y`, `HAZARD_VX_*`, `FLOATER_VY_*`, `SCORE_PER_KILL`, `DAMAGE_PER_HIT`), groups `anchor_head`/`ship`.
- Produces: `class_name Hazard` (Area2D) with `enum Kind { DRIFT, FLOATER }`, `var kind`, `var velocity`, `func setup(kind: Kind, pos: Vector2)`, `_physics_process`, `_on_area_entered(area)` (connected to its own `area_entered` signal in `_ready`).

- [ ] **Step 1: Write `scripts/hazard.gd`**

```gdscript
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
		body.polygon = PackedVector2Array(-12, -12, 12, -12, 12, 12, -12, 12)
	else:
		body.color = Color(0.2, 0.7, 0.5, 1)     # teal triangle
		body.polygon = PackedVector2Array(0, -14, 12, 12, -12, 12)
```

- [ ] **Step 2: Write `scenes/hazard.tscn`**

```ini
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/hazard.gd" id="1_hazard"]

[sub_resource type="RectangleShape2D" id="RectangleShape2D_1"]
size = Vector2(24, 24)

[node name="Hazard" type="Area2D"]
script = ExtResource("1_hazard")

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("RectangleShape2D_1")

[node name="Body" type="Polygon2D" parent="."]
polygon = PackedVector2Array(-12, -12, 12, -12, 12, 12, -12, 12)
color = Color(0.85, 0.6, 0.2, 1)
```

- [ ] **Step 3: Verify**

Launch editor, `get_debug_output`. Expected: no errors. (Hazards aren't spawned yet — Task 8's spawner does that. The waterline clamp and collision logic get exercised in the end-to-end test in Task 9.)

**Verification:** Scenario + script parse. Hazard is in neither special group itself; collisions dispatch by *the other side's* group (`anchor_head`/`ship`). This is correct because the Anchor Head and Ship carry those groups.

---

## Task 8: Spawner

**Files:**
- Create: `scripts/spawner.gd`

**Interfaces:**
- Consumes: `Hazard` scene (`res://scenes/hazard.tscn`), `Game` constants (`SPAWN_X`, `SPAWN_Y_MIN`, `SPAWN_Y_MAX`), `Game.is_playing()`.
- Produces: `class_name Spawner` (Node2D) with `@export var spawn_interval := 1.4`, `func clear_all()`.

- [ ] **Step 1: Write `scripts/spawner.gd`**

```gdscript
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
```

- [ ] **Step 2: Verify**

Launch editor, `get_debug_output`. Expected: no errors. (Preload path must resolve — it does since Task 7 created `hazard.tscn`.) Close editor.

**Verification:** Spawner compiles and its preload resolves. Wiring + runtime spawn verified in Task 9.

---

## Task 9: Main scene — assemble everything + HUD + flow wiring + end-to-end run

**Files:**
- Create: `scripts/main.gd`
- Create: `scenes/main.tscn`
- Modify: `project.godot` (main_scene already `res://scenes/main.tscn` — confirm)

**Interfaces:**
- Consumes: all prior scenes/scripts, `Game` signals (`flow_changed`, `durability_changed`, `score_changed`, `game_over`).
- Produces: the runnable game. `main.gd` wires Ship↔Anchor, binds HUD, sets StartButton shortcut, updates MessageLabel on flow changes, resets Spawner on Game Over.

- [ ] **Step 1: Write `scripts/main.gd`**

```gdscript
extends Node2D
# Root scene: assembles Ship<->Anchor, wires the HUD to Game signals,
# builds the StartButton shortcut, and updates flow text.

@onready var spawner: Spawner = $Spawner
@onready var ship: Ship = $Ship
@onready var anchor: Anchor = $Anchor
@onready var durability_bar: ProgressBar = $HUD/DurabilityBar
@onready var score_label: Label = $HUD/ScoreLabel
@onready var message_label: Label = $HUD/MessageLabel
@onready var start_button: Button = $HUD/StartButton

func _ready() -> void:
	# Wire ship <-> anchor.
	ship.anchor = anchor
	anchor.ship = ship

	# Bind HUD to Game state.
	Game.durability_changed.connect(_on_durability_changed)
	Game.score_changed.connect(_on_score_changed)
	Game.flow_changed.connect(_on_flow_changed)
	Game.game_over.connect(_on_game_over)

	# StartButton drives Game; build its Space shortcut in code.
	var sc := Shortcut.new()
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_SPACE
	sc.events.append(ev)
	start_button.shortcut = sc
	start_button.pressed.connect(Game.on_start_button_pressed)

	# Initialize HUD + flow to READY without going through a transition.
	_on_durability_changed(Game.durability, Game.max_durability)
	_on_score_changed(Game.score)
	_on_flow_changed(Game.flow_state)

func _on_durability_changed(current: int, maxv: int) -> void:
	durability_bar.max_value = maxv
	durability_bar.value = current

func _on_score_changed(s: int) -> void:
	score_label.text = "Score: %d" % s

func _on_flow_changed(state: Game.FlowState) -> void:
	match state:
		Game.FlowState.READY:
			message_label.text = "准备好抛锚!"
			_apply_button(true, "开始游戏 (Space)")
			spawner.clear_all()
		Game.FlowState.PLAYING:
			message_label.text = ""
			start_button.visible = false
			start_button.disabled = true
		Game.FlowState.GAME_OVER:
			message_label.text = "Game Over — 按空格重开"
			_apply_button(true, "重新开始 (Space)")
			spawner.clear_all()

func _on_game_over() -> void:
	pass  # flow_changed(GAME_OVER) already handles messaging/clear.

func _apply_button(show: bool, text: String) -> void:
	start_button.text = text
	start_button.visible = show
	start_button.disabled = not show
```

- [ ] **Step 2: Write `scenes/main.tscn`**

```ini
[gd_scene load_steps=6 format=3]

[ext_resource type="Script" path="res://scripts/main.gd" id="1_main"]
[ext_resource type="Script" path="res://scripts/spawner.gd" id="2_spawner"]
[ext_resource type="PackedScene" path="res://scenes/ship.tscn" id="3_ship"]
[ext_resource type="PackedScene" path="res://scenes/anchor.tscn" id="4_anchor"]

[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_bar_bg"]
bg_color = Color(0.12, 0.12, 0.15, 1)

[node name="Main" type="Node2D"]
script = ExtResource("1_main")

[node name="Background" type="ColorRect" parent="."]
offset_right = 1152.0
offset_bottom = 180.0
color = Color(0.55, 0.75, 0.95, 1)

[node name="Water" type="ColorRect" parent="."]
offset_top = 180.0
offset_right = 1152.0
offset_bottom = 600.0
color = Color(0.15, 0.35, 0.6, 1)

[node name="Seabed" type="ColorRect" parent="."]
offset_top = 600.0
offset_right = 1152.0
offset_bottom = 648.0
color = Color(0.3, 0.25, 0.18, 1)

[node name="Spawner" type="Node2D" parent="."]
script = ExtResource("2_spawner")

[node name="Ship" parent="." instance=ExtResource("3_ship")]

[node name="Anchor" parent="." instance=ExtResource("4_anchor")]

[node name="HUD" type="CanvasLayer" parent="."]

[node name="DurabilityBar" type="ProgressBar" parent="HUD"]
offset_left = 20.0
offset_top = 20.0
offset_right = 320.0
offset_bottom = 48.0
max_value = 100.0
value = 100.0

[node name="ScoreLabel" type="Label" parent="HUD"]
offset_left = 20.0
offset_top = 56.0
offset_right = 320.0
offset_bottom = 80.0
text = "Score: 0"

[node name="MessageLabel" type="Label" parent="HUD"]
offset_left = 360.0
offset_top = 20.0
offset_right = 1120.0
offset_bottom = 60.0
text = "准备好抛锚!"

[node name="StartButton" type="Button" parent="HUD"]
offset_left = 460.0
offset_top = 300.0
offset_right = 692.0
offset_bottom = 360.0
text = "开始游戏 (Space)"
```

- [ ] **Step 3: Confirm main_scene in project.godot**

Ensure `project.godot` `[application] run/main_scene="res://scenes/main.tscn"`.

- [ ] **Step 4: Run the project end-to-end**

Run MCP `run_project` with the projectPath. Let it run a few seconds, then `stop_project`, then `get_debug_output`. Expected: window opens, sky/water/seabed visible, ship at left, "准备好抛锚!" message and a StartButton visible.

- [ ] **Step 5: Manual playtest checklist (you, the user)**

Launch via MCP `launch_editor` and press Play (or `run_project`), then verify by playing:
1. Click the StartButton (or press Space) → button hides, "准备好抛锚!" clears, hazards start spawning from the right at random depths moving left.
2. Click in the water to the right/below the ship → anchor flies toward the click, chain visible, head descends.
3. Anchor reaches seabed OR chain maxes out → retracts to the ship.
4. While anchor is flying (Launched), click again → anchor retracts early (mid-flight retract).
5. Click above the anchor hole (sky) → anchor fires horizontally (clamped), skims the waterline — can hit a surfaced B-type.
6. Anchor hitting a hazard (A or B) → hazard disappears, score increases by 10, anchor keeps flying (piercing).
7. A B-type (teal triangle) reaching the ship → durability drops by 5, hazard disappears.
8. A-type (amber square) passing through the ship → no damage, no removal.
9. Durability to 0 → "Game Over — 按空格重开" appears, StartButton returns, spawning stops, remaining hazards cleared.
10. Press Space (or click button) → resets durability/score to full/0, returns to PLAYING.

Report any failure with which checklist item and the `get_debug_output` errors.

**Verification:** If all 10 pass, the game meets the spec. If not, capture `get_debug_output` and the failing item — enter systematic-debugging to fix before claiming done.

---

## Task 10: Balance pass + cleanup

**Files:**
- Modify: `autoload/game.gd` (only constants, based on playtest feedback)
- Remove: any throwaway `_ready` no-ops left in `ship.gd`

**Interfaces:** none new.

- [ ] **Step 1: Remove throwaway `_ready` from `ship.gd`**

If `ship.gd` still has a no-op `func _ready() -> void: pass`, delete it. (Avoids dead code.)

- [ ] **Step 2: Balance review**

Based on playtest (Task 9 step 5), tune in `game.gd` if needed:
- If hazards are too sparse/dense: adjust `spawn_interval` (in `spawner.gd` default `1.4`, or export-override on the Spawner node).
- If B-types never reach the ship (no threat) or always hit (unfair): adjust `FLOATER_VY_MIN/MAX` and/or `HAZARD_VX_MIN/MAX`.
- If anchor feels sluggish/fast: `ANCHOR_FIRE_SPEED` / `ANCHOR_RETRACT_SPEED`.
- If chain too short/long for the seabed depth (WATERLINE 180 → SEABED 600 = 420px water depth; `MAX_CHAIN_LEN=460` barely reaches seabed on a straight-down shot): confirm 460 reaches seabed; if horizontal shots can't reach a hazard in time, raise `MAX_CHAIN_LEN` (note: a horizontal shot at 460px reaches x≈610 from the ship at x=150, i.e. x=760 — hazards spawn at x=1170, so the player must wait for them to drift into range; this is intended difficulty).

- [ ] **Step 3: Final end-to-end run**

`run_project`, playtest the 10 items from Task 9 once more after tuning. Confirm no regressions.

**Verification:** Game plays cleanly per spec; no debug errors; constants centralized.

---

## Self-Review Notes

**Spec coverage:** §3 layout → Tasks 1,3,6,7,9. §4 coords/constants → Task 1. §5 flow + StartButton shortcut → Tasks 1,9. §6 anchor state machine (Idle/Launched/Retracting, direction clamp, never-up, refire-prevention via states) → Tasks 2-6. §7 hazards/spawner/collision/waterline-clamp/scoring → Tasks 7-8, collisions in 7. §8 YAGNI respected (no audio/particles/persistence/pause/healthbars). §9 testing → inline verification steps + Task 9 playtest checklist.

**Type consistency check:** `Anchor.can_fire/fire(direction: Vector2)/request_retract` (Task 3) ← consumed by `Ship` (Task 6) ✓. `Anchor._get_hole_global()/_snap_head_to_hole()/_update_chain()` defined Task 3/4 ✓. `Ship.anchor_hole_global()` defined Task 6, consumed by `Anchor._get_hole_global()` (Task 3) ✓. `Hazard.setup(kind: Kind, pos: Vector2)` (Task 7) ← consumed by `Spawner` (Task 8) ✓. `Spawner.clear_all()` (Task 8) ← consumed by `Main` (Task 9) ✓. `Game` signals `durability_changed/score_changed/game_over/flow_changed` (Task 1) ← consumed by `Main` (Task 9) ✓. StateMachine `init(state_name, anchor)` (Task 2) ← called by `Anchor._ready` (Task 3) ✓ — note `init` takes a String name + anchor, matches usage. `IdleState/LaunchedState/RetractingState` `class_name` (Tasks 3,4,5) ← referenced by `anchor.gd.can_fire/request_retract` via `is IdleState`/`is LaunchedState` ✓.

**Known plan-internal risks flagged for the implementer:**
- `anchor.tscn` `load_steps` counts: re-verified per task (Task 3→4, Task 4→5, Task 5→6). If Godot complains, the editor corrects `load_steps` automatically on save — safe.
- `RectangleShape2D` uses `size` (Godot 4), not `extents` (Godot 3) — used correctly.
- The `InputEventKey.physical_keycode = KEY_SPACE` shortcut works regardless of layout; `Button.shortcut` is global while the button is visible+enabled, matching §5's conflict-avoidance design.
- `_unhandled_input` on the Ship fires only when the click isn't consumed by a Control (`StartButton`) — during PLAYING the button is hidden+disabled, so clicks reach the ship. ✓
