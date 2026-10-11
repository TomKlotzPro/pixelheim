class_name Packs
## Wild packs with homes (PIX-142): each pack lives at its spawn's home,
## wanders a few tiles from it, notices a hero it can see, gives up a chase
## that strays too far and walks home healed; one far below the hero runs
## from it instead (PIX-251). A cleared pack stays down for a while
## (respawnSteps tiles walked, or until a night at the inn) and comes back
## only where the hero can't watch it appear. Pure, over combat.json's
## "packs" numbers; enemy.gd and world.gd do the moving and drawing.
##
## The wilds keep hours (PIX-252): a spawn's "hours" says when its pack is
## out - "night" only after dark, "day" only by day, every hour without it -
## and "sleeps": "night" keeps a day pack at home asleep by its camp's fire
## after dark. Under the ground (the caves) no pack keeps hours: no sun
## reaches them, and the night there looks like the day. A night pack is a
## little stronger and drops a little more (packs.night).

const TILE := 16.0
## The cells around a cell, the straight steps before the diagonals (a tie
## goes to a straight step).
const AROUND: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
]
## How far back across the hero's way a fleeing step may lead, as the
## cosine of its angle to straight away: square to it (sideways) within its
## region; out of it, a little past square, enough to slip round a wall's
## end beside the hero's line, never back at them.
const SIDEWAYS := -0.01
const FLIGHT_SLACK := -0.3


static func rules() -> Dictionary:
	return Bestiary._data()["packs"]


static func tiles(key: String) -> float:
	return float(rules()[key]) * TILE


## Which way to wander: the pick, unless the monster has strayed past its
## leash, then straight back toward home.
static func wander_dir(home: Vector2, at: Vector2, pick: Vector2) -> Vector2:
	var back := home - at
	if back.length() <= tiles("wanderTiles"):
		return pick
	if absf(back.x) >= absf(back.y):
		return Vector2(signf(back.x), 0)
	return Vector2(0, signf(back.y))


## Close enough to notice (the line of sight and the screen are the world's).
static func within_notice(at: Vector2, hero: Vector2) -> bool:
	return at.distance_to(hero) <= tiles("noticeTiles")


## A chase is over when the monster is too far from home or the hero has
## got too far ahead.
static func gives_up(home: Vector2, at: Vector2, hero: Vector2) -> bool:
	var leash := tiles("giveUpTiles")
	return at.distance_to(home) > leash or at.distance_to(hero) > leash


## Too weak to face the hero (PIX-251): a monster fleeLevels or more below
## the hero runs instead of charging. An elite counts fleeEliteLevels above
## its kind, as it hits half again as hard and lasts longer: a slime (level
## 1) runs from a level-7 hero, an elite slime from a level-9 one. Which
## monsters may run at all is the enemy's to say (Enemy.flees_from).
static func outmatched(level: int, elite: bool, hero_level: int) -> bool:
	var counts := level + (int(rules()["fleeEliteLevels"]) if elite else 0)
	return hero_level - counts >= int(rules()["fleeLevels"])


## A fleeing monster this far from the hero has got away: it calms down and
## walks home, as a chase given up does.
static func calmed(at: Vector2, hero: Vector2) -> bool:
	return at.distance_to(hero) > tiles("calmTiles")


## A boss or a named monster never gives a chase up for a few steps
## (PIX-232: walking off used to send it home whole), but it isn't bound to
## one forever either (PIX-288: Old Greymaw hunted a hero gone far away, his
## bar across the screen and every road out of the Reach barred). These are
## its reasons; enemy.gd times them and gives up.
##
## Lost: so far behind the hero (bossLoseTiles) it's past the screen's
## edge whichever way it lies (at play zoom the screen is some 27 cells
## across). By distance alone, so a run reads the same with a window or
## without.
static func lost(at: Vector2, hero: Vector2) -> bool:
	return at.distance_to(hero) > tiles("bossLoseTiles")


## Strayed: a named monster of the wilds (Hunts.of_the_wilds) led out of its
## ground, bossLeashTiles from its lair, by a hero now beyond its notice. A
## hero fighting it at the edge of its ground keeps it there.
static func strays(home: Vector2, at: Vector2, hero: Vector2) -> bool:
	return at.distance_to(home) > tiles("bossLeashTiles") and not within_notice(at, hero)


## The cell a point of the world is in.
static func cell_of(at: Vector2) -> Vector2i:
	return Vector2i((at / TILE).floor())


## A foe's feet, centred on its position (enemy.gd's collision box).
const FEET := Vector2(10, 8)


