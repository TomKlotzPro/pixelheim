class_name SettlementsLayer
extends MapLayer
## areas: town rooms travel +town-age*
## Each settlement's set dressing, what the Post's routes put up, chimney
## smoke and the village seen far off (Hamlet, Routes, PIX-248, PIX-313,
## PIX-322): MapView's `decor_hamlet` and `decor_routes` units, and the
## smoke and village life its lit windows add (PIX-359).

## Chimney smoke (PIX-313): a cottage's grey, a forge's dark, each thinning
## to nothing; out of the mouth of Shade's chimney, from its cell's top
## left.
const SMOKE := Color(0.55, 0.53, 0.53, 0.7)
const SMOKE_FORGE := Color(0.22, 0.2, 0.21, 0.85)
const CHIMNEY_MOUTH := Vector2(8, 2)
## A waystation's ember lamp at night (PIX-322): the halo round its shard
## and its warmth pooled on the ground about its foot (from its cell's top
## left), reaching this far.
const EMBER_HALO := 12
const EMBER_HALO_PEAK := 0.36
const EMBER_POOL := Vector2(8, 12)
const EMBER_REACH := 80.0
## How far a miner's lantern and the fire under Morvax's door light the
## ground at night.
const LANTERN_REACH := 44.0
const FORGE_REACH := 52.0
## A burnt house seen small from afar smokes with this share of a ruin's
## motes in town (PIX-248).
const VILLAGE_RUIN_SMOKE := 0.4
## Its lamps lit one to each this many cells about (PIX-311).
const VILLAGE_LAMPS_APART := 2
## The halo round each of the bunting's lanterns at night (PIX-382).
const BUNTING_HALO := 5
const BUNTING_HALO_PEAK := 0.45


## The settlement's dressing, then the routes' pieces.
func build(view: MapView, slices: Slicer) -> void:
	slices.add("decor_hamlet", func() -> void: _decor_hamlet(view))
	slices.add("decor_routes", func() -> void: _decor_routes(view))


## A thread of smoke from a house's chimney (PIX-313: out of the chimney's
## own mouth, where the house has one); without one, up from its door to
## the roof's top, a little to the side. A house whose settlement raised a
## stack of its own (Morvax's forge) smokes from that (_decor_hamlet).
static func _add_chimney_smoke(view: MapView, door: Vector2i) -> void:
	for piece: Dictionary in view.hamlet["pieces"]:
		if piece["kind"] == "roof" and absi(piece["cell"].x - door.x) <= 4 and piece["cell"].y < door.y:
			return
	var chimney := chimney_of(door, view.buildings["decor"])
	if chimney.x >= 0:
		_add_smoke_thread(view, Vector2(chimney * TILE) + CHIMNEY_MOUTH)
		return
	var top := door
	while view.buildings["pieces"].has(top + Vector2i.UP):
		top += Vector2i.UP
	_add_smoke_thread(view, Vector2(top * TILE) + Vector2(TILE * 1.5, 2))


## The chimney on the house whose door is `door`, among a drawing's `decor`
## (PunyTown's chimneys): the nearest above the door within a house's
## reach of it, or (-1, -1).
static func chimney_of(door: Vector2i, decor: Dictionary) -> Vector2i:
	var best := Vector2i(-1, -1)
	for cell: Vector2i in decor:
		if decor[cell] != PunyTown.CHIMNEY[1] or cell.y >= door.y or door.y - cell.y > 8 or absi(cell.x - door.x) > 6:
			continue
		if best.x < 0 or absi(cell.x - door.x) + door.y - cell.y < absi(best.x - door.x) + door.y - best.y:
			best = cell
	return best


