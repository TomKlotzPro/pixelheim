extends Node2D
## World orchestration: loads maps exported from the web game, builds their
## TileMapLayer, moves the hero through portals, and spawns mobs in the wild.
## Tile tables live in WorldTiles; map data in MapData; everything that
## persists (position, discovery, chests, loot) in the GameState autoload.

const TILE := 16
## Defeat sends the hero back to the overworld spawn until combat v2 (PIX-126)
## wakes them at the inn like the web game.
const RESPAWN_MAP := "overworld"
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
var chest_sprites := {}  # chest id -> Sprite2D
var last_player_position := Vector2.ZERO
var hp_bar: ProgressBar
var kills_label: Label
var gold_label: Label
var message_label: Label
var prompt_label: Label
var sky_overlay: ColorRect

func _ready() -> void:
	_setup_input()
	var args := OS.get_cmdline_user_args()
	GameState.boot(args)
	# Harness: `--town-tier N` previews the village at another age.
	var tier_index := args.find("--town-tier")
	if tier_index >= 0 and tier_index + 1 < args.size():
		GameState.settlement.town_tier = int(args[tier_index + 1])
	var house_index := args.find("--house-tier")
	if house_index >= 0 and house_index + 1 < args.size():
		GameState.settlement.house["tier"] = int(args[house_index + 1])
	# Resume where the save stands; `--map <id>` (harness) boots at that map's spawn.
	var map_index := args.find("--map")
	var override := map_index >= 0 and map_index + 1 < args.size()
	map = _load_map(args[map_index + 1] if override else GameState.world.map_id)
	var arrival := map.spawn if override else GameState.world.cell
	if not map.is_walkable(arrival):
		arrival = map.spawn
	# Hero, mobs, and decor share one y-sorted layer so the hero walks in
	# front of trunks and behind canopies.
	actors = Node2D.new()
	actors.y_sort_enabled = true
	add_child(actors)
	_spawn_player()
	player.face(WorldState.FACINGS.get(GameState.world.facing, Vector2.DOWN))
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
	_enter_map(map, arrival)
	# A first visit to the Godot build that finds a web game hero in this
	# browser offers to bring them along before anything else.
	if GameState.first_run:
		var found := WebImport.find_in_browser()
		if not found.is_empty():
			_open_saves(found, true)
	_run_test_harness()

func _process(_delta: float) -> void:
	if player == null or player.dead:
		return
	if Input.is_action_just_pressed("menu"):
		_open_saves()
		return
	if Input.is_action_just_pressed("map"):
		var screen := preload("res://scripts/map_screen.gd").new()
		screen.world = self
		add_child(screen)
		return
	if Input.is_action_just_pressed("interact"):
		_try_interact()
	_update_prompt()
	GameState.walk(player.position.distance_to(last_player_position) / TILE)
	last_player_position = player.position
	sky_overlay.color = DayNight.sky_at(GameState.world.steps)
	var cell := Vector2i((player.position / TILE).floor())
	if cell == player_cell:
		return
	player_cell = cell
	GameState.move_to(map, cell, player.facing)
	# Walking into the bought house's shut door walks you in.
	if map.id == "town" and cell + Vector2i(player.facing) == Town.house_door() and GameState.owns_house():
		_enter_house()
		return
	_collect_ground_treasure(cell)
	if map.portals.has(cell):
		_use_portal(map.portals[cell])

## Maps as the town has grown: the village and the house redraw per tier.
func _load_map(map_id: String) -> MapData:
	return MapData.load_tiered(map_id, GameState.town_tier(), int(GameState.settlement.house.get("tier", 1)))

func is_walkable(cell: Vector2i) -> bool:
	return map.is_walkable(cell)

func on_enemy_died() -> void:
	kills += 1
	kills_label.text = "Slain: %d" % kills

func on_player_hp_changed(hp: int) -> void:
	hp_bar.value = hp

