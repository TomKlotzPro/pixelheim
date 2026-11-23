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
// pale ash, cracks and cinders (open_ground.gdshaderinc); and a country
// road's ends and turns their own shape, not its cells' (PIX-404,
// road_shape.gdshaderinc).
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
//
// Light relief (PIX-528, PIX-529, relief.gdshaderinc): the lamps and the
// lantern shape the decor and the trees (domed) and the Frostgate's paving
// (carved), as `relief_form` says; the open ground stays plain.

#include "res://shaders/wind.gdshaderinc"
#include "res://shaders/linear.gdshaderinc"
#include "res://shaders/see_through.gdshaderinc"
#include "res://shaders/relief.gdshaderinc"

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
// Light relief's form (Relief.PLAIN, CARVED, DOMED: the ground plain) and
// whether this draws a tile layer.
uniform int relief_form = 0;
uniform bool relief_tiles = true;
// The open air's ice a colder blue than the cave's, to read on the snow.
const vec3 OPEN_ICE = vec3(0.82, 0.88, 0.95);

// Where the pixel lies in the plane (see above).
varying vec2 world_pos;
// A sprite standing alone (a tree): the y it is sorted on (its foot), in
// the canvas, so it turns see-through round the hero while it stands over
// them (PIX-430, see_through.gdshaderinc).
varying float sorted_on;

const float BAYER[16] = float[16](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0
);
// Shade's sea foam (his sand shore's ring, overworld tiles 282-286,
// 309-313, 336-338), its shade and his shallows' light; his white water
// (his falls, 598-601) where the sea breaks. Whole pixels, never mixed in.
const vec3 SEA_FOAM = vec3(0.624, 0.918, 0.867);
const vec3 SEA_FOAM_SHADE = vec3(0.494, 0.875, 0.808);
const vec3 SEA_LACE = vec3(0.369, 0.82, 0.714);
const vec3 WHITE_WATER = vec3(0.616, 1.0, 0.996);
// The water map reads 0.5 on its cells' edge, a sixteenth more or less a
// pixel either way; Shade's water spills about 4 pixels past his cells
// (WATERLINE). The shallows reach SHALLOWS.
const float SHALLOWS = 0.45;
const float WATERLINE = 0.25;
// A rock's foot (the mask's blue from STEEP up: PunyTerrain.ROCK_SURF) is
// steep: Shade's water begins at the cell's edge (0.5), and a wave runs in
// half as far before it slaps the rock. His cliff's face hangs ROCK_FOOT px
// down over the water at its foot, so there the wash reads its shore from
// that far up: read where it lies, the first water seen under a rock was
// already past the red's gradient, and nothing ever broke on it.
const float STEEP = 0.85;
const float ROCK_FOOT = 6.0;
// The wash (PIX-532): once a swell (SWELL_SPEED, the light's beat) a wave
// rolls in from WASH_FROM pixels out to the waterline over RUN_IN of it,
// its spent foam WASH_BODY behind, then draws back BACKWASH as a lace;
// each stretch of shore SWELL_LATE sooner or later over SWELL_BENDS
// pixels, so it reaches a beach bent and broken, never ruled (at 80 and
// 1.5 a whole cove came in at once, an even band along Shade's ring). Its
// crest breaks white over its last BREAK_RUN px and as much more of its run
// as the sea breaks there (the mask's blue), and as it turns heaps white
// over as much of the shore as it broke on (a point's reaching past the
// lighthouse's foot, 4 px out), BREAK_HEAP at the most and never all of it
// (HEAP_THICK): a storm's ran into the red's plateau, a white slab with a
// ruled edge. Each wave its own crest: wavering CREST_WAVER either way over
// CREST_BENDS pixels and broken off in gaps CREST_GAPS across, about
// CREST_GAP of it, so a rock's straight foot never draws a ruled line (a
// pixel's waver over 5 drew one band under the headland); and its spent
// foam its own grain, a hash a pixel (a Bayer step drew a ruled row of dots
// under it). A storm whitens every shore (STORM_SURF a wind above 1).
const float SWELL_SPEED = 1.1;
const float SWELL_LATE = 2.0;
const float SWELL_BENDS = 56.0;
const float BREAK_RUN = 1.0;
const float BREAK_HEAP = 6.0;
const float HEAP_THICK = 0.85;
const float WASH_FROM = 7.0;
const float WASH_BODY = 3.0;
const float RUN_IN = 0.3;
const float BACKWASH = 4.0;
const float STORM_SURF = 0.5;
const float CREST_WAVER = 1.5;
const float CREST_BENDS = 4.0;
const float CREST_GAPS = 6.0;
const float CREST_GAP = 0.4;
// A pier's posts: one each POST_EVERY pixels under each side, a half-gap
// from the cell's ends so no ring is cut there. A post froths only near its
// swell's top (past POST_PEAK), and on each swell only some do (POST_QUIET
// of them stay still): a broken arc POST_RING round, POST_LIFT more with
// the wind at the top. All of them at once read as a ruled row of beads.
const float POST_EVERY = 8.0;
const float POST_PEAK = 0.6;
const float POST_QUIET = 0.5;
const float POST_RING = 2.0;
const float POST_LIFT = 1.5;
// Foam under the moon (sun.w, LightRig): a cool lift, as the roofs' (roof_light).
global uniform vec4 sun;
const vec3 MOON_FOAM = vec3(0.7, 0.82, 1.0);
const float FOAM_MOON = 0.3;
vec3 moonlit(vec3 foam) {
	return foam * (1.0 + MOON_FOAM * FOAM_MOON * clamp(sun.w, 0.0, 1.0));
}
// Shade's river between his planks.
const vec3 PLANK_GAP = vec3(0.039, 0.565, 0.627);

