# player_animation.gd
# ─────────────────────────────────────────────────────────────────────────────
# MILESTONE M2.4 — Transition polish: speed scaling and apex threshold
#
# Changes from M2.3:
#   + APEX_THRESHOLD, MIN_ANIM_SPEED, MAX_ANIM_SPEED  constants
#   + _update_animation_speed()  function
#   ~ _process(): calls _update_animation_speed()
#   ~ _update_animation(): apex threshold replaces direct velocity.y < 0 check
# ─────────────────────────────────────────────────────────────────────────────
class_name PlayerAnimationController
extends AnimatedSprite2D


# ─── ANIMATION NAME CONSTANTS ─────────────────────────────────────────────────

const ANIM_IDLE: String        = "idle"
const ANIM_WALK: String        = "walk"
const ANIM_RUN: String         = "run"
const ANIM_JUMP_RISE: String   = "jump_rise"
const ANIM_JUMP_FALL: String   = "jump_fall"
const ANIM_JUMP_LAND: String   = "jump_land"
const ANIM_WALL_SLIDE: String  = "wall_slide"
const ANIM_DOUBLE_JUMP: String = "double_jump"
const ANIM_DASH: String        = "dash"
const ANIM_HURT: String        = "hurt"
const ANIM_DEATH: String       = "death"
const ANIM_ATTACK_01: String   = "attack_01"
const ANIM_ATTACK_UP: String   = "attack_up"
const ANIM_ATTACK_DOWN: String = "attack_down"


# ─── TUNING CONSTANTS ─────────────────────────────────────────────────────────

## Horizontal speed above which "run" plays instead of "walk"
const RUN_THRESHOLD: float = 0.8

## Horizontal speed below which "idle" plays instead of "walk"
const IDLE_THRESHOLD: float = 10.0

## Maximum slope angle (radians) before sprite tilt is clamped (~30°)
const MAX_TILT_ANGLE: float = 0.52

## ← NEW M2.4
## velocity.y magnitude below which the player is considered "at the apex".
## Within this zone we hold jump_fall to prevent rise/fall flickering.
## 60.0 px/s = approximately 3.5 frames at 60hz near the very top of the arc.
## Increase this value if flickering is still visible. Decrease if the
## fall animation triggers too early (player still visibly rising).
const APEX_THRESHOLD: float = 60.0

## ← NEW M2.4
## Minimum animation playback multiplier — used when barely moving.
## 0.6 = walk animation plays at 60% speed when velocity is very low.
const MIN_ANIM_SPEED: float = 0.6

## ← NEW M2.4
## Maximum animation playback multiplier — used at full sprint.
## 1.4 = walk/run animation plays at 140% speed at move_speed.
## Keep below 2.0 or individual frames become too brief to read.
const MAX_ANIM_SPEED: float = 1.4


# ─── PLAYER REFERENCE ─────────────────────────────────────────────────────────

var _player: PlayerController


# ─── ONE-SHOT ANIMATION LOCK ──────────────────────────────────────────────────

# Non-empty = a one-shot animation is playing and blocking lower priorities.
# Cleared by _on_animation_finished() when the animation completes.
var _locked_anim: String = ""


# ─── TRANSITION DETECTION ─────────────────────────────────────────────────────

# True if the player was NOT on the floor at the end of last _process() call.
# Used to detect the landing frame (just_landed).
var _was_airborne: bool = false

# Double jump flash timer value from last _process() call.
# Compared with current value to detect the double jump activation frame.
var _prev_dj_timer: float = 0.0


# ─── BUILT-IN FUNCTIONS ──────────────────────────────────────────────────────

func _ready() -> void:
	_player = get_parent() as PlayerController

	if _player == null:
		push_error("[PlayerAnimation] Parent is not a PlayerController. " +
				   "Verify player_animation.gd is attached to Sprite (AnimatedSprite2D), " +
				   "which must be a direct child of Player (CharacterBody2D).")
		return

	# When any non-looping animation completes, clear the one-shot lock.
	animation_finished.connect(_on_animation_finished)

	play(ANIM_IDLE)
	print("[PlayerAnimation] Ready")


func _process(_delta: float) -> void:
	if _player == null:
		return

	# ── Per-frame transition detection ────────────────────────────────────────
	var on_floor: bool       = _player.is_on_floor()
	var just_landed: bool    = on_floor and _was_airborne

	var dj_timer: float         = _player.get_double_jump_flash_timer()
	var just_double_jumped: bool = dj_timer > 0.0 and _prev_dj_timer == 0.0

	_was_airborne  = not on_floor
	_prev_dj_timer = dj_timer

	# ── Update visual properties ──────────────────────────────────────────────
	_update_flip()
	_update_tilt()
	_update_animation_speed()   # ← NEW M2.4

	# ── Drive the animation cascade ───────────────────────────────────────────
	_update_animation(just_landed, just_double_jumped)


# ─── VISUAL PROPERTY UPDATES ──────────────────────────────────────────────────

func _update_flip() -> void:
	## Mirror sprite horizontally for left-facing direction.
	## facing_direction:  1.0 = right (no flip),  -1.0 = left (flip).
	flip_h = _player.facing_direction < 0.0


func _update_tilt() -> void:
	## Rotate sprite to visually plant the character on angled floors.
	if _player.is_on_floor():
		rotation = clamp(_player.get_floor_angle(), -MAX_TILT_ANGLE, MAX_TILT_ANGLE)
	else:
		# Clear tilt while airborne — character should not stay rotated mid-jump
		rotation = 0.0


