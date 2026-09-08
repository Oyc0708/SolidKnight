# boss.gd
# ─────────────────────────────────────────────────────────────────────────────
# Boss root. Uses StateMachine to handle Actions
# ─────────────────────────────────────────────────────────────────────────────
extends CharacterBody2D
class_name Boss

signal health_changed(current_health: int, max_health: int)
signal died()

@export var max_health: int = 500
@export var move_speed: float = 80.0
#@export var attack_range: float = 60.0
@export var phase_2_threshold: float = 0.5  # fraction of max_health remaining

@onready var visuals: Node2D = $Visuals
@onready var animated_sprite: AnimatedSprite2D = $Visuals/AnimatedSprite2D
@onready var state_machine: BossStateMachine = $StateMachine
@onready var detection_area: Area2D = $DetectionArea
@onready var attack_range_area: Area2D = $Visuals/AttackRangeArea
@onready var attack_range_collision: CollisionShape2D = $Visuals/AttackRangeArea/CollisionShape2D

var _is_flashing: bool = false
var _original_modulate: Color = Color.WHITE

var current_health: int
var phase: int = 1
var player_ref: Node2D = null
var player_in_attack_range: bool = false


func _ready() -> void:
	add_to_group("boss")
	print("BOSS READY: ", self)
	print("BOSS GROUPS: ", get_groups())
	current_health = max_health
	detection_area.body_entered.connect(_on_detection_entered)
	detection_area.body_exited.connect(_on_detection_exited)
	attack_range_area.body_entered.connect(_on_attack_range_entered)
	attack_range_area.body_exited.connect(_on_attack_range_exited)
	


func _on_detection_entered(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		player_ref = body


func _on_detection_exited(body: Node2D) -> void:
	if body == player_ref:
		player_ref = null


func _on_attack_range_entered(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		player_in_attack_range = true


func _on_attack_range_exited(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		player_in_attack_range = false


## Called by whatever deals damage to the boss (player attack hitbox, etc.)
func take_damage(amount: int) -> void:
	_flash_hurt()
	if state_machine.current_state and state_machine.current_state.name == "DeathState":
		return

	current_health = max(current_health - amount, 0)
	health_changed.emit(current_health, max_health)

	if current_health <= 0:
		died.emit()
		state_machine.transition_to(^"DeathState")
		return

	if phase == 1 and float(current_health) / max_health <= phase_2_threshold:
		phase = 2
		state_machine.transition_to(^"PhaseTransitionState")
		
func _flash_hurt() -> void:
	if _is_flashing:
		return

	_is_flashing = true
	_original_modulate = visuals.modulate

	# Flash to bright white instantly
	visuals.modulate = Color(10.0, 10.0, 10.0, 1.0)

	# Tween back to the original modulate over 0.1 seconds
	var tween := create_tween()
	tween.tween_property(visuals, "modulate", _original_modulate, 0.1)
	tween.finished.connect(func() -> void:
		_is_flashing = false
		visuals.modulate = _original_modulate   # safety reset
	)
			
func _set_attack_range_for_phase(new_phase: int) -> void:
	# 1. Change the size using the CollisionShape2D
	if attack_range_collision.shape is RectangleShape2D:
		var rect := attack_range_collision.shape as RectangleShape2D
		match new_phase:
			1:
				rect.size = Vector2(332.0, 133)
			2:
				rect.size = Vector2(434.0, 266.0)
	elif attack_range_collision.shape is CircleShape2D:
		var circle := attack_range_collision.shape as CircleShape2D
		match new_phase:
			1:
				circle.radius = 50.0
			2:
				circle.radius = 80.0

	# 2. After resizing, use the Area2D to re-check overlap
	if player_ref and attack_range_area.overlaps_body(player_ref):
		player_in_attack_range = true
	else:
		player_in_attack_range = false
