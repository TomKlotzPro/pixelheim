class_name GateArt
## areas: travel story +overworld*
## What a shut gate looks like (PIX-254, Gates): the road still there and the
## land past it in sight, something drawn across it that blocks like any
## prop. The cliff road's rockfall is a heap of fallen stone tallest in the
## middle, the ruins' greys in three sizes with a broken trunk in it, its
## scree fanned out flat on the road before it (PIX-556); the river bridge
## burnt on the Night of Ash is its planks gone in the middle, the ruins'
## charred posts standing in the water and a burnt log drifting; Ulla's
## barricade is a log fence and crates across the Greyhold road, one of her
## old guard in front of it; the avalanche on the Frostgate road is a bank of
## snow in lumps, shaded on its east side, a snowed pine snapped and lying
## half buried in its crest, sparkling by day (PIX-556). The heap, its scree
## and the bank are drawn here in code in Shade's palette (RuinArt's stones,
## HamletArt's inks), the same with or without the paid pack (PunyProps);
## the pine is the Medieval Age's with it and ours without, its snapped
## trunk ours in both; without it the fence and the crates are the
## dungeon's palisade; the rest is CC0.
## Pure but for texture(): MapView draws the pieces, and its bodies stop the
## hero on the gate's cells.

const TILE := 16
## A piece: on `cell`, its sprite's top-left `at` px from the cell's (a
## standing one's bottom `at.y` below its cell's bottom), from `sheet`
## ("world": PunyTerrain's, "dungeon": PunyDungeon's, "props": the paid
## Medieval Age's, "villager": PunyArt's, `sprite` its id, "gate": drawn
## here, `sprite` its name, "glint": HamletArt's sparkle), `tone`
## ("charred" or ""), `flat` lying on the ground under everyone; sorted among
## the actors on its own foot otherwise. `turn`: laid on its side, its top
## to the west; `day`: shown by day only; `cast`: ours, standing on the
## ground, casting the sun's shadow.
const DRIFTWOOD := 703
## Shade's log fence down a run (PunyProps.FENCE by N=1, S=4): its top,
## middle and bottom posts; his crate; the CC0 dungeon's palisade.
const FENCE_TOP := 3643
const FENCE_RUN := 3863
const FENCE_END := 4083
const POST := 4303
const CRATE := 1024
const PALISADE := 460
const DUNGEON_POST := 512
## How dark a burnt post is.
const CHARRED := Color(0.42, 0.34, 0.3)

## The rockfall (PIX-556): the heap's picture, a little wider than the road
## so it lies against the cliffs, the ground it covers that deep along its
## bottom and its foot this far below its cell's (it fills the pass's last
## row too, a way on that nothing grows on); the scree's picture, flat
## before it and no wider than the road's dirt, its bottom this far up from
## the heap's foot, just under its crest, so its thickest band shows.
const HEAP := Vector2i(54, 44)
const HEAP_DEPTH := 18
const HEAP_DROP := 12
const SCREE := Vector2i(34, 20)
const HEAP_BACK := 30
## How far its foot reaches from its middle (px; a big stone's spill short
## of the picture's sides), how tall it stands at its middle, how sharp its
## peak (1 a cone), and how far its outline wanders in and out along its
## front and back (a share of its reach; its ends stay in the picture).
const HEAP_REACH := Vector2(24, 9.5)
const HEAP_PEAK := 24
const HEAP_POINT := 1.0
const HEAP_WOBBLE := 0.12
## Its stones in three sizes, small, middle and big (from the least to the
## most of each): this many, smaller the higher they lie, sunk a third into
## the heap; each the ruins' plain or sooty stone (RuinArt.STONE) in one of
## three lights, sunlit up top, plain, darker on its east side, so the heap
## keeps a few fixed inks as the ruins do.
const STONE_LEAST: Array[Vector2i] = [Vector2i(4, 3), Vector2i(6, 5), Vector2i(9, 7)]
const STONE_MOST: Array[Vector2i] = [Vector2i(5, 5), Vector2i(8, 7), Vector2i(12, 10)]
const STONE_COUNT := 160
const STONE_LIGHTS := [1.0, 0.88, 0.76]
## Two big ones rolled to its foot, in front, on the picture.
const ROLLED: Array[Rect2i] = [Rect2i(1, 36, 11, 8), Rect2i(40, 37, 10, 7)]
## The broken trunk lying across its front: its splintered end (sticking out
## past the heap's west shoulder) and its root end, buried, on the picture,
## laid among the stones on this row of the ground.
const TRUNK_FROM := Vector2i(5, 19)
const TRUNK_TO := Vector2i(27, 30)
const TRUNK_ROW := 15
## How many pebbles the scree has.
const PEBBLES := 64

