class_name MapView
extends RefCounted
## One visit to a map, as drawn (PIX-136): Shade's ground, houses, rooms and
## dungeons, the props, field scatter, chests and door signs, the house's
## placed furniture, and the invisible boxes on what the hero can't walk
## into. Planning it also tells the map what all that covers (house corners,
## prop feet, blocking scatter, chests), so the grid, the villagers and the
## monsters agree with the art. world.gd keeps the play: the actors,
## interaction, combat and music; standing things go into its y-sorted
## `actors` layer, everything else under it.
## A drawing stands at an `offset` (One Reach, PIX-269, step 5): the map the
## hero stands on at the world's origin, a map beside it where the plane
## puts it. What it draws under the actors (`under`: the ground, the
## invisible boxes, the door signs) and what stands among them (`stand`,
## y-sorted with the world's actors) move as one. Planning and drawing are
## lists of small units (`planning`, `building`): a map entered through a
## door runs them all at once (plan, build), the map beside the hero a few
## a frame (Neighbours), the same units, so it draws the same map.

const TILE := 16

var data: MapData
## What stands among the actors goes here: this drawing's own y-sorted layer
## (`stand`) once it's built, sorted with the world's actors.
var actors: Node2D
## Where this drawing's cell (0, 0) stands in the world, in pixels: the
## origin for the map the hero stands on, its place in the plane for a map
## drawn beside it (Neighbours). Moving it moves the whole drawing.
var offset := Vector2.ZERO:
	set(value):
		offset = value
		if under != null:
			under.position = value
		if stand != null:
			stand.position = value
## The ground, the blockers and the signs, under the world's actors; and
## what stands among them, y-sorted with them (the world's actors layer).
var under: Node2D
var stand: Node2D
var _actor_layer: Node2D
## Where the hero arrives, as the plan settled it.
var arrival := Vector2i.ZERO
## Drawn a few units a frame beside the hero: its tile layers drawn as each
## unit lays them, not at the frame's end, so the clock counts it; and
## `hidden` until it's whole.
var sliced := false
var hidden := false
## The ground as kept (KeptGround), and the layers drawn from it: the corner
## tiles, the cliffs standing in water, sand or a road, and the forest's
## crowns, which a map beside it stitches along their line (Neighbours).
var kept: KeptGround
var ground_layer: TileMapLayer
var rim_layer: TileMapLayer
var crown_layer: TileMapLayer
var _objects_layer: TileMapLayer
var _growth_layer: TileMapLayer
## Pixelheim's rampart in the Medieval Age's stone: whole, and scorched.
var _rampart_layers: Array[TileMapLayer] = []
## Every material that reads the region's masks (region_tint.gdshader), to
## hand them a neighbour's masks beside their own (set_masks).
var _toned: Array[ShaderMaterial] = []
## The map's cells in the grid's own order (row by row), for its decor a
## few rows a unit.
var _keys: Array = []
## Houses (PunyTown) or a room (PunyInterior): {"pieces", "decor", "freed"},
## a room adding "floor", "walls", "void" and "over".
var buildings := {"pieces": {}, "decor": {}, "freed": []}
## Outdoor props (PunyProps): {"props", "flat", "drawn"}.
var outdoor_props := {"props": [], "flat": {}, "drawn": {}}
## Field decor that blocks: cell -> Puny World tile.
var solid_scatter := {}
var ground: Node2D
var ground_tint: ShaderMaterial
## The same toning for what the wind moves (PIX-223): each tree and wheat
## sheaf leaning on its own beat (decor_sway), the forest's crowns as one
## sheet (canopy), the town's flowers (flowers_sway).
var decor_sway: ShaderMaterial
var canopy: ShaderMaterial
var flowers_sway: ShaderMaterial
var tile_layer: TileMapLayer
## Door signs, above the world and outside the y-sort.
var props: Node2D
## A dungeon floor's torches, barrels and stairs (a cleared floor adds stairs down).
var dungeon_objects: TileMapLayer
## Chest id -> its sprite, to open or take it.
var chest_sprites := {}
## The door signs: {door, name, about}, for the nameplate.
var door_signs: Array = []
## The ways on from this map (PIX-269, Ways.on): bare ground and rock, but
## for the gate the story bars.
var ways: Array[Dictionary] = []
## The gates still shut on this visit (PIX-254, Gates): drawn across their
## cells (GateArt), which block; and the cells whose objects they hide (a
## burnt bridge's planks).
var gates: Array[Dictionary] = []
var gate_hides := {}
var furniture_cells: Array[Vector2i] = []
## Night (PIX-149): each lamp's flame and its cold torch for the day, and
## the warm glows of lamps and windows; set_night shows one or the other.
var lamps: Array[Dictionary] = []
var night_glows: Array[Node2D] = []
## The ruins burning on the Night of Ash (PIX-197): [{rect, nodes}], in
## Town.ruins' order, so the dawn can put them out one by one.
var fires: Array[Dictionary] = []
var _night := -1
## Gathering patches (PIX-143): cell -> {"id", "item"}, and each one's sprite.
var patches := {}
var patch_sprites := {}
## Where the map's wild patches may grow, shuffled (Gathering.decks), and
## the day they were dealt for: a new day deals new ones (PIX-250).
var patch_decks := {}
var patch_day := -1
## Each wild pack's camp (PIX-142): cell -> {"kind": "tent"|"torch", "tile"},
## a tent in its region's colour behind its home and a torch beside it.
var camps := {}
## The village seen from outside (PIX-248, Skyline.plan), on the maps that
## hold it as one block (PunyTerrain.SKYLINE_MAPS); empty elsewhere.
var skyline := {}
## Pixelheim's rampart and its gatehouse (PIX-248, Rampart.plan): the
## town's own, or the ring round the village far off; empty elsewhere.
var rampart := {}
## What a building rising on the town's tour lifts out and puts back
## (PIX-264): the houses' layers and the flat flowers' ("pieces", "decor",
## "flowers"), and each outdoor prop's node by its cell.
var layers := {}
var prop_nodes := {}
## What each part of `build` took, in ms, when `timed` (the harness's
## `reentry`, One Reach step 8): what drawing a map beside the hero would
## cost part by part. Off, nothing is noted.
var timed := false
var took := {}

## How far the wind leans what grows, in pixels at its top (PIX-223): a
## tree or a sheaf, a flower, a forest's crowns (all of a piece, so less).
const TREE_SWAY := 1.3
const FLOWER_SWAY := 0.7
const CANOPY_SWAY := 0.4
## The projects board on the square (PIX-145): a Puny World notice board.
const PROJECT_BOARD := 846
const BOARD_FOOT := Rect2(1, 8, 14, 8)
## Puny World tents by region: green in the woods, straw in the wetlands,
## red on the ash.
const TENTS := {"forest": 895, "deepwood": 895, "marsh": 706, "mire": 706, "ash": 905}
## The CC0 dungeon sheet's torch flame, planted in the ground by a camp.
const CAMP_TORCH := [16, 17, 18, 19, 20, 21, 22, 23]
## Where a camp's pieces may stand around its home, best first: behind it,
## then beside, then in front (the pack itself takes the home and its sides).
const CAMP_RING := [
	Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-2, 0), Vector2i(2, 0), Vector2i(-1, 1), Vector2i(1, 1),
	Vector2i(-2, -1), Vector2i(2, -1), Vector2i(-1, 2), Vector2i(1, 2), Vector2i(0, 2), Vector2i(-2, 1),
	Vector2i(2, 1), Vector2i(0, -2),
]
const TENT_FOOT := Rect2(1, 5, 14, 11)
const TORCH_FOOT := Rect2(5, 9, 6, 7)
## How many cells of ground are drawn on past the map's edges (PIX-269):
## more than the dock covers, so the camera looking past the south edge
## never shows the void.
const EDGE_PAD := 4
## How strongly a region tones the ground (region_tint.gdshader's strength).
const TONE := 0.85
## Indoors and underground, the dark goes on this many cells past the map's
## edges: a map smaller than the view (every room since the camera stood
## back to CameraRig.ZOOM 3, a short dungeon floor) is shown whole in the
## middle of the screen, and round it must be the dark, not the window's
## flat grey, out to the screen's edges at any window size.
const DARK_PAD := 32
## The dark beyond a room's walls and a dungeon's rock.
const DARK := Color("0b0a0e")
## One cold light over the ice (PIX-255) in every so many cells across and down.
const ICE_LIGHT_EVERY := Vector2i(6, 5)
## How far a way out's light reaches, in pixels (PIX-292), and how far
## over its cell its plate stands.
const WAY_OUT_GLOW := 80.0
const WAY_OUT_PLATE := 4.0
## A burnt house seen small from afar smokes with this share of a ruin's
## motes in town (PIX-248).
const VILLAGE_RUIN_SMOKE := 0.4
## A unit of drawing: a tile layers' physics quadrant, 16 cells square, and
## four whole rendering quadrants (LIGHT_BLOCK), laid and drawn once; the
## decor and the objects a few rows at a time; the props a handful.
const BLOCK := 16
const DECOR_ROWS := 4
const PROPS_A_UNIT := 16
## Each tile layer's rendering quadrant, this many cells a side (PIX-285).
## A rendering quadrant is one canvas item, and Godot lights a canvas item
## with only the first Lights.PER_ITEM lights that reach it: with quadrants
## of 16, three dozen fires reached one on the Night of Ash, and each light
## left out of one stopped at its edge, the ground lit and dark in straight
## lines. A quadrant of 8 is a quarter of the ground, and far fewer lights
## reach it (test_night_light). It divides BLOCK, so a unit of drawing
## still lays whole quadrants, each drawn once.
const LIGHT_BLOCK := 8
## A burning house lights the ground as a few soft pools (PIX-285): one for
## each part of it at most FIRE_POOL cells a side, from the part's middle
## to FIRE_REACH pixels past its corners. A light on every flame put three
## dozen on the square and washed its ash white.
const FIRE_POOL := 6
const FIRE_REACH := 36.0


func _init(map_data: MapData, actor_layer: Node2D) -> void:
	data = map_data
	_actor_layer = actor_layer
	actors = actor_layer


