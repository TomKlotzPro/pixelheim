class_name UiStyle
## The game's one look (PIX-132): retro RPG windows on the title's night. A
## deep navy fill inside a cream frame with a dark outline and a bevel, cards
## and rows in a lighter navy with a periwinkle rim, gold for whatever has
## focus. Every frame is pixel art drawn here from the palette at 1x and shown
## at UI_SCALE, so the chrome sits on a pixel grid like the world does.
## Type, all pixel fonts rendered at their own size and scaled by whole
## numbers only, so nothing is ever smoothed: below 16 a screen asks for dense
## text (rows, descriptions, hints) and gets Pixel Operator at 1x; 16 and up
## is read at a glance (dialogue, names, menus, values) and gets the chunkier
## Pixel Operator 8 at 2x, on the frames' grid (3x from 24); headings are
## Press Start 2P. All CC0 or OFL.

## Canvas pixels per pixel of UI art.
const UI_SCALE := 2
## The fonts' own pixel sizes: what fixed-size rendering scales from.
const BODY_PX := 16
const HEADING_PX := 8

const NIGHT := Color("0e1024")
const BACKDROP := Color(0.035, 0.04, 0.1, 0.93)
const WINDOW := Color("1f2347")
const CARD := Color("2a2f5c")
const RIM := Color("5a62a0")
const FRAME := Color("eadfc2")
const BEVEL := Color("8f8cb8")
const LAMP := Color("ffd94d")
const INK := Color("f6f0de")
const FADED := Color("a9acd3")

static var _frames := {}
static var _heading_font: FontFile
static var _bold_font: FontFile
static var _chunky_font: FontFile
static var _chunky_bold_font: FontFile


## Once, before any screen is built: the body font (the project's default,
## gui/theme/custom_font) renders at its pixel size and scales whole.
static func setup() -> void:
	_pixel_font(load("res://assets/fonts/PixelOperator.ttf"), BODY_PX)


static func _pixel_font(font: FontFile, pixels: int) -> FontFile:
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	font.hinting = TextServer.HINTING_NONE
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	font.fixed_size = pixels
	font.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_INTEGER_ONLY
	return font


static func label(text: String, font_size: int, color: Color, at := Vector2.ZERO) -> Label:
	var node := Label.new()
	node.text = text
	node.position = at
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_color_override("font_color", color)
	sized(node, font_size)
	return node


## The type a size asks for (see above), on any control: dense 1x below 16,
## chunky 2x from 16, 3x from 24.
static func sized(node: Control, font_size: int, bold := false) -> Control:
	if font_size < 16:
		if bold:
			node.add_theme_font_override("font", bold_font())
		node.add_theme_font_size_override("font_size", BODY_PX)
	else:
		node.add_theme_font_override("font", chunky_bold_font() if bold else chunky_font())
		node.add_theme_font_size_override("font_size", 24 if font_size >= 24 else 16)
	return node


## A label in the bold cut (names, amounts, what a row is).
static func strong(text: String, font_size: int, color: Color, at := Vector2.ZERO) -> Label:
	var node := label(text, font_size, color, at)
	sized(node, font_size, true)
	return node


static func bold_font() -> FontFile:
	if _bold_font == null:
		_bold_font = _pixel_font(load("res://assets/fonts/PixelOperator-Bold.ttf"), BODY_PX)
	return _bold_font


static func chunky_font() -> FontFile:
	if _chunky_font == null:
		_chunky_font = _pixel_font(load("res://assets/fonts/PixelOperator8.ttf"), 8)
	return _chunky_font


static func chunky_bold_font() -> FontFile:
	if _chunky_bold_font == null:
		_chunky_bold_font = _pixel_font(load("res://assets/fonts/PixelOperator8-Bold.ttf"), 8)
	return _chunky_bold_font


## A framed surface. Screens describe it by colour and padding, as they
## always have; the frame follows from that:
## - a gold rim is focus: a card with a gold frame;
## - a roomy padding (12 or more) with the card fill is a window: navy inside
##   the cream frame;
## - anything else is a card in its own fill and rim (a clear rim, no frame).
static func box(fill: Color, rim: Color, padding := 8) -> StyleBoxTexture:
	if rim == LAMP:
		return _style(_card(fill, LAMP), 2, padding)
	if padding >= 12 and fill == CARD:
		return window(padding)
	return _style(_card(fill, rim), 2, padding)


## The main window: navy in a cream frame, a dark outline, a bevel inside.
static func window(padding := 16, fill := WINDOW) -> StyleBoxTexture:
	var key := "window %s" % fill.to_html()
	if not _frames.has(key):
		var art := Image.create(12, 12, false, Image.FORMAT_RGBA8)
		art.fill(fill)
		_ring(art, 0, NIGHT, true)
		_ring(art, 1, FRAME, false)
		_ring(art, 2, BEVEL, false)
		# Rounded corners: the outline steps in, the frame turns inside it.
		for corner: Vector2i in _corners(art, 1):
			art.set_pixelv(corner, NIGHT)
		_frames[key] = _texture(art)
	return _style(_frames[key], 3, padding)


