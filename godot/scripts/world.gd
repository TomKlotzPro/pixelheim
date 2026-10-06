extends Node2D
## World orchestration: loads maps exported from the web game, builds their
## TileMapLayer, moves the hero through portals, and spawns mobs in the wild.
## Tile tables live in WorldTiles; map data in MapData; everything that
## persists (position, discovery, chests, loot) in the GameState autoload.

const TILE := 16
## Monsters at each of the web's visible spawn points: a small pack of the
## species that lives there, so the real-time fight has bodies to swing at.
const PACK_SIZE := 3
const LOG_LINES := 5
const LOG_SECONDS := 4.0
## The dark under the mountain, whatever the hour above.
const DUNGEON_GLOOM := Color(0.04, 0.02, 0.08, 0.28)
## Fight music holds this long after the last hunter gives up.
const COMBAT_LINGER_S := 3.0

## Puny World objects scattered on terrain (PIX-130), picked by cell hash:
## tile id -> [density %, [Puny tile ids]]. Forests grow pines and round
## trees, the blocked highlands carry pines and boulders, fields the odd
## stone or stump, and crops stand in rows of wheat.
const SCATTER := {
	"forest": [85, [197, 224, 251, 206, 233, 260, 705, 729, 732, 783, 810]],
	"mountain": [30, [197, 224, 251, 783, 810, 702]],
	"grass": [3, [702, 703, 730, 784]],
	"ash": [6, [702, 703, 784, 811, 838]],
	"marsh": [10, [703, 732, 838]],
	"crops": [100, [756, 757]],
}

var map: MapData
var ground: Node2D
## Region tones (ash, mire) shared by the ground and the decor standing on it.
var ground_tint: ShaderMaterial
var tile_layer: TileMapLayer
var props: Node2D
var actors: Node2D
var player: CharacterBody2D
var camera: Camera2D
var player_cell := Vector2i.ZERO
var kills := 0
var chest_sprites := {}  # chest id -> Sprite2D
var last_player_position := Vector2.ZERO
## The hero panel: health, resource, xp, gold, the screens (HudPanel).
var hud_panel: PanelContainer
var log_box: VBoxContainer
## spawn id -> monsters of its pack still standing
var pack_alive := {}
## Sound's view of the hero: what changed is heard (coin, heal, hurt).
var heard_gold := 0
var heard_hp := 0
## When something last hunted the hero, and whether a boss did.
var hunted_at := -100.0
var hunted_by_boss := false
var noticed_at := -100.0
## Foes still standing on the dungeon floor the hero walks (0 when cleared).
var floor_foes := 0
## Torches, barrels, stairs on a dungeon floor; a cleared floor's way up joins them.
var dungeon_objects: TileMapLayer
var message_label: Label
var prompt_label: Label
var sky_overlay: ColorRect

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	GameState.boot(args)
	Sound.apply_volumes()
	_setup_input()
	apply_video.call_deferred()
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
	var greeted := false
	if GameState.first_run:
		var found := WebImport.find_in_browser()
		if not found.is_empty():
			_open_saves(found, true)
			greeted = true
	# The title greets a launch (not a slot switch or a reload, and not the harness).
	var harness := OS.get_cmdline_user_args().has("--screenshot")
	if not greeted and not GameState.title_seen and (not harness or OS.get_cmdline_user_args().has("title")):
		_open_title()
	_run_test_harness()


func _open_title() -> void:
	var title := preload("res://scripts/title_screen.gd").new()
	title.world = self
	add_child(title)

func _process(_delta: float) -> void:
	if player == null or player.dead:
		return
	if Input.is_action_just_pressed("menu"):
		var pause := preload("res://scripts/pause_screen.gd").new()
		pause.world = self
		add_child(pause)
		return
	for screen: String in ["journal", "stats", "skills", "codex", "inventory"]:
		if Input.is_action_just_pressed(screen):
			open_screen(screen)
			return
	if Input.is_action_just_pressed("map"):
		open_screen("map")
		return
	if Input.is_action_just_pressed("interact"):
		_try_interact()
	_update_prompt()
	GameState.walk(player.position.distance_to(last_player_position) / TILE)
	last_player_position = player.position
	sky_overlay.color = DUNGEON_GLOOM if map.floor_level > 0 else DayNight.sky_at(GameState.world.steps)
	_update_music()
	var cell := Vector2i((player.position / TILE).floor())
	if cell == player_cell:
		return
	player_cell = cell
	Sound.play("step")
	# Down a dungeon the save keeps the hero at its gate, as the web does.
	if map.floor_level == 0:
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

## A monster fell: the web's victory pays out, and the last of a spawn's pack
## clears that spawn until the hero leaves the map.
func on_enemy_died(enemy: Node) -> void:
	kills += 1
	var cleared := ""
	if enemy.spawn_id != "":
		pack_alive[enemy.spawn_id] = pack_alive.get(enemy.spawn_id, 1) - 1
		if pack_alive[enemy.spawn_id] <= 0:
			cleared = enemy.spawn_id
	var floor_level := int(Bestiary.region(enemy.region).get("dropFloor", 1)) if enemy.region != "" else 1
	if map.floor_level > 0:
		floor_level = map.floor_level
	var gear_before := GameState.pack.gear.size()
	_log(GameState.defeat_monster(enemy.fighter, enemy.region, cleared, floor_level))
	if GameState.pack.gear.size() > gear_before:
		Sound.play("drop")
	if cleared != "":
		_log(["The wilds fall quiet again."])
	if map.floor_level > 0 and floor_foes > 0:
		floor_foes -= 1
		if floor_foes == 0:
			_floor_cleared(Vector2i((enemy.position / TILE).floor()))