## A cell's centre in map pixels.
static func center(cell: Vector2i) -> Vector2:
	return Vector2(cell * TILE) + Vector2(TILE, TILE) / 2.0


## Decides what stands where and marks it on the map, before anything is
## drawn; returns where the hero arrives (the map's spawn when `arrival_at`
## is now covered).
func plan(arrival_at: Vector2i) -> Vector2i:
	var slices := Slicer.new()
	planning(arrival_at, slices)
	slices.finish()
	return arrival


## The plan as units on `slices`, in order (`plan` runs them at once). What
## takes longest is kept for the session (KeptGround): the village far off,
## the props, the blocking scatter.
func planning(arrival_at: Vector2i, slices: Slicer) -> void:
	arrival = arrival_at
	slices.add("plan_houses", _plan_houses)
	slices.add("plan_room", _plan_room)
	slices.add("plan_props", _plan_props)
	slices.add("plan_gates", _plan_gates)
	slices.add("plan_scatter", _plan_scatter)


## Where patches may grow, then the houses: the town's own, or the village
## far off.
func _plan_houses() -> void:
	# Where patches may grow is read before anything is drawn over the map
	# (PIX-250), so it's the same with or without the paid art; worked out
	# on the first visit this session and kept (KeptGround, PIX-269).
	patch_decks = KeptGround.decks(data)
	# Far off (the overworld) the town's block of roofs is the village, small.
	var near := data.floor_level == 0 and data.id not in PunyTerrain.SKYLINE_MAPS
	buildings = PunyTown.compose(data.grid) if near else {"pieces": {}, "decor": {}, "freed": []}
	# What a house covers is house: its corners stop the hero and villagers
	# too; the roof cells it leaves open are ground.
	for cell: Vector2i in buildings["pieces"]:
		if not String(data.grid.get(cell, "")).begins_with("door"):
			data.grid[cell] = "roof"
	for cell: Vector2i in buildings["freed"]:
		data.grid[cell] = "grass"
	# The village as it stands now (PIX-248): its ruins, its rebuilt houses,
	# what each age added. Only drawn: the block's cells stay as they are.
	# Kept while the town doesn't change (KeptGround.skyline).
	skyline = {}
	if data.floor_level == 0 and data.id in PunyTerrain.SKYLINE_MAPS:
		var done := Town.done_projects(GameState.settlement)
		var ruins: Array = Town.ruins(done).map(func(ruin: Dictionary) -> Rect2i: return ruin["rect"])
		skyline = KeptGround.skyline(data, done, ruins)
		if PunyTown.available():
			buildings = {"pieces": skyline["pieces"], "decor": skyline["decor"], "freed": []}
	# One wall round the village, its gatehouse where the road runs through
	# (PIX-248): the town's, or the ring round it far off.
	rampart = {}
	if data.floor_level == 0 and data.id in Rampart.MAPS:
		rampart = Rampart.plan(data.grid, Rampart.ashen(Town.done_projects(GameState.settlement)))
	elif not skyline.is_empty():
		rampart = skyline["rampart"]


## Inside, Shade's rooms (PunyInterior): furniture spreading onto the floor
## blocks it, like the rest of the furniture.
func _plan_room() -> void:
	if not (PunyTown.available() and PunyInterior.is_room(data.id)):
		return
	var room: Dictionary = PunyInterior.plan(data.id, data.grid)
	# Then Shade's furnished corners (PIX-163), clear of the way in, the
	# keepers and the hero's own furniture.
	var placed: Array = GameState.household.furniture() if data.id == "town_house" else []
	var dressed := PunyInterior.furnish(data.id + data.variant, data.grid, PunyInterior.reserved(data, placed))
	buildings = {
		"pieces": room["pieces"], "decor": {}, "freed": [], "floor": room["floor"], "walls": room["walls"], "void": room["void"], "over": room["over"],
		"rug": dressed["rug"], "objects": dressed["objects"], "tops": dressed["tops"], "lifted": dressed["lifted"],
	}
	for cell: Vector2i in room["blocked"] + dressed["blocked"]:
		data.grid[cell] = "wall"


## Outdoors, Shade's props stand where the web's did (PunyProps): what they
## stand on blocks, even ground the web left open (the fountain's basin).
## Then the packs' camps, and the town's boards, stalls and tent.
func _plan_props() -> void:
	var outdoor := data.floor_level == 0 and PunyTerrain.is_outdoor(data.grid)
	outdoor_props = KeptGround.props(data) if outdoor else {"props": [], "flat": {}, "drawn": {}}
	data.covered = {}
	for prop: Dictionary in outdoor_props["props"]:
		if (prop["foot"] as Rect2).has_area():
			for cell: Vector2i in prop["covers"]:
				data.covered[cell] = true
	# The gatehouse's towers stand a cell above the wall: nothing grows or
	# walks there.
	if not rampart.get("covers", []).is_empty():
		# The props' plan may be kept for the session (KeptGround.props):
		# added to on a copy of its own.
		outdoor_props = outdoor_props.duplicate()
		outdoor_props["drawn"] = (outdoor_props["drawn"] as Dictionary).duplicate()
	for cell: Vector2i in rampart.get("covers", []):
		data.covered[cell] = true
		outdoor_props["drawn"][cell] = true
	camps = plan_camps(data)
	if data.id == "town":
		camps[Town.project_board()] = {"kind": "board", "tile": PROJECT_BOARD}
		# Its neighbour wears a wanted poster: the bounties (PIX-156).
		camps[Town.bounty_board()] = {"kind": "board", "tile": PROJECT_BOARD, "wanted": true}
		# A festival day's stalls (PIX-159), wherever the ground is open.
		if GameState.holdings.festival_on():
			for stall: Dictionary in Town.festival("stalls"):
				var at := Vector2i(int(stall["x"]), int(stall["y"]))
				if data.is_walkable(at) and not data.covered.has(at) and not camps.has(at):
					camps[at] = {"kind": "tent", "tile": int(stall["tile"])}
		# Sela's tent on the square while the inn is rubble (PIX-146).
		var tent := Town.ashes_tent(Town.done_projects(GameState.settlement))
		if tent.x >= 0:
			camps[tent] = {"kind": "tent", "tile": TENTS["marsh"]}
	for cell: Vector2i in camps:
		data.covered[cell] = true


## The gates the story still keeps shut (PIX-254): what's drawn across each
## blocks its cells, and a burnt bridge has no planks there. Then the ways
## on, and today's patches (PIX-250): a few dealt from each region's ground.
func _plan_gates() -> void:
	gates = []
	gate_hides = {}
	if data.floor_level == 0:
		gates = Gates.closed_on(data.id, GameState.progression, GameState.settlement, GameState.world.discovered)
	for gate: Dictionary in gates:
		for cell: Vector2i in Gates.cells_of(gate):
			data.covered[cell] = true
		for cell: Vector2i in GateArt.plan(gate, PunyProps.available())["hides"]:
			gate_hides[cell] = true
	ways = Ways.on(data)
	patches = {}
	patch_day = -1
	deal_patches(Gathering.day_of(GameState.world.steps))


## Where the hero arrives (the spawn when the arrival is covered now), and
## the field decor that blocks, kept off it.
func _plan_scatter() -> void:
	if not data.is_walkable(arrival):
		arrival = data.spawn
	solid_scatter = _solid_scatter(data, arrival)
	for cell: Vector2i in solid_scatter:
		data.covered[cell] = true


## Draws the map at once: its ground, the blockers and door signs under the
## actors (as the first child of `root`), then what stands among the actors,
## then the house's furniture.
func build(root: Node) -> void:
	var slices := Slicer.new()
	building(root, slices)
	slices.finish()
	if timed:
		took = parts_of(slices)


## What `slices` took by part: the first word of each unit's kind.
static func parts_of(slices: Slicer) -> Dictionary:
	var parts := {}
	for kind: String in slices.totals:
		var part := kind.get_slice("_", 0)
		parts[part] = float(parts.get(part, 0.0)) + float(slices.totals[kind])
	return parts


## The drawing as units on `slices`, in order (`build` runs them at once,
## Neighbours a few a frame): the ground (laid a unit at a time when
## `sliced`), the blockers a band of rows at a time, the signs, the decor a
## few rows at a time, then the rest. The plan has run.
func building(root: Node, slices: Slicer) -> void:
	slices.add("ground_setup", _setup.bind(root))
	if data.floor_level > 0 or data.style == "cave":
		slices.add("ground_dungeon", func() -> void: _ground_root(_build_dungeon(data)))
	elif buildings.has("floor"):
		slices.add("ground_room", func() -> void: _ground_root(_build_room(data)))
	else:
		_ground_units(slices)
	slices.add("blockers_setup", _blockers_setup)
	slices.add_each("blockers_rows", ceili(data.size.y / float(BLOCK)), _blocker_rows)
	slices.add("signs", func() -> void:
		props = _build_props(data)
		under.add_child(props)
		# A dungeon's ways straight out, once its boss is down: lit (PIX-292).
		for cell: Vector2i in Depths.exits(data):
			light_way_out(cell))
	_decor_units(slices)
	slices.add("set_pieces", _add_set_pieces.bind(data))
	slices.add("rest", func() -> void:
		furnish()
		_night = -1
		set_night(DayNight.is_night(GameState.world.steps)))


## The drawing's two roots: what lies under the actors (first under
## `root`), and its own y-sorted layer among the world's actors, still (a
## static drawing needs no smoothing between physics ticks).
func _setup(root: Node) -> void:
	under = Node2D.new()
	under.position = offset
	under.visible = not hidden
	root.add_child(under)
	root.move_child(under, 0)
	stand = Node2D.new()
	stand.y_sort_enabled = true
	stand.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	stand.position = offset
	stand.visible = not hidden
	if _actor_layer != null:
		_actor_layer.add_child(stand)
	actors = stand
	_keys = data.grid.keys()


func _ground_root(node: Node2D) -> void:
	ground = node
	ground.modulate = data.tint
	under.add_child(ground)


## Takes the drawing down at once (Neighbours takes a map beside the hero
## down a few hundred nodes a frame instead).
func clear() -> void:
	for node: Node in [under, stand]:
		if node != null and is_instance_valid(node):
			node.queue_free()