## The village far off (PIX-248): smoke from every roof (the houses are the
## paid pack's) and over what still lies in ruins, and its lamps lit at
## night (its windows light with the town's). Small glows with small lights:
## the village is small here.
static func _add_village_life(view: MapView) -> void:
	if PunyTown.available():
		for at: Vector2 in view.skyline["smoke"]:
			_add_smoke_thread(view, at)
	for ruin: Rect2i in view.skyline["ruins"]:
		CampsLayer._add_smoke(view, ruin, VILLAGE_RUIN_SMOKE)
	# Every lamp glows, but the town's lamps stand close here, small: one
	# light to each few (PIX-311), so its blocks of ground keep room for
	# what moves at the City age (test_night_light).
	var lit: Array[Vector2i] = []
	for cell: Vector2i in view.skyline["lamps"]:
		var halo := view._add_halo(MapView.center(cell), 5, 0.5)
		if lit.any(func(other: Vector2i) -> bool: return maxi(absi(other.x - cell.x), absi(other.y - cell.y)) <= VILLAGE_LAMPS_APART):
			continue
		lit.append(cell)
		var light := Lights.make(MapView.center(cell), 26.0, Lights.LAMP, Lights.LAMP_ENERGY, true)
		view.props.add_child(light)
		halo.set_meta("light", light)


## A thread of chimney smoke rising from `at`, grey enough to read on a
## bright day (PIX-313: a cottage's was a few pale specks), thinning to
## nothing as the wind takes it; a forge's (`forge`) thick and dark. Still
## with Reduce motion.
static func _add_smoke_thread(view: MapView, at: Vector2, forge := false) -> void:
	if GameState.settings.reduce_motion:
		return
	var motes := MapView._still(CPUParticles2D.new())
	motes.position = at
	motes.amount = 10 if forge else 7
	motes.lifetime = 4.5 if forge else 4.0
	# Already rising when the map comes into view.
	motes.preprocess = motes.lifetime
	motes.direction = Vector2.UP
	motes.spread = 10.0
	motes.gravity = Vector2(4, -3)
	motes.initial_velocity_min = 5.0
	motes.initial_velocity_max = 9.0
	motes.scale_amount_min = 3.0 if forge else 2.0
	motes.scale_amount_max = 4.0 if forge else 3.0
	var fade := Gradient.new()
	var first: Color = SMOKE_FORGE if forge else SMOKE
	fade.set_color(0, first)
	fade.set_color(1, Color(first.lightened(0.35), 0.0))
	fade.add_point(0.35, Color(first.lightened(0.15), first.a * 0.8))
	motes.color_ramp = fade
	motes.z_index = 6
	motes.add_to_group("decor")
	view.props.add_child(motes)


