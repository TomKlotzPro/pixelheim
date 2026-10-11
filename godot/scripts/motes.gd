class_name Motes
## The small life of the world (PIX-225): fireflies at dusk and night over
## the grass and in the woods, leaves falling in the forests, dust floating
## in a room's light, embers off forges, hearths and camp fires, dust and
## splashes under the hero's feet, sparks where steel meets armour. What
## glows (fireflies, embers, sparks) ignores the dark and blooms at night;
## the rest takes the scene's light. Pure: what each looks like and when it
## shows. The Atmosphere node keeps them over the view and fires the bursts.

## What the hero's feet kick up from the ground: its dust's colour...
const DUST := {
	"path": Color(0.72, 0.6, 0.42), "sand": Color(0.86, 0.78, 0.55),
	"ash": Color(0.6, 0.57, 0.53), "stone": Color(0.64, 0.64, 0.66),
	"snow": Color(0.95, 0.97, 1.0), "ice": Color(0.84, 0.92, 1.0),
	"bridge": Color(0.66, 0.55, 0.4), "dock": Color(0.66, 0.55, 0.4),
}
## ...or a splash, wading through a bog.
const WADES := ["marsh"]
## Foes in plate or mail, of stone or of iron: steel throws sparks off them.
const ARMOURED := [
	"orc", "boneknight", "golem", "iron_demon", "hollow_guard", "turncoat",
	"turncoat_bowman", "pirate_captain", "mimic", "dragon", "frost_drake", "wyvern",
]
## Fireflies come out as the light goes, from this darkness to full.
const FIREFLY_DUSK := 0.3
const FIREFLY_NIGHT := 0.7
## The airs they keep away from: too hot, too cold, too salt.
const NO_FIREFLIES := ["ash", "frost", "coast"]


## How many fireflies, 0..1: under the sky at dusk and night, but not on the
## Ash, the Frostgate or the coast, not in the rain, not in the fire.
static func fireflies(map: MapData, air: String, dark: float, rain: float) -> float:
	if not Lights.under_sky(map) or air in NO_FIREFLIES:
		return 0.0
	# Not the night the village burns, nor the night it holds (PIX-253 step 9).
	if map.id == "town" and (GameState.progression.prologue != Prologue.DONE or GameState.progression.bells != Bells.NONE):
		return 0.0
	return clampf((dark - FIREFLY_DUSK) / (FIREFLY_NIGHT - FIREFLY_DUSK), 0.0, 1.0) * (1.0 - rain)


## Whether steel throws sparks off a foe.
static func sparks_off(foe_id: String) -> bool:
	return foe_id in ARMOURED


## The kick of a footfall on `tile`: "dust", "splash" or "" (grass, floors).
static func footfall(tile: String) -> String:
	if tile in WADES:
		return "splash"
	return "dust" if DUST.has(tile) else ""


## Particles over a rectangle the Atmosphere keeps on the view.
static func over_view(amount: int, lifetime: float, direction: Vector2, spread: float, speed: Vector2, gravity: Vector2) -> CPUParticles2D:
	var node := CPUParticles2D.new()
	node.amount = amount
	node.lifetime = lifetime
	node.preprocess = lifetime
	node.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	node.direction = direction
	node.spread = spread
	node.initial_velocity_min = speed.x
	node.initial_velocity_max = speed.y
	node.gravity = gravity
	return node


## A one-shot burst, all at once from a small circle, fired where needed.
static func burst(amount: int, lifetime: float, spread: float, speed: Vector2, gravity: Vector2) -> CPUParticles2D:
	var node := CPUParticles2D.new()
	node.amount = amount
	node.lifetime = lifetime
	node.one_shot = true
	node.explosiveness = 1.0
	node.emitting = false
	node.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	node.emission_sphere_radius = 3.0
	node.direction = Vector2.UP
	node.spread = spread
	node.initial_velocity_min = speed.x
	node.initial_velocity_max = speed.y
	node.gravity = gravity
	return node


## `color` fading to nothing over a particle's life.
static func fading(color: Color) -> Gradient:
	var ramp := Gradient.new()
	ramp.set_color(0, color)
	ramp.set_color(1, Color(color, 0.0))
	return ramp


