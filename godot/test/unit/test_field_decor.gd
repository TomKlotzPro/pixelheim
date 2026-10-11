extends GutTest
## The field's decor (PIX-304): its trees, wheat, bushes, stumps and stones.
## From One Land (PIX-269, v0.219) MapView counted the units that draw them
## from a list its first unit filled, so it planned none: every map in the
## open air was a bare lawn, while the bushes that block still stopped the
## hero and the packs where nobody could see them. A map with field decor
## plans and builds it, drawn at once or a few units a frame beside the
## hero; it grows wherever Scatter picks but where something else stands or
## a way leads on; what blocks is drawn, and kept off the hero's arrival,
## the packs' homes and anything lying to pick up; rooms and dungeons grow
## none.

var _saved := {}


func before_all() -> void:
	KeptGround.forget()


func after_all() -> void:
	KeptGround.forget()


func before_each() -> void:
	_saved = {"tier": GameState.settlement.town_tier, "projects": GameState.settlement.projects.duplicate()}


func after_each() -> void:
	GameState.settlement.town_tier = _saved["tier"]
	GameState.settlement.projects.assign(_saved["projects"])


## `data` drawn as a door draws it, or a unit at a time as Neighbours draws
## it beside the hero (its kept ground and its patches' decks worked out in
## slices too).
func _draw(data: MapData, sliced: bool) -> MapView:
	var root := Node2D.new()
	add_child_autofree(root)
	var standing := Node2D.new()
	root.add_child(standing)
	var view := MapView.new(data, standing)
	if sliced:
		view.sliced = true
		var slices := Slicer.new()
		KeptGround.decks_working(data, slices)
		view.planning(data.spawn, slices)
		slices.add("plan_kept", func() -> void:
			view.kept = KeptGround.working(data, view.look(), MapView.EDGE_PAD, slices)
			slices.add("plan_draw", func() -> void: view.building(root, slices)))
		slices.finish()
		assert_true(slices.totals.has("decor_field"), "%s: its field's decor drawn in units of their own" % data.id)
	else:
		view.plan(data.spawn)
		view.build(root)
	return view


## The maps on disk in the open air, or under a roof or the ground.
static func _maps(outdoor: bool) -> Array[MapData]:
	var out: Array[MapData] = []
	for file: String in DirAccess.get_files_at("res://assets/maps"):
		if not file.ends_with(".json") or file == "interactables.json":
			continue
		var map_id := file.get_basename()
		var map: MapData
		if "@" in map_id:
			map = MapData.load_tiered(map_id.get_slice("@", 0), [], int(map_id.get_slice("@", 1)))
		else:
			map = MapData.load_by_id(map_id)
		if PunyTerrain.is_outdoor(map.grid) == outdoor:
			out.append(map)
	return out


## What Scatter grows on `data`: cell -> tile.
static func _picked(data: MapData) -> Dictionary:
	var out := {}
	for cell: Vector2i in data.grid:
		var choice := Scatter.choice(data.grid, cell)
		if choice >= 0:
			out[cell] = choice
	return out


## Where something else stands on `view`'s map or a way leads on, as the
## world places it: cell -> what.
static func _taken(view: MapView) -> Dictionary:
	var data := view.data
	var out := {}
	for cell: Vector2i in data.portals:
		out[cell] = "a way on"
	for cell: Vector2i in view.outdoor_props["drawn"]:
		out[cell] = "a prop"
	for cell: Vector2i in view.camps:
		out[cell] = "a camp"
	for gate: Dictionary in view.gates:
		for cell: Vector2i in Gates.cells_of(gate):
			out[cell] = "a shut gate"
		for piece: Dictionary in GateArt.plan(gate, PunyProps.available())["pieces"]:
			out[piece["cell"]] = "a shut gate's piece"
	for entrance: Dictionary in view.entrances:
		for piece: Dictionary in entrance["pieces"]:
			out[piece["cell"]] = "an entrance's piece"
		for cell: Vector2i in entrance["blocks"]:
			out[cell] = "an entrance"
	for chest: Dictionary in Interactables.chests_on(data.id):
		out[Vector2i(int(chest["x"]), int(chest["y"]))] = "a chest" if chest["look"] == "chest" else "a pickup"
	for npc: Dictionary in Npcs.on_map(data.id, GameState.settlement.town_tier, GameState.settlement.settlers, Town.done_projects(GameState.settlement), Relics.gate_open(GameState.progression), Letters.tin_waits(GameState.progression)):
		out[Vector2i(int(npc["x"]), int(npc["y"]))] = "a villager's home"
	return out


