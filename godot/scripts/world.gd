extends Node2D
## World orchestration: loads maps exported from the web game, builds their
## TileMapLayer, moves the hero through portals, and spawns mobs in the wild.
## Tile tables live in WorldTiles; map data in MapData; everything that
## persists (position, discovery, chests, loot) in the GameState autoload.

const TILE := 16
## Monsters at each of the web's visible spawn points: a small pack of the
## species that lives there, so the real-time fight has bodies to swing at.
const PACK_SIZE := 3
## Fight music holds this long after the last hunter gives up.
const COMBAT_LINGER_S := 3.0



var map: MapData
## The map as drawn on this visit (MapView): ground, houses, props, chests,
## door signs, furniture.
var view: MapView
var actors: Node2D
var player: CharacterBody2D
## The camera (Solid Ground: its own node, CameraRig).
var camera_rig: CameraRig
## What flashes and floats over the world (WorldFx).
var fx: WorldFx
## What the world says in words: the message plate and the battle log (Messages).
var messages: Messages
## What the hero hears: the music, the ambience and the world's sounds (Soundscape).
var soundscape: Soundscape
## The villagers: who stands where, and the village's hours (Folk).
var folk: Folk
## What E does, what the hero steps on, and the prompt (Interaction).
var interaction: Interaction
var player_cell := Vector2i.ZERO
var kills := 0
var last_player_position := Vector2.ZERO
## The hero panel: health, resource, xp, gold, the screens (HudPanel).
var dock: Control
## spawn id -> monsters of its pack still standing
var pack_alive := {}
## When the hero last arrived somewhere: a moment's grace before anything
## notices them (Packs graceSeconds).
var arrived_at := -100.0
## Seconds until the next look for packs due to come home.
var respawn_check := 0.0
## When something last hunted the hero, and whether a boss did.
var hunted_at := -100.0
var hunted_by_boss := false
## How long that silence lasts, and how slow the world runs as it falls.
const BOSS_HUSH_S := 3.5
const BOSS_SLOW := 0.25
const BOSS_SLOW_S := 0.8
var boss_bar: Control
var noticed_at := -100.0
## The HUD's layer, and the first-time hint on it now (PIX-160).
var hud_root: CanvasLayer
var hint_card: PanelContainer
static var _hint_doc := {}
static var _hint_generation := 0
## Foes still standing on the dungeon floor the hero walks (0 when cleared).
var floor_foes := 0
## The main quest's next step, quietly above the dock (PIX-144): a dark
## pill holding "Next" and the step.
var objective_box: PanelContainer
var objective_label: Label
## The nameplate over the signed door the hero walks up to (ShopSign).
var nameplate: PanelContainer
var nameplate_door := Vector2i(-1, -1)
var sky_overlay: ColorRect
## The world's light and darkness (PIX-221, light_rig.gd).
var lights: Node
## Each region's air and the weather (PIX-224).
var atmosphere: Node
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
	# The phone version (PIX-162): on a touch screen (or a harness run with
	# `touch`) the canvas fills the screen's own shape instead of
	# letterboxing it.
	Touch.forced = args.has("touch")
	if Touch.enabled():
		get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
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
	# Harness: `--town-tier N` previews the village at another age; without it
	# a run shows the Hamlet its flows were written for (`--town-tier 0` is a
	# new hero's Ashes).
	var tier_index := args.find("--town-tier")
	if tier_index >= 0 and tier_index + 1 < args.size():
		GameState.settlement.town_tier = int(args[tier_index + 1])
	elif args.has("--screenshot") and GameState.settlement.projects.is_empty():
		GameState.settlement.town_tier = maxi(1, GameState.settlement.town_tier)
	# Harness runs skip the Night of Ash (their flows were written for the
	# town by day) unless `--prologue N` puts them at its step N.
	if args.has("--screenshot"):
		var prologue_index := args.find("--prologue")
		if prologue_index >= 0 and prologue_index + 1 < args.size():
			GameState.progression.prologue = int(args[prologue_index + 1])
			GameState.settlement.town_tier = 0
			GameState.world.steps = Prologue.night_steps()
			if GameState.progression.prologue == Prologue.SCAVENGER:
				var start := Prologue.start()
				GameState.world.map_id = start["mapId"]
				GameState.world.cell = Vector2i(start["x"], start["y"])
		elif GameState.progression.prologue != Prologue.DONE:
			# A slot from a real run (--slot N) mid-night: start it by day.
			GameState.progression.prologue = Prologue.DONE
			GameState.world.steps = 0.0
			GameState.world.map_id = "town"
			var spawn: Dictionary = Catalog._data()["townSpawn"]
			GameState.world.cell = Vector2i(int(spawn["x"]), int(spawn["y"]))
			GameState.pack.remove_item("chancellors_letter")
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
	messages = Messages.new()
	messages.world = self
	add_child(messages)
	soundscape = Soundscape.new()
	soundscape.world = self
	add_child(soundscape)
	folk = Folk.new()
	folk.world = self
	add_child(folk)
	interaction = Interaction.new()
	interaction.world = self
	add_child(interaction)
	_build_hud()
	interaction.build_prompt()
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
		command = interaction.interact
	else:
		for screen: String in ["journal", "stats", "skills", "codex", "inventory", "map"]:
			if event.is_action_pressed(screen):
				command = open_screen.bind(screen)
				break
	if command.is_valid():
		get_viewport().set_input_as_handled()
		command.call()

