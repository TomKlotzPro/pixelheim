class_name Gathering
## Gathering spots (PIX-143): patches of each wild region's material that
## the hero picks by walking over, and one patch on every dungeon floor, of
## a material that deepens with the floors. Pure, over combat.json's
## "gathering"; GameState picks, MapView draws.
##
## What grows moves with the days (PIX-250). Patches used to stand on fixed
## cells and come back every 300 steps, several times a day, so the same
## herbs waited in the same places and a long session filled the pack with
## them. Now each region's ground (the kind its patches always stood on, in
## the open, kept off the roads, the ways in and out, the villages and the
## packs' camps) is shuffled once into a deck, and each day (DayNight's, the
## one a night's sleep ends) deals its next few cards: the same day always
## grows the same patches (from the day and the seed, as the showers fall,
## so nothing new is saved), today's are never yesterday's, and the deck
## comes round again only after hundreds of days. How many a day is each
## material's daily supply ("daily", shared between the regions it grows
## in), set by its worth in the catalogue: forest herb and marsh reed (6g)
## three a day; deep root, ember shard, grave moss and sea glass (9-12g)
## two; frost lily, blackiron ore and old steel (16-20g) one, their two
## homes taking turns day by day. A patch picked stays picked until the
## next morning. There is no tool or level to pick one, as before: the
## foraging job only makes a second one likelier.

## Mixed into every shuffle and every beat: change it and every patch moves.
const SEED := 250
## How far (in cells, every way) a patch keeps from a house, a door or a
## villager's post (a village's streets are no place to forage), from a way
## in or out (a portal, the map's spawn, a waypoint's arrival), and from a
## pack's home (its camp's tent and torch stand within CAMP_REACH).
const TOWN_REACH := 4
const DOOR_REACH := 2
const CAMP_REACH := 4
## How far apart (in cells, every way) a day's patches on a map grow, so two
## never sit side by side.
const APART := 6
## Walkable tiles something stands on (a statue, a cave mouth, a doorway):
## a patch keeps a cell away from them.
const STANDING := ["shrine", "cave", "door"]


static func rules() -> Dictionary:
	return Bestiary._data()["gathering"]


## The day `steps` falls on: the turns of the day/night wheel (DayNight).
## A day starts at six in the morning, where a night's sleep wakes the hero
## (DayNight.next_morning).
static func day_of(steps: float) -> int:
	return floori(steps / DayNight.DAY_CYCLE_STEPS)


## What a wild patch grows: its region's forage material.
static func material_at(map: MapData, cell: Vector2i) -> String:
	return Bestiary._data()["regionMaterials"].get(map.region_at(cell), "")


## How many patches `region` grows a day: its material's daily supply,
## shared evenly between the regions it grows in (sea glass on the coast and
## in the sea cave). A fraction is a patch on some days only.
static func daily_in(region: String) -> float:
	var materials: Dictionary = Bestiary._data()["regionMaterials"]
	var ground: Dictionary = rules()["ground"]
	var material: String = materials.get(region, "")
	if material == "" or not ground.has(region):
		return 0.0
	var homes := ground.keys().filter(func(other: String) -> bool: return materials.get(other, "") == material).size()
	return float(rules()["daily"].get(material, 0)) / homes


## The most patches `region` grows on any one day.
static func cap_in(region: String) -> int:
	return ceili(daily_in(region))


## Where each region of `map` may grow a patch, shuffled into the deck its
## days deal from: region -> Array of cells. The ground the region's patches
## always stood on ("ground"), never a road; in the open (every neighbour
## walkable, nothing standing or growing there already, so the patch shows
## and never blocks a way); and clear of the ways in and out, the villages
## and the packs' camps. Read from the map as it loads, before a house or a
## prop is drawn over it, so it's the same with or without the paid art.
static func decks(map: MapData) -> Dictionary:
	var out := {}
	if map.floor_level > 0:
		return out
	var ground: Dictionary = rules()["ground"]
	var kept := _kept_clear(map)
	var cells: Array = map.regions.keys()
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	for cell: Vector2i in cells:
		var region: String = map.regions[cell]
		if not ground.has(region) or map.tile_at(cell) not in ground[region] or kept.has(cell):
			continue
		if Scatter.choice(map.grid, cell) >= 0 or not _in_the_open(map, cell):
			continue
		if not out.has(region):
			out[region] = []
		out[region].append(cell)
	for region: String in out:
		_shuffle(out[region], "%d:%s:%s" % [SEED, map.id, region])
	return out


