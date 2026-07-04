# Item Type Refinement — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the two existing item types (DriftItem, FloaterItem) with 5 new types (JunkItem, NormalFishItem, AggressiveFishItem, ChestItem, TreasureItem), each with independent behavior, visuals, and scoring.

**Architecture:** Class inheritance — `Item` base → 5 subclasses. `AggressiveFishItem` extends `NormalFishItem`. Base `_on_area_entered` delegates to `_get_score()` and `_on_killed()` virtual methods. Spawner uses a weighted table for 4 types (TreasureItem only spawns from ChestItem kills). Visuals via Polygon2D in self-contained `.tscn` files.

**Tech Stack:** Godot 4.6 GDScript (GL Compatibility), MCP server for running/verification. No automated tests — verification via `mcp__godot__run_project` + `mcp__godot__get_debug_output`.

## Global Constraints

- All `.gd.uid` files must be tracked in git (CLAUDE.md requirement).
- `:=` inference needs explicit types for class refs (e.g., `var item: Item = scene.instantiate()`).
- Verification: `run_project` + `get_debug_output` must return `errors: []`.
- Debug `print()` uses comma form, not `%` format.
- No changes to Ship, Anchor, state machines, flow state machine, viewport/waterline/seabed/spawn coordinates.
- Items still one-hit-destroy.
- No Godot scene inheritance (subclass scenes are self-contained).

---

### Task 1: Add new constants to game.gd

**Files:**
- Modify: `autoload/game.gd`

**Interfaces:**
- Produces: `Game.JUNK_VX_MIN`, `Game.JUNK_VX_MAX`, `Game.JUNK_VY_MIN`, `Game.JUNK_VY_MAX`, `Game.CHEST_VX_MIN`, `Game.CHEST_VX_MAX`, `Game.FISH_VX_MIN`, `Game.FISH_VX_MAX`, `Game.FISH_SWING_AMP`, `Game.FISH_SWING_FREQ`, `Game.AGGRO_DETECT_DIST`, `Game.AGGRO_WINDUP_TIME`, `Game.AGGRO_CHARGE_SPEED`, `Game.TREASURE_FALL_SPEED_SMALL`, `Game.TREASURE_FALL_SPEED_LARGE`

**What this task achieves:** New constants coexist with old ones. Old items still work (they reference `ITEM_VX_*`, `FLOATER_VY_*`, `SCORE_PER_KILL` — all untouched). Clean boot confirms no syntax errors.

- [ ] **Step 1: Add new constants after existing `ITEM_VX_MAX` line**

Edit `autoload/game.gd` — insert after line 34 (`const ITEM_VX_MAX := -90.0`), before line 35 (blank line), then insert the fish/aggro/treasure blocks before `const MAX_CHAIN_LEN`:

The edit adds the new constants between the existing `ITEM_VX_*` block and `MAX_CHAIN_LEN`:

```gdscript
# ---- 垃圾（JunkItem）----
const JUNK_VX_MIN := -180.0
const JUNK_VX_MAX := -90.0
const JUNK_VY_MIN := -70.0
const JUNK_VY_MAX := -25.0

# ---- 箱子（ChestItem）----
const CHEST_VX_MIN := -150.0
const CHEST_VX_MAX := -80.0

# ---- 鱼（NormalFish / AggressiveFish 巡逻态）----
const FISH_VX_MIN    := -150.0
const FISH_VX_MAX    := -80.0
const FISH_SWING_AMP  := 35.0
const FISH_SWING_FREQ := 2.5

# ---- 攻击性鱼（AggressiveFish）----
const AGGRO_DETECT_DIST   := 576.0
const AGGRO_WINDUP_TIME   := 0.5
const AGGRO_CHARGE_SPEED  := 380.0

# ---- 宝藏（TreasureItem）----
const TREASURE_FALL_SPEED_SMALL := 60.0
const TREASURE_FALL_SPEED_LARGE := 100.0
```

Use these two Edit operations on `autoload/game.gd`:

