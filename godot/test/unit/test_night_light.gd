extends GutTest
## Every light a soft pool, never a straight edge (PIX-285). Godot lights a
## canvas item with only the first Lights.PER_ITEM lights that reach it, and
## a tile layer is drawn a block of cells to a canvas item: a light left out
## of one block lit the block beside it and stopped at their edge. On the
## Night of Ash three dozen fires reached one of the engine's 16-cell blocks
## and the square came out lit and dark in straight lines. So every map at
## night, the town at every age and on the Night of Ash, the region dungeons'
## floors and the mountain's, and the Reach with the regions round it drawn
## beside one another as the hero walks between them, draws its tile layers
## in MapView.LIGHT_BLOCK blocks that no more lights reach than leave room
## for what moves: the hero's lantern and a spell or two.

## What moves among the lights a map lays: the hero's lantern and the
## flares of two spells landing at once; and where a boss can stand, its
## glow on the floor round its feet (PIX-314, Enemy._weigh: it lights the
## floor's blocks alone).
const MOVING := 3
const BOSS_GLOW := 1

var _saved := {}


func before_each() -> void:
	_saved = {
		"prologue": GameState.progression.prologue,
		"doused": GameState.progression.prologue_doused.duplicate(),
		"tier": GameState.settlement.town_tier,
		"projects": GameState.settlement.projects.duplicate(),
		"steps": GameState.world.steps,
	}
	GameState.world.steps = Prologue.night_steps()


func after_each() -> void:
	GameState.progression.prologue = _saved["prologue"]
	GameState.progression.prologue_doused.assign(_saved["doused"])
	GameState.settlement.town_tier = _saved["tier"]
	GameState.settlement.projects.assign(_saved["projects"])
	GameState.world.steps = _saved["steps"]


## `map` drawn as a door draws it, in the tree.
func _drawn(map: MapData) -> Node2D:
	var root := Node2D.new()
	add_child_autofree(root)
	var actors := Node2D.new()
	root.add_child(actors)
	var view := MapView.new(map, actors)
	view.plan(map.spawn)
	view.build(root)
	return root


## Each light's square of reach, in map pixels.
static func _reaches(root: Node) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for node in root.find_children("*", "PointLight2D", true, false):
		var light := node as PointLight2D
		var reach := light.texture_scale * Lights.TEXTURE_PX / 2.0 * maxf(absf(light.global_scale.x), absf(light.global_scale.y))
		out.append(Rect2(light.global_position - Vector2.ONE * reach, Vector2.ONE * reach * 2.0))
	return out


## Every tile layer drawn in light blocks, and none reached by more lights
## than leave room for what moves.
func _check(label: String, root: Node, moving := MOVING) -> void:
	var reaches := _reaches(root)
	var budget := Lights.PER_ITEM - moving
	var worst := 0
	var at := ""
	for node in root.find_children("*", "TileMapLayer", true, false):
		var layer := node as TileMapLayer
		var block := layer.rendering_quadrant_size
		assert_eq(block, MapView.LIGHT_BLOCK, "%s: a tile layer drawn in light blocks" % label)
		var blocks := {}
		for cell: Vector2i in layer.get_used_cells():
			blocks[Vector2i(floori(cell.x / float(block)), floori(cell.y / float(block)))] = true
		for corner: Vector2i in blocks:
			# A block's tiles may stand a cell past its cells (tall art).
			var rect := Rect2(layer.global_position + Vector2(corner * block * MapView.TILE), Vector2.ONE * block * MapView.TILE).grow(MapView.TILE)
			var reached := reaches.filter(func(reach: Rect2) -> bool: return reach.intersects(rect)).size()
			if reached > worst:
				worst = reached
				at = "the block at cell %s" % (corner * block)
	assert_lte(worst, budget, "%s: %d lights reach %s" % [label, worst, at])


## What moves on `maps`: a boss's glow too where a named monster has its
## lair (PIX-314).
static func _moving_on(maps: Array) -> int:
	var bosses := Hunts.all().any(func(entry: Dictionary) -> bool: return String(entry["mapId"]) in maps)
	return MOVING + (BOSS_GLOW if bosses else 0)


