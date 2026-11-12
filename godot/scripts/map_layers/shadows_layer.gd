class_name ShadowsLayer
extends MapLayer
## areas: town travel field night +deepwood* +saltmere* +greyhold*
## The scenery's shadows on the ground (PIX-449): a soft one under each
## tree, bush and lamp's foot and a slanted one off each house, all falling
## the same way and following the day (DayNight.sun, handed to the shaders
## by LightRig): short and darkest at noon, longer and fainter low, none at
## night when the lamps take over. MapView's `shadows` units, once every
## other unit has drawn what stands and said where it casts (MapLayer.cast,
## `view.casters`); the houses it reads off their plan. A map's standing
## pieces are one mesh and its houses another, each shadow four vertices
## that the shader spreads along the sun's cast (shaders/scenery_shadow
## .gdshader), inside one CanvasGroup, so shadows that meet are one shadow,
## not a darker one; the group darkens the ground under them once
## (shaders/scenery_shade.gdshader). Three nodes a map, nothing a frame but
## the sun's uniform. It lies on the ground under every actor, so it never
## darkens a hero under a tree turned see-through (PIX-429), over what lies
## flat there and under the cliffs, the forest's crowns and the houses.
## Shade's Puny World trees and rocks have a shadow in their art (a dark
## oval under each) and cast none of ours; his Medieval Age art and the
## pieces drawn in code have none.

## A house's drawing is the ground it stands on seen from the front and
## above (its footprint, behind the front wall) and its height: these
## shares of how tall it is drawn.
const HOUSE_GROUND := 0.45
const HOUSE_RISE := 0.5
## A footprint under something standing is this deep for its width.
const FOOT_DEPTH := 0.45
## How the vertices carry a footprint's depth and its caster's height
## together in the UV's y (scenery_shadow.gdshader's PACK).
const PACK := 1024
## The units the shadows are laid in (Slicer), a share of what stands each,
## the last laying the houses and the group: the Deepwood's 2129 at once
## took 2-3 ms on the desktop, a few times that in the browser, past a
## frame's budget beside the hero. A fixed count: what stands is cast by
## the units before, so it can't count them (PIX-304).
const UNITS := 6

static var _shade: ShaderMaterial
static var _pieces := {}


## Under the sky only (GroundLayer's maps): a room's and a dungeon's things
## cast none.
func build(view: MapView, slices: Slicer) -> void:
	var standing := _Mesh.new()
	slices.add_each("shadows", UNITS, func(i: int) -> void:
		if not view.has_ground_layers():
			return
		var casters := view.casters
		for k in range(casters.size() * i / UNITS, casters.size() * (i + 1) / UNITS):
			_stand(standing, casters[k])
		if i == UNITS - 1:
			_lay(view, standing))


## Gone at night, when the lamps take over: the sun's strength is none
## then, and the group's pass rests.
func set_night(view: MapView, night: bool) -> void:
	var group: Node = view.layers.get("shadows")
	if group != null and is_instance_valid(group):
		(group as CanvasItem).visible = not night


## The map's shadows: what stands (laid in `standing`), then the houses, in
## one group on the ground.
static func _lay(view: MapView, standing: _Mesh) -> void:
	var houses: Array[Rect2i] = []
	if view.layers.has("pieces"):
		houses = houses_of(view.buildings["pieces"])
	if standing.points.is_empty() and houses.is_empty():
		return
	var group := CanvasGroup.new()
	group.material = _group_shade()
	# The group's pass covers what its meshes draw past their vertices.
	group.fit_margin = 0.0
	if not standing.points.is_empty():
		group.add_child(standing.piece(false))
	if not houses.is_empty():
		group.add_child(_houses(houses))
	view.ground.add_child(group)
	_settle(view, group)
	view.layers["shadows"] = group


## A standing piece's shadow: an oval round its foot, as wide as the piece
## and FOOT_DEPTH as deep, its middle on the foot's last row: half of it
## shows under the trunk, the rest of the crown's lies behind it.
static func _stand(mesh: _Mesh, caster: Vector4) -> void:
	var wide := maxi(1, roundi(caster.z))
	mesh.add(Vector2(caster.x, caster.y), Vector2i(wide, maxi(2, roundi(wide * FOOT_DEPTH))), roundi(caster.w))


