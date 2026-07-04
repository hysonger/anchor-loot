# Item Base Class Refactor — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor `hazard.gd` (enum Kind branching) into an `Item` base class with `DriftItem`/`FloaterItem` subclasses, moving damage values into subclass scripts and making waterline clamping a base-class invariant.

**Architecture:** Script inheritance (`Item` → `DriftItem`/`FloaterItem`) with one self-contained scene per subclass (no Godot scene inheritance). Visual (shape/color) lives in .tscn; behavior in .gd. Base `Item` owns movement + culling + waterline clamp + collision dispatch; subclasses override `_init_velocity()` and `_get_damage()` only.

**Tech Stack:** Godot 4.6 GDScript (GL Compatibility), MCP server for running/verification. No automated tests — verification via `mcp__godot__run_project` + `mcp__godot__get_debug_output`.

## Global Constraints

- No new item type beyond DRIFT/FLOATER (YAGNI).
- No `_get_score()` — score stays uniform `SCORE_PER_KILL` in base.
- No Godot scene inheritance (subclass scenes are self-contained).
- No changes to Ship, Anchor, state machines, or flow state machine.
- Viewport/waterline/seabed/spawn coordinates unchanged.
- Speed ranges unchanged (only rename `HAZARD_VX_*` → `ITEM_VX_*`, values identical).
- Damage 0 in base (safe default); each subclass const `DAMAGE := 25` returns via `_get_damage()`.
- All `.gd.uid` files must be tracked in git (CLAUDE.md requirement).
- Verification: `run_project` + `get_debug_output` must return `errors: []`. Debug `print()` uses comma form, not `%` format.
- `:=` inference needs explicit types for class refs (e.g., `var item: Item = scene.instantiate()`, not `var item := scene.instantiate()`).

---

### Task 1: Create Item base class + subclass scripts + new game.gd constants

**Files:**
- Create: `scripts/item.gd`
- Create: `scripts/items/drift_item.gd`
- Create: `scripts/items/floater_item.gd`
- Create: `scripts/items/` (directory)
- Modify: `autoload/game.gd:31-33`

**Interfaces:**
- Consumes: `Game.WATERLINE_Y`, `Game.SCORE_PER_KILL`, `Game.ITEM_VX_MIN`, `Game.ITEM_VX_MAX`, `Game.FLOATER_VY_MIN`, `Game.FLOATER_VY_MAX` (ITEM_VX_* added in this task)
- Produces: `class_name Item`, `class_name DriftItem`, `class_name FloaterItem` — all available for scene creation (Task 2) and spawner (Task 3)

**What this task achieves:** The class hierarchy exists on disk and parses clean. Old hazard still works because `HAZARD_VX_*` and `DAMAGE_PER_HIT` are untouched in game.gd. New subclass scripts use the freshly-added `ITEM_VX_*` constants. Clean boot `errors: []` confirms no parse issues (class_name conflict, syntax, etc.).

- [ ] **Step 1: Create `scripts/items/` directory**

```
mkdir -p scripts/items
```

- [ ] **Step 2: Write `scripts/item.gd`**

```gdscript
class_name Item
extends Area2D
# 水中物品基类。共性：位移 + 水线钳制 + 越界销毁 + 碰撞派发 + setup。
# 子类覆写虚方法：_init_velocity() / _get_damage()（必要时也可覆写 _post_move）。
# 伤害默认 0（安全兜底，裸 Item 不应被实例化）；子类用 DAMAGE 常量覆写 _get_damage()。

var velocity: Vector2 = Vector2.ZERO

func _ready() -> void:
	area_entered.connect(_on_area_entered)

func setup(pos: Vector2) -> void:
	global_position = pos
	velocity = _init_velocity()

func _physics_process(delta: float) -> void:
	global_position += velocity * delta
	_post_move(delta)
	if global_position.x < -60.0:
		queue_free()

# ---- 虚钩子 ----
func _init_velocity() -> Vector2:        return Vector2.ZERO   # 默认不动

func _post_move(_delta: float) -> void:
	# 通用物理不变量：任何上浮物品抵水面即止，随后沿水面漂流。
	# vy<0 才触发；DriftItem(vy=0) 天然跳过。
	if velocity.y < 0.0 and global_position.y <= Game.WATERLINE_Y:
		global_position.y = Game.WATERLINE_Y
		velocity.y = 0.0

func _get_damage() -> int:               return 0              # 默认无伤害（子类覆写）

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("anchor_head"):
		Game.add_score(Game.SCORE_PER_KILL)
		queue_free()
	elif area.is_in_group("ship"):
		Game.take_damage(_get_damage())
		queue_free()
```

- [ ] **Step 3: Write `scripts/items/drift_item.gd`**

