extends HBoxContainer

# Displays player health using heart icons
# Call update_heart(value) to refresh the display

# Heart texture resources
const HEART_EMPTY = preload("res://assets/ui/hud/Heart_Empty.png")
const HEART_FULL = preload("res://assets/ui/hud/Heart_Full.png")

## Maximum health (total number of hearts)
@export var max_hearts: int = 5

## Current health (number of red hearts)
@export var current_hearts: int = 5

## Initializes with 3 hearts for testing purposes
func _ready():
	update_heart(3)

func update_heart(value):
	# Loop through all child nodes
	for i in range(get_child_count()):
		# Get child node and cast to TextureRect
		var heart = get_child(i) as TextureRect

# Determine whether to show full or empty heart based on index
		if i < value:
			heart.texture = HEART_FULL
		else:
			heart.texture = HEART_EMPTY
