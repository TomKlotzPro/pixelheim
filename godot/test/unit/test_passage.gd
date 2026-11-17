extends GutTest
## One way to change place (PIX-500): world.go comes to a place the way it
## is told (Passage: a door, the dark, a cut, the Reach's hand-over, the
## hero's own map drawn again), and each way does of a door's work only its
## own. Until then every map was entered one way, so a town drawn again
## round the hero (back from the board, a hub grown by the post, Lantern
## Night's stalls) played the door's sound, freed every foe, ended the
## hero's ailments, saved and cut the camera.
## The world here is world.gd itself with its pieces standing in (each
## counts what it is asked) and no map drawn: what `go` asks of them.

## What each way does, written out apart from Passage.DOES so that changing
## one means changing the other on purpose.
const ROWS := {
	Passage.DOOR: "sound foes ailments placed save name arrival news hush",
	Passage.DARK: "sound foes ailments placed save name arrival news fade hush",
	Passage.CUT: "sound foes ailments placed save name arrival news fade",
	Passage.SEAMLESS: "foes save name arrival",
	Passage.REDRAW: "news fade",
}
const HERE := Vector2i(3, 3)
const THERE := Vector2i(7, 5)
## Off its cell's middle: a hero stood somewhere is put on the middle.
const STOOD := Vector2(5, -3)

var _kept := {}
var _saves: Array = []
## The foe, the dressing and the wagon of the world a test stands in.
var _cast := {}


class Hero extends "res://test/bare_hero.gd":
	func face(to: Vector2) -> void:
		facing = to


class SpyRig extends CameraRig:
	var cuts := 0
	var shifted := 0
	## Whether the bounds were last held at once (a cut) or eased.
	var bounds_cut: Array = []

	func _ready() -> void:
		pass

	func cut() -> void:
		cuts += 1

	func set_bounds(_rect: Rect2, _under_dock := false, at_once := true) -> void:
		bounds_cut.append(at_once)

	func shift(_by: Vector2) -> void:
		shifted += 1

	func in_view(_at: Vector2, _margin := 0.0) -> bool:
		return false


class SpyBar extends BossBar:
	var let := 0

	func let_go() -> void:
		let += 1


class SpyHud extends Hud:
	## Each naming: whether it was only noted (quiet).
	var named: Array = []
	var hints: Array = []

	func name_place(_map: MapData, _cell: Vector2i, quiet := false) -> void:
		named.append(quiet)

	func hint(id: String, _values := {}, _key := "") -> void:
		hints.append(id)


class SpySoundscape extends Soundscape:
	var refreshed := 0

	func listen_again() -> void:
		pass

	func refresh() -> void:
		refreshed += 1


class SpyFolk extends Folk:
	var spawned := 0
	var came := 0

	func spawn_for(_data: MapData) -> void:
		spawned += 1

	func keep_hours(_arriving := false) -> void:
		pass

	func come_in(_coming: Callable) -> void:
		came += 1


class SpyFoes extends Foes:
	var made := 0
	var came := 0

	func spawn_for(_data: MapData) -> void:
		made += 1

	func come_in() -> void:
		came += 1

	func spawn_lairs(_unseen := false) -> void:
		pass


class SpyStage extends Stage:
	var arrived := 0
	var shown := 0
	var toured := 0
	var confetti := 0

	func arrive(_next: MapData) -> void:
		arrived += 1

	func festival() -> void:
		confetti += 1

	func play_reveals() -> void:
		shown += 1

	func play_hub_tour() -> void:
		toured += 1


class SpyNight extends Night:
	var arrived := 0

	func arrive(_next: MapData) -> void:
		arrived += 1


class SpyDelve extends Delve:
	var arrived := 0

	func arrive(_map: MapData) -> void:
		arrived += 1


class SpyNeighbours extends Neighbours:
	var forgot := 0
	var handed := 0

	func forget() -> void:
		forgot += 1

	func handed_over(_beside: Dictionary, _left: MapData, _left_view: MapView) -> void:
		handed += 1

	func saves_now() -> bool:
		return true

	func origin() -> Vector2i:
		return Vector2i.ZERO


class SpyLoot extends LootPop:
	func settle() -> void:
		pass


## The wagon the hero sees home, never set on its road.
class Wagon extends Escort:
	func _ready() -> void:
		pass

	func _physics_process(_delta: float) -> void:
		pass


class Air extends Atmosphere:
	func carry_on() -> void:
		pass


