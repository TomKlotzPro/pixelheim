class_name RankLook
## How each rank of a class looks on the hero (PIX-244). Tom asked for « une
## meilleure différenciation entre chaque niveau de classe »: a rank was a
## title, a faint pool under the feet and a figure 5% bigger. Since PIX-242
## every hero wears a survivor's plain clothes and whatever gear they put on
## (PunyArt.dressed), so a rank never changes what is worn: it layers on top,
## one step a rank, each kept by the ranks after it, and none is drawn over a
## pixel of the clothes or the gear (the shirt's reds the motion check finds
## the hero by stay as they are):
## - I (levels 1-4): the plain survivor, nothing added.
## - II (5): the trim. The figure's outer edge - Shade's black outline where
##   it meets the air - in the class's colour; the eyes and the lines inside
##   stay black. The pool of light under the feet comes silver (Ranks.aura).
## - III (10): a rim of light. A pixel of the class's light just outside the
##   figure, along its top and sides as if lit from above (never under the
##   feet), drawn on a copy of the frame behind the sprite and unshaded, so
##   it shows at night and the glow pass blooms it. The pool turns gold.
## - IV (15): the weapon's glow. A swing or a cast flares in the class's
##   light at the weapon, its arc lingers, sparks of that light fly off it,
##   and at night it lights the ground round the blow.
## - V (20): a trail of light. Motes of the class's light are shed behind
##   every step and roll, and the rim breathes.
## Ranks.presence still grows the figure a touch a rank. `spec` is pure (rank
## to what is worn); `wear` hangs the trim and the rim on a sprite, and the
## textures and emitters here are the art's whole pixels, drawn in code.

## What each rank adds, by rank (HeroRules.rank_index): the survivor adds
## nothing, then the trim, the rim, the weapon's glow and the trail.
const STEPS := ["survivor", "trim", "rim", "weapon", "trail"]
## Each class's colours: its trim, a cloth colour dark enough to stand for
## an outline, and its light (the rim, the weapon's glow, the trail), bright
## enough to bloom at night.
const COLORS := {
	"warrior": ["b8322a", "ff8a5c"],
	"paladin": ["c08a1e", "ffe07a"],
	"rogue": ["23946f", "6dffc8"],
	"cleric": ["b9a25a", "fff4c4"],
	"mage": ["2f62cf", "7cc4ff"],
	"necromancer": ["7442c4", "c9a2ff"],
	"ranger": ["4f8f25", "bdf06a"],
}
## How strongly the rim shows, and how far it breathes at rank V (from this
## much under full, over BREATH_SECONDS).
const RIM_ALPHA := 0.85
const BREATH := 0.35
const BREATH_SECONDS := 2.4
## The weapon's glow (rank IV): how long a blow's flare lasts, how far its
## light reaches at night and how strong it is then, and how much longer a
## glowing weapon's arc lingers.
const FLARE_SECONDS := 0.22
const FLARE_REACH := 40.0
const FLARE_ENERGY := 0.6
const LINGER := 1.6
## Nothing worn there.
const NONE := Color(0, 0, 0, 0)
## The rim's node under the sprite it follows.
const RIM_NODE := "rank_rim"
const RIM_SHADER := preload("res://shaders/rank_rim.gdshader")


## What the hero wears at `rank` (0 the survivor .. 4): each step's colour,
## NONE where the rank hasn't reached it, and the steps by name.
static func spec(role_id: String, rank: int) -> Dictionary:
	rank = clampi(rank, 0, STEPS.size() - 1)
	var colors: Array = COLORS.get(role_id, COLORS["warrior"])
	var trim := Color(String(colors[0]))
	var light := Color(String(colors[1]))
	var aura: Variant = Ranks.aura(rank * 5)
	return {
		"rank": rank,
		"steps": STEPS.slice(1, rank + 1),
		"trim": trim if rank >= 1 else NONE,
		"aura": aura if aura != null else NONE,
		"rim": light if rank >= 2 else NONE,
		"weapon": light if rank >= 3 else NONE,
		"trail": light if rank >= 4 else NONE,
		"breath": rank >= 4,
		"light": light,
	}