func on_player_died() -> void:
	await get_tree().create_timer(1.2).timeout
	# Defeat is forgiving: wake at the inn, healed, purse intact.
	var inn: Dictionary = GameState.wake_at_inn()
	var bed := Vector2i(inn["x"], inn["y"])
	map = _load_map(inn["mapId"])
	_enter_map(map, bed)
	player.respawn(_cell_center(bed))
	last_player_position = player.position  # a respawn is not a walk

## One monster of `species` at `cell`; wild ones pay the reduced wild rewards.
func spawn_enemy(species: String, cell: Vector2i, region := "", spawn_id := "", elite := false, wild := true) -> void:
	var enemy := preload("res://scripts/enemy.gd").new()
	enemy.world = self
	var fighter := Bestiary.spawn(species, elite)
	enemy.fighter = Bestiary.wild(fighter) if wild else fighter
	enemy.region = region
	enemy.spawn_id = spawn_id
	enemy.position = _cell_center(cell)
	enemy.add_to_group("mobs")
	actors.add_child(enemy)

## A number that rises and fades where a blow landed.
func float_number(value: int, at: Vector2, color: Color) -> void:
	var label := Label.new()
	label.text = str(value)
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.12))
	label.add_theme_constant_override("outline_size", 3)
	label.position = at - Vector2(6, 0)
	label.z_index = 10
	add_child(label)
	var tween := create_tween().set_parallel()
	tween.tween_property(label, "position:y", label.position.y - 12, 0.6).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.6).set_delay(0.25)
	tween.chain().tween_callback(label.queue_free)

func log_line(line: String) -> void:
	_log([line])

## The battle log: recent lines stack bottom-left and fade.
func _log(lines: Array) -> void:
	for line: String in lines:
		var label := Label.new()
		label.text = line
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08))
		label.add_theme_constant_override("outline_size", 4)
		log_box.add_child(label)
		var tween := label.create_tween()
		tween.tween_interval(LOG_SECONDS)
		tween.tween_property(label, "modulate:a", 0.0, 0.6)
		tween.tween_callback(label.queue_free)
	while log_box.get_child_count() > LOG_LINES:
		var oldest := log_box.get_child(0)
		log_box.remove_child(oldest)
		oldest.queue_free()

func _on_hp_changed(_hp: int, _max_hp: int) -> void:
	hud_panel.refresh()

func _use_portal(target: Dictionary) -> void:
	match target["kind"]:
		"map":
			map = _load_map(target["mapId"])
			_enter_map(map, Vector2i(int(target["x"]), int(target["y"])))
			# Stepping into the inn takes a bed for coin, as on the web.
			if map.id == "town_inn":
				_flash_message(GameState.rest_at_inn())
		"dungeon":
			# The floor select opens while the hero waits at the door.
			_step_back()
			var screen := preload("res://scripts/dungeon_screen.gd").new()
			screen.world = self
			screen.dungeon_id = target["dungeon"]
			add_child(screen)
		"gate":
			_leave_floor()


## One of the hero's screens, from its key or the panel's button.
func open_screen(screen: String) -> void:
	if player.dead or get_tree().paused:
		return
	match screen:
		"inventory":
			_open_inventory()
		"map":
			if map.floor_level > 0:
				_flash_message("No map reaches this deep.")
				return
			var chart := preload("res://scripts/map_screen.gd").new()
			chart.world = self
			add_child(chart)
		_:
			add_child(load("res://scripts/%s_screen.gd" % screen).new())


func _open_inventory() -> void:
	var screen := preload("res://scripts/inventory_screen.gd").new()
	screen.world = self
	add_child(screen)


## Furniture from the pack onto the floor tile the hero faces (PLACE_FURNITURE).
func place_from_pack(item_id: String) -> void:
	var cell := _facing_cell()
	var text := GameState.place_furniture(item_id, cell, map.tile_at(cell))
	if text != "":
		_flash_message(text)
	_build_furniture()


## Gold that grows rings (SFX.coin); health heard rising or falling.
func _hear_gold(gold: int) -> void:
	if gold > heard_gold:
		Sound.play("coin")
	heard_gold = gold


func _hear_hp(hp: int, _max_hp: int) -> void:
	if hp < heard_hp:
		Sound.play("hurt")
	elif hp > heard_hp:
		Sound.play("heal")
	heard_hp = hp


## A fight is on: something has hunted the hero in the last few seconds.
func in_fight() -> bool:
	return Time.get_ticks_msec() / 1000.0 - hunted_at < COMBAT_LINGER_S


