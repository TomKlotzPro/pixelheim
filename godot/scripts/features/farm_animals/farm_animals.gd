class_name FarmAnimals
extends MapLayer
## areas: town night
## Pixelheim's farm animals by its age (PIX-387, the village's step 2): hens
## and chicks pecking round the farmhouses and kitchen gardens, sheep on the
## meadow by the river, pigs in the sty by the east field, cows and the bull
## in the field along the river's bank. A few hens in the Hamlet, more
## of everything in the Village, the whole farmyard in the Town and the
## City; none in the Ashes. Each animal has a small patch of the town by
## hand (`HERD`) and wanders it a cell at a time (Herd), never onto a road,
## a door or its step, a villager's place or pacing, a stall, wherever the
## story stands someone (Yards.kept) or what the yards lay. The hero bumps
## into them and they step aside from him (Herd, PIX-389); they're no
## foes. Drawn from ninth-jedi's Farm Animals, a paid pack
## (scripts/fetch-private-art.sh), at two thirds of its size (Herd.SCALE):
## without it, none. The plan is pure (`plan_herd`).

const MAP := "town"
const FOLDER := "res://assets/puny/animals"
## Each sheet's kind, as the report counts them.
const KINDS := {"chicken1": "hen", "chicken2": "hen", "chick": "chick", "sheep": "sheep", "pig": "pig", "cow": "cow", "bull": "bull"}

## Their patches: Maren's back yard; inside the sty fenced between the east
## field, the road and the wall (the town map's, its gate on the road); the
## lane between the two cottages and their gardens; the yard behind the
## house by the inn; the meadow by the east lawn's garden; the field along
## the river's bank, a column short of the water (a cow is wider than its
## cell: on the bank's last column its tail stood in the river).
const MARENS_YARD := Rect2i(18, 4, 8, 2)
const STY := Rect2i(78, 18, 4, 2)
const COTTAGES := Rect2i(9, 28, 6, 5)
const UPPER_YARD := Rect2i(57, 4, 7, 2)
const MEADOW := Rect2i(50, 28, 8, 5)
const RIVER_FIELD := Rect2i(63, 21, 3, 9)

## Each animal by hand: its sheet, its patch and the age it comes at.
const HERD := [
	# The Hamlet: a few hens about Maren's and the sty by the east field.
	{"sheet": "chicken1", "pen": MARENS_YARD, "age": 1},
	{"sheet": "chicken2", "pen": MARENS_YARD, "age": 1},
	{"sheet": "chicken2", "pen": STY, "age": 1},
	# The Village: chicks, the cottages' hens, sheep, pigs and a cow.
	{"sheet": "chick", "pen": MARENS_YARD, "age": 2},
	{"sheet": "chick", "pen": MARENS_YARD, "age": 2},
	{"sheet": "chicken1", "pen": COTTAGES, "age": 2},
	{"sheet": "chicken2", "pen": COTTAGES, "age": 2},
	{"sheet": "chick", "pen": COTTAGES, "age": 2},
	{"sheet": "sheep", "pen": MEADOW, "age": 2},
	{"sheet": "sheep", "pen": MEADOW, "age": 2},
	{"sheet": "sheep", "pen": MEADOW, "age": 2},
	{"sheet": "pig", "pen": STY, "age": 2},
	{"sheet": "pig", "pen": STY, "age": 2},
	{"sheet": "cow", "pen": RIVER_FIELD, "age": 2},
	# The Town, and the City after it: the whole farmyard.
	{"sheet": "chicken1", "pen": UPPER_YARD, "age": 3},
	{"sheet": "chicken2", "pen": UPPER_YARD, "age": 3},
	{"sheet": "chick", "pen": UPPER_YARD, "age": 3},
	{"sheet": "chick", "pen": UPPER_YARD, "age": 3},
	{"sheet": "chick", "pen": COTTAGES, "age": 3},
	{"sheet": "sheep", "pen": MEADOW, "age": 3},
	{"sheet": "sheep", "pen": MEADOW, "age": 3},
	{"sheet": "pig", "pen": STY, "age": 3},
	{"sheet": "cow", "pen": RIVER_FIELD, "age": 3},
	{"sheet": "bull", "pen": RIVER_FIELD, "age": 3},
]
## Their walk's and their sleep's frames a second.
const FPS := {"walk": 6.0, "sleep": 2.0}

