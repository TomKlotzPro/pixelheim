shader_type canvas_item;
// Glow (PIX-222): what's bright in the world blooms softly around itself.
// The browser's renderer has no glow of its own, so this does it by hand:
// the world drawn so far (the screen texture, in its mipmaps for a cheap wide
// blur), only what's brighter than `threshold`, added back over the world.
// It sits on its own canvas layer between the world and the HUD, so the HUD
// never glows. The LightRig sets `strength` by how dark it is: lamps and
// fires bloom at night, while daylight sand doesn't. On the desktop app's
// linear canvas (PIX-227) it adds what shows the same glow.
render_mode unshaded, blend_add;

#include "res://shaders/linear.gdshaderinc"

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float threshold = 0.58;
uniform float strength = 0.8;

void fragment() {
	vec3 glow = vec3(0.0);
	// Wider rings weigh more: a tight core and a soft long falloff.
	glow += max(to_display(textureLod(screen, SCREEN_UV, 1.5).rgb) - threshold, vec3(0.0)) * 0.12;
	glow += max(to_display(textureLod(screen, SCREEN_UV, 2.5).rgb) - threshold, vec3(0.0)) * 0.2;
	glow += max(to_display(textureLod(screen, SCREEN_UV, 3.5).rgb) - threshold, vec3(0.0)) * 0.26;
	glow += max(to_display(textureLod(screen, SCREEN_UV, 4.5).rgb) - threshold, vec3(0.0)) * 0.26;
	vec3 base = to_display(textureLod(screen, SCREEN_UV, 0.0).rgb);
	COLOR = vec4(lift(base, glow * strength), 1.0);
}
