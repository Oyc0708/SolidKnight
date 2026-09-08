class_name ZoneBFlyer
extends EnemyBase


# ============================================================
# PATROL SETTINGS
# ============================================================

## Normal horizontal patrol speed.
@export var patrol_speed: float = 55.0

## Distance travelled from the original spawn point.
@export var patrol_distance: float = 110.0

## Hover duration when reaching the patrol boundary.
@export var hover_pause: float = 0.7


# ============================================================
# HOVER SETTINGS
# ============================================================

## Vertical bobbing distance.
@export var hover_amplitude: float = 5.0

## Hover frequency.
@export var hover_frequency: float = 2.0

## How quickly the Flyer follows the hover position.
@export var hover_follow_speed: float = 6.0


# ============================================================
# TURN SETTINGS
# ============================================================

## Duration of each turning frame.
@export var turn_frame_duration: float = 0.10

var turn_frames: Array[int] = []
var turn_frame_index: int = 0
var turn_frame_timer: float = 0.0


# ============================================================
# DIVE ATTACK SETTINGS
# ============================================================

## Warning time before the Flyer starts diving.
@export var dive_windup: float = 0.35

## Dive movement speed.
@export var dive_speed: float = 230.0

## Maximum duration of a dive.
@export var dive_duration: float = 0.9

## Damage dealt when the dive reaches the player.
@export var dive_damage: int = 15

## Time before another dive attack is allowed.
@export var attack_cooldown: float = 1.8


# ============================================================
# EVADE / RETURN SETTINGS
# ============================================================

## Speed used when escaping after a dive.
@export var evade_speed: float = 150.0

## How long the evade movement lasts.
@export var evade_duration: float = 0.35

## Speed used when returning to the patrol area.
@export var return_speed: float = 100.0


# ============================================================
# SPRITE SETTINGS
# ============================================================

## Normal frame used when hovering.
@export var hover_frame: int = 0

## Normal frame used when patrolling.
@export var patrol_frame: int = 0

## Normal frame used during the dive attack.
@export var dive_frame: int = 0


# ============================================================
# REFERENCES
# ============================================================

@onready var sprite: AnimatedSprite2D = $Sprite


# ============================================================
# FLYER STATES
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

var flyer_state: int = FlyerState.RETURN


# ============================================================
# INTERNAL VARIABLES
# ============================================================

## Original position of the enemy in Zone B.
var home_position: Vector2

## 1 = right
## -1 = left
var patrol_direction: float = 1.0

var hover_time: float = 0.0

var state_timer: float = 0.0
var attack_timer: float = 0.0

var dive_direction: Vector2 = Vector2.ZERO
var evade_direction: Vector2 = Vector2.ZERO

var damage_done: bool = false


# ============================================================
# READY
# ============================================================

func _ready() -> void:
	super._ready()

	# Flying enemy does not use normal floor movement.
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING

	# Remember the starting position.
	home_position = global_position

	# Normal sprite orientation.
	sprite.flip_h = false

	# Start by hovering.
	_set_flyer_state(
		FlyerState.HOVER,
		hover_pause
	)


# ============================================================
# MAIN LOOP
# ============================================================

func _physics_process(delta: float) -> void:
	hover_time += delta

	state_timer = max(
		0.0,
		state_timer - delta
	)

	attack_timer = max(
		0.0,
		attack_timer - delta
	)

	# Find player every physics frame.
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

	# If the Flyer hits a wall or platform while diving,
	# stop the dive and begin evading.
	if flyer_state == FlyerState.DIVE:
		if get_slide_collision_count() > 0:
			_begin_evade()


# ============================================================
# PATROL
# ============================================================

func _process_patrol() -> void:

	# Detect player while patrolling.
	if _player_in_detection_range():
		if attack_timer <= 0.0:
			_begin_windup()
			return

	# Horizontal patrol movement.
	velocity.x = patrol_direction * patrol_speed

	# Gentle vertical flying movement.
	var target_y: float = (
		home_position.y
		+ sin(
			hover_time * hover_frequency
		) * hover_amplitude
	)

	velocity.y = (
		target_y - global_position.y
	) * hover_follow_speed


	# --------------------------------------------------------
	# RIGHT BOUNDARY
	# --------------------------------------------------------

	if (
		patrol_direction > 0.0
		and global_position.x
		>= home_position.x + patrol_distance
	):
		_begin_turn(-1.0)
		return


	# --------------------------------------------------------
	# LEFT BOUNDARY
	# --------------------------------------------------------

	if (
		patrol_direction < 0.0
		and global_position.x
		<= home_position.x - patrol_distance
	):
		_begin_turn(1.0)
		return


	# Normal patrol only uses horizontal mirroring.
	_update_facing()


