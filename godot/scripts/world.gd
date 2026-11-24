class_name World
extends Node2D
## areas: all
## World orchestration: loads the maps (assets/maps), builds their
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
var player: Player
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
## The maps drawn beside the hero's under the Reach's sky, and the hand-over
## at the line (One Reach, PIX-269: Neighbours).
var neighbours: Neighbours
## The monsters and the fight's clock (Foes), and the dungeon floors (Delve).
var foes: Foes
var delve: Delve
## The story over the world: moments, the night, the ending, reveals (Stage).
var stage: Stage
## The Night of Bells on the town map (Night, PIX-253 step 9).
var night: Night
## The HUD: its layer and widgets, hints, the objective, the nameplate (Hud).
var hud: Hud
var player_cell := Vector2i.ZERO
var last_player_position := Vector2.ZERO
## Seconds until the next look for packs due to come home.
var respawn_check := 0.0
## The world's light and darkness (PIX-221, light_rig.gd).
var lights: LightRig
## Each region's air and the weather (PIX-224).
var atmosphere: Atmosphere
## A thunderstorm's lightning, thunder and what the rain leaves (PIX-491).
var storm: Storm
## A `--screenshot` run: the harness drives, nobody else.
var harness := false
## The way the story kept shut that last stopped the hero (`barred`: true
## for the mountain's gate, "vault" for the Kings' Vault's door), for the
## harness's report.
var barred_said := ""

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
	# `cc0` (harness): the paid pack held back, as a build without the
	# private art draws (PIX-318), and GegX's UI kit with it (PIX-385), and
	# the sound packs' takes (PIX-411).
	PunyTown.withheld = flags.has("cc0")
	UiStyle.withheld = PunyTown.withheld
	Sound.withheld = PunyTown.withheld
	if Touch.enabled():
		get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	if harness:
		# The harness window opens on the desktop of someone who may be typing
		# elsewhere: it doesn't take the keyboard (and harness.gd drops anything
		# but its own presses), and it stays on top, because macOS stops drawing
		# a covered window and the run would never reach its screenshot.
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	# A harness run boots its own throwaway hero (HarnessBoot, PIX-357).
	if harness:
		HarnessBoot.boot(flags, GameState)
	else:
		GameState.boot(int(flags.value("--slot", "-1")))
	Sound.apply_volumes()
	_setup_input()
	apply_video.call_deferred()
	# A harness run's presets (`--town-tier`, `--built`, `--bells`...), set
	# before the first map is drawn (HarnessBoot, PIX-357).
	if harness:
		HarnessBoot.before_first_map(flags)
	# Resume where the save stands; `--map <id>` (harness) boots at that map's spawn.
	var override := flags.has("--map")
	# A save on a floor of a region's dungeon wakes at the top of that
	# floor (PIX-255, PIX-302 step 4).
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
	night = Night.new()
	night.world = self
	add_child(night)
	hud = Hud.new()
	hud.world = self
	add_child(hud)
	neighbours = Neighbours.new()
	neighbours.world = self
	add_child(neighbours)
	_build_hud()
	interaction.build_prompt()
	go(map, arrival, Passage.CUT)
	# The title greets a launch (not a slot switch or a reload, and not the harness).
	if not GameState.title_seen and (not harness or flags.has("title")):
		open_title()
	elif GameState.slot_note != "":
		# What the title would have said (PIX-303: this hero is the save
		# before, its last unreadable), on the plate.
		messages.flash(GameState.slot_note)
		GameState.slot_note = ""
	elif preload("res://scripts/options_screen.gd").back_at >= 0:
		# Rebuilt in a language chosen in Options (PIX-428): the pause menu
		# they were over opens again, and they over it.
		open_pause()
	# The web page's loading screen fades as the first screen rises out of
	# the same picture (PIX-296, web/shell.html); it waits for this word.
	if OS.has_feature("web"):
		var page: Variant = JavaScriptBridge.get_interface("window")
		if page.pixelheimShown:
			page.pixelheimShown()
	if harness and not HarnessBoot.failed_to_load(get_tree(), [preload("res://scripts/harness.gd")]):
		var driver := preload("res://scripts/harness.gd").new()
		driver.world = self
		driver.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(driver)
	# `play` (PIX-423): tools/play.py's session, on the web only; on the
	# root, once, so a world reloaded mid-command (New Game) keeps it.
	if flags.has("play") and OS.has_feature("web") and get_tree().root.get_node_or_null("play_bridge") == null:
		var bridge := preload("res://scripts/play_bridge.gd").new()
		bridge.name = "play_bridge"
		bridge.page = JavaScriptBridge.get_interface("pixelheimPlay")
		get_tree().root.add_child.call_deferred(bridge)


