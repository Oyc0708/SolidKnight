# player.gd
# ─────────────────────────────────────────────────────────────────────────────
# MILESTONE M1.6 — Slopes and knockback / invincibility frames
#
# New additions this milestone:
#   + knockback_force, knockback_duration, iframes_duration  @export
#   + PLACEHOLDER_HURT_COLOR  visual constant
#   + _iframes_timer, _knockback_timer, _knockback_direction  state vars
#   + _current_floor_angle  state var (used by Phase 2 sprite rotation)
#   + take_damage(amount, source_position)  PUBLIC function
#   ~ _is_invincible  now COMPUTED from _is_dashing + _iframes_timer
#   ~ _start_dash() / _end_dash()  no longer write _is_invincible directly
#   ~ _update_timers()  ticks new timers, computes _is_invincible at end
#   ~ _handle_horizontal_movement()  respects _knockback_timer lock
#   ~ _update_floor_state()  reads floor normal, stores _current_floor_angle
#   ~ _ready()  configures floor_snap_length, collision layer/mask
#   ~ _draw()  flashing during I-frames, floor angle indicator
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


# ─── EXPORTED KNOCKBACK CONSTANTS ← NEW M1.6 ─────────────────────────────────

## Speed of the knockback launch in the direction away from damage source.
## Applied as a direct velocity override when damage is taken.
@export var knockback_force: float = 380.0

## Small upward component always added to knockback.
## Gives the hit a visible bounce — makes damage feel physical.
@export var knockback_vertical_force: float = -200.0

## How long horizontal control is suppressed after taking damage (seconds).
## Player cannot walk out of the knockback during this window.
@export var knockback_duration: float = 0.25

## How long invincibility frames last after taking damage (seconds).
## Hollow Knight has approximately 1.2 seconds — quite forgiving.
## This number is tunable here without touching code.
@export var iframes_duration: float = 1.2


# ─── PHYSICS LAYER CONSTANTS ─────────────────────────────────────────────────

## Layer number for one-way (drop-through) platforms
const DROP_THROUGH_LAYER: int = 13

## How long the player phases through one-way platforms when dropping
const DROP_THROUGH_DURATION: float = 0.15


# ─── PLACEHOLDER VISUAL CONSTANTS ────────────────────────────────────────────

const PLACEHOLDER_WIDTH: int  = 32
const PLACEHOLDER_HEIGHT: int = 64
const PLACEHOLDER_COLOR: Color       = Color(0.6, 0.4, 1.0, 1.0)   # Purple (grounded)
const PLACEHOLDER_AIR_COLOR: Color   = Color(0.8, 0.6, 1.0, 1.0)   # Light purple (airborne)
const PLACEHOLDER_DASH_COLOR: Color  = Color(0.4, 1.0, 1.0, 1.0)   # Cyan (dashing)
const PLACEHOLDER_WALL_COLOR: Color  = Color(1.0, 0.6, 0.2, 1.0)   # Orange (wall sliding)
const PLACEHOLDER_HURT_COLOR: Color  = Color(1.0, 0.3, 0.3, 1.0)   # Red (taking damage) ← NEW M1.6
const PLACEHOLDER_EYE_COLOR: Color   = Color(1.0, 1.0, 1.0, 1.0)   # White eyes
const PLACEHOLDER_RING_COLOR: Color  = Color(0.9, 0.7, 1.0, 1.0)   # Double jump ring

## How long the double jump ring animation lasts (seconds)
const DOUBLE_JUMP_RING_DURATION: float = 0.15


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

var _can_double_jump: bool         = true
var _double_jump_flash_timer: float = 0.0


# ─── DROP-THROUGH STATE ───────────────────────────────────────────────────────

var _drop_through_timer: float = 0.0


# ─── INVINCIBILITY STATE ← REFACTORED M1.6 ───────────────────────────────────
# _is_invincible is now COMPUTED at the end of each physics frame:
#     _is_invincible = _is_dashing OR (_iframes_timer > 0.0)
# No function writes to this variable directly anymore.
# Read this value from outside to check if the player can take damage.
var _is_invincible: bool = false


# ─── KNOCKBACK STATE ← NEW M1.6 ──────────────────────────────────────────────

# How many seconds of invincibility frames remain after taking damage.
# When this is > 0, _is_invincible will compute to true.
var _iframes_timer: float = 0.0

