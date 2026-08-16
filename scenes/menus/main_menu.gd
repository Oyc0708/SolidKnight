extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	EventBus.play_music_requested.emit("main_menu")
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

## Handles the "Start" button press.
func _on_start_pressed() -> void:
	EventBus.play_sfx_requested.emit("button_click")
	get_tree().change_scene_to_file("res://scenes/main/game.tscn")

## Handles the "Settings" button press.
func _on_settings_pressed() -> void:
	EventBus.play_sfx_requested.emit("button_click")
	print("Settings pressed")

## Handles the "Exit" button press.
func _on_exit_pressed() -> void:
	EventBus.play_sfx_requested.emit("button_click")
	await get_tree().create_timer(0.15).timeout
	get_tree().quit()
