# boss.gd
# ─────────────────────────────────────────────────────────────────────────────
# Boss root. Uses StateMachine to handle Actions
# ─────────────────────────────────────────────────────────────────────────────
extends CharacterBody2D
class_name Boss

@export var max_health: int = 50
@export var move_speed: float = 80.0
#@export var attack_range: float = 60.0
@export var phase_2_threshold: float = 0.5  # fraction of max_health remaining

@onready var visuals: Node2D = $Visuals
@onready var animated_sprite: AnimatedSprite2D = $Visuals/AnimatedSprite2D
@onready var state_machine: BossStateMachine = $StateMachine
@onready var detection_area: Area2D = $DetectionArea
@onready var attack_range_area: Area2D = $Visuals/AttackRangeArea

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


	#var shape_node: CollisionShape2D = attack_range_area.get_node("CollisionShape2D")
	#if shape_node.shape is RectangleShape2D:
		#(shape_node.shape as RectangleShape2D).size = Vector2(attack_range, attack_range)
		#shape_node.position = Vector2(attack_range / 2.0, 0)


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
