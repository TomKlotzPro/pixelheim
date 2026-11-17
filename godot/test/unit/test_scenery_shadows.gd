extends GutTest
## The scenery's shadows (PIX-449): under each tree, bush and lamp and off
## each house, one group on the ground of a map under the sky, under the
## cliffs, the crowns and the houses, over what lies flat; houses that
## touch cast one shadow; gone at night; none indoors.


var _tier := 0


func before_all() -> void:
	KeptGround.forget()
	# The Hamlet, its lamps up (the Ashes have none).
	_tier = GameState.settlement.town_tier
	GameState.settlement.town_tier = 1


func after_all() -> void:
	GameState.settlement.town_tier = _tier
	KeptGround.forget()


func _draw(id: String) -> MapView:
	var data := MapData.load_by_id(id)
	var root := Node2D.new()
	add_child_autofree(root)
	var standing := Node2D.new()
	root.add_child(standing)
	var view := MapView.new(data, standing)
	view.plan(data.spawn)
	view.build(root)
	return view


func test_the_village_lays_its_shadows_on_the_ground() -> void:
	var view := _draw("town")
	assert_true(view.layers.has("shadows"), "the village has shadows")
	assert_gt(view.casters.size(), 0, "its lamps cast them, with the pack or without")
	var group: CanvasGroup = view.layers["shadows"]
	assert_eq(group.get_parent(), view.ground, "on the ground, under every actor")
	assert_lt(group.get_index(), view.rim_layer.get_index(), "under the cliffs and the forest's crowns")
	if view.layers.has("pieces"):
		assert_lt(group.get_index(), (view.layers["pieces"] as Node).get_index(), "under the houses")
		assert_gt(ShadowsLayer.houses_of(view.buildings["pieces"]).size(), 0, "the houses cast theirs")
	for child: Node in view.ground.get_children().slice(group.get_index() + 1):
		assert_true(child is TileMapLayer, "%s, lying flat, is under the shadows" % child)


func test_they_go_at_night_and_come_back_by_day() -> void:
	var view := _draw("town")
	var group: CanvasGroup = view.layers["shadows"]
	view.set_night(true)
	assert_false(group.visible, "the lamps take over")
	view.set_night(false)
	assert_true(group.visible, "the sun again")


func test_a_room_casts_none() -> void:
	var view := _draw("town_inn")
	assert_false(view.layers.has("shadows"))


func test_houses_that_touch_cast_one_shadow() -> void:
	var pieces := {}
	# A house with a wing down its east side, and one apart.
	for cell: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 2)]:
		pieces[cell] = 1
	pieces[Vector2i(6, 0)] = 1
	var houses := ShadowsLayer.houses_of(pieces)
	assert_eq(houses.size(), 2)
	assert_has(houses, Rect2i(0, 0, 3, 3), "the house and its wing, by their bounds")
	assert_has(houses, Rect2i(6, 0, 1, 1), "the one apart")


## PIX-524: what the settlements put up casts as the trees do (PIX-521's
## audit: only trees, lamps and houses did), with the pack or without:
## Saltmere's stall, racks, cart and keg, the town's crates and kegs, each
## from the bottom of its own cells.
func test_the_dressing_casts() -> void:
	for id: String in ["saltmere", "town"]:
		var view := _draw(id)
		var feet := {}
		for caster: Vector4 in view.casters:
			feet[Vector2i(floori(caster.x / MapView.TILE), floori((caster.y - 1.0) / MapView.TILE))] = true
		var standing: Array = view.hamlet["pieces"].filter(func(piece: Dictionary) -> bool:
			return piece["kind"] == "stand" and piece.has("art") and piece["art"] != "lamp_post")
		if id == "saltmere":
			assert_gt(standing.size(), 5, "Saltmere's quay dressed")
		for piece: Dictionary in standing:
			var cells: Array = piece["cells"]
			assert_true(cells.any(func(cell: Vector2i) -> bool: return feet.has(cell)), "%s's %s at %s casts" % [id, piece["art"], piece["cell"]])
		for cell: Vector2i in view.data.grid:
			if view.data.tile_at(cell) in ["barrel", "crate"]:
				assert_true(feet.has(cell), "%s's %s at %s casts" % [id, view.data.tile_at(cell), cell])
