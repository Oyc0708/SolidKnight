@tool
extends EditorScript

func _run():
	print("Starting combat level redesign (Error-Free Version)...")
	var scene_path = "res://scenes/levels/combat_level/combat_level.tscn"
	var packed_scene = load(scene_path)
	if not packed_scene:
		print("Failed to load scene")
		return
		
	var root = packed_scene.instantiate()
	
	# 1. Clear old terrain completely
	var terrain = root.get_node_or_null("Terrain")
	if terrain:
		terrain.free()
		
	var terrain_node = Node2D.new()
	terrain_node.name = "Terrain"
	root.add_child(terrain_node)
	terrain_node.owner = root
		
	# 2. Create new TileMapLayer for terrain
	var tilemap = TileMapLayer.new()
	tilemap.name = "TerrainLayer"
	var tileset = load("res://assets/tiles/world_tileset.tres")
	tilemap.tile_set = tileset
	terrain_node.add_child(tilemap)
	tilemap.owner = root
	
	# Create a background TileMapLayer for pillars
	var bg_map = TileMapLayer.new()
	bg_map.name = "BackgroundLayer"
	bg_map.tile_set = tileset
	bg_map.z_index = -1
	bg_map.modulate = Color(0.4, 0.4, 0.5)
	# CRITICAL: Disable collision on the background so pillars are pass-through!
	bg_map.collision_enabled = false
	terrain_node.add_child(bg_map)
	bg_map.owner = root

	var width_tiles = 160
	
	var add_platform = func(px, py, w, h):
		for x in range(px, px + w):
			for y in range(py, py + h):
				var ax = 1
				var ay = 1
				if x == px: ax = 0
				elif x == px + w - 1: ax = 2
				if y == py: ay = 0
				elif y == py + h - 1: ay = 2
				
				if ax != 1 or ay != 1:
					tilemap.set_cell(Vector2i(x, y), 0, Vector2i(ax, ay))
				else:
					tilemap.set_cell(Vector2i(x, y), 0, Vector2i(1, 1))
				
				if y == py + h - 1:
					for bgy in range(py + h, 50):
						bg_map.set_cell(Vector2i(x, bgy), 0, Vector2i(1, 1))

	# Floor with gaps for jumping mechanics
	add_platform.call(-10, 42, 50, 10) # Start floor
	add_platform.call(55, 42, 40, 10)  # Middle island
	add_platform.call(110, 42, 60, 10) # End floor
	
	# Boundary Walls
	add_platform.call(-10, -20, 10, 72)
	add_platform.call(width_tiles, -20, 10, 72)

	# Platforming Layout - More complex and vertical
	add_platform.call(18, 35, 12, 2) # First jump
	add_platform.call(35, 28, 10, 2) # Second jump
	
	add_platform.call(55, 22, 25, 2) # High central bridge
	add_platform.call(62, 33, 15, 2) # Low central route
	
	add_platform.call(85, 28, 8, 2)  # Stepping stone
	add_platform.call(100, 20, 12, 2) # High right
	add_platform.call(115, 30, 16, 2) # Lower right approach
	add_platform.call(138, 24, 18, 2) # Final high ledge
	
	# 5. Add Parallax Background
	var old_bg = root.get_node_or_null("ParallaxBackground")
	if old_bg: old_bg.free()
		
	var pbg = ParallaxBackground.new()
	pbg.name = "ParallaxBackground"
	
	var pl = ParallaxLayer.new()
	pl.name = "ParallaxLayer"
	pl.motion_scale = Vector2(0.3, 0.3)
	pl.motion_mirroring = Vector2(2048, 2048) 
	pbg.add_child(pl)
	
	var tr = TextureRect.new()
	tr.name = "BackgroundTexture"
	tr.texture = load("res://assets/backgrounds/main_menu background.jpg")
	tr.modulate = Color(0.2, 0.2, 0.3)
	tr.stretch_mode = TextureRect.STRETCH_TILE
	tr.size = Vector2(4096, 4096)
	tr.position = Vector2(-1024, -1024)
	pl.add_child(tr)
	
	root.add_child(pbg)
	pbg.owner = root
	pl.owner = root
	tr.owner = root

	var spawn = root.get_node_or_null("SpawnPoints/PlayerSpawn")
	if spawn:
		spawn.position = Vector2(100, 600) 
		
	var enemies = root.get_node_or_null("Enemies")
	if enemies:
		# Clear old enemies and markers completely
		for c in enemies.get_children():
			c.free()
			
		var ground_scene = load("res://scenes/enemies/example_enemy.tscn")
		var flying_scene = load("res://scenes/enemies/flying_enemy.tscn")
		
		var i_ge = 0
		var setup_patrol = func(ex, ey, mx1, mx2):
			i_ge += 1
			var enemy = ground_scene.instantiate()
			enemy.name = "GroundEnemy" + str(i_ge)
			enemy.position = Vector2(ex, ey)
			enemies.add_child(enemy)
			enemy.owner = root
			
			var m1 = Marker2D.new()
			m1.name = enemy.name + "_PatrolA"
			m1.position = Vector2(mx1, ey)
			enemies.add_child(m1)
			m1.owner = root
			
			var m2 = Marker2D.new()
			m2.name = enemy.name + "_PatrolB"
			m2.position = Vector2(mx2, ey)
			enemies.add_child(m2)
			m2.owner = root
			
			enemy.set("patrol_point_a", enemy.get_path_to(m1))
			enemy.set("patrol_point_b", enemy.get_path_to(m2))

		# Complex enemy placement
		setup_patrol.call(400, 640, 160, 500)   # Floor left
		setup_patrol.call(1100, 320, 950, 1200) # High central bridge
		setup_patrol.call(1120, 480, 1030, 1200) # Low central bridge
		setup_patrol.call(1900, 448, 1850, 2050) # Right platform
		setup_patrol.call(2200, 640, 1900, 2400) # Right floor
		
		var i_fe = 0
		var spawn_fe = func(ex, ey):
			i_fe += 1
			var en = flying_scene.instantiate()
			en.name = "FlyingEnemy" + str(i_fe)
			en.position = Vector2(ex, ey)
			enemies.add_child(en)
			en.owner = root
			
		# Flying enemies in strategic jump paths
		spawn_fe.call(750, 450)  # Gap 1 hazard
		spawn_fe.call(1500, 200) # High jump hazard
		spawn_fe.call(1700, 550) # Gap 2 hazard
		spawn_fe.call(2300, 300) # Right area flyer
				
	# 8. Add Death Zone and Checkpoint
	var old_death = root.get_node_or_null("DeathZone")
	if old_death: old_death.free()
	var death_zone = Area2D.new()
	death_zone.name = "DeathZone"
	death_zone.position = Vector2(1280, 1400)
	var death_script = load("res://scenes/levels/test_death.gd")
	if death_script:
		death_zone.set_script(death_script)
	var death_shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(5000, 200)
	death_shape.shape = rect
	death_zone.add_child(death_shape)
	root.add_child(death_zone)
	death_zone.owner = root
	death_shape.owner = root
	
	var old_cp = root.get_node_or_null("Checkpoint")
	if old_cp: old_cp.free()
	var checkpoint = Area2D.new()
	checkpoint.name = "Checkpoint"
	checkpoint.position = Vector2(100, 600)
	checkpoint.collision_layer = 3
	var cp_script = load("res://scripts/objects/auto_checkpoint.gd")
	if cp_script:
		checkpoint.set_script(cp_script)
		checkpoint.set("checkpoint_id", "combat_level_start")
	var cp_shape = CollisionShape2D.new()
	var cp_rect = RectangleShape2D.new()
	cp_rect.size = Vector2(64, 64)
	cp_shape.shape = cp_rect
	checkpoint.add_child(cp_shape)
	root.add_child(checkpoint)
	checkpoint.owner = root
	cp_shape.owner = root
	
	var new_scene = PackedScene.new()
	new_scene.pack(root)
	var err = ResourceSaver.save(new_scene, scene_path)
	
	if err == OK:
		print("SUCCESS! Combat level redesigned. No errors!")
	else:
		print("Error saving scene: ", err)
