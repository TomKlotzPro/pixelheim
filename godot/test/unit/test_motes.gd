extends GutTest
## The small life of the world (PIX-225): fireflies by the hour and the
## place, what the hero's feet kick up, which foes throw sparks, what glows
## in the dark and what takes the scene's light, and the perf guard's count.


var _bells := 0


func before_each() -> void:
	_bells = GameState.progression.bells


func after_each() -> void:
	GameState.progression.prologue = Prologue.DONE
	GameState.progression.bells = _bells


## The steps at `hour`:`minute` of the first day (a day runs from six).
static func _hour(hour: int, minute := 0) -> float:
	return fposmod(float(hour * 60 + minute - DayNight.MORNING_MINUTE), float(DayNight.DAY_CYCLE_STEPS))


func test_mist_lies_at_dawn_over_the_river_and_the_grass() -> void:
	# PIX-526: dawn pale gold, mist over the river and the grass.
	var overworld := MapData.load_by_id("overworld")
	assert_eq(Motes.mist(overworld, "", _hour(5, 30), 0.0), 1.0, "thick at half past five")
	assert_between(Motes.mist(overworld, "", _hour(6, 30), 0.0), 0.5, 0.99, "thinning by half past six")
	for hour: int in [4, 12, 23]:
		assert_eq(Motes.mist(overworld, "", _hour(hour), 0.0), 0.0, "none at %d" % hour)
	assert_eq(Motes.mist(overworld, "", _hour(19, 30), 0.0), 0.0, "none at dusk")
	assert_eq(Motes.mist(overworld, "", _hour(5, 30), 1.0), 0.0, "none in the rain")
	for air: String in Motes.NO_MIST:
		assert_eq(Motes.mist(overworld, air, _hour(5, 30), 0.0), 0.0, "none in the %s air" % air)
	assert_eq(Motes.mist(MapData.load_by_id("town_inn"), "", _hour(5, 30), 0.0), 0.0, "none indoors")
	var town := MapData.load_by_id("town")
	GameState.progression.bells = Bells.NONE
	assert_eq(Motes.mist(town, "", _hour(5, 30), 0.0), 1.0, "over the village's river")
	GameState.progression.prologue = Prologue.SCAVENGER
	assert_eq(Motes.mist(town, "", _hour(5, 30), 0.0), 0.0, "not the night it burns")
	GameState.progression.prologue = Prologue.DONE
	GameState.progression.bells = Bells.HOLD
	assert_eq(Motes.mist(town, "", _hour(5, 30), 0.0), 0.0, "nor the night it holds")


func test_a_wisp_is_symmetric_in_shades_whites_and_fades_in_and_out() -> void:
	for rows: Array in Motes.WISPS:
		assert_eq(rows.size(), int(Motes.WISP_SIZE.y))
		for row: String in rows:
			assert_eq(row.length(), int(Motes.WISP_SIZE.x))
			assert_eq(row, row.reverse(), "the same either way")
			for ink in row:
				assert_true(ink in [".", "y", "s"], "Shade's white and snow white only")
	assert_gt(Motes.WISP_SIZE.x, Motes.WISP_SIZE.y, "longer than tall")
	assert_eq(Motes.mist_strip().get_size(), Vector2(Motes.WISP_SIZE.x * Motes.WISPS.size(), Motes.WISP_SIZE.y))
	assert_eq(Motes.mist_alpha(0.0), 0.0, "rising out of nothing")
	assert_almost_eq(Motes.mist_alpha(0.5), Motes.MIST_PEAK, 0.001, "lying a while")
	assert_eq(Motes.mist_alpha(1.0), 0.0, "sinking back")


## A grid from rows: "." grass, "~" water, ":" path, "#" a roof.
static func _grid(rows: Array) -> Dictionary:
	var kinds := {".": "grass", "~": "water", ":": "path", "#": "roof"}
	var grid := {}
	for y in rows.size():
		for x in String(rows[y]).length():
			grid[Vector2i(x, y)] = kinds[String(rows[y])[x]]
	return grid


