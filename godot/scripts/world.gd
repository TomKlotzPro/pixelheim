extends Node2D
## World orchestration: loads maps exported from the web game, builds their
## TileMapLayer, moves the hero through portals and doors, and runs the
## frame. Its pieces do the rest (Solid Ground, PIX-260, world_*.gd): the
## camera (CameraRig), what floats over the world (WorldFx), words
## (Messages), sound (Soundscape), villagers (Folk), what E does
## (Interaction), monsters (Foes), dungeon floors (Delve), the story (Stage)
## and the HUD (Hud). Tile tables live in WorldTiles; map data in MapData;
## everything that persists (position, discovery, chests, loot) in the
## GameState autoload.

const TILE := 16

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
## The monsters and the fight's clock (Foes), and the dungeon floors (Delve).
var foes: Foes
var delve: Delve
## The story over the world: moments, the night, the ending, reveals (Stage).
var stage: Stage
## The HUD: its layer and widgets, hints, the objective, the nameplate (Hud).
var hud: Hud
var player_cell := Vector2i.ZERO
var last_player_position := Vector2.ZERO
## Seconds until the next look for packs due to come home.
var respawn_check := 0.0
## The world's light and darkness (PIX-221, light_rig.gd).
var lights: Node
## Each region's air and the weather (PIX-224).
var atmosphere: Node
## A `--screenshot` run: the harness drives, nobody else.
var harness := false

func _ready() -> void:
	# The command line's flags, parsed once against the harness's table (PIX-262).
	var flags := HarnessFlags.given()
	if flags.has("--help"):
		# `-- --help`: the table, and nothing else: no slot is read or written.
		print(HarnessFlags.help())
		process_mode = Node.PROCESS_MODE_DISABLED
		get_tree().quit()
		return
	UiStyle.setup()
	# Only what physics moves is interpolated between ticks (the actors and
	# the camera riding the hero); the ground and the UI hold still.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	# The world's physics step runs after the actors', to note where the hero ended.
	process_physics_priority = 10
	harness = flags.has("--screenshot")
	# The phone version (PIX-162): on a touch screen (or a harness run with
	# `touch`) the canvas fills the screen's own shape instead of
	# letterboxing it.
	Touch.forced = flags.has("touch")
	if Touch.enabled():
		get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	if harness:
		# The harness window opens on the desktop of someone who may be typing
		# elsewhere: it doesn't take the keyboard (and harness.gd drops anything
		# but its own presses), and it stays on top, because macOS stops drawing
		# a covered window and the run would never reach its screenshot.
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	GameState.boot(flags)
	Sound.apply_volumes()
	_setup_input()
	apply_video.call_deferred()
	# Harness: `--town-tier N` previews the village at another age; without it
	# a run shows the Hamlet its flows were written for (`--town-tier 0` is a
	# new hero's Ashes).
	if flags.has("--town-tier"):
		GameState.settlement.town_tier = int(flags.value("--town-tier"))
	elif harness and GameState.settlement.projects.is_empty():
		GameState.settlement.town_tier = maxi(1, GameState.settlement.town_tier)
	# Harness runs skip the Night of Ash (their flows were written for the
	# town by day) unless `--prologue N` puts them at its step N.
	if harness:
		if flags.has("--prologue"):
			GameState.progression.prologue = int(flags.value("--prologue"))
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
	if flags.has("--house-tier"):
		GameState.settlement.house["tier"] = int(flags.value("--house-tier"))
	# `--day N`: the morning of day N, its patches grown (PIX-250).
	if flags.has("--day"):
		GameState.world.steps = float(int(flags.value("--day")) * DayNight.DAY_CYCLE_STEPS)
	# `--seen` and `--hunted`: stories told and named monsters slain before
	# the first map is drawn, so the gates they open stand open (PIX-254).
	for story_id: String in flags.list("--seen"):
		GameState.mark_seen(story_id)
	for named_id: String in flags.list("--hunted"):
		if named_id not in GameState.progression.hunted:
			GameState.progression.hunted.append(named_id)
	# The family a keepsake brings home is home already (PIX-255).
	if flags.has("--hunted"):
		GameState.holdings.come_home(true)
	# Resume where the save stands; `--map <id>` (harness) boots at that map's spawn.
	var override := flags.has("--map")
	# A save on a floor of a region's dungeon wakes at its entrance (PIX-255).
	var woke := Depths.waking(GameState.world.map_id, GameState.world.cell)
	map = load_map(flags.value("--map", woke["mapId"]))
	# A save standing in a doorway (the old doors into the caves, PIX-256)
	# wakes on the open ground beside it, not in the way through.
	var arrival: Vector2i = map.spawn if override else Ways.standing(map, woke["cell"])
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
	foes = Foes.new()
	foes.world = self
	add_child(foes)
	delve = Delve.new()
	delve.world = self
	add_child(delve)
	stage = Stage.new()
	stage.world = self
	stage.cards = not harness
	add_child(stage)
	hud = Hud.new()
	hud.world = self
	add_child(hud)
	_build_hud()
	interaction.build_prompt()
	enter_map(map, arrival)
	# A first visit to the Godot build that finds a web game hero in this
	# browser offers to bring them along before anything else.
	var greeted := false
	if GameState.first_run:
		var found := WebImport.find_in_browser()
		if not found.is_empty():
			open_saves(found, true)
			greeted = true
	# The title greets a launch (not a slot switch or a reload, and not the harness).
	if not greeted and not GameState.title_seen and (not harness or flags.has("title")):
		open_title()
	if harness:
		var driver := preload("res://scripts/harness.gd").new()
		driver.world = self
		driver.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(driver)


