class_name TitleScene
extends Node2D
## The title's backdrop (PIX-139): Pixelheim's street at night under the
## Ashen Mountain, in Shade's art, drawn in art pixels at 2x. Far to near: a
## dithered sky, stars, the moon behind drifting cloud, the far ranges, the
## Ashen Mountain smoking with Fafnyr's fire at its summit, pine hills, then
## the village - cottages with lit windows and smoking chimneys, torches, the
## fountain, the watchman on his round, and the hero in the street looking up
## at the mountain. The layers sway on one slow clock, and now and then the
## dragon crosses the moon.
## Reduce motion stills the sway, the clouds, the smoke, the fireflies, the
## watchman and the dragon; flames and water still move.

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
const WATCHMAN := "characters/Human-Soldier-Cyan.png"
## One sway takes this long; the dragon comes this soon, then this often (s).
const SWAY_S := 80.0
const DRAGON_FIRST_S := 4.0
const DRAGON_EVERY_S := 45.0
const DRAGON_SPEED := 36.0

var still := false
var clock := 0.0
## [node, home x, sway in art pixels]
var layers: Array = []
## [node, art pixels per second]
var clouds: Array = []
var dragon: AnimatedSprite2D
var dragon_at := DRAGON_FIRST_S
var summit_glow: Sprite2D
## [node, home, phase]
var fireflies: Array = []
## [glow, phase]
var flames: Array = []
var watchman: Node2D
var lantern: Sprite2D
var watch_dir := 1.0


func _ready() -> void:
	scale = Vector2.ONE * PIXEL
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	still = GameState.settings.reduce_motion
	_sky()
	_stars()
	_moon()
	_clouds()
	_dragon()
	_ridge(FAR_RANGE, 0.0, 268, Color("1d1a3f"), Color("2f2b62"), 3.0, 11)
	_glow_behind()
	var ashen := _ridge(ASHEN, 6.0, 268, Color("0a0918"), Color("2a2654"), 5.0, 23)
	ashen.crater = Vector2i(int(SUMMIT.x) - 6, int(SUMMIT.x) + 6)
	_fire()
	_hills()
	_village()


## The boot splash: the scene as the title opens on it, with no one about
## and nothing in the sky yet.
func as_splash() -> void:
	dragon.visible = false
	watchman.visible = false
	lantern.visible = false


func _sky() -> void:
	var image := Image.create(4, int(ART.y), false, Image.FORMAT_RGBA8)
	var last := SKY.size() - 1
	for y in int(ART.y):
		var t := pow(y / (ART.y - 1.0), 1.4) * last
		var band := mini(int(t), last - 1)
		# Solid bands that dither into the next over their last stretch.
		var into := clampf((t - band - 0.55) / 0.45, 0.0, 1.0)
		for x in 4:
			var threshold: float = (BAYER[(y % 4) * 4 + x] + 0.5) / 16.0
			image.set_pixel(x, y, SKY[band + 1] if into > threshold else SKY[band])
	var sky := TextureRect.new()
	sky.texture = ImageTexture.create_from_image(image)
	sky.stretch_mode = TextureRect.STRETCH_TILE
	sky.size = ART
	add_child(sky)


func _stars() -> void:
	var field := Node2D.new()
	add_child(field)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1984
	for i in 110:
		var at := Vector2(rng.randi_range(0, int(ART.x) - 1), rng.randi_range(0, 200))
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
	parent.add_child(dot)


## A full moon in pixels: a cream disc with a few seas, shaded toward the
## lower left, in stepped rings of light.
func _moon() -> void:
	var halo := Sprite2D.new()
	halo.texture = _glow_texture(56, Color("f4ecd0"), 0.1, 4)
	halo.position = MOON
	add_child(halo)
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
	add_child(disc)