func test_mist_rises_from_misty_runs_only() -> void:
	var rows := [
		"..~~~~::.....",
		":....#.......",
		"...::........",
		"~~~~~~~~~~~~~",
	]
	var grid := _grid(rows)
	var size := Vector2i(13, 4)
	var whole := Rect2i(Vector2i.ZERO, size)
	var points := Motes.mist_points(grid, size, Vector2i.ZERO, whole)
	assert_gt(points.size(), 0)
	var tile := float(MapView.TILE)
	var cells := {}
	for point in points:
		var cell := Vector2i((point / tile).floor())
		cells[cell] = true
		var inside := point - Vector2(cell) * tile
		assert_true(inside.x >= 2.0 and inside.x < tile - 1.0 and inside.y >= 2.0 and inside.y < tile - 1.0, "inside its cell: %s" % point)
		for near: Vector2i in [Vector2i.LEFT, Vector2i.ZERO, Vector2i.RIGHT, Vector2i(2, 0), Vector2i.UP]:
			var kind: String = grid.get(cell + near, "grass")
			assert_true(Motes.MISTY.has(kind), "%s rises clear of the path and the roof (%s: %s)" % [cell, near, kind])
	assert_true(cells.has(Vector2i(0, 0)), "off the map counts as misty at its west edge")
	assert_true(cells.has(Vector2i(12, 0)), "and at its east edge")
	assert_false(cells.has(Vector2i(1, 1)), "but the map's own path beside a cell counts")
	assert_true(cells.has(Vector2i(6, 3)), "over the river")
	assert_false(cells.has(Vector2i(5, 2)), "not against the foot of the house above")
	assert_true(cells.has(Vector2i(9, 1)), "but beside it, under the grass")
	# Inside a smaller view the map's own cells beyond it still count.
	var part := Motes.mist_points(grid, size, Vector2i.ZERO, Rect2i(1, 1, 6, 3))
	for point in part:
		assert_ne(Vector2i((point / tile).floor()), Vector2i(1, 1), "the path west of the view stops it")
	# A map drawn beside: the same wisps, moved by its offset.
	var origin := Vector2i(20, -3)
	var moved := Motes.mist_points(grid, size, origin, Rect2i(origin, size))
	assert_eq(moved.size(), points.size())
	for i in points.size():
		assert_eq(moved[i], points[i] + Vector2(origin) * tile, "moved by its offset, jitter and all")
	assert_eq(Motes.mist_points(grid, size, Vector2i.ZERO, whole), points, "the same every time")
	var coast := {}
	for x in size.x:
		coast[Vector2i(x, 3)] = "coast"
	for point in Motes.mist_points(grid, size, Vector2i.ZERO, whole, coast):
		assert_ne(int(point.y / tile), 3, "none over the coast's own sea")


func test_fireflies_come_out_at_dusk_and_night_in_the_open() -> void:
	var overworld := MapData.load_by_id("overworld")
	assert_eq(Motes.fireflies(overworld, "", 0.0, 0.0), 0.0, "none by day")
	assert_eq(Motes.fireflies(overworld, "", 1.0, 0.0), 1.0, "all of them at night")
	assert_between(Motes.fireflies(overworld, "woods", 0.5, 0.0), 0.01, 0.99, "the first at dusk")
	assert_eq(Motes.fireflies(overworld, "", 1.0, 1.0), 0.0, "none in the rain")
	for air: String in Motes.NO_FIREFLIES:
		assert_eq(Motes.fireflies(overworld, air, 1.0, 0.0), 0.0, "none in the %s air" % air)
	assert_eq(Motes.fireflies(MapData.load_by_id("town_inn"), "", 1.0, 0.0), 0.0, "none indoors")
	var town := MapData.load_by_id("town")
	assert_eq(Motes.fireflies(town, "", 1.0, 0.0), 1.0, "over the village's green")
	GameState.progression.prologue = Prologue.SCAVENGER
	assert_eq(Motes.fireflies(town, "", 1.0, 0.0), 0.0, "but not the night it burns")


func test_feet_kick_up_dust_or_splash() -> void:
	assert_eq(Motes.footfall("path"), "dust")
	assert_eq(Motes.footfall("snow"), "dust", "snow puffs too")
	assert_eq(Motes.footfall("marsh"), "splash", "wading through a bog")
	assert_eq(Motes.footfall("water"), "splash", "or the Mirefen's shallows (PIX-519)")
	assert_eq(Motes.footfall("grass"), "", "grass keeps quiet")
	assert_eq(Motes.footfall("floor"), "")
	for tile: String in Motes.DUST:
		assert_true(WorldTiles.is_walkable(tile), "%s is walked on" % tile)


func test_steel_sparks_off_armour() -> void:
	var monsters: Dictionary = Bestiary._data()["monsters"]
	for id: String in Motes.ARMOURED:
		assert_true(monsters.has(id), "%s is a foe" % id)
	assert_true(Motes.sparks_off("orc"))
	assert_true(Motes.sparks_off("golem"))
	assert_false(Motes.sparks_off("slime"), "no sparks off a slime")
	assert_false(Motes.sparks_off("wolf"))


func test_what_glows_glows_and_the_rest_takes_the_light() -> void:
	for node: CPUParticles2D in [Motes.make_fireflies(), Motes.make_embers(), Motes.make_sparks()]:
		autofree(node)
		assert_eq(node.material, Lights.glow(), "it glows in the dark")
	for node: CPUParticles2D in [Motes.make_leaves(), Motes.make_dust(), Motes.make_splash()]:
		autofree(node)
		assert_null(node.material, "it takes the scene's light")
	for node: CPUParticles2D in [Motes.make_dust(), Motes.make_splash(), Motes.make_sparks()]:
		autofree(node)
		assert_true(node.one_shot, "a burst, fired when needed")
		assert_false(node.emitting, "and quiet until then")


func test_the_perf_guard_counts_particles() -> void:
	var root: Node2D = autofree(Node2D.new())
	var on := Motes.make_embers(5)
	on.emitting = true
	root.add_child(on)
	var off := Motes.make_sparks()
	root.add_child(off)
	assert_eq(PerfProbe.particles(root), 5, "only what's emitting")
