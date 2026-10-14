// Open ground (PIX-305), for region_tint.gdshader's ground layer
// (`ground_life`): most of every outdoor screen was one of Shade's grass
// tufts repeated, snow that tuft whitened, the mire a murky tone over it.
// Here the grass lies in slow patches of the Medieval Age's greens, lusher in
// the hollows and drier on the rises, their edges dithered over a pixel or
// two of the art as Shade's sea is between its depths; under snow the same
// patches are drifts and their blue shadows; in the mire, murk and sedge, and
// in the murk puddles of still dark water with a bank of shadow above them
// and the sky caught along their near edge. When the wind gusts
// (wind.gdshaderinc's gust, the one the trees lean in), ripples of light
// roll over the long grass. Only Shade's grass is touched: his dirt, sand,
// rock and water are left to their own.
//
// Included by region_tint.gdshader after its BAYER and CELL.

// Shade's grass base is the Medieval Age's first green (#85a643); its next
// two greens, by channel over his, are the lusher patches. Drier ground
// warms the other way.
const vec3 DRY = vec3(1.06, 1.02, 0.95);
const vec3 LUSH = vec3(0.887, 0.934, 1.03);
const vec3 LUSHER = vec3(0.805, 0.892, 1.06);
// Where the patches' noise (0..1) turns drier, lusher and lusher still.
const float DRY_BELOW = 0.37;
const float LUSH_ABOVE = 0.58;
const float LUSHER_ABOVE = 0.7;
// How many art pixels either side of a patch's edge the dither reaches.
const float PATCH_SEAM = 1.2;
// The patches' sizes in cells: broad swells, and the clumps along them,
// each read turned off the grid (value noise left alone runs its edges
// along the lattice, in straight lines).
const vec2 PATCH_SCALES = vec2(6.0, 2.0);
const vec2 PATCH_WEIGHTS = vec2(0.62, 0.38);
const mat2 SWELLS_TURN = mat2(vec2(0.8775826, 0.4794255), vec2(-0.4794255, 0.8775826));
const mat2 CLUMPS_TURN = mat2(vec2(0.4535961, 0.8912074), vec2(-0.8912074, 0.4535961));
// Snow: the lush patches lie in a drift's blue shadow, the dry ones are
// fresh and bright.
const vec3 DRIFT_SHADOW = vec3(0.92, 0.95, 1.0);
const float FRESH = 0.4;
// The mire: murk in its hollows, brown and dark; its drier ground the
// yellow of sedge.
const vec3 MURK = vec3(0.82, 0.78, 0.66);
const vec3 SEDGE = vec3(1.07, 1.04, 0.9);
// The mire's puddles, in its murk: still water, a bank of shadow above it,
// the sky along its near edge. One may lie in each square of PUDDLE_BLOCK
// pixels whose middle is murk, a ragged oval wider than it is deep (seen
// from above, as the land is), PUDDLE_RADIUS pixels across and within its
// square.
const vec3 PUDDLE = vec3(0.27, 0.38, 0.38);
const vec3 PUDDLE_BANK = vec3(0.16, 0.21, 0.18);
const vec3 PUDDLE_SHADE = vec3(0.21, 0.3, 0.29);
const vec3 PUDDLE_SKY = vec3(0.55, 0.67, 0.64);
const vec3 PUDDLE_GLEAM = vec3(0.68, 0.8, 0.78);
const float PUDDLE_BLOCK = 32.0;
const float PUDDLE_CHANCE = 0.55;
const vec2 PUDDLE_RADIUS = vec2(4.0, 8.0);
const float PUDDLE_SQUASH = 0.65;
// The wind over long grass: ripples RIPPLE_CELLS apart rolling downwind at
// RIPPLE_SPEED cells a second, lighter by SHEEN along their crests, showing
// as a gust passes (from GUST_FROM).
const float SHEEN = 0.07;
const float RIPPLE_CELLS = 5.0;
const float RIPPLE_SPEED = 1.8;
const float RIPPLE_CREST = 0.6;
const float GUST_FROM = 0.15;

