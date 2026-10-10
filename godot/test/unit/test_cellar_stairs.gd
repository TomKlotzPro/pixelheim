extends GutTest
## A house opens onto a room, and the dungeon is down in its cellar
## (PIX-256: « Bizarre d'entrer dans une maison et arriver dans un donjon »).
## No door in a building opens straight onto a cave or a dungeon's floors:
## the Frostgate's observatory opens onto Liane's room and Greyhold's keep
## onto Captain Hale's hall, each with a stairwell in its floor down to its
## cave, whose stairs lead back up into the room. Going down asks first, the
## question naming where they go (PIX-269: no nameplate pops up by the
## stair). Every cell the hero lands on is open
## ground with open ground ahead, and saves made before stand where they
## stood.

const GameStateScript := preload("res://scripts/state/game_state.gd")

## The doors that opened straight onto a cave: the room each opens onto now,
## and the cave down its stair.
const HOUSES := [
	{"outside": "frostgate", "door": Vector2i(27, 6), "room": "observatory", "cave": "icecave"},
	{"outside": "greyhold", "door": Vector2i(37, 12), "room": "keep", "cave": "cellars"},
]


## The map as the world enters it: a room's furniture and Shade's dressing
## block.
func _as_entered(map_id: String) -> MapData:
	var map := MapData.load_by_id(map_id)
	if PunyInterior.is_room(map_id):
		var plan := PunyInterior.plan(map.id, map.grid)
		var dressed := PunyInterior.furnish(map.id, map.grid, PunyInterior.reserved(map, []))
		for cell: Vector2i in plan["blocked"] + dressed["blocked"]:
			map.grid[cell] = "wall"
	return map


## The one stairwell down in a room.
func _down(room: MapData) -> Vector2i:
	var downs := room.portals.keys().filter(func(cell: Vector2i) -> bool: return Ways.goes_down(room, cell))
	assert_eq(downs.size(), 1, "%s has one stair down" % room.id)
	return downs[0] if not downs.is_empty() else Ways.NOWHERE


func test_no_door_in_a_building_opens_onto_a_cave_or_a_dungeon() -> void:
	var doors := 0
	for map_id: String in Catalog._data()["places"]:
		var map := MapData.load_by_id(map_id)
		for way: Dictionary in Ways.on(map):
			if way["kind"] != "door":
				continue
			doors += 1
			var to: Dictionary = way["to"]
			assert_eq(to["kind"], "map", "%s: the door at %s opens onto a room, not a dungeon's floors" % [map_id, way["at"]])
			if to["kind"] == "map":
				var next := MapData.load_by_id(String(to["mapId"]))
				assert_ne(next.style, "cave", "%s: the door at %s opens onto a room, not %s" % [map_id, way["at"], next.id])
	assert_gt(doors, 10, "every door was looked at")


func test_each_house_door_leads_into_its_room_and_back_out() -> void:
	for house: Dictionary in HOUSES:
		var outside := MapData.load_by_id(house["outside"])
		var door: Vector2i = house["door"]
		assert_eq(Ways.kind_of(outside, door), "door", "%s: a door in a building" % outside.id)
		assert_eq(outside.portals[door]["mapId"], house["room"], "%s's door opens onto %s" % [outside.id, house["room"]])
		var room := MapData.load_by_id(house["room"])
		assert_true(PunyInterior.is_room(room.id), "%s is one of Shade's rooms" % room.id)
		assert_true(Ways.indoors(room), "%s is indoors" % room.id)
		var out: Array = room.portals.keys().filter(func(cell: Vector2i) -> bool: return room.portals[cell]["mapId"] == outside.id)
		assert_eq(out.size(), 1, "%s has one door out" % room.id)
		assert_eq(Ways.kind_of(room, out[0]), "door")
		var back: Dictionary = room.portals[out[0]]
		assert_eq(Vector2i(int(back["x"]), int(back["y"])), door + Vector2i.DOWN, "%s: out in front of the door" % room.id)
		assert_ne(Catalog.place_name(room.id), room.id.capitalize(), "%s has a name of its own" % room.id)


