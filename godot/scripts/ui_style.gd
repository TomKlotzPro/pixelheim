class_name UiStyle
## The game's one look (PIX-127): the map screen's night backdrop and waypoint
## gold, oak cards with square 2px rims, parchment ink; Courier Prime for every
## word (the project's default font, gui/theme/custom_font) and Press Start 2P
## for headings and the logo, as the web sets them.

const BACKDROP := Color(0.043, 0.047, 0.063, 0.97)
const LAMP := Color(1, 0.85, 0.3)
const CARD := Color(0.12, 0.1, 0.085)
const RIM := Color(0.32, 0.26, 0.2)
const INK := Color(0.95, 0.91, 0.83)
const FADED := Color(0.95, 0.91, 0.83, 0.55)


static func label(text: String, font_size: int, color: Color, at := Vector2.ZERO) -> Label:
	var node := Label.new()
	node.text = text
	node.position = at
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	return node


## Square-cornered pixel panels: a flat fill and a 2px rim.
static func box(fill: Color, rim: Color, padding := 8) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = rim
	style.set_border_width_all(2)
	style.set_content_margin_all(padding)
	return style


## Clickable twins of key commands; keyboard focus stays with the screen.
static func button(text: String, action: Callable) -> Button:
	var node := Button.new()
	node.text = text
	node.focus_mode = Control.FOCUS_NONE
	node.add_theme_font_size_override("font_size", 14)
	node.add_theme_color_override("font_color", INK)
	node.add_theme_color_override("font_hover_color", LAMP)
	node.add_theme_stylebox_override("normal", box(Color(0, 0, 0, 0), RIM))
	node.add_theme_stylebox_override("hover", box(Color(0, 0, 0, 0), LAMP))
	node.add_theme_stylebox_override("pressed", box(CARD, LAMP))
	node.pressed.connect(action)
	return node


static var _heading_font: FontFile


## The pixel font for headings: crisp, never smoothed.
static func heading_font() -> FontFile:
	if _heading_font == null:
		_heading_font = load("res://assets/fonts/press-start-2p.woff2")
		_heading_font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		_heading_font.hinting = TextServer.HINTING_NONE
		_heading_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	return _heading_font


## A heading in the pixel font (screen titles, the logo, the ascension).
static func heading(text: String, font_size: int, color: Color, at := Vector2.ZERO) -> Label:
	var node := label(text, font_size, color, at)
	node.add_theme_font_override("font", heading_font())
	return node
