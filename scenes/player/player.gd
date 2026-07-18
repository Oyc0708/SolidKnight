# player.gd
# ─────────────────────────────────────────────────────────────────────────────
# MILESTONE M1.5 — Double jump and drop-through platforms
#
# New additions this milestone:
#   + double_jump_force  @export constant
#   + DROP_THROUGH_LAYER, DROP_THROUGH_DURATION  constants
#   + _can_double_jump, _double_jump_flash_timer, _drop_through_timer  state vars
#   + PLACEHOLDER_RING_COLOR  visual constant
#   + _execute_double_jump(), _start_drop_through()  new functions
#   ~ _ready(): sets collision layer and mask via code
#   ~ _update_timers(): ticks flash and drop-through timers
#   ~ _handle_jump(): drop-through and double jump inserted at correct priority
#   ~ _update_floor_state(): restores _can_double_jump on landing
#   ~ _draw(): expanding ring animation on double jump
# ─────────────────────────────────────────────────────────────────────────────
class_name PlayerController
extends CharacterBody2D


# ─── EXPORTED MOVEMENT CONSTANTS ─────────────────────────────────────────────

## Horizontal movement speed (pixels per second)
@export var move_speed: float = 180.0

## Base gravity when rising with jump held (pixels per second squared)
@export var gravity: float = 1800.0


# ─── EXPORTED JUMP CONSTANTS ─────────────────────────────────────────────────

## Upward velocity applied on a regular jump (negative = up)
@export var jump_force: float = -700.0

## Gravity multiplier while falling
@export var fall_gravity_multiplier: float = 2.5

## Gravity multiplier while rising with jump released (jump cut)
@export var jump_cut_multiplier: float = 3.5

## Terminal falling velocity — prevents tunnelling
@export var max_fall_speed: float = 800.0

## Seconds after leaving a ledge that a jump still fires
@export var coyote_time: float = 0.12

## Seconds a jump input is stored before landing
@export var jump_buffer_time: float = 0.10


# ─── EXPORTED DASH CONSTANTS ─────────────────────────────────────────────────

## Velocity override during dash (pixels per second)
@export var dash_speed: float = 500.0

## Duration of the dash (seconds)
@export var dash_duration: float = 0.18

## Minimum time between dashes (seconds)
@export var dash_cooldown: float = 0.50


# ─── EXPORTED WALL CONSTANTS ─────────────────────────────────────────────────

## Fraction of normal gravity while sliding down a wall
@export var wall_slide_gravity_multiplier: float = 0.12

## Maximum downward speed while wall sliding (pixels per second)
@export var wall_slide_max_speed: float = 60.0

## Horizontal force away from wall on wall jump (pixels per second)
@export var wall_jump_horizontal_force: float = 250.0

## Upward force on wall jump (pixels per second)
@export var wall_jump_vertical_force: float = -650.0

## How long horizontal input is locked after a wall jump (seconds)
@export var wall_jump_lock_duration: float = 0.20


# ─── EXPORTED DOUBLE JUMP CONSTANTS ← NEW M1.5 ───────────────────────────────

## Upward velocity applied on the double jump.
## Slightly lower than jump_force (700) to feel like a secondary ability.
## Tap for a small hop, hold for the full arc — same variable-height system applies.
@export var double_jump_force: float = -600.0


# ─── PHYSICS LAYER CONSTANTS ← NEW M1.5 ──────────────────────────────────────

## The collision layer number of OneWayPlatform bodies.
## Must match Layer 13 as defined in Project Settings → Layer Names → 2D Physics.
## This constant is used to toggle platform collision for drop-through.
const DROP_THROUGH_LAYER: int = 13

## How long the player ignores OneWayPlatform collision when dropping through.
## Must be long enough to clear the platform geometry (20px at initial velocity ≈ 0.10s).
## 0.15s gives comfortable margin.
const DROP_THROUGH_DURATION: float = 0.15


# ─── PLACEHOLDER VISUAL CONSTANTS ────────────────────────────────────────────

