class_name Touch
## The phone version (PIX-162): whether to play by touch, and how the game's
## 1280x720 canvas sits on a screen of another shape. On a touch device the
## canvas grows to fill the screen (portrait or landscape) instead of
## letterboxing: the HUD keeps to the bottom, screens to the middle. On a
## desktop the canvas keeps its shape and every offset here is zero.

## The design canvas every HUD and screen is laid out on.
const DESIGN := Vector2(1280, 720)

## Harness runs (`touch`) play as a phone would.
static var forced := false


## A phone or a tablet: the web build on Android or iOS, or a native mobile
## build. A laptop with a touch screen keeps its keyboard layout.
static func enabled() -> bool:
	return forced or OS.has_feature("web_android") or OS.has_feature("web_ios") or OS.has_feature("mobile")


## The canvas as the screen shows it now (1280x720 on a desktop).
static func view_size(node: Node) -> Vector2:
	return node.get_viewport().get_visible_rect().size


## Where the HUD's 1280x720 layout goes: centred across, down at the bottom.
static func hud_offset(node: Node) -> Vector2:
	return hud_offset_for(view_size(node))


static func hud_offset_for(size: Vector2) -> Vector2:
	return Vector2(roundf((size.x - DESIGN.x) / 2.0), roundf(size.y - DESIGN.y))


## Where a screen's 1280x720 layout goes: in the middle.
static func center_offset(node: Node) -> Vector2:
	return center_offset_for(view_size(node))


static func center_offset_for(size: Vector2) -> Vector2:
	return ((size - DESIGN) / 2.0).round()
