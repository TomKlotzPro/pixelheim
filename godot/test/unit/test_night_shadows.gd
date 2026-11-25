extends GutTest
## The shadows the lamps cast in the dark (PIX-490): what
## blocks a light and from what footprint (NightShadows), the occluders a
## map lays (NightShadowsLayer), what a shadow falls on, and the few lights
## that cast (the cap, the LightRig).


var _tier := 0
var _shadows := true


func before_all() -> void:
	KeptGround.forget()
	# The Hamlet, its lamps up (the Ashes have none).
	_tier = GameState.settlement.town_tier
	GameState.settlement.town_tier = 1
	_shadows = GameState.settings.shadows


func after_all() -> void:
	GameState.settlement.town_tier = _tier
	GameState.settings.shadows = _shadows
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


func _cells(rows: Array) -> Dictionary:
	var out := {}
	for y in rows.size():
		for x in String(rows[y]).length():
			if String(rows[y])[x] == "#":
				out[Vector2i(x, y)] = true
	return out


# --- What blocks ----------------------------------------------------------------

func test_what_stands_tall_blocks_and_what_lies_flat_or_low_does_not() -> void:
	for tile: String in ["mountain", "wall", "rock", "roof", "roof_thatch", "sign_inn", "statue", "wreck"]:
		assert_true(NightShadows.blocks(tile), "%s blocks a light" % tile)
	for tile: String in ["water", "sea", "garden", "fence", "counter", "grass", "forest", "door", "lamp", "coals"]:
		assert_false(NightShadows.blocks(tile), "%s lets it by" % tile)


func test_a_cell_the_hero_can_stand_on_never_blocks() -> void:
	for tile: String in WorldTiles.TILE_INFO:
		if WorldTiles.is_walkable(tile):
			assert_false(NightShadows.solid({Vector2i.ZERO: tile}, {}, [], true).has(Vector2i.ZERO), "%s: the lantern would be shut in" % tile)


func test_a_prop_blocks_by_its_foot_not_its_cell() -> void:
	var grid := {Vector2i(0, 0): "wall", Vector2i(1, 0): "wall"}
	assert_eq(NightShadows.solid(grid, {Vector2i(1, 0): true}, [], true).keys(), [Vector2i(0, 0)])


func test_a_house_blocks_by_the_ground_it_stands_on() -> void:
	assert_eq(NightShadows.house_foot(Rect2i(3, 2, 6, 5)), Rect2i(3, 5, 6, 2), "the lowest rows of a house five rows tall")
	assert_eq(NightShadows.house_foot(Rect2i(0, 0, 4, 1)), Rect2i(0, 0, 4, 1), "a low one whole")
	var grid := {}
	for y in 4:
		for x in 3:
			grid[Vector2i(x, y)] = "door" if Vector2i(x, y) == Vector2i(1, 3) else "roof"
	var house := Rect2i(0, 0, 3, 4)
	var solid := NightShadows.solid(grid, {}, [house], true)
	assert_false(solid.has(Vector2i(0, 0)), "its roof's rows let the light by")
	assert_true(solid.has(Vector2i(0, 3)) and solid.has(Vector2i(2, 2)), "its foot blocks it")
	assert_false(solid.has(Vector2i(1, 3)), "but for its door, which the hero stands in")
	assert_true(NightShadows.solid(grid, {}, [house], false).is_empty(), "nothing where no house is drawn (without the paid art)")


# --- Footprint shapes -----------------------------------------------------------

func test_a_block_of_cells_is_one_outline() -> void:
	var loops := NightShadows.outlines(_cells(["###", "###"]))
	assert_eq(loops.size(), 1, "one occluder for six cells")
	assert_eq(Array(loops[0]), [Vector2(0, 0), Vector2(3, 0), Vector2(3, 2), Vector2(0, 2)], "its four corners, clockwise")


func test_blocks_apart_are_outlines_apart_and_a_hole_has_its_own() -> void:
	assert_eq(NightShadows.outlines(_cells(["#.#"])).size(), 2)
	var ring := NightShadows.outlines(_cells(["###", "#.#", "###"]))
	assert_eq(ring.size(), 2, "the ring's rim and its yard")
	var turns := ring.map(func(loop: PackedVector2Array) -> bool: return Geometry2D.is_polygon_clockwise(loop))
	assert_ne(turns[0], turns[1], "wound against each other: the block on the same side of every edge")


