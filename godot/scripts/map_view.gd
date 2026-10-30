class_name MapView
extends RefCounted
## areas: town rooms travel +town-age*
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
## The open ground's patches (paid pack only) and small things (PIX-305).
var patch_layer: TileMapLayer
var detail_layer: TileMapLayer
## The Ash's cinders, lit by nothing but themselves (PIX-308).
var ember_layer: TileMapLayer
## The dead trees on the burnt rock (AshLand.snag), cell -> which; and the
## workings dressing a mining country (AshLand.workings) with the cells
## their pieces take, where nothing else is drawn (PIX-308).
var snags := {}
var workings := {}
var worked := {}
## The streets' paving in the Medieval Age's stone, by the town's age, and
## the roads' wear and verges (PIX-307): the look each street takes
## (Streets.plan), what of it is paved (with the paid pack: all of it) and
## each paved cell's tile, and the layers they lie on, over the ground and
## under the cliffs standing in it.
var streets := {}
var street_tiles := {}
var _paved := {}
## The paved cells the town's traffic has worn (Streets.worn, PIX-382 step 4).
var worn_paving := {}
var _street_bands: Array[Dictionary] = []
var paving_layer: TileMapLayer
var wear_layer: TileMapLayer
var verge_layer: TileMapLayer
## Pixelheim's rampart in the Medieval Age's stone: whole, and scorched.
var _rampart_layers: Array[TileMapLayer] = []
## Every material that reads the region's masks (region_tint.gdshader), to
## hand them a neighbour's masks beside their own (set_masks).
var _toned: Array[ShaderMaterial] = []
## Houses (PunyTown) or a room (PunyInterior): {"pieces", "decor", "freed"},
## a room adding "floor", "walls", "void" and "over".
var buildings := {"pieces": {}, "decor": {}, "freed": []}
## Outdoor props (PunyProps): {"props", "flat", "drawn"}.
var outdoor_props := {"props": [], "flat": {}, "drawn": {}}
## Field decor that blocks: cell -> Puny World tile.
var solid_scatter := {}
## The cells that grow no field decor (PIX-304), as the plan settles them:
## where a prop, a camp, a shut gate or a dungeon's entrance stands, a chest
## or a pickup lies, a villager lives, or a way leads on. No tree hides a
## tent or a pickup, and no log lies under a gate.
var bare := {}
## The field decor the drawing grew (PIX-304), cell -> its Puny World tile:
## the trees, the wheat, the bushes, stumps, stones and tufts. The harness
## reports how many (decor=).
var field := {}
## The woods' pieces by cell, as worked out this session (KeptGround.woods).
var woods := {}
var ground: Node2D
var ground_tint: ShaderMaterial
## The same toning for what the wind moves (PIX-223): each tree and wheat
## sheaf leaning on its own beat (decor_sway), the forest's crowns as one
## sheet (canopy), the town's flowers (flowers_sway).
var decor_sway: ShaderMaterial
## The same, but in their own colours: the Medieval Age's trees (PIX-309).
var woods_sway: ShaderMaterial
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
## Each dungeon's way in drawn as an entrance in its setting (PIX-290,
## EntranceArt.plan): its look, pieces and the open cells they block; their
## cells' own objects (the plain mouth, the castle gate) go in gate_hides.
var entrances: Array[Dictionary] = []
## A settlement's own grammar (Hamlet, PIX-313): its houses' style
## (PunyTown.plan) and its set dressing as planned (Hamlet.plan); empty
## elsewhere.
var house_style := {}
var hamlet := {"look": "", "pieces": [], "blocks": []}
## What the Post's routes put up on the Ashenreach (PIX-322, Routes.plan):
## the signposts at their forks and the waystations built, and the cells
## they block; empty elsewhere.
var routes := {"pieces": [], "blocks": [], "open": []}
## The ash healed round the lit ember lamps (PIX-323, Lamps.healed): cell ->
## what it's drawn as (bare earth, grass, a meadow, a grove), laid over the
## ground as drawn (look); empty elsewhere.
var healed := {}
## A dungeon floor's torches on the wall (PIX-291), by cell.
var wall_torches: Array[Vector2i] = []
## How a dungeon floor is dressed as its place (DungeonLook.plan, PIX-310);
## empty on any other map.
var dressing := {}
var furniture_cells: Array[Vector2i] = []
## Night (PIX-149): each lamp's flame and its cold torch for the day, and
## the warm glows of lamps and windows; set_night shows one or the other.
var lamps: Array[Dictionary] = []
var night_glows: Array[Node2D] = []
## A room's windows full of the day, shown until night (PIX-311).
var day_glows: Array[Node2D] = []
## What lights the map for the harness's `lamplight` (PIX-311): the lit
## windows' glass, a room's candles and sconces (their halos) and the day
## through its windows (their lights).
var panes: Array[Node2D] = []
var flames: Array[Node2D] = []
var beams: Array[PointLight2D] = []
## The sun's shafts into the Deepwood's glades by day (PIX-309).
var shafts: Array[PointLight2D] = []
## The material that draws the map's ice frozen (frozen.gdshaderinc: the
## floor's in a cave, PIX-255; the ground's in the open air, PIX-398), null
## on a map with none; and the cold lights the ice gives back.
var frozen: ShaderMaterial
var ice_lights: Array[PointLight2D] = []
## The ruins burning on the Night of Ash (PIX-197): [{rect, nodes}], in
## Town.ruins' order, so the dawn can put them out one by one.
var fires: Array[Dictionary] = []
var _night := -1
## The post box on the square (PIX-320), once the Post is open; null
## elsewhere.
var post_box: Sprite2D
## The post house behind it once built (PIX-325); null elsewhere.
var post_house: Sprite2D
## Morvax's tally marks on his forge's wall (PIX-253 step 8; PIX-325 adds
## the courier's lamps); null elsewhere.
var tally_marks: TallyMarks
## The post boxes at the waystations on this map (PIX-322): each holds the
## day's post as the square's does.
var post_boxes: Array[Sprite2D] = []
## The waystations drawn on this map, by their route's place, and each one's
## ember lamp's shard alight at night (PIX-322): the harness reports them.
var waystations: Array[String] = []
var ember_lamps := {}
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
## The old stone ruins in the open (PIX-381, Ruins.plan): their walls' and
## the ground's pieces; empty on a map without any.
var ruins := {}
## The other walls standing in the open (PIX-386, StoneWalls.plan): Greyhold's
## fort, a hut's; empty on a map without any.
var stone_walls := {}
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
## What MapView draws through layers of their own (PIX-359,
## scripts/map_layers/), in drawing order: each adds its units where its
## kind stands in `planning` and `building`, and all are set for the hour.
var _layers: Dictionary[String, MapLayer] = {
	"dungeon": DungeonLayer.new(), "rooms": RoomsLayer.new(), "ground": GroundLayer.new(),
	"camps": CampsLayer.new(), "patches": PatchesLayer.new(), "props": PropsLayer.new(), "gates": GatesLayer.new(),
	"settlements": SettlementsLayer.new(), "ruins": RuinsLayer.new(),
}
## Every feature's layers (Features, PIX-361), in `_layers` too so the hour
## sets them: their units come after the core's, in the plan and in the
## drawing before the set pieces.
var _feature_layers := Features.layers()

