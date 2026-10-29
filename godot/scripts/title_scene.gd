class_name TitleScene
extends Node2D
## areas: title
## The title's backdrop (PIX-139): Pixelheim's street at night under the
## Ashen Mountain, in Shade's art, drawn in art pixels at 2x. Far to near: a
## dithered sky, stars, the moon behind drifting cloud, the far ranges, the
## Ashen Mountain smoking with Fafnyr's fire at its summit, pine hills, then
## the village - cottages with lit windows and smoking chimneys, torches, the
## fountain, the watchman on his round, and the hero in the street looking up
## at the mountain. Now and then the dragon crosses the moon.
##
## And it lives as the world does (PIX-249, the "Beautiful on Computer"
## work brought to the title): a camera drifts slowly over it, the near
## layers travelling further than the far; the torches, the lit windows and
## the watchman's lantern are real lights pooling warm on the moonlit walls,
## the bank and the street (PIX-221), and what's bright blooms (PIX-222);
## the lake behind the street swells and glints, the trees and the hill pines
## lean in the wind (PIX-223), mist rolls along the valley and embers rise
## off the torches (PIX-225). It keeps the world's clock and wind for its
## shaders while the world waits under it.
## Reduce motion holds the scene still: no drift, no wind, no flicker; the
## swell, mist, clouds, smoke, fireflies, watchman and dragon stopped, the
## flames, the fountain and the figures on their first frame. (Shade's water
## tiles ripple on, as in the world: their frames are the tileset's own.)
##
## And it is deeper (PIX-392): moonlight falls in shafts, ash drifts down
## from the mountain, a dark tree and a banner with its lantern stand nearer
## than the street and frame it, and with Shade's pack the street keeps
## market: two stalls, bunting with its lanterns between the torches, hens
## asleep by the barrel. A launch's entrance (TitleEntrance) poses it: the
## camera comes down from the stars (`descent`), the dragon makes its pass
## close by (`fly_wyrm`), and the mountain wakes and lights the valley
## (`flare`, `erupt`).

const ART := Vector2(640, 360)
const PIXEL := 2.0
## The street's top edge (art pixels): the house walls stand on it.
const STREET := 320
## Moonlight on the village: how much of each colour the night leaves.
const MOONLIT := Color(0.3, 0.33, 0.56)
const MOON := Vector2(556, 58)
const SUMMIT := Vector2(118, 112)
## The sky, top to bottom: night deepening upward, warming toward the fire.
const SKY := [Color("04061a"), Color("080c28"), Color("0f1238"), Color("1a1847"), Color("2a1f55"), Color("3d275c"), Color("54305c")]
const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
const FAR_RANGE := [[0, 206], [70, 186], [140, 202], [230, 172], [300, 196], [372, 158], [446, 192], [520, 174], [590, 198], [640, 188]]
const ASHEN := [[-60, 250], [10, 214], [64, 162], [104, 124], [111, 112], [118, 117], [125, 111], [138, 126], [184, 168], [262, 210], [350, 242], [420, 256]]
const HILLS := [[0, 276], [90, 266], [190, 279], [300, 268], [410, 280], [520, 264], [640, 274]]
## Puny World trees for the hill crest, and the village's ground.
const PINES := [197, 224, 251, 206, 233, 260]
const GRASS := [1, 2, 28, 29]
## A road with grass along its top edge, then plain dirt.
const ROAD_EDGE := 5
const ROAD := [13, 14]
const WATCHMAN := "characters/aligned/Human-Soldier-Cyan.png"
## The watchman's pace on his round (art px a second); his steps keep to it
## (PIX-243).
const WATCH_PACE := 12.0
## The dragon comes this soon, then this often (s).
const DRAGON_FIRST_S := 4.0
const DRAGON_EVERY_S := 45.0
const DRAGON_SPEED := 36.0
## The camera's slow drift (PIX-249): how far it travels each way, in art
## pixels at the village (the nearest layer), and how long one sweep takes
## along the street and one rise and fall (s). It starts on the frame the
## title was composed for.
const DRIFT := Vector2(28, 5)
const DRIFT_S := Vector2(96, 57)
## How far each layer travels with the camera, the village's 1: the sky
## barely, the mountains less than the hills.
const DEPTH := {
	"stars": 0.04, "moon": 0.07, "clouds": 0.12, "far": 0.2, "ashen": 0.36,
	"mist": 0.5, "hills": 0.66, "village": 1.0, "near": 1.35,
}
## The entrance's descent (PIX-392): at `descent` 1 every layer stands TILT
## art pixels lower, the camera looking up at the stars, and each CRANE
## further by its depth, so the mountains rise into view before the hills,
## the village and, last, what stands nearest.
const TILT := 200.0
const CRANE := 160.0
## The dragon's pass close by (PIX-392): its wings beat so many times over
## the pass, and it breathes fire from its mouth over this share of it.
const WINGBEATS := 7.0
const BREATH := Vector2(0.4, 0.62)
const MOUTH := Vector2(-60, 0)
## Moonlight falling from the moon down the valley: [the angle off straight
## down toward the west, width at its foot, length, strength], art pixels.
const SHAFTS := [[0.55, 60.0, 340.0, 0.045], [0.8, 90.0, 380.0, 0.035], [1.05, 44.0, 300.0, 0.04]]
## What stands nearest (PIX-392), framing the view: the dark tree at the left
## (its foot below the view) and the banner's pole at the right.
const NEAR_TREE := Vector2(-20, 384)
const NEAR_POLE := Vector2(612, 372)
const NEAR_DARK := Color("05060d")
const NEAR_RIM := Color("262f5c")
## The street keeps market (PIX-392): two stalls under their awnings, the
## bunting with its lanterns glowing strung across the street, and hens
## asleep by the barrel (ninth-jedi's, where they're installed).
func _market(street: Node2D) -> void:
	for spec: Array in STALLS:
		var stall := Sprite2D.new()
		stall.texture = HamletArt.texture(spec[0])
		stall.centered = false
		stall.offset = -Vector2(HamletArt.size(spec[0]).x / 2, HamletArt.size(spec[0]).y)
		stall.position = spec[1]
		street.add_child(stall)
	var bunting := HamletArt.bunting(BUNTING_CELLS)
	var line := Sprite2D.new()
	line.texture = bunting["day"]
	line.centered = false
	line.position = BUNTING
	village.add_child(line)
	var lit := Sprite2D.new()
	lit.texture = bunting["lit"]
	lit.centered = false
	lit.position = BUNTING
	lights.add_child(lit)
	for at: Vector2 in bunting["lights"]:
		var halo := Sprite2D.new()
		halo.texture = glow_texture(5, Color("ffc070"), 0.5, 2)
		halo.material = additive()
		halo.position = BUNTING + at
		lights.add_child(halo)
		flames.append([halo, at.x])
	if not FarmAnimals.available():
		return
	for spec: Array in HENS:
		var hen := AnimatedSprite2D.new()
		hen.sprite_frames = FarmAnimals.frames(spec[0])
		hen.play("sleep")
		hen.frame = int(spec[1].x) % 4
		hen.offset = Vector2(0, -6)
		hen.position = spec[1]
		if still:
			hen.stop()
		street.add_child(hen)