# How many seconds of control suppression remain after taking damage.
# While > 0, horizontal input is locked (same technique as wall jump lock).
var _knockback_timer: float = 0.0

# The horizontal direction the player was launched on last hit: 1.0 or -1.0.
# Stored for reference — the velocity is already applied at the hit moment.
var _knockback_direction: float = 1.0


# ─── SLOPE STATE ← NEW M1.6 ──────────────────────────────────────────────────

# The angle (in radians) of the floor the player is currently standing on.
# 0.0 = perfectly flat. Positive = floor tilts right. Negative = tilts left.
# Read by AnimatedSprite2D in M2.2 to tilt the sprite to match the ground.
# Also read by this script's _draw() to tilt the placeholder visual.
var _current_floor_angle: float = 0.0


# ─── BUILT-IN FUNCTIONS ──────────────────────────────────────────────────────

func _ready() -> void:
	# ── Collision layer and mask ──────────────────────────────────────────────
	collision_layer = 0
	set_collision_layer_value(2,  true)   # Player
	collision_mask  = 0
	set_collision_mask_value(1,  true)    # World
	set_collision_mask_value(13, true)    # OneWayPlatform
	set_meta("hide_placeholder", true)

	# ── Floor snap ← NEW M1.6 ────────────────────────────────────────────────
	# Keeps the player grounded when walking over convex surfaces (slope tops).
	# Godot disables this automatically when velocity.y < 0 (jumping).
	floor_snap_length = 8.0

	queue_redraw()
	print("[Player] Ready — position: ", global_position)
	
	


