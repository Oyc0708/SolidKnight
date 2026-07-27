extends CanvasLayer

@export var pause_panel: Panel

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

## Handles keyboard input events.
## Toggles pause state when the ESC key is pressed.
func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.keycode == KEY_ESCAPE and event.pressed:
			if not get_tree().paused:
				_on_pause_button_pressed()
			else:
				_on_resume_button_pressed()

## Pause button pressed.
## Freezes the game and shows the pause panel.
func _on_pause_button_pressed() -> void:
	get_tree().paused = true
	pause_panel.visible = true

## Resume button pressed.
## Unfreezes the game and hides the pause panel.
func _on_resume_button_pressed() -> void:
	get_tree().paused = false
	pause_panel.visible = false

## Restart button pressed
func _on_restart_button_pressed() -> void:
	pass # Replace with function body.

## Settings button pressed.
func _on_settings_button_pressed() -> void:
	pass # Replace with function body.

## Main Menu button pressed.
## Returns to the main menu and ensures the game is unpaused.
func _on_main_menu_button_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/menus/main_menu.tscn")
