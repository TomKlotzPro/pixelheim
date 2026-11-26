class_name GatesLayer
extends MapLayer
## areas: town rooms travel +town-age*
## The gates the story still keeps shut, each dungeon's way in drawn in its
## setting, and a mining country's workings (PIX-254, PIX-290, PIX-308):
## MapView's `plan_gates` and `decor_gates` units (PIX-359).

## How far a torch on the mountain's gatehouse lights the road (PIX-312),
## and its flame: the CC0 dungeon sheet's torch (a camp's until PIX-554).
const GATE_TORCH_REACH := 64.0
const GATE_TORCH := [16, 17, 18, 19, 20, 21, 22, 23]


## The gates the story still keeps shut (PIX-254): what's drawn across each
## blocks its cells, and a burnt bridge has no planks there. Then the ways
## on, and today's patches (PIX-250): a few dealt from each region's ground.
func plan(view: MapView, slices: Slicer) -> void:
	slices.add("plan_gates", func() -> void: _plan_gates(view))


static func _plan_gates(view: MapView) -> void:
	view.gate_hides = {}
	view.gates = Gates.closed_on(view.data.id, GameState.progression, GameState.settlement, GameState.world.discovered)
	for gate: Dictionary in view.gates:
		for cell: Vector2i in Gates.cells_of(gate):
			view.data.covered[cell] = true
		for cell: Vector2i in GateArt.plan(gate, PunyProps.available())["hides"]:
			view.gate_hides[cell] = true
	view.ways = Ways.on(view.data)
	# Each dungeon's way in as an entrance in its setting (PIX-290).
	view.entrances = []
	for way: Dictionary in view.ways:
		var barred := Ways.barred(way["to"], GameState.progression, GameState.settlement)
		var entrance := EntranceArt.plan(view.data, way, barred, PunyProps.available())
		if entrance["look"] == "":
			continue
		view.entrances.append(entrance)
		for cell: Vector2i in entrance["hides"]:
			view.gate_hides[cell] = true
		for cell: Vector2i in entrance["blocks"]:
			view.data.covered[cell] = true
	view.patches = {}
	view.patch_day = -1
	view.deal_patches(Gathering.day_of(GameState.world.steps))


## The gates, the ways in and the workings, drawn: our pictures first, a
## unit each (PIX-556: drawn once a session, the bank some 3 ms headless and
## the heap 1.5, together past Neighbours' budget in one frame).
func build(view: MapView, slices: Slicer) -> void:
	for gate: Dictionary in view.gates:
		for piece: Dictionary in GateArt.plan(gate, PunyProps.available())["pieces"]:
			if piece["sheet"] == "gate":
				var name := String(piece["sprite"])
				slices.add("decor_gate_art", func() -> void: GateArt.texture(name))
	slices.add("decor_gates", func() -> void:
		for gate: Dictionary in view.gates:
			_add_gate(view, gate)
		for entrance: Dictionary in view.entrances:
			_add_entrance(view, entrance)
		# A mining country's workings (PIX-308).
		for piece: Dictionary in view.workings.get("pieces", []):
			_add_gate_piece(view, piece))


## A gate still shut (PIX-254): its pieces (GateArt) among the actors or flat
## on the ground, and a box on each of its cells, so it blocks like any prop.
static func _add_gate(view: MapView, gate: Dictionary) -> void:
	for piece: Dictionary in GateArt.plan(gate, PunyProps.available())["pieces"]:
		_add_gate_piece(view, piece)
	for cell: Vector2i in Gates.cells_of(gate):
		var body := StaticBody2D.new()
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(TILE, TILE)
		shape.shape = rect
		body.add_child(shape)
		body.position = MapView.center(cell)
		body.add_to_group("decor")
		view.actors.add_child(body)


## A dungeon's way in drawn in its setting (PIX-290): its pieces (EntranceArt,
## GateArt's kind) among the actors or flat on the ground, and a box on each
## open cell they stand on.
static func _add_entrance(view: MapView, entrance: Dictionary) -> void:
	for piece: Dictionary in entrance["pieces"]:
		_add_gate_piece(view, piece)
	for cell: Vector2i in entrance["blocks"]:
		var body := StaticBody2D.new()
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(TILE, TILE)
		shape.shape = rect
		body.add_child(shape)
		body.position = MapView.center(cell)
		body.add_to_group("decor")
		view.actors.add_child(body)