## The ground in Shade's Puny World tiles (PunyTerrain): grass, roads, sand,
## cliffs and rippling water on the dual grid, half a tile up-left of the
## cells so every terrain edge sits on a cell edge. All of it at once (the
## town's tour draws a past town over the town with it, draw_ground).
func _build_ground(_data: MapData) -> Node2D:
	if buildings.has("floor"):
		return _build_room(data)
	var root := _ground_layers()
	kept.lay_ground(ground_layer)
	kept.lay_rims(rim_layer)
	kept.lay_crowns(crown_layer)
	for i in ceili(data.size.y / float(BLOCK)):
		_object_rows(i)
	_ground_pieces()
	return root


## The ground's units: its layers, the tiles (a BLOCK a unit when sliced,
## else from the kept layers in one call), the objects a band of rows a
## unit, then the pieces (the village far off, gates in the rock, growth,
## flowers, houses).
func _ground_units(slices: Slicer) -> void:
	if kept == null:
		kept = KeptGround.of(data, look(), EDGE_PAD)
	slices.add("ground_layers", func() -> void: _ground_root(_ground_layers()))
	if sliced or kept.ground_cells.is_empty():
		var blocks := quadrants(kept.corners())
		slices.add_each("ground_tiles", blocks.size(), func(i: int) -> void:
			kept.lay_block(ground_layer, rim_layer, crown_layer, blocks[i])
			if sliced:
				draw_now()
			if i == blocks.size() - 1 and kept.ground_cells.is_empty():
				# Kept, for the next drawing to lay in one call.
				kept.ground_cells = ground_layer.tile_map_data
				kept.rim_cells = rim_layer.tile_map_data
				kept.crown_cells = crown_layer.tile_map_data)
	else:
		slices.add("ground_tiles", func() -> void:
			kept.lay_ground(ground_layer)
			kept.lay_rims(rim_layer)
			kept.lay_crowns(crown_layer))
	slices.add_each("ground_objects", ceili(data.size.y / float(BLOCK)), _object_rows)
	slices.add("ground_pieces", _ground_pieces)


## The units of a tile layer (BLOCK square) that `rect` (of its cells)
## covers, each clipped to it: whole rendering quadrants (LIGHT_BLOCK), so a
## quadrant laid in one unit is drawn once.
static func quadrants(rect: Rect2i) -> Array[Rect2i]:
	var out: Array[Rect2i] = []
	var first := Vector2i(floori(rect.position.x / float(BLOCK)), floori(rect.position.y / float(BLOCK)))
	var last := Vector2i(floori((rect.end.x - 1) / float(BLOCK)), floori((rect.end.y - 1) / float(BLOCK)))
	for qy in range(first.y, last.y + 1):
		for qx in range(first.x, last.x + 1):
			out.append(Rect2i(Vector2i(qx, qy) * BLOCK, Vector2i(BLOCK, BLOCK)).intersection(rect))
	return out


## A tile layer of `tile_set`, drawn in rendering quadrants of LIGHT_BLOCK
## cells: every tile layer a drawing makes.
static func tile_layer_of(tile_set: TileSet) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.tile_set = tile_set
	layer.rendering_quadrant_size = LIGHT_BLOCK
	return layer


## The ground's layers, empty but for their materials, in drawing order:
## the corner tiles, the crowns, the objects, then the village's growth, the
## flowers and the houses where there are any.
func _ground_layers() -> Node2D:
	var root := Node2D.new()
	ground_layer = tile_layer_of(PunyTerrain.tileset())
	ground_layer.position = Vector2(-TILE, -TILE) / 2.0
	# The ground as drawn: the map's, but for the village far off (PIX-248),
	# whose streets, river and ash lie where its block's cells are. On past
	# the map's edges: below the dock the camera looks past the south edge
	# (CameraRig.set_limits, PIX-269), and sees the ground go on, as it lies
	# there in the Reach's plane (the map beside, or the ridge's rock).
	# Worked out on the map's first visit this session, and kept (PIX-269).
	if kept == null:
		kept = KeptGround.of(data, look(), EDGE_PAD)
	# Ash and mire are toned from Shade's dirt and grass, decor included.
	_toned = []
	ground_tint = ShaderMaterial.new()
	ground_tint.shader = preload("res://shaders/region_tint.gdshader")
	ground_tint.set_shader_parameter("tint_map", kept.tint_map)
	ground_tint.set_shader_parameter("map_pixels", Vector2(data.size * TILE))
	# Where the map lies in the plane: what the shader's slow noise and the
	# water's light read, so they run on unbroken into a map beside it.
	var origin := ReachPlane.origin(data.id) if ReachPlane.holds(data.id) else Vector2i.ZERO
	ground_tint.set_shader_parameter("map_origin", Vector2(origin * TILE))
	_toned.append(ground_tint)
	# The water swells, glints and foams at the shore (PIX-223).
	var water := _toning()
	water.set_shader_parameter("water_life", true)
	water.set_shader_parameter("water_map", kept.water_map)
	ground_tint.set_shader_parameter("water_map", kept.water_map)
	ground_layer.material = water
	root.add_child(ground_layer)
	# Shade's cliffs standing in the water, the sand and the roads
	# (PunyTerrain.rimmed), toned as the ground is, but still: the water
	# under them swells.
	rim_layer = tile_layer_of(PunyTerrain.tileset())
	rim_layer.position = ground_layer.position
	rim_layer.material = ground_tint
	root.add_child(rim_layer)
	decor_sway = _swaying(TREE_SWAY, true)
	flowers_sway = _swaying(FLOWER_SWAY, false)
	flowers_sway.set_shader_parameter("strength", 0.0)
	canopy = _toning()
	canopy.set_shader_parameter("canopy", CANOPY_SWAY)
	crown_layer = tile_layer_of(PunyTerrain.tileset())
	crown_layer.position = ground_layer.position
	# Under snow the pines on the ridges whiten with the ground (PIX-169);
	# elsewhere they keep their green (but along a line with a snowy map
	# beside, where they whiten as its own do: set_masks).
	if not kept.crowns_toned:
		canopy.set_shader_parameter("strength", 0.0)
	crown_layer.material = canopy
	root.add_child(crown_layer)
	# Bridges, cave mouths and ramparts stand on that ground as Puny objects;
	# the village far off brings its own rampart, wells and growth.
	_objects_layer = tile_layer_of(PunyTerrain.tileset())
	root.add_child(_objects_layer)
	# Pixelheim's rampart in the Medieval Age's stone, its gatehouse at the
	# road (PIX-248); what the fire left of it darker, on a layer of its own.
	_rampart_layers = []
	if not rampart.is_empty() and PunyTown.available():
		for scorched: bool in [false, true]:
			var stone := tile_layer_of(PunyTown.tileset())
			if scorched:
				stone.modulate = Rampart.SCORCHED
			root.add_child(stone)
			_rampart_layers.append(stone)
	_growth_layer = null
	if not skyline.get("growth", {}).is_empty():
		# Its woods and fields lean in the wind together.
		_growth_layer = tile_layer_of(PunyTerrain.tileset())
		_growth_layer.material = _swaying(TREE_SWAY, false)
		root.add_child(_growth_layer)
	# Shade's flowers, flat on the ground (the hero walks through them).
	if not outdoor_props["flat"].is_empty():
		var flowers := tile_layer_of(PunyTown.tileset())
		flowers.material = flowers_sway
		root.add_child(flowers)
		layers["flowers"] = flowers
	# The houses, then what stands on their roofs (chimneys).
	for part: String in ["pieces", "decor"]:
		if buildings[part].is_empty():
			continue
		var houses := tile_layer_of(PunyTown.tileset())
		root.add_child(houses)
		layers[part] = houses
	return root


## The ground as drawn: the map's, but for the village far off (PIX-248),
## whose streets, river and ash lie where its block's cells are.
func look() -> Dictionary:
	return data.grid.merged(skyline["ground"], true) if not skyline.is_empty() else data.grid


## Bridges, cave mouths and ramparts on cell rows [i * BLOCK, (i + 1) *
## BLOCK): a band of the objects layer's quadrants, whole.
func _object_rows(i: int) -> void:
	var drawn := look()
	var outdoor := PunyTerrain.is_outdoor(data.grid)
	var village: Rect2i = skyline.get("block", Rect2i())
	var walled: Dictionary = rampart.get("pieces", {})
	for y in range(i * BLOCK, mini((i + 1) * BLOCK, data.size.y)):
		for x in data.size.x:
			var cell := Vector2i(x, y)
			if not drawn.has(cell):
				continue
			var object := PunyTerrain.object_at(drawn, cell)
			if outdoor and object < 0 and not village.has_point(cell) and not walled.has(cell):
				object = PunyTerrain.wall_piece(data.grid, cell)
			if object >= 0 and not gate_hides.has(cell):
				PunyTerrain.place(_objects_layer, cell, object)
	if sliced:
		_objects_layer.update_internals()