## The hero's look at their level.
static func of_hero(hero: HeroState) -> Dictionary:
	return spec(hero.role_id, HeroRules.rank_index(hero.level))


## What a rank brings to the look, in a line the ascension shows ("" for the
## survivor's, who has nothing new).
static func line(rank: int) -> String:
	match STEPS[clampi(rank, 0, STEPS.size() - 1)]:
		"trim":
			return Text.t("New look: an edge in your class's colour")
		"rim":
			return Text.t("New look: a rim of light around you")
		"weapon":
			return Text.t("New look: your weapon glows as it strikes")
		"trail":
			return Text.t("New look: light trails your steps")
	return ""


## Puts `look` on `sprite`: the trim through its fighter material (one is
## given if it has none), the rim as a copy of its frames behind it. A look
## without them takes them off.
static func wear(sprite: AnimatedSprite2D, look: Dictionary) -> void:
	var material := sprite.material as ShaderMaterial
	if material == null:
		material = Juice.fighter_material()
		sprite.material = material
	material.set_shader_parameter("trim", look.get("trim", NONE))
	var rim := rim_of(sprite)
	var color: Color = look.get("rim", NONE)
	if color.a == 0.0:
		if rim != null:
			# Out of the tree at once, so a rim put back this frame takes its name.
			sprite.remove_child(rim)
			rim.queue_free()
		return
	if rim == null:
		rim = Rim.new()
		rim.name = RIM_NODE
		sprite.add_child(rim)
	rim.wear(color, look.get("breath", false))


## The rim hung on `sprite`, or null.
static func rim_of(sprite: Node) -> Rim:
	var rim := sprite.get_node_or_null(RIM_NODE)
	return rim as Rim if rim != null and not rim.is_queued_for_deletion() else null


## A rank's rim of light: the sprite's own frame, drawn behind it through the
## rim shader, frame for frame. It follows the sprite it hangs on (its
## frames, animation and frame, through their signals, so it never lags a
## frame behind), inherits its place, size, squash and fading, and draws
## nothing of its own on the figure. At rank V it breathes, unless motion is
## reduced.
class Rim extends AnimatedSprite2D:
	var breath := false
	var _clock := 0.0

	func _ready() -> void:
		show_behind_parent = true
		var sprite := get_parent() as AnimatedSprite2D
		sprite.sprite_frames_changed.connect(_follow)
		sprite.animation_changed.connect(_follow)
		sprite.frame_changed.connect(_follow)
		_follow()

	func wear(color: Color, breathes: bool) -> void:
		if material == null:
			material = ShaderMaterial.new()
			(material as ShaderMaterial).shader = RankLook.RIM_SHADER
		(material as ShaderMaterial).set_shader_parameter("rim", Color(color, RankLook.RIM_ALPHA))
		breath = breathes
		self_modulate.a = 1.0

	func _follow() -> void:
		var sprite := get_parent() as AnimatedSprite2D
		if sprite_frames != sprite.sprite_frames:
			sprite_frames = sprite.sprite_frames
		if sprite_frames == null:
			return
		if animation != sprite.animation:
			animation = sprite.animation
		frame = sprite.frame
		flip_h = sprite.flip_h
		flip_v = sprite.flip_v
		centered = sprite.centered
		offset = sprite.offset

	func _process(delta: float) -> void:
		if not breath or GameState.settings.reduce_motion:
			self_modulate.a = 1.0
			return
		_clock = fmod(_clock + delta, RankLook.BREATH_SECONDS)
		self_modulate.a = 1.0 - RankLook.BREATH * (0.5 - 0.5 * cos(_clock / RankLook.BREATH_SECONDS * TAU))


## Motes of the class's light shed behind the hero's steps (rank V): set
## `emitting` while they walk. In the world's coordinates, so they stay where
## they were shed; added behind the sprite.
static func trail(color: Color) -> CPUParticles2D:
	var node := CPUParticles2D.new()
	node.amount = 24
	node.lifetime = 1.0
	node.texture = mote()
	node.emitting = false
	node.local_coords = false
	node.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	node.emission_rect_extents = Vector2(3, 5)
	node.position = Vector2(0, -3)
	node.direction = Vector2.UP
	node.spread = 40.0
	node.initial_velocity_min = 2.0
	node.initial_velocity_max = 7.0
	node.gravity = Vector2(0, -5)
	node.color_ramp = Motes.fading(Color(color, 0.95))
	node.material = Lights.glow()
	return node