## The lake behind the street: water from row 17, at the forest's foot, to
## the bank on row 19 the fences and torches stand on, under every house.
const LAKE_ROWS := Vector2i(17, 19)
const LAKE_COLUMNS := Vector2i(-3, 43)
## Real light in the village (PIX-221's): [reach in art pixels, colour,
## strength]. The torches flicker; the lantern walks with the watchman.
const TORCH_LIGHT := [72.0, Lights.FIRE, 0.9]
const WINDOW_LIGHT := [32.0, Lights.WINDOW, 0.55]
const LANTERN_LIGHT := [44.0, Lights.LANTERN, 0.65]
const FOUNTAIN_LIGHT := [40.0, Lights.ICE, 0.5]
## The street's market (PIX-392): [piece, its foot], art pixels; the bunting
## strung from the west house's eave to the east's (its rope tied there); the
## hens asleep by the barrel: [sheet, foot].
const STALLS := [["market_stall", Vector2(112, 352)], ["market_stall_blue", Vector2(488, 354)]]
const BUNTING := Vector2(176, 266)
const BUNTING_CELLS := 15
const HENS := [["chicken1", Vector2(170, 333)], ["chick", Vector2(158, 334)], ["chicken2", Vector2(186, 335)]]
## The one light-mask bit the village's art answers to: its lights reach
## nothing else on the canvas (the sky, the title's words, a story's captions).
const LIT_MASK := 1 << 9
## Meta on what the lights leave alone in the village (the lake).
const UNLIT := &"title_unlit"
## How strongly the bright things bloom: the world's at full night.
const GLOW := 0.9
## How far the wind leans what grows, in art pixels at its top: the trees
## in the village, the far pines on the hills.
const TREE_SWAY := 1.3
const PINE_SWAY := 0.6
## Shade's trees from the Medieval Age pack along the bank: [the tile at the
## top-left, its size in tiles, where its foot stands]. An oak by the
## barrel, a young tree at the water's edge behind the fence, a pine in the
## gap between the cottages.
const TREES := [
	[2876, Vector2i(2, 2), Vector2(170, 318)],
	[236, Vector2i(1, 2), Vector2(402, 308)],
	[240, Vector2i(1, 2), Vector2(584, 318)],
]
## The mist along the valley (art pixels, at its layer), its moonlit grey
## and how thick it lies at most.
const MIST := Rect2(-40, 220, 720, 70)
const MIST_SHADE := Color(0.42, 0.44, 0.7)
const MIST_STRENGTH := 0.5

var still := false
var clock := 0.0
## [node, home, depth]: what moves with the camera, and how far.
var layers: Array = []
## Where the camera has drifted (art pixels, at the village).
var camera := Vector2.ZERO
## [node, art pixels per second]
var clouds: Array = []
var dragon: AnimatedSprite2D
var dragon_at := DRAGON_FIRST_S
## False when a story borrows the scene and brings its own dragon (Cutscene).
var dragon_rounds := true
var summit_glow: Sprite2D
## [node, home, phase]
var fireflies: Array = []
## [glow, phase]
var flames: Array = []
## [light, strength, phase]: the lights that flicker.
var lamps: Array = []
## The village (moonlit) and what shines over it.
var village: Node2D
var lights: Node2D
var watchman: Node2D
var lantern: Sprite2D
var lantern_light: PointLight2D
var watch_dir := 1.0
## The glow over the backdrop, and the screen copy it reads.
var bloom: ColorRect
var _bloom_copy: BackBufferCopy
## The entrance's pose (PIX-392): how far up the camera still looks (1 at
## the stars, 0 the title's frame) and how hard the mountain burns (0 its
## smoulder, 1 awake).
var descent := 0.0
var flare := 0.0
var sky: TextureRect
var wyrm: Wyrm
var breath: CPUParticles2D
var eruption: CPUParticles2D
var valley_glow: Sprite2D
## [node, strength, phase]: the moonlight's shafts.
var shafts: Array = []
var banner: Sprite2D


func _ready() -> void:
	scale = Vector2.ONE * PIXEL
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	still = GameState.settings.reduce_motion
	_sky()
	_stars()
	_moon()
	_clouds()
	_dragon()
	_shafts()
	_ridge(FAR_RANGE, DEPTH["far"], 268, Color("1d1a3f"), Color("2f2b62"), 3.0, 11)
	_glow_behind()
	var ashen := _ridge(ASHEN, DEPTH["ashen"], 268, Color("0a0918"), Color("2a2654"), 5.0, 23)
	ashen.crater = Vector2i(int(SUMMIT.x) - 6, int(SUMMIT.x) + 6)
	_fire()
	_mist()
	_hills()
	_wyrm()
	_village()
	_answer_lights(village)
	_near()
	_ash()
	_glow()
	_keep_time()


## A layer of the backdrop that travels `depth` as far as the camera does.
func _layer(depth: float) -> Node2D:
	var node := Node2D.new()
	add_child(node)
	layers.append([node, Vector2.ZERO, depth])
	return node


## Where the camera has drifted at `time` (art pixels, at the village): a
## slow sweep along the street and a gentler rise and fall, from the frame
## the title opens on.
static func drift(time: float) -> Vector2:
	return Vector2(DRIFT.x * sin(time * TAU / DRIFT_S.x), DRIFT.y * sin(time * TAU / DRIFT_S.y))


## Where a layer of `depth` stands, from `home`, with the camera at `at`: on
## whole screen pixels.
static func parallax(home: Vector2, depth: float, at: Vector2) -> Vector2:
	return home - (at * depth * PIXEL).round() / PIXEL


## The night's dither, TILT taller than the view: the entrance looks up
## into its darkest.
func _sky() -> void:
	var image := Image.create(4, int(ART.y + TILT), false, Image.FORMAT_RGBA8)
	var last := SKY.size() - 1
	for y in image.get_height():
		var t := pow(maxf(y - TILT, 0.0) / (ART.y - 1.0), 1.4) * last
		var band := mini(int(t), last - 1)
		# Solid bands that dither into the next over their last stretch.
		var into := clampf((t - band - 0.55) / 0.45, 0.0, 1.0)
		for x in 4:
			var threshold: float = (BAYER[(y % 4) * 4 + x] + 0.5) / 16.0
			image.set_pixel(x, y, SKY[band + 1] if into > threshold else SKY[band])
	sky = TextureRect.new()
	sky.texture = ImageTexture.create_from_image(image)
	sky.stretch_mode = TextureRect.STRETCH_TILE
	sky.size = ART + Vector2(0, TILT)
	sky.position.y = -TILT
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Taller than the view on purpose, for the entrance: not a layout to fit.
	sky.set_meta(Layout.DECOR, true)
	add_child(sky)


func _stars() -> void:
	var field := _layer(DEPTH["stars"])
	var rng := RandomNumberGenerator.new()
	rng.seed = 1984
	# Up into the sky the entrance starts in, too.
	for i in 170:
		var at := Vector2(rng.randi_range(0, int(ART.x) - 1), rng.randi_range(-int(TILT), 200))
		var bright := rng.randf()
		if at.distance_to(MOON) < 30:
			continue
		var star := Node2D.new()
		star.position = at
		field.add_child(star)
		var color := Color(1, 0.95, 0.82, lerpf(0.2, 0.85, bright))
		_pixel(star, Vector2.ZERO, color)
		# The brightest few shine as small crosses.
		if bright > 0.94:
			for arm: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
				_pixel(star, arm, Color(color, 0.35))
		if still or i % 3 != 0:
			continue
		var twinkle := create_tween().set_loops()
		twinkle.tween_property(star, "modulate:a", 0.2, rng.randf_range(1.4, 3.0)).set_delay(rng.randf_range(0, 3))
		twinkle.tween_property(star, "modulate:a", 1.0, rng.randf_range(1.4, 3.0))