func test_blocks_that_touch_at_a_corner_each_close() -> void:
	var loops := NightShadows.outlines(_cells(["#.", ".#"]))
	assert_eq(loops.size(), 2)
	for loop in loops:
		assert_eq(loop.size(), 4, "a square each")


func test_every_edge_of_a_map_is_in_one_outline() -> void:
	var data := MapData.load_by_id("seacave")
	var solid := NightShadows.solid(data.grid, {}, [], true)
	var edges := 0
	for cell: Vector2i in solid:
		for side: Array in NightShadows.SIDES:
			edges += int(not solid.has(cell + side[0]))
	var walked := 0.0
	for loop in NightShadows.outlines(solid):
		for i in loop.size():
			walked += loop[i].distance_to(loop[(i + 1) % loop.size()])
	assert_gt(edges, 0)
	assert_eq(roundi(walked), edges, "each edge between rock and floor once")


func test_what_stands_casts_from_its_foot() -> void:
	assert_eq(NightShadows.foot_of(Vector2(16, 16)), Vector2.ZERO, "a tuft or a log is too low")
	assert_ne(NightShadows.foot_of(Vector2(16, 16), true), Vector2.ZERO, "a tree a cell tall isn't (Shade's free ones)")
	var tree := NightShadows.foot_of(Vector2(32, 32))
	assert_between(tree.x, 4.0, 12.0, "a trunk, not the crown's width")
	assert_lt(tree.y, 6.0)
	assert_eq(NightShadows.foot_of_body(Vector2(12, 11)), Vector2(16, 11), "a prop's box, as wide as its cell: a stall's two feet meet")


func test_a_foot_has_no_inside_and_blocks_every_way() -> void:
	var outline := NightShadows.outline(Vector2(8, 4))
	assert_eq(outline.size(), 4, "one stroke")
	# Both diagonals of its box are in it.
	var strokes: Array = []
	for i in outline.size() - 1:
		strokes.append([outline[i], outline[i + 1]])
	for ray: Array in [[Vector2(-10, 0), Vector2(10, 0)], [Vector2(0, -10), Vector2(0, 10)], [Vector2(-10, -1.5), Vector2(10, 1.5)], [Vector2(-3, -10), Vector2(-3, 10)], [Vector2(3.5, -10), Vector2(3.9, 10)]]:
		assert_true(strokes.any(func(stroke: Array) -> bool:
			return Geometry2D.segment_intersects_segment(ray[0], ray[1], stroke[0], stroke[1]) != null), "%s is stopped" % [ray])


func test_what_holds_a_light_casts_none() -> void:
	var foot := Rect2(2, 5, 12, 11)
	assert_true(NightShadows.holds_light(foot, PackedVector2Array([Vector2(8, 12)])), "a lamp's post")
	assert_false(NightShadows.holds_light(foot, PackedVector2Array([Vector2(40, 12)])), "a barrel a lamp stands by")


func test_a_light_in_or_against_a_wall_casts_none() -> void:
	var solid := {Vector2i(2, 2): true}
	assert_true(NightShadows.shut_in(solid, Vector2(2.5, 2.5)), "in it")
	assert_true(NightShadows.shut_in(solid, Vector2(2.5, 3.05)), "against it")
	assert_false(NightShadows.shut_in(solid, Vector2(2.5, 3.2)), "a wall torch, three pixels below its wall")


# --- The lights that cast -------------------------------------------------------

func test_only_the_nearest_lamps_cast() -> void:
	var far := PackedFloat32Array([200.0, 30.0, 500.0, 90.0, 60.0, 31.0])
	assert_eq(Array(NightShadows.nearest(far, 3)), [1, 5, 4], "the three nearest")
	assert_eq(Array(NightShadows.nearest(far, 0)), [], "none with no room")
	assert_eq(Array(NightShadows.nearest(PackedFloat32Array([NightShadows.REACH + 1.0]), 3)), [], "none past the screen")
	assert_eq(Array(NightShadows.nearest(PackedFloat32Array([50.0, 50.0]), 1)), [0], "of two as near, the same one every run")


func test_a_lamps_shadows_fade_in_and_out_and_wait_for_room() -> void:
	var step := NightShadows.FADE / 4.0
	assert_almost_eq(NightShadows.faded(0.0, true, true, step), 0.25, 0.001, "in")
	assert_eq(NightShadows.faded(0.9, true, false, step), 1.0, "one already casting goes on")
	assert_eq(NightShadows.faded(0.0, true, false, step), 0.0, "one wanted waits while the cap is full")
	assert_almost_eq(NightShadows.faded(1.0, false, true, step), 0.75, 0.001, "out")
	assert_eq(NightShadows.faded(0.1, false, true, step), 0.0)


