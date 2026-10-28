extends GutTest
## The town's farm animals (PIX-387): how many of each kind at each age,
## none ever standing or stepping where a road, a door, a villager, a stall,
## the story or the yards are, the same plan on every run, none without the
## pack; and a step stays in its patch, off its herd-mates.

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
