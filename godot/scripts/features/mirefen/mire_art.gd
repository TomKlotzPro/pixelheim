class_name MireArt
## areas: field night +mirefen*
## What the Mirefen stands in that Shade's sheets don't draw (PIX-401): its
## dead trees (AshArt's snags, their foot in the mud and moss, not the
## ash), reed beds of cattails, a stilt hut over its pool with a ladder
## down, and the will-o'-wisps' glow (its boardwalks are Shade's own bridge
## planks: MireDressing, PIX-519). Drawn here in code in Shade's palette
## (HamletArt.INKS) with his dark outline, so they sit beside his art; our
## own, so CC0, the same with or without the paid pack.

const TILE := 16
## The fen's mud and moss at a dead tree's foot, for the ash AshArt heaps
## there (its Q and U inks).
const MUD := Color("3b4a2a")
const MOSS := Color("5d6e3a")
## A reed bed's stems, dark to light, and a cattail's head.
const REED_GREENS := [Color("2f5a3a"), Color("4c8a4e"), Color("7bb35a")]
const CATTAIL := Color("79542d")
const CATTAIL_LIT := Color("a1753f")
## How many reed beds there are, picked by the cell.
const REED_BEDS := 4
## A reed bed's picture: a cell wide, this tall, its foot the bottom row.
const REED_SIZE := Vector2i(16, 20)
## The stilt hut at the houses' scale (PIX-557: it stood two cells wide,
## its door 9 pixels and the hero 14): three cells wide, its picture this
## big, its stilts' feet on its cells' foot and its ladder's HUT_BELOW
## pixels under them (onto the boardwalk before it).
const HUT_SIZE := Vector2i(48, 78)
const HUT_BELOW := 12
## Its window's glass, lit at night; its door with its frame and the row
## its wall starts on: where in its picture.
const HUT_WINDOW := Rect2i(27, 31, 10, 8)
const HUT_DOOR := Rect2i(4, 32, 12, 19)
const HUT_WALL := 19
## Its picture, a character a pixel in HamletArt's inks: a pitched reed
## roof gone to moss over plank walls two cells tall, a plank door (fish
## drying on a line over it) and a window, on a deck on four stilts, a
## ladder down the front. The fen's water under it is the map's (MireDressing).
const HUT := [
	"...........oooooooooooooooooooooooooo...........",
	"..........oKKKKKKKKKKKKKKKKKKKKKKKKKKo..........",
	".........oKDDDDDDDDDDDDDDDDDDDDDDDDDDDo.........",
	".........oKDFFFDDDFFFKKDFFvvFFFvFvFvFFo.........",
	"........oKDDFFvDDDFFFKDDFFvFFvvFFvFvFFvo........",
	"........oKDKDKdDDDDDDKDDDdDDDDdDDDDDddXo........",
	".......oFdDKdKdDDDDDDKDDDDDDDDdDDDdddDdXo.......",
	"......oKKdDKdDdFFFvFFDdDDDDDDDdDdFFvDDDFFo......",
	"......oKdXXdXXdvFFFFvXXdXXdXXdXXdvFFXXdvFo......",
	".....oFvFdDDvFFKKDFFFDdDKdDFFFdDddDDFFFFFFo.....",
	".....oFFFdDDFFvKKDFFFdKDKdDFFvdKDdDDvvFFFFo.....",
	"....oKDDDDDKDDdvvFvFvdKDKddFFvdKDDDDDDDdDdFo....",
	"....oKDdDDDKdDdFvFFFFdKDDDdFFFdKDDDdDDDdddFo....",
	"...oFFDdDDDKdDdvvFDKdDDDDDdDDdvFFDDdKKDddDdXo...",
	"..oFFvXXdXXdXXdvFvXXdXXdXXdXXdXXdXXdXXdXXdXdXo..",
	"..oKDDDDDDDDKDdvFFFFvFFvFFFdDddDdDDDKKDdKDFFFo..",
	".oKDDDDDDDDDKKdFFFFvFFFvFFFdDDdKDDDDDDKDKDvvvXo.",
	".oKdXdXdXdXdXdXFFFXdXdXdXdXdXdXdXFvFXdXFFFFFFXo.",
	"oKdXdXdXdXdXdXdFvFdXdXdXdXdXdXdXdvFvdXdvFFvvvdXo",
	".oo322221222212222122221222212222122221222212oo.",
	"..o322221222212222122221222212222122221222212o..",
	"..o55444233332444423333254442333X244442333322o..",
	"..o55444233332444423333254442333X244442333322o..",
	"..o55444233332444423333254442333X244442333322o..",
	"..o554442333325444233X3244442333324X442333X22o..",
	"..o551111111111144233X3244442333324X442333X22o..",
	"..o554h423h332h444233X3244442333324X442333X22o..",
	"..o55ll42ll33ll444233X3244442333324X442333X22o..",
	"..o55hh42hh33hh444233332444X23333244442333X22o..",
	"..o554l423l332l444233332444X23333244442333X22o..",
	"..o554442333325444233332546666666666662333X22o..",
	"..o554442333325444233332545ZZZZ22ZZZZ32333X22o..",
	"..o566666666666544233332545zZZz22zzzz32333322o..",
	"..o551111111111344233332545ZZzz22zzzz32333322o..",
	"..o553222132221344233332545222222222232333322o..",
	"..o553333333333344233332545zzzz22zzzz32333322o..",
	"..o55111111111134423X332445zzzz22zzzz32X33322o..",
	"..o55322213222134423X332445zzzz22zzzz32X33322o..",
	"..o55322213222134423X332445zzzz22zzzz32X33322o..",
	"..o55322213222134423X332445555555555532X33322o..",
	"..o5532221322213442X3332455555555555555333322o..",
	"..o5532221322213442X3332422222222222222333322o..",
	"..o553222132jh13442X3332444423333254442333322o..",
	"..o553222132hi13442X3332444423333254442333322o..",
	"..o5532221322213442333324444233332544X2333322o..",
	"..o5532221322213442333324444233332544X2333322o..",
	"..o5533333333333442333324444233332544X2333322o..",
	"..o5511111111113442333324444233332544X2333322o..",
	"..o553222132221344233332444423333254442333322o..",
	"..o553222132221344233332444423333254442333322o..",
	".oo553222132221322222222222222222222222222222oo.",
	"o5555555555555555555555555555555555555555555555o",
	"o4444244442444424444244442444424444244442444424o",
	"o3333333333333333333333333333333333333333333333o",
	".o42oo45555553oo42o3ooooooooooo42ooooooooooo42o.",
	".o42oo4oooooo3oo42oo3o........o42o.........o42o.",
	".o42oo4oooooo3oo42o.o3o.......o42o.........o42o.",
	".o42oo45555553oo42o..o3o......o42o.........o42o.",
	".o42oo4oooooo3oo42o...o3o.....o42o.........o42o.",
	".o42oo4oooooo3oo42o....o3o....o42o.........o42o.",
	".o42oo45555553oo42o.....o3o...o42o.........o42o.",
	".o42oo4oooooo3oo42o......o3o..o42o.........o42o.",
	".o42oo4oooooo3oo42o.......o3o.o42o.........o42o.",
	".o42oo45555553oo42o........o3oo42o.........o42o.",
	".o42oo4oooooo3oo42o.........o.o42o.........o42o.",
	".o42oo4oooooo3oo42o...........o42o.........o42o.",
	"..oo.o45555553o.oo.............oo...........oo..",
	".....o4oooooo3o.................................",
	".....o4oooooo3o.................................",
	".....o45555553o.................................",
	".....o4oooooo3o.................................",
	".....o4oooooo3o.................................",
	".....o45555553o.................................",
	".....o4oooooo3o.................................",
	".....o4oooooo3o.................................",
	".....o45555553o.................................",
	".....o4oooooo3o.................................",
	"......o......o..................................",
]
## A will-o'-wisp's glow: its pale green, its halo's radius and peak.
const WISP := Color(0.66, 1.0, 0.78)
const WISP_HALO := 14
const WISP_PEAK := 0.5

static var _textures := {}


## A picture by name, made once a session: "snag_<n>", "reeds_<n>",
## "hut", "hut_lit" (its window at night), "wisp" (the bright heart).
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


## The stilt hut (HUT's rows drawn).
static func hut() -> Image:
	var image := Image.create(HUT_SIZE.x, HUT_SIZE.y, false, Image.FORMAT_RGBA8)
	for y in HUT.size():
		var row := String(HUT[y])
		for x in row.length():
			if row[x] != ".":
				image.set_pixel(x, y, HamletArt.INKS[row[x]])
	return image


## The hut's window lit (shown at night, the dark doesn't touch it).
static func hut_window() -> Image:
	var image := Image.create(HUT_SIZE.x, HUT_SIZE.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for y in range(HUT_WINDOW.position.y, HUT_WINDOW.end.y):
		for x in range(HUT_WINDOW.position.x, HUT_WINDOW.end.x):
			# Its glass alone: the bars stay in the night.
			if String(HUT[y])[x] in ["z", "Z"]:
				image.set_pixel(x, y, HamletArt.INKS["a"] if y > HUT_WINDOW.position.y + 3 else HamletArt.INKS["Y"])
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
