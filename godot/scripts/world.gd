extends Node2D
## Spike world (PIX-118): builds the overworld from the ASCII map shipped by
## the web game and runs live action combat — roaming Pixel Crawler mobs, free
## movement, sword swings. Char and walkability tables are ported verbatim from
## src/world/parseMap.ts and src/world/tiles.ts.

const TILE := 16
const MAP_PATH := "res://assets/maps/overworld.txt"
const ENEMY_COUNT := 28
const MIN_SPAWN_DISTANCE_TILES := 8
const SPAWN_CHARS := ["S", "$", "*"]

const CHAR_TILES := {
	".": "grass", "S": "grass", "f": "forest", "^": "mountain", "~": "water",
	"=": "path", "*": "path", "s": "sand", "b": "bridge", "w": "marsh",
	"a": "ash", "k": "crops", "T": "trophy_shelf", "G": "garden", "#": "wall",
	"_": "floor", "$": "floor", "r": "roof", "1": "roof_slate",
	"2": "roof_thatch", "3": "roof_awning", "4": "roof_moss",
	"h": "sign_smith", "m": "sign_inn", "p": "sign_potion", "g": "sign_goods",
	"F": "fence", "x": "flowers", "o": "barrel", "c": "crate", "O": "well",
	"L": "lamp", "A": "anvil", "e": "forge", "t": "shelf", "u": "cauldron",
	"n": "counter", "B": "bed", "H": "hearth", "D": "door", "d": "door_shut",
	"C": "cave", "W": "shrine",
}

## tile id -> [sprite basename, walkable]
const TILE_INFO := {
	"grass": ["tile_grass", true], "forest": ["tile_forest", true],
	"mountain": ["tile_mountain", false], "water": ["tile_water", false],
	"path": ["tile_path", true], "sand": ["tile_sand", true],
	"bridge": ["tile_bridge", true], "marsh": ["tile_marsh", true],
	"ash": ["tile_ash", true], "crops": ["tile_crops", true],
	"trophy_shelf": ["tile_trophy_shelf", false], "garden": ["tile_garden", false],
	"wall": ["tile_wall", false], "floor": ["tile_floor", true],
	"roof": ["tile_roof", false], "roof_slate": ["tile_roof_slate", false],
	"roof_thatch": ["tile_roof_thatch", false], "roof_awning": ["tile_roof_awning", false],
	"roof_moss": ["tile_roof_moss", false], "sign_goods": ["sign_goods", false],
	"sign_smith": ["sign_smith", false], "sign_potion": ["sign_potion", false],
	"sign_inn": ["sign_inn", false], "fence": ["tile_fence", false],
	"flowers": ["tile_flowers", true], "barrel": ["tile_barrel", false],
	"crate": ["tile_crate", false], "well": ["tile_well", false],
	"lamp": ["tile_lamp", false], "anvil": ["tile_anvil", false],
	"forge": ["tile_forge", false], "shelf": ["tile_shelf", false],
	"cauldron": ["tile_cauldron", false], "counter": ["tile_counter", false],
	"bed": ["tile_bed", false], "hearth": ["tile_hearth", false],
	"door": ["tile_door", true], "door_shut": ["tile_door_shut", false],
	"cave": ["tile_cave", true], "shrine": ["tile_shrine", true],
}

## tile id -> mob that roams there
const MOB_HABITATS := {
	"grass": "orc", "forest": "orc", "ash": "skeleton", "marsh": "skeleton",
}

var grid := {}  # Vector2i -> tile id
var map_size := Vector2i.ZERO
var spawn_cell := Vector2i.ZERO
var player: CharacterBody2D
var kills := 0
var hp_bar: ProgressBar
var kills_label: Label

func _ready() -> void:
	_setup_input()
	add_child(_build_map())
	spawn_cell = _find_spawn()
	_spawn_player()
	_spawn_enemies()
	_build_hud()
	_run_test_harness()

func is_walkable(cell: Vector2i) -> bool:
	var tile: String = grid.get(cell, "")
	return tile != "" and TILE_INFO[tile][1]

func on_enemy_died() -> void:
	kills += 1
	kills_label.text = "Slain: %d" % kills

