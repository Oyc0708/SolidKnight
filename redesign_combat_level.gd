@tool
extends SceneTree

func _init():
	print("Starting combat level redesign...")
	var scene_path = "res://scenes/levels/combat_level/combat_level.tscn"
	var packed_scene = load(scene_path)
	if not packed_scene:
		print("Failed to load scene")
		quit(1)
		return
		
	var root = packed_scene.instantiate()
	
	# 1. Clear old terrain completely
	var terrain = root.get_node_or_null("Terrain")
	if terrain:
		terrain.free()
		
	# 2. Create new TileMapLayer for terrain
	var tilemap = TileMapLayer.new()
	tilemap.name = "TerrainLayer"
	var tileset = load("res://assets/tiles/world_tileset.tres")
	tilemap.tile_set = tileset
	root.add_child(tilemap)
	tilemap.owner = root
	
	# Create a background TileMapLayer
	var bg_map = TileMapLayer.new()
	bg_map.name = "BackgroundLayer"
	bg_map.tile_set = tileset
	bg_map.z_index = -1
	bg_map.modulate = Color(0.4, 0.4, 0.5) # Darken background
	root.add_child(bg_map)
	bg_map.owner = root

	# 3. Generate Level Layout (Horizontal, 2560 wide (160 tiles), 720 high (45 tiles))
	var width_tiles = 160
	var height_tiles = 45
	
	# We'll use grass/dirt (0,0 to 2,2) for the terrain since we know it works.
	# Top left: 0,0, Top: 1,0, Top right: 2,0
	# Mid left: 0,1, Mid: 1,1, Mid right: 2,1
	# Bot left: 0,2, Bot: 1,2, Bot right: 2,2
	
	# Build Floor (y = 40 to 45)
	for x in range(-10, width_tiles + 10):
		for y in range(35, 45):
			if y == 35:
				tilemap.set_cell(Vector2i(x, y), 0, Vector2i(1, 0)) # Top dirt
			else:
				tilemap.set_cell(Vector2i(x, y), 0, Vector2i(1, 1)) # Inner dirt
				
	# Build Walls
	for y in range(-10, 45):
		# Left Wall
		for x in range(-10, 0):
			if x == -1:
				tilemap.set_cell(Vector2i(x, y), 0, Vector2i(2, 1)) # Right edge of left wall
			else:
				tilemap.set_cell(Vector2i(x, y), 0, Vector2i(1, 1))
		# Right Wall
		for x in range(width_tiles, width_tiles + 10):
			if x == width_tiles:
				tilemap.set_cell(Vector2i(x, y), 0, Vector2i(0, 1)) # Left edge of right wall
			else:
				tilemap.set_cell(Vector2i(x, y), 0, Vector2i(1, 1))

	# Function to generate a platform
	var add_platform = func(px, py, w, h):
		for x in range(px, px + w):
			for y in range(py, py + h):
				var ax = 1
				var ay = 1
				if x == px: ax = 0
				elif x == px + w - 1: ax = 2
				if y == py: ay = 0
				elif y == py + h - 1: ay = 2
				tilemap.set_cell(Vector2i(x, y), 0, Vector2i(ax, ay))
				
				# Add background pillars supporting the platform
				if y == py + h - 1:
					for bgy in range(py + h, 45):
						bg_map.set_cell(Vector2i(x, bgy), 0, Vector2i(1, 1))

	# 4. Design Platforming Layout
	add_platform.call(15, 28, 10, 3) # Platform 1
	add_platform.call(35, 22, 15, 3) # Platform 2
	add_platform.call(60, 26, 12, 3) # Platform 3
	add_platform.call(85, 18, 20, 3) # High Platform 4
	add_platform.call(115, 28, 10, 3) # Platform 5
	add_platform.call(135, 20, 15, 3) # Platform 6

	# 5. Add Parallax Background
	var pbg = ParallaxBackground.new()
	pbg.name = "ParallaxBackground"
	var pl = ParallaxLayer.new()
	pl.name = "ParallaxLayer"
	pl.motion_scale = Vector2(0.2, 0.2)
	pl.motion_mirroring = Vector2(1280, 720)
	pbg.add_child(pl)
	
	var spr = Sprite2D.new()
	spr.name = "BackgroundSprite"
	spr.texture = load("res://assets/backgrounds/main_menu background.jpg")
	spr.centered = false
	spr.modulate = Color(0.3, 0.3, 0.4) # Dark and moody
	# Scale it so it covers well
	spr.scale = Vector2(2.0, 2.0)
	pl.add_child(spr)
	
	root.add_child(pbg)
	pbg.owner = root
	pl.owner = root
	spr.owner = root

	# 6. Reposition Enemies & Spawns
	var spawn = root.get_node_or_null("SpawnPoints/PlayerSpawn")
	if spawn:
		spawn.position = Vector2(100, 500) # x=100 is ~tile 6. y=500 is ~tile 31.
		
	var enemies = root.get_node_or_null("Enemies")
	if enemies:
		# Reposition existing enemies across the new wide map
		var ge1 = enemies.get_node_or_null("GroundEnemy1")
		if ge1: ge1.position = Vector2(400, 500) # Under platform 1
		var ge2 = enemies.get_node_or_null("GroundEnemy2")
		if ge2: ge2.position = Vector2(1200, 500) # Middle floor
		var ge3 = enemies.get_node_or_null("GroundEnemy3")
		if ge3: ge3.position = Vector2(1500, 250) # High platform
		
		var fe1 = enemies.get_node_or_null("FlyingEnemy1")
		if fe1: fe1.position = Vector2(800, 300)
		var fe2 = enemies.get_node_or_null("FlyingEnemy2")
		if fe2: fe2.position = Vector2(2000, 350)
		
		# Add a few more enemies to fill the wide level
		var flying_scene = load("res://scenes/enemies/flying_enemy.tscn")
		var new_fe = flying_scene.instantiate()
		new_fe.name = "FlyingEnemy3"
		new_fe.position = Vector2(1800, 200)
		enemies.add_child(new_fe)
		new_fe.owner = root
		
	var new_scene = PackedScene.new()
	new_scene.pack(root)
	ResourceSaver.save(new_scene, scene_path)
	
	print("Combat level redesigned successfully!")
	quit(0)
