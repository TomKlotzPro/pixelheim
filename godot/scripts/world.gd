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


var map: MapData
## The map as drawn on this visit (MapView): ground, houses, props, chests,
## door signs, furniture.
var view: MapView
var actors: Node2D
var player: CharacterBody2D
var camera: Camera2D
var player_cell := Vector2i.ZERO
var kills := 0
var last_player_position := Vector2.ZERO
## The hero panel: health, resource, xp, gold, the screens (HudPanel).
var dock: Control
var log_box: VBoxContainer
## spawn id -> monsters of its pack still standing
var pack_alive := {}
## When the hero last arrived somewhere: a moment's grace before anything
## notices them (Packs graceSeconds).
var arrived_at := -100.0
## Seconds until the next look for packs due to come home.
var respawn_check := 0.0
## Sound's view of the hero: what changed is heard (coin, heal, hurt).
var heard_gold := 0
var heard_hp := 0
## When something last hunted the hero, and whether a boss did.
var hunted_at := -100.0
var hunted_by_boss := false
var noticed_at := -100.0
## Foes still standing on the dungeon floor the hero walks (0 when cleared).
var floor_foes := 0
var message_label: Label
## The nameplate over the signed door the hero walks up to (ShopSign).
var nameplate: PanelContainer
var nameplate_door := Vector2i(-1, -1)
var prompt_label: Label
var sky_overlay: ColorRect
## A `--screenshot` run: the harness drives, nobody else.
var harness := false

func _ready() -> void:
	UiStyle.setup()
	# Screens ease in as they open (UiStyle.enter), all but the two that make
	# their own entrance.
	child_entered_tree.connect(func(node: Node) -> void:
		if node is CanvasLayer and node.get_script() != null:
			var file: String = node.get_script().resource_path.get_file()
			if file.ends_with("_screen.gd") and file not in ["title_screen.gd", "rankup_screen.gd"]:
				node.ready.connect(UiStyle.enter.bind(node), CONNECT_ONE_SHOT)
	)
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
	respawn_check -= delta
	if respawn_check <= 0:
		respawn_check = 1.0
		_revive_packs()
		view.refresh_patches()
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
	_gather_at(cell)
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

## One monster of `species` at `cell`, at home there unless `home` says where
## its pack lives; wild ones pay the reduced wild rewards.
func spawn_enemy(species: String, cell: Vector2i, region := "", spawn_id := "", elite := false, wild := true, home := Vector2i(-1, -1)) -> Node:
	var enemy := preload("res://scripts/enemy.gd").new()
	enemy.world = self
	var fighter := Bestiary.spawn(species, elite)
	enemy.fighter = Bestiary.wild(fighter) if wild else fighter
	enemy.region = region
	enemy.spawn_id = spawn_id
	enemy.position = _cell_center(cell)
	enemy.home = _cell_center(home if home != Vector2i(-1, -1) else cell)
	enemy.add_to_group("mobs")
	actors.add_child(enemy)
	return enemy


## Whether a monster may notice the hero now (PIX-142): not in the moment
## after an arrival, only close by, only where the player can see it (on
## screen, above the dock) and only with nothing solid between them.
func can_notice(enemy: Node) -> bool:
	if Time.get_ticks_msec() / 1000.0 - arrived_at < float(Packs.rules()["graceSeconds"]):
		return false
	var at: Vector2 = enemy.global_position
	if not Packs.within_notice(at, player.global_position) or not in_view(at):
		return false
	return Packs.can_see(map, Vector2i((at / TILE).floor()), Vector2i((player.position / TILE).floor()))


## The world the player can see: the screen above the dock, widened by
## `margin` world pixels on every side.
func view_rect(margin := 0.0) -> Rect2:
	if camera == null:
		return Rect2()
	var half := Vector2(640, 360) / camera.zoom.x
	# Where the camera stands, held inside the map as its limits hold it.
	var center := camera.global_position
	center.x = clampf(center.x, camera.limit_left + half.x, maxf(camera.limit_left + half.x, camera.limit_right - half.x))
	center.y = clampf(center.y, camera.limit_top + half.y, maxf(camera.limit_top + half.y, camera.limit_bottom - half.y))
	return Rect2(center - half, Vector2(1280, _dock_top()) / camera.zoom.x).grow(margin)


## Where the dock begins on the 1280x720 canvas (the bottom, before it is built).
func _dock_top() -> float:
	return dock.top() if dock != null and dock.top() > 0 else 720.0


## How far below the hero the camera stands, so the hero is centred in the
## world above the dock rather than on the whole screen (PIX-142).
func _frame_lift() -> float:
	if camera == null:
		return 0.0
	return roundf((720.0 - _dock_top()) / 2.0 / camera.zoom.y)


