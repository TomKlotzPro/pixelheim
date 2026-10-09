extends Node
## The look book (PIX-220): the same scenes, staged the same way every time -
## the town by day, at dusk and at night, the forest, the Ash, the Mire, the
## Frostgate, a dungeon floor, a fight and the overworld at night - each saved
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
]
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
		if with_motion:
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
