class_name MapView
extends RefCounted
## One visit to a map, as drawn (PIX-136): Shade's ground, houses, rooms and
## dungeons, the props, field scatter, chests and door signs, the house's
## placed furniture, and the invisible boxes on what the hero can't walk
## into. Planning it also tells the map what all that covers (house corners,
## prop feet, blocking scatter, chests), so the grid, the villagers and the
## monsters agree with the art. world.gd keeps the play: the actors,
## interaction, combat and music; standing things go into its y-sorted
## `actors` layer, everything else into the three layers `build` adds.

const TILE := 16

var data: MapData
## The world's y-sorted layer: the hero, villagers, monsters and whatever
## they walk behind or in front of.
var actors: Node2D
## Houses (PunyTown) or a room (PunyInterior): {"pieces", "decor", "freed"},
## a room adding "floor", "void" and "over".
var buildings := {"pieces": {}, "decor": {}, "freed": []}
## Outdoor props (PunyProps): {"props", "flat", "drawn"}.
var outdoor_props := {"props": [], "flat": {}, "drawn": {}}
## Field decor that blocks: cell -> Puny World tile.
var solid_scatter := {}
var ground: Node2D
var ground_tint: ShaderMaterial
var tile_layer: TileMapLayer
## Door signs, above the world and outside the y-sort.
var props: Node2D
## A dungeon floor's torches, barrels and stairs (a cleared floor adds stairs down).
var dungeon_objects: TileMapLayer
## Chest id -> its sprite, to open or take it.
var chest_sprites := {}
## The door signs: {door, name, about}, for the nameplate.
var door_signs: Array = []
var furniture_cells: Array[Vector2i] = []
## Gathering patches (PIX-143): cell -> {"id", "item"}, and each one's sprite.
var patches := {}
var patch_sprites := {}
## Each wild pack's camp (PIX-142): cell -> {"kind": "tent"|"torch", "tile"},
## a tent in its region's colour behind its home and a torch beside it.
var camps := {}

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


func _init(map_data: MapData, actor_layer: Node2D) -> void:
	data = map_data
	actors = actor_layer


## A cell's centre in map pixels.
static func center(cell: Vector2i) -> Vector2:
	return Vector2(cell * TILE) + Vector2(TILE, TILE) / 2.0


## Decides what stands where and marks it on the map, before anything is
## drawn; returns where the hero arrives (the map's spawn when `arrival` is
## now covered).
func plan(arrival: Vector2i) -> Vector2i:
	# Far off (the overworld's skyline) a town stays one Puny house icon.
	var near := data.floor_level == 0 and data.id not in PunyTerrain.SKYLINE_MAPS
	buildings = PunyTown.compose(data.grid) if near else {"pieces": {}, "decor": {}, "freed": []}
	# What a house covers is house: its corners stop the hero and villagers
	# too; the roof cells it leaves open are ground.
	for cell: Vector2i in buildings["pieces"]:
		if not String(data.grid.get(cell, "")).begins_with("door"):
			data.grid[cell] = "roof"
	for cell: Vector2i in buildings["freed"]:
		data.grid[cell] = "grass"
	# Inside, Shade's rooms (PunyInterior): furniture spreading onto the floor
	# blocks it, like the rest of the furniture.
	if PunyTown.available() and PunyInterior.is_room(data.id):
		var room: Dictionary = PunyInterior.plan(data.id, data.grid)
		buildings = {"pieces": room["pieces"], "decor": {}, "freed": [], "floor": room["floor"], "void": room["void"], "over": room["over"]}
		for cell: Vector2i in room["blocked"]:
			data.grid[cell] = "wall"
	# Outdoors, Shade's props stand where the web's did (PunyProps): what they
	# stand on blocks, even ground the web left open (the fountain's basin).
	var outdoor := data.floor_level == 0 and PunyTerrain.is_outdoor(data.grid)
	outdoor_props = PunyProps.compose(data.grid) if outdoor else {"props": [], "flat": {}, "drawn": {}}
	data.covered = {}
	for prop: Dictionary in outdoor_props["props"]:
		if (prop["foot"] as Rect2).has_area():
			for cell: Vector2i in prop["covers"]:
				data.covered[cell] = true
	camps = plan_camps(data)
	if data.id == "town":
		camps[Town.project_board()] = {"kind": "board", "tile": PROJECT_BOARD}
		# Sela's tent on the square while the inn is rubble (PIX-146).
		var tent := Town.ashes_tent(Town.done_projects(GameState.settlement))
		if tent.x >= 0:
			camps[tent] = {"kind": "tent", "tile": TENTS["marsh"]}
	for cell: Vector2i in camps:
		data.covered[cell] = true
	patches = {}
	if data.floor_level == 0:
		for spot: Dictionary in Gathering.spots_on(data.id):
			var at := Vector2i(spot["x"], spot["y"])
			patches[at] = {"id": spot["id"], "item": Gathering.material_at(data, at)}
	if not data.is_walkable(arrival):
		arrival = data.spawn
	solid_scatter = _solid_scatter(data, arrival)
	for cell: Vector2i in solid_scatter:
		data.covered[cell] = true
	return arrival