func _process(delta: float) -> void:
	camera_rig.update(delta)
	if player == null or player.dead:
		return
	interaction.update_prompt()
	_update_nameplate()
	_run_clocks(delta)
	messages.update()
	# A first-time hint stands under the boss bar while one is up (PIX-210).
	if hint_card != null and is_instance_valid(hint_card):
		hint_card.position.y = boss_bar.bottom() + 6 if boss_bar.following() else 18.0
	_tend_escort()
	GameState.walk(player.position.distance_to(last_player_position) / TILE)
	last_player_position = player.position
	# The dark is the world's own now (PIX-221: the LightRig), not a veil
	# over it; the veil is left for the dawn's own fades.
	sky_overlay.color = Color(0, 0, 0, 0)
	soundscape.refresh()
	respawn_check -= delta
	if respawn_check <= 0:
		respawn_check = 1.0
		_revive_packs()
		view.refresh_patches()
		folk.keep_hours()
		_hint_boards()
	_update_objective()
	var cell := Vector2i((player.position / TILE).floor())
	if cell == player_cell:
		return
	player_cell = cell
	Sound.play("step")
	# Dust off dry ground, a splash in a bog (PIX-225).
	atmosphere.footfall(player.global_position + Vector2(0, 2), map.tile_at(cell))
	# Down a dungeon the save keeps the hero at its gate, as the web does.
	if map.floor_level == 0:
		GameState.move_to(map, cell, player.facing)
	# Walking into the bought house's shut door walks you in.
	if map.id == "town" and cell + Vector2i(player.facing) == Town.house_door() and GameState.owns_house():
		enter_house()
		return
	interaction.step_on(cell)
	if map.portals.has(cell):
		_use_portal(map.portals[cell])

## Maps as the town has grown: the village and the house redraw per tier.
func _load_map(map_id: String) -> MapData:
	return MapData.load_tiered(map_id, Town.done_projects(GameState.settlement), int(GameState.settlement.house.get("tier", 1)))

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
	var floor_level := Bestiary.wild_drop_floor(enemy.region, enemy.fighter) if enemy.region != "" else 1
	if map.floor_level > 0:
		floor_level = Dungeons.drop_floor(map.floor_level)
	var gear_before := GameState.pack.gear.size()
	messages.log_lines(GameState.defeat_monster(enemy.fighter, enemy.region, cleared, floor_level, map.floor_level))
	fx.show_loot(GameState.pack.gear.slice(gear_before), enemy.global_position)
	if enemy.has_meta("prologue"):
		messages.flash(GameState.prologue_pouch())
	# The last of a wave of the night's foes: on to the next beat.
	if enemy.has_meta("prologue_wave"):
		var left := get_tree().get_nodes_in_group("mobs").filter(func(mob: Node) -> bool:
			return mob != enemy and mob.has_meta("prologue_wave") and not mob.dying)
		if left.is_empty():
			messages.flash(GameState.prologue_wave_cleared())
	if enemy.fighter.has("named"):
		Sound.play("bounty")
	if GameState.pack.gear.size() > gear_before:
		Sound.play("drop")
	if cleared != "":
		messages.log_lines([Text.t("The pack is scattered. Another comes once you've walked a good way, or after a night's rest.")])
	# The dead a boss summons aren't the floor's own foes (PIX-150).
	if map.floor_level > 0 and floor_foes > 0 and not enemy.is_in_group("summoned"):
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
func spawn_enemy(species: String, cell: Vector2i, region := "", spawn_id := "", elite := false, wild := true, home := Vector2i(-1, -1), lift := 0) -> Node:
	var enemy := preload("res://scripts/enemy.gd").new()
	enemy.world = self
	var fighter := Bestiary.spawn(species, elite, lift)
	enemy.fighter = Bestiary.wild(fighter, region) if wild else fighter
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
	if enemy.feeding and at.distance_to(player.global_position) > TILE * 1.5:
		return false
	if not Packs.within_notice(at, player.global_position) or not camera_rig.in_view(at):
		return false
	return Packs.can_see(map, Vector2i((at / TILE).floor()), Vector2i((player.position / TILE).floor()))



func _on_hp_changed(hp: int, max_hp: int) -> void:
	dock.refresh()
	# Hurt on the first night: how to drink a potion, once (PIX-197).
	if GameState.progression.prologue != Prologue.DONE and hp * 2 < max_hp and hp > 0:
		hint("potion")

func _use_portal(target: Dictionary) -> void:
	match target["kind"]:
		"map":
			_through_door(func() -> void:
				map = _load_map(target["mapId"])
				_enter_map(map, Vector2i(int(target["x"]), int(target["y"])))
				# Stepping into the inn takes a bed for coin, as on the web.
				if map.id == "town_inn":
					messages.flash(GameState.rest_at_inn())
					dream()
			)
		"dungeon":
			# The floor select opens while the hero waits at the door.
			_step_back()
			# Barred since the Night of Ash until the relics come home (PIX-170).
			if target["dungeon"] == "mountain" and not Relics.gate_open(GameState.progression):
				messages.flash(Relics.barred_line())
				return
			var screen := preload("res://scripts/dungeon_screen.gd").new()
			screen.world = self
			screen.dungeon_id = target["dungeon"]
			add_child(screen)
		"gate":
			_leave_floor()
		"deeper":
			enter_floor(map.floor_level + 1)


## One of the hero's screens, from its key or the panel's button.
func open_screen(screen: String) -> void:
	if player.dead or get_tree().paused:
		return
	match screen:
		"inventory":
			_open_inventory()
		"map":
			if map.floor_level > 0:
				messages.flash("No map reaches this deep.")
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


## A fight is on: something has hunted the hero in the last few seconds.
func in_fight() -> bool:
	return Time.get_ticks_msec() / 1000.0 - hunted_at < COMBAT_LINGER_S


