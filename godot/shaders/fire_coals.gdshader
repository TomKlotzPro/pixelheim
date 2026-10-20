shader_type canvas_item;
render_mode unshaded;
// The coals on a burning house's fallen floor (PIX-327, FireArt.air): here
// and there a pixel or two of the ash still alight, each breathing on its own
// slow beat, dark, then red, then orange, in Shade's colours, in steps.
// Never darkened by the night; held still with the clock under Reduce
// motion.

#include "res://shaders/linear.gdshaderinc"

global uniform float world_time;
uniform vec2 size = vec2(112.0, 64.0);
uniform float seed = 0.0;
// One coal in so many 3x3 blocks, and the steps a second they breathe in.
const float SHARE = 0.07;
const float STEPS = 6.0;
const vec3 RED = vec3(0.675, 0.196, 0.196);
const vec3 ORANGE = vec3(0.875, 0.443, 0.149);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7)) + seed * 17.13) * 43758.5453);
}

void fragment() {
	vec2 px = floor(UV * size);
	vec2 block = floor(px / 3.0);
	float h = hash(block);
	vec2 spot = block * 3.0 + floor(vec2(hash(block + 7.1), hash(block + 3.9)) * 3.0);
	bool lit = h < SHARE && (px == spot || (h < SHARE * 0.5 && px == spot + vec2(1.0, 0.0)));
	vec4 coal = vec4(0.0);
	if (lit) {
		float t = floor(world_time * STEPS) / STEPS;
		float beat = 0.5 + 0.5 * sin(t * (0.9 + 1.4 * h / SHARE) + h * 61.0);
		if (beat > 0.3) {
			coal = vec4(beat > 0.7 ? ORANGE : RED, 1.0);
		}
	}
	COLOR = vec4(to_canvas(coal.rgb), coal.a);
}
