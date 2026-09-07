# idle_state.gd
extends BossState


func enter() -> void:
	boss.animated_sprite.play("idle")
	boss.velocity = Vector2.ZERO


func physics_update(_delta: float) -> void:
	if boss.player_ref != null:
		boss.state_machine.transition_to(^"TrackState")