func test_the_night_of_ash_burns_in_soft_pools() -> void:
	GameState.progression.prologue = Prologue.SCAVENGER
	GameState.progression.prologue_doused.clear()
	GameState.settlement.town_tier = 0
	GameState.settlement.projects.clear()
	var ruins := Town.ruins([])
	assert_gt(ruins.size(), 5, "the village burns")
	var root := _drawn(MapData.load_tiered("town", [], 1))
	# A burning house lights the ground as a few pools, not one to a flame.
	var pools := 0
	for ruin: Dictionary in ruins:
		pools += MapView.fire_pools(ruin["rect"]).size()
	assert_lt(pools, ruins.size() * 3, "a few pools to a burning house")
	assert_gte(_reaches(root).size(), pools, "every pool is a light")
	_check("the Night of Ash", root)


func test_a_burning_house_is_lit_from_end_to_end() -> void:
	for ruin: Dictionary in Town.ruins([]):
		var rect: Rect2i = ruin["rect"]
		var area := Rect2(Vector2(rect.position * MapView.TILE), Vector2(rect.size * MapView.TILE))
		for pool: Dictionary in MapView.fire_pools(rect):
			assert_true(area.has_point(pool["at"]), "a pool in the house it lights")
		# Every corner of the house is under a pool, short of its rim.
		for corner: Vector2 in [area.position, area.position + Vector2(area.size.x, 0), area.end, area.position + Vector2(0, area.size.y)]:
			var lit := MapView.fire_pools(rect).any(func(pool: Dictionary) -> bool: return (pool["at"] as Vector2).distance_to(corner) < float(pool["radius"]) * 0.8)
			assert_true(lit, "the corner %s of the house at %s is lit" % [corner, rect])


func test_the_town_at_night_at_every_age() -> void:
	GameState.progression.prologue = Prologue.DONE
	for tier in Town.MAX_TIER + 1:
		GameState.settlement.town_tier = tier
		var projects := Town.projects_through(tier)
		GameState.settlement.projects.assign(projects)
		# Fafnyr lands on the square on the Night of Bells, before the City
		# (whose age asks for the dragon freed).
		var moving := MOVING + (BOSS_GLOW if tier < Town.MAX_TIER else 0)
		_check("the town at age %d" % tier, _drawn(MapData.load_tiered("town", projects, 1)), moving)


## The village seen from the Reach at every age (PIX-311): its lamps stand
## close there, small, and at the City age a light to each crowded one of
## the ground's blocks with fifteen.
func test_the_village_far_off_at_every_age() -> void:
	GameState.progression.prologue = Prologue.DONE
	for tier in Town.MAX_TIER + 1:
		GameState.settlement.town_tier = tier
		GameState.settlement.projects.assign(Town.projects_through(tier))
		_check("the Reach with the village at age %d" % tier, _drawn(MapData.load_by_id("overworld")))


## The Post's roads with every waystation built (PIX-322): each ember lamp
## one light, and the Reach still within the budget, alone and drawn as one
## land with the regions round it.
func test_the_reach_with_every_waystation_lit() -> void:
	GameState.progression.prologue = Prologue.DONE
	var kept_post := GameState.post
	GameState.post = PostState.new()
	var done := Town.done_projects(GameState.settlement)
	for place: String in Routes.places():
		Routes.tally(GameState.post, place, "bram", Routes.station_at(place) if not Routes.station(place).is_empty() else Routes.signs_at(place))
		if not Routes.station(place).is_empty():
			done.append(String(Routes.station(place)["work"]))
	Routes.raise_signs(GameState.post)
	GameState.settlement.projects.assign(done)
	assert_eq(Routes.lamps(GameState.settlement).size(), 4, "an ember lamp at each waystation")
	_check("the Reach with every waystation lit", _drawn(MapData.load_by_id(Routes.MAP)))
	_check("the Reach as one land with every waystation lit", _one_land(), _moving_on(ReachPlane.maps()))
	GameState.post = kept_post


## The hubs fully grown (PIX-324): the lighthouse lit, the miners' stall's
## lantern, Gunnar's lodge's windows, each a light of its own, and every
## hub's map within the budget; and the Reach with every lamp lit, the
## Mirefen Pass's too.
func test_the_hubs_grown_and_every_lamp_lit() -> void:
	GameState.progression.prologue = Prologue.DONE
	var kept_post := GameState.post
	GameState.post = PostState.new()
	for place: String in Hubs.places():
		Routes.tally(GameState.post, place, "bram", int(Hubs.marks()[-1]))
		_check("%s grown" % place, _drawn(MapData.load_by_id(place)), _moving_on([place]))
	var done := Town.done_projects(GameState.settlement)
	for place: String in Routes.places():
		var lamp := Routes.lamp_of(place)
		if not lamp.is_empty():
			done.append(String(lamp["work"]))
	GameState.settlement.projects.assign(done)
	assert_eq(Routes.lamps(GameState.settlement).size(), 5, "an ember lamp at each waystation and at the Mirefen Pass")
	_check("the Reach with every lamp lit", _drawn(MapData.load_by_id(Routes.MAP)), _moving_on([Routes.MAP]))
	GameState.post = kept_post


