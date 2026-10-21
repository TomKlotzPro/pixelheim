class_name Postmark
## areas: quest
## The courier's book's postmarks (PIX-321): a round date stamp per place,
## pixel art in the page's inks drawn at 1x and shown at UiStyle.UI_SCALE,
## like the frames and the marks over the world. A double ring round the
## place's emblem (a house for Pixelheim, a fish for Saltmere, a signpost
## for the Reach, cattails for the Mirefen, a pine for the Deepwood, a pick
## for Blackiron, a tower for Greyhold, a snowflake for the Frostgate, an
## anvil for Morvax's forge), worn where the ink didn't take, the same
## every time (the wear is the place's own), with the post office's wavy
## cancellation lines beside the big one. A page not stamped yet shows a
## faint dashed ring. Ours, drawn in code from the palette (CC0); post.json's
## `book` names each page's ink and emblem.

## The inks a page may name, all on the parchment's palette.
const INKS := {
	"lamp": UiStyle.LAMP, "fine": UiStyle.FINE, "epic": UiStyle.EPIC, "ink": UiStyle.INK,
	"faded": UiStyle.FADED, "brass": UiStyle.BRASS_DARK, "wood": UiStyle.WOOD_DARK,
}
## Each emblem, 11 by 11, a row of letters a line ("#" inked).
const EMBLEMS := {
	"house": [
		".....#.....", "....###....", "...#####...", "..#######..", ".#########.", "..#######..",
		"..#.#####..", "..#.#####..", "..#####.#..", "..#####.#..", "..#####.#..",
	],
	"fish": [
		"...........", "...........", "...........", "...####...#", ".#######.##", "##.#######.",
		".#######.##", "...####...#", "...........", "...........", "...........",
	],
	"road": [
		".....#.....", ".#######...", ".########..", ".#######...", ".....#.....", "...######..",
		"..#######..", "...######..", ".....#.....", ".....#.....", "....###....",
	],
	"reed": [
		"...#.......", "..###..#...", "..###.###..", "..###.###..", "...#..###..", "...#...#...",
		"#..#...#..#", ".#.#...#.#.", "..##...##..", "...#...#...", "##.##.##.##",
	],
	"tree": [
		".....#.....", "....###....", "...#####...", "....###....", "...#####...", "..#######..",
		"...#####...", "..#######..", ".#########.", ".....#.....", "....###....",
	],
	"pick": [
		"..#######..", ".#########.", "##...#...##", "#....#....#", ".....#.....", ".....#.....",
		".....#.....", ".....#.....", ".....#.....", ".....#.....", ".....#.....",
	],
	"tower": [
		"..#.#.#.#..", "..#######..", "...#####...", "...#####...", "...##.##...", "...##.##...",
		"...#####...", "...#####...", "..#######..", "..###.###..", "..###.###..",
	],
	"flake": [
		".....#.....", ".#...#...#.", "..#..#..#..", "...#.#.#...", "....###....", "###########",
		"....###....", "...#.#.#...", "..#..#..#..", ".#...#...#.", ".....#.....",
	],
	"anvil": [
		"...........", "......#....", ".....#.#...", "......#....", "##########.", "..########.",
		"....####...", "....####...", "...######..", "..########.", "...........",
	],
}
## The big stamp's size at 1x, its rings' radii; the small one's (a row's).
const BIG := 60
const BIG_RINGS := [[26.5, 28.5], [23.5, 24.5]]
const SMALL := 17
const SMALL_RINGS := [[7.5, 8.5]]
## The share of a stamp's pixels the ink didn't take.
const WEAR := 0.12

static var _made := {}


## A page's postmark: big (the page's own) or small (its row in the index),
## stamped or still waiting for its first piece.
static func view(page: Dictionary, big: bool, stamped: bool) -> TextureRect:
	var node := TextureRect.new()
	node.texture = texture(page, big, stamped)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return node


## The cancellation's three wavy lines, in the page's ink, beside a big
## stamp.
static func waves_view(page: Dictionary) -> TextureRect:
	var key := "waves:%s" % page.get("place", "")
	if not _made.has(key):
		var art := Image.create(40, 22, false, Image.FORMAT_RGBA8)
		art.fill(Color(0, 0, 0, 0))
		var ink := ink_of(page)
		for line in 3:
			for x in 40:
				var y := 4 + line * 7 + roundi(1.6 * sin(TAU * x / 13.0))
				_dab(art, Vector2i(x, y), ink, String(page.get("place", "")))
		_made[key] = _blown_up(art)
	var node := TextureRect.new()
	node.texture = _made[key]
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return node


static func texture(page: Dictionary, big: bool, stamped: bool) -> ImageTexture:
	var key := "%s:%s:%s" % [page.get("place", ""), big, stamped]
	if not _made.has(key):
		_made[key] = _blown_up(image(page, big, stamped))
	return _made[key]


## The stamp at 1x.
static func image(page: Dictionary, big: bool, stamped: bool) -> Image:
	var side := BIG if big else SMALL
	var art := Image.create(side, side, false, Image.FORMAT_RGBA8)
	art.fill(Color(0, 0, 0, 0))
	var place := String(page.get("place", ""))
	var ink := ink_of(page) if stamped else Color(UiStyle.FADED, 0.5)
	var centre := Vector2(side, side) / 2.0
	for ring: Array in (BIG_RINGS if big else SMALL_RINGS):
		for y in side:
			for x in side:
				var at := Vector2(x + 0.5, y + 0.5) - centre
				var reach := at.length()
				if reach < float(ring[0]) or reach >= float(ring[1]):
					continue
				# A page still waiting shows its outer ring only, dashed.
				if not stamped:
					if ring != (BIG_RINGS if big else SMALL_RINGS)[0] or posmod(roundi(rad_to_deg(at.angle()) / 12.0), 2) == 1:
						continue
					art.set_pixel(x, y, ink)
				else:
					_dab(art, Vector2i(x, y), ink, place)
	if not stamped:
		return art
	var rows: Array = EMBLEMS.get(String(page.get("emblem", "")), [])
	var cell := 2 if big else 1
	var from := (side - 11 * cell) / 2
	for row in rows.size():
		for column in String(rows[row]).length():
			if String(rows[row])[column] != "#":
				continue
			for dy in cell:
				for dx in cell:
					_dab(art, Vector2i(from + column * cell + dx, from + row * cell + dy), ink, place)
	return art


## The ink a page names (its book entry's `ink`), the page's INK otherwise.
static func ink_of(page: Dictionary) -> Color:
	return INKS.get(String(page.get("ink", "")), UiStyle.INK)


## One pixel of ink, or none where the stamp didn't take, a little lighter
## here and there: the place's own wear, the same every time.
static func _dab(art: Image, at: Vector2i, ink: Color, place: String) -> void:
	if at.x < 0 or at.y < 0 or at.x >= art.get_width() or at.y >= art.get_height():
		return
	var grain := float(hash("%s:%d:%d" % [place, at.x, at.y]) % 1000) / 1000.0
	if grain < WEAR:
		return
	art.set_pixel(at.x, at.y, Color(ink, 0.78 if grain > 0.85 else 1.0))


static func _blown_up(art: Image) -> ImageTexture:
	art.resize(art.get_width() * UiStyle.UI_SCALE, art.get_height() * UiStyle.UI_SCALE, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(art)