```gdscript
class_name DriftItem
extends Item
# 纯左移。vy=0，基类水线钳制天然不触发；接触船即扣血（基类行为）。

const DAMAGE := 25

func _init_velocity() -> Vector2:
	return Vector2(randf_range(Game.ITEM_VX_MIN, Game.ITEM_VX_MAX), 0.0)

func _get_damage() -> int:
	return DAMAGE
```

- [ ] **Step 4: Write `scripts/items/floater_item.gd`**

```gdscript
class_name FloaterItem
extends Item
# 左移 + 上浮；抵水面即止（基类通用规则），随后水面漂流，可撞船扣血。

const DAMAGE := 25

func _init_velocity() -> Vector2:
	return Vector2(randf_range(Game.ITEM_VX_MIN, Game.ITEM_VX_MAX),
					randf_range(Game.FLOATER_VY_MIN, Game.FLOATER_VY_MAX))

func _get_damage() -> int:
	return DAMAGE
```

- [ ] **Step 5: Add `ITEM_VX_*` constants to `autoload/game.gd`**

Insert after line 33 (after `const FLOATER_VY_MAX`), before the `const MAX_CHAIN_LEN` line. Keep `HAZARD_VX_*` and `DAMAGE_PER_HIT` untouched — old hazard still needs them.

```gdscript
const ITEM_VX_MIN    := -180.0
const ITEM_VX_MAX    := -90.0
```

Edit operation — insert after `const FLOATER_VY_MAX := -25.0`:

```gdscript
const FLOATER_VY_MAX := -25.0

const ITEM_VX_MIN    := -180.0
const ITEM_VX_MAX    := -90.0

const MAX_CHAIN_LEN := 460.0
```

- [ ] **Step 6: Run project, verify clean boot, stop**

Run: `mcp__godot__run_project` (projectPath `/Users/songer/ownCloud/Projects/anchor-game`)

Wait 3 seconds for Godot boot, then:

Run: `mcp__godot__get_debug_output`

Expected: `{"output": "...", "errors": []}` — no parse errors on item.gd, drift_item.gd, floater_item.gd, or game.gd. Old hazard still loads fine (references `HAZARD_VX_*` which still exists).

Run: `mcp__godot__stop_project`

If `errors` is non-empty, review the error line numbers against the files written in steps 2-5, fix, and re-verify.

- [ ] **Step 7: Track .uid files and commit**

Godot generated `.gd.uid` files for the three new scripts during the run in step 6.

```bash
git add scripts/item.gd scripts/item.gd.uid \
        scripts/items/drift_item.gd scripts/items/drift_item.gd.uid \
        scripts/items/floater_item.gd scripts/items/floater_item.gd.uid \
        autoload/game.gd
git commit -m "feat(item): add Item base class and DriftItem/FloaterItem scripts"
```

> `.gd.uid` files are generated by Godot on project scan (step 6). If a .uid file is missing, it means Godot didn't see the script — check the file path and re-run.

---

### Task 2: Create DriftItem + FloaterItem scenes

**Files:**
- Create: `scenes/drift_item.tscn`
- Create: `scenes/floater_item.tscn`

**Interfaces:**
- Consumes: `class_name DriftItem` (Task 1), `class_name FloaterItem` (Task 1) — referenced by scene `ext_resource script` path
- Produces: `res://scenes/drift_item.tscn`, `res://scenes/floater_item.tscn` — preloaded by spawner (Task 3)

**What this task achieves:** Two self-contained scenes on disk, each with a correctly-configured Body polygon/color and CollisionShape. Loadable by Godot (clean boot). Old spawner still uses `hazard.tscn` — no gameplay change yet.

- [ ] **Step 1: Write `scenes/drift_item.tscn`**

```gd-scene
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/items/drift_item.gd" id="1_drift_item"]

[sub_resource type="RectangleShape2D" id="RectangleShape2D_1"]
size = Vector2(24, 24)

[node name="DriftItem" type="Area2D"]
script = ExtResource("1_drift_item")

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("RectangleShape2D_1")

[node name="Body" type="Polygon2D" parent="."]
polygon = PackedVector2Array(-12, -12, 12, -12, 12, 12, -12, 12)
color = Color(0.85, 0.6, 0.2, 1)
```

Amber square `Color(0.85, 0.6, 0.2, 1)` — matches current DRIFT visual.

- [ ] **Step 2: Write `scenes/floater_item.tscn`**

```gd-scene
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/items/floater_item.gd" id="1_floater_item"]

[sub_resource type="RectangleShape2D" id="RectangleShape2D_1"]
size = Vector2(24, 24)

[node name="FloaterItem" type="Area2D"]
script = ExtResource("1_floater_item")

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("RectangleShape2D_1")

[node name="Body" type="Polygon2D" parent="."]
polygon = PackedVector2Array(0, -14, 12, 12, -12, 12)
color = Color(0.2, 0.7, 0.5, 1)
```

