class_name ShopSign
## areas: town +town-age*
## The town's shop signs (PIX-134, PIX-553): a wooden board for each trade,
## painted with its icon, hanging from an iron bracket at the eave over the
## door. The bracket is wrought iron out from the wall, a scroll in its
## corner and a curl at its tip; the board hangs from it by two chains,
## painted with its trade in Shade's own icons (cheese for the general
## store, a tankard for the inn, the anvil, the brewing pot, the hall's
## ledger, a key for the house). Shade's own hanging signs are 16 pixels,
## carved tone on tone: by
## day from across the street they read as a chest over the door. So the
## board and the iron are drawn here, in his way (a dark outline, a lit top
## edge, a shaded foot, grain), at least as big as the old board and hung
## where it was, from the eave, the icon in its own colours on the wood.
## Each trade has its own board (LOOKS: its shape, its wood, its chains'
## length, the side its bracket grows from), so the street isn't stamped.
## The board swings in the world's wind (shaders/sign.gdshader), each door on
## its own beat, still with Reduce motion; the door's lantern lights it at
## night and rims its edge. Who is inside is told by the nameplate that rises
## as the hero walks up (world.gd); the board carries no words. The icons
## come from the paid Medieval Age atlas (PunyTown.SHEET); without it the
## doors stand bare.

## Icon per sign label, then per door target for anything unnamed.
const ICONS := {
	"GOODS": 801, "INN": 2121, "FORGE": 2125, "BREWS": 139, "HALL": 2778,
	"FOR SALE": 5860, "HOME": 5860,
}
## The woods, each [base, lit, shaded]; each sign's against its icon's
## colours (the cheese on dark walnut, the brown tankard on pale ash).
const OAK := [Color("8c5a2e"), Color("b47c44"), Color("5e3b1d")]
const WALNUT := [Color("6e4a30"), Color("94684a"), Color("46301f")]
const CHERRY := [Color("96502c"), Color("c07a48"), Color("683420")]
const HONEY := [Color("a8763a"), Color("cf9c58"), Color("74502a")]
const WEATHERED := [Color("857058"), Color("a89478"), Color("5a4a3a")]
const PALE := [Color("b8956a"), Color("d8b88a"), Color("8a6a48")]
const RIM := Color("2a1a10")
const IRON := Color("34323a")
const IRON_LIGHT := Color("6b6874")
## The boards' shapes: how far each row stands in from the board's sides,
## top row first.
const SHAPES := {
	"arch": [7, 5, 3, 2, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1],
	"tun": [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 2, 3, 5, 7],
	"shield": [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 2, 3, 4, 5, 6, 8, 10],
	"round": [7, 5, 4, 3, 2, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 2, 3, 4, 5, 7],
	"plaque": [3, 2, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3],
	"plank": [2, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 2],
}
## Each sign's own look: its board's shape and wood, where on the board the
## icon's tile is painted (its drawing centred on the field: Shade's icons
## sit anywhere in their tiles), how long its chains are, and whether its
## bracket grows from the wall on the left.
const LOOKS := {
	"GOODS": {"shape": "arch", "wood": WALNUT, "icon": Vector2i(3, 5), "drop": 4, "left": true},
	"INN": {"shape": "tun", "wood": PALE, "icon": Vector2i(2, 4), "drop": 5, "left": false},
	"FORGE": {"shape": "shield", "wood": CHERRY, "icon": Vector2i(3, 4), "drop": 3, "left": false},
	"BREWS": {"shape": "round", "wood": HONEY, "icon": Vector2i(3, 2), "drop": 4, "left": true},
	"HALL": {"shape": "plaque", "wood": OAK, "icon": Vector2i(4, 3), "drop": 5, "left": true},
	"FOR SALE": {"shape": "plank", "wood": WEATHERED, "icon": Vector2i(3, 2), "drop": 6, "left": false},
	"HOME": {"shape": "plank", "wood": CHERRY, "icon": Vector2i(3, 2), "drop": 6, "left": false},
}
## The tallest board, in world pixels (one per art pixel, as the houses);
## none less than the old board's 22x20.
const BOARD := Vector2i(22, 22)
## The columns of the board its two chains hang on.
const CHAINS := [5, 16]
## How far over the door's top the bracket's arm runs: the longest chains
## and the tallest board end a pixel over the door.
const HINGE_UP := 28
## The bracket, the wall on its left: `#` iron, `+` iron lit from above. A
## plate on the wall, the arm out from it over the board, a scroll bracing
## its corner and a curl at its tip. The arm's last row is the hinge.
const BRACKET := [
	"............................##..",
	"...........................#..#.",
	".+.........................#.##.",
	"#++++++++++++++++++++++++++#....",
	"###########################.....",
	"##.++...........................",
	"##...#+.........................",
	"##.+..#.........................",
	"##.#+.#.........................",
	"##..##..........................",
	"##..............................",
	".#..............................",
]
## The rows of the bracket down to the arm's underside.
const ARM_ROWS := 5
## How far over the door's top the sign reaches: its curl's top (the
## nameplate rises over it).
const HIGH := HINGE_UP + ARM_ROWS
## How far a door's lantern lights the sign by it, and how bright.
const LIT_REACH := 56.0
const LIT_ENERGY := 0.5

