shader_type canvas_item;
render_mode blend_mul, unshaded;
// The ground darker under a forest's canopy (PIX-309: the Deepwood's trees
// stood on the same bright lawn as its glades). Drawn over the ground as one
// sprite of the forest's mask (Woods.shade_rows: a cell a texel, scaled to
// the cells and filtered between them), so the shade runs soft from cell to
// cell; a slow noise bends its edge off the grid and it is laid in two
// steps, dithered in whole art pixels the way the sea's depths are: under
// the trees, and deeper where the forest is thickest. It multiplies what lies
// under it by a shade picked in the screen's colours, so the ground darkens
// alike on the browser's canvas and the app's linear one (an alpha blend
// toward black there lost most of its darkening).
// Unshaded (PIX-330): the ground under it is lit and darkened by the night
// already, so the night's dark (the CanvasModulate) and the lights stay off
// the shade itself. Shaded, it took the dark a second time over the whole
// map, and at a line between two maps the strip of ground one map draws
// past its sprite's edge stood out across the screen, lighter.

#include "res://shaders/linear.gdshaderinc"

// What each step multiplies the ground by, a little greener than grey.
const vec3 UNDER = vec3(0.8, 0.85, 0.8);
const vec3 DEEP = vec3(0.68, 0.75, 0.69);
// How much of the forest a pixel must have round it for each step (the
// mask reads 1 inside, a half on its edge), and how far the noise bends it.
const float UNDER_AT = 0.42;
const float DEEP_AT = 0.86;
const float BEND = 0.32;
// The noise's scale, in art pixels.
const float BENDS = 21.0;

const float BAYER[16] = float[16](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0
);

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	// The forest's share round this pixel, filtered between cells.
	float cover = texture(TEXTURE, UV).r;
	vec2 px = floor(world_pos);
	cover += (value_noise(px / BENDS) - 0.5) * 2.0 * BEND;
	ivec2 block = ivec2(px) & ivec2(3);
	float dither = (BAYER[block.y * 4 + block.x] + 0.5) / 16.0 - 0.5;
	vec3 shade = vec3(1.0);
	if (cover > UNDER_AT + dither * 0.24) {
		shade = UNDER;
	}
	if (cover > DEEP_AT + dither * 0.2) {
		shade = DEEP;
	}
	COLOR = vec4(to_canvas(shade), 1.0);
}
