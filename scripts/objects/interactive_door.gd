extends Area2D

@export_file("*.tscn") var target_scene: String = ""
@export var target_spawn_name: String = ""

var _triggered := false
var _player_in_range := false
var _label: Label

func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	set_collision_mask_value(2, true) # Layer 2 is Player
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	_label = get_node_or_null("Label")
	if _label:
		_label.visible = false

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		_player_in_range = true
		if _label:
			_label.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		_player_in_range = false
		if _label:
			_label.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if _triggered or not _player_in_range or target_scene.is_empty():
		return
		
	# Check for left click ("attack") or explicitly the interact key
	var is_click = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	var is_attack_action = event.is_action_pressed("attack")
	var is_interact_action = event.is_action_pressed("interact")
	
	if is_click or is_attack_action or is_interact_action:
		var game := get_tree().get_first_node_in_group(&"game")
		if game == null or not game.has_method("transition_to_room"):
			push_error("[InteractiveDoor] No persistent Game controller found")
			return
			
		_triggered = true
		get_viewport().set_input_as_handled()
		await game.transition_to_room(target_scene, target_spawn_name)