**Edit 1**: Replace `const ITEM_VX_MAX    := -90.0\n\nconst MAX_CHAIN_LEN` with `const ITEM_VX_MAX    := -90.0\n\nconst JUNK_VX_MIN := -180.0\nconst JUNK_VX_MAX := -90.0\nconst JUNK_VY_MIN := -70.0\nconst JUNK_VY_MAX := -25.0\n\nconst CHEST_VX_MIN := -150.0\nconst CHEST_VX_MAX := -80.0\n\nconst FISH_VX_MIN    := -150.0\nconst FISH_VX_MAX    := -80.0\nconst FISH_SWING_AMP  := 35.0\nconst FISH_SWING_FREQ := 2.5\n\nconst AGGRO_DETECT_DIST   := 576.0\nconst AGGRO_WINDUP_TIME   := 0.5\nconst AGGRO_CHARGE_SPEED  := 380.0\n\nconst TREASURE_FALL_SPEED_SMALL := 60.0\nconst TREASURE_FALL_SPEED_LARGE := 100.0\n\nconst MAX_CHAIN_LEN`

(Old `FLOATER_VY_*` and `SCORE_PER_KILL` remain untouched — old items still depend on them.)

- [ ] **Step 2: Run project, verify clean boot**

Run: `mcp__godot__run_project` (projectPath `/Users/songer/ownCloud/Projects/anchor-game`)
Wait 3s.
Run: `mcp__godot__get_debug_output`
Expected: `"errors": []` — new constants parse, old items still work.
Run: `mcp__godot__stop_project`

- [ ] **Step 3: Commit**

```bash
git add autoload/game.gd
git commit -m "feat(game): add constants for 5 new item types"
```

---

### Task 2: Create 5 subclass scripts and 6 scene files

**Files:**
- Create: `scripts/items/junk_item.gd`
- Create: `scripts/items/normal_fish_item.gd`
- Create: `scripts/items/aggressive_fish_item.gd`
- Create: `scripts/items/chest_item.gd`
- Create: `scripts/items/treasure_item.gd`
- Create: `scenes/junk_item.tscn`
- Create: `scenes/normal_fish_item.tscn`
- Create: `scenes/aggressive_fish_item.tscn`
- Create: `scenes/chest_item.tscn`
- Create: `scenes/treasure_item_small.tscn`
- Create: `scenes/treasure_item_large.tscn`

**Interfaces:**
- Consumes: `Game.JUNK_VX_*`, `Game.JUNK_VY_*`, `Game.CHEST_VX_*`, `Game.FISH_*`, `Game.AGGRO_*`, `Game.TREASURE_*` (Task 1), `Game.WATERLINE_Y`, `Game.SCORE_PER_KILL`, `Game.SEABED_Y`, `Game.SHIP_X` (existing)
- Produces: `class_name JunkItem`, `class_name NormalFishItem`, `class_name AggressiveFishItem`, `class_name ChestItem`, `class_name TreasureItem`, and their `.tscn` files — consumed by spawner (Task 4)

**What this task achieves:** All 5 types exist on disk. Scene files reference scripts correctly. Clean boot confirms no parse errors. Old spawner still uses old items — new types not spawned yet.

**Ordering constraint:** Write scenes FIRST (they reference scripts by path), then run project to generate `.gd.uid` files. The `preload()` calls in chest_item.gd's LOOT_TABLE need all scenes to exist, so chest_item.gd is the last script written.

- [ ] **Step 1: Write `scripts/items/junk_item.gd`**

```gdscript
class_name JunkItem
extends Item
# 垃圾：左移 + 上浮至水面即止（复用基类水线钳制），撞船扣耐久。

const DAMAGE := 25
const SCORE := 10

func _init_velocity() -> Vector2:
	return Vector2(randf_range(Game.JUNK_VX_MIN, Game.JUNK_VX_MAX),
					randf_range(Game.JUNK_VY_MIN, Game.JUNK_VY_MAX))

func _get_damage() -> int:
	return DAMAGE

func _get_score() -> int:
	return SCORE
```

