class_name Hurtbox
extends Area2D

# We export the node that actually has the health/take_damage function.
# Usually, this is the CharacterBody2D root node (like your Player).
@export var owner_node: Node2D

func _ready() -> void:
	if owner_node == null:
		# Default to the parent node if nothing is assigned in the inspector
		owner_node = get_parent()

# This function is called by a Hitbox when it overlaps this Hurtbox
func take_hit(damage: int, hitbox_global_position: Vector2) -> void:
	if owner_node and owner_node.has_method("take_damage"):
		owner_node.take_damage(damage, hitbox_global_position)
