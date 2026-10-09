shader_type canvas_item;
// The open air of the title's backdrop (PIX-249), the world's (PIX-223,
// PIX-224) brought to the street under the mountain:
// - `sway` leans the top of what grows in the wind while its foot stays put,
//   each tree on the beat of where it stands;
// - `water` gives Shade's water a slow swell of light and glints catching
//   the moon. The village is moonlit by its modulate, which hides the
//   water's blue from COLOR, so the water is known by its texel;
// - `mist` lays a low fog down the valley, rolling slowly west: the Mire's
//   fog (atmosphere.gdshader) in moonlit grey, soft, in eight steps, thinning
//   as the rect's own alpha does toward its edges.
// What moves is read in the node's own pixels, so it stays on the water and
// in the valley as the title's camera drifts. The clock and the wind are the
// world's own (wind.gdshaderinc): TitleScene keeps them while the world waits.

#include "res://shaders/wind.gdshaderinc"
#include "res://shaders/linear.gdshaderinc"

uniform float sway = 0.0;
uniform bool water = false;
uniform bool mist = false;
uniform sampler2D noise : filter_linear, repeat_enable;
uniform vec3 mist_color = vec3(0.4, 0.42, 0.66);
uniform float mist_strength = 0.3;

// A glint is moonlight, bright enough to bloom.
const vec3 GLINT = vec3(0.96, 0.95, 0.84);

varying vec2 local;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	local = VERTEX;
	if (sway > 0.0 && top_corner(VERTEX_ID)) {
		// Where it stands on the canvas sets its beat: it changes only as
		// slowly as the camera drifts, so no tree jumps.
		VERTEX.x += sway * wind_lean(MODEL_MATRIX[3].xy, 0.0);
	}
}

void fragment() {
	if (water) {
		vec3 texel = to_display(texture(TEXTURE, UV).rgb);
		// Shade's water, river and sea: blue-green with little red.
		if (texel.b > 0.5 && texel.r < 0.45) {
			vec3 c = to_display(COLOR.rgb);
			vec2 px = floor(local);
			// A slow swell of light rolling over the water.
			float swell = 0.6 * sin(world_time * 1.1 + px.x * 0.09 + px.y * 0.17)
				+ 0.4 * sin(world_time * 0.7 - px.x * 0.05 + px.y * 0.13);
			c *= 1.0 + 0.08 * swell;
			// Glints: a short streak catches the moon for a moment, here and
			// there, brightest in its middle.
			vec2 streak = vec2(floor(px.x / 3.0), px.y);
			float slot = floor(world_time * 1.8 + hash(streak) * 9.0);
			if (hash(streak + slot * 13.7) > 0.992) {
				c = mix(c, GLINT, mod(px.x, 3.0) == 1.0 ? 0.85 : 0.45);
			}
			COLOR.rgb = to_canvas(c);
		}
	}
	if (mist) {
		// Banks longer than they are tall, rolling west.
		vec2 px = floor(local);
		vec2 drift = vec2(world_time * 3.0, world_time * 0.5);
		float thick = texture(noise, (px + drift) / vec2(420.0, 90.0)).r;
		thick *= 0.7 + 0.3 * texture(noise, (px - drift * 0.6) / vec2(160.0, 50.0)).g;
		// Soft, in eight steps: a fog has no edge to dither.
		float fog = floor(smoothstep(0.32, 0.72, thick) * 8.0) / 8.0;
		// A light haze blended in linear light shows stronger than over sRGB:
		// taken into the canvas's light, it shows the same over the night.
		float haze = to_canvas(vec3(fog * mist_strength * COLOR.a)).r;
		COLOR = vec4(to_canvas(mist_color), haze);
	}
}