func on_player_hp_changed(hp: int) -> void:
	hp_bar.value = hp

func on_player_died() -> void:
	await get_tree().create_timer(1.2).timeout
	player.respawn(_cell_center(spawn_cell))

func _cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell * TILE) + Vector2(TILE, TILE) / 2.0

func _build_map() -> TileMapLayer:
	var lines := FileAccess.get_file_as_string(MAP_PATH).strip_edges().split("\n")
	map_size = Vector2i(lines[0].length(), lines.size())

	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(TILE, TILE)
	tileset.add_physics_layer()
	var box := PackedVector2Array([
		Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8),
	])
	var source_ids := {}  # tile id -> atlas source id
	for tile: String in TILE_INFO:
		var source := TileSetAtlasSource.new()
		source.texture = load("res://assets/sprites/%s.png" % TILE_INFO[tile][0])
		source.texture_region_size = Vector2i(TILE, TILE)
		source.create_tile(Vector2i.ZERO)
		source_ids[tile] = tileset.add_source(source)
		if not TILE_INFO[tile][1]:
			var data := source.get_tile_data(Vector2i.ZERO, 0)
			data.add_collision_polygon(0)
			data.set_collision_polygon_points(0, 0, box)

	var layer := TileMapLayer.new()
	layer.tile_set = tileset
	for y in lines.size():
		for x in lines[y].length():
			var tile: String = CHAR_TILES.get(lines[y][x], "grass")
			grid[Vector2i(x, y)] = tile
			layer.set_cell(Vector2i(x, y), source_ids[tile], Vector2i.ZERO)
	return layer

func _find_spawn() -> Vector2i:
	var lines := FileAccess.get_file_as_string(MAP_PATH).strip_edges().split("\n")
	for spawn_char in SPAWN_CHARS:
		for y in lines.size():
			var x := lines[y].find(spawn_char)
			if x >= 0:
				return Vector2i(x, y)
	return map_size / 2

func _spawn_player() -> void:
	player = preload("res://scripts/player.gd").new()
	player.world = self
	player.position = _cell_center(spawn_cell)
	add_child(player)

	var camera := Camera2D.new()
	camera.zoom = Vector2(3, 3)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = map_size.x * TILE
	camera.limit_bottom = map_size.y * TILE
	player.add_child(camera)

func _spawn_enemies() -> void:
	var habitats := {}  # kind -> Array[Vector2i]
	for cell: Vector2i in grid:
		var kind: String = MOB_HABITATS.get(grid[cell], "")
		var far_enough := cell.distance_to(spawn_cell) >= MIN_SPAWN_DISTANCE_TILES
		if kind != "" and far_enough:
			habitats.get_or_add(kind, []).append(cell)
	for kind: String in habitats:
		var cells: Array = habitats[kind]
		for i in ENEMY_COUNT / habitats.size():
			spawn_enemy(kind, cells.pick_random())

func spawn_enemy(kind: String, cell: Vector2i) -> void:
	var enemy := preload("res://scripts/enemy.gd").new()
	enemy.world = self
	enemy.kind = kind
	enemy.position = _cell_center(cell)
	add_child(enemy)

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
	var bindings := {
		"move_up": [KEY_UP, KEY_W], "move_down": [KEY_DOWN, KEY_S],
		"move_left": [KEY_LEFT, KEY_A], "move_right": [KEY_RIGHT, KEY_D],
		"attack": [KEY_SPACE, KEY_J],
	}
	for action: String in bindings:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key: Key in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)

## `godot --path godot -- --screenshot [fight]` saves a frame for agent-side
## visual verification (headless can't render), then quits. `fight` warps an
## orc next to the hero and swings mid-frame.
func _run_test_harness() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.has("--screenshot"):
		return
	await get_tree().create_timer(0.4).timeout
	if args.has("fight"):
		player.invulnerable = true
		spawn_enemy("orc", spawn_cell + Vector2i(2, 0))
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
	print("screenshot saved; grid=%s spawn=%s hp=%d" % [map_size, spawn_cell, player.hp])
	get_tree().quit()
