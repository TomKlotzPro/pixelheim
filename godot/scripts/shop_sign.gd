class_name ShopSign
## The town's shop signs (PIX-134): a wooden board with a carved rim hanging
## by two chains from an iron bar over each door, painted with its trade in
## Shade's own icons (cheese for the general store, a tankard for the inn, the
## anvil, the brewing pot, the hall's ledger, a key for the house). Who is
## inside is told by the nameplate that rises as the hero walks up (world.gd);
## the board itself carries no words.
## The icons come from the paid Medieval Age atlas (PunyTown.SHEET); without
## it the old lettered boards stay.

## Icon per sign label, then per door target for anything unnamed.
const ICONS := {
	"GOODS": 801, "INN": 2121, "FORGE": 2125, "BREWS": 139, "HALL": 2778,
	"FOR SALE": 5860, "HOME": 5860,
}
const WOOD := Color("8c5a2e")
const WOOD_LIGHT := Color("b47c44")
const WOOD_DARK := Color("5e3b1d")
const RIM := Color("2a1a10")
const IRON := Color("34323a")
const IRON_LIGHT := Color("6b6874")
## The board, in world pixels (one per art pixel, as the houses).
const BOARD := Vector2i(22, 20)
const BAR := Vector2i(28, 3)
const DROP := 3

static var _board: ImageTexture
static var _bar: ImageTexture


static func available() -> bool:
	return PunyTown.available()


## What the nameplate says about a door: {"name", "about"}. `target` is the
## map the door leads to ("" for the house, which opens by its deed).
static func about(label: String, target: String, house_owned: bool) -> Dictionary:
	if Town.deeds().has(target):
		var shop := Economy.shop(String(Economy._data()["shopMaps"][target]))
		return {"name": Town.deeds()[target]["name"], "about": shop["keeper"]}
	match target:
		"town_inn":
			return {"name": "The Inn", "about": _keeper(target, "a bed and a stew")}
		"town_hall":
			return {"name": "Town Hall", "about": _keeper(target, "the town's ledger")}
	if label == "HOME" or (target == "" and house_owned):
		return {"name": "Home", "about": "Your house"}
	if label == "FOR SALE":
		return {"name": "For sale", "about": "A house: %dg, at the door" % int(Town._data()["houseDeedCost"])}
	return {"name": label.capitalize(), "about": ""}


## The one who keeps a place: the villager who stays put in it.
static func _keeper(map_id: String, otherwise: String) -> String:
	for npc: Dictionary in Npcs._data()["npcs"]:
		if npc["mapId"] == map_id and not npc.get("wander", false):
			return npc["name"]
	return otherwise


## The sign over a door: bar, chains, board, icon. Origin at the door cell's
## top-left; the board hangs centred over the door, on the eave.
static func build(label: String, door: Vector2i) -> Node2D:
	var root := Node2D.new()
	var centre := Vector2(door.x * 16 + 8, door.y * 16)
	var bar_at := Vector2(roundf(centre.x - BAR.x / 2.0), centre.y - BOARD.y - DROP - BAR.y - 2)
	root.add_child(_sprite(bar_texture(), bar_at))
	# Two chains, a pixel each, from the bar's hooks to the board.
	for hook_x: int in [4, BAR.x - 5]:
		var chain := ColorRect.new()
		chain.color = IRON
		chain.position = bar_at + Vector2(hook_x, BAR.y)
		chain.size = Vector2(1, DROP)
		root.add_child(chain)
	var board_at := Vector2(roundf(centre.x - BOARD.x / 2.0), bar_at.y + BAR.y + DROP)
	root.add_child(_sprite(board_texture(), board_at))
	var icon := Sprite2D.new()
	icon.centered = false
	var tile: int = ICONS.get(label, 801)
	var region := AtlasTexture.new()
	region.atlas = load(PunyTown.SHEET)
	region.region = Rect2(Vector2((tile % PunyTown.COLUMNS) * 16, (tile / PunyTown.COLUMNS) * 16), Vector2(16, 16))
	icon.texture = region
	icon.position = board_at + Vector2((BOARD.x - 16) / 2, (BOARD.y - 16) / 2)
	root.add_child(icon)
	return root


static func _sprite(texture: Texture2D, at: Vector2) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.texture = texture
	sprite.position = at
	return sprite


## The board: dark rim with clipped corners, a lit top plank, a shadowed
## bottom, and a carved inner line a pixel in.
static func board_texture() -> ImageTexture:
	if _board == null:
		var w := BOARD.x
		var h := BOARD.y
		var art := Image.create(w, h, false, Image.FORMAT_RGBA8)
		art.fill(Color(0, 0, 0, 0))
		for y in h:
			for x in w:
				var edge := x == 0 or y == 0 or x == w - 1 or y == h - 1
				var corner := (x == 0 or x == w - 1) and (y == 0 or y == h - 1)
				if corner:
					continue
				var colour := WOOD
				if edge:
					colour = RIM
				elif y == 1:
					colour = WOOD_LIGHT
				elif y == h - 2:
					colour = WOOD_DARK
				elif (x == 2 or x == w - 3) and y >= 2 and y <= h - 3 or (y == 2 or y == h - 3) and x >= 2 and x <= w - 3:
					colour = WOOD_DARK.lerp(WOOD, 0.35)  # the carved line
				art.set_pixel(x, y, colour)
		_board = ImageTexture.create_from_image(art)
	return _board


## The iron bar: a dark rod with a lit top edge and a hook under each end.
static func bar_texture() -> ImageTexture:
	if _bar == null:
		var art := Image.create(BAR.x, BAR.y, false, Image.FORMAT_RGBA8)
		art.fill(Color(0, 0, 0, 0))
		for x in BAR.x:
			art.set_pixel(x, 0, IRON_LIGHT)
			art.set_pixel(x, 1, IRON)
		for x: int in [0, 1, BAR.x - 2, BAR.x - 1]:
			art.set_pixel(x, 2, IRON)  # the bar's ends curl down
		for x: int in [4, BAR.x - 5]:
			art.set_pixel(x, 2, IRON)  # the hooks
		_bar = ImageTexture.create_from_image(art)
	return _bar