func test_a_shadow_is_never_black() -> void:
	var left := NightShadows.left_in_shadow(Lights.LANTERN, Lights.LANTERN_ENERGY, 1.0)
	assert_gt(left.a, 0.0, "some of the light is left in it")
	assert_lt(left.a, 0.5)
	assert_almost_eq(left.r, Lights.LANTERN.r * Lights.LANTERN_ENERGY, 0.001, "in the light's colour at its strength")
	assert_eq(NightShadows.left_in_shadow(Lights.LAMP, 0.4, 0.0).a, 1.0, "none taken while it doesn't cast")


# --- On a map ---------------------------------------------------------------------

func test_a_map_lays_its_occluders_from_what_stands() -> void:
	var view := _draw("town")
	var laid := NightShadowsLayer.laid(view)
	assert_gt(laid["feet"], 20, "at the feet of what stands")
	assert_gt(laid["walls"], 0, "and round its walls")
	assert_eq(view.actors.find_children("*", "LightOccluder2D", true, false).size(), laid["feet"])
	for occluder: LightOccluder2D in view.actors.find_children("*", "LightOccluder2D", true, false):
		assert_eq(occluder.occluder_light_mask, NightShadows.SCENERY)
		assert_false(occluder.occluder.closed, "a foot has no inside")
	for occluder: Node in view.under.get_children():
		if occluder is LightOccluder2D:
			assert_eq((occluder as LightOccluder2D).occluder.cull_mode, OccluderPolygon2D.CULL_COUNTER_CLOCKWISE, "a wall facing the light stays lit")
			# A block's outline blocks the lamps and the lantern, never the
			# lightning (PIX-491): one house laid the whole square in shadow.
			assert_eq((occluder as LightOccluder2D).occluder_light_mask & NightShadows.SKY, 0)
			assert_ne((occluder as LightOccluder2D).occluder_light_mask & NightShadows.LANTERN, 0)
			assert_ne((occluder as LightOccluder2D).occluder_light_mask & NightShadows.LAMP, 0)


## PIX-505's review: the well's body grew to its roof and it cast as a solid
## block three cells tall, the green east of it dark from the roof's top.
func test_the_roofed_well_casts_from_its_rim() -> void:
	if not PunyTown.available():
		pass_test("the roofed well is the paid pack's")
		return
	var well: Node2D = _draw("town").prop_nodes[Vector2i(34, 31)]
	assert_eq(well.find_children("*", "CollisionShape2D", true, false).size(), 2, "the hero is kept off the rim and the roof")
	var cast := well.find_children("*", "LightOccluder2D", true, false)
	assert_eq(cast.size(), 1)
	var occluder: LightOccluder2D = cast[0]
	assert_eq((occluder.occluder.polygon[0] * 2.0).abs().y, 16.0, "the rim's height, not the picture's")
	assert_eq(occluder.position.y, -8.0, "at the rim, the root standing on its foot's bottom")


func test_a_lamp_casts_and_never_blocks_itself() -> void:
	var view := _draw("town")
	var lamps := view.under.find_children("*", "PointLight2D", true, false).filter(
		func(light: Node) -> bool: return light.get_meta("casts", false))
	assert_gt(lamps.size(), 0, "the street lamps may cast")
	var lights := PackedVector2Array()
	for lamp: PointLight2D in lamps:
		lights.append(NightShadowsLayer._place(lamp, view.under))
	for occluder: LightOccluder2D in view.actors.find_children("*", "LightOccluder2D", true, false):
		var at := NightShadowsLayer._place(occluder, view.actors)
		for light in lights:
			assert_gt(at.distance_to(light), 6.0, "no foot under a lamp's own flame")
	for window: PointLight2D in view.under.find_children("*", "PointLight2D", true, false):
		if not window.get_meta("flicker", false):
			assert_false(window.get_meta("casts", false), "a window's spill casts none")