func _pixel(parent: Node, at: Vector2, color: Color) -> void:
	var dot := ColorRect.new()
	dot.size = Vector2.ONE
	dot.position = at
	dot.color = color
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# A star: most of them wait above the view for the entrance.
	dot.set_meta(Layout.DECOR, true)
	parent.add_child(dot)


## A full moon in pixels: a cream disc with a few seas, shaded toward the
## lower left, in stepped rings of light.
func _moon() -> void:
	var sky := _layer(DEPTH["moon"])
	var halo := Sprite2D.new()
	halo.texture = glow_texture(56, Color("f4ecd0"), 0.1, 4)
	halo.position = MOON
	sky.add_child(halo)
	var r := 17.5
	var image := Image.create(36, 36, false, Image.FORMAT_RGBA8)
	var seas := [[13, 12, 4.5], [22, 19, 3.5], [15, 23, 3.0], [24, 10, 2.0]]
	for y in 36:
		for x in 36:
			var d := Vector2(x + 0.5 - 18, y + 0.5 - 18)
			if d.length() > r:
				continue
			var color := Color("f1e8c8")
			for sea: Array in seas:
				if Vector2(x + 0.5 - sea[0], y + 0.5 - sea[1]).length() < sea[2]:
					color = Color("d9cca3")
			if d.length() > r - 2.2 and d.x - d.y < -6:
				color = Color("c9bb90")
			image.set_pixel(x, y, color)
	var disc := Sprite2D.new()
	disc.texture = ImageTexture.create_from_image(image)
	disc.position = MOON
	sky.add_child(disc)


## Long low clouds, moonlit along their tops, drifting west.
func _clouds() -> void:
	var sky := _layer(DEPTH["clouds"])
	for spec: Array in [[150, Vector2(486, 66), 1.6, 5], [110, Vector2(90, 34), 1.0, 9], [190, Vector2(250, 128), 2.2, 13]]:
		var cloud := Sprite2D.new()
		cloud.texture = _cloud_texture(spec[0], spec[3])
		cloud.centered = false
		cloud.position = spec[1]
		sky.add_child(cloud)
		clouds.append([cloud, spec[2]])


func _cloud_texture(width: int, seed_value: int) -> ImageTexture:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var height := 20
	var puffs: Array = []
	for i in width / 12:
		puffs.append([rng.randf_range(12, width - 12), rng.randf_range(10, 13), rng.randf_range(7, 15), rng.randf_range(3, 6)])
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	var inside := func(x: int, y: int) -> bool:
		if y < 0 or y >= height - 4:
			return false
		for puff: Array in puffs:
			var dx: float = (x + 0.5 - puff[0]) / puff[2]
			var dy: float = (y + 0.5 - puff[1]) / puff[3]
			if dx * dx + dy * dy <= 1.0:
				return true
		return false
	for y in height:
		for x in width:
			if not inside.call(x, y):
				continue
			var color := Color(0.12, 0.11, 0.27, 0.92)
			if not inside.call(x, y - 1):
				color = Color(0.25, 0.24, 0.45, 0.95)
			elif not inside.call(x, y + 1) or not inside.call(x, y + 2):
				color = Color(0.08, 0.07, 0.2, 0.92)
			image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)


## Fafnyr, far off, crossing the moon (as far off as the moon, in front of
## the clouds).
func _dragon() -> void:
	var spec := PunyArt.monster("dragon")
	dragon = AnimatedSprite2D.new()
	dragon.sprite_frames = PunyArt.frames(spec)
	dragon.play(PunyArt.pick(dragon.sprite_frames, "walk", "left"))
	dragon.speed_scale = 1.6
	if still:
		dragon.stop()
	dragon.modulate = Color(0.04, 0.03, 0.09)
	dragon.visible = false
	_layer(DEPTH["moon"]).add_child(dragon)


## A mountain range as a silhouette: the profile through its key points,
## roughened, with moonlight on the slopes that face the moon. It travels
## `depth` as far as the camera.
func _ridge(points: Array, depth: float, base: int, fill: Color, rim: Color, rough: float, seed_value: int) -> Ridge:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 0.045
	noise.fractal_octaves = 4
	# Wide enough that the camera never finds its end.
	var margin := 16 + ceili(DRIFT.x * depth)
	var tops := PackedInt32Array()
	for x in range(-margin, int(ART.x) + margin):
		var y := float(base)
		for i in points.size() - 1:
			var a: Array = points[i]
			var b: Array = points[i + 1]
			if x >= a[0] and x <= b[0]:
				y = lerpf(a[1], b[1], float(x - a[0]) / (b[0] - a[0]))
		if x < points[0][0] or x > points[-1][0]:
			y = base
		tops.append(int(round(y + noise.get_noise_1d(x) * rough * 2.0)))
	var ridge := Ridge.new()
	ridge.tops = tops
	ridge.left = -margin
	ridge.base = base
	ridge.fill = fill
	ridge.rim = rim
	add_child(ridge)
	layers.append([ridge, Vector2.ZERO, depth])
	return ridge


class Ridge:
	extends Node2D
	var tops: PackedInt32Array
	var left := 0
	var base := 0
	var fill: Color
	var rim: Color
	## Columns whose top glows with the fire inside (x from..to), if any.
	var crater := Vector2i(1, 0)

	func _draw() -> void:
		for i in tops.size():
			var top := tops[i]
			if top >= base:
				continue
			draw_rect(Rect2(left + i, top, 1, base - top), fill)
			# Slopes falling toward the moon (east) catch its light.
			var next := tops[mini(i + 1, tops.size() - 1)]
			var before := tops[maxi(i - 1, 0)]
			if next >= top and before <= top + 1:
				draw_rect(Rect2(left + i, top, 1, 2 if next > top + 1 else 1), rim)
			if left + i >= crater.x and left + i <= crater.y:
				draw_rect(Rect2(left + i, top, 1, 1), Color("ffb04a"))
				draw_rect(Rect2(left + i, top + 1, 1, 1), Color("c2401c"))


## Fire in the crater lights the sky above the summit (drawn behind the
## mountain, so its shoulders stand dark against it); the glow breathes.
func _glow_behind() -> void:
	summit_glow = Sprite2D.new()
	summit_glow.texture = glow_texture(34, Color("ff5a20"), 0.5, 6)
	summit_glow.material = additive()
	summit_glow.position = SUMMIT + Vector2(0, 6)
	add_child(summit_glow)
	layers.append([summit_glow, summit_glow.position, DEPTH["ashen"]])


## Over the summit: a plume of smoke lit from below, drifting west, and
## embers riding up out of it.
func _fire() -> void:
	var mountain := _layer(DEPTH["ashen"])
	var at := SUMMIT + Vector2(0, 2)
	var smoke := _particles(at, 22, 14.0, Color("6a3036"), Vector2(-1.6, -0.3), 4.0, 3.0, 9.0)
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	fade.colors = PackedColorArray([Color(0.55, 0.22, 0.2, 0.7), Color(0.2, 0.16, 0.3, 0.6), Color(0.16, 0.14, 0.28, 0.0)])
	smoke.color_ramp = fade
	mountain.add_child(smoke)
	var embers := _particles(at, 10, 4.5, Color("ffa040"), Vector2(-1.2, -1.5), 8.0, 0.25, 0.25)
	embers.spread = 50.0
	embers.material = additive()
	mountain.add_child(embers)
	# Awake (PIX-392): its fire lights the mountain's flanks and the valley
	# under it, and throws up a fountain of embers (`erupt`).
	valley_glow = Sprite2D.new()
	valley_glow.texture = glow_texture(48, Color("ff5a20"), 0.26, 8)
	valley_glow.material = additive()
	valley_glow.position = SUMMIT + Vector2(10, 64)
	valley_glow.scale = Vector2(3.0, 2.0)
	valley_glow.modulate.a = 0.0
	mountain.add_child(valley_glow)
	eruption = _particles(at, 48, 2.8, Color("ffc060"), Vector2(-4, 30), 58.0, 1.0, 0.5)
	eruption.spread = 34.0
	eruption.one_shot = true
	eruption.explosiveness = 0.8
	eruption.preprocess = 0.0
	eruption.emitting = false
	eruption.material = additive()
	mountain.add_child(eruption)


