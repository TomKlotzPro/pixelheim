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


## `css` CSS pixels (what a thumb measures) in canvas units (PIX-214): the
## screen's own scale over the canvas's. The web draws at devicePixelRatio
## (and a phone at its density); a desktop window, even playing as a phone,
## draws a pixel a point.
static func css(node: Node, css_px: float) -> float:
	var canvas := maxf(0.2, node.get_tree().root.get_final_transform().get_scale().x)
	var density := DisplayServer.screen_get_scale() if OS.has_feature("web") or OS.has_feature("mobile") else 1.0
	return css_px * maxf(1.0, density) / canvas


## The pad's sizes in CSS pixels, a thumb's measure whatever the screen
## (PIX-214: they were screen pixels, a third of a thumb on a dense phone):
## diameters, then the gaps between.
const STICK_CSS := 120.0
const BIG_CSS := 72.0
const SMALL_CSS := 52.0
const MARGIN_CSS := 20.0
const GAP_CSS := 8.0
## Room left for the dock under the pad, in canvas units.
const DOCK_ROOM := 130.0


## Where the pad's controls go on a canvas of `size`, `unit` canvas units to
## a CSS pixel: the stick bottom-left; attack in the bottom-right corner, then
## around it a ring with the roll, the first skill and use, and a wider ring
## with skills two to six - all above the dock.
## {stick_center, stick_radius, buttons: [{action, glyph, center, radius}]}.
static func pad_plan(size: Vector2, unit: float) -> Dictionary:
	var stick_radius := STICK_CSS / 2.0 * unit
	var margin := MARGIN_CSS * unit
	var gap := GAP_CSS * unit
	var big := BIG_CSS / 2.0 * unit
	var small := SMALL_CSS / 2.0 * unit
	var attack := Vector2(size.x - margin - big, size.y - DOCK_ROOM - margin - big)
	# Rings wide enough that neighbours a few degrees apart never touch.
	var near := big + small + gap * 2.0
	var far := near + small * 2.0 + gap * 2.0
	var at := func(angle: float, reach: float) -> Vector2: return attack + Vector2.RIGHT.rotated(deg_to_rad(angle)) * reach
	var buttons: Array[Dictionary] = [
		{"action": "attack", "glyph": "sword", "center": attack, "radius": big},
		{"action": "dodge", "glyph": "roll", "center": at.call(185.0, near), "radius": small},
		{"action": "skill_1", "glyph": "1", "center": at.call(225.0, near), "radius": small},
		{"action": "interact", "glyph": "use", "center": at.call(265.0, near), "radius": small},
	]
	for index in 5:
		buttons.append({"action": "skill_%d" % (index + 2), "glyph": str(index + 2), "center": at.call(180.0 + 22.5 * index, far), "radius": small})
	return {
		"stick_center": Vector2(margin + stick_radius, size.y - DOCK_ROOM - margin - stick_radius),
		"stick_radius": stick_radius,
		"buttons": buttons,
	}


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