## The avalanche (PIX-556): the bank's picture, a little wider than the
## road, the ground it covers that deep along its bottom; the domes of snow
## it's heaped of, on that ground, each its middle (x, y) and its (radius x,
## radius y, height) in px, every one inside the picture, so its ends are
## round: a long low bank, lumps on it.
const BANK := Vector2i(62, 46)
const BANK_DEPTH := 26
const DOMES: Array[AABB] = [
	AABB(Vector3(31, 13, 0), Vector3(30, 12, 9)),
	AABB(Vector3(14, 9, 0), Vector3(12, 8, 15)), AABB(Vector3(30, 7, 0), Vector3(13, 7, 18)),
	AABB(Vector3(46, 10, 0), Vector3(11, 8, 14)), AABB(Vector3(7, 17, 0), Vector3(7, 7, 8)),
	AABB(Vector3(22, 18, 0), Vector3(10, 7, 10)), AABB(Vector3(38, 19, 0), Vector3(10, 6, 9)),
	AABB(Vector3(53, 17, 0), Vector3(7, 8, 11)),
]
## The light on it, from the north-west and above, and snow's tones by how
## much falls (HamletArt's inks), `y` in the sun to `W` in the shade; its
## east end this much darker; its rim `S`, `w` along the ground.
const SUN := Vector3(-0.55, -0.15, 0.82)
const SNOW_TONES := [[0.76, "y"], [0.44, "s"], [0.16, "S"], [-2.0, "W"]]
const EAST_SHADE := 0.25
## The snapped pine: the Medieval Age's tall snowy pine (its crown's tile,
## its trunk's under it), or ours; where it lies across the bank's crest
## from the cell behind the bank's, half of it behind the crest, half
## against the road beyond. Ours: its picture, lying, its crown's tiers of
## needles this long from its tip, each this long, and its trunk's
## splintered end; with the pack its trunk and break alone lie under the
## Medieval Age's crown.
const PINE_TOP := 2216
const PINE_AT := Vector2(-15, 5)
const PINE := Vector2i(45, 16)
const PINE_CROWN := 30
const PINE_TIER := 6
const PINE_BREAK := Vector2i(39, 5)
## The sparkles by day, on its lit crest: each on the bank's foot row x
## cells from its middle, (y, z) px from that cell's top-left.
const GLINTS: Array[Vector3] = [Vector3(-1, -1, -27), Vector3(0, -2, -31), Vector3(1, -4, -25)]

static var _drawn := {}


## The pieces of `gate`'s look, and the cells whose own objects (a bridge's
## planks) aren't drawn while it's shut: {pieces: [piece], hides: [cell]}.
## `paid`: the Medieval Age pack is here (PunyProps.available()).
static func plan(gate: Dictionary, paid: bool) -> Dictionary:
	var cells := Gates.cells_of(gate)
	match String(gate["look"]):
		"rockfall":
			return {"pieces": _rockfall(cells), "hides": []}
		"burnt_bridge":
			return {"pieces": _burnt_bridge(cells, paid), "hides": cells}
		"barricade":
			return {"pieces": _barricade(cells, paid), "hides": []}
		"avalanche":
			return {"pieces": _avalanche(cells, paid), "hides": []}
	return {"pieces": [], "hides": []}


