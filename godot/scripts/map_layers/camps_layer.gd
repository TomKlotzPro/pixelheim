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
## A pack's tent by region (PIX-554: HamletArt's, in its cloth): green in
## the woods, straw in the wetlands and anywhere else, red on the ash. It
## blocks its two cells as the post house does (POST_HOUSE_FOOT).
const TENTS := {"forest": "camp_tent_green", "deepwood": "camp_tent_green", "marsh": "camp_tent_straw", "mire": "camp_tent_straw", "ash": "camp_tent_red"}
const TENT := "camp_tent_straw"
## Shade's straw tent, Iva's on the square on the Night of Bells (pitch_tent).
const PITCHED := 706
## Where a camp's fire's flame stands in its ring, from its cell's top
## left, and FireArt's flame it burns with. Its light reaches as far as the
## torch's it took the place of (PIX-221), so no light was added to a map.
const CAMP_FLAME := Vector2(8, 12)
const CAMP_FIRE := "lick"
const CAMP_LIGHT := 72.0
## How many of a camp's fire's coals breathe (shaders/fire_coals.gdshader):
## its bed is a few pixels, a burning house's floor a few cells.
const CAMP_COALS := 0.6
## The pack's own square (its home and the cells beside it), and how far
## from its home a camp's pieces lie (Gathering.CAMP_REACH keeps the wild
## patches further off).
const PACK_SQUARE := [Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
const CAMP_REACH := 3
## Where a camp's bedroll lies by its tent (from the tent's left cell): in
## front, then at its sides; and its log by its fire: at its sides, in
## front and behind, then at its corners.
const BEDROLL_AT := [Vector2i(0, 1), Vector2i(1, 1), Vector2i(-1, 0), Vector2i(2, 0), Vector2i(-1, 1), Vector2i(2, 1)]
const LOG_AT := [
	Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.UP,
	Vector2i(-1, 1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1),
]
## What lies low in a camp: it blocks, but casts nothing at night, nor
## keeps the fire beside it from casting (NightShadowsLayer).
const LOW := ["fire", "bedroll", "log"]
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
## Sela's tent on the square while the inn is rubble (PIX-543: Shade's
## one-tile tent was a triangle the hero's size, hidden behind them): the
## sutler's tent the hubs pitch (HubArt, drawn in code, so it stands without
## the pack), two cells wide on the post house's foot.
const PAVILION := "sutler_tent"
## The pieces HamletArt draws, by kind (a camp's tent in its region's
## cloth: TENTS).
const DRAWN := {"post": "post_box", "post_house": "post_house", "pavilion": PAVILION, "fire": "camp_fire", "bedroll": "bedroll", "log": "camp_log"}
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
			view.camps[tent] = {"kind": "pavilion"}
			view.data.covered[tent + Vector2i.RIGHT] = true
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


## Where each wild pack's camp stands (PIX-554): its tent across two cells
## of its region, its left on the first of CAMP_RING with room for both;
## its fire on the next with a cell clear between it and the tent, so the
## fire's light casts the tent's shadow (NightShadows.AGAINST), else within
## two of it; its bedroll by the tent and its log by the fire. The tent's
## left cell holds the spawn and where its fire, bedroll and log lie
## ("fire", "bed", "log"), its right cell is "beside" it. Nothing on the
## pack's own square or a door, nor further than CAMP_REACH from its home,
## nor where it would close a way on (Ways.kept_open: PIX-554), nor leave
## its stash (CampStashes, PIX-453) no cell by the tent closing none either:
## the first such cell is kept from the camps after.
## A night pack keeps none (PIX-252): it comes out of the dark, and a camp,
## drawn once for the visit, would stand empty all day.
static func plan_camps(map: MapData) -> Dictionary:
	var out := {}
	if map.style == "cave":
		return out
	# Off a mining country's rails, laid after (AshLand.workings, PIX-308):
	# a camp across them broke the line.
	var rails := {}
	for working: Dictionary in AshLand.WORKINGS.get(map.id, []):
		for cell: Vector2i in AshLand.rail_cells(working["rails"] as Array):
			rails[cell] = true
	# What the camps cover, their stashes' cells with them.
	var shut := {}
	for spawn: Dictionary in Bestiary.spawns_on(map.id):
		if Packs.of_the_night(spawn):
			continue
		var home := Vector2i(spawn["x"], spawn["y"])
		var region := map.region_at(home)
		var fits := func(cell: Vector2i) -> bool:
			var off := cell - home
			return off not in PACK_SQUARE and maxi(absi(off.x), absi(off.y)) <= CAMP_REACH and map.is_walkable(cell) \
					and map.region_at(cell) == region and not map.portals.has(cell) and not rails.has(cell) and not shut.has(cell)
		# The first of the stash's cells (`by`, stash_ring) open and closing
		# no way on, with `also` covered too.
		var stash_at := func(by: Array[Vector2i], also: Dictionary) -> Vector2i:
			var after := shut.merged(also)
			return _first(by, func(cell: Vector2i) -> bool: return fits.call(cell) and not also.has(cell) and Ways.kept_open(map, [cell], after))
		# `cells` taken for the camp, if they fit, close no way on and leave
		# its stash one of `by`.
		var takes := func(cells: Array[Vector2i], by: Array[Vector2i]) -> bool:
			if not cells.all(fits) or not Ways.kept_open(map, cells, shut):
				return false
			var also := {}
			for cell: Vector2i in cells:
				also[cell] = true
			return (stash_at.call(by, also) as Vector2i).x >= 0
		var ring: Array[Vector2i] = []
		var lefts: Array[Vector2i] = []
		for offset: Vector2i in CAMP_RING:
			ring.append(home + offset)
			lefts.append_array([home + offset, home + offset + Vector2i.LEFT])
		var tent := _first(lefts, func(left: Vector2i) -> bool:
			var both: Array[Vector2i] = [left, left + Vector2i.RIGHT]
			return fits.call(left) and fits.call(left + Vector2i.RIGHT) and takes.call(both, stash_ring(home, left)))
		if tent.x < 0:
			continue
		var camp := {"kind": "camp", "art": TENTS.get(region, TENT), "spawn": spawn["id"]}
		out[tent] = camp
		out[tent + Vector2i.RIGHT] = {"kind": "beside"}
		shut[tent] = true
		shut[tent + Vector2i.RIGHT] = true
		var stash_cells := stash_ring(home, tent)
		var clear := func(cell: Vector2i) -> bool:
			var one: Array[Vector2i] = [cell]
			return takes.call(one, stash_cells)
		var fire := _first(ring, func(cell: Vector2i) -> bool: return _apart(cell, tent) == 2 and clear.call(cell))
		if fire.x < 0:
			fire = _first(ring, func(cell: Vector2i) -> bool: return _apart(cell, tent) <= 2 and clear.call(cell))
		if fire.x >= 0:
			out[fire] = {"kind": "fire"}
			camp["fire"] = fire
			shut[fire] = true
		for part: Array in [["bed", "bedroll", tent, BEDROLL_AT], ["log", "log", fire, LOG_AT]]:
			var by: Vector2i = part[2]
			if by.x < 0:
				continue
			var near: Array[Vector2i] = []
			for offset: Vector2i in part[3]:
				near.append(by + offset)
			var cell := _first(near, clear)
			if cell.x >= 0:
				out[cell] = {"kind": part[1]}
				camp[part[0]] = cell
				shut[cell] = true
		# Its stash's cell kept from the camps after.
		shut[stash_at.call(stash_cells, {})] = true
	return out


## The cells a camp's stash may take (CampStashes, PIX-453), best first: of
## CAMP_RING's two off the pack's home, those beside its tent's left cell,
## then those within two of it.
static func stash_ring(home: Vector2i, tent: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for reach: int in [1, 2]:
		for offset: Vector2i in CAMP_RING:
			var cell: Vector2i = home + offset
			if maxi(absi(offset.x), absi(offset.y)) == 2 and maxi(absi(cell.x - tent.x), absi(cell.y - tent.y)) <= reach and cell not in out:
				out.append(cell)
	return out


## The first of `cells` that `ok`, or (-1, -1).
static func _first(cells: Array[Vector2i], ok: Callable) -> Vector2i:
	for cell: Vector2i in cells:
		if ok.call(cell):
			return cell
	return Vector2i(-1, -1)


## How many cells `cell` stands off the tent whose left cell is `tent`,
## every way.
static func _apart(cell: Vector2i, tent: Vector2i) -> int:
	return mini(maxi(absi(cell.x - tent.x), absi(cell.y - tent.y)), maxi(absi(cell.x - tent.x - 1), absi(cell.y - tent.y)))


## The camps standing, then the town's ruins.
func build(view: MapView, slices: Slicer) -> void:
	slices.add("decor_camps", func() -> void:
		for cell: Vector2i in view.camps:
			_add_camp_piece(view, cell, view.camps[cell]))
	if view.data.id == "town":
		slices.add("decor_ruins", func() -> void: _decor_ruins(view))


## The town hall's house in cells (empty where there is none): on the town's
## map the house whose door leads into it, on the Reach its small self in the
## village far off (Skyline's `hall`).
static func hall(view: MapView) -> Rect2i:
	if view.data.id != "town":
		return view.skyline.get("hall", Rect2i())
	for door: Vector2i in view.data.portals:
		if view.data.portals[door].get("mapId", "") == "town_hall":
			return PunyTown.house_of(view.data.grid, door)
	return Rect2i()


## The hall on the Night of Ash (PIX-516: it stood whole on the square, its
## windows warm, on the night nobody is in it): its windows dark and its
## walls and roof scorched as the gatehouse is (GroundLayer's `ashen` layer).
## The town is drawn anew after the dawn (Stage.play_dawn), whole and lit.
func set_night(view: MapView, _night: bool) -> void:
	if GameState.progression.prologue == Prologue.DONE:
		return
	var house := hall(view)
	for pane: Node2D in view.panes:
		if is_instance_valid(pane) and house.has_point(Vector2i(pane.position) / TILE):
			# MapView.set_night keeps a `dark` pane unlit each second after.
			pane.set_meta("dark", true)
			pane.visible = false
			# The LightRig shows a light by its energy: none thrown below it.
			# A far pane has none (get_meta with a null default still
			# logs an error for a missing key: PIX-538).
			if pane.has_meta("light") and is_instance_valid(pane.get_meta("light")):
				(pane.get_meta("light") as Node).set_meta("energy", 0.0)


## The town's ruins smoking, and on the night of the fire still burning
## (PIX-151), but for the ones the hero put out (PIX-197): those smoulder,
## as the ruins do the days after.
static func _decor_ruins(view: MapView) -> void:
	var burning := GameState.progression.prologue != Prologue.DONE
	var ruins := Town.ruins(Town.done_projects(GameState.settlement))
	for i in ruins.size():
		if burning and i not in GameState.progression.prologue_doused:
			var fire := {"rect": ruins[i]["rect"], "nodes": _add_fire(view, ruins[i]["rect"]), "ruin": i}
			_bar(view, fire)
			view.fires.append(fire)
		else:
			_add_smoke(view, ruins[i]["rect"])


## A burning ruin bars the way as a standing house does (PIX-515: the hero
## walked in at the door and stood among the flames, unhurt): one box over
## the frame and all inside it, no further out than the frame's own posts
## block (a cell's blocker starts 4 in and 7 down, art.md's Collision), and
## its open cells covered, so nothing is stood or sent in there. Both go
## with the fire (douse): the box is one of its nodes, the cells `barred`.
static func _bar(view: MapView, fire: Dictionary) -> void:
	var rect: Rect2i = fire["rect"]
	var barred: Array[Vector2i] = []
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if view.data.is_walkable(Vector2i(x, y)):
				barred.append(Vector2i(x, y))
				view.data.covered[Vector2i(x, y)] = true
	fire["barred"] = barred
	var box := Rect2(rect.position * TILE, rect.size * TILE).grow_individual(-4, -7, -4, 0)
	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var boxed := RectangleShape2D.new()
	boxed.size = box.size
	shape.shape = boxed
	body.add_child(shape)
	body.position = box.get_center()
	# Not shrunk as a flame is when the fire goes out: let go at its end.
	body.set_meta("fades", true)
	body.add_to_group("decor")
	# With the fire's lights and air, not the actors: no shadow is cast from it.
	view.props.add_child(body)
	(fire["nodes"] as Array[Node2D]).append(body)


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
## rather than shrinks as the fire goes out (douse). With no `part`, no
## fire's: a chimney's smoke (PIX-523).
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
	if part != "":
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
	for cell: Vector2i in fire.get("barred", []):
		view.data.covered.erase(cell)
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
	for ember: bool in [false, true]:
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
	view.camps[cell] = {"kind": "tent", "tile": PITCHED}
	view.data.covered[cell] = true
	_add_camp_piece(view, cell, view.camps[cell])


## A piece of a camp, or of the town (its boards, stalls and tent, the post
## box and its house): sorted among the actors at its foot, which blocks.
## Ours stand on the bottom of their cells (HamletArt); a camp's bedroll
## lies flat on the ground over its block, and its tent's other cell
## (`beside`) is the tent's.
static func _add_camp_piece(view: MapView, cell: Vector2i, piece: Dictionary) -> void:
	if piece["kind"] == "beside":
		return
	var foot: Rect2 = {"tent": TENT_FOOT, "board": BOARD_FOOT, "post_house": POST_HOUSE_FOOT, "pavilion": POST_HOUSE_FOOT, "camp": POST_HOUSE_FOOT, "desk": DESK_FOOT}.get(piece["kind"], MapView.HAMLET_FOOT)
	var art: String = piece["art"] if piece["kind"] == "camp" else DRAWN.get(piece["kind"], "")
	var root := Node2D.new()
	root.position = Vector2(cell * TILE) + Vector2(0, foot.end.y)
	root.add_to_group("decor")
	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.position = Vector2(0, -foot.end.y)
	if piece["kind"] == "post":
		# The post box (PIX-320), its pennant up while it holds the day's
		# post (show_post_box).
		view.post_box = sprite
		view.show_post_box()
	elif art != "":
		sprite.texture = HamletArt.texture(art)
		if piece["kind"] == "post_house":
			view.post_house = sprite
	else:
		sprite.texture = RoomArt.texture(piece["art"]) if piece.has("art") else PunyTerrain.sheet().tile_texture(piece["tile"])
		# Her ledger read by its candle at night.
		if piece["kind"] == "desk":
			view._add_candle(Vector2(cell * TILE) + DESK_FLAME)
	if art != "":
		sprite.position.y = TILE - HamletArt.size(art).y - foot.end.y
	if piece["kind"] == "bedroll":
		sprite.position += root.position
		sprite.add_to_group("decor")
		view.ground.add_child(sprite)
	else:
		root.add_child(sprite)
	if piece["kind"] == "fire":
		_add_camp_fire(view, root, cell)
	# A tent, a board, the post box and its house cast as the trees do
	# (PIX-524); what lies low in a camp doesn't.
	if sprite.texture != null and piece["kind"] not in LOW:
		var drawn := sprite.texture.get_size()
		cast(view, root.position + sprite.position + Vector2(drawn.x / 2.0, drawn.y), drawn.x - 2.0, drawn.y)
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
	if piece["kind"] in LOW:
		body.set_meta("low", true)
	root.add_child(body)
	view.actors.add_child(root)


## A camp's fire in its ring (PIX-554: it was a street torch on a stake):
## FireArt's flame standing in it, unshaded, at its own pace (calmer with
## Reduce motion); the torch's light, so no light was added to a map
## (PIX-221); sparks rising (PIX-225); a few coals breathing in its bed and
## a thread of smoke going up (shaders/fire_*.gdshader), as off a house.
static func _add_camp_fire(view: MapView, root: Node2D, cell: Vector2i) -> void:
	var at := Vector2(cell * TILE) + CAMP_FLAME - root.position
	var coals := _fire_air(view, "", Rect2(at + Vector2(-4, -2), Vector2(9, 3)), preload("res://shaders/fire_coals.gdshader"), 0, {
		"seed": float(absi(hash(cell)) % 97) / 9.7, "share": CAMP_COALS,
	})
	# Laid in the ring, under the flame (`at` is the ring's own).
	coals.reparent(root, false)
	var size: Vector2i = FireArt.KINDS[CAMP_FIRE]
	var flame := AnimatedSprite2D.new()
	flame.sprite_frames = FireArt.frames(CAMP_FIRE, absi(hash(cell)) % FireArt.VARIANTS)
	flame.centered = false
	flame.position = at
	flame.offset = Vector2(-(size.x / 2), -size.y)
	# Each camp's fire flickers on its own beat.
	flame.frame = absi(hash(cell)) % FireArt.FRAMES
	flame.speed_scale = FireArt.pace({"cell": cell, "frame": flame.frame}, GameState.settings.reduce_motion)
	flame.material = Lights.unshaded()
	root.add_child(flame)
	flame.play()
	root.add_child(Lights.make(at - Vector2(0, 4), CAMP_LIGHT, Lights.FIRE, Lights.FIRE_ENERGY, true))
	var embers := MapView._still(Motes.make_embers(3))
	embers.position = at - Vector2(0, size.y)
	embers.z_index = 6
	root.add_child(embers)
	SettlementsLayer._add_smoke_thread(view, Vector2(cell * TILE) + CAMP_FLAME - Vector2(0, size.y - 4), "camp")


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
			for x: int in POSTER[y].length():
				if POSTER[y][x] != ".":
					art.set_pixel(x, y, Color(POSTER_INKS[POSTER[y][x]]))
		_poster = ImageTexture.create_from_image(art)
	return _poster