func test_a_map_in_the_open_air_grows_its_decor_at_once_or_in_slices() -> void:
	for map_id: String in ReachPlane.maps() + ["town"]:
		var whole := _draw(MapData.load_by_id(map_id), false)
		var picked := _picked(whole.data)
		assert_gt(whole.field.size(), picked.size() * 0.95, "%s grows its field's decor (%d of %d)" % [map_id, whole.field.size(), picked.size()])
		for cell: Vector2i in whole.field:
			assert_eq(whole.field[cell], picked.get(cell, -1), "%s: %s grows what Scatter picks" % [map_id, cell])
		var sliced := _draw(MapData.load_by_id(map_id), true)
		assert_eq(sliced.field, whole.field, "%s drawn beside the hero grows the same" % map_id)
	var deepwood := _draw(MapData.load_by_id("deepwood"), false)
	var trees := deepwood.field.values().filter(func(tile: int) -> bool: return tile in Scatter.SCATTER["forest"][1])
	assert_gt(trees.size(), 1000, "the Deepwood is a forest")


func test_nothing_grows_where_something_stands_or_a_way_leads() -> void:
	var spared := 0
	for data: MapData in _maps(true):
		var view := _draw(data, false)
		var picked := _picked(data)
		var taken := _taken(view)
		for cell: Vector2i in taken:
			assert_false(view.field.has(cell), "%s: nothing grows on %s at %s" % [data.id, taken[cell], cell])
			if picked.has(cell):
				spared += 1
		for cell: Vector2i in view.field:
			var tile: String = data.grid[cell]
			assert_false(tile.begins_with("door") or tile == "road", "%s: nothing grows on the %s at %s" % [data.id, tile, cell])
	assert_gt(spared, 5, "camps in the woods, a chest under the pines, the gate across the coast road: spared")


func test_what_blocks_is_drawn_and_kept_off_arrivals_homes_and_pickups() -> void:
	for data: MapData in _maps(true):
		var view := _draw(data, false)
		var clear := {view.arrival: "the hero's arrival"}
		for cell: Vector2i in view.patches:
			clear[cell] = "a patch"
		for spawn: Dictionary in Bestiary.spawns_on(data.id):
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					clear[Vector2i(spawn["x"] + dx, spawn["y"] + dy)] = "a pack's home"
		var taken := _taken(view)
		for cell: Vector2i in view.solid_scatter:
			assert_true(view.field.has(cell), "%s: the bush at %s is drawn" % [data.id, cell])
			assert_false(data.is_walkable(cell), "%s: the bush at %s blocks" % [data.id, cell])
			assert_false(clear.has(cell), "%s: no bush on %s at %s" % [data.id, clear.get(cell, ""), cell])
			assert_false(taken.has(cell), "%s: no bush on %s at %s" % [data.id, taken.get(cell, ""), cell])
		assert_true(data.is_walkable(view.arrival), "%s: the hero arrives on open ground" % data.id)


func test_the_town_grows_its_wheat_at_every_age() -> void:
	for tier in Town.MAX_TIER + 1:
		GameState.settlement.town_tier = tier
		var projects := Town.projects_through(tier)
		GameState.settlement.projects.assign(projects)
		var view := _draw(MapData.load_tiered("town", projects, 1), false)
		var taken := _taken(view)
		var crops := 0
		var wheat := 0
		for cell: Vector2i in view.data.grid:
			if view.data.grid[cell] == "crops" and not taken.has(cell):
				crops += 1
				if view.field.get(cell, -1) in Scatter.SCATTER["crops"][1]:
					wheat += 1
		assert_gt(crops, 100, "the town at age %d has its fields" % tier)
		assert_eq(wheat, crops, "the town at age %d grows wheat in every field" % tier)


func test_rooms_and_dungeons_grow_none() -> void:
	for data: MapData in _maps(false):
		assert_true(_draw(data, false).field.is_empty(), "%s grows no field decor" % data.id)
	for dungeon_id: String in Depths.dungeons():
		for entry: Dictionary in Depths.floors(dungeon_id):
			var data := MapData.load_by_id(entry["mapId"])
			assert_true(_draw(data, false).field.is_empty(), "%s grows no field decor" % data.id)