## The mountain wakes (PIX-392): its embers thrown up all at once.
func erupt() -> void:
	eruption.restart()


## Mist lying along the valley at the mountains' feet, rolling west: the
## Mire's soft fog (title_life.gdshader) over the world's cloud noise
## (LightRig.cloud_noise), in moonlit grey, thinning toward its top and
## bottom.
func _mist() -> void:
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0.4)])
	var thinning := GradientTexture2D.new()
	thinning.gradient = fade
	thinning.width = 1
	thinning.height = 32
	thinning.fill_to = Vector2(0, 1)
	var mist := TextureRect.new()
	mist.texture = thinning
	mist.stretch_mode = TextureRect.STRETCH_SCALE
	mist.position = MIST.position
	mist.size = MIST.size
	mist.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Wider than the view on purpose, for the camera: not a layout to fit.
	mist.set_meta(Layout.DECOR, true)
	var material := _life(0.0, false)
	material.set_shader_parameter("mist", true)
	material.set_shader_parameter("noise", preload("res://scripts/light_rig.gd").cloud_noise())
	material.set_shader_parameter("mist_color", Vector3(MIST_SHADE.r, MIST_SHADE.g, MIST_SHADE.b))
	material.set_shader_parameter("mist_strength", MIST_STRENGTH)
	mist.material = material
	_layer(DEPTH["mist"]).add_child(mist)


## Moonlight falling from the moon in shafts down toward the valley (PIX-392):
## faint, soft at their sides, breathing slowly, each wider at its foot and
## gone by it.
func _shafts() -> void:
	var sky := _layer(DEPTH["clouds"])
	for i in SHAFTS.size():
		var spec: Array = SHAFTS[i]
		var down := Vector2(-sin(spec[0]), cos(spec[0]))
		var across := Vector2(down.y, -down.x)
		var head := MOON + down * 20.0
		var foot := MOON + down * float(spec[2])
		var half := float(spec[1]) / 2.0
		var beam := Polygon2D.new()
		beam.polygon = PackedVector2Array([head + across * 8.0, head - down * 3.0, head - across * 8.0, foot - across * half, foot + down * 12.0, foot + across * half])
		var light := Color(0.78, 0.82, 1.0, spec[3])
		var none := Color(light, 0.0)
		beam.vertex_colors = PackedColorArray([none, light, none, none, Color(light, float(spec[3]) * 0.3), none])
		beam.material = additive()
		sky.add_child(beam)
		shafts.append([beam, spec[3], i * 2.1])


## Fafnyr close by, for the entrance's pass (PIX-392): his shape against
## the night (Wyrm) and the fire he breathes.
func _wyrm() -> void:
	wyrm = Wyrm.new()
	wyrm.visible = false
	add_child(wyrm)
	breath = CPUParticles2D.new()
	breath.amount = 110
	breath.lifetime = 0.9
	breath.emitting = false
	breath.texture = _puff_texture()
	breath.direction = Vector2(-1.0, 0.45)
	breath.spread = 14.0
	breath.initial_velocity_min = 140.0
	breath.initial_velocity_max = 200.0
	breath.damping_min = 70.0
	breath.damping_max = 110.0
	breath.gravity = Vector2(0, -20)
	var sizes := Curve.new()
	sizes.add_point(Vector2(0, 0.25))
	sizes.add_point(Vector2(1, 1.0))
	breath.scale_amount_curve = sizes
	breath.scale_amount_min = 5.0
	breath.scale_amount_max = 6.0
	var heat := Gradient.new()
	heat.offsets = PackedFloat32Array([0.0, 0.2, 0.55, 1.0])
	heat.colors = PackedColorArray([Color("fffbe0"), Color("fbf236"), Color("df7126"), Color(0.67, 0.2, 0.2, 0.0)])
	breath.color_ramp = heat
	breath.material = additive()
	add_child(breath)


## Fafnyr in flight (PIX-392), facing west, his shape against the night:
## head and horn, neck, body, the tail's spade, legs tucked, the near wing
## beating (`stroke`: 0 up, 1 down) and the far one a beat behind it; the
## moon on his upper edges, the mountain's fire under him. Shade drew no
## dragon on the wing this size: ours, in the title's colours.
class Wyrm:
	extends Node2D
	const HULL := [
		Vector2(-60, -1), Vector2(-55, -5), Vector2(-49, -7), Vector2(-45, -12), Vector2(-40, -17),
		Vector2(-41, -9), Vector2(-34, -8), Vector2(-26, -9), Vector2(-18, -10), Vector2(-6, -11),
		Vector2(6, -10), Vector2(18, -7), Vector2(32, -4), Vector2(46, -2), Vector2(58, -3), Vector2(65, -7),
		Vector2(70, -11), Vector2(72, -3), Vector2(67, 1), Vector2(56, 2), Vector2(44, 3), Vector2(30, 3),
		Vector2(18, 5), Vector2(6, 7), Vector2(-8, 7), Vector2(-20, 4), Vector2(-30, 2), Vector2(-40, 1),
		Vector2(-48, 3), Vector2(-56, 3),
	]
	const LEGS := [
		[Vector2(-12, 6), Vector2(-7, 6), Vector2(-5, 11), Vector2(-10, 12)],
		[Vector2(10, 5), Vector2(15, 5), Vector2(19, 11), Vector2(14, 12)],
	]
	## The wing from the shoulder: wrist, tip and two fingers, up and down.
	const SHOULDER := Vector2(-12, -9)
	const ROOT := Vector2(12, -8)
	const UP := [Vector2(-20, -34), Vector2(4, -54), Vector2(18, -37), Vector2(25, -20)]
	const DOWN := [Vector2(-22, 12), Vector2(-6, 38), Vector2(10, 29), Vector2(20, 14)]
	const BODY := Color("0b0711")
	const FAR := Color("1a1530")
	const MOONLIT := Color("37336a")
	const FIRELIT := Color("6e2616")
	var stroke := 0.0

	func _draw() -> void:
		_fan(_wing(clampf(stroke + 0.25, 0.0, 1.0), Vector2(9, -3), 1.0), Vector2.ZERO, FAR)
		var near := _wing(stroke, Vector2.ZERO, 1.25)
		var body: Array[PackedVector2Array] = [PackedVector2Array(HULL), PackedVector2Array(LEGS[0]), PackedVector2Array(LEGS[1])]
		for edge: Array in [[Vector2(1, -1), MOONLIT], [Vector2(0, 1), FIRELIT], [Vector2.ZERO, BODY]]:
			_fan(near, edge[0], edge[1])
			for shape in body:
				draw_colored_polygon(Transform2D(0.0, edge[0]) * shape, edge[1])

	## A wing as triangles fanned from its shoulder: edge on, mid-stroke, it
	## has no area to triangulate, and a fan draws it as the thin line it is.
	func _fan(wing: PackedVector2Array, shift: Vector2, color: Color) -> void:
		var colors := PackedColorArray([color, color, color])
		for i in range(1, wing.size() - 1):
			draw_primitive(PackedVector2Array([wing[0] + shift, wing[i] + shift, wing[i + 1] + shift]), colors, PackedVector2Array())

	## The wing at `at` of its stroke, its membrane scalloped between the
	## fingers back to the body.
	static func _wing(at: float, shift: Vector2, size: float) -> PackedVector2Array:
		var bones: Array[Vector2] = []
		for i in UP.size():
			bones.append(SHOULDER + (UP[i].lerp(DOWN[i], at) - SHOULDER) * size + shift)
		var wing := PackedVector2Array([SHOULDER + shift, bones[0], bones[1]])
		var reach: Array[Vector2] = [bones[1], bones[2], bones[3], ROOT + shift]
		for i in 3:
			var middle: Vector2 = reach[i].lerp(reach[i + 1], 0.5)
			wing.append(middle.lerp(Vector2(0, -9) + shift, 0.2))
			wing.append(reach[i + 1])
		return wing