func test_a_flame_against_what_stands_lights_softly() -> void:
	# PIX-495: the camp's torch east of the gate burns 8 px from its tent's
	# foot, whose shadow was a hard-edged wedge a quarter of the pool wide.
	assert_true(NightShadows.holds_light(Rect2(0, 0, 18, 11), PackedVector2Array([Vector2(-7, 15)]), NightShadows.AGAINST), "a torch against a tent")
	assert_false(NightShadows.holds_light(Rect2(0, 0, 18, 11), PackedVector2Array([Vector2(-23, 5)]), NightShadows.AGAINST), "one a cell and a half off")
	var view := _draw("overworld")
	# PIX-554: that camp's fire now burns a cell clear of its tent (CampsLayer.plan_camps).
	var fire_cell := Vector2i(-1, -1)
	for cell: Vector2i in view.camps:
		if (view.camps[cell] as Dictionary).get("spawn", "") == "forest_1":
			fire_cell = view.camps[cell]["fire"]
	var fire: PointLight2D = null
	var casting := 0
	var feet: Array[Rect2] = []
	for occluder: LightOccluder2D in view.actors.find_children("*", "LightOccluder2D", true, false):
		var size := (occluder.occluder.polygon[0] * 2.0).abs()
		feet.append(Rect2(NightShadowsLayer._place(occluder, view.actors) - size / 2.0, size))
	for root: Node in [view.under, view.actors]:
		for light: PointLight2D in root.find_children("*", "PointLight2D", true, false):
			var at := NightShadowsLayer._place(light, root)
			if Vector2i((at / MapView.TILE).floor()) == fire_cell:
				fire = light
			if not light.get_meta("casts", false):
				continue
			casting += 1
			for foot in feet:
				assert_false(NightShadows.holds_light(foot, PackedVector2Array([at]), NightShadows.AGAINST), "no flame at %s casts from against a foot" % at)
	assert_not_null(fire, "the camp's fire by its tent")
	assert_true(fire != null and fire.get_meta("casts", false), "a cell clear of its tent, it casts the tent's shadow")
	assert_gt(casting, 0, "the Reach's other flames still cast")
	assert_gt(feet.size(), 0, "and the tent still blocks the lantern")


func test_shadows_fall_on_the_ground_and_never_on_what_stands() -> void:
	var view := _draw("town")
	for flat: TileMapLayer in [view.ground_layer, view.wear_layer, view.verge_layer, view.detail_layer]:
		assert_ne(flat.light_mask & NightShadows.SCENERY, 0, "the ground takes them")
	if view.paving_layer != null:
		assert_ne(view.paving_layer.light_mask & NightShadows.SCENERY, 0, "the square's paving too")
	assert_eq(view.crown_layer.light_mask & NightShadows.SCENERY, 0, "the forest's crowns don't")
	if view.layers.has("pieces"):
		assert_eq((view.layers["pieces"] as CanvasItem).light_mask & NightShadows.SCENERY, 0, "nor the houses")
	for node: Node in view.actors.find_children("*", "CanvasItem", true, false):
		assert_eq((node as CanvasItem).light_mask & (NightShadows.SCENERY | NightShadows.FOLK), 0, "nor %s, standing" % node.name)
	var hero: CanvasItem = autofree(preload("res://scripts/player.gd").new())
	assert_eq(hero.light_mask & (NightShadows.SCENERY | NightShadows.FOLK), 0, "nor the hero")


func test_a_dungeon_blocks_by_its_walls_and_a_room_not_at_all() -> void:
	var cave := NightShadowsLayer.laid(_draw("seacave"))
	assert_gt(cave["walls"], 0, "a dungeon's walls")
	assert_true(NightShadowsLayer.laid(_draw("town_inn")).is_empty(), "a room lays none")


func test_every_light_is_ready_to_cast_on_the_floor_alone() -> void:
	var lamp: PointLight2D = autofree(Lights.make(Vector2.ZERO, 72.0, Lights.LAMP, Lights.LAMP_ENERGY, true))
	assert_false(lamp.shadow_enabled, "none casts until the LightRig says so")
	assert_eq(lamp.shadow_item_cull_mask, NightShadows.SCENERY | NightShadows.FOLK | NightShadows.WALLS)
	assert_eq(lamp.shadow_item_cull_mask & 1, 0, "what stands (Godot's first light bit) takes no shadow")
	assert_ne(lamp.shadow_filter, Light2D.SHADOW_FILTER_NONE, "soft-edged")


# --- The LightRig -----------------------------------------------------------------

## A rig for `view` with the hero at `at`, their lantern lit: not in the
## tree (its frame needs the whole world), its shadows stepped by hand.
func _rig(view: MapView, at: Vector2) -> Node:
	var world := _World.new()
	add_child_autofree(world)
	world.view = view
	var hero: Player = preload("res://test/bare_hero.gd").new()
	hero.position = at
	world.add_child(hero)
	var rig: Node = autofree(preload("res://scripts/light_rig.gd").new())
	rig.world = world
	rig.give_lantern(hero)
	rig.lantern.visible = true
	return rig


