shader_type canvas_item;
// The desktop app's glow, its first half (PIX-227): what's brighter than
// `threshold` in the world, picked out before the glow's blur. The screen is
// written back as it is, with how much brighter than the threshold each
// pixel is (in linear light, up to 1) kept in its alpha as 1 minus that.
// glow_wide.gdshader's screen copy blurs the colours and this mark alike, so
// it spreads only the brights: a flame's light reaches as far as it is
// bright, however small the flame. Unmarked, the alpha stays 1 and nothing
// more glows. Last on the LightRig's layer (after the browser's glow), shown
// only on the desktop app's canvas, at night.
render_mode unshaded, blend_disabled;

#include "res://shaders/linear.gdshaderinc"

uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform float threshold = 0.45;

void fragment() {
	vec3 seen = texture(screen, SCREEN_UV).rgb;
	vec3 light = to_light(seen);
	float bright = max(max(light.r, light.g), light.b);
	COLOR = vec4(seen, 1.0 - clamp(bright - threshold, 0.0, 1.0));
}
