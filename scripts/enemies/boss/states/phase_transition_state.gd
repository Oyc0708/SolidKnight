# phase_transition_state.gd
extends BossState

@export var transition_duration: float = 1.5

var _timer: float = 0.0


func enter() -> void:
	boss.animated_sprite.play("phase_transition")
	boss.velocity = Vector2.ZERO
	_timer = transition_duration
	EventBus.boss_phase_changed.emit(boss.phase)


func physics_update(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		boss.state_machine.transition_to(^"TrackState")
