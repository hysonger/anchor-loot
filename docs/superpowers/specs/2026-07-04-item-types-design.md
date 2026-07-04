# Anchor Game — 物品类型细化设计

- **日期**: 2026-07-04
- **引擎**: Godot 4.6（GL Compatibility，通过 MCP server 使用）
- **项目目录**: `/Users/songer/ownCloud/Projects/anchor-game`
- **状态**: 设计已确认，待写实现计划
- **关系**: 取代 `2026-07-04-item-refactor-design.md` §2–§4 的类层级与 spawner 设计；基础 `Item` 架构保留，子类全部替换

## 1. 动机与目标

当前 `Item` 基类下仅有 `DriftItem`（纯左移）和 `FloaterItem`（左移+上浮）两种类型。本次设计将物品体系细化为 5 种类型，每种有独立的行为逻辑、视觉标识和分值：

| # | 类型 | 运动特征 | 撞船 | 得分 | 出现方式 |
|---|------|---------|------|------|---------|
| 1 | **JunkItem**（垃圾） | 左移 + 上浮至水面止 | 扣耐久 | 10 | Spawner 25% |
| 2 | **NormalFishItem**（普通鱼） | 左移 + 垂直正弦摆动 | 扣耐久 | 20 | Spawner 30% |
| 3 | **AggressiveFishItem**（攻击性鱼） | 同普通鱼 + 近船触发冲撞 | 扣耐久 | 40 | Spawner 20% |
| 4 | **ChestItem**（箱子） | 纯左移 | 扣耐久 | 10 | Spawner 25% |
| 5 | **TreasureItem**（宝藏） | 缓慢向下坠落至海底销毁 | 否（兜底 0） | 50/100 | 仅箱子掉落 |

所有类型暂用几何体（Polygon2D）实现视觉，颜色/形状区别明显，后续替换为 Sprite2D + 贴图/动画即可。

**现有 DriftItem / FloaterItem 完全移除**，由新 5 类型取代。

## 2. 类层级

延续当前 `Item` 基类 + 子类覆写的模式（方案 A）：

```
Area2D
  └─ Item                    (scripts/item.gd)
      ├─ JunkItem            (scripts/items/junk_item.gd)
      ├─ NormalFishItem      (scripts/items/normal_fish_item.gd)
      │   └─ AggressiveFishItem  (scripts/items/aggressive_fish_item.gd)
      ├─ ChestItem           (scripts/items/chest_item.gd)
      └─ TreasureItem        (scripts/items/treasure_item.gd)
```

`AggressiveFishItem` 继承 `NormalFishItem` —— 两者共享摆动逻辑，仅在触发攻击后行为分化。

### 基类 Item 改动

当前 `_on_area_entered` 硬编码 `Game.add_score(Game.SCORE_PER_KILL)`。移除该常量，新增 `_get_score()` 虚方法和 `_on_killed()` 虚钩子：

```gdscript
# item.gd — _on_area_entered 中
if area.is_in_group("anchor_head"):
    Game.add_score(_get_score())
    _on_killed()          # 新增：子类可在被击毁时执行额外行为
    queue_free()
elif area.is_in_group("ship"):
    Game.take_damage(_get_damage())
    queue_free()

# 新增虚方法
func _get_score() -> int:   return 0   # 子类覆写
func _on_killed() -> void:  pass       # 子类覆写（如 ChestItem 生成掉落物）
```

其余不变：`velocity`、`setup()`、`_physics_process`、`_post_move`（水线钳制）、`_get_damage()` 全部保留。

### `SCORE_PER_KILL` 移除

从 `game.gd` 移除 `SCORE_PER_KILL` —— 每个子类自带分值。`Damage` 常量已在 item-refactor 中移出 game.gd，本次不动。

## 3. 各类型详细设计

### 3.1 JunkItem（垃圾）

**继承**: `Item`

**视觉**: 暗灰色方块 `Color(0.35, 0.35, 0.35, 1)`，`Rect 24×24`

**运动**: 左移 + 上浮至水面即止（复用基类 `_post_move` 水线钳制）

**碰撞**:
- 碰 `ship` 组 → `take_damage(DAMAGE)` + `queue_free()`
- 碰 `anchor_head` 组 → `add_score(10)` + `queue_free()`

**常量**: `DAMAGE := 25`，`SCORE := 10`

**速度**: 水平 `Game.JUNK_VX_MIN..MAX`，垂直 `Game.JUNK_VY_MIN..MAX`

### 3.2 NormalFishItem（普通鱼）

**继承**: `Item`

**视觉**: 蓝色菱形 `Color(0.3, 0.5, 0.9, 1)`，钻石形 polygon，约 22×30

**运动**: 水平左移 + 垂直正弦摆动。摆动以 `setup()` 时的 `y` 坐标为基准：

