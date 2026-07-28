extends Node2D
## World orchestration: loads maps exported from the web game, builds their
## TileMapLayer, moves the hero through portals, and spawns mobs in the wild.
## Tile tables live in WorldTiles; map data in MapData.

const TILE := 16
const START_MAP := "overworld"
## Maps where mobs roam; interiors and the town stay safe.
const WILD_MAPS := ["overworld", "deepwood", "mirefen"]
const ENEMY_COUNT := 28
const MIN_SPAWN_DISTANCE_TILES := 8

## Pixel Crawler decor scattered on terrain (PIX-121): trees over forest,
## plants over grass/marsh/ash. [texture path, region]; picked by cell hash.
const TREES := [
	["res://assets/crawler/tree_m01_s02.png", Rect2(12, 0, 52, 64)],
	["res://assets/crawler/tree_m01_s02.png", Rect2(76, 0, 52, 64)],
	["res://assets/crawler/tree_m02_s02.png", Rect2(0, 0, 32, 48)],
]
const TREE_DENSITY := 55  # % of forest cells that grow a full tree
## tile id -> [density %, sheet, [texture region choices]]
const SCATTER := {
	"grass": [6, "crawler/vegetation", [Rect2(0, 0, 32, 32), Rect2(80, 144, 16, 16), Rect2(96, 144, 16, 16)]],
	"forest": [40, "crawler/vegetation", [Rect2(0, 0, 32, 32), Rect2(80, 144, 16, 16)]],
	"marsh": [14, "crawler/vegetation", [Rect2(144, 160, 16, 16), Rect2(160, 160, 16, 16)]],
	"ash": [5, "crawler/vegetation", [Rect2(96, 0, 32, 32)]],
	"crops": [
		100, "crawler/farm",
		[Rect2(80, 16, 16, 16), Rect2(80, 48, 16, 16), Rect2(128, 80, 16, 16), Rect2(48, 80, 16, 16)],
	],
}

var map: MapData
var ground: ColorRect
var ground_noise: ImageTexture
var tile_layer: TileMapLayer
var props: Node2D
var actors: Node2D
var player: CharacterBody2D
var camera: Camera2D
var player_cell := Vector2i.ZERO
var kills := 0
var opened_chests: Array[String] = []  # session-only until saves land (PIX-122)
var chest_sprites := {}  # chest id -> Sprite2D
var discovered := {}  # map_id -> Dictionary(Vector2i -> true); saved by PIX-122
var settlers: Array = []  # nobody recruited until the settlers port (PIX-124)
var world_steps := 0.0  # tiles walked; turns the day/night wheel
var last_player_position := Vector2.ZERO
var hp_bar: ProgressBar
var kills_label: Label
var message_label: Label
var prompt_label: Label
var sky_overlay: ColorRect

func _ready() -> void:
	_setup_input()
	var args := OS.get_cmdline_user_args()
	var map_index := args.find("--map")
	var start := args[map_index + 1] if map_index >= 0 and map_index + 1 < args.size() else START_MAP
	map = MapData.load_by_id(start)
	# Hero, mobs, and decor share one y-sorted layer so the hero walks in
	# front of trunks and behind canopies.
	actors = Node2D.new()
	actors.y_sort_enabled = true
	add_child(actors)
	_spawn_player()
	_build_hud()
	# World-space "!" that floats over a faced interactable.
	prompt_label = Label.new()
	prompt_label.text = "!"
	prompt_label.add_theme_font_size_override("font_size", 10)
	prompt_label.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	prompt_label.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.12))
	prompt_label.add_theme_constant_override("outline_size", 3)
	prompt_label.visible = false
	add_child(prompt_label)
	_enter_map(map, map.spawn)
	_run_test_harness()

