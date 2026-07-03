# Anchor Game — 设计文档

- **日期**: 2026-07-03
- **引擎**: Godot 4.6.stable（通过 MCP server 使用）
- **项目目录**: `/Users/songer/ownCloud/Projects/anchor-game`（初始为空目录）
- **状态**: 设计已确认，待写实现计划

## 1. 概述

横版 2D 游戏。画面左上一艘船浮在水面，水面以下占大半屏高度。水体右侧随机垂直位置刷出物体，随水流左移。两种物体：

- **A 型 (DRIFT)**：纯向左移动，不撞船。
- **B 型 (FLOATER)**：向左移动 **且向上浮动**，会撞船扣耐久。

船可发射锚摧毁物体（A/B 均可）得分。耐久清零 Game Over。锚有发射/飞行/收回三态，收回前无法再发射。

**核心约束（来自需求）**：
- 物体水平速度与 B 型上浮速度在一定范围内随机取值，使船确实受到被撞威胁。
- 锚：鼠标点击发射/收回，方向由鼠标指针与船锚接合点的连线决定（朝锚孔上方点击时夹到水平、不朝天）；触海底 / 达锁链最大长度 / 飞行中再次点击 → 收回；收回前不可再发射。
- 代码用状态机模式，结构清晰。

## 2. 已确认的决策

| 决策点 | 选择 |
|---|---|
| 目标/计分 | 击毁计分（A/B 均可被锚击毁得分） |
| 美术风格 | 纯几何原型（代码生成形状，无外部资源） |
| A 型是否撞船 | 仅 B 型撞船（A 型纯左移，只是经过） |
| 状态机架构 | 混合方案：锚用 State 类继承模式；游戏流程用枚举 `match`；物体用类型枚举 |
| 游戏开始/重开 | HUD 的 Button，`shortcut` 绑定 Space 快捷键，而非裸空格输入 |

## 3. 项目布局与场景树

视口 `1152×648`（16:9）。

### 目录结构

```
anchor-game/
├─ project.godot
├─ scenes/
│   ├─ main.tscn            # Main（运行时根场景）
│   ├─ ship.tscn            # 船
│   ├─ hazard.tscn          # 水中物体（A/B 共用，按 type 区分）
│   └─ anchor.tscn          # 锚
├─ scripts/
│   ├─ main.gd              # 游戏流程装配 + HUD 绑定
│   ├─ ship.gd              # 船：耐久、碰撞、鼠标点击发射/收回锚
│   ├─ anchor.gd            # 锚：持有 StateMachine + 链绘制
│   ├─ anchor_states/
│   │   ├─ state.gd         # State 基类
│   │   ├─ idle.gd
│   │   ├─ launched.gd
│   │   └─ retracting.gd
│   ├─ state_machine.gd     # 通用 StateMachine
│   ├─ hazard.gd            # 物体：移动 + 可选上浮 + 被击毁/撞船检测
│   └─ spawner.gd           # 右侧随机垂直位置定时生成物体
├─ autoload/
│   └─ game.gd              # Game 单例：流程状态、耐久、分数、信号
└─ docs/superpowers/specs/2026-07-03-anchor-game-design.md
```

### main.tscn 场景树

```
Main (Node2D) ← main.gd
├─ Background (ColorRect)        # 天色（整屏底层）
├─ Water (ColorRect)             # 水体（下部大半高度）
├─ Seabed (ColorRect)            # 海底线
├─ Spawner (Node2D)              # spawner.gd，子节点为运行时生成的 hazard
├─ Ship (实例化 ship.tscn)
├─ Anchor (实例化 anchor.tscn)   # 与 Ship 平级（世界坐标）
└─ HUD (CanvasLayer)
    ├─ DurabilityBar (ProgressBar)
    ├─ ScoreLabel (Label)
    ├─ MessageLabel (Label)      # 状态提示文字
    └─ StartButton (Button)      # 开始/重开，shortcut 绑定 Space
```

