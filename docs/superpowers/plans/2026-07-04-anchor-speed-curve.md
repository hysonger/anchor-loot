# Anchor speed curve Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add direction-based speed compensation to the anchor: shots closer to vertical fly faster, using a cosine curve with a configurable floor ratio. Also bump full speed from 650 to 800.

**Architecture:** Two-file change — config constant + existing speed line in the launched state. The normalized `fly_direction.y` equals `cos(angle_from_vertical)`, so no trig needed. All constants stay in `game.gd` following the project's established pattern.

**Tech Stack:** Godot 4.6 GDScript

## Global Constraints

- No external art/audio assets — pure geometry
- All tunable constants go in `autoload/game.gd`
- Verification via `mcp__godot__run_project` + playtest (no automated test suite)

---

### Task 1: Update fire speed to 800 and add MIN_RATIO constant

**Files:**
- Modify: `autoload/game.gd:58`

**Interfaces:**
- Produces: `Game.ANCHOR_FIRE_SPEED := 800.0` (was 650.0), `Game.ANCHOR_SPEED_MIN_RATIO := 0.4`

- [ ] **Step 1: Change ANCHOR_FIRE_SPEED and add ANCHOR_SPEED_MIN_RATIO**

In `autoload/game.gd`, replace line 58:
```gdscript
const ANCHOR_FIRE_SPEED := 650.0
```
with:
```gdscript
const ANCHOR_FIRE_SPEED := 800.0
# Anchor speed curve: horizontal shots run at this fraction of vertical speed.
# 0.0 = motionless at horizontal, 1.0 = no compensation (all directions equal).
const ANCHOR_SPEED_MIN_RATIO := 0.4
```

- [ ] **Step 2: Commit**

```bash
git add autoload/game.gd
git commit -m "feat(anchor): bump fire speed to 800, add ANCHOR_SPEED_MIN_RATIO constant"
```

---

### Task 2: Apply cosine speed compensation in launched state

**Files:**
- Modify: `scripts/anchor_states/launched.gd:16`

**Interfaces:**
- Consumes: `Game.ANCHOR_FIRE_SPEED` (800.0), `Game.ANCHOR_SPEED_MIN_RATIO` (0.4)
- Produces: direction-aware speed for `LaunchedState.physics_process`

- [ ] **Step 1: Replace the constant-speed line with compensated speed**

In `scripts/anchor_states/launched.gd`, replace line 16:
```gdscript
anchor.head.global_position += anchor.fly_direction * Game.ANCHOR_FIRE_SPEED * delta
```
with:
```gdscript
var speed_factor := Game.ANCHOR_SPEED_MIN_RATIO + (1.0 - Game.ANCHOR_SPEED_MIN_RATIO) * anchor.fly_direction.y
var speed := Game.ANCHOR_FIRE_SPEED * speed_factor
anchor.head.global_position += anchor.fly_direction * speed * delta
```

- [ ] **Step 2: Commit**

```bash
git add scripts/anchor_states/launched.gd
git commit -m "feat(anchor): apply cosine speed compensation by fire angle"
```

---

### Task 3: Verify via playtest

**Files:** (none — manual verification)

- [ ] **Step 1: Run the project**

```
mcp__godot__run_project(projectPath: "/Users/songer/ownCloud/Projects/anchor-game")
```

- [ ] **Step 2: Playtest — fire at different angles**

1. Click nearly straight down → anchor should fly noticeably faster than before (800 vs old 650)
2. Click near-horizontal to the right → anchor should be visibly slower (~320 px/s, about 2.5× slower than vertical)
3. Click at ~45° downward → speed between the two extremes
4. Verify the anchor still retracts correctly at seabed and max chain length

- [ ] **Step 3: Check debug output for errors**

```
mcp__godot__get_debug_output()
```
Expected: `errors: []`

- [ ] **Step 4: Commit if no further changes needed**

No code changes expected at this step — verification is read-only.
