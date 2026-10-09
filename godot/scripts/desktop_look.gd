class_name DesktopLook
## The desktop app's extras (PIX-227). The browser build stays the main one.
## Its renderer (Compatibility, WebGL2) draws the canvas eight bits a channel
## in the screen's own sRGB, so there the light and the glow are LightRig's
## passes alone. The app (macOS, Windows, or any desktop run) has the desktop
## renderer (Forward+), which does more:
## - the canvas in HDR: linear light, sixteen bits a channel, so a light adds
##   as light does and a lamp's falloff and the glow's rings into the night
##   have no bands; debanded on their way out;
## - a second, wider glow at night (shaders/glow_mask.gdshader and
##   glow_wide.gdshader): the brights picked out before the blur, so a
##   flame's light reaches as far as it is bright, however small the flame.
## (The renderer's own glow, a WorldEnvironment, was tried and dropped: on
## 4.7 everything drawn after its pass, the HUD included, came out lifted,
## and lamplit rooms washed out.) The app keeps the browser's saves: the same
## slot files (user://saves/slot_<n>.json under the pinned user dir), the
## same format.
##
## A look is how the app wears these, by name (LOOKS). LightRig wears one;
## a run picks another with `--look NAME`, and the look book shoots several
## side by side (`--looks a,b`). The rules here are pure.

## hdr: the canvas in linear HDR; wide: the wider glow's strength at full
## night (none by day), on top of the browser's own glow pass.
const LOOKS := {
	"browser": {"hdr": false, "wide": 0.0},
	"hdr": {"hdr": true, "wide": 0.0},
	"app": {"hdr": true, "wide": 1.0},
	"app_bright": {"hdr": true, "wide": 1.6},
}
## The browser's look (no extras), and the app's.
const BROWSER := "browser"
const APP := "app"
## The renderer the extras need: the desktop's. (The mobile renderer's HDR
## canvas keeps two bits of alpha, too few for the wide glow's mark.)
const RENDERERS := ["forward_plus"]

## The look worn now, and whether the canvas draws in linear light now
## (LightRig keeps both).
static var look := BROWSER
static var linear := false


## Whether the extras can run: the desktop renderer drawing to a window, not
## the browser's build. (A desktop renderer that couldn't start falls back
## to the browser's, and so to its look.)
static func available(method: String, web: bool, display: String) -> bool:
	return not web and display != "headless" and method in RENDERERS


## Whether they can run here.
static func here() -> bool:
	return available(RenderingServer.get_current_rendering_method(), OS.has_feature("web"), DisplayServer.get_name())


## The look to wear: the browser's where the extras can't run, else the one
## `--look NAME` names, else the app's.
static func pick(can: bool, args: PackedStringArray) -> String:
	if not can:
		return BROWSER
	var index := args.find("--look")
	if index >= 0 and index + 1 < args.size() and LOOKS.has(args[index + 1]):
		return args[index + 1]
	return APP


static func _spec(name: String) -> Dictionary:
	return LOOKS.get(name, LOOKS[BROWSER])


## Whether a look draws the canvas in linear HDR.
static func hdr(name: String) -> bool:
	return bool(_spec(name)["hdr"])


## How strong the wider glow is when it is `dark` (0 by day, 1 at night):
## none in the sun (sunlit sand and snow are bright too), none with the
## player's Glow off, none off a linear canvas (it adds light as light).
static func wide(name: String, dark: float, glow_on: bool) -> float:
	if not glow_on or not hdr(name):
		return 0.0
	return float(_spec(name)["wide"]) * clampf(dark, 0.0, 1.0)


## A light's colour on the canvas. Lights are taken as they are, so in
## linear light a colour picked by eye must be made linear to keep its hue.
static func canvas_color(color: Color, is_linear: bool) -> Color:
	return color.srgb_to_linear() if is_linear else color


## What a pixel read off the canvas shows on the screen.
static func shown(color: Color, is_linear: bool) -> Color:
	return color.linear_to_srgb() if is_linear else color


## Waits for a frame drawn. While the window is hidden (another app full
## screen over it) the engine draws nothing of its own accord, so this draws
## the frame itself.
static func drawn(node: Node) -> void:
	if DisplayServer.window_can_draw():
		await RenderingServer.frame_post_draw
	else:
		await node.get_tree().process_frame
		RenderingServer.force_draw(false)


## The screen's sRGB from a linear picture, pixel for pixel.
const _TO_SRGB := """
shader_type canvas_item;
render_mode unshaded, blend_disabled;
void fragment() {
	vec3 c = clamp(texture(TEXTURE, UV).rgb, 0.0, 1.0);
	COLOR = vec4(mix(1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, c * 12.92, lessThan(c, vec3(0.0031308))), 1.0);
}
"""


## What the screen shows now, as a picture to save. A linear canvas holds
## light, not the screen's colours, and would save far too dark: it is
## turned into the screen's sRGB on the GPU first (eight bits a channel of
## linear light would band the night).
static func snapshot(node: Node) -> Image:
	var viewport := node.get_viewport()
	var image := viewport.get_texture().get_image()
	if not viewport.use_hdr_2d:
		return image
	var view := SubViewport.new()
	view.size = image.get_size()
	view.use_hdr_2d = false
	view.render_target_update_mode = SubViewport.UPDATE_ONCE
	var picture := TextureRect.new()
	picture.texture = ImageTexture.create_from_image(image)
	picture.size = Vector2(image.get_size())
	var shader := Shader.new()
	shader.code = _TO_SRGB
	var material := ShaderMaterial.new()
	material.shader = shader
	picture.material = material
	view.add_child(picture)
	node.add_child(view)
	await drawn(node)
	var out := view.get_texture().get_image()
	view.queue_free()
	return out
