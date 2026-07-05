# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Anchor Loot — a 2D side-scroller in Godot 4.6 (GL Compatibility renderer). A ship floats at the left waterline; items spawn on the right and drift left. The player fires an anchor (mouse click) to destroy items for score; the anchor can be retracted mid-flight with a second click. Some items damage the ship on contact; durability reaching 0 ends the run. The game uses real art assets (no procedural generation).

## Running & verifying

There is **no `godot` CLI on PATH** and no automated test suite. Run and verify exclusively through the **godot MCP server**:

- `mcp__godot__run_project` (projectPath `/Users/songer/ownCloud/Projects/anchor-loot`) — launches in debug mode. Optional `scene` param runs a specific scene without mutating `main_scene`.
- `mcp__godot__get_debug_output` — returns `{output, errors}` **while the process is active**; confirm `errors: []` for a clean boot and read runtime `print()` output. Returns nothing once the game closes, and does NOT capture the GUI editor.
- `mcp__godot__stop_project` — stops a running project.
- Runtime `print()` output and parse-time warnings also persist to `~/Library/Application Support/Godot/app_userdata/Anchor Loot/logs/godot.log` — read after the process closes if you didn't poll in time.

Debugging flow that works here: add `print("[DBG] ...")` at component boundaries → `run_project` → user reproduces → `get_debug_output` (or read godot.log). Use comma-form `print(a, b, c)` — `"x %s" % array` triggers a formatting error.

There is no lint/format step configured. Verification is manual playtest.

## Architecture

Three independent state-management strategies, deliberately at different abstraction levels:

1. **Anchor** — formal `State` class hierarchy (`scripts/state_machine.gd` + `scripts/anchor_states/{state,idle,launched,retracting}.gd`). The anchor has real spatial behavior (seabed geometry, multiple retract triggers, speed curve by angle), which warrants dedicated classes.
2. **Game flow** — enum `FlowState {READY, PLAYING, GAME_OVER}` + `match` in `autoload/game.gd`. Too simple for State classes.
3. **Items** — polymorphic `Item` base class (`scripts/item.gd`) with virtual hooks (`_init_velocity()`, `_post_move()`, `_get_damage()`, `_get_score()`, `_on_killed()`). Each item type is a subclass that overrides only what it needs.

### Item types

Five item subclasses in `scripts/items/`, each with its own scene in `scenes/`:

| Item | Behavior | Damages ship | Notes |
|---|---|---|---|
| **JunkItem** | Floats up to waterline, drifts left | Yes | |
| **NormalFishItem** | Sine-wave vertical swim, drifts left | Yes | |
| **AggressiveFishItem** | Like NormalFish, but charges toward ship when within detection range | Yes (higher) | Three-state internal FSM: PATROL → WINDUP → CHARGE |
| **ChestItem** | Sine-wave bob, drifts left | Yes | On anchor kill: opens sprite, drops a random loot (treasure or aggressive fish) |
| **TreasureItem** | Falls straight down to seabed, fades out | No | Two sizes (SMALL/LARGE); larger falls faster. High score value. |

### `Game` autoload is the hub

`autoload/game.gd` (registered as the `Game` singleton in `project.godot`) holds: flow state, durability, score, five broadcast signals (`durability_changed`, `score_changed`, `game_over`, `flow_changed`, `score_popup`), and **every tunable constant** (viewport, waterline/seabed Y, spawn bounds, speeds, scoring/damage, detection distances). When balancing or repositioning, change constants here — gameplay code references `Game.<CONST>`.

Cross-node coordination goes through `Game` signals + the `is_playing()` / `take_damage()` / `add_score()` / `reset()` / `on_start_button_pressed()` API. Game Over is triggered from `take_damage` (called in the Item collision callback), not from the button path.

### Input ownership: Ship owns all input, Anchor is driven

The Ship (`scripts/ship.gd`) handles `_unhandled_input` mouse clicks and drives the anchor through a small public API: `anchor.can_fire()`, `anchor.fire(direction)`, `anchor.request_retract()`. The `StateMachine` does **not** forward `_unhandled_input` — anchor states never see input directly.

