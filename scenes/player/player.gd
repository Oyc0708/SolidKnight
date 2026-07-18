# player.gd
# ─────────────────────────────────────────────────────────────────────────────
# MILESTONE M1.2 — Variable jump, gravity curves, coyote time, jump buffer
#
# Changes from M1.1:
#   + jump_force, fall_gravity_multiplier, jump_cut_multiplier, max_fall_speed
#   + coyote_time, jump_buffer_time @export variables
#   + _is_jumping, _was_on_floor state variables
#   + _coyote_timer, _jump_buffer_timer countdown floats
#   + _update_timers(), _read_jump_input(), _handle_jump(), _update_floor_state()
#   ~ _apply_gravity() now uses multipliers instead of flat gravity
#   ~ _physics_process() call order updated
# ─────────────────────────────────────────────────────────────────────────────
class_name PlayerController
extends CharacterBody2D


# ─── EXPORTED MOVEMENT CONSTANTS ─────────────────────────────────────────────
## How fast the player moves horizontally (pixels per second)
@export var move_speed: float = 180.0

## Base gravity when rising with jump held (pixels per second squared)
## This is the MINIMUM gravity. Multipliers scale up from here.
@export var gravity: float = 1800.0


# ─── EXPORTED JUMP CONSTANTS ─────────────────────────────────────────────────
## ← NEW M1.2
## Upward velocity applied on jump (negative = upward in Godot)
## Derived: height = jump_force² ÷ (2 × gravity) = 700²÷3600 ≈ 136 pixels
@export var jump_force: float = -700.0

## ← NEW M1.2
## Gravity multiplier when falling (velocity.y > 0)
## 2.5 means falling feels noticeably snappier than rising
@export var fall_gravity_multiplier: float = 2.5

## ← NEW M1.2
## Gravity multiplier when RISING but jump button is RELEASED
## Higher value = jump height is cut more aggressively on tap
@export var jump_cut_multiplier: float = 3.5

## ← NEW M1.2
## Maximum downward speed (terminal velocity), pixels per second
## Prevents enormous velocity buildup during long falls
## which could cause the player to tunnel through thin floors
@export var max_fall_speed: float = 800.0

## ← NEW M1.2
## Seconds after leaving a floor that the player can still jump
## 0.12 is the industry-standard sweet spot: noticeable but not exploitable
@export var coyote_time: float = 0.12

## ← NEW M1.2
## Seconds a jump input is remembered before landing
## "I pressed jump just before I landed" is honoured within this window
@export var jump_buffer_time: float = 0.10


# ─── PLACEHOLDER VISUAL CONSTANTS ────────────────────────────────────────────
# Unchanged from M1.1 — removed in Phase 2 when real sprites are added
const PLACEHOLDER_WIDTH: int = 32
const PLACEHOLDER_HEIGHT: int = 64
const PLACEHOLDER_COLOR: Color = Color(0.6, 0.4, 1.0, 1.0)
const PLACEHOLDER_AIR_COLOR: Color = Color(0.8, 0.6, 1.0, 1.0)  # ← NEW M1.2 lighter when airborne
const PLACEHOLDER_EYE_COLOR: Color = Color(1.0, 1.0, 1.0, 1.0)


# ─── STATE VARIABLES ──────────────────────────────────────────────────────────
# Which horizontal direction the player last faced:  1.0 = right,  -1.0 = left
var facing_direction: float = 1.0

## ← NEW M1.2
## True from the moment of a jump press until the player lands again.
## Used to prevent coyote time activating after a deliberate jump
## (we only want coyote time when the player WALKS off a ledge, not jumps off)
var _is_jumping: bool = false

## ← NEW M1.2
## Stores is_on_floor() from the END of the previous frame.
## We compare it to the current frame's is_on_floor() to detect the
## exact moment the player steps off a ledge → that is when we
## start the coyote timer.
var _was_on_floor: bool = false

## ← NEW M1.2
## Counts DOWN from coyote_time to 0.0 after leaving the floor.
## While > 0, the player may still execute a jump.
var _coyote_timer: float = 0.0

## ← NEW M1.2
## Counts DOWN from jump_buffer_time to 0.0 after pressing jump.
## While > 0, the player WANTS to jump — executed on the next valid landing.
var _jump_buffer_timer: float = 0.0


# ─── BUILT-IN FUNCTIONS ──────────────────────────────────────────────────────

func _ready() -> void:
	queue_redraw()
	print("[Player] Ready — position: ", global_position)


func _draw() -> void:
	# ← MODIFIED M1.2: color changes when airborne for visual feedback
	var body_color: Color = PLACEHOLDER_COLOR if is_on_floor() else PLACEHOLDER_AIR_COLOR

	# Body rectangle — feet sit at Y=0 (this node's local origin)
	var body_rect := Rect2(
		-PLACEHOLDER_WIDTH / 2.0,
		-PLACEHOLDER_HEIGHT,
		PLACEHOLDER_WIDTH,
		PLACEHOLDER_HEIGHT
	)
	draw_rect(body_rect, body_color)

	# Eyes — shift toward facing direction
	var eye_x_offset: float = facing_direction * 4.0
	var eye_y: float = -PLACEHOLDER_HEIGHT * 0.7

	draw_circle(Vector2(eye_x_offset - 5.0, eye_y), 4.0, PLACEHOLDER_EYE_COLOR)
	draw_circle(Vector2(eye_x_offset + 5.0, eye_y), 4.0, PLACEHOLDER_EYE_COLOR)


