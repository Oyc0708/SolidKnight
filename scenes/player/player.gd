# player.gd
# ─────────────────────────────────────────────────────────────────────────────
# MILESTONE M2.3 — AnimationPlayer frame events, attack timing, landing events
#
# Fixes applied from M1.6 file:
#   ~ _is_attacking / _attack_direction moved to correct ATTACK STATE section
#   ~ _handle_horizontal_movement() duplicate code removed, effective_speed fixed
#   ~ get_current_floor_angle() renamed to get_floor_angle() (matches animation controller)
#
# New additions this milestone:
#   + attack_move_penalty  @export constant
#   + _is_attacking, _attack_direction  state variables (moved to correct section)
#   + _debug_hitbox_active  debug variable
#   + _handle_attack_input()  reads attack button, sets direction, starts AnimationPlayer
#   + _on_attack_started/finished/hitbox_active  AnimationPlayer callback stubs
#   + _on_land_impact(), _on_play_sfx()  event callback stubs
#   + is_attacking(), get_attack_direction()  public accessors
#   ~ _start_dash()  cancels active attack before dashing
#   ~ take_damage()  cancels active attack when hit
#   ~ _handle_horizontal_movement()  applies attack_move_penalty cleanly (fixed)
#   ~ _draw()  adds debug hitbox rectangle during active hitbox window
# ─────────────────────────────────────────────────────────────────────────────
class_name PlayerController
extends CharacterBody2D


# ─── EXPORTED MOVEMENT CONSTANTS ─────────────────────────────────────────────

## Horizontal movement speed (pixels per second)
@export var move_speed: float = 180.0

## Base gravity when rising with jump held (pixels per second squared)
@export var gravity: float = 1800.0


# ─── EXPORTED JUMP CONSTANTS ─────────────────────────────────────────────────

## Upward velocity on a ground jump (negative = up)
@export var jump_force: float = -700.0

## Gravity multiplier while falling
@export var fall_gravity_multiplier: float = 2.5

## Gravity multiplier while rising with jump button released
@export var jump_cut_multiplier: float = 3.5

## Terminal falling speed (pixels per second)
@export var max_fall_speed: float = 800.0

## Grace window after leaving a floor (seconds)
@export var coyote_time: float = 0.12

## Stored jump input window before landing (seconds)
@export var jump_buffer_time: float = 0.10


# ─── EXPORTED DASH CONSTANTS ─────────────────────────────────────────────────

## Velocity override during dash (pixels per second)
@export var dash_speed: float = 500.0

## Dash duration (seconds)
@export var dash_duration: float = 0.18

## Minimum time between dashes (seconds)
@export var dash_cooldown: float = 0.50


# ─── EXPORTED WALL CONSTANTS ─────────────────────────────────────────────────

## Fraction of normal gravity while wall sliding
@export var wall_slide_gravity_multiplier: float = 0.12

## Maximum downward speed while wall sliding (pixels per second)
@export var wall_slide_max_speed: float = 60.0

## Horizontal force away from wall on wall jump (pixels per second)
@export var wall_jump_horizontal_force: float = 250.0

## Upward force on wall jump (pixels per second)
@export var wall_jump_vertical_force: float = -650.0

## Horizontal input lock after wall jump (seconds)
@export var wall_jump_lock_duration: float = 0.20


# ─── EXPORTED DOUBLE JUMP CONSTANTS ──────────────────────────────────────────

## Upward velocity on the double jump (slightly less than jump_force)
@export var double_jump_force: float = -600.0


# ─── EXPORTED KNOCKBACK CONSTANTS ────────────────────────────────────────────

## Speed of the knockback launch in the direction away from damage source
@export var knockback_force: float = 380.0

## Small upward component always added to knockback
@export var knockback_vertical_force: float = -200.0

## How long horizontal control is suppressed after taking damage (seconds)
@export var knockback_duration: float = 0.25

## How long invincibility frames last after taking damage (seconds)
@export var iframes_duration: float = 1.2


# ─── EXPORTED ATTACK CONSTANTS ← NEW M2.3 ────────────────────────────────────

## Horizontal speed multiplier while attacking on the ground.
## 0.6 = 60% of normal speed — creates commitment, cannot freely reposition mid-swing.
## 1.0 = no penalty.  Air attacks are always full speed (penalty only applies on floor).
@export var attack_move_penalty: float = 0.6