## The title screen over the world (a launch, or back from the saves).
func open_title() -> void:
	var title := preload("res://scripts/title_screen.gd").new()
	title.world = self
	add_child(title)


## The pause menu (Esc).
func open_pause() -> void:
	var pause := preload("res://scripts/pause_screen.gd").new()
	pause.world = self
	add_child(pause)


## Keys arrive as events, never polled: a key a conversation or a menu
## already took (E on the last line, Esc to leave, I to close the pack) stops
## there, instead of reopening the talk or the pause menu behind it in the
## same frame. A paused world hears nothing.
func _unhandled_input(event: InputEvent) -> void:
	if player == null or player.dead:
		return
	var command := Callable()
	if event.is_action_pressed("menu"):
		command = open_pause
	elif event.is_action_pressed("interact"):
		command = interaction.interact
	else:
		for screen: String in ["journal", "stats", "skills", "codex", "inventory", "map"]:
			if event.is_action_pressed(screen):
				command = open_screen.bind(screen)
				break
	if command.is_valid():
		get_viewport().set_input_as_handled()
		# The E that ended a talk, pressed again at once, opens nothing
		# (PIX-486); and a screen E opens takes no E for a moment.
		if command == interaction.interact and Screen.hushed(event):
			return
		command.call()
		if command == interaction.interact and Screen.holds() > 0:
			Screen.hush()

func _process(delta: float) -> void:
	camera_rig.update(delta)
	# What stands over the hero turns see-through round them (PIX-429,
	# shaders/see_through.gdshaderinc).
	RenderingServer.global_shader_parameter_set("hero_at", player.global_position if player != null and player.visible else Foes.NOBODY)
	if player == null or player.dead:
		return
	interaction.update_prompt()
	hud.update_nameplate()
	stage.run_clocks(delta)
	messages.update()
	hud.next_hint()
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
		# The post box's pennant goes up with the morning's post (PIX-320).
		view.show_post_box()
		folk.keep_hours()
		hud.hint_boards()
		for feature in Features.all():
			feature.every_second(self)
	hud.update_objective()
	hud.update_arrow()
	hud.update_clock()
	stage.watch_chapters(delta)
	var cell := Vector2i((player.position / TILE).floor())
	# In a feature's shallows the hero wades (PIX-548): by where they stand
	# now, an arrival in them too.
	Wading.tread(player, player.sprite, view.data.shallows.has(cell))
	if cell == player_cell:
		return
	# A gatehouse's door opens once the hero is in under its arch (PIX-425).
	if map.portals.has(cell) and not Rampart.entered(map.grid, cell, player.position):
		return
	player_cell = cell
	# A step by the ground under it and what's laid over it, a street's
	# paving or a cave's rock (PIX-411), and dust off dry ground, a splash in
	# a bog (PIX-225).
	# A stone room's floor is its flags (PunyInterior.STONE_ROOMS), not boards.
	# The ground as a feature draws it first: the Mirefen's planks are wood,
	# its shallows water (MapView.drawn_as, PIX-519).
	var under: String = view.drawn_as.get(cell, map.tile_at(cell))
	var over: String = view.streets.get(cell, "stone" if map.id in PunyInterior.STONE_ROOMS else map.style)
	Sound.play(Sound.step_for(under, over))
	atmosphere.footfall(player.global_position + Vector2(0, 2), under)
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
	elif map.portals.has(cell) and not neighbours.seamless(cell):
		# A road out to a map drawn beside this one walks on into it (the
		# hand-over at the line, Neighbours); every other way is a door.
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
	# The web's music hushed under the inn's build (PIX-417, Sound.hush).
	# Both wait out a screen (PIX-503): running through a pause, they built
	# the inn under the Night of Bells' dawn or a foe's last words and freed
	# the foe those were about.
	get_tree().create_timer(1.2 - Sound.HUSH_S, false).timeout.connect(Sound.hush)
	await get_tree().create_timer(1.2, false).timeout
	# A named foe standing down is heard out and paid before the hero wakes
	# elsewhere (Foes.stood_down).
	while is_instance_valid(foes.yielding):
		await get_tree().process_frame
	# Raised meanwhile (the Night of Bells' dawn, Night._raise): no waking.
	if not player.dead:
		return
	# A fall on the Night of Bells wakes in the inn's doorway, the beat set
	# out again (PIX-253 step 9).
	if night.running():
		night.hero_fell()
		return
	# Defeat is forgiving: wake at the inn, healed, purse intact.
	var inn: Dictionary = GameState.upkeep.wake_at_inn()
	var bed := Vector2i(inn["x"], inn["y"])
	go(load_map(inn["mapId"]), bed, Passage.CUT)
	player.respawn(MapView.center(bed))
	last_player_position = player.position  # a respawn is not a walk

