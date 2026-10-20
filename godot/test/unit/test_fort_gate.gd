extends GutTest
## Greyhold's way in (PIX-337, Tom: « revamp l'entrée ici »): the road came
## up to one block of the fort's wall with a dark notch at its foot, two
## lamps behind it on the bare yard. Now it is a gatehouse, a tower either
## side, its lamps before them, and the road runs on through it, open, up
## the yard to the keep. Pure: none of it needs the paid art.

const GATE := Vector2i(37, 26)
const TOWERS := [Vector2i(36, 26), Vector2i(38, 26)]
const TOPS := [Vector2i(36, 25), Vector2i(38, 25)]
const LAMPS := [Vector2i(35, 27), Vector2i(39, 27)]
## The road through: up from the Reach's road to the yard's crossing.
const ROAD := [Vector2i(37, 29), Vector2i(37, 28), Vector2i(37, 27), GATE, Vector2i(37, 25), Vector2i(37, 24)]


func _view() -> MapView:
	var map := MapData.load_by_id("greyhold")
	var view := MapView.new(map, null)
	view.plan(map.spawn)
	return view


func test_a_gatehouse_in_the_fort_wall() -> void:
	var view := _view()
	var gates: Array = view.rampart["gates"]
	assert_eq(gates.size(), 1, "one gate in the fort's wall")
	assert_eq(gates[0]["cells"], [GATE])
	assert_eq(gates[0]["towers"], TOWERS, "between two towers")
	assert_eq(view.rampart["pieces"][GATE], Rampart.GATE, "its portcullis up")
	for side in 2:
		assert_eq(view.rampart["pieces"][TOWERS[side]], Rampart.TOWER[side])
		assert_eq(view.rampart["pieces"][TOPS[side]], Rampart.ROOF[side], "a roof on each tower")
		assert_true(view.data.covered.has(TOPS[side]), "the tower's top blocks where it stands")
	assert_false(view.rampart["fallback"].has(GATE), "without the pack the gate between the towers is open, not a block of wall")
	assert_eq(view.rampart["pieces"].size(), 5, "the gatehouse alone: the rest of the wall stays Shade's castle run")


func test_the_way_through_is_open() -> void:
	var view := _view()
	var map := view.data
	for cell: Vector2i in ROAD:
		assert_true(map.is_walkable(cell), "the road open at %s" % cell)
		assert_false(view.field.has(cell), "no decor grows at %s" % cell)
		assert_false(view.outdoor_props["drawn"].has(cell), "no prop stands at %s" % cell)
		assert_false(cell in view.hamlet["blocks"], "no dressing at %s" % cell)
	assert_eq(PunyTerrain.ground_at(map.grid, GATE), "dirt", "the gate stands on the road")
	assert_eq(Streets.plan("greyhold", map.grid, 0).get(Vector2i(37, 25)), "sandstone", "the road paved on through the yard")


func test_its_lamps_stand_before_its_towers() -> void:
	var map := MapData.load_by_id("greyhold")
	var lamps: Array = PunyProps.plan(map.grid)["props"].filter(func(prop: Dictionary) -> bool: return prop["kind"] == "lamp").map(func(prop: Dictionary) -> Vector2i: return prop["cell"])
	for cell: Vector2i in LAMPS:
		assert_eq(map.tile_at(cell), "lamp", "a lamp at %s" % cell)
		assert_has(lamps, cell, "lit at night")
	for cell: Vector2i in TOPS:
		assert_ne(map.tile_at(cell), "lamp", "none under the towers' roofs at %s" % cell)
