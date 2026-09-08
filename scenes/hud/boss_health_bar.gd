extends Control

@onready var health_bar: ProgressBar = $Panel/HealthBar
@onready var boss_name: Label = $Panel/BossName

func setup_boss(boss: Boss) -> void:
	boss_name.text = "BRINGER OF DEATH"
	health_bar.max_value = boss.max_health
	health_bar.value = boss.current_health
	boss.health_changed.connect(_on_boss_health_changed)
	boss.died.connect(_on_boss_died)
	visible = true

func _on_boss_health_changed(current_health: int, max_health: int) -> void:
	health_bar.max_value = max_health
	health_bar.value = current_health

func _on_boss_died() -> void:
	visible = false

func hide_bar() -> void:
	visible = false