## The title screen over the world (a launch, or back from the saves).
func open_title() -> void:
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
	hud.update_nameplate()
	stage.run_clocks(delta)
	messages.update()
	hud.keep_hint_clear()
	# The boss slayer's edge (PIX-232) wears down while the world runs.
	GameState.spoils.tick_slayer(delta)
	hud.update_edge()
	stage.tend_escort()
	GameState.walk(player.position.distance_to(last_player_position) / TILE)
	last_player_position = player.position
	# The dark is the world's own now (PIX-221: the LightRig), not a veil
	# over it; the veil is left for the dawn's own fades.
	hud.sky_overlay.color = Color(0, 0, 0, 0)
	soundscape.refresh()
	respawn_check -= delta
	if respawn_check <= 0:
		respawn_check = 1.0
		foes.keep_hours()
		view.refresh_patches()
		folk.keep_hours()
		hud.hint_boards()
	hud.update_objective()
	hud.update_arrow()
	hud.update_clock()
	stage.watch_chapters(delta)
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
	# Into a region of the Reach: its name, once (PIX-269).
	hud.name_place(map, cell)
	# Walking into the bought house's shut door walks you in.
	if map.id == "town" and cell + Vector2i(player.facing) == Town.house_door() and GameState.household.owns_house():
		enter_house()
		return
	interaction.step_on(cell)
	if Ways.goes_down(map, cell):
		# The stairs down from a room ask first (PIX-256): the hero waits at
		# the top, like at a dungeon's gate.
		_step_back()
		interaction.ask_down(cell)
	elif map.portals.has(cell):
		use_portal(map.portals[cell])

## Maps as the town has grown: the village and the house redraw per tier.
func load_map(map_id: String) -> MapData:
	var loaded := MapData.load_tiered(map_id, Town.done_projects(GameState.settlement), int(GameState.settlement.house.get("tier", 1)))
	# A region dungeon's shortcut stands open once its boss is down (PIX-255).
	Depths.open_shortcut(loaded, GameState.progression.hunted)
	return loaded

func is_walkable(cell: Vector2i) -> bool:
	return map.is_walkable(cell)

func on_player_died() -> void:
	await get_tree().create_timer(1.2).timeout
	# Defeat is forgiving: wake at the inn, healed, purse intact.
	var inn: Dictionary = GameState.upkeep.wake_at_inn()
	var bed := Vector2i(inn["x"], inn["y"])
	map = load_map(inn["mapId"])
	enter_map(map, bed)
	player.respawn(MapView.center(bed))
	last_player_position = player.position  # a respawn is not a walk

## Through a portal the hero stepped on (or the harness sent them to): a
## door to another map, a dungeon's gate and its floor select, the stairs
## up from a floor, or the hole deeper.
func use_portal(target: Dictionary) -> void:
	# No running from a boss (PIX-232): the way out holds until it falls.
	var boss := foes.boss_hunting()
	if boss != null:
		_step_back()
		messages.flash(Text.t("%s bars your way: no leaving until the fight is over.") % boss.fighter["name"])
		return
	match target["kind"]:
		"map":
			var next := load_map(target["mapId"])
			_through_door(func() -> void:
				var from_id := map.id
				var arrival := Vector2i(int(target["x"]), int(target["y"]))
				map = next
				# Facing into the new map, away from the way back (PIX-269),
				# not into the rock or the door they came out of.
				player.face(Ways.arrival_facing(map, arrival, from_id, player.facing))
				enter_map(map, arrival)
			, Ways.goes_under(map, next))
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
			# Back up the stairs: up out of the dark dissolves.
			_through_door(delve.leave_floor)
		"deeper":
			delve.enter_floor(map.floor_level + 1)