func _draw() -> void:
	# ── Resolve current state → visual parameters ─────────────────────────────
	# Priority: damage flash > dash > wall slide > airborne > grounded
	# Damage flash overrides everything so it is always visible.

	var body_width: float  = float(PLACEHOLDER_WIDTH)
	var body_height: float = float(PLACEHOLDER_HEIGHT)
	var body_color: Color
	var show_eyes: bool = true

	if has_meta("hide placeholder"):
		return
		
	if _is_dashing:
		body_width  = PLACEHOLDER_WIDTH * 1.6
		body_height = PLACEHOLDER_HEIGHT * 0.75
		body_color  = PLACEHOLDER_DASH_COLOR
		show_eyes   = false
	elif _is_wall_sliding:
		body_width  = PLACEHOLDER_WIDTH * 0.55
		body_height = PLACEHOLDER_HEIGHT * 1.1
		body_color  = PLACEHOLDER_WALL_COLOR
	else:
		body_color = PLACEHOLDER_COLOR if is_on_floor() else PLACEHOLDER_AIR_COLOR

	# ── I-frame flash ← NEW M1.6 ─────────────────────────────────────────────
	# Alternate between full alpha and reduced alpha every 0.08 seconds.
	# fmod(timer, 0.16) cycles from 0 → 0.16 repeatedly.
	# When the cycle is in its first half (< 0.08), alpha is reduced.
	# This creates a fast, obvious flicker that signals vulnerability status.
	var draw_alpha: float = 1.0
	if _iframes_timer > 0.0 and not _is_dashing:
		var cycle: float = fmod(_iframes_timer, 0.16)
		if cycle < 0.08:
			draw_alpha = 0.25
			body_color = PLACEHOLDER_HURT_COLOR   # tints red on the "off" frames

	# Apply alpha to the resolved body color
	body_color.a = draw_alpha

	# ── Body offset for wall slide ────────────────────────────────────────────
	var body_x_offset: float = 0.0
	if _is_wall_sliding:
		body_x_offset = -_wall_normal.x * (body_width * 0.3)

	# ── Slope tilt ← NEW M1.6 ────────────────────────────────────────────────
	# Rotate the draw transform so the body appears to tilt with the slope.
	# draw_set_transform(position, rotation, scale) sets a local transform
	# that affects all subsequent draw calls until reset.
	# Only apply tilt when grounded and not doing something that overrides it.
	if is_on_floor() and not _is_dashing and not _is_wall_sliding:
		draw_set_transform(
			Vector2(body_x_offset, 0.0),
			_current_floor_angle,
			Vector2.ONE
		)
		# Draw with zero offset now — the transform handles positioning
		draw_rect(Rect2(-body_width / 2.0, -body_height, body_width, body_height), body_color)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)   # Reset transform
	else:
		# No tilt — draw normally
		draw_rect(
			Rect2(-body_width / 2.0 + body_x_offset, -body_height, body_width, body_height),
			body_color
		)

	# ── Wall slide streaks ────────────────────────────────────────────────────
	if _is_wall_sliding and velocity.y > 0.0:
		var mark_x: float   = -_wall_normal.x * (body_width * 0.5 + 3.0)
		var mark_color: Color = Color(1.0, 0.85, 0.5, 0.8 * draw_alpha)
		for i in range(3):
			draw_line(Vector2(mark_x - 5.0, -float(i + 1) * 14.0),
					  Vector2(mark_x + 5.0, -float(i + 1) * 14.0),
					  mark_color, 2.0)

	# ── Eyes ──────────────────────────────────────────────────────────────────
	if show_eyes:
		var eye_color: Color = Color(PLACEHOLDER_EYE_COLOR.r,
									 PLACEHOLDER_EYE_COLOR.g,
									 PLACEHOLDER_EYE_COLOR.b,
									 draw_alpha)
		var eye_x: float = facing_direction * 4.0
		var eye_y: float = -body_height * 0.7
		draw_circle(Vector2(eye_x - 5.0, eye_y), 4.0, eye_color)
		draw_circle(Vector2(eye_x + 5.0, eye_y), 4.0, eye_color)

	# ── Dash cooldown bar ─────────────────────────────────────────────────────
	if _dash_cooldown_timer > 0.0 and not _is_dashing:
		var fraction: float = 1.0 - (_dash_cooldown_timer / dash_cooldown)
		var bar_w: float    = float(PLACEHOLDER_WIDTH)
		draw_rect(Rect2(-bar_w / 2.0, 4.0, bar_w,            4.0), Color(0.15, 0.15, 0.2, 0.9))
		if fraction > 0.0:
			draw_rect(Rect2(-bar_w / 2.0, 4.0, bar_w * fraction, 4.0), Color(0.4, 1.0, 1.0, 0.9))

	# ── Double jump ring ──────────────────────────────────────────────────────
	if _double_jump_flash_timer > 0.0:
		var progress: float    = 1.0 - (_double_jump_flash_timer / DOUBLE_JUMP_RING_DURATION)
		var ring_radius: float = progress * 36.0
		var ring_alpha: float  = (1.0 - progress) * draw_alpha
		draw_arc(
			Vector2(0.0, -body_height * 0.5),
			ring_radius, 0.0, TAU, 20,
			Color(PLACEHOLDER_RING_COLOR.r, PLACEHOLDER_RING_COLOR.g,
				  PLACEHOLDER_RING_COLOR.b, ring_alpha),
			2.5
		)

	# ── Floor angle indicator ← NEW M1.6 ─────────────────────────────────────
	# Small yellow line below the feet showing the current floor normal direction.
	# Only visible when on a non-flat surface (angle > ~1°).
	# This will be removed when sprites replace the placeholder in Phase 2.
	if is_on_floor() and abs(_current_floor_angle) > 0.02:
		var normal_x: float = sin(_current_floor_angle) * -16.0
		var normal_y: float = cos(_current_floor_angle) * -16.0
		draw_line(
			Vector2.ZERO,
			Vector2(normal_x, normal_y),
			Color(1.0, 0.95, 0.2, 0.7),
			2.0
		)


func _physics_process(delta: float) -> void:
	_update_timers(delta)
	_read_jump_input()
	_detect_wall_slide()
	_handle_jump()
	_handle_dash_input()
	_apply_gravity(delta)
	_handle_horizontal_movement()
	move_and_slide()
	_update_floor_state()

	# ── Compute _is_invincible from its two sources ← REFACTORED M1.6 ────────
	# This line replaces all direct writes to _is_invincible across the script.
	# Evaluated AFTER all state changes this frame so it reflects the final state.
	_is_invincible = _is_dashing or (_iframes_timer > 0.0)

	queue_redraw()


# ─── TIMER MANAGEMENT ← MODIFIED M1.6 ────────────────────────────────────────

func _update_timers(delta: float) -> void:
	_coyote_timer            = max(0.0, _coyote_timer            - delta)
	_jump_buffer_timer       = max(0.0, _jump_buffer_timer       - delta)
	_dash_cooldown_timer     = max(0.0, _dash_cooldown_timer     - delta)
	_wall_jump_lock_timer    = max(0.0, _wall_jump_lock_timer    - delta)
	_double_jump_flash_timer = max(0.0, _double_jump_flash_timer - delta)
	_iframes_timer           = max(0.0, _iframes_timer           - delta)   # ← NEW M1.6
	_knockback_timer         = max(0.0, _knockback_timer         - delta)   # ← NEW M1.6

	# Active dash duration
	if _is_dashing:
		_dash_timer -= delta
		if _dash_timer <= 0.0:
			_end_dash()

	# Drop-through window
	if _drop_through_timer > 0.0:
		_drop_through_timer -= delta
		if _drop_through_timer <= 0.0:
			_drop_through_timer = 0.0
			set_collision_mask_value(DROP_THROUGH_LAYER, true)


