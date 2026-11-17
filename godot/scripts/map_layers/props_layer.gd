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
			add_puny_prop(view, prop))


## The street lamps' glass lit from dusk's end to dawn, cold by day; a lamp
## put out stays out (MapView.lamps_out).
func set_night(view: MapView, night: bool) -> void:
	for lamp: Dictionary in view.lamps:
		if is_instance_valid(lamp["flame"]) and not lamp.get("out", false):
			lamp["flame"].visible = night


## One of Shade's props among the actors (PunyProps): sorted on the bottom of
## its foot, so the hero passes behind it from the north and in front from
## the south, with a body exactly where the foot is.
static func add_puny_prop(view: MapView, prop: Dictionary) -> Node2D:
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
		_light_fountain(view, root, jet, prop["cell"])
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
		ShadowsLayer.cast_art(view, art, Vector2(prop["cell"] * TILE) + Vector2(0, TILE))
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
		var rows := 1
		for piece: Array in prop["tiles"]:
			var still := Sprite2D.new()
			still.texture = PunyDungeon.sheet().tile_texture(piece[1]) if prop["sheet"] == "dungeon" else PunyProps.texture(piece[1])
			still.centered = false
			still.position = Vector2(piece[0] * TILE) - Vector2(0, sort_y + lift)
			# The well's roof stood over the cells behind it (PIX-429).
			see_through(still)
			root.add_child(still)
			rows = maxi(rows, 1 - (piece[0] as Vector2i).y)
		# The wells, the knight on his plinth and the market's crates cast
		# from their foot, as tall as they are drawn (PIX-524: the roofed
		# well floated beside the lamp and the stall that cast); a fence's
		# run of posts would lay a dark band, so it casts none.
		if prop["kind"] in ["well", "shrine", "stall"]:
			cast(view, root.position + Vector2(foot.get_center().x, 0), foot.size.x, rows * TILE + lift)
	# A lamp hung on a wall stands on nothing (PIX-524).
	if foot.has_area() and not (prop["kind"] == "lamp" and on_wall(view, prop["cell"])):
		var body := StaticBody2D.new()
		# The foot first: the night's shadows are cast from a body's first
		# box (NightShadowsLayer._foot), never from the well's roof over it.
		for box: Rect2 in [foot, prop.get("roof", Rect2())]:
			if not box.has_area():
				continue
			var shape := CollisionShape2D.new()
			var rect := RectangleShape2D.new()
			rect.size = box.size
			shape.shape = rect
			shape.position = box.get_center() - Vector2(0, sort_y)
			body.add_child(shape)
		root.add_child(body)
	view.actors.add_child(root)
	view.prop_nodes[prop["cell"]] = root
	return root


## The square's fountain lit at night (PIX-382 step 3: the plaza was the
## darkest place in the City): its water and its jet drawn again over the
## dark (PunyProps.fountain_lit_frames), the stone left to the night, and
## the water's cold light on the paving round the basin.
static func _light_fountain(view: MapView, root: Node2D, jet: AnimatedSprite2D, cell: Vector2i) -> void:
	var lit := AnimatedSprite2D.new()
	lit.sprite_frames = PunyProps.fountain_lit_frames()
	lit.material = Lights.unshaded()
	lit.centered = false
	lit.position = jet.position
	lit.visible = false
	lit.play()
	root.add_child(lit)
	view.night_glows.append(lit)
	var light := Lights.make(Vector2(cell * TILE) + FOUNTAIN_POOL, FOUNTAIN_REACH, Lights.ICE, FOUNTAIN_ENERGY)
	view.props.add_child(light)
	lit.tree_exiting.connect(light.queue_free)


## Where the fountain's light pools, from its cell's corner (the basin's
## middle), how far and how bright: about a lamp's, a little dimmer.
const FOUNTAIN_POOL := Vector2(16, 18)
const FOUNTAIN_REACH := 64.0
const FOUNTAIN_ENERGY := 0.34