func _update_animation_speed() -> void:
	## ← NEW M2.4
	## Scale animation playback rate to match actual horizontal movement speed.
	##
	## Why: At 60% movement speed (attack penalty), the walk animation plays too
	## fast relative to visible foot movement. At knockback speeds (2× normal),
	## the animation is far too slow. Speed scaling makes feet match body movement.
	##
	## This only applies to ground movement animations — all other states
	## (jump, dash, attack, wall slide) use 1.0 to preserve intended timing.

	var on_floor: bool        = _player.is_on_floor()
	var is_attacking: bool    = _player.is_attacking()
	var is_dashing: bool      = _player.is_dashing()
	var is_wall_sliding: bool = _player.is_wall_sliding()

	# Non-movement states: return to default speed
	if not on_floor or is_attacking or is_dashing or is_wall_sliding:
		speed_scale = 1.0
		return

	# Compute what fraction of maximum speed the player is currently moving at.
	# clamp() prevents values above 1.0 from exceeding MAX_ANIM_SPEED.
	var h_speed: float        = abs(_player.velocity.x)
	var speed_fraction: float = clamp(h_speed / _player.move_speed, 0.0, 1.0)

	# Linearly interpolate between minimum and maximum playback rates.
	# lerp(a, b, t):  t=0.0 returns a,  t=1.0 returns b,  t=0.5 returns midpoint.
	speed_scale = lerp(MIN_ANIM_SPEED, MAX_ANIM_SPEED, speed_fraction)


# ─── ANIMATION PRIORITY CASCADE ───────────────────────────────────────────────

func _update_animation(just_landed: bool, just_double_jumped: bool) -> void:
	## Priority cascade — executes top to bottom, returns on first match.

	# ── GUARD: One-shot animation is locked ───────────────────────────────────
	if _locked_anim != "":
		# Only hurt and death can interrupt a locked animation
		if _player.get_knockback_timer() > 0.0:
			if _locked_anim != ANIM_HURT and _locked_anim != ANIM_DEATH:
				_play_locked(ANIM_HURT)
		return

	# ── PRIORITY 1: HURT ─────────────────────────────────────────────────────
	if _player.get_knockback_timer() > 0.0:
		_play_locked(ANIM_HURT)
		return

	# ── PRIORITY 2: ATTACK ───────────────────────────────────────────────────
	if _player.is_attacking():
		match _player.get_attack_direction():
			"up":   _play(ANIM_ATTACK_UP)
			"down": _play(ANIM_ATTACK_DOWN)
			_:      _play(ANIM_ATTACK_01)
		return

	# ── PRIORITY 3: DASH ─────────────────────────────────────────────────────
	if _player.is_dashing():
		_play(ANIM_DASH)
		return

	# ── PRIORITY 4: WALL SLIDE ───────────────────────────────────────────────
	if _player.is_wall_sliding():
		_play(ANIM_WALL_SLIDE)
		return

	# ── PRIORITY 5: LANDING ──────────────────────────────────────────────────
	if just_landed:
		_play_locked(ANIM_JUMP_LAND)

		# Also trigger the AnimationPlayer event track for the land sound/particles
		var ap := get_parent().get_node_or_null("AnimationPlayer") as AnimationPlayer
		if ap:
			ap.play("player_land")
		return

	# ── PRIORITY 6: AIRBORNE ─────────────────────────────────────────────────
	if not _player.is_on_floor():

		# Sub-priority A: Double jump burst (rising edge — fires once)
		if just_double_jumped:
			_play_locked(ANIM_DOUBLE_JUMP)
			return

		# Sub-priority B: Rise vs fall vs apex ← MODIFIED M2.4
		# Without a threshold, velocity.y near 0 causes rise/fall flickering.
		# APEX_THRESHOLD creates a dead-zone where fall is held regardless
		# of the exact sign of velocity.y — prevents the stutter at the peak.
		var vy: float = _player.velocity.y

		if vy < -APEX_THRESHOLD:
			# Clearly rising: far enough below zero to be unambiguous
			_play(ANIM_JUMP_RISE)
		else:
			# At the apex (|vy| < threshold) OR falling (vy > threshold):
			# both cases show jump_fall.
			# Rationale: the apex is brief and the fall pose reads as "about
			# to drop" which feels more accurate than holding the rise pose.
			_play(ANIM_JUMP_FALL)
		return

	# ── PRIORITY 7: GROUNDED MOVEMENT ────────────────────────────────────────
	var h_speed: float = abs(_player.velocity.x)

	if h_speed > IDLE_THRESHOLD:
		if h_speed >= _player.move_speed * RUN_THRESHOLD:
			_play(ANIM_RUN)
		else:
			_play(ANIM_WALK)
		return

	# ── PRIORITY 8: IDLE ─────────────────────────────────────────────────────
	_play(ANIM_IDLE)


# ─── ANIMATION PLAYBACK HELPERS ───────────────────────────────────────────────

func _play(anim_name: String) -> void:
	## Play animation only if it is not already playing.
	## Prevents restarting from frame 0 every frame for looping animations.
	if animation == anim_name and is_playing():
		return
	play(anim_name)


func _play_locked(anim_name: String) -> void:
	## Play a one-shot animation and activate the cascade lock.
	## The cascade returns early on every frame until animation_finished fires.
	if _locked_anim == anim_name:
		return   # Already locked on this animation — do not restart it
	_locked_anim = anim_name
	play(anim_name)


# ─── SIGNAL HANDLERS ─────────────────────────────────────────────────────────

func _on_animation_finished() -> void:
	## Fires when any non-looping animation completes its final frame.
	## Clears the cascade lock so normal priority selection resumes.

	var finished: String = _locked_anim

	# Death is a permanent lock — hold the final frame until Phase 5 takes over
	if finished == ANIM_DEATH:
		return

	# All other one-shots: clear lock and resume cascade
	_locked_anim = ""
