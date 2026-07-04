# 锚连击倍率机制

日期: 2026-07-04
状态: approved

## 概述

从锚射出到收回，每命中一个物品，其得分倍率依次递增（第1个 1x，第2个 2x，第3个 3x...）。当加分受到倍率加成时（> 1x），弹窗显示倍率提示。

连击计数器随锚收回（进入 IdleState）清零。

## 设计

### 涉及文件

| 文件 | 改动内容 |
|---|---|
| `scripts/anchor.gd` | 新增 `combo_count` 变量和 `register_hit()` 方法 |
| `scripts/anchor_states/idle.gd` | `enter()` 时调用 `anchor.reset_combo()` |
| `scripts/item.gd` | 命中 anchor_head 时获取 Anchorm 调用 `register_hit()`，计算最终得分，传递 multiplier |
| `autoload/game.gd` | `score_popup` 信号增加 `multiplier` 参数；`add_score()` 不变 |
| `scripts/main.gd` | 弹窗文本：`multiplier > 1` 时显示 `"+N (Mx)"` 格式 |

### 数据流

```
Item._on_area_entered(area)
  → 确认 area 在 "anchor_head" 组
  → var anchor := area.get_parent() as Anchor
  → var mult := anchor.register_hit()    // 返回当前倍率（1, 2, 3...）
  → var final_score := _get_score() * mult
  → Game.add_score(final_score)
  → Game.score_popup.emit(final_score, mult, Vector2(SHIP_X, WATERLINE_Y))
```

### Anchor 新增

```gdscript
var combo_count: int = 0

func register_hit() -> int:
    combo_count += 1
    return combo_count
```

不需要单独的 `reset_combo()` —— IdleState 直接设置 `anchor.combo_count = 0`。

### IdleState.enter() 重置

```gdscript
func enter() -> void:
    anchor.combo_count = 0   # 收回时连击清零
    anchor.head.visible = true
    anchor.chain.visible = false
    anchor._snap_head_to_hole()
```

### Game 信号

```gdscript
signal score_popup(points: int, multiplier: int, at_position: Vector2)
```

### 弹窗文本（main.gd）

- `multiplier == 1` → `"+10"` （无倍率提示，与现在一致）
- `multiplier > 1` → `"+60 (3x)"` （显示最终得分 + 倍率标记）

### 注意事项

- `area.get_parent()` 从 anchor_head 向上取父节点即为 Anchor（`Node2D`），见 `scenes/anchor.tscn` 的节点结构。
- `register_hit()` 每次调用递增并返回新值，无需额外状态管理。
- Item 基类的 `_on_area_entered` 已有 anchor_head 分支，改动集中在此分支内。
- Retracting 阶段仍然可能命中物品（锚在收回路径上掠过），连击保持有效。
