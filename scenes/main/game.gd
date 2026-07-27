# scripts/main/game.gd
extends "res://addons/MetroidvaniaSystem/Template/Scripts/MetSysGame.gd"
class_name Game

## Which room to load when the game starts (must match a room name in the MetSys map)
@export_file("room_link") var starting_room: String

func _ready() -> void:
	# Make this script easily reachable from anywhere
	get_script().set_meta(&"singleton", self)

	# 1. Reset & initialise the map data (ONLY ONCE per session)
	MetSys.reset_state()
	MetSys.set_save_data()

	# 2. Register the player so MetSys automatically tracks its position
	set_player($Player)

	# 3. Add the built‑in room‑transition module
	add_module("RoomTransitions.gd")

	# 4. Load the first room
	load_room(starting_room)

	# Optional: emit your own event when a room finishes loading
	room_loaded.connect(_on_room_loaded)
	
	#Debug Test
	print("[Game] Loaded room: ", starting_room)
	print("[Game] Current room instance: ", MetSys.get_current_room_instance())
func _on_room_loaded() -> void:
	EventBus.room_transition_finished.emit()

# Helper so other scripts can find this instance
static func get_singleton() -> Game:
	return (Game as Script).get_meta(&"singleton") as Game
