class_name Neighbours
extends Node
## The maps drawn beside the hero's (One Reach, PIX-269, steps 5 and 6). Tom
## found crossing between the Reach's maps a cut; now, near a road out of a
## map under the Reach's sky, the map past it is drawn beside it where the
## plane puts it (ReachPlane), drawn only - no foes, folk or anything to
## talk to - a few units a frame (Slicer: 3 ms of the frame by the clock,
## shared with taking maps down and working them out ahead), hidden until
## it's whole. Then the two are stitched along their line (Seam): the ground
## both draw there worked out from both sides, the ground each carries on
## past its edges taken off the other, the region's tone and the water's
## foam laid across, and the camera may look over it (CameraRig.set_bounds)
## with the ridge (Seam.ridge_texture) drawn where no map lies. Walking on
## past the line, the world hands the hero over to it (world.hand_over):
## it becomes the map the hero stands on and the one left is drawn beside
## it. Far from it again, it's let go, a few hundred nodes a frame.
## Early in a session each map of the Reach is worked out ahead (its kept
## ground and the slow parts of its plan, KeptGround), so drawing it beside
## the hero later is quick. A road a shut gate keeps (Gates) is drawn past
## all the same, the land beyond it in sight; the gate stands on the Reach's
## side and blocks there, as it always did.
## A door that stays a door (the town's gate, houses, caves) isn't a line:
## going through one takes every map beside the hero down at once
## (forget). If the map past a road isn't whole when the hero reaches it (a
## very slow machine), its road is a door again: the soft one it was.

var world: Node
## Each map drawn beside the hero's, by id: {"id", "data", "view", "offset"
## (cells: where its cell (0, 0) lies from the hero's map's), "state"
## ("drawing", "stitching", "ready", "dropping"), "slices", "road"}.
var drawn := {}
## Milliseconds a frame for everything here, by the clock (PR #338); in a
## harness run, so many units a frame instead (`counted`, PIX-276: stepped,
## it draws the maps beside the hero in the same frames on any machine), but
## for the run that times the frames (`crossing`).
const BUDGET_MS := 3.0
const UNITS_A_FRAME := 4
var counted := false
## No map is drawn beside the hero's (the harness's `unstreamed`): every
## road out is the soft door it was, as on a machine too slow to draw one in
## time.
var unstreamed := false
## How many nodes one unit of taking a map down frees.
const DROP_A_UNIT := 120
## How long a unit of each kind has taken at most, shared by every slicer.
var learned := {}
## The hero's map, the roads out of it, and the maps it was worked out for.
var _roads_of: MapData
var _roads: Array[Dictionary] = []
## Maps worked out ahead this session, and the one being worked out
## (PLANE: the plane's maps' sizes and the ridge, first).
const PLANE := "(plane)"
var _warmed := {}
var _warming := {}
## Each line's ground worked out once (Seam.stitch), by "map to other"; and the
## corners of each drawing set from it, by drawing.
var _stitches := {}
var _laid := {}
## The ridge round the maps, where the camera may look and no map lies.
var ridge: Sprite2D
## The water the reflections read, laid out in the plane (LightRig):
## {"texture", "origin" (plane cell), "cells"}; `mirror_version` counts its
## changes.
var mirror := {}
var mirror_version := 0
## When a handover last saved (ms), and how many saves and handovers there
## have been (the harness reports them).
var saved_at := -100000
var saves := 0
var handovers := 0
## Seconds until the drawn maps' night and patches are looked at again.
var _hours_left := 0.0
## What this frame's work took, ms (the harness's `crossing` reads it).
var spent := 0.0


func _ready() -> void:
	# After the hero has moved this tick, before the camera notes where.
	process_physics_priority = 5
	var flags := HarnessFlags.given()
	counted = world.harness and not flags.has("crossing")
	unstreamed = world.harness and flags.has("unstreamed")


