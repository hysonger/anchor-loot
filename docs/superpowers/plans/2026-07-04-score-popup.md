# 得分浮动提示（Score Popup）Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When the player scores, show a "+N" floating label near the ship that stacks upward with existing popups and fades out at max height.

**Architecture:** Add a `score_popup` signal to `Game`, emit it from `Item._on_area_entered` on anchor hit, and handle it in `Main` by creating Labels managed in a stack — new popups push existing ones up via Tween, fading out when they exceed the height cap.

**Tech Stack:** Godot 4.6 GDScript, no external assets.

## Global Constraints

- Godot 4.6 GL Compatibility renderer
- No external art/audio assets — pure geometric prototypes
- UI strings in Chinese (score "+N" format uses no Chinese text but the design is neutral)
- Verify via `mcp__godot__run_project` + `mcp__godot__get_debug_output` — no automated test suite

---

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `autoload/game.gd` | Modify | Add `score_popup` signal |
| `scripts/item.gd` | Modify | Emit `score_popup` on anchor hit |
| `scripts/main.gd` | Modify | Popup manager: create/tween/cleanup Labels |

No new files. All popup logic lives in Main as the root scene controller.

---

### Task 1: Add `score_popup` signal to Game

**Files:**
- Modify: `autoload/game.gd`

- [ ] **Step 1: Add the new signal declaration**

Add the following line after the existing four signal declarations (after `signal flow_changed(state: FlowState)`, line 10):

```gdscript
signal score_popup(points: int, at_position: Vector2)
```

The full signal block becomes:

```gdscript
signal durability_changed(current: int, maxv: int)
signal score_changed(score: int)
signal game_over()
signal flow_changed(state: FlowState)
signal score_popup(points: int, at_position: Vector2)
```

No other changes to `game.gd`. `add_score` already exists and emits `score_changed` — the new signal is emitted downstream by the item that triggered the score, not by `add_score` itself (allowing the item to pass its world position if needed to `at_position`).

- [ ] **Step 2: Commit**

```bash
git add autoload/game.gd
git commit -m "feat(game): add score_popup signal for floating score text"
```

---

### Task 2: Emit `score_popup` from Item on anchor hit

**Files:**
- Modify: `scripts/item.gd:46` (inside `_on_area_entered`, anchor_head branch)

**Interfaces:**
- Consumes: `Game.score_popup(points: int, at_position: Vector2)` signal added in Task 1
- Produces: Signal emission consumed by Task 3

- [ ] **Step 1: Add the signal emission in `_on_area_entered`**

In `scripts/item.gd`, inside the `_on_area_entered` method, in the `anchor_head` branch (line 46-48), add `Game.score_popup.emit` after `Game.add_score`:

```gdscript
func _on_area_entered(area: Area2D) -> void:
	if _spawn_protection > 0.0:
		return
	if area.is_in_group("anchor_head"):
		Game.add_score(_get_score())
		Game.score_popup.emit(_get_score(), Vector2(Game.SHIP_X, Game.WATERLINE_Y))
		_on_killed()
		queue_free()
	elif area.is_in_group("ship"):
		Game.take_damage(_get_damage())
		queue_free()
```

- [ ] **Step 2: Verify parse — run the project and check for errors**

```bash
# Use godot MCP: mcp__godot__run_project
# Then mcp__godot__get_debug_output — confirm errors: []
```

- [ ] **Step 3: Commit**

```bash
git add scripts/item.gd
git commit -m "feat(item): emit score_popup signal on anchor hit"
```

---

### Task 3: Implement popup manager in Main

**Files:**
- Modify: `scripts/main.gd`

**Interfaces:**
- Consumes: `Game.score_popup(points: int, at_position: Vector2)` from Task 1, emitted by Task 2
- Produces: Visual score popups; no public API for other consumers

**Constants to add at the top of the script (after `extends Node2D`):**

```gdscript
const POPUP_SLOT_HEIGHT := 28.0
const POPUP_MAX_Y := Game.WATERLINE_Y - 140.0
const POPUP_X_JITTER := 20.0
const POPUP_TWEEN_DURATION := 0.3
const POPUP_FONT_SIZE := 18
```

- [ ] **Step 1: Declare the popup tracking array and constants**

After the `@onready` block (lines 5-12), add popup tracking:

```gdscript
# Popup manager: active floating score labels, newest last (bottom of stack).
var _popup_labels: Array[Label] = []
```

