# death_state.gd
extends BossState

var despawn_timer: float = 3.0
var _is_dead: bool = false


func enter() -> void:
	_is_dead = true
	boss.animated_sprite.play("death")
	boss.velocity = Vector2.ZERO
	
	# Fix for Bug #18: Pass the global_position along with the boss node
	EventBus.enemy_died.emit(boss, boss.global_position)

	if boss.animated_sprite.sprite_frames and boss.animated_sprite.sprite_frames.has_animation("death"):
		boss.animated_sprite.animation_finished.connect(_on_death_animation_finished, CONNECT_ONE_SHOT)
	else:
		boss.queue_free()


# Fix for Bug #13: Fallback timer to ensure the boss despawns even if the animation fails/is empty
func _process(delta: float) -> void:
	if _is_dead:
		despawn_timer -= delta
		if despawn_timer <= 0.0 and is_instance_valid(boss):
			boss.queue_free()


func _on_death_animation_finished() -> void:
	if is_instance_valid(boss):
		boss.queue_free()