**锚的归属**：锚挂在 `Main` 下与 `Ship` 平级，使用世界坐标。链起点取自 Ship 报告的锚孔全局位置，终点为锚头位置。

## 4. 坐标、水体与边界

坐标系：原点左上，x→右，y→下。

### 水平分区（垂直方向）

- `y = 0 ~ WATERLINE_Y`：天空（船所在）
- `y = WATERLINE_Y`：水面线
- `y = WATERLINE_Y ~ SEABED_Y`：水体（物体生成与活动区）
- `y = SEABED_Y`：海底（锚到此收回）
- `y = SEABED_Y ~ 648`：海底视觉留白

### 关键常量（集中于 `game.gd` Autoload，全局可读）

```
const VIEWPORT_W   = 1152
const VIEWPORT_H   = 648
const WATERLINE_Y  = 180     # 水面（船浮在此线上方）
const SEABED_Y     = 600     # 海底（锚到此收回；留 48px 海底视觉带）
const SPAWN_X      = 1170    # 屏幕右侧外，物体生成点
const SPAWN_Y_MIN  = 220     # 生成区上界（水面下方一点）
const SPAWN_Y_MAX  = 560     # 生成区下界（海底上方一点）
const SHIP_X       = 150     # 船的水平位置
```

- 船的锚孔位于水线 `(SHIP_X, WATERLINE_Y)`，锚从此处向水中射出；水平发射时正好沿水面扫射已浮出水面的 B 型物体。
- 物体在 x=SPAWN_X 生成，y 随机于 `[SPAWN_Y_MIN, SPAWN_Y_MAX]`。
- **B 型上浮**：vy 为负，上浮至水面（`y ≤ WATERLINE_Y`）即停止上浮（`vy` 清零）、改为在水面漂流左移；仍可能撞船。被锚击毁或撞船后销毁。
- **锚的活动范围**：从锚孔出发，沿鼠标点击方向（钳为不朝天）飞入水中；触海底、达锁链最大长度、或飞行中再次点击鼠标 → 收回。

## 5. 游戏流程状态机（枚举 `match`，在 `game.gd` Autoload）

游戏仅 3 个状态，转换极简，用枚举 + `match`。不为它套 State 类。

```
enum FlowState { READY, PLAYING, GAME_OVER }
var flow_state: FlowState = FlowState.READY
```

### StartButton 与快捷键

- 一个 HUD 上的 `Button`，文案随状态切换：`READY` → "开始游戏 (Space)"，`GAME_OVER` → "重新开始 (Space)"。
- `Button.shortcut` 绑定 `Shortcut` 资源：`events` 含一个 `InputEventKey`（`physical_keycode = KEY_SPACE`）。在 `_ready` 中代码构造并赋值，无需外部资源。
- `pressed` 信号 → `Game.on_start_button_pressed()`，按 `flow_state` 分支：`READY` → 转 `PLAYING`；`GAME_OVER` → `reset()` 后转 `PLAYING`。
- 可见/可用性由 `flow_changed` 信号驱动：`READY`/`GAME_OVER` 时 `visible=true, disabled=false`；`PLAYING` 时隐藏并禁用。

**快捷键冲突避免**：Godot 4 中 `Button.shortcut` 在按钮可见且未禁用时全局生效（无需聚焦），先于 `_unhandled_input` 消费事件。`PLAYING` 时按钮禁用，shortcut 不再消费空格。锚的发射/收回现在由**鼠标点击**驱动（见 §6），不再占用空格，因此空格专属于"开始/重开"按钮，无残留冲突。READY→PLAYING 那次 Space 被按钮消费，随后按钮禁用。重开同理。

### 状态表

| 状态 | StartButton | Spawner/船/锚 | 转换触发 |
|---|---|---|---|
| `READY` | 显示 + 启用，文案"开始游戏 (Space)" | 暂停 | StartButton.pressed → `PLAYING` |
| `PLAYING` | 隐藏 + 禁用 | 全部运作 | 耐久≤0 → `GAME_OVER`（Ship 碰撞回调中 `take_damage` 触发）|
| `GAME_OVER` | 显示 + 启用，文案"重新开始 (Space)" | 暂停，清空残物 | StartButton.pressed → `reset()` → `PLAYING` |

