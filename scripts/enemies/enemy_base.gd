# enemy_base.gd
# ─────────────────────────────────────────────────────────────────────────────
# Shared skeleton for all enemy types. 
#
# MILESTONE M2.6 — Health Pickup Integration
#   + Added drop_scene and drop_chance for loot spawning on death
# ─────────────────────────────────────────────────────────────────────────────
extends CharacterBody2D
class_name EnemyBase

enum State { IDLE, PATROL, CHASE, ATTACK, RETURN, DEAD }

@export var max_health: int = 10
@export var detection_range: float = 150.0
@export var attack_range: float = 40.0

# ─── LOOT SETTINGS ───────────────────────────────────────────────────────────
@export var drop_scene: PackedScene
@export_range(0.0, 1.0) var drop_chance: float = 0.5 # 50% chance by default

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
	
	# NEW M2.6: Spawn loot before freeing the node
	if drop_scene != null and randf() <= drop_chance:
		var drop = drop_scene.instantiate()
		drop.global_position = global_position
		# Add to the current scene so it doesn't get deleted when the enemy frees itself
		get_tree().current_scene.add_child(drop)
	
	# Fix for Bug #18: Pass the global_position along with the enemy node
	EventBus.enemy_died.emit(self, global_position)
	queue_free()


# Override in subclasses
func _on_patrol(_delta: float) -> void: pass
func _on_chase(_delta: float) -> void: pass
func _on_attack(_delta: float) -> void: pass
func _on_return(_delta: float) -> void: pass
