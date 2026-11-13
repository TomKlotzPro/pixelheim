// Where an inland water's bank lies (PIX-306, PIX-467): how far inside the
// drawn bank a pixel is, worked out from the water mask
// (PunyTerrain.water_map) and the slow noise that bends the bank off the
// grid. Shared by the two shaders that must agree on it to the pixel:
// region_tint.gdshader draws the water and its bank there
// (inland_water.gdshaderinc), and reflections.gdshader mirrors only on what
// was drawn as water (the bank lies up to 15 pixels inside its water's
// cells in the mire, and by the cells alone the hero's reflection showed
// on the dry marsh above it).
//
// Included after CELL and the uniforms water_map (read smoothly:
// filter_linear) and map_pixels (the mask's size in pixels). The noise is
// region_tint's own, kept here so both shaders bend a bank alike.

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Smooth value noise, 0..1: the slow bends of a region's edge and a bank.
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

// The tones (PunyTerrain.WATER_*): clear, the mire's, the Deepwood's, the
// cold's; and what a code's bits hold (TONE_BIT, SPAN_BIT, FLOWS).
const int TONE_CLEAR = 1;
const int TONE_MIRE = 2;
const int TONE_DEEP = 3;
const int TONE_ICE = 4;

// How far the bank bends off its cells, in pixels either way, and how many
// cells lie between its bends; how far inside its water's cells it lies at
// the least, its rim (it lies there and further in by its wander, never
// out over the land: PIX-467, below).
const float BANK_WANDER = 5.0;
const float BANK_BENDS = 1.5;
// The quicker bends on the slow ones: this many to one of them, and their
// share of the bend.
const float BANK_RIPPLE = 2.6;
const float BANK_RIPPLES = 0.25;
// The Mirefen's pools were laid two cells a step and their banks stepped
// with them (PIX-401): there the mask is read softened this many pixels
// each way, and the bank bends further and wider.
const float MIRE_SOFT = 9.0;
const float MIRE_WANDER = 7.0;
const float MIRE_BENDS = 2.2;
// The hole in the Frostgate's ice is a cell thin: its banks bend this
// little, so they never meet and the hole still isn't a ruled slot.
const float ICE_WANDER = 2.0;
const float BANK_IN = 1.0;
// How far out from its bank the water is still drawn by how near the bank
// is (its shallows, the foam's lap, the mire's reeds).
const float BANK_SHOAL = 7.0;
// Where a bridge lands the bank lies this far in under its planks, and the
// bank beside comes round to meet it over LANDING_EASE cells (it stood out of
// the bank's wander as a square tongue of land before): a cell, no more, or
// a bank drawn inside its cells runs ruler-straight from the bridge
// (PIX-467), and landing_ease looks no further than the cells beside.
const float LANDING_IN = -3.0;
const float LANDING_EASE = 1.0;
// The Reach's river meanders off its cells (PIX-397: seen whole it was a
// ruler-straight band): its banks pulled in over its water, the north bank
// as the south lets go and back, by up to `river_swing` pixels
// (PunyTerrain.RIVER_SWING, 0 elsewhere) on bends SWING_BENDS cells long,
// each turning on a smoothstep so the bank swings rather than humps; never
// out over the land, nor more than SWING_CAP pixels into a water cell, so
// the hero never stops short of the water by more. Each bank's distance is
// counted down the column's water cells, up to SWING_CELLS of them (the
// mask's red lies whole a cell in, too near to swing a bank further). It
// eases to nothing over SWING_STILL cells by a bridge.
uniform float river_swing = 0.0;
const float SWING_BENDS = 10.0;
const float SWING_CAP = 11.0;
const float SWING_STILL = 3.0;
const int SWING_CELLS = 6;

vec4 mask_texel(ivec2 cell) {
	ivec2 size = textureSize(water_map, 0);
	return texelFetch(water_map, clamp(cell, ivec2(0), size - 1), 0);
}

// The mask's code at cell `cell` (the mask's own texels).
int water_code_at(ivec2 cell) {
	ivec2 size = textureSize(water_map, 0);
	if (cell.x < 0 || cell.y < 0 || cell.x >= size.x || cell.y >= size.y) {
		return 0;
	}
	return int(round(texelFetch(water_map, cell, 0).a * 255.0));
}

// The code of the water at `cell` or, on the land by a bank, of the water
// beside it (the bank bends out over the land's cell).
int water_code_near(ivec2 cell) {
	if (mask_texel(cell).r > 0.5) {
		return water_code_at(cell);
	}
	for (int side = 0; side < 4; side++) {
		ivec2 next = cell + (side == 0 ? ivec2(-1, 0) : (side == 1 ? ivec2(1, 0) : (side == 2 ? ivec2(0, -1) : ivec2(0, 1))));
		if (mask_texel(next).r > 0.5) {
			return water_code_at(next);
		}
	}
	return water_code_at(cell) / 16 * 16;
}