## What stands on the ground but the objects: the village far off's wells,
## Pixelheim's rampart and its gatehouse, a gate in the rock, growth, the
## flowers and the houses.
func _ground_pieces() -> void:
	if not skyline.is_empty():
		var drawn: Dictionary = skyline["objects"].merged({} if PunyTown.available() else skyline["icons"])
		for cell: Vector2i in drawn:
			PunyTerrain.place(_objects_layer, cell, drawn[cell])
	# Pixelheim's rampart in Shade's CC0 castle pieces, without the paid pack.
	if not PunyTown.available():
		for cell: Vector2i in rampart.get("fallback", {}):
			PunyTerrain.place(_objects_layer, cell, rampart["fallback"][cell])
	for layer: TileMapLayer in _rampart_layers:
		var scorched := layer == _rampart_layers[-1]
		for cell: Vector2i in rampart["pieces"]:
			if rampart["scorched"].has(cell) == scorched:
				PunyTown.place(layer, cell, rampart["pieces"][cell])
	# A gate set in the rock (the Ashen Mountain's, PIX-269; its other side
	# at the foot of the mountain road, PIX-253 step 8), where nothing stood
	# in the notch: Shade's castle gate, its portcullis down while the story
	# bars it (`barred`, until Maren's promise).
	for way: Dictionary in ways:
		if way["rock"]:
			var barred: bool = way["to"].get("barred", false) and not Relics.gate_open(GameState.progression)
			PunyTerrain.place(_objects_layer, way["at"], Ways.ROCK_GATE_BARRED if barred else Ways.ROCK_GATE)
	if _growth_layer != null:
		for cell: Vector2i in skyline["growth"]:
			PunyTerrain.place(_growth_layer, cell, skyline["growth"][cell])
	if layers.has("flowers"):
		for cell: Vector2i in outdoor_props["flat"]:
			PunyTown.place(layers["flowers"], cell, outdoor_props["flat"][cell])
	for part: String in ["pieces", "decor"]:
		if layers.has(part):
			for cell: Vector2i in buildings[part]:
				PunyTown.place(layers[part], cell, buildings[part][cell])
	if sliced:
		for layer: Node in ground.get_children():
			if layer is TileMapLayer and layer not in [ground_layer, rim_layer, crown_layer]:
				(layer as TileMapLayer).update_internals()


## Hands the region's masks to every material that reads them (One Reach,
## PIX-269): this map's own, or laid out with a map beside it across the
## line (Neighbours), `origin` the local pixel at the masks' first texel and
## `pixels` their size. The crowns read `crowns`, the tone of the regions
## that whiten their pines (null where none does, and they keep their
## green), laid out the same.
func set_masks(tint: Texture2D, water: Texture2D, origin: Vector2, pixels: Vector2, crowns: Texture2D = null) -> void:
	for material: ShaderMaterial in _toned:
		material.set_shader_parameter("tint_map", crowns if material == canopy else tint)
		material.set_shader_parameter("water_map", water)
		material.set_shader_parameter("mask_origin", origin)
		material.set_shader_parameter("map_pixels", pixels)
	if canopy != null:
		canopy.set_shader_parameter("strength", TONE if crowns != null else 0.0)


## This map's own masks again.
func own_masks() -> void:
	if kept != null and not _toned.is_empty():
		set_masks(kept.tint_map, kept.water_map, Vector2.ZERO, Vector2(data.size * TILE), kept.tint_map if kept.crowns_toned else null)


## Sets dual cell `cell`'s ground, cliff and crown (-1 none) as a map beside
## this one has them along their line (Neighbours); `tiles` [ground, crown,
## rim], or [] for the kept ones.
func set_corner(cell: Vector2i, tiles: Array) -> void:
	var kept_tiles := [kept.ground_at(cell), kept.crown_at(cell), kept.rim_at(cell)]
	for i in 3:
		var layer: TileMapLayer = [ground_layer, crown_layer, rim_layer][i]
		var tile: int = tiles[i] if not tiles.is_empty() else kept_tiles[i]
		if tile >= 0:
			PunyTerrain.place(layer, cell, tile)
		else:
			layer.erase_cell(cell)


## Draws the ground's layers now, not at the frame's end (the clock counts it).
func draw_now() -> void:
	if ground_layer != null:
		ground_layer.update_internals()
		rim_layer.update_internals()
		crown_layer.update_internals()


## Whether this drawing's ground is laid from Puny tiles (the open air).
func has_ground_layers() -> bool:
	return ground_layer != null and is_instance_valid(ground_layer)


## This plan's ground drawn on its own over `windows` (PIX-264): Shade's
## terrain (on the dual grid, so it spills half a cell past each window),
## crowns, spans, flowers, houses and the flat field decor over all it
## spills on, without the actors, lights or bodies a visit adds. The town's
## tour draws the town as it stood a moment ago over the town as it stands
## while a building rises out of its ruin.
func draw_ground(windows: Array[Rect2i]) -> Node2D:
	var root := _build_ground(data)
	for layer: Node in root.get_children():
		if not layer is TileMapLayer:
			continue
		# A dual-grid layer sits half a tile up-left: its cell is a corner,
		# and a window's corners run one past its last cell. A layer on the
		# cells keeps every cell those corners reach into.
		var corners: bool = (layer as TileMapLayer).position != Vector2.ZERO
		for cell: Vector2i in (layer as TileMapLayer).get_used_cells():
			var kept := windows.any(func(window: Rect2i) -> bool:
				return (window.grow_individual(0, 0, 1, 1) if corners else window.grow(1)).has_point(cell))
			if not kept:
				(layer as TileMapLayer).erase_cell(cell)
	var seen := {}
	for window: Rect2i in windows:
		var reach := window.grow(1)
		for y in range(reach.position.y, reach.end.y):
			for x in range(reach.position.x, reach.end.x):
				var cell := Vector2i(x, y)
				if seen.has(cell) or not data.grid.has(cell):
					continue
				seen[cell] = true
				var choice := Scatter.choice(data.grid, cell)
				if _is_flat_decor(cell, choice):
					root.add_child(_flat_decor(cell, choice))
	return root


## Field decor drawn flat on the ground (the hero steps over it): not where
## a prop stands, not what blocks, not in a forest.
func _is_flat_decor(cell: Vector2i, choice: int) -> bool:
	return choice >= 0 and not outdoor_props["drawn"].has(cell) and not solid_scatter.has(cell) \
		and choice in Scatter.FLAT and data.grid[cell] != "forest"


func _flat_decor(cell: Vector2i, choice: int) -> Sprite2D:
	var h := absi(hash(cell))
	var flat := Sprite2D.new()
	flat.texture = PunyTerrain.sheet().tile_texture(choice)
	flat.position = center(cell) + Vector2((h >> 12) % 7 - 3, (h >> 16) % 5 - 2)
	flat.material = ground_tint
	flat.add_to_group("decor")
	return flat


## The ground's toning, leaning in the wind `sway` pixels at the top: each
## sprite on its own beat (`alone`), or a layer's tiles together.
func _swaying(sway: float, alone: bool) -> ShaderMaterial:
	var material := _toning()
	material.set_shader_parameter("sway", sway)
	material.set_shader_parameter("sway_alone", alone)
	return material


## A material toned as the ground is, kept in step with its masks.
func _toning() -> ShaderMaterial:
	var material := ground_tint.duplicate() as ShaderMaterial
	_toned.append(material)
	return material


## A room in Shade's Medieval Age pack (PunyInterior): the dark beyond its
## walls, the floor, walls and rugs, then door and furniture (on the walls
## where they lean on them, PIX-237), then his furnished corners (PIX-163):
## what stands, what stands on it, and what sits on that, 6 px up as in his
## samples.
func _build_room(data: MapData) -> Node2D:
	var root := Node2D.new()
	root.add_child(_dark_beyond(data))
	for part: String in ["floor", "walls", "rug", "pieces", "objects", "tops", "lifted"]:
		var layer := tile_layer_of(PunyTown.tileset())
		for cell: Vector2i in buildings.get(part, {}):
			PunyTown.place(layer, cell, buildings[part][cell])
		if part == "lifted":
			layer.position.y = -6
		root.add_child(layer)
	return root


## The dark under a room or a dungeon, on past the map's edges (DARK_PAD).
static func _dark_beyond(data: MapData) -> ColorRect:
	var dark := ColorRect.new()
	dark.color = DARK
	dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dark.position = -Vector2.ONE * DARK_PAD * TILE
	dark.size = Vector2(data.size * TILE) + Vector2.ONE * DARK_PAD * TILE * 2
	return dark


## A dungeon floor in Shade's Puny Dungeon: stone, walls by his grammar and
## the dark beyond, torches flickering on their blocks, barrels, pots and the
## stairs up.
func _build_dungeon(data: MapData) -> Node2D:
	var root := Node2D.new()
	root.add_child(_dark_beyond(data))
	var dungeon := PunyDungeon.sheet()
	var layer := tile_layer_of(dungeon.tileset)
	dungeon_objects = tile_layer_of(dungeon.tileset)
	for cell: Vector2i in data.grid:
		var tile: String = data.grid[cell]
		match tile:
			"wall":
				dungeon.place(layer, cell, PunyDungeon.wall_tile(data.grid, cell))
				continue
			"lamp":
				dungeon.place(layer, cell, PunyDungeon.TORCH_BLOCK)
				dungeon.place(dungeon_objects, cell, PunyDungeon.TORCH)
				# Its fire lights the floor before it (PIX-221).
				root.add_child(Lights.make(center(cell) + Vector2(0, TILE * 0.7), 92.0, Lights.FIRE, Lights.TORCH_ENERGY, true))
				continue
		dungeon.place(layer, cell, PunyDungeon.floor_tile(cell))
		# What a region dungeon's floor draws over a cell (PIX-255): a wreck's
		# beams, the shortcut's door, shut or open.
		if data.pieces.has(cell):
			dungeon.place(dungeon_objects, cell, int(data.pieces[cell]))
			continue
		match tile:
			"barrel":
				dungeon.place(dungeon_objects, cell, PunyDungeon.BARRELS[absi(hash(cell)) % 2])
			"crate":
				dungeon.place(dungeon_objects, cell, PunyDungeon.POT)
			"cave":
				dungeon.place(dungeon_objects, cell, PunyDungeon.STAIRS)
			"stairwell":
				dungeon.place(dungeon_objects, cell, PunyDungeon.STAIRS_DOWN)
			"rock":
				dungeon.place(dungeon_objects, cell, PunyDungeon.BOULDERS[absi(hash(cell)) % PunyDungeon.BOULDERS.size()])
			"winch":
				# The ore cage's winch by its gate (PIX-255: the Black Seam).
				dungeon.place(dungeon_objects, cell, PunyDungeon.WHEEL)
			# The Greyhold cellars' stone knights and iron grilles (PIX-255).
			"statue":
				dungeon.place(dungeon_objects, cell, PunyDungeon.STATUE)
			"grille":
				dungeon.place(dungeon_objects, cell, PunyDungeon.GRILLE)
	root.add_child(layer)
	var ice := _frozen(data)
	if ice != null:
		root.add_child(ice)
		# The ice gives the dark back a little cold light, here and there.
		for cell: Vector2i in data.grid:
			if data.grid[cell] == "ice" and posmod(cell.x, ICE_LIGHT_EVERY.x) == 2 and posmod(cell.y, ICE_LIGHT_EVERY.y) == 2:
				root.add_child(Lights.make(center(cell), 72.0, Lights.ICE, Lights.ICE_ENERGY))
	root.add_child(dungeon_objects)
	return root


