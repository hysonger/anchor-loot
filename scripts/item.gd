class_name Item
extends Area2D
# 水中物品基类。共性：位移 + 水线钳制 + 越界销毁 + 碰撞派发 + setup。
# 子类覆写虚方法：_init_velocity() / _get_damage()（必要时也可覆写 _post_move）。
# 伤害默认 0（安全兜底，裸 Item 不应被实例化）；子类用 DAMAGE 常量覆写 _get_damage()。

var velocity: Vector2 = Vector2.ZERO
var _spawn_protection: float = 0.0

func _ready() -> void:
	area_entered.connect(_on_area_entered)

func setup(pos: Vector2) -> void:
	global_position = pos
	velocity = _init_velocity()
	_spawn_protection = Game.SPAWN_PROTECTION_TIME

func _physics_process(delta: float) -> void:
	global_position += velocity * delta
	_post_move(delta)
	if _spawn_protection > 0.0:
		_spawn_protection = max(0.0, _spawn_protection - delta)
	if global_position.x < -60.0:
		queue_free()

# ---- 虚钩子 ----
func _init_velocity() -> Vector2:        return Vector2.ZERO   # 默认不动

func _post_move(_delta: float) -> void:
	# 通用物理不变量：任何上浮物品抵水面即止，随后沿水面漂流。
	# vy<0 才触发；vy=0 天然跳过。
	if velocity.y < 0.0 and global_position.y <= Game.WATERLINE_Y:
		global_position.y = Game.WATERLINE_Y
		velocity.y = 0.0

func _get_damage() -> int:               return 0              # 默认无伤害（子类覆写）

func _get_score() -> int:                return 0              # 默认无得分（子类覆写）

func _on_killed() -> void:               pass                  # 被锚击毁钩子（子类覆写）

func _on_area_entered(area: Area2D) -> void:
	if _spawn_protection > 0.0:
		return
	if area.is_in_group("anchor_head"):
		Game.add_score(_get_score())
		Game.score_popup.emit(_get_score(), Vector2(Game.SHIP_X, Game.WATERLINE_Y))
		_on_killed()
		queue_free()
	elif area.is_in_group("ship"):
		Game.take_damage(_get_damage())
		queue_free()
