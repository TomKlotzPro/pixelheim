extends GutTest
## Furnished rooms (PIX-163): every room's layout fits whole (no vignette
## skipped), Shade's pieces are furniture and never his villagers, and the
## dressing leaves the way in, the spawn, every keeper and every fixture
## within reach.

const ROOMS := {
	"town_inn": ["town_inn", 1], "town_shop": ["town_shop", 1], "town_smith": ["town_smith", 1],
	"town_alchemist": ["town_alchemist", 1], "town_hall": ["town_hall", 1],
	"town_house": ["town_house", 1], "town_house@2": ["town_house", 2], "town_house@3": ["town_house", 3],
	"observatory": ["observatory", 1], "keep": ["keep", 1],
}
## What the hero uses by facing it.
const FIXTURES := ["bed", "hearth", "forge", "anvil", "cauldron", "shelf", "trophy_shelf", "counter", "garden", "crate", "barrel"]


## The room as it was (`dress` false) or dressed.
func _room(key: String, dress: bool) -> MapData:
	var room: Array = ROOMS[key]
	var map := MapData.load_tiered(room[0], [], int(room[1]))
	var plan := PunyInterior.plan(map.id, map.grid)
	var blocked: Array = plan["blocked"]
	if dress:
		var dressed := PunyInterior.furnish(map.id + map.variant, map.grid, PunyInterior.reserved(map, []))
		assert_eq(dressed["skipped"], [], "%s: every piece fits" % key)
		assert_gt(dressed["objects"].size() + dressed["tops"].size(), 8, "%s is furnished" % key)
		blocked = blocked + dressed["blocked"]
	for cell: Vector2i in blocked:
		map.grid[cell] = "wall"
	return map


## The cells the hero can walk to from the door.
func _reach(map: MapData) -> Dictionary:
	var door: Vector2i = map.portals.keys()[0]
	var start := door + Vector2i.UP
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var at: Vector2i = queue.pop_front()
		for side in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next: Vector2i = at + side
			if not seen.has(next) and map.is_walkable(next):
				seen[next] = true
				queue.append(next)
	return seen


func _beside(reach: Dictionary, cell: Vector2i) -> bool:
	for side in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		if reach.has(cell + side):
			return true
	return false


func test_every_room_is_dressed_and_still_walkable() -> void:
	for key: String in ROOMS:
		var before := _reach(_room(key, false))
		var map := _room(key, true)
		var reach := _reach(map)
		assert_true(reach.has(map.spawn), "%s: the spawn" % key)
		for npc: Dictionary in Npcs._data()["npcs"]:
			if npc.get("mapId", "") == map.id:
				assert_true(_beside(reach, Vector2i(int(npc["x"]), int(npc["y"]))), "%s: %s can be talked to" % [key, npc["id"]])
		# Whatever fixture the hero could reach before, they still can.
		for cell: Vector2i in map.grid:
			if map.grid[cell] in FIXTURES and (_beside(before, cell) or before.has(cell)):
				assert_true(_beside(reach, cell) or reach.has(cell), "%s: the %s at %s" % [key, map.grid[cell], cell])
		# Room to move: at least half the open floor stays open.
		var floor := map.grid.values().filter(func(tile: String) -> bool: return tile == "floor").size()
		assert_gt(reach.size(), floor / 2, "%s keeps its floor" % key)


func test_pieces_are_furniture_never_villagers() -> void:
	for name: String in PunyInterior.interiors()["vignettes"]:
		var piece: Dictionary = PunyInterior.interiors()["vignettes"][name]
		for kind: String in ["rug", "objects", "tops", "lifted"]:
			for part: Array in piece[kind]:
				assert_lt(int(part[2]), 27500, "%s: tile %d is no villager" % [name, int(part[2])])
				assert_lt(int(part[1]), int(piece["size"][1]), name)


func test_the_heros_own_furniture_comes_first() -> void:
	var map := MapData.load_tiered("town_house", [], 1)
	# A pie table where the hero set a bench: the table yields.
	var table: Array = PunyInterior.interiors()["rooms"]["town_house"]["pieces"].filter(func(p: Array) -> bool: return p[0] == "pie_table")[0]
	var bench := Vector2i(int(table[1]), int(table[2]) + 1)
	var dressed := PunyInterior.furnish("town_house", map.grid, PunyInterior.reserved(map, [{"x": bench.x, "y": bench.y}]))
	assert_has(dressed["skipped"], "pie_table")
	assert_false(dressed["blocked"].has(bench))
