class_name Telegraph
## A danger marked on the ground before it lands (PIX-150, shared by the
## bosses and, PIX-155, the elites): a red shape with a bright edge that
## pulses for its tell, then calls `strike` with the shape so the caster can
## hurt whoever still stands in it, then flashes and fades. Shape helpers
## build the usual lines and circles in map pixels.

const COLOR := Color(1.0, 0.18, 0.08, 0.32)
const EDGE := Color(1.0, 0.62, 0.2, 0.95)


## Draws `shape` over the ground (under everyone standing on it) and strikes
## after `tell` seconds. Returns the mark (freed by itself after the strike).
static func mark(world: Node, shape: PackedVector2Array, tell: float, strike: Callable) -> Polygon2D:
	var shown := Polygon2D.new()
	shown.polygon = shape
	shown.color = COLOR
	# A bright edge so the mark reads on grass, stone and water alike.
	var edge := Line2D.new()
	edge.points = shape
	edge.closed = true
	edge.width = 1.5
	edge.default_color = EDGE
	shown.add_child(edge)
	world.add_child(shown)
	world.move_child(shown, 3)
	var pulse := shown.create_tween()
	pulse.tween_property(shown, "color:a", 0.6, tell * 0.5)
	pulse.tween_property(shown, "color:a", 0.35, tell * 0.5)
	pulse.tween_callback(func() -> void:
		if strike.is_valid():
			strike.call(shown.polygon)
		var flash := shown.create_tween()
		flash.tween_property(shown, "color", Color(1.0, 0.75, 0.3, 0.7), 0.06)
		flash.tween_property(shown, "color:a", 0.0, 0.25)
		flash.tween_callback(shown.queue_free)
	)
	return shown


static func circle(center: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 20:
		points.append(center + Vector2.RIGHT.rotated(TAU * i / 20.0) * radius)
	return points


## A band from `from` toward `toward`, `length` long and `width` wide.
static func band(from: Vector2, toward: Vector2, length: float, width: float) -> PackedVector2Array:
	var along := (toward - from).normalized()
	if along == Vector2.ZERO:
		along = Vector2.DOWN
	var across := along.orthogonal() * width / 2.0
	var tip := along * length
	return PackedVector2Array([from + across, from + tip + across, from + tip - across, from - across])


## Whether the hero stands in a struck shape.
static func catches(world: Node, shape: PackedVector2Array) -> bool:
	var player: CharacterBody2D = world.player
	return not player.dead and Geometry2D.is_point_in_polygon(player.global_position, shape)