## A street lamp at night (PIX-311): a soft halo this big round its glass,
## and its light pooled on the ground about its foot (from its cell's top
## left), reaching this far.
const LAMP_HALO := 11
const LAMP_HALO_PEAK := 0.32
const LAMP_POOL := Vector2(8, 12)
const LAMP_REACH := 72.0
## A settlement's standing dressing's foot in its cell (Hamlet, PIX-313):
## the middle of the bottom of the cell, as every prop's.
const HAMLET_FOOT := Rect2(2, 5, 12, 11)
## A lit window's light thrown on the ground below it, and the day through a
## room's window on its floor (Lights.spill, Lights.shaft), this far.
const WINDOW_SPILL := 48.0
const SUN_REACH := 64.0
## A candle's or a sconce's light in a room at night, and its halo.
const CANDLE_REACH := 46.0
const CANDLE_HALO := 6
const CANDLE_HALO_PEAK := 0.45
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
## A unit of drawing: a tile layers' physics quadrant, 16 cells square, and
## four whole rendering quadrants (LIGHT_BLOCK), laid and drawn once; the
## decor and the objects a few rows at a time; the props a handful.
const BLOCK := 16
## The field's decor two rows a unit (PIX-304): four rows of the Deepwood's
## forest are some two hundred trees, about a millisecond on the desktop and
## a few times that in the browser, past a frame's budget (Slicer); two rows
## fit it. Since its woods grow in thickets with undergrowth (PIX-309) a row
## of them is about what two were: one row a unit.
const DECOR_ROWS := 1
## The tiles whose decor is the woods' (Woods.pieces): a forest's trees, the
## ridge's pines and rocks on its rim.
const WOODED := ["forest", "mountain"]
## Each tile layer's rendering quadrant, this many cells a side (PIX-285).
## A rendering quadrant is one canvas item, and Godot lights a canvas item
## with only the first Lights.PER_ITEM lights that reach it: with quadrants
## of 16, three dozen fires reached one on the Night of Ash, and each light
## left out of one stopped at its edge, the ground lit and dark in straight
## lines. A quadrant of 8 is a quarter of the ground, and far fewer lights
## reach it (test_night_light). It divides BLOCK, so a unit of drawing
## still lays whole quadrants, each drawn once.
const LIGHT_BLOCK := 8