## Ice over a dungeon's stone (PIX-255: the ice cave's frozen lake, and its
## glass hall's floor): the floor of its `ice` cells and of the stone round
## them laid again, frozen by shaders/frozen.gdshader from a mask a texel a
## cell (the shore runs between cells, bent off the grid, frost creeping out
## over the stone). Between the floor and what stands on it; null for a map
## with no ice.
func _frozen(data: MapData) -> TileMapLayer:
	var mask := Image.create(maxi(data.size.x, 1), maxi(data.size.y, 1), false, Image.FORMAT_L8)
	var frozen := false
	for cell: Vector2i in data.grid:
		if data.grid[cell] == "ice":
			mask.set_pixelv(cell, Color.WHITE)
			frozen = true
	if not frozen:
		return null
	var dungeon := PunyDungeon.sheet()
	var layer := tile_layer_of(dungeon.tileset)
	for cell: Vector2i in data.grid:
		if data.grid[cell] not in ["wall", "lamp"] and _by_ice(data, cell):
			dungeon.place(layer, cell, PunyDungeon.floor_tile(cell))
	var frost := ShaderMaterial.new()
	frost.shader = preload("res://shaders/frozen.gdshader")
	frost.set_shader_parameter("ice_map", ImageTexture.create_from_image(mask))
	frost.set_shader_parameter("map_pixels", Vector2(data.size * TILE))
	layer.material = frost
	return layer


## Whether `cell` is ice or touches it, corners too: where the frost may
## reach.
static func _by_ice(data: MapData, cell: Vector2i) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if data.grid.get(cell + Vector2i(dx, dy), "") == "ice":
				return true
	return false


## A cell opened while the hero looks on (PIX-255: the shortcut's door once
## the dungeon's boss is down): drawn again as it stands now, and its
## invisible box gone once it's open ground.
func reopen(cell: Vector2i) -> void:
	if dungeon_objects != null and data.pieces.has(cell):
		PunyDungeon.sheet().place(dungeon_objects, cell, int(data.pieces[cell]))
	if data.is_walkable(cell):
		tile_layer.erase_cell(cell)


## A way straight out of a dungeon's bottom floor (PIX-292: its shortcut's
## door, or a way out opened where its boss fell): a lamp of daylight over
## it that breathes, and its plate as the hero comes near - "Way out", and
## where it leads (depths.json `sign`).
func light_way_out(cell: Vector2i) -> void:
	var door := Depths.shortcut_on(data.id)
	# The door in the rock spills its daylight onto the floor before it, as a
	# torch in the wall does; a way out in the floor lights round itself.
	var spill := Vector2(0, TILE * 0.7) if door.get("cell") == cell else Vector2.ZERO
	var lamp := Lights.make(center(cell) + spill, WAY_OUT_GLOW, Lights.WAY_OUT, Lights.WAY_OUT_ENERGY)
	lamp.set_meta("pulse", true)
	props.add_child(lamp)
	door_signs.append({"door": cell, "name": Text.t("Way out"), "about": String(door.get("sign", "")), "node": null, "over": WAY_OUT_PLATE})


## Chests and terrain decor live in the y-sorted actors layer: units of the
## drawing, in order - the camps, the town's ruins, the patches, the lit
## windows and hearths, the chests, the props a handful at a time, the
## gates, then the field's decor a few rows at a time.
func _decor_units(slices: Slicer) -> void:
	slices.add("decor_camps", func() -> void:
		for cell: Vector2i in camps:
			_add_camp_piece(cell, camps[cell]))
	if data.id == "town":
		slices.add("decor_ruins", _decor_ruins)
	slices.add("decor_patches", func() -> void:
		patch_sprites = {}
		for cell: Vector2i in patches:
			_add_patch_sprite(cell))
	slices.add("decor_lights", _decor_lights)
	slices.add("decor_chests", _decor_chests)
	var standing: Array = outdoor_props["props"]
	slices.add_each("decor_props", ceili(standing.size() / float(PROPS_A_UNIT)), func(i: int) -> void:
		for prop: Dictionary in standing.slice(i * PROPS_A_UNIT, (i + 1) * PROPS_A_UNIT):
			_add_puny_prop(prop))
	slices.add("decor_gates", func() -> void:
		for gate: Dictionary in gates:
			_add_gate(gate))
	var a_unit := maxi(1, data.size.x * DECOR_ROWS)
	slices.add_each("decor_field", ceili(_keys.size() / float(a_unit)), func(i: int) -> void:
		for cell: Vector2i in _keys.slice(i * a_unit, (i + 1) * a_unit):
			_add_field_decor(cell))


## The town's ruins smoking, and on the night of the fire still burning
## (PIX-151), but for the ones the hero put out (PIX-197).
func _decor_ruins() -> void:
	var burning := GameState.progression.prologue != Prologue.DONE
	var ruins := Town.ruins(Town.done_projects(GameState.settlement))
	for i in ruins.size():
		_add_smoke(ruins[i]["rect"])
		if burning and i not in GameState.progression.prologue_doused:
			fires.append({"rect": ruins[i]["rect"], "nodes": _add_fire(ruins[i]["rect"]), "ruin": i})


## Lit windows at night, smoke from every finished house (PIX-149). A
## room's windows are in its walls. The village far off has its own.
func _decor_lights() -> void:
	var built: Dictionary = buildings.get("walls", {}).merged(buildings["pieces"], true)
	for cell: Vector2i in built:
		var tile: int = built[cell]
		if tile == PunyTown.WINDOW and skyline.is_empty():
			# A candle behind the glass lights the street a little (PIX-221).
			_add_glow(center(cell), 10, 0.5, 40.0, Lights.WINDOW, false, Lights.WINDOW_ENERGY)
		elif tile == PunyTown.WINDOW:
			# Far off the windows stand side by side: a smaller candle each,
			# on the glass rather than round it (PIX-248).
			_add_glow(center(cell) + Vector2(0, -1), 6, 0.55, 30.0, Lights.WINDOW, false, Lights.WINDOW_ENERGY)
		elif tile in PunyInterior.FIRE_TILES:
			# A hearth or a forge warms the room it's in, and embers rise off
			# it (PIX-225).
			props.add_child(Lights.make(center(cell) + Vector2(TILE / 2.0, 4), 96.0, Lights.FIRE, Lights.FIRE_ENERGY, true))
			var embers := _still(Motes.make_embers())
			embers.position = center(cell) + Vector2(TILE / 2.0, 6)
			embers.z_index = 6
			props.add_child(embers)
		elif tile == PunyTown.DOOR and skyline.is_empty():
			_add_chimney_smoke(cell)
	if not skyline.is_empty():
		_add_village_life()


## The chests and the treasure on the ground, as they stand.
func _decor_chests() -> void:
	chest_sprites = {}
	for chest: Dictionary in Interactables.chests_on(data.id):
		var texture := treasure_texture(chest, GameState.spoils.is_opened(chest))
		if texture == null:
			continue
		var cell := Vector2i(int(chest["x"]), int(chest["y"]))
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.position = center(cell)
		sprite.add_to_group("decor")
		actors.add_child(sprite)
		chest_sprites[chest["id"]] = sprite
		if chest["look"] == "chest":
			# Furniture blocks the tile; ground treasure never does. The grid
			# knows too, so nothing spawns or paces into it.
			data.covered[cell] = true
			var body := StaticBody2D.new()
			var shape := CollisionShape2D.new()
			var rect := RectangleShape2D.new()
			rect.size = Vector2(TILE, TILE)
			shape.shape = rect
			body.add_child(shape)
			body.position = center(cell)
			body.add_to_group("decor")
			actors.add_child(body)


## A cell's field decor: a bush or a stump that blocks, a tuft flat on the
## ground, or a tree or a sheaf among the actors.
func _add_field_decor(cell: Vector2i) -> void:
	var choice := Scatter.choice(data.grid, cell)
	if choice < 0 or outdoor_props["drawn"].has(cell):
		return
	if solid_scatter.has(cell):
		_add_solid_decor(choice, cell)
	elif _is_flat_decor(cell, choice):
		ground.add_child(_flat_decor(cell, choice))
	else:
		_add_decor_sprite(PunyTerrain.SHEET, PunyTerrain.region(choice), cell, absi(hash(cell)))
		actors.get_child(-1).material = decor_sway if choice in Scatter.SWAYS else ground_tint


## A drawing's motes rise in its own space (One Reach, PIX-269): handed
## over at a line, the drawing moves under them, and what was already in the
## air moves with it. They never move otherwise, so they look the same.
static func _still(motes: CPUParticles2D) -> CPUParticles2D:
	motes.local_coords = true
	return motes


## Field decor that blocks (Scatter.solid), kept off the cell the hero
## arrives on, villagers' homes and chests.
func _solid_scatter(data: MapData, arrival: Vector2i) -> Dictionary:
	if data.floor_level > 0 or not PunyTerrain.is_outdoor(data.grid):
		return {}
	var kept := {arrival: true}
	for npc: Dictionary in Npcs.on_map(data.id, GameState.settlement.town_tier, GameState.settlement.settlers, Town.done_projects(GameState.settlement), Relics.gate_open(GameState.progression), GameState.progression.deepest, Letters.tin_waits(GameState.progression)):
		kept[Vector2i(int(npc["x"]), int(npc["y"]))] = true
	for chest: Dictionary in Interactables.chests_on(data.id):
		kept[Vector2i(int(chest["x"]), int(chest["y"]))] = true
	for cell: Vector2i in patches:
		kept[cell] = true
	# A pack's home and the cells around it stay open for the pack.
	for spawn: Dictionary in Bestiary.spawns_on(data.id):
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				kept[Vector2i(spawn["x"] + dx, spawn["y"] + dy)] = true
	return Scatter.solid(data, kept, outdoor_props["drawn"])