## How hard the hero's skills strike on this floor (PIX-216): less on a
## warded depth of the Deep Hunt.
func skill_ward() -> float:
	if map != null and Dungeons.modifier(map.floor_level).get("id", "") == "warded":
		return float(Bestiary._data()["deepHunt"]["wardedSkills"])
	return 1.0


## Something has seen the hero: a growl (SFX.bump), not more than once a beat.
func on_enemy_noticed(enemy: Node) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	hint("dodge")
	# A named monster or a boss roars (PIX-158, PIX-210); anything else bumps.
	if fights_like_boss(enemy):
		Sound.play("roar")
	elif now - noticed_at > 1.5:
		Sound.play("bump")
	noticed_at = now
	hunted_at = now
	hunted_by_boss = hunted_by_boss or fights_like_boss(enemy)
	if enemy.fighter.has("named"):
		messages.log_lines([Hunts.named(enemy.fighter["named"])["seen"]])


## A boss or a named monster (PIX-156): the boss's music plays.
func fights_like_boss(enemy: Node) -> bool:
	return Bestiary.is_boss(enemy.fighter["id"]) or enemy.fighter.has("named")


## The HUD's 1280x720 layout on the screen as it is (PIX-162): along the
## bottom, centred across, with the sky's tint edge to edge. On a desktop the
## canvas is 1280x720 and nothing moves.
func _place_hud() -> void:
	if hud_root == null:
		return
	hud_root.offset = Touch.hud_offset(self)
	sky_overlay.position = -hud_root.offset
	sky_overlay.size = Touch.view_size(self)


## A first-time hint (PIX-160): a card under the top of the screen that
## says what something is, once per player (GameSettings.hints_seen, `key`
## when one hint has many, a skill each) and never with hints off. It doesn't
## stop the game, and fades by itself.
func hint(id: String, values := {}, key := "") -> void:
	var settings := GameState.settings
	var seen_id := key if key != "" else id
	if not settings.hints or seen_id in settings.hints_seen or hud_root == null:
		return
	settings.hints_seen.append(seen_id)
	settings.save_file()
	if _hint_doc.is_empty() or _hint_generation != Text.generation:
		_hint_doc = Text.localize(JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/hints.json")))
		_hint_generation = Text.generation
	var title := String(_hint_doc[id]["title"])
	var text := Controls.say(String(_hint_doc[id]["text"]))
	for name: String in values:
		title = title.replace("{%s}" % name, str(values[name]))
		text = text.replace("{%s}" % name, str(values[name]))
	if hint_card != null:
		hint_card.queue_free()
	hint_card = PanelContainer.new()
	hint_card.add_theme_stylebox_override("panel", UiStyle.window(12))
	hint_card.position = Vector2(340, boss_bar.bottom() + 6 if boss_bar.following() else 18.0)
	hint_card.custom_minimum_size = Vector2(600, 0)
	hint_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 4)
	hint_card.add_child(lines)
	lines.add_child(UiStyle.strong(title, 16, UiStyle.LAMP))
	var body := UiStyle.label(text, UiStyle.reading(14), UiStyle.INK)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(570, 0)
	lines.add_child(body)
	hud_root.add_child(hint_card)
	hint_card.modulate.a = 0.0
	var show := hint_card.create_tween()
	show.tween_property(hint_card, "modulate:a", 1.0, 0.3)
	show.tween_interval(10.0 if settings.large_text else 7.0)
	show.tween_property(hint_card, "modulate:a", 0.0, 0.6)
	show.tween_callback(hint_card.queue_free)


## The boards on the square, explained the first time the hero walks up.
func _hint_boards() -> void:
	if map.id != "town" or GameState.progression.prologue != Prologue.DONE:
		return
	if Vector2(player_cell).distance_to(Vector2(Town.project_board())) <= 3.0:
		hint("board")
	if Vector2(player_cell).distance_to(Vector2(Town.bounty_board())) <= 2.0 \
			and not Hunts.notices(GameState.board_floors(), GameState.progression.hunted).is_empty():
		hint("bounty")


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
	camera_rig.cut()
	last_player_position = player.position
	GameState.move_to(map, back, player.facing)


