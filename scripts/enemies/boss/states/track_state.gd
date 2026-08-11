# track_state.gd
extends BossState


func enter() -> void:
	boss.animated_sprite.play("track")


func physics_update(_delta: float) -> void:
	if boss.player_ref == null:
		boss.state_machine.transition_to(^"IdleState")
		return

	var dist := boss.global_position.distance_to(boss.player_ref.global_position)
	if dist <= boss.attack_range:
		if boss.phase == 1:
			boss.state_machine.transition_to(^"AttackPhase1State")
		else:
			boss.state_machine.transition_to(^"AttackPhase2State")
		return

	var dir := (boss.player_ref.global_position - boss.global_position).normalized()
	boss.velocity.x = dir.x * boss.move_speed
	if dir.x != 0:
		boss.visuals.scale.x = -1 if dir.x > 0 else 1
	boss.move_and_slide()