## The patches a map grows on day `day`, dealt from its `decks`: cell ->
## {"id", "item"}. Each region deals its daily share from where the day
## before stopped; a fraction deals a card on the region's beat (`_beat`:
## every other day, the two homes of a material taking turns). A patch's id
## is its region's and its place in the day's deal ("forest_patch_1", the
## ids the fixed patches had), so what is picked is remembered as it always
## was (gatheredAt), and tomorrow's patch of that id is a new one.
static func patches_on(decks: Dictionary, day: int) -> Dictionary:
	var out := {}
	for region: String in decks:
		var deck: Array = decks[region]
		var rate := daily_in(region)
		if deck.is_empty() or rate <= 0.0:
			continue
		var beat := _beat(region)
		var dealt := floori(day * rate + beat)
		var today := floori((day + 1) * rate + beat) - dealt
		for k in mini(today, deck.size()):
			out[_card_apart(deck, dealt + k, out)] = {"id": "%s_patch_%d" % [region, k + 1], "item": Bestiary._data()["regionMaterials"][region]}
	return out


## Where in the day a region's deal falls, 0..1: from a start of its
## material's own, its homes spread evenly round it, so a material shared
## half and half grows in one home one day and in the other the next (old
## steel in Greyhold's courtyard, then in its cellars), never in both or
## neither.
static func _beat(region: String) -> float:
	var materials: Dictionary = Bestiary._data()["regionMaterials"]
	var material: String = materials.get(region, "")
	var homes: Array = rules()["ground"].keys().filter(func(other: String) -> bool: return materials.get(other, "") == material)
	var start := float(absi(hash("%d:%s:beat" % [SEED, material])) % 1000) / 1000.0
	return fposmod(start + float(homes.find(region)) / maxi(1, homes.size()), 1.0)


## The card at `at` in `deck`; or, when it would grow within APART of a
## patch already dealt today, the first that doesn't of the cards spread
## evenly round the deck from it (up to sixteen, at least eight cards
## apart). Those are never the cards of the day before or after (a day
## deals at most a few), so a day still never repeats the next; when none
## is far enough, the card itself.
static func _card_apart(deck: Array, at: int, dealt: Dictionary) -> Vector2i:
	var turns := clampi(deck.size() / 8, 1, 16)
	var stride := deck.size() / turns
	for turn in turns:
		var cell: Vector2i = deck[posmod(at + turn * stride, deck.size())]
		var clear := true
		for other: Vector2i in dealt:
			if maxi(absi(other.x - cell.x), absi(other.y - cell.y)) < APART:
				clear = false
				break
		if clear:
			return cell
	return deck[posmod(at, deck.size())]


## What a dungeon floor's patch grows: deeper floors, rarer finds.
static func floor_material(level: int) -> String:
	var found := ""
	for step: Array in rules()["floorMaterials"]:
		if level >= int(step[0]):
			found = step[1]
	return found


## A floor's patch has its own id, so it regrows like any other.
static func floor_spot_id(level: int) -> String:
	return "floor_%d_patch" % level


## Where a floor's patch grows on day `day` (PIX-250): one of the open cells
## of its first hall (DungeonFloor's patch_ground), dealt as the wild ones
## are, a different one each day.
static func floor_patch(ground: Array, level: int, day: int) -> Vector2i:
	var deck := ground.duplicate()
	_shuffle(deck, "%d:floor:%d" % [SEED, level])
	return deck[posmod(day, deck.size())]


## Ready to pick: never picked, or picked on an earlier day (PIX-250: it
## grows again the next morning, somewhere new).
static func is_ready(world: WorldState, spot_id: String) -> bool:
	if not world.gathered_at.has(spot_id):
		return true
	return day_of(float(world.gathered_at[spot_id])) < day_of(world.steps)


