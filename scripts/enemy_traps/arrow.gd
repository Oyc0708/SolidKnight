extends CharacterBody2D
## A real moving physics body: move_and_collide stops fast arrows at walls.
@export var speed: float = 400.0
@export var damage: int = 12
var direction := Vector2.RIGHT
func _ready() -> void:
 $Lifetime.timeout.connect(queue_free)
func _physics_process(delta: float) -> void:
 rotation = direction.angle()
 var hit := move_and_collide(direction * speed * delta)
 if hit:
  var body := hit.get_collider()
  if body.is_in_group("player") and body.has_method("take_damage"):
   body.take_damage(damage, global_position)
  queue_free()