func _process(_delta: float) -> void:
	if player == null or player.dead:
		return
	if Input.is_action_just_pressed("map"):
		var screen := preload("res://scripts/map_screen.gd").new()
		screen.world = self
		add_child(screen)
		return
	if Input.is_action_just_pressed("interact"):
		_try_interact()
	_update_prompt()
	world_steps += player.position.distance_to(last_player_position) / TILE
	last_player_position = player.position
	sky_overlay.color = DayNight.sky_at(world_steps)
	var cell := Vector2i((player.position / TILE).floor())
	if cell == player_cell:
		return
	player_cell = cell
	Discovery.discover_around(discovered, map, cell)
	_collect_ground_treasure(cell)
	if map.portals.has(cell):
		_use_portal(map.portals[cell])

func is_walkable(cell: Vector2i) -> bool:
	return map.is_walkable(cell)

func on_enemy_died() -> void:
	kills += 1
	kills_label.text = "Slain: %d" % kills

func on_player_hp_changed(hp: int) -> void:
	hp_bar.value = hp

func on_player_died() -> void:
	await get_tree().create_timer(1.2).timeout
	if map.id != START_MAP:
		map = MapData.load_by_id(START_MAP)
		_enter_map(map, map.spawn)
	player.respawn(_cell_center(map.spawn))

func spawn_enemy(kind: String, cell: Vector2i) -> void:
	var enemy := preload("res://scripts/enemy.gd").new()
	enemy.world = self
	enemy.kind = kind
	enemy.position = _cell_center(cell)
	enemy.add_to_group("mobs")
	actors.add_child(enemy)

func _use_portal(target: Dictionary) -> void:
	match target["kind"]:
		"map":
			map = MapData.load_by_id(target["mapId"])
			_enter_map(map, Vector2i(int(target["x"]), int(target["y"])))
		_:
			# Dungeons arrive with PIX-126.
			_flash_message("The way is sealed... for now.")

func _enter_map(next: MapData, arrival: Vector2i) -> void:
	for stale in get_tree().get_nodes_in_group("mobs") + get_tree().get_nodes_in_group("decor"):
		stale.queue_free()
	if tile_layer != null:
		tile_layer.queue_free()
	if props != null:
		props.queue_free()
	if ground != null:
		ground.queue_free()
	ground = _build_ground(next)
	add_child(ground)
	tile_layer = _build_tile_layer(next)
	add_child(tile_layer)
	props = _build_props(next)
	add_child(props)
	# Layers are added after the actors layer exists — keep them behind it.
	move_child(props, 0)
	move_child(tile_layer, 0)
	move_child(ground, 0)
	_build_decor(next)
	player.position = _cell_center(arrival)
	last_player_position = player.position
	player_cell = arrival
	Discovery.discover_around(discovered, next, arrival)
	camera.limit_right = next.size.x * TILE
	camera.limit_bottom = next.size.y * TILE
	camera.reset_smoothing()
	if next.id in WILD_MAPS:
		_spawn_enemies(next)

## Fast travel from the map screen; the waypoint is already usability-checked.
func travel_to(waypoint: Dictionary) -> void:
	var arrival := Vector2i(int(waypoint["arrival"]["x"]), int(waypoint["arrival"]["y"]))
	if waypoint["mapId"] != map.id:
		map = MapData.load_by_id(waypoint["mapId"])
	_enter_map(map, arrival)

func _cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell * TILE) + Vector2(TILE, TILE) / 2.0

## Walkable ground drawn by the Voronoi blending shader (one quad per map):
## borders between grass/path/ash/marsh/sand meander instead of following the
## grid, and a broad noise octave varies brightness across fields.
func _build_ground(data: MapData) -> ColorRect:
	var ids := Image.create(data.size.x, data.size.y, false, Image.FORMAT_R8)
	for cell: Vector2i in data.grid:
		var index: int = WorldTiles.GROUND_TILES.get(data.grid[cell], 0)
		ids.set_pixelv(cell, Color(index / 255.0, 0, 0))
	if ground_noise == null:
		var noise := FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_CELLULAR
		noise.seed = 7
		noise.frequency = 0.09
		ground_noise = ImageTexture.create_from_image(noise.get_seamless_image(256, 256))
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/ground.gdshader")
	material.set_shader_parameter("id_map", ImageTexture.create_from_image(ids))
	material.set_shader_parameter("noise_tex", ground_noise)
	material.set_shader_parameter("fill_grass", load("res://assets/crawler/terrain/pc_grass.png"))
	material.set_shader_parameter("fill_dirt", load("res://assets/crawler/terrain/pc_dirt.png"))
	material.set_shader_parameter("fill_gravel", load("res://assets/crawler/terrain/pc_gravel.png"))
	material.set_shader_parameter("fill_marsh", load("res://assets/sprites/tile_marsh.png"))
	material.set_shader_parameter("fill_sand", load("res://assets/sprites/tile_sand.png"))
	material.set_shader_parameter("map_size", Vector2(data.size))
	var rect := ColorRect.new()
	rect.material = material
	rect.size = Vector2(data.size * TILE)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect

