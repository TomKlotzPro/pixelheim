shader_type canvas_item;
// Ice over a dungeon's stone (PIX-255: the ice cave's frozen lake and its
// glass hall). MapView lays the floor of the ice cells, and of the stone
// round them, again on a layer of its own with this; `ice_map` has a texel a
// cell, white where the ice is. The look is frozen.gdshaderinc's, which the
// ground in the open air shares (region_tint.gdshader, PIX-398): here the
// stone is the ghost under the ice and the frost creeps out over it.

#include "res://shaders/linear.gdshaderinc"

global uniform float world_time;
uniform sampler2D ice_map : filter_linear, repeat_disable;
uniform vec2 map_pixels;

varying vec2 world_pos;

const float BAYER[16] = float[16](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0
);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
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

#include "res://shaders/frozen.gdshaderinc"

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 base = COLOR;  // already the texel times the modulate
	base.rgb = to_display(base.rgb);
	vec2 px = floor(world_pos) + 0.5;
	ivec2 block = ivec2(floor(world_pos / 2.0)) & ivec2(3);
	float threshold = (BAYER[block.y * 4 + block.x] + 0.5) / 16.0;
	vec4 ice = ice_over(base.rgb, px, texture(ice_map, ice_shore_at(px) / map_pixels).r, threshold, vec3(1.0));
	if (ice.a == 0.0) {
		discard;
	}
	COLOR = vec4(to_canvas(ice.rgb), base.a);
}
