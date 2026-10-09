class_name Packs
## Wild packs with homes (PIX-142): each pack lives at its spawn's home,
## wanders a few tiles from it, notices a hero it can see, gives up a chase
## that strays too far and walks home healed; one far below the hero runs
## from it instead (PIX-251). A cleared pack stays down for a while
## (respawnSteps tiles walked, or until a night at the inn) and comes back
## only where the hero can't watch it appear. Pure, over combat.json's
## "packs" numbers; enemy.gd and world.gd do the moving and drawing.

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
