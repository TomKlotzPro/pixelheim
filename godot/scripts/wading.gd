class_name Wading
extends RefCounted
## areas: field combat +mirefen*
## Wading through shallow water (PIX-548: the Mirefen's strips beside its
## boardwalks looked like water that should stop the hero, who walked
## through them dry): on a cell of MapData.shallows a figure's feet sink
## SINK pixels of its art, cut by a waterline in the water's lip
## (fighter.gdshader's `wade`: the sprite drawn lower and its rows under the
## line gone, so nothing that moves the sprite is touched), and as it moves
## a ring spreads from under it every STRIDE pixels, in whole pixels that
## thin out, never fade; none with Reduce motion. It costs nothing: the
## shallows are walked as any open ground. The hero (World) and the foes
## (Enemy) wade; the villagers share one material and keep to their roads.

## How far a wader's feet sink, in pixels of its art: the hero stands 14
## tall on legs of 3, so one row of leg still shows over the waterline.
const SINK := 2
## A ring every so many pixels waded, spreading over RIPPLE_SECONDS through
## RINGS' frames.
const STRIDE := 10.0
const RIPPLE_SECONDS := 0.6
## A ring's half width in each frame, half as tall (seen from above the
## ground), and the share of its pixels still drawn: it breaks up as it
## spreads.
const RINGS: Array[Vector2] = [Vector2(3, 1.0), Vector2(4, 1.0), Vector2(5, 0.8), Vector2(6, 0.55), Vector2(7, 0.3)]
const RING_SIZE := Vector2i(16, 8)
## The mire's foam (inland_water.gdshaderinc's water_foam).
const LIP := Color(0.66, 0.7, 0.5)

static var _rings: ImageTexture


## `figure` (its `sprite` wearing the fighters' material) as it stands this
## tick, in the shallows (`deep`) or out of them: sunk or not, and a ring
## from under it where it has waded STRIDE since its last.
static func tread(figure: Node2D, sprite: AnimatedSprite2D, deep: bool) -> void:
	if deep != figure.has_meta(&"waded"):
		sink(sprite, deep)
		if deep:
			figure.set_meta(&"waded", figure.global_position)
		else:
			figure.remove_meta(&"waded")
	if not deep or GameState.settings.reduce_motion:
		return
	var last: Vector2 = figure.get_meta(&"waded")
	if figure.global_position.distance_to(last) >= STRIDE:
		figure.set_meta(&"waded", figure.global_position)
		ripple(figure, sprite)


## Sinks `sprite` into the water to its waterline, or stands it back out.
static func sink(sprite: AnimatedSprite2D, deep: bool) -> void:
	var material := sprite.material as ShaderMaterial
	if material == null:
		return
	material.set_shader_parameter("wade", float(SINK) if deep else 0.0)
	material.set_shader_parameter("wade_foot", foot(sprite))


## How far `sprite` is sunk, in pixels of its art: 0 out of the water.
static func sunk(sprite: AnimatedSprite2D) -> int:
	var material := sprite.material as ShaderMaterial
	if material == null or material.get_shader_parameter("wade") == null:
		return 0
	return roundi(float(material.get_shader_parameter("wade")))


## The row under `sprite`'s soles in its own pixels, from its middle, on the
## frame it stands in facing the player (as its shadow is measured).
static func foot(sprite: AnimatedSprite2D) -> float:
	var frames := sprite.sprite_frames
	var frame := frames.get_frame_texture(PunyArt.pick(frames, "idle", "down"), 0)
	return Ink.used(frame).end.y - frame.get_height() / 2.0


## A ring on the water under `figure`, at its waterline: beside it in its
## parent, under every figure as the shadows are, gone when it has spread.
static func ripple(figure: Node2D, sprite: AnimatedSprite2D) -> void:
	var parent := figure.get_parent()
	if parent == null:
		return
	var ring := Sprite2D.new()
	ring.texture = rings()
	ring.hframes = RINGS.size()
	ring.z_as_relative = false
	ring.position = (figure.position + Vector2(0, sprite.position.y + foot(sprite) * sprite.scale.y)).round()
	parent.add_child(ring)
	var spread := ring.create_tween()
	spread.tween_property(ring, "frame", RINGS.size() - 1, RIPPLE_SECONDS)
	spread.tween_callback(ring.queue_free)


## The rings' frames side by side: each an ellipse a pixel thick in the
## lip's colour, whole pixels, the later ones with pixels left out.
static func rings() -> ImageTexture:
	if _rings == null:
		_rings = ImageTexture.create_from_image(draw_rings())
	return _rings


static func draw_rings() -> Image:
	var image := Image.create(RING_SIZE.x * RINGS.size(), RING_SIZE.y, false, Image.FORMAT_RGBA8)
	for n in RINGS.size():
		var reach := RINGS[n].x
		for y in RING_SIZE.y:
			for x in RING_SIZE.x:
				var d := Vector2(x + 0.5 - RING_SIZE.x / 2.0, (y + 0.5 - RING_SIZE.y / 2.0) * 2.0).length()
				if absf(d - reach) < 0.75 and (absi(hash(Vector3i(x, y, n))) % 100) / 100.0 < RINGS[n].y:
					image.set_pixel(n * RING_SIZE.x + x, y, LIP)
	return image
