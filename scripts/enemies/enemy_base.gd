# enemy_base.gd
# ─────────────────────────────────────────────────────────────────────────────
# Shared skeleton for all enemy types. Subclasses override the _on_* methods
# to implement type-specific behavior; the state machine and player-detection
# plumbing stays here so it isn't duplicated per enemy.
# ─────────────────────────────────────────────────────────────────────────────
extends CharacterBody2D
class_name EnemyBase

enum State { IDLE, PATROL, CHASE, ATTACK, RETURN, DEAD }

@export var max_health: int = 10
@export var detection_range: float = 150.0
@export var attack_range: float = 40.0

var current_health: int
var state: State = State.IDLE
var player_ref: Node2D = null


func _ready() -> void:
	current_health = max_health


func _physics_process(delta: float) -> void:
	match state:
		State.IDLE, State.PATROL:
			_on_patrol(delta)
		State.CHASE:
			_on_chase(delta)
		State.ATTACK:
			_on_attack(delta)
		State.RETURN:
			_on_return(delta)


func take_damage(amount: int) -> void:
	current_health -= amount
	if current_health <= 0:
		_die()


func _die() -> void:
	state = State.DEAD
	# Fix for Bug #18: Pass the global_position along with the enemy node
	EventBus.enemy_died.emit(self, global_position)
	queue_free()


# Override in subclasses
func _on_patrol(_delta: float) -> void: pass
func _on_chase(_delta: float) -> void: pass
func _on_attack(_delta: float) -> void: pass
func _on_return(_delta: float) -> void: pass
