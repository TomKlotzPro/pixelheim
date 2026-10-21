class_name Lamps
## areas: travel field night +overworld*
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
## Each lamp is of a kind (PIX-324, Something to Come Back To's step 5), from
## its region's material, paid for with its work on the town's board: a
## look (RouteArt) and one rule (KINDS). Once Aske lives in Pixelheim he
## keeps the lamps trimmed as he does the courier's lantern: every ring a
## third wider (`wider`, his `lantern` share).
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
## The lamps' kinds and their one rule each: `reach`, cells more a ring
## reaches (sea glass, Saltmere's: the glass carries the light); `rate`,
## cells it grows a morning (frost lily, the Frostgate's: it heals twice as
## fast); `clears`, the air that thins inside its ring besides the Ash's
## (grave moss, the Mirefen's: its fog). An ember lamp is PIX-323's.
const KINDS := {
	"ember": {}, "sea_glass": {"reach": 1}, "frost_lily": {"rate": 2}, "grave_moss": {"clears": "mire"},
}
## A lamp whose ground has healed (its ring whole) draws something by
## morning (PIX-324): some mornings a find at its foot, now and then
## someone from the village out to see it. Mixed into every roll; how many
## mornings in a hundred bring a find, and a visitor.
const SEED := 324
const FIND_CHANCE := 40
const VISIT_CHANCE := 25
## What turns up at a lamp: a lost thing, a traveller's thank-you, a bite
## to eat, and twice as often its own region's material (KIND_FINDS).
const FINDS := ["apple", "bread", "cheese_wheel", "forest_herb", "potion_hp", "old_boot"]
const KIND_FINDS := {"ember": "ember_shard", "sea_glass": "sea_glass", "frost_lily": "frost_lily", "grave_moss": "grave_moss"}
## Lamps standing closer than this (cells, either way) share one light: the
## first keeps its own, the others only their halo, a cheaper light, so
## dozens along a road stay within the light budget (test_night_light).
const LIGHT_APART := 4


## The lit lamps on `map_id` on day `day` (Gathering.day_of): each one's
## cell, its kind, how far its ring reaches once whole ("reach": its kind's,
## a share `wider` more, Aske's) and the cells it has grown ("mornings": its
## kind's rate for each morning since it was lit). A lamp with no day kept
## (built before the day was saved) has burnt long enough to be whole.
static func rings(map_id: String, settlement: SettlementState, post: PostState, day: int, wider := 0.0) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for lamp: Dictionary in Routes.lamps(settlement):
		if lamp["mapId"] == map_id:
			var rule: Dictionary = KINDS.get(lamp["kind"], {})
			var whole := roundi((REACH + int(rule.get("reach", 0))) * (1.0 + wider))
			var lit := int(post.lit.get(lamp["place"], day - whole))
			out.append({"place": lamp["place"], "cell": lamp["cell"], "kind": lamp["kind"], "reach": whole, "mornings": maxi(0, day - lit) * int(rule.get("rate", 1))})
	return out


## The rings on `map_id` today, as the hero's state stands (Aske trimming
## them once he's home).
static func now(map_id: String) -> Array[Dictionary]:
	if map_id != Routes.MAP:
		return []
	return rings(map_id, GameState.settlement, GameState.post, Gathering.day_of(GameState.world.steps), GameState.holdings.settler_share("lantern"))


## How far a ring reaches `mornings` after its lamp was lit, `whole` once
## it has grown.
static func reach(mornings: int, whole := REACH) -> int:
	return mini(mornings, whole)


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
			best = maxi(best, mini(int(ring["mornings"]) - d + 1, int(ring.get("reach", REACH)) + 1 - d))
	return clampi(best, 0, SAPLINGS)


## Whether `cell` lies inside `ring` as far as it has grown: nothing the day
## its lamp is lit.
static func inside(cell: Vector2i, ring: Dictionary) -> bool:
	return int(ring["mornings"]) > 0 and distance(cell, ring["cell"]) <= reach(ring["mornings"], ring.get("reach", REACH))


## Whether `cell` lies inside a ring.
static func shelters(cell: Vector2i, rings: Array[Dictionary]) -> bool:
	return rings.any(func(ring: Dictionary) -> bool: return inside(cell, ring))


## Whether the air `air` thins at `cell` within `rings`: the Ash's heat and
## embers inside any ring, and the air a ring's kind clears inside its own
## (grave moss: the Mirefen's fog).
static func clears(air: String, cell: Vector2i, rings: Array[Dictionary]) -> bool:
	return rings.any(func(ring: Dictionary) -> bool:
		return (air == "ash" or KINDS.get(ring.get("kind", ""), {}).get("clears", "") == air) and inside(cell, ring))


