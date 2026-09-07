extends Node


const BOSS_ROOM := "res://scenes/levels/boss_room/boss_room.tscn"
const ZONE_A := "res://scenes/levels/zone_a/zone_a.tscn"
const ZONE_B := "res://scenes/levels/zone_b/zone_b.tscn"
const ZONE_C := "res://scenes/levels/zone_c/zone_c.tscn"


func _transition_to(room_path: String) -> void:
	var game = get_tree().get_first_node_in_group(&"game")
	if game and game.has_method("transition_to_room"):
		# Set last checkpoint ID to empty so it uses the PlayerSpawn marker
		GameManager.last_checkpoint_id = "" 
		game.transition_to_room(room_path, "PlayerSpawn")
	else:
		SceneManager.go_to_scene(room_path)

func load_boss_room() -> void:
	_transition_to(BOSS_ROOM)


func load_zone_a() -> void:
	_transition_to(ZONE_A)


func load_zone_b() -> void:
	_transition_to(ZONE_B)


func load_zone_c() -> void:
	_transition_to(ZONE_C)