func _init(map_data: MapData, actor_layer: Node2D) -> void:
	data = map_data
	_actor_layer = actor_layer
	actors = actor_layer
	_layers.merge(_feature_layers)


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
	_layers["rooms"].plan(self, slices)
	# The props' plan and the camps' share one unit, as they always did.
	slices.add("plan_props", func() -> void:
		_plan_props()
		CampsLayer.plan_in(self))
	_layers["ruins"].plan(self, slices)
	_layers["gates"].plan(self, slices)
	slices.add("plan_hamlet", _plan_hamlet)
	slices.add("plan_routes", _plan_routes)
	slices.add("plan_healed", func() -> void: healed = Lamps.healed(data.grid, Lamps.now(data.id)))
	slices.add("plan_scatter", _plan_scatter)
	for layer: MapLayer in _feature_layers.values():
		layer.plan(self, slices)


## Where patches may grow, then the houses: the town's own, or the village
## far off.
func _plan_houses() -> void:
	# Where patches may grow is read before anything is drawn over the map
	# (PIX-250), so it's the same with or without the paid art; worked out
	# on the first visit this session and kept (KeptGround, PIX-269).
	patch_decks = KeptGround.decks(data)
	# Far off (the overworld) the town's block of roofs is the village, small.
	var near := data.id not in PunyTerrain.SKYLINE_MAPS
	# Beyond Pixelheim each settlement builds in its own grammar (PIX-313).
	house_style = Hamlet.house_style(data.id) if near else {}
	buildings = PunyTown.compose(data.grid, house_style) if near else {"pieces": {}, "decor": {}, "freed": []}
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
	if data.id in PunyTerrain.SKYLINE_MAPS:
		var done := Town.done_projects(GameState.settlement)
		var ruins: Array = Town.ruins(done).map(func(ruin: Dictionary) -> Rect2i: return ruin["rect"])
		skyline = KeptGround.skyline(data, done, ruins)
		if PunyTown.available():
			buildings = {"pieces": skyline["pieces"], "decor": skyline["decor"], "freed": []}
	# One wall round the village, its gatehouse where the road runs through
	# (PIX-248): the town's, or the ring round it far off.
	rampart = {}
	if data.id in Rampart.MAPS:
		rampart = Rampart.plan(data.grid, Rampart.ashen(Town.done_projects(GameState.settlement)))
	elif data.id in Rampart.GATEHOUSES:
		rampart = Rampart.plan(data.grid, false, true)
	elif not skyline.is_empty():
		rampart = skyline["rampart"]


## The pixels a piece drawn in code (RoomArt) covers among `cells` of this
## room, with the pack or without (PIX-338: a ledger lying open on its
## table, what its prompt stands over); an empty rect for none.
func drawn_in(cells: Rect2i) -> Rect2:
	var pieces: Dictionary = buildings.get("art", {}).duplicate()
	var objects: Dictionary = buildings.get("objects", {})
	for cell: Vector2i in objects:
		if objects[cell] is String and String(objects[cell]).begins_with("r:"):
			pieces[cell] = String(objects[cell]).trim_prefix("r:")
	for cell: Vector2i in pieces:
		var rect := Rect2i(cell, RoomArt.cells(pieces[cell]))
		if rect.intersects(cells):
			return Rect2(Vector2(rect.position * TILE), Vector2(rect.size * TILE))
	return Rect2()


## How a room is drawn, for the harness (PIX-318): from the paid pack, from
## the CC0 sheets (free), or not at all (none); its walls, floor and
## stairs down, counted.
func room_drawn() -> Dictionary:
	var art := "none"
	if buildings.has("floor"):
		art = "free" if buildings.get("free", false) else "paid"
	var stairs: Array = buildings.get("pieces", {}).values().filter(func(piece: Variant) -> bool:
		return (piece is int and piece == PunyInterior.STAIRWELL) or (piece is String and piece == PunyInterior.FREE_STAIRWELL))
	return {"art": art, "walls": buildings.get("walls", {}).size(), "floor": buildings.get("floor", {}).size(), "stairs": stairs.size()}


## Outdoors, Shade's props stand where the web's did (PunyProps): what they
## stand on blocks, even ground the web left open (the fountain's basin).
## The packs' camps and the town's boards, stalls and tent follow in the same
## unit (CampsLayer.plan_in).
func _plan_props() -> void:
	var outdoor := PunyTerrain.is_outdoor(data.grid)
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


## A settlement's set dressing (Hamlet, PIX-313): what stands blocks the
## open ground it takes, never where the hero arrives, a villager stands or
## any day's patches may grow.
func _plan_hamlet() -> void:
	hamlet = {"look": "", "pieces": [], "blocks": []}
	# Pixelheim's yards and square by its age (PIX-382), laid as a
	# settlement's dressing is.
	var yards := Yards.plan(data, buildings["pieces"], GameState.town_tier(), PunyTown.available()) if data.id == "town" else ([] as Array[Dictionary])
	if Hamlet.look_of(data.id) == "" and yards.is_empty():
		return
	var kept := Hamlet.kept_on(data, patch_decks)
	if not yards.is_empty():
		kept.merge(Yards.kept(data))
	kept[arrival] = true
	# What its hub has grown as its post road filled (PIX-324).
	var grown := Hubs.dressing(data.id, GameState.post)
	grown.append_array(yards)
	hamlet = Hamlet.plan(data, kept, grown)
	for cell: Vector2i in hamlet["blocks"]:
		data.covered[cell] = true