JunkItem uses `Game.JUNK_VX_*` for horizontal speed and `Game.JUNK_VY_*` for vertical.

- [ ] **Step 2: Write `scripts/items/normal_fish_item.gd`**

```gdscript
class_name NormalFishItem
extends Item
# 普通鱼：左移 + 垂直正弦摆动。摆动以 setup() 时的 y 为基准。

const DAMAGE := 25
const SCORE := 20

var _spawn_y: float = 0.0
var _swing_time: float = 0.0

func _init_velocity() -> Vector2:
	_spawn_y = global_position.y
	_swing_time = randf_range(0.0, TAU)
	return Vector2(randf_range(Game.FISH_VX_MIN, Game.FISH_VX_MAX), 0.0)

func _post_move(delta: float) -> void:
	super._post_move(delta)
	_swing_time += delta
	global_position.y = _spawn_y + sin(_swing_time * Game.FISH_SWING_FREQ) * Game.FISH_SWING_AMP

func _get_damage() -> int:
	return DAMAGE

func _get_score() -> int:
	return SCORE
```

- [ ] **Step 3: Write `scripts/items/aggressive_fish_item.gd`**

```gdscript
class_name AggressiveFishItem
extends NormalFishItem
# 攻击性鱼：继承普通鱼摆动。进入检测范围后转向朝向船，停顿后直线冲撞。

enum AggroState { PATROL, WINDUP, CHARGE }

const DAMAGE := 35
const SCORE := 40

var _aggro_state: AggroState = AggroState.PATROL
var _windup_timer: float = 0.0

func _post_move(delta: float) -> void:
	match _aggro_state:
		AggroState.PATROL:
			super._post_move(delta)
			if _distance_to_ship() <= Game.AGGRO_DETECT_DIST:
				_aggro_state = AggroState.WINDUP
				_windup_timer = 0.0
		AggroState.WINDUP:
			_windup_timer += delta
			_face_ship()
			if _windup_timer >= Game.AGGRO_WINDUP_TIME:
				_aggro_state = AggroState.CHARGE
				velocity = _dir_to_ship() * Game.AGGRO_CHARGE_SPEED
		AggroState.CHARGE:
			pass  # velocity set at transition; base _physics_process moves us

func _distance_to_ship() -> float:
	return global_position.distance_to(Vector2(Game.SHIP_X, Game.WATERLINE_Y))

func _dir_to_ship() -> Vector2:
	var d := Vector2(Game.SHIP_X, Game.WATERLINE_Y) - global_position
	if d.length_squared() < 0.0001:
		return Vector2.LEFT
	return d.normalized()

func _face_ship() -> void:
	rotation = _dir_to_ship().angle()

func _get_damage() -> int:
	return DAMAGE

func _get_score() -> int:
	return SCORE
```

- [ ] **Step 4: Write `scenes/junk_item.tscn`**

```gd-scene
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/items/junk_item.gd" id="1_junk_item"]

[sub_resource type="RectangleShape2D" id="RectangleShape2D_1"]
size = Vector2(24, 24)

[node name="JunkItem" type="Area2D"]
script = ExtResource("1_junk_item")

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("RectangleShape2D_1")

[node name="Body" type="Polygon2D" parent="."]
polygon = PackedVector2Array(-12, -12, 12, -12, 12, 12, -12, 12)
color = Color(0.35, 0.35, 0.35, 1)
```

- [ ] **Step 5: Write `scenes/normal_fish_item.tscn`**

```gd-scene
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/items/normal_fish_item.gd" id="1_normal_fish"]

[sub_resource type="RectangleShape2D" id="RectangleShape2D_1"]
size = Vector2(24, 30)

[node name="NormalFishItem" type="Area2D"]
script = ExtResource("1_normal_fish")

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("RectangleShape2D_1")

[node name="Body" type="Polygon2D" parent="."]
polygon = PackedVector2Array(0, -15, 11, 0, 0, 15, -11, 0)
color = Color(0.3, 0.5, 0.9, 1)
```

