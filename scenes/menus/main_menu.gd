extends CanvasLayer

@export var main_menu_panel: Panel
@export var settings_panel: Panel
@export var audio_panel: Panel

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	EventBus.play_music_requested.emit("main_menu")
	main_menu_panel.visible = true
	settings_panel.visible = false
	audio_panel.visible = false
	
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
	settings_panel.visible = true

## Handles the "Exit" button press.
func _on_exit_pressed() -> void:
	EventBus.play_sfx_requested.emit("button_click")
	await get_tree().create_timer(0.15).timeout
	get_tree().quit()


## Handles the "Back" button press.
func _on_back_pressed() -> void:
	EventBus.play_sfx_requested.emit("button_click")
	settings_panel.visible = false
	main_menu_panel.visible = true

func _on_audio_button_pressed() -> void:
	EventBus.play_sfx_requested.emit("button_click")
	settings_panel.visible = false
	audio_panel.visible = true

func _on_audio_back_button_pressed() -> void:
	EventBus.play_sfx_requested.emit("button_click")
	audio_panel.visible = false
	settings_panel.visible = true

func _test_level_manager() -> void:
	LevelManager.load_zone_a()
