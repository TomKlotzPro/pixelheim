shader_type canvas_item;
// Tones whole regions of the Puny ground from a per-cell mask (PunyTerrain
// .tint_map: a region's hue, and in its alpha what kind of toning the cell
// asks for). Each pixel takes the tone of one cell, read where a slow noise
// bends the edges off the grid (PIX-247: a region ended in straight lines
// and right angles, cell by cell) and a pixel's Bayer step jitters it, so
// an edge is a wandering line dithered over its last few pixels and every
// pixel inside a region is wholly toned (PIX-305: a coverage faded over a
// cell and a half and dithered in 2px blocks left bands across the ash
// wherever a road thinned it). Water keeps its own colours, so the mire and
// the ash stop at the shore. On the ground layer (`ground_life`) the open
// ground has its patches, drifts, murk and puddles, and the Ash its char,
// pale ash, cracks and cinders (open_ground.gdshaderinc).
//
// And what moves in the open air (PIX-223): `sway` leans the top of each quad
// it draws (a tree, a wheat sheaf, a flower) while its foot stays put - one
// sprite as one (`sway_alone`, its own beat) or a layer's tiles together;
// `canopy` sways a whole forest's crowns as one sheet, in pixels. On the
// ground (`water_life`) the water swells with light, glints here and there,
// and foam laps where PunyTerrain.water_map's water meets the land; inland
// (PIX-306, inland_water.gdshaderinc) rivers, ponds and pools are drawn
// again with depth, banks bent off the grid and each region's own water.
//
// One plane (One Reach, PIX-269, step 5): a map drawn beside the hero's
// reads its masks from its own corner (`map_origin`, where its cell (0, 0)
// lies in the plane), and everything that wanders - a region's edge, the
// water's swell and glints, the foam's lapping - runs on the plane's own
// pixels (the world's plus `plane_origin`, the hero's map's place), so it
// runs on unbroken across the line and doesn't jump when the hero's map
// changes there. Beside another map the masks are laid out a few cells past
// this map's edges with the other's (`mask_origin`, the map pixel at their
// first texel), so a region's tone and the shore's foam cross the line too.
//
// The ice in the open air (PIX-398: the Frostgate's lake) is the ice cave's
// (frozen.gdshaderinc), drawn over the ground layer (`ice_life`) from a mask
// of the map's own (`ice_map`, `ice_pixels`, read from `map_origin` alone:
// no map beside it has ice), its shore rounded and bent off the grid, the
// snow under it a ghost and its frost over the snow by the shore.

#include "res://shaders/wind.gdshaderinc"
#include "res://shaders/linear.gdshaderinc"

uniform sampler2D tint_map : filter_linear, repeat_disable;
uniform vec2 map_pixels;
uniform vec2 map_origin = vec2(0.0);
uniform vec2 mask_origin = vec2(0.0);
uniform float strength = 0.85;
uniform float sway = 0.0;
uniform bool sway_alone = false;
uniform float canopy = 0.0;
uniform bool water_life = false;
uniform bool ground_life = false;
// The cliffs standing in the ash (the rim layer) scorched on their tops as
// the ground's are, and nothing else of the ground's life (PIX-308).
uniform bool scorch_life = false;
uniform sampler2D water_map : filter_linear, repeat_disable;
// Bridges' planks (PIX-306): Shade drew his river showing between them,
// which takes the water's own look under them.
uniform bool planks = false;
// The town as it stood giving way to the town as it stands (PIX-264): as
// this goes 0 to 1 its 2px blocks drop out in the Bayer order, the same
// pixels in every layer drawn with it, so it goes as one picture.
uniform float dissolve = 0.0;
uniform bool ice_life = false;
uniform sampler2D ice_map : filter_linear, repeat_disable;
uniform vec2 ice_pixels = vec2(1.0);
// The open air's ice a colder blue than the cave's, to read on the snow.
const vec3 OPEN_ICE = vec3(0.82, 0.88, 0.95);

// Where the pixel lies in the plane (see above).
varying vec2 world_pos;

