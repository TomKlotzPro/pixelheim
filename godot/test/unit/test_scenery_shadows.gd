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


## Where `view`'s casters stand: the cells their feet are on the bottom of.
func _feet(view: MapView) -> Dictionary:
	var feet := {}
	for caster: Vector4 in view.casters:
		feet[Vector2i(floori(caster.x / MapView.TILE), floori((caster.y - 1.0) / MapView.TILE))] = true
	return feet


## PIX-524: what the settlements put up casts as the trees do (PIX-521's
## audit: only trees, lamps and houses did), with the pack or without:
## Saltmere's stall, racks, cart and keg, the town's crates and kegs, its
## roofed well, the shrine's knight and the market's crates, its boards and
## post box, each from the bottom of its own cells.
func test_the_dressing_casts() -> void:
	# The Post open, so the town's post box stands among its camps.
	var quests := GameState.progression.quests.duplicate()
	GameState.progression.quests["letter_wenna"] = {"progress": 1, "done": true}
	for id: String in ["saltmere", "town"]:
		var view := _draw(id)
		var feet := _feet(view)
		# The camps' tents, the town's boards and its post box (CampsLayer);
		# what lies low in a camp casts none (PIX-554).
		if id == "town":
			assert_true(view.camps.has(Post.box_cell()), "the post box stands")
		for cell: Vector2i in view.camps:
			if view.camps[cell]["kind"] not in CampsLayer.LOW + ["beside"]:
				# A tent two cells wide casts from the middle of its foot.
				assert_true(feet.has(cell) or feet.has(cell + Vector2i.RIGHT), "%s's %s at %s casts" % [id, view.camps[cell]["kind"], cell])
		var standing: Array = view.hamlet["pieces"].filter(func(piece: Dictionary) -> bool:
			return piece["kind"] == "stand" and piece.has("art") and piece["art"] != "lamp_post")
		if id == "saltmere":
			assert_gt(standing.size(), 5, "Saltmere's quay dressed")
		for piece: Dictionary in standing:
			var cells: Array = piece["cells"]
			assert_true(cells.any(func(cell: Vector2i) -> bool: return feet.has(cell)), "%s's %s at %s casts" % [id, piece["art"], piece["cell"]])
		for prop: Dictionary in view.outdoor_props["props"]:
			if prop["kind"] in ["barrel", "crate", "well", "shrine", "stall"]:
				var covers: Array = prop["covers"]
				assert_true(covers.any(func(cell: Vector2i) -> bool: return feet.has(cell)), "%s's %s at %s casts" % [id, prop["kind"], prop["cell"]])
	GameState.progression.quests = quests


## PIX-524: the Post's road casts too, its signposts and a waystation built
## (its hut, bench, post box and ember lamp), as flow waystation-bench sets
## it up; and the Mirefen's stilt huts.
func test_the_roads_and_the_fen_cast() -> void:
	var post := GameState.post
	var projects := GameState.settlement.projects.duplicate()
	var prologue := GameState.progression.prologue
	GameState.progression.prologue = Prologue.DONE
	GameState.post = PostState.new()
	Routes.tally(GameState.post, "saltmere", "bram", 6)
	Routes.raise_signs(GameState.post)
	GameState.settlement.projects.assign(Town.done_projects(GameState.settlement) + ["waystation_saltmere"])
	var reach := _draw(Routes.MAP)
	GameState.post = post
	GameState.settlement.projects.assign(projects)
	GameState.progression.prologue = prologue
	var feet := _feet(reach)
	var kinds: Array = reach.routes["pieces"].map(func(piece: Dictionary) -> String: return piece["kind"])
	for kind: String in ["signpost", "hut", "bench", "box", "lamp"]:
		assert_has(kinds, kind, "the road has its %s" % kind)
	for piece: Dictionary in reach.routes["pieces"]:
		var cells: Array = piece["cells"]
		assert_true(cells.any(func(cell: Vector2i) -> bool: return feet.has(cell)), "the road's %s at %s casts" % [piece["kind"], piece["cell"]])
	var fen := _feet(_draw("mirefen"))
	for hut: Vector2i in MireDressing.HUTS:
		assert_true(fen.has(hut) or fen.has(hut + Vector2i.RIGHT), "the Mirefen's stilt hut at %s casts" % hut)
