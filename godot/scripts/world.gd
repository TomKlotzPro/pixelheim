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
## The town's houses from the Medieval Age pack (PunyTown.compose): their
## pieces, chimneys, and so which cells they cover. Empty elsewhere.
var buildings := {"pieces": {}, "decor": {}, "freed": []}
## Shade's props on the outdoor ground (PunyProps.compose).
var outdoor_props := {"props": [], "flat": {}, "drawn": {}}
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
## The doors with signs on this map: {door, name, about}; the nameplate over
## the one the hero walks up to (ShopSign).
var door_signs: Array = []
var nameplate: PanelContainer
var nameplate_door := Vector2i(-1, -1)
var prompt_label: Label
var sky_overlay: ColorRect
## A `--screenshot` run: the harness drives, nobody else.
var harness := false

func _ready() -> void:
	UiStyle.setup()
	# Only what physics moves is interpolated between ticks (the actors and
	# the camera riding the hero); the ground and the UI hold still.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	# The world's physics step runs after the actors', to note where the hero ended.
	process_physics_priority = 10
	var args := OS.get_cmdline_user_args()
	harness = args.has("--screenshot")
	if harness:
		# The harness window opens on the desktop of someone who may be typing
		# elsewhere: it doesn't take the keyboard (and harness.gd drops anything
		# but its own presses), and it stays on top, because macOS stops drawing
		# a covered window and the run would never reach its screenshot.
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
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
	actors.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
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
	if not greeted and not GameState.title_seen and (not harness or OS.get_cmdline_user_args().has("title")):
		_open_title()
	if harness:
		var driver := preload("res://scripts/harness.gd").new()
		driver.world = self
		driver.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(driver)


func _open_title() -> void:
	var title := preload("res://scripts/title_screen.gd").new()
	title.world = self
	add_child(title)

## Keys arrive as events, never polled: a key a conversation or a menu
## already took (E on the last line, Esc to leave, I to close the pack) stops
## there, instead of reopening the talk or the pause menu behind it in the
## same frame. A paused world hears nothing.
func _unhandled_input(event: InputEvent) -> void:
	if player == null or player.dead:
		return
	var command := Callable()
	if event.is_action_pressed("menu"):
		command = func() -> void:
			var pause := preload("res://scripts/pause_screen.gd").new()
			pause.world = self
			add_child(pause)
	elif event.is_action_pressed("interact"):
		command = _try_interact
	else:
		for screen: String in ["journal", "stats", "skills", "codex", "inventory", "map"]:
			if event.is_action_pressed(screen):
				command = open_screen.bind(screen)
				break
	if command.is_valid():
		get_viewport().set_input_as_handled()
		command.call()

func _process(delta: float) -> void:
	_follow_hero(delta)
	if player == null or player.dead:
		return
	_update_prompt()
	_update_nameplate()
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
		var label := UiStyle.label(line, 12, UiStyle.INK)
		label.add_theme_color_override("font_outline_color", UiStyle.NIGHT)
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
	_teleported()
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
	# Far off (the overworld's skyline) a town stays one Puny house icon.
	var near := next.floor_level == 0 and next.id not in PunyTerrain.SKYLINE_MAPS
	buildings = PunyTown.compose(next.grid) if near else {"pieces": {}, "decor": {}, "freed": []}
	# What a house covers is house: its corners stop the hero and villagers
	# too; the roof cells it leaves open are ground.
	for cell: Vector2i in buildings["pieces"]:
		if not String(next.grid.get(cell, "")).begins_with("door"):
			next.grid[cell] = "roof"
	for cell: Vector2i in buildings["freed"]:
		next.grid[cell] = "grass"
	# Inside, Shade's rooms (PunyInterior): furniture spreading onto the floor
	# blocks it, like the rest of the furniture.
	if PunyTown.available() and PunyInterior.is_room(next.id):
		var room: Dictionary = PunyInterior.plan(next.id, next.grid)
		buildings = {"pieces": room["pieces"], "decor": {}, "freed": [], "floor": room["floor"], "void": room["void"]}
		for cell: Vector2i in room["blocked"]:
			next.grid[cell] = "wall"
	# Outdoors, Shade's props stand where the web's did (PunyProps): what they
	# stand on blocks, even ground the web left open (the fountain's basin).
	var outdoor := next.floor_level == 0 and PunyTerrain.is_outdoor(next.grid)
	outdoor_props = PunyProps.compose(next.grid) if outdoor else {"props": [], "flat": {}, "drawn": {}}
	next.covered = {}
	for prop: Dictionary in outdoor_props["props"]:
		if (prop["foot"] as Rect2).has_area():
			for cell: Vector2i in prop["covers"]:
				next.covered[cell] = true
	if not next.is_walkable(arrival):
		arrival = next.spawn
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
	_teleported()
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
	if buildings.has("floor"):
		return _build_room(data)
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
	# Shade's flowers, flat on the ground (the hero walks through them).
	if not outdoor_props["flat"].is_empty():
		var flowers := TileMapLayer.new()
		flowers.tile_set = PunyTown.tileset()
		for cell: Vector2i in outdoor_props["flat"]:
			PunyTown.place(flowers, cell, outdoor_props["flat"][cell])
		root.add_child(flowers)
	# The houses, then what stands on their roofs (chimneys).
	for part: String in ["pieces", "decor"]:
		if buildings[part].is_empty():
			continue
		var houses := TileMapLayer.new()
		houses.tile_set = PunyTown.tileset()
		for cell: Vector2i in buildings[part]:
			PunyTown.place(houses, cell, buildings[part][cell])
		root.add_child(houses)
	return root