## A skill's light where it lands: a soft burst that swells and fades.
func skill_flash(at: Vector2, color: Color) -> void:
	var burst := Sprite2D.new()
	burst.texture = preload("res://scripts/player.gd")._glow()
	burst.modulate = Color(color, 0.85)
	burst.global_position = at
	burst.scale = Vector2(0.4, 0.6)
	burst.z_index = 5
	add_child(burst)
	var bloom := create_tween().set_parallel()
	bloom.tween_property(burst, "scale", Vector2(1.6, 2.2), 0.35).set_ease(Tween.EASE_OUT)
	bloom.tween_property(burst, "modulate:a", 0.0, 0.35)
	bloom.chain().tween_callback(burst.queue_free)


## Something has seen the hero: a growl (SFX.bump), not more than once a beat.
func on_enemy_noticed(enemy: Node) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - noticed_at > 1.5:
		Sound.play("bump")
	noticed_at = now
	hunted_at = now
	hunted_by_boss = hunted_by_boss or Bestiary.is_boss(enemy.fighter["id"])


## The place's theme, or the fight's while anything hunts the hero (and a
## few seconds after), the boss's when a boss does; and the place's weather.
func _update_music() -> void:
	if not GameState.title_seen and not OS.get_cmdline_user_args().has("--screenshot"):
		return  # the title plays its own
	var now := Time.get_ticks_msec() / 1000.0
	for enemy in get_tree().get_nodes_in_group("mobs"):
		if enemy.hunting and not enemy.dying:
			hunted_at = now
			hunted_by_boss = hunted_by_boss or Bestiary.is_boss(enemy.fighter["id"])
	var fight := ""
	if now - hunted_at < COMBAT_LINGER_S:
		fight = "boss" if hunted_by_boss else "battle"
	else:
		hunted_by_boss = false
	if Sound.track != "victory" or fight != "":
		Sound.play_track(Sound.track_for(map.id, map.floor_level, fight))
	Sound.set_ambience(Sound.ambience_for(map.id, map.floor_level))


## The ascension scene: a new title, and at a fork the path cards.
func _ascend(title: String) -> void:
	Sound.play("evolve")
	player.refresh_rank()
	var scene := preload("res://scripts/rankup_screen.gd").new()
	scene.title = title
	add_child(scene)


## Back off a gate to the cell the hero came from (the web keeps them there).
func _step_back() -> void:
	var back := player_cell - Vector2i(player.facing)
	if not map.is_walkable(back):
		return
	player_cell = back
	player.position = _cell_center(back)
	last_player_position = player.position
	GameState.move_to(map, back, player.facing)


## Down to a dungeon floor (DungeonFloor): its foes one per room, the
## guardian last. The save still holds the gate the hero entered by.
func enter_floor(level: int) -> void:
	var plan := DungeonFloor.plan(level)
	map = plan["map"]
	_enter_map(map, map.spawn)
	floor_foes = plan["foes"].size()
	for foe: Dictionary in plan["foes"]:
		spawn_enemy(foe["id"], foe["cell"], "", "", foe["elite"], false)
	var floor_def := Dungeons.floor_def(level)
	_log(["Floor %d: %s" % [level, floor_def["name"]], String(floor_def["description"])])


## Up the stairs, back to the gate the save remembers.
func _leave_floor() -> void:
	map = _load_map(GameState.world.map_id)
	_enter_map(map, Vector2i(GameState.world.cell))


## The floor's last foe fell: its hoard on a first clear, and a way up where
## the guardian stood, so the hero needn't walk the halls back.
func _floor_cleared(at: Vector2i) -> void:
	var result := GameState.clear_floor(map.floor_level)
	Sound.play("victory")
	_log(result["lines"])
	var stairs := at
	if not map.is_walkable(stairs) or map.portals.has(stairs):
		stairs = player_cell
	map.grid[stairs] = "cave"
	map.portals[stairs] = {"kind": "gate"}
	PunyDungeon.sheet().place(dungeon_objects, stairs, PunyDungeon.STAIRS)
	if result["victory"]:
		Sound.play_track("victory")
		_talk({
			"id": "victory", "name": "Victory",
			"lines": [
				"%s slew Fafnyr the Ashen above and cast down Morvax the Deathless below." % GameState.hero.name,
				"The mountain is quiet at last, the tavern is loud, and the cheese has never tasted better.",
			],
		})

func _enter_map(next: MapData, arrival: Vector2i) -> void:
	if tile_layer != null:
		Sound.play("door")
	hunted_at = -100.0
	for stale in get_tree().get_nodes_in_group("mobs") + get_tree().get_nodes_in_group("decor"):
		stale.queue_free()
	if tile_layer != null:
		tile_layer.queue_free()
	if props != null:
		props.queue_free()
	if ground != null:
		ground.queue_free()
	ground = _build_dungeon(next) if next.floor_level > 0 else _build_ground(next)
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
	player.ailments.clear()
	last_player_position = player.position
	player_cell = arrival
	# Crossing into a map is a moment worth keeping: save at once. Dungeon
	# floors aren't web maps: the save keeps the gate.
	if next.floor_level == 0:
		GameState.move_to(next, arrival, player.facing)
		GameState.save_now()
	floor_foes = 0
	camera.limit_right = next.size.x * TILE
	camera.limit_bottom = next.size.y * TILE
	camera.reset_smoothing()
	_spawn_enemies(next)
	_update_music()

