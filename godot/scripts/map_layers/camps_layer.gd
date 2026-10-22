class_name CampsLayer
extends MapLayer
## areas: town rooms travel +town-age*
## The packs' camps, the town's boards, stalls, tents and post box, and the
## houses on fire (PIX-142, PIX-145, PIX-197, PIX-327): MapView's
## `decor_camps` and `decor_ruins` units, the camps' share of `plan_props`,
## the fires burnt and doused and the smoke over the ruins (PIX-359).

## The projects board on the square (PIX-145): a Puny World notice board.
const PROJECT_BOARD := 846
const BOARD_FOOT := Rect2(1, 8, 14, 8)
## Mirelle's counting table (PIX-338): both its cells, its foot the length
## of it, and where its candle burns (RoomArt's bank_desk).
const DESK_FOOT := Rect2(1, 2, 14, 30)
const DESK_FLAME := Vector2(7.5, 14)
## Puny World tents by region: green in the woods, straw in the wetlands,
## red on the ash.
const TENTS := {"forest": 895, "deepwood": 895, "marsh": 706, "mire": 706, "ash": 905}
## The CC0 dungeon sheet's torch flame, planted in the ground by a camp.
const CAMP_TORCH := [16, 17, 18, 19, 20, 21, 22, 23]
## The post house's foot (PIX-325): across its two cells, each blocked over
## x 4..12, y 7..15 as every blocker must be.
const POST_HOUSE_FOOT := Rect2(2, 5, 28, 11)
## Where a camp's pieces may stand around its home, best first: behind it,
## then beside, then in front (the pack itself takes the home and its sides).
const CAMP_RING := [
	Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-2, 0), Vector2i(2, 0), Vector2i(-1, 1), Vector2i(1, 1),
	Vector2i(-2, -1), Vector2i(2, -1), Vector2i(-1, 2), Vector2i(1, 2), Vector2i(0, 2), Vector2i(-2, 1),
	Vector2i(2, 1), Vector2i(0, -2),
]
const TENT_FOOT := Rect2(1, 5, 14, 11)
const TORCH_FOOT := Rect2(5, 9, 6, 7)
## A burning house lights the ground as a few soft pools (PIX-285): one for
## each part of it at most FIRE_POOL cells a side, from the part's middle
## to FIRE_REACH pixels past its corners. A light on every flame put three
## dozen on the square and washed its ash white.
const FIRE_POOL := 6
const FIRE_REACH := 36.0


## The camps, the town's boards and stalls and tent, and the post box: the
## camps' share of the `plan_props` unit, after the props' (MapView).
static func plan_in(view: MapView) -> void:
	view.camps = plan_camps(view.data)
	if view.data.id == "town":
		view.camps[Town.project_board()] = {"kind": "board", "tile": PROJECT_BOARD}
		# Its neighbour wears a wanted poster: the bounties (PIX-156).
		view.camps[Town.bounty_board()] = {"kind": "board", "tile": PROJECT_BOARD, "wanted": true}
		# A festival day's stalls (PIX-159), wherever the ground is open.
		if GameState.holdings.festival_on():
			for stall: Dictionary in Town.festival("stalls"):
				var at := Vector2i(int(stall["x"]), int(stall["y"]))
				if view.data.is_walkable(at) and not view.data.covered.has(at) and not view.camps.has(at):
					view.camps[at] = {"kind": "tent", "tile": int(stall["tile"])}
		# Sela's tent on the square while the inn is rubble (PIX-146).
		var tent := Town.ashes_tent(Town.done_projects(GameState.settlement))
		if tent.x >= 0:
			view.camps[tent] = {"kind": "tent", "tile": TENTS["marsh"]}
		# Mirelle's counting table by the hall once she's settled, her
		# ledger open on it (PIX-338).
		var desk := Town.bank_desk().position
		if GameState.holdings.is_settled("settler_mirelle") and view.data.is_walkable(desk) and view.data.is_walkable(desk + Vector2i.DOWN) \
				and not view.camps.has(desk) and not view.camps.has(desk + Vector2i.DOWN):
			view.camps[desk] = {"kind": "desk", "art": "bank_desk"}
			view.data.covered[desk + Vector2i.DOWN] = true
	# The post box past the bounty board, once Maren's first letter reaches
	# Saltmere (PIX-320).
	if view.data.id == Post.box_map() and GameState.posting.is_open():
		view.camps[Post.box_cell()] = {"kind": "post"}
		# The post house behind it once built (PIX-325).
		var house := Post.house_cells()
		if Post.house_built(GameState.settlement) and house.all(func(cell: Vector2i) -> bool: return view.data.is_walkable(cell) and not view.camps.has(cell)):
			view.camps[house[0]] = {"kind": "post_house"}
			view.data.covered[house[1]] = true
	for cell: Vector2i in view.camps:
		view.data.covered[cell] = true


