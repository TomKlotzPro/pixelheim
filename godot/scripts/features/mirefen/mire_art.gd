class_name MireArt
## areas: field night +mirefen*
## What the Mirefen stands in that Shade's sheets don't draw (PIX-401): its
## dead trees (AshArt's snags, their foot in the mud and moss, not the
## ash), reed beds of cattails, boardwalks of grey planks on posts, a stilt
## hut over its pool with a ladder down, and the will-o'-wisps' glow. Drawn
## here in code in Shade's palette (HamletArt.INKS) with his dark outline,
## so they sit beside his art; our own, so CC0, the same with or without
## the paid pack.

const TILE := 16
## The fen's mud and moss at a dead tree's foot, for the ash AshArt heaps
## there (its Q and U inks).
const MUD := Color("3b4a2a")
const MOSS := Color("5d6e3a")
## A reed bed's stems, dark to light, and a cattail's head.
const REED_GREENS := [Color("2f5a3a"), Color("4c8a4e"), Color("7bb35a")]
const CATTAIL := Color("79542d")
const CATTAIL_LIT := Color("a1753f")
## How many reed beds and plank patterns there are, picked by the cell.
const REED_BEDS := 4
const PLANKINGS := 4
## A reed bed's picture: a cell wide, this tall, its foot the bottom row.
const REED_SIZE := Vector2i(16, 20)
## A run of boardwalk, a cell along: its planks this wide across the way,
## the posts under them the rest.
const WALK_ACROSS := 10
const WALK_SIZE := Vector2i(16, 12)
## The stilt hut: two cells wide; its picture this big, its stilts' feet in
## its pool HUT_BELOW pixels under its cells (onto the boardwalk before it).
const HUT_SIZE := Vector2i(32, 44)
const HUT_BELOW := 12
## Its window, lit at night: where in its picture.
const HUT_WINDOW := Rect2i(6, 17, 4, 3)
## A will-o'-wisp's glow: its pale green, its halo's radius and peak.
const WISP := Color(0.66, 1.0, 0.78)
const WISP_HALO := 14
const WISP_PEAK := 0.5

static var _textures := {}


## A picture by name, made once a session: "snag_<n>", "reeds_<n>",
## "walk_<n>" (across a row) or "walk_<n>_down" (down a column), "hut",
## "hut_lit" (its window at night), "wisp" (the bright heart).
static func texture(name: String) -> Texture2D:
	if not _textures.has(name):
		_textures[name] = ImageTexture.create_from_image(draw(name))
	return _textures[name]


## Picture `name`, drawn.
static func draw(name: String) -> Image:
	if name.begins_with("snag_"):
		return snag(int(name.trim_prefix("snag_")))
	if name.begins_with("reeds_"):
		return reeds(int(name.trim_prefix("reeds_")))
	if name.begins_with("walk_"):
		var image := walk(int(name.trim_prefix("walk_").get_slice("_", 0)))
		if name.ends_with("_down"):
			image.rotate_90(CLOCKWISE)
		return image
	match name:
		"hut":
			return hut()
		"hut_lit":
			return hut_window()
		_:
			return wisp()


## AshArt's dead tree `n` with its foot in the fen's mud and moss.
static func snag(n: int) -> Image:
	var image := AshArt.draw("snag_%d" % n)
	var ash: Color = AshArt.INKS["Q"]
	var pale: Color = AshArt.INKS["U"]
	for y in image.get_height():
		for x in image.get_width():
			var c := image.get_pixel(x, y)
			if c.is_equal_approx(ash):
				image.set_pixel(x, y, MUD)
			elif c.is_equal_approx(pale):
				image.set_pixel(x, y, MOSS)
	return image