# ─── PHYSICS LAYER CONSTANTS ─────────────────────────────────────────────────

## Layer number for one-way (drop-through) platforms
const DROP_THROUGH_LAYER: int = 13

## How long the player phases through one-way platforms when dropping
const DROP_THROUGH_DURATION: float = 0.15


# ─── ANIMATION TIMING CONSTANTS ──────────────────────────────────────────────

## Duration of the double jump trigger window (seconds).
## _double_jump_flash_timer is set to this value on double jump.
## player_animation.gd reads the timer for rising-edge detection —
## this is how it knows EXACTLY which frame the double jump fired.
## The visual ring it originally drew was removed in M2.4.
const DOUBLE_JUMP_ANIM_DURATION: float = 0.15

# ─── FACING STATE ─────────────────────────────────────────────────────────────

# 1.0 = facing right, -1.0 = facing left
var facing_direction: float = 1.0


# ─── JUMP STATE ───────────────────────────────────────────────────────────────

var _is_jumping: bool         = false
var _was_on_floor: bool       = false
var _coyote_timer: float      = 0.0
var _jump_buffer_timer: float = 0.0


# ─── DASH STATE ───────────────────────────────────────────────────────────────

var _is_dashing: bool           = false
var _dash_timer: float          = 0.0
var _dash_cooldown_timer: float = 0.0
var _dash_direction: float      = 1.0
var _can_air_dash: bool         = true


# ─── WALL SLIDE STATE ─────────────────────────────────────────────────────────

var _is_wall_sliding: bool       = false
var _wall_normal: Vector2        = Vector2.ZERO
var _wall_jump_lock_timer: float = 0.0


# ─── DOUBLE JUMP STATE ────────────────────────────────────────────────────────

var _can_double_jump: bool          = true
var _double_jump_flash_timer: float = 0.0


# ─── DROP-THROUGH STATE ───────────────────────────────────────────────────────

var _drop_through_timer: float = 0.0


# ─── INVINCIBILITY STATE ──────────────────────────────────────────────────────
# Computed at the end of each _physics_process() frame:
#     _is_invincible = _is_dashing OR (_iframes_timer > 0.0)
# Never written directly — always derived from its two sources.
var _is_invincible: bool = false


# ─── KNOCKBACK STATE ──────────────────────────────────────────────────────────

# Seconds of I-frame protection remaining after taking damage
var _iframes_timer: float = 0.0

# Seconds of horizontal control suppression remaining after taking damage
var _knockback_timer: float = 0.0

# Cached horizontal knockback direction for external reference
var _knockback_direction: float = 1.0


# ─── SLOPE STATE ──────────────────────────────────────────────────────────────

# Floor angle in radians from get_floor_normal() — 0.0 = flat
# Read by player_animation.gd via get_floor_angle() to tilt the sprite
var _current_floor_angle: float = 0.0


# ─── ATTACK STATE ← NEW M2.3 ─────────────────────────────────────────────────
# NOTE: These variables are declared here, in the state section, so they exist
# before any function that references them. Declaring them after _handle_attack_input()
# (as in the previous version) causes confusing ordering — always declare variables
# at the top of their logical section, before any functions.

# True from _on_attack_started() call until _on_attack_finished() call.
# AnimationPlayer method tracks drive both transitions.
var _is_attacking: bool = false

# Direction set at the moment the attack button is pressed.
# "neutral" = left/right slash   "up" = upward slash   "down" = pogo down-slash
# Used by AnimationPlayer to select the correct timing track and by Phase 4 to
# position the hitbox Area2D.
var _attack_direction: String = "neutral"

# True while the AnimationPlayer hitbox window is active (between hitbox_on and
# hitbox_off keyframes). Drives the debug orange rectangle in _draw().
# Replaced by real Area2D.monitoring in Phase 4.
var _debug_hitbox_active: bool = false


# ─── BUILT-IN FUNCTIONS ──────────────────────────────────────────────────────

func _ready() -> void:
	# ── Collision layer and mask ──────────────────────────────────────────────
	collision_layer = 0
	set_collision_layer_value(2,  true)   # Layer 2: Player
	collision_mask  = 0
	set_collision_mask_value(1,  true)    # Layer 1: World (solid geometry)
	set_collision_mask_value(13, true)    # Layer 13: OneWayPlatform

	# ── Floor snap ───────────────────────────────────────────────────────────
	# Keeps the player grounded when cresting hills or slope peaks.
	# Godot disables this automatically when velocity.y < 0 (jumping upward).
	floor_snap_length = 8.0

	print("[Player] Ready — position: ", global_position)


