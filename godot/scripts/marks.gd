class_name Marks
## areas: town combat screen quest
## The marks over the world (PIX-284, PIX-289), one family in the UI's
## palette: pixel art drawn here a pixel per letter, as UiStyle draws its
## frames, never shapes smoothed or turned. Tom found the old ones ugly: the
## arrow a flat yellow triangle, the "!"s a font's glyph in a ring.
## - The talk mark over someone with something to say (Npc): a speech bubble
##   on a pin's tail pointing down at their head, "!" for a quest to give, "?"
##   for one to hand in; parchment for a side quest, gold for the main story,
##   faded while a quest is under way.
## - The danger mark over a foe that has seen the hero: a red burst round a
##   pale "!" (blue and cold when it takes fright and runs).
## - The arrow at the view's edge toward where the hero is headed (Hud): a
##   bevelled arrow, gold for the main story, cream for anything else
##   followed, drawn for each of eight ways so its pixels stay square.
## - The quill by the clock (Hud.Quill, PIX-302 step 4): a cream feather
##   that writes a line as the game saves a moment.
## Told apart by their shapes (round bubble, spiky burst, arrow) and colours;
## each is ringed in the night, lit from the top left, so it reads on grass,
## sand, snow and in the dark of a cave. The world's marks are at the world's
## scale (an art pixel each, three on the screen at play zoom); the arrow,
## on the HUD, at UiStyle.UI_SCALE like the dock.

## The talk marks, a letter a pixel: o the dark line, L the lit edge, F the
## fill, S the shaded edge, i the glyph. The glyph's two middle columns are
## the bubble's, so it centres on a head as the old "!" did (PIX-268).
const TALK := {
	"!": [
		"..oooooo..",
		".oLLLLLLo.",
		"oLFFiiFFSo",
		"oLFFiiFFSo",
		"oFFFiiFFSo",
		"oFFFiiFFSo",
		"oFFFFFFFSo",
		"oFFFiiFFSo",
		".oSSSSSSo.",
		"..ooSSoo..",
		"...oSSo...",
		"....oo....",
	],
	"?": [
		"..oooooo..",
		".oLLLLLLo.",
		"oLFiiiiFSo",
		"oLiiFFiiSo",
		"oFFFFiiFSo",
		"oFFFiiFFSo",
		"oFFFFFFFSo",
		"oFFFiiFFSo",
		".oSSSSSSo.",
		"..ooSSoo..",
		"...oSSo...",
		"....oo....",
	],
}
## Their inks: parchment and ink for a side quest, the dock's brass for the
## main story, faded parchment while a quest is under way.
const TALK_TONES := {
	"plain": {"o": UiStyle.NIGHT, "L": UiStyle.KEY_LIGHT, "F": UiStyle.CREAM, "S": UiStyle.DUSK, "i": UiStyle.INK},
	"gold": {"o": UiStyle.NIGHT, "L": UiStyle.BRASS_LIGHT, "F": UiStyle.GOLD, "S": UiStyle.BRASS, "i": UiStyle.INK},
	"waiting": {"o": UiStyle.NIGHT, "L": UiStyle.CREAM, "F": UiStyle.DUSK, "S": UiStyle.RIM, "i": UiStyle.FADED},
}
## The danger mark: R the burst's red, its spikes the four ways and the
## corners between, the "!" in its middle columns.
const BURST := [
	"......oo......",
	"..o..oLLo..o..",
	".oLooLRRSooSo.",
	"..oLLRRRRSSo..",
	"..oLRRiiRRSo..",
	".ooLRRiiRRSoo.",
	"oLLRRRiiRRRSSo",
	"oSLRRRiiRRRSSo",
	".ooLRRRRRRSoo.",
	"..oLRRiiRRSo..",
	"..oSSRRRRSSo..",
	".oSooSRRSooSo.",
	"..o..oSSo..o..",
	"......oo......",
]
## The charge's red, or the fright's cold blue (Juice's, with its drop of
## sweat beside it).
const BURST_TONES := {
	"danger": {"o": UiStyle.NIGHT, "L": Color("f0805a"), "R": Color("d8433f"), "S": UiStyle.LAMP, "i": UiStyle.KEY_LIGHT},
	"fright": {"o": Juice.SWEAT_RIM, "L": Color("d6eeff"), "R": Juice.SWEAT, "S": Juice.FRIGHT_INK, "i": Juice.SWEAT_RIM},
}
## The arrow's shape pointing right and down-right (# is the arrow); the
## other six ways are these turned by quarter turns, which keep every pixel
## square. Its head is a right angle, so its edges step a pixel a pixel.
const ARROW_RIGHT := [
	".....#.....",
	".....##....",
	".....###...",
	".....####..",
	"##########.",
	"###########",
	"##########.",
	".....####..",
	".....###...",
	".....##....",
	".....#.....",
]
const ARROW_DOWN_RIGHT := [
	"...........",
	".##........",
	".###.......",
	"..###.....#",
	"...###...##",
	"....###.###",
	".....######",
	"......#####",
	".....######",
	"....#######",
	"...########",
]
## The arrow's inks: L the lit edge, F the lit half, S the shaded half, D
## the shaded edge; gold for the main story, cream for anything else.
const ARROW_TONES := {
	"gold": {"L": UiStyle.BRASS_LIGHT, "F": UiStyle.GOLD, "S": UiStyle.BRASS, "D": UiStyle.BRASS_DARK},
	"cream": {"L": UiStyle.KEY_LIGHT, "F": UiStyle.CREAM, "S": UiStyle.DUSK, "D": UiStyle.RIM},
}
## The quill by the clock (PIX-302 step 4), the HUD's word that the game
## has saved: a feather leaning up to the right, lit along its top, its
## shaft down the middle and a brass nib at the bottom left (`QUILL_NIB`),
## where it writes. o the dark line, L the lit edge, F the fill, S the
## shade, R the shaft, b the nib and d its point.
const QUILL := [
	"............ooo",
	"..........ooLFo",
	".........oLFFRo",
	"........oLFFRSo",
	".......oLFFRSSo",
	"......oLFFRSSo.",
	"......oLFRSSo..",
	".....oLFRSo....",
	"....oLFRSSo....",
	"....oFRSoo.....",
	"...oLRoo.......",
	"..obo..........",
	".obo...........",
	"odo............",
	"oo.............",
]
const QUILL_NIB := Vector2i(1, 13)
const QUILL_INKS := {
	"o": UiStyle.NIGHT, "L": UiStyle.KEY_LIGHT, "F": UiStyle.CREAM, "S": UiStyle.DUSK, "R": UiStyle.RIM,
	"b": UiStyle.BRASS, "d": UiStyle.BRASS_DARK,
}
## Where the light comes from: above, a little from the left (no way of the
## eight lies along it, so one half of the arrow is always the lit one).
const LIGHT := Vector2(-0.45, -0.89)
## The arrow's shadow on the ground under it, a pixel down and right.
const SHADOW := Color(0.11, 0.07, 0.04, 0.45)

