shader_type canvas_item;
// Frost round the ice cave's stair down through Liane's floor (PIX-290,
// EntranceArt): the cold coming up it has frosted the boards, the carpet and
// the stair itself, thick at the stairwell and thinning out over the floor
// in the same 2px Bayer dither as the regions' edges, its rim wandering, so
// it reads as drawn frost, not a smudge or a circle. `stair` is the
// stairwell's middle and `reach` how far the frost creeps from it, both in
// the world's pixels (a tile layer draws in blocks, each its own item, so
// the vertex is read in the world).

#include "res://shaders/linear.gdshaderinc"

uniform vec2 stair;
uniform float reach = 40.0;

varying vec2 world_px;

const vec3 FROST = vec3(0.86, 0.93, 1.0);
const float BAYER[16] = float[16](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0
);

void vertex() {
	world_px = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 base = COLOR;  // already the texel times the modulate
	base.rgb = to_display(base.rgb);
	vec2 block = floor(world_px / 2.0) * 2.0 + 1.0;
	vec2 off = block - stair;
	float angle = atan(off.y, off.x);
	float rim = reach * (0.86 + 0.1 * sin(angle * 5.0 + 0.7) + 0.06 * sin(angle * 11.0 + 2.1));
	// Thick inside a little over half the reach, thinning to nothing at the rim.
	float thick = clamp((rim - length(off)) / (reach * 0.45), 0.0, 1.0);
	ivec2 cell = ivec2(floor(world_px / 2.0)) & ivec2(3);
	float threshold = (BAYER[cell.y * 4 + cell.x] + 0.5) / 16.0;
	if (thick > threshold) {
		float luma = dot(base.rgb, vec3(0.299, 0.587, 0.114));
		base.rgb = mix(base.rgb, FROST * (0.65 + 0.45 * luma), 0.8);
	}
	COLOR = vec4(to_canvas(base.rgb), base.a);
}
