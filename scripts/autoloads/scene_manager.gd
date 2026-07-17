# scene_manager.gd
# ─────────────────────────────────────────────────────────────────────────────
# Handles all scene and room transitions.
# In Phase 7 this gets a full fade-to-black transition animation.
# Right now it's a direct scene change wrapper that prevents
# double-transitions and notifies the EventBus.
#
# HOW TO USE FROM ANY SCRIPT:
#   SceneManager.go_to_scene("res://scenes/levels/zone_01/room_01.tscn")
#   SceneManager.reload_scene()
# ─────────────────────────────────────────────────────────────────────────────
extends Node


# ─── VARIABLES ───────────────────────────────────────────────────────────────
# Guard flag — prevents calling scene change twice before the first finishes
var _is_transitioning: bool = false


# ─── BUILT-IN FUNCTIONS ──────────────────────────────────────────────────────
func _ready() -> void:
	print("[SceneManager] Ready")


# ─── PUBLIC FUNCTIONS ─────────────────────────────────────────────────────────
## Load a new scene by its full resource path
## Example: go_to_scene("res://scenes/levels/zone_01/room_01.tscn")
func go_to_scene(scene_path: String) -> void:
	if _is_transitioning:
		push_warning("[SceneManager] Transition already in progress — ignoring request")
		return
	
	if not ResourceLoader.exists(scene_path):
		push_error("[SceneManager] Scene not found: " + scene_path)
		return
	
	_is_transitioning = true
	EventBus.room_transition_started.emit(scene_path)
	
	# change_scene_to_file unloads the current scene and loads the new one
	# In Phase 7 we add a fade-out before this line and fade-in after
	get_tree().change_scene_to_file(scene_path)
	
	_is_transitioning = false
	EventBus.room_transition_finished.emit()


## Reload the scene that is currently running
## Used for: player death → respawn at last checkpoint position
func reload_scene() -> void:
	if _is_transitioning:
		return
	
	_is_transitioning = true
	get_tree().reload_current_scene()
	_is_transitioning = false
