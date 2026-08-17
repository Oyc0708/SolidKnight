class_name Hitbox
extends Area2D

@export var damage: int = 10

func _on_area_entered(area: Area2D) -> void:
	# Check if the area we just touched is a Hurtbox
	if area is Hurtbox:
		# Tell the Hurtbox to take damage, passing our position for knockback calculations
		area.take_hit(damage, global_position)