static func _add_gate_piece(view: MapView, piece: Dictionary) -> void:
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
		post.add_child(preload("res://scripts/enemy.gd").ground_shadow(guard, 1.0, guard.position.y))
		post.add_child(guard)
		view.actors.add_child(post)
		return
	if piece["sheet"] == "glint":
		# The hoard's gold glinting through the Vault's open door (PIX-312):
		# over the door, untouched by the dark.
		var glint := AnimatedSprite2D.new()
		glint.sprite_frames = HamletArt.glint()
		glint.centered = false
		# The snow's by day (PIX-556) dim with the hour as the snow does.
		if not piece.get("day", false):
			glint.material = Lights.unshaded()
		glint.position = at - Vector2(0, TILE)
		# Sparkles side by side don't catch the light together.
		glint.frame = absi(hash(cell)) % glint.sprite_frames.get_frame_count("default")
		glint.play()
		var over := Node2D.new()
		# Sorted a pixel past the door's own foot, so it shows on it.
		over.position = Vector2(cell * TILE) + Vector2(0, TILE + 1)
		over.add_to_group("decor")
		over.add_child(glint)
		view.actors.add_child(over)
		# The snow's sparkles by day (PIX-556): gone with the sun.
		if piece.get("day", false):
			view.day_glows.append(over)
		return
	if piece["sheet"] == "torch":
		_add_gate_torch(view, cell, at)
		return
	var sprite := Sprite2D.new()
	match String(piece["sheet"]):
		"dungeon":
			sprite.texture = PunyDungeon.sheet().tile_texture(piece["tile"])
		"props":
			sprite.texture = PunyProps.texture(piece["tile"])
		"art":
			sprite.texture = DungeonArt.texture(piece["tile"])
		"ash":
			sprite.texture = AshArt.texture(piece["tile"])
		"hamlet":
			sprite.texture = HamletArt.texture(piece["sprite"])
		"gate":
			sprite.texture = GateArt.texture(String(piece["sprite"]))
		_:
			sprite.texture = PunyTerrain.sheet().tile_texture(piece["tile"])
	sprite.centered = false
	match String(piece["tone"]):
		"charred":
			sprite.modulate = GateArt.CHARRED
		"iron":
			sprite.modulate = EntranceArt.BLACK_IRON
	if piece["flat"]:
		sprite.position = Vector2(cell * TILE) + at
		view.ground.add_child(sprite)
		return
	# Sorted on its own foot, the bottom of its sprite.
	var root := Node2D.new()
	root.position = Vector2(cell * TILE) + Vector2(0, TILE + at.y)
	root.add_to_group("decor")
	# A tile is a cell tall; ours (PIX-556) as tall as drawn.
	var size := sprite.texture.get_size() if piece["sheet"] == "gate" else Vector2(TILE, TILE)
	sprite.position = Vector2(at.x, -size.y)
	if piece.get("turn", false):
		# Laid on its side, its top to the west (the avalanche's pine).
		sprite.rotation = -PI / 2.0
		sprite.position.y = 0.0
	root.add_child(sprite)
	view.actors.add_child(root)
	if piece.get("cast", false):
		# Ours cast the sun's shadow as the trees do (PIX-556); the rockfall's
		# never shows, the marsh round it under the mire's sky all cloud.
		cast(view, root.position + Vector2(at.x + size.x / 2.0, 0), size.x, size.y)


## A torch on a tower of the mountain's gatehouse (PIX-312): Shade's CC0
## flame on the tower's face, `at` from its cell, among the actors over the
## tower; at night a halo round it and its light on the road below.
static func _add_gate_torch(view: MapView, cell: Vector2i, at: Vector2) -> void:
	var flame := AnimatedSprite2D.new()
	flame.sprite_frames = _torch_frames()
	flame.centered = false
	flame.frame = absi(hash(cell)) % flame.sprite_frames.get_frame_count("default")
	flame.play()
	flame.position = at - Vector2(0, TILE)
	var root := Node2D.new()
	# Sorted a pixel past the tower's own foot, so it shows on its face.
	root.position = Vector2(cell * TILE) + Vector2(0, TILE + 1)
	root.add_to_group("decor")
	root.add_child(flame)
	view.actors.add_child(root)
	var middle := Vector2(cell * TILE) + at + Vector2(TILE / 2.0, TILE / 2.0 - 2)
	var halo := view._add_halo(middle, MapView.LAMP_HALO, MapView.LAMP_HALO_PEAK)
	var light := Lights.make(middle + Vector2(0, TILE), GATE_TORCH_REACH, Lights.FIRE, Lights.TORCH_ENERGY, true)
	view.props.add_child(light)
	halo.set_meta("light", light)


static var _torch: SpriteFrames


static func _torch_frames() -> SpriteFrames:
	if _torch == null:
		_torch = SpriteFrames.new()
		_torch.set_animation_speed("default", 8.0)
		for tile: int in GATE_TORCH:
			_torch.add_frame("default", PunyDungeon.sheet().tile_texture(tile))
	return _torch