func _physics_process(delta: float) -> void:
	_update_timers(delta)
	_read_jump_input()
	_detect_wall_slide()
	_handle_jump()
	_handle_dash_input()
	_handle_attack_input()         # ← M2.3
	_apply_gravity(delta)
	_handle_horizontal_movement()
	move_and_slide()
	_update_floor_state()

	# Compute _is_invincible from its two sources.
	# Evaluated AFTER all state changes so it reflects the final frame state.
	_is_invincible = _is_dashing or (_iframes_timer > 0.0)


# ─── TIMER MANAGEMENT ────────────────────────────────────────────────────────

func _update_timers(delta: float) -> void:
	_coyote_timer            = max(0.0, _coyote_timer            - delta)
	_jump_buffer_timer       = max(0.0, _jump_buffer_timer       - delta)
	_dash_cooldown_timer     = max(0.0, _dash_cooldown_timer     - delta)
	_wall_jump_lock_timer    = max(0.0, _wall_jump_lock_timer    - delta)
	_double_jump_flash_timer = max(0.0, _double_jump_flash_timer - delta)
	_iframes_timer           = max(0.0, _iframes_timer           - delta)
	_knockback_timer         = max(0.0, _knockback_timer         - delta)

	# Active dash duration tick
	if _is_dashing:
		_dash_timer -= delta
		if _dash_timer <= 0.0:
			_end_dash()

	# Drop-through window tick
	if _drop_through_timer > 0.0:
		_drop_through_timer -= delta
		if _drop_through_timer <= 0.0:
			_drop_through_timer = 0.0
			set_collision_mask_value(DROP_THROUGH_LAYER, true)


# ─── PUBLIC DAMAGE FUNCTION ───────────────────────────────────────────────────

## Called by hurtboxes (M4.1) and hazards (M7.6) when the player takes damage.
## amount:           HP to remove — forwarded to EventBus for health system (Phase 5)
## source_position:  world position of damage source — used to compute knockback direction.
##                   Pass Vector2.ZERO for hazards with no directional source.
func take_damage(amount: int, source_position: Vector2 = Vector2.ZERO) -> void:
	# Guard: already invincible — damage is ignored
	if _is_invincible:
		return

	# ── Cancel active attack ← NEW M2.3 ──────────────────────────────────────
	# Taking a hit interrupts any ongoing attack sequence.
	# The AnimationPlayer attack track is stopped so its callbacks don't fire
	# out of sequence (e.g. hitbox_off after the animation was interrupted).
	if _is_attacking:
		_is_attacking     = false
		_attack_direction = "neutral"
		_debug_hitbox_active = false
		var ap := get_node_or_null("AnimationPlayer") as AnimationPlayer
		if ap:
			ap.stop()

	# ── Compute knockback direction ───────────────────────────────────────────
	var knockback_dir: Vector2

	if source_position == Vector2.ZERO:
		knockback_dir = Vector2(-facing_direction, -0.5).normalized()
	else:
		knockback_dir = (global_position - source_position).normalized()

		# Enforce minimum horizontal component — avoids purely vertical knockback
		if abs(knockback_dir.x) < 0.3:
			knockback_dir.x = sign(global_position.x - source_position.x)
			if knockback_dir.x == 0.0:
				knockback_dir.x = 1.0
			knockback_dir = knockback_dir.normalized()

	# ── Apply velocity impulse ────────────────────────────────────────────────
	velocity.x           = knockback_dir.x * knockback_force
	velocity.y           = knockback_vertical_force
	_knockback_direction = knockback_dir.x

	# ── Start timers ──────────────────────────────────────────────────────────
	_knockback_timer = knockback_duration
	_iframes_timer   = iframes_duration

	# ── Cancel active dash ────────────────────────────────────────────────────
	if _is_dashing:
		_end_dash()

	# ── Notify EventBus ───────────────────────────────────────────────────────
	# Phase 5 health system, Phase 11 audio, and Phase 12 VFX all listen here
	EventBus.player_damaged.emit(amount, source_position)


## Read-only check — use this instead of reading _is_invincible directly
func is_invincible() -> bool:
	return _is_invincible


# ─── JUMP INPUT ───────────────────────────────────────────────────────────────

