## Touchable checkpoint that stores a cross-room respawn location.
extends Area2D

@export var checkpoint_id: String = ""

var _activated := false


func _ready() -> void:
	# PlayerController is assigned to physics layer 2 at runtime.
	collision_mask = 0
	set_collision_mask_value(2, true)
	body_entered.connect(_on_body_entered)
	if checkpoint_id.is_empty():
		push_warning("[Checkpoint] Missing checkpoint_id: " + str(get_path()))


func _on_body_entered(body: Node2D) -> void:
	# Guard: Only the player can trigger checkpoints
	if not body.is_in_group(&"player"):
		return

	# Always set the checkpoint when the player touches it, allowing reuse (Fix for Bug #19)
	GameManager.set_checkpoint(checkpoint_id, global_position, _get_owning_room_path())

	# Only fire the visual/audio feedback event once
	if not _activated:
		_activated = true
		EventBus.checkpoint_activated.emit(checkpoint_id)


func _get_owning_room_path() -> String:
	var node: Node = self
	while node:
		if not node.scene_file_path.is_empty():
			return node.scene_file_path
		node = node.get_parent()
	return ""
