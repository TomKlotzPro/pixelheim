class_name RouteArt
## What the Post's routes put up beside the road (PIX-322): a fingerpost at
## a fork, and a waystation's hut, bench and ember lamp (its post box is
## HamletArt's, the square's own). Drawn here in code in Shade's palette
## (HamletArt.INKS: his outline, his woods, irons and straw), at 1x on his
## 16 px grid, so they stand beside his art as his; our own, so CC0 like the
## rest of the repository, the same with or without the paid pack.
## Pictures are rows of characters, one a pixel; a piece's foot is its
## bottom row. The ember lamp is a shard of the mountain's warmth in an iron
## cage on a post: dull red by day, and at night its shard alight (`ember`,
## the only part the dark doesn't touch), as a street lamp's glass is.

## A hut's window lit at night, and the ember's glow, in the dark.
const PANE := Color("ffd27a")
const PANE_LOW := Color("ffbb55")
## The ember shard alight, in three beats of its warmth: where it sits in
## the lamp (the cage's inside, its top left) and each beat's rows.
const EMBER_AT := Vector2i(6, 6)
const EMBER_LIT := [
	["..Y.", "aYqa", "aqYa", "aqqY", "aYqa", ".aY."],
	["..a.", "aqYa", "aYqY", "aqqa", "aqaY", ".Ya."],
	["..Y.", "aaqY", "aqqa", "aYqa", "aqYa", ".aa."],
]
const EMBER_FPS := 3.0
## The middle of the shard, in the lamp's pixels: where its halo stands.
const HALO_AT := Vector2(8.0, 8.5)
## The hut's window's glass (its pixels, frame left out), lit at night.
const WINDOW := Rect2i(20, 21, 5, 4)

const PIECES := {
	## A fingerpost at a fork: two arms on a post, the upper pointing one way
	## and the lower the other, letters cut in them; a cap, a little earth at
	## its foot.
	"signpost": [
		"................",
		"................",
		"......oooo......",
		"......o65o......",
		"......o54o......",
		"..oooooooooo....",
		".o6666666665o...",
		".o535335355o....",
		"..oooooooooo....",
		"......o43o......",
		"....oooooooooo..",
		"...o5666666666o.",
		"....o5335335354o",
		"....oooooooooo..",
		"......o43o......",
		"......o43o......",
		"......o32o......",
		"......o43o......",
		"......o43o......",
		"......o43o......",
		"......o32o......",
		"......o43o......",
		"......o43o......",
		".....oo32oo.....",
		"....o233332o....",
		"....oooooooo....",
	],
	## A waystation's hut, two cells wide: a thatched roof over plank walls on
	## a stone footing, its door on the left under the Post's board (a letter
	## drawn on it, sealed red), a window on the right.
	"hut": [
		"................................",
		"................................",
		"................................",
		".........oooooooooooooo.........",
		"..........oooooooooooo..........",
		".........oo4444444444oo.........",
		"........o64565555455554o........",
		".......o6555554555555454o.......",
		".......o6554555565455554o.......",
		"......o645555554556555454o......",
		".....o65565545555554655554o.....",
		"....o6555456555545555564554o....",
		"...o654555555455555545556554o...",
		"..o66555554555565455555545654o..",
		".o6555645555554556555455555544o.",
		"o333333333333333333333333333333o",
		".oooooooooooooooooooooooooooooo.",
		"..11ooooooooo11111111111111111..",
		"..o2oBoBBBoBo3333333333333332o..",
		"..o2oBBoRoBBo4444444444444442o..",
		"..o24ooooooo4444444ooooooo442o..",
		"..o23o11111o3333333oUU2UUo332o..",
		"..o24o12121o4444444o22222o442o..",
		"..o24o12121o4444444ouu2uuo442o..",
		"..o23o12121o3333333ouu2uuo332o..",
		"..o24o121j1o4444444ooooooo442o..",
		"..o24o121h1o44444433333333342o..",
		"..o23o12121o33333333333333332o..",
		"..o24o12121o44444444444444442o..",
		"..o24o12121o44444444444444442o..",
		".ollihhhhhhhilllilllilllilllilo.",
		".oooooooooooooooooooooooooooooo.",
	],
	## A bench by the hut, to sit a moment: its back, its seat, its legs.
	"bench": [
		"................",
		"................",
		"................",
		"................",
		"................",
		"..oooooooooooo..",
		"..o6666666665o..",
		"..o4444444443o..",
		"..oo2ooooo2ooo..",
		".oooooooooooooo.",
		".o666666666665o.",
		".o444444444443o.",
		".oooooooooooooo.",
		"..o3o......o3o..",
		"..o2o......o2o..",
		"..ooo......ooo..",
	],
	## The ember lamp by day: a stone foot, a wooden post, an iron cage on
	## top and the mountain's shard in it, dull red.
	"ember_lamp": [
		"................",
		"................",
		".......oo.......",
		"......okko......",
		".....okiiko.....",
		"....okkkkkko....",
		"....oko.eoko....",
		"....oke1Reko....",
		"....okeRe1ko....",
		"....ok1eReko....",
		"....oke1e1ko....",
		"....okoe1oko....",
		"....okkkkkko....",
		".....oiiiio.....",
		"......okko......",
		"......o54o......",
		"......o54o......",
		"......o43o......",
		"......o43o......",
		"......o32o......",
		"......o43o......",
		"......o43o......",
		"......o43o......",
		"......o43o......",
		"......o32o......",
		"......o43o......",
		"......o43o......",
		".....oiiiio.....",
		".....o3443o.....",
		"....ohlllllo....",
		"....oiiiiiio....",
		"....oooooooo....",
	],
}