## Where the dragon is `p` of the way through its pass, in art pixels: in
## from the east by the moon, down low over the valley, up and away west.
static func wyrm_at(p: float) -> Vector2:
	return Vector2(lerpf(ART.x + 60.0, -60.0, p), 60.0 + 96.0 * sin(p * PI) + 4.0 * sin(p * TAU * 3.0))


## The dragon `p` of the way through its pass (outside 0..1, gone),
## breathing fire on the valley over BREATH.
func fly_wyrm(p: float) -> void:
	wyrm.visible = p >= 0.0 and p <= 1.0
	breath.emitting = wyrm.visible and p >= BREATH.x and p <= BREATH.y
	if wyrm.visible:
		wyrm.position = wyrm_at(p).round()
		wyrm.stroke = 0.5 - 0.5 * cos(p * TAU * WINGBEATS)
		wyrm.queue_redraw()
		breath.position = wyrm.position + MOUTH


## What stands nearest (PIX-392), dark against the moonlit street and
## travelling further than it as the camera drifts: a tree at the left, its
## crown over the view's corner, and at the right a banner's pole, the
## banner swaying from its crossbar beside a lit lantern. Our own pieces, in
## the night's darkest blue with the moon on their edges: drawn without the
## pack too.
func _near() -> void:
	var near := _layer(DEPTH["near"])
	var tree := Sprite2D.new()
	tree.texture = _near_tree()
	tree.centered = false
	tree.offset = Vector2(0, -tree.texture.get_height())
	tree.position = NEAR_TREE
	tree.material = _life(1.2, false)
	near.add_child(tree)
	var pole := Sprite2D.new()
	pole.texture = _near_pole()
	pole.centered = false
	pole.offset = -Vector2(pole.texture.get_size()) + Vector2(2, 0)
	pole.position = NEAR_POLE
	near.add_child(pole)
	var top := NEAR_POLE - Vector2(0, pole.texture.get_height())
	banner = Sprite2D.new()
	banner.texture = _banner_texture()
	banner.centered = false
	banner.position = top + Vector2(-27, 5)
	near.add_child(banner)
	var lantern := Sprite2D.new()
	lantern.texture = HamletArt.texture("lantern")
	lantern.centered = false
	lantern.position = top + Vector2(-42, -2)
	near.add_child(lantern)
	var glass := Sprite2D.new()
	glass.texture = HamletArt.texture("lantern_lit")
	glass.centered = false
	glass.position = lantern.position
	near.add_child(glass)
	var halo := Sprite2D.new()
	halo.texture = glow_texture(12, Color("ffb050"), 0.45, 4)
	halo.material = additive()
	halo.position = lantern.position + HamletArt.LANTERN_GLASS
	near.add_child(halo)
	flames.append([halo, 2.7])


static var _tree: ImageTexture
static var _pole: ImageTexture
static var _banner: ImageTexture


## The near tree, a dark shape: a leaning trunk and a bough, the crown in
## many small ragged clumps about three hearts, the moon catching the edges
## that face it (east and up).
static func _near_tree() -> ImageTexture:
	if _tree != null:
		return _tree
	var image := Image.create(110, 290, false, Image.FORMAT_RGBA8)
	for y in range(90, 290):
		var x := 22 + int((290 - y) * 0.05)
		image.fill_rect(Rect2i(x, y, 8 if y > 210 else 6, 1), NEAR_DARK)
	for i in 30:
		image.fill_rect(Rect2i(28 + i, 150 - i, 3, 3), NEAR_DARK)
	var rng := RandomNumberGenerator.new()
	rng.seed = 392
	for heart: Vector2 in [Vector2(34, 46), Vector2(70, 92), Vector2(18, 100)]:
		for i in 16:
			var at := heart + Vector2(rng.randf_range(-30, 30), rng.randf_range(-24, 24))
			var r := rng.randf_range(6.0, 12.0)
			for y in range(int(at.y - r), int(at.y + r) + 1):
				for x in range(int(at.x - r), int(at.x + r) + 1):
					var d := Vector2((x - at.x) / r, (y - at.y) / (r * 0.8)).length_squared()
					if x >= 0 and x < image.get_width() and y >= 0 and d < 1.0 - 0.35 * rng.randf():
						image.set_pixel(x, y, NEAR_DARK)
	for y in range(1, 290):
		for x in range(0, 109):
			if image.get_pixel(x, y).a > 0.0 and image.get_pixel(x + 1, y - 1).a == 0.0:
				image.set_pixel(x, y, NEAR_RIM)
	_tree = ImageTexture.create_from_image(image)
	return _tree


## The banner's pole: a post with a crossbar and a knob at its top.
static func _near_pole() -> ImageTexture:
	if _pole == null:
		var image := Image.create(46, 262, false, Image.FORMAT_RGBA8)
		image.fill_rect(Rect2i(42, 4, 3, 258), NEAR_DARK)
		image.fill_rect(Rect2i(44, 6, 1, 256), NEAR_RIM)
		image.fill_rect(Rect2i(41, 0, 5, 4), NEAR_DARK)
		image.fill_rect(Rect2i(0, 5, 46, 2), NEAR_DARK)
		image.fill_rect(Rect2i(0, 5, 42, 1), NEAR_RIM)
		_pole = ImageTexture.create_from_image(image)
	return _pole


## Pixelheim's banner in the moon's light: deep red cloth hung from a gold
## rod, a gold edge and the village's flame on it, cut in a swallowtail.
static func _banner_texture() -> ImageTexture:
	if _banner == null:
		var cloth := Color("4a1622")
		var fold := Color("2e0c16")
		var gold := Color("8c6a2c")
		var image := Image.create(20, 62, false, Image.FORMAT_RGBA8)
		for y in 62:
			for x in 20:
				# The swallowtail: the bottom's middle cut away.
				if y > 50 and absi(x * 2 - 19) < (y - 50) * 2:
					continue
				var edge := x < 2 or x > 17 or y < 3
				image.set_pixel(x, y, gold if edge else fold if x % 6 == 4 else cloth)
		# The flame: a drop rising to a point, in gold.
		for y in range(16, 36):
			var half := int(5.0 * sin(clampf((y - 14) / 22.0, 0.0, 1.0) * PI * 0.9))
			for x in range(10 - half, 10 + half):
				image.set_pixel(x, y, gold)
		_banner = ImageTexture.create_from_image(image)
	return _banner


