extends GutTest
## The lookout on the mountain road (PIX-363): its view shows exactly the
## lamps lit on the Reach, each in its kind's colour, and the land each
## ring has healed in its lamp's colour; none while Lantern Night's lamps
## wait for Fafnyr; its spyglass stands on open ground beside the road.

const DAY := 40


## A settlement with the lamps of `places` built (their waystations or
## their own works), on day DAY.
static func _built(places: Array) -> SettlementState:
	var settlement := SettlementState.new()
	for place: String in places:
		settlement.projects.append(Routes.lamp_of(place)["work"])
	return settlement


static func _rings(places: Array, mornings := 9) -> Array[Dictionary]:
	var post := PostState.new()
	for place: String in places:
		post.lit[place] = DAY - mornings
	return Lamps.rings(Routes.MAP, _built(places), post, DAY)


static func _every_lamp() -> Array:
	return Routes.places().filter(func(place: String) -> bool: return not Routes.lamp_of(place).is_empty())


func test_it_shows_exactly_the_lit_lamps_in_their_kinds_colours() -> void:
	var every := _every_lamp()
	assert_gt(every.size(), 2, "lamps to light")
	for lit: Array in [every.slice(0, 2), every]:
		var shown := LookoutScreen.lamps(_rings(lit))
		var places: Array = shown.map(func(lamp: Dictionary) -> String: return lamp["place"])
		places.sort()
		var want := lit.duplicate()
		want.sort()
		assert_eq(places, want, "the lit lamps, no more")
		for lamp: Dictionary in shown:
			var kind := String(Routes.lamp_of(lamp["place"])["kind"])
			assert_eq(lamp["kind"], kind)
			assert_eq(lamp["color"], RouteArt.light_of(kind), "%s burns in its kind's colour" % lamp["place"])
			assert_eq(lamp["cell"], Routes.lamp_of(lamp["place"])["cell"])
	var kinds: Array = LookoutScreen.lamps(_rings(every)).map(func(lamp: Dictionary) -> String: return lamp["kind"])
	assert_true(kinds.has("sea_glass") and kinds.has("ember"), "more than one kind shown: %s" % [kinds])
	assert_eq(LookoutScreen.lamps(_rings([])), [] as Array[Dictionary], "no lamp built, none shown")


func test_lantern_nights_lamps_wait_dark() -> void:
	assert_eq(LookoutScreen.lamps(_rings(_every_lamp()), true), [] as Array[Dictionary])


func test_the_healed_rings_in_their_lamps_colours() -> void:
	var grid := MapData.load_by_id(Routes.MAP).grid
	var rings := _rings(_every_lamp())
	var drawn := LookoutScreen.rings_healed(grid, rings)
	assert_eq(drawn.keys().size(), Lamps.healed(grid, rings).size(), "every healed cell, and only those")
	assert_gt(drawn.size(), 0)
	for ring: Dictionary in rings:
		var own: Array[Dictionary] = [ring]
		var light := RouteArt.light_of(String(ring["kind"]))
		var by_look := {}
		for cell: Vector2i in Lamps.healed(grid, own):
			var color: Color = drawn[cell]
			if Lamps.distance(cell, ring["cell"]) < 2:
				assert_eq(Color(color, 1.0), light, "near %s, its own colour" % ring["place"])
			by_look[Lamps.healed(grid, own)[cell]] = color.a
		if by_look.has("earth") and by_look.has("grove"):
			assert_lt(float(by_look["earth"]), float(by_look["grove"]), "the ring's grown heart shows strongest")
	# A ring lit this morning has healed nothing yet.
	assert_eq(LookoutScreen.rings_healed(grid, _rings(_every_lamp(), 0)), {})


func test_the_spyglass_stands_off_the_road() -> void:
	var road := MapData.load_by_id(Lookout.MAP)
	assert_true(road.is_walkable(Lookout.CELL), "on open ground")
	assert_eq(road.tile_at(Lookout.CELL + Vector2i.RIGHT), "path", "beside the road, where the hero passes")
	assert_ne(road.tile_at(Lookout.CELL), "path", "off the road")
	assert_false(road.portals.has(Lookout.CELL), "no way out under it")
	assert_eq(Lookout.texture().get_size(), Vector2(16, Lookout.PIECE.size()))