## Through a portal the hero stepped on (or the harness sent them to): a
## door, a gate or a stair to another map. A gate the story keeps shut
## (`barred`: the mountain's until Maren's promise, the Kings' Vault's until
## the dragon is freed) holds the hero before it.
func use_portal(target: Dictionary) -> void:
	# No running from a boss (PIX-232): the way out holds until it falls.
	var boss := foes.boss_hunting()
	if boss != null:
		bar_the_way(boss)
		return
	# Every way out of town is shut on the Night of Bells (PIX-253 step 9).
	var barred := night.barred()
	if barred != "":
		_step_back()
		messages.flash(barred)
		return
	if target["kind"] != "map":
		return
	# The mountain's gate, shut since the Night of Ash until Maren's promise
	# opens it on the road up to Morvax's forge (PIX-170, PIX-253 step 8),
	# and the Kings' Vault's door under the summit, shut until the dragon is
	# freed (PIX-257): the hero waits before it.
	if Ways.barred(target, GameState.progression, GameState.settlement):
		_step_back()
		messages.flash(Ways.barred_line(target))
		barred_said = "vault" if str(target.get("barred", "")) == Vault.DUNGEON else "mountain"
		return
	var next := load_map(target["mapId"])
	var arrival := Vector2i(int(target["x"]), int(target["y"]))
	# Facing into the new map, away from the way back (PIX-269), not into
	# the rock or the door they came out of: turned as the place changes.
	var turn := func() -> void: player.face(Ways.arrival_facing(next, arrival, map.id, player.facing))
	# The Vault's door opened the first time (PIX-257): Fafnyr shows the
	# hoard he hated, then the hero goes in.
	var first := Vault.first_word(target, GameState.progression)
	if first != "":
		_step_back()
		stage.play_story(first, func() -> void: go(next, arrival, Passage.through(map, next), turn))
		return
	# A stair taken, down or up, or a cave's mouth (PIX-414): steps ringing in the stone.
	var at: Variant = map.portals.find_key(target)
	if at != null and Ways.kind_of(map, at) in ["stairs", "down", "cave"]:
		Sound.play("stairs")
	go(next, arrival, Passage.through(map, next), turn)


## One of the hero's screens, from its key or the panel's button.
func open_screen(screen: String) -> void:
	if player.dead or get_tree().paused:
		return
	if screen == "journal":
		hud.hint_learnt("journal")
	match screen:
		"inventory":
			open_inventory()
		"map":
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


## A boss on the hunt holds the way out (PIX-232): back a step, and told.
func bar_the_way(boss: Node) -> void:
	_step_back()
	messages.flash(Text.t("%s bars your way: no leaving until the fight is over.") % boss.fighter["name"])


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


## One way to change place (PIX-500): the hero comes to `place` at `arrival`
## the way `how` says (Passage: DOOR, DARK, CUT, SEAMLESS, REDRAW), and
## that way decides what arriving does (Passage.DOES) - so a map drawn
## again round the hero is no door. `place` is a map read as the town has
## grown (load_map); a hand-over's is the map drawn beside the hero's
## (Neighbours), a redraw's the hero's own map read again, `arrival` their
## cell. `turning` runs as the place changes, before it is drawn (a door
## turns the hero to face into the new map).
## A door and the dark hush the web's music themselves (PIX-417); a cut and
## a redraw are built at once, so off a door their caller awaits
## `hushed_build` first (PIX-420). True once the hero is there, false when
## a change of place already under way dropped this one: a cut, a redraw
## and a hand-over never wait, and never drop.
func go(place: MapData, arrival: Vector2i, how: int, turning := Callable()) -> bool:
	if how == Passage.SEAMLESS:
		var beside: Dictionary = neighbours.drawn[place.id]
		_hand_over(beside, arrival)
		return true
	# Only the hero's own map is drawn again: any other is come to. And a
	# night sets its scene out as the town is come to, its foes with it
	# (Stage.arrive, Night.arrive), and has no other way to put its fires
	# and lanterns back: under one, the town drawn again is come to again,
	# as it always was.
	if how == Passage.REDRAW and (map == null or place.id != map.id or GameState.progression.prologue != Prologue.DONE or night.running()):
		how = Passage.CUT
	var there := [false]
	var arrive := func() -> void:
		if turning.is_valid():
			turning.call()
		map = place
		_enter_map(place, arrival, how)
		there[0] = true
	match how:
		Passage.DOOR:
			await _through_door(arrive)
		Passage.DARK:
			await _through_door(arrive, true)
		_:
			arrive.call()
	return there[0]