bool span_at(ivec2 cell) {
	return (water_code_at(cell) / 8) % 2 == 1;
}

// How far the river's swing reaches at `local_px` (mask pixels, in `cell`):
// all of it SWING_STILL cells from a bridge, easing to nothing at its side.
// The Reach's river runs across the map, its bridge across it.
float swing_ease(vec2 local_px, ivec2 cell) {
	float nearest = SWING_STILL * CELL;
	for (int dy = -1; dy <= 1; dy++) {
		for (int dx = -int(SWING_STILL); dx <= int(SWING_STILL); dx++) {
			if (span_at(cell + ivec2(dx, dy))) {
				float left = float(cell.x + dx) * CELL;
				nearest = min(nearest, max(max(left - local_px.x, local_px.x - left - CELL), 0.0));
			}
		}
	}
	return smoothstep(0.0, SWING_STILL * CELL, nearest);
}

// How much of the bank's own wander and lie the bank keeps at `local_px`
// (mask pixels, in `cell`): none on a bridge's cells, all of it LANDING_EASE
// cells from them, so it meets the bank where the bridge lands.
float landing_ease(vec2 local_px, ivec2 cell) {
	float nearest = LANDING_EASE * CELL;
	for (int dy = -1; dy <= 1; dy++) {
		for (int dx = -1; dx <= 1; dx++) {
			ivec2 span = cell + ivec2(dx, dy);
			if (span_at(span)) {
				vec2 low = vec2(span) * CELL;
				nearest = min(nearest, length(max(max(low - local_px, local_px - low - CELL), vec2(0.0))));
			}
		}
	}
	return smoothstep(0.0, LANDING_EASE * CELL, nearest);
}

// A meandering river's `in_water` at `at` (mask pixels, the bank's wander
// in it; `plain` without it): no further in than either bank, each swung in
// over the water by turns (river_swing, eased by `ease` near a bridge), and
// never past SWING_CAP into the water's cells. `ground` becomes the ground
// of the nearer bank's land, for what's drawn back over the water.
float river_swung(vec2 at, vec2 plain, float in_water, float ease, inout int ground) {
	ivec2 cell = ivec2(floor(at / CELL));
	// On the land by a bank, the water's column is the one beside it.
	if (mask_texel(cell).r < 0.5) {
		if (mask_texel(cell + ivec2(0, 1)).r > 0.5) {
			cell.y += 1;
		} else if (mask_texel(cell - ivec2(0, 1)).r > 0.5) {
			cell.y -= 1;
		} else {
			return in_water;
		}
	}
	ivec2 north = cell - ivec2(0, 1);
	for (int i = 0; i < SWING_CELLS; i++) {
		if (mask_texel(north).r < 0.5) {
			break;
		}
		north.y -= 1;
	}
	ivec2 south = cell + ivec2(0, 1);
	for (int i = 0; i < SWING_CELLS; i++) {
		if (mask_texel(south).r < 0.5) {
			break;
		}
		south.y += 1;
	}
	float bends = CELL * SWING_BENDS;
	float turn = sin(at.x / bends * PI + value_noise(vec2(at.x / (bends * 2.0), 61.3)) * 2.5);
	float from_north = at.y - float(north.y + 1) * CELL - river_swing * ease * smoothstep(-0.4, 1.0, turn);
	float from_south = float(south.y) * CELL - at.y - river_swing * ease * smoothstep(-0.4, 1.0, -turn);
	ground = int(round(mask_texel(from_north < from_south ? north : south).a * 255.0)) % 16;
	float deep = min(plain.y - float(north.y + 1) * CELL, float(south.y) * CELL - plain.y);
	// The bank's own lie is in `in_water`.
	return min(in_water, max(min(from_north, from_south) - BANK_IN, deep - SWING_CAP));
}

// Which way the water in a cell of code `code` runs: (0, 0) still, west
// along a river across the map, south down one (PunyTerrain.FLOWS).
vec2 flow_of(int code) {
	int flow = code % 8;
	return flow == 1 ? vec2(-1.0, 0.0) : (flow == 2 ? vec2(0.0, 1.0) : vec2(0.0));
}

// How far the bank bends off its cells, by its water's tone, and how far
// inside them it lies where it doesn't bend (PIX-467): by its rim and all
// its wander, so no bend brings it out over the land. What stops the hero
// is the water's cells: a bank lying 3 pixels out, as it did, and wandering
// 5 more put up to 8 pixels of water under their feet (and twice that in
// the mire).
float bank_wander(int tone) {
	return tone == TONE_MIRE ? MIRE_WANDER : (tone == TONE_ICE ? ICE_WANDER : BANK_WANDER);
}