## A room in Shade's Medieval Age pack (PunyInterior): the dark beyond its
## walls, the floor and rug, then walls, door and furniture.
func _build_room(data: MapData) -> Node2D:
	var root := Node2D.new()
	var dark := ColorRect.new()
	dark.color = Color("0b0a0e")
	dark.size = Vector2(data.size * TILE)
	root.add_child(dark)
	for part: String in ["floor", "pieces"]:
		var layer := TileMapLayer.new()
		layer.tile_set = PunyTown.tileset()
		for cell: Vector2i in buildings[part]:
			PunyTown.place(layer, cell, buildings[part][cell])
		root.add_child(layer)
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
		var texture := _treasure_texture(chest, GameState.is_opened(chest))
		if texture == null:
			continue
		var cell := Vector2i(int(chest["x"]), int(chest["y"]))
		var sprite := Sprite2D.new()
		sprite.texture = texture
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
		if buildings["pieces"].has(cell) or outdoor_props["drawn"].has(cell):
			continue  # the house draws its own door (PunyTown), PunyProps its stalls
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
	for prop: Dictionary in outdoor_props["props"]:
		_add_puny_prop(prop)
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

## A chest or ground treasure as it stands: Shade's chest, pouch or herbs
## (PunyProps), or the web's sprites without the pack; null when it's gone.
func _treasure_texture(chest: Dictionary, opened: bool) -> Texture2D:
	if PunyProps.available():
		var tile := PunyProps.treasure_tile(chest["look"], opened)
		return PunyProps.texture(tile) if tile >= 0 else null
	var sprite_name := Interactables.sprite_name(chest, opened)
	return load("res://assets/sprites/%s.png" % sprite_name) if sprite_name != "" else null