const PLACEHOLDER_WIDTH: int = 32
const PLACEHOLDER_HEIGHT: int = 64
const PLACEHOLDER_COLOR: Color        = Color(0.6, 0.4, 1.0, 1.0)
const PLACEHOLDER_AIR_COLOR: Color    = Color(0.8, 0.6, 1.0, 1.0)
const PLACEHOLDER_DASH_COLOR: Color   = Color(0.4, 1.0, 1.0, 1.0)
const PLACEHOLDER_WALL_COLOR: Color   = Color(1.0, 0.6, 0.2, 1.0)
const PLACEHOLDER_EYE_COLOR: Color    = Color(1.0, 1.0, 1.0, 1.0)

## ← NEW M1.5: Color of the expanding ring drawn on double jump
const PLACEHOLDER_RING_COLOR: Color   = Color(0.9, 0.7, 1.0, 1.0)


# ─── FACING STATE ─────────────────────────────────────────────────────────────

var facing_direction: float = 1.0


# ─── JUMP STATE ───────────────────────────────────────────────────────────────

var _is_jumping: bool          = false
var _was_on_floor: bool        = false
var _coyote_timer: float       = 0.0
var _jump_buffer_timer: float  = 0.0


# ─── DASH STATE ───────────────────────────────────────────────────────────────

var _is_dashing: bool           = false
var _dash_timer: float          = 0.0
var _dash_cooldown_timer: float = 0.0
var _dash_direction: float      = 1.0
var _can_air_dash: bool         = true
var _is_invincible: bool        = false


# ─── WALL SLIDE STATE ─────────────────────────────────────────────────────────

var _is_wall_sliding: bool   = false
var _wall_normal: Vector2    = Vector2.ZERO
var _wall_jump_lock_timer: float = 0.0


# ─── DOUBLE JUMP STATE ← NEW M1.5 ────────────────────────────────────────────

# Set to false when the double jump is used, restored when the player lands.
# Deliberately NOT restored by wall jumps — landing is the only reset.
var _can_double_jump: bool = true

# Counts down from 0.15 after a double jump fires.
# While > 0, an expanding ring is drawn in _draw() as visual feedback.
# This is a placeholder for the particle effect added in Phase 12.
var _double_jump_flash_timer: float = 0.0

## The duration of the double jump visual ring, in seconds.
## Separate from the jump mechanics — purely cosmetic timing.
const DOUBLE_JUMP_RING_DURATION: float = 0.15


# ─── DROP-THROUGH STATE ← NEW M1.5 ───────────────────────────────────────────

# Counts down from DROP_THROUGH_DURATION after the player initiates a drop.
# While > 0, Layer 13 (OneWayPlatform) is excluded from the collision mask.
# When it reaches 0, Layer 13 is re-added to the mask.
var _drop_through_timer: float = 0.0


# ─── BUILT-IN FUNCTIONS ──────────────────────────────────────────────────────

func _ready() -> void:
	# ── Set collision layer and mask in code ──────────────────────────────────
	# This ensures the correct setup regardless of Inspector values.
	# Done here rather than relying on Inspector alone so it is version-controlled
	# in this script and self-documenting.

	# LAYER: this body IS on Layer 2 (Player)
	# Other systems (enemy hitboxes) will check "did I hit something on Layer 2?"
	collision_layer = 0                      # Clear all bits first
	set_collision_layer_value(2, true)       # Set Layer 2: Player

	# MASK: this body DETECTS these layers for move_and_slide()
	collision_mask = 0                       # Clear all bits first
	set_collision_mask_value(1, true)        # Detect Layer 1: World (solid geometry)
	set_collision_mask_value(13, true)       # Detect Layer 13: OneWayPlatform

	queue_redraw()
	print("[Player] Ready — position: ", global_position)