## The saves screen; `web_save` defaults to whatever this browser's web game holds.
func _open_saves(web_save := {}, welcome := false) -> void:
	var screen := preload("res://scripts/saves_screen.gd").new()
	screen.web_save = web_save if not web_save.is_empty() else WebImport.find_in_browser()
	screen.welcome = welcome
	add_child(screen)

## Fast travel from the map screen; the waypoint is already usability-checked.
func travel_to(waypoint: Dictionary) -> void:
	Sound.play("travel")
	var arrival := Vector2i(int(waypoint["arrival"]["x"]), int(waypoint["arrival"]["y"]))
	if waypoint["mapId"] != map.id:
		map = _load_map(waypoint["mapId"])
	_enter_map(map, arrival)

func _cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell * TILE) + Vector2(TILE, TILE) / 2.0

## The ground in Shade's Puny World tiles (PunyTerrain): grass, roads, sand,
## cliffs and rippling water on the dual grid, half a tile up-left of the
## cells so every terrain edge sits on a cell edge.
func _build_ground(data: MapData) -> Node2D:
	var root := Node2D.new()
	var layer := TileMapLayer.new()
	layer.tile_set = PunyTerrain.tileset()
	layer.position = Vector2(-TILE, -TILE) / 2.0
	var tiles := PunyTerrain.ground_tiles(data.grid, data.size)
	for cell: Vector2i in tiles:
		PunyTerrain.place(layer, cell, tiles[cell])
	# Ash and mire are toned from Shade's dirt and grass, decor included.
	ground_tint = ShaderMaterial.new()
	ground_tint.shader = preload("res://shaders/region_tint.gdshader")
	ground_tint.set_shader_parameter("tint_map", PunyTerrain.tint_map(data.grid, data.size))
	ground_tint.set_shader_parameter("map_pixels", Vector2(data.size * TILE))
	layer.material = ground_tint
	root.add_child(layer)
	var forest := TileMapLayer.new()
	forest.tile_set = PunyTerrain.tileset()
	forest.position = layer.position
	var crowns := PunyTerrain.forest_tiles(data.grid, data.size)
	for cell: Vector2i in crowns:
		PunyTerrain.place(forest, cell, crowns[cell])
	root.add_child(forest)
	# Bridges, cave mouths, ramparts and (seen from afar) whole towns stand on
	# that ground as Puny objects.
	var objects := TileMapLayer.new()
	objects.tile_set = PunyTerrain.tileset()
	var outdoor := PunyTerrain.is_outdoor(data.grid)
	for cell: Vector2i in data.grid:
		var object := PunyTerrain.object_at(data.grid, cell)
		if outdoor and object < 0:
			object = PunyTerrain.wall_piece(data.grid, cell)
		if object >= 0:
			PunyTerrain.place(objects, cell, object)
	if data.id in PunyTerrain.SKYLINE_MAPS:
		var skyline := PunyTerrain.skyline(data.grid)
		for cell: Vector2i in skyline:
			PunyTerrain.place(objects, cell, skyline[cell])
	root.add_child(objects)
	return root

