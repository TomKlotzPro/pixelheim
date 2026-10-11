shader_type canvas_item;
// Frost round the ice cave's stair down through Liane's floor (PIX-290,
// EntranceArt; PIX-317: under her lamplit room's warm light it read as a
// pink-and-red dithered square). The cold coming up the stair has rimed the
// boards and the carpet round it, all in whole pixels of the art and in
// three blues: solid rime at the stair, clumping and breaking up as it goes,
// then crystals - small crosses and stars - scattered past it, its rim
// wandering with the noise and reaching out along its feathers, so it never
// follows the carpet's square. The rime keeps the grain of what it lies on
// in its deep blue, is lit from the top left, and the floor round it is
// chilled, so no warm colour shows through. The stair itself goes cold: its
// steps pale, the dark down it a deep blue. Now and then a glint catches and
// goes out. `stair` is the stairwell's middle and `reach` how far the frost
// creeps from it, in the world's pixels (a tile layer draws in blocks, each
// its own item, so the vertex is read in the world); the tones are
// EntranceArt.FROST_TONES, in the screen's colours.
//
// Lit, the frost gives the room's warm light back white (light()): a candle
// or the sun through the window brightens it without warming it, while the
// stair's own cold light stays blue on it.

#include "res://shaders/linear.gdshaderinc"

global uniform float world_time;
uniform vec2 stair;
uniform float reach = 48.0;
// Where its rim wanders, shares of the reach (EntranceArt.FROST_RIM).
uniform vec2 rim_range = vec2(0.5, 1.1);
// Half the stair's cell, in pixels: what lies within is the stair.
uniform float stair_half = 8.0;
uniform vec3 rime = vec3(0.74, 0.86, 1.0);
uniform vec3 rime_deep = vec3(0.5, 0.64, 0.88);
uniform vec3 snow = vec3(0.9, 0.96, 1.0);
uniform vec3 steps = vec3(0.6, 0.72, 0.9);
uniform vec3 depths = vec3(0.06, 0.08, 0.2);
// How sharply light() tells a warm light from a cold one
// (EntranceArt.WARM_SHARPNESS).
uniform float warm_sharpness = 8.0;

varying vec2 world_px;
// How much of the frost's own colour this pixel shows, for light().
varying float frosted;

// The cold air over the floor round the frost: its own shade, bluer.
const vec3 CHILL = vec3(0.86, 0.94, 1.08);
// How many feathers round the stair: the noise's cells across the rays.
const float FEATHERS = 44.0;
// Crystals seeded one in a cell of this many pixels.
const float SEED_CELL = 5.0;
// Glints: one may catch in a patch of this many pixels, now and then.
const float GLINT_PATCH = 9.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

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

float luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

