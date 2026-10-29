class_name Yards
## areas: town night +town-age*
## What Pixelheim's households keep about their houses, and the square's
## dress, by the town's age (PIX-382). The audit found every house standing
## in bare lawn, the square an empty floor, and nothing but the paving and
## the lamps to tell the Village from the City. Each age adds to the last:
## - the Hamlet: firewood by the homes, a keg, a crate or coal by each
##   keeper's door, a scarecrow over the field across the river, a window
##   box here and there, the market's first stall, bare, on the square's
##   east rim;
## - the Village: a second stall under its awning beside it, produce and
##   bread on their counters, a flowering hedge along the wall by the gate,
##   washing strung between the houses, kitchen gardens (Maren's, the
##   cottage's, the east lawn's), sacks by Odo's, the inn's crates, half the
##   windows in flower;
## - the Town: benches on the square's west rim, the hedge longer, the east
##   lawn's garden grown with its scarecrow, hay by the slate hall and the
##   east field, a cart by the forge, lanterns by the keepers' doors, most
##   windows in flower;
## - the City: every window in flower, roses and box round the hall and
##   lanterns either side of its door, and bunting strung across the square
##   between its lamps, its lanterns lit at night.
## The houses the ages raise (Town.age_houses, PIX-382 step 3) keep theirs
## from the age they stand: firewood, hay and kegs.
## The market, the streets and their green by the age (PIX-382 step 4, the
## sets): the stalls sell what the pack draws, laid on their bare counters
## under their awnings (`on`: blocking nothing more), from one bare stall in
## the Hamlet to produce and bread in the Village, the draper's stall and a
## basket out front in the Town, and in the City the butcher's and the
## bookseller's stalls either side of the avenue south, pots, and a cart of
## the coast's catch between the east rim's stalls;
## the trades' signs by their doors (the forge's anvil and grindstone, the
## brewery's cask); potted trees along Upper Street and at the square's
## corners from the Town, potted flowers between them and on the avenue in
## the City (`pot`).
## Laid as a settlement's dressing is (Hamlet.plan's `grown`): what stands
## blocks only open ground off the paths and never closes a way, and keeps
## clear of every villager's place and pacing, the square's boards, stalls
## and lanterns, the post and wherever the story stands someone (`kept`).
## A piece by a house (`by`, its door) stands only once the house does.
## Only with the paid pack: without it the town's houses aren't drawn, so
## nothing hangs on them or stands beside them. Pure: MapView draws it.

## The pack's own pieces (Medieval Age tiles): flowering bushes, sacks, a
## basket of greens, a scarecrow and a hay bale.
const ROSES := 2656
const LAVENDER := 2657
const MARIGOLDS := 2658
const BERRIES := 2660
const BUSH := 2661
const BLUEBELLS := 2662
const BOX_BUSH := 2663
const SACKS := 1900
const BASKET := 1235
const SCARECROW := 3005
const HAY := 2787
## The market's wares (PIX-382 step 4), the pack's: produce, bread and
## cheese, a draper's folded cloth, a potter's jug, flour sacks, a ham and a
## roast, books and an open one; the trades' signs (a cask on its cradle, the
## anvil, a grindstone); and the small trees that grow in the planters.
const REDS := 1456
const YELLOWS := 1675
const LOAF := 1019
const SMALL_LOAF := 1020
const CHEESE := 801
const CLOTH := [2777, 2778, 2779]
const JUG := 2115
const FLOUR := 2999
const HAM := 1018
const ROAST := 803
const BOOKS := [2775, 2776]
const OPEN_BOOK := 2780
const CASK := 2123
const ANVIL := 2124
const GRINDSTONE := 2127
const TREES := [16, 1338, 1342]

## The houses' doors: a piece by one stands once its house does.
const MAREN := Vector2i(21, 10)
const ODO := Vector2i(30, 10)
const INN := Vector2i(50, 10)
const UPPER := Vector2i(60, 10)
const VEX := Vector2i(23, 19)
const HALL := Vector2i(40, 19)
const FORGE := Vector2i(55, 18)
const SLATE := Vector2i(74, 17)
const LANE_WEST := Vector2i(6, 25)
const HOME := Vector2i(15, 25)
const LANE_EAST := Vector2i(24, 25)
const THATCH := Vector2i(7, 32)
const MOSS := Vector2i(16, 32)
## The houses the ages raise (Town.age_houses): the farmhouse in the
## orchard, the house on the east lawn, the house by the west woods and the
## farmstead in the south-east woods.
const FARM := Vector2i(76, 9)
const LAWN := Vector2i(57, 25)
const WEST := Vector2i(6, 18)
const STEAD := Vector2i(76, 36)

