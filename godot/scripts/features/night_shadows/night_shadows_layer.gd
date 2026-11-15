class_name NightShadowsLayer
extends MapLayer
## areas: town field dungeon night
## What blocks the lantern's and the lamps' light on a map (PIX-490), once
## everything stands: a LightOccluder2D at the foot of each thing among the
## actors, worked out from the thing itself (its body's box, or the bottom
## of its picture: NightShadows), never placed by hand, so a prop a feature
## adds tomorrow casts too; and one round each block of tall cells (houses,
## cliffs, a dungeon's walls: NightShadows.outlines). It also puts
## what lies flat on the ground on the floor's light bit (Lights.FLOOR),
## so a shadow falls on it as on the grass round it, and marks the map's flames that may cast
## (`casts`): the LightRig picks the nearest of them frame by frame.
## Nothing a frame here, and nothing by day but the occluders standing by.

## The units the feet are laid in (Slicer), a share of what stands each: a
## fixed count, as what stands is laid by the units before (PIX-304).
const UNITS := 12
## What was laid, kept on the blockers' layer under this name: {"feet",
## "walls"}.
const LAID := "night_shadows"

## The feet's outlines, one a size.
static var _outlines := {}


func build(view: MapView, slices: Slicer) -> void:
	if not NightShadows.on_map(view.data):
		return
	var seen := {"feet": 0, "walls": 0, "lights": PackedVector2Array()}
	slices.add("nightshadows_walls", func() -> void:
		var near := view.data.id not in PunyTerrain.SKYLINE_MAPS
		var solid := NightShadows.solid(view.data.grid, view.outdoor_props.get("drawn", {}),
			PunyTown.houses(view.data.grid).map(func(house: Dictionary) -> Rect2i: return house["rect"]) if near else [], view.layers.has("pieces"))
		seen["walls"] = _walls(view, solid)
		seen["lights"] = _flames(view, solid))
	slices.add_each("nightshadows", UNITS, func(i: int) -> void:
		var standing := view.actors.get_children()
		for k in range(standing.size() * i / UNITS, standing.size() * (i + 1) / UNITS):
			seen["feet"] += int(_foot(standing[k], seen["lights"]))
		if i == UNITS - 1:
			_flatten(view)
			view.tile_layer.set_meta(LAID, {"feet": seen["feet"], "walls": seen["walls"]}))


## An occluder round each block of the map's cells that block a light
## (NightShadows.solid): how many. The village far off (the Reach's block
## of roofs) is one block; a town's houses block by their feet.
static func _walls(view: MapView, solid: Dictionary) -> int:
	var loops := NightShadows.outlines(solid)
	for loop in loops:
		var outline := OccluderPolygon2D.new()
		# The light passes its near edges and stops at its far ones.
		outline.cull_mode = OccluderPolygon2D.CULL_COUNTER_CLOCKWISE
		for k in loop.size():
			loop[k] *= TILE
		outline.polygon = loop
		var occluder := LightOccluder2D.new()
		occluder.occluder = outline
		# The lamps' and the lantern's, never the lightning's (PIX-491).
		occluder.occluder_light_mask = NightShadows.WALLS
		view.under.add_child(occluder)
	return loops.size()


## What was laid on `view`: {"feet", "walls"}, or {} where nothing casts.
static func laid(view: MapView) -> Dictionary:
	if view == null or view.tile_layer == null or not is_instance_valid(view.tile_layer):
		return {}
	return view.tile_layer.get_meta(LAID, {})


## The map's flames (lamps, torches, fires: every light that flickers but a
## burning house's), where they burn in the map's pixels; each marked to
## cast unless it burns in or against a `solid` cell, where its light would
## be shut in (NightShadows.shut_in).
static func _flames(view: MapView, solid: Dictionary) -> PackedVector2Array:
	var out := PackedVector2Array()
	for root: Node in [view.under, view.actors]:
		for node: Node in root.find_children("*", "", true, false):
			var light := node as PointLight2D
			if light == null or not light.get_meta("flicker", false) or light.get_meta("blaze", false):
				continue
			var at := _place(light, root)
			out.append(at)
			if not NightShadows.shut_in(solid, at / TILE):
				light.set_meta("casts", true)
	return out


