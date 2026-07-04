# Anchor Game — 物品基类重构设计

- **日期**: 2026-07-04
- **引擎**: Godot 4.6（GL Compatibility，通过 MCP server 使用）
- **项目目录**: `/Users/songer/ownCloud/Projects/anchor-game`
- **状态**: 设计已确认，待写实现计划
- **关系**: 取代 `2026-07-03-anchor-game-design.md` §7（物体 / hazard 章节）；其余章节不变

## 1. 动机与目标

当前 `scripts/hazard.gd` 用 `enum Kind {DRIFT, FLOATER}` 在三处分支：`_physics_process`（FLOATER 上浮）、`_on_area_entered`（仅 FLOATER 撞船扣血）、`_apply_visual`（形状/颜色）。类型一多就退化为大 switch。

本次重构把 hazard 提炼为物品基类 `Item`，现有两类型作为子类派生，使架构清晰、便于将来新增类型。

**用户需求（本次重构边界）**：

1. hazard → 物品通用对象（`Item` 基类），可基于其派生多种类型。
2. **所有 hazard 均能和船发生碰撞**——移除「仅 FLOATER 撞船」特判；基类统一处理船碰撞，扣血值由子类提供。
3. 现有两种物品（DRIFT / FLOATER）归一到 `Item` 之下。
4. 「抵水面即沿水面漂流」是水中物品的通用物理不变量，上移到基类。
5. **伤害数值移出 `game.gd`，进到 Item 类层级**：基类有默认值（0，安全兜底），各子类用自身 `DAMAGE` 常量覆写 `_get_damage()`。

**范围（YAGNI）**：仅重构现有两类型，不新增第三种类型。但基类使新增类型 = 加一个子类脚本 + 一个场景。

## 2. 类层级、文件与场景布局

### 类层级

```
Area2D
  └─ Item          (scripts/item.gd)              共性：位移、水线钳制、越界销毁、碰撞派发、setup
      ├─ DriftItem    (scripts/items/drift_item.gd)    纯左移
      └─ FloaterItem  (scripts/items/floater_item.gd)  左移 + 上浮至水面止
```

### 文件改动

| 操作 | 文件 |
|---|---|
| 新增 | `scripts/item.gd`、`scripts/items/drift_item.gd`、`scripts/items/floater_item.gd` |
| 新增 | `scenes/drift_item.tscn`、`scenes/floater_item.tscn` |
| 改 | `autoload/game.gd`、`scripts/spawner.gd` |
| 删 | `scripts/hazard.gd`(+`hazard.gd.uid`)、`scenes/hazard.tscn` |

`scripts/items/` 子目录沿用 `scripts/anchor_states/` 约定；基类 `item.gd` 放 `scripts/` 顶层（与 `anchor.gd` 同级）。`scripts/main.gd` 无 `Hazard` 引用，不改。

### 场景结构（两子类场景各自自包含，不用 Godot 场景继承）

```
DriftItem (Area2D) ← drift_item.gd         FloaterItem (Area2D) ← floater_item.gd
├─ CollisionShape2D  (Rect 24×24)          ├─ CollisionShape2D  (Rect 24×24)
└─ Body (Polygon2D, 琥珀方块)              └─ Body (Polygon2D, 青绿三角)
```

视觉（形状 / 颜色）直接定在场景里——基类不再有 `_apply_visual()`；脚本只管行为。新增类型 = 加一个子类脚本 + 一个场景。

## 3. Item 基类接口与子类覆写

### `scripts/item.gd`（基类）

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

### `scripts/items/drift_item.gd`

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

### `scripts/items/floater_item.gd`

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

### 设计要点

- **`kind == FLOATER` 特判消失**：基类 `_on_area_entered` 对任何 `ship` 组接触都 `take_damage(_get_damage())`。所有类型都扣血，伤害值由子类 `_get_damage()` 提供。
- **伤害值在子类脚本里**：每个子类用 `const DAMAGE := <n>` 自带伤害值，覆写 `_get_damage()` 返回之。基类默认 0（裸 Item 不应被实例化，兜底用）。`game.gd` 不再持有任何伤害常量——读子类脚本即知该类型伤害。
- **`_apply_visual()` 删除**：视觉在场景里，脚本不管形状 / 颜色。
- **`enum Kind` 删除**：子类本身就是「类型」，`setup()` 只收 `pos`。
- **水线钳制通用化**：`_post_move()` 在基类实现「上浮至水面即止」；FloaterItem 不再覆写它。将来若某子类需额外后处理，覆写并先调 `super._post_move(delta)` 保留钳制。
- **YAGNI：不引入 `_get_score()`**。得分对所有类型统一 `SCORE_PER_KILL`；将来要按类型计分再加虚方法，此刻不建。

## 4. 集成改动

### `autoload/game.gd` 常量

```gdscript
# 旧
const DAMAGE_PER_HIT := 25
const HAZARD_VX_MIN := -180.0
const HAZARD_VX_MAX := -90.0

# 新（伤害移出 game.gd，进到 Item 子类；水平速度改 ITEM_ 前缀）
const ITEM_VX_MIN := -180.0
const ITEM_VX_MAX := -90.0
# SCORE_PER_KILL / FLOATER_VY_MIN/MAX / 其余不变
```