func _read_jump_input() -> void:
	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time


# ─── JUMP EXECUTION ───────────────────────────────────────────────────────────

func _handle_jump() -> void:
	if _is_dashing:
		return

	# Priority 1: Wall jump
	if _is_wall_sliding and _jump_buffer_timer > 0.0:
		_execute_wall_jump()
		return

	# Priority 2: Drop-through
	if is_on_floor() and Input.is_action_pressed("move_down") and _jump_buffer_timer > 0.0:
		_start_drop_through()
		return

	# Priority 3: Floor / coyote jump
	# Must be checked BEFORE double jump so coyote fires a standard jump
	# and does NOT consume _can_double_jump.
	var can_floor_jump: bool = is_on_floor() or _coyote_timer > 0.0
	var wants_to_jump: bool  = _jump_buffer_timer > 0.0

	if can_floor_jump and wants_to_jump:
		_execute_jump()
		return

	# Priority 4: Double jump
	if _can_double_jump and wants_to_jump:
		_execute_double_jump()


func _execute_jump() -> void:
	velocity.y         = jump_force
	_is_jumping        = true
	_jump_buffer_timer = 0.0
	_coyote_timer      = 0.0


func _execute_double_jump() -> void:
	# Direct assignment cancels existing vertical velocity regardless of direction
	velocity.y               = double_jump_force
	_can_double_jump         = false
	_is_jumping              = true
	_jump_buffer_timer       = 0.0
	_double_jump_flash_timer = DOUBLE_JUMP_ANIM_DURATION

func _start_drop_through() -> void:
	# Temporarily remove OneWayPlatform from collision mask
	set_collision_mask_value(DROP_THROUGH_LAYER, false)
	_drop_through_timer = DROP_THROUGH_DURATION
	velocity.y          = 80.0   # Small push to break floor contact immediately
	_jump_buffer_timer  = 0.0


# ─── WALL SLIDE ───────────────────────────────────────────────────────────────

func _detect_wall_slide() -> void:
	# Gate 1: Must be on a wall but NOT simultaneously on a floor surface
	if not is_on_wall_only():
		_is_wall_sliding = false
		_wall_normal     = Vector2.ZERO
		return

	# Gate 2: Dash overrides wall slide
	if _is_dashing:
		_is_wall_sliding = false
		return

	# Gate 3: Player must be pressing toward the wall
	# direction × wall_normal.x < 0  means pressing toward the solid surface
	var direction: float  = Input.get_axis("move_left", "move_right")
	_wall_normal          = get_wall_normal()
	var toward_wall: bool = direction * _wall_normal.x < 0

	if not toward_wall:
		_is_wall_sliding = false
		return

	# All gates passed — wall slide is active
	_is_wall_sliding = true
	facing_direction = _wall_normal.x   # Face away from wall (toward open space)


func _execute_wall_jump() -> void:
	velocity.x            = _wall_normal.x * wall_jump_horizontal_force
	velocity.y            = wall_jump_vertical_force
	_wall_jump_lock_timer = wall_jump_lock_duration
	_is_jumping           = true
	_jump_buffer_timer    = 0.0
	_is_wall_sliding      = false
	_can_air_dash         = true
	# _can_double_jump is intentionally NOT restored by wall jumps


# ─── DASH ─────────────────────────────────────────────────────────────────────

func _handle_dash_input() -> void:
	if not Input.is_action_just_pressed("dash"):  return
	if _is_dashing:                                return
	if _dash_cooldown_timer > 0.0:                 return
	if not is_on_floor() and not _can_air_dash:    return
	_start_dash()


func _start_dash() -> void:
	# ── Cancel active attack ← NEW M2.3 ──────────────────────────────────────
	# Dashing out of an attack is intentional — it is the player's escape option.
	# Stop the AnimationPlayer so hitbox callbacks don't fire after the attack ends.
	if _is_attacking:
		_is_attacking        = false
		_attack_direction    = "neutral"
		_debug_hitbox_active = false
		var ap := get_node_or_null("AnimationPlayer") as AnimationPlayer
		if ap:
			ap.stop()

	_is_dashing          = true
	_dash_timer          = dash_duration
	_dash_cooldown_timer = dash_cooldown
	_dash_direction      = facing_direction

	if not is_on_floor():
		_can_air_dash = false

	velocity.y = 0.0
	# _is_invincible is NOT set here — it is computed from _is_dashing at end of frame