## A settlement's set dressing (Hamlet, PIX-313): what stands sorted among
## the actors on its foot with a box on each cell it blocks, what lies flat
## on the ground, boats afloat on the swell, lanterns on the walls lit at
## night, a washing line between two walls, Morvax's forge stack smoking and
## his fire's light under the door; and Pixelheim's planters, and the wares
## on its stalls and its cart (PIX-382 step 4).
static func _decor_hamlet(view: MapView) -> void:
	# What stands on each cell, so a ware laid on it is drawn over it, and a
	# stall's awning drawn again over its wares, so they sit under it.
	var stood := {}
	var awnings := {}
	for piece: Dictionary in view.hamlet["pieces"]:
		var cell: Vector2i = piece["cell"]
		match String(piece["kind"]):
			"on":
				var ware := Sprite2D.new()
				ware.centered = false
				ware.texture = PunyProps.texture(piece["tile"]) if piece.has("tile") else HamletArt.texture(piece["art"])
				if stood.has(cell):
					ware.position = Vector2(piece["on"]) - Vector2(0, TILE)
					(stood[cell] as Node2D).add_child(ware)
					if awnings.has(cell):
						(stood[cell] as Node2D).move_child(awnings[cell], -1)
				else:
					stand_on(view, ware, cell, Vector2(piece["on"]))
			"line":
				if piece.get("art", "") == "bunting":
					_add_bunting(view, cell, int(piece["line"]), int(piece.get("high", 0)))
				else:
					var line := Sprite2D.new()
					line.texture = HamletArt.washing(int(piece["line"]))
					line.centered = false
					stand_on(view, line, cell, Vector2.ZERO)
			"glow":
				_add_door_glow(view, cell)
			"flat":
				var flat := Sprite2D.new()
				flat.texture = HamletArt.texture(piece["art"])
				flat.centered = false
				flat.position = Vector2(cell * TILE) + Vector2(0, TILE - HamletArt.size(piece["art"]).y)
				flat.add_to_group("decor")
				view.ground.add_child(flat)
			"moored":
				var boat := AnimatedSprite2D.new()
				boat.sprite_frames = HamletArt.afloat(piece["art"])
				boat.centered = false
				boat.frame = absi(hash(cell)) % 2
				boat.play()
				stand_on(view, boat, cell, Vector2(-HamletArt.AFLOAT_PAD, TILE - boat.sprite_frames.get_frame_texture("default", 0).get_height() + HamletArt.AFLOAT_SINK))
			_:
				var art: String = piece.get("art", "")
				var still := Sprite2D.new()
				still.centered = false
				# One of the pack's own stands a tile high (PIX-382, the town's
				# bushes, sacks and scarecrows); ours as tall as it's drawn.
				# A planter is the pack's tub, its plant growing out of it.
				var potted: bool = piece.get("pot", false)
				still.texture = PunyProps.texture(PunyProps.TUB if potted else piece["tile"]) if piece.has("tile") else HamletArt.texture(art)
				var tall := TILE if piece.has("tile") else HamletArt.size(art).y
				var root := stand_on(view, still, cell, Vector2(0, TILE - tall))
				stood[cell] = root
				if HamletArt.STALLS.has(art):
					var awning := Sprite2D.new()
					awning.centered = false
					awning.texture = still.texture
					awning.region_enabled = true
					awning.region_rect = Rect2(0, 0, HamletArt.size(art).x, HamletArt.AWNING)
					awning.position = still.position
					root.add_child(awning)
					awnings[cell] = awning
				if potted:
					var plant := Sprite2D.new()
					plant.centered = false
					plant.texture = PunyProps.texture(piece["tile"])
					plant.position = still.position - Vector2(0, PunyProps.POT_RISE)
					root.add_child(plant)
				if piece["kind"] == "stand":
					for taken: Vector2i in piece["cells"]:
						block(view, taken)
					if piece.get("lit", false):
						_add_shine(view, root, cell, art)
					if piece.has("smoke"):
						# Its chimney's mouth, in its pixels (Gunnar's lodge, PIX-324).
						_add_smoke_thread(view, Vector2(cell * TILE) + Vector2(piece["smoke"][0], TILE - HamletArt.size(art).y + int(piece["smoke"][1])))
				elif art == "lantern":
					_add_lantern_light(view, root, cell, not piece.get("dim", false))
				elif art == "forge_stack":
					# The fire's glow in its mouth, untouched by the dark.
					var fire := Sprite2D.new()
					fire.texture = HamletArt.texture("forge_mouth")
					fire.centered = false
					fire.material = Lights.unshaded()
					fire.position = still.position
					root.add_child(fire)
					var mouth := Vector2(cell * TILE) + HamletArt.STACK_MOUTH
					_add_smoke_thread(view, mouth, true)
					if not GameState.settings.reduce_motion:
						var embers := MapView._still(Motes.make_embers(3))
						embers.position = mouth
						embers.z_index = 6
						view.props.add_child(embers)


## The bunting over the City's square (PIX-382, Yards): from the lamp half
## a cell before `cell` to the one half a cell past its last, `high` rows
## up from its row and sorted on it; at night its lanterns lit (the dark
## doesn't touch them), a small halo round each and no light of their own:
## the square's lamps light it.
static func _add_bunting(view: MapView, cell: Vector2i, cells: int, high: int) -> void:
	var drawn := HamletArt.bunting(cells)
	var at := Vector2(-TILE / 2.0, -TILE - high * TILE)
	var day := Sprite2D.new()
	day.texture = drawn["day"]
	day.centered = false
	var root := stand_on(view, day, cell, at)
	var lit := Sprite2D.new()
	lit.texture = drawn["lit"]
	lit.centered = false
	lit.material = Lights.unshaded()
	lit.position = day.position
	lit.visible = false
	root.add_child(lit)
	view.night_glows.append(lit)
	for glass: Vector2 in drawn["lights"]:
		view._add_halo(Vector2(cell * TILE) + at + glass, BUNTING_HALO, BUNTING_HALO_PEAK)


