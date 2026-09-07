extends Node2D

@export var bounce_height: float = 8.0
@export var bounce_speed: float = 4.0

@onready var arrow_shape: Polygon2D = $ArrowShape

var time_passed: float = 0.0
var base_y: float = 0.0

func _ready() -> void:
	if arrow_shape:
		base_y = arrow_shape.position.y

func _process(delta: float) -> void:
	if arrow_shape:
		time_passed += delta * bounce_speed
		arrow_shape.position.y = base_y + sin(time_passed) * bounce_height