## Each piece placed by hand, as Hamlet.DRESSING's (`art` ours or `tile`
## the pack's), with the age it comes at; a lantern `dim` keeps its halo
## without a light of its own, where the City's lamps already reach.
const PIECES := [
	# The Hamlet: what a house rebuilt needs first.
	{"art": "woodpile", "cell": Vector2i(18, 9), "by": MAREN, "age": 1},
	{"art": "box", "cell": Vector2i(35, 9), "by": ODO, "age": 1},
	{"art": "keg", "cell": Vector2i(57, 9), "by": INN, "age": 1},
	{"art": "woodpile", "cell": Vector2i(61, 5), "by": UPPER, "age": 1},
	{"art": "keg", "cell": Vector2i(28, 18), "by": VEX, "age": 1},
	{"art": "tub", "cell": Vector2i(61, 16), "by": FORGE, "age": 1},
	{"art": "coal", "cell": Vector2i(61, 15), "by": FORGE, "age": 1},
	{"art": "woodpile", "cell": Vector2i(3, 24), "by": LANE_WEST, "age": 1},
	{"art": "box", "cell": Vector2i(28, 24), "by": LANE_EAST, "age": 1},
	{"tile": SCARECROW, "cell": Vector2i(81, 14), "age": 1},
	# The Village: washing out, gardens dug, stock laid in.
	{"line": 1, "cell": Vector2i(25, 7), "by": MAREN, "age": 2},
	{"line": 1, "cell": Vector2i(10, 23), "by": LANE_WEST, "age": 2},
	{"line": 1, "cell": Vector2i(57, 6), "by": UPPER, "age": 2},
	{"art": "garden", "cell": Vector2i(20, 4), "flat": true, "by": MAREN, "age": 2},
	{"art": "garden", "cell": Vector2i(21, 4), "flat": true, "by": MAREN, "age": 2},
	{"art": "garden", "cell": Vector2i(22, 4), "flat": true, "by": MAREN, "age": 2},
	{"tile": ROSES, "cell": Vector2i(18, 10), "by": MAREN, "age": 2},
	{"tile": SACKS, "cell": Vector2i(35, 10), "by": ODO, "age": 2},
	{"art": "box", "cell": Vector2i(57, 8), "by": INN, "age": 2},
	{"art": "keg", "cell": Vector2i(28, 19), "by": VEX, "age": 2},
	{"art": "woodpile", "cell": Vector2i(61, 14), "by": FORGE, "age": 2},
	{"art": "keg", "cell": Vector2i(3, 25), "by": LANE_WEST, "age": 2},
	{"art": "woodpile", "cell": Vector2i(28, 23), "by": LANE_EAST, "age": 2},
	{"art": "woodpile", "cell": Vector2i(4, 31), "by": THATCH, "age": 2},
	{"art": "garden", "cell": Vector2i(6, 28), "flat": true, "by": THATCH, "age": 2},
	{"art": "garden", "cell": Vector2i(7, 28), "flat": true, "by": THATCH, "age": 2},
	{"art": "garden", "cell": Vector2i(58, 30), "flat": true, "age": 2},
	{"art": "garden", "cell": Vector2i(59, 30), "flat": true, "age": 2},
	{"art": "garden", "cell": Vector2i(60, 30), "flat": true, "age": 2},
	{"art": "woodpile", "cell": Vector2i(79, 9), "by": FARM, "age": 2},
	# The Town: the square's rims kept, the lawns worked, the doors lit.
	{"line": 2, "cell": Vector2i(20, 23), "by": HOME, "age": 3},
	{"line": 3, "cell": Vector2i(11, 30), "by": MOSS, "age": 3},
	{"art": "garden", "cell": Vector2i(8, 28), "flat": true, "by": THATCH, "age": 3},
	{"art": "garden", "cell": Vector2i(15, 28), "flat": true, "by": MOSS, "age": 3},
	{"art": "garden", "cell": Vector2i(16, 28), "flat": true, "by": MOSS, "age": 3},
	{"art": "woodpile", "cell": Vector2i(20, 30), "by": MOSS, "age": 3},
	{"tile": BASKET, "cell": Vector2i(35, 8), "by": ODO, "age": 3},
	{"art": "tub", "cell": Vector2i(28, 17), "by": VEX, "age": 3},
	{"art": "cart", "cell": Vector2i(63, 17), "by": FORGE, "age": 3},
	{"tile": HAY, "cell": Vector2i(72, 18), "by": SLATE, "age": 3},
	{"tile": HAY, "cell": Vector2i(77, 31), "age": 3},
	{"tile": HAY, "cell": Vector2i(79, 31), "age": 3},
	{"art": "bench", "cell": Vector2i(30, 22), "age": 3},
	{"art": "bench", "cell": Vector2i(30, 25), "age": 3},
	{"art": "garden", "cell": Vector2i(58, 31), "flat": true, "age": 3},
	{"art": "garden", "cell": Vector2i(59, 31), "flat": true, "age": 3},
	{"art": "garden", "cell": Vector2i(60, 31), "flat": true, "age": 3},
	{"tile": SCARECROW, "cell": Vector2i(61, 30), "age": 3},
	{"art": "lantern", "cell": Vector2i(31, 10), "wall": true, "by": ODO, "age": 3, "dim": true},
	{"art": "lantern", "cell": Vector2i(51, 10), "wall": true, "by": INN, "age": 3},
	{"art": "lantern", "cell": Vector2i(24, 19), "wall": true, "by": VEX, "age": 3},
	{"art": "lantern", "cell": Vector2i(56, 18), "wall": true, "by": FORGE, "age": 3},
	{"tile": HAY, "cell": Vector2i(73, 10), "by": FARM, "age": 3},
	{"art": "woodpile", "cell": Vector2i(62, 22), "by": LAWN, "age": 3},
	# The City: dressed for the whole Reach to see.
	{"art": "lantern", "cell": Vector2i(39, 19), "wall": true, "by": HALL, "age": 4},
	{"art": "lantern", "cell": Vector2i(41, 19), "wall": true, "by": HALL, "age": 4},
	{"art": "garden", "cell": Vector2i(17, 28), "flat": true, "by": MOSS, "age": 4},
	{"tile": LAVENDER, "cell": Vector2i(18, 6), "by": MAREN, "age": 4},
	{"tile": MARIGOLDS, "cell": Vector2i(2, 21), "by": LANE_WEST, "age": 4},
	{"tile": BOX_BUSH, "cell": Vector2i(34, 17), "by": HALL, "age": 4},
	{"tile": ROSES, "cell": Vector2i(34, 18), "by": HALL, "age": 4},
	{"tile": BOX_BUSH, "cell": Vector2i(46, 17), "by": HALL, "age": 4},
	{"tile": ROSES, "cell": Vector2i(46, 18), "by": HALL, "age": 4},
	{"art": "keg", "cell": Vector2i(62, 25), "by": LAWN, "age": 4},
	{"art": "woodpile", "cell": Vector2i(10, 15), "by": WEST, "age": 4},
	{"art": "box", "cell": Vector2i(10, 17), "by": WEST, "age": 4},
	{"tile": HAY, "cell": Vector2i(73, 37), "by": STEAD, "age": 4},
	{"art": "woodpile", "cell": Vector2i(79, 37), "by": STEAD, "age": 4},
	# Strung between the square's lamps: (31,29)-(49,29), and (34,19)-(46,19)
	# along the hall's front, drawn from the row before it, a cell higher.
	{"art": "bunting", "line": 17, "cell": Vector2i(32, 29), "age": 4},
	{"art": "bunting", "line": 11, "cell": Vector2i(35, 20), "high": 1, "age": 4},
]
## Flowering hedges along the foot of the wall: [first cell, last, age].
const HEDGES := [[Vector2i(26, 3), Vector2i(36, 3), 2], [Vector2i(18, 3), Vector2i(25, 3), 3], [Vector2i(58, 3), Vector2i(63, 3), 3]]
## A hedge's bushes, picked by cell: mostly green, in flower here and there.
const HEDGE := [BUSH, ROSES, BOX_BUSH, BUSH, LAVENDER, BOX_BUSH, BLUEBELLS, BUSH, BERRIES]
## A house's window boxes, all one colour, picked by its door.
const WINDOW_BOXES := ["window_box", "window_box_gold", "window_box_white", "window_box_blue"]
## The market (PIX-382 step 4): Mabel's stalls with their counters bare
## (HamletArt.STALLS), each trade's wares laid on its counter (`on`: where
## the ware's top left lies from the cell's: its foot on the counter, 6 px
## down the stall's cell, one at the back of it 1-2 px higher), what stands
## out front, and a cart come up from the coast. A stall comes before its
## wares, and a ware at the back before those in front of it.
const MARKET := [
	{"art": "stall_red", "cell": Vector2i(50, 23), "age": 1},
	{"tile": BASKET, "cell": Vector2i(50, 23), "on": Vector2i(1, -9), "age": 2},
	{"tile": REDS, "cell": Vector2i(50, 23), "on": Vector2i(15, -9), "age": 2},
	{"art": "stall_blue", "cell": Vector2i(50, 26), "age": 2},
	{"tile": CHEESE, "cell": Vector2i(50, 26), "on": Vector2i(8, -7), "age": 3},
	{"tile": LOAF, "cell": Vector2i(50, 26), "on": Vector2i(1, -4), "age": 2},
	{"tile": SMALL_LOAF, "cell": Vector2i(50, 26), "on": Vector2i(16, -3), "age": 2},
	{"tile": YELLOWS, "cell": Vector2i(49, 23), "age": 3},
	{"art": "stall_green", "cell": Vector2i(30, 24), "age": 3},
	{"tile": CLOTH[0], "cell": Vector2i(30, 24), "on": Vector2i(3, -6), "age": 3},
	{"tile": CLOTH[1], "cell": Vector2i(30, 24), "on": Vector2i(10, -7), "age": 3},
	{"tile": CLOTH[2], "cell": Vector2i(30, 24), "on": Vector2i(17, -9), "age": 3},
	{"tile": JUG, "cell": Vector2i(49, 27), "age": 4},
	{"art": "handcart", "cell": Vector2i(50, 24), "age": 4},
	{"tile": FLOUR, "cell": Vector2i(50, 24), "on": Vector2i(2, -6), "age": 4},
	{"art": "fish_crate", "cell": Vector2i(50, 24), "on": Vector2i(11, -5), "age": 4},
	{"art": "stall_gold", "cell": Vector2i(37, 30), "age": 4},
	{"tile": HAM, "cell": Vector2i(37, 30), "on": Vector2i(0, -4), "age": 4},
	{"tile": ROAST, "cell": Vector2i(37, 30), "on": Vector2i(16, -5), "age": 4},
	{"art": "stall_teal", "cell": Vector2i(42, 30), "age": 4},
	{"tile": BOOKS[1], "cell": Vector2i(42, 30), "on": Vector2i(4, -8), "age": 4},
	{"tile": BOOKS[0], "cell": Vector2i(42, 30), "on": Vector2i(0, -6), "age": 4},
	{"tile": OPEN_BOOK, "cell": Vector2i(42, 30), "on": Vector2i(16, -3), "age": 4},
]
## The trades' signs by their doors (PIX-382 step 4): the brewery's cask on
## its cradle, the forge's anvil and its grindstone.
const STREET := [
	{"tile": CASK, "cell": Vector2i(29, 19), "by": VEX, "age": 3},
	{"tile": ANVIL, "cell": Vector2i(62, 15), "by": FORGE, "age": 3},
	{"tile": GRINDSTONE, "cell": Vector2i(64, 15), "by": FORGE, "age": 4},
]
## Planters (PIX-382 step 4, `pot`): a small tree in the pack's tub along
## Upper Street's south side and at the square's top corners from the Town;
## flowers between the trees and a tree either side of the avenue in the City.
const GREEN := [
	{"tile": TREES[0], "cell": Vector2i(23, 13), "pot": true, "age": 3},
	{"tile": TREES[1], "cell": Vector2i(41, 13), "pot": true, "age": 3},
	{"tile": TREES[2], "cell": Vector2i(61, 13), "pot": true, "age": 3},
	{"tile": TREES[0], "cell": Vector2i(31, 21), "pot": true, "age": 3},
	{"tile": TREES[0], "cell": Vector2i(49, 21), "pot": true, "age": 3},
	{"tile": ROSES, "cell": Vector2i(20, 13), "pot": true, "age": 4},
	{"tile": LAVENDER, "cell": Vector2i(26, 13), "pot": true, "age": 4},
	{"tile": MARIGOLDS, "cell": Vector2i(35, 13), "pot": true, "age": 4},
	{"tile": ROSES, "cell": Vector2i(46, 13), "pot": true, "age": 4},
	{"tile": TREES[1], "cell": Vector2i(38, 7), "pot": true, "age": 4},
	{"tile": TREES[1], "cell": Vector2i(42, 7), "pot": true, "age": 4},
]
## The sets by name, as the report counts them (`lived=`).
const SETS := {"market": MARKET, "street": STREET, "green": GREEN}