## One of Shade's props among the actors (PunyProps): sorted on the bottom of
## its foot, so the hero passes behind it from the north and in front from
## the south, with a body exactly where the foot is.
func _add_puny_prop(prop: Dictionary) -> void:
	var foot: Rect2 = prop["foot"]
	var sort_y := foot.end.y if foot.has_area() else float(TILE)
	var root := Node2D.new()
	root.position = Vector2(prop["cell"] * TILE) + Vector2(0, sort_y)
	root.add_to_group("decor")
	if prop["kind"] == "fountain":
		var jet := AnimatedSprite2D.new()
		jet.sprite_frames = PunyProps.fountain_sprite_frames()
		jet.centered = false
		jet.position = Vector2(0, -TILE / 2.0 - sort_y)
		jet.play()
		root.add_child(jet)
	else:
		for piece: Array in prop["tiles"]:
			var sprite: Node2D
			if not prop["frames"].is_empty():
				var flame := AnimatedSprite2D.new()
				flame.sprite_frames = PunyProps.animation(prop["frames"], PunyProps.LAMP_FPS)
				flame.centered = false
				# Each torch flickers on its own beat.
				flame.play()
				flame.frame = absi(hash(prop["cell"])) % prop["frames"].size()
				sprite = flame
			else:
				var still := Sprite2D.new()
				still.texture = PunyDungeon.sheet().tile_texture(piece[1]) if prop["sheet"] == "dungeon" else PunyProps.texture(piece[1])
				still.centered = false
				sprite = still
			sprite.position = Vector2(piece[0] * TILE) - Vector2(0, sort_y)
			root.add_child(sprite)
	if foot.has_area():
		var body := StaticBody2D.new()
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = foot.size
		shape.shape = rect
		shape.position = foot.get_center() - Vector2(0, sort_y)
		body.add_child(shape)
		root.add_child(body)
	actors.add_child(root)

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
	door_signs = []
	if ShopSign.available():
		# Hanging boards with the trade's icon; the name rises on approach.
		for sign_def: Dictionary in Interactables.signs_on(data.id, GameState.owns_house()):
			var door := Vector2i(int(sign_def["x"]), int(sign_def["y"]))
			var target: Dictionary = data.portals.get(door, {})
			root.add_child(ShopSign.build(sign_def["label"], door))
			var told := ShopSign.about(sign_def["label"], String(target.get("mapId", "")), GameState.owns_house())
			door_signs.append({"door": door, "name": told["name"], "about": told["about"]})
		return root
	for sign_def: Dictionary in Interactables.signs_on(data.id, GameState.owns_house()):
		var door := Vector2(int(sign_def["x"]) * TILE + TILE / 2.0, int(sign_def["y"]) * TILE)
		# A wooden shop board over the door, in the web's sign wood: the name
		# in the pixel type, and the trade's icon above it for craft stations.
		var board := PanelContainer.new()
		board.add_theme_stylebox_override("panel", _sign_wood())
		board.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var label := Label.new()
		label.text = sign_def["label"]
		label.add_theme_font_override("font", UiStyle.chunky_font())
		label.add_theme_font_size_override("font_size", 8)
		label.add_theme_color_override("font_color", Color("e8c34a"))
		board.add_child(label)
		root.add_child(board)
		board.reset_size()
		# Over the eave just above the door (Puny houses), or above the old
		# two-tile arch doors.
		var lift := 10.0 if buildings["pieces"].has(Vector2i(sign_def["x"], sign_def["y"])) else 26.0
		board.position = (door - Vector2(board.size.x / 2.0, lift + board.size.y - 8)).round()
		if sign_def.has("icon"):
			var texture: Texture2D = load("res://assets/sprites/%s.png" % sign_def["icon"])
			var size := texture.get_size() + Vector2(4, 4)
			var plate := Panel.new()
			plate.add_theme_stylebox_override("panel", _sign_wood())
			plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
			plate.size = size
			plate.position = Vector2(door.x - size.x / 2.0, board.position.y - size.y + 1).round()
			var icon := TextureRect.new()
			icon.texture = texture
			icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			icon.position = Vector2(2, 2)
			plate.add_child(icon)
			root.add_child(plate)
	return root

## Sign wood (the web's door signs): a dark plank, a lit top edge, a shadow.
func _sign_wood() -> StyleBoxFlat:
	var wood := StyleBoxFlat.new()
	wood.bg_color = Color("2a2118")
	wood.border_color = Color("8a6238")
	wood.border_width_top = 1
	wood.border_width_bottom = 1
	wood.set_content_margin_all(2)
	wood.content_margin_top = 1
	wood.content_margin_bottom = 0
	return wood

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
	chest_sprites[chest["id"]].texture = _treasure_texture(chest, true)
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
		if outdoor_props["drawn"].has(cell):
			# Shade's prop stands here, with its own body (PunyProps); in a ruin
			# it stands on the ruin's floor, not the grass beyond.
			if [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT].any(
				func(step: Vector2i) -> bool: return data.grid.get(cell + step, "") == "floor"
			):
				layer.set_cell(cell, source_ids["floor"], Vector2i.ZERO)
			continue
		var puny_drawn: bool = (
			data.floor_level > 0
			or buildings.has("floor")
			or buildings["pieces"].has(cell)
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
	camera.limit_left = 0
	camera.limit_top = 0
	# The camera follows where the hero is drawn (between physics ticks), not
	# where physics last put them: attached to the hero it would lag the drawn
	# sprite by up to a tick and snap back, a shake that blurs every step.
	camera.top_level = true
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	player.add_child(camera)
	_fit_zoom()
	get_tree().root.size_changed.connect(_fit_zoom)
	_teleported()

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
	nameplate = PanelContainer.new()
	nameplate.add_theme_stylebox_override("panel", UiStyle.window(8))
	nameplate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nameplate.visible = false
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 0)
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nameplate.add_child(lines)
	var title := UiStyle.strong("", 16, UiStyle.LAMP)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lines.add_child(title)
	var keeper := UiStyle.label("", 12, UiStyle.INK)
	keeper.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lines.add_child(keeper)
	hud.add_child(nameplate)
	message_label = Label.new()
	message_label.position = Vector2(190, 610)
	message_label.custom_minimum_size = Vector2(900, 0)
	message_label.size = Vector2(900, 0)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	message_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiStyle.sized(message_label, 16)
	message_label.add_theme_color_override("font_color", UiStyle.INK)
	message_label.add_theme_color_override("font_outline_color", UiStyle.NIGHT)
	message_label.add_theme_constant_override("outline_size", 6)
	message_label.modulate.a = 0.0
	hud.add_child(message_label)