## world.gd with nothing of the world built, and no map drawn: `_draw_map` only
## notes the drawing and may say the hero's cell was built over.
class ModeWorld extends "res://scripts/world.gd":
	var log: Array = []
	var built_over := Ways.NOWHERE

	func _ready() -> void:
		pass

	func _process(_delta: float) -> void:
		pass

	func _unhandled_input(_event: InputEvent) -> void:
		pass

	func _draw_map(next: MapData, arrival: Vector2i) -> Vector2i:
		log.append("draw")
		view = MapView.new(next, actors)
		return built_over if built_over != Ways.NOWHERE else arrival


func before_each() -> void:
	# A hero of the test's own, the Night of Ash behind them, saved nowhere.
	for section: String in ["hero", "pack", "settlement", "progression", "world", "slot", "dirty"]:
		_kept[section] = GameState.get(section)
	var lent: Node = autofree(preload("res://scripts/state/game_state.gd").new())
	lent.new_game("Robin", "warrior")
	for section: String in ["hero", "pack", "settlement", "progression", "world"]:
		GameState.set(section, lent.get(section))
	GameState.slot = GameState.NO_SLOT
	GameState.progression.prologue = Prologue.DONE
	_kept["reduce_motion"] = GameState.settings.reduce_motion
	GameState.settings.reduce_motion = false
	_kept["web"] = Sound.hushes_builds
	_saves.clear()
	GameState.saved.connect(_saved)


func after_each() -> void:
	GameState.saved.disconnect(_saved)
	Sound.hushes_builds = _kept["web"]
	Sound.hushed = 0.0
	Sound._hush_left = 0.0
	Sound.apply_volumes()
	GameState.settings.reduce_motion = _kept["reduce_motion"]
	for section: String in ["hero", "pack", "settlement", "progression", "world", "slot", "dirty"]:
		GameState.set(section, _kept[section])


func _saved(how: int) -> void:
	_saves.append(how)


func _map(id: String) -> MapData:
	var data := MapData.new()
	data.id = id
	data.size = Vector2i(20, 20)
	return data


## A world on the Reach's first map with a map drawn already, a poisoned
## hero off their cell's middle at HERE, a foe hunting them, something of
## the map's dressing, and the wagon they are seeing home.
func _world() -> ModeWorld:
	# Freed by the test as it ends: two worlds at once would share the groups.
	var world := ModeWorld.new()
	add_child(world)
	world.actors = Node2D.new()
	world.add_child(world.actors)
	world.player = Hero.new()
	world.actors.add_child(world.player)
	world.player.position = MapView.center(HERE) + STOOD
	world.player.ailments.effects.append({"kind": "poison"})
	world.player_cell = HERE
	world.hud = autofree(SpyHud.new())
	world.hud.root = CanvasLayer.new()
	world.add_child(world.hud.root)
	world.hud.boss_bar = autofree(SpyBar.new())
	world.camera_rig = autofree(SpyRig.new())
	world.soundscape = autofree(SpySoundscape.new())
	world.folk = autofree(SpyFolk.new())
	world.foes = autofree(SpyFoes.new())
	world.foes.hunted_at = 5.0
	world.stage = autofree(SpyStage.new())
	world.night = autofree(SpyNight.new())
	world.delve = autofree(SpyDelve.new())
	world.neighbours = autofree(SpyNeighbours.new())
	world.fx = autofree(WorldFx.new())
	world.fx.loot = autofree(SpyLoot.new())
	world.atmosphere = autofree(Air.new())
	world.map = _map("overworld")
	world.view = MapView.new(world.map, world.actors)
	for group: String in ["mobs", "decor", "escort"]:
		var node: Node2D = Wagon.new() if group == "escort" else Node2D.new()
		node.name = group
		node.add_to_group("decor" if group == "escort" else group)
		world.actors.add_child(node)
		_cast[group] = node
	world.stage.escort = _cast["escort"]
	return world


## Whether the world's foe (`mobs`), dressing (`decor`) or wagon (`escort`)
## has gone with the place.
func _gone(who: String) -> bool:
	return not is_instance_valid(_cast[who]) or _cast[who].is_queued_for_deletion()


## The darks a fade runs on (world.gd's _fade_rect) still up over `world`.
func _darks(world: ModeWorld) -> int:
	return world.hud.root.get_children().filter(func(node: Node) -> bool:
		return node.has_meta("fade") and not node.is_queued_for_deletion()).size()