static var _frames := {}


## The town's animals at `age` (GameState.town_tier) on `map`, clear of
## `kept` (`kept_on`): {sheet, kind, cell (where it starts), area (the cells
## it may stand on)}, each on a cell of its own. None without the pack.
static func plan_herd(map: MapData, age: int, kept: Dictionary, paid: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not paid or map.id != MAP:
		return out
	var taken := {}
	for index in HERD.size():
		var entry: Dictionary = HERD[index]
		if int(entry["age"]) > age:
			continue
		var pen: Rect2i = entry["pen"]
		var area: Array[Vector2i] = []
		for y in range(pen.position.y, pen.end.y):
			for x in range(pen.position.x, pen.end.x):
				if grazes(map, kept, Vector2i(x, y)):
					area.append(Vector2i(x, y))
		# Its first cell spread from its pen-mates': the first free one from
		# a place of its own in the patch.
		for step in area.size():
			var cell := area[(index * 11 + step) % area.size()]
			if not taken.has(cell):
				taken[cell] = true
				out.append({"sheet": entry["sheet"], "kind": KINDS[entry["sheet"]], "cell": cell, "area": area})
				break
	return out


## Whether an animal may stand on `cell`: open ground, no road or square,
## no door nor the step before one, nothing `kept` clear.
static func grazes(map: MapData, kept: Dictionary, cell: Vector2i) -> bool:
	var tile := map.tile_at(cell)
	return map.is_walkable(cell) and tile not in Hamlet.WAYS and not tile.begins_with("door") \
		and not map.portals.has(cell) and not map.tile_at(cell + Vector2i.UP).begins_with("door") and not kept.has(cell)


## What the animals keep clear of on `map`: what a settlement's dressing
## does (Hamlet.kept_on, its patches `decks`), every villager's place and
## pacing and the story's spots at every age (Yards.kept), and the cells of
## what the yards lay (`pieces`, Hamlet.plan's: a hen in the cabbages).
static func kept_on(map: MapData, decks: Variant, pieces: Array) -> Dictionary:
	var out := Hamlet.kept_on(map, decks)
	out.merge(Yards.kept(map))
	for piece: Dictionary in pieces:
		for cell: Vector2i in piece["cells"]:
			out[cell] = true
	return out


## Where an animal on `cell` steps next in its `area`: a cell beside it no
## other stands on or is bound for (`taken`), by its own `dice`; its own
## cell when there's none.
static func step(area: Array[Vector2i], cell: Vector2i, taken: Dictionary, dice: RandomNumberGenerator) -> Vector2i:
	var open: Array[Vector2i] = []
	for way: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if area.has(cell + way) and not taken.has(cell + way):
			open.append(cell + way)
	return cell if open.is_empty() else open[dice.randi() % open.size()]


## Whether the pack is here (and not held back: the harness's `cc0`).
static func available() -> bool:
	return not PunyTown.withheld and ResourceLoader.exists("%s/cow_walk1.png" % FOLDER)


## A sheet's walk and sleep, four frames each, made once a session.
static func frames(sheet: String) -> SpriteFrames:
	if not _frames.has(sheet):
		var out := SpriteFrames.new()
		for anim: String in FPS:
			out.add_animation(anim)
			out.set_animation_speed(anim, FPS[anim])
			for n in range(1, 5):
				out.add_frame(anim, load("%s/%s_%s%d.png" % [FOLDER, sheet, anim, n]))
		_frames[sheet] = out
	return _frames[sheet]


## The herd, wandering among the actors once the yards are laid.
func build(view: MapView, slices: Slicer) -> void:
	# Without the pack, nothing to plan: kept_on's merge isn't free.
	if view.data.id != MAP or not available():
		return
	slices.add("decor_animals", func() -> void:
		var herd := plan_herd(view.data, GameState.town_tier(), kept_on(view.data, view.patch_decks, view.hamlet["pieces"]), true)
		if herd.is_empty():
			return
		var node := Herd.new(herd, view.actors)
		view.actors.add_child(node)
		view.set_meta("herd", node))


## Asleep where they stand from dusk's end to dawn.
func set_night(view: MapView, night: bool) -> void:
	# get_meta's default can't be null: a missing key with it is an error.
	var herd: Variant = view.get_meta("herd") if view.has_meta("herd") else null
	if is_instance_valid(herd):
		herd.sleep(night)
