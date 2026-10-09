extends Node
## The agent verification harness, loaded only for `--screenshot` runs
## (world.gd adds it; it never ships in play): headless Godot cannot render,
## so it drives a real window briefly - warps, keys, screens, fights - saves
## screenshot.png, prints a report line, and quits:
## `godot --path godot -- --screenshot [fight] [kill] [saves] [--map <id>]
## [--walk l,d,r,u,...] [--web-save <file>] ...`. Every flag is documented in
## godot/README.md; the release flows (tools/flows.sh) drive it.

## The device id the harness stamps on the keys it presses (`--keys`).
const DEVICE := 77

var world: Node


func _ready() -> void:
	_run_test_harness()


## Keys from anyone but the harness are dropped, paused or not: the window
## opens on the desktop of someone who may be typing elsewhere, and a stray D
## would walk the hero or close a conversation mid-shot. (The world used to
## filter, but a paused world hears nothing, so a conversation took them.)
## The Input singleton has already counted the key, so its actions are let
## go too, or movement, which reads them, would still walk.
func _input(event: InputEvent) -> void:
	if event.device == DEVICE:
		return
	get_viewport().set_input_as_handled()
	for action: StringName in InputMap.get_actions():
		if event.is_action(action, true):
			Input.action_release(action)


## `--keys e,e,esc,...` presses real keys, one at a time, as a player would.
func _keys(args: PackedStringArray) -> void:
	var keys_index := args.find("--keys")
	if keys_index < 0 or keys_index + 1 >= args.size():
		return
	var codes := {
		"e": KEY_E, "esc": KEY_ESCAPE, "space": KEY_SPACE, "enter": KEY_ENTER, "s": KEY_S, "w": KEY_W,
		"i": KEY_I, "q": KEY_Q, "k": KEY_K, "c": KEY_C, "m": KEY_M, "b": KEY_B, "shift": KEY_SHIFT,
		"r": KEY_R, "a": KEY_A, "d": KEY_D, "z": KEY_Z, "x": KEY_X, "f": KEY_F,
	}
	for key: String in args[keys_index + 1].split(","):
		for pressed: bool in [true, false]:
			_press(codes[key], pressed)
			# Held through two physics ticks too: walking and facing are read
			# there, and a quiet run's frames come faster than its ticks.
			await get_tree().process_frame
			await get_tree().physics_frame
			await get_tree().physics_frame
			await get_tree().process_frame
		# Paced in time as well as frames, as a hand is: a quiet (headless)
		# run draws frames far faster than a window, and a screen that
		# ignores the press that opened it would miss the next.
		await get_tree().create_timer(0.08).timeout
	await get_tree().create_timer(0.2).timeout