## Work under way is given up with the world (its units hold their slicers).
func _exit_tree() -> void:
	forget()


## A new slicer, timing its kinds with every other.
func _slicer() -> Slicer:
	var slices := Slicer.new()
	slices.learn_from(learned)
	slices.counted = counted
	return slices


## The hero's map's place in the plane, in cells (zero off it).
func origin() -> Vector2i:
	var map: MapData = world.map
	return ReachPlane.origin(map.id) if map != null and _on_plane(map) else Vector2i.ZERO


static func _on_plane(map: MapData) -> bool:
	return map.floor_level == 0 and ReachPlane.holds(map.id)


func _process(delta: float) -> void:
	if world.view == null or world.player == null:
		return
	var map: MapData = world.map
	if not _on_plane(map) or unstreamed:
		if not drawn.is_empty():
			forget()
	else:
		_want(world.player_cell)
		_hours_left -= delta
		if _hours_left <= 0.0:
			_hours_left = 1.0
			for id: String in drawn:
				if drawn[id]["state"] == "ready":
					drawn[id]["view"].set_night(DayNight.is_night(GameState.world.steps))
					drawn[id]["view"].refresh_patches()
	_work()


## Which maps should be drawn beside the hero standing on `cell`: past every
## road out within Seam.NEAR, kept till Seam.FAR and while the view shows
## any of it; the rest let go.
func _want(cell: Vector2i) -> void:
	var map: MapData = world.map
	if _roads_of != map:
		_roads_of = map
		_roads = Seam.roads_out(map)
	var near := {}
	var keep := {}
	for road: Dictionary in _roads:
		if Seam.near(cell, road["way"], Seam.NEAR):
			near[road["to"]] = road
		if Seam.near(cell, road["way"], Seam.FAR):
			keep[road["to"]] = true
	for id: String in near:
		if not drawn.has(id):
			_draw(id, near[id])
	for id: String in drawn.keys():
		var beside: Dictionary = drawn[id]
		if beside["state"] == "dropping" or near.has(id) or keep.has(id) or _seen(beside):
			continue
		_drop(id)


## Whether the camera shows any of a map drawn beside the hero's.
func _seen(beside: Dictionary) -> bool:
	if beside["state"] not in ["stitching", "ready"]:
		return false
	var cells: Vector2i = beside["data"].size
	var rect := Rect2(Vector2(beside["offset"] * MapView.TILE), Vector2(cells * MapView.TILE))
	return world.camera_rig.view_rect(MapView.TILE * 2).intersects(rect)


## Starts drawing map `id` beside the hero's, past `road`: loaded, planned,
## its ground worked out if it isn't kept, then drawn, hidden, a few units a
## frame; then stitched along its lines and shown.
func _draw(id: String, road: Dictionary) -> void:
	var beside := {"id": id, "offset": road["offset"], "state": "drawing", "road": road, "data": null, "view": null}
	var slices := _slicer()
	beside["slices"] = slices
	drawn[id] = beside
	slices.add("plan_load", func() -> void:
		var data: MapData = world.load_map(id)
		var view := MapView.new(data, world.actors)
		view.sliced = true
		view.hidden = true
		view.offset = Vector2(beside["offset"] * MapView.TILE)
		beside["data"] = data
		beside["view"] = view
		# It's walked into across the line, onto the road's far side.
		var arrival := Vector2i(int(road["way"]["to"]["x"]), int(road["way"]["to"]["y"]))
		KeptGround.decks_working(data, slices)
		view.planning(arrival, slices)
		slices.add("plan_kept", func() -> void:
			view.kept = KeptGround.working(data, view.look(), MapView.EDGE_PAD, slices)
			slices.add("plan_draw", func() -> void: view.building(world, slices))))


