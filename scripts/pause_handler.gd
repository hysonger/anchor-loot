extends Node
# PauseHandler: detects pause triggers (Esc, window focus loss) and resume
# trigger (mouse click). Runs with PROCESS_MODE_ALWAYS so it continues to
# function while get_tree().paused = true.

var _message_label: Label = null  # injected by Main

const PAUSE_MESSAGE := "游戏暂停（点击或 Esc 继续）"


func _ready() -> void:
    process_mode = PROCESS_MODE_ALWAYS
    Game.paused.connect(_on_paused)
    Game.unpaused.connect(_on_unpaused)


func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
        if Game.is_playing() and not Game.is_paused:
            Game.set_paused(true)


func _input(event: InputEvent) -> void:
    # Esc toggles pause during gameplay / resume during pause.
    if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
        if Game.is_playing() and not Game.is_paused:
            Game.set_paused(true)
        elif Game.is_paused:
            Game.set_paused(false)
        get_viewport().set_input_as_handled()
        return

    # Resume trigger: any mouse click during pause.
    if Game.is_paused and event is InputEventMouseButton and event.pressed:
        Game.set_paused(false)
        get_viewport().set_input_as_handled()
        return


func _on_paused() -> void:
    if _message_label != null:
        _message_label.text = PAUSE_MESSAGE


func _on_unpaused() -> void:
    if _message_label != null:
        _message_label.text = ""