## Down to a dungeon floor (DungeonFloor): its foes one per room, the
## guardian last. The save still holds the gate the hero entered by.
func enter_floor(level: int) -> void:
	var plan := DungeonFloor.plan(level)
	map = plan["map"]
	_enter_map(map, map.spawn)
	floor_foes = plan["foes"].size()
	# A depth of the Deep Hunt already cleared pays its foes a share (PIX-180).
	var replay := Dungeons.is_deep(level) and Dungeons.depth_of(level) <= GameState.progression.deepest
	# The mountain's foes wear their floor's name (PIX-188): a Cellar Slime.
	var epithet := Dungeons.epithet(level)
	var twist := Dungeons.modifier(level)
	var rules: Dictionary = Bestiary._data()["deepHunt"]
	for foe: Dictionary in plan["foes"]:
		var spawned := spawn_enemy(foe["id"], foe["cell"], "", "", foe["elite"], false, Vector2i(-1, -1), foe["lift"])
		# A twisted depth (PIX-216): its foes quicker, or their bites venomous.
		match String(twist.get("id", "")):
			"swift":
				spawned.pace = float(rules["swiftPace"])
			"venom":
				var venom: Dictionary = rules["venom"]
				spawned.fighter["inflicts"] = {"kind": venom["kind"], "chance": venom["chance"], "turns": venom["turns"], "power": maxi(2, roundi(int(spawned.fighter["attack"]) * float(venom["attackShare"])))}
		if String(foe.get("name", "")) != "":
			# A warden goes by its own name (PIX-216).
			spawned.fighter["name"] = Text.t(foe["name"])
		elif epithet != "" and int(foe["lift"]) > 0:
			# Named, not positional: French puts the epithet after (PIX-196).
			var titled := Text.t("{epithet} {name}").format({"epithet": Text.t(epithet), "name": Bestiary.monster(foe["id"])["name"]})
			spawned.fighter["name"] = Text.t("Elite %s") % titled if foe["elite"] else titled
		if replay:
			spawned.fighter["gold"] = roundi(int(spawned.fighter["gold"]) * float(Bestiary._data()["deepHunt"]["replayGoldShare"]))
	# A Deep Hunt named monster takes its depth's stair (PIX-219).
	if Dungeons.is_deep(level):
		var hunted := Hunts.deep_guardian(Dungeons.depth_of(level), GameState.board_floors(), GameState.progression.hunted)
		if not hunted.is_empty():
			var guardian: Dictionary = plan["foes"][-1]
			for mob in get_tree().get_nodes_in_group("mobs"):
				if mob.position == _cell_center(guardian["cell"]):
					mob.remove_from_group("mobs")
					mob.queue_free()
			spawn_named(hunted["id"], guardian["cell"])
	view.add_patch(plan["patch"], Gathering.floor_spot_id(level), Gathering.floor_material(level))
	var floor_def := Dungeons.floor_def(level)
	messages.log_lines([String(floor_def["name"]) if Dungeons.is_deep(level) else Text.t("Floor %d: %s") % [level, floor_def["name"]], String(floor_def["description"])])
	if not twist.is_empty():
		messages.log_lines([Text.t("%s: %s") % [Text.t(twist["name"]), Text.t(twist["line"])]])
	# A boss's floor: its intro, the first time only (PIX-32).
	play_story(Cutscene.moment("boss:%s" % Dungeons.boss_of(level)["monsterId"]))


## Up the stairs, back to the gate the save remembers.
func _leave_floor() -> void:
	map = _load_map(GameState.world.map_id)
	_enter_map(map, Vector2i(GameState.world.cell))


## The floor's last foe fell: its hoard on a first clear, and a way up where
## the guardian stood, so the hero needn't walk the halls back.
func _floor_cleared(at: Vector2i) -> void:
	var deep := Dungeons.is_deep(map.floor_level)
	var result := GameState.clear_deep(map.floor_level) if deep else GameState.clear_floor(map.floor_level)
	Sound.play("victory")
	messages.log_lines(result["lines"])
	var stairs := at
	if not map.is_walkable(stairs) or map.portals.has(stairs):
		stairs = player_cell
	map.grid[stairs] = "cave"
	map.portals[stairs] = {"kind": "gate"}
	PunyDungeon.sheet().place(view.dungeon_objects, stairs, PunyDungeon.STAIRS)
	# The Deep Hunt (PIX-161) goes on: a hole into the dark beside the way up.
	if deep or Dungeons.is_final(map.floor_level):
		for side: Vector2i in [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2)]:
			var down := stairs + side
			if map.is_walkable(down) and not map.portals.has(down):
				map.grid[down] = "cave"
				map.portals[down] = {"kind": "deeper"}
				PunyDungeon.sheet().place(view.dungeon_objects, down, PunyDungeon.VOID)
				break
	if result["victory"] and Story.ending_of(GameState.progression.story_seen) == "":
		# Morvax kneels: the hero decides how it ends (PIX-157).
		var throne := preload("res://scripts/throne_screen.gd").new()
		throne.on_choice = _play_ending
		add_child(throne)
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
	var changing := view != null
	if changing:
		Sound.play("door")
	hunted_at = -100.0
	soundscape.listen_again()
	arrived_at = Time.get_ticks_msec() / 1000.0
	for stale in get_tree().get_nodes_in_group("mobs") + get_tree().get_nodes_in_group("decor"):
		stale.queue_free()
	if view != null:
		view.clear()
	view = MapView.new(next, actors)
	arrival = view.plan(arrival)
	view.build(self)
	folk.spawn_for(next)
	player.position = _cell_center(arrival)
	camera_rig.cut()
	player.ailments.clear()
	last_player_position = player.position
	player_cell = arrival
	# Crossing into a map is a moment worth keeping: save at once. Dungeon
	# floors aren't web maps: the save keeps the gate.
	if next.floor_level == 0:
		GameState.move_to(next, arrival, player.facing)
		GameState.save_now()
	floor_foes = 0
	_prologue_arrive(next)
	# A festival day: confetti over the square (PIX-159).
	if next.id == "town" and GameState.festival_on():
		_festival()
	_play_reveals.call_deferred()
	folk.keep_hours(true)
	camera_rig.set_limits(Vector2(next.size * TILE))
	_spawn_enemies(next)
	soundscape.refresh()
	if changing:
		_fade_in()


## Through a door the world fades to the dark first (PIX-226), then the new
## map fades in (_fade_in): no cut either way. Once at a time; at once with
## reduced motion or in harness runs.
const DOOR_FADE := 0.15
var _passing := false


func _through_door(then: Callable) -> void:
	if GameState.settings.reduce_motion or harness or hud_root == null:
		then.call()
		return
	if _passing:
		return
	_passing = true
	var dark := ColorRect.new()
	dark.color = Color(UiStyle.NIGHT, 0.0)
	dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dark.position = -hud_root.offset
	dark.size = Touch.view_size(self)
	hud_root.add_child(dark)
	var fade := dark.create_tween()
	fade.tween_property(dark, "color:a", 1.0, DOOR_FADE).set_ease(Tween.EASE_OUT)
	fade.tween_callback(func() -> void:
		then.call()
		dark.queue_free()
		_passing = false
	)


