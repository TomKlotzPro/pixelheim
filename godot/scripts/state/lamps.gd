class_name Lamps
## The land heals round the lamps (PIX-323, Something to Come Back To's step
## 4): each waystation's ember lamp (Routes.lamps), lit the day it was built,
## pushes a ring of green one cell further into the ash each morning, up to
## REACH cells. From the ash in to the lamp the healed ground goes bare
## earth, grass, flowers, saplings: the ring's front is bare earth, and
## behind it the land grows a stage each morning, so a lamp's ring is whole
## REACH mornings after it was lit. Only the ash heals: the roads, the rock
## and the green land stay as they are, and nothing changes what anyone
## walks on (MapView draws the healed ground as its look: Shade's dirt and
## grass on the dual grid, so its edge is soft, and the v0.243 scorch gives
## way there).
## Inside a lamp's ring the night is kinder: no night pack rises there
## (`keeps_off`), and the Ash's heat and embers fade over it (`shelters`:
## Weather reads the air cell by cell).
## Saved: only the day each lamp was lit (PostState.lit); the rest is worked
## out from the days since.

## How far a ring reaches once whole, in cells.
const REACH := 5
## The stages of healed ground, ash (0) to saplings.
const EARTH := 1
const GRASS := 2
const FLOWERS := 3
const SAPLINGS := 4
## What each stage is drawn as (MapView.look; PunyTerrain and Scatter know
## them): bare earth, grass, a meadow in flower, a grove of saplings.
const LOOKS := ["ash", "earth", "grass", "meadow", "grove"]
## Lamps standing closer than this (cells, either way) share one light: the
## first keeps its own, the others only their halo, a cheaper light, so
## dozens along a road stay within the light budget (test_night_light).
const LIGHT_APART := 4


## The lit lamps on `map_id` on day `day` (Gathering.day_of): each one's
## cell and the mornings since it was lit. A lamp with no day kept (built
## before the day was saved) has burnt long enough for its ring to be whole.
static func rings(map_id: String, settlement: SettlementState, post: PostState, day: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for lamp: Dictionary in Routes.lamps(settlement):
		if lamp["mapId"] == map_id:
			var lit := int(post.lit.get(lamp["place"], day - REACH))
			out.append({"cell": lamp["cell"], "mornings": maxi(0, day - lit)})
	return out


## The rings on `map_id` today, as the hero's state stands.
static func now(map_id: String) -> Array[Dictionary]:
	if map_id != Routes.MAP:
		return []
	return rings(map_id, GameState.settlement, GameState.post, Gathering.day_of(GameState.world.steps))


## How far a ring reaches `mornings` after its lamp was lit.
static func reach(mornings: int) -> int:
	return mini(mornings, REACH)


## How far `cell` lies from a lamp at `lamp`, in whole cells: rounded, so
## a ring is round.
static func distance(cell: Vector2i, lamp: Vector2i) -> int:
	return roundi(Vector2(cell - lamp).length())


## The stage of the ground at `cell` within `rings` (0: no ring reaches it).
## A cell `d` from its lamp is reached the d-th morning and grows a stage
## each morning after, up to the stage its place in the whole ring allows:
## bare earth at the ring's edge, saplings nearest the lamp.
static func stage(cell: Vector2i, rings: Array[Dictionary]) -> int:
	var best := 0
	for ring: Dictionary in rings:
		if inside(cell, ring):
			var d := distance(cell, ring["cell"])
			best = maxi(best, mini(int(ring["mornings"]) - d + 1, REACH + 1 - d))
	return clampi(best, 0, SAPLINGS)


## Whether `cell` lies inside `ring` as far as it has grown: nothing the day
## its lamp is lit.
static func inside(cell: Vector2i, ring: Dictionary) -> bool:
	return int(ring["mornings"]) > 0 and distance(cell, ring["cell"]) <= reach(ring["mornings"])


## Whether `cell` lies inside a ring.
static func shelters(cell: Vector2i, rings: Array[Dictionary]) -> bool:
	return rings.any(func(ring: Dictionary) -> bool: return inside(cell, ring))


## Whether a pack's spawn stays home: a night pack whose home lies inside a
## ring never rises.
static func keeps_off(spawn: Dictionary, rings: Array[Dictionary]) -> bool:
	return Packs.of_the_night(spawn) and shelters(Vector2i(int(spawn["x"]), int(spawn["y"])), rings)


## The ash of `grid` healed by `rings`: cell -> what it's drawn as (LOOKS).
static func healed(grid: Dictionary, rings: Array[Dictionary]) -> Dictionary:
	var out := {}
	for ring: Dictionary in rings:
		var lamp: Vector2i = ring["cell"]
		var r := reach(ring["mornings"])
		for y in range(lamp.y - r, lamp.y + r + 1):
			for x in range(lamp.x - r, lamp.x + r + 1):
				var cell := Vector2i(x, y)
				if grid.get(cell, "") == "ash" and not out.has(cell):
					var grown := stage(cell, rings)
					if grown > 0:
						out[cell] = LOOKS[grown]
	return out


## The lamps among `cells` that carry a light of their own, in order: each
## at least LIGHT_APART cells from every one lit before it.
static func lit_among(cells: Array[Vector2i]) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for cell: Vector2i in cells:
		if not out.any(func(other: Vector2i) -> bool: return maxi(absi(other.x - cell.x), absi(other.y - cell.y)) < LIGHT_APART):
			out.append(cell)
	return out