The full `@onready` + popup section:

```gdscript
@onready var spawner: Spawner = $Spawner
@onready var ship: Ship = $Ship
@onready var anchor: Anchor = $Anchor
@onready var durability_bar: ProgressBar = $HUD/DurabilityBar
@onready var score_label: Label = $HUD/ScoreLabel
@onready var message_label: Label = $HUD/MessageLabel
@onready var start_button: Button = $HUD/StartButton
@onready var tip_clean_timer = $TipCleanTimer

# Popup manager
var _popup_labels: Array[Label] = []
```

- [ ] **Step 2: Connect the `score_popup` signal in `_ready`**

In `_ready()`, after the existing signal connections, add:

```gdscript
Game.score_popup.connect(_on_score_popup)
```

The `_ready` body after all connections:

```gdscript
func _ready() -> void:
	# Wire ship <-> anchor.
	ship.anchor = anchor
	anchor.ship = ship

	# Bind HUD to Game state.
	Game.durability_changed.connect(_on_durability_changed)
	Game.score_changed.connect(_on_score_changed)
	Game.flow_changed.connect(_on_flow_changed)
	Game.game_over.connect(_on_game_over)
	Game.score_popup.connect(_on_score_popup)

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
```

- [ ] **Step 3: Implement the `_on_score_popup` handler**

Add the following methods after `_on_timer_timeout`:

```gdscript
func _on_score_popup(points: int, at_position: Vector2) -> void:
	# Create a floating "+N" label at the ship position, then slide all
	# existing popups up one slot. Labels exceeding POPUP_MAX_Y fade out.
	var label := Label.new()
	label.text = "+%d" % points
	label.add_theme_font_size_override("font_size", POPUP_FONT_SIZE)
	label.add_theme_color_override("font_color", Color.GOLD)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Offset x slightly to reduce overlap with concurrent popups.
	label.position = at_position + Vector2(randf_range(-POPUP_X_JITTER, POPUP_X_JITTER), 0.0)
	add_child(label)
	_popup_labels.append(label)

	# Slide all popups (including the new one) up to their new positions.
	_slide_popups()

	# Clean up labels that have scrolled past the max height.
	_prune_popups()
```

- [ ] **Step 4: Implement `_slide_popups`**

```gdscript
func _slide_popups() -> void:
	# Each popup occupies its own slot: newest at bottom (slot 0), oldest at top.
	# Position = at_position.y - slot_index * POPUP_SLOT_HEIGHT.
	for i in range(_popup_labels.size()):
		var lbl: Label = _popup_labels[i]
		var slot_index := _popup_labels.size() - 1 - i   # 0 = newest (bottom)
		var target_y := Game.WATERLINE_Y - slot_index * POPUP_SLOT_HEIGHT
		var tween := create_tween()
		tween.tween_property(lbl, "position:y", target_y, POPUP_TWEEN_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
```

- [ ] **Step 5: Implement `_prune_popups`**

```gdscript
func _prune_popups() -> void:
	# Fade out and remove labels above POPUP_MAX_Y, then clean the array.
	for i in range(_popup_labels.size() - 1, -1, -1):
		var lbl: Label = _popup_labels[i]
		if lbl.position.y <= POPUP_MAX_Y:
			# This label is above the max height — fade and destroy.
			var tween := create_tween()
			tween.tween_property(lbl, "modulate:a", 0.0, POPUP_TWEEN_DURATION).set_trans(Tween.TRANS_QUAD)
			tween.tween_callback(lbl.queue_free)
			_popup_labels.remove_at(i)
```

- [ ] **Step 6: Verify parse — run the project and check for errors**

Use the MCP godot server:
```
mcp__godot__run_project
mcp__godot__get_debug_output → confirm errors: []
```

- [ ] **Step 7: Manual playtest verification**

Items to verify (play the game and check):
1. Hit a JunkItem → "+10" appears near ship, gold color
2. Hit a NormalFishItem → "+20" stacks above "+10" (if still visible)
3. Hit a TreasureItem → "+100" or "+500" appears in stack
4. Labels fade out and disappear when they reach ~y=40 (above the waterline region)
5. Fast consecutive hits produce non-overlapping labels via x jitter
6. No errors in debug output throughout

- [ ] **Step 8: Commit**

```bash
git add scripts/main.gd
git commit -m "feat(ui): add floating score popup with stack-and-fade behavior"
```
