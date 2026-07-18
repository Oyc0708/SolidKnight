# test_platform.gd
# Temporary platform visual for the test level.
extends StaticBody2D

const PLATFORM_WIDTH: float = 200.0
const PLATFORM_HEIGHT: float = 20.0
const PLATFORM_COLOR: Color = Color(0.4, 0.4, 0.5, 1.0)

func _draw() -> void:
	draw_rect(
		Rect2(-PLATFORM_WIDTH / 2.0, 0.0, PLATFORM_WIDTH, PLATFORM_HEIGHT),
		PLATFORM_COLOR
	)

func _ready() -> void:
	queue_redraw()