## A dungeon floor in Shade's Puny Dungeon: stone, walls by his grammar and
## the dark beyond, torches flickering on their blocks, barrels, pots and the
## stairs up.
func _build_dungeon(data: MapData) -> Node2D:
	var root := Node2D.new()
	var dungeon := PunyDungeon.sheet()
	var layer := TileMapLayer.new()
	layer.tile_set = dungeon.tileset
	dungeon_objects = TileMapLayer.new()
	dungeon_objects.tile_set = dungeon.tileset
	for cell: Vector2i in data.grid:
		var tile: String = data.grid[cell]
		match tile:
			"wall":
				dungeon.place(layer, cell, PunyDungeon.wall_tile(data.grid, cell))
				continue
			"lamp":
				dungeon.place(layer, cell, PunyDungeon.TORCH_BLOCK)
				dungeon.place(dungeon_objects, cell, PunyDungeon.TORCH)
				continue
		dungeon.place(layer, cell, PunyDungeon.floor_tile(cell))
		match tile:
			"barrel":
				dungeon.place(dungeon_objects, cell, PunyDungeon.BARRELS[absi(hash(cell)) % 2])
			"crate":
				dungeon.place(dungeon_objects, cell, PunyDungeon.POT)
			"cave":
				dungeon.place(dungeon_objects, cell, PunyDungeon.STAIRS)
	root.add_child(layer)
	root.add_child(dungeon_objects)
	return root

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
	# Gates in outdoor ramparts are drawn by the Puny castle pieces.
	var outdoor := PunyTerrain.is_outdoor(data.grid)
	for cell: Vector2i in data.grid:
		var tile: String = data.grid[cell]
		if not WorldTiles.PROP_TILES.has(tile):
			continue
		if outdoor and PunyTerrain.wall_piece(data.grid, cell) == PunyTerrain.GATE:
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
		if not SCATTER.has(tile):
			continue
		var h := absi(hash(cell))
		if h % 100 >= SCATTER[tile][0]:
			continue
		var choices: Array = SCATTER[tile][1]
		_add_decor_sprite(PunyTerrain.SHEET, PunyTerrain.region(choices[(h >> 7) % choices.size()]), cell, h)
		actors.get_child(-1).material = ground_tint

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
		# Craft stations advertise their trade with an icon over the name, on
		# a little plate in the web's sign wood so it reads against any wall.
		if sign_def.has("icon"):
			var texture: Texture2D = load("res://assets/sprites/%s.png" % sign_def["icon"])
			var size := texture.get_size() + Vector2(4, 4)
			var plate := ColorRect.new()
			plate.color = Color("2a2118")
			plate.size = size
			plate.position = Vector2(int(sign_def["x"]) * TILE + 8 - size.x / 2, label.position.y - size.y + 1)
			var rim := ColorRect.new()
			rim.color = Color("8a6238")
			rim.size = Vector2(size.x, 1)
			plate.add_child(rim)
			var icon := TextureRect.new()
			icon.texture = texture
			icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			icon.position = Vector2(2, 2)
			plate.add_child(icon)
			root.add_child(plate)
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
	Sound.play("chest")
	if result["mimic"]:
		var ambush := player_cell + Vector2i(0, -1)
		if not map.is_walkable(ambush):
			ambush = player_cell + Vector2i(1, 0)
		spawn_enemy("mimic", ambush, map.region_at(ambush), "", false, true)

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
## the hero wins, then a faced unopened chest; the "!" floats over their head.
func _update_prompt() -> void:
	var beside := _npc_beside()
	if not beside.is_empty():
		prompt_label.visible = true
		prompt_label.position = Vector2((player_cell + Vector2i(beside["side"])) * TILE) + Vector2(5, -20)
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
	var outdoor := PunyTerrain.is_outdoor(data.grid)
	for tile: String in WorldTiles.TILE_INFO:
		if WorldTiles.GROUND_TILES.has(tile):
			continue  # the Puny ground draws these
		var source := TileSetAtlasSource.new()
		var sheet: String = WorldTiles.TILE_ANIMATIONS.get(tile, "")
		var cut: bool = outdoor and tile in WorldTiles.GRASS_PROPS
		if sheet == "":
			var path := WorldTiles.sprite_path(tile)
			if outdoor and tile == "floor":
				source.texture = PunyDungeon.sheet().tile_texture(PunyDungeon.FLOOR)
			else:
				source.texture = WorldTiles.cutout(path) if cut else load(path)
			source.texture_region_size = Vector2i(TILE, TILE)
			source.create_tile(Vector2i.ZERO)
		else:
			# Animated terrain: the sheet is a horizontal strip; consecutive
			# columns become animation frames at the fps atlas.json declares.
			var meta: Dictionary = WorldTiles.atlas_animations()[sheet]
			var path := "res://assets/sprites/%s.png" % sheet
			source.texture = WorldTiles.cutout(path) if cut else load(path)
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

	# Ground the Puny layer draws still blocks where the web says so (water,
	# mountains): an invisible tile that only collides.
	var blocker := TileSetAtlasSource.new()
	blocker.texture = ImageTexture.create_from_image(Image.create(TILE, TILE, false, Image.FORMAT_RGBA8))
	blocker.texture_region_size = Vector2i(TILE, TILE)
	blocker.create_tile(Vector2i.ZERO)
	var blocker_id := tileset.add_source(blocker)
	var blocker_tile := blocker.get_tile_data(Vector2i.ZERO, 0)
	blocker_tile.add_collision_polygon(0)
	blocker_tile.set_collision_polygon_points(0, 0, box)

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
	var skyline: bool = data.id in PunyTerrain.SKYLINE_MAPS
	for cell: Vector2i in data.grid:
		var tile: String = data.grid[cell]
		var puny_drawn: bool = (
			data.floor_level > 0
			or WorldTiles.GROUND_TILES.has(tile)
			or (outdoor and PunyTerrain.wall_piece(data.grid, cell) >= 0)
			or (skyline and WorldTiles.ROOF_TILES.has(tile))
		)
		if puny_drawn:
			if not WorldTiles.is_walkable(tile):
				layer.set_cell(cell, blocker_id, Vector2i.ZERO)
			continue
		var source_id: int = source_ids[tile]
		if (
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
	# Shade's figures are 16px: 4x shows ~20x11 tiles, close to the web game's view.
	camera.zoom = Vector2(4, 4)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	camera.limit_left = 0
	camera.limit_top = 0
	player.add_child(camera)

## Packs at the web's visible spawns (spawns.ts): the species its region and
## position decide, an elite roll each, none where the slain ledger says the
## spawn was cleared on this visit.
func _spawn_enemies(data: MapData) -> void:
	pack_alive = {}
	for spawn: Dictionary in Bestiary.spawns_on(data.id):
		if spawn["id"] in GameState.world.slain:
			continue
		var home := Vector2i(spawn["x"], spawn["y"])
		var region := data.region_at(home)
		var species := Bestiary.species_at(region, home)
		var elite_chance := float(Bestiary.region(region)["eliteChance"])
		var cells: Array[Vector2i] = [home]
		for offset in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1)]:
			var cell: Vector2i = home + offset
			if cells.size() < PACK_SIZE and data.is_walkable(cell) and data.region_at(cell) != "" and not data.portals.has(cell):
				cells.append(cell)
		for cell in cells:
			spawn_enemy(species, cell, region, spawn["id"], GameState.roll.call() < elite_chance)
		pack_alive[spawn["id"]] = cells.size()