## Chests and terrain decor live in the y-sorted actors layer.
func _build_decor(data: MapData) -> void:
	chest_sprites = {}
	for chest: Dictionary in Interactables.chests_on(data.id):
		var opened: bool = chest["id"] in opened_chests
		var sprite_name := Interactables.sprite_name(chest, opened)
		if sprite_name == "":
			continue
		var cell := Vector2i(int(chest["x"]), int(chest["y"]))
		var sprite := Sprite2D.new()
		sprite.texture = load("res://assets/sprites/%s.png" % sprite_name)
		sprite.position = _cell_center(cell)
		sprite.add_to_group("decor")
		actors.add_child(sprite)
		chest_sprites[chest["id"]] = sprite
		if chest["look"] == "chest":
			# Furniture blocks the tile; ground treasure never does.
			var body := StaticBody2D.new()
			var shape := CollisionShape2D.new()
			var rect := RectangleShape2D.new()
			rect.size = Vector2(TILE, TILE)
			shape.shape = rect
			body.add_child(shape)
			body.position = _cell_center(cell)
			body.add_to_group("decor")
			actors.add_child(body)
	# Furniture and stations: one sprite per span of each horizontal run, so a
	# 3-tile counter shows one 48px counter instead of three overlapping ones.
	for cell: Vector2i in data.grid:
		var tile: String = data.grid[cell]
		if not WorldTiles.PROP_TILES.has(tile):
			continue
		if data.grid.get(cell + Vector2i.LEFT, "") == tile:
			continue  # not the run's left edge
		var run := 0
		while data.grid.get(cell + Vector2i(run, 0), "") == tile:
			run += 1
		var config: Array = WorldTiles.PROP_TILES[tile]
		var span := maxi(1, ceili((config[1] as Rect2).size.x / TILE))
		var i := 0
		while i < run:
			_add_prop_sprite(config[0], config[1], cell + Vector2i(i, 0))
			i += span
	for cell: Vector2i in data.grid:
		var tile: String = data.grid[cell]
		var h := absi(hash(cell))
		var roll := h % 100
		if tile == "forest" and roll < TREE_DENSITY:
			var pick: Array = TREES[(h >> 7) % TREES.size()]
			_add_decor_sprite(pick[0], pick[1], cell, h)
		elif SCATTER.has(tile) and roll - (TREE_DENSITY if tile == "forest" else 0) < SCATTER[tile][0]:
			var choices: Array = SCATTER[tile][2]
			_add_decor_sprite(
				WorldTiles.sprite_file(SCATTER[tile][1]),
				choices[(h >> 7) % choices.size()], cell, h
			)

func _add_prop_sprite(sheet: String, region: Rect2, cell: Vector2i) -> void:
	var atlas := AtlasTexture.new()
	atlas.atlas = load(WorldTiles.sprite_file(sheet))
	atlas.region = region
	var sprite := Sprite2D.new()
	sprite.texture = atlas
	sprite.centered = false
	sprite.position = Vector2(cell * TILE) + Vector2(0, TILE)
	sprite.offset = Vector2(0, -region.size.y)
	sprite.add_to_group("decor")
	actors.add_child(sprite)

