extends GutTest
## The town's farm animals (PIX-387): how many of each kind at each age,
## none ever standing or stepping where a road, a door, a villager, a stall,
## the story or the yards are, nor cattle by the water, the pigs inside their
## sty, the same plan on every run, none without the pack; a step stays in
## its patch, off its herd-mates; and the herd's day (Herd).

const Towns := preload("res://test/unit/test_yards.gd")


## The animals at `age`, planned on the town as MapView plans it (its
## houses, props and yards): {plan, map, kept}.
static func _herd(age: int) -> Dictionary:
	var town := Towns._town(age)
	var map: MapData = town["map"]
	for cell: Vector2i in town["planned"]["blocks"]:
		map.covered[cell] = true
	var kept := FarmAnimals.kept_on(map, null, town["planned"]["pieces"])
	return {"plan": FarmAnimals.plan_herd(map, age, kept, true), "map": map, "kept": kept}


static func _counts(plan: Array[Dictionary]) -> Dictionary:
	var out := {}
	for animal in plan:
		out[animal["kind"]] = int(out.get(animal["kind"], 0)) + 1
	return out


func test_how_many_live_in_the_town_at_each_age() -> void:
	assert_eq(_counts(_herd(0)["plan"]), {}, "none in the Ashes")
	assert_eq(_counts(_herd(1)["plan"]), {"hen": 3}, "a few hens in the Hamlet")
	assert_eq(_counts(_herd(2)["plan"]), {"hen": 5, "chick": 3, "sheep": 3, "pig": 2, "cow": 1}, "the Village")
	var farmyard := {"hen": 7, "chick": 6, "sheep": 5, "pig": 3, "cow": 2, "bull": 1}
	assert_eq(_counts(_herd(3)["plan"]), farmyard, "the whole farmyard in the Town")
	assert_eq(_counts(_herd(Town.MAX_TIER)["plan"]), farmyard, "and in the City")


func test_none_ever_stands_where_it_must_not() -> void:
	for age in range(1, Town.MAX_TIER + 1):
		var herd := _herd(age)
		var map: MapData = herd["map"]
		var starts := {}
		for animal: Dictionary in herd["plan"]:
			assert_false(starts.has(animal["cell"]), "age %d: %s starts alone" % [age, animal["cell"]])
			starts[animal["cell"]] = true
			assert_has(animal["area"], animal["cell"], "age %d: it starts in its patch" % age)
			assert_gt(animal["area"].size(), 3, "age %d: a %s has room to wander" % [age, animal["kind"]])
			for cell: Vector2i in animal["area"]:
				var tile := map.tile_at(cell)
				var why := "age %d: a %s never on %s (%s)" % [age, animal["kind"], cell, tile]
				assert_true(map.is_walkable(cell), why)
				assert_does_not_have(Hamlet.WAYS, tile, why)
				assert_false(tile.begins_with("door") or map.portals.has(cell), why)
				assert_false(map.tile_at(cell + Vector2i.UP).begins_with("door"), why)
				assert_false(herd["kept"].has(cell), why)
				assert_false(Yards.kept(map).has(cell), why)
				# Cattle are wider than a cell: beside the river a tail stood in it.
				if animal["kind"] in ["cow", "bull"]:
					assert_false(map.tile_at(cell + Vector2i.LEFT) == "water" or map.tile_at(cell + Vector2i.RIGHT) == "water", why + ": by the water")


func test_the_pigs_keep_to_their_sty() -> void:
	var herd := _herd(Town.MAX_TIER)
	var map: MapData = herd["map"]
	for animal: Dictionary in herd["plan"]:
		if animal["kind"] == "pig":
			for cell: Vector2i in animal["area"]:
				assert_true(FarmAnimals.STY.has_point(cell), "a pig only in its sty: %s" % cell)
	# Round it, the town map's fence and the wall, but for its gate.
	var gates: Array[Vector2i] = []
	var ring := FarmAnimals.STY.grow(1)
	for y in range(ring.position.y, ring.end.y):
		for x in range(ring.position.x, ring.end.x):
			var cell := Vector2i(x, y)
			if not FarmAnimals.STY.has_point(cell) and map.tile_at(cell) not in ["fence", "wall"]:
				gates.append(cell)
	assert_eq(gates.size(), 1, "fenced all round but its gate: %s" % [gates])
	assert_true(gates.size() == 1 and map.tile_at(gates[0] + Vector2i.DOWN) in Hamlet.WAYS, "its gate on the road")


func test_the_plan_is_the_same_on_every_run() -> void:
	var city := _herd(Town.MAX_TIER)
	assert_eq(FarmAnimals.plan_herd(city["map"], Town.MAX_TIER, city["kept"], true), city["plan"])
	assert_eq(_herd(Town.MAX_TIER)["plan"], city["plan"])