const float BAYER[16] = float[16](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0
);
// Foam's colour. The water map reads 0.5 on its cells' edge, a sixteenth
// less or more a pixel either way, and Shade's water spills about 4 pixels
// past its cells (to 0.25): the shallows reach SHALLOWS, and the foam's thin
// line laps in and out around FOAM_REACH, broken here and there.
const vec3 FOAM = vec3(0.86, 0.98, 0.95);
const float SHALLOWS = 0.45;
const float FOAM_REACH = 0.34;
const float FOAM_LAP = 0.035;
const float FOAM_LINE = 0.032;
// Shade's river between his planks.
const vec3 PLANK_GAP = vec3(0.039, 0.565, 0.627);

// A cell of the ground, in pixels.
const float CELL = 16.0;
// How far a region's edge wanders off the grid and how wide its bends are,
// in cells; and how many art pixels either side of it the dither reaches.
const float EDGE_WANDER = 0.4;
const float EDGE_BENDS = 2.6;
const float EDGE_SEAM = 1.5;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Shade's water, river and sea: blue-green with little red.
bool is_water(vec3 c) {
	return c.b > 0.5 && c.r < 0.45;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy + plane_origin;
	float lean = canopy * wind_lean(world_pos - plane_origin, 0.0);
	if (sway > 0.0 && top_corner(VERTEX_ID)) {
		if (sway_alone) {
			vec2 foot = MODEL_MATRIX[3].xy;
			lean += sway * wind_lean(foot, hash(foot + plane_origin) * 6.2832);
		} else {
			lean += sway * wind_lean(world_pos - plane_origin, 0.0);
		}
	}
	VERTEX.x += lean;
}

// Smooth value noise, 0..1: the slow bends of a region's edge.
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

#include "res://shaders/open_ground.gdshaderinc"
#include "res://shaders/frozen.gdshaderinc"

// The tone over the art pixel at `at`: the mask's texel (hue, and the kind
// in its alpha) of the one cell it's read from, where a slow noise bends the
// grid and the pixel's Bayer step jitters it by up to EDGE_SEAM pixels.
vec4 region_tone(vec2 at) {
	vec2 px = floor(at);
	vec2 cells = px / CELL;
	vec2 bend = vec2(value_noise(cells / EDGE_BENDS), value_noise(cells / EDGE_BENDS + 17.3)) - 0.5;
	vec2 jitter = vec2(art_dither(px), art_dither(px.yx + vec2(1.0, 2.0))) - 0.5;
	// The masks are the map's own, from its corner in the plane.
	vec2 read = px + 0.5 + bend * 2.0 * EDGE_WANDER * CELL + jitter * 2.0 * EDGE_SEAM - map_origin - mask_origin;
	vec2 texel = floor(read / CELL) + 0.5;
	return texture(tint_map, texel * CELL / map_pixels);
}

#include "res://shaders/inland_water.gdshaderinc"