## What the Post's routes put up on the Ashenreach (PIX-322): the signposts
## at the forks of the roads that have carried enough, and the waystations
## built, beside the road on open ground (Routes.plan: never a road, a way
## in, a gate, a pack's home or where the hero arrives). What they stand on
## blocks, and grows no patch: a day's patch dealt under one is left out.
func _plan_routes() -> void:
	routes = {"pieces": [], "blocks": [], "open": []}
	if data.id != Routes.MAP:
		return
	var kept := Hamlet.kept_on(data, {})
	kept[arrival] = true
	routes = Routes.plan(data, GameState.post, GameState.settlement, kept)
	for cell: Vector2i in routes["blocks"]:
		data.covered[cell] = true
		patches.erase(cell)


## Where the hero arrives (the spawn when the arrival is covered now), the
## cells left bare, and the field decor that blocks, kept off both.
func _plan_scatter() -> void:
	if not data.is_walkable(arrival):
		arrival = data.spawn
	bare = _bare_cells()
	solid_scatter = _solid_scatter(data, arrival)
	for cell: Vector2i in solid_scatter:
		data.covered[cell] = true
	# A mining country's workings (PIX-308), clear of all that, the blocking
	# scatter too: they block nothing.
	workings = AshLand.workings(data, bare.merged(solid_scatter), PunyProps.available())
	worked = {}
	for piece: Dictionary in workings["pieces"]:
		worked[piece["cell"]] = true


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
## few rows at a time, then the rest. The plan has run, and the units are
## counted from what it settled (the map's size, its props), never from what
## an earlier unit fills: the field's decor, counted from a list the first
## unit filled, came to no unit at all and no map grew a tree (PIX-304).
func building(root: Node, slices: Slicer) -> void:
	slices.add("ground_setup", _setup.bind(root))
	# The ground's slot: a dungeon's, a room's or the open air's, each layer
	# adding its units only on its own kind of map.
	_layers["dungeon"].build(self, slices)
	_layers["rooms"].build(self, slices)
	_layers["ground"].build(self, slices)
	slices.add("blockers_setup", _blockers_setup)
	slices.add_each("blockers_rows", ceili(data.size.y / float(BLOCK)), _blocker_rows)
	_layers["ruins"].build(self, slices)
	slices.add("signs", func() -> void:
		props = _build_props(data)
		under.add_child(props)
		# A dungeon's ways straight out, once its boss is down: lit (PIX-292).
		for cell: Vector2i in Depths.exits(data):
			light_way_out(cell))
	_decor_units(slices)
	for layer: MapLayer in _feature_layers.values():
		layer.build(self, slices)
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


## A tile layer of `tile_set`, drawn in rendering quadrants of LIGHT_BLOCK
## cells: every tile layer a drawing makes.
static func tile_layer_of(tile_set: TileSet) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.tile_set = tile_set
	layer.rendering_quadrant_size = LIGHT_BLOCK
	return layer


## The ground as drawn: the map's, but for the village far off (PIX-248),
## whose streets, river and ash lie where its block's cells are, and the
## ash healed round the lamps (PIX-323).
func look() -> Dictionary:
	var drawn: Dictionary = data.grid.merged(skyline["ground"], true) if not skyline.is_empty() else data.grid
	return drawn.merged(healed, true) if not healed.is_empty() else drawn


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
		set_masks(kept.tint_map, kept.water_map, Vector2.ZERO, Vector2(data.size * TILE), kept.crown_map)


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
	var root := GroundLayer._build_ground(self, data)
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


## The dark under a room or a dungeon, on past the map's edges (DARK_PAD).
static func _dark_beyond(data: MapData) -> ColorRect:
	var dark := ColorRect.new()
	dark.color = DARK
	dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dark.position = -Vector2.ONE * DARK_PAD * TILE
	dark.size = Vector2(data.size * TILE) + Vector2.ONE * DARK_PAD * TILE * 2
	return dark


## A cell opened while the hero looks on (PIX-255: the shortcut's door once
## the dungeon's boss is down): drawn again as it stands now, and its
## invisible box gone once it's open ground.
func reopen(cell: Vector2i) -> void:
	if dungeon_objects != null and data.pieces.has(cell):
		PunyDungeon.sheet().place(dungeon_objects, cell, int(data.pieces[cell]))
	if data.is_walkable(cell):
		tile_layer.erase_cell(cell)


## A way straight out of a dungeon's bottom floor, lit and signed
## (DungeonLayer).
func light_way_out(cell: Vector2i) -> void:
	DungeonLayer.light_way_out(self, cell)