## Lets map `id` go: unstitched from the maps it lay beside, hidden, then
## taken down a few hundred nodes a frame.
func _drop(id: String) -> void:
	var beside: Dictionary = drawn[id]
	var view: MapView = beside["view"]
	beside["state"] = "dropping"
	(beside["slices"] as Slicer).cancel()
	var slices := _slicer()
	beside["slices"] = slices
	if view == null or view.under == null:
		slices.add("drop_nodes", func() -> void:
			if view != null:
				view.clear())
		return
	_stitch(slices)
	slices.add("drop_hide", func() -> void:
		view.under.visible = false
		view.stand.visible = false)
	for root: Node in [view.stand, view.under]:
		var nodes: Array[Node] = []
		_gather(root, nodes)
		slices.add_each("drop_nodes", ceili(nodes.size() / float(DROP_A_UNIT)), func(i: int) -> void:
			for node: Node in nodes.slice(i * DROP_A_UNIT, (i + 1) * DROP_A_UNIT):
				if is_instance_valid(node):
					node.free())
	slices.add("drop_done", func() -> void:
		_laid.erase(view)
		drawn.erase(id))


## Every node under `root`, the deepest first and `root` last, to free one
## by one (a node freed frees what's under it all at once).
static func _gather(root: Node, into: Array[Node]) -> void:
	for child: Node in root.get_children():
		_gather(child, into)
	into.append(root)


## Takes every map drawn beside the hero down at once (a door: the map the
## hero stands on is about to be drawn anew).
func forget() -> void:
	if not _warming.is_empty():
		(_warming["slices"] as Slicer).cancel()
		_warming = {}
	for id: String in drawn:
		(drawn[id]["slices"] as Slicer).cancel()
		var view: MapView = drawn[id]["view"]
		if view != null:
			view.clear()
	drawn.clear()
	_laid.clear()
	_roads_of = null
	if ridge != null:
		ridge.visible = false
	mirror = {}
	mirror_version += 1


## The frame's work, within BUDGET_MS: the maps being drawn (nearest first),
## then those being let go, then working the Reach out ahead. What it took
## is the slicers' own measure.
func _work() -> void:
	spent = 0.0
	if unstreamed:
		return
	var left := float(UNITS_A_FRAME) if counted else BUDGET_MS
	var fresh := true
	var order := drawn.keys()
	order.sort_custom(func(a: String, b: String) -> bool: return _rank(drawn[a]) < _rank(drawn[b]))
	for id: String in order:
		var beside: Dictionary = drawn.get(id, {})
		if beside.is_empty() or beside["state"] == "ready":
			continue
		var slices: Slicer = beside["slices"]
		var done := slices.run(left, fresh)
		left -= slices.spent
		_spent(slices)
		fresh = fresh and slices.ran == 0
		if done:
			_finished(beside)
		if left <= 0.0:
			return
	_warm(left, fresh)


## Notes what a slicer's run this frame took, ms.
func _spent(slices: Slicer) -> void:
	if not slices.counted:
		spent += slices.spent


## Drawing first, the nearest road first; then letting go.
func _rank(beside: Dictionary) -> float:
	if beside["state"] == "dropping":
		return 1e6
	var road: Dictionary = beside["road"]
	return Vector2(world.player_cell - (road["way"]["at"] as Vector2i)).length()


## A map's units are all done. Drawn: it's shown (its edge rows lie under
## the hero's map's ground until the lines are stitched, so nothing shows
## through), then stitched in, a few units a frame, and ready to walk into.
## Stitched or taken down: nothing more.
func _finished(beside: Dictionary) -> void:
	if beside["state"] != "drawing":
		return
	if beside["view"] == null or beside["view"].under == null:
		return
	beside["state"] = "stitching"
	var view: MapView = beside["view"]
	view.under.visible = true
	view.stand.visible = true
	var slices := _slicer()
	beside["slices"] = slices
	_stitch(slices)
	slices.add("stitch_done", func() -> void: beside["state"] = "ready")