void fragment() {
	vec4 base = COLOR;  // already the texel times the modulate
	base.rgb = to_display(base.rgb);
	vec4 tint = region_tone(world_pos);
	ivec2 block = ivec2(floor(world_pos / 2.0)) & ivec2(3);
	float threshold = (BAYER[block.y * 4 + block.x] + 0.5) / 16.0;
	if (threshold < dissolve) {
		discard;
	}
	// Rivers, ponds and pools drawn again with their banks (PIX-306); the
	// bank is toned as the land is, the water keeps its own.
	int inland = water_life ? inland_water(world_pos, base.rgb, TEXTURE_PIXEL_SIZE) : INLAND_NONE;
	if (inland == INLAND_LAND) {
		base.rgb = to_display(texture(TEXTURE, base.xy * TEXTURE_PIXEL_SIZE).rgb);
		inland = INLAND_BANK;
	}
	if (planks && distance(base.rgb, PLANK_GAP) < 0.03) {
		vec3 under = base.rgb;
		if (inland_water(world_pos, under, TEXTURE_PIXEL_SIZE) == INLAND_WATER) {
			base.rgb = under;
		}
	}
	bool water = inland == INLAND_WATER || (inland == INLAND_NONE && base.b > base.g);
	int kind = tone_kind(tint.a);
	// The Ash's ground and burnt rock's grassy top, scorched once toned
	// (PIX-308).
	bool ashen = (ground_life || scorch_life) && !water && kind == KIND_TONE && (is_grass(base.rgb) || is_dirt(base.rgb))
		&& (tinted(tint.rgb, ASH_TINT) || (tinted(tint.rgb, BURNT_ROCK) && is_grass(base.rgb)));
	// Open ground (PIX-305): the grass's patches, before the tone takes it.
	bool grass = ground_life && !water && !ashen && is_grass(base.rgb);
	int level = grass ? patch_level(floor(world_pos)) : 0;
	bool puddle = grass && kind == KIND_MIRE && puddled(floor(world_pos));
	if (grass) {
		base.rgb = ground_patches(base.rgb, level);
	}
	bool toned = kind == KIND_TONE || kind == KIND_MIRE || (kind == KIND_FRINGE && is_dirt(base.rgb));
	if (toned && !water && !puddle) {
		float luma = dot(base.rgb, vec3(0.299, 0.587, 0.114));
		base.rgb = mix(base.rgb, luma * tint.rgb * 2.0, strength);
	}
	if (puddle) {
		base.rgb = puddle_color(floor(world_pos));
	} else if (grass) {
		bool snow = toned && dot(tint.rgb, vec3(0.299, 0.587, 0.114)) > 0.7;
		base.rgb = ground_after(base.rgb, floor(world_pos), level, snow, kind == KIND_MIRE);
	} else if (ashen) {
		base.rgb = scorched_ground(base.rgb, floor(world_pos));
	}
	// The ice over the ground; the water in a hole in it left as it is.
	bool iced = false;
	if (ice_life && !water) {
		vec2 px = floor(world_pos) + 0.5;
		vec4 ice = ice_over(base.rgb, px, texture(ice_map, (ice_shore_at(px) - map_origin) / ice_pixels).r, threshold, OPEN_ICE);
		if (ice.a > 0.0) {
			base.rgb = ice.rgb;
			iced = true;
		}
	}
	// Ice never swells, foams or glints as water: its blue lip passed for water.
	if (water_life && !iced && inland == INLAND_NONE && is_water(base.rgb)) {
		vec2 px = floor(world_pos);
		// A slow swell of light rolling over the water.
		float swell = 0.6 * sin(world_time * 1.1 + px.x * 0.09 + px.y * 0.17)
			+ 0.4 * sin(world_time * 0.7 - px.x * 0.05 + px.y * 0.13);
		base.rgb *= 1.0 + 0.045 * swell;
		// Lighter in the shallows, and a broken line of foam lapping at the
		// shore.
		float out_from_shore = texture(water_map, (px - map_origin - mask_origin + 0.5) / map_pixels).r;
		if (out_from_shore < SHALLOWS) {
			base.rgb = mix(base.rgb, FOAM, 0.12);
		}
		float lap = FOAM_REACH + FOAM_LAP * sin(world_time * 1.6 + (px.x + px.y) * 0.15);
		float broken = sin(px.x * 0.35 - px.y * 0.2 - world_time * 1.3) + sin(px.x * 0.13 + px.y * 0.31 + world_time * 0.7);
		if (abs(out_from_shore - lap) < FOAM_LINE && broken > -0.5) {
			base.rgb = mix(base.rgb, FOAM, 0.6);
		}
		// Glints: a short streak catches the light for a moment, here and
		// there, brightest in its middle.
		vec2 streak = vec2(floor(px.x / 3.0), px.y);
		float slot = floor(world_time * 1.8 + hash(streak) * 9.0);
		if (hash(streak + slot * 13.7) > 0.9965) {
			float middle = mod(px.x, 3.0) == 1.0 ? 0.7 : 0.4;
			base.rgb = mix(base.rgb, vec3(0.9, 1.0, 1.0), middle);
		}
	}
	COLOR = vec4(to_canvas(base.rgb), base.a);
}
