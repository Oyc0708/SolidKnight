extends Area2D


@export var damage: int = 15


func _ready() -> void:
	# Spike itself does not need a collision layer.
	collision_layer = 0

	# Player is on physics layer 2.
	collision_mask = 0
	set_collision_mask_value(2, true)

	monitoring = true

	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group(&"player"):
		return

	if body.has_method("take_damage"):
		body.take_damage(
			damage,
			global_position
		)