## The hero's map drawn for this visit (MapView) at `arrival`; the cell they
## arrive on, the map's spawn when that one is built over now.
func _draw_map(next: MapData, arrival: Vector2i) -> Vector2i:
	if view != null:
		view.clear()
	view = MapView.new(next, actors)
	arrival = view.plan(arrival)
	view.build(self)
	_set_plane()
	return arrival


## `next` built and the hero in it at `arrival`, come the way `how` says:
## each thing a door does only where that way does it (Passage.does). Only
## `go` calls it. The first map of a session (no view yet) is come to
## quietly: no sound, no card, a quiet save, no fade.
func _enter_map(next: MapData, arrival: Vector2i, how: int) -> void:
	var changing := view != null
	var leaving := Passage.does(how, Passage.FOES)
	if changing and Passage.does(how, Passage.SOUND):
		Sound.play("door")
	# Through a door every map drawn beside the hero's goes at once; and
	# drawn again, the hero's map has to be stitched to them anew.
	neighbours.forget()
	soundscape.listen_again()
	var stale: Array = get_tree().get_nodes_in_group("decor")
	if leaving:
		foes.hunted_at = -100.0
		foes.arrived_at = GameClock.seconds()
		stale += get_tree().get_nodes_in_group("mobs")
		# A boss's bar goes with the place it was fought in (PIX-288: a hero
		# felled mid-fight wakes at the inn, not under it).
		if hud.boss_bar != null:
			hud.boss_bar.let_go()
	for node: Node in stale:
		# Drawn again, a map keeps who walks it: its foes (not among these),
		# and the wagon the hero is seeing home (Stage.tend_escort), which
		# is among the decor only to go with the place.
		if leaving or node != stage.escort:
			node.queue_free()
	var asked := arrival
	arrival = _draw_map(next, arrival)
	folk.spawn_for(next)
	# Stood on the arrival and the camera cut there; a map drawn again
	# leaves the hero where they stand, but for one whose cell was built
	# over.
	if Passage.does(how, Passage.PLACED) or arrival != asked:
		player.position = MapView.center(arrival)
		camera_rig.cut()
	if Passage.does(how, Passage.AILMENTS):
		player.ailments.clear()
	last_player_position = player.position
	player_cell = arrival
	GameState.move_to(next, arrival, player.facing)
	# Crossing into a map is a moment worth keeping: save at once, and the
	# quill says so (PIX-302 step 4); the map the game opens on is saved
	# quietly, nothing having happened yet.
	if Passage.does(how, Passage.SAVE):
		GameState.save_now(GameState.MOMENT if changing else GameState.QUIET)
	# The place's name once the hero is there, not on a post by the way out
	# (PIX-269); the map the game opens on is only noted, and so is one
	# drawn again.
	hud.name_place(next, arrival, not changing or not Passage.does(how, Passage.NAME))
	if Passage.does(how, Passage.ARRIVAL):
		stage.arrive(next)
		# Home after the run, the Night of Bells (PIX-253 step 9).
		night.arrive(next)
		# A floor of a region's dungeon says which (PIX-255).
		delve.arrive(next)
	# A festival day: confetti over the square (PIX-159).
	if next.id == "town" and GameState.holdings.festival_on():
		stage.festival()
	if Passage.does(how, Passage.NEWS):
		stage.play_reveals.call_deferred()
		# A hub grown since the hero was last there has its tour (PIX-324).
		stage.play_hub_tour.call_deferred()
	folk.keep_hours(true)
	# Held to the map at once, or eased back to it where nothing cuts (the
	# maps beside a map drawn again come back in a moment).
	camera_rig.set_bounds(Rect2(Vector2.ZERO, Vector2(next.size * TILE)), Passage.does(how, Passage.PLACED))
	if leaving:
		foes.spawn_for(next)
	# The dodge taught on the way out to where packs roam, after the first
	# night, so no boss is the first to charge (PIX-341: L'Appelle-Marée
	# was); it waits for the place's card, the packs out (PIX-462: a hint
	# shows while what it is about is there).
	if changing and Passage.does(how, Passage.ARRIVAL) and GameState.progression.prologue == Prologue.DONE and not Bestiary.spawns_on(next.id).is_empty():
		hud.hint("dodge")
	respawn_check = 0.0
	soundscape.refresh()
	# Through a door that dissolves, the old picture is already fading out
	# over this one; otherwise (a dungeon's floors, waking at the inn, the
	# story's moments, a map drawn again) the new map comes in from the dark.
	if changing and Passage.does(how, Passage.FADE):
		_fade_in()