func _build_hud() -> void:
	var hud := CanvasLayer.new()
	add_child(hud)
	# Day/night tint sits under the HUD widgets, over the world.
	sky_overlay = ColorRect.new()
	sky_overlay.color = Color(0, 0, 0, 0)
	sky_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(sky_overlay)
	hud_panel = preload("res://scripts/hud_panel.gd").new()
	hud_panel.world = self
	hud.add_child(hud_panel)
	var skill_bar := preload("res://scripts/skill_bar.gd").new()
	skill_bar.world = self
	hud.add_child(skill_bar)
	log_box = VBoxContainer.new()
	log_box.position = Vector2(24, 520)
	log_box.custom_minimum_size = Vector2(700, 0)
	log_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(log_box)
	GameState.hp_changed.connect(_on_hp_changed)
	heard_gold = GameState.pack.gold
	heard_hp = GameState.hero.hp
	GameState.gold_changed.connect(_hear_gold)
	GameState.hp_changed.connect(_hear_hp)
	GameState.leveled_up.connect(func(_level: int) -> void:
		Sound.play("levelUp")
		heard_hp = GameState.hero.hp
	)
	GameState.loaded.connect(func() -> void:
		heard_gold = GameState.pack.gold
		heard_hp = GameState.hero.hp
	)
	GameState.gold_changed.connect(func(_gold: int) -> void: hud_panel.refresh())
	GameState.inventory_changed.connect(hud_panel.refresh)
	GameState.healed.connect(hud_panel.refresh)
	GameState.message.connect(_flash_message)
	GameState.healed.connect(func() -> void: player.heal())
	GameState.ranked_up.connect(_ascend)
	GameState.settlers_changed.connect(_respawn_npcs)
	message_label = Label.new()
	message_label.position = Vector2(190, 610)
	message_label.custom_minimum_size = Vector2(900, 0)
	message_label.size = Vector2(900, 0)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	message_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.12))
	message_label.add_theme_constant_override("outline_size", 4)
	message_label.modulate.a = 0.0
	hud.add_child(message_label)

## A line for the hero, held long enough to read (quests say a lot).
func _flash_message(text: String) -> void:
	message_label.text = text
	var tween := create_tween()
	tween.tween_property(message_label, "modulate:a", 1.0, 0.15)
	tween.tween_interval(clampf(text.length() / 22.0, 1.6, 6.0))
	tween.tween_property(message_label, "modulate:a", 0.0, 0.4)

## The keys, as the player bound them (Controls, GameSettings).
func _setup_input() -> void:
	Controls.apply(GameState.settings.bindings)


var crt: CanvasLayer

## The CRT scanlines over everything, and fullscreen (never in harness runs).
func apply_video() -> void:
	var settings := GameState.settings
	if settings.scanlines and crt == null:
		crt = CanvasLayer.new()
		crt.layer = 20
		var lines := ColorRect.new()
		lines.set_anchors_preset(Control.PRESET_FULL_RECT)
		lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var material := ShaderMaterial.new()
		material.shader = preload("res://shaders/crt.gdshader")
		lines.material = material
		crt.add_child(lines)
		add_child(crt)
	elif not settings.scanlines and crt != null:
		crt.queue_free()
		crt = null
	if OS.get_cmdline_user_args().has("--screenshot"):
		return
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if settings.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)

## Agent verification harness (headless can't render, so this drives a real
## window briefly): `godot --path godot -- --screenshot [fight] [kill] [saves]
## [--map <id>] [--walk l,d,r,u,...] [--web-save <file>]` scripts inputs,
## saves screenshot.png, quits. Documented in godot/README.md.
## Harness `lineup`: the cast PunyArt assigns, side by side with names.
func _lineup() -> void:
	for node in get_tree().get_nodes_in_group("mobs") + get_tree().get_nodes_in_group("npcs"):
		node.queue_free()
	camera.zoom = Vector2(2.6, 2.6)
	var rows := [
		PunyArt.HEROES.keys().map(func(role: String) -> Array: return [role, PunyArt.hero(role)]),
		PunyArt.VILLAGERS.keys().map(func(id: String) -> Array: return [id, PunyArt.villager(id)]),
		PunyArt.MONSTERS.keys().map(func(id: String) -> Array: return [id, PunyArt.monster(id)]),
	]
	var origin := player.position + Vector2(-210, -100)
	var y := 0
	for row: Array in rows:
		for dir in ["down", "right"]:
			var x := 0
			for entry: Array in row:
				var spec: Dictionary = entry[1]
				var sprite := AnimatedSprite2D.new()
				sprite.sprite_frames = PunyArt.frames(spec)
				sprite.play(PunyArt.pick(sprite.sprite_frames, "walk", dir))
				sprite.scale = Vector2.ONE * spec.get("scale", 1.0)
				sprite.self_modulate = spec.get("tint", Color.WHITE)
				sprite.position = origin + Vector2(x * 28, y * 34)
				add_child(sprite)
				if dir == "down":
					var label := Label.new()
					label.text = entry[0]
					label.add_theme_font_size_override("font_size", 5)
					label.position = sprite.position + Vector2(-12, 9)
					add_child(label)
				x += 1
			y += 1

