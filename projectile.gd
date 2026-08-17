# projectile.gd
class_name Projectile
extends Area2D

@export var speed: float = 400.0
@export var damage: int = 10
@export var lifetime: float = 2.0

var _direction: float = 1.0

func _ready() -> void:
	# Destroy the bullet automatically after 'lifetime' seconds to save memory
	get_tree().create_timer(lifetime).timeout.connect(queue_free)
	
	# Connect signals for hitting enemies and walls
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	# Move the projectile in a straight line every frame
	global_position.x += speed * _direction * delta

# Called by player.gd immediately after spawning the projectile
func set_direction(dir: float) -> void:
	_direction = dir
	
	# Flip the sprite visually if shooting left
	var sprite = get_node_or_null("Sprite2D")
	if sprite:
		sprite.flip_h = (_direction < 0.0)

# Triggers when touching another Area2D (like an enemy Hurtbox)
func _on_area_entered(area: Area2D) -> void:
	if area is Hurtbox:
		area.take_hit(damage, global_position)
		_destroy()

# Triggers when touching a PhysicsBody2D (like World Geometry on Layer 1)
func _on_body_entered(_body: Node2D) -> void:
	_destroy()

func _destroy() -> void:
	# Optional: Spawn a little hit particle here before queue_free()
	queue_free()