- [ ] **Step 6: Write `scenes/aggressive_fish_item.tscn`**

```gd-scene
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/items/aggressive_fish_item.gd" id="1_aggro_fish"]

[sub_resource type="RectangleShape2D" id="RectangleShape2D_1"]
size = Vector2(24, 30)

[node name="AggressiveFishItem" type="Area2D"]
script = ExtResource("1_aggro_fish")

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("RectangleShape2D_1")

[node name="Body" type="Polygon2D" parent="."]
polygon = PackedVector2Array(0, -15, 11, 0, 0, 15, -11, 0)
color = Color(0.9, 0.2, 0.2, 1)
```

- [ ] **Step 7: Write `scenes/chest_item.tscn`**

Hexagon polygon: `PackedVector2Array(0, -13, 13, -6.5, 13, 6.5, 0, 13, -13, 6.5, -13, -6.5)`.

```gd-scene
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/items/chest_item.gd" id="1_chest_item"]

[sub_resource type="RectangleShape2D" id="RectangleShape2D_1"]
size = Vector2(28, 28)

[node name="ChestItem" type="Area2D"]
script = ExtResource("1_chest_item")

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("RectangleShape2D_1")

[node name="Body" type="Polygon2D" parent="."]
polygon = PackedVector2Array(0, -13, 13, -6.5, 13, 6.5, 0, 13, -13, 6.5, -13, -6.5)
color = Color(0.55, 0.35, 0.1, 1)
```

- [ ] **Step 8: Write `scenes/treasure_item_small.tscn`**

```gd-scene
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/items/treasure_item.gd" id="1_treasure_item"]

[sub_resource type="RectangleShape2D" id="RectangleShape2D_1"]
size = Vector2(14, 18)

[node name="TreasureItem" type="Area2D"]
script = ExtResource("1_treasure_item")
treasure_size = 0

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("RectangleShape2D_1")

[node name="Body" type="Polygon2D" parent="."]
polygon = PackedVector2Array(0, -8, 6, 0, 0, 8, -6, 0)
color = Color(1.0, 0.85, 0.1, 1)
```

- [ ] **Step 9: Write `scenes/treasure_item_large.tscn`**

```gd-scene
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/items/treasure_item.gd" id="1_treasure_item"]

[sub_resource type="RectangleShape2D" id="RectangleShape2D_1"]
size = Vector2(22, 30)

[node name="TreasureItem" type="Area2D"]
script = ExtResource("1_treasure_item")
treasure_size = 1

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("RectangleShape2D_1")

[node name="Body" type="Polygon2D" parent="."]
polygon = PackedVector2Array(0, -14, 10, 0, 0, 14, -10, 0)
color = Color(1.0, 0.75, 0.05, 1)
```

- [ ] **Step 10: Write `scripts/items/treasure_item.gd`**

```gdscript
class_name TreasureItem
extends Item
# 宝藏：仅从箱子掉落。缓慢向下坠落至海底销毁。大小由 treasure_size export 区分。

enum Size { SMALL, LARGE }
@export var treasure_size: Size = Size.SMALL

const DAMAGE := 0

func _init_velocity() -> Vector2:
	var vy := Game.TREASURE_FALL_SPEED_SMALL if treasure_size == Size.SMALL else Game.TREASURE_FALL_SPEED_LARGE
	return Vector2(0.0, vy)

func _post_move(_delta: float) -> void:
	super._post_move(_delta)
	if global_position.y >= Game.SEABED_Y:
		queue_free()

func _get_damage() -> int:
	return DAMAGE

func _get_score() -> int:
	return 50 if treasure_size == Size.SMALL else 100
```

- [ ] **Step 11: Write `scripts/items/chest_item.gd`** (last — needs all scene files from steps 4-9 to exist for preload)