func _run_test_harness() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.has("--screenshot"):
		return
	await get_tree().create_timer(0.4).timeout
	# Dungeons: `--floor N` walks down floor N, `gate [--dungeon id]` opens a
	# gate's floor select (mountain by default).
	var floor_index := args.find("--floor")
	if floor_index >= 0 and floor_index + 1 < args.size():
		enter_floor(int(args[floor_index + 1]))
		await get_tree().create_timer(0.3).timeout
	if args.has("clear"):
		# Fell every foe on the floor at once: the clear, its hoard, the way up.
		for foe in get_tree().get_nodes_in_group("mobs"):
			foe.take_hit(99999, foe.global_position + Vector2.LEFT)
		await get_tree().create_timer(0.6).timeout
	if args.has("gate"):
		var dungeon_index := args.find("--dungeon")
		_use_portal({
			"kind": "dungeon",
			"dungeon": args[dungeon_index + 1] if dungeon_index >= 0 else "mountain",
		})
		await get_tree().create_timer(0.3).timeout
		if args.has("descend"):
			# Take the selected floor, as E would.
			get_children().filter(func(node: Node) -> bool: return node.has_method("_descend"))[0]._act()
			await get_tree().create_timer(0.4).timeout
	if args.has("leave"):
		# Up the stairs, back to the gate.
		_use_portal({"kind": "gate"})
		await get_tree().create_timer(0.3).timeout
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
	# Terrain review: `--at x,y` stands the hero on a cell, `--zoom Z` changes
	# the camera, `overview` frames the whole map.
	var at_index := args.find("--at")
	if at_index >= 0 and at_index + 1 < args.size():
		var at := args[at_index + 1].split(",")
		player_cell = Vector2i(int(at[0]), int(at[1]))
		player.position = _cell_center(player_cell)
		camera.reset_smoothing()
	var zoom_index := args.find("--zoom")
	if zoom_index >= 0 and zoom_index + 1 < args.size():
		camera.zoom = Vector2.ONE * float(args[zoom_index + 1])
	if args.has("overview"):
		var view := get_viewport_rect().size
		var fit := minf(view.x / (map.size.x * TILE), view.y / (map.size.y * TILE))
		camera.top_level = true
		camera.zoom = Vector2(fit, fit)
		camera.limit_right = 1 << 20
		camera.limit_bottom = 1 << 20
		camera.limit_left = -(1 << 20)
		camera.limit_top = -(1 << 20)
		camera.global_position = Vector2(map.size * TILE) / 2.0
		camera.reset_smoothing()
		await get_tree().create_timer(0.2).timeout
	if args.has("worldmap"):
		var screen := preload("res://scripts/map_screen.gd").new()
		screen.world = self
		add_child(screen)
		await get_tree().create_timer(0.3).timeout
	var level_index := args.find("--level")
	if level_index >= 0 and level_index + 1 < args.size():
		# A hero of that level: the rank's title, aura and presence.
		GameState.hero.level = int(args[level_index + 1])
		player.refresh_rank()
		_on_hp_changed(GameState.hero.hp, int(GameState.hero.stats["maxHp"]))
	if args.has("rankup"):
		# Enough XP to cross into the next rank: the ascension plays.
		var hero := GameState.hero
		hero.level = (HeroRules.rank_index(hero.level) + 1) * 5 - 1
		hero.xp_to_next = HeroState.xp_to_next_for(hero.level)
		hero.xp = hero.xp_to_next
		GameState._grant_levels()
		await get_tree().create_timer(1.6).timeout
		if args.has("walk-path"):
			get_children().filter(func(node: Node) -> bool: return node.has_method("_walk"))[0]._walk()
			await get_tree().create_timer(0.3).timeout
	if args.has("stats") or args.has("skills"):
		# Points to spend: a few of each.
		GameState.hero.stat_points = 5
		GameState.hero.skill_points = 3
		var sheet := "stats_screen" if args.has("stats") else "skills_screen"
		add_child(load("res://scripts/%s.gd" % sheet).new())
		await get_tree().create_timer(0.3).timeout
	if args.has("splash"):
		# Pair with `title`: the boot splash, once every letter has landed.
		get_children().filter(func(node: Node) -> bool: return node.has_method("as_splash"))[0].as_splash()
		await get_tree().create_timer(1.2).timeout
	if args.has("create"):
		# Hero creation over the title, a role picked and a name typed.
		var creation := preload("res://scripts/create_screen.gd").new()
		creation.world = self
		creation.role_index = 4
		creation.look = 1
		add_child(creation)
		await get_tree().create_timer(0.1).timeout
		creation.name_field.text = "Robin"
		creation._refresh()
		await get_tree().create_timer(0.4).timeout
	if args.has("title") and args.has("options"):
		# Options over the title, before any hero is made.
		get_children().filter(func(node: Node) -> bool: return node.has_method("as_splash"))[0]._options()
		await get_tree().create_timer(0.3).timeout
	elif args.has("pause") or args.has("options"):
		if args.has("scanlines"):
			GameState.settings.scanlines = true
			apply_video()
		var pause := preload("res://scripts/pause_screen.gd").new()
		pause.world = self
		add_child(pause)
		if args.has("options"):
			pause._options()
		await get_tree().create_timer(0.3).timeout
	if args.has("inventory"):
		# A pack worth reading: a fine sword, armor worn, potions and an antidote.
		var sword := InventoryState.create_gear("iron_sword", "fine")
		var armor := InventoryState.create_gear("leather_armor")
		var ring := InventoryState.create_gear("band_of_grit")
		GameState.pack.gear.append_array([sword, armor, ring])
		GameState.equip(armor["uid"])
		GameState.equip(ring["uid"])
		GameState.pack.items.merge({"potion_hp": 3, "antidote": 1, "wolf_pelt": 2})
		_open_inventory()
		await get_tree().create_timer(0.3).timeout
	if args.has("codex"):
		# A record to read: twelve beasts (Slayer I) and a few undead.
		GameState.hero.mastery = {"beasts": 12, "undead": 3}
		var codex := preload("res://scripts/codex_screen.gd").new()
		codex.tab = 1 if args.has("bestiary") else 0
		add_child(codex)
		await get_tree().create_timer(0.3).timeout
	if args.has("quest"):
		# A conversation with the elder closes: his quest is accepted.
		GameState.finish_dialogue("elder")
		await get_tree().create_timer(0.3).timeout
	if args.has("journal"):
		# A few promises in hand: slimes half done, the cheese ready, the troll kept.
		GameState.progression.quests.merge({
			"slime_trouble": {"progress": 2, "done": false},
			"cheese_run": {"progress": 0, "done": false},
			"troll_toll": {"progress": 1, "done": true},
		})
		GameState.pack.add_item("cheese_wheel")
		add_child(preload("res://scripts/journal_screen.gd").new())
		await get_tree().create_timer(0.3).timeout
	if args.has("lineup"):
		# Every hero role, villager and monster sheet, walking down then right.
		_lineup()
		await get_tree().create_timer(0.5).timeout
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
	if args.has("portal"):
		# Walk into the map's nearest doorway from a free side, as a player would.
		var doors := map.portals.keys()
		doors.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return a.distance_squared_to(player_cell) < b.distance_squared_to(player_cell)
		)
		for door: Vector2i in doors:
			var sides := [Vector2i.DOWN, Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT].filter(
				func(side: Vector2i) -> bool:
					return map.is_walkable(door + side) and not map.portals.has(door + side)
			)
			if sides.is_empty():
				continue
			var side: Vector2i = sides[0]
			player.position = _cell_center(door + side)
			player_cell = door + side
			player.scripted_dir = Vector2(-side)
			await get_tree().create_timer(0.4).timeout
			player.scripted_dir = Vector2.ZERO
			break
		await get_tree().create_timer(0.3).timeout
	if args.has("die"):
		# A blow no hero survives: the fall, then waking at the inn.
		player.take_hit(99999, player.global_position + Vector2.LEFT)
		await get_tree().create_timer(1.8).timeout
	if args.has("cast"):
		# A foe two steps away, then the first skill: the strike, the flash, the log.
		player.invulnerable = true
		spawn_enemy("orc", player_cell + Vector2i(2, 0), "ash")
		player.face(Vector2.RIGHT)
		await get_tree().create_timer(0.2).timeout
		player.cast(0)
		await get_tree().create_timer(0.15).timeout
	if args.has("fight"):
		# `--foe <species>` picks the opponent (default orc); `hurt` lets it bite.
		var foe_index := args.find("--foe")
		var foe: String = args[foe_index + 1] if foe_index >= 0 and foe_index + 1 < args.size() else "orc"
		player.invulnerable = not args.has("hurt")
		spawn_enemy(foe, player_cell + Vector2i(2, 0), "ash")
		player.face(Vector2.RIGHT)
		# `kill` swings until the foe drops (or 12 swings); plain `fight`
		# captures mid-swing.
		var swings := 12 if args.has("kill") else 1
		var kills_before := kills
		for i in swings:
			player.attack()
			if i < swings - 1:
				await get_tree().create_timer(0.45).timeout
			if kills > kills_before:
				break
		await get_tree().create_timer(0.4 if args.has("kill") else 0.1).timeout
	else:
		await get_tree().create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://screenshot.png")
	print("screenshot saved; map=%s cell=%s hp=%d gold=%d save=%s%s draws=%d" % [
		map.id, player_cell, player.hp, GameState.pack.gold, GameState.world.map_id, GameState.world.cell,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
	])
	# Let the audio server let go of the music before the engine shuts down.
	get_tree().paused = true  # nothing may start a track again
	Sound.stop_all()
	await get_tree().create_timer(0.1).timeout
	get_tree().quit()