`Ship.clamp_aim(dir)` is the only aim constraint: clamp `dir.y` to `>= 0` (never fire upward; horizontal is the max angle), then normalize. Zero/degenerate direction fires straight down.

**Speed curve**: horizontal shots are deliberately slower than vertical ones (`ANCHOR_SPEED_MIN_RATIO`). This compensates for the fact that horizontal shots cover more area — vertical shots get a speed bonus, making them viable for close-range reaction.

### Anchor is a sibling of Ship, not a child

`Anchor` is a top-level node in `main.tscn` (world coordinates), not parented to Ship. The chain start point is read live from `Ship.anchor_hole_global()` (returns `(Game.SHIP_X, Game.WATERLINE_Y)`). This keeps anchor motion in world space independent of the ship's transform.

The anchor head is an `Area2D` — motion is fully state-machine-driven, no physics simulation. It does **not** stop on hit: items handle their own destruction in `area_entered`, and the head keeps flying, so one shot can pass through multiple items (enabling the combo system).

### Combo multiplier

Each anchor flight (from fire to retract) tracks a `combo_count`. Every item hit increments it; the score for that hit is `base_score × combo_count`. This rewards line-up shots and adds strategy to aiming.

### Score popups

On each scored hit, `Game.score_popup` emits `(points, multiplier, at_position)`. `main.gd` creates floating `+N` or `+N (Mx)` labels that stack vertically near the ship, slide up as new ones appear, and fade out over time or when pushed too high.

### Group-based collision dispatch

Items self-dispatch collisions by group in `_on_area_entered`, decoupled from Ship/Anchor types:
- Collider in group `"anchor_head"` → `Game.add_score()` + combo multiplier + score popup + `_on_killed()` + `queue_free()`.
- Collider in group `"ship"` → `Game.take_damage(_get_damage())` + `queue_free()`.

Groups are set on the **Ship** and **Anchor Head** nodes. The Spawner parents runtime items under itself; `clear_all()` frees them on `READY`/`GAME_OVER` transitions.

### Spawning

`scripts/spawner.gd` spawns items at random depths on the right edge at a fixed interval, using a weighted random table. Items self-destruct when they go off-screen left (`x < -60`).

### Main assembles and wires

`scripts/main.gd` is the root scene controller: cross-links `ship.anchor = anchor` / `anchor.ship = ship`, binds HUD controls to `Game` signals, and manages the score popup display. Button visibility/text is driven by `flow_changed`. The StartButton is a `TextureButton` with hover overlay effects (tweened alpha).

## Godot 4 pitfalls (learned during development & build)

- The code uses **Tab** as indentation instead of spaces. Keep cautious when editing.
- Explicitly claim correct collision layers in the scene files, or the function will be broken.
- **ColorRects eat mouse clicks**: `Control` nodes default to `mouse_filter = STOP`, which consumes clicks before `_unhandled_input`. Set `mouse_filter = 2` (IGNORE) on non-interactive HUD controls.
- **Groups are a node-header attribute**, not a body property line. Writing `groups = ["x"]` as a property line is silently ignored in Godot 4 — the node gets no runtime group, `is_in_group()` returns false, and collision dispatch silently never fires. Put groups in the node header.
- **`:=` inference needs explicit types for class refs**: `var anchor: Node = ...` infers `Node`, not `Anchor` — write `var anchor: Anchor` when you need typed method access.
- **`.uid` files are tracked in git** (all of them) for stable resource references — don't delete `.gd.uid` files and don't add them to `.gitignore`.

## Development workflow

- **Design doc**: `GDD.md` — the game design document (in Chinese). Authoritative for gameplay intent.
- **Specs**: `docs/superpowers/specs/` — per-feature design specs with rationale.
- **Plans**: `docs/superpowers/plans/` — implementation plans.
- **Task ledger**: `.superpowers/sdd/progress.md` — per-task status and completion log; commits are the source of truth.

UI strings are in Chinese (e.g., StartButton text, MessageLabel prompts).