## Draws the map: its ground, the blockers and door signs as the first three
## children of `root` (behind the actors layer), then what stands among the
## actors, then the house's furniture.
func build(root: Node) -> void:
	ground = _build_dungeon(data) if data.floor_level > 0 else _build_ground(data)
	tile_layer = _build_tile_layer(data)
	props = _build_props(data)
	for layer: Node in [props, tile_layer, ground]:
		root.add_child(layer)
		root.move_child(layer, 0)
	_build_decor(data)
	furnish()


## Takes the drawing down (what stands among the actors is in the "decor"
## group, which the world clears with its monsters).
func clear() -> void:
	for layer: Node in [ground, tile_layer, props]:
		if layer != null:
			layer.queue_free()


## The ground in Shade's Puny World tiles (PunyTerrain): grass, roads, sand,
## cliffs and rippling water on the dual grid, half a tile up-left of the
## cells so every terrain edge sits on a cell edge.
func _build_ground(data: MapData) -> Node2D:
	if buildings.has("floor"):
		return _build_room(data)
	var root := Node2D.new()
	var layer := TileMapLayer.new()
	layer.tile_set = PunyTerrain.tileset()
	layer.position = Vector2(-TILE, -TILE) / 2.0
	var tiles := PunyTerrain.ground_tiles(data.grid, data.size)
	for cell: Vector2i in tiles:
		PunyTerrain.place(layer, cell, tiles[cell])
	# Ash and mire are toned from Shade's dirt and grass, decor included.
	ground_tint = ShaderMaterial.new()
	ground_tint.shader = preload("res://shaders/region_tint.gdshader")
	ground_tint.set_shader_parameter("tint_map", PunyTerrain.tint_map(data.grid, data.size))
	ground_tint.set_shader_parameter("map_pixels", Vector2(data.size * TILE))
	layer.material = ground_tint
	root.add_child(layer)
	var forest := TileMapLayer.new()
	forest.tile_set = PunyTerrain.tileset()
	forest.position = layer.position
	var crowns := PunyTerrain.forest_tiles(data.grid, data.size)
	for cell: Vector2i in crowns:
		PunyTerrain.place(forest, cell, crowns[cell])
	root.add_child(forest)
	# Bridges, cave mouths, ramparts and (seen from afar) whole towns stand on
	# that ground as Puny objects.
	var objects := TileMapLayer.new()
	objects.tile_set = PunyTerrain.tileset()
	var outdoor := PunyTerrain.is_outdoor(data.grid)
	for cell: Vector2i in data.grid:
		var object := PunyTerrain.object_at(data.grid, cell)
		if outdoor and object < 0:
			object = PunyTerrain.wall_piece(data.grid, cell)
		if object >= 0:
			PunyTerrain.place(objects, cell, object)
	if data.id in PunyTerrain.SKYLINE_MAPS:
		var skyline := PunyTerrain.skyline(data.grid)
		for cell: Vector2i in skyline:
			PunyTerrain.place(objects, cell, skyline[cell])
	root.add_child(objects)
	# Shade's flowers, flat on the ground (the hero walks through them).
	if not outdoor_props["flat"].is_empty():
		var flowers := TileMapLayer.new()
		flowers.tile_set = PunyTown.tileset()
		for cell: Vector2i in outdoor_props["flat"]:
			PunyTown.place(flowers, cell, outdoor_props["flat"][cell])
		root.add_child(flowers)
	# The houses, then what stands on their roofs (chimneys).
	for part: String in ["pieces", "decor"]:
		if buildings[part].is_empty():
			continue
		var houses := TileMapLayer.new()
		houses.tile_set = PunyTown.tileset()
		for cell: Vector2i in buildings[part]:
			PunyTown.place(houses, cell, buildings[part][cell])
		root.add_child(houses)
	return root