# ============================================================
# TURN
# ============================================================

func _begin_turn(new_direction: float) -> void:

	# Stop moving while turning.
	velocity = Vector2.ZERO

	# Use the patrol 8-direction sprite sheet.
	sprite.animation = &"patrol"
	sprite.pause()

	# The turn frames already contain their own directions.
	# Therefore, do not mirror them during TURN.
	sprite.flip_h = false


	# --------------------------------------------------------
	# RIGHT → LEFT
	#
	# 0 → 1 → 2 → 3 → 4
	#
	# Turns through the front side.
	# --------------------------------------------------------

	if (
		patrol_direction > 0.0
		and new_direction < 0.0
	):
		turn_frames = [
			0,
			1,
			2,
			3,
			4
		]


	# --------------------------------------------------------
	# LEFT → RIGHT
	#
	# 4 → 5 → 6 → 7 → 0
	#
	# Turns through the back side.
	# --------------------------------------------------------

	elif (
		patrol_direction < 0.0
		and new_direction > 0.0
	):
		turn_frames = [
			4,
			5,
			6,
			7,
			0
		]


	# Safety fallback.
	else:
		patrol_direction = new_direction

		_set_flyer_state(
			FlyerState.PATROL
		)

		return


	# Change the patrol direction.
	patrol_direction = new_direction

	# Reset turn animation.
	turn_frame_index = 0
	turn_frame_timer = 0.0

	# Show first turning frame.
	sprite.frame = turn_frames[0]

	# Enter TURN state.
	flyer_state = FlyerState.TURN


func _process_turn(delta: float) -> void:

	# Enemy stays still while turning.
	velocity = Vector2.ZERO

	turn_frame_timer += delta


	# Wait until enough time has passed.
	if turn_frame_timer < turn_frame_duration:
		return


	turn_frame_timer = 0.0
	turn_frame_index += 1


	# --------------------------------------------------------
	# TURN FINISHED
	# --------------------------------------------------------

	if turn_frame_index >= turn_frames.size():

		_set_flyer_state(
			FlyerState.PATROL
		)

		return


	# Show next turning frame.
	sprite.frame = turn_frames[
		turn_frame_index
	]


# ============================================================
# HOVER
# ============================================================

func _process_hover() -> void:

	velocity.x = 0.0

	var target_y: float = (
		home_position.y
		+ sin(
			hover_time * hover_frequency
		) * hover_amplitude
	)

	velocity.y = (
		target_y - global_position.y
	) * hover_follow_speed


	# Player enters detection range.
	if _player_in_detection_range():
		if attack_timer <= 0.0:
			_begin_windup()
			return


	# Finish hovering.
	if state_timer <= 0.0:

		_set_flyer_state(
			FlyerState.PATROL
		)


# ============================================================
# WINDUP / PLAYER DETECTED
# ============================================================

func _begin_windup() -> void:

	velocity = Vector2.ZERO

	_set_flyer_state(
		FlyerState.WINDUP,
		dive_windup
	)


func _process_windup() -> void:

	velocity = Vector2.ZERO


	# Player no longer exists.
	if player_ref == null:

		_set_flyer_state(
			FlyerState.RETURN
		)

		return


	# Player moved too far away.
	if (
		global_position.distance_to(
			player_ref.global_position
		)
		> detection_range * 1.3
	):

		_set_flyer_state(
			FlyerState.RETURN
		)

		return


	# Windup finished → start dive.
	if state_timer <= 0.0:

		dive_direction = (
			player_ref.global_position
			- global_position
		).normalized()


		# Safety fallback.
		if dive_direction == Vector2.ZERO:

			dive_direction = Vector2(
				patrol_direction,
				0.0
			)


		damage_done = false

		_set_flyer_state(
			FlyerState.DIVE,
			dive_duration
		)


# ============================================================
# DIVE ATTACK
# ============================================================

func _process_dive() -> void:

	velocity = (
		dive_direction
		* dive_speed
	)

	_update_facing()


	# --------------------------------------------------------
	# PLAYER HIT
	# --------------------------------------------------------

	if (
		player_ref != null
		and not damage_done
		and global_position.distance_to(
			player_ref.global_position
		) <= attack_range
	):

		damage_done = true


		if player_ref.has_method(
			"take_damage"
		):

			player_ref.take_damage(
				dive_damage,
				global_position
			)


		EventBus.enemy_attacked.emit(self)

		_begin_evade()

		return


	# --------------------------------------------------------
	# DIVE MISSED
	# --------------------------------------------------------

	if state_timer <= 0.0:

		_begin_evade()


