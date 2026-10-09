class_name Telegraph
## A danger marked on the ground before it lands (PIX-150, shared by the
## bosses and, PIX-155, the elites): a red shape with a bright edge (hazard
## stripes with a dark outline under clear warnings, PIX-160) that pulses
## for its tell, then calls `strike` with the shape so the caster can hurt
## whoever still stands in it, then flashes and fades. Shape helpers build
## the usual lines and circles in map pixels.

const COLOR := Color(1.0, 0.18, 0.08, 0.32)
const EDGE := Color(1.0, 0.62, 0.2, 0.95)


## Draws `shape` over the ground (under everyone standing on it) and strikes
## after `tell` seconds. Returns the mark (freed by itself after the strike).
## A mark is heard as it's drawn and as it strikes (PIX-210), unless `heard`
## is false (a bite's band under clear warnings, whose foe blips its own tell).
static func mark(world: Node, shape: PackedVector2Array, tell: float, strike: Callable, heard := true) -> Polygon2D:
	var shown := Polygon2D.new()
	shown.polygon = shape
	shown.color = COLOR
	var clear := GameState.settings.clear_warnings
	# Clear warnings (PIX-160): hazard stripes and a dark outline, read by
	# their pattern rather than their red.
	if clear:
		shown.texture = _stripes()
		shown.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		shown.color = Color(1, 1, 1, 0.5)
		var outline := Line2D.new()
		outline.points = shape
		outline.closed = true
		outline.width = 4.0
		outline.default_color = UiStyle.NIGHT
		shown.add_child(outline)
	# A bright edge so the mark reads on grass, stone and water alike.
	var edge := Line2D.new()
	edge.points = shape
	edge.closed = true
	edge.width = 2.0 if clear else 1.5
	edge.default_color = UiStyle.GOLD if clear else EDGE
	shown.add_child(edge)
	# A warning reads in the dark as by day (PIX-221).
	Lights.unshade(shown)
	world.add_child(shown)
	world.move_child(shown, 3)
	if heard:
		Sound.play_ui("mark")
	var pulse := shown.create_tween()
	pulse.tween_property(shown, "color:a", 0.6, tell * 0.5)
	pulse.tween_property(shown, "color:a", 0.35, tell * 0.5)
	pulse.tween_callback(func() -> void:
		if strike.is_valid():
			strike.call(shown.polygon)
		if heard:
			Sound.play_ui("slam")
		var flash := shown.create_tween()
		flash.tween_property(shown, "color", Color(1, 1, 1, 0.95) if clear else Color(1.0, 0.75, 0.3, 0.7), 0.06)
		flash.tween_property(shown, "color:a", 0.0, 0.25)
		flash.tween_callback(shown.queue_free)
	)
	return shown


static var _hazard: ImageTexture


## Diagonal gold and dark stripes, four pixels each, tiling.
static func _stripes() -> ImageTexture:
	if _hazard == null:
		var art := Image.create(8, 8, false, Image.FORMAT_RGBA8)
		for y in 8:
			for x in 8:
				art.set_pixel(x, y, UiStyle.GOLD if (x + y) % 8 < 4 else UiStyle.NIGHT)
		_hazard = ImageTexture.create_from_image(art)
	return _hazard


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