## Every mark drawn so far, by what it is.
static var _drawn := {}


## The talk mark with `glyph` ("!" or "?") in `tone` (TALK_TONES), at the
## world's scale.
static func talk(glyph: String, tone: String) -> Texture2D:
	var key := "talk:%s:%s" % [glyph, tone]
	if not _drawn.has(key):
		_drawn[key] = ImageTexture.create_from_image(lettered(TALK[glyph], TALK_TONES[tone]))
	return _drawn[key]


## The danger mark in `tone` (BURST_TONES), at the world's scale.
static func alert(tone := "danger") -> Texture2D:
	var key := "alert:" + tone
	if not _drawn.has(key):
		_drawn[key] = ImageTexture.create_from_image(lettered(BURST, BURST_TONES[tone]))
	return _drawn[key]


## The arrow pointing `way` (0 right, then clockwise by eighths: 1
## down-right, 2 down...), gold for the main story, at the UI's scale. Its
## middle (ARROW_MIDDLE of it) is where it stands.
static func arrow(way: int, main: bool) -> Texture2D:
	var key := "arrow:%d:%s" % [way, main]
	if not _drawn.has(key):
		var art := arrow_art(way, main)
		art.resize(art.get_width() * UiStyle.UI_SCALE, art.get_height() * UiStyle.UI_SCALE, Image.INTERPOLATE_NEAREST)
		_drawn[key] = ImageTexture.create_from_image(art)
	return _drawn[key]


