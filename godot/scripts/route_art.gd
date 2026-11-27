class_name RouteArt
## areas: town travel field night quest +overworld*
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
const WINDOW := Rect2i(25, 35, 12, 9)
## Its door with its frame and the row its wall starts on, in its pixels
## (PIX-557: the hero fits the door, the wall stands two cells tall).
const HUT_DOOR := Rect2i(4, 36, 12, 19)
const HUT_WALL := 23
## Each lamp's kind (PIX-324, Lamps.KINDS) is the ember lamp with its
## cage's inks swapped: sea glass panes round the shard (Saltmere's), a
## frost lily in it (the Frostgate's), its cage furred with grave moss (the
## Mirefen's); `glow`, the inks its shard burns in at night, and `light`,
## the colour it throws.
const KIND_LOOKS := {
	"sea_glass": {"inks": {"e": "m", "1": "T", "R": "M"}, "glow": {"a": "m", "Y": "M", "q": "y"}, "light": Color(0.62, 0.95, 0.88)},
	"frost_lily": {"inks": {"e": "S", "1": "s", "R": "y"}, "glow": {"a": "S", "Y": "s", "q": "y"}, "light": Color(0.8, 0.9, 1.0)},
	"grave_moss": {"inks": {"e": "f", "1": "F", "R": "v", "i": "F"}, "glow": {"a": "F", "Y": "v", "q": "Y"}, "light": Color(0.72, 0.95, 0.5)},
}

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
	## A waystation's hut at the houses' scale (PIX-557: it stood two cells
	## wide, its door 10 pixels and the hero 14), three cells wide, `hut` its
	## left cell: a pitched thatched roof, its front slope in three skirts
	## down to a ragged eave, over log walls two cells tall on a stone footing;
	## its plank door on the left (over `arrival`) under the Post's board (a
	## letter drawn on it, sealed red), a window on the right.
	"hut": [
		".............oooooooooooooooooooooo.............",
		"............o6666666666666666666666o............",
		"...........o655555555555555555555555o...........",
		"...........o655554555556566655466443o...........",
		"..........o64555545545565665544664543o..........",
		"..........o64556545545565665544665543o..........",
		".........o6545465556455655655466454443o.........",
		".........o6555465556455645645465454443o.........",
		"........o645564445564556454464654544543o........",
		".......o63433433433433433433433433433443o.......",
		".......o64464644455555555544645455454543o.......",
		"......o6545645455555555555544454544545543o......",
		"......o6545645555555544555544444446545443o......",
		".....o655555555555556445455545454465654543o.....",
		".....o655565555545556445454555454565654543o.....",
		"....o66555655555445465554445555555546555443o....",
		"...o6343343343343343343343343343343343343343o...",
		"...o6455554454555454555654545656555455555643o...",
		"..o654545544544554465556545456565545555556543o..",
		"..o654545545544554465555545456545545555555543o..",
		".o65544455655645544655555454465454455655455643o.",
		".o64343434343434343434343434343434343434343443o.",
		"o6434343434343434343434343434343434343434343443o",
		".oo222222222222222222222222222222222222222222oo.",
		"..o221111111111111111111111111111111111111122o..",
		"..o543i333333i3333333333333333333333333333354o..",
		"..o2oooooooooooo22222222222222222222222222222o..",
		"..o3oBBBBBBBBBBo55555555544444444445555555533o..",
		"..o6oBbBBBBBBbBo33444444444444444444444444465o..",
		"..o5oBBbBBBBbBBo33333333333333333333333333354o..",
		"..o2oBBBbRRbBBBo22222222222222222222222222222o..",
		"..o3oBBBBRRBBBBo44444444455555555554444455533o..",
		"..o6oBBBBBBBBBBo44444444444444444444444444465o..",
		"..o5obbbbbbbbbbo33333333333333333333333333354o..",
		"..o2oooooooooooo22222222666666666666662222222o..",
		"..o3355555444444444455555UUUUU22UUUUU35555533o..",
		"..o6666666666665444444445uUUuu22uuuuu34444465o..",
		"..o5511111111113333333335UUuuu22uuuuu33333354o..",
		"..o2532221322213222222225Uuuuu22uuuuu32222222o..",
		"..o353333333333355555555522222222222234455533o..",
		"..o6511111111113444444445uuuuu22uuuuu34444465o..",
		"..o5532221322213333333335uuuuu22uuuuu33333354o..",
		"..o2532221322213222222225uuuuu22uuuuu32222222o..",
		"..o3532221322213444444445uuuuu22uuuuu35544433o..",
		"..o653222132221333333444555555555555534444465o..",
		"..o553222132221333333335555555555555555333354o..",
		"..o253222132jh1322222222222222222222222222222o..",
		"..o353222132hi1355555555544444444444444444433o..",
		"..o653222132221333444444444444444444444444365o..",
		"..o553222132221333333333333333333333333333354o..",
		"..o253333333333322222222222222222222222222222o..",
		"..o351111111111344444444455555444444444444433o..",
		"..o653222132221344444444444444444444444333465o..",
		".oih532221322213llihllihllihhlihllihllihhlihllo.",
		".oii532221322213kiiikiiikiiikiiikiiikiiikiiikio.",
		"..oooooooooooooooooooooooooooooooooooooooooooo..",
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
		"..o3333333332o..",
		"..oo4oooooo2oo..",
		".ooo4o....o2ooo.",
		".o5oooooooooo4o.",
		".o4o66666666o3o.",
		".o3o55555554o2o.",
		".oooo3333332ooo.",
		"..o4o......o2o..",
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
static var _embers := {}
static var _pane: ImageTexture


## Piece `name` drawn (a "." clear), as an image, in HamletArt's inks.
static func picture(name: String) -> Image:
	return _drawn(PIECES[name])


## `rows` with each ink in `swapped` (ink -> ink) swapped.
static func _swapped(rows: Array, swapped: Dictionary) -> Array:
	return rows.map(func(row: String) -> String:
		var out := ""
		for ink in row:
			out += String(swapped.get(ink, ink))
		return out)


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


## A lamp of `kind` by day (PIX-324): the ember lamp, its cage's inks
## swapped for its kind's.
static func lamp(kind: String) -> Texture2D:
	if not KIND_LOOKS.has(kind):
		return texture("ember_lamp")
	var key := "ember_lamp:" + kind
	if not _textures.has(key):
		_textures[key] = ImageTexture.create_from_image(_drawn(_swapped(PIECES["ember_lamp"], KIND_LOOKS[kind]["inks"])))
	return _textures[key]


## The colour a lamp of `kind` throws at night.
static func light_of(kind: String) -> Color:
	return KIND_LOOKS[kind]["light"] if KIND_LOOKS.has(kind) else Lights.EMBER


## The shard alight over the lamp at night: clear but for the shard,
## EMBER_LIT's beats played in a loop, slow as a coal breathes; burning in
## its kind's inks (PIX-324).
static func ember(kind := "ember") -> SpriteFrames:
	if not _embers.has(kind):
		var frames := SpriteFrames.new()
		frames.set_animation_speed("default", EMBER_FPS)
		var lamp_size := size("ember_lamp")
		for beat: Array in EMBER_LIT:
			var image := Image.create(lamp_size.x, lamp_size.y, false, Image.FORMAT_RGBA8)
			var shard := _drawn(_swapped(beat, KIND_LOOKS[kind]["glow"]) if KIND_LOOKS.has(kind) else beat)
			image.blend_rect(shard, Rect2i(Vector2i.ZERO, shard.get_size()), EMBER_AT)
			frames.add_frame("default", ImageTexture.create_from_image(image))
		_embers[kind] = frames
	return _embers[kind]


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
					image.set_pixel(x, y, PANE if y < WINDOW.position.y + 5 else PANE_LOW)
		_pane = ImageTexture.create_from_image(image)
	return _pane