```gdscript
var _spawn_y: float
var _swing_time: float

func _init_velocity() -> Vector2:
    _spawn_y = global_position.y
    _swing_time = randf_range(0.0, TAU)  # 随机相位，避免鱼群同步
    return Vector2(randf_range(Game.FISH_VX_MIN, Game.FISH_VX_MAX), 0.0)

func _post_move(delta: float) -> void:
    super._post_move(delta)  # 水线钳制
    _swing_time += delta
    global_position.y = _spawn_y + sin(_swing_time * Game.FISH_SWING_FREQ) * Game.FISH_SWING_AMP
```

**碰撞**:
- 碰 `ship` 组 → `take_damage(DAMAGE)` + `queue_free()`
- 碰 `anchor_head` 组 → `add_score(20)` + `queue_free()`

**常量**: `DAMAGE := 25`，`SCORE := 20`

### 3.3 AggressiveFishItem（攻击性鱼）

**继承**: `NormalFishItem`

**视觉**: 红色菱形 `Color(0.9, 0.2, 0.2, 1)`，形状同 NormalFishItem，颜色明确区分

**攻击状态机**（3 态）：

```
PATROL ──[距船 ≤ DETECT_DIST]──▶ WINDUP ──[0.5s 计时到]──▶ CHARGE
  ↑                                                           │
  └────────────────────[撞船自毁 / 越界]──────────────────────┘
```

| 状态 | 行为 |
|------|------|
| `PATROL` | 与 NormalFishItem 完全一致：水平左移 + 正弦摆动。每帧检测与船距离 |
| `WINDUP` | 停止摆动，每帧更新朝向对准船（船在移动）；`AGGRO_WINDUP_TIME`（0.5s）后进入 CHARGE |
| `CHARGE` | 锁定方向，以 `AGGRO_CHARGE_SPEED` 直线冲撞；撞到船 → `take_damage` + 自毁 |

**船位置获取**: 用 `Game.SHIP_X`（船水平固定）+ `Game.WATERLINE_Y` 近似船锚孔位置。AggressiveFish 无需持有 ship 引用。

**冲撞速度**: `AGGRO_CHARGE_SPEED`（标量），方向为 WINDUP 结束时归一化的 `dir_to_ship`。水平分量天然较大（船在左侧远处），垂直分量视鱼与船高度差决定。

**碰撞**:
- 碰 `ship` 组 → `take_damage(DAMAGE)` + `queue_free()`
- 碰 `anchor_head` 组 → `add_score(40)` + `queue_free()`

**常量**: `DAMAGE := 35`（攻击性鱼撞击伤害更高），`SCORE := 40`

### 3.4 ChestItem（箱子）

**继承**: `Item`

**视觉**: 棕色六边形 `Color(0.55, 0.35, 0.1, 1)`，约 26×26

**运动**: 纯左移（`vy = 0`，水线钳制天然不触发）

**碰撞**:
- 碰 `ship` 组 → `take_damage(DAMAGE)` + `queue_free()`（撞船不生成掉落）
- 碰 `anchor_head` 组 → `add_score(10)` + `_on_killed()` + `queue_free()`

**_on_killed()**: 覆写基类钩子，在原地生成随机掉落物：

```gdscript
func _on_killed() -> void:
    var scene := _pick_loot_scene()
    var item: Item = scene.instantiate()
    get_parent().add_child(item)
    item.setup(global_position)
```

**箱子掉落**: 击毁时原地生成**1 个**随机物品。掉落表权重按分数反推（`1/score`）：

```gdscript
const LOOT_TABLE := [
    {"scene": preload("...junk_item.tscn"),             "weight": 0.100},  # 48.8%
    {"scene": preload("...normal_fish_item.tscn"),      "weight": 0.050},  # 24.4%
    {"scene": preload("...aggressive_fish_item.tscn"),  "weight": 0.025},  # 12.2%
    {"scene": preload("...treasure_item_small.tscn"),   "weight": 0.020},  #  9.8%
    {"scene": preload("...treasure_item_large.tscn"),   "weight": 0.010},  #  4.9%
    # 权重和 = 0.205；按归一化后的概率选取
]
```

掉落物以 `global_position` 生成，加入父节点（Spawner）——与生成物同级。

**常量**: `DAMAGE := 25`，`SCORE := 10`

### 3.5 TreasureItem（宝藏）

**继承**: `Item`

**视觉**: 金色钻石形 `Color(1.0, 0.85, 0.1, 1)`（小）/ `Color(1.0, 0.75, 0.05, 1)`（大），后续替换贴图

**出现**: 仅从 ChestItem 击毁时生成，不在 Spawner 中直接生成

