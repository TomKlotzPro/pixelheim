extends GutTest
## A player always sees their hero (PIX-429, PIX-430: the first agent
## playtest lost the hero under the village well's roof and in the west
## garden's grove). Whatever stands over a cell the hero can stand on - a
## tree's canopy, the well's roof, the mire's reeds - turns see-through round
## them (shaders/see_through.gdshaderinc), so on every outdoor map, with the
## paid pack and without, no walkable cell leaves the hero hidden by
## something that doesn't. The arch over a gate's passage is meant to be
## walked under (PIX-425): it covers the hero's middle, never their head.

const MAPS := ["town@0", "town@4", "overworld", "deepwood", "saltmere", "greyhold", "frostgate", "blackiron", "mirefen", "mountain_road", "morvax_forge"]
## More of the hero than this hidden is lost (the gate's arch: about 0.8).
const LOST := 0.9


## Every opaque pixel of the hero's figure as it stands, from their feet:
## the idle frame facing the player, centred on them and lifted as Player
## draws it.
func _figure() -> Array[Vector2]:
	var art := GameState.upkeep.hero_art()
	var frames := PunyArt.frames(art)
	var texture := frames.get_frame_texture(PunyArt.pick(frames, "idle", "down"), 0)
	var image := texture.get_image()
	var corner := Vector2(0, PunyArt.lift(art)) - texture.get_size() / 2.0
	var out: Array[Vector2] = []
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a > 0.5:
				out.append(corner + Vector2(x, y) + Vector2(0.5, 0.5))
	return out


## Whether `item` draws an opaque pixel at `local` (its own coordinates).
func _opaque(item: CanvasItem, local: Vector2) -> bool:
	if item is Sprite2D:
		var sprite := item as Sprite2D
		return sprite.get_rect().has_point(local) and sprite.is_pixel_opaque(local)
	var shown := item as AnimatedSprite2D
	var texture := shown.sprite_frames.get_frame_texture(shown.animation, shown.frame)
	var size := texture.get_size()
	var at := local - shown.offset + (size / 2.0 if shown.centered else Vector2.ZERO)
	if not Rect2(Vector2.ZERO, size).has_point(at):
		return false
	return texture.get_image().get_pixelv(Vector2i(at)).a > 0.5


## Whether `item` turns see-through round the hero: a prop's own material,
## or a tree's (region_tint standing alone).
func _sees_through(item: CanvasItem) -> bool:
	var material := item.material as ShaderMaterial
	if material == null:
		return false
	if material.shader.resource_path == "res://shaders/see_through.gdshader":
		return true
	return material.shader.resource_path == "res://shaders/region_tint.gdshader" and material.get_shader_parameter("sway_alone") == true


## What the view draws among the actors: [the y it is sorted on, the item,
## from the stand to the item, sees through], bucketed by the cells its
## drawing covers.
func _drawn(view: MapView) -> Dictionary:
	var stand := view.actors
	var buckets := {}
	for sorted: Node in stand.get_children():
		if not sorted is Node2D or not sorted.is_in_group("decor"):
			continue
		for item: Node in [sorted] + sorted.find_children("*", "", true, false):
			if not (item is Sprite2D or item is AnimatedSprite2D) or not (item as CanvasItem).is_visible_in_tree():
				continue
			var to_item: Transform2D = ((item as Node2D).get_global_transform().affine_inverse() * stand.get_global_transform())
			var rect: Rect2 = to_item.affine_inverse() * _local_rect(item)
			var entry := [(sorted as Node2D).position.y, item, to_item, _sees_through(item)]
			for cy in range(floori(rect.position.y / 16.0), floori(rect.end.y / 16.0) + 1):
				for cx in range(floori(rect.position.x / 16.0), floori(rect.end.x / 16.0) + 1):
					var cell := Vector2i(cx, cy)
					if not buckets.has(cell):
						buckets[cell] = []
					buckets[cell].append(entry)
	return buckets


func _local_rect(item: Node) -> Rect2:
	if item is Sprite2D:
		return (item as Sprite2D).get_rect()
	var shown := item as AnimatedSprite2D
	var size := shown.sprite_frames.get_frame_texture(shown.animation, shown.frame).get_size()
	return Rect2(shown.offset - (size / 2.0 if shown.centered else Vector2.ZERO), size)


## How much of the hero standing in the middle of `cell` is hidden: by
## what doesn't see through (`solid`), or by anything at all.
func _hidden(buckets: Dictionary, figure: Array[Vector2], cell: Vector2i, solid := true) -> float:
	var hero := MapView.center(cell)
	var near: Array = []
	for at: Vector2i in [cell, cell + Vector2i.UP, cell + Vector2i.LEFT, cell + Vector2i.RIGHT, cell + Vector2i(-1, -1), cell + Vector2i(1, -1)]:
		for entry: Array in buckets.get(at, []):
			if entry[0] > hero.y and not (solid and entry[3]) and not near.has(entry):
				near.append(entry)
	if near.is_empty():
		return 0.0
	var hidden := 0
	for pixel: Vector2 in figure:
		for entry: Array in near:
			if _opaque(entry[1], (entry[2] as Transform2D) * (hero + pixel)):
				hidden += 1
				break
	return hidden / float(figure.size())


func _view(map_id: String, root: Node2D) -> MapView:
	var actors := Node2D.new()
	actors.y_sort_enabled = true
	root.add_child(actors)
	# The town as it stood after the fire and as it stands grown.
	var map := MapData.load_tiered("town", Town.projects_through(int(map_id.get_slice("@", 1))), 1) if map_id.begins_with("town@") else MapData.load_by_id(map_id)
	var view := MapView.new(map, actors)
	view.plan(map.spawn)
	view.build(root)
	return view


func test_no_walkable_cell_hides_the_hero() -> void:
	var figure := _figure()
	assert_gt(figure.size(), 50, "the hero's figure read from their frame")
	var was := PunyTown.withheld
	for withheld: bool in [false, true]:
		PunyTown.withheld = withheld
		for map_id: String in MAPS:
			var root := Node2D.new()
			add_child_autofree(root)
			var view := _view(map_id, root)
			var buckets := _drawn(view)
			var lost := []
			for cell: Vector2i in view.data.grid:
				# A gate or a door takes the hero on before they stand in it.
				if view.data.is_walkable(cell) and not view.data.portals.has(cell) and _hidden(buckets, figure, cell) >= LOST:
					lost.append(cell)
			assert_eq(lost, [], "%s (%s): the hero lost there" % [map_id, "cc0" if withheld else "pack"])
			if map_id == "town@0" and not withheld and PunyTown.available():
				# The well's roof and the grove the playtest lost the hero
				# under: there still, seen through.
				for cell: Vector2i in [Vector2i(34, 30), Vector2i(9, 16)]:
					assert_gte(_hidden(buckets, figure, cell, false), LOST, "the hero under it at %s" % cell)
			root.free()
	PunyTown.withheld = was