func test_none_without_the_pack() -> void:
	var city := _herd(Town.MAX_TIER)
	assert_eq(FarmAnimals.plan_herd(city["map"], Town.MAX_TIER, city["kept"], false).size(), 0)
	PunyTown.withheld = true
	assert_false(FarmAnimals.available(), "the harness's cc0 holds them back")
	PunyTown.withheld = false


func test_a_step_stays_in_the_patch_off_the_others() -> void:
	var area: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1)]
	var dice := RandomNumberGenerator.new()
	dice.seed = 387
	var cell := Vector2i(1, 0)
	for i in 200:
		var taken := {Vector2i(2, 0): true}
		var next := FarmAnimals.step(area, cell, taken, dice)
		assert_true(next in area and not taken.has(next), "%s steps within its patch, off the others" % next)
		assert_eq(absi(next.x - cell.x) + absi(next.y - cell.y) <= 1, true, "a cell at a time")
		cell = next
	assert_eq(FarmAnimals.step(area, Vector2i(2, 0), {Vector2i(1, 0): true}, dice), Vector2i(2, 0), "boxed in, it stays")


## Two hens sharing a row of three cells through Herd's day: they live on
## the screen and rest off it, fall asleep mid-step and walk on after, and
## never stand on or head for the same cell (Herd._taken). In a viewport of
## their own, with frames of their own (no pack needed).
func test_the_herd_rests_sleeps_and_keeps_its_cells() -> void:
	var blank := ImageTexture.create_from_image(Image.create(16, 16, false, Image.FORMAT_RGBA8))
	var frames := SpriteFrames.new()
	for anim: String in FarmAnimals.FPS:
		frames.add_animation(anim)
		for n in 4:
			frames.add_frame(anim, blank)
	FarmAnimals._frames["test_hen"] = frames
	var screen := SubViewport.new()
	screen.size = Vector2i(320, 180)
	add_child_autofree(screen)
	var actors := Node2D.new()
	screen.add_child(actors)
	var row: Array[Vector2i] = [Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2)]
	var plan: Array[Dictionary] = [
		{"sheet": "test_hen", "kind": "hen", "cell": row[0], "area": row},
		{"sheet": "test_hen", "kind": "hen", "cell": row[2], "area": row},
	]
	var herd := Herd.new(plan, actors)
	herd.set_process(false)
	actors.add_child(herd)
	# On the screen they live: one sets off within a minute.
	var walker := {}
	for i in 600:
		herd._process(0.1)
		_assert_cells_kept(herd)
		for animal: Dictionary in herd.animals:
			if animal.has("goal") and animal["sprite"].position != Herd.foot(animal["cell"]):
				walker = animal
		if not walker.is_empty():
			break
	assert_false(walker.is_empty(), "a hen sets off")
	if walker.is_empty():
		FarmAnimals._frames.erase("test_hen")
		return
	var sprite: AnimatedSprite2D = walker["sprite"]
	assert_true(sprite.is_playing() and sprite.animation == "walk", "walking, it plays its walk")
	# Off the screen they rest: nothing moves or plays.
	screen.canvas_transform = Transform2D(0.0, Vector2(-4000, 0))
	var at := sprite.position
	for i in 20:
		herd._process(0.1)
	assert_true(herd.animals.all(func(animal: Dictionary) -> bool: return animal["resting"]), "off the screen they rest")
	assert_eq(sprite.position, at, "resting, it doesn't move")
	assert_false(sprite.is_playing(), "resting, it doesn't play")
	# Night falls mid-step while they rest; back on the screen they sleep.
	herd.sleep(true)
	assert_false(sprite.is_playing(), "asleep off the screen, still")
	screen.canvas_transform = Transform2D.IDENTITY
	herd._process(0.1)
	for animal: Dictionary in herd.animals:
		var hen: AnimatedSprite2D = animal["sprite"]
		assert_false(animal["resting"], "back on the screen they wake from their rest")
		assert_true(hen.is_playing() and hen.animation == "sleep", "and sleep where they stand")
	for i in 20:
		herd._process(0.1)
	assert_eq(sprite.position, at, "asleep, it doesn't move")
	_assert_cells_kept(herd)
	# Day: it plays its walk again and finishes the step it began.
	var goal: Vector2i = walker["goal"]
	herd.sleep(false)
	assert_true(sprite.is_playing() and sprite.animation == "walk", "awake, it walks on")
	for i in 100:
		herd._process(0.1)
		_assert_cells_kept(herd)
		if walker["cell"] == goal:
			break
	assert_eq(walker["cell"], goal, "it ends the step it began")
	assert_eq(sprite.position, Herd.foot(goal), "standing in its new cell")
	FarmAnimals._frames.erase("test_hen")


## Each hen's cell and the one it heads for are its own, and held (_taken).
func _assert_cells_kept(herd: Herd) -> void:
	var held := {}
	for animal: Dictionary in herd.animals:
		for key: String in ["cell", "goal"]:
			if animal.has(key):
				assert_false(held.has(animal[key]), "%s held once" % animal[key])
				held[animal[key]] = true
	assert_eq(herd._taken, held, "the cells held are theirs")
