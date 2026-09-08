extends CanvasLayer

@onready var boss_health_bar = $BossHealthBar

var current_boss: Boss = null


func _ready() -> void:
	boss_health_bar.hide_bar()


func _process(_delta: float) -> void:
	# Boss already connected
	if is_instance_valid(current_boss):
		return

	# Boss no longer exists → hide bar
	current_boss = null
	boss_health_bar.hide_bar()

	# Look for a boss in the current room
	var bosses = get_tree().get_nodes_in_group("boss")

	if bosses.size() > 0:
		current_boss = bosses[0] as Boss
		boss_health_bar.setup_boss(current_boss)


func _on_pause_button_pressed() -> void:
	GameManager.toggle_pause()