## The hand-over at a line (One Reach, PIX-269, step 6): the hero has
## walked on past their map's edge onto `beside`, a map drawn beside it
## (Neighbours), at `arrival`, its cell there; and it becomes theirs - no
## door, no dissolve, no dark. In the physics tick they crossed in, the
## world moves back by where that map lies, so its origin is the new map's:
## every drawing, the hero, the camera and whatever floats in the world,
## each as one, its smoothing between ticks moved with it, so nothing jumps
## on screen. The map left is drawn beside it now. Then what a map entered
## brings, as a walk brings it: the new map's packs come where they can't
## be seen and the old map's go (fading, if in sight), its folk come, its
## music cross-fades and its air eases in, the fog of war clears round the
## hero, the save follows them (once for crossing back and forth), and its
## name comes up as it would on arriving, with its three minutes' rest.
## Only `go` calls it (Passage.SEAMLESS).
func _hand_over(beside: Dictionary, arrival: Vector2i) -> void:
	var by := -Vector2(beside["offset"] * TILE)
	var left := map
	var left_view := view
	# What lives on the map left goes with it: its foes, its folk, a wagon.
	var leaving: Array[Node] = []
	for node: Node in get_tree().get_nodes_in_group("mobs") + get_tree().get_nodes_in_group("npcs"):
		if not node.is_queued_for_deletion():
			node.remove_from_group("mobs")
			node.remove_from_group("npcs")
			leaving.append(node)
	if stage.escort != null and is_instance_valid(stage.escort):
		leaving.append(stage.escort)
		stage.escort = null
	# A boss's bar goes with the boss left behind (PIX-288): no boss hunting
	# lets the hero over the line, but one that gave up may still be fading.
	var followed: Variant = hud.boss_bar.target
	if is_instance_valid(followed) and leaving.has(followed):
		hud.boss_bar.let_go()
	# A kill's coins still in the air land now (PIX-492): its float is up
	# before the world moves under it.
	fx.loot.settle()
	_shift_world(by)
	camera_rig.shift(by)
	last_player_position += by
	map = beside["data"]
	view = beside["view"]
	neighbours.handed_over(beside, left, left_view)
	_set_plane()
	for node: Node in leaving:
		_let_go(node)
	player_cell = arrival
	scene_change = "seamless"
	GameState.move_to(map, arrival, player.facing)
	if neighbours.saves_now():
		# A moment later, not in the very frame the line is crossed in.
		get_tree().create_timer(SAVE_AFTER_S).timeout.connect(GameState.save_now)
	hud.name_place(map, arrival)
	stage.arrive(map)
	atmosphere.carry_on()
	soundscape.listen_again()
	foes.come_in()
	foes.spawn_lairs(true)
	folk.come_in(_come)
	soundscape.refresh()


## How long what's left behind at a line takes to fade, and what comes to
## fade in; and how long after crossing it the save follows.
const LINE_FADE := 0.4
const SAVE_AFTER_S := 0.5


## Moves everything standing in the world by `by` (a hand-over): every
## drawing, the actors one by one (the actors' layer stays at the origin:
## its children's places are the world's), and whatever floats over them;
## never the HUD or the screens.
func _shift_world(by: Vector2) -> void:
	for child: Node in get_children():
		if child == actors:
			for actor: Node in actors.get_children():
				_shift(actor as CanvasItem, by)
		elif child is CanvasItem:
			_shift(child as CanvasItem, by)
		elif not child is CanvasLayer:
			for part: Node in child.get_children():
				if part is CanvasItem:
					_shift(part as CanvasItem, by)