### `game.gd` 接口

```
signal durability_changed(current: int, maxv: int)
signal score_changed(score: int)
signal game_over()
signal flow_changed(state)          # READY/PLAYING/GAME_OVER

var durability: int
var max_durability: int = 100
var score: int = 0

func on_start_button_pressed() -> void   # 按 flow_state 分支：开始 / 重开
func take_damage(n) -> void              # 扣耐久；≤0 发 game_over 并转 GAME_OVER
func add_score(n) -> void
func reset() -> void                     # 耐久=满、分数=0
func is_playing() -> bool
```

**为何用 Autoload**：耐久/分数/流程状态需被 Ship、Hazard、Anchor、HUD 跨节点读写，且 Game Over 由 Ship 碰撞回调中的 `take_damage` 触发（非按钮路径）。Autoload 提供全局访问点 + 信号广播，避免节点间互相持有引用的耦合。Main 仍负责场景装配与提示文字。

## 6. 锚的状态机（State 类继承模式）

锚是唯一用正式 State 类的系统：3 个状态、3 种触发转换、链长度约束、与海底/船的几何关系。用枚举 `match` 会让单文件变长且状态行为混杂。

### anchor.tscn

```
Anchor (Node2D) ← anchor.gd（持有 ship 引用；通过 StateMachine 节点驱动状态）
├─ StateMachine (Node)     # state_machine.gd，持有当前 State，转交 _physics_process/_unhandled_input
│   ├─ Idle (State)
│   ├─ Launched (State)
│   └─ Retracting (State)
├─ Chain (Line2D)          # 从船锚孔到锚头
└─ Head (Area2D)           # 锚头，加 anchor_head 组
    ├─ CollisionShape2D
    └─ Polygon2D
```

锚头用 `Area2D`（非 RigidBody）：锚运动完全由状态机控制，无需物理模拟；用 Area 检测击中 Hazard、触海底。

### state_machine.gd（通用）

```
class_name StateMachine extends Node
var current: State
func init(initial) -> void             # 由 anchor.gd 在 _ready 调用，传初始 State 节点
func change_to(state_name: String) -> void   # 旧 state.exit()、新 state.enter()
func _physics_process(dt): current.physics_process(dt)
```
（锚状态不直接处理输入——Ship 统一接管鼠标点击并通过 `fire()/request_retract()` 驱动状态机，故 StateMachine 不转发 `_unhandled_input`。）

### state.gd（基类）

```
class_name State extends Node
var anchor: Node                # 反向引用 Anchor
func enter() -> void
func exit() -> void
func physics_process(dt) -> void
```

### 三个状态子类

| 状态 | enter() | physics_process | 转换出 |
|---|---|---|---|
| **Idle** (`idle.gd`) | 锚头归位到船锚孔；链隐藏 | 无运动 | `Launched`（Ship 在鼠标点击时调 `anchor.fire(direction)`） |
| **Launched** (`launched.gd`) | 记录船锚孔为链起点；链可见；按发射方向给锚头初速 | 锚头沿方向匀速直线行进（下潜/斜向/水平皆可）；更新链终点；触海底 `y≥SEABED_Y` → `Retracting`；链长≥`MAX_CHAIN_LEN` → `Retracting`；Head Area 与 Hazard 重叠时由 **Hazard 自身**在 `area_entered` 里销毁并 `add_score`（锚**继续飞行，可穿多体**） | `Retracting` |
| **Retracting** (`retracting.gd`) | 记录当前锚头位置 | 锚头匀速向船锚孔移动；到位（距离<阈值）→ `Idle` | `Idle` |

### 关键约束落实