## Dozens of ember lamps (PIX-323): a road of the Reach lined with them, a
## lamp to a cell. Those close to one already lit keep their halo alone, a
## cheaper light, and the Reach holds the budget.
func test_the_reach_with_dozens_of_lamps() -> void:
	GameState.progression.prologue = Prologue.DONE
	var map := MapData.load_by_id(Routes.MAP)
	var root := Node2D.new()
	add_child_autofree(root)
	var actors := Node2D.new()
	root.add_child(actors)
	var view := MapView.new(map, actors)
	view.plan(map.spawn)
	var cells: Array[Vector2i] = []
	for x in range(4, 44):
		cells.append(Vector2i(x, 21))
		view.routes["pieces"].append({"kind": "lamp", "cell": cells[-1], "cells": [cells[-1]], "place": "lamp_%d" % x})
	view.build(root)
	var embers := root.find_children("*", "PointLight2D", true, false).filter(func(light: Node) -> bool:
		return light.get_meta("tint") == Lights.EMBER)
	assert_eq(embers.size(), Lamps.lit_among(cells).size(), "a light to each few lamps")
	assert_lt(embers.size(), cells.size() / 3, "not one to each")
	_check("the Reach with dozens of lamps", root)


func test_every_map_at_night() -> void:
	GameState.progression.prologue = Prologue.DONE
	var maps := DirAccess.get_files_at("res://assets/maps")
	var seen := 0
	for file: String in maps:
		if not file.ends_with(".json") or file == "interactables.json" or file == "town.json":
			continue
		var map_id := file.get_basename()
		var map: MapData
		if "@" in map_id:
			map = MapData.load_tiered(map_id.get_slice("@", 0), [], int(map_id.get_slice("@", 1)))
		else:
			map = MapData.load_by_id(map_id)
		_check(map_id, _drawn(map), _moving_on([map_id]))
		seen += 1
	assert_gt(seen, 20, "the maps on disk")


func test_every_dungeon_floor() -> void:
	for dungeon_id: String in Depths.dungeons():
		for entry: Dictionary in Depths.floors(dungeon_id):
			if Depths.is_planned(entry["mapId"]):
				_check(entry["mapId"], _drawn(MapData.load_by_id(entry["mapId"])), _moving_on([entry["mapId"]]))


## The Reach and the regions round it, each drawn as Neighbours draws a map
## beside the hero (a unit at a time, where it lies in the Reach's plane),
## all at once: a camp's fire by a road out reaches the blocks of the map
## past the line too.
func test_the_reach_drawn_as_one_land() -> void:
	GameState.progression.prologue = Prologue.DONE
	assert_gt(ReachPlane.maps().size(), 5, "the Reach and its regions")
	_check("the Reach as one land", _one_land(), _moving_on(ReachPlane.maps()))


## The Reach and the regions round it drawn as one land, as Neighbours
## draws each map beside the hero.
func _one_land() -> Node2D:
	var root := Node2D.new()
	add_child_autofree(root)
	var standing := Node2D.new()
	root.add_child(standing)
	for map_id: String in ReachPlane.maps():
		var data := MapData.load_by_id(map_id)
		var view := MapView.new(data, standing)
		view.sliced = true
		view.offset = Vector2(ReachPlane.origin(map_id) * MapView.TILE)
		var slices := Slicer.new()
		KeptGround.decks_working(data, slices)
		view.planning(data.spawn, slices)
		slices.add("plan_kept", func() -> void:
			view.kept = KeptGround.working(data, view.look(), MapView.EDGE_PAD, slices)
			slices.add("plan_draw", func() -> void: view.building(root, slices)))
		slices.finish()
	return root


## A unit of drawing lays whole light blocks, so each is drawn once.
func test_a_unit_of_drawing_lays_whole_light_blocks() -> void:
	assert_eq(MapView.BLOCK % MapView.LIGHT_BLOCK, 0)
	assert_lt(MapView.LIGHT_BLOCK, MapView.BLOCK, "smaller than the engine's blocks of 16")
