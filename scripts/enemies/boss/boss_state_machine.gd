# boss_state_machine.gd
# ─────────────────────────────────────────────────────────────────────────────
# Generic state machine: holds whichever BossState child is active, calls
# enter()/exit() on transition, and forwards _physics_process to the active
# state. States transition by calling boss.state_machine.transition_to(path),
# where path is a child NodePath relative to this node (e.g. ^"TrackState").
# ─────────────────────────────────────────────────────────────────────────────
extends Node
class_name BossStateMachine

## Path (relative to this node) of the state to enter on _ready(). Set in the
## Inspector — usually ^"IdleState".
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
		# Deferred: children's _ready() runs before the parent's (Boss's), so
		# boss.animated_sprite etc. aren't assigned yet if we call enter() here
		# directly. call_deferred runs this after the whole ready chain finishes.
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
