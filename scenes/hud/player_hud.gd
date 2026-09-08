extends CanvasLayer

@onready var boss_health_bar = $BossHealthBar

func _ready() -> void:
	boss_health_bar.hide_bar()

func _process(_delta: float) -> void:
	if not boss_health_bar.visible:
		var bosses = get_tree().get_nodes_in_group("boss")

		if bosses.size() > 0:
			print("Boss found by HUD!")
			boss_health_bar.setup_boss(bosses[0])

func _on_pause_button_pressed() -> void:
	GameManager.toggle_pause()
