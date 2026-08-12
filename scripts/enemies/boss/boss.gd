# boss.gd
# ─────────────────────────────────────────────────────────────────────────────
# Boss root. Does NOT extend EnemyBase — the simple enum+match state machine
# there doesn't fit a multi-phase boss. Instead this owns health/phase and a
# DetectionArea for player tracking, and hands all *behavior* off to
# StateMachine (see boss_state_machine.gd + states/*.gd).
# ─────────────────────────────────────────────────────────────────────────────
extends CharacterBody2D
class_name Boss

@export var max_health: int = 50
@export var move_speed: float = 80.0
@export var attack_range: float = 60.0
@export var phase_2_threshold: float = 0.5  # fraction of max_health remaining

@onready var visuals: Node2D = $Visuals
@onready var animated_sprite: AnimatedSprite2D = $Visuals/AnimatedSprite2D
@onready var state_machine: BossStateMachine = $StateMachine
@onready var detection_area: Area2D = $DetectionArea
@onready var attack_range_area: Area2D = $AttackRangeArea

var current_health: int
var phase: int = 1
var player_ref: Node2D = null
var player_in_attack_range: bool = false


func _ready() -> void:
	current_health = max_health
	detection_area.body_entered.connect(_on_detection_entered)
	detection_area.body_exited.connect(_on_detection_exited)
	attack_range_area.body_entered.connect(_on_attack_range_entered)
	attack_range_area.body_exited.connect(_on_attack_range_exited)

	# Keep the AttackRangeArea's actual shape in sync with attack_range so
	# there's only one number to tune, instead of the export var and the
	# Area2D's radius silently drifting apart.
	var shape_node: CollisionShape2D = attack_range_area.get_node("CollisionShape2D")
	if shape_node.shape is CircleShape2D:
		(shape_node.shape as CircleShape2D).radius = attack_range


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
	if state_machine.current_state and state_machine.current_state.name == "DeathState":
		return

	current_health -= amount

	if current_health <= 0:
		current_health = 0
		state_machine.transition_to(^"DeathState")
		return

	if phase == 1 and float(current_health) / max_health <= phase_2_threshold:
		phase = 2
		state_machine.transition_to(^"PhaseTransitionState")
