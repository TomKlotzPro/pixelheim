extends RefCounted
## areas: all
## The harness's steps in the world itself (PIX-357): the hour, the festival,
## the cast's lineup, a chest, a station or a bed used, and the shot held.
##
## Each `step_<name>()` is the step a flag names in scripts/harness_flags.txt
## (`flag | takes | does | step | order`); harness.gd runs the steps of the
## flags it was given in their order, awaiting each.

## The harness (harness.gd): its tree, its key presses and what's open.
var h: Node
var world: Node
var flags: HarnessFlags
## The report line's fields; a value known only part-way through is noted
## as it's known.
var report: HarnessReport


func step_night() -> void:
	# That day's night (`--day`'s, else the first's).
	GameState.world.steps = (Gathering.day_of(GameState.world.steps) + 0.7) * DayNight.DAY_CYCLE_STEPS
	# The night's packs out, as if the hero had just arrived after dark
	# (PIX-252): play swaps them only off the screen (nightfall). The
	# lamps and windows lit for it too (PIX-311), as the world's next
	# second would.
	world.foes.keep_hours(true)
	world.view.set_night(true)


func step_nightfall() -> void:
	# Night falls while the hero looks on (PIX-252): the world's look
	# each second changes only the packs whose homes are off the screen.
	GameState.world.steps = (Gathering.day_of(GameState.world.steps) + 0.7) * DayNight.DAY_CYCLE_STEPS
	await h.get_tree().create_timer(1.5).timeout


func step_festival() -> void:
	# A festival day (PIX-159): the town comes back with its stalls, its
	# barker and confetti, everyone on the square.
	GameState.holdings.start_festival(maxi(1, GameState.town_tier()))
	world.map = world.load_map("town")
	world.enter_map(world.map, world.player_cell)
	await h.get_tree().create_timer(0.3).timeout


func step_dusk() -> void:
	# Evening (PIX-159): the town's folk on the square.
	GameState.world.steps = (Gathering.day_of(GameState.world.steps) + 0.5) * DayNight.DAY_CYCLE_STEPS
	world.folk.keep_hours(true)


func step_lineup() -> void:
	# Every hero role, villager and monster sheet, walking down then right.
	_lineup()
	await h.get_tree().create_timer(0.5).timeout


func step_chest() -> void:
	# Pair with `--map town`: warp beside the nook chest, face it, open it.
	world.player.position = MapView.center(Vector2i(79, 4))
	world.camera_rig.cut()
	world.player_cell = Vector2i(79, 4)
	world.player.face(Vector2.RIGHT)
	world.interaction.interact()
	await h.get_tree().create_timer(0.3).timeout


func step_station() -> void:
	# Pair with `--map town_alchemist` (or town_smith): stand below the
	# room's first station (a cauldron, a forge), face it and press E
	# (PIX-234); the report adds the tab the counter opened on.
	var map: MapData = world.map
	var station := Vector2i(-1, -1)
	for y in map.size.y:
		for x in map.size.x:
			if station.x < 0 and Economy.station_job(map.id, map.tile_at(Vector2i(x, y))) != "":
				station = Vector2i(x, y)
	world.player.position = MapView.center(station + Vector2i.DOWN)
	world.camera_rig.cut()
	world.player_cell = station + Vector2i.DOWN
	world.player.face(Vector2.UP)
	world.interaction.interact()
	await h.get_tree().create_timer(0.3).timeout
	var counters: Array = world.get_children().filter(func(node: Node) -> bool: return node.has_method("_craft_job"))
	report.note("tab", counters[-1].tabs[counters[-1].tab] if not counters.is_empty() else "none")


func step_sleep() -> void:
	# Pair with `--map town_inn` (and `night`): face the room's first bed
	# from a free cell beside it and press E (PIX-246); the report adds
	# the clock the hero woke at.
	var map: MapData = world.map
	var bed := Vector2i(-1, -1)
	var stand := Vector2i(-1, -1)
	for y in map.size.y:
		for x in map.size.x:
			var cell := Vector2i(x, y)
			if bed.x >= 0 or map.tile_at(cell) != "bed":
				continue
			for side: Vector2i in [Vector2i.DOWN, Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP]:
				if stand.x < 0 and map.is_walkable(cell + side):
					bed = cell
					stand = cell + side
	world.player.position = MapView.center(stand)
	world.camera_rig.cut()
	world.player_cell = stand
	world.player.face(Vector2(bed - stand))
	world.interaction.interact()
	await h.get_tree().create_timer(0.3).timeout
	var woke := DayNight.clock(GameState.world.steps)
	report.note("clock", "%02d:%02d" % [woke.x, woke.y])


## `--wait S` holds the shot (an entrance still playing: the title's logo).
func step_wait() -> void:
	await h.get_tree().create_timer(float(flags.value("--wait"))).timeout


## Harness `lineup`: the cast PunyArt assigns, side by side with names.
func _lineup() -> void:
	for node in h.get_tree().get_nodes_in_group("mobs") + h.get_tree().get_nodes_in_group("npcs"):
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