## Comes to `place` at `at` the way `how` says and waits until there (true)
## or dropped (false); `hushed` says whether the music was hushed as it
## was asked.
func _go(world: ModeWorld, place: MapData, at: Vector2i, how: int, turning := Callable()) -> Dictionary:
	Sound._hush_left = 0.0
	Sound._played_at.clear()
	var over: Array = []
	var run := func() -> void: over.append(await world.go(place, at, how, turning))
	run.call()
	var hushed := Sound._hush_left > 0.0
	await wait_until(func() -> bool: return not over.is_empty(), 2.0)
	# What an arrival puts off to the end of its frame (the reveals, a tour).
	await wait_process_frames(2)
	return {"there": over == [true], "hushed": hushed}


## What coming `how` did of a door's work, read off the world's pieces.
func _did(world: ModeWorld, went: Dictionary) -> Array:
	var did := {
		Passage.SOUND: Sound._played_at.has("sfx/door"),
		Passage.FOES: _gone("mobs"),
		Passage.AILMENTS: world.player.ailments.effects.is_empty(),
		Passage.PLACED: world.camera_rig.cuts > 0,
		Passage.SAVE: not _saves.is_empty(),
		Passage.NAME: world.hud.named == [false],
		Passage.ARRIVAL: world.stage.arrived > 0,
		Passage.NEWS: world.stage.shown > 0 and world.stage.toured > 0,
		Passage.FADE: _darks(world) > 0,
		Passage.HUSH: went["hushed"],
	}
	var out: Array = []
	for effect: StringName in Passage.EFFECTS:
		if did[effect]:
			out.append(effect)
	return out


func _row(how: int, web: bool) -> Array:
	var row: Array = []
	for word: String in String(ROWS[how]).split(" "):
		# Only the web has music to hush (Sound.hushes_builds).
		if web or word != "hush":
			row.append(StringName(word))
	return row


func test_the_table_is_the_one_written_here() -> void:
	assert_eq(Passage.DOES.size(), ROWS.size(), "five ways")
	for how: int in ROWS:
		assert_eq(Passage.DOES[how], _row(how, true), Passage.NAMES[how])
		for effect: StringName in Passage.EFFECTS:
			assert_eq(Passage.does(how, effect), effect in _row(how, true), "%s: %s" % [Passage.NAMES[how], effect])
	for row: Array in Passage.DOES.values():
		for effect: StringName in row:
			assert_true(effect in Passage.EFFECTS, "%s is a thing a door does" % effect)


## The table itself: every way, on the desktop and on the web, does what its
## row says and nothing else of it.
func test_each_way_does_its_own_of_a_doors_work() -> void:
	for web: bool in [false, true]:
		for how: int in ROWS:
			var name := "%s%s" % [Passage.NAMES[how], " (web)" if web else ""]
			Sound.hushes_builds = web
			_saves.clear()
			var world := _world()
			var redraw := how == Passage.REDRAW
			var place := _map("overworld" if redraw else "deepwood")
			if how == Passage.SEAMLESS:
				world.neighbours.drawn["deepwood"] = {"data": place, "view": MapView.new(place, world.actors), "offset": Vector2i(20, 0)}
			var at := HERE if redraw else THERE
			var hero_was: Vector2 = world.player.position
			var went: Dictionary = await _go(world, place, at, how)
			if how == Passage.SEAMLESS:
				# Its save follows a moment after the line (SAVE_AFTER_S).
				await wait_seconds(world.SAVE_AFTER_S + 0.1)
			assert_true(went["there"], "%s: there" % name)
			assert_eq(_did(world, went), _row(how, web), "%s does this of a door's work" % name)
			assert_eq(world.map, place, "%s: the hero's map" % name)
			assert_eq(world.player_cell, at, "%s: and cell" % name)
			# What goes with the map as drawn, and who walks it.
			var built := how != Passage.SEAMLESS
			assert_eq(world.log, ["draw"] if built else [], "%s: drawn" % name)
			assert_eq(_gone("decor"), built, "%s: the dressing of a map drawn again goes with it" % name)
			assert_eq(_gone("escort"), not redraw, "%s: the wagon stays only with the map" % name)
			assert_eq(world.folk.spawned, 1 if built else 0, "%s: its folk" % name)
			assert_eq(world.foes.made, 1 if built and not redraw else 0, "%s: its packs" % name)
			assert_eq(world.foes.hunted_at, 5.0 if redraw or not built else -100.0, "%s: the hunt" % name)
			assert_eq(world.hud.boss_bar.let, 1 if built and not redraw else 0, "%s: a boss's bar" % name)
			assert_eq(world.night.arrived + world.delve.arrived, 2 if built and not redraw else 0, "%s: the night's and the floor's arrival" % name)
			assert_eq(world.hud.hints, ["dodge"] if built and not redraw else [], "%s: the dodge taught where packs roam" % name)
			assert_eq(world.neighbours.forgot, 1 if built else 0, "%s: the maps beside" % name)
			if built:
				assert_eq(world.camera_rig.bounds_cut, [not redraw], "%s: the camera's bounds held at once or eased" % name)
			if redraw:
				assert_eq(world.player.position, hero_was, "redraw: the hero where they stood")
				assert_eq(world.hud.named, [true], "redraw: the place only noted")
			elif built:
				assert_eq(world.player.position, MapView.center(at), "%s: the hero on the arrival" % name)
				assert_eq(_saves, [GameState.MOMENT], "%s: a moment kept" % name)
			world.free()