## Ash drifting down off the mountain over everything (PIX-392): grey
## flecks, and now and then a spark still glowing.
func _ash() -> void:
	for spec: Array in [[56, Color(0.62, 0.6, 0.7, 0.55), false], [12, Color(1.0, 0.62, 0.3, 0.9), true]]:
		var flecks := Motes.over_view(spec[0], 16.0, Vector2(-0.35, 1.0), 25.0, Vector2(3, 8), Vector2(-1.5, 1.5))
		flecks.position = ART / 2.0
		flecks.emission_rect_extents = ART / 2.0 + Vector2(30, 30)
		var fade := Gradient.new()
		fade.offsets = PackedFloat32Array([0.0, 0.15, 0.8, 1.0])
		var color: Color = spec[1]
		fade.colors = PackedColorArray([Color(color, 0.0), color, color, Color(color, 0.0)])
		flecks.color_ramp = fade
		if spec[2]:
			flecks.material = additive()
		if still:
			flecks.speed_scale = 0.0
		add_child(flecks)


func _particles(at: Vector2, amount: int, life: float, color: Color, gravity: Vector2, speed: float, size_from: float, size_to: float) -> CPUParticles2D:
	var puffs := CPUParticles2D.new()
	# In their layer's own space: they travel with it as the camera drifts.
	puffs.local_coords = true
	puffs.position = at
	puffs.amount = amount
	puffs.lifetime = life
	puffs.preprocess = life
	puffs.texture = _puff_texture()
	puffs.direction = Vector2.UP
	puffs.spread = 12.0
	puffs.gravity = gravity
	puffs.initial_velocity_min = speed * 0.6
	puffs.initial_velocity_max = speed
	var sizes := Curve.new()
	sizes.add_point(Vector2(0, size_from / 4.0))
	sizes.add_point(Vector2(1, size_to / 4.0))
	puffs.scale_amount_curve = sizes
	puffs.scale_amount_max = 4.0
	puffs.scale_amount_min = 4.0
	var fade := Gradient.new()
	fade.set_color(0, color)
	fade.set_color(1, Color(color, 0.0))
	puffs.color_ramp = fade
	if still:
		puffs.speed_scale = 0.0
	return puffs


static var _puff: ImageTexture


## A small round puff in pixels, for smoke and embers.
static func _puff_texture() -> ImageTexture:
	if _puff == null:
		var image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
		for y in 4:
			for x in 4:
				if not ((x == 0 or x == 3) and (y == 0 or y == 3)):
					image.set_pixel(x, y, Color.WHITE)
		_puff = ImageTexture.create_from_image(image)
	return _puff


## A light in stepped rings, the way pixel games draw glow.
static func glow_texture(radius: int, color: Color, peak: float, steps: int) -> ImageTexture:
	var size := radius * 2
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5 - radius, y + 0.5 - radius).length() / radius
			if d >= 1.0:
				continue
			var level := ceilf((1.0 - d) * steps) / steps
			image.set_pixel(x, y, Color(color, peak * level * level))
	return ImageTexture.create_from_image(image)


static func additive() -> CanvasItemMaterial:
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return material


## Dark hills with a crest of pines between the mountains and the village,
## the pines leaning in the wind.
func _hills() -> void:
	var hills := _layer(DEPTH["hills"])
	var sway := _life(PINE_SWAY, false)
	var noise := FastNoiseLite.new()
	noise.seed = 5
	noise.frequency = 0.02
	var tops := PackedInt32Array()
	for x in range(-24, int(ART.x) + 24):
		var y := 270.0
		for i in HILLS.size() - 1:
			var a: Array = HILLS[i]
			var b: Array = HILLS[i + 1]
			if x >= a[0] and x <= b[0]:
				y = lerpf(a[1], b[1], smoothstep(0.0, 1.0, float(x - a[0]) / (b[0] - a[0])))
		tops.append(int(round(y + noise.get_noise_1d(x) * 3.0)))
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	# Two rows of pines: the back row darker and higher on the slope.
	for row in 2:
		var x := -20.0 + row * 6
		while x < ART.x + 20:
			var top: int = tops[clampi(int(x) + 24, 0, tops.size() - 1)]
			var pine := Sprite2D.new()
			var tile: int = PINES[rng.randi() % PINES.size()]
			pine.texture = _world_tile(tile)
			pine.centered = false
			pine.position = Vector2(int(x), top - 13 + row * 5)
			pine.modulate = Color(0.1, 0.12, 0.22) if row == 0 else Color(0.13, 0.17, 0.28)
			pine.material = sway
			hills.add_child(pine)
			x += rng.randf_range(7.0, 15.0) if row == 1 else rng.randf_range(5.0, 11.0)
		if row == 0:
			var ground := Ridge.new()
			ground.tops = tops
			ground.left = -24
			ground.base = 330
			ground.fill = Color("0d1222")
			ground.rim = Color("1a2240")
			hills.add_child(ground)


func _world_tile(tile: int) -> AtlasTexture:
	var region := AtlasTexture.new()
	region.atlas = load(PunyTerrain.SHEET)
	region.region = PunyTerrain.region(tile)
	return region


## The street: three cottages from the Medieval Age pack around the square's
## fountain on the lakeside, torches and fences between, trees along the
## bank, the hero and the watchman out.
func _village() -> void:
	var near := _layer(DEPTH["village"])
	village = Node2D.new()
	village.modulate = MOONLIT
	near.add_child(village)
	lights = Node2D.new()
	near.add_child(lights)
	var ground := TileMapLayer.new()
	ground.tile_set = PunyTerrain.tileset()
	village.add_child(ground)
	for x in range(-3, 43):
		for y in range(18, 23):
			var tile: int = GRASS[absi(x * 7 + y * 3) % GRASS.size()]
			if y == STREET / 16:
				tile = ROAD_EDGE
			elif y > STREET / 16:
				tile = ROAD[absi(x * 5 + y) % ROAD.size()]
			PunyTerrain.place(ground, Vector2i(x, y), tile)
	_lake()
	if not PunyTown.available():
		return
	var grid := {}
	_house(grid, -2, 10, 0, 8, 4, "roof_thatch")
	_house(grid, 27, 35, 27, 35, 31, "roof")
	_house(grid, 37, 43, 99, 0, 40, "roof_moss")
	var plan := PunyTown.plan(grid)
	# Low houses carry no chimney in the town's grammar; these get one each.
	for x in [6, 33, 41]:
		var top := STREET / 16 - (5 if x != 41 else 4)
		plan["decor"][Vector2i(x, top)] = PunyTown.CHIMNEY[0]
		plan["decor"][Vector2i(x, top + 1)] = PunyTown.CHIMNEY[1]
	var houses := TileMapLayer.new()
	houses.tile_set = PunyTown.tileset()
	village.add_child(houses)
	for cell: Vector2i in plan["pieces"]:
		PunyTown.place(houses, cell, plan["pieces"][cell])
		if plan["pieces"][cell] == PunyTown.WINDOW:
			_lit_window(Vector2(cell * 16))
	for cell: Vector2i in plan["decor"]:
		PunyTown.place(houses, cell, plan["decor"][cell])
		if plan["decor"][cell] == PunyTown.CHIMNEY[0]:
			var smoke := _particles(Vector2(cell * 16) + Vector2(8, 4), 10, 7.0, Color(0.55, 0.55, 0.7, 0.35), Vector2(-1.2, 0), 5.0, 1.5, 3.0)
			village.add_child(smoke)
	var street := Node2D.new()
	street.y_sort_enabled = true
	village.add_child(street)
	for x in [13, 14, 15, 24, 25]:
		var mask := (2 if x != 15 and x != 25 else 0) | (8 if x != 13 and x != 24 else 0)
		_tile_sprite(street, PunyProps.FENCE[mask], Vector2(x * 16, 304))
	_tile_sprite(street, PunyProps.BARREL, Vector2(11 * 16, 304))
	_tile_sprite(street, PunyProps.CRATE, Vector2(26 * 16, 304))
	for x in [12, 23]:
		_torch(Vector2(x * 16, 304))
	var fountain := AnimatedSprite2D.new()
	fountain.sprite_frames = PunyProps.fountain_sprite_frames()
	fountain.centered = false
	fountain.position = Vector2(304, 296)
	fountain.play()
	street.add_child(fountain)
	# Lit at night as the square's is (PIX-382): its water drawn again
	# unshaded, a cold light on the paving.
	var jet := AnimatedSprite2D.new()
	jet.sprite_frames = PunyProps.fountain_lit_frames()
	jet.centered = false
	jet.position = fountain.position
	jet.play()
	lights.add_child(jet)
	_light(fountain.position + Vector2(16, 18), FOUNTAIN_LIGHT, false)
	_trees(street)
	_market(street)
	var hero_spec := GameState.upkeep.hero_art()
	var hero := AnimatedSprite2D.new()
	hero.sprite_frames = PunyArt.frames(hero_spec)
	hero.play(PunyArt.pick(hero.sprite_frames, "idle", "up"))
	hero.self_modulate = hero_spec.get("tint", Color.WHITE)
	hero.position = Vector2(350, 334 + PunyArt.lift(hero_spec))
	street.add_child(hero)
	watchman = Node2D.new()
	watchman.position = Vector2(90, 344)
	street.add_child(watchman)
	var guard_spec := {"sheet": WATCHMAN, "family": "puny"}
	var guard := AnimatedSprite2D.new()
	guard.name = "Figure"
	guard.sprite_frames = PunyArt.frames(guard_spec)
	guard.play(PunyArt.pick(guard.sprite_frames, "walk", "right"))
	guard.speed_scale = PunyArt.walk_speed_scale(guard_spec, WATCH_PACE)
	guard.position = Vector2(0, PunyArt.lift(guard_spec))
	watchman.add_child(guard)
	lantern = Sprite2D.new()
	lantern.position = watchman.position + Vector2(5, -4)
	lantern.texture = glow_texture(20, Color("ffb050"), 0.36, 4)
	lantern.material = additive()
	lights.add_child(lantern)
	lantern_light = _light(lantern.position, LANTERN_LIGHT, false)
	# Held still, Shade's own loops stop too: a picture, not a scene.
	if still:
		for figure: AnimatedSprite2D in [guard, hero, fountain, jet]:
			figure.stop()
	_fireflies()