```gdscript
class_name ChestItem
extends Item
# 箱子：纯左移。被锚击毁时原地生成一个随机掉落物。

const DAMAGE := 25
const SCORE := 10

const LOOT_TABLE: Array[Dictionary] = [
	{"scene": preload("res://scenes/junk_item.tscn"),             "weight": 0.100},
	{"scene": preload("res://scenes/normal_fish_item.tscn"),      "weight": 0.050},
	{"scene": preload("res://scenes/aggressive_fish_item.tscn"),  "weight": 0.025},
	{"scene": preload("res://scenes/treasure_item_small.tscn"),   "weight": 0.020},
	{"scene": preload("res://scenes/treasure_item_large.tscn"),   "weight": 0.010},
]

func _init_velocity() -> Vector2:
	return Vector2(randf_range(Game.CHEST_VX_MIN, Game.CHEST_VX_MAX), 0.0)

func _on_killed() -> void:
	var scene: PackedScene = _pick_loot_scene()
	var item: Item = scene.instantiate()
	get_parent().add_child(item)
	item.setup(global_position)

func _pick_loot_scene() -> PackedScene:
	var roll := randf()
	var total := 0.0
	for entry in LOOT_TABLE:
		total += entry.weight
	for entry in LOOT_TABLE:
		var norm := entry.weight / total
		if roll <= norm:
			return entry.scene
		roll -= norm
	return LOOT_TABLE[-1].scene

func _get_damage() -> int:
	return DAMAGE

func _get_score() -> int:
	return SCORE
```

- [ ] **Step 12: Run project, verify clean boot**

Run: `mcp__godot__run_project` (projectPath `/Users/songer/ownCloud/Projects/anchor-game`)
Wait 3s.
Run: `mcp__godot__get_debug_output`
Expected: `"errors": []` — no parse errors on any new script or scene. Old spawner still uses drift/floater; new types not spawned yet.

If `errors` is non-empty, check the line numbers and fix syntax.

Run: `mcp__godot__stop_project`

- [ ] **Step 13: Commit all new files including .uid files**

```bash
git add scripts/items/junk_item.gd scripts/items/junk_item.gd.uid \
        scripts/items/normal_fish_item.gd scripts/items/normal_fish_item.gd.uid \
        scripts/items/aggressive_fish_item.gd scripts/items/aggressive_fish_item.gd.uid \
        scripts/items/chest_item.gd scripts/items/chest_item.gd.uid \
        scripts/items/treasure_item.gd scripts/items/treasure_item.gd.uid \
        scenes/junk_item.tscn scenes/normal_fish_item.tscn \
        scenes/aggressive_fish_item.tscn scenes/chest_item.tscn \
        scenes/treasure_item_small.tscn scenes/treasure_item_large.tscn
git commit -m "feat(item): add 5 new item types with scripts and scenes

- JunkItem: drifts left + rises, damages ship
- NormalFishItem: drifts left + vertical sine swing
- AggressiveFishItem: extends NormalFish, charges ship when close
- ChestItem: drifts left, drops random loot on anchor kill
- TreasureItem: falls downward, spawned only from chest loot"
```

---

### Task 3: Update item.gd base class + patch old drift/floater

**Files:**
- Modify: `scripts/item.gd` — replace `Game.SCORE_PER_KILL` with `_get_score()`, add `_on_killed()` hook
- Modify: `scripts/items/drift_item.gd` — add `_get_score()` override
- Modify: `scripts/items/floater_item.gd` — add `_get_score()` override

**Interfaces:**
- Consumes: (none new — item.gd changes affect all Item subclasses)
- Produces: `func _get_score() -> int` (virtual, default 0), `func _on_killed() -> void` (virtual, no-op) — called by base `_on_area_entered`
- Produces: `DriftItem._get_score()` returns `Game.SCORE_PER_KILL`, `FloaterItem._get_score()` returns `Game.SCORE_PER_KILL` (temp; removed in Task 5)

**What this task achieves:** Base class delegates scoring to subclasses. Old items still work via temporary `_get_score()` that reads `Game.SCORE_PER_KILL`. Clean boot + old items still grant 10 points.

- [ ] **Step 1: Edit `scripts/item.gd` — add `_get_score()` and `_on_killed()`, update `_on_area_entered`**