func _draw() -> void:
	# ── Resolve visual state (priority: dash > wall > double-jump > air > ground) ─

	var body_width: float  = float(PLACEHOLDER_WIDTH)
	var body_height: float = float(PLACEHOLDER_HEIGHT)
	var body_color: Color
	var show_eyes: bool    = true

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

	# ── Body ─────────────────────────────────────────────────────────────────
	var body_x_offset: float = 0.0
	if _is_wall_sliding:
		body_x_offset = -_wall_normal.x * (body_width * 0.3)

	draw_rect(
		Rect2(-body_width / 2.0 + body_x_offset, -body_height, body_width, body_height),
		body_color
	)

	# ── Wall slide streaks ────────────────────────────────────────────────────
	if _is_wall_sliding and velocity.y > 0.0:
		var mark_x: float   = -_wall_normal.x * (body_width * 0.5 + 3.0)
		var mark_color: Color = Color(1.0, 0.85, 0.5, 0.8)
		for i in range(3):
			var mark_y: float = -float(i + 1) * 14.0
			draw_line(Vector2(mark_x - 5.0, mark_y), Vector2(mark_x + 5.0, mark_y), mark_color, 2.0)

	# ── Eyes ──────────────────────────────────────────────────────────────────
	if show_eyes:
		var eye_x: float = facing_direction * 4.0
		var eye_y: float = -body_height * 0.7
		draw_circle(Vector2(eye_x - 5.0, eye_y), 4.0, PLACEHOLDER_EYE_COLOR)
		draw_circle(Vector2(eye_x + 5.0, eye_y), 4.0, PLACEHOLDER_EYE_COLOR)

	# ── Dash cooldown bar ─────────────────────────────────────────────────────
	if _dash_cooldown_timer > 0.0 and not _is_dashing:
		var fraction: float = 1.0 - (_dash_cooldown_timer / dash_cooldown)
		var bar_w: float    = float(PLACEHOLDER_WIDTH)
		draw_rect(Rect2(-bar_w / 2.0, 4.0, bar_w,            4.0), Color(0.15, 0.15, 0.2, 0.9))
		if fraction > 0.0:
			draw_rect(Rect2(-bar_w / 2.0, 4.0, bar_w * fraction, 4.0), Color(0.4, 1.0, 1.0, 0.9))

	# ── Double jump expanding ring ← NEW M1.5 ─────────────────────────────────
	# Drawn AFTER the body so it appears on top.
	# The ring expands outward and fades to zero alpha over DOUBLE_JUMP_RING_DURATION.
	# progress: 0.0 at jump moment (ring small) → 1.0 at end (ring large and invisible)
	if _double_jump_flash_timer > 0.0:
		var progress: float = 1.0 - (_double_jump_flash_timer / DOUBLE_JUMP_RING_DURATION)
		var ring_radius: float = progress * 36.0              # Expands from 0 → 36 pixels
		var ring_alpha: float  = 1.0 - progress               # Fades from 1.0 → 0.0

		# draw_arc(center, radius, start_angle, end_angle, point_count, color, width)
		# TAU = 2π = full circle
		# Center is the player's mid-body (halfway up the height)
		draw_arc(
			Vector2(0.0, -body_height * 0.5),
			ring_radius,
			0.0,
			TAU,
			20,
			Color(PLACEHOLDER_RING_COLOR.r, PLACEHOLDER_RING_COLOR.g, PLACEHOLDER_RING_COLOR.b, ring_alpha),
			2.5
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
	queue_redraw()


# ─── TIMER MANAGEMENT ← MODIFIED M1.5 ────────────────────────────────────────

func _update_timers(delta: float) -> void:
	_coyote_timer         = max(0.0, _coyote_timer         - delta)
	_jump_buffer_timer    = max(0.0, _jump_buffer_timer    - delta)
	_dash_cooldown_timer  = max(0.0, _dash_cooldown_timer  - delta)
	_wall_jump_lock_timer = max(0.0, _wall_jump_lock_timer - delta)

	# ── Double jump ring timer ← NEW M1.5 ────────────────────────────────────
	_double_jump_flash_timer = max(0.0, _double_jump_flash_timer - delta)

	# ── Dash duration ─────────────────────────────────────────────────────────
	if _is_dashing:
		_dash_timer -= delta
		if _dash_timer <= 0.0:
			_end_dash()

	# ── Drop-through timer ← NEW M1.5 ────────────────────────────────────────
	# While active, Layer 13 is disabled in the collision mask.
	# When it reaches 0, re-enable Layer 13 so future platform landings work.
	if _drop_through_timer > 0.0:
		_drop_through_timer -= delta
		if _drop_through_timer <= 0.0:
			_drop_through_timer = 0.0
			# Re-enable OneWayPlatform collision
			# The player is now below the platform surface, so one-way
			# collision from below does not block them — safe to re-enable.
			set_collision_mask_value(DROP_THROUGH_LAYER, true)


# ─── JUMP INPUT ───────────────────────────────────────────────────────────────

func _read_jump_input() -> void:
	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time


# ─── JUMP EXECUTION ← MODIFIED M1.5 ─────────────────────────────────────────

func _handle_jump() -> void:
	# ── Guard: no jump during active dash ────────────────────────────────────
	if _is_dashing:
		return

	# ── Priority 1: Wall jump (highest) ─────────────────────────────────────
	if _is_wall_sliding and _jump_buffer_timer > 0.0:
		_execute_wall_jump()
		return

	# ── Priority 2: Drop-through ← NEW M1.5 ──────────────────────────────────
	# Condition: on a floor surface AND Down is held AND jump was pressed.
	# We check is_on_floor() first so this never fires in the air.
	# is_action_pressed() (not just_pressed) for Down because the player
	# may have been holding Down before pressing Jump.
	if is_on_floor() and Input.is_action_pressed("move_down") and _jump_buffer_timer > 0.0:
		_start_drop_through()
		return

	# ── Priority 3: Floor / coyote jump ──────────────────────────────────────
	# This MUST be checked before double jump so that coyote time fires
	# a standard jump and does NOT consume _can_double_jump.
	var can_floor_jump: bool  = is_on_floor() or _coyote_timer > 0.0
	var wants_to_jump: bool   = _jump_buffer_timer > 0.0

	if can_floor_jump and wants_to_jump:
		_execute_jump()
		return

	# ── Priority 4: Double jump ← NEW M1.5 ───────────────────────────────────
	# Only reached when: airborne, coyote expired, not wall sliding, buffer active.
	# _can_double_jump is false after use until next landing.
	if _can_double_jump and wants_to_jump:
		_execute_double_jump()


func _execute_jump() -> void:
	## Standard floor/coyote jump — extracted to a named function for clarity
	## because _execute_double_jump() is now a sibling and the two should be distinct.
	velocity.y         = jump_force
	_is_jumping        = true
	_jump_buffer_timer = 0.0
	_coyote_timer      = 0.0


func _execute_double_jump() -> void:
	## ← NEW M1.5
	## Direct assignment cancels any existing vertical velocity.
	## The same variable-height system applies: tap = small arc, hold = full arc.

	# Replace whatever vertical velocity exists with the double jump force.
	# If falling at +600: becomes -600 (full reversal). ✓
	# If rising at -200: becomes -600 (boosted). ✓
	velocity.y = double_jump_force

	# Consume the ability — restored only on landing (not wall jumps)
	_can_double_jump = false

	# Mark as jumping — prevents coyote timer starting if we somehow
	# trigger floor-leave detection this same frame
	_is_jumping = true

	# Consume the jump buffer
	_jump_buffer_timer = 0.0

	# Start the visual ring timer
	_double_jump_flash_timer = DOUBLE_JUMP_RING_DURATION


func _start_drop_through() -> void:
	## ← NEW M1.5
	## Temporarily removes OneWayPlatform from the collision mask
	## so the player falls through it. Solid geometry (Layer 1) is unaffected.

	# Remove OneWayPlatform from the collision mask.
	# move_and_slide() will now ignore Layer-13 bodies this frame and until
	# _drop_through_timer expires and re-enables it in _update_timers().
	set_collision_mask_value(DROP_THROUGH_LAYER, false)

	# Start the drop-through window.
	# _update_timers() ticks this down and calls set_collision_mask_value(13, true)
	# when it expires.
	_drop_through_timer = DROP_THROUGH_DURATION

	# Apply a small downward push to immediately break floor contact.
	# Without this, the player might remain "on floor" for 1-2 frames
	# before gravity moves them through the now-disabled platform.
	# 80 px/s is subtle but enough to trigger the fall.
	velocity.y = 80.0

	# Consume the jump buffer so a normal jump does not fire this same frame.
	_jump_buffer_timer = 0.0


# ─── WALL SLIDE ───────────────────────────────────────────────────────────────

func _detect_wall_slide() -> void:
	if not is_on_wall_only():
		_is_wall_sliding = false
		_wall_normal     = Vector2.ZERO
		return

	if _is_dashing:
		_is_wall_sliding = false
		return

	var direction: float = Input.get_axis("move_left", "move_right")
	_wall_normal = get_wall_normal()

	var pressing_toward_wall: bool = direction * _wall_normal.x < 0

	if not pressing_toward_wall:
		_is_wall_sliding = false
		return

	_is_wall_sliding  = true
	facing_direction  = _wall_normal.x


func _execute_wall_jump() -> void:
	velocity.x             = _wall_normal.x * wall_jump_horizontal_force
	velocity.y             = wall_jump_vertical_force
	_wall_jump_lock_timer  = wall_jump_lock_duration
	_is_jumping            = true
	_jump_buffer_timer     = 0.0
	_is_wall_sliding       = false
	_can_air_dash          = true
	# NOTE: _can_double_jump is NOT restored by wall jumps.
	# Double jump only resets on floor landing.


# ─── DASH ─────────────────────────────────────────────────────────────────────

func _handle_dash_input() -> void:
	if not Input.is_action_just_pressed("dash"):
		return
	if _is_dashing:
		return
	if _dash_cooldown_timer > 0.0:
		return
	if not is_on_floor() and not _can_air_dash:
		return
	_start_dash()


func _start_dash() -> void:
	_is_dashing          = true
	_dash_timer          = dash_duration
	_dash_cooldown_timer = dash_cooldown
	_dash_direction      = facing_direction
	if not is_on_floor():
		_can_air_dash = false
	velocity.y           = 0.0
	_is_invincible       = true


func _end_dash() -> void:
	_is_dashing    = false
	_dash_timer    = 0.0
	_is_invincible = false
	velocity.x     = clamp(velocity.x, -move_speed, move_speed)


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

	var current_gravity: float

	if velocity.y > 0.0:
		current_gravity = gravity * fall_gravity_multiplier
	elif not Input.is_action_pressed("jump"):
		current_gravity = gravity * jump_cut_multiplier
	else:
		current_gravity = gravity

	velocity.y += current_gravity * delta
	velocity.y  = min(velocity.y, max_fall_speed)


# ─── HORIZONTAL MOVEMENT ──────────────────────────────────────────────────────

func _handle_horizontal_movement() -> void:
	if _is_dashing:
		velocity.x = _dash_direction * dash_speed
		return

	if _is_wall_sliding:
		velocity.x = 0.0
		return

	if _wall_jump_lock_timer > 0.0:
		return

	var direction: float = Input.get_axis("move_left", "move_right")
	velocity.x = direction * move_speed

	if direction != 0.0:
		facing_direction = sign(direction)


# ─── FLOOR STATE ← MODIFIED M1.5 ─────────────────────────────────────────────

func _update_floor_state() -> void:
	# Ledge walk-off → coyote window
	if _was_on_floor and not is_on_floor() and not _is_jumping:
		_coyote_timer = coyote_time

	# Landing → restore all air abilities
	if is_on_floor():
		_is_jumping      = false
		_can_air_dash    = true
		_is_wall_sliding = false
		_can_double_jump = true   # ← NEW M1.5: double jump restored on landing only

	_was_on_floor = is_on_floor()
