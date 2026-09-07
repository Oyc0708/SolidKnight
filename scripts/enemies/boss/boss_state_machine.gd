# boss_state_machine.gd
# ─────────────────────────────────────────────────────────────────────────────
# state machine: holds whichever BossState child is active, calls
# enter()/exit() on transition
# ─────────────────────────────────────────────────────────────────────────────
extends Node
class_name BossStateMachine

@export var initial_state: NodePath

var current_state: BossState
var boss: Boss


func _ready() -> void:
	boss = get_parent() as Boss
	for child in get_children():
		if child is BossState:
			child.boss = boss

	if initial_state != NodePath():
		current_state = get_node(initial_state)
		
		current_state.call_deferred("enter")


func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)


func transition_to(path: NodePath) -> void:
	var next_state: BossState = get_node(path)
	if next_state == current_state:
		return

	if current_state:
		current_state.exit()
	current_state = next_state
	current_state.enter()
