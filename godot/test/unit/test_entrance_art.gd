extends GutTest
## Every dungeon's way in reads as an entrance in its setting (PIX-290, Tom:
## « Pas super beau les entrées de donjon, porte du Fernoir et le premier »):
## the shafts' mine mouth and the sea cave's arch set into an unbroken cliff
## rather than a little mound on a lone block, the Ashen Mountain's
## gatehouse from both its sides, the Kings' Vault's black iron door, and
## the frost round the ice cave's stair in Liane's floor. With or without
## the paid pack, and never in the way in or on the road up to it.

## Each way in from the open air, by map and cell: its look.
const MOUTHS := {
	"blackiron": {Vector2i(26, 4): "mine"},
	"saltmere": {Vector2i(6, 23): "sea_cave"},
	"overworld": {Vector2i(48, 6): "mountain_gate"},
	"mountain_road": {Vector2i(17, 30): "mountain_gate", Vector2i(12, 2): "vault_door"},
}
## The sheets free to show anyone (Shade's CC0 overworld and dungeon).
const CC0 := ["world", "dungeon"]


## The ways in `map_id` draws as entrances, as a visit plans them: cell ->
## the plan.
func _planned(map_id: String) -> Dictionary:
	var data := MapData.load_by_id(map_id)
	var view := MapView.new(data, null)
	view.plan(data.spawn)
	var out := {}
	for entrance: Dictionary in view.entrances:
		for cell: Vector2i in entrance["hides"]:
			out[cell] = entrance
	return out


func _way_at(map: MapData, cell: Vector2i) -> Dictionary:
	for way: Dictionary in Ways.on(map):
		if way["at"] == cell:
			return way
	return {}


func test_every_dungeon_s_way_in_is_drawn_in_its_setting() -> void:
	for map_id: String in MOUTHS:
		var planned := _planned(map_id)
		for cell: Vector2i in MOUTHS[map_id]:
			assert_true(planned.has(cell), "%s: the way in at %s is drawn as an entrance" % [map_id, cell])
			if planned.has(cell):
				assert_eq(planned[cell]["look"], MOUTHS[map_id][cell], "%s at %s" % [map_id, cell])
				assert_false(planned[cell]["pieces"].is_empty(), "%s at %s: drawn with pieces" % [map_id, cell])


func test_nothing_it_places_stands_in_the_way_in_or_on_the_road_up_to_it() -> void:
	for map_id: String in MOUTHS:
		var map := MapData.load_by_id(map_id)
		for cell: Vector2i in MOUTHS[map_id]:
			var way := _way_at(map, cell)
			for paid: bool in [true, false]:
				var plan := EntranceArt.plan(map, way, true, paid)
				for block: Vector2i in plan["blocks"]:
					assert_ne(block, way["at"], "%s: nothing stands in the way in" % map_id)
					assert_ne(block, way["from"], "%s: nor on the road up to it" % map_id)
					assert_true(WorldTiles.is_walkable(map.tile_at(block)), "%s: a block is open ground the art stands on" % map_id)
				for piece: Dictionary in plan["pieces"]:
					if piece["cell"] == way["from"]:
						assert_true(piece["flat"], "%s: only what lies flat (the rails) is on the road up to it" % map_id)


func test_a_cave_mouth_sits_in_an_unbroken_cliff() -> void:
	# Tom's shot: the shafts' mouth a small black square on a lone mossy
	# block. The rock runs on either side of each mouth and over it.
	for map_id: String in ["blackiron", "saltmere"]:
		var map := MapData.load_by_id(map_id)
		for cell: Vector2i in MOUTHS[map_id]:
			for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i(-1, -1), Vector2i(1, -1)]:
				assert_eq(map.tile_at(cell + step), "mountain", "%s: rock at %s round the mouth at %s" % [map_id, cell + step, cell])
			assert_true(WorldTiles.is_walkable(map.tile_at(cell + Vector2i.DOWN)), "%s: the road comes up to it" % map_id)


func test_without_the_paid_pack_every_look_is_shade_s_cc0_art() -> void:
	for map_id: String in MOUTHS:
		var map := MapData.load_by_id(map_id)
		for cell: Vector2i in MOUTHS[map_id]:
			for barred: bool in [true, false]:
				for piece: Dictionary in EntranceArt.plan(map, _way_at(map, cell), barred, false)["pieces"]:
					assert_has(CC0, piece["sheet"], "%s at %s: %s" % [map_id, cell, piece])


func test_the_mine_has_its_timbers_rails_and_winch() -> void:
	var map := MapData.load_by_id("blackiron")
	var tiles: Array = EntranceArt.plan(map, _way_at(map, Vector2i(26, 4)), false, true)["pieces"].map(func(piece: Dictionary) -> int: return piece["tile"])
	assert_has(tiles, EntranceArt.MINE_TOP, "the rock and the timber lintel over the dark")
	assert_has(tiles, EntranceArt.MINE_MOUTH, "its posts and the cart at its foot")
	assert_has(tiles, EntranceArt.RAIL, "the rails running out down the road")
	assert_has(tiles, PunyDungeon.WHEEL, "the pithead's winch")
	var cc0: Array = EntranceArt.plan(map, _way_at(map, Vector2i(26, 4)), false, false)["pieces"].map(func(piece: Dictionary) -> int: return piece["tile"])
	assert_has(cc0, EntranceArt.MINE_DOOR, "without the pack, Shade's CC0 mine door in its timber frame")


func test_a_barred_gate_shows_its_portcullis_down_and_the_vault_its_iron() -> void:
	var road := MapData.load_by_id("mountain_road")
	var gate := _way_at(road, Vector2i(17, 30))
	assert_has(_tiles(road, gate, true), EntranceArt.GATE_BARRED, "barred: the portcullis down")
	assert_has(_tiles(road, gate, false), EntranceArt.GATE_OPEN, "open: raised")
	assert_has(_tiles(road, gate, true), Rampart.TOWER[0], "a tower either side")
	var vault := _way_at(road, Vector2i(12, 2))
	assert_has(_tiles(road, vault, true), PunyDungeon.GRILLE, "black iron bars while the Vault is shut")
	assert_does_not_have(_tiles(road, vault, false), PunyDungeon.GRILLE, "a dark doorway once it opens")
	assert_has(_tiles(road, vault, false), PunyDungeon.STATUE, "a stone king keeping it")


func _tiles(map: MapData, way: Dictionary, barred: bool) -> Array:
	return EntranceArt.plan(map, way, barred, true)["pieces"].map(func(piece: Dictionary) -> int: return piece["tile"])


func test_only_dungeon_mouths_and_gates_in_the_rock_are_dressed() -> void:
	var town := MapData.load_by_id("town")
	for way: Dictionary in Ways.on(town):
		assert_eq(EntranceArt.look_of(way), "", "the village's ways are its own: %s" % way["at"])
	var keep := MapData.load_by_id("keep")
	for way: Dictionary in Ways.on(keep):
		assert_eq(EntranceArt.look_of(way), "", "a room's door and stair are its own")


func test_the_ice_cave_s_stair_breathes_frost_and_the_keep_s_does_not() -> void:
	assert_eq(EntranceArt.frosted_stairs(MapData.load_by_id("observatory")), [Vector2i(13, 5)] as Array[Vector2i], "Liane's stair down to the ice cave")
	assert_true(EntranceArt.frosted_stairs(MapData.load_by_id("keep")).is_empty(), "the keep's down to the cellars is dry stone")
	assert_true(EntranceArt.frosted_stairs(MapData.load_by_id("town")).is_empty())
