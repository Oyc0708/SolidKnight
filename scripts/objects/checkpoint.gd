## Touchable checkpoint that stores a cross-room respawn location.
extends Area2D

@export var checkpoint_id: String = ""

var _activated := false
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	# PlayerController is assigned to physics layer 2 at runtime.
	collision_mask = 0
	set_collision_mask_value(2, true)
	body_entered.connect(_on_body_entered)
	if checkpoint_id.is_empty():
		push_warning("[Checkpoint] Missing checkpoint_id: " + str(get_path()))
	if animated_sprite:
		animated_sprite.play("not_activated")



func _on_body_entered(body: Node2D) -> void:
	# Guard: Only the player can trigger checkpoints
	if not body.is_in_group(&"player"):
		return

	# Always set the checkpoint when the player touches it, allowing reuse
	GameManager.set_checkpoint(checkpoint_id, global_position, _get_owning_room_path())
	_restore_player_health(body)

	# Only fire the visual/audio feedback event once
	if not _activated:
		_activated = true
		EventBus.checkpoint_activated.emit(checkpoint_id)
		# Play checkpoint activation sound (make sure the SFX file exists)
		EventBus.play_sfx_requested.emit("checkpoint_activated")
		
		# Play the transition animation, then switch to idle
		if animated_sprite:
			animated_sprite.play("transition")
			# Wait for the transition to finish, then go to idle
			if not animated_sprite.animation_finished.is_connected(_on_transition_finished):
				animated_sprite.animation_finished.connect(_on_transition_finished)
				
func _on_transition_finished() -> void:
	if animated_sprite.animation == "transition":
		animated_sprite.play("idle")
		# Disconnect after use to avoid repeated calls
		if animated_sprite.animation_finished.is_connected(_on_transition_finished):
			animated_sprite.animation_finished.disconnect(_on_transition_finished)

func _get_owning_room_path() -> String:
	var node: Node = get_parent()
	while node:
		if not node.scene_file_path.is_empty():
			return node.scene_file_path
		node = node.get_parent()
	return ""

func _restore_player_health(body: Node2D) -> void:
	if body is PlayerController:
		body.heal(body.max_health)
