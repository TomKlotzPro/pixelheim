class_name AshArt
## What burnt land and a mine stand in that Shade's sheets don't draw
## (PIX-308): dead trees, black and bare, on the burnt rock where his pines
## stood; the timber shoring at a working's face, boarded across; spoil
## heaped at its foot. Drawn here a pixel a letter in his manner (a dark
## outline, light from the top left) and in his dungeon sheet's woods, so
## they sit beside his art as his; our own, so CC0 like the rest of the
## repository, the same with or without the paid pack.

## The colours: K his dark outline; the burnt wood, charred to grey where
## the light catches it (N X P); ash heaped at a foot (Q U); timber, his
## woods (L W M D) and the dark behind boards (O); an ember's or ore's glint
## (E F).
const INKS := {
	"K": Color("2e2036"), "N": Color("3b3134"), "X": Color("54443f"), "P": Color("8f8780"),
	"Q": Color("6f6862"), "U": Color("aaa39b"),
	"L": Color("c18f4f"), "W": Color("966a3a"), "M": Color("79542d"), "D": Color("644227"), "O": Color("1d1a20"),
	"E": Color("e0743a"), "F": Color("e8b04a"),
}
## Dead trees, their foot on the bottom row: tall and broken, short and
## split, forked, and a stump with an ember in its crack.
const SNAGS := [
	[
		".......K........",
		"......KPK.......",
		"......KPK.......",
		"..K...KXK...K...",
		"...K..KPK..K....",
		"....KKKXKKK.....",
		"......KPK.......",
		"......KXK.......",
		"..K...KPK..K....",
		"...KK.KXK.K.....",
		".....KKPKK......",
		"......KPXK......",
		"......KPXK......",
		"......KPXK..K...",
		"......KPXKKK....",
		"......KPXK......",
		"......KPXK......",
		".....KPPXNK.....",
		".....KPXXNK.....",
		"....KPXXNNNK....",
		"...UQKKKKKKQQ...",
		"....UQQQQQQQ....",
	],
	[
		".........K......",
		"........KP......",
		"....K...KX......",
		".....K..KPK.....",
		"......KKKXK.....",
		"......KPXK......",
		"......KPXK.K....",
		"......KPXKK.....",
		"......KPXK......",
		".....KPPXNK.....",
		"....KPPXXNNK....",
		"...UQKKKKKKQ....",
		"....UQQQQQQ.....",
	],
	[
		"..K.......K.....",
		"..KK.....KK.....",
		"...KP...KP......",
		"....KP.KPK......",
		".....KPPXK......",
		"......KPXK......",
		"......KPXK......",
		"......KPXK..K...",
		"......KPXKKK....",
		"......KPXK......",
		"......KPXK......",
		".....KPXXNK.....",
		"....KPXXXNNK....",
		"...UQKKKKKKQQ...",
		"....UQQQQQQQ....",
	],
	[
		"......KKK.......",
		".....KPXNK......",
		".....KPENK......",
		".....KPXNK......",
		"....KPPXNNK.....",
		"...UQKKKKKKQ....",
		"....UQQQQQ......",
	],
]
## A working's face: timber posts and a lintel shoring the rock, the way
## in boarded across.
const SHORING := [
	"................",
	"................",
	"KKKKKKKKKKKKKKKK",
	"KLLLLLLLLLLLLLLK",
	"KWWWWWWWWWWWWWWK",
	"KKKKKKKKKKKKKKKK",
	".KLWK......KLWK.",
	".KLWKOOOOOOKLWK.",
	".KLWKMMMMMMKLWK.",
	".KLWKDDDDDDKLWK.",
	".KLWKOOOOOOKLWK.",
	".KLWKMMMMMMKLWK.",
	".KLWKDDDDDDKLWK.",
	".KLWKOOOOOOKLWK.",
	".KLWK......KLWK.",
	".KKKK......KKKK.",
]
## Spoil heaped at a working's foot, low on the ground: a broad heap, and a
## small one with a glint of ore in it.
const SPOIL_A := [
	"......KKK.......",
	"....KKQPQKK.....",
	"...KQPQNQPQK....",
	"..KQPNQQXNQPK...",
	".KQNQPQNQQNQQK..",
	".KNQQNXQPNQXNQK.",
	"KNXNNQNNQNNXNNNK",
	".KKKKKKKKKKKKKK.",
]
const SPOIL_B := [
	".........KKK....",
	"..KKK...KQPQK...",
	".KQPQK.KQPFQNK..",
	"KQPNQNKQNQQNXNK.",
	"KNQXNNQNXNNQNNK.",
	".KKKKKKKKKKKKK..",
]
const TILE := 16
## A dead tree's picture is two cells tall, its foot at the bottom.
const SNAG_HEIGHT := 32

static var _textures := {}


## A piece's picture by name: "shoring", "spoil_a", "spoil_b", or
## "snag_<n>" (SNAGS), made once a session.
static func texture(name: String) -> Texture2D:
	if not _textures.has(name):
		_textures[name] = ImageTexture.create_from_image(draw(name))
	return _textures[name]


## Piece `name`, drawn: 16 px wide, a cell tall (a dead tree two).
static func draw(name: String) -> Image:
	var rows: Array = []
	var height := TILE
	match name:
		"shoring":
			rows = SHORING
		"spoil_a":
			rows = SPOIL_A
		"spoil_b":
			rows = SPOIL_B
		_:
			rows = SNAGS[int(name.trim_prefix("snag_")) % SNAGS.size()]
			height = SNAG_HEIGHT
	var image := Image.create(TILE, height, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	# Feet on the bottom row (the heaps one up, on the ground's middle).
	var top := height - rows.size() - (2 if name.begins_with("spoil") else 0)
	for y in rows.size():
		var line: String = rows[y]
		for x in line.length():
			if INKS.has(line[x]):
				image.set_pixel(x, top + y, INKS[line[x]])
	return image
