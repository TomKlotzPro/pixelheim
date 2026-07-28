class_name Discovery
## Fog-of-war bookkeeping, ported from src/world/discover.ts: the hero sees
## SIGHT_RADIUS tiles around themselves (Chebyshev), and what was seen stays
## seen. `discovered` is map_id -> Dictionary(Vector2i -> true), session-only
## until saves land (PIX-122).

const SIGHT_RADIUS := 2


static func discover_around(discovered: Dictionary, map: MapData, cell: Vector2i) -> void:
	var seen: Dictionary = discovered.get_or_add(map.id, {})
	for dy in range(-SIGHT_RADIUS, SIGHT_RADIUS + 1):
		for dx in range(-SIGHT_RADIUS, SIGHT_RADIUS + 1):
			var target := cell + Vector2i(dx, dy)
			var in_bounds := (
				target.x >= 0 and target.y >= 0
				and target.x < map.size.x and target.y < map.size.y
			)
			if in_bounds:
				seen[target] = true


static func is_discovered(discovered: Dictionary, map_id: String, cell: Vector2i) -> bool:
	return discovered.get(map_id, {}).has(cell)
