# scripts/main/game.gd
extends "res://addons/MetroidvaniaSystem/Template/Scripts/MetSysGame.gd"
class_name Game

## Which room to load when the game starts
@export_file("room_link") var starting_room: String

func _ready() -> void:
	get_script().set_meta(&"singleton", self)
	add_to_group(&"game")

	# 1. Reset & initialise the map data (ONLY ONCE per session)
	MetSys.reset_state()
	MetSys.set_save_data()

	# 2. Register the player so MetSys automatically tracks its position
	set_player($Player)
	
	# Connect health signal to HUD (Fix for Bug #14)
	if player:
		player.health_changed.connect(_on_player_health_changed)

	# 3. Add the built‑in room‑transition module
	add_module("RoomTransitions.gd")

	# Connect before loading because load_room() can complete immediately.
	room_loaded.connect(_on_room_loaded)

	# 4. Load the first room (Awaited to fix Bug #16)
	await load_room(starting_room)
	
	# After loading the starting room, move the player to the checkpoint if one exists
	if not GameManager.last_checkpoint_id.is_empty():
		player.global_position = GameManager.last_checkpoint_position
	
	#Debug Test
	print("[Game] Loaded room: ", starting_room)
	print("[Game] Current room instance: ", MetSys.get_current_room_instance())
	
func _on_room_loaded() -> void:
	EventBus.room_transition_finished.emit()

# Fix for Bug #14: Update the HUD when health changes
func _on_player_health_changed(current_hp: int, max_hp: int) -> void:
	var hud = get_node_or_null("PlayerHud/heart/HeartContainer")
	if hud and "max_hearts" in hud:
		var hearts := ceili(current_hp / float(max_hp) * hud.max_hearts)
		hud.update_heart(hearts)

## Loads a MetSys room without destroying the persistent player, HUD, or menus.
func transition_to_room(room_path: String, spawn_marker_name: String = "") -> void:
	if room_path.is_empty() or map_changing:
		return
	if not ResourceLoader.exists(room_path):
		push_error("[Game] Room not found: " + room_path)
		return

	GameManager.set_state(GameManager.State.LOADING)
	EventBus.room_transition_started.emit(room_path)
	await load_room(room_path)

	if not spawn_marker_name.is_empty():
		var spawn_marker := map.find_child(spawn_marker_name, true, false) as Marker2D
		if spawn_marker:
			player.global_position = spawn_marker.global_position
		else:
			push_warning("[Game] Spawn marker not found: " + spawn_marker_name)

	GameManager.set_state(GameManager.State.PLAYING)
