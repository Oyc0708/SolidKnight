extends CanvasLayer

@export var pause_panel: Panel

func _ready() -> void:
	pause_panel.visible = false
	# Connect to GameManager signals so the panel shows/hides automatically
	EventBus.game_paused.connect(_show_panel)
	EventBus.game_unpaused.connect(_hide_panel)

func _show_panel() -> void:
	pause_panel.visible = true
	EventBus.play_sfx_requested.emit("pause_open")
	# Optional: Grab focus on the resume button for controller support here

func _hide_panel() -> void:
	pause_panel.visible = false
	EventBus.play_sfx_requested.emit("pause_close")

## Resume button pressed
func _on_resume_button_pressed() -> void:
	GameManager.unpause_game()

## Restart button pressed
func _on_restart_button_pressed() -> void:
	GameManager.unpause_game()   # ensure game is unpaused before restart
	SceneManager.reload_scene()  # or SceneManager.go_to_scene("current_level")

## Settings button pressed
func _on_settings_button_pressed() -> void:
	EventBus.play_sfx_requested.emit("button_click")
	# Open settings panel (you can instance a settings scene or emit a signal)
	EventBus.open_settings_requested.emit()

## Main Menu button pressed
func _on_main_menu_button_pressed() -> void:
	GameManager.unpause_game()   # unpause before changing scene
	get_tree().change_scene_to_file("res://scenes/menus/main_menu.tscn")
