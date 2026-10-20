class_name Lights
## Light and darkness (PIX-221). The world itself darkens with the hour (a
## CanvasModulate the LightRig sets) instead of a dark veil laid over it, and
## real lights - lamps, windows, fires, torches, spells, the hero's lantern -
## pierce the dark. This holds the colours of the day, the one soft light
## shape every light shares, and the materials that let flames and the
## world's own words (damage numbers, prompts, health bars) stay bright at
## night. Pure helpers; the LightRig does the per-frame work.

const DAY := Color(1, 1, 1)
## Gold at dawn, orange at dusk, a deep blue night the lights cut through.
const DAWN := Color(1.0, 0.86, 0.72)
const DUSK := Color(1.0, 0.86, 0.74)
const NIGHT := Color(0.3, 0.34, 0.56)
## Under the mountain and in caves: a cold dark the torches warm.
const UNDERGROUND := Color(0.36, 0.34, 0.46)
## The Night of Ash: the sky red with the burning village.
const ASH_NIGHT := Color(0.56, 0.34, 0.32)
## Indoors: a little dim and warm by day, so the day through the windows
## pools on the floor below them; at night dark but where the hearth and the
## candles burn, the corners left in shadow (PIX-311: rooms were lit flat by
## day and only a little darker at night).
const INDOOR_DAY := Color(0.86, 0.82, 0.77)
const INDOOR_NIGHT := Color(0.4, 0.35, 0.4)
## [position in the day's wheel 0..1 (DayNight), the world's light then].
const DAY_LIGHT := [
	[0.0, DAY], [0.45, DAY], [0.53, DUSK], [0.62, NIGHT],
	[0.86, NIGHT], [0.93, DAWN], [1.0, DAY],
]
## The shapes' colours: warm flame, a window's candle, cold magic.
const FIRE := Color(1.0, 0.62, 0.3)
const LAMP := Color(1.0, 0.76, 0.45)
const WINDOW := Color(1.0, 0.8, 0.5)
const LANTERN := Color(1.0, 0.82, 0.58)
## A waystation's ember lamp (PIX-322): the mountain's warmth, redder than a
## street lamp's flame.
const EMBER := Color(1.0, 0.6, 0.34)
## A candle or a sconce in a room (PIX-311), and the day through a room's
## window.
const CANDLE := Color(1.0, 0.7, 0.38)
const SUN := Color(1.0, 0.95, 0.82)
## The ice cave's frozen floors (PIX-255): a cold light the ice gives back.
const ICE := Color(0.62, 0.84, 1.0)
## A way out of a dungeon once its boss is down (PIX-292): daylight, pale
## and warm, that breathes.
const WAY_OUT := Color(1.0, 0.93, 0.74)
## How strong each kind of light is at full dark. A 2D light adds to the
## night before the colours are multiplied, so near 1 it washes the ground
## out: these keep a lamp's pool warm, not white.
const LAMP_ENERGY := 0.42
const FIRE_ENERGY := 0.55
## A burning house's pools (PIX-285): fewer lights over it than it had
## flames, so each a little stronger.
const BLAZE_ENERGY := 0.8
const TORCH_ENERGY := 0.7
const WINDOW_ENERGY := 0.36
const LANTERN_ENERGY := 0.3
const EMBER_ENERGY := 0.5
const CANDLE_ENERGY := 0.55
## The sun through a window at noon: added to a room a little dim by day.
const SUN_ENERGY := 0.85
const ICE_ENERGY := 0.22
const WAY_OUT_ENERGY := 0.5
## How far a breathing light swells and fades, a share of its energy, and
## how fast (radians a second).
const PULSE_DEPTH := 0.3
const PULSE_SPEED := 3.0
## The size of the shared light texture, in pixels.
const TEXTURE_PX := 256
## How many lights Godot lights one canvas item with, in both renderers
## (its MAX_LIGHTS_PER_ITEM less one, PIX-285): the lights past these that
## reach it light the items beside it but not it, and stop at its edge.
## MapView draws tile layers in small blocks so none is reached by more.
const PER_ITEM := 15
## The floor's own light bit (PIX-314): the ground's and the dungeons' floor
## layers answer to it besides the world's lights (MapView), and a light
## that lights only it (`range_item_cull_mask`) falls on the floor alone -
## a boss's glow round its feet, under every actor and pickup standing in
## it, none of them tinted.
const FLOOR := 1 << 10


## The open air's light at `steps` on the day's wheel.
static func outdoor(steps: float) -> Color:
	var t := fposmod(steps, float(DayNight.DAY_CYCLE_STEPS)) / DayNight.DAY_CYCLE_STEPS
	var i := 0
	while i < DAY_LIGHT.size() - 2 and float(DAY_LIGHT[i + 1][0]) < t:
		i += 1
	var from: Array = DAY_LIGHT[i]
	var to: Array = DAY_LIGHT[i + 1]
	var span: float = float(to[0]) - float(from[0])
	return (from[1] as Color).lerp(to[1], (t - float(from[0])) / span if span > 0 else 0.0)


## A room's light: as dark as the night outside is, but kinder.
static func indoor(steps: float) -> Color:
	return INDOOR_DAY.lerp(INDOOR_NIGHT, darkness(outdoor(steps)))