## One of the hero's screens, from its key or the panel's button.
func open_screen(screen: String) -> void:
	if player.dead or get_tree().paused:
		return
	match screen:
		"inventory":
			open_inventory()
		"map":
			if map.floor_level > 0:
				messages.flash("No map reaches this deep.")
				return
			var chart := preload("res://scripts/map_screen.gd").new()
			chart.world = self
			add_child(chart)
		_:
			add_child(load("res://scripts/%s_screen.gd" % screen).new())


## The pack (I, or the dock's menu).
func open_inventory() -> void:
	var screen := preload("res://scripts/inventory_screen.gd").new()
	screen.world = self
	add_child(screen)


## Back off a gate to the cell the hero came from (the web keeps them there).
func _step_back() -> void:
	var back := player_cell - Vector2i(player.facing)
	if not map.is_walkable(back):
		return
	player_cell = back
	player.position = MapView.center(back)
	camera_rig.cut()
	last_player_position = player.position
	GameState.move_to(map, back, player.facing)


func enter_map(next: MapData, arrival: Vector2i) -> void:
	var changing := view != null
	if changing:
		Sound.play("door")
	foes.hunted_at = -100.0
	soundscape.listen_again()
	foes.arrived_at = GameClock.seconds()
	for stale in get_tree().get_nodes_in_group("mobs") + get_tree().get_nodes_in_group("decor"):
		stale.queue_free()
	if view != null:
		view.clear()
	view = MapView.new(next, actors)
	arrival = view.plan(arrival)
	view.build(self)
	folk.spawn_for(next)
	player.position = MapView.center(arrival)
	camera_rig.cut()
	player.ailments.clear()
	last_player_position = player.position
	player_cell = arrival
	# Crossing into a map is a moment worth keeping: save at once. Dungeon
	# floors aren't web maps: the save keeps the gate.
	if next.floor_level == 0:
		GameState.move_to(next, arrival, player.facing)
		GameState.save_now()
	foes.floor_foes = 0
	# The place's name once the hero is there, not on a post by the way out
	# (PIX-269); the map the game opens on is only noted.
	hud.name_place(next, arrival, not changing)
	stage.arrive(next)
	# A floor of a region's dungeon says which (PIX-255).
	delve.arrive(next)
	# A festival day: confetti over the square (PIX-159).
	if next.id == "town" and GameState.holdings.festival_on():
		stage.festival()
	stage.play_reveals.call_deferred()
	folk.keep_hours(true)
	# Under the sky the camera may look past the south edge, under the dock.
	camera_rig.set_limits(Vector2(next.size * TILE), next.floor_level == 0 and next.style != "cave" and PunyTerrain.is_outdoor(next.grid))
	foes.spawn_for(next)
	respawn_check = 0.0
	soundscape.refresh()
	# Through a door that dissolves, the old picture is already fading out
	# over this one; otherwise (a dungeon's floors, waking at the inn, the
	# story's moments) the new map comes in from the dark.
	if changing and not _dissolving:
		_fade_in()


## Through a door the old place dissolves into the new one (One Reach,
## PIX-269: Tom found crossing a cut): the town's gate, a house's or a
## shop's door, a cave's mouth and the stairs back up are short changes of
## scene, the screen as it stood fading out over the new map in a quarter
## of a second (Dissolve), with no black between. Going under the ground
## (into a cave, a cellar, a dungeon's floor: Ways.goes_under) keeps a
## brief dark, the mood down there: the world fades to the dark first
## (PIX-226), then the new map fades in (_fade_in). At once with reduced
## motion, and in harness runs unless they ask (`fades`).
const DOOR_FADE := 0.15
var _passing := false
## While a dissolve's new map is built under its picture.
var _dissolving := false
## How the last change of scene looked: "dissolve", "dark", or "cut" (with
## reduced motion); the harness reports it (`fades`).
var scene_change := ""


func _through_door(then: Callable, down := false) -> void:
	if down or not _fades():
		_through_dark(then)
		return
	scene_change = "dissolve"
	Dissolve.hold(self)
	_dissolving = true
	then.call()
	_dissolving = false


## Through the dark: the screen fades to it, `then` changes the scene, and
## whatever comes next fades in from it. Once at a time; at once (a cut)
## with no fades.
func _through_dark(then: Callable) -> void:
	if not _fades():
		scene_change = "cut"
		then.call()
		return
	if _passing:
		return
	_passing = true
	scene_change = "dark"
	var dark := _fade_rect(Color(UiStyle.NIGHT, 0.0))
	var fade := dark.create_tween()
	fade.tween_property(dark, "color:a", 1.0, DOOR_FADE).set_ease(Tween.EASE_OUT)
	fade.tween_callback(func() -> void:
		then.call()
		dark.queue_free()
		_passing = false
	)


