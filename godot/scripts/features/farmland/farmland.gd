class_name Farmland
## areas: travel field night +overworld*
## The farmland round Pixelheim's walls on the Reach, by the town's age
## (PIX-397, step 1). The v0.307 audit found bare grass, dark patches and
## stumps round the walls, a third of the town's decor, and the land unlit
## at night. It grows as the town does (GameState.town_tier, as Yards):
## - the Ashes: one plot by the north road, dug but trampled bare;
## - the Hamlet: that plot sown and sprouting, a scarecrow over it;
## - the Village: a second plot and a wheat field, a fenced pasture by the
##   north road, and lamps along the road out of the gate;
## - the Town: the crops grown, a second wheat field, an orchard and a
##   farmstead below the south wall (hay, a cart, a well, firewood, sacks);
## - the City: the full farmland, ripe: a vegetable field, a wheat field and
##   a second pasture by the orchard, the orchard's third row, more lamps.
## Every piece is the Medieval Age's (tilled soil, crops, wheat, small
## trees, hay, sacks, a basket, a well, log fences) or HamletArt's (carts
## and a woodpile), laid as a settlement's dressing is (Hamlet.plan's `grown`): fields
## lie flat, what stands blocks open ground and never closes a way. All of
## it lies in the open ground round the town that no foe region takes, off
## the roads, the gate's fork, the settlers found there and the spawn, and
## nothing stands under a fork's signpost or on a lamp's lantern
## (test_farmland). The pastures' animals are FarmAnimals'. Only with the
## paid pack, as the town's houses and yards. Pure: MapView draws it.

const MAP := "overworld"

## The Medieval Age's tilled soil, its furrows a nine-slice by row (top,
## middle, bottom) and column (left, middle, right).
const SOIL := [[3508, 3509, 3510], [3728, 3729, 3730], [3948, 3949, 3950]]
## A crop in the furrows as it grows: sprouts, leaves, heads, ripe cabbages;
## the town's age picks the stage, the Hamlet's sprouts to the City's ripe.
const CROPS := [3651, 3652, 3653, 3654]
## Wheat standing in a block, a nine-slice as the soil's: turning in the
## Village and the Town, gold in the City. The pack's green stage reads as a
## lawn, not a field, so it's left out.
const WHEAT := [
	[[1748, 1749, 1750], [1968, 1969, 1970], [2188, 2189, 2190]],
	[[2628, 2629, 2630], [2848, 2849, 2850], [3068, 3069, 3070]],
]
## The orchard's young trees, a berry bush, hay, sacks, a basket, the
## scarecrow and the small stone well.
const TREES := [16, 1338, 1342]
const BERRIES := 2660
const HAY := 2787
const SACKS := 1900
const BASKET := 1235
const SCARECROW := 3005
const WELL := 3444

## Fields: a rect of tilled soil with its crop in rows (`veg`) or
## a block of wheat, and the age it's dug at.
const FIELDS := [
	{"rect": Rect2i(41, 36, 4, 2), "crop": "veg", "age": 0},
	{"rect": Rect2i(36, 36, 4, 2), "crop": "veg", "age": 2},
	{"rect": Rect2i(36, 39, 4, 2), "crop": "wheat", "age": 2},
	{"rect": Rect2i(41, 39, 4, 2), "crop": "wheat", "age": 3},
	{"rect": Rect2i(52, 60, 4, 2), "crop": "veg", "age": 4},
	{"rect": Rect2i(57, 60, 4, 2), "crop": "wheat", "age": 4},
]
## Pastures: a ring of log fence round `rect`, open at `gate`. The ring is
## laid from beside the gate round to its other side, so each post leaves
## the ground round it one (Hamlet.fits) until the gate is all that's open;
## clear of the forest's pack by the road and of the mountain's foot.
const PASTURES := [
	{"rect": Rect2i(56, 35, 5, 6), "gate": Vector2i(58, 40), "age": 2},
	{"rect": Rect2i(34, 57, 6, 4), "gate": Vector2i(37, 57), "age": 4},
]
## Each piece placed by hand, as Yards' (`tile` the pack's, `art` ours,
## `flat` lying on the ground), with its set and the age it comes at; a
## `lamp` is the town's street lamp, lit at night.
const PIECES := [
	# The Hamlet: a scarecrow over the first plot.
	{"tile": SCARECROW, "cell": Vector2i(40, 36), "set": "farmstead", "age": 1},
	# The Village: lamps along the road out of the gate, hay between the
	# plots (by the road, over the gate's west lamp, it sat on its lantern).
	{"lamp": true, "cell": Vector2i(46, 37), "set": "wayside", "age": 2},
	{"lamp": true, "cell": Vector2i(50, 37), "set": "wayside", "age": 2},
	{"tile": HAY, "cell": Vector2i(40, 38), "set": "farmstead", "age": 2},
	# The Town: the orchard's first rows and the farmstead's yard below the
	# south wall.
	{"tile": TREES[0], "cell": Vector2i(42, 57), "set": "orchard", "age": 3},
	{"tile": TREES[1], "cell": Vector2i(44, 57), "set": "orchard", "age": 3},
	{"tile": TREES[2], "cell": Vector2i(46, 57), "set": "orchard", "age": 3},
	{"tile": TREES[0], "cell": Vector2i(43, 59), "set": "orchard", "age": 3},
	{"tile": TREES[1], "cell": Vector2i(45, 59), "set": "orchard", "age": 3},
	{"tile": TREES[2], "cell": Vector2i(47, 59), "set": "orchard", "age": 3},
	{"tile": HAY, "cell": Vector2i(53, 57), "set": "farmstead", "age": 3},
	{"tile": HAY, "cell": Vector2i(54, 57), "set": "farmstead", "age": 3},
	{"art": "cart", "cell": Vector2i(56, 57), "set": "farmstead", "age": 3},
	{"tile": WELL, "cell": Vector2i(59, 57), "set": "farmstead", "age": 3},
	{"art": "woodpile", "cell": Vector2i(61, 57), "set": "farmstead", "age": 3},
	{"tile": SACKS, "cell": Vector2i(58, 57), "set": "farmstead", "age": 3},
	# The City: the full farmland.
	{"tile": TREES[2], "cell": Vector2i(42, 61), "set": "orchard", "age": 4},
	{"tile": TREES[0], "cell": Vector2i(44, 61), "set": "orchard", "age": 4},
	{"tile": TREES[1], "cell": Vector2i(46, 61), "set": "orchard", "age": 4},
	{"tile": BERRIES, "cell": Vector2i(47, 57), "set": "orchard", "age": 4},
	{"art": "handcart", "cell": Vector2i(58, 59), "set": "farmstead", "age": 4},
	{"tile": BASKET, "cell": Vector2i(52, 57), "set": "farmstead", "age": 4},
	{"tile": HAY, "cell": Vector2i(35, 38), "set": "farmstead", "age": 4},
	{"tile": SCARECROW, "cell": Vector2i(56, 60), "set": "farmstead", "age": 4},
	# Off column 46 at row 35: a lamp there stands its lantern over the
	# gate fork's signpost at (46, 34) (test_farmland).
	{"lamp": true, "cell": Vector2i(45, 35), "set": "wayside", "age": 4},
	{"lamp": true, "cell": Vector2i(51, 35), "set": "wayside", "age": 4},
]