## Long low clouds, moonlit along their tops, drifting west.
func _clouds() -> void:
	for spec: Array in [[150, Vector2(486, 66), 1.6, 5], [110, Vector2(90, 34), 1.0, 9], [190, Vector2(250, 128), 2.2, 13]]:
		var cloud := Sprite2D.new()
		cloud.texture = _cloud_texture(spec[0], spec[3])
		cloud.centered = false
		cloud.position = spec[1]
		add_child(cloud)
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


## Fafnyr, far off, crossing the moon.
func _dragon() -> void:
	var spec := PunyArt.monster("dragon")
	dragon = AnimatedSprite2D.new()
	dragon.sprite_frames = PunyArt.frames(spec)
	dragon.play(PunyArt.pick(dragon.sprite_frames, "walk", "left"))
	dragon.speed_scale = 1.6
	dragon.modulate = Color(0.04, 0.03, 0.09)
	dragon.visible = false
	add_child(dragon)


## A mountain range as a silhouette: the profile through its key points,
## roughened, with moonlight on the slopes that face the moon.
func _ridge(points: Array, sway: float, base: int, fill: Color, rim: Color, rough: float, seed_value: int) -> Ridge:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 0.045
	noise.fractal_octaves = 4
	var margin := 16
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
	layers.append([ridge, 0.0, sway])
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
	summit_glow.texture = _glow_texture(34, Color("ff5a20"), 0.5, 6)
	summit_glow.material = _additive()
	summit_glow.position = SUMMIT + Vector2(0, 6)
	add_child(summit_glow)
	layers.append([summit_glow, summit_glow.position.x, 6.0])


## Over the summit: a plume of smoke lit from below, drifting west, and
## embers riding up out of it.
func _fire() -> void:
	var at := SUMMIT + Vector2(0, 2)
	var smoke := _particles(at, 22, 14.0, Color("6a3036"), Vector2(-1.6, -0.3), 4.0, 3.0, 9.0)
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	fade.colors = PackedColorArray([Color(0.55, 0.22, 0.2, 0.7), Color(0.2, 0.16, 0.3, 0.6), Color(0.16, 0.14, 0.28, 0.0)])
	smoke.color_ramp = fade
	add_child(smoke)
	layers.append([smoke, at.x, 6.0])
	var embers := _particles(at, 10, 4.5, Color("ffa040"), Vector2(-1.2, -1.5), 8.0, 0.25, 0.25)
	embers.spread = 50.0
	embers.material = _additive()
	add_child(embers)
	layers.append([embers, at.x, 6.0])


func _particles(at: Vector2, amount: int, life: float, color: Color, gravity: Vector2, speed: float, size_from: float, size_to: float) -> CPUParticles2D:
	var puffs := CPUParticles2D.new()
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
static func _glow_texture(radius: int, color: Color, peak: float, steps: int) -> ImageTexture:
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


static func _additive() -> CanvasItemMaterial:
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return material


## Dark hills with a crest of pines between the mountains and the village.
func _hills() -> void:
	var hills := Node2D.new()
	add_child(hills)
	layers.append([hills, 0.0, 9.0])
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
## fountain, torches and fences between, the hero and the watchman out.
func _village() -> void:
	var village := Node2D.new()
	village.modulate = MOONLIT
	add_child(village)
	var lights := Node2D.new()
	add_child(lights)
	layers.append([village, 0.0, 14.0])
	layers.append([lights, 0.0, 14.0])
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
			_lit_window(lights, Vector2(cell * 16))
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
		_torch(street, lights, Vector2(x * 16, 304))
	var fountain := AnimatedSprite2D.new()
	fountain.sprite_frames = PunyProps.fountain_sprite_frames()
	fountain.centered = false
	fountain.position = Vector2(304, 296)
	fountain.play()
	street.add_child(fountain)
	var hero_spec := GameState.hero_art()
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
	guard.position = Vector2(0, PunyArt.lift(guard_spec))
	watchman.add_child(guard)
	lantern = Sprite2D.new()
	lantern.position = watchman.position + Vector2(5, -4)
	lantern.texture = _glow_texture(30, Color("ffb050"), 0.38, 5)
	lantern.material = _additive()
	lights.add_child(lantern)
	if still:
		guard.stop()
	_fireflies(lights)


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
## of light that flickers.
func _torch(street: Node, lights: Node, at: Vector2) -> void:
	var flame := AnimatedSprite2D.new()
	flame.sprite_frames = PunyProps.animation(PunyProps.LAMP_FRAMES, PunyProps.LAMP_FPS)
	flame.centered = false
	flame.position = at
	flame.play()
	flame.frame = absi(int(at.x)) % PunyProps.LAMP_FRAMES.size()
	lights.add_child(flame)
	var glow := Sprite2D.new()
	glow.texture = _glow_texture(36, Color("ff9a40"), 0.42, 6)
	glow.material = _additive()
	glow.position = at + Vector2(8, 4)
	lights.add_child(glow)
	flames.append([glow, at.x * 0.37])