## `item` moved by `by`, and its smoothing between physics ticks with it
## (what was drawn a tick ago moved too), so it doesn't streak across.
static func _shift(item: CanvasItem, by: Vector2) -> void:
	if item == null:
		return
	if item.is_physics_interpolated_and_enabled():
		RenderingServer.canvas_item_transform_physics_interpolation(item.get_canvas_item(), Transform2D(0.0, by))
	if item is Node2D:
		(item as Node2D).position += by
	elif item is Control:
		(item as Control).position += by


## Something of the map left behind at a line goes: at once out of sight,
## fading in sight (at once with reduced motion), doing nothing meanwhile.
func _let_go(node: Node) -> void:
	var item := node as Node2D
	if item == null or GameState.settings.reduce_motion or not camera_rig.in_view(item.global_position, TILE):
		node.queue_free()
		return
	node.process_mode = Node.PROCESS_MODE_DISABLED
	var fade := node.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade.tween_property(item, "modulate:a", 0.0, LINE_FADE)
	fade.tween_callback(node.queue_free)


## Someone of the map walked into comes into sight fading in, not popping.
func _come(node: Node) -> void:
	var item := node as Node2D
	if item == null or GameState.settings.reduce_motion or not item.visible or not camera_rig.in_view(item.global_position, TILE):
		return
	item.modulate.a = 0.0
	item.create_tween().tween_property(item, "modulate:a", 1.0, LINE_FADE)


## Where the hero's map lies in the plane, for the shaders (the wind, the
## ground's slow noise, the water's light run on unbroken across a line).
func _set_plane() -> void:
	RenderingServer.global_shader_parameter_set("plane_origin", plane_px())


## The same, in pixels: zero off the plane.
func plane_px() -> Vector2:
	return Vector2(neighbours.origin() * TILE) if neighbours != null else Vector2.ZERO


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
## How the last change of scene looked: "dissolve", "dark", or "cut" (with
## reduced motion); the harness reports it (`fades`).
var scene_change := ""


func _through_door(then: Callable, down := false) -> void:
	if down or not _fades():
		await _through_dark(then)
		return
	if not _passing:
		_hero_goes_in()
	if not await _hushed(true):
		return
	scene_change = "dissolve"
	Dissolve.hold(self)
	then.call()
	if player != null:
		player.modulate.a = 1.0


## The hero out of the picture the dissolve holds (PIX-438: seen standing
## in the door as the place changed): faded over the web's hush, gone in a
## frame elsewhere. (A test's world may have no hero.)
func _hero_goes_in() -> void:
	if player == null:
		return
	if Sound.hushes_builds:
		player.create_tween().tween_property(player, "modulate:a", 0.0, Sound.HUSH_S)
	else:
		player.modulate.a = 0.0


## Through the dark: the screen fades to it, `then` changes the scene, and
## whatever comes next fades in from it. Once at a time; at once (a cut)
## with no fades. It returns once `then` has run, or at once when dropped.
func _through_dark(then: Callable) -> void:
	if not _fades():
		if not await _hushed():
			return
		scene_change = "cut"
		then.call()
		return
	if _passing:
		return
	_passing = true
	scene_change = "dark"
	# The music hushes as the screen darkens (the web, PIX-417): the fade
	# is the hush's HUSH_S.
	Sound.hush()
	var dark := _fade_rect(Color(UiStyle.NIGHT, 0.0))
	var fade := dark.create_tween()
	fade.tween_property(dark, "color:a", 1.0, DOOR_FADE).set_ease(Tween.EASE_OUT)
	fade.tween_callback(func() -> void:
		then.call()
		dark.queue_free()
		_passing = false
	)
	await fade.finished


