extends Node2D
## Zone C owns only its checkpoint. The shared GameManager performs the
## existing death animation, health reset, room restore and player respawn.

@onready var player_spawn: Marker2D = $SpawnPoints/PlayerSpawn


func _ready() -> void:
	if not InputMap.has_action(&"move_up"):
		InputMap.add_action(&"move_up")
		var up_key := InputEventKey.new()
		up_key.physical_keycode = KEY_UP
		InputMap.action_add_event(&"move_up", up_key)

	# Include the room path so dying after leaving Zone C can also restore it.
	GameManager.set_checkpoint(
		"zone_c_beginning",
		player_spawn.global_position,
		scene_file_path
	)
