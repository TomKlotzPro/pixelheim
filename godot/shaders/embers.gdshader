shader_type canvas_item;
render_mode unshaded;
// The Ash's cinders (PIX-308, GroundDetail's "cinders" on MapView's ember
// layer): a dark crust round a glowing heart, lit by nothing but itself, so
// at night they glow in the dark ash. Each breathes on its own slow beat,
// and now and then one flares and fades; the crust stays dark.

#include "res://shaders/wind.gdshaderinc"
#include "res://shaders/linear.gdshaderinc"

// How bright a heart burns: at the bottom of its breath, the breath's depth,
// and a flare's; a flare comes in one slot of FLARE_BEAT seconds in so many.
const float LOW = 0.55;
const float BREATH = 0.35;
const float FLARE = 0.6;
const float FLARE_BEAT = 2.4;
const float FLARE_SHARE = 0.3;

varying vec2 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy + plane_origin;
}

void fragment() {
	vec3 rgb = to_display(COLOR.rgb);
	vec2 cell = floor(world_pos / 16.0);
	float h = hash(cell);
	float beat = 0.5 + 0.5 * sin(world_time * (0.8 + 0.7 * h) + h * 6.2832);
	float t = world_time / FLARE_BEAT + h * 5.0;
	float flare = hash(cell + floor(t) * 7.31) < FLARE_SHARE ? sin(3.14159 * fract(t)) : 0.0;
	// The heart: the reds and oranges, never the crust.
	if (rgb.r - rgb.b > 0.25) {
		rgb = min(rgb * (LOW + BREATH * beat + FLARE * flare), vec3(1.0));
	}
	COLOR = vec4(to_canvas(rgb), COLOR.a);
}