// The frost's feathering: noise fine across the rays out of the stair (in
// FEATHERS cells round it, wrapping, so it has no seam) and slow along them,
// so its tongues and the grain of its rime run outward, as frost grows.
float feather(vec2 px) {
	vec2 off = px - stair;
	vec2 p = vec2((atan(off.y, off.x) / TAU + 0.5) * FEATHERS, length(off) / 9.0 + 5.3);
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float x0 = mod(i.x, FEATHERS);
	float x1 = mod(i.x + 1.0, FEATHERS);
	float a = hash(vec2(x0, i.y));
	float b = hash(vec2(x1, i.y));
	float c = hash(vec2(x0, i.y + 1.0));
	float d = hash(vec2(x1, i.y + 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// How thick the frost lies on the pixel at `px`: 1 at the stair, 0 past its
// rim, which wanders between `rim_range` of its reach with the noise and
// reaches out along its feathers (tongues and bays, no circle, no square).
float thickness(vec2 px) {
	float wander = 0.5 * value_noise(px / 10.0 + 3.1) + 0.2 * value_noise(px / 4.0 + 8.7) + 0.3 * feather(px);
	float rim = reach * mix(rim_range.x, rim_range.y, wander);
	return clamp((rim - length(px - stair)) / (reach * 0.6), 0.0, 1.0);
}

// Whether rime covers the pixel: all of it where the frost is thick, in
// clumps and specks where it thins.
bool rimed(vec2 px) {
	float t = thickness(px);
	float clump = value_noise(px / 3.0 + 1.7);
	return t + 0.6 * (clump - 0.5) + 0.22 * (hash(px) - 0.5) > 0.6;
}

// A crystal on the pixel, past the rime: 0 none, 1 an arm, 2 its heart.
// One may grow in each SEED_CELL, likelier the thicker the frost there: a
// speck, a cross, or a star of four diagonal points.
float crystal(vec2 px) {
	vec2 cell = floor(px / SEED_CELL);
	vec2 seed = cell * SEED_CELL + floor(vec2(hash(cell + 4.3), hash(cell + 9.1)) * (SEED_CELL - 2.0)) + 1.5;
	float t = thickness(seed);
	if (t <= 0.0 || hash(cell + 2.9) > 0.1 + 1.3 * t) {
		return 0.0;
	}
	vec2 at = abs(px - seed);
	if (at.x + at.y < 0.5) {
		return 2.0;
	}
	float shape = hash(cell + 6.6);
	if (shape < 0.35) {
		return 0.0;
	}
	if (shape < 0.75 ? (at.x + at.y < 1.5) : (abs(at.x - 1.0) < 0.5 && abs(at.y - 1.0) < 0.5)) {
		return 1.0;
	}
	return 0.0;
}

void vertex() {
	world_px = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	frosted = 0.0;
	vec2 px = floor(world_px) + 0.5;
	vec2 off = px - stair;
	float outer = reach * rim_range.y + 2.0;
	if (dot(off, off) < outer * outer) {
		vec4 base = COLOR;  // already the texel times the modulate
		base.rgb = to_display(base.rgb);
		float shade = luma(base.rgb);
		vec3 shown = base.rgb;
		if (max(abs(off.x), abs(off.y)) < stair_half) {
			// The stair gone cold: its steps rimed pale, the dark down it
			// deep blue, so it still reads as a way down.
			shown = mix(depths, steps, smoothstep(0.06, 0.5, shade));
			frosted = 1.0;
		} else {
			float t = thickness(px);
			float chill = smoothstep(0.0, 0.6, t) * 0.55;
			shown = mix(base.rgb, vec3(shade) * CHILL, chill);
			frosted = chill;
			if (rimed(px)) {
				// The rime in its three blues, whole pixels of them: the
				// grain under it (the boards' seams) in the deep one, its
				// body pale, snow where it lies thick and along its
				// feathers, speckled; lit from the top left, an edge with
				// bare floor below it on the right lies in shadow, one with
				// bare floor above it on the left catches the light.
				float level = 0.35 + 0.5 * smoothstep(0.12, 0.5, shade) + 0.45 * t + 0.5 * (feather(px) - 0.5) + 0.35 * (hash(px + 0.37) - 0.5);
				vec3 tone = level < 0.55 ? rime_deep : (level < 1.2 ? rime : snow);
				if (!rimed(px + vec2(1.0, 1.0))) {
					tone = rime_deep;
				} else if (!rimed(px - vec2(1.0, 1.0))) {
					tone = snow;
				}
				shown = tone;
				frosted = 1.0;
			} else {
				float c = crystal(px);
				if (c > 0.0) {
					shown = c > 1.5 ? snow : rime;
					frosted = 1.0;
				}
			}
			// A glint: a small cross of light catches on the rime and goes out.
			vec2 patch = floor(px / GLINT_PATCH);
			vec2 heart = patch * GLINT_PATCH + floor(GLINT_PATCH * 0.5) + 0.5;
			float beat = floor(world_time * 0.6 + hash(patch) * 13.0);
			if (frosted > 0.99 && hash(patch + beat * 7.31) > 0.94 && rimed(heart)) {
				vec2 at = abs(px - heart);
				if ((at.x < 0.5 || at.y < 0.5) && at.x + at.y < 2.5) {
					shown = mix(shown, vec3(1.0), at.x + at.y < 0.5 ? 0.95 : 0.55);
				}
			}
		}
		COLOR = vec4(to_canvas(shown), base.a);
	}
}

// A light on the floor: as Godot lights it, but on the frost a warm light
// comes back white (as bright, not as warm), while a cold one stays itself.
void light() {
	vec3 lit = LIGHT_COLOR.rgb * LIGHT_ENERGY;
	float grey = luma(lit);
	float warm = clamp((grey - lit.b) / max(grey, 0.001) * warm_sharpness, 0.0, 1.0);
	lit = mix(lit, vec3(grey), frosted * warm);
	LIGHT = vec4(COLOR.rgb * lit, LIGHT_COLOR.a);
}