func test_each_room_leads_down_to_its_cave_and_the_cave_back_up_into_it() -> void:
	for house: Dictionary in HOUSES:
		var room := MapData.load_by_id(house["room"])
		var down := _down(room)
		assert_eq(room.tile_at(down), "stairwell")
		assert_eq(room.portals[down]["mapId"], house["cave"], "%s's stair goes down to %s" % [room.id, house["cave"]])
		assert_eq(Ways.below(room.id), house["cave"])
		var cave := MapData.load_by_id(house["cave"])
		assert_eq(cave.style, "cave")
		var below := Vector2i(int(room.portals[down]["x"]), int(room.portals[down]["y"]))
		assert_true(Ways.open_ground(cave, below), "%s: down the stair onto open ground" % cave.id)
		for up: Vector2i in cave.portals:
			# A region dungeon's first floor goes on down too (PIX-255: the
			# cellars' stair to the crypt).
			if Ways.kind_of(cave, up) == "down":
				continue
			var target: Dictionary = cave.portals[up]
			assert_eq(Ways.kind_of(cave, up), "stairs")
			assert_eq(target["mapId"], room.id, "%s's stairs lead up into %s, not outside" % [cave.id, room.id])
			var landing := Vector2i(int(target["x"]), int(target["y"]))
			assert_lte(Vector2(landing - down).length(), 2.0, "%s: up beside the stairwell" % room.id)
		assert_eq(Ways.below(house["outside"]), "", "only a room has a stair down")


func test_every_cell_the_hero_arrives_on_is_open_ground_facing_in() -> void:
	var ids := ["frostgate", "greyhold", "observatory", "keep", "icecave", "cellars"]
	var landings := 0
	for id: String in ids:
		var map := MapData.load_by_id(id)
		for cell: Vector2i in map.portals:
			var target: Dictionary = map.portals[cell]
			if target.get("kind", "") != "map" or String(target["mapId"]) not in ids:
				continue
			landings += 1
			var next := _as_entered(String(target["mapId"]))
			var arrival := Vector2i(int(target["x"]), int(target["y"]))
			var said := "%s %s -> %s %s" % [id, cell, next.id, arrival]
			assert_true(Ways.open_ground(next, arrival), "%s: lands on open ground" % said)
			var facing := Vector2i(Ways.arrival_facing(next, arrival, id, Vector2.DOWN))
			assert_true(Ways.open_ground(next, arrival + facing), "%s: open ground ahead, facing %s" % [said, facing])
	assert_eq(landings, 8, "into each room and out, down each stair and up")


func test_the_stairs_ask_before_they_take_you_down_and_name_where_they_go() -> void:
	for house: Dictionary in HOUSES:
		var room := MapData.load_by_id(house["room"])
		var down := _down(room)
		var question := Ways.going_down(room, down)
		assert_eq(question["lines"].size(), 1, "one page: the question with its answers")
		var line: String = question["lines"][0]
		assert_true(line.ends_with("?"), "%s: it asks" % room.id)
		assert_string_contains(line, Text.mid(Catalog.place_name(house["cave"])))
		assert_eq(question["choices"].size(), 2, "go down, or stay")
		var ways := Ways.on(room).filter(func(way: Dictionary) -> bool: return way["kind"] == "down")
		assert_eq(ways.size(), 1)
		assert_eq(Ways.place_of(ways[0]["to"]), Catalog.place_name(house["cave"]), "the question names the cave")
		for cell: Vector2i in room.portals:
			if cell != down:
				assert_false(Ways.goes_down(room, cell), "%s: the door at %s just opens" % [room.id, cell])