## A map drawn again leaves the hero where they stand; when their cell was
## built over (MapView.plan answers the map's spawn) they are stood there
## and the camera cuts, and it is still no door.
func test_a_redraw_moves_only_a_hero_built_over() -> void:
	Sound.hushes_builds = false
	var world := _world()
	world.built_over = Vector2i(9, 9)
	var went: Dictionary = await _go(world, _map("overworld"), HERE, Passage.REDRAW)
	assert_eq(world.player_cell, Vector2i(9, 9))
	assert_eq(world.player.position, MapView.center(Vector2i(9, 9)), "stood on open ground")
	assert_eq(world.camera_rig.cuts, 1, "the camera cut there")
	assert_eq(_did(world, went), [Passage.PLACED, Passage.NEWS, Passage.FADE], "and nothing else of a door")
	world.free()


## Only the hero's own map is drawn again, and a night sets its scene out as
## the town is come to (its foes, fires and lanterns): a redraw of another
## map, or under the Night of Ash or of Bells, is a cut, as it always was.
func test_a_redraw_under_a_night_or_of_another_map_is_a_cut() -> void:
	Sound.hushes_builds = false
	for case: String in ["ash", "bells", "elsewhere"]:
		_saves.clear()
		GameState.progression.prologue = Prologue.FIRES if case == "ash" else Prologue.DONE
		GameState.progression.bells = Bells.LANTERNS if case == "bells" else Bells.NONE
		var world := _world()
		var went: Dictionary = await _go(world, _map("deepwood" if case == "elsewhere" else "overworld"), HERE, Passage.REDRAW)
		var row := _row(Passage.CUT, false)
		if case == "ash":
			# The dodge and the place's packs wait for the night's end; the
			# rest of an arrival is told.
			assert_eq(world.hud.hints, [])
		assert_eq(_did(world, went), row, case)
		world.free()


## A door asked while a change of place is under way is dropped (false), as
## it was; the place it was going to is never drawn.
func test_a_door_asked_during_a_change_is_dropped() -> void:
	Sound.hushes_builds = true
	var world := _world()
	var first: Array = []
	var run := func() -> void: first.append(await world.go(_map("deepwood"), THERE, Passage.DOOR))
	run.call()
	assert_false(await world.go(_map("town"), THERE, Passage.DOOR), "dropped")
	assert_false(await world.go(_map("town"), THERE, Passage.DARK), "the dark's too")
	await wait_until(func() -> bool: return not first.is_empty(), 2.0)
	assert_eq(first, [true], "the first arrives")
	assert_eq(world.map.id, "deepwood")
	assert_eq(world.log, ["draw"], "one place drawn")
	world.free()


## What a way does to the hero as the place changes (a door turns them to
## face into the new map) runs before the place is drawn, so the save and
## the drawing have them turned.
func test_the_turning_runs_before_the_place_is_drawn() -> void:
	Sound.hushes_builds = false
	for how: int in [Passage.DOOR, Passage.DARK, Passage.CUT]:
		var world := _world()
		var went: Dictionary = await _go(world, _map("deepwood"), THERE, how, func() -> void:
			world.log.append("turn in %s" % world.map.id)
			world.player.face(Vector2.LEFT))
		assert_true(went["there"])
		assert_eq(world.log, ["turn in overworld", "draw"], Passage.NAMES[how])
		assert_eq(GameState.world.facing, WorldState.facing_name(Vector2.LEFT), "saved turned")
		world.free()


## How a door's change looks is told by where it leads: the dark going under
## the ground, a dissolve every other way and every way back up.
func test_a_door_goes_through_the_dark_only_going_under() -> void:
	var town := MapData.load_by_id("town")
	var keep := MapData.load_by_id("keep")
	var cellars := MapData.load_by_id("cellars")
	assert_eq(Passage.through(town, keep), Passage.DOOR, "into a room")
	assert_eq(Passage.through(keep, cellars), Passage.DARK, "down under it")
	assert_eq(Passage.through(cellars, keep), Passage.DOOR, "and back up")