## A way out's plate as the hero comes near (DungeonLayer).
func sign_way_out(cell: Vector2i) -> void:
	DungeonLayer.sign_way_out(self, cell)


## Chests and terrain decor live in the y-sorted actors layer: units of the
## drawing, in order - the camps, the town's ruins, the patches, the lit
## windows and hearths, the chests, the props a handful at a time, the
## gates, then the field's decor a few rows at a time.
func _decor_units(slices: Slicer) -> void:
	_layers["camps"].build(self, slices)
	_layers["patches"].build(self, slices)
	slices.add("decor_lights", _decor_lights)
	slices.add("decor_shafts", _decor_shafts)
	slices.add("decor_chests", _decor_chests)
	_layers["props"].build(self, slices)
	_layers["gates"].build(self, slices)
	_layers["settlements"].build(self, slices)
	slices.add_each("decor_field", ceili(data.size.y / float(DECOR_ROWS)), _field_rows)


## The field decor of DECOR_ROWS rows from the `i`-th band down.
func _field_rows(i: int) -> void:
	if i == 0:
		woods = KeptGround.woods(data)
	for y in range(i * DECOR_ROWS, mini((i + 1) * DECOR_ROWS, data.size.y)):
		for x in data.size.x:
			_add_field_decor(Vector2i(x, y))


## Lit windows at night, smoke from every finished house (PIX-149). A
## room's windows are in its walls. The village far off has its own.
func _decor_lights() -> void:
	if buildings.get("free", false):
		_free_room_lights()
		return
	var built: Dictionary = buildings.get("walls", {}).merged(buildings["pieces"], true)
	var room := buildings.has("floor")
	for cell: Vector2i in built:
		var tile: int = built[cell]
		if tile == PunyTown.WINDOW and room:
			# The day comes in through a room's window and lies on the floor
			# below it, slanting (PIX-311); its glass is full of the sky
			# (_build_room).
			var beam := Lights.daylight(Vector2(cell * TILE) + Vector2(TILE / 2.0, TILE), SUN_REACH, Lights.SUN, Lights.SUN_ENERGY, Lights.shaft())
			props.add_child(beam)
			beams.append(beam)
		elif tile == PunyTown.WINDOW:
			_add_lit_window(cell, not skyline.is_empty())
		elif tile in PunyInterior.FIRE_TILES:
			# A hearth or a forge warms the room it's in, and embers rise off
			# it (PIX-225).
			_add_hearth(center(cell) + Vector2(TILE / 2.0, 4), center(cell) + Vector2(TILE / 2.0, 6))
		elif tile == PunyTown.DOOR and skyline.is_empty():
			SettlementsLayer._add_chimney_smoke(self, cell)
	# A room's candles and sconces burn at night, each warming the floor
	# round it, the corners left dark (PIX-311).
	for part: String in ["objects", "tops", "lifted"]:
		var pieces: Dictionary = buildings.get(part, {})
		for cell: Vector2i in pieces:
			if PunyInterior.FLAMES.has(pieces[cell]):
				_add_candle(Vector2(cell * TILE) + PunyInterior.FLAMES[pieces[cell]] - Vector2(0, 6 if part == "lifted" else 0))
	if not skyline.is_empty():
		SettlementsLayer._add_village_life(self)


## A CC0 room's light (PIX-318), by the rules a room keeps with the pack
## (PIX-311): the day through each window, slanting onto the floor below
## it; a hearth's or a forge's fire, from its mouth; and at night its
## sconces and lanterns, each warming the floor round it, a lantern's glass
## lit.
func _free_room_lights() -> void:
	for cell: Vector2i in buildings.get("windows", []):
		var beam := Lights.daylight(Vector2(cell * TILE) + Vector2(TILE / 2.0, TILE), SUN_REACH, Lights.SUN, Lights.SUN_ENERGY, Lights.shaft())
		props.add_child(beam)
		beams.append(beam)
	for cell: Vector2i in buildings.get("fires", []):
		_add_hearth(center(cell) + Vector2(0, 4), Vector2(cell * TILE) + HamletArt.STACK_MOUTH)
	for at: Vector2 in buildings.get("flames", []):
		_add_candle(at)
	var objects: Dictionary = buildings.get("objects", {})
	for cell: Vector2i in objects:
		if objects[cell] == "h:lantern":
			var lit := Sprite2D.new()
			lit.texture = HamletArt.texture("lantern_lit")
			lit.centered = false
			lit.material = Lights.unshaded()
			lit.position = Vector2(cell * TILE)
			lit.visible = false
			props.add_child(lit)
			night_glows.append(lit)


## A hearth's or a forge's fire (PIX-225): its warmth on the room, its
## light from `at`, and embers rising off it at `embers_at`.
func _add_hearth(at: Vector2, embers_at: Vector2) -> void:
	props.add_child(Lights.make(at, 96.0, Lights.FIRE, Lights.FIRE_ENERGY, true))
	var embers := _still(Motes.make_embers())
	embers.position = embers_at
	embers.z_index = 6
	props.add_child(embers)


