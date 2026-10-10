shader_type canvas_item;
// Ice over a dungeon's stone (PIX-255: the ice cave's frozen lake and its
// glass hall). MapView lays the floor of the ice cells, and of the stone
// round them, again on a layer of its own with this; `ice_map` has a texel a
// cell, white where the ice is, read smoothly so the shore runs between the
// cells, and a slow noise bends it off the grid as region_tint's edges are.
// The ice is pale and flat, the stone a ghost under it, bluer where it lies
// deep; thin cracks run between its plates here and there; a lip of deeper
// blue rims it, and frost creeps a little way out over the stone, thinning
// in the same 2px Bayer dither as the regions' edges. A few reflections lie
// on its polish, and now and then a glint catches the light and goes out.
// All of it in whole pixels of the art, so it reads as drawn, not smudged.

#include "res://shaders/linear.gdshaderinc"

global uniform float world_time;
uniform sampler2D ice_map : filter_linear, repeat_disable;
uniform vec2 map_pixels;

varying vec2 world_pos;

const float CELL = 16.0;
// How far the shore wanders off the grid, in pixels, and how wide its bends.
const float SHORE_WANDER = 7.0;
const float SHORE_BENDS = 1.3;
// The ice map reads 0.5 on the shore; frost reaches out over the stone to
// HALO, and the ice's lip runs in to LIP.
const float HALO = 0.36;
const float LIP = 0.56;
const vec3 ICE = vec3(0.8, 0.92, 1.0);
const vec3 DEEP = vec3(0.6, 0.78, 0.94);
const vec3 CRACK = vec3(0.55, 0.71, 0.88);
const vec3 LIP_TONE = vec3(0.68, 0.8, 0.94);
const vec3 FROST = vec3(0.9, 0.96, 1.0);
const vec3 SHEEN = vec3(0.97, 1.0, 1.0);
// The ice's plates, about this many pixels across, and how much of the lake
// is cracked between them.
const float PLATE = 30.0;
const float CRACKED = 0.36;
// A reflection: a few parallel dashes in one patch of this many pixels in
// so many.
const float PATCH = 26.0;
const float REFLECTED = 0.82;

const float BAYER[16] = float[16](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0
);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec2 hash2(vec2 p) {
	return vec2(hash(p), hash(p + 41.7));
}

// Smooth value noise, 0..1: the shore's slow bends, the ice's depth.
float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// How far `p` lies from the nearest edge between the plates (a Voronoi of
// one point a unit cell), in cells.
float plate_edge(vec2 p) {
	vec2 n = floor(p);
	vec2 f = fract(p);
	vec2 nearest_cell = vec2(0.0);
	vec2 nearest = vec2(8.0);
	float best = 8.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 r = g + hash2(n + g) * 0.8 + 0.1 - f;
			float d = dot(r, r);
			if (d < best) {
				best = d;
				nearest = r;
				nearest_cell = g;
			}
		}
	}
	float edge = 8.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = nearest_cell + vec2(float(i), float(j));
			vec2 r = g + hash2(n + g) * 0.8 + 0.1 - f;
			if (dot(nearest - r, nearest - r) > 0.0001) {
				edge = min(edge, dot(0.5 * (nearest + r), normalize(r - nearest)));
			}
		}
	}
	return edge;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 base = COLOR;  // already the texel times the modulate
	base.rgb = to_display(base.rgb);
	vec2 px = floor(world_pos) + 0.5;
	vec2 cells = floor(px / 2.0) * 2.0 / CELL / SHORE_BENDS;
	vec2 bend = vec2(value_noise(cells), value_noise(cells + 17.3)) - 0.5;
	float ice_here = texture(ice_map, (px + bend * 2.0 * SHORE_WANDER) / map_pixels).r;
	if (ice_here < HALO) {
		discard;
	}
	ivec2 block = ivec2(floor(world_pos / 2.0)) & ivec2(3);
	float threshold = (BAYER[block.y * 4 + block.x] + 0.5) / 16.0;
	if (ice_here < 0.5) {
		// Frost on the stone by the shore, thinning out.
		float reach = (ice_here - HALO) / (0.5 - HALO);
		if (reach * reach < threshold) {
			discard;
		}
		COLOR = vec4(to_canvas(mix(base.rgb, FROST, 0.32)), base.a);
	} else {
		// Pale, flat ice, bluer where it lies deep (in 2px steps of the
		// dither), the stone only a ghost under it.
		float depth = smoothstep(0.4, 0.75, value_noise(px / 44.0 + 3.7));
		vec3 ice = depth > threshold ? mix(ICE, DEEP, 0.4) : ICE;
		float luma = dot(base.rgb, vec3(0.299, 0.587, 0.114));
		ice *= 0.86 + 0.28 * luma;
		// Thin cracks between its plates, across some of it, broken off
		// along their way.
		if (value_noise(px / 70.0 + 9.1) > 1.0 - CRACKED && value_noise(px / 11.0 + 5.3) > 0.3
				&& plate_edge(px / PLATE) * PLATE < 0.7) {
			ice = CRACK;
		}
		if (ice_here < LIP) {
			ice *= LIP_TONE;
		}
		// A reflection on its polish, here and there: two or three short
		// parallel dashes rising to the right.
		vec2 patch = floor(px / PATCH);
		if (hash(patch + 3.1) > REFLECTED) {
			vec2 q = floor(px) - patch * PATCH - floor(vec2(hash(patch + 5.7) * 8.0 + 2.0, hash(patch + 9.2) * 6.0 + 16.0));
			float run = 4.0 + floor(hash(patch + 1.3) * 5.0);
			for (int line = 0; line < 3; line++) {
				float x = q.x - float(line) * 3.0;
				float reach = run - float(line) * 2.0;
				if (reach > 1.0 && x >= 0.0 && x < reach && q.y == -x) {
					ice = mix(ice, SHEEN, 0.6);
				}
			}
		}
		// A glint: a small cross of light that catches and goes out.
		vec2 spot = floor(px / 7.0);
		float beat = floor(world_time * 0.7 + hash(spot) * 13.0);
		if (hash(spot + beat * 7.31) > 0.993) {
			vec2 at = mod(floor(px), 7.0) - 3.0;
			float off = abs(at.x) + abs(at.y);
			if ((at.x == 0.0 || at.y == 0.0) && off <= 2.0) {
				ice = mix(ice, vec3(1.0), off < 0.5 ? 0.9 : 0.5);
			}
		}
		COLOR = vec4(to_canvas(ice), base.a);
	}
}