## Whether the sky is over the map: not indoors, not under the ground.
static func under_sky(map: MapData) -> bool:
	return map != null and map.style != "cave" and not PunyInterior.is_room(map.id)


## How dark a light is, 0 by day to 1 at night: how strongly lamps and
## fires show against it.
static func darkness(light: Color) -> float:
	return clampf((1.0 - light.get_luminance()) / (1.0 - NIGHT.get_luminance()), 0.0, 1.0)


static var _soft: Texture2D


## The soft round light every light shares: full at its heart, a long warm
## falloff, nothing at the edge.
static func soft() -> Texture2D:
	if _soft == null:
		var ramp := Gradient.new()
		ramp.set_color(0, Color(1, 1, 1, 1))
		ramp.set_color(1, Color(1, 1, 1, 0))
		ramp.add_point(0.3, Color(1, 1, 1, 0.62))
		ramp.add_point(0.65, Color(1, 1, 1, 0.18))
		var texture := GradientTexture2D.new()
		texture.gradient = ramp
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(1.0, 0.5)
		texture.width = TEXTURE_PX
		texture.height = TEXTURE_PX
		_soft = texture
	return _soft


## A light at `at` reaching `radius` pixels, of `color`, at full `energy`
## when it's darkest; fire flickers. The LightRig sets its energy each frame.
## Its `shape` is soft() unless given (a window's spill, a sunbeam).
static func make(at: Vector2, radius: float, color: Color, energy: float, flicker := false, shape: Texture2D = null) -> PointLight2D:
	var light := PointLight2D.new()
	light.texture = shape if shape != null else soft()
	light.texture_scale = radius * 2.0 / TEXTURE_PX
	# Picked by eye, in the screen's colours: on the desktop app's linear
	# canvas made linear (PIX-227, DesktopLook), the LightRig keeping it so.
	light.set_meta("tint", color)
	light.color = DesktopLook.canvas_color(color, DesktopLook.linear)
	light.energy = 0.0
	light.position = at
	light.set_meta("energy", energy)
	light.set_meta("flicker", flicker)
	light.set_meta("phase", fmod(absf(at.x * 0.37 + at.y * 0.61), TAU))
	light.add_to_group("lights")
	return light


## The day through a window (PIX-311): up with the sky, gone with the dusk
## (the LightRig reads `by_day`), whatever the room's own dark.
static func daylight(at: Vector2, radius: float, color: Color, energy: float, shape: Texture2D) -> PointLight2D:
	var light := make(at, radius, color, energy, false, shape)
	light.set_meta("by_day", true)
	return light


static var _spill: Texture2D
static var _shaft: Texture2D


## A lit window's light (PIX-311): a little round the glass on the wall, and
## thrown out on the ground below it, wider as it goes and fading - the
## window's shape on the street, not a ball of light round it. Its middle
## stands on the foot of the wall.
static func spill() -> Texture2D:
	if _spill == null:
		_spill = cast(0.0, 0.24, 0.55, 0.3)
	return _spill


## The day through a room's window (PIX-311): a pool slanting down the floor
## from the foot of the back wall, as the sun comes in from the left.
static func shaft() -> Texture2D:
	if _shaft == null:
		_shaft = cast(0.4, 0.22, 0.12, 0.0, 1.0, 0.55)
	return _shaft


## A light thrown down from a window, TEXTURE_PX square, its middle at the
## foot of the wall: below it a band `width` wide at the top (a share of the
## half size) widening by `spread` and leaning by `lean` as it goes down,
## soft at its sides from `edge` of its width and fading to nothing at the
## bottom (the steeper, the higher `fade`); above it a soft `halo` round the
## middle. Smooth, as every light is: built small and scaled up.
static func cast(lean: float, width: float, spread: float, halo: float, fade := 2.0, edge := 0.3) -> Texture2D:
	var size := 32
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var u := (x + 0.5) / size * 2.0 - 1.0
			var v := (y + 0.5) / size * 2.0 - 1.0
			var amount := 0.0
			if v > 0.0:
				var across := absf(u - lean * v) / (width + spread * v)
				amount = (1.0 - smoothstep(edge, 1.0, across)) * pow(1.0 - v, fade) * smoothstep(0.0, 0.05, v)
			amount = maxf(amount, halo * (1.0 - smoothstep(0.0, 0.32, Vector2(u, v * 1.3).length())))
			image.set_pixel(x, y, Color(1, 1, 1, amount))
	image.resize(TEXTURE_PX, TEXTURE_PX, Image.INTERPOLATE_BILINEAR)
	return ImageTexture.create_from_image(image)


static var _unshaded: CanvasItemMaterial
static var _glow: CanvasItemMaterial


## What the dark doesn't touch: flames, and the world's words and bars.
static func unshaded() -> CanvasItemMaterial:
	if _unshaded == null:
		_unshaded = CanvasItemMaterial.new()
		_unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return _unshaded


## A glow sprite's: added onto what's under it, and never darkened.
static func glow() -> CanvasItemMaterial:
	if _glow == null:
		_glow = CanvasItemMaterial.new()
		_glow.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_glow.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return _glow


## `node` and everything under it stay bright at night.
static func unshade(node: CanvasItem) -> void:
	node.material = unshaded()
	_share_material(node)


static func _share_material(node: Node) -> void:
	for child in node.get_children():
		if child is CanvasItem:
			(child as CanvasItem).use_parent_material = true
		_share_material(child)
