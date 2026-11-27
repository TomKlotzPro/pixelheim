extends GutTest
## MapView.plan (PIX-136): before anything is drawn, a visit marks on the map
## what its art covers, and never lands the hero inside it.


func test_an_arrival_on_a_blocked_cell_lands_at_the_spawn() -> void:
	var map := MapData.load_by_id("town")
	var wall := Vector2i(-1, -1)
	for cell: Vector2i in map.grid:
		if not map.is_walkable(cell):
			wall = cell
			break
	assert_ne(wall, Vector2i(-1, -1), "the town has walls")
	var view := MapView.new(map, null)
	assert_eq(view.plan(wall), map.spawn)


func test_an_open_arrival_stays() -> void:
	var map := MapData.load_by_id("town")
	var view := MapView.new(map, null)
	assert_eq(view.plan(map.spawn), map.spawn)


func test_blocking_scatter_is_covered_and_never_under_the_hero() -> void:
	var map := MapData.load_by_id("overworld")
	var view := MapView.new(map, null)
	var arrival := view.plan(map.spawn)
	assert_false(view.solid_scatter.is_empty(), "the overworld's fields grow bushes and stumps")
	for cell: Vector2i in view.solid_scatter:
		assert_true(map.covered.has(cell), "scatter at %s blocks" % cell)
	assert_false(view.solid_scatter.has(arrival))
	assert_true(map.is_walkable(arrival))


func test_a_dungeon_floor_plans_no_houses_or_scatter() -> void:
	var map := MapData.load_by_id("vault_1")
	var view := MapView.new(map, null)
	view.plan(map.spawn)
	assert_true(view.buildings["pieces"].is_empty())
	assert_true(view.solid_scatter.is_empty())


func test_a_cell_centre_is_half_a_tile_in() -> void:
	assert_eq(MapView.center(Vector2i(2, 3)), Vector2(40, 56))


## PIX-286: Tom found things on the ground a bit big - a herb lay as big as
## the hero. A pickup is its icon at half size, half a cell and narrower
## than the hero's head, its pixels on the art's grid, on a shadow (only
## under something), with a glint a pixel of the art.
func test_a_pickup_lies_half_a_cell() -> void:
	var icon := ImageTexture.create_from_image(Image.create(16, 16, false, Image.FORMAT_RGBA8))
	var root: Node2D = autofree(PatchesLayer.pickup(icon, Vector2i(3, 4)))
	assert_eq(root.position, MapView.center(Vector2i(3, 4)), "in the middle of its cell")
	var item: Sprite2D = root.get_node("item")
	var size: Vector2 = icon.get_size() * item.scale
	assert_eq(size, Vector2.ONE * MapView.TILE / 2.0, "half a cell")
	var corner: Vector2 = root.position + item.position - size / 2.0
	assert_eq(corner, corner.round(), "on the art's grid")
	# The hero's head: the figure's top seven rows (PunyArt.HEADS' cut).
	var figure := PunyArt.frames(PunyArt.plain("warrior")).get_frame_texture("idle_down", 0).get_image()
	var used := figure.get_used_rect()
	var head := figure.get_region(Rect2i(used.position, Vector2i(used.size.x, 7))).get_used_rect()
	assert_lt(size.x, float(head.size.x), "narrower than the hero's head")
	assert_true(root.get_children().any(func(node: Node) -> bool: return node is Sprite2D and node != item), "on a shadow")
	var glint: ColorRect = item.get_child(0)
	assert_eq(glint.size * item.scale, Vector2.ONE, "a glint, a pixel of the art")
	var bare: Node2D = autofree(PatchesLayer.pickup(null, Vector2i(3, 4)))
	assert_eq(bare.get_child_count(), 1, "without the paid icon, only the glint: no shadow of nothing")


