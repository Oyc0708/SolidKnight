extends Node


const BOSS_ROOM := "res://scenes/levels/boss_room/boss_room.tscn"
const ZONE_A := "res://scenes/levels/zone_a/zone_a.tscn"
const ZONE_B := "res://scenes/levels/zone_b/zone_b.tscn"
const ZONE_C := "res://scenes/levels/zone_c/zone_c.tscn"


func load_boss_room() -> void:
	SceneManager.go_to_scene(BOSS_ROOM)


func load_zone_a() -> void:
	SceneManager.go_to_scene(ZONE_A)


func load_zone_b() -> void:
	SceneManager.go_to_scene(ZONE_B)


func load_zone_c() -> void:
	# Keep the existing player, heart HUD, camera and pause/settings menu.
	# The PlayerSpawn marker inside Zone C is also used as its death checkpoint.
	var game := get_tree().get_first_node_in_group(&"game")
	if game != null and game.has_method("transition_to_room"):
		await game.transition_to_room(ZONE_C, "PlayerSpawn")
	else:
		SceneManager.go_to_scene(ZONE_C)