// What the tint mask's alpha asks for (PunyTerrain.KIND_*, read halfway
// between them): nothing, the dirt of a cell beside ash only (the fringe),
// the mire, a region's tone.
const int KIND_NONE = 0;
const int KIND_FRINGE = 1;
const int KIND_MIRE = 2;
const int KIND_TONE = 3;

int tone_kind(float a) {
	if (a < 0.19) {
		return KIND_NONE;
	}
	if (a < 0.56) {
		return KIND_FRINGE;
	}
	return a < 0.88 ? KIND_MIRE : KIND_TONE;
}

// The 4x4 Bayer threshold at an art pixel, 0..1.
float art_dither(vec2 px) {
	ivec2 b = ivec2(px) & ivec2(3);
	return (BAYER[b.y * 4 + b.x] + 0.5) / 16.0;
}

// A cheap hash of a lattice point, 0..1 (no sine: it runs a dozen times a
// pixel of the ground).
float ground_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// Smooth value noise over that hash, 0..1.
float ground_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(ground_hash(i), ground_hash(i + vec2(1.0, 0.0)), f.x),
		mix(ground_hash(i + vec2(0.0, 1.0)), ground_hash(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}

// Shade's grass greens (base, tufts, a cliff's grassy top); not the yellow-
// green where his grass meets dirt, nor rock, sand or water.
bool is_grass(vec3 c) {
	return c.g > c.r + 0.06 && c.g > c.b * 1.8 && c.g > 0.45;
}

// Shade's dirt: the road's yellow, its edge's olive, the dirt under a cliff.
bool is_dirt(vec3 c) {
	return c.r > 0.58 && c.r > c.g - 0.05 && c.b < 0.36 && c.r - c.b > 0.3;
}

// The patches' noise at an art pixel (on the plane, so patches run on
// across a line between maps).
float patch_noise(vec2 px) {
	vec2 cells = px / CELL;
	return PATCH_WEIGHTS.x * ground_noise(SWELLS_TURN * (cells / PATCH_SCALES.x))
		+ PATCH_WEIGHTS.y * ground_noise(CLUMPS_TURN * (cells / PATCH_SCALES.y) + 31.7);
}

// The patches' level at an art pixel: -1 drier, 0 as drawn, 1 lush, 2
// lusher. Each edge is read in pixels across it (the noise over its slope),
// so its dither is a pixel or two wide however gently the noise turns.
int patch_level(vec2 px) {
	float n = patch_noise(px);
	float slope = max(length(vec2(patch_noise(px + vec2(1.0, 0.0)), patch_noise(px + vec2(0.0, 1.0))) - n), 0.0005);
	float jitter = (art_dither(px) - 0.5) * 2.0 * PATCH_SEAM * slope;
	n += jitter;
	if (n < DRY_BELOW) {
		return -1;
	}
	if (n > LUSHER_ABOVE) {
		return 2;
	}
	return n > LUSH_ABOVE ? 1 : 0;
}

// The puddle of the square round an art pixel: its middle and radius, or a
// radius of 0 for none (no puddle drawn there, or not in the murk).
vec3 puddle_of(vec2 px) {
	vec2 block = floor(px / PUDDLE_BLOCK);
	if (ground_hash(block + 57.0) > PUDDLE_CHANCE) {
		return vec3(0.0);
	}
	float radius = mix(PUDDLE_RADIUS.x, PUDDLE_RADIUS.y, ground_hash(block + 21.4));
	vec2 room = vec2(PUDDLE_BLOCK) - 2.0 * vec2(PUDDLE_RADIUS.y + 1.0);
	vec2 middle = block * PUDDLE_BLOCK + PUDDLE_RADIUS.y + 1.0 + vec2(ground_hash(block + 3.1), ground_hash(block + 9.7)) * room;
	if (patch_noise(floor(middle)) < LUSH_ABOVE) {
		return vec3(0.0);
	}
	return vec3(middle, radius);
}

// Whether a puddle lies at an art pixel of the mire (in its murk).
bool puddled(vec2 px) {
	vec3 puddle = puddle_of(px);
	if (puddle.z <= 0.0) {
		return false;
	}
	vec2 off = (px + 0.5 - puddle.xy) / vec2(1.0, PUDDLE_SQUASH);
	float ragged = (ground_noise(px / 2.5 + floor(px / PUDDLE_BLOCK) * 7.3) - 0.5) * 2.0;
	return length(off) < puddle.z + ragged;
}

// The patches over the grass before the region tones it: Shade's green
// turned to the Medieval Age's next ones, or warmed drier.
vec3 ground_patches(vec3 c, int level) {
	if (level < 0) {
		return min(c * DRY, vec3(1.0));
	}
	if (level == 1) {
		return c * LUSH;
	}
	return level == 2 ? c * LUSHER : c;
}

// The wind's gust over a spot of the plane, 0..1 (wind.gdshaderinc's).
float gust_at(vec2 plane) {
	float gust = 0.5 + 0.5 * sin(world_time * 0.55 - plane.x * 0.011 - plane.y * 0.004);
	return gust * gust * gust * world_wind;
}

// Whether a ripple's crest lies over an art pixel of long grass now: the
// ripples run with the gusts (from the west, a little north), and their
// crests are dithered thin where the gust is weak.
bool rippled(vec2 px) {
	float gust = gust_at(px);
	if (gust < GUST_FROM) {
		return false;
	}
	float along = (px.x * 0.92 + px.y * 0.38) / (CELL * RIPPLE_CELLS);
	float crest = 0.5 + 0.5 * sin(6.2832 * (along - world_time * RIPPLE_SPEED / RIPPLE_CELLS));
	return crest * gust > RIPPLE_CREST * (0.6 + 0.8 * art_dither(px + 2.0));
}

// After the tone: snow's drifts and shadows, the mire's murk and sedge, and
// the sheen of a gust over the long grass. `snow` and `mire` say which.
vec3 ground_after(vec3 c, vec2 px, int level, bool snow, bool mire) {
	if (snow) {
		if (level >= 1) {
			return c * DRIFT_SHADOW;
		}
		return level < 0 ? mix(c, vec3(1.0), FRESH) : c;
	}
	if (mire) {
		if (level >= 1) {
			return c * mix(vec3(1.0), MURK, level == 2 ? 1.0 : 0.6);
		}
		return level < 0 ? min(c * SEDGE, vec3(1.0)) : c;
	}
	if (level >= 1 && rippled(px)) {
		return min(c * (1.0 + SHEEN) + vec3(0.01, 0.01, 0.0), vec3(1.0));
	}
	return c;
}

// A puddle's pixel: the bank's shadow along its top and the water darker
// under it, the sky along its near edge, a streak of it gleaming across its
// middle, and now and then a glint.
vec3 puddle_color(vec2 px) {
	if (!puddled(px - vec2(0.0, 1.0))) {
		return PUDDLE_BANK;
	}
	if (!puddled(px - vec2(0.0, 2.0))) {
		return PUDDLE_SHADE;
	}
	if (!puddled(px + vec2(0.0, 1.0))) {
		return PUDDLE_SKY;
	}
	vec3 puddle = puddle_of(px);
	vec2 off = px + 0.5 - puddle.xy;
	if (abs(off.y + 0.5) < 0.6 && abs(off.x + 1.0) < puddle.z * 0.45) {
		return PUDDLE_GLEAM;
	}
	float slot = floor(world_time * 0.9 + ground_hash(px) * 7.0);
	if (ground_hash(px + slot * 3.1) > 0.993) {
		return PUDDLE_GLEAM;
	}
	return PUDDLE;
}
