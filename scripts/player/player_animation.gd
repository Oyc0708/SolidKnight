# player_animation.gd
# ─────────────────────────────────────────────────────────────────────────────
# MILESTONE M2.2 — State-driven animation controller
#
# Attached to: Sprite (AnimatedSprite2D), child of Player (CharacterBody2D)
# Reads state from: PlayerController (parent node) via public accessor functions
# Writes to: nothing outside this script
#
# Responsibilities:
#   ✓ Play the correct animation based on a strict priority cascade
#   ✓ Flip the sprite horizontally for left/right facing
#   ✓ Tilt the sprite to match the slope angle when grounded
#   ✓ Lock one-shot animations until completion before resuming cascade
#   ✓ Detect rising-edge events (double jump, landing) for triggered animations
# ─────────────────────────────────────────────────────────────────────────────
class_name PlayerAnimationController
extends AnimatedSprite2D


# ─── ANIMATION NAME CONSTANTS ─────────────────────────────────────────────────
# Storing animation names as constants prevents typo bugs.
# "idle" vs "Idle" is a silent runtime failure — the constant catches it at load.

const ANIM_IDLE: String         = "idle"
const ANIM_WALK: String         = "walk"
const ANIM_RUN: String          = "run"
const ANIM_JUMP_RISE: String    = "jump_rise"
const ANIM_JUMP_FALL: String    = "jump_fall"
const ANIM_JUMP_LAND: String    = "jump_land"
const ANIM_WALL_SLIDE: String   = "wall_slide"
const ANIM_DOUBLE_JUMP: String  = "double_jump"
const ANIM_DASH: String         = "dash"
const ANIM_HURT: String         = "hurt"
const ANIM_DEATH: String        = "death"


# ─── TUNING CONSTANTS ─────────────────────────────────────────────────────────

## Horizontal speed above which "run" plays instead of "walk".
## 0.8 × move_speed means: almost at full speed = run, slower = walk.
## Adjust between 0.5 and 0.9 to taste.
const RUN_THRESHOLD: float = 0.8

## Horizontal speed below which "idle" plays instead of "walk".
## Small deadzone prevents idle/walk flickering when nearly still.
const IDLE_THRESHOLD: float = 10.0

## Maximum slope tilt angle (radians) before we stop rotating the sprite.
## Beyond this, the visual distortion looks wrong. ~30 degrees.
const MAX_TILT_ANGLE: float = 0.52


# ─── PLAYER REFERENCE ─────────────────────────────────────────────────────────

# Reference to the parent CharacterBody2D.
# Set in _ready() — null until then.
var _player: PlayerController


# ─── ONE-SHOT ANIMATION LOCK ──────────────────────────────────────────────────

# When non-empty, holds the name of a one-shot animation currently playing.
# Lower-priority animations are blocked while this is non-empty.
# Cleared by _on_animation_finished() when the animation completes.
var _locked_anim: String = ""


# ─── TRANSITION DETECTION ─────────────────────────────────────────────────────

# True if the player was airborne at the END of the last _process() call.
# Compared with current is_on_floor() to detect the landing frame.
var _was_airborne: bool = false

# The double jump flash timer value from the LAST _process() call.
# Compared with the current value to detect the double jump activation frame.
var _prev_dj_timer: float = 0.0


# ─── BUILT-IN FUNCTIONS ──────────────────────────────────────────────────────

func _ready() -> void:
	# ── Get parent reference ──────────────────────────────────────────────────
	# get_parent() returns the immediate parent node.
	# "as PlayerController" attempts to cast it to our class —
	# returns null if the parent is a different type (safe casting).
	_player = get_parent() as PlayerController

	if _player == null:
		push_error("[PlayerAnimation] Parent is not a PlayerController. " +
				   "Verify that player_animation.gd is attached to Sprite (AnimatedSprite2D), " +
				   "which must be a direct child of Player (CharacterBody2D).")
		return

	# ── Connect to own animation_finished signal ──────────────────────────────
	# AnimatedSprite2D emits this signal when any non-looping animation
	# reaches its final frame and stops. We use it to clear the animation lock.
	animation_finished.connect(_on_animation_finished)

	# ── Start on idle ─────────────────────────────────────────────────────────
	play(ANIM_IDLE)

	print("[PlayerAnimation] Ready")