func in_view(at: Vector2, margin := 0.0) -> bool:
	return view_rect(margin).has_point(at)

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
		var label := UiStyle.label(line, 12, UiStyle.CREAM)
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
	dock.refresh()

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
	var text := GameState.place_furniture(item_id, cell, _tile_in_hand(cell))
	if text != "":
		_flash_message(text)
	view.furnish()


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
	view.add_patch(plan["patch"], Gathering.floor_spot_id(level), Gathering.floor_material(level))
	var floor_def := Dungeons.floor_def(level)
	_log(["Floor %d: %s" % [level, floor_def["name"]], String(floor_def["description"])])
	# A boss's floor: its intro, the first time only (PIX-32).
	play_story(Cutscene.moment("boss:%s" % Dungeons.boss_of(level)["monsterId"]))


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
	PunyDungeon.sheet().place(view.dungeon_objects, stairs, PunyDungeon.STAIRS)
	if result["victory"]:
		Sound.play_track("victory")
		play_story(Cutscene.moment("victory"))
	elif result["first"]:
		play_story(Cutscene.moment("cleared:%d" % map.floor_level))


## A story moment over the world (Cutscene, PIX-32), once per hero; "" or a
## moment already seen plays nothing.
func play_story(scene_id: String) -> void:
	if scene_id == "" or GameState.has_seen(scene_id):
		return
	GameState.mark_seen(scene_id)
	var scene := Cutscene.new()
	scene.scene_id = scene_id
	add_child(scene)

func _enter_map(next: MapData, arrival: Vector2i) -> void:
	if view != null:
		Sound.play("door")
	hunted_at = -100.0
	arrived_at = Time.get_ticks_msec() / 1000.0
	for stale in get_tree().get_nodes_in_group("mobs") + get_tree().get_nodes_in_group("decor"):
		stale.queue_free()
	if view != null:
		view.clear()
	view = MapView.new(next, actors)
	arrival = view.plan(arrival)
	view.build(self)
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
	return MapView.center(cell)

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
		# Keepers trade instead of chatting: anyone in a shop opens its counter
		# (unless they have a quest to offer or take back: then they talk, and
		# the next word opens the counter), the mayor opens the town ledger, a
		# settled Mirelle her bank.
		var quest_word := Quests.awaits_word(beside["npc"]["id"], GameState.progression.quests, GameState.pack.items)
		if GameState.active_shop() != "" and not quest_word:
			_open_shop()
		elif map.id == "town_hall":
			add_child(preload("res://scripts/town_hall_screen.gd").new())
		elif beside["npc"]["id"] == "settler_mirelle" and GameState.is_settled("settler_mirelle"):
			add_child(preload("res://scripts/bank_screen.gd").new())
		else:
			_talk(beside["npc"])
		return

## What the hero's hands meet on a cell: the furniture drawn over it (a
## bed's foot is the bed: E rests there, nothing can be set on it), else the
## web's tile.
func _tile_in_hand(cell: Vector2i) -> String:
	return view.buildings.get("over", {}).get(cell, map.tile_at(cell))

func _enter_house() -> void:
	map = _load_map("town_house")
	_enter_map(map, Vector2i(8, 8))

## The house's fixtures and furniture; true when E meant one of them.
func _house_interact(cell: Vector2i) -> bool:
	var result := GameState.house_interact(cell, _tile_in_hand(cell))
	if result.is_empty():
		return false
	if result.has("text"):
		_flash_message(result["text"])
	if result.has("panel"):
		var screen := preload("res://scripts/home_screen.gd").new()
		screen.mode = result["panel"]
		screen.cell = cell
		screen.on_placed = view.furnish
		add_child(screen)
	view.furnish()
	return true

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
	var sprite: Sprite2D = view.chest_sprites[chest["id"]]
	if result["mimic"]:
		_mimic_wakes(sprite, chest)
		return
	sprite.texture = MapView.treasure_texture(chest, true)
	Sound.play("chest")


## A mimic's chest shudders before it bites (PIX-142): a beat to step back,
## then it bursts out beside the chest, nearest the hero, already hunting.
func _mimic_wakes(sprite: Sprite2D, chest: Dictionary) -> void:
	var visit := view
	var rest := sprite.position
	var shudder := sprite.create_tween()
	for i in 7:
		shudder.tween_property(sprite, "position:x", rest.x + (1.0 if i % 2 == 0 else -1.0), 0.07)
	shudder.tween_property(sprite, "position:x", rest.x, 0.07)
	await shudder.finished
	if view != visit:
		return
	sprite.texture = MapView.treasure_texture(chest, true)
	Sound.play("chest")
	var at := Vector2i(int(chest["x"]), int(chest["y"]))
	var ambush := Vector2i(-1, -1)
	for step: Vector2i in [Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i(-1, 1), Vector2i(1, 1)]:
		var cell := at + step
		if not map.is_walkable(cell) or cell == player_cell:
			continue
		if ambush.x < 0 or cell.distance_to(player_cell) < ambush.distance_to(player_cell):
			ambush = cell
	if ambush.x < 0:
		ambush = player_cell + Vector2i.RIGHT
	var mimic := spawn_enemy("mimic", ambush, map.region_at(ambush), "", false, true)
	appear(mimic)
	mimic.notice()


