# example_enemy.gd
# ─────────────────────────────────────────────────────────────────────────────
# Sample enemy  
# Walks between two patrol points
# Chases the player on detection
# Attacks in range
# Returns to its patrol path if it loses the player
#
# ─────────────────────────────────────────────────────────────────────────────
extends EnemyBase
class_name ExampleEnemy

@export var move_speed: float = 60.0
@export var patrol_point_a: Marker2D
@export var patrol_point_b: Marker2D
@export var attack_cooldown: float = 1.5

var _patrol_target: Marker2D
var _attack_timer: float = 0.0
var _origin_position: Vector2


func _ready() -> void:
	super._ready()
	_origin_position = global_position
	_patrol_target = patrol_point_b


func _physics_process(delta: float) -> void:
	_attack_timer = max(0.0, _attack_timer - delta)
	_update_state()
	super._physics_process(delta)
	
	# Apply gravity so the ground enemy doesn't float
	if not is_on_floor():
		velocity += get_gravity() * delta
		
	move_and_slide()


func _update_state() -> void:
	if state == State.DEAD:
		return

	player_ref = _find_player_in_range()

	if player_ref == null:
		if state == State.CHASE or state == State.ATTACK:
			state = State.RETURN
		return

	var dist := global_position.distance_to(player_ref.global_position)
	if dist <= attack_range:
		state = State.ATTACK
	elif dist <= detection_range:
		state = State.CHASE


func _find_player_in_range() -> Node2D:
	var players := get_tree().get_nodes_in_group(&"player")
	if players.is_empty():
		return null
	var p: Node2D = players[0]
	if global_position.distance_to(p.global_position) <= detection_range:
		return p
	return null


# ─── State overrides ──────────────────────────────────────────────────────────

func _on_patrol(_delta: float) -> void:
	if patrol_point_a == null or patrol_point_b == null or _patrol_target == null:
		return
	var dir := (_patrol_target.global_position - global_position).normalized()
	velocity.x = dir.x * move_speed

	if global_position.distance_to(_patrol_target.global_position) < 8.0:
		_patrol_target = patrol_point_a if _patrol_target == patrol_point_b else patrol_point_b


func _on_chase(_delta: float) -> void:
	if player_ref == null:
		return
	var dir := (player_ref.global_position - global_position).normalized()
	velocity.x = dir.x * move_speed * 1.5


# Fix for Bug #6: Uncommented the attack logic so the enemy deals damage
func _on_attack(_delta: float) -> void:
	velocity.x = 0.0
	if _attack_timer <= 0.0 and player_ref != null:
		_attack_timer = attack_cooldown
		if player_ref.has_method("take_damage"):
			# Pass global_position so the player gets knocked back properly!


			player_ref.take_damage(20, global_position) 
		EventBus.enemy_attacked.emit(self)


func _on_return(_delta: float) -> void:
	var dir := (_origin_position - global_position).normalized()
	velocity.x = dir.x * move_speed

	if global_position.distance_to(_origin_position) < 8.0:
		state = State.PATROL


# ─── Animation Logic ──────────────────────────────────────────────────────────

func _process(_delta: float) -> void:
	# Try to find the AnimatedSprite2D under Visuals
	var anim_sprite = get_node_or_null("Visuals/AnimatedSprite2D")
	
	if state == State.DEAD or anim_sprite == null:
		return
		
	# 1. Flip the sprite left/right based on movement direction
	if velocity.x > 0.1:
		anim_sprite.flip_h = false # Facing Right (adjust if your sprite is drawn facing left)
	elif velocity.x < -0.1:
		anim_sprite.flip_h = true  # Facing Left
		
	# 2. Play the correct animation based on state
	if state == State.ATTACK:
		anim_sprite.play("attack")
	elif abs(velocity.x) > 5.0:
		anim_sprite.play("run")
	else:
		anim_sprite.play("idle")

func _die() -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	
	var anim_sprite = get_node_or_null("Visuals/AnimatedSprite2D")
	if anim_sprite and anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation("dead"):
		# Force the animation not to loop, otherwise animation_finished never fires!
		anim_sprite.sprite_frames.set_animation_loop("dead", false)
		anim_sprite.play("dead")
		
		if has_node("CollisionShape2D"):
			$CollisionShape2D.set_deferred("disabled", true)
		if has_node("Hurtbox"):
			$Hurtbox.set_deferred("monitoring", false)
			$Hurtbox.set_deferred("monitorable", false)
			
		await anim_sprite.animation_finished
		
	super._die()