static var _boards := {}
static var _bracket: ImageTexture
static var _sway := {}


static func available() -> bool:
	return PunyTown.available()


## What the nameplate says about a door: {"name", "about"}. `target` is the
## map the door leads to ("" for the house, which opens by its deed).
static func about(label: String, target: String, house_owned: bool) -> Dictionary:
	if Town.deeds().has(target):
		var shop := Economy.shop(Economy.shop_at(target))
		return {"name": Town.deeds()[target]["name"], "about": shop["keeper"]}
	match target:
		"town_inn":
			return {"name": "The Inn", "about": _keeper(target, "a bed and a stew")}
		"town_hall":
			return {"name": "Town Hall", "about": _keeper(target, "the town's ledger")}
	if label == "HOME" or (target == "" and house_owned):
		return {"name": "Home", "about": "Your house"}
	if label == "FOR SALE":
		return {"name": "For sale", "about": Text.t("A house: %dg, at the door") % Town.deed_cost()}
	return {"name": label.capitalize(), "about": ""}


## The one who keeps a place: the villager who stays put in it.
static func _keeper(map_id: String, otherwise: String) -> String:
	for npc: Dictionary in Npcs.townsfolk():
		if npc["mapId"] == map_id and not npc.get("wander", false):
			return npc["name"]
	return otherwise


## The signs still hanging: a burnt house has lost its sign with its roof
## (PIX-146).
static func standing(signs: Array, ruins: Array[Dictionary]) -> Array:
	return signs.filter(func(sign_def: Dictionary) -> bool:
		var door := Vector2i(int(sign_def["x"]), int(sign_def["y"]))
		return not ruins.any(func(ruin: Dictionary) -> bool: return (ruin["rect"] as Rect2i).has_point(door)))


## The sign over a door: the bracket on the wall, and under its arm the
## board on its chains and the icon painted on it, both hung from the hinge
## (the node's origin, their sprites' offsets below it) so the wind swings
## them as one.
static func build(label: String, door: Vector2i) -> Node2D:
	var look: Dictionary = LOOKS.get(label, LOOKS["GOODS"])
	var root := Node2D.new()
	root.position = Vector2(door.x * 16 + 8, door.y * 16 - HINGE_UP)
	var bracket := Sprite2D.new()
	bracket.name = "bracket"
	bracket.centered = false
	bracket.texture = bracket_texture()
	bracket.flip_h = not look["left"]
	bracket.position = Vector2(-bracket.texture.get_width() / 2.0, -ARM_ROWS)
	# Iron standing out from the wall: domed and rimmed as every prop.
	bracket.material = Relief.material(Relief.DOMED, false)
	root.add_child(bracket)
	var board := Sprite2D.new()
	board.name = "board"
	board.centered = false
	board.texture = board_texture(label)
	board.offset = Vector2(-BOARD.x / 2.0, 0)
	board.material = sway_material(true)
	root.add_child(board)
	var icon := Sprite2D.new()
	icon.name = "icon"
	icon.centered = false
	var tile: int = ICONS.get(label, 801)
	var region := AtlasTexture.new()
	region.atlas = load(PunyTown.SHEET)
	region.region = Rect2(Vector2((tile % PunyTown.COLUMNS) * 16, (tile / PunyTown.COLUMNS) * 16), Vector2(16, 16))
	icon.texture = region
	icon.offset = Vector2(look["icon"] as Vector2i) + Vector2(-BOARD.x / 2.0, int(look["drop"]))
	icon.material = sway_material(false)
	root.add_child(icon)
	for piece: Sprite2D in [bracket, board, icon]:
		piece.light_mask |= Lights.SIGN
	return root