static func _piece(cell: Vector2i, sheet: String, tile: int, at: Vector2, tone := "", flat := false) -> Dictionary:
	return {"cell": cell, "sheet": sheet, "tile": tile, "sprite": "", "at": at, "tone": tone, "flat": flat}


## One of ours, drawn here (texture()), casting unless it lies flat.
static func _ours(cell: Vector2i, name: String, at: Vector2, flat := false) -> Dictionary:
	var piece := _piece(cell, "gate", -1, at, "", flat)
	piece["sprite"] = name
	piece["cast"] = not flat
	return piece


## The heap across the middle of the road, its scree before it.
static func _rockfall(cells: Array[Vector2i]) -> Array[Dictionary]:
	var middle := cells[cells.size() / 2]
	return [
		_ours(middle + Vector2i.UP, "scree", Vector2((TILE - SCREE.x) / 2, 2 * TILE + HEAP_DROP - SCREE.y - HEAP_BACK), true),
		_ours(middle, "rockfall", Vector2((TILE - HEAP.x) / 2, HEAP_DROP)),
	]


## The middle of the span gone: charred posts where its planks were, a
## burnt log in the water.
static func _burnt_bridge(cells: Array[Vector2i], paid: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var post_sheet := "props" if paid else "dungeon"
	var post := POST if paid else DUNGEON_POST
	var west := cells[0].x
	for cell: Vector2i in cells:
		var side := -6.0 if cell.x == west else 6.0
		out.append(_piece(cell, post_sheet, post, Vector2(side, -3 + (absi(hash(cell)) >> 4) % 6), "charred"))
	out.append(_piece(cells[-1], "world", DRIFTWOOD, Vector2(-9, -6), "charred", true))
	return out


## A log fence down the road's width, crates at its ends, and one of
## Ulla's old guard in front of it between them, facing whoever comes up
## the road.
static func _barricade(cells: Array[Vector2i], paid: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in cells.size():
		var cell := cells[i]
		var fence := FENCE_RUN if i > 0 and i < cells.size() - 1 else (FENCE_TOP if i == 0 else FENCE_END)
		out.append(_piece(cell, "props" if paid else "dungeon", fence if paid else PALISADE, Vector2(4, 0)))
		if i != cells.size() / 2:
			out.append(_piece(cell, "props" if paid else "dungeon", CRATE if paid else PALISADE, Vector2(-2, 1)))
	var guard := _piece(cells[cells.size() / 2], "villager", -1, Vector2(-1, 0))
	guard["sprite"] = "guard"
	out.append(guard)
	return out


## A bank of snow across the road, a snapped pine lying half buried on its
## crest (sorted behind it), a few sparkles on it by day (in front of it).
static func _avalanche(cells: Array[Vector2i], paid: bool) -> Array[Dictionary]:
	var low := cells[0]
	var high := cells[0]
	for cell: Vector2i in cells:
		low = Vector2i(mini(low.x, cell.x), mini(low.y, cell.y))
		high = Vector2i(maxi(high.x, cell.x), maxi(high.y, cell.y))
	var middle := Vector2i((low.x + high.x) / 2, high.y)
	var behind := Vector2i(middle.x, low.y - 1)
	# Ours first, so the Medieval Age's crown lies over its trunk's end; it
	# lies on the bank, so casts nothing on the road.
	var out: Array[Dictionary] = [_ours(behind, "snag" if paid else "pine", PINE_AT)]
	out[0]["cast"] = false
	if paid:
		for i in 2:
			var crown := _piece(behind, "props", PINE_TOP + i * PunyTown.COLUMNS, PINE_AT + Vector2(i * TILE, 0))
			crown["turn"] = true
			out.append(crown)
	out.append(_ours(middle, "avalanche", Vector2((TILE - BANK.x) / 2, 0)))
	for glint: Vector3 in GLINTS:
		var sparkle := _piece(middle + Vector2i(int(glint.x), 0), "glint", -1, Vector2(glint.y, glint.z))
		sparkle["day"] = true
		out.append(sparkle)
	return out


## Our piece `name` ("rockfall", "scree", "avalanche", "pine" or "snag"),
## drawn once a session, the same every time.
static func texture(name: String) -> Texture2D:
	if not _drawn.has(name):
		var dice := RandomNumberGenerator.new()
		dice.seed = hash(name)
		var image: Image
		match name:
			"rockfall":
				image = _heap(dice)
			"scree":
				image = _scree(dice)
			"pine", "snag":
				image = _pine(name == "pine")
			_:
				image = _bank()
		_drawn[name] = ImageTexture.create_from_image(image)
	return _drawn[name]


## The rockfall's heap: a dark bed of grit raised tallest in the middle,
## its stones lying on it back to front (small and sunlit up top, big at the
## foot, the east side a shade darker), the broken trunk among them, two
## boulders rolled to its foot.
static func _heap(dice: RandomNumberGenerator) -> Image:
	var image := Image.create(HEAP.x, HEAP.y, false, Image.FORMAT_RGBA8)
	var middle := Vector2(HEAP.x - 1, HEAP_DEPTH - 1) / 2.0
	var height := func(x: int, y: int) -> float:
		var off := (Vector2(x, y) - middle) / HEAP_REACH
		var angle := off.angle()
		# The wobble fades toward its ends (sin 0), so they stay inside.
		var d := off.length() / (1.0 + HEAP_WOBBLE * absf(sin(angle)) * (sin(3.0 * angle + 1.3) + 0.6 * sin(5.0 * angle + 2.1)))
		return HEAP_PEAK * pow(1.0 - d, HEAP_POINT) if d < 1.0 else 0.0
	# Its stones by the row of the ground they lie on.
	var stones := {}
	var tints: Array = [Color.WHITE, RuinArt.STONE["ash"]]
	for i in STONE_COUNT:
		var at := Vector2i(dice.randi_range(0, HEAP.x - 1), dice.randi_range(0, HEAP_DEPTH - 1))
		var h: float = height.call(at.x, at.y)
		if h <= 0.0:
			continue
		var high := h / HEAP_PEAK
		var kind := dice.rand_weighted(PackedFloat32Array([6, 4, 0] if high > 0.6 else ([3, 5, 2] if high > 0.3 else [1, 4, 5])))
		var size := Vector2i(dice.randi_range(STONE_LEAST[kind].x, STONE_MOST[kind].x), dice.randi_range(STONE_LEAST[kind].y, STONE_MOST[kind].y))
		# On the heap, so its ends slope down to the road.
		var west: float = height.call(at.x - size.x / 3, at.y)
		var east: float = height.call(at.x + size.x / 3, at.y)
		if west <= 0.0 or east <= 0.0:
			continue
		var bottom := HEAP.y - HEAP_DEPTH + at.y - roundi(h) + size.y / 3
		var light: float = STONE_LIGHTS[2 if at.x > middle.x + HEAP_REACH.x / 3.0 else (0 if high > 0.6 else 1)]
		var tint: Color = tints[dice.randi() % tints.size()] * light
		var row: Array = stones.get(at.y, [])
		row.append([Rect2i(at.x - size.x / 2, bottom - size.y + 1, size.x, size.y), Color(tint, 1.0)])
		stones[at.y] = row
	var grit := func(_x: int, _y: int, normal: Vector3) -> Color:
		return RuinArt.INKS["F" if normal.x < -0.3 else ("J" if normal.x > 0.4 else "B")]
	_raise(image, HEAP_DEPTH, height, grit, func(y: int) -> void:
		for stone: Array in stones.get(y, []):
			var rect: Rect2i = stone[0]
			var tint: Color = stone[1]
			RuinArt.stone(image, rect, tint)
		if y == TRUNK_ROW:
			_trunk(image, TRUNK_FROM, TRUNK_TO))
	var sooty: Color = RuinArt.STONE["ash"]
	for rolled: Rect2i in ROLLED:
		RuinArt.stone(image, rolled, sooty if rolled.position.x > middle.x else Color.WHITE)
	var outline: Color = RuinArt.INKS["J"]
	_rim(image, outline, outline)
	return image


## A pine's trunk lying from its splintered end `from` (the pale wood of
## the break, sticking out) to `to`, east or west of it, in HamletArt's
## woods: lit along its top, its bark streaked.
static func _trunk(image: Image, from: Vector2i, to: Vector2i) -> void:
	var inks := HamletArt.INKS
	var run := to - from
	var way := signi(run.x)
	for i in absi(run.x) + 1:
		var top := from + Vector2i(i * way, roundi(float(i) * run.y / absi(run.x)))
		var bark := PackedStringArray(["o", "3", "2", "1" if i % 5 == 2 else "2", "1", "o"] if i > 0 else ["o", "5", "6", "5", "4", "o"])
		for row in bark.size():
			var ink: Color = inks[bark[row]]
			image.set_pixelv(top + Vector2i(0, row), ink)
	# The break: splinters of pale wood, each ending in a dark tip.
	var reaches := PackedInt32Array([1, 3, 0, 2])
	for row in range(1, 5):
		var reach := reaches[row - 1]
		for k in range(1, reach + 2):
			var ink: Color = inks["o" if k > reach else ("6" if k < reach else "5")]
			image.set_pixelv(from + Vector2i(-k * way, row), ink)


## The avalanche's snapped pine, ours, lying: its crown's tiers of needles
## to the west, widening from its tip, each drooping back toward the trunk,
## snow along their tops; its trunk running east out of them to the break.
## `crown` false: the trunk and its break alone (under the Medieval Age's).
static func _pine(crown: bool) -> Image:
	var image := Image.create(PINE.x, PINE.y, false, Image.FORMAT_RGBA8)
	_trunk(image, PINE_BREAK, Vector2i(PINE_CROWN - PINE_TIER, PINE_BREAK.y))
	if crown:
		var inks := HamletArt.INKS
		var mid := PINE_BREAK.y + 2
		for x in range(1, PINE_CROWN):
			var reach := roundi((2.5 + 4.5 * x / PINE_CROWN) * (0.65 + 0.35 * (x % PINE_TIER) / (PINE_TIER - 1.0)))
			for y in range(mid - reach, mid + reach + 1):
				var depth := y - (mid - reach)
				image.set_pixel(x, y, inks["y" if depth == 1 else ("s" if depth == 2 else ("F" if y < mid else ("f" if y < mid + reach - 1 else "t")))])
	var outline: Color = HamletArt.INKS["o"]
	_rim(image, outline, outline)
	return image


## The scree before the heap: pebbles and grit lying flat, thickest along
## the picture's bottom (just under the heap's crest) and thinning out up
## the road, in the ruins' greys.
static func _scree(dice: RandomNumberGenerator) -> Image:
	var image := Image.create(SCREE.x, SCREE.y, false, Image.FORMAT_RGBA8)
	var inks := RuinArt.INKS
	var lower: Color = inks["F"]
	var shadow: Color = inks["B"]
	for i in PEBBLES:
		var reach := pow(dice.randf(), 1.8)
		var spread := (1.0 - 0.5 * reach) * (SCREE.x / 2.0 - 3)
		var size := Vector2i(dice.randi_range(1, 3), dice.randi_range(1, 2))
		var at := Vector2i(roundi(SCREE.x / 2.0 + dice.randf_range(-1.0, 1.0) * spread), SCREE.y - 3 - roundi(reach * (SCREE.y - 5)))
		for x in size.x:
			var top: Color = inks["L" if size.y == 2 else "CEI"[dice.randi() % 3]]
			image.set_pixelv(at + Vector2i(x, 0), top)
			if size.y == 2:
				image.set_pixelv(at + Vector2i(x, 1), lower)
		if size.x > 1:
			# Its shadow on the ground.
			image.set_pixelv(at + Vector2i(size.x - 1, size.y), shadow)
	return image


## The avalanche's bank: its domes of snow raised back to front, each point
## lit by its slope from the west and above and the east end darker, a rim
## round it all.
static func _bank() -> Image:
	var image := Image.create(BANK.x, BANK.y, false, Image.FORMAT_RGBA8)
	var inks := HamletArt.INKS
	var height := func(x: int, y: int) -> float:
		var top := 0.0
		for dome: AABB in DOMES:
			var d := (Vector2(x, y) - Vector2(dome.position.x, dome.position.y)) / Vector2(dome.size.x, dome.size.y)
			if d.length_squared() < 1.0:
				top = maxf(top, dome.size.z * sqrt(1.0 - d.length_squared()))
		return top
	var sun := SUN.normalized()
	var snow := func(x: int, _y: int, normal: Vector3) -> Color:
		var lit := normal.dot(sun) - EAST_SHADE * clampf((x - BANK.x * 0.55) / (BANK.x * 0.45), 0.0, 1.0)
		for tone: Array in SNOW_TONES:
			if lit > tone[0]:
				return inks[tone[1]]
		return inks["W"]
	_raise(image, BANK_DEPTH, height, snow, func(_y: int) -> void: pass)
	var rim: Color = inks["S"]
	var lip: Color = inks["w"]
	_rim(image, rim, lip)
	return image


## Ground `depth` px deep along `image`'s bottom raised to `height`
## (Callable(x, y) -> px, 0 off it), drawn back to front: each point a
## column from the ground up in `ink` (Callable(x, y, its normal) -> Color),
## then `row` (Callable(y)) lays what lies on that row of the ground, so the
## rows in front hide what they should.
static func _raise(image: Image, depth: int, height: Callable, ink: Callable, row: Callable) -> void:
	# Each point's height once, with a point's margin round them for slopes.
	var wide := image.get_width() + 2
	var heights := PackedFloat32Array()
	heights.resize(wide * (depth + 2))
	for y in depth + 2:
		for x in wide:
			heights[y * wide + x] = height.call(x - 1, y - 1)
	for y in depth:
		var ground := image.get_height() - depth + y
		for x in image.get_width():
			var at := (y + 1) * wide + x + 1
			var h := heights[at]
			if h <= 0.0:
				continue
			var slope := Vector3(heights[at - 1] - heights[at + 1], heights[at - wide] - heights[at + wide], 2.0)
			var color: Color = ink.call(x, y, slope.normalized())
			for up in range(maxi(0, ground - roundi(h)), ground + 1):
				image.set_pixel(x, up, color)
		row.call(y)


## Every drawn pixel of `image` beside an empty one in `side`, or in
## `bottom` when the empty one is below it (where it meets the ground).
static func _rim(image: Image, side: Color, bottom: Color) -> void:
	var size := image.get_size()
	var bounds := Rect2i(Vector2i.ZERO, size)
	for y in size.y:
		for x in size.x:
			if image.get_pixel(x, y).a == 0.0:
				continue
			var below := Vector2i(x, y + 1)
			if not bounds.has_point(below) or image.get_pixelv(below).a == 0.0:
				image.set_pixel(x, y, bottom)
				continue
			for beside: Vector2i in [Vector2i(x - 1, y), Vector2i(x + 1, y), Vector2i(x, y - 1)]:
				if not bounds.has_point(beside) or image.get_pixelv(beside).a == 0.0:
					image.set_pixel(x, y, side)
					break
