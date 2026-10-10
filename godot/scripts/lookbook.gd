extends Node
## The look book (PIX-220): the same scenes, staged the same way every time -
## the town by day, at dusk and at night, the forest, the Ash, the Mire, the
## Frostgate, a dungeon floor, a fight, the overworld at night, the
## village seen from its road (PIX-248), the ways between maps (PIX-269),
## the map screen (PIX-266), the rooms behind the Reach's doors with the
## stairs down in their floors (PIX-256) and the card naming a place come
## to - each saved
## as a picture, and all of them on one contact sheet, so a change to how the
## game looks is judged before and after, by eye. With `perf`, each shot also
## reports what its frames cost (PerfProbe); with `film`, each is filmed for
## a moment too, frame by frame, for what a still can't show (the wind, the
## water). With `--looks a,b`, the desktop renderer shoots each scene in each
## of the app's looks (PIX-227, DesktopLook.LOOKS), each look in its own
## folder with its own sheet. A shot that is a moment rather than a place (a
## clip: `rise`, PIX-264) is staged afresh for each look and kept as a strip
## of frames through it, <name>_strip.png; its last frame stands in the
## sheet. Each folder also gets shots.txt, the shots' names in the sheet's
## order, for tools/lookbook_compare.py. Run by tools/lookbook.sh.