## Fireflies: slow, wandering, blinking yellow-green, each a bright pixel
## with a faint glow round it, glowing in the dark.
static func make_fireflies() -> CPUParticles2D:
	var node := over_view(45, 5.0, Vector2.UP, 180.0, Vector2(2, 7), Vector2.ZERO)
	var glow := Image.create(3, 3, false, Image.FORMAT_RGBA8)
	glow.set_pixel(1, 1, Color.WHITE)
	for arm: Vector2i in [Vector2i(0, 1), Vector2i(2, 1), Vector2i(1, 0), Vector2i(1, 2)]:
		glow.set_pixelv(arm, Color(1, 1, 1, 0.35))
	node.texture = ImageTexture.create_from_image(glow)
	var blink := Gradient.new()
	blink.set_color(0, Color(0.85, 1.0, 0.45, 0.0))
	blink.set_color(1, Color(0.85, 1.0, 0.45, 0.0))
	blink.add_point(0.2, Color(0.9, 1.0, 0.5, 1.0))
	blink.add_point(0.45, Color(0.85, 1.0, 0.45, 0.15))
	blink.add_point(0.7, Color(0.9, 1.0, 0.5, 1.0))
	node.color_ramp = blink
	node.tangential_accel_min = -6.0
	node.tangential_accel_max = 6.0
	node.material = Lights.glow()
	return node


## Leaves drifting down through the woods, turning as they fall, in greens
## and autumn browns.
static func make_leaves() -> CPUParticles2D:
	var node := over_view(26, 7.0, Vector2(0.4, 1.0), 30.0, Vector2(6, 14), Vector2(2, 3))
	var leaf := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	leaf.set_pixel(0, 0, Color.WHITE)
	leaf.set_pixel(1, 0, Color.WHITE)
	leaf.set_pixel(1, 1, Color(0.8, 0.8, 0.8))
	node.texture = ImageTexture.create_from_image(leaf)
	var hues := Gradient.new()
	hues.set_color(0, Color(0.42, 0.62, 0.28))
	hues.set_color(1, Color(0.78, 0.55, 0.22))
	hues.add_point(0.5, Color(0.62, 0.68, 0.26))
	node.color_initial_ramp = hues
	node.angle_min = 0.0
	node.angle_max = 360.0
	node.angular_velocity_min = -90.0
	node.angular_velocity_max = 90.0
	return node


## Dust floating in a room's light: faint warm specks, drifting slowly.
static func make_room_dust() -> CPUParticles2D:
	var node := over_view(48, 8.0, Vector2.UP, 180.0, Vector2(1, 4), Vector2(0, 0.6))
	var drift := Gradient.new()
	drift.set_color(0, Color(1.0, 0.93, 0.76, 0.0))
	drift.set_color(1, Color(1.0, 0.93, 0.76, 0.0))
	drift.add_point(0.5, Color(1.0, 0.94, 0.8, 0.75))
	node.color_ramp = drift
	node.material = Lights.unshaded()
	return node


## Embers rising off a fire: a few at a time, orange to red, glowing.
static func make_embers(amount := 6) -> CPUParticles2D:
	var node := CPUParticles2D.new()
	node.amount = amount
	node.lifetime = 1.6
	node.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	node.emission_sphere_radius = 3.0
	node.direction = Vector2.UP
	node.spread = 25.0
	node.initial_velocity_min = 10.0
	node.initial_velocity_max = 22.0
	node.gravity = Vector2(0, -6)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.8, 0.35, 1.0))
	ramp.set_color(1, Color(0.75, 0.15, 0.05, 0.0))
	ramp.add_point(0.5, Color(1.0, 0.45, 0.12, 0.9))
	node.color_ramp = ramp
	node.material = Lights.glow()
	return node


## A little dust from a footfall, tinted by the ground: light, since it
## comes with every step.
static func make_dust() -> CPUParticles2D:
	var node := burst(4, 0.35, 70.0, Vector2(5, 11), Vector2(0, 16))
	node.color_ramp = fading(Color(1, 1, 1, 0.5))
	return node


## A splash from wading: droplets thrown up that fall back.
static func make_splash() -> CPUParticles2D:
	var node := burst(6, 0.35, 60.0, Vector2(14, 26), Vector2(0, 90))
	node.color_ramp = fading(Color(0.75, 0.88, 0.86, 0.85))
	return node


## What a fallen foe leaves as it dissolves (PIX-226): motes of its colour
## drifting up and away.
static func make_remains() -> CPUParticles2D:
	var node := burst(12, 0.7, 180.0, Vector2(8, 24), Vector2(0, -14))
	node.emission_sphere_radius = 6.0
	node.damping_min = 10.0
	node.damping_max = 20.0
	node.color_ramp = fading(Color(1, 1, 1, 0.9))
	return node


## Sparks off armour: white-hot, flying every way, falling, glowing.
static func make_sparks() -> CPUParticles2D:
	var node := burst(10, 0.28, 180.0, Vector2(40, 90), Vector2(0, 160))
	node.damping_min = 40.0
	node.damping_max = 80.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 1.0, 0.85, 1.0))
	ramp.set_color(1, Color(1.0, 0.45, 0.1, 0.0))
	ramp.add_point(0.4, Color(1.0, 0.8, 0.35, 1.0))
	node.color_ramp = ramp
	node.material = Lights.glow()
	return node