## Where each wild pack's camp stands: a tent on the first open cell of its
## region in CAMP_RING, and a torch on the next one within two of the tent.
## A night pack keeps none (PIX-252): it comes out of the dark, and a camp,
## drawn once for the visit, would stand empty all day.
static func plan_camps(map: MapData) -> Dictionary:
	var out := {}
	if map.style == "cave":
		return out
	for spawn: Dictionary in Bestiary.spawns_on(map.id):
		if Packs.of_the_night(spawn):
			continue
		var home := Vector2i(spawn["x"], spawn["y"])
		var region := map.region_at(home)
		var fits := func(cell: Vector2i) -> bool:
			return map.is_walkable(cell) and map.region_at(cell) == region and not map.portals.has(cell) and not out.has(cell)
		var tent := Vector2i(-1, -1)
		for offset: Vector2i in CAMP_RING:
			if fits.call(home + offset):
				tent = home + offset
				out[tent] = {"kind": "tent", "tile": TENTS.get(region, 706)}
				break
		if tent.x < 0:
			continue
		for offset: Vector2i in CAMP_RING:
			var cell: Vector2i = home + offset
			if fits.call(cell) and maxi(absi(cell.x - tent.x), absi(cell.y - tent.y)) <= 2:
				out[cell] = {"kind": "torch", "tile": CAMP_TORCH[0]}
				break
	return out


## The camps standing, then the town's ruins.
func build(view: MapView, slices: Slicer) -> void:
	slices.add("decor_camps", func() -> void:
		for cell: Vector2i in view.camps:
			_add_camp_piece(view, cell, view.camps[cell]))
	if view.data.id == "town":
		slices.add("decor_ruins", func() -> void: _decor_ruins(view))


## The town's ruins smoking, and on the night of the fire still burning
## (PIX-151), but for the ones the hero put out (PIX-197): those smoulder,
## as the ruins do the days after.
static func _decor_ruins(view: MapView) -> void:
	var burning := GameState.progression.prologue != Prologue.DONE
	var ruins := Town.ruins(Town.done_projects(GameState.settlement))
	for i in ruins.size():
		if burning and i not in GameState.progression.prologue_doused:
			view.fires.append({"rect": ruins[i]["rect"], "nodes": _add_fire(view, ruins[i]["rect"]), "ruin": i})
		else:
			_add_smoke(view, ruins[i]["rect"])


## A house on fire (the Night of Ash's ruins, the Night of Bells' roofs;
## PIX-327, FireArt): our own flames standing on what burns, y-sorted with
## the actors, each playing at its own pace (calmer with Reduce motion);
## coals alight on a fallen floor, smoke rising off the house and sparks
## flying from it (shaders/fire_*.gdshader; no sparks with Reduce motion).
## Its light falls in a few soft pools (fire_pools), not one to a flame,
## and flickers as a blaze does (Lights.blaze). No glow round each flame:
## the flames are bright enough to bloom.
static func _add_fire(view: MapView, rect: Rect2i) -> Array[Node2D]:
	var nodes: Array[Node2D] = []
	for pool: Dictionary in fire_pools(rect):
		var light := Lights.blaze(pool["at"], pool["radius"])
		view.props.add_child(light)
		nodes.append(light)
	var still := GameState.settings.reduce_motion
	for flame: Dictionary in FireArt.plan(rect, _burning(view, rect)):
		var size: Vector2i = FireArt.KINDS[flame["kind"]]
		var foot: Vector2 = flame["at"]
		var sprite := AnimatedSprite2D.new()
		sprite.sprite_frames = FireArt.frames(flame["kind"], flame["variant"])
		sprite.centered = false
		# Drawn in front of what stands above its sort line, its foot where
		# it burns from.
		sprite.position = Vector2(foot.x, flame["sort"])
		sprite.offset = Vector2(-(size.x / 2), foot.y - float(flame["sort"]) - size.y)
		sprite.frame = flame["frame"]
		sprite.speed_scale = FireArt.pace(flame, still)
		sprite.material = Lights.unshaded()
		sprite.set_meta("fire", "flames")
		sprite.add_to_group("decor")
		view.actors.add_child(sprite)
		sprite.play()
		nodes.append(sprite)
	var air := FireArt.air(rect)
	var seed := float(absi(rect.position.x * 31 + rect.position.y * 17) % 97) / 9.7
	nodes.append(_fire_air(view, "coals", air["coals"], preload("res://shaders/fire_coals.gdshader"), 0, {"seed": seed}))
	nodes.append(_fire_air(view, "smoke", air["smoke"], preload("res://shaders/fire_smoke.gdshader"), 5, {
		"source": air["source"], "spread": rect.size.x * TILE / 2.0, "seed": seed,
	}))
	if not still:
		nodes.append(_fire_air(view, "sparks", air["sparks"], preload("res://shaders/fire_sparks.gdshader"), 6, {"born": air["born"], "seed": seed}))
	return nodes