## Where in the day a shot stands (DayNight's wheel, 0..1).
const DAY := 0.2
const DUSK := 0.53
const NIGHT := 0.75
## The sheet's areas, in its order (PIX-273): the village and its rooms,
## the Reach around it, the regions beyond, the ways between them,
## underground, a fight, and the game's pages. A shot names its area, and
## the sheet groups them so, in the order SHOTS gives within an area.
const AREAS := ["town", "rooms", "reach", "regions", "ways", "dungeon", "combat", "screens"]
## Each shot by its name (its picture's file, and `--only`'s word: never a
## number, which every branch adding a shot took the same next one of): its
## area; a map and where on it (Upper Street, a pack's home, a cell, or the
## map's arrival), or a dungeon floor; the hour, or the first shower by day
## (`rain`); and a foe to face, for the fight, struck on a beat while it's
## filmed (`strike`), the third blow felling it. Only a shot with `card`
## keeps the title card naming the place it enters (PIX-269). A new shot
## goes with its area's.
const SHOTS := {
	"town_day": {"area": "town", "map": "town", "at": "street", "time": DAY},
	"town_dusk": {"area": "town", "map": "town", "at": "street", "time": DUSK},
	"town_night": {"area": "town", "map": "town", "at": "street", "time": NIGHT},
	"riverside": {"area": "town", "map": "town", "cell": Vector2i(72, 8), "time": DAY},
	# The hero's walk (PIX-243), filmed (`film`) setting off, striding, turning
	# right round and settling, then walking up the street.
	"walk": {"area": "town", "map": "town", "cell": Vector2i(38, 13), "time": DAY, "walk": true},
	# Odo's store rising out of its ruin on the town's tour (PIX-264).
	"rise": {"area": "town", "map": "town", "at": "street", "time": DAY, "rise": "odos_store"},
	"inn_night": {"area": "rooms", "map": "town_inn", "time": NIGHT},
	"smithy_day": {"area": "rooms", "map": "town_smith", "time": DAY},
	# A house opens onto a room, the cave down a stair in its floor (PIX-256):
	# Liane's room and Captain Hale's hall from beside the stairwell, then at
	# its top, the stairs asking.
	"lianes_room": {"area": "rooms", "map": "observatory", "cell": Vector2i(13, 7), "time": DAY},
	"lianes_stair": {"area": "rooms", "map": "observatory", "cell": Vector2i(13, 6), "time": DAY, "down": true},
	"hales_hall": {"area": "rooms", "map": "keep", "cell": Vector2i(13, 7), "time": DAY},
	"hales_stair": {"area": "rooms", "map": "keep", "cell": Vector2i(13, 6), "time": DAY, "down": true},
	"forest": {"area": "reach", "map": "overworld", "at": "forest_2", "time": DAY},
	"ash": {"area": "reach", "map": "overworld", "at": "ash_3", "time": DAY},
	"overworld_night": {"area": "reach", "map": "overworld", "at": "forest_2", "time": NIGHT},
	"rain": {"area": "reach", "map": "overworld", "at": "forest_1", "rain": true},
	# The village seen from outside (PIX-248): up the road to its gate by day
	# and at night, and its lit windows from the road along its west wall.
	"village_road": {"area": "reach", "map": "overworld", "cell": Vector2i(48, 40), "time": DAY},
	"village_gate_night": {"area": "reach", "map": "overworld", "cell": Vector2i(48, 41), "time": NIGHT},
	"village_west_night": {"area": "reach", "map": "overworld", "cell": Vector2i(34, 47), "time": NIGHT},
	"mire": {"area": "regions", "map": "mirefen", "time": DAY},
	"frostgate": {"area": "regions", "map": "frostgate", "time": DAY},
	"coast": {"area": "regions", "map": "saltmere", "cell": Vector2i(33, 27), "time": DAY},
	"deepwood": {"area": "regions", "map": "deepwood", "time": DAY},
	# The ways between maps (PIX-269): the river road running out through
	# the cliffs at the Deepwood pass by day and by night, the Mirefen's way
	# back (high on its east edge since the Reach became one plane), and the
	# road south out through the ridge - bare ground, no post.
	"deepwood_pass": {"area": "ways", "map": "overworld", "cell": Vector2i(91, 33), "time": DAY},
	"deepwood_pass_night": {"area": "ways", "map": "overworld", "cell": Vector2i(91, 33), "time": NIGHT},
	"mire_pass": {"area": "ways", "map": "mirefen", "cell": Vector2i(55, 5), "time": DAY},
	"road_south": {"area": "ways", "map": "overworld", "cell": Vector2i(16, 60), "time": DAY},
	# Come through the pass into the Mirefen: its name on a card, once.
	"place_card": {"area": "ways", "map": "mirefen", "cell": Vector2i(55, 5), "time": DAY, "card": true},
	"dungeon": {"area": "dungeon", "floor": 5, "time": DAY},
	"fight": {"area": "combat", "map": "overworld", "at": "forest_1", "time": DAY, "foe": "orc"},
	"strike": {"area": "combat", "map": "overworld", "at": "forest_1", "time": DAY, "foe": "orc", "strike": true},
	# The map (PIX-266) of a hero who has walked the whole Reach, its list
	# scrolled down to the last waypoint, in Greyhold on the Reach's one page
	# (PIX-269 step 7).
	"map": {"area": "screens", "map": "town", "at": "street", "time": DAY, "chart": "greyhold_keep"},
}
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
## A clip's frames, in seconds after the rise begins: the ruin, giving way
## in dust as the first courses drop, the roof going up, and standing with
## its confetti, its name and what it brings.
const CLIP_MARKS := [0.1, 0.55, 0.95, 2.1]
## Upper Street: the shop's and the inn's fronts, the street lamps, the hall.
const STREET := Vector2i(40, 13)
## The contact sheet: three across, each shot at half size.
const SHEET_COLUMNS := 3
const SETTLE_SECONDS := 1.2
## A stair's shot (`down`, PIX-256): this long facing it before it asks.
const ASK_AFTER := 0.5
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
	if only != "" and not SHOTS.has(only):
		push_error("lookbook: no shot is called %s (%s)" % [only, ", ".join(ordered())])
		return
	var shot_names: PackedStringArray = []
	for shot_name in ordered():
		if only != "" and shot_name != only:
			continue
		shot_names.append(shot_name)
		var shot: Dictionary = SHOTS[shot_name].duplicate()
		shot["name"] = shot_name
		if shot.has("rise"):
			await _clip(shot, folders, images)
			continue
		_stage(shot)
		if shot.get("down", false):
			await get_tree().create_timer(ASK_AFTER).timeout
			world.interaction.ask_down(world.player_cell + Vector2i.UP)
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
		# A screen a shot opened goes, so the next finds the world its own.
		for node in world.get_children():
			if node is Screen:
				(node as Screen).close()
	for look: String in folders:
		sheet(images[look]).save_png("%s/sheet.png" % folders[look])
		FileAccess.open("%s/shots.txt" % folders[look], FileAccess.WRITE).store_string("\n".join(shot_names) + "\n")
		print("%s %s/%s" % ["LOOK", ProjectSettings.globalize_path(folders[look]), "sheet.png"])