`DAMAGE_PER_HIT` 仅被 `hazard.gd`（删除）引用，安全移除且不在 game.gd 设替代——伤害改由各 Item 子类的 `DAMAGE` 常量提供（DriftItem / FloaterItem 均为 25，保持 4 击 = Game Over 的现有平衡）。`game.gd` 仍持有 `SCORE_PER_KILL`（得分统一，非按类型）与速度 / 坐标常量（CLAUDE.md：可调常量集中）。

### `scripts/spawner.gd`

```gdscript
const DRIFT_ITEM_SCENE   := preload("res://scenes/drift_item.tscn")
const FLOATER_ITEM_SCENE := preload("res://scenes/floater_item.tscn")

func _spawn_one() -> void:
    var scene: PackedScene = DRIFT_ITEM_SCENE if randf() < 0.5 else FLOATER_ITEM_SCENE
    var item: Item = scene.instantiate()   # 显式 : Item，避免 := 推断为 Node（CLAUDE.md 坑）
    add_child(item)
    var y := randf_range(Game.SPAWN_Y_MIN, Game.SPAWN_Y_MAX)
    item.setup(Vector2(Game.SPAWN_X, y))   # setup 不再收 kind

func clear_all() -> void:
    for c in get_children():
        if c is Item:                      # 基类判断，两子类都匹配
            c.queue_free()
```

`scripts/main.gd` 不改（无 `Hazard` 引用，仅调 `spawner.clear_all()`）。

## 5. 迁移与删除

| 操作 | 文件 |
|---|---|
| 删 | `scripts/hazard.gd`、`scripts/hazard.gd.uid`、`scenes/hazard.tscn` |
| 新增 | `scripts/item.gd`(+`.uid`)、`scripts/items/drift_item.gd`(+`.uid`)、`scripts/items/floater_item.gd`(+`.uid`)、`scenes/drift_item.tscn`、`scenes/floater_item.tscn` |
| 改 | `autoload/game.gd`、`scripts/spawner.gd` |

`.gd.uid` 由 Godot 首次扫描时生成；创建脚本后用 MCP `run_project` 触发扫描再纳入 git（CLAUDE.md：所有 .uid 都 tracked）。场景 UID 嵌在 `.tscn` 头部 `[gd_scene ... uid="..."]`。

## 6. 碰撞与分组（不变）

- Ship 为 `Area2D`，组 `"ship"`；Anchor Head 组 `"anchor_head"`。两者不改。
- Item **不需要**分组——它是检测方，在自身 `_on_area_entered` 里判对方组别。
- 锚击毁物品：对方在 `anchor_head` 组 → `add_score(SCORE_PER_KILL)` + `queue_free()`，锚继续飞行可穿多体。
- 物品撞船：对方在 `ship` 组 → `take_damage(_get_damage())` + `queue_free()`，撞一次销毁不连续扣。
- `area_entered` 每对只触发一次 + `queue_free()`，无重入。

## 7. 测试策略（MCP 手动 playtest）

1. **干净启动**：`run_project` → `get_debug_output` → `errors: []`（警惕 `:=` 推断坑、`_post_move` 未用参数 `_delta` 命名）。
2. **DRIFT**：深处生成、纯左移、不出顶、x<-60 销毁；够不到船。
3. **FLOATER**：深处生成、上浮至 y=180 止、随后水面左移、x<-60 销毁。
4. **水线钳制通用**：无任何物品越过 y=180（DRIFT 的 vy=0 天然跳过）。
5. **锚击毁**：锚穿过 DRIFT/FLOATER → `add_score`+自毁，锚继续飞（可穿多体）。
6. **撞船（本次变更核心）**：任何物品接触船区域 → `take_damage(_get_damage())`+自毁；架构不再 `kind==FLOATER` 特判。实测仅 FLOATER 能到达船。
7. **伤害值**：FLOATER 撞船 -25（`FloaterItem.DAMAGE`），4 次出局；`DriftItem.DAMAGE`=25 经代码核对（运行时够不到船，靠审阅）。
8. **流程**：READY/GAME_OVER `clear_all` 清空两类型；PLAYING 生成；重开正常。
9. **分组不变**：Ship 仍 `"ship"`、Anchor Head 仍 `"anchor_head"`；物品无分组。
10. **无回归**：原 spec §9 的 10 项 playtest 全过。

调试流程（CLAUDE.md）：在组件边界加 `print("[DBG] ...")`（逗号形式，非 `%` 格式）→ `run_project` → 用户复现 → `get_debug_output` 或读 godot.log。

## 8. YAGNI / 明确不做

- 不新增第三种物品类型（仅重构现有两类型）。
- 不引入 `_get_score()`（得分统一）。
- 不改锚、船、状态机、流程状态机。
- 不改视口 / 水线 / 海底坐标、生成区、速度范围（仅常量名换 `HAZARD_VX_*`→`ITEM_VX_*`，值不变；伤害常量移出 game.gd）。
- 不引入 Godot 场景继承（子类场景自包含）。
- 物品仍一击即毁（无血量）。
