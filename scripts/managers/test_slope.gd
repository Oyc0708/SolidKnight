# test_slope.gd
# Temporary slope visual for the test level.
# The node itself is rotated in the Inspector — this script draws unrotated
# and the node's transform handles the actual rotation.
extends StaticBody2D

@export var slope_width: float = 180.0
@export var slope_color: Color = Color(0.52, 0.35, 0.35, 1.0)

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	# Draw centered on the node origin — rotation applied by the node transform
	draw_rect(
		Rect2(-slope_width / 2.0, -7.0, slope_width, 14.0),
		slope_color
	)