## A room in Shade's Medieval Age pack (PunyInterior): the dark beyond its
## walls, the floor and rug, then walls, door and furniture.
func _build_room(data: MapData) -> Node2D:
	var root := Node2D.new()
	var dark := ColorRect.new()
	dark.color = Color("0b0a0e")
	dark.size = Vector2(data.size * TILE)
	root.add_child(dark)
	for part: String in ["floor", "pieces"]:
		var layer := TileMapLayer.new()
		layer.tile_set = PunyTown.tileset()
		for cell: Vector2i in buildings[part]:
			PunyTown.place(layer, cell, buildings[part][cell])
		root.add_child(layer)
	return root


## A dungeon floor in Shade's Puny Dungeon: stone, walls by his grammar and
## the dark beyond, torches flickering on their blocks, barrels, pots and the
## stairs up.
func _build_dungeon(data: MapData) -> Node2D:
	var root := Node2D.new()
	var dungeon := PunyDungeon.sheet()
	var layer := TileMapLayer.new()
	layer.tile_set = dungeon.tileset
	dungeon_objects = TileMapLayer.new()
	dungeon_objects.tile_set = dungeon.tileset
	for cell: Vector2i in data.grid:
		var tile: String = data.grid[cell]
		match tile:
			"wall":
				dungeon.place(layer, cell, PunyDungeon.wall_tile(data.grid, cell))
				continue
			"lamp":
				dungeon.place(layer, cell, PunyDungeon.TORCH_BLOCK)
				dungeon.place(dungeon_objects, cell, PunyDungeon.TORCH)
				continue
		dungeon.place(layer, cell, PunyDungeon.floor_tile(cell))
		match tile:
			"barrel":
				dungeon.place(dungeon_objects, cell, PunyDungeon.BARRELS[absi(hash(cell)) % 2])
			"crate":
				dungeon.place(dungeon_objects, cell, PunyDungeon.POT)
			"cave":
				dungeon.place(dungeon_objects, cell, PunyDungeon.STAIRS)
	root.add_child(layer)
	root.add_child(dungeon_objects)
	return root


## Chests and terrain decor live in the y-sorted actors layer.
func _build_decor(data: MapData) -> void:
	for cell: Vector2i in camps:
		_add_camp_piece(cell, camps[cell])
	if data.id == "town":
		for ruin: Dictionary in Town.ruins(Town.done_projects(GameState.settlement)):
			_add_smoke(ruin["rect"])
	patch_sprites = {}
	for cell: Vector2i in patches:
		_add_patch_sprite(cell)
	chest_sprites = {}
	for chest: Dictionary in Interactables.chests_on(data.id):
		var texture := treasure_texture(chest, GameState.is_opened(chest))
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
	for prop: Dictionary in outdoor_props["props"]:
		_add_puny_prop(prop)
	for cell: Vector2i in data.grid:
		var choice := Scatter.choice(data.grid, cell)
		if choice < 0 or outdoor_props["drawn"].has(cell):
			continue
		var h := absi(hash(cell))
		if solid_scatter.has(cell):
			_add_solid_decor(choice, cell)
		elif choice in Scatter.FLAT and data.grid[cell] != "forest":
			# Flat on the ground: the hero steps over it.
			var flat := Sprite2D.new()
			flat.texture = PunyTerrain.sheet().tile_texture(choice)
			flat.position = center(cell) + Vector2((h >> 12) % 7 - 3, (h >> 16) % 5 - 2)
			flat.material = ground_tint
			flat.add_to_group("decor")
			ground.add_child(flat)
		else:
			_add_decor_sprite(PunyTerrain.SHEET, PunyTerrain.region(choice), cell, h)
			actors.get_child(-1).material = ground_tint