## A night's sleep (PIX-246): the screen goes dark, `then` lets the night
## pass (the clock runs on to the morning), and the world wakes to it - its
## folk where the morning puts them - fading in. With no fades (reduced
## motion, a harness run) it simply happens.
func sleep_through(then: Callable) -> void:
	_through_dark(func() -> void:
		then.call()
		folk.keep_hours(true)
		_fade_in()
	)


## A new map fades in from the dark (PIX-211) instead of cutting.
func _fade_in() -> void:
	if not _fades():
		return
	var dark := _fade_rect(UiStyle.NIGHT)
	var fade := dark.create_tween()
	fade.tween_property(dark, "color:a", 0.0, 0.35).set_ease(Tween.EASE_IN)
	fade.tween_callback(dark.queue_free)

## Whether the screen fades through the dark: not with reduced motion, nor in
## harness runs, whose pictures are taken at once, unless one asks (`fades`).
func _fades() -> bool:
	if GameState.settings.reduce_motion or hud.root == null:
		return false
	return not harness or HarnessFlags.given().has("fades")


## The dark a fade runs on, over the world and under the HUD's widgets. It
## runs on while the world is paused (PIX-238): the town's tour pauses the
## world a frame after it's redrawn, and the fade froze at full black over
## the whole tour.
func _fade_rect(color: Color) -> ColorRect:
	var dark := ColorRect.new()
	dark.color = color
	dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dark.position = -hud.root.offset
	dark.size = Touch.view_size(self)
	dark.process_mode = Node.PROCESS_MODE_ALWAYS
	dark.set_meta("fade", true)
	hud.root.add_child(dark)
	return dark


## The saves screen; `web_save` defaults to whatever this browser's web game holds.
func open_saves(web_save := {}, welcome := false) -> void:
	var screen := preload("res://scripts/saves_screen.gd").new()
	screen.web_save = web_save if not web_save.is_empty() else WebImport.find_in_browser()
	screen.welcome = welcome
	add_child(screen)

## Fast travel from the map screen; the waypoint is already usability-checked.
## The map and the place left dissolve into where it lands, as a door does.
func travel_to(waypoint: Dictionary) -> void:
	Sound.play("travel")
	var arrival := Vector2i(int(waypoint["arrival"]["x"]), int(waypoint["arrival"]["y"]))
	var next := map if waypoint["mapId"] == map.id else load_map(waypoint["mapId"])
	_through_door(func() -> void:
		map = next
		enter_map(map, arrival)
	, Ways.goes_under(map, next))

## Into the bought house, at its door (E on the door, or walking into it).
func enter_house() -> void:
	_through_door(func() -> void:
		map = load_map("town_house")
		enter_map(map, Vector2i(8, 8))
		hud.hint("house")
	)


## The objective line hides while the world is paused (menus,
## conversations, cutscenes).
func _notification(what: int) -> void:
	if hud == null or hud.objective_box == null:
		return
	if what == NOTIFICATION_PAUSED:
		hud.objective_box.visible = false
	elif what == NOTIFICATION_UNPAUSED:
		hud.objective_box.visible = true


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

## The HUD (Hud builds its widgets), and which of GameState's signals reach
## what: the dock and the hints, the messages, the sounds, the story.
func _build_hud() -> void:
	hud.build()
	GameState.hp_changed.connect(hud.on_hp_changed)
	soundscape.listen()
	GameState.leveled_up.connect(func(_level: int) -> void:
		Sound.play("levelUp")
		soundscape.heard_hp = GameState.hero.hp
		fx.level_up_burst()
	)
	GameState.gold_changed.connect(func(_gold: int) -> void: hud.dock.refresh())
	GameState.inventory_changed.connect(hud.dock.refresh)
	GameState.healed.connect(hud.dock.refresh)
	GameState.message.connect(messages.flash)
	GameState.noted.connect(messages.log_lines)
	GameState.healed.connect(func() -> void: player.heal())
	GameState.ranked_up.connect(stage.ascend)
	GameState.prologue_dawn.connect(stage.play_dawn)
	GameState.skill_learned.connect(func(entry: Dictionary, key: int) -> void:
		var values := {"skill": entry["name"], "what": entry.get("description", ""), "slot": Controls.say("{key:skill_%d}" % key)}
		hud.hint("skill" if key > 0 else "skill_full", values, "skill:" + String(entry["id"]))
	)
	# Thumbs instead of keys on a phone (PIX-162), and a word for whoever
	# holds it upright: the game reads best sideways.
	if Touch.enabled():
		add_child(preload("res://scripts/touch_controls.gd").new())
		var size := Touch.view_size(self)
		if size.y > size.x:
			hud.hint.call_deferred("turn")
	GameState.settlers_changed.connect(folk.respawn)

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
		UiStyle.sized(hud.objective_label, UiStyle.reading(16))
		hud.objective_box.reset_size()
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
	if harness:
		return
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if settings.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