Replace the `_on_area_entered` method and add the two new virtual methods. The `_get_damage()` and other methods stay unchanged.

**Edit 1**: Replace `Game.SCORE_PER_KILL` → `_get_score()` and add `_on_killed()`:

old:
```gdscript
	if area.is_in_group("anchor_head"):
		Game.add_score(Game.SCORE_PER_KILL)
		queue_free()
```

new:
```gdscript
	if area.is_in_group("anchor_head"):
		Game.add_score(_get_score())
		_on_killed()
		queue_free()
```

**Edit 2**: Add virtual methods after `_get_damage()`:

old:
```gdscript
func _get_damage() -> int:               return 0              # 默认无伤害（子类覆写）
```

new:
```gdscript
func _get_damage() -> int:               return 0              # 默认无伤害（子类覆写）

func _get_score() -> int:                return 0              # 默认无得分（子类覆写）

func _on_killed() -> void:               pass                  # 被锚击毁钩子（子类覆写）
```

- [ ] **Step 2: Patch `scripts/items/drift_item.gd` — add `_get_score()`**

Append after the existing `_get_damage()`:

```gdscript
func _get_score() -> int:
	return Game.SCORE_PER_KILL
```

- [ ] **Step 3: Patch `scripts/items/floater_item.gd` — add `_get_score()`**

Append after the existing `_get_damage()`:

```gdscript
func _get_score() -> int:
	return Game.SCORE_PER_KILL
```

Both old types still use `Game.SCORE_PER_KILL` — this constant still exists until Task 5 cleanup. The override ensures old items still give 10 points after the base class switches to `_get_score()`.

- [ ] **Step 4: Run project, verify clean boot + score still works**

Run: `mcp__godot__run_project` (projectPath `/Users/songer/ownCloud/Projects/anchor-game`)
Wait 3s.
Run: `mcp__godot__get_debug_output`
Expected: `"errors": []`.

Manual playtest (quick):
1. Start game (Space).
2. Fire anchor at items — score should increment by 10 per kill (old items + SCORE_PER_KILL still works).
3. Let FLOATER hit ship — durability drops by 25.

Run: `mcp__godot__stop_project`

- [ ] **Step 5: Commit**

```bash
git add scripts/item.gd scripts/items/drift_item.gd scripts/items/floater_item.gd
git commit -m "refactor(item): add _get_score/_on_killed virtual methods to base class"
```

---

### Task 4: Update spawner to use new item types

**Files:**
- Modify: `scripts/spawner.gd` — replace 2-item 50/50 with 4-item weighted table

**Interfaces:**
- Consumes: `JunkItem`, `NormalFishItem`, `AggressiveFishItem`, `ChestItem` scene files (Task 2), `Item` base class (existing)
- Produces: spawner now instantiates the 4 new types by weight; `clear_all()` unchanged (`is Item` still matches all subclasses)

**What this task achieves:** New item types appear in gameplay. Old items are no longer spawned (but their files still exist). Visual/behavioral differentiation visible: gray squares, blue diamonds, red diamonds, brown hexagons.

- [ ] **Step 1: Rewrite `scripts/spawner.gd`**

Replace the entire file:

```gdscript
class_name Spawner
extends Node2D
# Periodically spawns items on the right edge at a random depth while playing.

@export var spawn_interval := 1.4

const SPAWN_TABLE: Array[Dictionary] = [
	{"scene": preload("res://scenes/junk_item.tscn"),             "weight": 0.25},
	{"scene": preload("res://scenes/normal_fish_item.tscn"),      "weight": 0.30},
	{"scene": preload("res://scenes/aggressive_fish_item.tscn"),  "weight": 0.20},
	{"scene": preload("res://scenes/chest_item.tscn"),            "weight": 0.25},
]

var _timer := 0.0

func _physics_process(delta: float) -> void:
	if not Game.is_playing():
		return
	_timer += delta
	if _timer >= spawn_interval:
		_timer = 0.0
		_spawn_one()

func _spawn_one() -> void:
	var scene: PackedScene = _pick_spawn_scene()
	var item: Item = scene.instantiate()
	add_child(item)
	var y := randf_range(Game.SPAWN_Y_MIN, Game.SPAWN_Y_MAX)
	item.setup(Vector2(Game.SPAWN_X, y))

func _pick_spawn_scene() -> PackedScene:
	var roll := randf()
	var acc := 0.0
	for entry in SPAWN_TABLE:
		acc += entry.weight
		if roll <= acc:
			return entry.scene
	return SPAWN_TABLE[-1].scene

func clear_all() -> void:
	for c in get_children():
		if c is Item:
			c.queue_free()
```

