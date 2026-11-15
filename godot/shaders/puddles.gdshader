shader_type canvas_item;
// What the rain leaves on the ground (PIX-491, PuddlesLayer): one sheet
// over a map's ground. While the ground is wet it is darker and cooler
// (`ground_wet.x`); puddles gather in its hollows as they fill
// (`ground_wet.y`): a slow noise on the plane's own pixels says how deep
// each art pixel lies, the sheet's texture (a cell a texel, read softly: red)
// how readily water gathers there, and a puddle is where the two pass the
// level, so it grows from the middle of a hollow as it rains and shrinks
// back as it dries, in whole art pixels. Each has its bank's shadow along
// its far edge and the sky along its near one, as the mire's puddles do
// (open_ground.gdshaderinc), and rings where drops land while it rains
// (`ground_wet.z`). Still water is a mirror: by day the storm's grey sky,
// and in a light (`light()`) the light itself, not the water's dark - the
// lamps, the lantern and the lightning gleam in it, in broken streaks.

#include "res://shaders/wind.gdshaderinc"
#include "res://shaders/linear.gdshaderinc"

// How wet the ground is, how full its puddles and how hard it rains, 0..1
// (the Storm node sets it each frame).
global uniform vec3 ground_wet;

// Where the pixel lies in the plane, so puddles run on across a line.
varying vec2 world_pos;
// How much of a light a pixel mirrors (a puddle's open water), 0..1.
varying float mirror;

// Wet ground: a dark, cool veil, this opaque when soaked.
const vec3 WET = vec3(0.03, 0.05, 0.11);
const float WET_DEPTH = 0.32;
// A puddle: the sky in still water, the bank's shadow, the sky's line.
const vec3 WATER = vec3(0.4, 0.48, 0.58);
const vec3 BANK = vec3(0.09, 0.1, 0.13);
const vec3 SKYLINE = vec3(0.68, 0.76, 0.84);
const float WATER_DEPTH = 0.84;
// A mirror gives a light back whole: this many times what pale ground
// would, so a lamp's gleam in a puddle is the brightest thing on the floor.
const float MIRROR = 1.7;
// The hollows: broad ones and the dips along them, wider than deep (seen
// from above at a slant, as the land is), turned off the grid.
const vec2 HOLLOW = vec2(16.0, 9.0);
const vec2 DIP = vec2(6.0, 4.0);
const mat2 TURN = mat2(vec2(0.8775826, 0.4794255), vec2(-0.4794255, 0.8775826));
// How far down the hollows the water reaches when the puddles are full,
// where it gathers most readily.
const float REACH = 0.25;
// Round a street lamp's foot the ground is trodden hollow: the water
// reaches this much further there, so every lamp has a puddle to shine in.
const float LAMP_HOLLOW = 0.5;
// Rings: one drop a RING_CELL square at a time, RING_BEAT a second, its
// ring opening to RING_WIDE pixels.
const float RING_CELL = 9.0;
const float RING_BEAT = 1.7;
const float RING_WIDE = 3.6;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}

// Whether water lies at an art pixel the water's `level` reaches (how far
// down the hollows, 0..1).
bool puddled(vec2 px, float level) {
	float deep = 0.66 * noise(TURN * (px / HOLLOW)) + 0.34 * noise(px / DIP + 17.3);
	return deep > 1.0 - level;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy + plane_origin;
}

void fragment() {
	vec2 px = floor(world_pos);
	// How readily water gathers here, and how near a street lamp's foot.
	vec2 ground = texture(TEXTURE, UV).rg;
	// They shrink slowly as they dry, then go.
	float level = pow(ground_wet.y, 0.4) * (REACH * ground.r + LAMP_HOLLOW * ground.g);
	mirror = 0.0;
	vec4 over = vec4(to_canvas(WET), veil(WET_DEPTH * ground_wet.x));
	if (level > 0.0 && puddled(px, level)) {
		vec3 c = WATER;
		if (!puddled(px - vec2(0.0, 1.0), level)) {
			c = BANK;
		} else if (!puddled(px + vec2(0.0, 1.0), level)) {
			c = SKYLINE;
		} else {
			// Streaks: every other row mirrors less, shifting slowly.
			mirror = 0.55 + 0.45 * step(0.5, fract(px.y * 0.5 + floor(world_time * 1.3 + hash(px.yy) * 4.0) * 0.5));
			if (ground_wet.z > 0.05) {
				vec2 cell = floor(px / RING_CELL);
				float beat = world_time * RING_BEAT + hash(cell) * 5.0;
				float drop = floor(beat);
				float age = fract(beat);
				vec2 middle = (cell + 0.2 + 0.6 * vec2(hash(cell + drop * 3.1), hash(cell + drop * 7.7))) * RING_CELL;
				vec2 off = (px + 0.5 - middle) * vec2(1.0, 1.6);
				if (abs(length(off) - age * RING_WIDE) < 0.55 && hash(cell + drop * 1.3) < ground_wet.z) {
					c = mix(c, SKYLINE, 1.0 - age);
				}
			}
		}
		over = vec4(to_canvas(c), WATER_DEPTH);
	}
	COLOR = over;
}

void light() {
	vec3 lit = COLOR.rgb;
	if (mirror > 0.0) {
		// Strongest near a lamp (its texture's own falloff); the sky's
		// light is everywhere at once.
		float near = LIGHT_IS_DIRECTIONAL ? 0.3 : smoothstep(0.06, 0.6, LIGHT_COLOR.a);
		lit = mix(lit, vec3(MIRROR), mirror * near);
	}
	LIGHT = vec4(LIGHT_COLOR.rgb * lit * LIGHT_ENERGY, LIGHT_COLOR.a);
}
