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
// paler than the ground; at night (`ground_wet.w`) the night's, darker
// than the wet ground round it, and in it a flame's own colour (`light()`)
// in a few broken dashes close under the lamp or the lantern, never the
// whole puddle gone pale. Lightning only glints on it. Nothing is wet
// where no rain falls (the texture's blue: not the Ash, the snow, open
// water or a roof).

#include "res://shaders/wind.gdshaderinc"
#include "res://shaders/linear.gdshaderinc"

// How wet the ground is, how full its puddles, how hard it rains and how
// dark the hour is, 0..1 (the Storm node sets it each frame).
global uniform vec4 ground_wet;

// Where the pixel lies in the plane, so puddles run on across a line.
varying vec2 world_pos;
// Whether a pixel mirrors a light (a puddle's open water), 0 or 1.
varying float mirror;

// Wet ground: a dark, cool veil, this opaque when soaked.
const vec3 WET = vec3(0.03, 0.05, 0.11);
const float WET_DEPTH = 0.32;
// A puddle: the sky in still water, the bank's shadow, the sky's line.
const vec3 WATER = vec3(0.4, 0.48, 0.58);
const vec3 BANK = vec3(0.09, 0.1, 0.13);
const vec3 SKYLINE = vec3(0.68, 0.76, 0.84);
const float WATER_DEPTH = 0.84;
// At night the sky in the water is dark: the water and its sky's line
// keep this share of their day's colour, so a puddle is a darker patch
// than the wet ground round it, for a flame to show in.
const float NIGHT_WATER = 0.3;
const float NIGHT_SKYLINE = 0.42;
// A flame mirrored: its own colour, deepened (to the power 2.5: a lamp's pale
// amber comes back as amber through the storm's grey), this bright at most (never white), at full
// strength from a light of 1 / MIRROR energy up, only this near it (its
// texture's own falloff), and only in a streak straight under it: whole
// for its first STREAK_WHOLE of the way (the flame itself, upside down),
// then short dashes on every other row, STREAK.x art pixels to each side
// and up to STREAK.y more by the row's own throw, fading and breaking up
// (rows missing) over STREAK_LONG pixels down: a gleam, not a ladder.
const float GLEAM = 0.95;
const float MIRROR = 2.2;
const vec2 GLEAM_NEAR = vec2(0.27, 0.45);
const float STREAK_WHOLE = 0.3;
const vec2 STREAK = vec2(1.5, 2.0);
const float STREAK_LONG = 26.0;
// The sky's light (the lightning's fill) is everywhere at once: at night
// a cold sheen over the water, brighter on its dashes, well under white.
const float SKY_SHEEN = 0.2;
const float SKY_GLINT = 0.6;
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
	// How readily water gathers here, how near a street lamp's foot, and
	// whether rain falls here at all.
	vec3 ground = texture(TEXTURE, UV).rgb;
	// They shrink slowly as they dry, then go.
	float level = pow(ground_wet.y, 0.4) * (REACH * ground.r + LAMP_HOLLOW * ground.g);
	mirror = 0.0;
	vec4 over = vec4(to_canvas(WET), veil(WET_DEPTH * ground_wet.x * ground.b));
	if (level > 0.0 && puddled(px, level)) {
		vec3 skyline = SKYLINE * mix(1.0, NIGHT_SKYLINE, ground_wet.w);
		vec3 c = WATER * mix(1.0, NIGHT_WATER, ground_wet.w);
		if (!puddled(px - vec2(0.0, 1.0), level)) {
			c = BANK;
		} else if (!puddled(px + vec2(0.0, 1.0), level)) {
			c = skyline;
		} else {
			mirror = 1.0;
			if (ground_wet.z > 0.05) {
				vec2 cell = floor(px / RING_CELL);
				float beat = world_time * RING_BEAT + hash(cell) * 5.0;
				float drop = floor(beat);
				float age = fract(beat);
				vec2 middle = (cell + 0.2 + 0.6 * vec2(hash(cell + drop * 3.1), hash(cell + drop * 7.7))) * RING_CELL;
				vec2 off = (px + 0.5 - middle) * vec2(1.0, 1.6);
				if (abs(length(off) - age * RING_WIDE) < 0.55 && hash(cell + drop * 1.3) < ground_wet.z) {
					c = mix(c, skyline, 1.0 - age);
				}
			}
		}
		over = vec4(to_canvas(c), WATER_DEPTH);
	}
	COLOR = over;
}

void light() {
	bool sky = LIGHT_IS_DIRECTIONAL;
	vec3 got = LIGHT_COLOR.rgb * COLOR.rgb * LIGHT_ENERGY;
	// Every other row of art pixels, each on its own slow beat.
	vec2 px = floor(world_pos);
	// Out here, not in the branch below: derivatives need every pixel alike.
	float per_px = abs(dFdx(world_pos.x));
	float row = step(0.5, fract(px.y * 0.5));
	float shift = floor(world_time * 1.3 + hash(px.yy) * 4.0);
	if (mirror > 0.0) {
		float share;
		if (sky) {
			// Broken dashes all over the water.
			float dash = row * step(0.6, hash(vec2(floor((px.x + shift) / 3.0), px.y)));
			share = mix(SKY_SHEEN, SKY_GLINT, dash) * ground_wet.w;
		} else {
			// Where the art pixel lies from the light, in art pixels: the
			// streak hangs straight down the screen from it. The bolt's
			// flat light is no flame to mirror (its texture's alpha is
			// under GLEAM_NEAR, storm.gd): the sky's glint is the flash's.
			vec2 from = (LIGHT_VERTEX.xy - LIGHT_POSITION.xy) * per_px + px + 0.5 - world_pos;
			float far = clamp(from.y / STREAK_LONG, 0.0, 1.0);
			float wide = STREAK.x + STREAK.y * hash(vec2(px.y, shift));
			float off = from.x + 2.0 * (hash(vec2(shift, px.y)) - 0.5);
			float kept = step(far * 0.8, hash(vec2(px.y + 3.7, shift)));
			share = max(row * kept, step(far, STREAK_WHOLE)) * (1.0 - far * far) * step(-1.0, from.y) * step(abs(off), wide) * smoothstep(GLEAM_NEAR.x, GLEAM_NEAR.y, LIGHT_COLOR.a);
		}
		// The light's own colour, however strong it is.
		vec3 own = LIGHT_COLOR.rgb / max(max(LIGHT_COLOR.r, max(LIGHT_COLOR.g, LIGHT_COLOR.b)), 0.001);
		got += pow(own, vec3(2.5)) * to_canvas(vec3(GLEAM)).r * min(LIGHT_ENERGY * MIRROR, 1.0) * share;
	}
	// A directional light's alpha is its energy again, not a falloff.
	LIGHT = vec4(got, sky ? 1.0 : LIGHT_COLOR.a);
	// A shadow takes a share of the light, as on every floor (PIX-528,
	// relief.gdshaderinc).
	SHADOW_MODULATE.rgb = COLOR.rgb * max(LIGHT_ENERGY, 1.0);
}
