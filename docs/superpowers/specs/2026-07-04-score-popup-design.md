# 得分浮动提示（Score Popup）

## 概述

当玩家命中物品获得分数时，在船旁出现类似 "+30" 的浮动文字提示。多个提示向上堆叠卷动，到达高度上限后淡出销毁。

## 行为规格

### 显示与卷动

- 新得分提示出现在船锚孔附近（`SHIP_X + 随机偏移 ±20`, `WATERLINE_Y`）
- 已有提示同时向上卷动一个槽位（28px），由 Tween 0.3s 平滑过渡
- 提示超过高度上限（`WATERLINE_Y - 140`）后：淡出（alpha → 0，0.3s），然后 queue_free
- 每个提示最多存活 4 条槽位（底部 → 顶部 = 4 × 28 = 112px + 淡出区）

### 视觉效果

- 字体大小 18px，金色/黄色（Color.GOLD 或接近色）
- 文字格式：`+N`（如 +10、+40、+500）
- 不引入新场景文件，纯代码创建 Label + Tween

### 连续得分

- 快速连续得分（如一发锚击中两个物品）各自产生独立提示，自然堆叠
- 随机 x 偏移避免完全重叠

## 技术方案

### 信号流向

```
Item._on_area_entered 命中 anchor_head
  → Game.add_score(n)          // 现有逻辑
  → Game.score_popup(n, pos)   // 新增信号

Main._on_score_popup(n, pos)
  → 创建 Label，管理堆叠
```

### 改动文件

1. **`autoload/game.gd`** — 新增 `signal score_popup(points: int, at_position: Vector2)`
2. **`scripts/item.gd`** — 在 `_on_area_entered` 命中 anchor_head 分支中，`add_score` 之后 emit `Game.score_popup`
3. **`scripts/main.gd`** — 新增 ScorePopupManager 逻辑：连接信号，维护活跃 Label 列表，处理创建/卷动/销毁

### 参数常量

| 参数 | 值 | 说明 |
|------|-----|------|
| `POPUP_START_POS` | `Vector2(Game.SHIP_X, Game.WATERLINE_Y)` | 基准起始位置 |
| `POPUP_SLOT_HEIGHT` | 28 | 每次卷动像素 |
| `POPUP_MAX_HEIGHT` | `Game.WATERLINE_Y - 140` | 高度上限 |
| `POPUP_X_JITTER` | 20 | x 随机偏移范围 |
| `POPUP_TWEEN_DURATION` | 0.3 | 动画时长（秒） |
| `POPUP_FONT_SIZE` | 18 | 字体大小 |
