extends Area2D

func _ready() -> void:
	collision_mask = 0
	set_collision_mask_value(2, true)
	body_entered.connect(func(body):
		if body.is_in_group("player"):
			GameManager.kill_player(body)
	)