## The lake behind the street: Shade's river water on the dual grid (the
## world's, PunyTerrain.ground_tiles), from the forest's foot down to the
## bank, its swell and glints on the world's clock (title_life.gdshader).
## It runs under every house, so the camera never finds its end.
func _lake() -> void:
	var size := Vector2i(LAKE_COLUMNS.y - LAKE_COLUMNS.x + 1, LAKE_ROWS.y - LAKE_ROWS.x + 1)
	var grid := {}
	for y in size.y:
		for x in size.x:
			grid[Vector2i(x, y)] = "water" if LAKE_ROWS.x + y < LAKE_ROWS.y else "grass"
	var lake := TileMapLayer.new()
	lake.tile_set = PunyTerrain.tileset()
	# A dual tile sits on the corner its four cells share, half a tile up-left.
	lake.position = Vector2(LAKE_COLUMNS.x * 16 - 8, LAKE_ROWS.x * 16 - 8)
	var tiles := PunyTerrain.ground_tiles(grid, size)
	for cell: Vector2i in tiles:
		# The first row of corners would rise over the forest's foot, the last
		# lies on the street's own bank.
		if cell.y >= 1 and cell.y < size.y:
			PunyTerrain.place(lake, cell, tiles[cell])
	lake.material = _life(0.0, true)
	# A light multiplies what it falls on, so lamplight would only turn Shade's
	# water teal: the flames' warm halos fall on it instead.
	lake.set_meta(UNLIT, true)
	village.add_child(lake)


## Shade's trees along the bank, leaning in the wind, each on its own beat.
func _trees(street: Node) -> void:
	var sway := _life(TREE_SWAY, false)
	for spec: Array in TREES:
		var tile: int = spec[0]
		var tiles: Vector2i = spec[1]
		var art := AtlasTexture.new()
		art.atlas = load(PunyTown.SHEET)
		art.region = Rect2(Vector2((tile % PunyTown.COLUMNS) * 16, (tile / PunyTown.COLUMNS) * 16), Vector2(tiles * 16))
		var tree := Sprite2D.new()
		tree.texture = art
		tree.centered = false
		# Sorted and leaning from its foot.
		tree.offset = Vector2(-tiles.x * 8, -tiles.y * 16)
		tree.position = spec[2]
		tree.material = sway
		street.add_child(tree)


## The title's open air on what grows or flows (shaders/title_life.gdshader):
## leaning `sway` pixels at its top, or the water's life (the mist turns on
## its own).
static func _life(sway: float, water: bool) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/title_life.gdshader")
	material.set_shader_parameter("sway", sway)
	material.set_shader_parameter("water", water)
	return material


## A real light in the village at `at` (spec: [reach, colour, strength]),
## among what shines; a flickering one joins `lamps`.
func _light(at: Vector2, spec: Array, flicker: bool) -> PointLight2D:
	var light := PointLight2D.new()
	light.texture = Lights.soft()
	light.texture_scale = float(spec[0]) * 2.0 / Lights.TEXTURE_PX
	light.color = lit(spec[1], DesktopLook.linear)
	light.energy = float(spec[2])
	light.range_item_cull_mask = LIT_MASK
	# A light reaches canvas layer 0 alone unless told: the title draws on its
	# own layer (7), a story borrowing the scene on another.
	light.range_layer_min = -512
	light.range_layer_max = 512
	light.position = at
	lights.add_child(light)
	if flicker:
		lamps.append([light, float(spec[2]), fmod(absf(at.x * 0.37 + at.y * 0.61), TAU)])
	return light


## A light's colour over the moonlit village. A 2D light adds its colour
## times what it falls on, and the village wears the moonlight as its
## modulate, so the colour picked by eye is divided by the moonlight: what
## the light adds is its own colour on Shade's, as the world's lights add to
## its night (Lights). On the desktop app's linear canvas both are linear.
static func lit(color: Color, is_linear: bool) -> Color:
	var light := DesktopLook.canvas_color(color, is_linear)
	var moon := DesktopLook.canvas_color(MOONLIT, is_linear)
	return Color(light.r / moon.r, light.g / moon.g, light.b / moon.b)


## The village's art answers to its lights (LIT_MASK), but for the lake;
## nothing else on the canvas does.
static func _answer_lights(node: Node) -> void:
	if node.has_meta(UNLIT):
		return
	if node is CanvasItem:
		(node as CanvasItem).light_mask |= LIT_MASK
	for child in node.get_children():
		_answer_lights(child)


## The glow over the backdrop (the world's pass, PIX-222), under the title's
## words: the moon, the flames, the lit windows and the glints bloom softly.
## The player's Glow setting turns it off here too.
func _glow() -> void:
	_bloom_copy = BackBufferCopy.new()
	_bloom_copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	add_child(_bloom_copy)
	bloom = ColorRect.new()
	bloom.size = ART
	bloom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/bloom.gdshader")
	material.set_shader_parameter("strength", GLOW)
	bloom.material = material
	add_child(bloom)
	_show_glow()