Teal triangle `Color(0.2, 0.7, 0.5, 1)` — matches current FLOATER visual.

- [ ] **Step 3: Run project, verify clean boot**

Run: `mcp__godot__run_project` (projectPath `/Users/songer/ownCloud/Projects/anchor-game`)
Wait 3s.
Run: `mcp__godot__get_debug_output`

Expected: `"errors": []` — new scenes load cleanly (scripts resolve, `ExtResource` and `SubResource` references valid). Old spawner still preloads `hazard.tscn` and spawns hazards normally.

Run: `mcp__godot__stop_project`

- [ ] **Step 4: Commit**

```bash
git add scenes/drift_item.tscn scenes/floater_item.tscn
git commit -m "feat(item): add DriftItem and FloaterItem scenes"
```

Godot may add `uid="..."` to the scene headers on first scan. If the files changed after step 3 (uid injected), re-add them before committing.

---

### Task 3: Update spawner to use new Item system

**Files:**
- Modify: `scripts/spawner.gd` (entire file)

**Interfaces:**
- Consumes: `DriftItem`/`FloaterItem` scenes (Task 2), `Item` class (Task 1), `Game.ITEM_VX_*` (Task 1)
- Produces: spawner now instantiates `DriftItem`/`FloaterItem` instead of `Hazard` with `Kind`; `clear_all()` matches on `is Item`

**What this task achieves:** The spawner is fully switched to the new item system. New items spawn (50% DriftItem, 50% FloaterItem), old hazard is no longer spawned. Old `hazard.gd` still exists but is unreferenced. Clean boot + basic item behavior verified (DRIFT left-drift, FLOATER rise-then-drift).

- [ ] **Step 1: Rewrite `scripts/spawner.gd`**

Replace the entire file content:

```gdscript
class_name Spawner
extends Node2D
# Periodically spawns items on the right edge at a random depth while playing.

@export var spawn_interval := 1.4
const DRIFT_ITEM_SCENE   := preload("res://scenes/drift_item.tscn")
const FLOATER_ITEM_SCENE := preload("res://scenes/floater_item.tscn")

var _timer := 0.0

func _physics_process(delta: float) -> void:
	if not Game.is_playing():
		return
	_timer += delta
	if _timer >= spawn_interval:
		_timer = 0.0
		_spawn_one()

func _spawn_one() -> void:
	var scene: PackedScene = DRIFT_ITEM_SCENE if randf() < 0.5 else FLOATER_ITEM_SCENE
	var item: Item = scene.instantiate()   # 显式 : Item，避免 := 推断为 Node
	add_child(item)
	var y := randf_range(Game.SPAWN_Y_MIN, Game.SPAWN_Y_MAX)
	item.setup(Vector2(Game.SPAWN_X, y))   # setup 不再收 kind

func clear_all() -> void:
	for c in get_children():
		if c is Item:                      # 基类判断，两子类都匹配
			c.queue_free()
```

No `Hazard`, no `Kind` enum, no `HAZARD_SCENE`. `clear_all` uses `is Item` — matches both `DriftItem` and `FloaterItem`.

- [ ] **Step 2: Run project, verify basic item behavior**

Run: `mcp__godot__run_project` (projectPath `/Users/songer/ownCloud/Projects/anchor-game`)
Wait 3s.
Run: `mcp__godot__get_debug_output`

Expected: `"errors": []` — new spawner preloads resolve, instantiation works.

**Manual observation (playtest items 1-4 from spec):**
1. Start game (Space key).
2. Observe: amber squares (DriftItem) spawn at random depths, drift left, never rise above waterline, disappear off left edge.
3. Observe: teal triangles (FloaterItem) spawn, rise to waterline (y≈180), then drift left along surface.
4. Observe: no items cross above waterline (waterline clamp is generic in base).

Run: `mcp__godot__stop_project`

> The user plays the game briefly to confirm items appear and move correctly. If items don't appear, check spawner.gd for `:=` inference issues (the `var item: Item` explicit type is critical — see CLAUDE.md Godot 4 pitfall).

- [ ] **Step 3: Quick collision smoke-test**

Run: `mcp__godot__run_project` (projectPath `/Users/songer/ownCloud/Projects/anchor-game`)

Manual check:
1. Start game. Click to fire anchor at items — score increments on hit (anchor destroys item, keeps flying).
2. Let FLOATER items reach the surface — they collide with ship area, durability decreases by 25, item self-destructs.
3. DRIFT items: they stay deep, never reach ship. Simple visual confirmation they exist and move correctly.