- [ ] **Step 2: Run project, verify new items spawn with correct visuals**

Run: `mcp__godot__run_project` (projectPath `/Users/songer/ownCloud/Projects/anchor-game`)
Wait 3s.
Run: `mcp__godot__get_debug_output`
Expected: `"errors": []`.

Manual playtest:
1. Start game. Observe 4 types spawning:
   - Gray squares (JunkItem) — drift left, rise to surface
   - Blue diamonds (NormalFishItem) — drift left, vertical swing
   - Red diamonds (AggressiveFishItem) — drift left, vertical swing
   - Brown hexagons (ChestItem) — drift left, no vertical
2. Shoot items with anchor — each type gives its correct score (Junk 10, NormalFish 20, AggroFish 40, Chest 10).
3. Shoot a ChestItem — verify a random item spawns at the chest's position.
4. Let AggressiveFish get close to ship — observe it turn toward ship, pause, then charge.
5. Let any type hit ship — durability decreases.

Run: `mcp__godot__stop_project`

- [ ] **Step 3: Commit**

```bash
git add scripts/spawner.gd
git commit -m "feat(spawner): switch to 5-type weighted spawn table"
```

---

### Task 5: Remove old drift/floater files + cleanup game.gd

**Files:**
- Delete: `scripts/items/drift_item.gd`, `scripts/items/drift_item.gd.uid`
- Delete: `scripts/items/floater_item.gd`, `scripts/items/floater_item.gd.uid`
- Delete: `scenes/drift_item.tscn`, `scenes/floater_item.tscn`
- Modify: `autoload/game.gd` — remove `SCORE_PER_KILL`, `ITEM_VX_MIN`, `ITEM_VX_MAX`, `FLOATER_VY_MIN`, `FLOATER_VY_MAX`

**Interfaces:**
- Consumes: spawner already switched (Task 4) — no code references `DriftItem`, `FloaterItem`, `SCORE_PER_KILL`, `ITEM_VX_*`, or `FLOATER_VY_*` (old names)
- Produces: clean project — no dead code or dead constants

**What this task achieves:** Old two-type system fully removed. Only 5 new types remain. All constants cleaned.

- [ ] **Step 1: Note what's still referencing old constants**

In `autoload/game.gd`:
- `SCORE_PER_KILL` — only referenced by drift_item.gd and floater_item.gd (both being deleted). Not referenced by any new code (new items use their own `SCORE` const).
- `ITEM_VX_MIN`, `ITEM_VX_MAX` — only referenced by old drift_item.gd and floater_item.gd (both being deleted). JunkItem uses `JUNK_VX_*` (added in Task 1). Safe to remove.
- `FLOATER_VY_MIN`, `FLOATER_VY_MAX` — only referenced by old floater_item.gd. JunkItem uses `JUNK_VY_*` (added in Task 1). Safe to remove.

So the cleanup is:
- Remove: `SCORE_PER_KILL`, `ITEM_VX_MIN`, `ITEM_VX_MAX`, `FLOATER_VY_MIN`, `FLOATER_VY_MAX`

- [ ] **Step 2: Delete old files**

```bash
rm scripts/items/drift_item.gd scripts/items/drift_item.gd.uid
rm scripts/items/floater_item.gd scripts/items/floater_item.gd.uid
rm scenes/drift_item.tscn scenes/floater_item.tscn
```