## What the Post's routes put up (PIX-322, Routes.plan), standing among the
## actors on their cells, each blocking them: a fingerpost at each fork
## signed, its name on a plate as the hero comes near ("Bram's Corner", the
## post roads it points down); and each waystation built, its hut (its
## window lit at night, its name on a plate), its post box (full while the
## day's post waits, as the square's), its bench and its ember lamp.
static func _decor_routes(view: MapView) -> void:
	view.waystations = []
	view.ember_lamps = {}
	view.post_boxes = []
	# Lamps close together share a light (PIX-323, Lamps.lit_among).
	var lamp_cells: Array[Vector2i] = []
	for piece: Dictionary in view.routes["pieces"]:
		if piece["kind"] == "lamp":
			lamp_cells.append(piece["cell"])
	var own_light := Lamps.lit_among(lamp_cells)
	for piece: Dictionary in view.routes["pieces"]:
		var cell: Vector2i = piece["cell"]
		var kind := String(piece["kind"])
		var art: String = {"signpost": "signpost", "hut": "hut", "bench": "bench", "lamp": "ember_lamp"}.get(kind, "")
		var sprite := Sprite2D.new()
		sprite.centered = false
		if kind == "box":
			sprite.texture = HamletArt.texture("post_box")
			view.post_boxes.append(sprite)
			stand_on(view, sprite, cell, Vector2(0, TILE - HamletArt.size("post_box").y))
		else:
			# Each lamp in its kind's look (PIX-324).
			sprite.texture = RouteArt.lamp(String(piece.get("lamp", "ember"))) if kind == "lamp" else RouteArt.texture(art)
			var root := stand_on(view, sprite, cell, Vector2(0, TILE - RouteArt.size(art).y))
			if kind == "lamp":
				_add_ember_lamp(view, root, cell, String(piece["place"]), cell in own_light, String(piece.get("lamp", "ember")))
			elif kind == "hut":
				_add_hut_window(view, root)
				view.waystations.append(String(piece["place"]))
		for taken: Vector2i in piece["cells"]:
			block(view, taken)
		if kind == "signpost":
			view.door_signs.append({
				"door": cell, "name": Routes.fork_name(piece["fork"], GameState.post),
				"about": Routes.fork_about(piece["fork"], GameState.post), "node": null, "over": RouteArt.size("signpost").y - TILE + 4,
			})
		elif kind == "hut":
			view.door_signs.append({
				"door": cell, "name": String(Routes.station(piece["place"])["name"]),
				"about": Text.t("Halfway to %s") % Text.mid(Catalog.place_name(piece["place"])), "node": null, "over": RouteArt.size("hut").y - TILE + 4,
			})
	view.show_post_box()


## A waystation's ember lamp (PIX-322): a shard of the mountain's warmth in
## its cage, dull by day; at night alight (the dark doesn't touch it), a
## soft halo round it and its warmth on the ground about its foot. One
## light: test_night_light's budget holds with every waystation built; a
## lamp close by one that has it (`own_light` false) keeps its halo alone,
## a cheaper light, so dozens of lamps hold it too (PIX-323). It burns in
## its `kind`'s colour (PIX-324: sea glass, frost lily, grave moss).
static func _add_ember_lamp(view: MapView, root: Node2D, cell: Vector2i, place: String, own_light := true, kind := "ember") -> void:
	var lit := AnimatedSprite2D.new()
	lit.sprite_frames = RouteArt.ember(kind)
	lit.material = Lights.unshaded()
	lit.centered = false
	lit.position = Vector2(0, -RouteArt.size("ember_lamp").y)
	lit.frame = absi(hash(cell)) % lit.sprite_frames.get_frame_count("default")
	lit.play()
	lit.visible = false
	root.add_child(lit)
	view.night_glows.append(lit)
	view.ember_lamps[place] = lit
	var top := Vector2(cell * TILE) + Vector2(0, TILE - RouteArt.size("ember_lamp").y)
	var halo := view._add_halo(top + RouteArt.HALO_AT, EMBER_HALO, EMBER_HALO_PEAK, RouteArt.light_of(kind) if RouteArt.KIND_LOOKS.has(kind) else MapView.HALO_TINT)
	# Lit or held dark with its ember (LanternLayer, PIX-362).
	lit.set_meta("halo", halo)
	if not own_light:
		return
	var light := Lights.make(Vector2(cell * TILE) + EMBER_POOL, EMBER_REACH, RouteArt.light_of(kind), Lights.EMBER_ENERGY, true)
	view.props.add_child(light)
	halo.tree_exiting.connect(light.queue_free)
	halo.set_meta("light", light)