## A candle's or a sconce's flame at `at` (PIX-311): lit at night, a halo
## round it and its light on the floor round it.
func _add_candle(at: Vector2) -> void:
	var halo := _add_halo(at, CANDLE_HALO, CANDLE_HALO_PEAK)
	var light := Lights.make(at + Vector2(0, TILE / 2.0), CANDLE_REACH, Lights.CANDLE, Lights.CANDLE_ENERGY, true)
	props.add_child(light)
	halo.set_meta("light", light)
	flames.append(halo)


## A window lit at night (PIX-311: it was a round orb on the wall): its own
## glass lit amber (LampArt.panes), the dark untouched; and near, its light
## thrown on the ground below it in the window's shape (Lights.spill). Far
## off (the village from the Reach) the lit glass alone: its lamps light its
## streets, and a light for every window crowded the ground's blocks.
func _add_lit_window(cell: Vector2i, far: bool) -> void:
	var glass := LampArt.panes()
	if glass == null:
		return
	var pane := Sprite2D.new()
	pane.texture = glass
	pane.centered = false
	pane.position = Vector2(cell * TILE)
	pane.material = Lights.unshaded()
	pane.add_to_group("decor")
	props.add_child(pane)
	night_glows.append(pane)
	panes.append(pane)
	if far:
		return
	var light := Lights.make(Vector2(cell * TILE) + Vector2(TILE / 2.0, TILE), WINDOW_SPILL, Lights.WINDOW, Lights.WINDOW_ENERGY, false, Lights.spill())
	props.add_child(light)
	pane.set_meta("light", light)


## The chests and the treasure on the ground, as they stand.
func _decor_chests() -> void:
	chest_sprites = {}
	for chest: Dictionary in Interactables.chests_on(data.id):
		var texture := treasure_texture(chest, GameState.spoils.is_opened(chest))
		if texture == null:
			continue
		var cell := Vector2i(int(chest["x"]), int(chest["y"]))
		if chest["look"] != "chest":
			# A pouch on the road, herbs in the grass: picked up, the size
			# of what lies about (PIX-286).
			var lying := PatchesLayer.pickup(texture, cell)
			actors.add_child(lying)
			chest_sprites[chest["id"]] = lying
			continue
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.position = center(cell)
		sprite.add_to_group("decor")
		actors.add_child(sprite)
		chest_sprites[chest["id"]] = sprite
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
	if bare.has(cell) or worked.has(cell):
		return
	var choice := Scatter.choice(data.grid, cell)
	# Burnt rock grows dead trees, not pines; its boulders stay (PIX-308).
	if kept != null and kept.burnt.has(cell) and choice != AshLand.BOULDER:
		var snag := AshLand.snag(data.grid, cell)
		if snag >= 0:
			snags[cell] = snag
			var h := absi(hash(cell))
			var sprite := Sprite2D.new()
			sprite.texture = AshArt.texture("snag_%d" % snag)
			sprite.position = center(cell) + Vector2((h >> 12) % 7 - 3, (h >> 16) % 5 - 2)
			sprite.offset = Vector2(0, -AshArt.SNAG_HEIGHT / 2.0 + 6)
			sprite.flip_h = (h >> 20) % 2 == 1
			sprite.add_to_group("decor")
			actors.add_child(sprite)
		return
	if choice < 0:
		return
	field[cell] = choice
	if solid_scatter.has(cell):
		_add_solid_decor(choice, cell)
	elif _is_flat_decor(cell, choice):
		ground.add_child(_flat_decor(cell, choice))
	elif data.grid[cell] in WOODED:
		# The woods in clumps, and the ridge's rim (Woods, PIX-309), worked
		# out once a session (PIX-360).
		if not woods.has(cell):
			woods[cell] = Woods.pieces(data.grid[cell], cell, choice, Woods.look_at(data, cell), PunyTown.available())
		for piece: Dictionary in woods[cell]:
			_add_wood(piece, cell)
	else:
		_add_decor_sprite(PunyTerrain.SHEET, PunyTerrain.region(choice), cell, absi(hash(cell)))
		actors.get_child(-1).material = decor_sway if choice in Scatter.SWAYS else ground_tint


## A tree, a bush or a rock of the woods (Woods.pieces), its foot where the
## piece says in `cell`, among the actors: leaning in the wind on its own
## beat, in its own colours when it's the Medieval Age's (the region's tone
## would grey its greens and whiten its snow's blue away).
func _add_wood(piece: Dictionary, cell: Vector2i) -> void:
	var rect: Rect2 = piece["rect"]
	var sprite := Sprite2D.new()
	sprite.texture = _cut(piece["sheet"], rect)
	sprite.position = Vector2(cell * TILE) + piece["foot"]
	sprite.offset = Vector2(0, -rect.size.y / 2.0)
	sprite.material = woods_sway if piece["own"] else decor_sway
	sprite.add_to_group("decor")
	actors.add_child(sprite)


