# attack_phase2_state.gd
extends BossState

@export var attack_cooldown: float = 0.7
@export var damage: int = 3

var _timer: float = 0.0


func enter() -> void:
	boss.animated_sprite.play("attack_p2")
	boss.velocity = Vector2.ZERO
	_timer = 0.0


func physics_update(delta: float) -> void:
	_timer = max(0.0, _timer - delta)

	if boss.player_ref == null:
		boss.state_machine.transition_to(^"IdleState")
		return

	var dist := boss.global_position.distance_to(boss.player_ref.global_position)
	if dist > boss.attack_range:
		boss.state_machine.transition_to(^"TrackState")
		return

	if _timer <= 0.0:
		_timer = attack_cooldown
		if boss.player_ref.has_method("take_damage"):
			boss.player_ref.take_damage(damage)
		EventBus.enemy_attacked.emit(boss)