## Every shot's name in the sheet's order: by area, as AREAS lists them, and
## in SHOTS' order within an area.
static func ordered() -> PackedStringArray:
	var out: PackedStringArray = []
	for area: String in AREAS:
		for shot_name: String in SHOTS:
			if SHOTS[shot_name]["area"] == area:
				out.append(shot_name)
	return out


## Puts the hero where the shot stands, at its hour, with its foe - the last
## shot's words cleared away.
func _stage(shot: Dictionary) -> void:
	world.messages.clear()
	world.hud.forget_places()
	GameState.world.steps = shower_by_day() if shot.get("rain", false) else float(shot["time"]) * DayNight.DAY_CYCLE_STEPS
	if shot.has("floor"):
		world.delve.enter_floor(int(shot["floor"]))
	else:
		world.map = world.load_map(shot["map"])
		var at: Vector2i = nearest_walkable(world.map, shot["cell"]) if shot.has("cell") else _cell(world.map, String(shot.get("at", "")))
		world.enter_map(world.map, at)
	# The card naming the place stands over its own shot only.
	if not shot.get("card", false):
		world.hud.forget_places()
	world.folk.keep_hours(true)
	world.lights.time = CLOCK
	if shot.has("foe"):
		var foe: Node = world.foes.spawn_enemy(shot["foe"], world.player_cell + Vector2i(2, 0), "", "", true, false)
		world.player.face(Vector2.RIGHT)
		foe.notice()
		_foe = foe
	if shot.get("down", false):
		# At the top of a room's stair, facing it (PIX-256): the stairs ask
		# once the world has drawn the hero turned (run).
		world.player.face(Vector2.UP)
	if shot.has("chart"):
		# The map over a hero who has walked it all, a waypoint chosen.
		Atlas.walk_all(GameState.world.discovered)
		world.open_screen("map")
		for node in world.get_children():
			if node.has_method("show_waypoint"):
				node.show_waypoint(shot["chart"])


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


## A building rising on the town's tour (PIX-264), in each look: the town
## staged, back from the board with the shot's project built, the tour on
## its way; then CLIP_MARKS' frames from the moment it rises, side by side.
## The tour is closed after, so the next shot finds the world its own.
func _clip(shot: Dictionary, folders: Dictionary, images: Dictionary) -> void:
	for look: String in folders:
		if look != "":
			world.lights.wear(look)
		_stage(shot)
		GameState.reveals.assign(["project:" + String(shot["rise"])])
		world.stage.after_board()
		var rise: RebuildRise = null
		for frame in 600:
			rise = get_tree().get_first_node_in_group(RebuildRise.GROUP) as RebuildRise
			if rise != null and rise.phase != "ruin":
				break
			await drawn()
		var began := GameClock.msec()
		var frames: Array[Image] = []
		for mark: float in CLIP_MARKS:
			var left := mark - (GameClock.msec() - began) / 1000.0
			if left > 0.0:
				await get_tree().create_timer(left).timeout
			await drawn()
			frames.append(await DesktopLook.snapshot(self))
		strip(frames).save_png("%s/%s_strip.png" % [folders[look], shot["name"]])
		frames[-1].save_png("%s/%s.png" % [folders[look], shot["name"]])
		images[look].append(frames[-1])
		for node in world.get_children():
			if node is Screen:
				(node as Screen).close()
		print("%s %s" % ["LOOK", shot["name"]])


## A clip's frames side by side at half size.
static func strip(frames: Array[Image]) -> Image:
	var cell := Vector2i(frames[0].get_width() / 2, frames[0].get_height() / 2)
	var out := Image.create(cell.x * frames.size(), cell.y, false, Image.FORMAT_RGBA8)
	for index in frames.size():
		var small := frames[index].duplicate()
		small.convert(Image.FORMAT_RGBA8)
		small.resize(cell.x, cell.y, Image.INTERPOLATE_BILINEAR)
		out.blit_rect(small, Rect2i(Vector2i.ZERO, cell), Vector2i(index * cell.x, 0))
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
