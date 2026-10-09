extends Node
## The look book (PIX-220): the same scenes, staged the same way every time -
## the town by day, at dusk and at night, the forest, the Ash, the Mire, the
## Frostgate, a dungeon floor, a fight and the overworld at night - each saved
## as a picture, and all of them on one contact sheet, so a change to how the
## game looks is judged before and after, by eye. With `perf`, each shot also
## reports what its frames cost (PerfProbe); with `motion`, each is filmed for
## a moment too, frame by frame, for what a still can't show (the wind, the
## water). Run by tools/lookbook.sh.

## Where in the day a shot stands (DayNight's wheel, 0..1).
const DAY := 0.2
const DUSK := 0.53
const NIGHT := 0.75
## Each shot: a map and where on it (Upper Street, a pack's home, a cell, or
## the map's arrival), or a dungeon floor; the hour; and a foe to face, for
## the fight.
const SHOTS := [
	{"name": "01_town_day", "map": "town", "at": "street", "time": DAY},
	{"name": "02_town_dusk", "map": "town", "at": "street", "time": DUSK},
	{"name": "03_town_night", "map": "town", "at": "street", "time": NIGHT},
	{"name": "04_forest", "map": "overworld", "at": "forest_2", "time": DAY},
	{"name": "05_ash", "map": "overworld", "at": "ash_3", "time": DAY},
	{"name": "06_mire", "map": "mirefen", "time": DAY},
	{"name": "07_frostgate", "map": "frostgate", "time": DAY},
	{"name": "08_dungeon", "floor": 5, "time": DAY},
	{"name": "09_fight", "map": "overworld", "at": "forest_1", "time": DAY, "foe": "orc"},
	{"name": "10_overworld_night", "map": "overworld", "at": "forest_2", "time": NIGHT},
	{"name": "11_inn_night", "map": "town_inn", "time": NIGHT},
	{"name": "12_smithy_day", "map": "town_smith", "time": DAY},
	{"name": "13_riverside", "map": "town", "cell": Vector2i(72, 8), "time": DAY},
]
## Upper Street: the shop's and the inn's fronts, the street lamps, the hall.
const STREET := Vector2i(40, 13)
## The contact sheet: three across, each shot at half size.
const SHEET_COLUMNS := 3
const SETTLE_SECONDS := 1.2
## Filming (`motion`): this many frames, this far apart, into
## <out>/motion/<shot>/NN.png.
const MOTION_FRAMES := 24
const MOTION_STEP := 0.1
## The world's clock at each shot, so the clouds and the wind stand the same
## way every time.
const CLOCK := 40.0

var world: Node
var out_dir := "res://lookbook"
var with_perf := false
var with_motion := false


func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	# Pictures to look at, not the game's: Godot leaves the folder alone.
	FileAccess.open("%s/.gdignore" % out_dir, FileAccess.WRITE)
	# The same picture every time: no first-time hints over the scene, and a
	# hero no foe can fell while a shot is taken or its frames are timed.
	GameState.settings.hints = false
	world.player.invulnerable = true
	# The town at its fullest: every age built, its lamps and roofs up.
	GameState.settlement.town_tier = Town.MAX_TIER
	GameState.settlement.projects.assign(Town.projects_through(Town.MAX_TIER))
	var images: Array[Image] = []
	for shot: Dictionary in SHOTS:
		_stage(shot)
		await get_tree().create_timer(SETTLE_SECONDS).timeout
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		image.save_png("%s/%s.png" % [out_dir, shot["name"]])
		images.append(image)
		# Developer output, not the player's: no words for the translators.
		var line := "%s %s" % ["LOOK", shot["name"]]
		if with_perf:
			line += "  " + await PerfProbe.sample(self, 180)
		print(line)
		if with_motion:
			await _film(shot["name"])
	sheet(images).save_png("%s/sheet.png" % out_dir)
	print("%s %s/%s" % ["LOOK", ProjectSettings.globalize_path(out_dir), "sheet.png"])


## Puts the hero where the shot stands, at its hour, with its foe - the last
## shot's words cleared away.
func _stage(shot: Dictionary) -> void:
	for line in world.log_box.get_children():
		line.queue_free()
	world._messages.clear()
	world._message_now = ""
	world.message_box.modulate.a = 0.0
	GameState.world.steps = float(shot["time"]) * DayNight.DAY_CYCLE_STEPS
	if shot.has("floor"):
		world.enter_floor(int(shot["floor"]))
	else:
		world.map = world._load_map(shot["map"])
		var at: Vector2i = nearest_walkable(world.map, shot["cell"]) if shot.has("cell") else _cell(world.map, String(shot.get("at", "")))
		world._enter_map(world.map, at)
	world._keep_hours(true)
	world.lights.time = CLOCK
	if shot.has("foe"):
		var foe: Node = world.spawn_enemy(shot["foe"], world.player_cell + Vector2i(2, 0), "", "", true, false)
		world.player.face(Vector2.RIGHT)
		foe.notice()


## The shot as it moves: MOTION_FRAMES frames, MOTION_STEP seconds apart.
func _film(shot_name: String) -> void:
	var folder := "%s/motion/%s" % [out_dir, shot_name]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	for frame in MOTION_FRAMES:
		await get_tree().create_timer(MOTION_STEP).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%02d.png" % [folder, frame])


## Where on the map: the square, beside a pack's home, or the arrival.
func _cell(map: MapData, at: String) -> Vector2i:
	var want := map.spawn
	if at == "street":
		want = STREET
	elif at != "":
		for spawn: Dictionary in Bestiary.spawns_on(map.id):
			if spawn["id"] == at:
				want = Vector2i(int(spawn["x"]), int(spawn["y"])) + Vector2i(0, 3)
	return nearest_walkable(map, want)


## The closest cell to `want` the hero can stand on (outward in rings).
static func nearest_walkable(map: MapData, want: Vector2i) -> Vector2i:
	for reach in 12:
		for dy in range(-reach, reach + 1):
			for dx in range(-reach, reach + 1):
				var cell := want + Vector2i(dx, dy)
				if maxi(absi(dx), absi(dy)) == reach and map.is_walkable(cell):
					return cell
	return map.spawn


## Every shot at half size, SHEET_COLUMNS across, in order.
static func sheet(images: Array[Image]) -> Image:
	var cell := Vector2i(images[0].get_width() / 2, images[0].get_height() / 2)
	var rows := ceili(images.size() / float(SHEET_COLUMNS))
	var out := Image.create(cell.x * SHEET_COLUMNS, cell.y * rows, false, Image.FORMAT_RGBA8)
	out.fill(Color(0.07, 0.05, 0.04))
	for index in images.size():
		var small := images[index].duplicate()
		small.convert(Image.FORMAT_RGBA8)
		small.resize(cell.x, cell.y, Image.INTERPOLATE_BILINEAR)
		out.blit_rect(small, Rect2i(Vector2i.ZERO, cell), Vector2i(index % SHEET_COLUMNS * cell.x, index / SHEET_COLUMNS * cell.y))
	return out