## On the web the music hushed before a map is built under a dissolve or a
## cut (PIX-417, Sound.hush_first); at once elsewhere. False while a change
## of place already waits on it. `draw_first`: a dissolve's picture wants a
## frame drawn first, off the web too.
func _hushed(draw_first := false) -> bool:
	if not Sound.hushes_builds and not draw_first:
		return true
	if _passing:
		return false
	_passing = true
	# The hero waits on the door meanwhile, as on the desktop (PIX-425):
	# walking on, they were over the town's wall when the place changed.
	# (A test's world may have no hero.)
	if player != null:
		player.set_physics_process(false)
	await Sound.hush_first()
	# With no hush to wait on, a frame drawn as things now stand, for the
	# dissolve's picture (a quiet run draws none).
	if draw_first and not Sound.hushes_builds and DisplayServer.get_name() != "headless":
		await get_tree().process_frame
		await get_tree().process_frame
	if player != null:
		player.set_physics_process(true)
	_passing = false
	return true


## Before a map built where no door is (PIX-420): a scene's place (the dawn,
## the ending, the morning after the Night of Bells), Lantern Night's stalls,
## a place grown round the hero. On the web it waits on the music's hush as
## a door's build does (_hushed), in the dark the new map fades in from
## (_fade_in), so the place left isn't seen again; at once elsewhere. False
## while a change of place already waits on it, unless `must`: a story's
## build, asked once the story has moved on, waits for that change to end
## instead (a dark fade's too, off the web), then builds: never dropped.
func hushed_build(must := false) -> bool:
	while must and _passing:
		await get_tree().process_frame
	var dark: ColorRect = _fade_rect(UiStyle.NIGHT) if Sound.hushes_builds and _fades() else null
	var go: bool = await _hushed()
	if dark != null:
		# Freed after this frame's build, under the fade-in's own dark.
		dark.queue_free()
	return go


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


## The saves screen.
func open_saves() -> void:
	add_child(preload("res://scripts/saves_screen.gd").new())

## Fast travel from the map screen; the waypoint is already usability-checked.
## The map and the place left dissolve into where it lands, as a door does.
func travel_to(waypoint: Dictionary) -> void:
	# Not on the Night of Bells: the square needs the hero (PIX-253 step 9).
	if night.barred() != "":
		messages.flash(night.barred())
		return
	Sound.play("travel")
	var arrival := Vector2i(int(waypoint["arrival"]["x"]), int(waypoint["arrival"]["y"]))
	var next := map if waypoint["mapId"] == map.id else load_map(waypoint["mapId"])
	go(next, arrival, Passage.through(map, next))

## Into the bought house, at its door (E on the door, or walking into it).
func enter_house() -> void:
	if await go(load_map("town_house"), Vector2i(8, 8), Passage.DOOR):
		hud.hint("house")


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
	# lantern the hero carries for when it's dark (PIX-530: none without one).
	lights = preload("res://scripts/light_rig.gd").new()
	lights.world = self
	add_child(lights)
	lights.give_lantern(player)
	atmosphere = preload("res://scripts/atmosphere.gd").new()
	atmosphere.world = self
	add_child(atmosphere)
	# After the LightRig, whose windows' light it flashes (PIX-491).
	storm = preload("res://scripts/storm.gd").new()
	storm.world = self
	add_child(storm)

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
	GameState.leveled_up.connect(func(_level: int, ranked: bool) -> void:
		Sound.play("level_up")
		soundscape.heard_hp = GameState.hero.hp
		# The ascension opens in the same tick and holds the world still: a
		# burst begun now froze half-popped behind it (PIX-536).
		if not ranked:
			fx.level_up_burst()
	)
	GameState.gold_changed.connect(func(_gold: int) -> void: hud.dock.refresh())
	GameState.inventory_changed.connect(hud.dock.refresh)
	GameState.healed.connect(hud.dock.refresh)
	GameState.message.connect(messages.flash)
	# A quest's count, the Post's words: they wait out a fight (PIX-334).
	GameState.noted.connect(messages.log_lines.bind(true))
	GameState.healed.connect(func() -> void: player.heal())
	GameState.ranked_up.connect(stage.ascend)
	GameState.prologue_dawn.connect(stage.play_dawn)
	GameState.skill_learned.connect(func(entry: Dictionary, key: int) -> void:
		var values := {"skill": entry["name"], "slot": Controls.say("{key:skill_%d}" % key)}
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
	# The quill by the clock writes as a moment is saved (PIX-302 step 4).
	GameState.saved.connect(hud.on_saved)

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
		# Their tags the size of their words (PIX-471).
		UiStyle.sized(messages.message_tag, UiStyle.reading(16), true)
		messages.message_box.reset_size()
		UiStyle.sized(hud.objective_label, UiStyle.reading(16))
		UiStyle.sized(hud.objective_tag, UiStyle.reading(16), true)
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