Run: `mcp__godot__stop_project`

- [ ] **Step 4: Commit**

```bash
git add scripts/spawner.gd
git commit -m "refactor(spawner): switch to Item-based spawning"
```

---

### Task 4: Remove old hazard code, clean game.gd, final verification

**Files:**
- Delete: `scripts/hazard.gd`, `scripts/hazard.gd.uid`, `scenes/hazard.tscn`
- Modify: `autoload/game.gd` — remove `DAMAGE_PER_HIT`, `HAZARD_VX_MIN`, `HAZARD_VX_MAX` (dead after hazard.gd delete)

**Interfaces:**
- Consumes: spawner already switched (Task 3) — no code references `Hazard`, `Kind`, `DAMAGE_PER_HIT`, or `HAZARD_VX_*` anymore
- Produces: clean project — no dead code or dead constants

**What this task achieves:** Old hazard system fully removed. game.gd has no damage constants (damage lives in subclass `DAMAGE` consts). Full playtest confirms all 10 spec test items pass. All .uid files tracked.

- [ ] **Step 1: Delete old hazard files**

```bash
rm scripts/hazard.gd scripts/hazard.gd.uid scenes/hazard.tscn
```

- [ ] **Step 2: Remove dead constants from `autoload/game.gd`**

Remove these three lines:

```gdscript
const DAMAGE_PER_HIT := 25

const HAZARD_VX_MIN := -180.0
const HAZARD_VX_MAX := -90.0
```

`DAMAGE_PER_HIT` was only used by `hazard.gd` (now deleted). `HAZARD_VX_*` replaced by `ITEM_VX_*` (added in Task 1). The `ITEM_VX_*` constants, `FLOATER_VY_*`, and all other constants remain.

- [ ] **Step 3: Run project, verify clean boot**

Run: `mcp__godot__run_project` (projectPath `/Users/songer/ownCloud/Projects/anchor-game`)
Wait 3s.
Run: `mcp__godot__get_debug_output`

Expected: `"errors": []` — no references to deleted Hazard class or removed constants. If errors appear, check for stale references (e.g., other scene files still referencing `hazard.tscn` or `hazard.gd`).

- [ ] **Step 4: Full playtest (all 10 spec test items)**

Play through each item with the game running:

1. **Clean boot** — already confirmed in step 3 (errors: []).
2. **DRIFT** — amber squares spawn deep, drift left only (no vertical), disappear at x<-60.
3. **FLOATER** — teal triangles spawn, rise to y≈180, then drift left along surface.
4. **Waterline clamp** — no item ever appears above y=180 (both types: DRIFT vy=0 skips, FLOATER clamped).
5. **Anchor destroys items** — click to fire anchor; anchor passes through DRIFT/FLOATER, each kill adds +10 score, anchor keeps flying (multi-kill possible).
6. **Ship collision** — let a FLOATER reach the ship at the surface; durability drops by 25, item self-destructs. One hit per item. DRIFT cannot reach the ship at current depth.
7. **Damage values** — confirm each FLOATER hit takes 25 durability (4 hits = Game Over). `DriftItem.DAMAGE` = 25 verified by code review (cannot reach ship to test).
8. **Flow states** — READY: no items spawn. Press Space → PLAYING: items spawn. Let durability hit 0 → GAME_OVER: items clear, "GAME OVER" shown. Press Space → restart: durability reset, new items spawn.
9. **Groups unchanged** — ship `"ship"` group, anchor head `"anchor_head"` group confirmed. Items have no groups (detection side).
10. **No regression** — all original behaviors intact: anchor firing/retracting mechanics, chain length limit, seabed trigger, mouse-aim clamp (no upward fire), start button/space shortcut.

Run: `mcp__godot__stop_project`

- [ ] **Step 5: Track all .uid files and commit**

```bash
# Verify all .uid files are present and tracked
ls scripts/item.gd.uid scripts/items/drift_item.gd.uid scripts/items/floater_item.gd.uid

# Commit: deletions + game.gd cleanup
git add scripts/hazard.gd scripts/hazard.gd.uid scenes/hazard.tscn autoload/game.gd
git commit -m "chore(item): remove deprecated hazard.gd, dead game.gd constants

Delete: hazard.gd, hazard.gd.uid, hazard.tscn (replaced by Item base + subclass system).
Remove from game.gd: DAMAGE_PER_HIT, HAZARD_VX_* (damage now in subclass DAMAGE consts;
horizontal speed renamed to ITEM_VX_*)."
```

> `.uid` files in the deletion are `git rm`-d via the `git add` of deleted paths. Run `git status` after commit — should be clean on the refactor branch.
