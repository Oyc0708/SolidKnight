extends CanvasLayer
# ─────────────────────────────────────────────
# PANELS
# ─────────────────────────────────────────────
@export var pause_panel: Panel
@export var settings_panel: Panel
@export var audio_panel: Panel
@export var level_select_panel: Panel

# ─────────────────────────────────────────────
# READY
# ─────────────────────────────────────────────
func _ready() -> void:
	# Hide all panels when the scene starts
	pause_panel.visible = false
	settings_panel.visible = false
	audio_panel.visible = false
	level_select_panel.visible = false

	# Listen for pause / unpause events
	EventBus.game_paused.connect(_show_panel)
	EventBus.game_unpaused.connect(_hide_panel)

# ─────────────────────────────────────────────
# PAUSE MENU SHOW / HIDE
# ─────────────────────────────────────────────
func _show_panel() -> void:
	pause_panel.visible = true
	settings_panel.visible = false
	audio_panel.visible = false
	level_select_panel.visible = false

	EventBus.play_sfx_requested.emit("pause_open")


func _hide_panel() -> void:
	pause_panel.visible = false
	settings_panel.visible = false
	audio_panel.visible = false
	level_select_panel.visible = false

	EventBus.play_sfx_requested.emit("pause_close")

# ─────────────────────────────────────────────
# RESUME
# ─────────────────────────────────────────────
func _on_resume_button_pressed() -> void:
	EventBus.play_sfx_requested.emit("button_click")
	GameManager.unpause_game()

# ─────────────────────────────────────────────
# RESTART
# ─────────────────────────────────────────────
func _on_restart_button_pressed() -> void:
	EventBus.play_sfx_requested.emit("button_click")

	# Make sure the game is no longer paused
	GameManager.unpause_game()

	# Reload current scene
	SceneManager.reload_scene()


# ─────────────────────────────────────────────
# SETTINGS
# ─────────────────────────────────────────────
func _on_settings_button_pressed() -> void:
	EventBus.play_sfx_requested.emit("button_click")

	pause_panel.visible = false
	settings_panel.visible = true
	audio_panel.visible = false
	level_select_panel.visible = false


# ─────────────────────────────────────────────
# AUDIO SETTINGS
# ─────────────────────────────────────────────
func _on_audio_button_pressed() -> void:
	EventBus.play_sfx_requested.emit("button_click")

	settings_panel.visible = false
	audio_panel.visible = true

# ─────────────────────────────────────────────
# AUDIO → SETTINGS BACK
# ─────────────────────────────────────────────
func _on_audio_back_button_pressed() -> void:
	EventBus.play_sfx_requested.emit("button_click")

	audio_panel.visible = false
	settings_panel.visible = true

# ─────────────────────────────────────────────
# SETTINGS → PAUSE MENU BACK
# ─────────────────────────────────────────────
func _on_back_button_pressed() -> void:
	EventBus.play_sfx_requested.emit("button_click")

	settings_panel.visible = false
	audio_panel.visible = false
	level_select_panel.visible = false
	pause_panel.visible = true

# ─────────────────────────────────────────────
# LEVEL SELECT
# ────────────────────────────────────────────
func _on_level_select_button_pressed() -> void:
	EventBus.play_sfx_requested.emit("button_click")

	pause_panel.visible = false
	settings_panel.visible = false
	audio_panel.visible = false
	level_select_panel.visible = true

# ─────────────────────────────────────────────
# LEVEL SELECT → BOSS ROOM
# ─────────────────────────────────────────────
func _on_boss_room_button_pressed() -> void:
	EventBus.play_sfx_requested.emit("button_click")

	GameManager.unpause_game()
	LevelManager.load_boss_room()

# ─────────────────────────────────────────────
# LEVEL SELECT → ZONE A
# ─────────────────────────────────────────────
func _on_zone_a_button_pressed() -> void:
	EventBus.play_sfx_requested.emit("button_click")

	GameManager.unpause_game()
	LevelManager.load_zone_a()

# ─────────────────────────────────────────────
# LEVEL SELECT → ZONE B
# ─────────────────────────────────────────────
func _on_zone_b_button_pressed() -> void:
	EventBus.play_sfx_requested.emit("button_click")

	GameManager.unpause_game()
	LevelManager.load_zone_b()

# ─────────────────────────────────────────────
# LEVEL SELECT → ZONE C
# ─────────────────────────────────────────────
func _on_zone_c_button_pressed() -> void:
	EventBus.play_sfx_requested.emit("button_click")

	GameManager.unpause_game()
	LevelManager.load_zone_c()

# ─────────────────────────────────────────────
# LEVEL SELECT → PAUSE MENU BACK
# ─────────────────────────────────────────────
func _on_level_select_back_button_pressed() -> void:
	EventBus.play_sfx_requested.emit("button_click")

	level_select_panel.visible = false
	pause_panel.visible = true

# ─────────────────────────────────────────────
# MAIN MENU
# ─────────────────────────────────────────────
func _on_main_menu_button_pressed() -> void:
	EventBus.play_sfx_requested.emit("button_click")

	# Unpause before changing scene
	GameManager.unpause_game()

	# Return to main menu
	SceneManager.go_to_scene("res://scenes/menus/main_menu.tscn")

# ─────────────────────────────────────────────
# EXIT GAME
# ─────────────────────────────────────────────
func _on_exit_button_pressed() -> void:
	EventBus.play_sfx_requested.emit("button_click")

	await get_tree().create_timer(0.15).timeout

	get_tree().quit()