## Where each wild pack's camp stands: a tent on the first open cell of its
## region in CAMP_RING, and a torch on the next one within two of the tent.
## A night pack keeps none (PIX-252): it comes out of the dark, and a camp,
## drawn once for the visit, would stand empty all day.
static func plan_camps(map: MapData) -> Dictionary:
	var out := {}
	if map.floor_level > 0 or map.style == "cave":
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


## Flames on a house that's still burning (the Night of Ash): Shade's looped
## flame on a handful of its cells and his embers drifting over it; without
## the paid pack, an orange flicker of motes instead. Its light falls in a
## few soft pools (fire_pools), not one to a flame.
func _add_fire(rect: Rect2i) -> Array[Node2D]:
	var nodes: Array[Node2D] = []
	for pool: Dictionary in fire_pools(rect):
		var light := Lights.make(pool["at"], pool["radius"], Lights.FIRE, Lights.BLAZE_ENERGY, true)
		props.add_child(light)
		nodes.append(light)
	var flame := ItemIcons.effect("flame", 10.0)
	var embers := ItemIcons.effect("embers", 8.0)
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if (x * 5 + y * 11) % 6 != 0:
				continue
			var at := center(Vector2i(x, y))
			if flame != null:
				var fire := AnimatedSprite2D.new()
				fire.sprite_frames = flame
				fire.position = at + Vector2(0, -4)
				fire.frame = absi(x * 3 + y) % flame.get_frame_count("default")
				fire.play()
				fire.material = Lights.unshaded()
				fire.z_index = 4
				fire.add_to_group("decor")
				props.add_child(fire)
				nodes.append(fire)
				nodes.append(_add_glow(at, 14, 0.4))
			if embers != null and (x + y) % 3 == 0:
				var drift := AnimatedSprite2D.new()
				drift.sprite_frames = embers
				drift.position = at + Vector2(0, -14)
				drift.play()
				drift.z_index = 6
				drift.add_to_group("decor")
				props.add_child(drift)
				nodes.append(drift)
	if flame == null:
		var motes := _still(CPUParticles2D.new())
		motes.position = Vector2(rect.position * TILE) + Vector2(rect.size * TILE) / 2.0
		motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		motes.emission_rect_extents = Vector2(rect.size * TILE) / 2.0
		motes.amount = 16
		motes.lifetime = 0.9
		motes.direction = Vector2.UP
		motes.gravity = Vector2(0, -20)
		motes.initial_velocity_min = 8.0
		motes.initial_velocity_max = 16.0
		motes.scale_amount_min = 2.0
		motes.scale_amount_max = 3.0
		motes.color = Color(1.0, 0.5, 0.12, 0.9)
		motes.z_index = 6
		motes.add_to_group("decor")
		props.add_child(motes)
		nodes.append(motes)
	return nodes


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
func burn(rect: Rect2i) -> int:
	fires.append({"rect": rect, "nodes": _add_fire(rect)})
	return fires.size() - 1


## Every lamp in the village out (PIX-253 step 9: Aske puts them out, all
## but the five lanterns, so the dragon comes down on the square): each
## flame and its glow gone, its light dark, the cold torch shown.
func lamps_out() -> void:
	for lamp: Dictionary in lamps:
		lamp["out"] = true
		if is_instance_valid(lamp["flame"]):
			lamp["flame"].visible = false
			lamp["unlit"].visible = true
		var glow: Node2D = lamp.get("glow")
		if not is_instance_valid(glow):
			continue
		glow.visible = false
		night_glows.erase(glow)
		# Its light gone with it, so the square's own lights have the
		# ground's blocks to themselves (PIX-285, test_night_light).
		var light: Node = glow.get_meta("light", null)
		if is_instance_valid(light):
			light.free()
		glow.remove_meta("light")


## The fire on ruin `ruin` (Town.ruins' order), if it still burns.
func douse_ruin(ruin: int, seconds := 1.2) -> void:
	for i in fires.size():
		if int(fires[i].get("ruin", -1)) == ruin:
			douse(i, seconds)


## The fire on one burning ruin (the Night of Ash's dawn, PIX-197) gutters
## out: its flames shrink and fade over `seconds`, its light dims, a last
## breath of smoke goes up, and they're gone.
func douse(index: int, seconds := 1.2) -> void:
	if index < 0 or index >= fires.size():
		return
	var fire: Dictionary = fires[index]
	if fire.get("out", false):
		return
	fire["out"] = true
	for node: Node2D in fire["nodes"]:
		if not is_instance_valid(node):
			continue
		night_glows.erase(node)
		var out := node.create_tween().set_parallel()
		if node is PointLight2D:
			# The LightRig brings a light up to its "energy" every frame.
			out.tween_method(func(energy: float) -> void: node.set_meta("energy", energy), float(node.get_meta("energy", 0.0)), 0.0, seconds)
		else:
			out.tween_property(node, "scale", node.scale * Vector2(0.2, 0.05), seconds).set_ease(Tween.EASE_IN)
			out.tween_property(node, "modulate:a", 0.0, seconds)
		out.chain().tween_callback(node.queue_free)
	var rect: Rect2i = fire["rect"]
	var puff := _still(CPUParticles2D.new())
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
	props.add_child(puff)
	puff.finished.connect(puff.queue_free)
	puff.emitting = true


## Smoke and embers over a burnt house (PIX-146): pixel motes drifting up
## from its footing, the embers quicker and fewer (a `share` of them, for a
## house seen small from afar). Still with Reduce motion.
func _add_smoke(rect: Rect2i, share := 1.0) -> void:
	if GameState.settings.reduce_motion:
		return
	var middle := Vector2(rect.position * TILE) + Vector2(rect.size * TILE) / 2.0
	var extents := (Vector2(rect.size * TILE) / 2.0 - Vector2(10, 10)).max(Vector2(3, 3))
	for ember in [false, true]:
		var motes := _still(CPUParticles2D.new())
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
		props.add_child(motes)


static var _glow_textures := {}


## A warm, stepped glow (the title's lamplight), shown only at night, and
## with `light_radius` a real light beside it that lights what's around
## (PIX-221), gone with it.
func _add_glow(at: Vector2, radius: int, peak: float, light_radius := 0.0, light_color := Lights.LAMP, flicker := false, energy := 1.0) -> Sprite2D:
	var key := "%d:%f" % [radius, peak]
	if not _glow_textures.has(key):
		_glow_textures[key] = TitleScene.glow_texture(radius, Color(1.0, 0.72, 0.38), peak, 4)
	var glow := Sprite2D.new()
	glow.texture = _glow_textures[key]
	# Added onto the night, never darkened by it.
	glow.material = Lights.glow()
	if light_radius > 0.0:
		var lamp := Lights.make(at, light_radius, light_color, energy, flicker)
		props.add_child(lamp)
		glow.tree_exiting.connect(lamp.queue_free)
		glow.set_meta("light", lamp)
	glow.position = at
	glow.z_index = 5
	glow.add_to_group("decor")
	props.add_child(glow)
	night_glows.append(glow)
	return glow


## Lamps and windows for the hour: lit from dusk's end to dawn, cold by day.
func set_night(night: bool) -> void:
	if int(night) == _night:
		return
	_night = int(night)
	for lamp: Dictionary in lamps:
		if is_instance_valid(lamp["flame"]) and not lamp.get("out", false):
			lamp["flame"].visible = night
			lamp["unlit"].visible = not night
	for glow in night_glows:
		if is_instance_valid(glow):
			glow.visible = night


## A thread of smoke from a house's chimney: up from its door to the roof's
## top, a little to the side.
func _add_chimney_smoke(door: Vector2i) -> void:
	var top := door
	while buildings["pieces"].has(top + Vector2i.UP):
		top += Vector2i.UP
	_add_smoke_thread(Vector2(top * TILE) + Vector2(TILE * 1.5, 2))


## The village far off (PIX-248): smoke from every roof (the houses are the
## paid pack's) and over what still lies in ruins, and its lamps lit at
## night (its windows light with the town's). Small glows with small lights:
## the village is small here.
func _add_village_life() -> void:
	if PunyTown.available():
		for at: Vector2 in skyline["smoke"]:
			_add_smoke_thread(at)
	for ruin: Rect2i in skyline["ruins"]:
		_add_smoke(ruin, VILLAGE_RUIN_SMOKE)
	for cell: Vector2i in skyline["lamps"]:
		_add_glow(center(cell), 5, 0.4, 26.0, Lights.LAMP, true, Lights.LAMP_ENERGY)


## A thread of chimney smoke rising from `at`. Still with Reduce motion.
func _add_smoke_thread(at: Vector2) -> void:
	if GameState.settings.reduce_motion:
		return
	var motes := _still(CPUParticles2D.new())
	motes.position = at
	motes.amount = 5
	motes.lifetime = 3.5
	motes.direction = Vector2.UP
	motes.spread = 12.0
	motes.gravity = Vector2(3, -3)
	motes.initial_velocity_min = 4.0
	motes.initial_velocity_max = 8.0
	motes.scale_amount_min = 2.0
	motes.scale_amount_max = 3.0
	var fade := Gradient.new()
	fade.set_color(0, Color(0.82, 0.8, 0.78, 0.5))
	fade.set_color(1, Color(0.85, 0.84, 0.82, 0.0))
	motes.color_ramp = fade
	motes.z_index = 6
	motes.add_to_group("decor")
	props.add_child(motes)


## A patch the world adds after planning (a dungeon floor's).
func add_patch(cell: Vector2i, spot_id: String, item_id: String) -> void:
	patches[cell] = {"id": spot_id, "item": item_id}
	_add_patch_sprite(cell)