## What burns over `rect` (cells), for FireArt.plan: the grid's tiles (a
## ruin's frame, rubble and ash; a standing house's roof), and a house's
## windows where its front has them.
static func _burning(view: MapView, rect: Rect2i) -> Dictionary:
	var tiles := {}
	var pieces: Dictionary = view.buildings.get("pieces", {})
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var cell := Vector2i(x, y)
			tiles[cell] = "window" if pieces.get(cell, -1) == PunyTown.WINDOW else String(view.data.grid.get(cell, ""))
	return tiles


static var _blank: ImageTexture


## A burning house's coals, smoke or sparks (`part`): a quad over `rect`
## (map pixels, whole) drawn by `shader`, `z` over the actors. It fades
## rather than shrinks as the fire goes out (douse).
static func _fire_air(view: MapView, part: String, rect: Rect2, shader: Shader, z: int, params: Dictionary) -> Sprite2D:
	if _blank == null:
		var white := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		white.fill(Color.WHITE)
		_blank = ImageTexture.create_from_image(white)
	var quad := Sprite2D.new()
	quad.texture = _blank
	quad.centered = false
	quad.position = rect.position.floor()
	quad.scale = rect.size.floor()
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("size", rect.size.floor())
	for key: String in params:
		material.set_shader_parameter(key, params[key])
	quad.material = material
	quad.z_index = z
	quad.set_meta("fire", part)
	quad.set_meta("fades", true)
	quad.add_to_group("decor")
	view.props.add_child(quad)
	return quad


## Where a burning house's light falls (PIX-285): [{at, radius}], a pool in
## the middle of each part of `rect` (cells) at most FIRE_POOL cells a side,
## in map pixels.
static func fire_pools(rect: Rect2i) -> Array[Dictionary]:
	var parts := Vector2i(ceili(rect.size.x / float(FIRE_POOL)), ceili(rect.size.y / float(FIRE_POOL)))
	var part := Vector2(rect.size * TILE) / Vector2(parts)
	var out: Array[Dictionary] = []
	for j in parts.y:
		for i in parts.x:
			var at := Vector2(rect.position * TILE) + part * (Vector2(i, j) + Vector2(0.5, 0.5))
			out.append({"at": at, "radius": part.length() / 2.0 + FIRE_REACH})
	return out


## A roof set burning on the Night of Bells (PIX-253 step 9): flames over
## the house, as over the Night of Ash's ruins. Its index in `fires`, for
## douse.
static func burn(view: MapView, rect: Rect2i) -> int:
	view.fires.append({"rect": rect, "nodes": _add_fire(view, rect)})
	return view.fires.size() - 1


## The fire on ruin `ruin` (Town.ruins' order), if it still burns.
static func douse_ruin(view: MapView, ruin: int, seconds := 1.2) -> void:
	for i in view.fires.size():
		if int(view.fires[i].get("ruin", -1)) == ruin:
			douse(view, i, seconds)


