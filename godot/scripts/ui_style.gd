class_name UiStyle
## The game's one look (PIX-138): pages of a village ledger. Parchment in a
## carved wooden frame with brass studs at the corners, in the wood of the
## shop signs; rows and slots inked onto the page; brown-black ink for text
## and rubric red, the scribes' red, for whatever has focus. Around the
## windows the world dims to a warm dark where text is cream and focus gold.
## Every frame is pixel art drawn here from the palette at 1x and shown at
## UI_SCALE, so the chrome sits on a pixel grid like the world does.
## Type, all pixel fonts on the frames' grid: every letter at 2x or 3x of its
## own pixels, never 1x, so text is as crisp and as heavy as the chrome round
## it: Pixeloid Sans (and Bold) for everything, 18 on the canvas, or 27 for
## screen titles and what is read across the room. The title's logo keeps
## Press Start 2P (`logo_font`). Both OFL.

## Canvas pixels per pixel of UI art.
const UI_SCALE := 2
## The fonts' own pixel sizes: what fixed-size rendering scales from.
const BODY_PX := 9
const LOGO_PX := 8
## Text on the canvas: what's read, and what's read at a glance.
const TEXT := 18
const BIG := 27

## The dark: outlines, shadows, and what the world dims to behind a screen.
const NIGHT := Color("1c120a")
const BACKDROP := Color(0.08, 0.05, 0.03, 0.9)
## The page: a window's parchment, a row's or slot's darker sheet, its inked rim.
const WINDOW := Color("ead6a6")
const CARD := Color("dcc391")
const RIM := Color("a8854e")
## The frame: the shop signs' wood, and brass for the studs.
const WOOD_LIGHT := Color("b47c44")
const WOOD := Color("8c5a2e")
const WOOD_DARK := Color("5e3b1d")
const BRASS_LIGHT := Color("f6dc8a")
const BRASS := Color("d9a441")
const BRASS_DARK := Color("8a6420")
## Text on the page: ink, faded ink, and rubric red for focus.
const INK := Color("3a2414")
const FADED := Color("7d5f3e")
const LAMP := Color("b03a1e")
## Text on the dark (titles over the dimmed world, key footers, the title
## screen): cream, dusk, and gold for focus.
const CREAM := Color("f3e6c4")
const DUSK := Color("c9b48a")
const GOLD := Color("f2c14e")
## Rarity, inked: fine pieces in blue, epic in purple.
const FINE := Color("1f5a9a")
const EPIC := Color("6e2d8c")
## Grain flecks in the parchment.
const GRAIN := Color("e0c995")

static var _frames := {}
static var _logo_font: FontFile
static var _body_font: FontFile
static var _bold_font: FontFile


## Once, before any screen is built: the body font (the project's default,
## gui/theme/custom_font) renders at its pixel size and scales whole, and a
## control nobody sized reads at TEXT.
static func setup() -> void:
	ThemeDB.fallback_font = body_font()
	ThemeDB.fallback_font_size = TEXT
	var root := (Engine.get_main_loop() as SceneTree).root
	if root.theme == null:
		root.theme = Theme.new()
	root.theme.default_font = body_font()
	root.theme.default_font_size = TEXT


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


## The type a size asks for (see above), on any control: TEXT below 24,
## BIG from 24.
static func sized(node: Control, font_size: int, bold := false) -> Control:
	node.add_theme_font_override("font", bold_font() if bold else body_font())
	node.add_theme_font_size_override("font_size", BIG if font_size >= 24 else TEXT)
	return node


## A label in the bold cut (names, amounts, what a row is).
static func strong(text: String, font_size: int, color: Color, at := Vector2.ZERO) -> Label:
	var node := label(text, font_size, color, at)
	sized(node, font_size, true)
	return node


static func body_font() -> FontFile:
	if _body_font == null:
		_body_font = _pixel_font(load("res://assets/fonts/PixeloidSans.ttf"), BODY_PX)
	return _body_font


static func bold_font() -> FontFile:
	if _bold_font == null:
		_bold_font = _pixel_font(load("res://assets/fonts/PixeloidSans-Bold.ttf"), BODY_PX)
	return _bold_font


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


