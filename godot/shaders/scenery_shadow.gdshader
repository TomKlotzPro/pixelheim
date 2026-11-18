shader_type canvas_item;
render_mode unshaded;
// The scenery's shadows (PIX-449), each drawn as coverage alone (white,
// opaque or clear) into its map's group of shadows (ShadowsLayer's
// CanvasGroup), where shadows that meet are one: scenery_shade.gdshader
// darkens the ground under all of them once, in the group's colour.
// A shadow is four vertices on the middle of its footprint, their UVs
// carrying its size and its caster's height (ShadowsLayer._quad): the
// vertex shader spreads them over the footprint and the footprint carried
// along the sun's cast (global `sun`, LightRig, DayNight.sun), and the
// fragment shader asks of each art pixel, at its middle, whether the
// footprint passes over it on its way, so the edges are whole art pixels
// at any zoom. A blob (`walls` off: a tree, a bush, a lamp's foot) is an
// oval, crisp at the foot and softer as it reaches away, its rim soft;
// a wall (a house) is its footprint, its edge half a shade for a pixel.
// It writes coverage, not a colour, so it reads the same on the browser's
// canvas and the app's linear one.

#include "res://shaders/linear.gdshaderinc"

global uniform vec4 sun;
uniform bool walls = false;

// A footprint's depth and its caster's height share the UV's y (PACK in
// ShadowsLayer).
const float PACK = 1024.0;
// The oval's soft rim, a share of its radius: at the foot, and at the far
// end of its cast.
const float RIM_NEAR = 0.25;
const float RIM_FAR = 0.6;

// The footprint's middle in the canvas, its half size and where the sun
// carries it, the same over the whole shadow; and where the pixel lies.
varying flat vec2 middle;
varying flat vec2 half_size;
varying flat vec2 cast;
varying vec2 canvas_px;

void vertex() {
	vec2 corner = sign(UV);
	float packed = abs(UV.y) - 1.0;
	float tall = floor(packed / PACK);
	half_size = vec2(abs(UV.x) - 1.0, packed - tall * PACK) * 0.5;
	cast = sun.xy * tall;
	middle = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	// Over the footprint where it stands and where the sun carries it, and
	// a pixel round: an art pixel on the edge is drawn whole.
	vec2 low = min(vec2(0.0), cast) - half_size - 1.0;
	vec2 high = max(vec2(0.0), cast) + half_size + 1.0;
	VERTEX += mix(low, high, corner * 0.5 + 0.5);
	canvas_px = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

// Narrows [low, high], the part of the way along `c` the footprint (from
// -h to h on this axis) covers `p`.
void slab(float p, float h, float c, inout float low, inout float high) {
	if (abs(c) < 0.001) {
		if (abs(p) > h) {
			low = 2.0;
		}
		return;
	}
	float a = (p - h) / c;
	float b = (p + h) / c;
	low = max(low, min(a, b));
	high = min(high, max(a, b));
}

// Whether a box `h` either side of its middle, carried along `c`, passes
// over `p` (from its middle where it stands).
bool swept(vec2 p, vec2 h, vec2 c) {
	float low = 0.0;
	float high = 1.0;
	slab(p.x, h.x, c.x, low, high);
	slab(p.y, h.y, c.y, low, high);
	return low <= high;
}

void fragment() {
	vec2 pixel = floor(canvas_px);
	vec2 p = pixel + 0.5 - middle;
	// Coverage, soft at the rim (Tom, 2026-11-18: a dithered rim read as a
	// checkerboard on long shadows); scenery_shade darkens by it.
	float cover;
	if (walls) {
		cover = swept(p, half_size - 1.0, cast) ? 1.0 : (swept(p, half_size, cast) ? 0.5 : 0.0);
	} else {
		// The oval nearest `p` on its way, and how far `p` lies from its
		// middle there, in its radii.
		vec2 r = max(half_size, vec2(0.5));
		vec2 q = p / r;
		vec2 v = cast / r;
		float t = clamp(dot(q, v) / max(dot(v, v), 0.0001), 0.0, 1.0);
		float d = length(q - t * v);
		float rim = mix(RIM_NEAR, RIM_FAR, t);
		cover = 1.0 - smoothstep(1.0 - rim, 1.0, d);
	}
	COLOR = vec4(1.0, 1.0, 1.0, cover);
}