## The town's dressing at `age` (GameState.town_tier) on `map`, its houses
## `pieces` as PunyTown drew them (window boxes go under their windows):
## Hamlet.plan's `grown` entries. None without the pack (`paid`).
static func plan(map: MapData, pieces: Dictionary, age: int, paid: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not paid:
		return out
	for entry: Dictionary in PIECES + hedges() + sets():
		if int(entry["age"]) <= age and (not entry.has("by") or map.tile_at(entry["by"]).begins_with("door")):
			out.append(entry)
	out.append_array(window_boxes(pieces, age))
	return out


## The market's, the streets' and the planters' pieces, each marked with
## its set (`set`).
static func sets() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for name: String in SETS:
		for entry: Dictionary in SETS[name]:
			out.append(entry.merged({"set": name}))
	return out


## The hedges' bushes, a piece a cell.
static func hedges() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for hedge: Array in HEDGES:
		var first: Vector2i = hedge[0]
		var last: Vector2i = hedge[1]
		for x in range(first.x, last.x + 1):
			var cell := Vector2i(x, first.y)
			out.append({"tile": HEDGE[(cell.x * 7 + cell.y * 13) % HEDGE.size()], "cell": cell, "age": hedge[2]})
	return out


## A window box under some of the houses' windows: a share of them, more
## with each age (a quarter in the Hamlet, every one in the City), which
## windows by their cells; a house's all of one colour, by its door.
static func window_boxes(pieces: Dictionary, age: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for cell: Vector2i in pieces:
		if pieces[cell] != PunyTown.WINDOW or (cell.x * 5 + cell.y * 3) % Town.MAX_TIER >= age:
			continue
		out.append({"art": WINDOW_BOXES[_door_of(pieces, cell).x % WINDOW_BOXES.size()], "cell": cell, "wall": true, "age": age})
	return out


## The door in the wall a window is in: the nearest along its row.
static func _door_of(pieces: Dictionary, window: Vector2i) -> Vector2i:
	for step in range(1, 16):
		for side: int in [-1, 1]:
			var cell := window + Vector2i(step * side, 0)
			if pieces.get(cell, -1) == PunyTown.DOOR:
				return cell
	return window


## The cells the town's dressing leaves open, beyond what a settlement's
## does (Hamlet.kept_on): every villager's place, a wanderer's whole pacing
## square, at every age and with every settler home, and on the Night of
## Bells; the square's gathering spots, boards, festival stalls and barker,
## the ending's lanterns, the post box and its house, where Fafnyr lands,
## Morvax's bench, the Ashes' tent and where a fall wakes by it.
static func kept(map: MapData) -> Dictionary:
	var out := _standing().duplicate()
	for cell: Vector2i in Town.gathering_spots(map):
		out[cell] = true
	return out


## Where the data stands anyone or anything on the town, worked out once a
## session (it was a millisecond and a half of every visit's plan).
static var _stood := {}


static func _standing() -> Dictionary:
	if not _stood.is_empty():
		return _stood
	var settled: Array = Npcs.recruits().map(func(recruit: Dictionary) -> String: return recruit["id"])
	for tier in Town.MAX_TIER + 1:
		var done := Town.projects_through(tier)
		var folk: Array = Npcs.on_map("town", tier, [], done) + Npcs.on_map("town", tier, settled, done) + Bells.folk(settled, tier)
		folk.append_array(Town.site_workers(Town.projects_through(tier - 1)))
		for npc: Dictionary in folk:
			for offset: Vector2i in Npcs.LOOP if npc.get("wander", false) else [Vector2i.ZERO]:
				_stood[Vector2i(int(npc["x"]), int(npc["y"])) + offset] = true
	var spots: Array = Town.lanterns() + Post.house_cells()
	spots.append_array([Town.project_board(), Town.bounty_board(), Post.box_cell(), Bells.landing(), Homecoming.bench(), Town.ashes_tent([])])
	for at: Dictionary in Town.festival("stalls") + [Town.festival("barker"), Town.ashes_wake()]:
		spots.append(Vector2i(int(at["x"]), int(at["y"])))
	for cell: Vector2i in spots:
		_stood[cell] = true
	return _stood