## Stitches every map drawn (the hero's and those shown beside it) along
## their lines, lays their masks across, and frames the camera and the
## ridge round them all: as units on `slices`, each looking at what's drawn
## when it runs.
func _stitch(slices: Slicer) -> void:
	var views := _stitched()
	for view: MapView in views:
		for other: MapView in views:
			if other != view and _touch(view.data.id, other.data.id):
				slices.add("stitch_line", _line.bind(view, other))
	for view: MapView in views:
		slices.add("stitch_lay", func() -> void:
			if view.has_ground_layers():
				_lay(view, _stitched()))
	slices.add("stitch_frame", func() -> void: _frame(_stitched()))


## The ground along the line from `view`'s map to `other`'s (Seam.stitch),
## worked out once.
func _line(view: MapView, other: MapView) -> Dictionary:
	var key := view.data.id + " to " + other.data.id
	if not _stitches.has(key) or _stitches[key]["kept"] != view.kept:
		var grids := {view.data.id: view.data.grid, other.data.id: other.data.grid}
		_stitches[key] = {"kept": view.kept, "changes": Seam.stitch(view.data.id, other.data.id, grids, view.kept, MapView.EDGE_PAD)}
	return _stitches[key]["changes"]


## The maps drawn now that stitch: the hero's, and those shown beside it.
func _stitched() -> Array[MapView]:
	var views: Array[MapView] = []
	if world.view != null and world.view.has_ground_layers() and _on_plane(world.map):
		views.append(world.view)
	for id: String in drawn:
		if drawn[id]["state"] in ["stitching", "ready"] and drawn[id]["view"].has_ground_layers():
			views.append(drawn[id]["view"])
	return views


## Whether two maps' drawn ground (their pads) and lines meet.
static func _touch(a: String, b: String) -> bool:
	return ReachPlane.rect_of(a).grow(MapView.EDGE_PAD + 2).intersects(ReachPlane.rect_of(b))


## Lays `view`'s corners along its lines with every map of `views` beside it
## (and puts back those a map no longer there had changed), then its masks.
func _lay(view: MapView, views: Array[MapView]) -> void:
	var target := {}
	var masks := {}
	for other: MapView in views:
		if other == view or not _touch(view.data.id, other.data.id):
			continue
		masks[other.data.id] = [other.kept.tint_image, other.kept.water_image, other.kept.tint_image if other.kept.crowns_toned else null]
		var changes := _line(view, other)
		for cell: Vector2i in changes:
			# Where two lines meet, a corner gone stays gone.
			if not target.has(cell) or changes[cell][0] < 0:
				target[cell] = changes[cell]
	var laid: Dictionary = _laid.get(view, {})
	for cell: Vector2i in laid:
		if not target.has(cell):
			view.set_corner(cell, [])
	for cell: Vector2i in target:
		if laid.get(cell, []) != target[cell]:
			view.set_corner(cell, target[cell])
	_laid[view] = target
	view.draw_now()
	if masks.is_empty():
		view.own_masks()
		return
	var tint := Seam.masks_beside(view.data.id, view.kept.tint_image, _images(masks, 0))
	var water := Seam.masks_beside(view.data.id, view.kept.water_image, _images(masks, 1))
	# The pines whiten under snow only (PIX-169), on both sides of a line
	# alike: a map whose own keep their green reads its snowy neighbour's.
	var snowy := _images(masks, 2)
	var crowns: ImageTexture = null
	if view.kept.crowns_toned or not snowy.is_empty():
		var own: Image = view.kept.tint_image if view.kept.crowns_toned else null
		crowns = ImageTexture.create_from_image(Seam.masks_beside(view.data.id, own, snowy, view.data.size))
	var margin := Vector2.ONE * Seam.MASK_MARGIN * MapView.TILE
	view.set_masks(ImageTexture.create_from_image(tint), ImageTexture.create_from_image(water), -margin, Vector2(tint.get_size() * MapView.TILE), crowns)


