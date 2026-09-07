## Global gameplay state, checkpoint state, and respawn orchestration.
extends Node

enum State {
	LOADING,    # A scene is loading — input should be ignored
	PLAYING,    # Normal gameplay — full player control
	PAUSED,     # Pause menu is open — game is frozen
	DIALOGUE,   # Player is talking to an NPC — movement locked
	INVENTORY,  # Inventory/charm screen is open
	MAP,        # World map is open
	DEAD,       # Player just died — waiting for respawn sequence
}

# ─── VARIABLES ───────────────────────────────────────────────────────────────
# The state the game is currently in
# We start in LOADING and change to PLAYING once the first scene is ready
var current_state: State = State.PLAYING

# Whether the game engine is paused
# Godot's pause system stops _process() and _physics_process() on all
# nodes UNLESS they have process_mode set to "Always"
var is_paused := false

var last_checkpoint_id := ""
var last_checkpoint_position := Vector2.ZERO
var last_checkpoint_room := ""

# ─── BUILT-IN FUNCTIONS ──────────────────────────────────────────────────────
func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS


func _unhandled_input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("pause"):
		toggle_pause()

# ─── BUILT-IN FUNCTIONS ──────────────────────────────────────────────────────
## Changes the game state and notifies all listeners via EventBus
func set_state(new_state: State) -> void:
	if current_state == new_state:
		return
	current_state = new_state
	EventBus.game_state_changed.emit(new_state)

## Returns true if the player currently has full control
func is_playing() -> bool:
	return current_state == State.PLAYING

## Freeze the game and open the pause menu
func pause_game() -> void:
	if is_paused:
		return
	is_paused = true
	get_tree().paused = true
	set_state(State.PAUSED)
	EventBus.game_paused.emit()

## Toggle between paused and playing
func unpause_game() -> void:
	if not is_paused:
		return
	is_paused = false
	get_tree().paused = false
	set_state(State.PLAYING)
	EventBus.game_unpaused.emit()


func toggle_pause() -> void:
	if is_paused:
		unpause_game()
	else:
		pause_game()


func set_checkpoint(checkpoint_id: String, position: Vector2, room_path: String = "") -> void:
	last_checkpoint_id = checkpoint_id
	last_checkpoint_position = position
	last_checkpoint_room = room_path
	print("[GameManager] Checkpoint set: ", checkpoint_id, " @ ", position)


## Call this from the health system when HP reaches zero.
func kill_player(player: Node2D) -> void:
	if current_state == State.DEAD:
		return
	set_state(State.DEAD)
	EventBus.player_died.emit()
	await get_tree().create_timer(0.6).timeout
	await respawn_player(player)


func respawn_player(player: Node2D) -> void:
	if last_checkpoint_id.is_empty():
		push_warning("[GameManager] No checkpoint set; preserving current position")
	else:
		await _load_checkpoint_room_if_needed()
		player.global_position = last_checkpoint_position

	if player.has_method("reset_after_death"):
		player.reset_after_death()

	set_state(State.PLAYING)
	EventBus.player_respawned.emit()


func _load_checkpoint_room_if_needed() -> void:
	if last_checkpoint_room.is_empty():
		return

	var game := get_tree().get_first_node_in_group(&"game")
	if game == null or not game.has_method("load_room"):
		push_warning("[GameManager] Cannot restore checkpoint room; no Game controller found")
		return

	var current_map: Node = game.map
	if current_map and current_map.scene_file_path == last_checkpoint_room:
		return

	set_state(State.LOADING)
	EventBus.room_transition_started.emit(last_checkpoint_room)
	await game.load_room(last_checkpoint_room)
	
func has_checkpoint() -> bool:
	return not last_checkpoint_id.is_empty()