func _add_decor_sprite(texture_path: String, region: Rect2, cell: Vector2i, h: int) -> void:
	var atlas := AtlasTexture.new()
	atlas.atlas = load(texture_path)
	atlas.region = region
	var sprite := Sprite2D.new()
	sprite.texture = atlas
	# Feet on the ground with a little organic jitter.
	sprite.position = _cell_center(cell) + Vector2((h >> 12) % 7 - 3, (h >> 16) % 5 - 2)
	sprite.offset = Vector2(0, -region.size.y / 2 + 6)
	sprite.add_to_group("decor")
	actors.add_child(sprite)

## Door signs float above the world, outside the y-sort.
func _build_props(data: MapData) -> Node2D:
	var root := Node2D.new()
	for sign_def: Dictionary in Interactables.signs_on(data.id):
		var label := Label.new()
		label.text = sign_def["label"]
		label.add_theme_font_size_override("font_size", 8)
		label.add_theme_color_override("font_color", Color(1, 0.95, 0.75))
		label.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.12))
		label.add_theme_constant_override("outline_size", 3)
		label.custom_minimum_size = Vector2(64, 0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		# Above the 2-tile-tall arch doors.
		label.position = Vector2(int(sign_def["x"]) * TILE + 8 - 32, int(sign_def["y"]) * TILE - 26)
		root.add_child(label)
	return root

func _chest_at(cell: Vector2i) -> Dictionary:
	for chest: Dictionary in Interactables.chests_on(map.id):
		if int(chest["x"]) == cell.x and int(chest["y"]) == cell.y:
			return chest
	return {}

func _facing_cell() -> Vector2i:
	return player_cell + Vector2i(player.facing)

func _try_interact() -> void:
	var chest := _chest_at(_facing_cell())
	if chest.is_empty() or chest["look"] != "chest" or chest["id"] in opened_chests:
		return
	_open_chest(chest)

func _open_chest(chest: Dictionary) -> void:
	opened_chests.append(chest["id"])
	chest_sprites[chest["id"]].texture = load("res://assets/sprites/chest_open.png")
	if chest.get("mimic", false):
		_flash_message("The chest bares its teeth — a mimic!")
		var ambush := player_cell + Vector2i(0, -1)
		if not map.is_walkable(ambush):
			ambush = player_cell + Vector2i(1, 0)
		spawn_enemy("skeleton", ambush)
		return
	_flash_message(Interactables.loot_text(chest))

func _collect_ground_treasure(cell: Vector2i) -> void:
	var chest := _chest_at(cell)
	if chest.is_empty() or chest["look"] == "chest" or chest["id"] in opened_chests:
		return
	opened_chests.append(chest["id"])
	chest_sprites[chest["id"]].queue_free()
	chest_sprites.erase(chest["id"])
	_flash_message(Interactables.loot_text(chest))

## The one interaction-prompt rule (ported from interactionPrompt.ts): a "!"
## floats over a faced, unopened chest. NPCs join with PIX-123.
func _update_prompt() -> void:
	var chest := _chest_at(_facing_cell())
	var show: bool = (
		not chest.is_empty() and chest["look"] == "chest" and not chest["id"] in opened_chests
	)
	prompt_label.visible = show
	if show:
		prompt_label.position = Vector2(_facing_cell() * TILE) + Vector2(5, -14)

func _build_tile_layer(data: MapData) -> TileMapLayer:
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(TILE, TILE)
	tileset.add_physics_layer()
	var box := PackedVector2Array([
		Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8),
	])
	var source_ids := {}  # tile id -> atlas source id
	for tile: String in WorldTiles.TILE_INFO:
		var source := TileSetAtlasSource.new()
		var sheet: String = WorldTiles.TILE_ANIMATIONS.get(tile, "")
		if sheet == "":
			source.texture = load(WorldTiles.sprite_path(tile))
			source.texture_region_size = Vector2i(TILE, TILE)
			source.create_tile(Vector2i.ZERO)
		else:
			# Animated terrain: the sheet is a horizontal strip; consecutive
			# columns become animation frames at the fps atlas.json declares.
			var meta: Dictionary = WorldTiles.atlas_animations()[sheet]
			source.texture = load("res://assets/sprites/%s.png" % sheet)
			source.texture_region_size = Vector2i(TILE, TILE)
			source.create_tile(Vector2i.ZERO)
			source.set_tile_animation_frames_count(Vector2i.ZERO, int(meta["frames"]))
			for i in int(meta["frames"]):
				source.set_tile_animation_frame_duration(Vector2i.ZERO, i, 1.0 / float(meta["fps"]))
		source_ids[tile] = tileset.add_source(source)
		if not WorldTiles.is_walkable(tile):
			var data_tile := source.get_tile_data(Vector2i.ZERO, 0)
			data_tile.add_collision_polygon(0)
			data_tile.set_collision_polygon_points(0, 0, box)
		if WorldTiles.ROOF_TILES.has(tile):
			source.get_tile_data(Vector2i.ZERO, 0).modulate = WorldTiles.ROOF_TILES[tile]

	# Roof eaves: tinted shingle edge for the bottom row of each roof.
	var eave_ids := {}
	for tile: String in WorldTiles.ROOF_TILES:
		var source := TileSetAtlasSource.new()
		source.texture = load(WorldTiles.sprite_file(WorldTiles.ROOF_EAVE))
		source.texture_region_size = Vector2i(TILE, TILE)
		source.create_tile(Vector2i.ZERO)
		eave_ids[tile] = tileset.add_source(source)
		var data_tile := source.get_tile_data(Vector2i.ZERO, 0)
		data_tile.modulate = WorldTiles.ROOF_TILES[tile]
		data_tile.add_collision_polygon(0)
		data_tile.set_collision_polygon_points(0, 0, box)

	# Cliff faces: a second source used on a tile's bottom edge.
	var face_ids := {}
	for tile: String in WorldTiles.FACE_TILES:
		var source := TileSetAtlasSource.new()
		source.texture = load(WorldTiles.sprite_file(WorldTiles.FACE_TILES[tile]))
		source.texture_region_size = Vector2i(TILE, TILE)
		source.create_tile(Vector2i.ZERO)
		face_ids[tile] = tileset.add_source(source)
		var data_tile := source.get_tile_data(Vector2i.ZERO, 0)
		data_tile.add_collision_polygon(0)
		data_tile.set_collision_polygon_points(0, 0, box)

	# Prop tiles show their base tile; the furniture sprite is y-sorted decor.
	# Unwalkable props still need a colliding version of that base.
	var blocked_base_ids := {}
	for tile: String in WorldTiles.PROP_TILES:
		var base: String = WorldTiles.PROP_TILES[tile][2]
		if WorldTiles.is_walkable(tile) or blocked_base_ids.has(base):
			continue
		var source := TileSetAtlasSource.new()
		source.texture = load(WorldTiles.sprite_path(base))
		source.texture_region_size = Vector2i(TILE, TILE)
		source.create_tile(Vector2i.ZERO)
		blocked_base_ids[base] = tileset.add_source(source)
		var data_tile := source.get_tile_data(Vector2i.ZERO, 0)
		data_tile.add_collision_polygon(0)
		data_tile.set_collision_polygon_points(0, 0, box)

	var layer := TileMapLayer.new()
	layer.tile_set = tileset
	for cell: Vector2i in data.grid:
		var tile: String = data.grid[cell]
		if WorldTiles.GROUND_TILES.has(tile):
			continue  # the ground shader draws these
		var source_id: int = source_ids[tile]
		if WorldTiles.FACE_TILES.has(tile) and data.grid.get(cell + Vector2i.DOWN, tile) != tile:
			source_id = face_ids[tile]
		elif (
			WorldTiles.ROOF_TILES.has(tile)
			and not WorldTiles.ROOF_TILES.has(data.grid.get(cell + Vector2i.DOWN, ""))
		):
			source_id = eave_ids[tile]
		elif WorldTiles.PROP_TILES.has(tile):
			var base: String = WorldTiles.PROP_TILES[tile][2]
			var blocked: bool = not WorldTiles.is_walkable(tile)
			source_id = blocked_base_ids[base] if blocked else source_ids[base]
		layer.set_cell(cell, source_id, Vector2i.ZERO)
	return layer