## The main window: parchment in a carved wooden frame (lit top and left,
## shaded bottom and right), a dark outline, an inked line inside it, brass
## studs at the corners and flecks of grain in the page, which tiles rather
## than stretches. A dark `fill` is a plate of wood instead of a page (the
## dialogue's name tab).
static func window(padding := 16, fill := WINDOW) -> StyleBoxTexture:
	var key := "window %s" % fill.to_html()
	if not _frames.has(key):
		var size := 28  # a 6-pixel frame around a 16-pixel tile of page
		var art := Image.create(size, size, false, Image.FORMAT_RGBA8)
		art.fill(fill)
		if fill == WINDOW:
			for fleck: Vector2i in [
				Vector2i(8, 9), Vector2i(15, 7), Vector2i(19, 13), Vector2i(11, 16),
				Vector2i(17, 20), Vector2i(7, 21), Vector2i(21, 8), Vector2i(13, 11),
			]:
				art.set_pixelv(fleck, GRAIN)
		_ring(art, 0, NIGHT, true)
		for i in range(1, size - 1):
			# The wood: lit along the top and left, shaded along the bottom and right.
			art.set_pixel(i, 1, WOOD_LIGHT)
			art.set_pixel(1, i, WOOD_LIGHT)
			for row: int in [2, 3]:
				art.set_pixel(i, row, WOOD)
				art.set_pixel(row, i, WOOD)
				art.set_pixel(i, size - 1 - row, WOOD)
				art.set_pixel(size - 1 - row, i, WOOD)
			art.set_pixel(i, size - 2, WOOD_DARK)
			art.set_pixel(size - 2, i, WOOD_DARK)
		_ring(art, 4, NIGHT, false)
		_ring(art, 5, RIM, false)
		# A brass stud in each corner: lit top-left, shaded bottom-right.
		for corner: Vector2i in [Vector2i(1, 1), Vector2i(size - 4, 1), Vector2i(1, size - 4), Vector2i(size - 4, size - 4)]:
			art.set_pixelv(corner, BRASS_LIGHT)
			art.set_pixelv(corner + Vector2i(1, 0), BRASS)
			art.set_pixelv(corner + Vector2i(0, 1), BRASS)
			art.set_pixelv(corner + Vector2i(1, 1), BRASS_DARK)
		# Rounded corners: the outline steps in.
		for corner: Vector2i in _corners(art, 1):
			art.set_pixelv(corner, NIGHT)
		_frames[key] = _texture(art)
	var style := _style(_frames[key], 6, padding)
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	return style


## A page laid behind a screen's content, `rect` in canvas pixels: the
## window, not a container, so rows and words already placed sit on it.
static func page(rect: Rect2) -> Panel:
	var node := Panel.new()
	node.position = rect.position
	node.size = rect.size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_stylebox_override("panel", window(0))
	return node


## A card, row or slot: its fill inside a one-pixel rim and the outline.
static func _card(fill: Color, rim: Color) -> ImageTexture:
	var key := "card %s %s" % [fill.to_html(), rim.to_html()]
	if not _frames.has(key):
		var art := Image.create(8, 8, false, Image.FORMAT_RGBA8)
		art.fill(fill)
		if rim.a > 0.0:
			# Inked onto the page: the rim is the line, no outline beyond it
			# (focus doubles it, a rubric box).
			_ring(art, 0, rim, true)
			if rim == LAMP:
				_ring(art, 1, rim, false)
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
	sized(node, TEXT)
	node.add_theme_color_override("font_color", CREAM)
	node.add_theme_color_override("font_hover_color", GOLD)
	node.add_theme_color_override("font_pressed_color", GOLD)
	node.add_theme_stylebox_override("normal", plank(false, 6))
	node.add_theme_stylebox_override("hover", plank(true, 6))
	node.add_theme_stylebox_override("pressed", plank(true, 6))
	node.add_theme_stylebox_override("disabled", plank(false, 6, true))
	node.add_theme_color_override("font_disabled_color", Color(DUSK, 0.7))
	node.pressed.connect(action)
	return node


## A button with focus (the chosen tab or menu line): the plank lit brass, its
## words in gold.
static func focus(button: Button, on := true) -> void:
	button.add_theme_stylebox_override("normal", plank(on, 6))
	button.add_theme_color_override("font_color", GOLD if on else CREAM)


## A wooden plank (buttons, the menu): wood with a lit top edge and a dark
## outline; `lit` gives it a brass rim (hover, focus), `dim` darkens it (a
## button that can't be pressed now).
static func plank(lit: bool, padding := 6, dim := false) -> StyleBoxTexture:
	var key := "plank %s %s" % [lit, dim]
	if not _frames.has(key):
		var art := Image.create(8, 8, false, Image.FORMAT_RGBA8)
		art.fill(WOOD_DARK if dim else WOOD)
		for i in range(1, 7):
			art.set_pixel(i, 1, WOOD if dim else WOOD_LIGHT)
			art.set_pixel(i, 6, NIGHT if dim else WOOD_DARK)
		_ring(art, 0, BRASS if lit else NIGHT, true)
		_frames[key] = _texture(art)
	return _style(_frames[key], 2, padding)