## The sun through the canopy's edge into the Deepwood's glades by day
## (PIX-309, Woods.shafts), gone at night with the day.
func _decor_shafts() -> void:
	shafts = []
	for cell: Vector2i in Woods.shafts(data):
		var shaft := Lights.daylight(Vector2(cell * TILE) + Vector2(TILE / 4.0, 0), Woods.SHAFT_REACH, Lights.SUN, Woods.SHAFT_ENERGY, Lights.shaft())
		props.add_child(shaft)
		shafts.append(shaft)


## A drawing's motes rise in its own space (One Reach, PIX-269): handed
## over at a line, the drawing moves under them, and what was already in the
## air moves with it. They never move otherwise, so they look the same.
static func _still(motes: CPUParticles2D) -> CPUParticles2D:
	motes.local_coords = true
	return motes


## The cells that grow no field decor (`bare`): what the props stand on,
## the camps, each shut gate's cells and pieces, each entrance's pieces and
## the cells it blocks or hides, the chests and pickups, the villagers' homes
## and the ways on; and what the Post's roads put up, and where a waystation
## sets the hero down (PIX-322).
func _bare_cells() -> Dictionary:
	var out: Dictionary = (outdoor_props["drawn"] as Dictionary).duplicate()
	var cells: Array = camps.keys() + data.portals.keys() + gate_hides.keys()
	for gate: Dictionary in gates:
		cells.append_array(Gates.cells_of(gate))
		for piece: Dictionary in GateArt.plan(gate, PunyProps.available())["pieces"]:
			cells.append(piece["cell"])
	for entrance: Dictionary in entrances:
		cells.append_array(entrance["blocks"])
		for piece: Dictionary in entrance["pieces"]:
			cells.append(piece["cell"])
	for chest: Dictionary in Interactables.chests_on(data.id):
		cells.append(Vector2i(int(chest["x"]), int(chest["y"])))
	for piece: Dictionary in hamlet["pieces"]:
		cells.append_array(piece["cells"])
	cells.append_array(routes["blocks"] + routes["open"])
	for npc: Dictionary in Npcs.on_map(data.id, GameState.settlement.town_tier, GameState.settlement.settlers, Town.done_projects(GameState.settlement), Relics.gate_open(GameState.progression), Letters.tin_waits(GameState.progression)):
		cells.append(Vector2i(int(npc["x"]), int(npc["y"])))
	for cell: Vector2i in cells:
		out[cell] = true
	return out


## Field decor that blocks (Scatter.solid), kept off the cell the hero
## arrives on, today's patches, the packs' homes and the cells left bare.
func _solid_scatter(data: MapData, arrival: Vector2i) -> Dictionary:
	if not PunyTerrain.is_outdoor(data.grid):
		return {}
	var kept := {arrival: true}
	for cell: Vector2i in patches:
		kept[cell] = true
	# A pack's home and the cells around it stay open for the pack.
	for spawn: Dictionary in Bestiary.spawns_on(data.id):
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				kept[Vector2i(spawn["x"] + dx, spawn["y"] + dy)] = true
	return Scatter.solid(data, kept, bare)


## A roof set burning on the Night of Bells: its index in `fires`, for
## douse (CampsLayer).
func burn(rect: Rect2i) -> int:
	return CampsLayer.burn(self, rect)


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


## The fire on ruin `ruin`, if it still burns, put out (CampsLayer).
func douse_ruin(ruin: int, seconds := 1.2) -> void:
	CampsLayer.douse_ruin(self, ruin, seconds)


## The fire on one burning ruin gutters out over `seconds` (CampsLayer).
func douse(index: int, seconds := 1.2) -> void:
	CampsLayer.douse(self, index, seconds)


static var _halo_textures := {}
## A halo's warmth; a lamp of another kind's colour tints its own (PIX-324).
const HALO_TINT := Color(1.0, 0.72, 0.38)


## A soft halo round a small flame (PIX-311): smooth to nothing at its rim,
## not a disc of steps, added onto the night and shown only then; the glow
## pass blooms the flame itself.
func _add_halo(at: Vector2, radius: int, peak: float, tint := HALO_TINT) -> Sprite2D:
	var key := "%d:%f:%s" % [radius, peak, tint.to_html()]
	if not _halo_textures.has(key):
		var size := radius * 2
		var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
		for y in size:
			for x in size:
				var d := Vector2(x + 0.5 - radius, y + 0.5 - radius).length() / radius
				if d < 1.0:
					image.set_pixel(x, y, Color(tint, peak * pow(1.0 - d, 2.2)))
		_halo_textures[key] = ImageTexture.create_from_image(image)
	var halo := Sprite2D.new()
	halo.texture = _halo_textures[key]
	halo.material = Lights.glow()
	halo.position = at
	halo.z_index = 5
	halo.add_to_group("decor")
	props.add_child(halo)
	night_glows.append(halo)
	return halo