## Each house's shadow: its footprint (HOUSE_GROUND of its drawing, at its
## foot) carried off by the sun as far as HOUSE_RISE of it stands.
static func _houses(houses: Array[Rect2i]) -> MeshInstance2D:
	var mesh := _Mesh.new()
	for house: Rect2i in houses:
		var drawn := Rect2(house.position * TILE, house.size * TILE)
		var ground := roundi(drawn.size.y * HOUSE_GROUND)
		mesh.add(Vector2(drawn.get_center().x, drawn.end.y - ground / 2.0), Vector2i(roundi(drawn.size.x), ground), roundi(drawn.size.y * HOUSE_RISE))
	return mesh.piece(true)


## Each house in `pieces` (cells of their drawing, PunyTown.compose): the
## cells of houses that touch drawn as one, by their bounds.
static func houses_of(pieces: Dictionary) -> Array[Rect2i]:
	var out: Array[Rect2i] = []
	var seen := {}
	for start: Vector2i in pieces:
		if seen.has(start):
			continue
		seen[start] = true
		var bounds := Rect2i(start, Vector2i.ONE)
		var todo: Array[Vector2i] = [start]
		while not todo.is_empty():
			var cell: Vector2i = todo.pop_back()
			bounds = bounds.merge(Rect2i(cell, Vector2i.ONE))
			for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var next := cell + step
				if pieces.has(next) and not seen.has(next):
					seen[next] = true
					todo.append(next)
		out.append(bounds)
	return out


## Over the ground and all that lies flat on it, under the cliffs, the
## forest's crowns, the bridges and the houses: before the cliffs' layer,
## with what was laid flat on the ground's root after its layers (field
## decor, fields, floors, patches) moved under it, in their order.
static func _settle(view: MapView, group: CanvasGroup) -> void:
	var at := view.rim_layer.get_index()
	for child: Node in view.ground.get_children().slice(at):
		if child != group and not child is TileMapLayer:
			view.ground.move_child(child, at)
			at += 1
	view.ground.move_child(group, at)


## The group's shade, one for every map.
static func _group_shade() -> ShaderMaterial:
	if _shade == null:
		_shade = ShaderMaterial.new()
		_shade.shader = preload("res://shaders/scenery_shade.gdshader")
	return _shade


## A mesh of shadows, a shadow at a time.
class _Mesh:
	var points := PackedVector2Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var bounds := Rect2()
	## The farthest a shadow reaches from its vertices.
	var reach := 0.0

	## One shadow: four vertices on its footprint's `middle`, their UVs'
	## signs its corners, their x its width and their y its depth and its
	## caster's height (PACK).
	func add(middle: Vector2, size: Vector2i, tall: int) -> void:
		var first := points.size()
		var uv := Vector2(1 + size.x, 1 + size.y + ShadowsLayer.PACK * tall)
		points.append(middle)
		points.append(middle)
		points.append(middle)
		points.append(middle)
		uvs.append(-uv)
		uvs.append(Vector2(uv.x, -uv.y))
		uvs.append(uv)
		uvs.append(Vector2(-uv.x, uv.y))
		indices.append(first)
		indices.append(first + 1)
		indices.append(first + 2)
		indices.append(first)
		indices.append(first + 2)
		indices.append(first + 3)
		bounds = Rect2(middle, Vector2.ZERO) if first == 0 else bounds.expand(middle)
		reach = maxf(reach, maxf(size.x, size.y) / 2.0 + tall * DayNight.SHADOW_LONGEST + 1.0)

	## The mesh drawn: seen wherever any shadow of it may reach.
	func piece(walls: bool) -> MeshInstance2D:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = points
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_INDEX] = indices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var seen := bounds.grow(reach)
		mesh.custom_aabb = AABB(Vector3(seen.position.x, seen.position.y, -1.0), Vector3(seen.size.x, seen.size.y, 2.0))
		var drawn := MeshInstance2D.new()
		drawn.mesh = mesh
		drawn.material = ShadowsLayer._piece_shade(walls)
		return drawn


## The shadows' own material, the oval's or the walls' (scenery_shadow).
static func _piece_shade(walls: bool) -> ShaderMaterial:
	if not _pieces.has(walls):
		var material := ShaderMaterial.new()
		material.shader = preload("res://shaders/scenery_shadow.gdshader")
		material.set_shader_parameter("walls", walls)
		_pieces[walls] = material
	return _pieces[walls]