## A card, row or slot: its fill inside a one-pixel rim and the outline.
static func _card(fill: Color, rim: Color) -> ImageTexture:
	var key := "card %s %s" % [fill.to_html(), rim.to_html()]
	if not _frames.has(key):
		var art := Image.create(8, 8, false, Image.FORMAT_RGBA8)
		art.fill(fill)
		if rim.a > 0.0:
			_ring(art, 0, Color(NIGHT, minf(1.0, fill.a + rim.a)), true)
			_ring(art, 1, rim, false)
			for corner: Vector2i in _corners(art, 1):
				art.set_pixelv(corner, Color(NIGHT, minf(1.0, fill.a + rim.a)))
		_frames[key] = _texture(art)
	return _frames[key]


## One square ring of pixels `inset` in from the edge; `rounded` leaves its
## four corners clear.
static func _ring(art: Image, inset: int, color: Color, rounded: bool) -> void:
	var last := art.get_width() - 1 - inset
	for i in range(inset, last + 1):
		for cell: Vector2i in [Vector2i(i, inset), Vector2i(i, last), Vector2i(inset, i), Vector2i(last, i)]:
			art.set_pixelv(cell, color)
	if rounded:
		for corner: Vector2i in _corners(art, inset):
			art.set_pixelv(corner, Color(0, 0, 0, 0))


static func _corners(art: Image, inset: int) -> Array[Vector2i]:
	var last := art.get_width() - 1 - inset
	return [Vector2i(inset, inset), Vector2i(last, inset), Vector2i(inset, last), Vector2i(last, last)]


## UI art blown up to UI_SCALE, pixel for pixel.
static func _texture(art: Image) -> ImageTexture:
	art.resize(art.get_width() * UI_SCALE, art.get_height() * UI_SCALE, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(art)


static func _style(texture: Texture2D, border: int, padding: int) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = border * UI_SCALE
	style.texture_margin_top = border * UI_SCALE
	style.texture_margin_right = border * UI_SCALE
	style.texture_margin_bottom = border * UI_SCALE
	style.set_content_margin_all(maxi(padding, border * UI_SCALE + 2))
	return style


## Clickable twins of key commands; keyboard focus stays with the screen.
static func button(text: String, action: Callable) -> Button:
	var node := Button.new()
	node.text = text
	node.focus_mode = Control.FOCUS_NONE
	sized(node, BODY_PX)
	node.add_theme_color_override("font_color", INK)
	node.add_theme_color_override("font_hover_color", LAMP)
	node.add_theme_color_override("font_pressed_color", LAMP)
	node.add_theme_stylebox_override("normal", box(CARD, RIM, 6))
	node.add_theme_stylebox_override("hover", box(CARD, LAMP, 6))
	node.add_theme_stylebox_override("pressed", box(WINDOW, LAMP, 6))
	node.pressed.connect(action)
	return node


## The pixel font for headings: crisp, never smoothed.
static func heading_font() -> FontFile:
	if _heading_font == null:
		_heading_font = _pixel_font(load("res://assets/fonts/press-start-2p.woff2"), HEADING_PX)
	return _heading_font


## A heading in the pixel font (screen titles, the logo, the ascension).
static func heading(text: String, font_size: int, color: Color, at := Vector2.ZERO) -> Label:
	var node := label(text, font_size, color, at)
	node.add_theme_font_override("font", heading_font())
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_shadow_color", NIGHT)
	node.add_theme_constant_override("shadow_offset_x", UI_SCALE)
	node.add_theme_constant_override("shadow_offset_y", UI_SCALE)
	return node


## The key a command answers to, as a little keycap: "E", "Esc". `small`
## caps carry the dense type (HUD chips).
static func keycap(key: String, small := false) -> PanelContainer:
	var cap := PanelContainer.new()
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.add_theme_stylebox_override("panel", _style(_card(INK, BEVEL), 2, 2 if small else 4))
	var text := strong(key, 12 if small else BODY_PX, NIGHT)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.custom_minimum_size = Vector2(8, 0)
	cap.add_child(text)
	return cap


## Relabels a keycap (a rebound key).
static func keycap_text(cap: PanelContainer, key: String) -> void:
	(cap.get_child(0) as Label).text = key


## The gold "more to read" arrow under a page: pixel art, blinking elsewhere.
static func arrow() -> TextureRect:
	if not _frames.has("arrow"):
		var art := Image.create(7, 5, false, Image.FORMAT_RGBA8)
		art.fill(Color(0, 0, 0, 0))
		for row in 4:
			for x in range(row, 7 - row):
				art.set_pixel(x, row, LAMP if row < 3 and x > row and x < 6 - row else NIGHT)
		_frames["arrow"] = _texture(art)
	var node := TextureRect.new()
	node.texture = _frames["arrow"]
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return node


## A screen's key footer from its hint line, "Esc  close      W/S  choose":
## commands apart by four spaces or more, each a key, two spaces, what it does.
static func footer(line: String, at: Vector2) -> HBoxContainer:
	var pairs := []
	for command in RegEx.create_from_string(" {4,}").sub(line.strip_edges(), "\t", true).split("\t"):
		var cut := command.find("  ")
		pairs.append_array([command.substr(0, cut).strip_edges(), command.substr(cut).strip_edges()] if cut > 0 else ["", command])
	var row := hints(pairs)
	row.position = at
	return row


## A row of key hints: keycap, what it does, keycap, what it does...
static func hints(pairs: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	for i in range(0, pairs.size(), 2):
		if i > 0:
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(10, 0)
			row.add_child(gap)
		if pairs[i] != "":
			row.add_child(keycap(pairs[i], true))
		row.add_child(label(pairs[i + 1], 12, FADED))
	return row