## Sparks of the class's light off a swing (rank IV): one burst, fired with
## `restart()`.
static func sparks(color: Color) -> CPUParticles2D:
	var node := Motes.burst(8, 0.35, 180.0, Vector2(30, 60), Vector2(0, 70))
	node.damping_min = 40.0
	node.damping_max = 80.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	ramp.set_color(1, Color(color, 0.0))
	ramp.add_point(0.35, Color(color, 1.0))
	node.color_ramp = ramp
	node.material = Lights.glow()
	return node


static var _mote: Texture2D
static var _flare: Texture2D


## A mote of the trail: a bright pixel with a faint cross of light round it
## (the fireflies' shape, Motes).
static func mote() -> Texture2D:
	if _mote == null:
		var image := Image.create(3, 3, false, Image.FORMAT_RGBA8)
		image.set_pixel(1, 1, Color.WHITE)
		for arm: Vector2i in [Vector2i(0, 1), Vector2i(2, 1), Vector2i(1, 0), Vector2i(1, 2)]:
			image.set_pixelv(arm, Color(1, 1, 1, 0.4))
		_mote = ImageTexture.create_from_image(image)
	return _mote
static var _beam: Texture2D
static var _halo: Texture2D


## The weapon's flare (rank IV): a glint of light, a cross of pixels in a
## stepped ring, white at the heart; tinted by the modulate, added on.
static func flare() -> Texture2D:
	if _flare == null:
		var size := 11
		var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
		var middle := size / 2
		for y in size:
			for x in size:
				var dx := absi(x - middle)
				var dy := absi(y - middle)
				var alpha := 0.0
				if (dx == 0 and dy <= 5) or (dy == 0 and dx <= 5):
					alpha = 1.0 - 0.15 * maxi(dx, dy)
				elif dx + dy <= 3:
					alpha = 0.45
				elif dx + dy <= 5:
					alpha = 0.18
				image.set_pixel(x, y, Color(1, 1, 1, alpha))
		_flare = ImageTexture.create_from_image(image)
	return _flare


## A shaft of light falling on the hero (the ascension): brightest in its
## middle columns and nearest the ground, in steps, not a smooth ramp, so at
## the stage's size it stands in the art's whole pixels.
static func beam() -> Texture2D:
	if _beam == null:
		var size := Vector2i(15, 64)
		var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
		var middle := size.x / 2
		for y in size.y:
			# Six steps from faint at the top to full at the feet.
			var down := floorf(float(y) / size.y * 6.0) / 5.0
			for x in size.x:
				var across := absi(x - middle)
				var band := 1.0 if across <= 1 else (0.6 if across <= 3 else (0.32 if across <= 5 else 0.14))
				image.set_pixel(x, y, Color(1, 1, 1, band * lerpf(0.15, 1.0, down)))
		_beam = ImageTexture.create_from_image(image)
	return _beam


## The halo behind the lifted hero: rings of light in steps, a Bayer
## dither between them (the ground's own 2px blocks, PIX-264, at one pixel).
static func halo() -> Texture2D:
	if _halo == null:
		var size := 41
		var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
		var middle := Vector2(size / 2.0, size / 2.0)
		var bayer := [[0.0, 0.5], [0.75, 0.25]]
		var rings := [[7.0, 0.8], [12.0, 0.5], [16.5, 0.28], [20.5, 0.12]]
		for y in size:
			for x in size:
				var reach := (Vector2(x + 0.5, y + 0.5) - middle).length()
				var alpha := 0.0
				for ring: Array in rings:
					# Within a pixel and a half of the ring's edge, alternate
					# pixels take the next ring's light.
					var edge: float = ring[0]
					if reach < edge - 1.5 or (reach < edge and float(bayer[y % 2][x % 2]) < (edge - reach) / 1.5):
						alpha = ring[1]
						break
				image.set_pixel(x, y, Color(1, 1, 1, alpha))
		_halo = ImageTexture.create_from_image(image)
	return _halo