# ─── PUBLIC DAMAGE FUNCTION ← NEW M1.6 ───────────────────────────────────────

## Called by hurtboxes (M4.1) and hazards (M7.6) when the player takes damage.
## amount:          how much HP to remove — passed to EventBus for the health system (Phase 5)
## source_position: world position of the damage source — used to compute knockback direction
##                  Defaults to Vector2.ZERO for hazards with no clear source position.
func take_damage(amount: int, source_position: Vector2 = Vector2.ZERO) -> void:
	# ── Guard: already invincible (dashing or in I-frames) ───────────────────
	# If the player is currently protected, the damage is ignored entirely.
	# This check reads the PREVIOUS frame's _is_invincible because the current
	# frame's value is computed at the END of _physics_process(). That is fine —
	# one frame of lag is imperceptible and avoids a more complex evaluation order.
	if _is_invincible:
		return

	# ── Compute knockback direction ───────────────────────────────────────────
	var knockback_dir: Vector2

	if source_position == Vector2.ZERO:
		# No source position provided (e.g. walked into a spike).
		# Push the player backward relative to their facing direction.
		knockback_dir = Vector2(-facing_direction, -0.5).normalized()
	else:
		# Direction FROM source TO player (push player away from source).
		knockback_dir = (global_position - source_position).normalized()

		# Enforce minimum horizontal component.
		# Without this, a hit from directly below sends the player straight up
		# with no horizontal arc — looks floaty and unintentional.
		if abs(knockback_dir.x) < 0.3:
			knockback_dir.x = sign(global_position.x - source_position.x)
			if knockback_dir.x == 0.0:
				knockback_dir.x = 1.0
			knockback_dir = knockback_dir.normalized()

	# ── Apply velocity impulse ────────────────────────────────────────────────
	# Horizontal: full knockback_force in the computed direction.
	# Vertical: fixed upward component regardless of direction.
	# We use direct assignment (not +=) so existing momentum doesn't
	# stack with knockback — the hit should override whatever the player was doing.
	velocity.x = knockback_dir.x * knockback_force
	velocity.y = knockback_vertical_force

	# Cache the direction for any system that wants to read it later
	_knockback_direction = knockback_dir.x

	# ── Start control lock ────────────────────────────────────────────────────
	_knockback_timer = knockback_duration

	# ── Start I-frames ────────────────────────────────────────────────────────
	# _is_invincible will be recomputed at the end of this frame to true.
	_iframes_timer = iframes_duration

	# ── Cancel any active dash ────────────────────────────────────────────────
	# Taking a hit while dashing ends the dash. The knockback replaces it.
	if _is_dashing:
		_end_dash()

	# ── Notify the EventBus ──────────────────────────────────────────────────
	# Phase 5 health system listens for this signal and subtracts HP.
	# VFX (Phase 12) and Audio (Phase 11) also listen for screen flash and hurt sound.
	EventBus.player_damaged.emit(amount, source_position)


## Read-only accessor for external systems (hurtbox, enemy AI) to check
## if the player can currently be damaged. Do not write _is_invincible directly.
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
	velocity.y               = double_jump_force
	_can_double_jump         = false
	_is_jumping              = true
	_jump_buffer_timer       = 0.0
	_double_jump_flash_timer = DOUBLE_JUMP_RING_DURATION


func _start_drop_through() -> void:
	set_collision_mask_value(DROP_THROUGH_LAYER, false)
	_drop_through_timer = DROP_THROUGH_DURATION
	velocity.y          = 80.0
	_jump_buffer_timer  = 0.0


# ─── WALL SLIDE ───────────────────────────────────────────────────────────────