**运动**: 无水平速度（`vx = 0`），缓慢向下坠落（`vy > 0`）。到达海底（`y >= Game.SEABED_Y`）即 `queue_free()`。覆写 `_post_move` 检查海底：

```gdscript
func _post_move(_delta: float) -> void:
    super._post_move(_delta)
    if global_position.y >= Game.SEABED_Y:
        queue_free()
```

基类 `Item._physics_process` 仍检查 `x < -60` 越界销毁，对宝藏也适用（极端情况兜底）。

**大小区分**: 用 `@export var treasure_size: Size` 区分，两个独立场景（`treasure_item_small.tscn` / `treasure_item_large.tscn`）各自设置值

| 大小 | 坠落速度 | 得分 |
|------|---------|------|
| SMALL | `TREASURE_FALL_SPEED_SMALL` | 50 |
| LARGE | `TREASURE_FALL_SPEED_LARGE` | 100 |

**碰撞**:
- 碰 `ship` 组 → `take_damage(0)` + `queue_free()`（安全兜底；宝藏从水中向下坠落，物理上不会碰到水面上的船）
- 碰 `anchor_head` 组 → `add_score(50 或 100)` + `queue_free()`

**常量**: `DAMAGE := 0`，`SCORE` 由 `treasure_size` 决定

## 4. Game 常量整理

`autoload/game.gd` 中的配置常量：

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
const FISH_SWING_AMP  := 35.0    # 垂直摆动幅度（px）
const FISH_SWING_FREQ := 2.5     # 摆动角频率（rad/s）

# ---- 攻击性鱼（AggressiveFish）----
const AGGRO_DETECT_DIST   := 576.0   # 检测船体距离（≈半屏宽）
const AGGRO_WINDUP_TIME   := 0.5     # 转向后冲撞前停顿（秒）
const AGGRO_CHARGE_SPEED  := 380.0   # 冲撞速度（标量，快于巡逻 VX_MAX=80）

# ---- 宝藏（TreasureItem）----
const TREASURE_FALL_SPEED_SMALL := 60.0
const TREASURE_FALL_SPEED_LARGE := 100.0

# ---- 移除 ----
# SCORE_PER_KILL（各子类 _get_score() 自提供）
# ITEM_VX_MIN / ITEM_VX_MAX / FLOATER_VY_MIN / FLOATER_VY_MAX（改为 JUNK_VX_*/JUNK_VY_*）
```

所有数值均可后续微调。

## 5. Spawner 生成

`scripts/spawner.gd` — 4 种物品按权重随机生成（TreasureItem 不直接生成）：

```gdscript
const SPAWN_TABLE: Array[Dictionary] = [
    {"scene": preload("res://scenes/junk_item.tscn"),             "weight": 0.25},
    {"scene": preload("res://scenes/normal_fish_item.tscn"),      "weight": 0.30},
    {"scene": preload("res://scenes/aggressive_fish_item.tscn"),  "weight": 0.20},
    {"scene": preload("res://scenes/chest_item.tscn"),            "weight": 0.25},
]

func _pick_spawn_scene() -> PackedScene:
    var roll := randf()
    var acc := 0.0
    for entry in SPAWN_TABLE:
        acc += entry.weight
        if roll <= acc:
            return entry.scene
    return SPAWN_TABLE[-1].scene