## The fire on one burning ruin (the Night of Ash's dawn, PIX-197) gutters
## out: its flames shrink and fade over `seconds`, its smoke thins and its
## sparks and coals die, its light dims, a last breath of smoke goes up, and
## they're gone (a ruin smouldering on).
static func douse(view: MapView, index: int, seconds := 1.2) -> void:
	if index < 0 or index >= view.fires.size():
		return
	var fire: Dictionary = view.fires[index]
	if fire.get("out", false):
		return
	fire["out"] = true
	for node: Node2D in fire["nodes"]:
		if not is_instance_valid(node):
			continue
		view.night_glows.erase(node)
		var out := node.create_tween().set_parallel()
		if node is PointLight2D:
			# The LightRig brings a light up to its "energy" every frame.
			out.tween_method(func(energy: float) -> void: node.set_meta("energy", energy), float(node.get_meta("energy", 0.0)), 0.0, seconds)
		elif node.has_meta("fades"):
			# The smoke thins and the sparks and coals die (PIX-327).
			out.tween_property(node, "modulate:a", 0.0, seconds)
		else:
			out.tween_property(node, "scale", node.scale * Vector2(0.2, 0.05), seconds).set_ease(Tween.EASE_IN)
			out.tween_property(node, "modulate:a", 0.0, seconds)
		out.chain().tween_callback(node.queue_free)
	var rect: Rect2i = fire["rect"]
	var puff := MapView._still(CPUParticles2D.new())
	puff.position = Vector2(rect.position * TILE) + Vector2(rect.size * TILE) / 2.0
	puff.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	puff.emission_rect_extents = Vector2(rect.size * TILE) / 2.0
	puff.amount = 24
	puff.lifetime = 2.6
	puff.one_shot = true
	puff.explosiveness = 0.6
	puff.direction = Vector2.UP
	puff.spread = 25.0
	puff.gravity = Vector2(4, -6)
	puff.initial_velocity_min = 6.0
	puff.initial_velocity_max = 14.0
	puff.scale_amount_min = 2.0
	puff.scale_amount_max = 4.0
	var fade := Gradient.new()
	fade.set_color(0, Color(0.55, 0.52, 0.5, 0.7))
	fade.set_color(1, Color(0.6, 0.58, 0.56, 0.0))
	puff.color_ramp = fade
	puff.z_index = 6
	puff.add_to_group("decor")
	view.props.add_child(puff)
	puff.finished.connect(puff.queue_free)
	puff.emitting = true
	# A ruin put out smoulders on, as the ruins do the days after.
	if fire.has("ruin"):
		_add_smoke(view, rect)


## Smoke and embers over a burnt house (PIX-146): pixel motes drifting up
## from its footing, the embers quicker and fewer (a `share` of them, for a
## house seen small from afar). Still with Reduce motion.
static func _add_smoke(view: MapView, rect: Rect2i, share := 1.0) -> void:
	if GameState.settings.reduce_motion:
		return
	var middle := Vector2(rect.position * TILE) + Vector2(rect.size * TILE) / 2.0
	var extents := (Vector2(rect.size * TILE) / 2.0 - Vector2(10, 10)).max(Vector2(3, 3))
	for ember in [false, true]:
		var motes := MapView._still(CPUParticles2D.new())
		motes.position = middle
		motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		motes.emission_rect_extents = extents
		motes.amount = maxi(1, roundi((4 if ember else 12) * share))
		motes.lifetime = 1.6 if ember else 3.5
		motes.direction = Vector2.UP
		motes.spread = 20.0
		motes.gravity = Vector2(3, -4)
		motes.initial_velocity_min = 10.0 if ember else 5.0
		motes.initial_velocity_max = 18.0 if ember else 10.0
		motes.scale_amount_min = 1.0 if ember else 2.0
		motes.scale_amount_max = 1.0 if ember else 3.0
		var fade := Gradient.new()
		fade.set_color(0, Color(1.0, 0.55, 0.15, 0.95) if ember else Color(0.32, 0.3, 0.3, 0.55))
		fade.set_color(1, Color(1.0, 0.3, 0.05, 0.0) if ember else Color(0.4, 0.38, 0.38, 0.0))
		motes.color_ramp = fade
		motes.z_index = 6
		motes.add_to_group("decor")
		view.props.add_child(motes)


## A tent pitched on the map as it stands (PIX-253 step 9: Iva's on the
## square's edge, the Night of Bells): drawn among the actors, its cell
## blocked, gone with the visit.
static func pitch_tent(view: MapView, cell: Vector2i) -> void:
	if view.camps.has(cell):
		return
	view.camps[cell] = {"kind": "tent", "tile": TENTS["marsh"]}
	view.data.covered[cell] = true
	_add_camp_piece(view, cell, view.camps[cell])