func _detect_wall_slide() -> void:
	if not is_on_wall_only():
		_is_wall_sliding = false
		_wall_normal     = Vector2.ZERO
		return
	if _is_dashing:
		_is_wall_sliding = false
		return

	var direction: float  = Input.get_axis("move_left", "move_right")
	_wall_normal          = get_wall_normal()
	var toward_wall: bool = direction * _wall_normal.x < 0

	if not toward_wall:
		_is_wall_sliding = false
		return

	_is_wall_sliding = true
	facing_direction = _wall_normal.x


func _execute_wall_jump() -> void:
	velocity.x            = _wall_normal.x * wall_jump_horizontal_force
	velocity.y            = wall_jump_vertical_force
	_wall_jump_lock_timer = wall_jump_lock_duration
	_is_jumping           = true
	_jump_buffer_timer    = 0.0
	_is_wall_sliding      = false
	_can_air_dash         = true


# ─── DASH ─────────────────────────────────────────────────────────────────────

func _handle_dash_input() -> void:
	if not Input.is_action_just_pressed("dash"):  return
	if _is_dashing:                                return
	if _dash_cooldown_timer > 0.0:                 return
	if not is_on_floor() and not _can_air_dash:    return
	_start_dash()


func _start_dash() -> void:
	_is_dashing          = true
	_dash_timer          = dash_duration
	_dash_cooldown_timer = dash_cooldown
	_dash_direction      = facing_direction
	if not is_on_floor():
		_can_air_dash = false
	velocity.y           = 0.0
	# Note: _is_invincible is no longer set here — computed from _is_dashing


func _end_dash() -> void:
	_is_dashing = false
	_dash_timer = 0.0
	velocity.x  = clamp(velocity.x, -move_speed, move_speed)
	# Note: _is_invincible is no longer cleared here — computed from _is_dashing


# ─── GRAVITY ──────────────────────────────────────────────────────────────────

func _apply_gravity(delta: float) -> void:
	if is_on_floor() and not _is_jumping:
		velocity.y = 0.0
		return
	if _is_dashing:
		velocity.y = 0.0
		return
	if _is_wall_sliding:
		if velocity.y > 0.0:
			velocity.y += gravity * wall_slide_gravity_multiplier * delta
			velocity.y  = min(velocity.y, wall_slide_max_speed)
		else:
			velocity.y += gravity * delta
		return

	var g: float
	if velocity.y > 0.0:
		g = gravity * fall_gravity_multiplier
	elif not Input.is_action_pressed("jump"):
		g = gravity * jump_cut_multiplier
	else:
		g = gravity

	velocity.y += g * delta
	velocity.y  = min(velocity.y, max_fall_speed)


# ─── HORIZONTAL MOVEMENT ← MODIFIED M1.6 ─────────────────────────────────────

func _handle_horizontal_movement() -> void:
	if _is_dashing:
		velocity.x = _dash_direction * dash_speed
		return
	if _is_wall_sliding:
		velocity.x = 0.0
		return
	if _wall_jump_lock_timer > 0.0:
		return

	# ── Knockback control lock ← NEW M1.6 ────────────────────────────────────
	# During knockback, suppress horizontal input entirely.
	# The knockback velocity applied in take_damage() carries the player.
	# Without this, the player's held direction immediately cancels knockback —
	# a skilled player would never feel the impact.
	if _knockback_timer > 0.0:
		return

	var direction: float = Input.get_axis("move_left", "move_right")
	velocity.x = direction * move_speed

	if direction != 0.0:
		facing_direction = sign(direction)


# ─── FLOOR STATE ← MODIFIED M1.6 ─────────────────────────────────────────────

func _update_floor_state() -> void:
	# Ledge walk-off → coyote window
	if _was_on_floor and not is_on_floor() and not _is_jumping:
		_coyote_timer = coyote_time

	if is_on_floor():
		_is_jumping      = false
		_can_air_dash    = true
		_is_wall_sliding = false
		_can_double_jump = true

		# ── Read and store the floor angle ← NEW M1.6 ─────────────────────────
		# get_floor_normal() returns the outward normal of the surface under the player.
		# angle_to() returns the signed angle from Vector2.UP to that normal.
		# Flat floor: normal = (0,-1) = Vector2.UP → angle = 0.0
		# Left slope: normal tilts right → angle is positive
		# Right slope: normal tilts left → angle is negative
		var floor_normal: Vector2 = get_floor_normal()
		_current_floor_angle = Vector2.UP.angle_to(floor_normal)
	else:
		# Not on floor — clear the stored angle so the sprite doesn't
		# stay tilted while airborne
		_current_floor_angle = 0.0

	_was_on_floor = is_on_floor()