## A harness key press, as a player's would land: the Input singleton's
## actions (what polling reads) and the event itself, straight to the
## viewport, which needs no window focus (an unfocused window's keys are
## dropped by the display server).
func _press(keycode: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.keycode = keycode
	event.pressed = pressed
	event.device = DEVICE
	for action: StringName in InputMap.get_actions():
		if InputMap.event_is_action(event, action, true):
			if pressed:
				Input.action_press(action)
			else:
				Input.action_release(action)
	get_viewport().push_input(event)


## Harness `lineup`: the cast PunyArt assigns, side by side with names.
func _lineup() -> void:
	for node in get_tree().get_nodes_in_group("mobs") + get_tree().get_nodes_in_group("npcs"):
		node.queue_free()
	world.camera_rig.camera.zoom = Vector2(2.6, 2.6)
	var rows := [
		PunyArt.HEROES.keys().map(func(role: String) -> Array: return [role, PunyArt.hero(role)]),
		PunyArt.VILLAGERS.keys().map(func(id: String) -> Array: return [id, PunyArt.villager(id)]),
		PunyArt.MONSTERS.keys().map(func(id: String) -> Array: return [id, PunyArt.monster(id)]),
	]
	var origin: Vector2 = world.player.position + Vector2(-210, -100)
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
				world.add_child(sprite)
				if dir == "down":
					var label := Label.new()
					label.text = entry[0]
					label.add_theme_font_size_override("font_size", 5)
					label.position = sprite.position + Vector2(-12, 9)
					world.add_child(label)
				x += 1
			y += 1


## Runs the flags it was given, in a fixed order, then shoots and quits.
func _run_test_harness() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.has("--screenshot"):
		return
	await get_tree().create_timer(0.4).timeout
	# `--set large_text,clear_warnings`: those settings on for this run only
	# (the harness never writes the player's settings).
	var set_index := args.find("--set")
	if set_index >= 0 and set_index + 1 < args.size():
		for setting: String in args[set_index + 1].split(","):
			GameState.settings.set(setting, true)
		world.apply_video()
	# Dungeons: `--floor N` walks down floor N, `gate [--dungeon id]` opens a
	# gate's floor select (mountain by default).
	var floor_index := args.find("--floor")
	if floor_index >= 0 and floor_index + 1 < args.size():
		world.delve.enter_floor(int(args[floor_index + 1]))
		await get_tree().create_timer(0.3).timeout
	# `--story <id>`: a story scene from assets/data/story.json, over the world.
	var story_index := args.find("--story")
	if story_index >= 0 and story_index + 1 < args.size():
		world.play_story(args[story_index + 1])
		await get_tree().create_timer(0.3).timeout
	if args.has("gate"):
		var dungeon_index := args.find("--dungeon")
		# The floor select, not the barred gate (PIX-170): the relics are home.
		if not Relics.gate_open(GameState.progression):
			GameState.progression.quests[Relics.quest_id()] = {"progress": Relics.all().size(), "done": true}
		world._use_portal({
			"kind": "dungeon",
			"dungeon": args[dungeon_index + 1] if dungeon_index >= 0 else "mountain",
		})
		await get_tree().create_timer(0.3).timeout
		if args.has("descend"):
			# Take the selected floor, as E would.
			world.get_children().filter(func(node: Node) -> bool: return node.has_method("_descend"))[0]._act()
			await get_tree().create_timer(0.4).timeout
	if args.has("clear"):
		# Fell every foe on the floor at once (after `gate descend`): the clear, its hoard, the way up.
		for foe in get_tree().get_nodes_in_group("mobs"):
			foe.take_hit(99999, foe.global_position + Vector2.LEFT)
		await get_tree().create_timer(0.6).timeout
	if args.has("leave"):
		# Up the stairs, back to the gate.
		world._use_portal({"kind": "gate"})
		await get_tree().create_timer(0.3).timeout
	var motion_report := ""
	if args.has("motion"):
		# `motion` (PIX-135): what the screen shows each rendered frame while
		# the hero walks right: the hero found by its horns' red in the image
		# (a still frame of the walk, so only motion moves it), and the
		# world's scroll from the camera. A hero who steps back on screen
		# while walking forward is the shake that blurred every step.
		world.player.scripted_dir = Vector2.RIGHT
		world.player.sprite.speed_scale = 0.0
		var hero_x: Array[float] = []
		var scroll_x: Array[float] = []
		for i in 45:
			await RenderingServer.frame_post_draw
			var image := get_viewport().get_texture().get_image()
			var sum := 0.0
			var n := 0
			# Only near the hero (the town's grass has red flowers too).
			var around: Vector2 = (get_viewport().get_canvas_transform() * world.player.global_position) * (image.get_width() / get_viewport().get_visible_rect().size.x)
			for y in range(int(around.y) - 90, int(around.y) + 30):
				for x in range(int(around.x) - 50, int(around.x) + 50):
					if DesktopLook.shown(image.get_pixel(x, y), DesktopLook.linear).to_html(false) == "ae0000":
						sum += x
						n += 1
			hero_x.append(sum / maxf(n, 1))
			scroll_x.append(get_viewport().get_canvas_transform().origin.x)
		world.player.scripted_dir = Vector2.ZERO
		var hero_steps: Array = []
		var scroll_steps: Array = []
		for i in range(1, hero_x.size()):
			hero_steps.append(snappedf(hero_x[i] - hero_x[i - 1], 0.1))
			scroll_steps.append(snappedf(scroll_x[i] - scroll_x[i - 1], 0.1))
		var back := hero_steps.filter(func(d: float) -> bool: return d < -0.05).size()
		var frozen := scroll_steps.filter(func(d: float) -> bool: return absf(d) < 0.05).size()
		print("MOTION fps=%d hero_backsteps=%d scroll_frozen=%d hero=%s scroll=%s" % [
			Engine.get_frames_per_second(), back, frozen, str(hero_steps.slice(5, 17)), str(scroll_steps.slice(5, 17))])
		# The release flow reads it off the report line (PIX-135).
		motion_report = " backsteps=%d" % back
	# Terrain review: `--at x,y` stands the hero on a cell (before `--walk`,
	# so a walk can test what stops them), `--zoom Z` changes the camera;
	# `overview` (below) frames the whole map.
	# `--role necromancer`: the hero's role, for how a role wears gear (PIX-175).
	var role_index := args.find("--role")
	if role_index >= 0 and role_index + 1 < args.size():
		GameState.hero.role_id = args[role_index + 1]
		world.player.refresh_rank()
	# `--wear iron_helm,iron_armor`: gear put on the hero (drawn on them, PIX-129).
	var wear_index := args.find("--wear")
	if wear_index >= 0 and wear_index + 1 < args.size():
		for item_id: String in args[wear_index + 1].split(","):
			var piece := InventoryState.create_gear(item_id)
			GameState.pack.gear.append(piece)
			GameState.equip(piece["uid"])
	var at_index := args.find("--at")
	if at_index >= 0 and at_index + 1 < args.size():
		var at := args[at_index + 1].split(",")
		world.player_cell = Vector2i(int(at[0]), int(at[1]))
		world.player.position = world._cell_center(world.player_cell)
		world.camera_rig.cut()
		world.camera_rig.camera.reset_smoothing()
	var zoom_index := args.find("--zoom")
	if zoom_index >= 0 and zoom_index + 1 < args.size():
		world.camera_rig.camera.zoom = Vector2.ONE * float(args[zoom_index + 1])
	var walk_index := args.find("--walk")
	if walk_index >= 0 and walk_index + 1 < args.size():
		var dirs := {
			"l": Vector2i.LEFT, "r": Vector2i.RIGHT, "u": Vector2i.UP, "d": Vector2i.DOWN,
		}
		for move in args[walk_index + 1].split(","):
			world.player.scripted_dir = Vector2(dirs[move])
			await get_tree().create_timer(0.2).timeout
		world.player.scripted_dir = Vector2.ZERO
	if args.has("night"):
		GameState.world.steps = 0.7 * DayNight.DAY_CYCLE_STEPS
	if args.has("overview"):
		var view := get_viewport().get_visible_rect().size
		var fit := minf(view.x / (world.map.size.x * world.TILE), view.y / (world.map.size.y * world.TILE))
		world.camera_rig.follows = false
		world.camera_rig.camera.zoom = Vector2(fit, fit)
		world.camera_rig.camera.limit_right = 1 << 20
		world.camera_rig.camera.limit_bottom = 1 << 20
		world.camera_rig.camera.limit_left = -(1 << 20)
		world.camera_rig.camera.limit_top = -(1 << 20)
		world.camera_rig.camera.global_position = Vector2(world.map.size * world.TILE) / 2.0
		world.camera_rig.camera.reset_smoothing()
		await get_tree().create_timer(0.2).timeout
	var settlers_index := args.find("--settlers")
	if settlers_index >= 0 and settlers_index + 1 < args.size():
		# `--settlers iva,wren`: recruits already living in town.
		for short: String in args[settlers_index + 1].split(","):
			GameState.settlement.settlers.append("settler_" + short)
	var cleared_index := args.find("--cleared")
	if cleared_index >= 0 and cleared_index + 1 < args.size():
		# `--cleared N`: floors 1 to N beaten, for the main quest's later chapters.
		var deepest := int(args[cleared_index + 1])
		for level in range(1, deepest + 1):
			if level not in GameState.progression.cleared_levels:
				GameState.progression.cleared_levels.append(level)
		GameState.progression.unlocked_level = maxi(GameState.progression.unlocked_level, mini(deepest + 1, Dungeons.floor_count()))
		# The named monsters those floors post come out to their lairs (PIX-156).
		world.foes.spawn_lairs()
	if args.has("festival"):
		# A festival day (PIX-159): the town comes back with its stalls, its
		# barker and confetti, everyone on the square.
		GameState._start_festival(maxi(1, GameState.town_tier()))
		world.map = world.load_map("town")
		world.enter_map(world.map, world.player_cell)
		await get_tree().create_timer(0.3).timeout
	if args.has("dusk"):
		# Evening (PIX-159): the town's folk on the square.
		GameState.world.steps = 0.5 * DayNight.DAY_CYCLE_STEPS
		world.folk.keep_hours(true)
	if args.has("ringtoss"):
		world.add_child(preload("res://scripts/ring_toss_screen.gd").new())
		await get_tree().create_timer(0.3).timeout
	if args.has("waypoints"):
		# Every waypoint found (Solid Ground): the map's list at its longest.
		for waypoint: Dictionary in Interactables.waypoints():
			var at := Vector2i(int(waypoint["at"]["x"]), int(waypoint["at"]["y"]))
			Discovery.discover_around(GameState.world.discovered, MapData.load_by_id(waypoint["mapId"]), at)
	if args.has("worldmap"):
		# After `--cleared`: the lairs it posts are on the map.
		var screen := preload("res://scripts/map_screen.gd").new()
		screen.world = world
		world.add_child(screen)
		await get_tree().create_timer(0.3).timeout
	var level_index := args.find("--level")
	if level_index >= 0 and level_index + 1 < args.size():
		# A hero of that level: the rank's title, aura and presence.
		GameState.hero.level = int(args[level_index + 1])
		world.player.refresh_rank()
		world._on_hp_changed(GameState.hero.hp, int(GameState.hero.stats["maxHp"]))
	if args.has("rankup"):
		# Enough XP to cross into the next rank: the ascension plays.
		var hero := GameState.hero
		hero.level = (HeroRules.rank_index(hero.level) + 1) * 5 - 1
		hero.xp_to_next = HeroState.xp_to_next_for(hero.level)
		hero.xp = hero.xp_to_next
		GameState._grant_levels()
		await get_tree().create_timer(1.6).timeout
		if args.has("walk-path"):
			world.get_children().filter(func(node: Node) -> bool: return node.has_method("_walk"))[0]._walk()
			await get_tree().create_timer(0.3).timeout
	if args.has("levelup"):
		# A breath short of the next level (PIX-211): the first kill lifts it.
		GameState.hero.xp = GameState.hero.xp_to_next - 1
	var nodes_index := args.find("--nodes")
	if nodes_index >= 0:
		# Skills already learned (PIX-190): `--nodes a,b,c`, then onto the dock.
		for node_id in args[nodes_index + 1].split(","):
			GameState.hero.skill_nodes.append(node_id)
			Skills.place_on_dock(GameState.hero, node_id)
	var path_index := args.find("--path")
	if path_index >= 0:
		# A path already walked: `--path juggernaut,bastion`.
		GameState.hero.path = Array(args[path_index + 1].split(","))
		Skills.place_on_dock(GameState.hero, "path")
	var cast_index := args.find("--cast")
	if cast_index >= 0:
		# A dock key pressed (PIX-190): `--cast 5`, with energy to spare.
		await get_tree().create_timer(0.4).timeout
		GameState.hero.mp = maxi(99, int(GameState.hero.stats["maxMp"]))
		var hurt_before: Array = get_tree().get_nodes_in_group("mobs").map(func(mob: Node) -> int: return int(mob.fighter["hp"]))
		world.player.cast(int(args[cast_index + 1]) - 1)
		await get_tree().create_timer(0.6).timeout
		var hurt_after: Array = get_tree().get_nodes_in_group("mobs").map(func(mob: Node) -> int: return int(mob.fighter["hp"]))
		print("cast %s: foes' hp %s -> %s, %s %d" % [Skills.docked(GameState.hero)[int(args[cast_index + 1]) - 1].get("name", "-"), hurt_before, hurt_after, Skills.resource_label(GameState.hero.role_id), GameState.hero.mp])
	if args.has("stats") or args.has("skills"):
		# Points to spend: a few of each.
		GameState.hero.stat_points = 5
		GameState.hero.skill_points = 3
		var sheet := "stats_screen" if args.has("stats") else "skills_screen"
		world.add_child(load("res://scripts/%s.gd" % sheet).new())
		await get_tree().create_timer(0.3).timeout
	if args.has("splash"):
		# Pair with `title`: the boot splash, once every letter has landed.
		world.get_children().filter(func(node: Node) -> bool: return node.has_method("as_splash"))[0].as_splash()
		await get_tree().create_timer(1.2).timeout
	if args.has("create"):
		# Hero creation over the title, a role picked and a name typed.
		var creation := preload("res://scripts/create_screen.gd").new()
		creation.world = world
		creation.role_index = 4
		creation.look = 1
		world.add_child(creation)
		await get_tree().create_timer(0.1).timeout
		creation.name_field.text = "Robin"
		creation._refresh()
		await get_tree().create_timer(0.4).timeout
	if args.has("title") and not args.has("talk"):
		# `title --keys s,s,s`: walk the title's menu.
		await _keys(args)
	if args.has("title") and args.has("whatsnew"):
		# What's new over the title, as the version line opens it.
		world.get_children().filter(func(node: Node) -> bool: return node.has_method("as_splash"))[0]._whats_new()
		await get_tree().create_timer(0.3).timeout
	if args.has("title") and args.has("options"):
		# Options over the title, before any hero is made.
		world.get_children().filter(func(node: Node) -> bool: return node.has_method("as_splash"))[0]._options()
		await get_tree().create_timer(0.3).timeout
	elif args.has("pause") or args.has("options"):
		if args.has("scanlines"):
			GameState.settings.scanlines = true
			world.apply_video()
		var pause := preload("res://scripts/pause_screen.gd").new()
		pause.world = world
		world.add_child(pause)
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
		world._open_inventory()
		# `--tab N` opens another tab (7 is Craft).
		var inv_tab := args.find("--tab")
		if inv_tab >= 0 and inv_tab + 1 < args.size():
			world.get_children().filter(func(node: Node) -> bool: return node.has_method("_craft_rows"))[-1]._switch(int(args[inv_tab + 1]))
		await get_tree().create_timer(0.3).timeout
	if args.has("codex"):
		# A record to read: twelve beasts (Slayer I) and a few undead.
		GameState.hero.mastery = {"beasts": 12, "undead": 3}
		var codex := preload("res://scripts/codex_screen.gd").new()
		codex.tab = 1 if args.has("bestiary") else 0
		world.add_child(codex)
		await get_tree().create_timer(0.3).timeout
	if args.has("quest"):
		# A conversation with the elder closes: his quest is accepted.
		GameState.finish_dialogue("elder")
		await get_tree().create_timer(0.3).timeout
	if args.has("journal"):
		# A few promises in hand: slimes half done, the cheese ready, the troll
		# kept; Maren's relics asked for, the ladle won, the iron still out
		# there (PIX-171). `--tab side|bounties|story` opens that chapter.
		GameState.progression.quests.merge({
			"slime_trouble": {"progress": 2, "done": false},
			"cheese_run": {"progress": 0, "done": false},
			"troll_toll": {"progress": 1, "done": true},
			"maren_relics": {"progress": 0, "done": false},
			"garrick_crew": {"progress": 4, "done": true},
			"garrick_seam": {"progress": 0, "done": false},
			"sela_rum": {"progress": 0, "done": false},
		})
		if "tidecaller" not in GameState.progression.hunted:
			GameState.progression.hunted.append("tidecaller")
		GameState.pack.add_item("cheese_wheel")
		GameState.pack.add_item("tams_ladle")
		var journal := preload("res://scripts/journal_screen.gd").new()
		var tab_index := args.find("--tab")
		if tab_index >= 0 and tab_index + 1 < args.size():
			journal.tab = args[tab_index + 1]
		world.add_child(journal)
		await get_tree().create_timer(0.3).timeout
	if args.has("dockmenu"):
		# The dock's menu of screens, opened as its button would.
		world.dock._toggle_menu()
		await get_tree().create_timer(0.2).timeout
	if args.has("lineup"):
		# Every hero role, villager and monster sheet, walking down then right.
		_lineup()
		await get_tree().create_timer(0.5).timeout
	if args.has("shop"):
		# Pair with `--map town_shop|town_smith|town_alchemist`; `--tab N` picks a tab.
		GameState.pack.gold = 500
		var screen: Node = preload("res://scripts/shop_screen.gd").new()
		world.add_child(screen)
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
		world.add_child(screen)
		await get_tree().create_timer(0.3).timeout
	if args.has("hall") or args.has("bank"):
		GameState.pack.gold = 20000
		# `--own town_shop,town_smith`: deeds held, four days of rent waiting (PIX-178).
		var own_index := args.find("--own")
		if own_index >= 0 and own_index + 1 < args.size():
			for map_id in args[own_index + 1].split(","):
				GameState.settlement.properties.append(map_id)
				GameState.investments()["tills"] = GameState.investments().get("tills", {})
				GameState.investments()["tills"][map_id] = {"gold": 0, "earned": 900, "at": GameState.steps_now() - 480 * 4}
		var ledger := "town_hall_screen" if args.has("hall") else "bank_screen"
		world.add_child(load("res://scripts/%s.gd" % ledger).new())
		await get_tree().create_timer(0.3).timeout
	if args.has("saves"):
		# `--web-save <file>` stands in for a browser's web save (a code or JSON)
		# and opens the first-visit offer.
		var web_index := args.find("--web-save")
		var web_file := args[web_index + 1] if web_index >= 0 and web_index + 1 < args.size() else ""
		var stand_in := WebImport.parse_any(FileAccess.get_file_as_string(web_file)) if web_file != "" else {}
		world._open_saves(stand_in, not stand_in.is_empty())
		await get_tree().create_timer(0.3).timeout
	var ready_index := args.find("--ready")
	if ready_index >= 0:
		# A quest accepted and its goal met (PIX-192): `--ready fenwick_locket`.
		var quest := Quests.by_id(args[ready_index + 1])
		var objective: Dictionary = quest["objective"]
		GameState.progression.quests[quest["id"]] = {"progress": int(objective["count"]), "done": false}
		if objective["kind"] == "deliver":
			GameState.pack.add_item(objective["itemId"], int(objective["count"]))
	var take_index := args.find("--take")
	if take_index >= 0:
		# A quest taken, nothing done yet: `--take gunnar_wagon`.
		GameState.progression.quests[args[take_index + 1]] = {"progress": 0, "done": false}
	var follow_index := args.find("--follow-wagon")
	if follow_index >= 0:
		# The hero walks beside the escort's wagon for that many seconds (PIX-192).
		var until := Time.get_ticks_msec() / 1000.0 + float(args[follow_index + 1])
		while Time.get_ticks_msec() / 1000.0 < until:
			await get_tree().physics_frame
			if world.escort != null and is_instance_valid(world.escort):
				world.player.position = world.escort.position + Vector2(20, 0)
		print("escort: waypoint %d, hp %d" % [world.escort.index, world.escort.hp] if world.escort != null and is_instance_valid(world.escort) else "escort: none")
	var talk_index := args.find("--talk-to")
	if talk_index >= 0:
		# A conversation with one villager by id, wherever they stand.
		world.interaction.talk(Npcs.by_id(args[talk_index + 1], GameState.settlement.settlers))
		await get_tree().create_timer(0.3).timeout
		await _keys(args)
	if args.has("talk") or args.has("near"):
		# Stand below the map's first villager facing up; `talk` also presses E.
		var villager: Node = get_tree().get_first_node_in_group("npcs")
		world.player.position = world._cell_center(villager.cell + Vector2i.DOWN)
		world.camera_rig.cut()
		world.player_cell = villager.cell + Vector2i.DOWN
		world.player.face(Vector2.UP)
		if args.has("talk"):
			world.interaction.interact()
		await get_tree().create_timer(0.3).timeout
		# The way a player leaves it (the report lists what stays open).
		await _keys(args)
	if args.has("chest"):
		# Pair with `--map town`: warp beside the nook chest, face it, open it.
		world.player.position = world._cell_center(Vector2i(79, 4))
		world.camera_rig.cut()
		world.player_cell = Vector2i(79, 4)
		world.player.face(Vector2.RIGHT)
		world.interaction.interact()
		await get_tree().create_timer(0.3).timeout
	var hunted_index := args.find("--hunted")
	if hunted_index >= 0 and hunted_index + 1 < args.size():
		# `--hunted greymaw,cinderjaw`: named monsters already slain (PIX-156).
		for named_id: String in args[hunted_index + 1].split(","):
			GameState.progression.hunted.append(named_id)
	if args.has("reveal"):
		# The town risen (PIX-147): pair with `--map town --town-tier 2`; the
		# lamps' stop, then the age's. With `--hunted`, the first one's
		# homecoming instead (PIX-156).
		if hunted_index >= 0:
			GameState.reveals.assign(["hunt:" + GameState.progression.hunted[0]])
		else:
			GameState.reveals.assign(["project:street_lamps", "age:2"])
		world._play_reveals()
		await get_tree().create_timer(1.4).timeout
	if args.has("ending"):
		# The ending (PIX-150): home to the festival and the tour's first stop;
		# `rest` the ending where Morvax is laid to rest (PIX-157).
		world.play_ending("rest" if args.has("rest") else "destroy")
		await get_tree().create_timer(1.4).timeout
	var seen_index := args.find("--seen")
	if seen_index >= 0 and seen_index + 1 < args.size():
		# `--seen maren_confession`: stories already told this hero.
		for story_id: String in args[seen_index + 1].split(","):
			GameState.mark_seen(story_id)
	if args.has("throne"):
		# Morvax beaten (PIX-157): the choice. Pair with `--cleared 15` and
		# `--seen maren_confession` to have "lay him to rest" open.
		var throne := preload("res://scripts/throne_screen.gd").new()
		throne.on_choice = world.play_ending
		world.add_child(throne)
		await get_tree().create_timer(0.3).timeout
	if args.has("mimic"):
		# Pair with `--map mirefen`: open the mire's mimic chest; `--wait`
		# catches its shudder (under 0.6 s) or the ambush after.
		world.player.position = world._cell_center(Vector2i(42, 13))
		world.camera_rig.cut()
		world.player_cell = Vector2i(42, 13)
		world.player.invulnerable = true
		world.player.face(Vector2.UP)
		world.interaction.interact()
	if args.has("portal"):
		# Walk into the map's nearest doorway from a free side, as a player would.
		var doors: Array = world.map.portals.keys()
		doors.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return a.distance_squared_to(world.player_cell) < b.distance_squared_to(world.player_cell)
		)
		for door: Vector2i in doors:
			var sides := [Vector2i.DOWN, Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT].filter(
				func(side: Vector2i) -> bool:
					return world.map.is_walkable(door + side) and not world.map.portals.has(door + side)
			)
			if sides.is_empty():
				continue
			var side: Vector2i = sides[0]
			world.player.position = world._cell_center(door + side)
			world.camera_rig.cut()
			world.player_cell = door + side
			world.player.scripted_dir = Vector2(-side)
			await get_tree().create_timer(0.4).timeout
			world.player.scripted_dir = Vector2.ZERO
			break
		await get_tree().create_timer(0.3).timeout
	if args.has("die"):
		# A blow no hero survives: the fall, then waking at the inn.
		world.player.take_hit(99999, world.player.global_position + Vector2.LEFT)
		await get_tree().create_timer(1.8).timeout
	if args.has("cast"):
		# A foe two steps away, then the first skill: the strike, the flash, the log.
		world.player.invulnerable = true
		world.foes.spawn_enemy("orc", world.player_cell + Vector2i(2, 0), "ash")
		world.player.face(Vector2.RIGHT)
		await get_tree().create_timer(0.2).timeout
		world.player.cast(0)
		await get_tree().create_timer(0.15).timeout
	if args.has("fight"):
		# `--foe <species>` picks the opponent (default orc); `hurt` lets it bite.
		var foe_index := args.find("--foe")
		var foe: String = args[foe_index + 1] if foe_index >= 0 and foe_index + 1 < args.size() else "orc"
		world.player.invulnerable = not args.has("hurt")
		# `--foe-distance N` stands it N cells off (an elite's opener from range).
		var distance_index := args.find("--foe-distance")
		var foe_distance := int(args[distance_index + 1]) if distance_index >= 0 and distance_index + 1 < args.size() else 2
		# A named monster's id (`--foe greymaw`) brings it out of its lair (PIX-156).
		var opponent: Node
		if not Hunts.named(foe).is_empty():
			opponent = world.foes.spawn_named(foe, world.player_cell + Vector2i(foe_distance, 0))
		else:
			opponent = world.foes.spawn_enemy(foe, world.player_cell + Vector2i(foe_distance, 0), "ash", "", args.has("elite"))
		world.player.face(Vector2.RIGHT)
		if args.has("slay"):
			# Felled outright: what its death pays (a named one's bounty).
			await get_tree().create_timer(0.2).timeout
			opponent.take_hit(99999, opponent.global_position + Vector2.LEFT)
		# `kill` swings until the foe drops (or 12 swings); plain `fight`
		# captures mid-swing.
		var swings := 12 if args.has("kill") else 1
		var kills_before: int = world.foes.kills
		for i in swings:
			world.player.attack()
			if i < swings - 1:
				await get_tree().create_timer(0.45).timeout
			if world.foes.kills > kills_before:
				break
		await get_tree().create_timer(0.4 if args.has("kill") else 0.1).timeout
	else:
		await get_tree().create_timer(0.2).timeout
	# `--keys` at whatever screen the run opened (talk and title press theirs
	# earlier): `inventory --keys esc` checks it closes and lets the world go.
	if not args.has("talk") and not args.has("title"):
		await _keys(args)
	# `--dawn-beat N`: the Night of Ash's dawn (PIX-197) jumped to beat N.
	var beat_index := args.find("--dawn-beat")
	if beat_index >= 0 and beat_index + 1 < args.size():
		for node in world.get_children():
			if node.has_method("jump_to"):
				node.jump_to(int(args[beat_index + 1]))
		await get_tree().create_timer(0.6).timeout
	# `lookbook [perf] [film] [--only NAME] [--out DIR] [--looks a,b]`: the
	# look book (PIX-220), every staged scene saved and on one sheet, in each
	# of the app's looks named (PIX-227); tools/lookbook.sh runs it.
	if args.has("lookbook"):
		var book: Node = preload("res://scripts/lookbook.gd").new()
		book.world = world
		book.with_perf = args.has("perf")
		# `film`, not `motion`: that's the walking-scroll check above, which
		# would stop the hero's animations for the whole book.
		book.with_motion = args.has("film")
		var only_index := args.find("--only")
		if only_index >= 0 and only_index + 1 < args.size():
			book.only = args[only_index + 1]
		book.looks = book.looks_from(args)
		var out_index := args.find("--out")
		if out_index >= 0 and out_index + 1 < args.size():
			book.out_dir = args[out_index + 1]
		world.add_child(book)
		await book.run()
	elif args.has("perf"):
		# `perf`: what this scene's frames cost (PerfProbe, the perf guard).
		print("PERF " + await PerfProbe.sample(world))
	# `--wait S` holds the shot (an entrance still playing: the title's logo).
	var wait_index := args.find("--wait")
	if wait_index >= 0 and wait_index + 1 < args.size():
		await get_tree().create_timer(float(args[wait_index + 1])).timeout
	# `overflow` (Solid Ground): every visible piece of an open screen that
	# runs past the canvas, as OVERFLOW lines; text that grows (French is
	# longer) mustn't push a panel off the screen. Works headless.
	if args.has("overflow"):
		await get_tree().process_frame
		var overflows := Layout.overflows(get_tree().root, Touch.view_size(world))
		for line in overflows:
			print("%s %s" % ["OVERFLOW", line])
		motion_report += " overflow=%d" % overflows.size()
	# A quiet run (--headless: no window, nothing drawn) still reports; only
	# a windowed run has a picture to save.
	if DisplayServer.get_name() == "headless":
		await get_tree().process_frame
	else:
		await RenderingServer.frame_post_draw
		# As the screen shows it (the desktop app's canvas is linear light).
		(await DesktopLook.snapshot(self)).save_png("res://screenshot.png")
	# The menus and conversations still open over the world, by script name.
	var open := world.get_children().filter(func(node: Node) -> bool:
		return node is CanvasLayer and node.get_script() != null and (
			node.get_script().resource_path.ends_with("_screen.gd")
			or node.get_script().resource_path.ends_with("dialogue_box.gd")
		)
	).map(func(node: Node) -> String: return node.get_script().resource_path.get_file().get_basename())
	var mobs := get_tree().get_nodes_in_group("mobs").filter(func(mob: Node) -> bool: return not mob.dying).size()
	print("screenshot saved; map=%s cell=%s hp=%d gold=%d save=%s%s draws=%d paused=%s open=%s night=%d mobs=%d" % [
		world.map.id, world.player_cell, world.player.hp, GameState.pack.gold, GameState.world.map_id, GameState.world.cell,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), get_tree().paused,
		",".join(open) if not open.is_empty() else "none",
		GameState.progression.prologue, mobs,
	] + motion_report)
	# Let the audio server let go of the music before the engine shuts down.
	get_tree().paused = true  # nothing may start a track again
	Sound.stop_all()
	await get_tree().create_timer(0.1).timeout
	get_tree().quit()