func _end_dash() -> void:
	_is_dashing = false
	_dash_timer = 0.0
	# Clamp exit velocity so the player doesn't leave the dash at 500px/s
	velocity.x  = clamp(velocity.x, -move_speed, move_speed)
	# _is_invincible is NOT cleared here — computed from _is_dashing at end of frame


# ─── ATTACK ← NEW M2.3 ───────────────────────────────────────────────────────

func _handle_attack_input() -> void:
	# Gate 1: Cannot start a new attack while one is already active
	if _is_attacking:
		return

	# Gate 2: Attack button must have been JUST pressed this frame
	if not Input.is_action_just_pressed("attack"):
		return

	# ── Determine attack direction ────────────────────────────────────────────
	# Checked at the moment of button press — cannot be changed mid-attack.
	if Input.is_action_pressed("move_up"):
		_attack_direction = "up"
	elif Input.is_action_pressed("move_down") and not is_on_floor():
		# Down-slash only in the air — on the ground, down+jump = drop-through
		_attack_direction = "down"
	else:
		_attack_direction = "neutral"

	# ── Start the attack ──────────────────────────────────────────────────────
	_is_attacking = true

	# Trigger the corresponding AnimationPlayer timing track.
	# get_node_or_null is used instead of get_node to prevent crashes if the
	# AnimationPlayer node is renamed or missing during development.
	var ap := get_node_or_null("AnimationPlayer") as AnimationPlayer
	if ap:
		match _attack_direction:
			"up":   ap.play("attack_up")
			"down": ap.play("attack_down")
			_:      ap.play("attack_01")


# ─── GRAVITY ──────────────────────────────────────────────────────────────────

func _apply_gravity(delta: float) -> void:
	# Case 1: On the floor — reset residual Y velocity
	# "and not _is_jumping" prevents gravity from zeroing velocity.y on the
	# exact frame a jump fires (when the player is still touching the floor)
	if is_on_floor() and not _is_jumping:
		velocity.y = 0.0
		return

	# Case 2: Dashing — suppress gravity entirely for a horizontal dash
	if _is_dashing:
		velocity.y = 0.0
		return

	# Case 3: Wall sliding — reduced gravity for slow controlled descent
	if _is_wall_sliding:
		if velocity.y > 0.0:
			velocity.y += gravity * wall_slide_gravity_multiplier * delta
			velocity.y  = min(velocity.y, wall_slide_max_speed)
		else:
			# Rising along wall — apply normal gravity to decelerate
			velocity.y += gravity * delta
		return

	# Case 4: Airborne — select appropriate gravity curve
	var g: float
	if velocity.y > 0.0:
		g = gravity * fall_gravity_multiplier          # Falling: fast drop
	elif not Input.is_action_pressed("jump"):
		g = gravity * jump_cut_multiplier              # Rising, jump released: cut height
	else:
		g = gravity                                    # Rising, jump held: full arc

	velocity.y += g * delta
	velocity.y  = min(velocity.y, max_fall_speed)


# ─── HORIZONTAL MOVEMENT ─────────────────────────────────────────────────────

func _handle_horizontal_movement() -> void:
	# Override 1: Dash locks velocity to dash speed in the locked direction
	if _is_dashing:
		velocity.x = _dash_direction * dash_speed
		return

	# Override 2: Wall slide — no horizontal movement while pressed to wall
	if _is_wall_sliding:
		velocity.x = 0.0
		return

	# Override 3: Wall jump input lock — preserve wall jump momentum briefly
	if _wall_jump_lock_timer > 0.0:
		return

	# Override 4: Knockback control lock — preserve knockback momentum
	if _knockback_timer > 0.0:
		return

	# ── Normal movement with optional attack penalty ───────────────────────────
	# NOTE: This is the FIX from the previous version.
	# The old code set velocity.x = direction * move_speed FIRST, then set it
	# again with effective_speed below, creating a duplicate assignment.
	# Now there is exactly ONE assignment to velocity.x in this branch.
	var direction: float = Input.get_axis("move_left", "move_right")

	# Attack penalty: slow the player while swinging on the ground.
	# Air attacks do not penalise speed — full aerial control is preserved.
	var effective_speed: float = move_speed
	if _is_attacking and is_on_floor():
		effective_speed *= attack_move_penalty

	velocity.x = direction * effective_speed

	# Only update facing when actually moving — preserves last-moved direction
	# when standing still (important for attack direction detection)
	if direction != 0.0:
		facing_direction = sign(direction)