func on_player_died() -> void:
	await get_tree().create_timer(1.2).timeout
	if map.id != RESPAWN_MAP:
		map = _load_map(RESPAWN_MAP)
		_enter_map(map, map.spawn)
	player.respawn(_cell_center(map.spawn))
	last_player_position = player.position  # a respawn is not a walk
	GameState.move_to(map, map.spawn, player.facing)

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
			map = _load_map(target["mapId"])
			_enter_map(map, Vector2i(int(target["x"]), int(target["y"])))
			# Stepping into the inn takes a bed for coin, as on the web.
			if map.id == "town_inn":
				_flash_message(GameState.rest_at_inn(player.hp < player.MAX_HP))
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
	_build_furniture()
	_spawn_npcs(next)
	player.position = _cell_center(arrival)
	last_player_position = player.position
	player_cell = arrival
	# Crossing into a map is a moment worth keeping: save at once.
	GameState.move_to(next, arrival, player.facing)
	GameState.save_now()
	camera.limit_right = next.size.x * TILE
	camera.limit_bottom = next.size.y * TILE
	camera.reset_smoothing()
	if next.id in WILD_MAPS:
		_spawn_enemies(next)

## The saves screen; `web_save` defaults to whatever this browser's web game holds.
func _open_saves(web_save := {}, welcome := false) -> void:
	var screen := preload("res://scripts/saves_screen.gd").new()
	screen.web_save = web_save if not web_save.is_empty() else WebImport.find_in_browser()
	screen.welcome = welcome
	add_child(screen)

## Fast travel from the map screen; the waypoint is already usability-checked.
func travel_to(waypoint: Dictionary) -> void:
	var arrival := Vector2i(int(waypoint["arrival"]["x"]), int(waypoint["arrival"]["y"]))
	if waypoint["mapId"] != map.id:
		map = _load_map(waypoint["mapId"])
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
		var sprite_name := Interactables.sprite_name(chest, GameState.is_opened(chest))
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

## Villagers who live on this map now: tier-gated townsfolk and recruits.
func _spawn_npcs(data: MapData) -> void:
	var settlers := GameState.settlement.settlers
	for npc: Dictionary in Npcs.on_map(data.id, GameState.settlement.town_tier, settlers):
		var villager := preload("res://scripts/npc.gd").new()
		villager.world = self
		villager.data = npc
		villager.add_to_group("decor")
		villager.add_to_group("npcs")
		actors.add_child(villager)

## A recruit settled or the town grew: redraw who stands on this map.
func _respawn_npcs() -> void:
	for villager in get_tree().get_nodes_in_group("npcs"):
		villager.queue_free()
	_spawn_npcs(map)

## The villager beside the hero, faced side first: {npc, side} or {}.
func _npc_beside() -> Dictionary:
	var occupied := {}
	for villager in get_tree().get_nodes_in_group("npcs"):
		occupied[villager.cell] = villager.data
	return Npcs.beside(occupied, player_cell, Vector2i(player.facing))

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
	for sign_def: Dictionary in Interactables.signs_on(data.id, GameState.owns_house()):
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

## E in the web's INTERACT order: a faced chest, the house door, the house's
## fixtures, then the villager beside the hero (turning to face them).
func _try_interact() -> void:
	var faced := _facing_cell()
	var chest := _chest_at(faced)
	if not chest.is_empty() and chest["look"] == "chest" and not GameState.is_opened(chest):
		_open_chest(chest)
		return
	if map.id == "town" and faced == Town.house_door():
		if GameState.owns_house():
			_enter_house()
		else:
			_flash_message(GameState.buy_house())
		return
	if map.id == "town_house" and _house_interact(faced):
		return
	var beside := _npc_beside()
	if not beside.is_empty():
		player.face(Vector2(beside["side"]))
		# Keepers trade instead of chatting: anyone in a shop opens its counter,
		# the mayor opens the town ledger, a settled Mirelle her bank.
		if GameState.active_shop() != "":
			_open_shop()
		elif map.id == "town_hall":
			add_child(preload("res://scripts/town_hall_screen.gd").new())
		elif beside["npc"]["id"] == "settler_mirelle" and GameState.is_settled("settler_mirelle"):
			add_child(preload("res://scripts/bank_screen.gd").new())
		else:
			_talk(beside["npc"])
		return

