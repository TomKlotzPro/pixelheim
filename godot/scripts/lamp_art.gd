class_name LampArt
## Lamps and lit windows (PIX-311). By day a street lamp was Shade's wall
## torch, cold: a dark speck on the road that read as a bug, and at night
## every lit window a round orb on the wall. Now a lamp is a post with a
## lantern on it, drawn here in a few pixels of Shade's palette (so it
## stands without the paid pack too): its glass cold by day, lit at night
## (`glass`, the only part the dark doesn't touch). A lit window is its own
## glass lit amber (`panes`), the frame left in the night, and a room's
## windows by day are its glass full of the sky (`day_panes`). A camp's
## torch stands on a stake (`stake`). Pictures are rows of characters, one
## a pixel, keyed in PALETTE: art made in code, not cut from a sheet.

## Shade's palette, by the character the rows draw it with.
const PALETTE := {
	"o": "2e2036", "k": "2d2d2d", "i": "484849", "l": "6f6f70", "h": "9a9b9e",
	"d": "4a3132", "w": "644227", "m": "79542d", "b": "a1753f", "c": "c18f4f", "e": "d6a555",
	"g": "4d587a", "G": "5e769e", "n": "c5ab63", "u": "4f6d96", "s": "201d2f", "t": "1f3d46",
	"p": "c5ab63", "P": "96793f", "q": "6e5139",
	"y": "ffffff", "Y": "fbf014", "a": "f8ac34", "r": "d5773b",
}
## The street lamp, foot on the bottom row: a stone foot, a wooden post, an
## iron collar, and the lantern under its little roof, its glass cold (a
## glint of the sky, the candle inside unlit).
const POST := [
	"................",
	"................",
	".......oo.......",
	"......oiko......",
	".....oliiko.....",
	"....oiiiiiko....",
	"....okkkkkko....",
	"....okGgggko....",
	"....okGgggko....",
	"....okggogko....",
	"....okggngko....",
	"....okggngko....",
	"....okgiigko....",
	"....oiiiiiio....",
	".....okkkko.....",
	"......ocmo......",
	"......ocmo......",
	"......ocmo......",
	"......ocwo......",
	"......ocmo......",
	"......ocmo......",
	"......ocmo......",
	"......ocmo......",
	"......ocwo......",
	"......ocmo......",
	"......ocmo......",
	".....oiiiio.....",
	".....ocmmwo.....",
	"....ohlllllo....",
	"....oiiiiiio....",
	"....oooooooo....",
	"................",
]
## The lantern's glass lit, in three beats of the flame: where it stands in
## the post (its top-left), and each beat's rows.
const GLASS_AT := Vector2i(6, 7)
const LIT := [
	["raar", "aYYa", "aYya", "aYYa", "raar", "rrrr"],
	["raar", "aYya", "aYYa", "aYYa", "raar", "rrrr"],
	["rrar", "aYYa", "aYya", "aYYa", "arar", "rrrr"],
]
const LIT_FPS := 5.0
## The middle of the glass, in the post's pixels: where its halo stands.
const HALO_AT := Vector2(8.0, 10.0)
## A camp torch's stake driven into the ground, a little earth round it:
## the torch stands on it, raised STAKE_LIFT pixels.
const STAKE := [
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	".......oo.......",
	"......ocmo......",
	"......ocmo......",
	"......ocwo......",
	".....oqcmqo.....",
	"....oqPqqPqo....",
	".....ooooooo....",
]
const STAKE_LIFT := 5
## A lit window's glass (the title's too): lamplight above, warmer below,
## the glazing bars' shadows amber.
const PANE_TOP := Color("ffd27a")
const PANE_LOW := Color("ffbb55")
const PANE_BARS := Color("c9772e")
## A room's window by day: the sky through it, pale, a little deeper below.
const SKY_TOP := Color("e3f1f6")
const SKY_LOW := Color("b9d6e4")
const SKY_BARS := Color("8fb3c8")


## `rows` drawn in PALETTE (a "." is clear), as an image.
static func picture(rows: Array) -> Image:
	var image := Image.create(String(rows[0]).length(), rows.size(), false, Image.FORMAT_RGBA8)
	for y in rows.size():
		var row := String(rows[y])
		for x in row.length():
			var key := row[x]
			if key != ".":
				image.set_pixel(x, y, Color(PALETTE[key]))
	return image


static var _post: ImageTexture
static var _glass: SpriteFrames
static var _stake: ImageTexture
static var _panes: ImageTexture
static var _day_panes: ImageTexture


## The street lamp, cold (its post and lantern, by day and night alike).
static func post() -> ImageTexture:
	if _post == null:
		_post = ImageTexture.create_from_image(picture(POST))
	return _post


## How big the lamp is, in pixels: its foot on the bottom row.
static func size() -> Vector2i:
	return Vector2i(String(POST[0]).length(), POST.size())


## The lantern's glass lit, over the post at night: clear but for the glass,
## LIT's beats played in a loop.
static func glass() -> SpriteFrames:
	if _glass == null:
		_glass = SpriteFrames.new()
		_glass.set_animation_speed("default", LIT_FPS)
		for beat: Array in LIT:
			var image := Image.create(size().x, size().y, false, Image.FORMAT_RGBA8)
			image.blit_rect(picture(beat), Rect2i(0, 0, 4, beat.size()), GLASS_AT)
			_glass.add_frame("default", ImageTexture.create_from_image(image))
	return _glass


## A camp torch's stake (STAKE).
static func stake() -> ImageTexture:
	if _stake == null:
		_stake = ImageTexture.create_from_image(picture(STAKE))
	return _stake


## The window tile's glass lit (the frame stays in the night): drawn over a
## lit window at night, and over the title's village.
static func panes() -> ImageTexture:
	if _panes == null:
		_panes = _glazed(PANE_TOP, PANE_LOW, PANE_BARS)
	return _panes


## A room's window by day, the sky through its glass.
static func day_panes() -> ImageTexture:
	if _day_panes == null:
		_day_panes = _glazed(SKY_TOP, SKY_LOW, SKY_BARS)
	return _day_panes


## The window tile (the paid pack's) with only its glass left, `top` above
## the middle bar, `low` below it and `bars` for the glazing's shadows.
## Null without the pack: no house, no window.
static func _glazed(top: Color, low: Color, bars: Color) -> ImageTexture:
	if not PunyProps.available():
		return null
	var tile := PunyProps.texture(PunyTown.WINDOW).get_image()
	tile.convert(Image.FORMAT_RGBA8)
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in range(1, 11):
		for x in range(1, 15):
			match tile.get_pixel(x, y).to_html(false):
				"2e2036":
					image.set_pixel(x, y, top if y < 6 else low)
				"4a3132":
					image.set_pixel(x, y, bars)
	return ImageTexture.create_from_image(image)