## A new map fades in from the dark (PIX-211) instead of cutting; not with
## reduced motion, nor in harness runs, whose pictures are taken at once.
func _fade_in() -> void:
	if GameState.settings.reduce_motion or harness or hud_root == null:
		return
	var dark := ColorRect.new()
	dark.color = UiStyle.NIGHT
	dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dark.position = -hud_root.offset
	dark.size = Touch.view_size(self)
	hud_root.add_child(dark)
	var fade := dark.create_tween()
	fade.tween_property(dark, "color:a", 0.0, 0.35).set_ease(Tween.EASE_IN)
	fade.tween_callback(dark.queue_free)

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

## Into the bought house, at its door (E on the door, or walking into it).
func enter_house() -> void:
	map = _load_map("town_house")
	_enter_map(map, Vector2i(8, 8))
	hint("house")


## A mimic's chest shudders before it bites (PIX-142): a beat to step back,
## then it bursts out beside the chest, nearest the hero, already hunting.
func mimic_wakes(sprite: Sprite2D, chest: Dictionary) -> void:
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
	fx.appear(mimic)
	mimic.notice()


## The line above the dock (PIX-144): the main quest's next step, faded out
## in a fight, under a flashing message and once the story is done; hidden
## while the world is paused (menus, conversations, cutscenes).
func _update_objective() -> void:
	var step := MainQuest.next_step(GameState.progression, GameState.settlement)
	var text: String = step.get("text", "")
	if GameState.progression.prologue != Prologue.DONE:
		text = Prologue.objective(GameState.progression.prologue, GameState.progression.prologue_doused.size(), GameState.first_skill_heals())
	if text != objective_label.text:
		objective_label.text = text
		objective_box.reset_size()
	objective_box.position.y = (dock.top() if dock != null and dock.top() > 0 else 690.0) - 38
	# A message stands where the objective line does and grows upward, so a
	# long one (a barred gate, a quest's words) never runs under the dock.
	if messages.message_box.modulate.a > 0.0:
		messages.fit()
	messages.message_box.position.y = objective_box.position.y + objective_box.size.y - messages.message_box.size.y
	# The battle log stands on the objective line, or on a taller message
	# (PIX-211), and grows upward, so a long kill never runs into either.
	var under := objective_box.position.y
	if messages.message_box.modulate.a > 0.0:
		under = minf(under, messages.message_box.position.y)
	messages.log_box.reset_size()
	messages.log_box.position.y = under - 6 - messages.log_box.size.y
	var show := text != "" and not in_fight() and messages.message_box.modulate.a < 0.05
	var target := 1.0 if show else 0.0
	if objective_box.get_meta("fading_to", -1.0) != target:
		objective_box.set_meta("fading_to", target)
		objective_box.create_tween().tween_property(objective_box, "modulate:a", target, 0.3)


func _notification(what: int) -> void:
	if objective_box == null:
		return
	if what == NOTIFICATION_PAUSED:
		objective_box.visible = false
	elif what == NOTIFICATION_UNPAUSED:
		objective_box.visible = true


## The Night of Ash on arriving somewhere (PIX-152): on the road, the
## scavenger feeding at the gate (and the night's first words); through the
## gate, the village is the next step.
func _prologue_arrive(next: MapData) -> void:
	match GameState.progression.prologue:
		Prologue.SCAVENGER:
			if next.id == "overworld":
				var at: Dictionary = Prologue.data()["scavenger"]
				var scavenger := spawn_enemy(at["monsterId"], Vector2i(at["x"], at["y"]), "forest", "", false, true)
				scavenger.set_meta("prologue", true)
				# It keeps to its meal until the hero walks up or strikes:
				# the night's first fight is the hero's to start.
				scavenger.feeding = true
				messages.flash.call_deferred(String(Prologue.data()["arrival"]))
		Prologue.GATE:
			if next.id == "town":
				GameState.prologue_reached_town()
				prologue_wave.call_deferred()
		Prologue.HOUNDS, Prologue.EMBERS:
			if next.id == "town":
				prologue_wave.call_deferred()


## The night's foes for this beat (PIX-197): the ash hounds inside the gate,
## the embers on the square - below their kind's level, one told lunge
## among the hounds for the roll.
func prologue_wave() -> void:
	var wave := Prologue.wave(GameState.progression.prologue)
	if wave.is_empty() or map.id != "town":
		return
	var kind := Bestiary.monster(wave["monsterId"])
	for at: Array in wave["cells"]:
		var cell := Vector2i(int(at[0]), int(at[1]))
		var foe := spawn_enemy(wave["monsterId"], cell, "", "", bool(wave.get("elite", false)), false, cell, int(wave["level"]) - int(kind["level"]))
		foe.fighter["name"] = wave["name"]
		foe.set_meta("prologue_wave", true)
		fx.appear(foe)


## Dawn after the Night of Ash (PIX-197): played on the town itself - the
## fires going out, the survivors on the square, the letter read, Fafnyr's
## shadow - and then the day.
func _play_dawn() -> void:
	var dawn := preload("res://scripts/dawn_screen.gd").new()
	dawn.world = self
	dawn.on_done = func() -> void:
		GameState.finish_prologue()
		map = _load_map("town")
		# The day begins on the square, below the hall, whether the dawn
		# was watched or skipped.
		_enter_map(map, Town.square() + Vector2i(0, 2))
	add_child(dawn)


## A night under Sela's roof (or canvas) brings Morvax's voice, once per
## dream, in the order the story earns them (PIX-154).
func dream() -> void:
	if GameState.progression.prologue != Prologue.DONE:
		return
	play_story(Story.next_dream(GameState.progression.cleared_levels, GameState.progression.story_seen))