## The map's flames that may cast, all burning.
func _flames(view: MapView) -> Array[PointLight2D]:
	var out: Array[PointLight2D] = []
	for light: PointLight2D in view.under.find_children("*", "PointLight2D", true, false):
		if light.get_meta("casts", false):
			light.visible = true
			out.append(light)
	return out


class _World:
	extends "res://test/bare_world.gd"


func _shadowed() -> int:
	return get_tree().get_nodes_in_group("lights").filter(func(light: Node) -> bool: return (light as PointLight2D).shadow_enabled).size()


func test_no_more_than_the_cap_of_lamps_cast_and_never_the_lantern() -> void:
	GameState.settings.shadows = true
	var view := _draw("town")
	var flames := _flames(view)
	var rig := _rig(view, MapView.center(Vector2i(40, 24)))
	assert_gt(flames.size(), NightShadows.LAMPS, "more lamps burn in the village than may cast")
	var most := 0
	for i in 90:
		rig._cast_shadows(flames, 1.0 / 60.0)
		most = maxi(most, rig.casting.size())
	assert_eq(rig.casting.size(), NightShadows.LAMPS, "the cap of lamps")
	assert_eq(most, NightShadows.LAMPS, "never more, while they fade in")
	assert_false(rig.lantern in rig.casting or rig.lantern.shadow_enabled, "never the hero's own lantern: its shadows read as a field of view")
	assert_eq(_shadowed(), rig.casting.size(), "every other light as before")
	# Walked up the street, other lamps take over: still no more.
	(rig.lantern.get_parent() as Node2D).position = MapView.center(Vector2i(47, 13))
	for i in 90:
		rig._cast_shadows(flames, 1.0 / 60.0)
		assert_lte(rig.casting.size(), NightShadows.LAMPS)
	assert_eq(rig.casting.size(), NightShadows.LAMPS)
	# The setting off: none.
	GameState.settings.shadows = false
	rig._cast_shadows(flames, 1.0 / 60.0)
	assert_eq(rig.casting.size(), 0)
	assert_eq(_shadowed(), 0, "the Shadows setting off")
	GameState.settings.shadows = true


func test_a_lamp_freed_with_its_map_stops_no_other() -> void:
	# PIX-496: a map left at night frees its lamps while the rig still
	# holds them. The filter that asked for each by its type failed on the
	# freed one, with an error a map change, and came back empty: the lamps
	# fading out were let go still casting.
	GameState.settings.shadows = true
	var view := _draw("town")
	var flames := _flames(view)
	var rig := _rig(view, MapView.center(Vector2i(40, 24)))
	for i in 90:
		rig._cast_shadows(flames, 1.0 / 60.0)
	assert_eq(rig.casting.size(), NightShadows.LAMPS)
	var gone: PointLight2D = rig.casting[0]
	flames.erase(gone)
	gone.free()
	# The hero far from every lamp: those left fade out.
	(rig.lantern.get_parent() as Node2D).position = Vector2(-4000, -4000)
	for i in 90:
		rig._cast_shadows(flames, 1.0 / 60.0)
	assert_eq(rig.casting.size(), 0, "none: the lantern never casts")
	assert_eq(_shadowed(), 0, "and no lamp left casting behind it")


func test_by_day_and_in_a_room_nothing_casts() -> void:
	GameState.settings.shadows = true
	var rig := _rig(_draw("town"), MapView.center(Vector2i(40, 24)))
	# By day no light is lit (the rig hides them): the sun's shadows alone.
	var none: Array[PointLight2D] = []
	rig.lantern.visible = false
	rig._cast_shadows(none, 1.0 / 60.0)
	assert_eq(rig.casting.size(), 0)
	var room := _rig(_draw("town_inn"), Vector2(40, 40))
	room._cast_shadows(none, 1.0 / 60.0)
	assert_eq(room.casting.size(), 0, "a room has no occluders: its lantern lights as before")
	assert_false(room.lantern.shadow_enabled)


func test_the_setting_is_kept() -> void:
	var path := "user://test_night_shadows.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var settings := GameSettings.new(path)
	assert_false(settings.shadows, "off until turned on (2026-11-18: the long wedges read as a field of view)")
	settings.shadows = true
	settings.save_file()
	var again := GameSettings.new(path)
	again.load_file()
	assert_true(again.shadows, "kept on")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
