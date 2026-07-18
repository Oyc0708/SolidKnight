# test_one_way_platform.gd
# Visual for a one-way (drop-through) platform in the test level.
# Arrow markers show the player this surface is passable from below.
extends StaticBody2D

const PLATFORM_WIDTH: float  = 180.0
const PLATFORM_HEIGHT: float = 16.0
const PLATFORM_COLOR: Color  = Color(0.55, 0.8, 0.55, 1.0)   # Muted green
const ARROW_COLOR: Color     = Color(0.3, 0.6, 0.3, 0.9)

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	# ── Platform surface ──────────────────────────────────────────────────────
	draw_rect(
		Rect2(-PLATFORM_WIDTH / 2.0, 0.0, PLATFORM_WIDTH, PLATFORM_HEIGHT),
		PLATFORM_COLOR
	)

	# ── Small downward arrows — visual hint the platform is drop-through ──────
	# Drawn at three evenly-spaced positions along the platform top
	var arrow_y: float = -8.0    # above the platform surface
	for i in range(3):
		var arrow_x: float = -50.0 + i * 50.0
		# Short vertical line down
		draw_line(Vector2(arrow_x, arrow_y),   Vector2(arrow_x, arrow_y + 8.0),  ARROW_COLOR, 2.0)
		# Arrowhead left leg
		draw_line(Vector2(arrow_x, arrow_y + 8.0), Vector2(arrow_x - 4.0, arrow_y + 4.0), ARROW_COLOR, 2.0)
		# Arrowhead right leg
		draw_line(Vector2(arrow_x, arrow_y + 8.0), Vector2(arrow_x + 4.0, arrow_y + 4.0), ARROW_COLOR, 2.0)
