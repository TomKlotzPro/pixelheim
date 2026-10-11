shader_type canvas_item;
render_mode blend_add, unshaded;
// Dust in a torch's light (PIX-310): a few motes drifting slowly up and
// sideways through the pool of light under a torch on a dungeon's wall,
// each a single pixel of the art, brightening as it drifts into the light
// and fading out, warm as the flame. Drawn on a quad over the light's pool
// from the world's clock alone (no dice: a stepped run draws them the same
// every time), held still with the clock under reduced motion.

#include "res://shaders/linear.gdshaderinc"

global uniform float world_time;
// The quad's size in pixels, how many motes drift in it, their warmth.
uniform vec2 size = vec2(40.0, 34.0);
uniform float seed = 0.0;
const int MOTES = 7;
const vec3 WARM = vec3(1.0, 0.86, 0.6);
// How long a mote takes to drift through, in seconds.
const float DRIFT = 7.0;

float hash(float n) {
	return fract(sin(n * 127.1 + seed * 311.7) * 43758.5453);
}

void fragment() {
	vec2 px = floor(UV * size);
	float light = 0.0;
	for (int i = 0; i < MOTES; i++) {
		float n = float(i);
		float life = fract(world_time / (DRIFT * (0.8 + 0.4 * hash(n + 0.3))) + hash(n + 1.7));
		vec2 from = vec2(hash(n + 2.9) * size.x, size.y * (0.55 + 0.45 * hash(n + 4.1)));
		vec2 at = from + vec2(sin(life * 6.283 + n) * 3.0, -life * size.y * 0.6);
		if (floor(at) == px) {
			// Up into the light's heart and out again.
			float glow = sin(life * 3.1416);
			float heart = 1.0 - clamp(length(at - vec2(size.x * 0.5, size.y * 0.25)) / (size.x * 0.6), 0.0, 1.0);
			light = max(light, glow * (0.35 + 0.65 * heart));
		}
	}
	COLOR = vec4(lift(vec3(0.0), WARM * light * 0.85), 1.0);
}