## A boss falls (PIX-210): the world slows a moment, shakes and flashes
## white, and the music cuts so the victory sting rings out alone (the
## floor's clearing plays it; a boss with foes still about plays its own).
func boss_fell() -> void:
	Sound.stop_music()
	soundscape.hush(BOSS_HUSH_S)
	hunted_by_boss = false
	if map.floor_level == 0 or floor_foes > 0:
		Sound.play("victory")
	camera_rig.shake(8.0, 0.6)
	if GameState.settings.reduce_motion:
		return
	camera_rig.hit_stop(BOSS_SLOW_S, BOSS_SLOW)
	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, 0.75)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.position = -hud_root.offset
	flash.size = Touch.view_size(self)
	hud_root.add_child(flash)
	var fade := flash.create_tween().set_ignore_time_scale(true)
	fade.tween_property(flash, "color:a", 0.0, 0.45)
	fade.tween_callback(flash.queue_free)


## The ending (PIX-150): home to the square, the camera touring each age's
## landmark the hero built, then the square - and then the story's ending
## and credits. How Morvax ended (PIX-157) sets the evening: a festival
## with confetti for the one destroyed, five lanterns for the five who
## climbed for the one laid to rest.
func _play_ending(choice := "destroy") -> void:
	var scene_id := Story.ending_scene(choice)
	GameState.mark_seen(scene_id)
	GameState.reveals.clear()
	map = _load_map("town")
	# Below the fountain, facing the hall.
	var square := Town.square() + Vector2i(0, 3)
	_enter_map(map, square)
	if choice == "rest":
		_lanterns()
	else:
		_festival()
	Sound.play_track("victory")
	var stops: Array[Dictionary] = []
	var done := Town.done_projects(GameState.settlement)
	for entry: Dictionary in Town.ages():
		var built: Array = entry["projects"].filter(func(project_entry: Dictionary) -> bool: return project_entry["id"] in done)
		if built.is_empty():
			continue
		var landmark: Dictionary = built[-1]
		stops.append({
			"at": _cell_center(Town.project_center(landmark["id"])),
			"line": "%s - %s" % [landmark["name"], String(landmark["blurb"]).to_lower()],
		})
	var town_name := String(Town.tier(GameState.town_tier())["name"]).to_lower()
	stops.append({
		"at": _cell_center(square),
		"line": (Text.t("Five lanterns on the square, one for each of the five who climbed. Tonight the %s remembers them - and %s.")
			if choice == "rest" else Text.t("Pixelheim, a %s raised from the ashes. Tonight it celebrates %s.")) % [town_name, GameState.hero.hero_name],
	})
	var tour := preload("res://scripts/reveal_screen.gd").new()
	tour.world = self
	tour.stops = stops
	tour.on_done = func() -> void:
		var ending := Cutscene.new()
		ending.scene_id = scene_id
		add_child(ending)
	add_child(tour)


## Five lanterns in a row on the square (PIX-157), for Maren, Oskar,
## Liane, Tam and Morvax: Shade's flame on a post, or a warm square.
func _lanterns() -> void:
	var spots := Town.lanterns()
	for i in spots.size():
		var lantern := Node2D.new()
		lantern.position = _cell_center(spots[i])
		lantern.add_to_group("decor")
		var post := ColorRect.new()
		post.color = Color("4a3426")
		post.size = Vector2(2, 9)
		post.position = Vector2(-1, -7)
		lantern.add_child(post)
		var frames := ItemIcons.effect("flame", 10.0)
		if frames != null:
			var flame := AnimatedSprite2D.new()
			flame.sprite_frames = frames
			flame.scale = Vector2.ONE * 0.5
			flame.position = Vector2(0, -11)
			flame.frame = i
			flame.play()
			lantern.add_child(flame)
		else:
			var glow := ColorRect.new()
			glow.color = Color(1.0, 0.75, 0.35)
			glow.size = Vector2(4, 4)
			glow.position = Vector2(-2, -12)
			lantern.add_child(glow)
		actors.add_child(lantern)


## Confetti over the square: the town's festival, until the hero leaves.
func _festival() -> void:
	if GameState.settings.reduce_motion:
		return
	for color: Color in [Color("f2c14e"), Color("d8433f"), Color("4f7cff"), Color("5cbf4a")]:
		var confetti := CPUParticles2D.new()
		confetti.position = _cell_center(Town.square() + Vector2i(0, -4))
		confetti.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		confetti.emission_rect_extents = Vector2(14 * TILE, TILE)
		confetti.amount = 18
		confetti.lifetime = 4.0
		confetti.direction = Vector2.DOWN
		confetti.spread = 25.0
		confetti.gravity = Vector2(0, 14)
		confetti.initial_velocity_min = 4.0
		confetti.initial_velocity_max = 10.0
		confetti.scale_amount_min = 1.0
		confetti.scale_amount_max = 2.0
		confetti.color = color
		confetti.z_index = 7
		confetti.add_to_group("decor")
		add_child(confetti)


## Back from the board with something built: the town redraws around the
## hero, then shows it.
func after_board() -> void:
	if GameState.reveals.is_empty() or map.id != "town":
		return
	map = _load_map("town")
	_enter_map(map, player_cell)