// A cell of the ground, in pixels.
const float CELL = 16.0;
// How far a region's edge wanders off the grid and how wide its bends are,
// in cells; and how many art pixels either side of it the dither reaches.
const float EDGE_WANDER = 0.4;
const float EDGE_BENDS = 2.6;
const float EDGE_SEAM = 1.5;

// hash and value_noise (the slow bends of a region's edge), and where an
// inland water's bank lies, as the reflections read it too.
#include "res://shaders/water_bank.gdshaderinc"

// Shade's water, river and sea: blue-green with little red.
bool is_water(vec3 c) {
	return c.b > 0.5 && c.r < 0.45;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy + plane_origin;
	sorted_on = MODEL_MATRIX[3].y;
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

#include "res://shaders/open_ground.gdshaderinc"
#include "res://shaders/frozen.gdshaderinc"
#include "res://shaders/road_shape.gdshaderinc"

// Where in the masks (their pixels) the tone over the art pixel at `at` is
// read: where a slow noise bends the grid and the pixel's Bayer step jitters
// it by up to EDGE_SEAM pixels. The bank's land follows it (bank_land).
vec2 tone_read(vec2 at) {
	vec2 px = floor(at);
	vec2 cells = px / CELL;
	vec2 bend = vec2(value_noise(cells / EDGE_BENDS), value_noise(cells / EDGE_BENDS + 17.3)) - 0.5;
	vec2 jitter = vec2(art_dither(px), art_dither(px.yx + vec2(1.0, 2.0))) - 0.5;
	// The masks are the map's own, from its corner in the plane.
	return px + 0.5 + bend * 2.0 * EDGE_WANDER * CELL + jitter * 2.0 * EDGE_SEAM - map_origin - mask_origin;
}

// The tone over the art pixel at `at`: the mask's texel (hue, and the kind
// in its alpha) of the one cell it's read from, where a slow noise bends the
// grid and the pixel's Bayer step jitters it by up to EDGE_SEAM pixels.
// Where a country road meets open ground, the road's own shape decides
// which (PIX-404, road_toned).
vec4 region_tone(vec2 at) {
	vec2 read = tone_read(at);
	vec2 texel = road_toned(floor(read / CELL) + 0.5, read + mask_origin);
	return texture(tint_map, texel * CELL / map_pixels);
}

#include "res://shaders/inland_water.gdshaderinc"

// The swell's beat at `px` (plane pixels): one wash a TAU, each stretch of
// shore a little sooner or later than the next.
float wash_beat(vec2 px) {
	return world_time * SWELL_SPEED + (value_noise(px / SWELL_BENDS + 9.1) - 0.5) * 2.0 * SWELL_LATE;
}

// The wash's foam over the sea's pixel `px` (plane pixels), `red` and
// `surf` the water map's red and how hard the sea breaks there: Shade's
// colour, alpha 1, or alpha 0. The wind sets how far it runs: none with
// Reduce motion.
vec4 sea_foam(vec2 px, float red, float surf) {
	float steep = smoothstep(STEEP, 1.0, surf);
	float d = (red - mix(WATERLINE, 0.5, steep)) * CELL;
	float wind = clamp(world_wind, 0.0, 2.0);
	float run = min(wind, 1.0);
	float white = clamp(surf + (wind - 1.0) * STORM_SURF, 0.0, 1.0);
	float beat = wash_beat(px) / TAU;
	float c = fract(beat);
	float wave = floor(beat);
	float grain = hash(px + vec2(wave * 3.7, 1.3));
	float broken = value_noise(px / 3.0 + vec2(world_time * 0.6, 0.0));
	float churn = hash(px + floor(world_time * 3.0));
	float from = WASH_FROM * (1.0 - 0.5 * steep);
	float breaks = BREAK_RUN + from * white;
	if (c < RUN_IN) {
		float k = c / RUN_IN;
		float front = from * run * (1.0 - k) * (1.0 - k);
		float waver = (value_noise(px / CREST_BENDS + 3.3 + wave * 1.9) - 0.5) * 2.0 * CREST_WAVER;
		bool gap = value_noise(px / CREST_GAPS + 7.7 + wave * 2.3) < CREST_GAP;
		if (!gap && abs(d - front - waver) < 0.5 + white && broken > 0.4 - white * 0.1) {
			return vec4(front < breaks && churn < white * 0.9 ? WHITE_WATER : SEA_FOAM, 1.0);
		}
		// Its spent foam behind, in patches (a plain dither drew a cove's
		// whole ring in an even checkered band).
		float trail = d - front;
		if (trail > 0.0 && trail < WASH_BODY * run && broken > 0.35 && grain < (1.0 - trail / WASH_BODY) * 0.75) {
			return vec4(SEA_FOAM_SHADE, 1.0);
		}
	} else {
		float k = (c - RUN_IN) / (1.0 - RUN_IN);
		// White water heaped where it broke, its edge ragged, settling.
		if (k < 0.25 && d < min(breaks, BREAK_HEAP) * (1.0 + 0.4 * broken) && churn < min(white * 1.2, HEAP_THICK) * (1.0 - k * 4.0)) {
			return vec4(WHITE_WATER, 1.0);
		}
		float back = BACKWASH * (1.0 - 0.5 * steep) * run * k;
		if (d >= 0.0 && abs(d - back) < 1.0 && broken > 0.4 && grain < (1.0 - k) * 0.6) {
			// Spent foam first, then lace as it thins: his shallows' light
			// alone hardly shows on them.
			return vec4(k < 0.5 ? SEA_FOAM_SHADE : SEA_LACE, 1.0);
		}
	}
	return vec4(0.0);
}

// The sea round a pier's posts (PIX-532): now and then, near the top of its
// own swell, a post froths, a broken arc on the water's side, white at its
// height; a different few on each swell, most of them still.
vec4 pier_posts(vec2 px, vec2 local_px) {
	ivec2 cell = ivec2(floor(local_px / CELL));
	vec2 into = local_px - vec2(cell) * CELL;
	for (int side = 0; side < 4; side++) {
		ivec2 toward = side == 0 ? ivec2(-1, 0) : (side == 1 ? ivec2(1, 0) : (side == 2 ? ivec2(0, -1) : ivec2(0, 1)));
		if (!span_at(cell + toward)) {
			continue;
		}
		float edge = toward.x < 0 ? into.x : (toward.x > 0 ? CELL - into.x : (toward.y < 0 ? into.y : CELL - into.y));
		float along = toward.x != 0 ? into.y : into.x;
		float off = mod(along, POST_EVERY) - POST_EVERY * 0.5;
		float post = floor(along / POST_EVERY) + dot(vec2(cell), vec2(7.1, 3.3)) + float(side) * 1.7;
		float phase = wash_beat(px) + hash(vec2(post, 4.2)) * TAU;
		// Which swell this is turns over while the post is still (sin 0,
		// under POST_PEAK), never while it froths.
		if (hash(vec2(post, floor(phase / TAU))) < POST_QUIET) {
			continue;
		}
		float rise = (sin(phase) - POST_PEAK) / (1.0 - POST_PEAK);
		float reach = POST_RING + POST_LIFT * clamp(world_wind, 0.0, 1.0) * rise;
		if (rise > 0.0 && abs(length(vec2(off, edge)) - reach) < 0.5 && hash(floor(px) + floor(phase * 2.0)) > 0.35) {
			return vec4(rise > 0.6 ? WHITE_WATER : SEA_FOAM, 1.0);
		}
	}
	return vec4(0.0);
}

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
	bool drawn_back = inland == INLAND_LAND;
	if (drawn_back) {
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
	// A country road's ends and turns drawn to its shape (PIX-404), before
	// the grass's patches read the ground.
	if (road_ground && !water) {
		base.rgb = road_ground_at(base.rgb, floor(world_pos) + 0.5 - map_origin);
	}
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
		// A hole in the ice is cut in it (PIX-467): the ice lies whole up to the
		// hole's rim of shelf ice, which stays bare. Its own shore wandered
		// round the hole's cells, and its blue lip showed as a bar under the
		// hole once the hole's bank was drawn inside them.
		float reach = inland == INLAND_BANK ? float(drawn_back) : texture(ice_map, (ice_shore_at(px) - map_origin) / ice_pixels).r;
		vec4 ice = ice_over(base.rgb, px, reach, threshold, OPEN_ICE);
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
		// Lighter in the shallows; the wash rolling in and drawing back with
		// the swell, white where the sea breaks, and round a pier's posts
		// (PIX-532).
		vec2 local_px = px - map_origin - mask_origin + 0.5;
		vec4 sea = texture(water_map, local_px / map_pixels);
		if (sea.r < SHALLOWS) {
			base.rgb = mix(base.rgb, SEA_FOAM, 0.12);
		}
		// Only inside the shore's gradient (red < 1): where it saturates every
		// pixel reads the same and a band would fill the open sea.
		// How hard it breaks, of the sea's cells alone: the land's blue is 0,
		// and read smoothly it halved a rock's foot at its edge.
		float red = sea.r;
		float surf = red > 0.0 ? sea.b / red : 0.0;
		if (sea.b > 0.0) {
			vec4 up = texture(water_map, (local_px - vec2(0.0, ROCK_FOOT)) / map_pixels);
			if (up.r < red && up.b > STEEP * up.r) {
				red = up.r;
				surf = up.b / up.r;
			}
		}
		vec4 foam = red < 0.99 ? sea_foam(px, red, surf) : vec4(0.0);
		if (foam.a == 0.0 && sea.b > 0.0) {
			foam = pier_posts(px, local_px);
		}
		if (foam.a > 0.0) {
			base.rgb = moonlit(foam.rgb);
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
	if (sway_alone) {
		base.a *= see_through(world_pos - plane_origin, sorted_on);
	}
	// Light relief (PIX-528, PIX-529), of the art as it is drawn here, in its
	// form: none on the water, a puddle, the ice or a bank drawn again over
	// Shade's.
	if (relief > 0.0 && relief_form != RELIEF_PLAIN && !water && !puddle && !iced && inland == INLAND_NONE) {
		NORMAL_MAP = RELIEF_SHAPE(relief_form, relief_tiles);
	} else {
		NORMAL_MAP = RELIEF_FLAT;
	}
	COLOR = vec4(to_canvas(base.rgb), base.a);
}
