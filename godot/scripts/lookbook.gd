extends Node
## The look book (PIX-220): the same scenes, staged the same way every time -
## the town by day, at dusk and at night, the forest, the Ash, the Mire, the
## Frostgate, a dungeon floor, a fight, the overworld at night and the
## village seen from its road (PIX-248) - each saved
## as a picture, and all of them on one contact sheet, so a change to how the
## game looks is judged before and after, by eye. With `perf`, each shot also
## reports what its frames cost (PerfProbe); with `film`, each is filmed for
## a moment too, frame by frame, for what a still can't show (the wind, the
## water). With `--looks a,b`, the desktop renderer shoots each scene in each
## of the app's looks (PIX-227, DesktopLook.LOOKS), each look in its own
## folder with its own sheet. Run by tools/lookbook.sh.

## Where in the day a shot stands (DayNight's wheel, 0..1).
const DAY := 0.2
const DUSK := 0.53
const NIGHT := 0.75
## Each shot: a map and where on it (Upper Street, a pack's home, a cell, or
## the map's arrival), or a dungeon floor; the hour, or the first shower by
## day (`rain`); and a foe to face, for the fight, struck on a beat while
## it's filmed (`strike`), the third blow felling it.
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
	{"name": "14_rain", "map": "overworld", "at": "forest_1", "rain": true},
	{"name": "15_coast", "map": "saltmere", "cell": Vector2i(33, 27), "time": DAY},
	{"name": "16_deepwood", "map": "deepwood", "time": DAY},
	{"name": "17_strike", "map": "overworld", "at": "forest_1", "time": DAY, "foe": "orc", "strike": true},
	# The village seen from outside (PIX-248): up the road to its gate by day
	# and at night, and its lit windows from the road along its west wall.
	{"name": "18_village_road", "map": "overworld", "cell": Vector2i(48, 40), "time": DAY},
	{"name": "19_village_gate_night", "map": "overworld", "cell": Vector2i(48, 41), "time": NIGHT},
	{"name": "20_village_west_night", "map": "overworld", "cell": Vector2i(34, 47), "time": NIGHT},
	# The hero's walk (PIX-243), filmed (`film`) setting off, striding, turning
	# right round and settling, then walking up the street.
	{"name": "21_walk", "map": "town", "cell": Vector2i(38, 13), "time": DAY, "walk": true},
]
## Filming the walk: slowed to a quarter, a picture every WALK_STEP of the
## game's time (thirty a second: two or three of each frame of the walk),
## cropped round the hero this far (art px) each way; the legs of the clip
## as [heading, pictures].
const WALK_SLOW := 0.25
const WALK_STEP := 1.0 / 30.0
const WALK_CROP := Vector2(22, 26)
const WALK_LEGS := [[Vector2.ZERO, 3], [Vector2.RIGHT, 20], [Vector2.LEFT, 12], [Vector2.ZERO, 9], [Vector2.UP, 12], [Vector2.ZERO, 9]]
## The strip of crops: this many across.
const STRIP_COLUMNS := 11
## Upper Street: the shop's and the inn's fronts, the street lamps, the hall.
const STREET := Vector2i(40, 13)
## The contact sheet: three across, each shot at half size.
const SHEET_COLUMNS := 3
const SETTLE_SECONDS := 1.2
## Filming (`film`): this many frames, this far apart, into
## <out>/motion/<shot>/NN.png.
const MOTION_FRAMES := 24
const MOTION_STEP := 0.1
## The world's clock at each shot, so the clouds and the wind stand the same
## way every time.
const CLOCK := 40.0
## Frames drawn after a look is put on, before its shot: the canvas is remade
## and the glow's levels filled.
const LOOK_FRAMES := 4

var world: Node
var out_dir := "res://lookbook"
var with_perf := false
var with_motion := false
## Only the shot of this name ("" for all), to look at one quickly.
var only := ""
## The shot's foe, to strike while filming.
var _foe: Node
## Filming a strike: the frames the hero swings on (the second a crit, the
## last one felling it), and what each blow takes.
const STRIKES := [2, 8, 14]
const STAGED_BLOW := 12
## The looks to shoot each scene in (`--looks`); none: the look worn.
var looks: PackedStringArray = []


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
	# Each look's folder ("" is the look worn, straight into out_dir) and its
	# shots so far.
	var folders := {}
	var images := {}
	for look in (looks if not looks.is_empty() else PackedStringArray([""])):
		folders[look] = out_dir if look == "" else "%s/%s" % [out_dir, look]
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folders[look]))
		var shots: Array[Image] = []
		images[look] = shots
	# Developer output, not the player's: no words for the translators.
	print("%s %s=%s" % ["LOOK", "look", DesktopLook.look])
	for shot: Dictionary in SHOTS:
		if only != "" and shot["name"] != only:
			continue
		_stage(shot)
		await get_tree().create_timer(SETTLE_SECONDS).timeout
		await drawn()
		for look: String in folders:
			if look != "":
				world.lights.wear(look)
				for frame in LOOK_FRAMES:
					await drawn()
			var image: Image = await DesktopLook.snapshot(self)
			image.save_png("%s/%s.png" % [folders[look], shot["name"]])
			images[look].append(image)
		var line := "%s %s" % ["LOOK", shot["name"]]
		if with_perf:
			line += "  " + await PerfProbe.sample(self, 180)
		print(line)
		if with_motion and shot.get("walk", false):
			await _film_walk(shot["name"])
		elif with_motion:
			await _film(shot["name"], shot.get("strike", false))
	for look: String in folders:
		sheet(images[look]).save_png("%s/sheet.png" % folders[look])
		print("%s %s/%s" % ["LOOK", ProjectSettings.globalize_path(folders[look]), "sheet.png"])


