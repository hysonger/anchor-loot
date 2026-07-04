# Anchor Speed Curve — 锚发射速度平衡机制

**日期**: 2026-07-04  
**状态**: approved

## 目标

为锚的发射速度添加方向补偿：与垂直方向夹角越小，发射速度越快。模拟"重力辅助"的直觉——垂直向下发射阻力最小，水平发射最慢。

## 方案

余弦曲线（方案 B）：`speed = ANCHOR_FIRE_SPEED × [MIN_RATIO + (1 − MIN_RATIO) × cos(θ)]`

利用 `fly_direction` 已归一化的性质，直接使用 `fly_direction.y` 作为 `cos(θ)`（θ 为与垂直方向的夹角）：
- 垂直向下 `y=1` → cos=1 → 全速
- 水平 `y=0` → cos=0 → 速率 × MIN_RATIO

无需调用三角函数。

## 改动范围

### 1. `autoload/game.gd` — 调整全速 & 新增常量

`ANCHOR_FIRE_SPEED` 从 650 提升到 800。在 `ANCHOR_RETRACT_SPEED` 行之后添加：

```gdscript
const ANCHOR_FIRE_SPEED := 800.0
# Anchor speed curve: horizontal shots run at this fraction of vertical speed.
# 0.0 = motionless at horizontal, 1.0 = no compensation (all directions equal).
const ANCHOR_SPEED_MIN_RATIO := 0.4
```

### 2. `scripts/anchor_states/launched.gd` — 应用速度补偿

将 `physics_process` 中的匀速计算改为带补偿的速度计算：

```gdscript
var speed_factor := Game.ANCHOR_SPEED_MIN_RATIO + (1.0 - Game.ANCHOR_SPEED_MIN_RATIO) * anchor.fly_direction.y
var speed := Game.ANCHOR_FIRE_SPEED * speed_factor
anchor.head.global_position += anchor.fly_direction * speed * delta
```

## 验证

- 运行游戏，垂直向下点击发射锚 → 速度为 800（全速）
- 水平点击发射锚 → 速度约为 320（800 × 0.4）
- 45° 点击发射锚 → 速度约为 560（800 × 0.7）