## Lamps and windows for the hour: lit from dusk's end to dawn, cold by day;
## a room's windows full of the day until then (PIX-311).
func set_night(night: bool) -> void:
	if int(night) == _night:
		return
	_night = int(night)
	for glow in night_glows:
		if is_instance_valid(glow):
			glow.visible = night
	for pane in day_glows:
		if is_instance_valid(pane):
			pane.visible = not night
	# After the glows, so a layer may keep one dark (PIX-362: Lantern
	# Night's lamps waiting for Fafnyr).
	for layer: MapLayer in _layers.values():
		layer.set_night(self, night)


## Deals day `day`'s wild patches, unless they're dealt already; whether
## they changed (PatchesLayer).
func deal_patches(day: int) -> bool:
	return PatchesLayer.deal_patches(self, day)


## Patches grown back show again, a new day's grow elsewhere (PatchesLayer).
func refresh_patches() -> void:
	PatchesLayer.refresh_patches(self)


## The post boxes drawn as they stand, full or empty (PatchesLayer).
func show_post_box() -> void:
	PatchesLayer.show_post_box(self)


## A tent pitched on the map as it stands, its cell blocked (CampsLayer).
func pitch_tent(cell: Vector2i) -> void:
	CampsLayer.pitch_tent(self, cell)


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


## Placed furniture in the house (PropsLayer).
func furnish() -> void:
	PropsLayer.furnish(self)


## What the cells add to Shade's layers (ground, houses, rooms, props,
## dungeons draw everything else): an invisible box on every unwalkable cell
## (a prop's own body stands in for its cells), and outdoors the stone floor
## of the ruins, in his dungeon stone, under whatever stands on it. The
## layer, then a band of rows a unit (a band of its physics quadrants).
func _blockers_setup() -> void:
	tile_layer = tile_layer_of(_blockers())
	under.add_child(tile_layer)


func _blocker_rows(i: int) -> void:
	var ruins := PunyTerrain.is_outdoor(data.grid)
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
				# Plain stone with the odd worn slab, as a dungeon's floor
				# (PIX-381).
				var slab := PunyDungeon.floor_tile(cell)
				tile_layer.set_cell(cell, STONE_SOURCE, Vector2i(slab % PunyDungeon.COLUMNS, slab / PunyDungeon.COLUMNS) - STONE_BLOCK.position)
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
## The block of Shade's dungeon sheet the ruins' floor slabs come from
## (PunyDungeon.FLOORS), in tiles.
const STONE_BLOCK := Rect2i(4, 0, 4, 4)


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
	var sheet: Image = (load(PunyDungeon.SHEET) as Texture2D).get_image()
	stone.texture = ImageTexture.create_from_image(sheet.get_region(Rect2i(STONE_BLOCK.position * TILE, STONE_BLOCK.size * TILE)))
	stone.texture_region_size = Vector2i(TILE, TILE)
	for y in STONE_BLOCK.size.y:
		for x in STONE_BLOCK.size.x:
			stone.create_tile(Vector2i(x, y))
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
			tally_marks = TallyMarks.new()
			tally_marks.rect = piece["rect"]
			# A red stroke for each of the courier's ember lamps (PIX-325).
			tally_marks.fresh = Routes.lamps(GameState.settlement).size()
			ground.add_child(tally_marks)


## Fifty years of tally marks scratched into a wall (PIX-253 step 8): rows of
## fives across `rect` (cells), four strokes and the fifth across them, in
## whole art pixels, dark on the plaster; the newest row runs out part-way
## (the counting isn't done), then a red stroke for each of the courier's
## lamps (`fresh`, PIX-325), in fives too.
class TallyMarks extends Node2D:
	const INK := Color(0.29, 0.2, 0.14, 0.9)
	const FRESH := Color(0.75, 0.27, 0.23, 0.95)
	var fresh := 0
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
				_five(left + group * GROUP, top, 5, INK)
			if last:
				# Two strokes of the next five: still counting.
				_five(left + count * GROUP, top, 2, INK)
				# As many as the wall has room for: "I've started on the door."
				for group in mini(ceili(fresh / 5.0), groups - count - 1):
					_five(left + (count + 1 + group) * GROUP, top, mini(fresh - group * 5, 5), FRESH)

	## `strokes` of a five at `x`: up to four upright, the fifth across them,
	## a pixel a step.
	func _five(x: int, top: int, strokes: int, ink: Color) -> void:
		for stroke in mini(strokes, 4):
			draw_rect(Rect2(x + stroke * 2, top, 1, STROKE), ink)
		if strokes == 5:
			for step in 8:
				draw_rect(Rect2(x - 1 + step, top + STROKE - 1 - int(step * STROKE / 8.0), 1, 1), ink)
