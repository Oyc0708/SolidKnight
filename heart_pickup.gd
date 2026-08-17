# heart_pickup.gd
class_name HeartPickup
extends Area2D

# 20 HP heals exactly 1 full heart in your current HUD configuration
@export var heal_amount: int = 20 

func _ready() -> void:
	# Connect the signal for when a physics body touches this area
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	# Ensure the object touching the pickup is the player
	if body is PlayerController and body.has_method("heal"):
		# Only consume the heart if the player's health is below max
		if body.current_health < body.max_health:
			body.heal(heal_amount)
			_consume()

func _consume() -> void:
	# Optional: Instantiate a small sparkle/particle effect here before freeing
	queue_free()