func _enter_house() -> void:
	map = _load_map("town_house")
	_enter_map(map, Vector2i(8, 8))

## The house's fixtures and furniture; true when E meant one of them.
func _house_interact(cell: Vector2i) -> bool:
	var result := GameState.house_interact(cell, map.tile_at(cell))
	if result.is_empty():
		return false
	if result.has("text"):
		_flash_message(result["text"])
	if result.has("panel"):
		var screen := preload("res://scripts/home_screen.gd").new()
		screen.mode = result["panel"]
		screen.cell = cell
		screen.on_placed = _build_furniture
		add_child(screen)
	_build_furniture()
	return true

## Placed furniture in the house: y-sorted sprites that block (rugs lie flat).
func _build_furniture() -> void:
	for piece in get_tree().get_nodes_in_group("furniture"):
		piece.queue_free()
	if map.id != "town_house":
		return
	for placed: Dictionary in GameState.furniture():
		var item_id: String = placed["itemId"]
		var cell := Vector2i(placed["x"], placed["y"])
		var sprite := Sprite2D.new()
		sprite.texture = load("res://assets/sprites/%s.png" % Catalog.item(item_id)["sprite"])
		sprite.position = _cell_center(cell)
		sprite.add_to_group("furniture")
		sprite.add_to_group("decor")
		if not Town.furniture_blocks(item_id):
			sprite.z_index = -1  # underfoot
		actors.add_child(sprite)
		if Town.furniture_blocks(item_id):
			var body := StaticBody2D.new()
			var shape := CollisionShape2D.new()
			var rect := RectangleShape2D.new()
			rect.size = Vector2(TILE, TILE)
			shape.shape = rect
			body.add_child(shape)
			body.position = _cell_center(cell)
			body.add_to_group("furniture")
			body.add_to_group("decor")
			actors.add_child(body)

func _open_shop() -> void:
	add_child(preload("res://scripts/shop_screen.gd").new())

func _talk(npc: Dictionary) -> void:
	var box := preload("res://scripts/dialogue_box.gd").new()
	box.npc = npc
	add_child(box)

func _open_chest(chest: Dictionary) -> void:
	var result := GameState.open_chest(chest)
	_flash_message(result["message"])
	if not result["opened"]:
		return
	chest_sprites[chest["id"]].texture = load("res://assets/sprites/chest_open.png")
	if result["mimic"]:
		var ambush := player_cell + Vector2i(0, -1)
		if not map.is_walkable(ambush):
			ambush = player_cell + Vector2i(1, 0)
		spawn_enemy("skeleton", ambush)

func _collect_ground_treasure(cell: Vector2i) -> void:
	var chest := _chest_at(cell)
	if chest.is_empty() or chest["look"] == "chest" or GameState.is_opened(chest):
		return
	var result := GameState.open_chest(chest)
	_flash_message(result["message"])
	if result["opened"]:
		chest_sprites[chest["id"]].queue_free()
		chest_sprites.erase(chest["id"])