## A street lamp (PIX-311: a cold torch read as a bug on the road by day):
## a post with its lantern (LampArt), its foot on the bottom of the cell;
## at night its glass lit (the dark doesn't touch it), a soft halo round
## the glass and its light pooled on the ground about its foot. In its look
## (PIX-524, `look_of`): at the square's corners a lantern either side of a
## taller post, a halo round each and one light, so the budget holds; hung
## on a house's wall by its corner, a lantern on a bracket, its halo alone
## as the keepers' door lanterns have (test_night_light), no shadow on the
## ground.
static func _add_lamp_post(view: MapView, root: Node2D, cell: Vector2i, sort_y: float) -> void:
	var look := look_of(view, cell)
	var drawn := LampArt.look(look)
	var size: Vector2i = drawn["size"]
	# Its post on the middle of its cell; a bracket's lantern to the house's
	# end, its plate on the wall.
	var top := Vector2((TILE - size.x) / 2.0, TILE - size.y - sort_y)
	var flip := look == "bracket" and on_wall(view, cell + Vector2i.RIGHT)
	var post := Sprite2D.new()
	post.texture = drawn["cold"]
	post.centered = false
	post.position = top
	post.flip_h = flip
	root.add_child(post)
	var flame := AnimatedSprite2D.new()
	flame.sprite_frames = drawn["lit"]
	flame.material = Lights.unshaded()
	flame.centered = false
	flame.position = top
	flame.flip_h = flip
	flame.play()
	# Each lamp flickers on its own beat.
	flame.frame = absi(hash(cell)) % flame.sprite_frames.get_frame_count("default")
	root.add_child(flame)
	var at := Vector2(cell * TILE) + Vector2(top.x, TILE - size.y)
	var halo: Sprite2D
	for glass: Vector2 in drawn["halos"]:
		var spot := at + (Vector2(size.x - glass.x, glass.y) if flip else glass)
		var one := view._add_halo(spot, MapView.LAMP_HALO - (3 if look == "bracket" else 0), MapView.LAMP_HALO_PEAK)
		if halo == null:
			halo = one
		else:
			# Put out with the first (MapView.lamps_out), at its z, not on
			# top of the first's (over the smoke and embers).
			one.reparent(halo)
			one.z_as_relative = false
	view.lamps.append({"flame": flame, "unlit": post, "glow": halo})
	if look == "bracket":
		return
	var light := Lights.make(Vector2(cell * TILE) + MapView.LAMP_POOL, MapView.LAMP_REACH, Lights.LAMP, Lights.LAMP_ENERGY, true)
	view.props.add_child(light)
	halo.tree_exiting.connect(light.queue_free)
	halo.set_meta("light", light)
	lamp_shadow(view, cell, Vector2i(TILE, size.y))


## How the lamp on `cell` looks (LampArt.LOOKS, PIX-524): hung on a house's
## wall (Yards' corner lamps), on a bracket; at the town square's corners
## (Yards.SQUARE_LAMPS), a lantern either side; elsewhere the street lamp.
static func look_of(view: MapView, cell: Vector2i) -> String:
	if on_wall(view, cell):
		return "bracket"
	return "double" if view.data.id == "town" and cell in Yards.SQUARE_LAMPS else "post"


## Whether `cell` is a house's: its roof, or its front's walls and door.
static func on_wall(view: MapView, cell: Vector2i) -> bool:
	var tile := view.data.tile_at(cell)
	return tile.begins_with("roof") or tile.begins_with("door")


## How wide a lamp's shadow is: its post's foot and its lantern.
const LAMP_SHADOW_WIDE := 6.0


## A lamp's shadow by day (PIX-449): a lamp `size` big stands on the bottom
## of `cell`, its foot's last row `clear` rows up; the shadow is the
## post's, long and thin, the lantern at its end.
static func lamp_shadow(view: MapView, cell: Vector2i, size: Vector2i, clear := 1) -> void:
	cast(view, Vector2(cell * TILE) + Vector2(size.x / 2.0, TILE - clear), LAMP_SHADOW_WIDE, size.y - 4)


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
	var root := add_puny_prop(view, {
		"kind": item_id, "cell": cell, "tiles": tiles, "sheet": "medieval", "frames": [],
		"foot": Rect2(0, 0, TILE, TILE), "covers": [cell],
	})
	root.add_to_group("furniture")
	view.furniture_cells.append(cell)
	view.data.covered[cell] = true