## Reed bed `n`: a clump of stems rising from a dark tuft, the tallest with
## a cattail's brown head, seeded by `n`.
static func reeds(n: int) -> Image:
	var image := Image.create(REED_SIZE.x, REED_SIZE.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 401 + n * 7919
	var foot := REED_SIZE.y - 1
	var stems := 7 + n % 3
	for stem in stems:
		# Spread across the bed, a pixel off either way: drawn anywhere,
		# one bed's stems piled up as one stake (PR #466's review).
		var x := clampi(2 + stem * (REED_SIZE.x - 5) / stems + rng.randi_range(-1, 1), 2, REED_SIZE.x - 3)
		var tall := rng.randi_range(7, REED_SIZE.y - 3)
		var lean := rng.randi_range(-1, 1)
		var green: Color = REED_GREENS[rng.randi_range(0, 2)]
		for rise in tall:
			var at := x + (lean if rise > tall * 2 / 3 else 0)
			image.set_pixel(at, foot - rise, green)
		if rng.randf() < 0.45:
			var top := x + lean
			for dy in 3:
				image.set_pixel(top, foot - tall - dy, CATTAIL if dy > 0 else CATTAIL_LIT)
	# A dark tuft at their foot.
	for x in range(3, REED_SIZE.x - 3):
		if (x + n) % 3 != 0:
			image.set_pixel(x, foot, REED_GREENS[0])
	return _outlined(image)


## A run of boardwalk a cell long, across a row: grey-brown planks across
## the way, a gap between each, one missing here and there, on posts.
static func walk(n: int) -> Image:
	var image := Image.create(WALK_SIZE.x, WALK_SIZE.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var inks := HamletArt.INKS
	# Weathered planks, grey-brown, four pixels each with a thin seam of
	# their own wood darkened between; one gone now and then, the mud dark
	# through the gap. Its edges outlined, its posts under it into the mud
	# every other cell.
	var planks := [inks["4"].lerp(inks["h"], 0.35), inks["3"].lerp(inks["l"], 0.3), inks["4"].lerp(inks["l"], 0.2), inks["3"].lerp(inks["h"], 0.25)]
	var outline: Color = inks["o"]
	for x in WALK_SIZE.x:
		var plank := x / 4
		var wood: Color = planks[(plank * 3 + n) % planks.size()]
		var gone := (n * 5 + plank) % 11 == 4
		image.set_pixel(x, 0, outline)
		image.set_pixel(x, WALK_ACROSS - 1, outline)
		for y in range(1, WALK_ACROSS - 1):
			var c: Color = wood.darkened(0.3) if x % 4 == 3 else (wood.lightened(0.15) if y == 1 else (wood.darkened(0.15) if y == WALK_ACROSS - 2 else wood))
			image.set_pixel(x, y, MUD.darkened(0.4) if gone else c)
	if n % 2 == 0:
		for post_x: int in [3, 12]:
			for y in range(WALK_ACROSS, WALK_SIZE.y):
				image.set_pixel(post_x, y, inks["2"])
				image.set_pixel(post_x - 1, y, outline)
				image.set_pixel(post_x + 1, y, outline)
	return image


## The stilt hut: a thatched roof over plank walls, a dark door and a
## window, on a platform on four stilts standing in its pool, a ladder down
## the front.
static func hut() -> Image:
	var inks := HamletArt.INKS
	var body := Image.create(HUT_SIZE.x, HUT_SIZE.y, false, Image.FORMAT_RGBA8)
	body.fill(Color(0, 0, 0, 0))
	# The stilts and a brace between two.
	for x: int in [4, 12, 19, 27]:
		for y in range(27, 41):
			body.set_pixel(x, y, inks["4"])
			body.set_pixel(x + 1, y, inks["2"])
	for i in 7:
		body.set_pixel(6 + i, 29 + i, inks["3"])
	# The platform's planks.
	for x in range(1, 31):
		body.set_pixel(x, 25, inks["5"])
		body.set_pixel(x, 26, inks["2"] if x % 4 == 0 else inks["4"])
		body.set_pixel(x, 27, inks["3"])
	# The walls' planks, a seam every third pixel.
	for y in range(14, 25):
		for x in range(4, 28):
			body.set_pixel(x, y, inks["2"] if x % 3 == 0 else (inks["4"] if (x / 3) % 2 == 0 else inks["3"]))
	# The door and the window.
	for y in range(16, 25):
		for x in range(13, 19):
			body.set_pixel(x, y, inks["1"] if x == 13 or x == 18 or y == 16 else inks["z"])
	for y in range(HUT_WINDOW.position.y, HUT_WINDOW.end.y):
		for x in range(HUT_WINDOW.position.x, HUT_WINDOW.end.x):
			body.set_pixel(x, y, inks["z"])
	for x in range(HUT_WINDOW.position.x - 1, HUT_WINDOW.end.x + 1):
		body.set_pixel(x, HUT_WINDOW.end.y, inks["5"])
	# The thatch: wider as it falls, strands of straw, the eaves ragged.
	for y in range(1, 16):
		var half := 2 + int(y * 1.05)
		for x in range(15 - half, 17 + half):
			if x < 0 or x >= HUT_SIZE.x:
				continue
			var straw: Color = inks["6"] if (x + y * 2) % 5 == 0 else (inks["5"] if (x + y) % 3 != 0 else inks["4"])
			if y >= 14:
				straw = inks["4"] if (x + y) % 2 == 0 else inks["3"]
			body.set_pixel(x, y, straw)
	# The ladder down the front, onto the boardwalk.
	for y in range(28, HUT_SIZE.y - 1):
		body.set_pixel(14, y, inks["4"])
		body.set_pixel(17, y, inks["3"])
		if y % 3 == 0:
			body.set_pixel(15, y, inks["5"])
			body.set_pixel(16, y, inks["5"])
	_outlined(body)
	# Its pool under it, flat on the ground, the stilts standing in it.
	var image := Image.create(HUT_SIZE.x, HUT_SIZE.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for y in range(HUT_SIZE.y - 9, HUT_SIZE.y - 2):
		for x in HUT_SIZE.x:
			var d := Vector2((x + 0.5 - HUT_SIZE.x / 2.0) / 15.5, (y + 0.5 - (HUT_SIZE.y - 5.5)) / 3.6)
			if d.length() < 1.0:
				image.set_pixel(x, y, MUD.darkened(0.25) if d.length() < 0.8 else MUD)
	image.blend_rect(body, Rect2i(Vector2i.ZERO, HUT_SIZE), Vector2i.ZERO)
	return image


## The hut's window lit (shown at night, the dark doesn't touch it).
static func hut_window() -> Image:
	var image := Image.create(HUT_SIZE.x, HUT_SIZE.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for y in range(HUT_WINDOW.position.y, HUT_WINDOW.end.y):
		for x in range(HUT_WINDOW.position.x, HUT_WINDOW.end.x):
			image.set_pixel(x, y, HamletArt.INKS["a"] if y > HUT_WINDOW.position.y else HamletArt.INKS["Y"])
	return image


## A wisp's bright heart: a pale dot with a dimmer cross round it.
static func wisp() -> Image:
	var image := Image.create(5, 5, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for step: Vector2i in [Vector2i(1, 2), Vector2i(3, 2), Vector2i(2, 1), Vector2i(2, 3)]:
		image.set_pixelv(step, Color(WISP, 0.55))
	image.set_pixel(2, 2, Color(0.92, 1.0, 0.94))
	return image


## A soft halo of `tint` (the wisp's green; the hut's window's warmth),
## smooth to nothing at its rim as MapView's lamps' are, added onto the
## night.
static func halo(tint := WISP, radius := WISP_HALO, peak := WISP_PEAK) -> Texture2D:
	var key := "halo:%s:%d:%f" % [tint.to_html(), radius, peak]
	if not _textures.has(key):
		var size := radius * 2
		var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
		for y in size:
			for x in size:
				var d := Vector2(x + 0.5 - radius, y + 0.5 - radius).length() / radius
				image.set_pixel(x, y, Color(tint, peak * pow(1.0 - d, 2.2)) if d < 1.0 else Color(0, 0, 0, 0))
		_textures[key] = ImageTexture.create_from_image(image)
	return _textures[key]


## Shade's dark outline on every clear pixel beside the figure, in place.
static func _outlined(image: Image) -> Image:
	var ink: Color = HamletArt.INKS["o"]
	var size := image.get_size()
	var marks: Array[Vector2i] = []
	for y in size.y:
		for x in size.x:
			if image.get_pixel(x, y).a > 0.0:
				continue
			for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var next := Vector2i(x, y) + step
				if next.x >= 0 and next.y >= 0 and next.x < size.x and next.y < size.y and image.get_pixelv(next).a > 0.0 and image.get_pixelv(next) != ink:
					marks.append(Vector2i(x, y))
					break
	for cell in marks:
		image.set_pixelv(cell, ink)
	return image
