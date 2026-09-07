# boss_state.gd
# ─────────────────────────────────────────────────────────────────────────────
# Base class for every boss state node. Each concrete state (IdleState,
# TrackState, etc.) extends this and lives as a child of StateMachine in
# boss.tscn — so tunables (cooldowns, speeds) are @export fields set per
# instance in the Inspector rather than hardcoded in one giant script.
# ─────────────────────────────────────────────────────────────────────────────
extends Node
class_name BossState

var boss: Boss


func enter() -> void:
	pass


func exit() -> void:
	pass


func physics_update(_delta: float) -> void:
	pass
