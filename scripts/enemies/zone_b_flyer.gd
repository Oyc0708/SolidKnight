class_name ZoneBFlyer
extends EnemyBase

# ============================================================
# MOVEMENT SETTINGS
# ============================================================
@export var patrol_speed: float = 55.0
@export var patrol_distance: float = 110.0
@export var hover_pause: float = 0.7

@export var hover_amplitude: float = 5.0
@export var hover_frequency: float = 2.0
@export var hover_follow_speed: float = 6.0

# ============================================================
# TURN SETTINGS
# ============================================================
@export var turn_frame_duration: float = 0.10

# ============================================================
# DIVE ATTACK SETTINGS
# ============================================================
@export var dive_windup: float = 0.35
@export var dive_speed: float = 230.0
@export var dive_duration: float = 0.9
@export var dive_damage: int = 15
@export var attack_cooldown: float = 1.8

# ============================================================
# EVADE / RETURN SETTINGS
# ============================================================
@export var evade_speed: float = 150.0
@export var evade_duration: float = 0.35
@export var return_speed: float = 100.0

# ============================================================
# SPRITE SETTINGS
# ============================================================
@export var hover_frame: int = 0
@export var patrol_frame: int = 0
@export var dive_frame: int = 0
@export var flip_when_moving_right: bool = true

# ============================================================
# REFERENCES
# ============================================================
@onready var sprite: AnimatedSprite2D = $Sprite

# ============================================================
# STATE
# ============================================================
enum FlyerState {
	PATROL,
	HOVER,
	TURN,
	WINDUP,
	DIVE,
	EVADE,
	RETURN
}

var flyer_state: int = FlyerState.HOVER

# ============================================================
# INTERNAL VARIABLES
# ============================================================
var home_position: Vector2
var patrol_direction: float = 1.0
var hover_time: float = 0.0
var state_timer: float = 0.0
var attack_timer: float = 0.0

var dive_direction: Vector2 = Vector2.ZERO
var evade_direction: Vector2 = Vector2.ZERO
var damage_done: bool = false

var turn_frames: Array[int] = []
var turn_frame_index: int = 0
var turn_frame_timer: float = 0.0

func _ready() -> void:
	super._ready()
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	home_position = global_position
	sprite.flip_h = false
	_set_flyer_state(FlyerState.HOVER, hover_pause)

# ============================================================
# MAIN LOOP
# ============================================================
func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		velocity = Vector2.ZERO
		return

	hover_time += delta
	state_timer = max(0.0, state_timer - delta)
	attack_timer = max(0.0, attack_timer - delta)
	player_ref = _find_player()

	match flyer_state:
		FlyerState.PATROL:
			_process_patrol()
		FlyerState.HOVER:
			_process_hover()
		FlyerState.TURN:
			_process_turn(delta)
		FlyerState.WINDUP:
			_process_windup()
		FlyerState.DIVE:
			_process_dive()
		FlyerState.EVADE:
			_process_evade()
		FlyerState.RETURN:
			_process_return()

	move_and_slide()

	# Stop a dive when the enemy hits a wall/platform.
	if flyer_state == FlyerState.DIVE and get_slide_collision_count() > 0:
		_begin_evade()

# ============================================================
# PATROL
# ============================================================
func _process_patrol() -> void:
	if _player_in_detection_range() and attack_timer <= 0.0:
		_begin_windup()
		return

	velocity.x = patrol_direction * patrol_speed
	velocity.y = (_hover_target_y() - global_position.y) * hover_follow_speed

	if patrol_direction > 0.0 and global_position.x >= home_position.x + patrol_distance:
		_begin_turn(-1.0)
		return

	if patrol_direction < 0.0 and global_position.x <= home_position.x - patrol_distance:
		_begin_turn(1.0)
		return

	_update_facing()

# ============================================================
# TURN
# ============================================================
func _begin_turn(new_direction: float) -> void:
	velocity = Vector2.ZERO
	sprite.animation = &"patrol"
	sprite.pause()
	sprite.flip_h = false

	if patrol_direction > 0.0 and new_direction < 0.0:
		turn_frames = [0, 1, 2, 3, 4]
	elif patrol_direction < 0.0 and new_direction > 0.0:
		turn_frames = [4, 5, 6, 7, 0]
	else:
		patrol_direction = new_direction
		_set_flyer_state(FlyerState.PATROL)
		return

	patrol_direction = new_direction
	turn_frame_index = 0
	turn_frame_timer = 0.0
	sprite.frame = turn_frames[0]
	flyer_state = FlyerState.TURN

func _process_turn(delta: float) -> void:
	velocity = Vector2.ZERO
	turn_frame_timer += delta

	if turn_frame_timer < turn_frame_duration:
		return

	turn_frame_timer = 0.0
	turn_frame_index += 1

	if turn_frame_index >= turn_frames.size():
		_set_flyer_state(FlyerState.PATROL)
		return

	sprite.frame = turn_frames[turn_frame_index]