## Whether a foe walks straight from `from` to `to` over open ground: every
## cell under its feet's corners along the way, a few pixels at a time. A
## boss charging straight at a hero across water or past a wall's end stood
## against it forever (PIX-288); where this fails it follows a route.
static func walks_straight(map: MapData, from: Vector2, to: Vector2) -> bool:
	var along := to - from
	var steps := maxi(1, ceili(along.length() / 4.0))
	var half := FEET / 2.0
	var corners: Array[Vector2] = [Vector2(-half.x, -half.y), Vector2(half.x - 0.01, -half.y), Vector2(-half.x, half.y - 0.01), half - Vector2(0.01, 0.01)]
	for i in steps + 1:
		var at := from + along * (float(i) / steps)
		for corner in corners:
			if not map.is_walkable(cell_of(at + corner)):
				return false
	return true


## The open ground of `map` within `area` (cells), to route a foe over:
## walkable cells, never a doorway or a way out (a foe never leaves its
## map). Diagonal steps only past open corners, where its feet can't catch.
static func route_grid(map: MapData, area: Rect2i) -> AStarGrid2D:
	var grid := AStarGrid2D.new()
	grid.region = area.intersection(Rect2i(Vector2i.ZERO, map.size))
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.update()
	for y in range(grid.region.position.y, grid.region.end.y):
		for x in range(grid.region.position.x, grid.region.end.x):
			var cell := Vector2i(x, y)
			if not map.is_walkable(cell) or map.portals.has(cell):
				grid.set_point_solid(cell)
	return grid


## The area a foe at `from` routes within to reach `to`: both cells and
## `margin` cells round them. A way round further than that (Greymaw's to a
## hero across the river: by the bridge, twenty cells off) is no way.
static func route_area(from: Vector2i, to: Vector2i, margin: int) -> Rect2i:
	return Rect2i(from, Vector2i.ONE).merge(Rect2i(to, Vector2i.ONE)).grow(margin)


