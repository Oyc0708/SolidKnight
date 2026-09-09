extends Node2D

## zone_c_attack_bridge.tscn. This script just test in my own , not use after combine.

var player: PlayerController
var was_attacking := false

@onready var hitbox: Hitbox = $Hitbox
@onready var hitbox_shape: CollisionShape2D = $Hitbox/CollisionShape2D
@onready var timing: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	_find_player()
	_set_hitbox_active(false)


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(player):
		_find_player()
		return

	# Keep the saved attack Area2D attached to the persistent player while this
	# room is loaded. The bridge disappears automatically when Zone C unloads.
	global_position = player.global_position

	var attacking := bool(player.get("_is_attacking"))
	if attacking and not was_attacking:
		_configure_attack_direction()
		timing.play("attack_window")
	elif not attacking and was_attacking:
		timing.stop()
		_set_hitbox_active(false)
	was_attacking = attacking


func _find_player() -> void:
	player = get_tree().get_first_node_in_group(&"player") as PlayerController
	if is_instance_valid(player):
		global_position = player.global_position
		_install_missing_player_animations()


func _install_missing_player_animations() -> void:
	var player_animation := player.get_node_or_null("AnimationPlayer") as AnimationPlayer
	var support_library := timing.get_animation_library(&"")
	if player_animation == null or support_library == null:
		return
	if not player_animation.has_animation_library(&""):
		player_animation.add_animation_library(&"", AnimationLibrary.new())
	var player_library := player_animation.get_animation_library(&"")
	for animation_name in [&"attack_01", &"attack_up", &"attack_down", &"player_land"]:
		if not player_library.has_animation(animation_name):
			player_library.add_animation(
				animation_name,
				support_library.get_animation(animation_name)
			)


func _configure_attack_direction() -> void:
	var direction := String(player.get("_attack_direction"))
	match direction:
		"up":
			hitbox.position = Vector2(0, -45)
			hitbox_shape.shape.size = Vector2(40, 40)
		"down":
			hitbox.position = Vector2(0, 15)
			hitbox_shape.shape.size = Vector2(40, 40)
		_:
			var facing := player.facing_direction
			if is_zero_approx(facing):
				facing = 1.0
			hitbox.position = Vector2(35.0 * signf(facing), -15)
			hitbox_shape.shape.size = Vector2(40, 50)


func _set_hitbox_active(active: bool) -> void:
	# Deferred toggling is required by Godot when a physics query is running.
	hitbox.set_deferred("monitoring", active)