## The town risen (PIX-147): what was built since the hero last saw the town,
## the age it reached, a homecoming - the camera tours them, then hands back.
func _play_reveals() -> void:
	if GameState.reveals.is_empty() or map.id != "town" or not is_inside_tree():
		return
	var stops: Array[Dictionary] = []
	for entry: String in GameState.reveals:
		var key := entry.get_slice(":", 1)
		match entry.get_slice(":", 0):
			"project":
				stops.append({"at": _cell_center(Town.project_center(key)), "line": Text.t("%s: built.") % Town.project(key)["name"]})
			"age":
				stops.append({
					"at": _cell_center(Town.square()),
					"line": Text.t("Pixelheim is a %s now.") % String(Town.tier(int(key))["name"]).to_lower(),
					"sound": "evolve", "dust": true,
				})
				if GameState.festival_on():
					stops.append({
						"at": _cell_center(Vector2i(int(Town.festival("barker")["x"]), int(Town.festival("barker")["y"]))),
						"line": Text.t("And today it celebrates: stalls on the square, and a ring toss with a prize for the best throw."),
					})
			"home":
				stops.append({"at": _cell_center(Town.square()), "line": Town.homecoming(int(key))})
			"hunt":
				stops.append({"at": _cell_center(Town.bounty_board() + Vector2i(0, 3)), "line": Hunts.named(key)["homecoming"]})
			"deep":
				# A Deep Hunt milestone (PIX-216): the town has heard.
				stops.append({"at": _cell_center(Town.square()), "line": Text.t(Dungeons.milestone(int(key))["homecoming"])})
	GameState.reveals.clear()
	if stops.is_empty() or (harness and not OS.get_cmdline_user_args().has("reveal")):
		return
	var tour := preload("res://scripts/reveal_screen.gd").new()
	tour.world = self
	tour.stops = stops
	add_child(tour)


## An escort under way on this map (PIX-192): its wagon waits at the start
## of the route, or comes back there a few breaths after it was lost.
var escort: Node2D
var escort_lost_at := -100.0


func _tend_escort() -> void:
	var due := GameState.escort_due()
	if due.is_empty() or map.id != due["def"]["mapId"]:
		return
	if escort != null and is_instance_valid(escort):
		return
	if Time.get_ticks_msec() / 1000.0 - escort_lost_at < 4.0:
		return
	var quest_id: String = due["quest"]["id"]
	escort = preload("res://scripts/escort.gd").new()
	escort.world = self
	escort.def = due["def"]
	escort.add_to_group("decor")
	escort.arrived.connect(func() -> void:
		GameState.escort_arrived(quest_id)
		messages.flash(due["def"]["arrived"]))
	escort.lost.connect(func() -> void:
		messages.flash(due["def"]["lost"])
		escort_lost_at = Time.get_ticks_msec() / 1000.0
		var gone := escort
		gone.create_tween().tween_property(gone, "modulate:a", 0.0, 1.0).finished.connect(gone.queue_free))
	actors.add_child(escort)


## A quest against the clock (PIX-192): its time ticks while the world runs,
## shown top right, red in its last half minute; a lapse closes the chest the
## goods went back to.
var run_clock: PanelContainer


func _run_clocks(delta: float) -> void:
	var ticked := GameState.tick_runs(delta)
	if ticked["message"] != "":
		messages.flash(ticked["message"])
	for chest_id: String in ticked["rearmed"]:
		if view.chest_sprites.has(chest_id):
			for chest: Dictionary in Interactables._data()["chests"]:
				if chest["id"] == chest_id:
					view.chest_sprites[chest_id].texture = MapView.treasure_texture(chest, false)
	var running := GameState.timed_run()
	if running.is_empty() or hud_root == null:
		if run_clock != null:
			run_clock.queue_free()
			run_clock = null
		return
	if run_clock == null:
		run_clock = PanelContainer.new()
		run_clock.add_theme_stylebox_override("panel", UiStyle.plate(12))
		run_clock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		run_clock.add_child(UiStyle.strong("", 16, UiStyle.CREAM))
		hud_root.add_child(run_clock)
	var left := ceili(float(running["left"]))
	var shown: Label = run_clock.get_child(0)
	shown.text = Text.t("%s  %d:%02d") % [running["quest"]["timed"]["clock"], left / 60, left % 60]
	shown.add_theme_color_override("font_color", Color("ff5a4a") if left <= 30 else UiStyle.CREAM)
	run_clock.reset_size()
	run_clock.position = Vector2(1280 - 24 - run_clock.size.x, 16)


func _spawn_player() -> void:
	player = preload("res://scripts/player.gd").new()
	player.world = self
	actors.add_child(player)
	# Light and darkness (PIX-221): the world's light for the hour, and the
	# hero's lantern for when it's dark.
	lights = preload("res://scripts/light_rig.gd").new()
	lights.world = self
	add_child(lights)
	lights.give_lantern(player)
	atmosphere = preload("res://scripts/atmosphere.gd").new()
	atmosphere.world = self
	add_child(atmosphere)

	camera_rig = CameraRig.new()
	camera_rig.world = self
	add_child(camera_rig)
	fx = WorldFx.new()
	fx.world = self
	add_child(fx)
	camera_rig.attach(player)
	get_tree().root.size_changed.connect(_place_hud)

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
	spawn_lairs()
	respawn_check = 0.0
	_revive_packs()


## The named monsters the board has posted, each in its lair on this map
## unless already out (PIX-156).
func spawn_lairs() -> void:
	if map.floor_level > 0:
		return
	var out := []
	for enemy in get_tree().get_nodes_in_group("mobs"):
		if not enemy.is_queued_for_deletion():
			out.append(enemy.fighter.get("named", ""))
	for entry in Hunts.living_on(map.id, GameState.board_floors(), GameState.progression.hunted):
		if entry["id"] not in out:
			spawn_named(entry["id"])