func _spawn_player() -> void:
	player = preload("res://scripts/player.gd").new()
	player.world = self
	actors.add_child(player)

	camera = Camera2D.new()
	camera.zoom = Vector2(3, 3)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	camera.limit_left = 0
	camera.limit_top = 0
	player.add_child(camera)

func _spawn_enemies(data: MapData) -> void:
	var habitats := {}  # mob kind -> Array[Vector2i]
	for cell: Vector2i in data.grid:
		var kind: String = WorldTiles.MOB_HABITATS.get(data.grid[cell], "")
		var far_enough := cell.distance_to(data.spawn) >= MIN_SPAWN_DISTANCE_TILES
		if kind != "" and far_enough:
			habitats.get_or_add(kind, []).append(cell)
	for kind: String in habitats:
		var cells: Array = habitats[kind]
		for i in ENEMY_COUNT / habitats.size():
			spawn_enemy(kind, cells.pick_random())

func _build_hud() -> void:
	var hud := CanvasLayer.new()
	add_child(hud)
	# Day/night tint sits under the HUD widgets, over the world.
	sky_overlay = ColorRect.new()
	sky_overlay.color = Color(0, 0, 0, 0)
	sky_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(sky_overlay)
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
	message_label = Label.new()
	message_label.position = Vector2(440, 640)
	message_label.custom_minimum_size = Vector2(400, 0)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.modulate.a = 0.0
	hud.add_child(message_label)

