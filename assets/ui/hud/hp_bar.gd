extends CanvasLayer

@onready var health_bar = $HealthBar

# This function will be called whenever the player takes damage or heals
func update_health_bar(current_hp: int, max_hp: int):
	health_bar.max_value = max_hp
	health_bar.value = current_hp
