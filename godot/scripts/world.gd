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

var map: MapData
var tile_layer: TileMapLayer
var props: Node2D
var player: CharacterBody2D
var camera: Camera2D
var player_cell := Vector2i.ZERO
var kills := 0
var opened_chests: Array[String] = []  # session-only until saves land (PIX-122)
var chest_sprites := {}  # chest id -> Sprite2D
var hp_bar: ProgressBar
var kills_label: Label
var message_label: Label
var prompt_label: Label

func _ready() -> void:
	_setup_input()
	var args := OS.get_cmdline_user_args()
	var map_index := args.find("--map")
	var start := args[map_index + 1] if map_index >= 0 and map_index + 1 < args.size() else START_MAP
	map = MapData.load_by_id(start)
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
	if Input.is_action_just_pressed("interact"):
		_try_interact()
	_update_prompt()
	var cell := Vector2i((player.position / TILE).floor())
	if cell == player_cell:
		return
	player_cell = cell
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
	add_child(enemy)

func _use_portal(target: Dictionary) -> void:
	match target["kind"]:
		"map":
			map = MapData.load_by_id(target["mapId"])
			_enter_map(map, Vector2i(int(target["x"]), int(target["y"])))
		_:
			# Dungeons arrive with PIX-126.
			_flash_message("The way is sealed... for now.")

func _enter_map(next: MapData, arrival: Vector2i) -> void:
	for mob in get_tree().get_nodes_in_group("mobs"):
		mob.queue_free()
	if tile_layer != null:
		tile_layer.queue_free()
	if props != null:
		props.queue_free()
	tile_layer = _build_tile_layer(next)
	add_child(tile_layer)
	props = _build_props(next)
	add_child(props)
	# Layers are added after the player node exists — keep them behind actors.
	move_child(props, 0)
	move_child(tile_layer, 0)
	player.position = _cell_center(arrival)
	player_cell = arrival
	camera.limit_right = next.size.x * TILE
	camera.limit_bottom = next.size.y * TILE
	camera.reset_smoothing()
	if next.id in WILD_MAPS:
		_spawn_enemies(next)

func _cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell * TILE) + Vector2(TILE, TILE) / 2.0

## Chests, ground treasure, and door signs for the current map.
func _build_props(data: MapData) -> Node2D:
	var root := Node2D.new()
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
		root.add_child(sprite)
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
			root.add_child(body)
	for sign_def: Dictionary in Interactables.signs_on(data.id):
		var label := Label.new()
		label.text = sign_def["label"]
		label.add_theme_font_size_override("font_size", 8)
		label.add_theme_color_override("font_color", Color(1, 0.95, 0.75))
		label.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.12))
		label.add_theme_constant_override("outline_size", 3)
		label.custom_minimum_size = Vector2(64, 0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.position = Vector2(int(sign_def["x"]) * TILE + 8 - 32, int(sign_def["y"]) * TILE - 11)
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

	var layer := TileMapLayer.new()
	layer.tile_set = tileset
	for cell: Vector2i in data.grid:
		layer.set_cell(cell, source_ids[data.grid[cell]], Vector2i.ZERO)
	return layer

func _spawn_player() -> void:
	player = preload("res://scripts/player.gd").new()
	player.world = self
	add_child(player)

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
