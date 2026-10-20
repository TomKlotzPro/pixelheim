shader_type canvas_item;
render_mode unshaded;
// Sparks off a burning house (PIX-327, FireArt.air): single art pixels born
// among the flames, climbing fast, wobbling, carried downwind, and cooling
// as they go, in Shade's fire colours (yellow, orange, red, then out). Each
// spark's slot is born somewhere new every time round. Drawn from the
// world's clock alone, so a stepped run draws them the same every time, and
// held still with the clock under Reduce motion. Never darkened by the night.

#include "res://shaders/linear.gdshaderinc"

global uniform float world_time;
global uniform float world_wind;
// The quad's size; the row the sparks are born from and how deep below it
// (pixels); a seed so no two houses throw alike.
uniform vec2 size = vec2(176.0, 152.0);
uniform vec2 born = vec2(44.0, 92.0);
uniform float seed = 0.0;
const int SPARKS = 18;
const vec3 HOT = vec3(0.984, 0.949, 0.212);
const vec3 WARM = vec3(0.875, 0.443, 0.149);
const vec3 COOL = vec3(0.675, 0.196, 0.196);

float hash(float n) {
	return fract(sin(n * 127.1 + seed * 311.7) * 43758.5453);
}

void fragment() {
	vec2 px = floor(UV * size);
	vec4 spark = vec4(0.0);
	for (int i = 0; i < SPARKS; i++) {
		float n = float(i);
		float span = 1.0 + 0.9 * hash(n + 0.3);
		float clock = world_time / span + hash(n + 1.7);
		float life = fract(clock);
		float round_no = floor(clock);
		vec2 from = vec2(hash(n * 3.1 + round_no * 7.7) * (size.x - 32.0) + 8.0, born.x + hash(n * 5.3 + round_no * 3.3) * born.y);
		float climb = (24.0 + 26.0 * hash(n + 4.1)) * life * span;
		float wobble = sin(life * 6.283 * (0.8 + hash(n + 8.0)) + n) * 2.5;
		vec2 at = from + vec2(wobble + (4.0 + 12.0 * world_wind) * life * life, -climb);
		if (floor(at) == px) {
			spark = vec4(life < 0.3 ? HOT : (life < 0.7 ? WARM : COOL), 1.0);
		}
	}
	COLOR = vec4(to_canvas(spark.rgb), spark.a);
}
