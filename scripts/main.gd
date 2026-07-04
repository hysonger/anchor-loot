extends Node2D
# Root scene: assembles Ship<->Anchor, wires the HUD to Game signals,
# builds the StartButton shortcut, and updates flow text.

# Popup constants
const POPUP_SLOT_HEIGHT := 28.0
const POPUP_MAX_Y := Game.WATERLINE_Y - 140.0
const POPUP_X_JITTER := 20.0
const POPUP_TWEEN_DURATION := 0.3
const POPUP_FONT_SIZE := 18
const POPUP_LIFETIME := 2.0

@onready var spawner: Spawner = $Spawner
@onready var ship: Ship = $Ship
@onready var anchor: Anchor = $Anchor
@onready var durability_bar: ProgressBar = $HUD/DurabilityBar
@onready var score_label: Label = $HUD/ScoreLabel
@onready var message_label: Label = $HUD/MessageLabel
@onready var start_button: TextureButton = $HUD/StartButton
@onready var start_btn_label: Label = $HUD/StartButton/StartBtnLabel
@onready var tip_clean_timer = $TipCleanTimer

# Popup manager: active floating score labels, newest last (bottom of stack).
var _popup_labels: Array[Label] = []

func _ready() -> void:
	# Wire ship <-> anchor.
	ship.anchor = anchor
	anchor.ship = ship

	# Bind HUD to Game state.
	Game.durability_changed.connect(_on_durability_changed)
	Game.score_changed.connect(_on_score_changed)
	Game.flow_changed.connect(_on_flow_changed)
	Game.game_over.connect(_on_game_over)
	Game.score_popup.connect(_on_score_popup)

	# StartButton drives Game; build its Space shortcut in code.
	var sc := Shortcut.new()
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_SPACE
	sc.events.append(ev)
	start_button.shortcut = sc
	start_button.pressed.connect(Game.on_start_button_pressed)

	# Initialize HUD + flow to READY without going through a transition.
	_on_durability_changed(Game.durability, Game.max_durability)
	_on_score_changed(Game.score)
	_on_flow_changed(Game.flow_state)

func _on_durability_changed(current: int, maxv: int) -> void:
	durability_bar.max_value = maxv
	durability_bar.value = current

func _on_score_changed(s: int) -> void:
	score_label.text = "Score: %d" % s

func _on_flow_changed(state: Game.FlowState) -> void:
	match state:
		Game.FlowState.READY:
			message_label.text = ""
			_apply_button(true, "开始游戏 [Space]")
			_clear_popups()
			spawner.clear_all()
		Game.FlowState.PLAYING:
			message_label.text = "点击鼠标🖱抛锚!"
			start_button.visible = false
			start_button.disabled = true
			tip_clean_timer.call_deferred("start")
		Game.FlowState.GAME_OVER:
			message_label.text = "GAME OVER"
			_apply_button(true, "重新开始 [Space]")
			_clear_popups()
			spawner.clear_all()

func _on_game_over() -> void:
	pass  # flow_changed(GAME_OVER) already handles messaging/clear.

func _apply_button(do_show: bool, text: String) -> void:
	start_btn_label.text = text
	start_button.visible = do_show
	start_button.disabled = not do_show

func _on_timer_timeout() -> void:
	message_label.text = ""

func _on_score_popup(points: int, multiplier: int, at_position: Vector2) -> void:
	var label := Label.new()
	if multiplier > 1:
		label.text = "+%d (%dx)" % [points, multiplier]
	else:
		label.text = "+%d" % points
	label.add_theme_font_size_override("font_size", POPUP_FONT_SIZE)
	label.add_theme_color_override("font_color", Color.GOLD)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = at_position + Vector2(randf_range(-POPUP_X_JITTER, POPUP_X_JITTER), 0.0)
	add_child(label)
	_popup_labels.append(label)
	_slide_popups()
	_prune_popups()
	# Time-based fade: if this label hasn't been pruned by height after
	# POPUP_LIFETIME seconds, fade it out anyway.
	get_tree().create_timer(POPUP_LIFETIME).timeout.connect(_on_popup_timeout.bind(label))

func _on_popup_timeout(lbl: Label) -> void:
	if not is_instance_valid(lbl):
		return
	var idx := _popup_labels.find(lbl)
	if idx == -1:
		return  # already pruned by height
	_popup_labels.remove_at(idx)
	var tween := create_tween()
	tween.tween_property(lbl, "modulate:a", 0.0, POPUP_TWEEN_DURATION).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(lbl.queue_free)
	_slide_popups()

func _slide_popups() -> void:
	for i in range(_popup_labels.size()):
		var lbl: Label = _popup_labels[i]
		var slot_index := _popup_labels.size() - 1 - i
		var target_y := Game.WATERLINE_Y - slot_index * POPUP_SLOT_HEIGHT
		var tween := create_tween()
		tween.tween_property(lbl, "position:y", target_y, POPUP_TWEEN_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _prune_popups() -> void:
	for i in range(_popup_labels.size() - 1, -1, -1):
		var lbl: Label = _popup_labels[i]
		if lbl.position.y <= POPUP_MAX_Y:
			var tween := create_tween()
			tween.tween_property(lbl, "modulate:a", 0.0, POPUP_TWEEN_DURATION).set_trans(Tween.TRANS_QUAD)
			tween.tween_callback(lbl.queue_free)
			_popup_labels.remove_at(i)

func _clear_popups() -> void:
	for lbl in _popup_labels:
		if is_instance_valid(lbl):
			lbl.queue_free()
	_popup_labels.clear()