## The quill (QUILL), at the UI's scale.
static func quill() -> Texture2D:
	if not _drawn.has("quill"):
		var art := lettered(QUILL, QUILL_INKS)
		art.resize(art.get_width() * UiStyle.UI_SCALE, art.get_height() * UiStyle.UI_SCALE, Image.INTERPOLATE_NEAREST)
		_drawn["quill"] = ImageTexture.create_from_image(art)
	return _drawn["quill"]


## Where the arrow's own middle is in its picture, at the UI's scale: past
## the dark line, the shadow left out.
static func arrow_middle() -> Vector2:
	return (Vector2.ONE + Vector2(ARROW_RIGHT[0].length(), ARROW_RIGHT.size()) / 2.0) * UiStyle.UI_SCALE


## The way of the eight nearest `heading`.
static func way_of(heading: Vector2) -> int:
	return posmod(roundi(heading.angle() / (PI / 4.0)), 8)


## The arrow's shape for `way`, as rows of # and .: the right or down-right
## one turned a quarter at a time.
static func arrow_shape(way: int) -> Array:
	var shape: Array = ARROW_RIGHT if way % 2 == 0 else ARROW_DOWN_RIGHT
	for turn in way / 2:
		shape = _quarter(shape)
	return shape


## `rows` turned a quarter clockwise.
static func _quarter(rows: Array) -> Array:
	var out := []
	for x in String(rows[0]).length():
		var line := ""
		for y in range(rows.size() - 1, -1, -1):
			line += String(rows[y])[x]
		out.append(line)
	return out


## The arrow for `way` at 1x: its shape ringed in the night, the half facing
## the light lit and the other shaded, each edge picked out (lit along the
## lit half's top and left, dark along the shaded half's bottom and right),
## and its shadow a pixel down and right.
static func arrow_art(way: int, main: bool) -> Image:
	var shape := arrow_shape(way)
	var inks: Dictionary = ARROW_TONES["gold" if main else "cream"]
	var size := Vector2i(String(shape[0]).length(), shape.size())
	var art := Image.create(size.x + 3, size.y + 3, false, Image.FORMAT_RGBA8)
	art.fill(Color(0, 0, 0, 0))
	var middle := (Vector2(size) - Vector2.ONE) / 2.0
	var heading := Vector2.RIGHT.rotated(way * PI / 4.0)
	var across := heading.orthogonal()
	var lit_side := signf(across.dot(LIGHT))
	var at := func(x: int, y: int) -> bool:
		return x >= 0 and y >= 0 and x < size.x and y < size.y and String(shape[y])[x] == "#"
	for y in range(-1, size.y + 1):
		for x in range(-1, size.x + 1):
			var cell := Vector2i(x + 1, y + 1)
			if at.call(x, y):
				var lit := (Vector2(x, y) - middle).dot(across) * lit_side >= 0.0
				var ink: Color = inks["F"] if lit else inks["S"]
				if lit and (not at.call(x, y - 1) or not at.call(x - 1, y)):
					ink = inks["L"]
				elif not lit and (not at.call(x, y + 1) or not at.call(x + 1, y)):
					ink = inks["D"]
				art.set_pixelv(cell, ink)
			elif at.call(x - 1, y) or at.call(x + 1, y) or at.call(x, y - 1) or at.call(x, y + 1):
				art.set_pixelv(cell, UiStyle.NIGHT)
	# The shadow, under whatever the arrow and its line leave bare.
	var drawn := art.duplicate() as Image
	for y in drawn.get_height() - 1:
		for x in drawn.get_width() - 1:
			if drawn.get_pixel(x, y).a > 0.0 and art.get_pixel(x + 1, y + 1).a == 0.0:
				art.set_pixel(x + 1, y + 1, SHADOW)
	return art


## `rows` drawn a pixel per letter in `inks` (a letter it doesn't name is
## left clear).
static func lettered(rows: Array, inks: Dictionary) -> Image:
	var art := Image.create(String(rows[0]).length(), rows.size(), false, Image.FORMAT_RGBA8)
	art.fill(Color(0, 0, 0, 0))
	for y in rows.size():
		var row := String(rows[y])
		for x in row.length():
			if inks.has(row[x]):
				art.set_pixel(x, y, inks[row[x]])
	return art


## Where a mark `width` pixels wide goes so its middle is over `centre`, in
## whole pixels (Ink.centred: half a pixel over the same way every time).
static func centred(width: float, centre: float) -> float:
	return Ink.centred(Rect2(0, 0, width, 0), centre)