## Puts the hero where the shot stands, at its hour, with its foe - the last
## shot's words cleared away.
func _stage(shot: Dictionary) -> void:
	world.messages.clear()
	GameState.world.steps = shower_by_day() if shot.get("rain", false) else float(shot["time"]) * DayNight.DAY_CYCLE_STEPS
	if shot.has("floor"):
		world.delve.enter_floor(int(shot["floor"]))
	else:
		world.map = world.load_map(shot["map"])
		var at: Vector2i = nearest_walkable(world.map, shot["cell"]) if shot.has("cell") else _cell(world.map, String(shot.get("at", "")))
		world.enter_map(world.map, at)
	world.folk.keep_hours(true)
	world.lights.time = CLOCK
	if shot.has("foe"):
		var foe: Node = world.foes.spawn_enemy(shot["foe"], world.player_cell + Vector2i(2, 0), "", "", true, false)
		world.player.face(Vector2.RIGHT)
		foe.notice()
		_foe = foe


## Waits for a frame drawn and ready to save. While the window is hidden
## (another app full screen over it) the engine draws nothing of its own
## accord and a run would wait forever, so the look book draws the frame
## itself.
func drawn() -> void:
	await DesktopLook.drawn(self)


## The shot as it moves: MOTION_FRAMES frames, MOTION_STEP seconds apart;
## with `strike`, the hero swings at the foe on STRIKES' frames.
func _film(shot_name: String, strike := false) -> void:
	var folder := "%s/motion/%s" % [out_dir, shot_name]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	for frame in MOTION_FRAMES:
		if strike and frame in STRIKES and is_instance_valid(_foe):
			world.player.face(_foe.global_position - world.player.global_position)
			if frame == STRIKES[-1]:
				_foe.fighter["hp"] = 1
			world.player.attack_ready = true
			world.player.attack()
			# Staged: the blow lands on the beat, wherever the foe has stepped.
			_foe.take_hit(STAGED_BLOW, world.player.global_position, null, frame == STRIKES[1])
		await get_tree().create_timer(MOTION_STEP).timeout
		await drawn()
		(await DesktopLook.snapshot(self)).save_png("%s/%02d.png" % [folder, frame])


## The hero's walk (PIX-243), slowed to WALK_SLOW: standing, setting off to
## the right, a stride, turning right round, settling, then up the street
## and settling again (the back's four beats). Every picture is cropped round
## the hero into <out>/motion/<shot>/NN.png, and all of them, in order and
## STRIP_COLUMNS across, into walk_strip.png beside them.
func _film_walk(shot_name: String) -> void:
	var folder := "%s/motion/%s" % [out_dir, shot_name]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var crops: Array[Image] = []
	Engine.time_scale = WALK_SLOW
	for leg: Array in WALK_LEGS:
		world.player.scripted_dir = leg[0]
		for picture in int(leg[1]):
			# The game's time, not drawn frames: a window drawing faster than
			# the clock would film the same tick over and over.
			await get_tree().create_timer(WALK_STEP).timeout
			await drawn()
			crops.append(_around_hero(await DesktopLook.snapshot(self)))
	world.player.scripted_dir = Vector2.ZERO
	Engine.time_scale = 1.0
	for index in crops.size():
		crops[index].save_png("%s/%02d.png" % [folder, index])
	_strip(crops).save_png("%s/walk_strip.png" % folder)
	print("%s %s" % ["LOOK", ProjectSettings.globalize_path("%s/walk_strip.png" % folder)])


## The part of `image` round the hero, WALK_CROP art px each way (a little
## more above, for the head).
func _around_hero(image: Image) -> Image:
	var view := get_viewport()
	var shown := image.get_width() / view.get_visible_rect().size.x
	var canvas := view.get_canvas_transform()
	var at: Vector2 = canvas * world.player.global_position * shown
	var half := WALK_CROP * canvas.get_scale().x * shown
	var box := Rect2i(Vector2i(at - Vector2(half.x, half.y * 1.25)), Vector2i(half * 2.0))
	box = box.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	var crop := image.get_region(box)
	crop.convert(Image.FORMAT_RGBA8)
	return crop


## The crops in order, STRIP_COLUMNS across, a dark line between them.
static func _strip(crops: Array[Image]) -> Image:
	var cell := crops[0].get_size() + Vector2i(2, 2)
	var rows := ceili(crops.size() / float(STRIP_COLUMNS))
	var out := Image.create(cell.x * STRIP_COLUMNS, cell.y * rows, false, Image.FORMAT_RGBA8)
	out.fill(Color(0.07, 0.05, 0.04))
	for index in crops.size():
		var size := crops[index].get_size().min(cell - Vector2i(2, 2))
		out.blit_rect(crops[index], Rect2i(Vector2i.ZERO, size), Vector2i(index % STRIP_COLUMNS * cell.x + 1, index / STRIP_COLUMNS * cell.y + 1))
	return out


## The looks `--looks a,b` names, those the app has (DesktopLook.LOOKS), in
## its order.
static func looks_from(flags: HarnessFlags) -> PackedStringArray:
	var out: PackedStringArray = []
	for look in flags.list("--looks"):
		if DesktopLook.LOOKS.has(look) and not out.has(look):
			out.append(look)
	return out


## The heart of the first shower that falls in full day (Weather).
static func shower_by_day() -> float:
	var steps := 0.0
	for tries in 40:
		steps = Weather.next_shower(steps)
		var hour := fposmod(steps, float(DayNight.DAY_CYCLE_STEPS)) / DayNight.DAY_CYCLE_STEPS
		if hour > 0.05 and hour < 0.42:
			return steps
		steps += DayNight.DAY_CYCLE_STEPS / 2.0
	return steps


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
