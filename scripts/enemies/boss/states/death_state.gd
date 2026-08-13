# death_state.gd
extends BossState


func enter() -> void:
	boss.animated_sprite.play("death")
	boss.velocity = Vector2.ZERO
	EventBus.enemy_died.emit(boss)

	if boss.animated_sprite.sprite_frames and boss.animated_sprite.sprite_frames.has_animation("death"):
		boss.animated_sprite.animation_finished.connect(_on_death_animation_finished, CONNECT_ONE_SHOT)
	else:
		boss.queue_free()


func _on_death_animation_finished() -> void:
	boss.queue_free()