## A camp's tent or torch: sorted among the actors at its foot, which blocks.
static func _add_camp_piece(view: MapView, cell: Vector2i, piece: Dictionary) -> void:
	var foot: Rect2 = {"tent": TENT_FOOT, "board": BOARD_FOOT, "post": MapView.HAMLET_FOOT, "post_house": POST_HOUSE_FOOT, "desk": DESK_FOOT}.get(piece["kind"], TORCH_FOOT)
	var root := Node2D.new()
	root.position = Vector2(cell * TILE) + Vector2(0, foot.end.y)
	root.add_to_group("decor")
	var sprite: Node2D
	if piece["kind"] == "torch":
		var flame := AnimatedSprite2D.new()
		flame.sprite_frames = _camp_torch_frames()
		flame.play()
		flame.material = Lights.unshaded()
		# A camp's fire lights the camp (PIX-221), and sparks rise off it
		# (PIX-225).
		root.add_child(Lights.make(Vector2(TILE / 2.0, -foot.end.y + 4), 72.0, Lights.FIRE, Lights.FIRE_ENERGY, true))
		var embers := MapView._still(Motes.make_embers(3))
		embers.position = Vector2(TILE / 2.0, -foot.end.y - 2 - LampArt.STAKE_LIFT)
		embers.z_index = 6
		root.add_child(embers)
		# Each camp's fire flickers on its own beat.
		flame.frame = absi(hash(cell)) % CAMP_TORCH.size()
		sprite = flame
		# On a stake driven into the ground, not a flame afloat (PIX-311).
		var stake := Sprite2D.new()
		stake.texture = LampArt.stake()
		stake.centered = false
		stake.position = Vector2(0, -foot.end.y)
		root.add_child(stake)
	elif piece["kind"] == "post":
		# The post box (PIX-320), its pennant up while it holds the day's
		# post (show_post_box), standing on the bottom of its cell.
		view.post_box = Sprite2D.new()
		sprite = view.post_box
		view.show_post_box()
	elif piece["kind"] == "post_house":
		view.post_house = Sprite2D.new()
		view.post_house.texture = HamletArt.texture("post_house")
		sprite = view.post_house
	else:
		var tent := Sprite2D.new()
		tent.texture = RoomArt.texture(piece["art"]) if piece.has("art") else PunyTerrain.sheet().tile_texture(piece["tile"])
		sprite = tent
		# Her ledger read by its candle at night.
		if piece["kind"] == "desk":
			view._add_candle(Vector2(cell * TILE) + DESK_FLAME)
	sprite.set("centered", false)
	sprite.position = Vector2(0, -foot.end.y - (LampArt.STAKE_LIFT if piece["kind"] == "torch" else 0))
	if piece["kind"] in ["post", "post_house"]:
		sprite.position.y = TILE - HamletArt.size("post_box" if piece["kind"] == "post" else "post_house").y - foot.end.y
	root.add_child(sprite)
	if piece.get("wanted", false):
		var poster := Sprite2D.new()
		poster.texture = _wanted_poster()
		poster.centered = false
		poster.position = Vector2(4, 3)
		sprite.add_child(poster)
	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = foot.size
	shape.shape = rect
	shape.position = foot.get_center() - Vector2(0, foot.end.y)
	body.add_child(shape)
	root.add_child(body)
	view.actors.add_child(root)


static var _torch_frames: SpriteFrames
static var _poster: ImageTexture


## The Slayer's Ledger's bounty pinned over the board's notes (PIX-338): a
## red pin, the beast's claw raked across it, the reward's line under.
const POSTER := [
	"....r....",
	"ffffrffff",
	"ffkffkffk",
	"ffkffkffk",
	"fkffkffkf",
	"fkffkffkf",
	"fffffffff",
	"fsssssssf",
	"sssssssss",
]
const POSTER_INKS := {"f": "f1e3c0", "s": "c9b48a", "r": "b33a2c", "k": "8a2a20"}


static func _wanted_poster() -> ImageTexture:
	if _poster == null:
		var art := Image.create(POSTER[0].length(), POSTER.size(), false, Image.FORMAT_RGBA8)
		for y in POSTER.size():
			for x in POSTER[y].length():
				if POSTER[y][x] != ".":
					art.set_pixel(x, y, Color(POSTER_INKS[POSTER[y][x]]))
		_poster = ImageTexture.create_from_image(art)
	return _poster


static func _camp_torch_frames() -> SpriteFrames:
	if _torch_frames == null:
		_torch_frames = SpriteFrames.new()
		_torch_frames.set_animation_speed("default", 8.0)
		for tile: int in CAMP_TORCH:
			_torch_frames.add_frame("default", PunyDungeon.sheet().tile_texture(tile))
	return _torch_frames