## Cells no patch grows on, around what stands on `map`: cell -> true.
static func _kept_clear(map: MapData) -> Dictionary:
	var out := {}
	for cell: Vector2i in map.grid:
		var tile: String = map.grid[cell]
		if tile.begins_with("roof") or tile.begins_with("door"):
			_mark(out, cell, TOWN_REACH)
	for npc: Dictionary in Npcs._data()["npcs"]:
		if npc["mapId"] == map.id:
			_mark(out, Vector2i(int(npc["x"]), int(npc["y"])), TOWN_REACH)
	for recruit: Dictionary in Npcs._data()["recruits"]:
		var found: Dictionary = recruit.get("found", {})
		if found.get("mapId", "") == map.id:
			_mark(out, Vector2i(int(found["x"]), int(found["y"])), TOWN_REACH)
	for portal: Vector2i in map.portals:
		_mark(out, portal, DOOR_REACH)
	_mark(out, map.spawn, DOOR_REACH)
	for waypoint: Dictionary in Interactables.waypoints():
		if waypoint["mapId"] == map.id:
			_mark(out, Vector2i(int(waypoint["arrival"]["x"]), int(waypoint["arrival"]["y"])), DOOR_REACH)
	for chest: Dictionary in Interactables.chests_on(map.id):
		_mark(out, Vector2i(int(chest["x"]), int(chest["y"])), 1)
	for spot: Dictionary in Bestiary._data().get("fishingSpots", []):
		if spot["mapId"] == map.id:
			_mark(out, Vector2i(int(spot["x"]), int(spot["y"])), 1)
	for spawn: Dictionary in Bestiary.spawns_on(map.id):
		_mark(out, Vector2i(int(spawn["x"]), int(spawn["y"])), CAMP_REACH)
	return out


static func _mark(cells: Dictionary, at: Vector2i, reach: int) -> void:
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			cells[at + Vector2i(dx, dy)] = true


## Every neighbour, corners too, is open ground: walkable, no portal, nothing
## standing on it.
static func _in_the_open(map: MapData, cell: Vector2i) -> bool:
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			var next: Vector2i = cell + Vector2i(dx, dy)
			var tile := map.tile_at(next)
			if not WorldTiles.is_walkable(tile) or tile in STANDING or map.portals.has(next):
				return false
	return true


## `cells` shuffled in place, the same way every time for the same `key`.
static func _shuffle(cells: Array, key: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	for i in range(cells.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var held: Variant = cells[i]
		cells[i] = cells[j]
		cells[j] = held


# ---- fishing (PIX-165) -------------------------------------------------------

## The places to fish from: stand there facing the water and press E.
static func fishing_spot_at(map_id: String, cell: Vector2i) -> Dictionary:
	for spot: Dictionary in Bestiary._data().get("fishingSpots", []):
		if spot["mapId"] == map_id and Vector2i(int(spot["x"]), int(spot["y"])) == cell:
			return spot
	return {}


## A fishing spot by its id, empty if there is none.
static func fishing_spot(spot_id: String) -> Dictionary:
	for spot: Dictionary in Bestiary._data().get("fishingSpots", []):
		if spot["id"] == spot_id:
			return spot
	return {}


## A spot bites again once enough steps have passed since its last catch.
static func fish_ready(world: WorldState, spot_id: String) -> bool:
	if not world.gathered_at.has(spot_id):
		return true
	return world.steps - float(world.gathered_at[spot_id]) >= float(Bestiary._data()["fishing"]["regrowSteps"])


## What comes up on the line: a weighted pick of combat.json "fishing", or
## of the spot's own "catches" (the ice hole's icefin, PIX-169).
static func catch(roll: Callable, spot := {}) -> String:
	var catches: Array = spot.get("catches", Bestiary._data()["fishing"]["catches"])
	var total := 0
	for entry: Array in catches:
		total += int(entry[1])
	var pick: float = roll.call() * total
	for entry: Array in catches:
		pick -= int(entry[1])
		if pick < 0:
			return entry[0]
	return catches[0][0]