## Camps (PIX-142, PIX-554): every day pack's camp, on every map, is a tent
## two cells wide in its region's cloth, a fire a cell clear of it (so its
## light casts the tent's shadow), a bedroll by the
## tent and a log by the fire: each on open ground of the pack's region,
## off its own square, the doors and a mine's rails, near its home,
## blocking like the art it is.
func test_packs_camp_beside_their_homes() -> void:
	var camps := 0
	var casting := 0
	var maps := {}
	for spawn: Dictionary in Bestiary._data()["spawns"]:
		maps[spawn["mapId"]] = true
	for map_id: String in maps:
		var map := MapData.load_by_id(map_id)
		var view := MapView.new(map, null)
		view.plan(map.spawn)
		for spawn: Dictionary in Bestiary.spawns_on(map_id):
			var home := Vector2i(spawn["x"], spawn["y"])
			assert_true(map.is_walkable(home))
			# PIX-566: nor on any cell its foes stand on, nor a fire straight
			# behind one (a foe at rest stood in its ring, the flame at its head).
			# Where they stand on the bare map, and with everything laid.
			var stands := Packs.stands(MapData.load_by_id(map_id), spawn) + Packs.stands(map, spawn)
			for offset: Vector2i in CampsLayer.PACK_SQUARE:
				stands.append(home + offset)
			for cell: Vector2i in stands:
				assert_false(view.camps.has(cell), "%s's square stays open at %s" % [spawn["id"], cell])
				assert_ne(view.camps.get(cell + Vector2i.UP, {}).get("kind", ""), "fire", "no fire straight behind %s's foe at %s" % [spawn["id"], cell])
		var fires := 0
		var rails: Array[Vector2i] = []
		for working: Dictionary in AshLand.WORKINGS.get(map_id, []):
			rails.append_array(AshLand.rail_cells(working["rails"] as Array))
		for tent: Vector2i in view.camps:
			var camp: Dictionary = view.camps[tent]
			if camp["kind"] != "camp":
				continue
			camps += 1
			var spawn: Dictionary = Bestiary.spawns_on(map_id).filter(func(row: Dictionary) -> bool: return row["id"] == camp["spawn"])[0]
			var home := Vector2i(spawn["x"], spawn["y"])
			var region := map.region_at(home)
			var who := "%s's camp" % spawn["id"]
			assert_false(Packs.of_the_night(spawn), "%s: a night pack keeps none (PIX-252)" % who)
			var art: String = camp["art"]
			assert_eq(art, CampsLayer.TENTS.get(region, CampsLayer.TENT), "%s: its tent in its region's cloth" % who)
			assert_eq(HamletArt.cells_wide(art), 2, "%s: a tent two cells wide" % who)
			assert_gt(HamletArt.inked(art).size.y, 20, "%s: a tent the folk's size" % who)
			var beside: Dictionary = view.camps.get(tent + Vector2i.RIGHT, {})
			assert_eq(beside.get("kind", ""), "beside", "%s: its tent's other cell" % who)
			for part: String in ["fire", "bed", "log"]:
				assert_true(camp.has(part), "%s has its %s" % [who, part])
			if not (camp.has("fire") and camp.has("bed") and camp.has("log")):
				continue
			fires += 1
			var fire: Vector2i = camp["fire"]
			var bed: Vector2i = camp["bed"]
			var seat: Vector2i = camp["log"]
			assert_eq(view.camps[fire]["kind"], "fire", who)
			assert_eq(view.camps[bed]["kind"], "bedroll", who)
			assert_eq(view.camps[seat]["kind"], "log", who)
			var apart := mini(_apart(fire, tent), _apart(fire, tent + Vector2i.RIGHT))
			assert_lte(apart, 2, "%s: its fire by its tent" % who)
			casting += int(apart == 2)
			assert_true(_apart(bed, tent) <= 1 or _apart(bed, tent + Vector2i.RIGHT) <= 1, "%s: its bedroll by its tent" % who)
			assert_eq(_apart(seat, fire), 1, "%s: its log by its fire" % who)
			# PIX-563: off the road, its stash too.
			for cell: Vector2i in [tent, tent + Vector2i.RIGHT, fire, bed, seat, camp.get("stash", tent)]:
				assert_false(map.tile_at(cell) in CampsLayer.ROADS, "%s at %s off the road" % [who, cell])
			for cell: Vector2i in [tent, tent + Vector2i.RIGHT, fire, bed, seat]:
				assert_eq(map.region_at(cell), region, "%s at %s on its region" % [who, cell])
				assert_lte(_apart(cell, home), CampsLayer.CAMP_REACH, "%s at %s near its home" % [who, cell])
				assert_false(cell - home in CampsLayer.PACK_SQUARE, "%s at %s off the pack's square" % [who, cell])
				assert_false(cell in rails, "%s at %s off the mine's rails" % [who, cell])
		assert_eq(fires, Bestiary.spawns_on(map_id).filter(func(spawn: Dictionary) -> bool: return not Packs.of_the_night(spawn)).size() if map.style != "cave" else 0, "%s: a fire to each day camp" % map_id)
		for cell: Vector2i in view.camps:
			assert_true(map.covered.has(cell), "a camp at %s blocks" % cell)
			assert_false(map.portals.has(cell))
	assert_eq(camps, 38, "38 camps under the sky")
	assert_eq(casting, camps, "every fire a cell clear of its tent")