# ============================================================
# HOVER
# ============================================================
func _process_hover() -> void:
	velocity.x = 0.0
	velocity.y = (_hover_target_y() - global_position.y) * hover_follow_speed

	if _player_in_detection_range() and attack_timer <= 0.0:
		_begin_windup()
		return

	if state_timer <= 0.0:
		_set_flyer_state(FlyerState.PATROL)

func _hover_target_y() -> float:
	return home_position.y + sin(hover_time * hover_frequency) * hover_amplitude

# ============================================================
# WINDUP
# ============================================================
func _begin_windup() -> void:
	velocity = Vector2.ZERO
	_set_flyer_state(FlyerState.WINDUP, dive_windup)

func _process_windup() -> void:
	velocity = Vector2.ZERO

	if player_ref == null:
		_set_flyer_state(FlyerState.RETURN)
		return

	if global_position.distance_to(player_ref.global_position) > detection_range * 1.3:
		_set_flyer_state(FlyerState.RETURN)
		return

	if state_timer > 0.0:
		return

	dive_direction = (player_ref.global_position - global_position).normalized()

	if dive_direction == Vector2.ZERO:
		dive_direction = Vector2(patrol_direction, 0.0)

	damage_done = false
	_set_flyer_state(FlyerState.DIVE, dive_duration)

# ============================================================
# DIVE ATTACK
# ============================================================
func _process_dive() -> void:
	velocity = dive_direction * dive_speed
	_update_facing()

	if (
		player_ref != null
		and not damage_done
		and global_position.distance_to(player_ref.global_position) <= attack_range
	):
		damage_done = true

		if player_ref.has_method("take_damage"):
			player_ref.take_damage(dive_damage, global_position)

		EventBus.enemy_attacked.emit(self)
		_begin_evade()
		return

	if state_timer <= 0.0:
		_begin_evade()

# ============================================================
# EVADE
# ============================================================
func _begin_evade() -> void:
	attack_timer = attack_cooldown

	if player_ref != null:
		evade_direction = (global_position - player_ref.global_position).normalized()
	else:
		evade_direction = -dive_direction

	# Move slightly upward while escaping.
	evade_direction.y -= 0.7
	evade_direction = evade_direction.normalized()

	if evade_direction == Vector2.ZERO:
		evade_direction = Vector2(-patrol_direction, -1.0).normalized()

	_set_flyer_state(FlyerState.EVADE, evade_duration)

func _process_evade() -> void:
	velocity = evade_direction * evade_speed
	_update_facing()

	if state_timer <= 0.0:
		_set_flyer_state(FlyerState.RETURN)

# ============================================================
# RETURN TO HOME
# ============================================================
func _process_return() -> void:
	var distance: float = global_position.distance_to(home_position)

	if distance <= 8.0:
		global_position = home_position
		velocity = Vector2.ZERO
		_set_flyer_state(FlyerState.HOVER, hover_pause)
		return

	var direction: Vector2 = (home_position - global_position).normalized()
	velocity = direction * return_speed
	_update_facing()

# ============================================================
# PLAYER DETECTION
# ============================================================
func _find_player() -> Node2D:
	return get_tree().get_first_node_in_group(&"player") as Node2D

func _player_in_detection_range() -> bool:
	return (
		player_ref != null
		and global_position.distance_to(player_ref.global_position) <= detection_range
	)

# ============================================================
# STATE MANAGEMENT
# ============================================================
func _set_flyer_state(new_state: int, duration: float = 0.0) -> void:
	flyer_state = new_state
	state_timer = duration

	match flyer_state:
		FlyerState.PATROL:
			_set_sprite(&"patrol", patrol_frame)
		FlyerState.HOVER:
			_set_sprite(&"hover", hover_frame)
		FlyerState.WINDUP:
			_set_sprite(&"hover", hover_frame)
		FlyerState.DIVE:
			_set_sprite(&"dive_attack", dive_frame)
		FlyerState.EVADE:
			_set_sprite(&"patrol", patrol_frame)
		FlyerState.RETURN:
			_set_sprite(&"patrol", patrol_frame)

# ============================================================
# SPRITE CONTROL
# ============================================================
func _set_sprite(animation_name: StringName, frame_number: int) -> void:
	if sprite.sprite_frames == null:
		return

	if not sprite.sprite_frames.has_animation(animation_name):
		return

	sprite.animation = animation_name
	sprite.pause()

	var frame_count: int = sprite.sprite_frames.get_frame_count(animation_name)
	if frame_count <= 0:
		return

	sprite.frame = clampi(frame_number, 0, frame_count - 1)
	_update_facing()

# ============================================================
# LEFT / RIGHT FACING
# ============================================================
func _update_facing() -> void:
	var horizontal_direction: float = patrol_direction

	if abs(velocity.x) > 0.5:
		horizontal_direction = sign(velocity.x)

	if flip_when_moving_right:
		sprite.flip_h = horizontal_direction > 0.0
	else:
		sprite.flip_h = horizontal_direction < 0.0
