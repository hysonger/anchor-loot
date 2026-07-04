# 锚连击倍率机制 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在锚的一次飞行（发射→收回）中，命中物品按 1x/2x/3x... 递增倍率计分，弹窗显示倍率。

**Architecture:** 连击计数器 `combo_count` 放在 Anchor 节点上，由 Item 通过 `area.get_parent()` 获取并递增；IdleState 进入时清零。信号 `score_popup` 增加 multiplier 参数。共 5 个文件的小范围改动。

**Tech Stack:** Godot 4.6 GDScript

## Global Constraints

- 项目无 godot CLI，验证通过 `mcp__godot__run_project` + `get_debug_output`
- 弹窗文本格式：`multiplier == 1` → `"+N"`；`multiplier > 1` → `"+N (Mx)"`
- 连击在 IdleState.enter() 时重置（收回到位清零）
- 缓存物品的 anchor_head 碰撞分支逻辑在 Item 基类中，所有子类自动生效

---

## 文件结构

| 文件 | 改动类型 | 职责 |
|---|---|---|
| `scripts/anchor.gd` | 修改 | 新增 `combo_count` 变量和 `register_hit()` 方法 |
| `scripts/anchor_states/idle.gd` | 修改 | `enter()` 重置 `combo_count = 0` |
| `scripts/item.gd` | 修改 | anchor_head 碰撞分支中获取 Anchor、调用 `register_hit()`、传 multiplier |
| `autoload/game.gd` | 修改 | 信号签名加 `multiplier` 参数 |
| `scripts/main.gd` | 修改 | `_on_score_popup` 根据 multiplier 格式化弹窗文本 |

---

### Task 1: Anchor — 新增 combo_count 和 register_hit()

**Files:**
- Modify: `scripts/anchor.gd`

**Interfaces:**
- Consumes: 无
- Produces: `var combo_count: int = 0`, `func register_hit() -> int`

在现有 `fly_direction` 声明之后添加代码。

- [ ] **Step 1: 在 anchor.gd 添加 combo_count 和 register_hit()**

在 `var fly_direction: Vector2 = Vector2.ZERO`（第 15 行）之后插入：

```gdscript
# Combo counter: incremented on each hit during one flight. Reset on Idle.
var combo_count: int = 0

# Called by Item on hit. Returns the multiplier for this hit (1, 2, 3...).
func register_hit() -> int:
	combo_count += 1
	return combo_count
```

- [ ] **Step 2: 验证语法正确**

Run: `mcp__godot__run_project` → `mcp__godot__get_debug_output`，确认 `errors: []`

- [ ] **Step 3: Commit**

```bash
git add scripts/anchor.gd
git commit -m "feat(anchor): add combo_count and register_hit()"
```

---

### Task 2: IdleState — 重置 combo_count

**Files:**
- Modify: `scripts/anchor_states/idle.gd`

**Interfaces:**
- Consumes: `anchor.combo_count`（Task 1 定义的变量）
- Produces: 无（副作用：清零 combo_count）

- [ ] **Step 1: 在 IdleState.enter() 中重置 combo_count**

当前代码：
```gdscript
func enter() -> void:
	anchor.head.visible = true
	anchor.chain.visible = false
	anchor._snap_head_to_hole()
```

改为：
```gdscript
func enter() -> void:
	anchor.combo_count = 0
	anchor.head.visible = true
	anchor.chain.visible = false
	anchor._snap_head_to_hole()
```

- [ ] **Step 2: 验证语法**

Run: `mcp__godot__run_project` → `mcp__godot__get_debug_output`，确认 `errors: []`

- [ ] **Step 3: Commit**

```bash
git add scripts/anchor_states/idle.gd
git commit -m "feat(idle): reset combo_count on anchor retract"
```

---

### Task 3: Game — score_popup 信号增加 multiplier 参数

**Files:**
- Modify: `autoload/game.gd`

**Interfaces:**
- Consumes: 无
- Produces: `signal score_popup(points: int, multiplier: int, at_position: Vector2)`

- [ ] **Step 1: 修改信号签名**

当前（第 11 行）：
```gdscript
signal score_popup(points: int, at_position: Vector2)
```

改为：
```gdscript
signal score_popup(points: int, multiplier: int, at_position: Vector2)
```

- [ ] **Step 2: 验证语法**

Run: `mcp__godot__run_project` → `mcp__godot__get_debug_output`，确认 `errors: []`

- [ ] **Step 3: Commit**

```bash
git add autoload/game.gd
git commit -m "feat(game): add multiplier param to score_popup signal"
```

---

### Task 4: Item — 命中时获取倍率并传递

**Files:**
- Modify: `scripts/item.gd`

**Interfaces:**
- Consumes: `anchor.register_hit() -> int`（Task 1）、`Game.score_popup` 新签名（Task 3）
- Produces: 无（副作用：倍率计分 + 新信号参数）