## The hero's position after the last two physics ticks (recorded after the
## hero has moved, see _physics_process), so the camera can stand exactly
## where the hero is drawn this frame.
var _hero_tick_from := Vector2.ZERO
var _hero_tick_to := Vector2.ZERO
## False while something else frames the shot (the harness overview).
var camera_follows := true
## Shade's figures are 16px: about 4x shows ~20x11 tiles, close to the web
## game's view. The exact zoom keeps an art pixel a whole number of screen
## pixels at any window size (_fit_zoom).
const ZOOM := 4.0
## How fast the camera catches up with the hero (per second, eased).
const CAMERA_EASE := 8.0
## Where the camera eases to stand, before it settles on a whole pixel.
var _camera_at := Vector2.ZERO

func _physics_process(_delta: float) -> void:
	if player == null:
		return
	_hero_tick_from = _hero_tick_to
	_hero_tick_to = player.position

## The hero was placed, not walked: no interpolating from the old spot, and
## the camera cuts there.
func _teleported() -> void:
	player.reset_physics_interpolation()
	_hero_tick_from = player.position
	_hero_tick_to = player.position
	if camera != null:
		_camera_at = player.position
		camera.global_position = player.position
		camera.reset_smoothing()

## The camera eases toward where the hero is drawn this frame (between the
## last two ticks, as the physics interpolation draws them) and stands on a
## whole screen pixel, so the world scrolls crisp, all of a piece.
func _follow_hero(delta: float) -> void:
	if camera == null or not camera_follows:
		return
	var drawn := _hero_tick_from.lerp(_hero_tick_to, Engine.get_physics_interpolation_fraction())
	_camera_at = _camera_at.lerp(drawn, 1.0 - exp(-CAMERA_EASE * delta))
	var pixels_per_unit := camera.zoom.x * _stretch()
	camera.global_position = (_camera_at * pixels_per_unit).round() / pixels_per_unit

## Screen pixels per pixel of the 1280x720 canvas (the window's stretch).
func _stretch() -> float:
	return get_tree().root.get_final_transform().get_scale().x

## The zoom nearest ZOOM at which an art pixel covers a whole number of
## screen pixels: no uneven 4-and-5-pixel columns shimmering as the world
## scrolls.
func _fit_zoom() -> void:
	if camera == null or not camera_follows:
		return
	var scale := _stretch()
	camera.zoom = Vector2.ONE * maxf(1.0, roundf(ZOOM * scale)) / scale

## The nameplate of the sign the hero stands near (two tiles or so): the
## place's name and who keeps it, over the board, in the UI's window style.
func _update_nameplate() -> void:
	var near := {}
	var best := 2.6 * TILE
	for entry: Dictionary in door_signs:
		var at := Vector2(entry["door"] * TILE) + Vector2(TILE / 2.0, TILE / 2.0)
		var distance := player.position.distance_to(at)
		if distance < best:
			best = distance
			near = entry
	if near.is_empty():
		if nameplate.visible and nameplate_door != Vector2i(-1, -1):
			nameplate_door = Vector2i(-1, -1)
			var fade := nameplate.create_tween()
			fade.tween_property(nameplate, "modulate:a", 0.0, 0.15)
			fade.tween_callback(nameplate.hide)
		return
	if near["door"] != nameplate_door:
		nameplate_door = near["door"]
		(nameplate.get_child(0).get_child(0) as Label).text = near["name"]
		(nameplate.get_child(0).get_child(1) as Label).text = near["about"]
		nameplate.get_child(0).get_child(1).visible = near["about"] != ""
		nameplate.reset_size()
		nameplate.show()
		nameplate.modulate.a = 1.0 if GameState.settings.reduce_motion else 0.0
		if not GameState.settings.reduce_motion:
			nameplate.create_tween().tween_property(nameplate, "modulate:a", 1.0, 0.15)
	# Over the board, wherever the camera has the door on screen.
	var top := Vector2(nameplate_door.x * TILE + TILE / 2.0, nameplate_door.y * TILE - ShopSign.BOARD.y - 10)
	var screen := get_viewport().get_canvas_transform() * top
	nameplate.position = (screen - Vector2(nameplate.size.x / 2.0, nameplate.size.y)).round()

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
