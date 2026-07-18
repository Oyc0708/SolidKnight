# player.gd
# ─────────────────────────────────────────────────────────────────────────────
# MILESTONE M1.1 — Basic movement and gravity
#
# What this script handles right now:
#   ✓ Left / right movement via keyboard input
#   ✓ Gravity pulling the player down
#   ✓ Landing on floor geometry
#   ✓ Placeholder visual drawn in code (no sprite sheet needed yet)
#
# What will be ADDED in later milestones:
#   M1.2 → Variable jump, coyote time, jump buffer
#   M1.4 → Dash
#   M1.5 → Wall slide / wall jump
#   M2.2 → Real sprite animations
# ─────────────────────────────────────────────────────────────────────────────
class_name PlayerController
extends CharacterBody2D


# ─── MOVEMENT CONSTANTS ──────────────────────────────────────────────────────
# @export means these values appear in the Godot Inspector.
# You can tweak them without opening this script.
# This is the professional workflow: designers tune @export values,
# programmers define the logic.

## How fast the player moves horizontally, in pixels per second
@export var move_speed: float = 180.0

## How strongly gravity pulls the player down, in pixels per second squared.
## Hollow Knight uses a high gravity value to create a fast, weighty arc.
## We start at 1800. We will tune this precisely in M1.2 when we add jumping.
@export var gravity: float = 1800.0


# ─── PLACEHOLDER VISUAL CONSTANTS ────────────────────────────────────────────
# These define how our temporary rectangle looks.
# Replaced entirely in Phase 2 when we add AnimatedSprite2D.
const PLACEHOLDER_WIDTH: int = 32
const PLACEHOLDER_HEIGHT: int = 64
const PLACEHOLDER_COLOR: Color = Color(0.6, 0.4, 1.0, 1.0)   # Purple
const PLACEHOLDER_EYE_COLOR: Color = Color(1.0, 1.0, 1.0, 1.0) # White eyes


# ─── STATE VARIABLES ──────────────────────────────────────────────────────────
# These track what the player is currently doing.
# Used for animation and logic decisions in later milestones.

# Which horizontal direction the player last moved:
#   1.0  = facing right
#  -1.0  = facing left
var facing_direction: float = 1.0


# ─── BUILT-IN FUNCTIONS ──────────────────────────────────────────────────────

func _ready() -> void:
	# _ready() is called once when this node enters the scene tree.
	# It is Godot's equivalent of an "initialize" function.

	# queue_redraw() schedules one call to _draw().
	# Without it, our placeholder visual never appears.
	queue_redraw()

	print("[Player] Ready — position: ", global_position)


func _draw() -> void:
	# _draw() is Godot's built-in custom drawing callback.
	# Runs when queue_redraw() is called.
	# All coordinates are relative to this node's own origin (0, 0).
	# We position things so the player's feet sit at y = 0 (the origin).
	# This makes floor collision math simpler — "feet at origin" is a
	# standard convention in 2D platformer development.

	# ── Body rectangle ──
	# Rect2(x, y, width, height)
	# x = -half width (centers the rect horizontally on the origin)
	# y = -full height (puts the top at -64 so feet are at 0)
	var body_rect := Rect2(
		-PLACEHOLDER_WIDTH / 2.0,  # Left edge:  -16
		-PLACEHOLDER_HEIGHT,       # Top edge:   -64
		PLACEHOLDER_WIDTH,         # Width:       32
		PLACEHOLDER_HEIGHT         # Height:      64
	)
	draw_rect(body_rect, PLACEHOLDER_COLOR)

	# ── Eyes (simple directional indicator) ──
	# Two small white dots so we can see which way the player faces.
	# eye_x_offset shifts both eyes toward the facing direction.
	var eye_x_offset: float = facing_direction * 4.0
	var eye_y: float = -PLACEHOLDER_HEIGHT * 0.7   # 70% up the body

	# Left eye
	draw_circle(
		Vector2(eye_x_offset - 5.0, eye_y),  # position
		4.0,                                   # radius
		PLACEHOLDER_EYE_COLOR
	)
	# Right eye
	draw_circle(
		Vector2(eye_x_offset + 5.0, eye_y),
		4.0,
		PLACEHOLDER_EYE_COLOR
	)


func _physics_process(delta: float) -> void:
	# _physics_process is called every physics tick (default: 60 times/second).
	# delta = time since last tick, approximately 0.01667 seconds.
	# ALL movement logic lives here — never in _process().
	#
	# Why not _process()?
	# _process() runs every render frame, which is NOT guaranteed to be 60fps.
	# Physics bodies interacting at variable frame rates cause jittery, inconsistent
	# movement. _physics_process() is fixed and deterministic.

	_apply_gravity(delta)
	_handle_horizontal_movement()

	# move_and_slide() must be called LAST, after velocity is fully calculated.
	# It physically moves the body and resolves all collisions this frame.
	move_and_slide()


# ─── PRIVATE MOVEMENT FUNCTIONS ───────────────────────────────────────────────

func _apply_gravity(delta: float) -> void:
	# Only apply gravity when NOT touching the floor.
	# is_on_floor() is updated by move_and_slide() each frame.
	# On the first frame before move_and_slide() has run, it returns false,
	# which is correct — we want gravity to activate and push the player down
	# until they reach the floor.
	if not is_on_floor():
		# velocity.y increases each frame because gravity is an acceleration.
		# Acceleration means velocity changes over time:
		#   Frame 1: velocity.y = 0 + (1800 × 0.0167) = 30.06
		#   Frame 2: velocity.y = 30.06 + 30.06 = 60.12
		#   ...keeps increasing until floor contact.
		velocity.y += gravity * delta


func _handle_horizontal_movement() -> void:
	# Input.get_axis(negative_action, positive_action) returns:
	#   -1.0  when only move_left is pressed
	#   +1.0  when only move_right is pressed
	#    0.0  when neither or both are pressed
	#
	# This handles keyboard AND gamepad analog sticks automatically.
	# For analog sticks, values between -1 and 1 are returned (e.g., 0.4)
	# giving smooth acceleration naturally.
	var direction: float = Input.get_axis("move_left", "move_right")

	# Set horizontal velocity directly.
	# There is no acceleration or deceleration yet — this gives instant
	# response. In M1.1 we want to confirm inputs work before adding
	# smoothing. We can add acceleration/deceleration in M1.2 if desired.
	velocity.x = direction * move_speed

	# Track facing direction for the placeholder eyes and future sprite flipping.
	# Only update if actually moving — we want to remember the last direction
	# when standing still (player should face the way they last walked).
	if direction != 0.0:
		facing_direction = sign(direction)
		# queue_redraw() schedules _draw() to run again next render frame.
		# We call it here because the eyes need to update when facing changes.
		queue_redraw()
