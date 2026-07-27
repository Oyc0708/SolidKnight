extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

## Handles the "Start" button press.
func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/levels/test_level.tscn")

## Handles the "Settings" button press.
func _on_settings_pressed() -> void:
	print("Settings pressed")

## Handles the "Exit" button press.
func _on_exit_pressed() -> void:
	get_tree().quit()
