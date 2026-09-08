extends AnimatedSprite2D

@onready var slash: AnimatedSprite2D = $"../Slash"

func play_attack() -> void:
	play("attack_01")
	slash.play("slash")