## The way from `from` to `to` over `grid`, both cells included, or [] when
## it has none. The two ends count as open whatever they stand on (a foe's
## feet, or the hero's, may reach into a covered cell's open half).
static func route(grid: AStarGrid2D, from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not grid.is_in_boundsv(from) or not grid.is_in_boundsv(to):
		return out
	var shut := [grid.is_point_solid(from), grid.is_point_solid(to)]
	grid.set_point_solid(from, false)
	grid.set_point_solid(to, false)
	out.assign(grid.get_id_path(from, to))
	grid.set_point_solid(from, shut[0])
	grid.set_point_solid(to, shut[1])
	return out


## Where a frightened monster at `at` runs from a hero at `hero` (PIX-251):
## the step to the cell beside it that leads most straight away from the
## hero - sideways along a wall if it must - never across a blocked corner
## (its feet would catch). It heads for that cell's middle and asks again
## from there. Open ground is walkable, no doorway or way out (a monster
## never leaves its map), and not `taken` (cells it found a body in: a
## packmate, the hero). It keeps to its own `region` while a step away or
## sideways stays in it; only when none does may it step out onto other
## open ground, even a little back across the hero's way (FLIGHT_SLACK) to
## slip round a wall's end: the line between regions is nothing the player
## sees, and a monster stopped by it would seem to turn and fight for no
## reason. ZERO when no such step is open at all: it is cornered, and turns
## to fight.
static func flight_step(map: MapData, region: String, at: Vector2, hero: Vector2, taken: Array = []) -> Vector2i:
	var away := (at - hero).normalized()
	if away == Vector2.ZERO:
		away = Vector2.DOWN
	var here := Vector2i((at / TILE).floor())
	var step := _straightest_step(map, region, here, away, SIDEWAYS, taken)
	if step == Vector2i.ZERO:
		step = _straightest_step(map, "", here, away, FLIGHT_SLACK, taken)
	return step


## The middle of `cell`, where a step heads.
static func middle(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * TILE


## The step from `here` most straight along `away` onto open ground (in
## `region`, or anywhere for ""), leading no further back than `slack` (the
## cosine of its angle to `away`), or ZERO when there is none.
static func _straightest_step(map: MapData, region: String, here: Vector2i, away: Vector2, slack: float, taken: Array) -> Vector2i:
	var best := Vector2i.ZERO
	var straightest := slack
	for step in AROUND:
		var straight := Vector2(step).normalized().dot(away)
		if straight <= straightest or taken.has(here + step) or not _open_for_flight(map, region, here + step):
			continue
		if step.x != 0 and step.y != 0 and not (_open_for_flight(map, region, here + Vector2i(step.x, 0)) and _open_for_flight(map, region, here + Vector2i(0, step.y))):
			continue
		straightest = straight
		best = step
	return best


## Ground a frightened monster may run onto (flight_step): in `region`
## unless that is "".
static func _open_for_flight(map: MapData, region: String, cell: Vector2i) -> bool:
	return map.is_walkable(cell) and not map.portals.has(cell) and (region == "" or map.region_at(cell) == region)


## Whether the cells between `from` and `to` let the eye through: walls,
## mountains, roofs and whatever the map's art covers block it; water and
## low ground don't.
static func can_see(map: MapData, from: Vector2i, to: Vector2i) -> bool:
	for cell in _line(from, to):
		if cell != from and cell != to and blocks_sight(map, cell):
			return false
	return true


static func blocks_sight(map: MapData, cell: Vector2i) -> bool:
	if map.covered.has(cell):
		return true
	var tile := map.tile_at(cell)
	return tile == "mountain" or tile == "wall" or tile.begins_with("roof")


## Every cell on the straight line from `from` to `to` (Bresenham).
static func _line(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var d := Vector2i(absi(to.x - from.x), -absi(to.y - from.y))
	var step := Vector2i(1 if from.x < to.x else -1, 1 if from.y < to.y else -1)
	var error := d.x + d.y
	var at := from
	while true:
		cells.append(at)
		if at == to:
			break
		var twice := 2 * error
		if twice >= d.y:
			error += d.y
			at.x += step.x
		if twice <= d.x:
			error += d.x
			at.y += step.y
	return cells


## The packs out on `map_id` at the clock's `minute` of the day (PIX-252),
## asleep or awake, in the spawns' order: those that keep no hours, and those
## whose hours ("day" or "night") it is. The roster is decided by the hour
## alone, so nothing new is saved.
static func out_at(map_id: String, minute: int) -> Array[Dictionary]:
	var night := DayNight.night_at(minute)
	var out: Array[Dictionary] = []
	for spawn: Dictionary in Bestiary.spawns_on(map_id):
		if is_out(spawn, night):
			out.append(spawn)
	return out


## Whether a spawn's pack is out by night (`night`) or by day.
static func is_out(spawn: Dictionary, night: bool) -> bool:
	match String(spawn.get("hours", "")):
		"night":
			return night
		"day":
			return not night
	return true


## Whether a spawn's pack is asleep at home at `minute`: one that sleeps at
## night (its camp's torch lit, no roaming), after dark.
static func asleep(spawn: Dictionary, minute: int) -> bool:
	return spawn.get("sleeps", "") == "night" and DayNight.night_at(minute)


## A night pack: one that comes out only after dark. It is all of its own
## kind (Bestiary.pack_species), keeps no camp, and is stronger for it.
static func of_the_night(spawn: Dictionary) -> bool:
	return spawn.get("hours", "") == "night"


## The night's numbers (combat.json packs.night).
static func night_numbers() -> Dictionary:
	return rules()["night"]


## A night pack's monster (PIX-252): a little stronger and better paid than
## its kind by day - its health, its bite, its XP and its gold by the night's
## multipliers - and marked so its drop rolls a little luckier (night_luck).
## Its level stays its kind's, so its tag and whether it runs (PIX-251) read
## as by day. Changes `fighter` and returns it, as Bestiary.wild does.
static func by_night(fighter: Dictionary) -> Dictionary:
	var lift := night_numbers()
	var hp := roundi(float(fighter["maxHp"]) * float(lift["hp"]))
	fighter["maxHp"] = hp
	fighter["hp"] = hp
	for stat: String in ["attack", "xp", "gold"]:
		fighter[stat] = roundi(float(fighter[stat]) * float(lift[stat]))
	fighter["night"] = true
	return fighter


## What a fighter's kill adds to its drop chance: the night's loot for a
## night pack's monster, else nothing.
static func night_luck(fighter: Dictionary) -> float:
	return float(night_numbers()["loot"]) if fighter.get("night", false) else 0.0


## A cleared pack still down: cleared fewer than respawnSteps tiles ago.
## Packs cleared before steps were kept (old saves) are long overdue.
static func is_down(world: WorldState, spawn_id: String) -> bool:
	if spawn_id not in world.slain:
		return false
	var at: float = world.slain_at.get(spawn_id, -INF)
	return world.steps - at < float(rules()["respawnSteps"])


## A cleared pack whose time is up: it may come back once its home is out
## of sight.
static func is_due(world: WorldState, spawn_id: String) -> bool:
	return spawn_id in world.slain and not is_down(world, spawn_id)
