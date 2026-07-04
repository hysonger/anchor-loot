extends Node2D
# Root scene: assembles Ship<->Anchor, wires the HUD to Game signals,
# builds the StartButton shortcut, and updates flow text.

@onready var spawner: Spawner = $Spawner
@onready var ship: Ship = $Ship
@onready var anchor: Anchor = $Anchor
@onready var durability_bar: ProgressBar = $HUD/DurabilityBar
@onready var score_label: Label = $HUD/ScoreLabel
@onready var message_label: Label = $HUD/MessageLabel
@onready var start_button: Button = $HUD/StartButton

func _ready() -> void:
	# Wire ship <-> anchor.
	ship.anchor = anchor
	anchor.ship = ship

	# Bind HUD to Game state.
	Game.durability_changed.connect(_on_durability_changed)
	Game.score_changed.connect(_on_score_changed)
	Game.flow_changed.connect(_on_flow_changed)
	Game.game_over.connect(_on_game_over)

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
			message_label.text = "点击鼠标🖱抛锚!"
			_apply_button(true, "开始游戏 [Space]")
			spawner.clear_all()
		Game.FlowState.PLAYING:
			message_label.text = ""
			start_button.visible = false
			start_button.disabled = true
		Game.FlowState.GAME_OVER:
			message_label.text = "GAME OVER"
			_apply_button(true, "重新开始 [Space]")
			spawner.clear_all()

func _on_game_over() -> void:
	pass  # flow_changed(GAME_OVER) already handles messaging/clear.

func _apply_button(do_show: bool, text: String) -> void:
	start_button.text = text
	start_button.visible = do_show
	start_button.disabled = not do_show
