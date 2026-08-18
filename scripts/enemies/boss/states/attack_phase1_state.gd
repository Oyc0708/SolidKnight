# attack_phase1_state.gd
extends BossState

@export var attack_cooldown: float = 1.2
@export var damage: int = 2

## Frame index within "attack_p1" where the hit lands.
@export var hit_frame: int = 5

var _hit_landed_this_swing: bool = false
var _waiting_for_cooldown: bool = false
var _cooldown_timer: float = 0.0


func enter() -> void:
	boss.animated_sprite.play("attack_p1")
	boss.animated_sprite.frame_changed.connect(_on_frame_changed)
	boss.animated_sprite.animation_finished.connect(_on_animation_finished)
	boss.velocity = Vector2.ZERO
	_hit_landed_this_swing = false
	_waiting_for_cooldown = false


func exit() -> void:
	if boss.animated_sprite.frame_changed.is_connected(_on_frame_changed):
		boss.animated_sprite.frame_changed.disconnect(_on_frame_changed)
	if boss.animated_sprite.animation_finished.is_connected(_on_animation_finished):
		boss.animated_sprite.animation_finished.disconnect(_on_animation_finished)


func physics_update(delta: float) -> void:
	# Attacks play until finish
	# Hit vs. miss is decided at the hit frame instead (see _on_frame_changed).
	if boss.player_ref == null:
		boss.state_machine.transition_to(^"IdleState")
		return

	if _waiting_for_cooldown:
		_cooldown_timer = max(0.0, _cooldown_timer - delta)
		if _cooldown_timer <= 0.0:
			_waiting_for_cooldown = false
			if boss.player_in_attack_range:
				boss.animated_sprite.play("attack_p1")
				_hit_landed_this_swing = false
			else:
				boss.state_machine.transition_to(^"TrackState")


func _on_frame_changed() -> void:
	if _hit_landed_this_swing:
		return
	if boss.animated_sprite.animation != "attack_p1":
		return
	if boss.animated_sprite.frame != hit_frame:
		return

	# Only deal damage if the player is in range right now 
	if boss.player_in_attack_range and boss.player_ref and boss.player_ref.has_method("take_damage"):
		boss.player_ref.take_damage(damage)
		EventBus.enemy_attacked.emit(boss)

	_hit_landed_this_swing = true


func _on_animation_finished() -> void:
	_waiting_for_cooldown = true
	_cooldown_timer = attack_cooldown