# ============================================================
# EVADE
# ============================================================

func _begin_evade() -> void:

	# Start attack cooldown.
	attack_timer = attack_cooldown


	# --------------------------------------------------------
	# MOVE AWAY FROM PLAYER
	# --------------------------------------------------------

	if player_ref != null:

		evade_direction = (
			global_position
			- player_ref.global_position
		).normalized()

	else:

		evade_direction = (
			-dive_direction
		)


	# Move slightly upward while escaping.
	evade_direction.y -= 0.7

	evade_direction = (
		evade_direction.normalized()
	)


	# Safety fallback.
	if evade_direction == Vector2.ZERO:

		evade_direction = Vector2(
			-patrol_direction,
			-1.0
		).normalized()


	_set_flyer_state(
		FlyerState.EVADE,
		evade_duration
	)


func _process_evade() -> void:

	velocity = (
		evade_direction
		* evade_speed
	)

	_update_facing()


	# Finish evade.
	if state_timer <= 0.0:

		_set_flyer_state(
			FlyerState.RETURN
		)


# ============================================================
# RETURN TO PATROL AREA
# ============================================================

func _process_return() -> void:

	var target_position: Vector2 = (
		home_position
	)

	var distance: float = (
		global_position.distance_to(
			target_position
		)
	)


	# --------------------------------------------------------
	# ARRIVED HOME
	# --------------------------------------------------------

	if distance <= 8.0:

		global_position = (
			target_position
		)

		velocity = Vector2.ZERO

		_set_flyer_state(
			FlyerState.HOVER,
			hover_pause
		)

		return


	# --------------------------------------------------------
	# MOVE TOWARD HOME
	# --------------------------------------------------------

	var direction: Vector2 = (
		target_position
		- global_position
	).normalized()


	velocity = (
		direction
		* return_speed
	)

	_update_facing()


# ============================================================
# PLAYER DETECTION
# ============================================================

func _find_player() -> Node2D:

	var players: Array = (
		get_tree().get_nodes_in_group(
			&"player"
		)
	)


	if players.is_empty():
		return null


	return players[0] as Node2D


func _player_in_detection_range() -> bool:

	if player_ref == null:
		return false


	return (
		global_position.distance_to(
			player_ref.global_position
		)
		<= detection_range
	)


# ============================================================
# STATE MANAGEMENT
# ============================================================

func _set_flyer_state(
	new_state: int,
	duration: float = 0.0
) -> void:

	flyer_state = new_state
	state_timer = duration


	match flyer_state:

		FlyerState.PATROL:

			_set_sprite(
				&"patrol",
				patrol_frame
			)


		FlyerState.HOVER:

			_set_sprite(
				&"hover",
				hover_frame
			)


		FlyerState.WINDUP:

			_set_sprite(
				&"hover",
				hover_frame
			)


		FlyerState.DIVE:

			_set_sprite(
				&"dive_attack",
				dive_frame
			)


		FlyerState.EVADE:

			_set_sprite(
				&"patrol",
				patrol_frame
			)


		FlyerState.RETURN:

			_set_sprite(
				&"patrol",
				patrol_frame
			)


# ============================================================
# SPRITE CONTROL
# ============================================================

func _set_sprite(
	animation_name: StringName,
	frame_number: int
) -> void:

	sprite.animation = animation_name

	# Do not automatically play all directional frames.
	sprite.pause()


	var frame_count: int = (
		sprite.sprite_frames.get_frame_count(
			animation_name
		)
	)


	if frame_count <= 0:
		return


	sprite.frame = clampi(
		frame_number,
		0,
		frame_count - 1
	)


	_update_facing()


# ============================================================
# LEFT / RIGHT FACING
# ============================================================

func _update_facing() -> void:

	# --------------------------------------------------------
	# MOVING
	# --------------------------------------------------------

	if abs(velocity.x) > 0.5:

		sprite.flip_h = velocity.x > 0.0
		return

	sprite.flip_h = patrol_direction > 0.0


	# --------------------------------------------------------
	# NOT MOVING
	#
	# Hover / windup etc. use the patrol direction.
	# --------------------------------------------------------

	sprite.flip_h = (
		patrol_direction < 0.0
	)