- **"收回前无法再发射"**：只有 Idle 能发射。Launched 中再次点击鼠标触发"收回"（Ship 调 `request_retract()` → 转 Retracting）；Retracting 期间点击被忽略（`can_fire()` 为 false 且 `request_retract()` 对非 Launched 无效）。由状态本身保证，无需额外标志位。
- **三类收回触发**：触海底 / 达最大链长 / 飞行中再次点击鼠标——前两者在 `Launched.physics_process` 判定，后者在 Ship 的点击处理中调 `anchor.request_retract()`，统一转 `Retracting`。
- **发射方向控制**：方向由鼠标点击位置与船锚孔连线决定，唯一约束为「不朝天」（详见下文）。无需独立"调角"输入。

### Ship ↔ Anchor 输入归属

**Ship 统一处理鼠标点击，Anchor 不碰输入。** Ship 监听鼠标点击（`_unhandled_input` 中 `MOUSE_BUTTON_LEFT` 的 `pressed`），仅在 `flow_state==PLAYING` 时响应。Anchor 持有 `ship` 引用以读取锚孔位置；暴露：

```
func can_fire() -> bool                      # 仅 Idle 为 true
func fire(direction: Vector2) -> void        # 已规整为「不朝天」的方向，锚头沿此方向飞行
func request_retract() -> void               # 仅 Launched 生效（飞行中再次点击）
```

**发射方向的计算**：点击发生时，取鼠标全局位置 `mp` 与船锚孔全局位置 `hole = Ship.anchor_hole_global()`（锚孔位于水线 `(SHIP_X, WATERLINE_Y)`）。方向向量 `d = mp - hole`。锚始终朝水里发射、**永不朝天**——方向 y 分量必为非负：
- `d.y > 0`（鼠标在锚孔下方/水里）：用真实 `d`，介于「竖直下潜」与「斜向」之间。
- `d.y ≤ 0`（鼠标在锚孔上方，即船甲板/天空）：将 `d.y` 钳为 `0`，方向变为**水平**（保留 x 分量，左右由鼠标 x 决定）。这样可沿水面水平扫射已浮出水面的 B 型物体。

唯一角度约束即「不朝天」（`d.y ≥ 0`），不再设额外最大偏角；水平为最大可达角，下潜深度与水平距离由 `MAX_CHAIN_LEN`/`ANCHOR_FIRE_SPEED` 自然约束。规整后的方向归一化传给 `anchor.fire(direction)`。Retracting 期间点击被忽略（锚不可再发射）。

`Ship._unhandled_input` 仅 PLAYING 处理：左键点击 → `if anchor.can_fire(): anchor.fire(规整方向) else: anchor.request_retract()`。

输入入口单一，状态机内部不碰输入。

## 7. 物体、Spawner、碰撞与击毁计分

### hazard.tscn（A/B 共用）

```
Hazard (Area2D) ← hazard.gd
├─ Body (Polygon2D)        # A 型方块色，B 型圆/三角（颜色+形状区分）
└─ CollisionShape2D        # RectangleShape2D
```

### hazard.gd

```
enum Kind { DRIFT, FLOATER }     # A=DRIFT，B=FLOATER
@export var kind: Kind
var velocity: Vector2            # x 负（左移）；B 型 y 负（上浮）

func setup(kind, pos):
    self.kind = kind
    position = pos
    velocity.x = Game.HAZARD_VX 随机
    if kind == FLOATER: velocity.y = Game.FLOATER_VY 随机
    set_color_by_kind()
func _physics_process(dt):
    position += velocity * dt
    # B 型上浮止于水面：到达水面后停止上浮，改为水面漂流
    if kind == FLOATER and velocity.y < 0 and position.y <= Game.WATERLINE_Y:
        position.y = Game.WATERLINE_Y
        velocity.y = 0.0
    # 越界销毁：x < -50（出左）。B 型已止于水面，不会出顶
func _on_area_entered(other):
    if other.is_in_group("anchor_head"):
        Game.add_score(Game.SCORE_PER_KILL); queue_free()
    elif other.is_in_group("ship") and kind == FLOATER:
        Game.take_damage(Game.DAMAGE_PER_HIT); queue_free()
```

### spawner.gd

