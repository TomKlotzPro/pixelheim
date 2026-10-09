shader_type canvas_item;
// Tones whole regions of the Puny ground from a per-cell mask (PunyTerrain
// .tint_map, hue premultiplied by coverage). Where regions meet, coverage
// fades over a cell and an ordered Bayer pattern in 2px blocks decides which
// pixels take the tone: the retro dither, never a smudge. Water keeps its own
// colours, so the mire and the ash stop at the shore.
//
// And what moves in the open air (PIX-223): `sway` leans the top of each quad
// it draws (a tree, a wheat sheaf, a flower) while its foot stays put - one
// sprite as one (`sway_alone`, its own beat) or a layer's tiles together;
// `canopy` sways a whole forest's crowns as one sheet, in pixels. On the
// ground (`water_life`) the water swells with light, glints here and there,
// and foam laps where PunyTerrain.water_map's water meets the land.

#include "res://shaders/wind.gdshaderinc"

uniform sampler2D tint_map : filter_linear, repeat_disable;
uniform vec2 map_pixels;
uniform float strength = 0.85;
uniform float sway = 0.0;
uniform bool sway_alone = false;
uniform float canopy = 0.0;
uniform bool water_life = false;
uniform sampler2D water_map : filter_linear, repeat_disable;

varying vec2 world_pos;

const float BAYER[16] = float[16](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0
);
// Foam's colour. The water map reads 0.5 on its cells' edge, a sixteenth
// less or more a pixel either way, and Shade's water spills about 4 pixels
// past its cells (to 0.25): the shallows reach SHALLOWS, and the foam's thin
// line laps in and out around FOAM_REACH, broken here and there.
const vec3 FOAM = vec3(0.86, 0.98, 0.95);
const float SHALLOWS = 0.45;
const float FOAM_REACH = 0.34;
const float FOAM_LAP = 0.035;
const float FOAM_LINE = 0.032;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Shade's water, river and sea: blue-green with little red.
bool is_water(vec3 c) {
	return c.b > 0.5 && c.r < 0.45;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	float lean = canopy * wind_lean(world_pos, 0.0);
	if (sway > 0.0 && top_corner(VERTEX_ID)) {
		if (sway_alone) {
			vec2 foot = MODEL_MATRIX[3].xy;
			lean += sway * wind_lean(foot, hash(foot) * 6.2832);
		} else {
			lean += sway * wind_lean(world_pos, 0.0);
		}
	}
	VERTEX.x += lean;
}

void fragment() {
	vec4 base = COLOR;  // already the texel times the modulate
	vec4 tint = texture(tint_map, world_pos / map_pixels);
	ivec2 block = ivec2(floor(world_pos / 2.0)) & ivec2(3);
	float threshold = (BAYER[block.y * 4 + block.x] + 0.5) / 16.0;
	bool water = base.b > base.g;
	if (tint.a > threshold && !water) {
		vec3 hue = tint.rgb / tint.a;
		float luma = dot(base.rgb, vec3(0.299, 0.587, 0.114));
		base.rgb = mix(base.rgb, luma * hue * 2.0, strength);
	}
	if (water_life && is_water(base.rgb)) {
		vec2 px = floor(world_pos);
		// A slow swell of light rolling over the water.
		float swell = 0.6 * sin(world_time * 1.1 + px.x * 0.09 + px.y * 0.17)
			+ 0.4 * sin(world_time * 0.7 - px.x * 0.05 + px.y * 0.13);
		base.rgb *= 1.0 + 0.045 * swell;
		// Lighter in the shallows, and a broken line of foam lapping at the
		// shore.
		float out_from_shore = texture(water_map, (px + 0.5) / map_pixels).r;
		if (out_from_shore < SHALLOWS) {
			base.rgb = mix(base.rgb, FOAM, 0.12);
		}
		float lap = FOAM_REACH + FOAM_LAP * sin(world_time * 1.6 + (px.x + px.y) * 0.15);
		float broken = sin(px.x * 0.35 - px.y * 0.2 - world_time * 1.3) + sin(px.x * 0.13 + px.y * 0.31 + world_time * 0.7);
		if (abs(out_from_shore - lap) < FOAM_LINE && broken > -0.5) {
			base.rgb = mix(base.rgb, FOAM, 0.6);
		}
		// Glints: a short streak catches the light for a moment, here and
		// there, brightest in its middle.
		vec2 streak = vec2(floor(px.x / 3.0), px.y);
		float slot = floor(world_time * 1.8 + hash(streak) * 9.0);
		if (hash(streak + slot * 13.7) > 0.9965) {
			float middle = mod(px.x, 3.0) == 1.0 ? 0.7 : 0.4;
			base.rgb = mix(base.rgb, vec3(0.9, 1.0, 1.0), middle);
		}
	}
	COLOR = base;
}
