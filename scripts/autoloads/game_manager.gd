# game_manager.gd
# ─────────────────────────────────────────────────────────────────────────────
# Tracks what state the game is currently in.
# Controls pausing.
# Acts as the source of truth for "what is the player allowed to do right now?"
#
# HOW TO USE FROM ANY SCRIPT:
#   GameManager.set_state(GameManager.State.PAUSED)
#   if GameManager.current_state == GameManager.State.PLAYING: ...
# ─────────────────────────────────────────────────────────────────────────────
extends Node


# ─── STATE ENUM ──────────────────────────────────────────────────────────────
# An enum is a named list of integer constants.
# GameManager.State.PLAYING is cleaner and safer than using raw numbers.
# "cleaner" = you read the name; "safer" = typos cause errors, not silent bugs
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
var is_paused: bool = false


# ─── BUILT-IN FUNCTIONS ──────────────────────────────────────────────────────
func _ready() -> void:
	print("[GameManager] Ready — state: ", State.keys()[current_state])


func _unhandled_input(event: InputEvent) -> void:
	# Listen for the pause button from anywhere in the game
	# _unhandled_input only fires if no other node consumed the event first
	if event.is_action_just_pressed("pause"):
		toggle_pause()


# ─── PUBLIC FUNCTIONS ─────────────────────────────────────────────────────────
## Changes the game state and notifies all listeners via EventBus
func set_state(new_state: State) -> void:
	if current_state == new_state:
		return  # Nothing to do — already in this state
	
	current_state = new_state
	
	# Notify the rest of the game — UI, enemies, player all listen for this
	EventBus.game_state_changed.emit(new_state)
	
	print("[GameManager] State → ", State.keys()[new_state])


## Returns true if the player currently has full control
func is_playing() -> bool:
	return current_state == State.PLAYING


## Freeze the game and open the pause menu
func pause_game() -> void:
	if is_paused:
		return  # Already paused, do nothing
	
	is_paused = true
	get_tree().paused = true  # This is Godot's built-in pause signal
							  # Stops _physics_process on all nodes by default
	set_state(State.PAUSED)
	EventBus.game_paused.emit()


## Unfreeze the game and close the pause menu
func unpause_game() -> void:
	if not is_paused:
		return  # Not paused, do nothing
	
	is_paused = false
	get_tree().paused = false
	set_state(State.PLAYING)
	EventBus.game_unpaused.emit()


## Toggle between paused and playing
func toggle_pause() -> void:
	if is_paused:
		unpause_game()
	else:
		pause_game()