func _process(delta: float) -> void:
	# _process() runs every render frame — appropriate for visual updates.
	# Physics state (_player.velocity, is_on_floor(), etc.) was computed in
	# the most recent _physics_process() call, which runs at a fixed 60hz.
	# Reading physics state here gives us up-to-date values at render time.

	if _player == null:
		return

	# ── Compute per-frame transition flags ────────────────────────────────────

	# Is the player currently on the floor?
	var on_floor: bool = _player.is_on_floor()

	# just_landed: true on the FIRST frame of floor contact after being airborne.
	# Example: frame 45 = airborne, frame 46 = on floor → just_landed = true on frame 46 only.
	var just_landed: bool = on_floor and _was_airborne

	# just_double_jumped: true on the FIRST frame after a double jump fires.
	# Detected by rising-edge comparison of the double jump timer.
	var dj_timer: float = _player.get_double_jump_flash_timer()
	var just_double_jumped: bool = dj_timer > 0.0 and _prev_dj_timer == 0.0

	# Store current state for next frame's comparison
	_was_airborne  = not on_floor
	_prev_dj_timer = dj_timer

	# ── Update visual properties ──────────────────────────────────────────────
	_update_flip()
	_update_tilt()

	# ── Update animation ──────────────────────────────────────────────────────
	_update_animation(just_landed, just_double_jumped)


# ─── VISUAL PROPERTY UPDATES ──────────────────────────────────────────────────

func _update_flip() -> void:
	## Flip the sprite to face the correct direction.
	## AnimatedSprite2D.flip_h = true mirrors the sprite along its Y axis.
	## facing_direction: 1.0 = right (no flip), -1.0 = left (flip).
	flip_h = _player.facing_direction < 0.0


func _update_tilt() -> void:
	## Rotate the sprite to visually align with sloped floors.
	## This makes the character look "planted" on angled surfaces.

	if _player.is_on_floor():
		var angle: float = _player.get_floor_angle()

		# Only tilt within a reasonable range.
		# A 50-degree tilt looks broken, not grounded.
		rotation = clamp(angle, -MAX_TILT_ANGLE, MAX_TILT_ANGLE)
	else:
		# Clear slope tilt while airborne.
		# Without this, the character would stay tilted mid-jump
		# from the slope they just left.
		rotation = 0.0


# ─── ANIMATION PRIORITY CASCADE ───────────────────────────────────────────────

func _update_animation(just_landed: bool, just_double_jumped: bool) -> void:
	## Priority cascade: each level only executes if all higher levels failed.
	## Return after each successful match — lower levels are skipped.

	# ── GUARD: One-shot animation is locked ───────────────────────────────────
	# If a locked animation is playing, almost nothing interrupts it.
	# The ONLY exception: hurt can interrupt non-hurt/non-death locks,
	# and death can interrupt everything.
	if _locked_anim != "":
		# Allow death to interrupt any locked animation
		# (Death detection added fully in Phase 5 — placeholder here)

		# Allow a NEW hurt to interrupt jump_land or double_jump lock
		# (Player got hit during landing animation — hurt takes priority)
		if _player.get_knockback_timer() > 0.0:
			if _locked_anim != ANIM_HURT and _locked_anim != ANIM_DEATH:
				_play_locked(ANIM_HURT)
		# All other cases: let the locked animation finish naturally
		return

	# ─────────────────────────────────────────────────────────────────────────
	# PRIORITY 1: HURT
	# Player has active knockback → we were just hit.
	# Play hurt and lock — do not let idle, walk, or air animations interrupt.
	# The hurt animation is 7 frames × 0.1s = 0.7s.
	# The knockback timer (control lock) is shorter at 0.25s.
	# The animation locks for the FULL visual duration, not just the control lock.
	# ─────────────────────────────────────────────────────────────────────────
	if _player.get_knockback_timer() > 0.0:
		_play_locked(ANIM_HURT)
		return

	# ─────────────────────────────────────────────────────────────────────────
	# PRIORITY 2: DASH
	# Dashing overrides all movement states visually.
	# We use _play() not _play_locked() because the dash state in player.gd
	# already controls its own duration — we do not need a separate animation lock.
	# When _is_dashing becomes false, this check fails and cascade continues.
	# ─────────────────────────────────────────────────────────────────────────
	if _player.is_dashing():
		_play(ANIM_DASH)
		return

	# ─────────────────────────────────────────────────────────────────────────
	# PRIORITY 3: WALL SLIDE
	# Wall slide is a looping animation — plays as long as wall contact holds.
	# Uses _play() not _play_locked() for the same reason as dash.
	# ─────────────────────────────────────────────────────────────────────────
	if _player.is_wall_sliding():
		_play(ANIM_WALL_SLIDE)
		return

	# ─────────────────────────────────────────────────────────────────────────
	# PRIORITY 4: LANDING
	# just_landed is true for exactly ONE frame.
	# We lock the landing animation so it plays its full 5 frames × 1/12s ≈ 0.42s
	# before the cascade resumes with idle or walk.
	# Without the lock, the cascade would immediately continue to idle on frame 2.
	# ─────────────────────────────────────────────────────────────────────────
	# if just_landed:
	#	_play_locked(ANIM_JUMP_LAND)
	#	return

	# ─────────────────────────────────────────────────────────────────────────
	# PRIORITY 5: AIRBORNE
	# Player is in the air (not on floor, not wall sliding).
	# Three sub-states inside this priority level.
	# ─────────────────────────────────────────────────────────────────────────
	if not _player.is_on_floor():

		# Sub-priority A: Double jump burst
		# just_double_jumped fires for one frame — triggers the burst animation.
		# Locked so it plays all 6 frames before returning to rise/fall.
		if just_double_jumped:
			_play_locked(ANIM_DOUBLE_JUMP)
			return

		# Sub-priority B: Rising vs. falling
		# Threshold at velocity.y < 0 (upward) vs >= 0 (downward or apex).
		# At the exact apex (velocity.y = 0) we show the fall pose.
		# This is a design choice — the apex is brief and the fall pose reads
		# as "starting to drop" which feels more accurate than "still rising".
		if _player.velocity.y < 0.0:
			_play(ANIM_JUMP_RISE)
		else:
			_play(ANIM_JUMP_FALL)
		return

	# ─────────────────────────────────────────────────────────────────────────
	# PRIORITY 6: GROUNDED MOVEMENT
	# Player is on the floor and has meaningful horizontal velocity.
	# Threshold prevents idle/walk flickering when nearly stationary.
	# ─────────────────────────────────────────────────────────────────────────
	var h_speed: float = abs(_player.velocity.x)

	if h_speed > IDLE_THRESHOLD:
		# Decide between walk and run based on proportion of max speed.
		# At 80%+ of move_speed → run.  Below 80% → walk.
		if h_speed >= _player.move_speed * RUN_THRESHOLD:
			_play(ANIM_RUN)
		else:
			_play(ANIM_WALK)
		return

	# ─────────────────────────────────────────────────────────────────────────
	# PRIORITY 7: IDLE
	# Lowest priority. Reached only when ALL other checks have failed.
	# Player is on the floor with near-zero velocity and no other state active.
	# ─────────────────────────────────────────────────────────────────────────
	_play(ANIM_IDLE)