## A waystation's window lit at night (PIX-322): its glass alone, the dark
## not touching it; no light of its own, so the lamp keeps the budget.
static func _add_hut_window(view: MapView, root: Node2D) -> void:
	var pane := Sprite2D.new()
	pane.texture = RouteArt.lit_window()
	pane.centered = false
	pane.material = Lights.unshaded()
	pane.position = Vector2(0, -RouteArt.size("hut").y)
	pane.visible = false
	root.add_child(pane)
	view.night_glows.append(pane)


## A miner's lantern by a door lit at night (PIX-313): its glass (the dark
## doesn't touch it), a soft halo and its light on the ground below; one
## among the City's lamps (PIX-382) keeps its halo alone, within the
## lights' budget (test_night_light).
static func _add_lantern_light(view: MapView, root: Node2D, cell: Vector2i, own_light := true) -> void:
	var lit := Sprite2D.new()
	lit.texture = HamletArt.texture("lantern_lit")
	lit.centered = false
	lit.material = Lights.unshaded()
	lit.position = Vector2(0, -TILE)
	lit.visible = false
	root.add_child(lit)
	view.night_glows.append(lit)
	var at := Vector2(cell * TILE) + HamletArt.LANTERN_GLASS
	var halo := view._add_halo(at, MapView.LAMP_HALO - 3, MapView.LAMP_HALO_PEAK)
	if not own_light:
		return
	var light := Lights.make(at + Vector2(0, TILE * 0.75), LANTERN_REACH, Lights.LAMP, Lights.LAMP_ENERGY, true)
	view.props.add_child(light)
	halo.set_meta("light", light)


## A hub's lit piece at night (PIX-324: the lighthouse's lantern, the
## lodge's windows, the stall's lantern): what burns in it (the dark doesn't
## touch it), a halo and its light on the ground about it.
static func _add_shine(view: MapView, root: Node2D, cell: Vector2i, art: String) -> void:
	var lit := Sprite2D.new()
	lit.texture = HamletArt.shine(art)
	lit.centered = false
	lit.material = Lights.unshaded()
	lit.position = Vector2(0, -HamletArt.size(art).y)
	lit.visible = false
	root.add_child(lit)
	view.night_glows.append(lit)
	var at := Vector2(cell * TILE) + Vector2(0, TILE - HamletArt.size(art).y) + HamletArt.shine_at(art)
	var halo := view._add_halo(at, MapView.LAMP_HALO, MapView.LAMP_HALO_PEAK)
	var light := Lights.make(at + Vector2(0, TILE * 0.5), MapView.LAMP_REACH, Lights.LAMP, Lights.LAMP_ENERGY, true)
	view.props.add_child(light)
	halo.set_meta("light", light)


## The fire's light under Morvax's door (PIX-312): the gap under it, its
## keyhole and a warm wash on the step, flickering by day and night (added
## onto what's under it, never darkened), and at night its light on the
## ground before the door.
static func _add_door_glow(view: MapView, door: Vector2i) -> void:
	var glow := AnimatedSprite2D.new()
	glow.sprite_frames = HamletArt.door_glow()
	glow.centered = false
	glow.material = Lights.glow()
	glow.position = Vector2(door * TILE)
	glow.frame = absi(hash(door)) % glow.sprite_frames.get_frame_count("default")
	glow.play()
	glow.add_to_group("decor")
	view.props.add_child(glow)
	view.props.add_child(Lights.make(Vector2(door * TILE) + Vector2(TILE / 2.0, TILE + 6), FORGE_REACH, Lights.FIRE, Lights.FIRE_ENERGY, true))