float bank_lie(int tone) {
	return BANK_IN + bank_wander(tone);
}

// How far into the water `texel` of the mask lies, in cells from the middle
// of the land's cell beside it: its red, a half on the bank and whole a
// half-cell in, and from there its blue (the cells to the bank, the same
// where the red is rising), so a bank can lie more than that half-cell in.
// Between two banks two cells apart no cell is deeper than its bank, and
// this stops at 1 right across: inland water is three cells thick at the
// least (test_inland_water).
float water_in(vec4 texel) {
	return max(texel.r, texel.b * 3.0);
}

// That at `at` (mask pixels), read smoothly between its cells; softened
// over `soft` pixels each way (the mire's, PIX-401), so a bank laid two
// cells a step rounds its corners and runs on between them.
float water_red(vec2 at, float soft) {
	if (soft <= 0.0) {
		return water_in(texture(water_map, at / map_pixels));
	}
	return 0.25 * (water_in(texture(water_map, (at + vec2(-soft, -soft)) / map_pixels))
		+ water_in(texture(water_map, (at + vec2(soft, -soft)) / map_pixels))
		+ water_in(texture(water_map, (at + vec2(-soft, soft)) / map_pixels))
		+ water_in(texture(water_map, (at + vec2(soft, soft)) / map_pixels)));
}


// How many pixels inside its drawn bank the pixel `px` (plane pixels, a
// pixel's middle; `local_px` the same in the mask's pixels) lies: 0 and up
// on the water, below on the bank and the land. `code` becomes the code of
// the water there or beside it (tone 0: no inland water near, and nothing
// else is worked out), `bend` how far the bank's wander moves the mask's
// read there, `bank_ground` the ground of a swung river's nearer bank.
float bank_in_water(vec2 px, vec2 local_px, out int code, out vec2 bend, out int bank_ground) {
	code = 0;
	bend = vec2(0.0);
	bank_ground = 0;
	vec4 plain = texture(water_map, local_px / map_pixels);
	if (plain.a <= 0.0) {
		return -1.0;
	}
	ivec2 cell = ivec2(floor(local_px / CELL));
	code = water_code_near(cell);
	int tone = code / 16;
	if (tone == 0) {
		return -1.0;
	}
	// The bank, bent off the grid; but where a bridge lands, straight and
	// in under its planks' ends.
	bool landing = (code / 8) % 2 == 1 && mask_texel(cell).r < 0.5;
	bool mire = tone == TONE_MIRE;
	// Only a river running west meanders (the Reach's, across the map): the
	// village far off's stream, in the same mask, runs south, and swing_ease
	// looks for its bridge to the side.
	bool swings = river_swing > 0.0 && flow_of(code).x < 0.0;
	vec2 cells = floor(px) / CELL / (mire ? MIRE_BENDS : BANK_BENDS);
	// Each bend turns on a smoothstep of the noise, reaching its wander only
	// at the noise's own ends: clamped at 1.7 times it, a bank held its
	// limit for cells at a time and ran ruler-straight along them (PIX-467).
	// A quicker, smaller bend rides on the slow one, so a bank still moves
	// where the slow one stays near its limit for a few cells (the Deepwood
	// lake's north-east arm).
	vec2 slow = vec2(value_noise(cells + 31.7), value_noise(cells + 47.1));
	vec2 quick = vec2(value_noise(cells * BANK_RIPPLE + 12.9), value_noise(cells * BANK_RIPPLE + 83.3));
	bend = (smoothstep(0.0, 1.0, mix(slow, quick, BANK_RIPPLES)) - 0.5) * 2.0 * bank_wander(tone);
	// Out in the water, past where a bank can lie and its shallows reach
	// (BANK_SHOAL), no bank is near to ease. Not by the mask's red, whole
	// from half a cell in: a bank lies further in than that now, and by a
	// bridge it broke there into a spit of land with water behind it.
	float ease = landing ? 0.0 : ((water_in(plain) - 0.5) * CELL < bank_lie(tone) + bank_wander(tone) + BANK_SHOAL ? landing_ease(local_px, cell) : 1.0);
	bend *= ease;
	float here = water_red(local_px + bend, mire && !landing ? MIRE_SOFT : 0.0);
	float in_water = (here - 0.5) * CELL + mix(LANDING_IN, -bank_lie(tone), ease);
	if (swings && !landing) {
		in_water = river_swung(local_px + bend, local_px, in_water, swing_ease(local_px, cell), bank_ground);
	}
	// Never water on a land cell, whatever the bends above make of a corner
	// (PIX-467): there the bank's rim at the most, on the pixel by the water.
	if (mask_texel(cell).r < 0.5) {
		in_water = min(in_water, min((plain.r - 0.5) * CELL, 0.0) - BANK_IN - 0.01);
	}
	return in_water;
}