## The pixel font for headings: crisp, never smoothed.
## The logo's arcade capitals (the title screen).
static func logo_font() -> FontFile:
	if _logo_font == null:
		_logo_font = _pixel_font(load("res://assets/fonts/press-start-2p.woff2"), LOGO_PX)
	return _logo_font


## A heading in the bold cut: from 18 a screen's title, at BIG; below, a
## section's, at TEXT.
static func heading(text: String, font_size: int, color: Color, at := Vector2.ZERO) -> Label:
	var node := label(text, font_size, color, at)
	sized(node, BIG if font_size >= 18 else TEXT, true)
	# A shadow lifts a heading off the dark; on the page ink lies flat.
	if color not in [INK, FADED, LAMP]:
		node.add_theme_color_override("font_shadow_color", NIGHT)
		node.add_theme_constant_override("shadow_offset_x", UI_SCALE)
		node.add_theme_constant_override("shadow_offset_y", UI_SCALE)
	return node


## The key a command answers to, as a little keycap: "E", "Esc". `small`
## caps carry the dense type (HUD chips).
static func keycap(key: String, small := false) -> PanelContainer:
	var cap := PanelContainer.new()
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.add_theme_stylebox_override("panel", _style(_card(CREAM, NIGHT), 2, 2 if small else 4))
	var text := strong(key, TEXT, NIGHT)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.custom_minimum_size = Vector2(8, 0)
	cap.add_child(text)
	return cap


## Relabels a keycap (a rebound key).
static func keycap_text(cap: PanelContainer, key: String) -> void:
	(cap.get_child(0) as Label).text = key


## A screen eases in once built: the dark fades up and the pages rise a few
## pixels into place, a fifth of a second (at once with reduce motion).
static func enter(layer: CanvasLayer) -> void:
	if not is_instance_valid(layer):
		return
	Sound.play_ui("open")
	layer.tree_exiting.connect(Sound.play_ui.bind("close"), CONNECT_ONE_SHOT)
	if GameState.settings.reduce_motion:
		return
	var tween := layer.create_tween().set_parallel()
	for child in layer.get_children():
		if not child is CanvasItem:
			continue
		var item := child as CanvasItem
		item.modulate.a = 0.0
		tween.tween_property(item, "modulate:a", 1.0, 0.14)
		# The backdrop only fades; what stands on it rises.
		if child is Control and not child is ColorRect:
			var control := child as Control
			var settled := control.position
			control.position = settled + Vector2(0, 10)
			tween.tween_property(control, "position", settled, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


## A gold coin: brass rim, lit face, a stamped mark (the purse in the dock).
static func coin() -> ImageTexture:
	if not _frames.has("coin"):
		var rows := [
			"..ooo..",
			".oLLGo.",
			"oLGGGBo",
			"oLGBGBo",
			"oGGGBBo",
			".oBBBo.",
			"..ooo..",
		]
		var colors := {"o": NIGHT, "L": BRASS_LIGHT, "G": GOLD, "B": BRASS}
		var art := Image.create(7, 7, false, Image.FORMAT_RGBA8)
		art.fill(Color(0, 0, 0, 0))
		for y in rows.size():
			for x in String(rows[y]).length():
				var key: String = rows[y][x]
				if colors.has(key):
					art.set_pixel(x, y, colors[key])
		_frames["coin"] = _texture(art)
	return _frames["coin"]


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
## `centered` spreads it across the screen's middle (at.x is ignored). It
## sits on the dark under the windows.
static func footer(line: String, at: Vector2, centered := false) -> HBoxContainer:
	var pairs := []
	for command in RegEx.create_from_string(" {4,}").sub(line.strip_edges(), "\t", true).split("\t"):
		var cut := command.find("  ")
		pairs.append_array([command.substr(0, cut).strip_edges(), command.substr(cut).strip_edges()] if cut > 0 else ["", command])
	var row := hints(pairs, true)
	row.position = at
	if centered:
		row.position.x = 0
		row.custom_minimum_size = Vector2(1280, 0)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
	return row


## A row of key hints: keycap, what it does, keycap, what it does... on the
## page, or `on_dark` under the windows.
static func hints(pairs: Array, on_dark := false) -> HBoxContainer:
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
		row.add_child(label(pairs[i + 1], 12, DUSK if on_dark else FADED))
	return row
