# save_system.gd
# ─────────────────────────────────────────────────────────────────────────────
# Handles writing game data to disk and reading it back.
# This script is a SKELETON — the full implementation is built in Phase 8.
# Right now it establishes the structure and creates the save directory.
#
# HOW TO USE FROM ANY SCRIPT (once fully implemented):
#   SaveSystem.save_game()
#   SaveSystem.load_game(0)  ← slot 0, 1, or 2
#   SaveSystem.save_exists(1)
# ─────────────────────────────────────────────────────────────────────────────
extends Node


# ─── CONSTANTS ───────────────────────────────────────────────────────────────
# "user://" is a special Godot path that maps to the OS-specific user data folder:
#   Windows: %APPDATA%/Godot/app_userdata/HKClone/
#   Mac:     ~/Library/Application Support/Godot/app_userdata/HKClone/
#   Linux:   ~/.local/share/godot/app_userdata/HKClone/
# This is the correct place to store save files — NOT inside res://
# (res:// is read-only in exported games)
const SAVE_DIR: String = "user://saves/"
const SAVE_FILE_PREFIX: String = "slot_"
const SAVE_FILE_EXTENSION: String = ".save"
const MAX_SLOTS: int = 3


# ─── VARIABLES ───────────────────────────────────────────────────────────────
# Which slot the player is currently playing on (0, 1, or 2)
var active_slot: int = 0

# The complete game data for the active slot, held in memory while playing
# This dictionary grows to include all world state, player stats, and inventory
var current_save_data: Dictionary = {}


# ─── BUILT-IN FUNCTIONS ──────────────────────────────────────────────────────
func _ready() -> void:
	# Ensure the save directory exists before we try to write to it
	# make_dir_recursive_absolute creates the full path including parent folders
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	print("[SaveSystem] Ready — save directory: ", SAVE_DIR)


# ─── PUBLIC FUNCTIONS ─────────────────────────────────────────────────────────
## Returns true if a save file exists for the given slot number
func save_exists(slot: int) -> bool:
	return FileAccess.file_exists(_get_save_path(slot))


## Save the current game data to disk (skeleton — expanded in Phase 8)
func save_game() -> void:
	print("[SaveSystem] save_game() — full implementation in Phase 8")


## Load game data from a slot into memory (skeleton — expanded in Phase 8)
## Returns true on success, false on failure
func load_game(slot: int) -> bool:
	if not save_exists(slot):
		push_warning("[SaveSystem] No save file found for slot " + str(slot))
		return false
	print("[SaveSystem] load_game() — full implementation in Phase 8")
	return false


## Delete the save file for a given slot
func delete_save(slot: int) -> void:
	var path := _get_save_path(slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
		print("[SaveSystem] Deleted save at: ", path)


# ─── PRIVATE FUNCTIONS ────────────────────────────────────────────────────────
## Returns the full file path for a given slot number
func _get_save_path(slot: int) -> String:
	return SAVE_DIR + SAVE_FILE_PREFIX + str(slot) + SAVE_FILE_EXTENSION