## The one interaction-prompt rule (interactionPrompt.ts): a villager beside
## the hero wins, then a faced unopened chest. Villagers stand two tiles tall,
## so their "!" floats higher.
func _update_prompt() -> void:
	var beside := _npc_beside()
	if not beside.is_empty():
		prompt_label.visible = true
		prompt_label.position = Vector2((player_cell + Vector2i(beside["side"])) * TILE) + Vector2(5, -30)
		return
	var chest := _chest_at(_facing_cell())
	var show: bool = (
		not chest.is_empty() and chest["look"] == "chest" and not GameState.is_opened(chest)
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
	gold_label = Label.new()
	gold_label.position = Vector2(24, 74)
	hud.add_child(gold_label)
	_on_gold_changed(GameState.pack.gold)
	GameState.gold_changed.connect(_on_gold_changed)
	GameState.message.connect(_flash_message)
	GameState.healed.connect(func() -> void: player.heal())
	GameState.settlers_changed.connect(_respawn_npcs)
	message_label = Label.new()
	message_label.position = Vector2(440, 640)
	message_label.custom_minimum_size = Vector2(400, 0)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.modulate.a = 0.0
	hud.add_child(message_label)

func _on_gold_changed(gold: int) -> void:
	gold_label.text = "Gold: %d" % gold

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
		"menu": [KEY_ESCAPE],
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
	var pad_menu := InputEventJoypadButton.new()
	pad_menu.button_index = JOY_BUTTON_START
	InputMap.action_add_event("menu", pad_menu)

## Agent verification harness (headless can't render, so this drives a real
## window briefly): `godot --path godot -- --screenshot [fight] [kill] [saves]
## [--map <id>] [--walk l,d,r,u,...] [--web-save <file>]` scripts inputs,
## saves screenshot.png, quits. Documented in godot/README.md.
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
		GameState.world.steps = 0.7 * DayNight.DAY_CYCLE_STEPS
	if args.has("worldmap"):
		var screen := preload("res://scripts/map_screen.gd").new()
		screen.world = self
		add_child(screen)
		await get_tree().create_timer(0.3).timeout
	if args.has("shop"):
		# Pair with `--map town_shop|town_smith|town_alchemist`; `--tab N` picks a tab.
		GameState.pack.gold = 500
		var screen: Node = preload("res://scripts/shop_screen.gd").new()
		add_child(screen)
		var tab_index := args.find("--tab")
		if tab_index >= 0 and tab_index + 1 < args.size():
			screen._switch(int(args[tab_index + 1]))
		await get_tree().create_timer(0.3).timeout
	if args.has("home"):
		# Pair with `--map town_house`; `--mode storage|workbench|trophies|nook|furniture`.
		GameState.settlement.house["owned"] = true
		GameState.pack.items.merge({"furn_plant": 1, "furn_rug": 1, "potion_hp": 4, "gem": 1})
		var mode_index := args.find("--mode")
		var screen := preload("res://scripts/home_screen.gd").new()
		screen.mode = args[mode_index + 1] if mode_index >= 0 else "storage"
		add_child(screen)
		await get_tree().create_timer(0.3).timeout
	if args.has("hall") or args.has("bank"):
		GameState.pack.gold = 20000
		var ledger := "town_hall_screen" if args.has("hall") else "bank_screen"
		add_child(load("res://scripts/%s.gd" % ledger).new())
		await get_tree().create_timer(0.3).timeout
	if args.has("saves"):
		# `--web-save <file>` stands in for a browser's web save (a code or JSON)
		# and opens the first-visit offer.
		var web_index := args.find("--web-save")
		var web_file := args[web_index + 1] if web_index >= 0 and web_index + 1 < args.size() else ""
		var stand_in := WebImport.parse_any(FileAccess.get_file_as_string(web_file)) if web_file != "" else {}
		_open_saves(stand_in, not stand_in.is_empty())
		await get_tree().create_timer(0.3).timeout
	if args.has("talk") or args.has("near"):
		# Stand below the map's first villager facing up; `talk` also presses E.
		var villager: Node = get_tree().get_first_node_in_group("npcs")
		player.position = _cell_center(villager.cell + Vector2i.DOWN)
		player_cell = villager.cell + Vector2i.DOWN
		player.face(Vector2.UP)
		if args.has("talk"):
			_try_interact()
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
	print("screenshot saved; map=%s cell=%s hp=%d gold=%d" % [map.id, player_cell, player.hp, GameState.pack.gold])
	get_tree().quit()