static func _apart(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


## Drawn (PIX-554): each camp's fire burns with one light, as far as the
## torch it took the place of (PIX-221), so no light was added; its tent
## casts by day, and of the camp only the tent and the folk stand in its
## fire's light at night (what lies low casts nothing).
func test_a_camp_drawn_burns_one_light_and_its_tent_casts() -> void:
	var map := MapData.load_by_id("deepwood")
	var root := Node2D.new()
	add_child_autofree(root)
	var actors := Node2D.new()
	root.add_child(actors)
	var view := MapView.new(map, actors)
	view.plan(map.spawn)
	view.build(root)
	var lights := actors.find_children("*", "PointLight2D", true, false)
	for tent: Vector2i in view.camps:
		var camp: Dictionary = view.camps[tent]
		if camp["kind"] != "camp":
			continue
		var fire: Vector2i = camp["fire"]
		var cell := Rect2(Vector2(fire * MapView.TILE), Vector2.ONE * MapView.TILE)
		var burning := lights.filter(func(light: PointLight2D) -> bool: return cell.has_point(light.global_position - actors.global_position))
		assert_eq(burning.size(), 1, "%s's fire burns with one light" % camp["spawn"])
		if burning.size() == 1:
			assert_almost_eq((burning[0] as PointLight2D).texture_scale, CampsLayer.CAMP_LIGHT * 2.0 / Lights.TEXTURE_PX, 0.001, "as far as the torch's")
		var foot := Vector2(tent * MapView.TILE) + Vector2(MapView.TILE, MapView.TILE)
		assert_true(view.casters.any(func(caster: Vector4) -> bool: return Vector2(caster.x, caster.y) == foot), "%s's tent casts by day" % camp["spawn"])
	var low := 0
	for body: Node in actors.find_children("*", "StaticBody2D", true, false):
		if body.get_meta("low", false):
			low += 1
			assert_eq(body.get_parent().find_children("*", "LightOccluder2D", true, false).size(), 0, "what lies low in a camp casts nothing at night")
	assert_eq(low, view.camps.values().filter(func(piece: Dictionary) -> bool: return piece["kind"] in CampsLayer.LOW).size(), "a camp's fire, bedroll and log lie low")


## PIX-538: every plain start logged « The object does not have any 'meta'
## values with the key 'light' » twice as the Night of Ash began: the hall's
## panes in the village far off carry no light, and get_meta with a null
## default still logs for a missing key.
func test_the_far_halls_panes_go_dark_without_an_error() -> void:
	var was := GameState.progression.prologue
	GameState.progression.prologue = Prologue.SCAVENGER
	var view := MapView.new(MapData.load_by_id("overworld"), null)
	view.skyline = {"hall": Rect2i(10, 10, 4, 4)}
	var pane: Sprite2D = autofree(Sprite2D.new())
	pane.position = Vector2(11, 11) * MapView.TILE
	view.panes.append(pane)
	CampsLayer.new().set_night(view, true)
	GameState.progression.prologue = was
	assert_false(pane.visible, "dark on the night nobody is in the hall")
	assert_engine_error_count(0, "a pane with no light of its own")