## Each map's mask `which` of `masks` (map id -> [tint, water, crowns]),
## those it has.
static func _images(masks: Dictionary, which: int) -> Dictionary:
	var out := {}
	for id: String in masks:
		if masks[id][which] != null:
			out[id] = masks[id][which]
	return out


## The camera's bounds round every map of `views` (CameraRig.set_bounds,
## eased as they grow), the ridge round them where no map lies, and the
## water the reflections read.
func _frame(views: Array[MapView]) -> void:
	if world.view == null or not _on_plane(world.map):
		return
	var ids: Array = views.map(func(view: MapView) -> String: return view.data.id)
	if not ids.has(world.map.id):
		ids.append(world.map.id)
	var bounds := Seam.bounds_of(ids)
	var here := origin()
	var rect := Rect2(Vector2((bounds.position - here) * MapView.TILE), Vector2(bounds.size * MapView.TILE))
	world.camera_rig.set_bounds(rect, true, false)
	if ridge == null:
		ridge = Sprite2D.new()
		ridge.texture = Seam.ridge_texture()
		ridge.centered = false
		ridge.region_enabled = true
		ridge.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		# Under every map's ground.
		ridge.z_index = -1
		world.add_child(ridge)
	ridge.visible = ids.size() > 1
	var margin := Vector2.ONE * Seam.RIDGE_MARGIN * MapView.TILE
	# On the ground's dual grid, half a tile up and left of the cells, so its
	# pines stand in the rows of those crowning the rock past each map's edge.
	ridge.position = rect.position - margin - Vector2.ONE * MapView.TILE / 2.0
	ridge.region_rect = Rect2(Vector2.ZERO, rect.size + margin * 2.0)
	var waters := {}
	for view: MapView in views:
		waters[view.data.id] = view.kept.water_image
	var laid := Seam.water_beside(waters)
	var image: Image = laid["image"]
	mirror = {"texture": ImageTexture.create_from_image(image), "origin": Vector2(laid["origin"]), "cells": Vector2(image.get_size())}
	mirror_version += 1


## Whether the hero may walk on over the road out at `cell` (a portal at
## the edge): the map past it is drawn and stitched, and no boss holds the
## way. Else the road is a door, as it was.
## In a harness run the map past the road is drawn now if it isn't yet
## (stepped, a long frame costs the game no time): only `unstreamed` makes
## the road a door, never a slow machine by chance.
func seamless(cell: Vector2i) -> bool:
	var map: MapData = world.map
	if unstreamed or not _on_plane(map) or not map.portals.has(cell) or world.foes.boss_hunting() != null:
		return false
	if Ways.kind_of(map, cell) != "edge":
		return false
	var to := String(map.portals[cell].get("mapId", ""))
	if world.harness and not (drawn.has(to) and drawn[to]["state"] == "dropping"):
		_draw_now(to)
	return drawn.has(to) and drawn[to]["state"] == "ready"


## Map `id` drawn and stitched beside the hero's at once: begun if it wasn't,
## its units all run.
func _draw_now(id: String) -> void:
	if not drawn.has(id):
		for road: Dictionary in Seam.roads_out(world.map):
			if road["to"] == id:
				_draw(id, road)
	if not drawn.has(id):
		return
	var beside: Dictionary = drawn[id]
	for step in 2:
		if beside["state"] == "ready":
			return
		(beside["slices"] as Slicer).finish()
		_finished(beside)


## The hand-over (step 6): once the hero has walked on past the line, onto a
## map drawn beside theirs, it becomes theirs - in the same physics tick,
## right after they moved, so nothing is drawn in between.
func _physics_process(_delta: float) -> void:
	var player: Node2D = world.player
	if player == null or player.dead or world.view == null or not _on_plane(world.map):
		return
	var cell := Vector2i((player.position / MapView.TILE).floor())
	var there := Seam.across(world.map.id, cell)
	if there.is_empty():
		return
	var beside: Dictionary = drawn.get(there["map"], {})
	if beside.is_empty() or beside["state"] != "ready":
		return
	var boss: Node = world.foes.boss_hunting()
	if boss != null:
		world.bar_the_way(boss)
		return
	world.hand_over(beside, there["cell"])


