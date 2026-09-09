extends CharacterBody2D

@export var max_health: int = 30
@export var detection_distance: float = 620.0
@export var retreat_distance: float = 160.0
@export var preferred_distance: float = 260.0
@export var move_speed: float = 85.0
@export var projectile_scene: PackedScene
var current_health: int
var player: Node2D
var behaviour := "SEARCHING"
var shots_fired := 0
@onready var sight: RayCast2D = $LineOfSight
@onready var cooldown: Timer = $ShotCooldown
@onready var windup: Timer = $AimTimer
func _ready() -> void:
 current_health = max_health
 windup.timeout.connect(_shoot)
 $Visuals/AnimatedSprite2D.play("idle")
func can_see_player() -> bool:
 if not is_instance_valid(player):
  return false
 if global_position.distance_to(player.global_position) > detection_distance:
  return false
 sight.target_position = sight.to_local(player.global_position + Vector2(0,-15))
 sight.force_raycast_update()
 return sight.is_colliding() and sight.get_collider() == player
func _physics_process(delta: float) -> void:
 if not is_instance_valid(player):
  player = get_tree().get_first_node_in_group("player") as Node2D
 velocity.y += 1800.0 * delta
 velocity.x = 0.0
 var visible_target := can_see_player()
 behaviour = "NO LINE OF SIGHT"
 if visible_target:
  var gap: float = player.global_position.x - global_position.x
  var facing: float = signf(gap)
  $Visuals.scale.x = facing if facing != 0 else 1.0
  behaviour = "HOLDING DISTANCE"
  if absf(gap) < retreat_distance:
   velocity.x = -facing * move_speed
   behaviour = "RETREATING"
  elif absf(gap) > preferred_distance + 25.0:
   velocity.x = facing * move_speed
   behaviour = "APPROACHING"
  if cooldown.is_stopped() and windup.is_stopped():
   windup.start()
  if not windup.is_stopped():
   behaviour += " / AIMING"
 else:
  # Never finish an old shot through cover.
  windup.stop()
 # Check the floor ahead before walking; do not retreat off a ledge.
 if velocity.x != 0:
  $FloorAhead.position.x = signf(velocity.x) * 32.0
  $FloorAhead.force_raycast_update()
  if is_on_floor() and not $FloorAhead.is_colliding():
   velocity.x = 0.0
 move_and_slide()
 $Visuals/AimWarning.visible = not windup.is_stopped()
 $Status.text = "%s\nHP %d / %d" % [behaviour, current_health, max_health]
func _shoot() -> void:
 # Recheck when the warning finishes: a wall may now be in the way.
 if not can_see_player() or projectile_scene == null:
  return
 var arrow = projectile_scene.instantiate()
 get_tree().current_scene.add_child(arrow)
 arrow.global_position = $Visuals/Muzzle.global_position
 arrow.direction = (player.global_position + Vector2(0,-15) - arrow.global_position).normalized()
 shots_fired += 1
 cooldown.start()
func take_damage(amount: int) -> void:
 current_health -= amount
 if current_health <= 0:
  EventBus.enemy_died.emit(self, global_position)
  queue_free()