## The farmland at `age` (GameState.town_tier) on `map`: Hamlet.plan's
## `grown` entries, fields first (they lie under what stands on them). None
## off the Reach or without the pack (`paid`).
static func plan(map: MapData, age: int, paid: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not paid or map.id != MAP:
		return out
	for field: Dictionary in FIELDS:
		if int(field["age"]) <= age:
			out.append_array(field_pieces(field["rect"], field["crop"], age))
	for pasture: Dictionary in PASTURES:
		if int(pasture["age"]) <= age:
			out.append_array(fence(pasture["rect"], pasture["gate"]))
	for entry: Dictionary in PIECES:
		if int(entry["age"]) <= age:
			out.append(entry)
	return out


## A field's flat pieces at `age`: its soil (or its wheat) cell by cell from
## the nine-slice, and a row of crops along each of the soil's, its stage the
## age's; none in the Ashes, the plot trampled bare.
static func field_pieces(rect: Rect2i, crop: String, age: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var crops: Array[Dictionary] = []
	var slice: Array = WHEAT[clampi(age - 3, 0, WHEAT.size() - 1)] if crop == "wheat" else SOIL
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var cell := Vector2i(x, y)
			var tile: int = slice[_part(y, rect.position.y, rect.end.y - 1)][_part(x, rect.position.x, rect.end.x - 1)]
			out.append({"tile": tile, "cell": cell, "flat": true, "set": "field", "age": age})
			if crop == "veg" and age > 0:
				crops.append({"tile": CROPS[clampi(age - 1, 0, CROPS.size() - 1)], "cell": cell, "flat": true, "set": "field", "age": age})
	return out + crops


## Which third of a nine-slice `at` takes between `first` and `last`.
static func _part(at: int, first: int, last: int) -> int:
	return 0 if at == first else (2 if at == last else 1)


## A pasture's fence round `rect`, open at `gate`: Shade's log fence joined
## to its neighbours (PunyProps.FENCE), each post a standing piece, laid
## from the gate round to its other side.
static func fence(rect: Rect2i, gate: Vector2i) -> Array[Dictionary]:
	var ring: Array[Vector2i] = []
	for x in range(rect.position.x, rect.end.x):
		ring.append(Vector2i(x, rect.position.y))
	for y in range(rect.position.y + 1, rect.end.y):
		ring.append(Vector2i(rect.end.x - 1, y))
	for x in range(rect.end.x - 2, rect.position.x - 1, -1):
		ring.append(Vector2i(x, rect.end.y - 1))
	for y in range(rect.end.y - 2, rect.position.y, -1):
		ring.append(Vector2i(rect.position.x, y))
	var start := ring.find(gate)
	var posts := ring.slice(start + 1) + ring.slice(0, start)
	var out: Array[Dictionary] = []
	for cell: Vector2i in posts:
		var mask := 0
		for bit: Array in [[Vector2i.UP, 1], [Vector2i.RIGHT, 2], [Vector2i.DOWN, 4], [Vector2i.LEFT, 8]]:
			if (cell + bit[0]) in posts:
				mask |= bit[1]
		out.append({"tile": PunyProps.FENCE[mask], "cell": cell, "set": "pasture", "age": 0})
	return out


## The report's farmland=: the town's age and the pieces laid by set
## (`pieces`, the view's dressing): 4:farmstead12,field72,orchard10,pasture32,wayside4.
static func describe(pieces: Array) -> String:
	var sets := {}
	for piece: Dictionary in pieces:
		if piece.has("set"):
			sets[piece["set"]] = int(sets.get(piece["set"], 0)) + 1
	var names: Array = sets.keys()
	names.sort()
	return "%d:%s" % [GameState.town_tier(), ",".join(names.map(func(name: String) -> String: return "%s%d" % [name, sets[name]]))]
