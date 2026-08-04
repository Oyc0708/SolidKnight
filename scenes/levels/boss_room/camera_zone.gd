extends Area2D

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	# Listen for player body entering the zone
	body_entered.connect(_on_body_entered)
	
	# Defer execution by one frame to detect if player is already inside after scene load
	call_deferred("_check_player_inside")

func _check_player_inside() -> void:
	# Check overlapping physics bodies
	for body in get_overlapping_bodies():
		if _is_player(body):
			_apply_camera_limits()
			return
			
	# Fallback: Check player global position directly if physics overlaps haven't registered
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		player = get_parent().find_child("Player", true, false)
		
	if player and _is_point_inside(player.global_position):
		_apply_camera_limits()

func _on_body_entered(body: Node2D) -> void:
	if _is_player(body):
		_apply_camera_limits()

func _is_player(body: Node2D) -> bool:
	return body.is_in_group("player") or body.name == "Player" or body.name == "player"

func _is_point_inside(point: Vector2) -> bool:
	if not collision_shape or not (collision_shape.shape is RectangleShape2D):
		return false
	var rect_shape: RectangleShape2D = collision_shape.shape
	var extents = rect_shape.size * collision_shape.global_scale / 2.0
	var center = collision_shape.global_position
	var rect = Rect2(center - extents, extents * 2.0)
	return rect.has_point(point)

func _apply_camera_limits() -> void:
	if not collision_shape or not (collision_shape.shape is RectangleShape2D):
		return
		
	var rect_shape: RectangleShape2D = collision_shape.shape
	var extents = rect_shape.size * collision_shape.global_scale / 2.0
	var center = collision_shape.global_position
	
	var camera = get_viewport().get_camera_2d()
	if camera:
		camera.limit_left = int(center.x - extents.x)
		camera.limit_right = int(center.x + extents.x)
		camera.limit_top = int(center.y - extents.y)
		camera.limit_bottom = int(center.y + extents.y)
		camera.reset_smoothing() # Reset smoothing instantly to prevent visual tearing
		print("[CameraZone] Applied camera limits for room '", get_parent().name, "': L=", camera.limit_left, " T=", camera.limit_top, " R=", camera.limit_right, " B=", camera.limit_bottom)