## A named monster in its lair (PIX-156), or at `cell` (the harness): never
## a pack, never respawned once dead; a chase it gives up ends with it home
## and whole again.
func spawn_named(named_id: String, cell := Vector2i(-1, -1)) -> Node:
	var at := Hunts.lair(Hunts.named(named_id)) if cell == Vector2i(-1, -1) else cell
	var enemy := preload("res://scripts/enemy.gd").new()
	enemy.world = self
	enemy.fighter = Hunts.fighter(named_id)
	enemy.region = map.region_at(at)
	enemy.position = _cell_center(at)
	enemy.home = _cell_center(at)
	enemy.add_to_group("mobs")
	actors.add_child(enemy)
	return enemy


## Cleared packs whose time is up, back at homes out of view.
func _revive_packs() -> void:
	if map.floor_level > 0:
		return
	for spawn: Dictionary in Bestiary.spawns_on(map.id):
		if not Packs.is_due(GameState.world, spawn["id"]):
			continue
		var home := _cell_center(Vector2i(spawn["x"], spawn["y"]))
		if camera_rig.in_view(home, 2 * TILE):
			continue
		GameState.revive_pack(spawn["id"])
		_spawn_pack(map, spawn)


## One pack around its home: up to PACK_SIZE on open cells of its region.
func _spawn_pack(data: MapData, spawn: Dictionary) -> void:
	var home := Vector2i(spawn["x"], spawn["y"])
	var region := data.region_at(home)
	var elite_chance := float(Bestiary.region(region)["eliteChance"])
	var cells: Array[Vector2i] = [home]
	for offset in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1)]:
		var cell: Vector2i = home + offset
		if cells.size() < PACK_SIZE and data.is_walkable(cell) and data.region_at(cell) != "" and not data.portals.has(cell):
			cells.append(cell)
	# A spawn may name its size: one captain, not three (PIX-165).
	cells.resize(mini(cells.size(), int(spawn.get("size", PACK_SIZE))))
	for i in cells.size():
		# The pack's leader is the spawn's kind; the rest the region's mix (PIX-191).
		var kind := Bestiary.pack_species(spawn, region, i, cells[i])
		spawn_enemy(kind, cells[i], region, spawn["id"], GameState.roll.call() < elite_chance, true, home)
	pack_alive[spawn["id"]] = cells.size()

func _build_hud() -> void:
	var hud := CanvasLayer.new()
	# Over the glow's layer (PIX-222: LightRig.GLOW_LAYER), so it never blooms.
	hud.layer = 2
	add_child(hud)
	# Day/night tint sits under the HUD widgets, over the world.
	sky_overlay = ColorRect.new()
	sky_overlay.color = Color(0, 0, 0, 0)
	sky_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(sky_overlay)
	# The hero's dock along the bottom; the battle log floats above its left.
	dock = preload("res://scripts/hud_dock.gd").new()
	dock.world = self
	hud.add_child(dock)
	boss_bar = preload("res://scripts/boss_bar.gd").new()
	hud.add_child(boss_bar)
	messages.build_log(hud)
	GameState.hp_changed.connect(_on_hp_changed)
	soundscape.listen()
	GameState.leveled_up.connect(func(_level: int) -> void:
		Sound.play("levelUp")
		soundscape.heard_hp = GameState.hero.hp
		fx.level_up_burst()
	)
	GameState.gold_changed.connect(func(_gold: int) -> void: dock.refresh())
	GameState.inventory_changed.connect(dock.refresh)
	GameState.healed.connect(dock.refresh)
	GameState.message.connect(messages.flash)
	GameState.noted.connect(messages.log_lines)
	GameState.healed.connect(func() -> void: player.heal())
	GameState.ranked_up.connect(_ascend)
	GameState.prologue_dawn.connect(_play_dawn)
	GameState.skill_learned.connect(func(entry: Dictionary, key: int) -> void:
		var values := {"skill": entry["name"], "what": entry.get("description", ""), "slot": Controls.say("{key:skill_%d}" % key)}
		hint("skill" if key > 0 else "skill_full", values, "skill:" + String(entry["id"]))
	)
	hud_root = hud
	_place_hud()
	# Thumbs instead of keys on a phone (PIX-162), and a word for whoever
	# holds it upright: the game reads best sideways.
	if Touch.enabled():
		add_child(preload("res://scripts/touch_controls.gd").new())
		var size := Touch.view_size(self)
		if size.y > size.x:
			hint.call_deferred("turn")
	GameState.settlers_changed.connect(folk.respawn)
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
	messages.build_plate(hud)
	objective_box = PanelContainer.new()
	objective_box.add_theme_stylebox_override("panel", UiStyle.plate())
	objective_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	objective_box.modulate.a = 0.0
	var objective_row := HBoxContainer.new()
	objective_row.add_theme_constant_override("separation", 8)
	objective_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	objective_box.add_child(objective_row)
	objective_row.add_child(UiStyle.plate_tag("Next"))
	objective_label = UiStyle.plate_text("")
	objective_row.add_child(objective_label)
	# Centred over the dock whatever the step's length.
	objective_box.resized.connect(func() -> void: objective_box.position.x = roundf((1280 - objective_box.size.x) / 2.0))
	hud.add_child(objective_box)

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

## The keys, as the player bound them (Controls, GameSettings).
func _setup_input() -> void:
	Controls.apply(GameState.settings.bindings)


var crt: CanvasLayer

## The CRT scanlines over everything, and fullscreen (never in harness runs).
func apply_video() -> void:
	var settings := GameState.settings
	# Large reading text (PIX-160) applies at once to what's on the HUD.
	if messages != null and messages.message_label != null:
		UiStyle.sized(messages.message_label, UiStyle.reading(16))
		messages.message_box.reset_size()
		UiStyle.sized(objective_label, UiStyle.reading(16))
		objective_box.reset_size()
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