## Dust where a monster comes into sight (PIX-142): a ring of motes kicked up
## from its feet as it fades in, so nothing simply pops into being.
func appear(enemy: Node) -> void:
	if not in_view(enemy.position, TILE):
		return
	enemy.modulate.a = 0.0
	var fade_in := enemy.create_tween()
	fade_in.tween_property(enemy, "modulate:a", 1.0, 0.3)
	for i in 8:
		var mote := ColorRect.new()
		mote.color = Color(0.86, 0.8, 0.68, 0.9) if i % 2 == 0 else Color(0.7, 0.64, 0.52, 0.9)
		mote.size = Vector2(2, 2)
		mote.position = enemy.position + Vector2(-1, 1)
		mote.z_index = 4
		mote.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(mote)
		var away := Vector2.RIGHT.rotated(TAU * i / 8.0) * Vector2(9, 4)
		var drift := mote.create_tween().set_parallel()
		drift.tween_property(mote, "position", mote.position + away + Vector2(0, -3), 0.45).set_ease(Tween.EASE_OUT)
		drift.tween_property(mote, "modulate:a", 0.0, 0.45).set_delay(0.15)
		drift.chain().tween_callback(mote.queue_free)

## A patch underfoot is picked (PIX-143).
func _gather_at(cell: Vector2i) -> void:
	var patch: Dictionary = view.patches.get(cell, {})
	if patch.is_empty():
		return
	var lines := GameState.gather(patch["id"], patch["item"])
	if lines.is_empty():
		return
	Sound.play("drop")
	_log(lines)
	view.refresh_patches()


func _collect_ground_treasure(cell: Vector2i) -> void:
	var chest := _chest_at(cell)
	if chest.is_empty() or chest["look"] == "chest" or GameState.is_opened(chest):
		return
	var result := GameState.open_chest(chest)
	_flash_message(result["message"])
	if result["opened"]:
		view.chest_sprites[chest["id"]].queue_free()
		view.chest_sprites.erase(chest["id"])

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

## Packs at their homes (the spawns): the species its region and position
## decide, an elite roll each. A pack the slain ledger keeps down stays away;
## one whose time is up comes home only where the hero can't see it appear
## (PIX-142), now or on a later look (_revive_packs).
func _spawn_enemies(data: MapData) -> void:
	pack_alive = {}
	for spawn: Dictionary in Bestiary.spawns_on(data.id):
		if spawn["id"] in GameState.world.slain:
			continue
		_spawn_pack(data, spawn)
	respawn_check = 0.0
	_revive_packs()


## Cleared packs whose time is up, back at homes out of view.
func _revive_packs() -> void:
	if map.floor_level > 0:
		return
	for spawn: Dictionary in Bestiary.spawns_on(map.id):
		if not Packs.is_due(GameState.world, spawn["id"]):
			continue
		var home := _cell_center(Vector2i(spawn["x"], spawn["y"]))
		if in_view(home, 2 * TILE):
			continue
		GameState.revive_pack(spawn["id"])
		_spawn_pack(map, spawn)


## One pack around its home: up to PACK_SIZE on open cells of its region.
func _spawn_pack(data: MapData, spawn: Dictionary) -> void:
	var home := Vector2i(spawn["x"], spawn["y"])
	var region := data.region_at(home)
	var species := Bestiary.species_of(spawn, region)
	var elite_chance := float(Bestiary.region(region)["eliteChance"])
	var cells: Array[Vector2i] = [home]
	for offset in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1)]:
		var cell: Vector2i = home + offset
		if cells.size() < PACK_SIZE and data.is_walkable(cell) and data.region_at(cell) != "" and not data.portals.has(cell):
			cells.append(cell)
	for cell in cells:
		spawn_enemy(species, cell, region, spawn["id"], GameState.roll.call() < elite_chance, true, home)
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
	# The hero's dock along the bottom; the battle log floats above its left.
	dock = preload("res://scripts/hud_dock.gd").new()
	dock.world = self
	hud.add_child(dock)
	log_box = VBoxContainer.new()
	log_box.position = Vector2(24, 506)
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
	GameState.gold_changed.connect(func(_gold: int) -> void: dock.refresh())
	GameState.inventory_changed.connect(dock.refresh)
	GameState.healed.connect(dock.refresh)
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
	message_label.add_theme_color_override("font_color", UiStyle.CREAM)
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
		_camera_at = player.position + Vector2(0, _frame_lift())
		camera.global_position = _camera_at
		camera.reset_smoothing()

## The camera eases toward where the hero is drawn this frame (between the
## last two ticks, as the physics interpolation draws them) and stands on a
## whole screen pixel, so the world scrolls crisp, all of a piece.
func _follow_hero(delta: float) -> void:
	if camera == null or not camera_follows:
		return
	var drawn := _hero_tick_from.lerp(_hero_tick_to, Engine.get_physics_interpolation_fraction())
	drawn.y += _frame_lift()
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
	for entry: Dictionary in view.door_signs:
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
