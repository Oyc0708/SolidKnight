# test_ground.gd
# Temporary visual for the test floor.
# Deleted when real TileMap levels are built in Phase 7.
extends StaticBody2D

const GROUND_WIDTH: float = 2000.0
const GROUND_HEIGHT: float = 40.0
const GROUND_COLOR: Color = Color(0.3, 0.3, 0.35, 1.0)   # Dark grey

func _draw() -> void:
	# Draw the floor centered on this node's origin
	draw_rect(
		Rect2(-GROUND_WIDTH / 2.0, 0.0, GROUND_WIDTH, GROUND_HEIGHT),
		GROUND_COLOR
	)

func _ready() -> void:
	queue_redraw()