# ─── FLOOR STATE ──────────────────────────────────────────────────────────────

func _update_floor_state() -> void:
	# Ledge walk-off: grant coyote time
	if _was_on_floor and not is_on_floor() and not _is_jumping:
		_coyote_timer = coyote_time

	if is_on_floor():
		_is_jumping      = false
		_can_air_dash    = true
		_is_wall_sliding = false
		_can_double_jump = true

		# Store floor tilt angle — read by get_floor_angle() for sprite rotation
		var floor_normal: Vector2 = get_floor_normal()
		_current_floor_angle = Vector2.UP.angle_to(floor_normal)
	else:
		# Clear tilt so sprite doesn't stay rotated while airborne
		_current_floor_angle = 0.0

	_was_on_floor = is_on_floor()


# ─── PUBLIC ACCESSORS ────────────────────────────────────────────────────────
# Read-only interface for player_animation.gd and other external systems.
# External scripts call these — they never read private variables directly.

## True while the dash velocity override is active
func is_dashing() -> bool:
	return _is_dashing

## True while the player is pressed against a wall and sliding downward
func is_wall_sliding() -> bool:
	return _is_wall_sliding

## Seconds of horizontal control lock remaining after knockback (0.0 = free)
func get_knockback_timer() -> float:
	return _knockback_timer

## Seconds remaining on the double jump visual timer.
## Non-zero for 0.15s after a double jump — used for rising-edge detection.
func get_double_jump_flash_timer() -> float:
	return _double_jump_flash_timer

## Floor tilt in radians. 0.0 = flat. Used by sprite rotation in animation controller.
## Renamed from get_current_floor_angle() to match player_animation.gd expectation.
func get_current_floor_angle() -> float:
	return _current_floor_angle

## True from attack start until _on_attack_finished() fires
func is_attacking() -> bool:
	return _is_attacking

## Current attack direction: "neutral", "up", or "down"
func get_attack_direction() -> String:
	return _attack_direction


# ─── ANIMATION EVENT CALLBACKS ← NEW M2.3 ────────────────────────────────────
# Called by AnimationPlayer method tracks at precise timestamps.
# Stubs now — Phase 4 connects real hitbox Area2D, Phase 11 adds audio,
# Phase 12 adds particle spawning.

## Called at t=0.00 of every attack animation — fires the swing sound request
func _on_attack_started() -> void:
	EventBus.play_sfx_requested.emit("player_attack_swing")
	print("[Player] Attack started — direction: ", _attack_direction)


## Called at t=0.15 (ON) and t=0.25 (OFF) of attack_01 by AnimationPlayer.
## active=true: hitbox window opens.  active=false: hitbox window closes.
## Phase 4 replaces the debug flag with real Area2D.monitoring control.
func _on_attack_hitbox_active(active: bool) -> void:
	# _debug_hitbox_active is kept as a flag — Phase 4 replaces this entire
	# function body with real Area2D.monitoring control:
	#
	#   var hitbox := get_node_or_null("AttackHitbox") as Area2D
	#   if hitbox:
	#       hitbox.monitoring  = active
	#       hitbox.monitorable = active
	_debug_hitbox_active = active
	print("[Player] Hitbox active: ", active)


## Called at t=0.55 of attack_01 (t=0.28 of attack_up/down) — ends the attack state.
## Clearing _is_attacking allows _handle_attack_input() to accept a new press.
func _on_attack_finished() -> void:
	_is_attacking        = false
	_attack_direction    = "neutral"
	_debug_hitbox_active = false
	print("[Player] Attack finished")


## Called at t=0.00 of the player_land AnimationPlayer animation.
## Fires the landing sound request and will trigger dust particles in Phase 12.
func _on_land_impact() -> void:
	EventBus.play_sfx_requested.emit("player_land")
	# Phase 12: EventBus.spawn_particles_requested.emit("dust_land", global_position)
	print("[Player] Land impact")


## Universal audio proxy — AnimationPlayer cannot call EventBus directly,
## so any method track that needs to play audio calls this function instead.
## sfx_name must match a filename in assets/audio/sfx/ (without extension).
func _on_play_sfx(sfx_name: String) -> void:
	EventBus.play_sfx_requested.emit(sfx_name)
