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
## Indoors: a little warm by day, lamplit at night.
const INDOOR_DAY := Color(0.97, 0.94, 0.89)
const INDOOR_NIGHT := Color(0.6, 0.53, 0.5)
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
## The ice cave's frozen floors (PIX-255): a cold light the ice gives back.
const ICE := Color(0.62, 0.84, 1.0)
## How strong each kind of light is at full dark. A 2D light adds to the
## night before the colours are multiplied, so near 1 it washes the ground
## out: these keep a lamp's pool warm, not white.
const LAMP_ENERGY := 0.42
const FIRE_ENERGY := 0.55
const TORCH_ENERGY := 0.7
const WINDOW_ENERGY := 0.3
const LANTERN_ENERGY := 0.3
const ICE_ENERGY := 0.22
## The size of the shared light texture, in pixels.
const TEXTURE_PX := 256


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
	return map != null and map.floor_level == 0 and map.style != "cave" and not PunyInterior.is_room(map.id)


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
static func make(at: Vector2, radius: float, color: Color, energy: float, flicker := false) -> PointLight2D:
	var light := PointLight2D.new()
	light.texture = soft()
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