func _show_glow() -> void:
	bloom.visible = GameState.settings.glow
	_bloom_copy.visible = bloom.visible


## A house over columns a..b standing on the street, four rows high; its
## gable (the 9 columns g0..g9, a door at `door`) rises a row higher.
func _house(grid: Dictionary, a: int, b: int, g0: int, g9: int, door: int, roof: String) -> void:
	var bottom := STREET / 16 - 1
	for x in range(a, b + 1):
		var top := bottom - 4 if x >= g0 and x <= g9 else bottom - 3
		for y in range(top, bottom + 1):
			grid[Vector2i(x, y)] = roof
	grid[Vector2i(door, bottom)] = "door"


func _tile_sprite(parent: Node, tile: int, at: Vector2) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = PunyProps.texture(tile)
	sprite.centered = false
	sprite.offset = Vector2(0, -16)
	sprite.position = at + Vector2(0, 16)
	parent.add_child(sprite)
	return sprite


## A torch: its flame burns at full colour over the moonlit street, in a pool
## of real light that flickers, embers rising off it.
func _torch(at: Vector2) -> void:
	var flame := AnimatedSprite2D.new()
	flame.sprite_frames = PunyProps.animation(PunyProps.LAMP_FRAMES, PunyProps.LAMP_FPS)
	flame.centered = false
	flame.position = at
	flame.play()
	if still:
		flame.stop()
	flame.frame = absi(int(at.x)) % PunyProps.LAMP_FRAMES.size()
	lights.add_child(flame)
	var glow := Sprite2D.new()
	glow.texture = glow_texture(24, Color("ff9a40"), 0.32, 5)
	glow.material = additive()
	glow.position = at + Vector2(8, 4)
	lights.add_child(glow)
	flames.append([glow, at.x * 0.37])
	_light(at + Vector2(8, 6), TORCH_LIGHT, true)
	var embers := Motes.make_embers(3)
	embers.local_coords = true
	embers.position = at + Vector2(8, 3)
	embers.emitting = not still
	lights.add_child(embers)


## A window lit from within: its panes glow amber, and the candle's light
## falls on the wall round it and the ground below.
func _lit_window(at: Vector2) -> void:
	var panes := Sprite2D.new()
	panes.texture = _panes_texture()
	panes.centered = false
	panes.position = at
	lights.add_child(panes)
	var glow := Sprite2D.new()
	glow.texture = glow_texture(14, Color("ffb050"), 0.3, 4)
	glow.material = additive()
	glow.position = at + Vector2(8, 6)
	lights.add_child(glow)
	_light(at + Vector2(8, 8), WINDOW_LIGHT, false)


## The window tile's glass, recoloured as lamplight (the frame stays
## moonlit underneath): bright panes, warm shadows in the glazing bars -
## the world's lit windows wear the same (LampArt.panes, PIX-311).
static func _panes_texture() -> ImageTexture:
	return LampArt.panes()


func _fireflies() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var texture := glow_texture(3, Color("e4ff8a"), 1.0, 2)
	for i in 16:
		var fly := Sprite2D.new()
		fly.texture = texture
		fly.material = additive()
		var home := Vector2(rng.randf_range(0, ART.x), rng.randf_range(262, 300))
		fly.position = home
		fly.modulate.a = 0.6
		lights.add_child(fly)
		fireflies.append([fly, home, rng.randf_range(0, TAU)])


func _process(delta: float) -> void:
	# Glow can be turned off in the options, over the title.
	_show_glow()
	if still:
		return
	clock += delta
	_keep_time()
	for fire: Array in flames:
		var glow: Sprite2D = fire[0]
		glow.modulate.a = 0.85 + 0.15 * sin(clock * 9.0 + fire[1]) * sin(clock * 3.3 + fire[1])
	for lamp: Array in lamps:
		var light: PointLight2D = lamp[0]
		var phase: float = lamp[2]
		light.energy = float(lamp[1]) * (1.0 + 0.07 * sin(clock * 8.3 + phase) + 0.04 * sin(clock * 21.7 + phase * 1.9))
	# The fire breathes, and roars up when the mountain wakes (`flare`).
	summit_glow.modulate.a = minf(1.0, 0.75 + 0.25 * sin(clock * 1.3) + flare)
	summit_glow.scale = Vector2.ONE * (1.0 + 1.4 * flare)
	# Awake or not, its fire warms the valley a little, breathing slowly.
	valley_glow.modulate.a = maxf(flare, 0.16 + 0.08 * sin(clock * 0.9))
	for shaft: Array in shafts:
		(shaft[0] as CanvasItem).modulate.a = 0.75 + 0.25 * sin(clock * 0.4 + float(shaft[2]))
	banner.skew = 0.05 * sin(clock * 1.1) + 0.02 * sin(clock * 2.9)
	# The camera drifts: near layers travel further, on whole screen pixels.
	camera = drift(clock)
	place()
	for cloud: Array in clouds:
		var node: Sprite2D = cloud[0]
		node.position.x -= cloud[1] * delta
		if node.position.x < -node.texture.get_width() - 10:
			node.position.x = ART.x + 10
	for fly: Array in fireflies:
		var node: Sprite2D = fly[0]
		var phase: float = fly[2]
		node.position = fly[1] + Vector2(sin(clock * 0.5 + phase) * 14, sin(clock * 0.8 + phase * 2.0) * 6)
		node.modulate.a = clampf(sin(clock * 1.7 + phase * 3.0) * 1.5, 0.0, 1.0)
	# No one walks the street without Shade's paid pack.
	if watchman != null:
		_watch(delta)
	_fly(delta)


## Every layer where the camera puts it: drifting (`camera`), and lifted by
## the entrance's `descent`, the near layers further (the sky with the
## stars), on whole screen pixels.
func place() -> void:
	var lift := roundf(descent * TILT * PIXEL) / PIXEL
	var at := camera - Vector2(0, descent * CRANE)
	sky.position.y = lift - TILT
	for layer: Array in layers:
		var node: Node2D = layer[0]
		node.position = parallax(layer[1], layer[2], at) + Vector2(0, lift)


## The world's clock and wind, for the shaders (wind.gdshaderinc): the world
## waits under the title, so the title keeps them meanwhile (the world takes
## them back as it runs again); with reduced motion the clock stops and the
## wind drops.
func _keep_time() -> void:
	RenderingServer.global_shader_parameter_set("world_time", clock)
	RenderingServer.global_shader_parameter_set("world_wind", 0.0 if still else 1.0)


## The watchman walks the street end to end, his lantern and its light with
## him.
func _watch(delta: float) -> void:
	watchman.position.x += watch_dir * WATCH_PACE * delta
	if watchman.position.x > ART.x + DRIFT.x + 24 or watchman.position.x < -DRIFT.x - 24:
		watch_dir = -watch_dir
		var guard: AnimatedSprite2D = watchman.get_node("Figure")
		guard.play(PunyArt.pick(guard.sprite_frames, "walk", "right" if watch_dir > 0 else "left"))
	lantern.position = watchman.position + Vector2(5 * watch_dir, -4)
	lantern_light.position = lantern.position


func _fly(delta: float) -> void:
	if not dragon_rounds:
		return
	if not dragon.visible:
		if clock >= dragon_at:
			dragon.visible = true
			dragon.position = Vector2(ART.x + 30, MOON.y - 6)
		return
	dragon.position.x -= DRAGON_SPEED * delta
	dragon.position.y = MOON.y - 6 + sin(dragon.position.x * 0.04) * 5
	if dragon.position.x < -40:
		dragon.visible = false
		dragon_at = clock + DRAGON_EVERY_S
