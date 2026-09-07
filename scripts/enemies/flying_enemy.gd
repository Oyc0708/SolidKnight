# flying_enemy.gd
# ─────────────────────────────────────────────────────────────────────────────
# A flying enemy that ignores gravity and floats freely in 2D space.
#
# Behaviour summary:
#   IDLE/PATROL  → hovers in place with a gentle sine-wave bob
#   CHASE        → steers directly toward the player in 2D (no floor needed)
#   ATTACK       → stops and deals contact damage every attack_cooldown seconds
#   DEAD         → handled by EnemyBase (_die, loot drop, queue_free)
# ─────────────────────────────────────────────────────────────────────────────
class_name FlyingEnemy
extends EnemyBase

# ─── EXPORTED MOVEMENT ───────────────────────────────────────────────────────

## Speed when steering toward the player
@export var move_speed: float = 90.0

## How often the flying enemy can deal damage (seconds)
@export var attack_cooldown: float = 1.8

## Vertical amplitude of the idle hover bob (pixels)
@export var hover_amplitude: float = 14.0

## Frequency of the idle hover bob (Hz)
@export var hover_frequency: float = 1.5


# ─── INTERNAL STATE ──────────────────────────────────────────────────────────

var _attack_timer: float = 0.0
var _hover_timer:  float = 0.0


# ─── BUILT-IN FUNCTIONS ──────────────────────────────────────────────────────

func _ready() -> void:
	super._ready()
	# Float freely — no floor snapping, no built-in gravity
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING


func _physics_process(delta: float) -> void:
	_attack_timer = max(0.0, _attack_timer - delta)
	_hover_timer  += delta

	_update_flying_state()
	super._physics_process(delta)   # dispatches to _on_patrol / _on_chase / _on_attack
	move_and_slide()


# ─── STATE MACHINE UPDATE ─────────────────────────────────────────────────────

func _update_flying_state() -> void:
	if state == State.DEAD:
		return

	player_ref = _find_player_in_range()

	if player_ref == null:
		# Lost sight of player — return to hovering
		if state == State.CHASE or state == State.ATTACK:
			state = State.IDLE
		return

	var dist: float = global_position.distance_to(player_ref.global_position)
	if dist <= attack_range:
		state = State.ATTACK
	elif dist <= detection_range:
		state = State.CHASE

# ─── ANIMATION LOGIC ──────────────────────────────────────────────────────────

func _process(_delta: float) -> void:
	var anim_sprite = get_node_or_null("Visuals/AnimatedSprite2D")
	
	if state == State.DEAD or anim_sprite == null:
		return
		
	# 1. Flip sprite based on movement direction
	if velocity.x > 0.1:
		anim_sprite.flip_h = false
	elif velocity.x < -0.1:
		anim_sprite.flip_h = true
		
	# 2. Play the correct animation
	if state == State.ATTACK:
		anim_sprite.play("attack")
	else:
		anim_sprite.play("idle")


func _find_player_in_range() -> Node2D:
	var players: Array = get_tree().get_nodes_in_group(&"player")
	if players.is_empty():
		return null
	var p: Node2D = players[0]
	if global_position.distance_to(p.global_position) <= detection_range:
		return p
	return null


# ─── STATE OVERRIDES ──────────────────────────────────────────────────────────

## Hover in place with a gentle sine bob
func _on_patrol(_delta: float) -> void:
	velocity.x = 0.0
	velocity.y = sin(_hover_timer * hover_frequency) * hover_amplitude


## Fly directly toward the player in 2D
func _on_chase(_delta: float) -> void:
	if player_ref == null:
		return
	var dir: Vector2 = (player_ref.global_position - global_position).normalized()
	velocity = dir * move_speed


## Stop and deal contact damage on cooldown
func _on_attack(_delta: float) -> void:
	velocity = Vector2.ZERO
	if _attack_timer <= 0.0 and player_ref != null:
		_attack_timer = attack_cooldown
		if player_ref.has_method("take_damage"):
			player_ref.take_damage(15, global_position)
		EventBus.enemy_attacked.emit(self)


## Flying enemies don't patrol or return — just hover
func _on_return(_delta: float) -> void:
	_on_patrol(_delta)

func _die() -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	
	var anim_sprite = get_node_or_null("Visuals/AnimatedSprite2D")
	if anim_sprite and anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation("dead"):
		# Force the animation not to loop, otherwise animation_finished never fires!
		anim_sprite.sprite_frames.set_animation_loop("dead", false)
		anim_sprite.play("dead")
		
		# Turn off collisions so it stops hitting the player
		if has_node("CollisionShape2D"):
			$CollisionShape2D.set_deferred("disabled", true)
		if has_node("Hurtbox"):
			$Hurtbox.set_deferred("monitoring", false)
			$Hurtbox.set_deferred("monitorable", false)
			
		# Wait for the animation to finish
		await anim_sprite.animation_finished
		
	super._die()