func test_the_stairwell_is_drawn_and_the_way_to_it_kept_clear() -> void:
	for house: Dictionary in HOUSES:
		var room := MapData.load_by_id(house["room"])
		var down := _down(room)
		var plan := PunyInterior.plan(room.id, room.grid)
		assert_eq(plan["pieces"].get(down), PunyInterior.STAIRWELL, "%s: Shade's steps" % room.id)
		assert_eq(plan["floor"].get(down), PunyInterior.STAIRWELL_FLOOR, "on his stone")
		for step: Vector2i in PunyInterior.STAIRWELL_RING:
			assert_eq(plan["floor"].get(down + step), PunyInterior.STAIRWELL_RING[step], "%s: the carpet round the stairwell at %s" % [room.id, down + step])
		assert_false(plan["blocked"].has(down))
		var dressed := PunyInterior.furnish(room.id, room.grid, PunyInterior.reserved(room, []))
		assert_eq(dressed["skipped"], [], "%s: every piece fits" % room.id)
		for dy in [-1, 0, 1, 2]:
			for dx in [-1, 0, 1]:
				var cell: Vector2i = down + Vector2i(dx, dy)
				for kind: String in ["rug", "objects", "tops", "lifted"]:
					assert_false(dressed[kind].has(cell), "%s: nothing laid on the stairwell's carpet or the way to it at %s" % [room.id, cell])


## A later step lays a readable thing here (an order book on Hale's table,
## notes on Liane's desk): a spot kept clear on each.
func test_the_captains_table_and_lianes_desk_keep_a_spot_clear() -> void:
	for room_id: String in ["keep", "observatory"]:
		var room := MapData.load_by_id(room_id)
		var layout: Dictionary = PunyInterior.interiors()["rooms"][room_id]
		var spot := Vector2i(int(layout["spot"][0]), int(layout["spot"][1]))
		var dressed := PunyInterior.furnish(room_id, room.grid, PunyInterior.reserved(room, []))
		assert_true(dressed["objects"].has(spot), "%s: the spot at %s is on the table" % [room_id, spot])
		assert_false(dressed["tops"].has(spot), "%s: nothing on it" % room_id)
		assert_false(dressed["lifted"].has(spot), "%s: nothing over it" % room_id)


func test_saves_from_before_stand_where_they_stood() -> void:
	# A hero saved in a cave loads there; one saved where the old doors set
	# them down outside still stands there, on open ground.
	for spot: Array in [["icecave", Vector2i(4, 25)], ["icecave", Vector2i(30, 20)], ["cellars", Vector2i(4, 27)], ["frostgate", Vector2i(27, 7)], ["greyhold", Vector2i(37, 13)]]:
		var state: Node = autofree(GameStateScript.new())
		state.new_game("Robin", "warrior")
		state.world.map_id = spot[0]
		state.world.cell = spot[1]
		var back: Node = autofree(GameStateScript.new())
		back.apply(SaveCodec.migrate(SaveCodec.parse_json(SaveCodec.serialize(state.to_dict()))))
		assert_eq(back.world.map_id, spot[0], "%s %s: the save keeps its map" % spot)
		assert_eq(back.world.cell, spot[1], "%s %s: and its cell" % spot)
		var map := MapData.load_by_id(spot[0])
		assert_eq(Ways.standing(map, spot[1]), spot[1], "%s %s: wakes where it stood, on open ground" % spot)
	# A save made in the doorway itself wakes in front of it, not in the room.
	for house: Dictionary in HOUSES:
		var outside := MapData.load_by_id(house["outside"])
		var door: Vector2i = house["door"]
		var woke := Ways.standing(outside, door)
		assert_eq(woke, door + Vector2i.DOWN, "%s: a save in the door wakes in front of it" % outside.id)
		assert_true(Ways.open_ground(outside, woke))
	assert_eq(Ways.standing(MapData.load_by_id("frostgate"), Vector2i(0, 0)), MapData.load_by_id("frostgate").spawn, "in the rock: the spawn")
