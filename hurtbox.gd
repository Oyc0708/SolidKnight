# hurtbox.gd
class_name Hurtbox
extends Area2D

# We export the node that actually has the health/take_damage function.
# Usually, this is the CharacterBody2D root node (like your Player).
@export var owner_node: Node2D
@export var iframe_duration: float = 0.5

var _is_invincible: bool = false

func _ready() -> void:
	if owner_node == null:
		# Default to the parent node if nothing is assigned in the inspector
		owner_node = get_parent()

# This function is called by a Hitbox when it overlaps this Hurtbox
func take_hit(damage: int, hitbox_global_position: Vector2) -> void:
	# 1. Check local Hurtbox I-Frames (protects simple enemies)
	if _is_invincible:
		return
	
	if owner_node:
		# 2. Check if the owner has its own specialized I-Frames (like the Player)
		if owner_node.has_method("is_invincible") and owner_node.is_invincible():
			return
			
		# 3. Apply damage
		if owner_node.has_method("take_damage"):
			# Pass knockback position if the owner supports it (Player), otherwise just damage (Enemies)
			if owner_node is PlayerController:
				owner_node.take_damage(damage, hitbox_global_position)
			else:
				owner_node.take_damage(damage)
			
			_trigger_iframes()

# Starts a temporary invincibility window for this specific hurtbox
func _trigger_iframes() -> void:
	_is_invincible = true
	await get_tree().create_timer(iframe_duration).timeout
	_is_invincible = false