# ─── ANIMATION PLAYBACK HELPERS ───────────────────────────────────────────────

func _play(anim_name: String) -> void:
	## Play an animation — but do not restart it if it is already playing.
	##
	## Without this guard, calling play("idle") every frame would reset the
	## animation to frame 0 every frame — the animation would never advance.
	## The guard checks BOTH the name (correct animation) AND is_playing()
	## (actually running). Both must be true to skip the play() call.

	if animation == anim_name and is_playing():
		return

	play(anim_name)


func _play_locked(anim_name: String) -> void:
	## Play a one-shot animation and activate the lock.
	##
	## The lock is stored in _locked_anim.
	## _update_animation() checks _locked_anim first every frame and returns
	## early if non-empty, preventing any lower-priority animation from firing.
	##
	## The lock is cleared by _on_animation_finished() when the animation ends.
	##
	## If this animation is already locked and playing, do nothing — we do not
	## want to restart a locked animation from frame 0 on every frame it is called.

	if _locked_anim == anim_name:
		return   # Already locked on this animation — let it finish

	_locked_anim = anim_name
	play(anim_name)


# ─── SIGNAL HANDLERS ─────────────────────────────────────────────────────────

func _on_animation_finished() -> void:
	## Called by AnimatedSprite2D when a NON-LOOPING animation completes.
	## Looping animations (idle, walk, run, wall_slide) never fire this signal.
	##
	## This is where the animation lock is cleared, allowing the priority
	## cascade to resume selecting animations on the next _process() frame.

	var finished: String = _locked_anim

	# ── Death is a permanent lock ─────────────────────────────────────────────
	# When the death animation finishes, the character holds its last frame.
	# We keep the lock so nothing else can play over the death pose.
	# Phase 5 (player death / respawn) takes over from here.
	if finished == ANIM_DEATH:
		# Keep _locked_anim = ANIM_DEATH — do not clear it
		return

	# ── All other one-shots: clear the lock ───────────────────────────────────
	# The next _process() frame will run the full priority cascade and
	# select the appropriate animation based on current state.
	_locked_anim = ""

	# Debug confirmation — remove this in M2.4 when the system is verified
	print("[PlayerAnimation] Animation finished: ", finished, " → resuming cascade")
