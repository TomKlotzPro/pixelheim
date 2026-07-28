extends Node2D
## World orchestration: builds the TileMapLayer from MapData, spawns the hero
## and mobs, owns HUD/camera/respawn, and hosts the agent test harness.
## Tile tables live in WorldTiles; parsing in MapData.

const TILE := 16
const MAP_PATH := "res://assets/maps/overworld.txt"
const ENEMY_COUNT := 28
const MIN_SPAWN_DISTANCE_TILES := 8

var map: MapData
var player: CharacterBody2D
var kills := 0
var hp_bar: ProgressBar
var kills_label: Label

func _ready() -> void:
	_setup_input()
	map = MapData.load_from(MAP_PATH)
	add_child(_build_tile_layer())
	_spawn_player()
	_spawn_enemies()
	_build_hud()
	_run_test_harness()

func is_walkable(cell: Vector2i) -> bool:
	return map.is_walkable(cell)

func on_enemy_died() -> void:
	kills += 1
	kills_label.text = "Slain: %d" % kills

func on_player_hp_changed(hp: int) -> void:
	hp_bar.value = hp

func on_player_died() -> void:
	await get_tree().create_timer(1.2).timeout
	player.respawn(_cell_center(map.spawn))

func spawn_enemy(kind: String, cell: Vector2i) -> void:
	var enemy := preload("res://scripts/enemy.gd").new()
	enemy.world = self
	enemy.kind = kind
	enemy.position = _cell_center(cell)
	add_child(enemy)

func _cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell * TILE) + Vector2(TILE, TILE) / 2.0

func _build_tile_layer() -> TileMapLayer:
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(TILE, TILE)
	tileset.add_physics_layer()
	var box := PackedVector2Array([
		Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8),
	])
	var source_ids := {}  # tile id -> atlas source id
	for tile: String in WorldTiles.TILE_INFO:
		var source := TileSetAtlasSource.new()
		source.texture = load(WorldTiles.sprite_path(tile))
		source.texture_region_size = Vector2i(TILE, TILE)
		source.create_tile(Vector2i.ZERO)
		source_ids[tile] = tileset.add_source(source)
		if not WorldTiles.is_walkable(tile):
			var data := source.get_tile_data(Vector2i.ZERO, 0)
			data.add_collision_polygon(0)
			data.set_collision_polygon_points(0, 0, box)

	var layer := TileMapLayer.new()
	layer.tile_set = tileset
	for cell: Vector2i in map.grid:
		layer.set_cell(cell, source_ids[map.grid[cell]], Vector2i.ZERO)
	return layer

func _spawn_player() -> void:
	player = preload("res://scripts/player.gd").new()
	player.world = self
	player.position = _cell_center(map.spawn)
	add_child(player)

	var camera := Camera2D.new()
	camera.zoom = Vector2(3, 3)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = map.size.x * TILE
	camera.limit_bottom = map.size.y * TILE
	player.add_child(camera)

func _spawn_enemies() -> void:
	var habitats := {}  # mob kind -> Array[Vector2i]
	for cell: Vector2i in map.grid:
		var kind: String = WorldTiles.MOB_HABITATS.get(map.grid[cell], "")
		var far_enough := cell.distance_to(map.spawn) >= MIN_SPAWN_DISTANCE_TILES
		if kind != "" and far_enough:
			habitats.get_or_add(kind, []).append(cell)
	for kind: String in habitats:
		var cells: Array = habitats[kind]
		for i in ENEMY_COUNT / habitats.size():
			spawn_enemy(kind, cells.pick_random())

func _build_hud() -> void:
	var hud := CanvasLayer.new()
	add_child(hud)
	hp_bar = ProgressBar.new()
	hp_bar.position = Vector2(24, 24)
	hp_bar.custom_minimum_size = Vector2(180, 20)
	hp_bar.max_value = player.MAX_HP
	hp_bar.value = player.hp
	hp_bar.show_percentage = false
	hp_bar.modulate = Color(1, 0.45, 0.45)
	hud.add_child(hp_bar)
	kills_label = Label.new()
	kills_label.text = "Slain: 0"
	kills_label.position = Vector2(24, 50)
	hud.add_child(kills_label)

func _setup_input() -> void:
	var keys := {
		"move_up": [KEY_UP, KEY_W], "move_down": [KEY_DOWN, KEY_S],
		"move_left": [KEY_LEFT, KEY_A], "move_right": [KEY_RIGHT, KEY_D],
		"attack": [KEY_SPACE, KEY_J],
	}
	## action -> [stick axis, direction]
	var pad_motions := {
		"move_up": [JOY_AXIS_LEFT_Y, -1.0], "move_down": [JOY_AXIS_LEFT_Y, 1.0],
		"move_left": [JOY_AXIS_LEFT_X, -1.0], "move_right": [JOY_AXIS_LEFT_X, 1.0],
	}
	for action: String in keys:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key: Key in keys[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)
		if pad_motions.has(action):
			var motion := InputEventJoypadMotion.new()
			motion.axis = pad_motions[action][0]
			motion.axis_value = pad_motions[action][1]
			InputMap.action_add_event(action, motion)
	var pad_attack := InputEventJoypadButton.new()
	pad_attack.button_index = JOY_BUTTON_A
	InputMap.action_add_event("attack", pad_attack)

## Agent verification harness (headless can't render, so this drives a real
## window briefly): `godot --path godot -- --screenshot [fight] [kill]
## [--walk l,d,r,u,...]` scripts inputs, saves screenshot.png, quits.
## Documented in godot/README.md.
func _run_test_harness() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.has("--screenshot"):
		return
	await get_tree().create_timer(0.4).timeout
	var walk_index := args.find("--walk")
	if walk_index >= 0 and walk_index + 1 < args.size():
		var dirs := {
			"l": Vector2i.LEFT, "r": Vector2i.RIGHT, "u": Vector2i.UP, "d": Vector2i.DOWN,
		}
		for move in args[walk_index + 1].split(","):
			player.face(Vector2(dirs[move]))
			player.velocity = Vector2(dirs[move]) * player.SPEED
			await get_tree().create_timer(0.2).timeout
	if args.has("fight"):
		player.invulnerable = true
		spawn_enemy("orc", map.spawn + Vector2i(2, 0))
		player.face(Vector2.RIGHT)
		# `kill` swings until the orc drops to verify death + the kill counter;
		# plain `fight` captures mid-swing.
		var swings := 5 if args.has("kill") else 1
		for i in swings:
			player.attack()
			if i < swings - 1:
				await get_tree().create_timer(0.45).timeout
		await get_tree().create_timer(0.1).timeout
	else:
		await get_tree().create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://screenshot.png")
	print("screenshot saved; grid=%s spawn=%s hp=%d" % [map.size, map.spawn, player.hp])
	get_tree().quit()