func _flash_message(text: String) -> void:
	message_label.text = text
	var tween := create_tween()
	tween.tween_property(message_label, "modulate:a", 1.0, 0.15)
	tween.tween_interval(1.6)
	tween.tween_property(message_label, "modulate:a", 0.0, 0.4)

func _setup_input() -> void:
	var keys := {
		"move_up": [KEY_UP, KEY_W], "move_down": [KEY_DOWN, KEY_S],
		"move_left": [KEY_LEFT, KEY_A], "move_right": [KEY_RIGHT, KEY_D],
		"attack": [KEY_SPACE, KEY_J],
		"interact": [KEY_E, KEY_ENTER],
		"map": [KEY_M, KEY_TAB],
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
	var pad_interact := InputEventJoypadButton.new()
	pad_interact.button_index = JOY_BUTTON_B
	InputMap.action_add_event("interact", pad_interact)
	var pad_map := InputEventJoypadButton.new()
	pad_map.button_index = JOY_BUTTON_Y
	InputMap.action_add_event("map", pad_map)

## Agent verification harness (headless can't render, so this drives a real
## window briefly): `godot --path godot -- --screenshot [fight] [kill]
## [--map <id>] [--walk l,d,r,u,...]` scripts inputs, saves screenshot.png,
## quits. Documented in godot/README.md.
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
			player.scripted_dir = Vector2(dirs[move])
			await get_tree().create_timer(0.2).timeout
		player.scripted_dir = Vector2.ZERO
	if args.has("night"):
		world_steps = 0.7 * DayNight.DAY_CYCLE_STEPS
	if args.has("worldmap"):
		var screen := preload("res://scripts/map_screen.gd").new()
		screen.world = self
		add_child(screen)
		await get_tree().create_timer(0.3).timeout
	if args.has("chest"):
		# Pair with `--map town`: warp beside the nook chest, face it, open it.
		player.position = _cell_center(Vector2i(61, 18))
		player_cell = Vector2i(61, 18)
		player.face(Vector2.RIGHT)
		_try_interact()
		await get_tree().create_timer(0.3).timeout
	if args.has("fight"):
		player.invulnerable = true
		spawn_enemy("orc", player_cell + Vector2i(2, 0))
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
	print("screenshot saved; map=%s cell=%s hp=%d" % [map.id, player_cell, player.hp])
	get_tree().quit()