## A window lit from within: its panes glow amber and spill a little light.
func _lit_window(lights: Node, at: Vector2) -> void:
	var panes := Sprite2D.new()
	panes.texture = _panes_texture()
	panes.centered = false
	panes.position = at
	lights.add_child(panes)
	var glow := Sprite2D.new()
	glow.texture = _glow_texture(22, Color("ffb050"), 0.3, 4)
	glow.material = _additive()
	glow.position = at + Vector2(8, 6)
	lights.add_child(glow)


static var _panes: ImageTexture


## The window tile's glass, recoloured as lamplight (the frame stays
## moonlit underneath): bright panes, warm shadows in the glazing bars.
static func _panes_texture() -> ImageTexture:
	if _panes == null:
		var tile := PunyProps.texture(PunyTown.WINDOW).get_image()
		tile.convert(Image.FORMAT_RGBA8)
		var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		for y in range(1, 11):
			for x in range(1, 15):
				match tile.get_pixel(x, y).to_html(false):
					"2e2036":
						image.set_pixel(x, y, Color("ffd27a") if y < 6 else Color("ffbb55"))
					"4a3132":
						image.set_pixel(x, y, Color("c9772e"))
		_panes = ImageTexture.create_from_image(image)
	return _panes


func _fireflies(lights: Node) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var texture := _glow_texture(3, Color("e4ff8a"), 1.0, 2)
	for i in 16:
		var fly := Sprite2D.new()
		fly.texture = texture
		fly.material = _additive()
		var home := Vector2(rng.randf_range(0, ART.x), rng.randf_range(262, 300))
		fly.position = home
		fly.modulate.a = 0.6
		lights.add_child(fly)
		fireflies.append([fly, home, rng.randf_range(0, TAU)])


func _process(delta: float) -> void:
	clock += delta
	for fire: Array in flames:
		var glow: Sprite2D = fire[0]
		glow.modulate.a = 0.85 + 0.15 * sin(clock * 9.0 + fire[1]) * sin(clock * 3.3 + fire[1])
	summit_glow.modulate.a = 0.75 + 0.25 * sin(clock * 1.3)
	if still:
		return
	# The sway: near layers travel further, on whole screen pixels.
	var sway := sin(clock * TAU / SWAY_S)
	for layer: Array in layers:
		var node: Node2D = layer[0]
		node.position.x = layer[1] + round(sway * layer[2] * PIXEL) / PIXEL
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
	_watch(delta)
	_fly(delta)


## The watchman walks the street end to end, his lantern with him.
func _watch(delta: float) -> void:
	watchman.position.x += watch_dir * 12.0 * delta
	if watchman.position.x > ART.x + 24 or watchman.position.x < -24:
		watch_dir = -watch_dir
		var guard: AnimatedSprite2D = watchman.get_node("Figure")
		guard.play(PunyArt.pick(guard.sprite_frames, "walk", "right" if watch_dir > 0 else "left"))
	lantern.position = watchman.position + Vector2(5 * watch_dir, -4)


func _fly(delta: float) -> void:
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