## Whether a pack's spawn stays home: a night pack whose home lies inside a
## ring never rises.
static func keeps_off(spawn: Dictionary, rings: Array[Dictionary]) -> bool:
	return Packs.of_the_night(spawn) and shelters(Vector2i(int(spawn["x"]), int(spawn["y"])), rings)


## The ash of `grid` healed by `rings`: cell -> what it's drawn as (LOOKS).
static func healed(grid: Dictionary, rings: Array[Dictionary]) -> Dictionary:
	var out := {}
	for ring: Dictionary in rings:
		var lamp: Vector2i = ring["cell"]
		var r := reach(ring["mornings"], ring.get("reach", REACH))
		for y in range(lamp.y - r, lamp.y + r + 1):
			for x in range(lamp.x - r, lamp.x + r + 1):
				var cell := Vector2i(x, y)
				if grid.get(cell, "") == "ash" and not out.has(cell):
					var grown := stage(cell, rings)
					if grown > 0:
						out[cell] = LOOKS[grown]
	return out


## What the map calls a wild region as the land round the lamps heals
## (PIX-325): the last of its `renamed` names (combat.json's regions) whose
## `healed` cells have healed, its own name before any: the Ash Fields,
## then the Greening, then the Lantern Meadows.
static func region_name(region: Dictionary, healed_cells: int) -> String:
	var name := String(region.get("name", ""))
	for entry: Dictionary in region.get("renamed", []):
		if healed_cells >= int(entry["healed"]):
			name = String(entry["name"])
	return name


## The last count of healed cells, by the map and its rings today.
static var _counted := {}


## How many of `map`'s ash cells have healed round its lamps today: worked
## out again only when the day or the lamps change, not each time a name is
## asked (the place's card asks as the hero walks).
static func healed_on(map: MapData) -> int:
	var rings := now(map.id)
	var key := str([map.id, rings])
	if not _counted.has(key):
		_counted = {key: healed(map.grid, rings).size()}
	return int(_counted[key])


## Whether `ring` has grown as far as it goes: its lamp's ground healed.
static func whole(ring: Dictionary) -> bool:
	return int(ring["mornings"]) >= int(ring.get("reach", REACH))


## A roll for the lamp on the road to `place` on day `day`, for `what`:
## the same every time, from the day alone, as the patches and the showers.
static func _roll(day: int, place: String, what: String) -> int:
	return absi(hash("%d:%d:%s:%s" % [SEED, day, place, what]))


## The finds lying by the healed lamps among `rings` on day `day`: cell ->
## {id, item}, as Gathering deals a patch (picked by walking over it, gone
## until the next morning, when another may lie there).
static func finds(rings: Array[Dictionary], day: int) -> Dictionary:
	var out := {}
	for ring: Dictionary in rings:
		var roll := _roll(day, ring["place"], "find")
		if not whole(ring) or roll % 100 >= FIND_CHANCE:
			continue
		var table: Array = FINDS + [KIND_FINDS[ring["kind"]], KIND_FINDS[ring["kind"]]]
		out[Routes.lamp_of(ring["place"])["find"]] = {"id": "lamp_find_%s" % ring["place"], "item": table[(roll >> 7) % table.size()]}
	return out


## Who has come out to the healed lamps among `rings` on day `day`, as
## Npcs.on_map gives villagers: someone from the village (post.json's
## routes `visitors`) standing by the lamp, saying what they came for; two
## lamps the same morning never the same one.
static func visitors(rings: Array[Dictionary], day: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var folk: Array = Routes._data()["visitors"]
	for i in rings.size():
		var ring: Dictionary = rings[i]
		if not whole(ring) or _roll(day, ring["place"], "visit") % 100 >= VISIT_CHANCE:
			continue
		var who: Dictionary = folk[(_roll(day, "", "who") + i) % folk.size()]
		var npc := Npcs.by_id(String(who["npc"]), [])
		var at: Vector2i = Routes.lamp_of(ring["place"])["visit"]
		out.append({
			"id": "lamp_visitor_%s" % ring["place"], "mapId": Routes.MAP, "x": at.x, "y": at.y, "wander": false,
			"name": npc["name"], "sprite": npc["sprite"], "lines": who["lines"],
		})
	return out


## The lamps among `cells` that carry a light of their own, in order: each
## at least LIGHT_APART cells from every one lit before it.
static func lit_among(cells: Array[Vector2i]) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for cell: Vector2i in cells:
		if not out.any(func(other: Vector2i) -> bool: return maxi(absi(other.x - cell.x), absi(other.y - cell.y)) < LIGHT_APART):
			out.append(cell)
	return out