static var _textures := {}
static var _ember: SpriteFrames
static var _pane: ImageTexture


## Piece `name` drawn (a "." clear), as an image, in HamletArt's inks.
static func picture(name: String) -> Image:
	return _drawn(PIECES[name])


static func _drawn(rows: Array) -> Image:
	var image := Image.create(String(rows[0]).length(), rows.size(), false, Image.FORMAT_RGBA8)
	for y in rows.size():
		var row := String(rows[y])
		for x in row.length():
			if row[x] != ".":
				image.set_pixel(x, y, HamletArt.INKS[row[x]])
	return image


## Piece `name` as a texture, drawn once a session.
static func texture(name: String) -> Texture2D:
	if not _textures.has(name):
		_textures[name] = ImageTexture.create_from_image(picture(name))
	return _textures[name]


## How big piece `name` is, in pixels.
static func size(name: String) -> Vector2i:
	var rows: Array = PIECES[name]
	return Vector2i(String(rows[0]).length(), rows.size())


## The shard alight over the lamp at night: clear but for the shard,
## EMBER_LIT's beats played in a loop, slow as a coal breathes.
static func ember() -> SpriteFrames:
	if _ember == null:
		_ember = SpriteFrames.new()
		_ember.set_animation_speed("default", EMBER_FPS)
		var lamp := size("ember_lamp")
		for beat: Array in EMBER_LIT:
			var image := Image.create(lamp.x, lamp.y, false, Image.FORMAT_RGBA8)
			var shard := _drawn(beat)
			image.blend_rect(shard, Rect2i(Vector2i.ZERO, shard.get_size()), EMBER_AT)
			_ember.add_frame("default", ImageTexture.create_from_image(image))
	return _ember


## The hut's window lit (the frame and its bar left in the night): drawn
## over the hut at night.
static func lit_window() -> ImageTexture:
	if _pane == null:
		var hut := size("hut")
		var image := Image.create(hut.x, hut.y, false, Image.FORMAT_RGBA8)
		var rows: Array = PIECES["hut"]
		for y in range(WINDOW.position.y, WINDOW.end.y):
			for x in range(WINDOW.position.x, WINDOW.end.x):
				if String(rows[y])[x] in ["u", "U"]:
					image.set_pixel(x, y, PANE if y < WINDOW.position.y + 2 else PANE_LOW)
		_pane = ImageTexture.create_from_image(image)
	return _pane