## Field decor that blocks (Scatter.solid), kept off the cell the hero
## arrives on, villagers' homes and chests.
func _solid_scatter(data: MapData, arrival: Vector2i) -> Dictionary:
	if data.floor_level > 0 or not PunyTerrain.is_outdoor(data.grid):
		return {}
	var kept := {arrival: true}
	for npc: Dictionary in Npcs.on_map(data.id, GameState.settlement.town_tier, GameState.settlement.settlers, Town.done_projects(GameState.settlement)):
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
static func plan_camps(map: MapData) -> Dictionary:
	var out := {}
	if map.floor_level > 0:
		return out
	for spawn: Dictionary in Bestiary.spawns_on(map.id):
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


## Smoke and embers over a burnt house (PIX-146): pixel motes drifting up
## from its footing, the embers quicker and fewer. Still with Reduce motion.
func _add_smoke(rect: Rect2i) -> void:
	if GameState.settings.reduce_motion:
		return
	var middle := Vector2(rect.position * TILE) + Vector2(rect.size * TILE) / 2.0
	var extents := Vector2(rect.size * TILE) / 2.0 - Vector2(10, 10)
	for ember in [false, true]:
		var motes := CPUParticles2D.new()
		motes.position = middle
		motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		motes.emission_rect_extents = extents
		motes.amount = 4 if ember else 12
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


## Patches that have grown back show again.
func refresh_patches() -> void:
	for spot_id: String in patch_sprites:
		patch_sprites[spot_id].visible = Gathering.is_ready(GameState.world, spot_id)


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
	sprite.material = ground_tint
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
				var flame := AnimatedSprite2D.new()
				flame.sprite_frames = PunyProps.animation(prop["frames"], PunyProps.LAMP_FPS)
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
	return root


func _add_decor_sprite(texture_path: String, region: Rect2, cell: Vector2i, h: int) -> void:
	var atlas := AtlasTexture.new()
	atlas.atlas = load(texture_path)
	atlas.region = region
	var sprite := Sprite2D.new()
	sprite.texture = atlas
	# Feet on the ground with a little organic jitter.
	sprite.position = center(cell) + Vector2((h >> 12) % 7 - 3, (h >> 16) % 5 - 2)
	sprite.offset = Vector2(0, -region.size.y / 2 + 6)
	sprite.add_to_group("decor")
	actors.add_child(sprite)


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
	for sign_def: Dictionary in Interactables.signs_on(data.id, GameState.owns_house()):
		var door := Vector2i(int(sign_def["x"]), int(sign_def["y"]))
		# A burnt house has lost its sign with its roof (PIX-146).
		if ruins.any(func(ruin: Dictionary) -> bool: return (ruin["rect"] as Rect2i).has_point(door)):
			continue
		var target: Dictionary = data.portals.get(door, {})
		root.add_child(ShopSign.build(sign_def["label"], door))
		var told := ShopSign.about(sign_def["label"], String(target.get("mapId", "")), GameState.owns_house())
		door_signs.append({"door": door, "name": told["name"], "about": told["about"]})
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
	for placed: Dictionary in GameState.furniture():
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
## of the ruins, in his dungeon stone, under whatever stands on it.
func _build_tile_layer(data: MapData) -> TileMapLayer:
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
	var stone_id := tileset.add_source(stone)
	var blocker := TileSetAtlasSource.new()
	blocker.texture = ImageTexture.create_from_image(Image.create(TILE, TILE, false, Image.FORMAT_RGBA8))
	blocker.texture_region_size = Vector2i(TILE, TILE)
	blocker.create_tile(Vector2i.ZERO)
	var blocker_id := tileset.add_source(blocker)
	var blocker_tile := blocker.get_tile_data(Vector2i.ZERO, 0)
	blocker_tile.add_collision_polygon(0)
	blocker_tile.set_collision_polygon_points(0, 0, box)

	var layer := TileMapLayer.new()
	layer.tile_set = tileset
	var ruins := data.floor_level == 0 and PunyTerrain.is_outdoor(data.grid)
	for cell: Vector2i in data.grid:
		var tile: String = data.grid[cell]
		var prop: bool = outdoor_props["drawn"].has(cell)
		if ruins and (tile == "floor" or (prop and [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT].any(
			func(step: Vector2i) -> bool: return data.grid.get(cell + step, "") == "floor"
		))):
			layer.set_cell(cell, stone_id, Vector2i.ZERO)
			continue
		if not prop and not WorldTiles.is_walkable(tile):
			layer.set_cell(cell, blocker_id, Vector2i.ZERO)
	return layer