## Where `node` stands under `root` (both roots lie at the map's offset).
static func _place(node: Node2D, root: Node) -> Vector2:
	var at := node.position
	var above := node.get_parent()
	while above != root and above is Node2D:
		at = (above as Node2D).transform * at
		above = above.get_parent()
	return at


## An occluder at the foot of `node`, one of the actors' standing things:
## its body's box when it has one, else the bottom of its picture; whether
## it got one (no: too low, or a light burns there).
static func _foot(node: Node, lights: PackedVector2Array) -> bool:
	if not node is Node2D:
		return false
	var body: Node = node if node is StaticBody2D else _first(node, func(child: Node) -> bool: return child is StaticBody2D)
	var box := Rect2()
	if body != null:
		var shape: CollisionShape2D = _first(body, func(child: Node) -> bool: return child is CollisionShape2D)
		if shape == null or not shape.shape is RectangleShape2D:
			return false
		var size := NightShadows.foot_of_body((shape.shape as RectangleShape2D).size)
		var middle := shape.position + (_place(body, node) if body != node else Vector2.ZERO)
		box = Rect2(middle - size / 2.0, size)
	elif node is Sprite2D and (node as Sprite2D).texture != null:
		var drawn := (node as Sprite2D).get_rect()
		var foot := NightShadows.foot_of(drawn.size, node.get_meta("tall", false))
		if foot == Vector2.ZERO:
			return false
		box = Rect2(Vector2(drawn.get_center().x - foot.x / 2.0, drawn.end.y - foot.y), foot)
	else:
		return false
	if NightShadows.holds_light(Rect2((node as Node2D).position + box.position, box.size), lights):
		return false
	var occluder := occluder_of(box.size, NightShadows.SCENERY)
	occluder.position = box.get_center()
	node.add_child(occluder)
	return true


## The first node under `node` that `is_one`, or null.
static func _first(node: Node, is_one: Callable) -> Node:
	for child: Node in node.find_children("*", "", true, false):
		if is_one.call(child):
			return child
	return null


## An occluder over a foot `size` pixels, about its middle, blocking the
## lights of `bits` (NightShadows.SCENERY, FOLK).
static func occluder_of(size: Vector2, bits: int) -> LightOccluder2D:
	if not _outlines.has(size):
		var outline := OccluderPolygon2D.new()
		outline.closed = false
		outline.polygon = NightShadows.outline(size)
		_outlines[size] = outline
	var occluder := LightOccluder2D.new()
	occluder.occluder = _outlines[size]
	occluder.occluder_light_mask = bits
	return occluder


## What lies flat on the ground and wasn't yet floor to the lights
## (Lights.FLOOR) is now: the paving, the roads' wear and verges, the flat
## flowers, and what lies beside the tile layers (field decor, crops,
## floors), so a shadow falls on a square as on the grass round it. The
## layers that stand (houses, crowns, ramparts) are left: lit, unshadowed.
static func _flatten(view: MapView) -> void:
	if view.ground == null or not is_instance_valid(view.ground):
		return
	var flat: Array = [view.paving_layer, view.wear_layer, view.verge_layer, view.layers.get("flowers")]
	for child: Node in view.ground.get_children():
		if child is CanvasItem and not child is TileMapLayer:
			flat.append(child)
			flat.append_array(child.find_children("*", "", true, false).filter(func(under: Node) -> bool: return under is CanvasItem))
	for item: Variant in flat:
		if item != null and is_instance_valid(item):
			(item as CanvasItem).light_mask |= Lights.FLOOR