func _physics_process(delta: float) -> void:
	# ── Call order is deliberate — do not reorder without understanding why ──
	#
	# 1. Timers count down first — they must be current before any check uses them
	# 2. Jump input is READ and buffered
	# 3. Jump is EXECUTED (before gravity, so jump_force is applied cleanly)
	# 4. Gravity is applied (now uses correct multiplier based on current velocity)
	# 5. Horizontal movement is applied
	# 6. move_and_slide() resolves all physics and updates is_on_floor()
	# 7. Floor state is updated for the NEXT frame (coyote, was_on_floor, landing)
	# 8. queue_redraw() requests a visual update (color change on floor state change)

	_update_timers(delta)
	_read_jump_input()
	_handle_jump()
	_apply_gravity(delta)
	_handle_horizontal_movement()
	move_and_slide()
	_update_floor_state()
	queue_redraw()


# ─── PRIVATE FUNCTIONS ────────────────────────────────────────────────────────

func _update_timers(delta: float) -> void:
	## ← NEW M1.2
	## Count both timers down toward zero every physics frame.
	## max(0.0, ...) prevents them going negative — a negative timer
	## is meaningless and could theoretically cause edge-case bugs.

	_coyote_timer = max(0.0, _coyote_timer - delta)
	_jump_buffer_timer = max(0.0, _jump_buffer_timer - delta)


func _read_jump_input() -> void:
	## ← NEW M1.2
	## Check if jump was JUST pressed this frame (not held, just pressed).
	## is_action_just_pressed() returns true for exactly ONE physics frame.
	##
	## When pressed, we RESET the buffer timer to its maximum value.
	## Resetting (not adding to) means rapid presses don't stack — only the
	## most recent press matters.

	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time


func _handle_jump() -> void:
	## ← NEW M1.2
	## Execute a jump if the player has a valid origin AND a buffered input.
	##
	## Valid origins:
	##   1. is_on_floor() — standing on solid ground right now
	##   2. _coyote_timer > 0 — just walked off a ledge within the grace period
	##
	## Buffered input: _jump_buffer_timer > 0 — jump was pressed recently
	##
	## When BOTH conditions are true simultaneously, we jump.

	var can_jump: bool = is_on_floor() or _coyote_timer > 0.0
	var wants_to_jump: bool = _jump_buffer_timer > 0.0

	if can_jump and wants_to_jump:
		# Apply the upward impulse — negative Y = upward in Godot
		velocity.y = jump_force

		# Mark that we CHOSE to jump (prevents coyote time activating again
		# on the same takeoff and prevents double-jump later using coyote time)
		_is_jumping = true

		# Consume both timers immediately:
		# - Consuming jump_buffer prevents the jump firing a second time
		# - Consuming coyote prevents using it again on this same takeoff
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0


func _apply_gravity(delta: float) -> void:
	## MODIFIED M1.2 — was a flat value, now uses three gravity curves
	##
	## We early-return when on the floor because move_and_slide() already
	## prevents downward penetration. Applying gravity on the floor would
	## not cause visible issues but creates unnecessary velocity.y buildup.

	if is_on_floor() and not _is_jumping:
		# Reset any residual downward velocity when grounded.
		# Without this, landing from a fall keeps velocity.y at its last
		# falling value for one frame before move_and_slide zeroes it.
		# This causes a one-frame ghost collision on slopes.
		velocity.y = 0.0
		return

	# ── Select the appropriate gravity multiplier ──────────────────────────

	var current_gravity: float

	if velocity.y > 0.0:
		# CASE 1: Player is FALLING (positive Y = downward)
		# Apply stronger gravity for a snappy, weighty fall arc
		current_gravity = gravity * fall_gravity_multiplier

	elif not Input.is_action_pressed("jump"):
		# CASE 2: Player is RISING (velocity.y < 0) but jump is NOT held
		# This is the jump cut — rapidly increase gravity to slash height
		# "Tapping" creates a small hop; "holding" creates max height
		current_gravity = gravity * jump_cut_multiplier

	else:
		# CASE 3: Player is RISING and jump IS held
		# Normal gravity — allows the full arc to develop
		current_gravity = gravity

	# Accumulate gravity this frame
	velocity.y += current_gravity * delta

	# Clamp to terminal velocity
	# Without this cap, a long fall could exceed 5000 px/s and
	# tunnel through a thin floor (moves too far in one frame to detect collision)
	velocity.y = min(velocity.y, max_fall_speed)


func _handle_horizontal_movement() -> void:
	## Unchanged from M1.1

	var direction: float = Input.get_axis("move_left", "move_right")
	velocity.x = direction * move_speed

	if direction != 0.0:
		facing_direction = sign(direction)


func _update_floor_state() -> void:
	## ← NEW M1.2
	## Called AFTER move_and_slide() so is_on_floor() reflects this frame's result.
	##
	## Three jobs:
	##   1. Detect ledge-walk-off → start coyote timer
	##   2. Detect landing → clear jump flag
	##   3. Store is_on_floor() for next frame's comparison

	# ── Job 1: Detect ledge walk-off ───────────────────────────────────────
	# "Was on floor last frame" AND "not on floor this frame" AND "didn't jump"
	# = player walked off a ledge → grant coyote time
	#
	# The "not _is_jumping" check is critical:
	# Without it, jumping from a floor would ALSO start the coyote timer,
	# allowing a second jump immediately after the first — unintended double jump.
	if _was_on_floor and not is_on_floor() and not _is_jumping:
		_coyote_timer = coyote_time

	# ── Job 2: Detect landing ───────────────────────────────────────────────
	# When the player touches the floor, clear _is_jumping.
	# This allows the coyote timer to work again on the NEXT ledge.
	if is_on_floor():
		_is_jumping = false

	# ── Job 3: Cache floor state for next frame ─────────────────────────────
	# Must be last — we need the CURRENT frame's is_on_floor() value
	# before overwriting it with itself (no-op, but semantically correct)
	_was_on_floor = is_on_floor()
