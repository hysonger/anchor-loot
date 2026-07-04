# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Anchor Game — a 2D side-scroller in Godot 4.6 (GL Compatibility renderer). A ship floats at the left waterline; hazards spawn on the right and drift left. The player fires an anchor (mouse click) to destroy hazards for score. `FLOATER` hazards rise and damage the ship on contact; durability reaching 0 ends the run. Pure geometric prototypes — no external art/audio assets.

## Running & verifying

There is **no `godot` CLI on PATH** and no automated test suite. Run and verify exclusively through the **godot MCP server**:

- `mcp__godot__run_project` (projectPath `/Users/songer/ownCloud/Projects/anchor-game`) — launches in debug mode. Optional `scene` param runs a specific scene without mutating `main_scene`.
- `mcp__godot__get_debug_output` — returns `{output, errors}` **while the process is active**; confirm `errors: []` for a clean boot and read runtime `print()` output. Returns nothing once the game closes, and does NOT capture the GUI editor.
- `mcp__godot__stop_project` — stops a running project.
- Runtime `print()` output and parse-time warnings also persist to `~/Library/Application Support/Godot/app_userdata/Anchor Game/logs/godot.log` — read after the process closes if you didn't poll in time.

Debugging flow that works here: add `print("[DBG] ...")` at component boundaries → `run_project` → user reproduces → `get_debug_output` (or read godot.log). Use comma-form `print(a, b, c)` — `"x %s" % array` triggers a formatting error.

There is no lint/format step configured. Verification is manual playtest (spec §9 lists the playtest items).

## Architecture

Three independent state machines, deliberately at different abstraction levels (design §2):

1. **Anchor** — formal `State` class hierarchy (`scripts/state_machine.gd` + `scripts/anchor_states/{state,idle,launched,retracting}.gd`). `StateMachine` collects `State` children by node name, forwards `_physics_process` only, and switches via old.`exit()` → new.`enter()`. The anchor has real spatial behavior (chain length, seabed geometry, three retract triggers), which is why it gets classes instead of an enum.
2. **Game flow** — enum `FlowState {READY, PLAYING, GAME_OVER}` + `match` in `autoload/game.gd`. Too simple for State classes.
3. **Hazard kind** — enum `Kind {DRIFT, FLOATER}` in `scripts/hazard.gd`, branching in `_physics_process` / `_on_area_entered`.

### `Game` autoload is the hub

`autoload/game.gd` (registered as the `Game` singleton in `project.godot`) holds: flow state, durability, score, the four broadcast signals (`durability_changed`, `score_changed`, `game_over`, `flow_changed`), and **every tunable constant** (viewport, waterline/seabed Y, spawn bounds, speeds, chain length, scoring/damage). When balancing or repositioning, change constants here — gameplay code references `Game.<CONST>`.

Cross-node coordination goes through `Game` signals + the `is_playing()` / `take_damage()` / `add_score()` / `reset()` API, not direct node references. Game Over is triggered from `take_damage` (called in the Hazard collision callback), not from the button path — which is why flow state lives in an autoload rather than on Main.

### Input ownership: Ship owns all input, Anchor is driven

The Ship (`scripts/ship.gd`) handles `_unhandled_input` mouse clicks and drives the anchor through a small public API: `anchor.can_fire()`, `anchor.fire(direction)`, `anchor.request_retract()`. The `StateMachine` does **not** forward `_unhandled_input` — anchor states never see input directly. Single input entry point; state internals stay input-free.

`Ship.clamp_aim(dir)` is the only aim constraint: clamp `dir.y` to `>= 0` (never fire upward; horizontal is the max angle), then normalize. Zero/degenerate direction fires straight down.

### Anchor is a sibling of Ship, not a child

`Anchor` is a top-level node in `main.tscn` (world coordinates), not parented to Ship. The chain start point is read live from `Ship.anchor_hole_global()` (returns `(Game.SHIP_X, Game.WATERLINE_Y)`) — `_get_hole_global()` tolerates a null ship and falls back to those constants.

The anchor head is an `Area2D` (not `RigidBody2D`) — motion is fully state-machine-driven, no physics simulation. It does **not** stop on hit: hazards self-destruct in their own `area_entered`, and the head keeps flying, so one shot can pass through multiple hazards.

### Group-based collision dispatch

Hazards self-dispatch collisions by group in `_on_area_entered`, decoupled from Ship/Anchor types:
- counter in group `"anchor_head"` → `Game.add_score()` + `queue_free()` (anchor keeps flying).
- counter in group `"ship"` AND self is `FLOATER` → `Game.take_damage()` + `queue_free()` (one hit, no re-entry).
- `DRIFT` hazards pass through the ship area ignored.

Groups are set on the **Ship** and **Anchor Head** nodes. The Spawner parents runtime hazards under itself; `clear_all()` frees them on `READY`/`GAME_OVER` transitions.

### Main assembles and wires

`scripts/main.gd` is the root scene controller: cross-links `ship.anchor = anchor` / `anchor.ship = ship`, binds HUD controls to `Game` signals, and constructs the StartButton's `Space` shortcut in code (an `InputEventKey` with `physical_keycode = KEY_SPACE` assigned to `Button.shortcut`). Button visibility/text is driven by `flow_changed`. The Spawner clears hazards on `READY`/`GAME_OVER`.

## Godot 4 pitfalls (learned during build)

- **ColorRects eat mouse clicks**: `Control` nodes default to `mouse_filter = STOP`, which consumes clicks before `_unhandled_input`. Set `mouse_filter = 2` (IGNORE) on Background/Water/Seabed and non-interactive HUD controls. (Already applied in `main.tscn`.)
- **Groups are a node-header attribute**, not a body property line. Writing `groups = ["x"]` as a property line is silently ignored in Godot 4 — the node gets no runtime group, `is_in_group()` returns false, and collision dispatch silently never fires. Put groups in the node header.
- **`:=` inference needs explicit types for class refs**: `var anchor: Node = ...` infers `Node`, not `Anchor` — write `var anchor: Anchor` when you need typed method access. Several latent parse errors from this were fixed late.
- **`.uid` files are tracked in git** (all of them) for stable resource references — don't delete `.gd.uid` files and don't add them to `.gitignore`.

## Development workflow

This project was built with the Superpowers SDD (subagent-driven-development) workflow and still uses its conventions:

- **Spec**: `docs/superpowers/specs/2026-07-03-anchor-game-design.md` — the authoritative design doc (in Chinese). Read it for the full rationale behind the decisions above.
- **Plan**: `docs/superpowers/plans/2026-07-03-anchor-game.md`.
- **Task ledger**: `.superpowers/sdd/progress.md` — per-task status and completion log; commits are the source of truth.
- Per-task briefs/reports live alongside in `.superpowers/sdd/`. New work follows the same commit-per-task cadence.

UI strings are in Chinese (e.g., StartButton text, MessageLabel prompts).