```

`_spawn_one()` 调用 `_pick_spawn_scene()` 而非硬编码 50/50。`clear_all()` 沿用 `is Item` 基类匹配。

## 6. 场景文件与视觉

每个子类一个 `.tscn`，使用 Polygon2D 作为身体几何体，颜色/形状定在场景中：

| 场景文件 | Body 形状 | 颜色 | 尺寸（约） |
|---------|----------|------|-----------|
| `junk_item.tscn` | 方块 | `(0.35, 0.35, 0.35)` 暗灰 | 24×24 |
| `normal_fish_item.tscn` | 钻石形 | `(0.3, 0.5, 0.9)` 蓝 | 22×30 |
| `aggressive_fish_item.tscn` | 钻石形 | `(0.9, 0.2, 0.2)` 红 | 22×30 |
| `chest_item.tscn` | 六边形 | `(0.55, 0.35, 0.1)` 棕 | 26×26 |
| `treasure_item_small.tscn` | 小钻石 | `(1.0, 0.85, 0.1)` 金 | 12×16 |
| `treasure_item_large.tscn` | 大钻石 | `(1.0, 0.75, 0.05)` 金 | 20×28 |

### 替换贴图路径

后续替换为 Sprite2D + 贴图：只需在场景中将 `Body (Polygon2D)` 替换为 `Sprite2D`（或 `AnimatedSprite2D`），设置 `texture`，脚本无需改动——脚本只管行为，不管视觉。

## 7. 碰撞行为总结

| 类型 | 碰船 | 碰锚头 | ship 组响应 | anchor_head 组响应 |
|------|------|--------|------------|-------------------|
| JunkItem | 扣耐久 + 自毁 | 加分 + 自毁 | `take_damage(DAMAGE)` | `add_score(10)` |
| NormalFishItem | 扣耐久 + 自毁 | 加分 + 自毁 | `take_damage(DAMAGE)` | `add_score(20)` |
| AggressiveFishItem | 扣耐久 + 自毁 | 加分 + 自毁 | `take_damage(DAMAGE)` | `add_score(40)` |
| ChestItem | 扣耐久 + 自毁 | 加分 + 掉落 + 自毁 | `take_damage(DAMAGE)` | `add_score(10)` → `_on_killed()` |
| TreasureItem | 自毁（扣 0） | 加分 + 自毁 | `take_damage(0)` + `queue_free()` | `add_score(50\|100)` |

所有类型的 `_on_area_entered` 均由基类 `Item` 处理——`queue_free()` 在基类中统一调用。ChestItem 覆写 `_on_killed()` 在 `anchor_head` 分支中生成掉落物。AggressiveFishItem 的 CHARGE 态撞船由基类 `_on_area_entered` 走 `ship` 分支处理，自毁即停止。

碰撞分组不变：Ship 保持 `"ship"` 组，Anchor Head 保持 `"anchor_head"` 组。Item 仍为检测方，不设组。

## 8. 文件改动清单

| 操作 | 文件 |
|------|------|
| 改 | `scripts/item.gd` — 新增 `_get_score()`、`_on_killed()` 虚方法，`_on_area_entered` 改用 `_get_score()` |
| 新增 | `scripts/items/junk_item.gd`、`scripts/items/normal_fish_item.gd`、`scripts/items/aggressive_fish_item.gd`、`scripts/items/chest_item.gd`、`scripts/items/treasure_item.gd` |
| 新增 | `scenes/junk_item.tscn`、`scenes/normal_fish_item.tscn`、`scenes/aggressive_fish_item.tscn`、`scenes/chest_item.tscn`、`scenes/treasure_item_small.tscn`、`scenes/treasure_item_large.tscn` |
| 删 | `scripts/items/drift_item.gd`（+`.uid`）、`scripts/items/floater_item.gd`（+`.uid`） |
| 删 | `scenes/drift_item.tscn`、`scenes/floater_item.tscn` |
| 改 | `scripts/spawner.gd` — 4 项 SPAWN_TABLE + 权重选择 |
| 改 | `autoload/game.gd` — 新增 §4 常量，移除 `SCORE_PER_KILL`/`ITEM_VX_*`/`FLOATER_VY_*` |

`scripts/main.gd` 不改（无 `DriftItem`/`FloaterItem` 引用，仅调 `spawner.clear_all()`）。

## 9. YAGNI / 明确不做

- 不新增音效、粒子（纯几何原型）
- 不引入 `_get_score()` 和 `_on_killed()` 之外的更多虚方法（`_get_damage()` 已存在）
- 不改锚、船、状态机、流程状态机
- 不改视口/水线/海底/生成区坐标
- 物品仍一击即毁（无血量）
- 不引入 Godot 场景继承（子类场景自包含）
- 不引入持久化最高分 / 难度递增
- 宝藏不掉落到海底（`y >= SEABED_Y`）之外不额外处理

## 10. 测试策略（MCP 手动 playtest）

1. **干净启动**: `run_project` → `get_debug_output` → `errors: []`
2. **JunkItem**: 深处生成、上浮至 y=180 止、水面漂流、撞船 -25、锚击 +10
3. **NormalFishItem**: 生成后垂直摆动、不越界、撞船 -25、锚击 +20
4. **AggressiveFishItem — PATROL**: 摆动行为与普通鱼一致，仅颜色不同
5. **AggressiveFishItem — 攻击**: 当鱼进入距船 ~576px 范围 → 转向朝向船 → 停顿约 0.5s → 直线冲撞 → 撞船 -35 + 自毁
6. **ChestItem**: 纯左移、撞船 -25、锚击毁 +10、原地生成随机掉落物
7. **ChestItem — 掉落**: 多次击毁箱子，确认掉落物分布符合概率表（垃圾常见，大宝藏稀有）
8. **TreasureItem**: 从箱子掉落点生成、缓慢向下坠落、无水平运动、落至海底销毁、锚击 +50/100
9. **碰撞分组**: 所有物品碰 ship 扣耐久自毁、碰 anchor_head 加分自毁，无重入
10. **流程**: READY 无生成 → PLAYING 4 种生成 → GAME_OVER `clear_all` 清空 → 重开正常
11. **基类虚方法**: `_get_score()` 每种返回正确分值；`_get_damage()` TreasureItem 返回 0 兜底
