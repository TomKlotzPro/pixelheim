extends GutTest
## The farmland round Pixelheim on the Reach by the town's age (PIX-397):
## every piece is laid where it's placed, at every age; nothing on a road, a
## portal, a foe region, the gate's fork, a settler's spot or pacing, the
## spawn or where the story starts, nothing standing under a fork's
## signpost, and no way closed; each age keeps the
## last's and adds to it; the pastures' animals graze inside their fences;
## nothing without the paid pack, nor off the Reach.

const Hamlets := preload("res://test/unit/test_hamlet.gd")


## The Reach at `age` as MapView plans it: {map, kept, grown, planned}.
static func _reach(age: int) -> Dictionary:
	var map := MapData.load_by_id(Farmland.MAP)
	var kept := Hamlet.kept_on(map)
	var grown := Farmland.plan(map, age, true)
	return {"map": map, "kept": kept, "grown": grown, "planned": Hamlet.plan(map, kept, grown)}


## Every cell the story, the Post and the settlers stand anyone or anything
## on, round the town: the gate's fork, each settler found here and the
## square they pace, the prologue's start and the spawn.
static func _spots(map: MapData) -> Dictionary:
	var out := {map.spawn: true}
	for fork: Dictionary in Routes.forks():
		out[Vector2i(int(fork["at"][0]), int(fork["at"][1]))] = true
	for recruit: Dictionary in Npcs.recruits():
		var found: Dictionary = recruit.get("found", {})
		if found.get("mapId", "") == map.id:
			for offset: Vector2i in Npcs.LOOP:
				out[Vector2i(int(found["x"]), int(found["y"])) + offset] = true
	var start: Dictionary = Prologue.data()["start"]
	out[Vector2i(int(start["x"]), int(start["y"]))] = true
	return out


## The cell under each fork: a piece standing there is two cells tall, so it
## would hide the fork's signpost behind it (the City's lamp did).
static func _under_forks() -> Dictionary:
	var out := {}
	for fork: Dictionary in Routes.forks():
		out[Vector2i(int(fork["at"][0]), int(fork["at"][1])) + Vector2i.DOWN] = true
	return out


func test_every_piece_is_laid_at_every_age() -> void:
	for age in Town.MAX_TIER + 1:
		var reach := _reach(age)
		var laid := {}
		for piece: Dictionary in reach["planned"]["pieces"]:
			laid[[piece["cell"], piece.get("tile", piece.get("art", "lamp"))]] = true
		for piece: Dictionary in reach["grown"]:
			assert_true(laid.has([piece["cell"], piece.get("tile", piece.get("art", "lamp"))]), "age %d: %s laid" % [age, piece])


func test_nothing_on_a_road_a_portal_a_region_or_a_spot() -> void:
	for age in Town.MAX_TIER + 1:
		var reach := _reach(age)
		var map: MapData = reach["map"]
		var spots := _spots(map)
		var under := _under_forks()
		for piece: Dictionary in reach["planned"]["pieces"]:
			for cell: Vector2i in piece["cells"]:
				var at := "age %d: %s at %s" % [age, piece.get("set", ""), cell]
				assert_does_not_have(Hamlet.WAYS, map.tile_at(cell), at + " off the roads")
				assert_true(WorldTiles.is_walkable(map.tile_at(cell)), at + " on open ground")
				assert_false(map.portals.has(cell), at + " off the portals")
				assert_eq(map.region_at(cell), "", at + " in no foe region")
				assert_false(spots.has(cell), at + " off the story's spots")
				assert_false(reach["kept"].has(cell), at + " off the packs, chests and patches")
				if not piece.get("flat", false):
					assert_false(under.has(cell), at + " not standing under a fork's signpost")


func test_no_way_is_closed() -> void:
	for age in Town.MAX_TIER + 1:
		var reach := _reach(age)
		var map: MapData = reach["map"]
		var before := Hamlets._reach(map, map.spawn)
		for cell: Vector2i in reach["planned"]["blocks"]:
			map.covered[cell] = true
		var after := Hamlets._reach(map, map.spawn)
		for cell: Vector2i in before:
			if cell not in reach["planned"]["blocks"]:
				assert_true(after.has(cell), "age %d: %s still reached from the spawn" % [age, cell])
		for portal: Vector2i in map.portals:
			assert_true(after.has(portal) or not before.has(portal), "age %d: the way out at %s" % [age, portal])


func test_each_age_keeps_the_last_and_adds_to_it() -> void:
	var before := {}
	for age in Town.MAX_TIER + 1:
		var cells := {}
		for piece: Dictionary in _reach(age)["planned"]["pieces"]:
			cells[piece["cell"]] = true
		assert_gt(cells.size(), before.size(), "age %d adds to the last" % age)
		for cell: Vector2i in before:
			assert_true(cells.has(cell), "age %d keeps %s" % [age, cell])
		before = cells
	var sets := {}
	for piece: Dictionary in _reach(Town.MAX_TIER)["planned"]["pieces"]:
		sets[piece["set"]] = true
	assert_eq(sets.keys().size(), 5, "the City's: fields, pastures, an orchard, a farmstead and lamps by the road")


func test_the_animals_graze_inside_their_fences() -> void:
	for age in Town.MAX_TIER + 1:
		var reach := _reach(age)
		var map: MapData = reach["map"]
		var herd := FarmAnimals.plan_herd(map, age, FarmAnimals.kept_on(map, null, reach["planned"]["pieces"]), true)
		var pens := FarmAnimals.REACH.filter(func(entry: Dictionary) -> bool: return int(entry["age"]) <= age)
		assert_eq(herd.size(), pens.size(), "age %d: every animal finds a cell" % age)
		for animal: Dictionary in herd:
			for cell: Vector2i in animal["area"]:
				assert_false(cell in reach["planned"]["blocks"], "age %d: %s grazes off the fences" % [age, cell])
				assert_eq(map.region_at(cell), "", "age %d: %s in no foe region" % [age, cell])


func test_nothing_without_the_pack_nor_off_the_reach() -> void:
	assert_eq(Farmland.plan(MapData.load_by_id(Farmland.MAP), Town.MAX_TIER, false).size(), 0)
	assert_eq(Farmland.plan(MapData.load_by_id("saltmere"), Town.MAX_TIER, true).size(), 0)


func test_every_tile_is_the_pack_s() -> void:
	for piece: Dictionary in Farmland.plan(MapData.load_by_id(Farmland.MAP), Town.MAX_TIER, true):
		if piece.has("tile"):
			assert_between(int(piece["tile"]), 0, PunyTown.COLUMNS * PunyTown.ROWS - 1, "%s: a tile of the pack" % piece["cell"])
		elif piece.has("art"):
			assert_gt(HamletArt.rows_of(piece["art"]).size(), 0, "%s: one of ours" % piece["art"])