```
@export var spawn_interval := 1.4
@onready var hazard_scene := preload("res://scenes/hazard.tscn")
var timer := 0.0
func _physics_process(dt):
    if not Game.is_playing(): return
    timer += dt
    if timer >= spawn_interval:
        timer = 0.0
        spawn_one()
func spawn_one():
    var h = hazard_scene.instantiate()
    add_child(h)
    var kind = randf() < 0.5 ? DRIFT : FLOATER
    var y = randf_range(Game.SPAWN_Y_MIN, Game.SPAWN_Y_MAX)
    h.setup(kind, Vector2(Game.SPAWN_X, y))
func clear_all():
    for c in get_children(): c.queue_free()
```

### 速度随机取值（需求要点）

- 水平速度 `vx`：`randf_range(-180, -90)` px/s（左移）。
- B 型上浮 `vy`：`randf_range(-70, -25)` px/s（向上）。
- **威胁来源**：B 型从生成点（`SPAWN_Y_MIN=220` 以下）上浮，需在抵达水面/撞上船之前被锚拦截，否则撞船。上浮速度随机使部分 B 型难以拦截 → 船受威胁。B 型到水面后停在水线漂流，继续左移经过船体范围仍是威胁（在水面撞船）。

### 碰撞 / 击毁处理

**用分组解耦**：
- Ship 为 `Area2D`（带 `CollisionShape2D`），加 `ship` 组。
- Anchor Head 加 `anchor_head` 组。
- Hazard 在 `area_entered` 判断对方组别处理，不直接知道 Ship/Anchor 类型。

1. **锚击毁物体（A/B 均可，+10 分）**：对方在 `anchor_head` 组 → `add_score(10)`，`queue_free()`。锚继续飞行，可穿多体。
2. **B 型撞船（扣 5 耐久，销毁该物体）**：对方在 `ship` 组且自身 kind==FLOATER → `take_damage(5)`，`queue_free()`（撞一次销毁，不连续扣）。
3. **A 型进入 ship 区域**：忽略，正常穿过。
4. **防重入**：`area_entered` 每对只触发一次，配合 `queue_free()`，不重复扣血/计分。

### 集中常量（`game.gd`）

```
SCORE_PER_KILL = 10
DAMAGE_PER_HIT = 5
HAZARD_VX_MIN = -180, HAZARD_VX_MAX = -90
FLOATER_VY_MIN = -70, FLOATER_VY_MAX = -25
MAX_CHAIN_LEN = 460
ANCHOR_FIRE_SPEED = 650
ANCHOR_RETRACT_SPEED = 900
# 无 FIRE_ANGLE_MAX_DEG：唯一角度约束为「不朝天」(方向 y≥0，水平为最大可达角，见 §6)
MAX_DURABILITY = 100
```

得分值、扣血值、速度范围全为常量集中，便于调参。

## 8. YAGNI / 明确不做

- 无音效、无粒子（纯几何原型）。
- 无持久化最高分（初版）。
- 无难度递增曲线（固定 `spawn_interval` 与速度范围，可后续扩展）。
- 无暂停（除 Game Over 外的暂停）。
- 物体无血量（一击即毁）。
- 锚无升级/冷却数值，仅"收回前不可再发射"约束。

## 9. 测试策略

代码结构上便于分块验证：
- 锚状态机：可独立验证 Idle→Launched→Retracting→Idle 闭环；触海底/达链长/飞行中再点击三条触发收回；收回前 fire 被拒。
- 物体/碰撞：A 型不扣血、B 型扣血并销毁；B 型上浮至水面停止（不超越水线）；锚击中任一型加分并继续飞行；越界销毁。
- 鼠标发射方向：点击水里→沿点击方向下潜；点击锚孔上方→夹到水平（不朝天，可扫水面物体）；Retracting 期间点击无效。
- 流程状态机：READY→PLAYING（按钮/Shortcut 快捷键）→GAME_OVER（耐久归零）→重开。
- 端到端手动跑：MCP `run_project` 启动，观察生成、碰撞、计分、Game Over、重开。
