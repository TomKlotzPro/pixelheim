class_name Packs
## Wild packs with homes (PIX-142): each pack lives at its spawn's home,
## wanders a few tiles from it, notices a hero it can see, gives up a chase
## that strays too far and walks home healed. A cleared pack stays down for a
## while (respawnSteps tiles walked, or until a night at the inn) and comes
## back only where the hero can't watch it appear. Pure, over combat.json's
## "packs" numbers; enemy.gd and world.gd do the moving and drawing.

const TILE := 16.0


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
