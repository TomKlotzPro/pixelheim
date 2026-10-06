shader_type canvas_item;
// Tones whole regions of the Puny ground from a per-cell mask (PunyTerrain
// .tint_map, hue premultiplied by coverage). Where regions meet, coverage
// fades over a cell and an ordered Bayer pattern in 2px blocks decides which
// pixels take the tone: the retro dither, never a smudge. Water keeps its own
// colours, so the mire and the ash stop at the shore.

uniform sampler2D tint_map : filter_linear, repeat_disable;
uniform vec2 map_pixels;
uniform float strength = 0.85;

varying vec2 world_pos;

const float BAYER[16] = float[16](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0
);

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
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
	COLOR = base;
}