- [ ] **Step 3: Remove dead constants from `autoload/game.gd`**

Remove these five lines:
```
const SCORE_PER_KILL := 10
```
```
const FLOATER_VY_MIN := -70.0
const FLOATER_VY_MAX := -25.0
```
```
const ITEM_VX_MIN    := -180.0
const ITEM_VX_MAX    := -90.0
```

Five separate deletions from the constants block. After removal, the constants block reads:

```gdscript
const MAX_DURABILITY := 100

const JUNK_VX_MIN := -180.0
const JUNK_VX_MAX := -90.0
const JUNK_VY_MIN := -70.0
const JUNK_VY_MAX := -25.0
# ... rest of new constants ...
```

- [ ] **Step 4: Run project, verify clean boot**

Run: `mcp__godot__run_project` (projectPath `/Users/songer/ownCloud/Projects/anchor-game`)
Wait 3s.
Run: `mcp__godot__get_debug_output`
Expected: `"errors": []` — no references to deleted classes or constants.

If errors appear, check for stale references in any other file.

Run: `mcp__godot__stop_project`

- [ ] **Step 5: Commit**

```bash
git add scripts/items/drift_item.gd scripts/items/drift_item.gd.uid \
        scripts/items/floater_item.gd scripts/items/floater_item.gd.uid \
        scenes/drift_item.tscn scenes/floater_item.tscn \
        autoload/game.gd
git commit -m "chore(item): remove deprecated drift/floater, clean dead game.gd constants"
```

---

### Task 6: Full playtest verification

**Files:**
- None (verification only)

**What this task achieves:** All spec §10 test items pass. Game is fully playable with 5 new types.

- [ ] **Step 1: Run project for extended playtest**

Run: `mcp__godot__run_project` (projectPath `/Users/songer/ownCloud/Projects/anchor-game`)
Wait 3s.
Run: `mcp__godot__get_debug_output`
Expected: `"errors": []`

- [ ] **Step 2: Play through all spec test items**

1. **Clean boot**: `errors: []` confirmed in Step 1.
2. **JunkItem**: Gray squares spawn, rise to y≈180, drift left along surface, anchor kill +10, ship hit -25.
3. **NormalFishItem**: Blue diamonds spawn, sine-wave swing, anchor kill +20, ship hit -25.
4. **AggressiveFishItem — PATROL**: Red diamonds, swing like NormalFish. Visually distinct.
5. **AggressiveFishItem — attack**: When within ~576px of ship → rotates to face ship → pauses ~0.5s → charges in straight line. Ship hit -35. Anchor kill +40 (during any state).
6. **ChestItem**: Brown hexagons, pure left drift, anchor kill +10, loot spawns at death position.
7. **ChestItem — loot**: Multiple chest kills → observe loot distribution (junk common, large treasure rare). Loot items spawn with correct behavior.
8. **TreasureItem**: Gold diamonds fall straight down, stop at seabed, anchor kill +50 (small) / +100 (large).
9. **Collision groups**: All items: `area_entered` dispatches correctly (ship → damage, anchor_head → score). No double triggers.
10. **Flow**: READY → no spawn. Space → PLAYING → 4 types spawn. Durability 0 → GAME_OVER → items cleared. Space → restart normal.
11. **Virtual methods**: `_get_score()` returns correct per-type value. `_get_damage()`: TreasureItem returns 0 (safe default).

- [ ] **Step 3: Quick edge case checks**

- Fire anchor through 2+ items in one shot → anchor penetrates, multi-kill works, correct scores per type.
- AggressiveFish in CHARGE hits ship → damage 35, self-destruct, no re-entry.
- TreasureItem falls past seabed → `queue_free()` at y >= 600.
- Chest loot spawns correctly when chest parent is Spawner → `get_parent().add_child(loot)` works.

Run: `mcp__godot__stop_project`

- [ ] **Step 4: Final git status check**

```bash
git status
```

Expected: clean working tree on main branch. All `.uid` files tracked.

- [ ] **Step 5: Done — no commit needed (verification only)**
