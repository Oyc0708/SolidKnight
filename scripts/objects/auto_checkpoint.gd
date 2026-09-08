## Auto-activating checkpoint — registers itself immediately when the level loads.
## This ensures that dying in this level always respawns the player here,
## not at the last manually-touched checkpoint in a different room.
extends Area2D

@export var checkpoint_id: String = ""

func _ready() -> void:
	# Still set up collision so it works as a normal checkpoint too
	collision_mask = 0
	set_collision_mask_value(2, true)
	body_entered.connect(_on_body_entered)

	if checkpoint_id.is_empty():
		push_warning("[AutoCheckpoint] Missing checkpoint_id: " + str(get_path()))
		return

	# Auto-activate on level load
	GameManager.set_checkpoint(checkpoint_id, global_position, _get_owning_room_path())
	_restore_player_health(get_tree().get_first_node_in_group(&"player"))
	EventBus.checkpoint_activated.emit(checkpoint_id)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group(&"player"):
		return
	GameManager.set_checkpoint(checkpoint_id, global_position, _get_owning_room_path())
	_restore_player_health(body)


func _get_owning_room_path() -> String:
	var node: Node = self
	while node:
		if not node.scene_file_path.is_empty():
			return node.scene_file_path
		node = node.get_parent()
	return ""

func _restore_player_health(body: Node) -> void:
	if body is PlayerController:
		body.heal(body.max_health)