- [ ] **Step 1: 修改 anchor_head 碰撞分支**

当前 `_on_area_entered` 的 anchor_head 分支（第 45-49 行）：
```gdscript
		if area.is_in_group("anchor_head"):
			Game.add_score(_get_score())
			Game.score_popup.emit(_get_score(), Vector2(Game.SHIP_X, Game.WATERLINE_Y))
			_on_killed()
			queue_free()
```

改为：
```gdscript
		if area.is_in_group("anchor_head"):
			var anchor := area.get_parent() as Anchor
			var mult := anchor.register_hit() if anchor != null else 1
			var final_score := _get_score() * mult
			Game.add_score(final_score)
			Game.score_popup.emit(final_score, mult, Vector2(Game.SHIP_X, Game.WATERLINE_Y))
			_on_killed()
			queue_free()
```

- [ ] **Step 2: 验证语法**

Run: `mcp__godot__run_project` → `mcp__godot__get_debug_output`，确认 `errors: []`

- [ ] **Step 3: Commit**

```bash
git add scripts/item.gd
git commit -m "feat(item): apply combo multiplier on anchor hit"
```

---

### Task 5: Main — 弹窗显示倍率

**Files:**
- Modify: `scripts/main.gd`

**Interfaces:**
- Consumes: `Game.score_popup(points, multiplier, at_position)` 新签名（Task 3）
- Produces: 无（副作用：弹窗文本含倍率）

`_on_score_popup` 签名和弹窗文本格式需要更新。

- [ ] **Step 1: 更新 _on_score_popup 签名和弹窗文本**

当前（第 86-96 行）：
```gdscript
func _on_score_popup(points: int, at_position: Vector2) -> void:
	var label := Label.new()
	label.text = "+%d" % points
	label.add_theme_font_size_override("font_size", POPUP_FONT_SIZE)
	label.add_theme_color_override("font_color", Color.GOLD)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = at_position + Vector2(randf_range(-POPUP_X_JITTER, POPUP_X_JITTER), 0.0)
	add_child(label)
	_popup_labels.append(label)
	_slide_popups()
	_prune_popups()
	get_tree().create_timer(POPUP_LIFETIME).timeout.connect(_on_popup_timeout.bind(label))
```

改为：
```gdscript
func _on_score_popup(points: int, multiplier: int, at_position: Vector2) -> void:
	var label := Label.new()
	if multiplier > 1:
		label.text = "+%d (%dx)" % [points, multiplier]
	else:
		label.text = "+%d" % points
	label.add_theme_font_size_override("font_size", POPUP_FONT_SIZE)
	label.add_theme_color_override("font_color", Color.GOLD)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = at_position + Vector2(randf_range(-POPUP_X_JITTER, POPUP_X_JITTER), 0.0)
	add_child(label)
	_popup_labels.append(label)
	_slide_popups()
	_prune_popups()
	get_tree().create_timer(POPUP_LIFETIME).timeout.connect(_on_popup_timeout.bind(label))
```

- [ ] **Step 2: （保留）** 方法底部代码（`_on_popup_timeout`、`_slide_popups`、`_prune_popups`、`_clear_popups`）不变

- [ ] **Step 3: 验证语法**

Run: `mcp__godot__run_project` → `mcp__godot__get_debug_output`，确认 `errors: []`

- [ ] **Step 4: Commit**

```bash
git add scripts/main.gd
git commit -m "feat(main): show combo multiplier in score popup"
```

---

### Task 6: 手动验证

**Files:**
- 无代码改动

运行项目并手动验证连击倍率表现。

- [ ] **Step 1: 运行项目**

`mcp__godot__run_project` → 启动游戏

- [ ] **Step 2: 验证连击命中**

按 Space 开始，点击发射锚，命中多个物品（比如一发射穿多个箱子/垃圾），观察弹窗：
- 第 1 个命中：`+10`（无倍率）
- 第 2 个命中：`+20 (2x)` 或 `+40 (2x)`（取决于物品基础分）
- 第 3 个命中：`+30 (3x)` 或 `+60 (3x)`

- [ ] **Step 3: 验证连击重置**

等待锚收回后再次发射，确认倍率从 1x 重新开始。

- [ ] **Step 4: 确认无异常**

`mcp__godot__get_debug_output` → errors 为空，控制台无异常。

---

## Verification

| 验证项 | 方法 |
|---|---|
| 语法无误 | `run_project` + `get_debug_output` → `errors: []` |
| 倍率递增 | 一锚穿多物，弹窗分别显示 1x、2x、3x |
| 倍率重置 | 收回再发，从 1x 重新开始 |
| 弹窗格式 | mult=1 仅 "+N"，mult>1 "+N (Mx)" |