## A patch on the ground: its material, with a glint that comes and goes so
## it reads as something to pick; hidden while it grows back.
func _add_patch_sprite(cell: Vector2i) -> void:
	var patch: Dictionary = patches[cell]
	var root := Node2D.new()
	root.position = center(cell)
	root.add_to_group("decor")
	var sprite := Sprite2D.new()
	sprite.texture = ItemIcons.texture(patch["item"])
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root.add_child(sprite)
	var glint := ColorRect.new()
	glint.color = Color(1, 1, 0.9)
	glint.size = Vector2(1, 1)
	glint.position = Vector2(3, -5)
	glint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(glint)
	# The glint's own tween: it goes when the glint goes.
	var twinkle := glint.create_tween().set_loops()
	twinkle.tween_property(glint, "modulate:a", 0.0, 0.6).set_delay(absf(sin(cell.x * 12.9 + cell.y * 78.2)) * 1.5)
	twinkle.tween_property(glint, "modulate:a", 1.0, 0.25)
	ground.add_child(root)
	patch_sprites[patch["id"]] = root
	root.visible = Gathering.is_ready(GameState.world, patch["id"])


## Deals day `day`'s wild patches (PIX-250), unless they're dealt already;
## whether they changed.
func deal_patches(day: int) -> bool:
	if patch_decks.is_empty() or day == patch_day:
		return false
	patch_day = day
	patches = Gathering.patches_on(patch_decks, day)
	return true


## Patches that have grown back show again; when the day turns while the
## hero is here, yesterday's go and the new day's grow elsewhere (PIX-250).
func refresh_patches() -> void:
	if deal_patches(Gathering.day_of(GameState.world.steps)):
		for spot_id: String in patch_sprites:
			patch_sprites[spot_id].queue_free()
		patch_sprites = {}
		for cell: Vector2i in patches:
			_add_patch_sprite(cell)
	for spot_id: String in patch_sprites:
		patch_sprites[spot_id].visible = Gathering.is_ready(GameState.world, spot_id)


## A tent pitched on the map as it stands (PIX-253 step 9: Iva's on the
## square's edge, the Night of Bells): drawn among the actors, its cell
## blocked, gone with the visit.
func pitch_tent(cell: Vector2i) -> void:
	if camps.has(cell):
		return
	camps[cell] = {"kind": "tent", "tile": TENTS["marsh"]}
	data.covered[cell] = true
	_add_camp_piece(cell, camps[cell])


## A camp's tent or torch: sorted among the actors at its foot, which blocks.
func _add_camp_piece(cell: Vector2i, piece: Dictionary) -> void:
	var foot: Rect2 = {"tent": TENT_FOOT, "board": BOARD_FOOT}.get(piece["kind"], TORCH_FOOT)
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
		var embers := _still(Motes.make_embers(3))
		embers.position = Vector2(TILE / 2.0, -foot.end.y - 2)
		embers.z_index = 6
		root.add_child(embers)
		# Each camp's fire flickers on its own beat.
		flame.frame = absi(hash(cell)) % CAMP_TORCH.size()
		sprite = flame
	else:
		var tent := Sprite2D.new()
		tent.texture = PunyTerrain.sheet().tile_texture(piece["tile"])
		sprite = tent
	sprite.set("centered", false)
	sprite.position = Vector2(0, -foot.end.y)
	root.add_child(sprite)
	if piece.get("wanted", false):
		var poster := Sprite2D.new()
		poster.texture = _wanted_poster()
		poster.centered = false
		poster.position = Vector2(5, 5)
		sprite.add_child(poster)
	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = foot.size
	shape.shape = rect
	shape.position = foot.get_center() - Vector2(0, foot.end.y)
	body.add_child(shape)
	root.add_child(body)
	actors.add_child(root)


static var _torch_frames: SpriteFrames
static var _poster: ImageTexture


## A wanted poster pinned over the board's notes: a red header, a dark face.
static func _wanted_poster() -> ImageTexture:
	if _poster == null:
		var art := Image.create(6, 7, false, Image.FORMAT_RGBA8)
		art.fill(Color("f1e3c0"))
		for x in range(1, 5):
			art.set_pixel(x, 1, Color("b33a2c"))
		for cell: Vector2i in [Vector2i(2, 3), Vector2i(3, 3), Vector2i(2, 4), Vector2i(3, 4), Vector2i(1, 4), Vector2i(4, 4)]:
			art.set_pixel(cell.x, cell.y, Color("4a3426"))
		for x in 6:
			art.set_pixel(x, 6, Color("c9b48a"))
		art.set_pixel(0, 0, Color("8a2a20"))
		art.set_pixel(5, 0, Color("8a2a20"))
		_poster = ImageTexture.create_from_image(art)
	return _poster


static func _camp_torch_frames() -> SpriteFrames:
	if _torch_frames == null:
		_torch_frames = SpriteFrames.new()
		_torch_frames.set_animation_speed("default", 8.0)
		for tile: int in CAMP_TORCH:
			_torch_frames.add_frame("default", PunyDungeon.sheet().tile_texture(tile))
	return _torch_frames


## A bush, stump or tree that blocks: on its cell's centre (no jitter, so the
## body sits under it), sorted and stopped at its foot.
func _add_solid_decor(choice: int, cell: Vector2i) -> void:
	var root := Node2D.new()
	root.position = Vector2(cell * TILE) + Vector2(0, Scatter.FOOT.end.y)
	root.add_to_group("decor")
	var sprite := Sprite2D.new()
	sprite.texture = PunyTerrain.sheet().tile_texture(choice)
	sprite.centered = false
	sprite.position = Vector2(0, -Scatter.FOOT.end.y)
	sprite.material = decor_sway if choice in Scatter.SWAYS else ground_tint
	root.add_child(sprite)
	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Scatter.FOOT.size
	shape.shape = rect
	shape.position = Scatter.FOOT.get_center() - Vector2(0, Scatter.FOOT.end.y)
	body.add_child(shape)
	root.add_child(body)
	actors.add_child(root)


## A gate still shut (PIX-254): its pieces (GateArt) among the actors or flat
## on the ground, and a box on each of its cells, so it blocks like any prop.
func _add_gate(gate: Dictionary) -> void:
	for piece: Dictionary in GateArt.plan(gate, PunyProps.available())["pieces"]:
		_add_gate_piece(piece)
	for cell: Vector2i in Gates.cells_of(gate):
		var body := StaticBody2D.new()
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(TILE, TILE)
		shape.shape = rect
		body.add_child(shape)
		body.position = center(cell)
		body.add_to_group("decor")
		actors.add_child(body)


func _add_gate_piece(piece: Dictionary) -> void:
	var cell: Vector2i = piece["cell"]
	var at: Vector2 = piece["at"]
	if piece["sheet"] == "villager":
		# One of the old guard, standing his post, facing down the road.
		var art := PunyArt.villager(piece["sprite"])
		var guard := AnimatedSprite2D.new()
		guard.sprite_frames = PunyArt.frames(art)
		guard.play(PunyArt.pick(guard.sprite_frames, "idle", "left"))
		# Sorted on the cell's foot, in front of the fence he keeps.
		guard.position = Vector2(0, -TILE / 2.0 + PunyArt.lift(art))
		var post := Node2D.new()
		post.position = Vector2(cell * TILE) + Vector2(TILE / 2.0 + at.x, TILE)
		post.add_to_group("decor")
		post.add_child(guard)
		actors.add_child(post)
		return
	var sprite := Sprite2D.new()
	match String(piece["sheet"]):
		"dungeon":
			sprite.texture = PunyDungeon.sheet().tile_texture(piece["tile"])
		"props":
			sprite.texture = PunyProps.texture(piece["tile"])
		_:
			sprite.texture = PunyTerrain.sheet().tile_texture(piece["tile"])
	sprite.centered = false
	match String(piece["tone"]):
		"snow":
			sprite.material = _snow()
		"charred":
			sprite.modulate = GateArt.CHARRED
	if piece["flat"]:
		sprite.position = Vector2(cell * TILE) + at
		ground.add_child(sprite)
		return
	# Sorted on its own foot, the bottom of its sprite.
	var root := Node2D.new()
	root.position = Vector2(cell * TILE) + Vector2(0, TILE + at.y)
	root.add_to_group("decor")
	sprite.position = Vector2(at.x, -TILE)
	root.add_child(sprite)
	actors.add_child(root)


static var _snow_tone: ShaderMaterial


## The Frostgate's snow on whatever wears it (PIX-254: the avalanche): the
## region tint's whitening, everywhere.
static func _snow() -> ShaderMaterial:
	if _snow_tone == null:
		var tint := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		tint.fill(PunyTerrain.TINTS["snow"])
		_snow_tone = ShaderMaterial.new()
		_snow_tone.shader = preload("res://shaders/region_tint.gdshader")
		_snow_tone.set_shader_parameter("tint_map", ImageTexture.create_from_image(tint))
		_snow_tone.set_shader_parameter("map_pixels", Vector2(TILE, TILE))
	return _snow_tone


## A chest or ground treasure as it stands: Shade's chest, pouch or herbs
## (PunyProps); without the paid pack his CC0 dungeon chest, and nothing for
## ground treasure. Null when it's gone.
static func treasure_texture(chest: Dictionary, opened: bool) -> Texture2D:
	if PunyProps.available():
		var tile := PunyProps.treasure_tile(chest["look"], opened)
		return PunyProps.texture(tile) if tile >= 0 else null
	if chest["look"] != "chest":
		return null
	return PunyDungeon.sheet().tile_texture(PunyDungeon.CHEST_OPEN if opened else PunyDungeon.CHEST)


