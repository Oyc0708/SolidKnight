## Area2D boundary that switches MetroidvaniaSystem rooms.
extends Area2D

@export_file("*.tscn") var target_scene: String = ""
@export var target_spawn_name: String = ""

var _triggered := false


func _ready() -> void:
	# PlayerController is assigned to physics layer 2 at runtime.
	collision_mask = 0
	set_collision_mask_value(2, true)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _triggered or target_scene.is_empty() or not body.is_in_group(&"player"):
		return

	var game := get_tree().get_first_node_in_group(&"game")
	if game == null or not game.has_method("transition_to_room"):
		push_error("[ZoneTransition] No persistent Game controller found")
		return

	_triggered = true
	GameManager.pending_spawn_marker = target_spawn_name
	await game.transition_to_room(target_scene, target_spawn_name)