## A lantern hung on `cell`, beside a signed door, lights that door's sign
## (`signs`: MapView.door_signs; the signposts' and huts' have no node): a
## light at its glass that reaches the signs alone (Lights.SIGN), a child
## of the lantern's `halo`, so it is lit and put out with it. Steady, so the
## night's shadows never take it for a flame to cast from
## (NightShadowsLayer). A door with no lantern keeps its sign in the dark.
static func light(signs: Array, cell: Vector2i, halo: Node2D) -> void:
	for entry: Dictionary in signs:
		var door: Vector2i = entry["door"]
		if entry["node"] != null and door.y == cell.y and absi(door.x - cell.x) == 1:
			var lamp := Lights.make(Vector2.ZERO, LIT_REACH, Lights.LAMP, LIT_ENERGY)
			lamp.range_item_cull_mask = Lights.SIGN
			halo.add_child(lamp)


## What hangs wears this (shaders/sign.gdshader): it swings in the world's
## wind, and the lights rim the board (`rimmed`), never the icon painted on
## it. One material each way for every sign.
static func sway_material(rimmed: bool) -> ShaderMaterial:
	if not _sway.has(rimmed):
		var made := ShaderMaterial.new()
		made.shader = preload("res://shaders/sign.gdshader")
		made.set_shader_parameter("relief_rimmed", rimmed)
		_sway[rimmed] = made
	return _sway[rimmed]


## A sign's board under its two chains, the hinge its top row.
static func board_texture(label: String) -> ImageTexture:
	if not _boards.has(label):
		_boards[label] = ImageTexture.create_from_image(board_image(LOOKS.get(label, LOOKS["GOODS"])))
	return _boards[label]


## A look's board, drawn: a dark outline round its shape, the top edge lit
## and the foot shaded, the left side a little lit and the right a little
## shaded, a carved line round the field the icon is painted on, a seam
## between its planks and flecks of grain; over it the two
## chains, a link a pixel, down to a staple in its top.
static func board_image(look: Dictionary) -> Image:
	var rows: Array = SHAPES[look["shape"]]
	var drop: int = look["drop"]
	var wood: Array = look["wood"]
	var art := Image.create(BOARD.x, drop + rows.size(), false, Image.FORMAT_RGBA8)
	art.fill(Color(0, 0, 0, 0))
	for y in rows.size():
		for x in BOARD.x:
			if not _inside(rows, x, y):
				continue
			var colour: Color = wood[0]
			if (y + 2) % 6 == 0:
				colour = colour.lerp(wood[2], 0.45)  # a seam between two planks
			elif (x * 7 + y * 13) % 11 == 0:
				colour = colour.lerp(wood[2], 0.3)  # grain
			elif (x * 5 + y * 3) % 17 == 0:
				colour = colour.lerp(wood[1], 0.4)
			if not (_inside(rows, x - 1, y) and _inside(rows, x + 1, y) and _inside(rows, x, y - 1) and _inside(rows, x, y + 1)):
				colour = RIM
			elif not _inside(rows, x, y - 2):
				colour = wood[1]
			elif not _inside(rows, x, y + 2):
				colour = wood[2]
			elif not _inside(rows, x - 2, y):
				colour = colour.lerp(wood[1], 0.5)
			elif not _inside(rows, x + 2, y):
				colour = colour.lerp(wood[2], 0.5)
			elif not (_inside(rows, x - 3, y) and _inside(rows, x + 3, y) and _inside(rows, x, y - 3) and _inside(rows, x, y + 3)):
				colour = wood[2].lerp(wood[0], 0.35)  # the carved line round the field
			art.set_pixel(x, drop + y, colour)
	for x: int in CHAINS:
		var y := 0
		while not _inside(rows, x, y - drop):
			art.set_pixel(x, y, IRON_LIGHT if y % 2 == 0 else IRON)
			y += 1
		art.set_pixel(x, y, IRON_LIGHT)
	return art


## Whether (x, y) is on a board of those `rows` (SHAPES).
static func _inside(rows: Array, x: int, y: int) -> bool:
	return y >= 0 and y < rows.size() and x >= int(rows[y]) and x < BOARD.x - int(rows[y])


## The wrought-iron bracket (BRACKET), the wall on its left.
static func bracket_texture() -> ImageTexture:
	if _bracket == null:
		var art := Image.create(BRACKET[0].length(), BRACKET.size(), false, Image.FORMAT_RGBA8)
		art.fill(Color(0, 0, 0, 0))
		for y in BRACKET.size():
			for x in BRACKET[y].length():
				if BRACKET[y][x] != ".":
					art.set_pixel(x, y, IRON_LIGHT if BRACKET[y][x] == "+" else IRON)
		_bracket = ImageTexture.create_from_image(art)
	return _bracket