## One of Shade's props among the actors (PunyProps): sorted on the bottom of
## its foot, so the hero passes behind it from the north and in front from
## the south, with a body exactly where the foot is.
func _add_puny_prop(prop: Dictionary) -> Node2D:
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
	else:
		for piece: Array in prop["tiles"]:
			var sprite: Node2D
			if not prop["frames"].is_empty():
				# Lit at night only, a cold torch by day, a warm glow around it.
				var unlit := Sprite2D.new()
				unlit.texture = PunyProps.texture(PunyProps.LAMP_UNLIT)
				unlit.centered = false
				unlit.position = Vector2(piece[0] * TILE) - Vector2(0, sort_y)
				root.add_child(unlit)
				var flame := AnimatedSprite2D.new()
				var glow := _add_glow(Vector2(prop["cell"] * TILE) + Vector2(TILE / 2.0, 4), 22, 0.35, 76.0, Lights.LAMP, true, Lights.LAMP_ENERGY)
				lamps.append({"flame": flame, "unlit": unlit, "glow": glow})
				flame.sprite_frames = PunyProps.animation(prop["frames"], PunyProps.LAMP_FPS)
				flame.material = Lights.unshaded()
				flame.centered = false
				# Each torch flickers on its own beat.
				flame.play()
				flame.frame = absi(hash(prop["cell"])) % prop["frames"].size()
				sprite = flame
			else:
				var still := Sprite2D.new()
				still.texture = PunyDungeon.sheet().tile_texture(piece[1]) if prop["sheet"] == "dungeon" else PunyProps.texture(piece[1])
				still.centered = false
				sprite = still
			sprite.position = Vector2(piece[0] * TILE) - Vector2(0, sort_y)
			root.add_child(sprite)
	if foot.has_area():
		var body := StaticBody2D.new()
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = foot.size
		shape.shape = rect
		shape.position = foot.get_center() - Vector2(0, sort_y)
		body.add_child(shape)
		root.add_child(body)
	actors.add_child(root)
	prop_nodes[prop["cell"]] = root
	return root


func _add_decor_sprite(texture_path: String, region: Rect2, cell: Vector2i, h: int) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = _cut(texture_path, region)
	# Feet on the ground with a little organic jitter.
	sprite.position = center(cell) + Vector2((h >> 12) % 7 - 3, (h >> 16) % 5 - 2)
	sprite.offset = Vector2(0, -region.size.y / 2 + 6)
	sprite.add_to_group("decor")
	actors.add_child(sprite)


## A piece of a sheet, cut once a session and shared by every sprite that
## shows it (PIX-269): a field's hundreds of trees and bushes are a dozen
## pieces, not a resource made (and freed again) for each one at every
## visit.
static var _cuts := {}


static func _cut(texture_path: String, region: Rect2) -> AtlasTexture:
	var key := "%s@%s" % [texture_path, region]
	if not _cuts.has(key):
		var atlas := AtlasTexture.new()
		atlas.atlas = load(texture_path)
		atlas.region = region
		_cuts[key] = atlas
	return _cuts[key]


## Door signs float above the world, outside the y-sort: Shade's hanging
## boards (ShopSign), the place's name rising as the hero walks up. They are
## the paid pack's; without it the doors stand bare.
func _build_props(data: MapData) -> Node2D:
	var root := Node2D.new()
	door_signs = []
	if not ShopSign.available():
		return root
	var ruins: Array[Dictionary] = []
	if data.id == "town":
		ruins = Town.ruins(Town.done_projects(GameState.settlement))
	for sign_def: Dictionary in Interactables.signs_on(data.id, GameState.household.owns_house()):
		var door := Vector2i(int(sign_def["x"]), int(sign_def["y"]))
		# A burnt house has lost its sign with its roof (PIX-146).
		if ruins.any(func(ruin: Dictionary) -> bool: return (ruin["rect"] as Rect2i).has_point(door)):
			continue
		var target: Dictionary = data.portals.get(door, {})
		var board := ShopSign.build(sign_def["label"], door)
		root.add_child(board)
		var told := ShopSign.about(sign_def["label"], String(target.get("mapId", "")), GameState.household.owns_house())
		door_signs.append({"door": door, "name": told["name"], "about": told["about"], "node": board})
	return root


## Placed furniture in the house: y-sorted sprites that block (rugs lie flat).
func furnish() -> void:
	for piece in actors.get_tree().get_nodes_in_group("furniture"):
		piece.queue_free()
	for cell: Vector2i in furniture_cells:
		data.covered.erase(cell)
	furniture_cells = []
	if data.id != "town_house":
		return
	for placed: Dictionary in GameState.household.furniture():
		var item_id: String = placed["itemId"]
		var cell := Vector2i(placed["x"], placed["y"])
		if PunyTown.available():
			_place_furniture(item_id, cell)
			continue
		# Without the paid pack the piece isn't drawn, but it still stands
		# in the way.
		if not Town.furniture_blocks(item_id):
			continue
		furniture_cells.append(cell)
		data.covered[cell] = true
		var body := StaticBody2D.new()
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(TILE, TILE)
		shape.shape = rect
		body.add_child(shape)
		body.position = center(cell)
		body.add_to_group("furniture")
		body.add_to_group("decor")
		actors.add_child(body)


## A piece the hero placed, in Shade's furniture (PunyInterior.PLACED): the
## rug on the floor under everyone, the rest standing on their cell like any
## prop, a whole cell their foot.
func _place_furniture(item_id: String, cell: Vector2i) -> void:
	var tiles: Array = PunyInterior.PLACED[item_id]
	if not Town.furniture_blocks(item_id):
		for piece: Array in tiles:
			var rug := Sprite2D.new()
			rug.texture = PunyProps.texture(piece[1])
			rug.centered = false
			rug.position = Vector2((cell + piece[0]) * TILE)
			rug.add_to_group("furniture")
			ground.add_child(rug)
		return
	var root := _add_puny_prop({
		"kind": item_id, "cell": cell, "tiles": tiles, "sheet": "medieval", "frames": [],
		"foot": Rect2(0, 0, TILE, TILE), "covers": [cell],
	})
	root.add_to_group("furniture")
	furniture_cells.append(cell)
	data.covered[cell] = true


## What the cells add to Shade's layers (ground, houses, rooms, props,
## dungeons draw everything else): an invisible box on every unwalkable cell
## (a prop's own body stands in for its cells), and outdoors the stone floor
## of the ruins, in his dungeon stone, under whatever stands on it. The
## layer, then a band of rows a unit (a band of its physics quadrants).
func _blockers_setup() -> void:
	tile_layer = tile_layer_of(_blockers())
	under.add_child(tile_layer)


func _blocker_rows(i: int) -> void:
	var ruins := data.floor_level == 0 and PunyTerrain.is_outdoor(data.grid)
	# The gatehouse's towers block a cell above the wall too (PIX-248).
	var towers: Array = rampart.get("covers", [])
	for y in range(i * BLOCK, mini((i + 1) * BLOCK, data.size.y)):
		for x in data.size.x:
			var cell := Vector2i(x, y)
			if not data.grid.has(cell):
				continue
			var tile: String = data.grid[cell]
			var prop: bool = outdoor_props["drawn"].has(cell)
			if ruins and (tile == "floor" or (prop and [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT].any(
				func(step: Vector2i) -> bool: return data.grid.get(cell + step, "") == "floor"
			))):
				tile_layer.set_cell(cell, STONE_SOURCE, Vector2i.ZERO)
				continue
			if (not prop and not WorldTiles.is_walkable(tile)) or cell in towers:
				tile_layer.set_cell(cell, BLOCKER_SOURCE, Vector2i.ZERO)
	if sliced:
		tile_layer.update_internals()


## The blockers' tileset, made once a session: the ruins' stone, and an
## invisible tile with a box the size of its cell.
static var _blocker_set: TileSet
const STONE_SOURCE := 0
const BLOCKER_SOURCE := 1


static func _blockers() -> TileSet:
	if _blocker_set != null:
		return _blocker_set
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(TILE, TILE)
	tileset.add_physics_layer()
	var box := PackedVector2Array([
		Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8),
	])
	var stone := TileSetAtlasSource.new()
	stone.texture = PunyDungeon.sheet().tile_texture(PunyDungeon.FLOOR)
	stone.texture_region_size = Vector2i(TILE, TILE)
	stone.create_tile(Vector2i.ZERO)
	tileset.add_source(stone, STONE_SOURCE)
	var blocker := TileSetAtlasSource.new()
	blocker.texture = ImageTexture.create_from_image(Image.create(TILE, TILE, false, Image.FORMAT_RGBA8))
	blocker.texture_region_size = Vector2i(TILE, TILE)
	blocker.create_tile(Vector2i.ZERO)
	tileset.add_source(blocker, BLOCKER_SOURCE)
	var blocker_tile := blocker.get_tile_data(Vector2i.ZERO, 0)
	blocker_tile.add_collision_polygon(0)
	blocker_tile.set_collision_polygon_points(0, 0, box)
	_blocker_set = tileset
	return tileset


## What the story leaves on a wall to be read (Letters.drawn_on, PIX-253
## step 8): Morvax's tally marks over his forge's back wall, drawn here in
## code over the wall's face. E reads them (WorldInteraction's readings).
func _add_set_pieces(data: MapData) -> void:
	for piece: Dictionary in Letters.drawn_on(data.id):
		if piece["look"] == "tally":
			var marks := TallyMarks.new()
			marks.rect = piece["rect"]
			ground.add_child(marks)


## Fifty years of tally marks scratched into a wall (PIX-253 step 8): rows of
## fives across `rect` (cells), four strokes and the fifth across them, in
## whole art pixels, dark on the plaster; the newest row runs out part-way
## (the counting isn't done).
class TallyMarks extends Node2D:
	const INK := Color(0.29, 0.2, 0.14, 0.9)
	## A stroke's height, and the room a five takes with the gap after it.
	const STROKE := 4
	const GROUP := 9
	## Each row's top, in pixels down the wall cell: on the plaster, above
	## the wall's dark foot.
	const ROWS := [1, 6]
	## How many fives the newest row has before it stops.
	const LAST_ROW_GROUPS := 7
	var rect := Rect2i()

	func _draw() -> void:
		var left := rect.position.x * TILE + 3
		var groups := int((rect.size.x * TILE - 6) / GROUP)
		for row in ROWS.size():
			var top := rect.position.y * TILE + int(ROWS[row])
			var last := row == ROWS.size() - 1
			var count := LAST_ROW_GROUPS if last else groups
			for group in count:
				var x := left + group * GROUP
				for stroke in 4:
					draw_rect(Rect2(x + stroke * 2, top, 1, STROKE), INK)
				# The fifth, across the four, a pixel a step.
				for step in 8:
					draw_rect(Rect2(x - 1 + step, top + STROKE - 1 - int(step * STROKE / 8.0), 1, 1), INK)
			if last:
				# Two strokes of the next five: still counting.
				for stroke in 2:
					draw_rect(Rect2(left + count * GROUP + stroke * 2, top, 1, STROKE), INK)
