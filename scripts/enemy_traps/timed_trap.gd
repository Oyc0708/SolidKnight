extends Node2D
## All visuals/collisions are saved nodes. This script only runs the cycle.
## Safe -> warning -> active -> recovery. Times are seconds of GAME time.
@export_enum("Spike", "Rotating", "Crystal", "Crusher") var kind: int = 0
@export var damage: int = 15
@export_range(0.0, 6.0) var start_offset: float = 0.0
## Turn this off for extra copies that share another trap's countdown label.
@export var show_indicator: bool = true
var elapsed := 0.0
var active := false
var phase := "SAFE"
@onready var animation: AnimationPlayer = $AnimationPlayer
func _ready() -> void:
 elapsed = start_offset
 animation.play("cycle")
 animation.pause()
 _update_cycle()
func _physics_process(delta: float) -> void:
 # One clock and modulo avoid chained timer drift. Pausing pauses this clock.
 elapsed = fposmod(elapsed + delta, 6.0)
 _update_cycle()
 if active:
  # Recheck occupants every physics frame: standing inside before activation
  # must still cause damage. The player's own invincibility prevents spam.
  for body in $MovingPart/DamageArea.get_overlapping_bodies():
   if body.is_in_group("player") and body.has_method("take_damage"):
    body.take_damage(damage, $MovingPart.global_position)
func _update_cycle() -> void:
 animation.seek(elapsed, true)
 var end_active := 3.65 if kind == 3 else 5.0
 active = elapsed >= 3.0 and elapsed < end_active
 var next_change: float
 if elapsed < 2.0:
  phase = "SAFE"
  next_change = 2.0
 elif elapsed < 3.0:
  phase = "WARNING"
  next_change = 3.0
 elif active:
  phase = "DANGER"
  next_change = end_active
 else:
  phase = "RESETTING" if kind == 3 else "SAFE"
  next_change = 6.0
 $Countdown.text = "%s  %.1fs" % [phase, next_change - elapsed]
 $Countdown.visible = show_indicator
 $Countdown.modulate = Color(1,0.4,0.35) if active else (Color(1,0.75,0.35) if phase == "WARNING" else Color(0.48,0.86,0.78))
 # The changing countdown colour is the warning indicator used in Zone C.
 $Warning.visible = false
