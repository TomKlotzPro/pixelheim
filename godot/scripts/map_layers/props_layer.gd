class_name PropsLayer
extends MapLayer
## areas: town rooms travel +town-age*
## Shade's props standing outdoors, the street lamps among them, and the
## furniture the hero placed in the house (PunyProps, LampArt, PIX-163,
## PIX-311): MapView's `decor_props` units, `furnish`, and the lamps lit at
## night (PIX-359).

## The props drawn a unit (Slicer): a handful.
const PROPS_A_UNIT := 16


## The standing props, a handful a unit.
func build(view: MapView, slices: Slicer) -> void:
	var standing: Array = view.outdoor_props["props"]
	slices.add_each("decor_props", ceili(standing.size() / float(PROPS_A_UNIT)), func(i: int) -> void:
		for prop: Dictionary in standing.slice(i * PROPS_A_UNIT, (i + 1) * PROPS_A_UNIT):
			_add_puny_prop(view, prop))


## The street lamps' glass lit from dusk's end to dawn, cold by day; a lamp
## put out stays out (MapView.lamps_out).
func set_night(view: MapView, night: bool) -> void:
	for lamp: Dictionary in view.lamps:
		if is_instance_valid(lamp["flame"]) and not lamp.get("out", false):
			lamp["flame"].visible = night


## One of Shade's props among the actors (PunyProps): sorted on the bottom of
## its foot, so the hero passes behind it from the north and in front from
## the south, with a body exactly where the foot is.
static func _add_puny_prop(view: MapView, prop: Dictionary) -> Node2D:
	var foot: Rect2 = prop["foot"]
	var sort_y := foot.end.y if foot.has_area() else float(TILE)
	var root := Node2D.new()
	root.position = Vector2(prop["cell"] * TILE) + Vector2(0, sort_y)
	root.add_to_group("decor")
	if prop["kind"] == "fountain":
		var jet := AnimatedSprite2D.new()
		jet.sprite_frames = PunyProps.fountain_sprite_frames()
		jet.centered = false
		jet.position = Vector2(0, -TILE / 2.0 - sort_y)
		jet.play()
		root.add_child(jet)
	elif prop["kind"] == "lamp":
		_add_lamp_post(view, root, prop["cell"], sort_y)
	elif prop["kind"] in ["barrel", "crate"]:
		# At the Puny folk's scale (PIX-313: Shade's stood as tall as the
		# villager beside it), as the settlement keeps them (Hamlet.store);
		# its foot, and what it blocks, as before.
		var art := Hamlet.store(view.data.id, prop["kind"], prop["cell"])
		var still := Sprite2D.new()
		still.texture = HamletArt.texture(art)
		still.centered = false
		still.position = Vector2(0, TILE - HamletArt.size(art).y) - Vector2(0, sort_y)
		root.add_child(still)
	else:
		var lift := 0.0
		if prop["kind"] == "shrine":
			# The stone knight raised on his plinth (PIX-381); his foot, and
			# what he blocks, as before.
			var plinth := Sprite2D.new()
			plinth.texture = RuinArt.plinth()
			plinth.centered = false
			plinth.position = Vector2(0, -sort_y)
			root.add_child(plinth)
			lift = RuinArt.PLINTH_RISE
		for piece: Array in prop["tiles"]:
			var still := Sprite2D.new()
			still.texture = PunyDungeon.sheet().tile_texture(piece[1]) if prop["sheet"] == "dungeon" else PunyProps.texture(piece[1])
			still.centered = false
			still.position = Vector2(piece[0] * TILE) - Vector2(0, sort_y + lift)
			root.add_child(still)
	if foot.has_area():
		var body := StaticBody2D.new()
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = foot.size
		shape.shape = rect
		shape.position = foot.get_center() - Vector2(0, sort_y)
		body.add_child(shape)
		root.add_child(body)
	view.actors.add_child(root)
	view.prop_nodes[prop["cell"]] = root
	return root


## A street lamp (PIX-311: a cold torch read as a bug on the road by day):
## a post with its lantern (LampArt), its foot on the bottom of the cell;
## at night its glass lit (the dark doesn't touch it), a soft halo round
## the glass and its light pooled on the ground about its foot.
static func _add_lamp_post(view: MapView, root: Node2D, cell: Vector2i, sort_y: float) -> void:
	var top := Vector2(0, TILE - LampArt.size().y - sort_y)
	var post := Sprite2D.new()
	post.texture = LampArt.post()
	post.centered = false
	post.position = top
	root.add_child(post)
	var flame := AnimatedSprite2D.new()
	flame.sprite_frames = LampArt.glass()
	flame.material = Lights.unshaded()
	flame.centered = false
	flame.position = top
	flame.play()
	# Each lamp flickers on its own beat.
	flame.frame = absi(hash(cell)) % flame.sprite_frames.get_frame_count("default")
	root.add_child(flame)
	var at := Vector2(cell * TILE) + Vector2(0, TILE - LampArt.size().y)
	var halo := view._add_halo(at + LampArt.HALO_AT, MapView.LAMP_HALO, MapView.LAMP_HALO_PEAK)
	var light := Lights.make(Vector2(cell * TILE) + MapView.LAMP_POOL, MapView.LAMP_REACH, Lights.LAMP, Lights.LAMP_ENERGY, true)
	view.props.add_child(light)
	halo.tree_exiting.connect(light.queue_free)
	halo.set_meta("light", light)
	view.lamps.append({"flame": flame, "unlit": post, "glow": halo})


## Placed furniture in the house: y-sorted sprites that block (rugs lie flat).
static func furnish(view: MapView) -> void:
	for piece in view.actors.get_tree().get_nodes_in_group("furniture"):
		piece.queue_free()
	for cell: Vector2i in view.furniture_cells:
		view.data.covered.erase(cell)
	view.furniture_cells = []
	if view.data.id != "town_house":
		return
	for placed: Dictionary in GameState.household.furniture():
		var item_id: String = placed["itemId"]
		var cell := Vector2i(placed["x"], placed["y"])
		if PunyTown.available():
			_place_furniture(view, item_id, cell)
			continue
		# Without the paid pack the piece isn't drawn, but it still stands
		# in the way.
		if not Town.furniture_blocks(item_id):
			continue
		view.furniture_cells.append(cell)
		view.data.covered[cell] = true
		var body := StaticBody2D.new()
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(TILE, TILE)
		shape.shape = rect
		body.add_child(shape)
		body.position = MapView.center(cell)
		body.add_to_group("furniture")
		body.add_to_group("decor")
		view.actors.add_child(body)


## A piece the hero placed, in Shade's furniture (PunyInterior.PLACED): the
## rug on the floor under everyone, the rest standing on their cell like any
## prop, a whole cell their foot.
static func _place_furniture(view: MapView, item_id: String, cell: Vector2i) -> void:
	var tiles: Array = PunyInterior.PLACED[item_id]
	if not Town.furniture_blocks(item_id):
		for piece: Array in tiles:
			var rug := Sprite2D.new()
			rug.texture = PunyProps.texture(piece[1])
			rug.centered = false
			rug.position = Vector2((cell + piece[0]) * TILE)
			rug.add_to_group("furniture")
			view.ground.add_child(rug)
		return
	var root := _add_puny_prop(view, {
		"kind": item_id, "cell": cell, "tiles": tiles, "sheet": "medieval", "frames": [],
		"foot": Rect2(0, 0, TILE, TILE), "covers": [cell],
	})
	root.add_to_group("furniture")
	view.furniture_cells.append(cell)
	view.data.covered[cell] = true
