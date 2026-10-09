shader_type canvas_item;
// The desktop app's glow, its second half (PIX-227): the brights
// glow_mask.gdshader marked in the screen's alpha, spread soft and far, in
// the hue of the light around them, and added as light (the app's canvas is
// linear). The mark rides the screen copy's blur only when this pass makes
// the copy itself, so it sits alone on a canvas layer of its own, right
// after the LightRig's and under the HUD's. LightRig sets `strength` by how
// dark it is.
render_mode unshaded, blend_add;

#include "res://shaders/linear.gdshaderinc"

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float strength = 0.0;

// The marked brights at a level of the blur, in the hue of the light
// around them (toward white where it's dark).
vec3 spread(vec2 uv, float lod) {
	vec4 seen = textureLod(screen, uv, lod);
	vec3 light = to_light(seen.rgb) + 0.03;
	return light / max(max(light.r, light.g), light.b) * max(1.0 - seen.a, 0.0);
}

void fragment() {
	// A halo a few art pixels wide weighs most, a broad one round it less.
	vec2 uv = SCREEN_UV;
	vec3 light = spread(uv, 2.0) * 0.3 + spread(uv, 3.0) * 0.5 + spread(uv, 4.0) * 0.5 + spread(uv, 5.0) * 0.3;
	vec3 seen = textureLod(screen, uv, 0.0).rgb;
	COLOR = vec4(from_light(to_light(seen) + light * strength) - seen, 1.0);
}
