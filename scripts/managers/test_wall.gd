# test_wall.gd
# Temporary visual for test level walls.
# Deleted when real TileMap levels are built in Phase 7.
extends StaticBody2D

## Set this in the Inspector to control the wall's visual size.
## Must match the CollisionShape2D size you set.
@export var wall_width: float = 32.0
@export var wall_height: float = 250.0
@export var wall_color: Color = Color(0.35, 0.35, 0.4, 1.0)

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	# Origin of StaticBody2D is the center of the collision shape.
	# Draw centered on that origin.
	draw_rect(
		Rect2(-wall_width / 2.0, -wall_height / 2.0, wall_width, wall_height),
		wall_color
	)