## The bookkeeping of a hand-over to `beside`: it's the hero's map now (no
## longer in `drawn`), and the map left (`left`, `left_view`) is drawn
## beside it; every other map drawn beside them now lies `offset` cells
## nearer. The drawings themselves have already moved (world.hand_over).
func handed_over(beside: Dictionary, left: MapData, left_view: MapView) -> void:
	var offset: Vector2i = beside["offset"]
	drawn.erase(beside["id"])
	for id: String in drawn:
		drawn[id]["offset"] -= offset
		if drawn[id]["view"] != null:
			drawn[id]["view"].offset = Vector2(drawn[id]["offset"] * MapView.TILE)
	beside["view"].offset = Vector2.ZERO
	left_view.offset = Vector2(-offset * MapView.TILE)
	var road := {}
	for out: Dictionary in Seam.roads_out(beside["data"]):
		if out["to"] == left.id:
			road = out
	drawn[left.id] = {"id": left.id, "data": left, "view": left_view, "offset": -offset, "state": "ready", "road": road, "slices": _slicer()}
	_roads_of = null
	handovers += 1
	# The lines and the masks are as they were, and the camera's bounds, the
	# ridge and the reflections' water stand where they stood (the camera and
	# the ridge moved with the world; the water is laid out in the plane).


## Whether this hand-over saves (crossing back and forth saves once), and
## noted if it does.
func saves_now() -> bool:
	var now := GameClock.msec()
	if not Seam.saves(now, saved_at):
		return false
	saved_at = now
	saves += 1
	return true


## Whether the maps wanted beside the hero are all drawn and stitched (the
## harness waits for it before walking over a line, `seamless`).
func settled() -> bool:
	return drawn.values().all(func(beside: Dictionary) -> bool: return beside["state"] == "ready")


## Each map of the Reach worked out ahead, the hero's neighbours first: its
## plan (what of it is kept, KeptGround), its kept ground and its music,
## with what the frame has `left` once the maps beside the hero have had
## theirs.
func _warm(left: float, fresh: bool) -> void:
	if left <= 0.0 or not _on_plane(world.map):
		return
	if _warming.is_empty():
		var next := _next_to_warm()
		if next == "":
			return
		_warming = {"id": next, "slices": _slicer()}
		var slices: Slicer = _warming["slices"]
		if next == PLANE:
			# First the plane itself: where each map lies and how big, and the
			# ridge between them.
			for id: String in ReachPlane.maps():
				slices.add("plan_size", ReachPlane.size_of.bind(id))
			slices.add("plan_ridge", Seam.ridge_texture)
		slices.add("plan_load", func() -> void:
			if next == PLANE:
				return
			var data: MapData = world.load_map(next)
			var view := MapView.new(data, null)
			Sound.ready_track(Sound.track_for(next, 0, ""))
			KeptGround.decks_working(data, slices)
			view.planning(data.spawn, slices)
			slices.add("plan_kept", func() -> void:
				KeptGround.working(data, view.look(), MapView.EDGE_PAD, slices)))
	var warming: Slicer = _warming["slices"]
	var warmed := warming.run(left, fresh)
	_spent(warming)
	if warmed:
		_warmed[_warming["id"]] = true
		_warming = {}


## The next map of the Reach to work out ahead: those beside the hero's
## map first, then the rest; "" when all are.
func _next_to_warm() -> String:
	_warmed[world.map.id] = true
	var order: Array[String] = [PLANE]
	for road: Dictionary in Seam.roads_out(world.map):
		order.append(road["to"])
	order.append_array(ReachPlane.maps())
	for id: String in order:
		if not _warmed.has(id) and not drawn.has(id):
			return id
	return ""
