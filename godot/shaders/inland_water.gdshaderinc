// Water inland (PIX-306): the rivers, the ponds, the Deepwood's lake and the
// Mirefen's pools, held to the sea. Shade drew them one flat cyan with a
// ruler-straight bank, so here they're drawn again from the water mask
// (PunyTerrain.water_map): red where the water lies (a half on its cells'
// edge, read smoothly), blue how far its bank is (deep down the middle),
// alpha its code - its tone, whether it runs and which way, a bridge
// standing in it - and on the land beside it the tone and the land's
// ground.
//
// The bank bends off the grid as a region's edge does: the mask is read
// where a slow noise moves it, a few pixels either way, and the bank is
// drawn on that line - Shade's dark bank earth, the water's dark edge and
// its light lip - with the land's own tile where it draws back over what
// Shade drew as water (and the grass he set between a road and it). The
// water deepens from its banks in its tone's four colours, dithered into
// each other in whole pixels of the art as the sea's depths are, its deep
// channel wandering; a swell of light rolls over it and glints catch. Foam
// laps a little way out from the bank; a river's streaks drift downstream
// and foam piles where it meets a bridge's piles. Each region has its own
// water: clear in the Reach and the village, dark teal in the Deepwood,
// murky olive in the Mirefen with lily pads, duckweed and reeds, icy in the
// Frostgate.
//
// Included by region_tint.gdshader after its hash, value_noise, BAYER and
// CELL, reading its water_map, map_origin, mask_origin and map_pixels. All
// of it in whole pixels of the art, and only within a cell and a half of
// inland water (one read of the mask everywhere else).

// What inland_water made of a pixel: nothing (no inland water near), the
// bank (to be toned as the land is), the water (drawn, kept as it is), or
// the land under where Shade's water was (its sheet's pixel to read in the
// colour's red and green, then toned as the bank is).
const int INLAND_NONE = 0;
const int INLAND_BANK = 1;
const int INLAND_WATER = 2;
const int INLAND_LAND = 3;

// The tones (PunyTerrain.WATER_*): clear, the mire's, the Deepwood's, the
// cold's; and what a code's bits hold (TONE_BIT, SPAN_BIT, FLOWS).
const int TONE_CLEAR = 1;
const int TONE_MIRE = 2;
const int TONE_DEEP = 3;
const int TONE_ICE = 4;

// How far the bank bends off its cells, in pixels either way, and how many
// cells lie between its bends; where it lies on average, in pixels past its
// water's cells (Shade's water spills about 4); and how far past them Shade
// drew his water and his bank, which the land's own tile covers where the
// bank draws back.
const float BANK_WANDER = 5.0;
const float BANK_BENDS = 1.5;
const float BANK_OUT = 3.0;
const float SHADE_BANK = 9.5;
// Where a bridge lands the bank lies this far in under its planks.
const float LANDING_IN = -3.0;
// The mask's blue (cells from the bank / 3) where the water starts to
// deepen, and over how much more it reaches its deepest; how far its deep
// channel wanders off the cells, in pixels, and over how many; where each
// colour gives way to the next, and how wide their dither.
const float DEPTH_FROM = 0.17;
const float DEPTH_OVER = 0.5;
const float DEPTH_WANDER = 11.0;
const float DEPTH_BENDS = 44.0;
const float BAND_AT[3] = float[3](0.16, 0.42, 0.72);
const float BAND_DITHER = 0.07;
// The foam's line, this many pixels out from the bank, lapping in and out.
const float LAP_OUT = 2.5;
const float LAP_SWING = 1.2;
// A river's streaks: lanes this many pixels apart, drifting this fast
// (pixels a second) downstream, a dash every so many pixels.
const float STREAK_LANE = 5.0;
const float STREAK_SPEED = 9.0;
const float STREAK_EVERY = 26.0;

// Each tone's water from its shallows to its deep (sRGB).
const vec3 CLEAR_WATER[4] = vec3[4](
	vec3(0.17, 0.75, 0.73), vec3(0.08, 0.67, 0.72), vec3(0.016, 0.61, 0.70), vec3(0.012, 0.51, 0.65));
const vec3 MIRE_WATER[4] = vec3[4](
	vec3(0.37, 0.39, 0.24), vec3(0.29, 0.32, 0.2), vec3(0.22, 0.26, 0.17), vec3(0.16, 0.2, 0.14));
const vec3 DEEP_WATER[4] = vec3[4](
	vec3(0.15, 0.58, 0.55), vec3(0.09, 0.47, 0.48), vec3(0.055, 0.37, 0.42), vec3(0.035, 0.28, 0.35));
const vec3 ICE_WATER[4] = vec3[4](
	vec3(0.42, 0.64, 0.78), vec3(0.3, 0.52, 0.7), vec3(0.2, 0.4, 0.6), vec3(0.13, 0.3, 0.5));

vec3 water_colour(int tone, int band) {
	if (tone == TONE_MIRE) {
		return MIRE_WATER[band];
	} else if (tone == TONE_DEEP) {
		return DEEP_WATER[band];
	} else if (tone == TONE_ICE) {
		return ICE_WATER[band];
	}
	return CLEAR_WATER[band];
}

// The light lip at the water's edge, its foam, and the dark wet line under
// the bank, by tone.
vec3 water_lip(int tone) {
	if (tone == TONE_MIRE) {
		return vec3(0.56, 0.6, 0.38);
	} else if (tone == TONE_DEEP) {
		return vec3(0.33, 0.7, 0.66);
	} else if (tone == TONE_ICE) {
		return vec3(0.9, 0.97, 1.0);
	}
	return vec3(0.11, 0.8, 0.8);
}

vec3 water_foam(int tone) {
	if (tone == TONE_MIRE) {
		return vec3(0.66, 0.7, 0.5);
	} else if (tone == TONE_DEEP) {
		return vec3(0.6, 0.85, 0.82);
	}
	return vec3(0.86, 0.98, 0.95);
}

vec3 water_wet(int tone) {
	if (tone == TONE_MIRE) {
		return vec3(0.2, 0.22, 0.14);
	} else if (tone == TONE_DEEP) {
		return vec3(0.04, 0.3, 0.32);
	} else if (tone == TONE_ICE) {
		return vec3(0.55, 0.72, 0.8);
	}
	return vec3(0.055, 0.5, 0.55);
}

// The bank's rim: Shade's dark bank earth; in the cold, shelf ice.
vec3 bank_rim(int tone) {
	return tone == TONE_ICE ? vec3(0.78, 0.88, 0.94) : vec3(0.36, 0.38, 0.22);
}

// Shade's full tiles of the land a bank may stand on (PunyTerrain
// .BANK_GROUNDS): his nine grasses, his dirt, his sand.
const int GRASS_TILES[9] = int[9](0, 1, 2, 27, 28, 29, 54, 55, 56);
const int DIRT_TILE = 38;
const int SAND_TILE = 50;
const float SHEET_COLUMNS = 27.0;

float bayer_at(vec2 px) {
	ivec2 b = ivec2(mod(px, 4.0));
	return (BAYER[b.y * 4 + b.x] + 0.5) / 16.0;
}

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

// The land by the bank where it bends back over what Shade drew as water:
// his own tile of that land's ground (marked on the land's cells by the
// bank), at this pixel's place in the dual grid's tile, so it runs on from
// the land round it; toned after as the land is. Where to read it on the
// tile layer's sheet (`sheet_pixel` its texel's size), in its pixels: the
// fragment reads it (a function can't be handed the TEXTURE built-in).
vec2 bank_land(vec2 local_px, vec2 map_px, vec2 sheet_pixel) {
	ivec2 corner = ivec2(floor((local_px - CELL * 0.5) / CELL));
	int ground = 0;
	for (int i = 0; i < 4; i++) {
		vec4 texel = mask_texel(corner + ivec2(i % 2, i / 2));
		if (texel.r < 0.5 && texel.a > 0.0) {
			ground = int(round(texel.a * 255.0)) % 16;
		}
	}
	// The ground layer lies half a tile up-left of the cells.
	vec2 dual = floor((map_px + CELL * 0.5) / CELL);
	int tile = ground == 1 ? DIRT_TILE : (ground == 2 ? SAND_TILE : GRASS_TILES[int(hash(dual + 0.17) * 8.99)]);
	// The tile layer draws from Godot's padded copy of the sheet: each tile
	// a pixel in from its slot's edges.
	float slot = 1.0 / sheet_pixel.x / SHEET_COLUMNS;
	vec2 origin = vec2(mod(float(tile), SHEET_COLUMNS), floor(float(tile) / SHEET_COLUMNS)) * slot + (slot - CELL) * 0.5;
	vec2 in_tile = mod(floor(map_px) + CELL * 0.5, CELL);
	return origin + in_tile + 0.5;
}

bool span_at(ivec2 cell) {
	return (water_code_at(cell) / 8) % 2 == 1;
}

// Which way the water in a cell of code `code` runs: (0, 0) still, west
// along a river across the map, south down one (PunyTerrain.FLOWS).
vec2 flow_of(int code) {
	int flow = code % 8;
	return flow == 1 ? vec2(-1.0, 0.0) : (flow == 2 ? vec2(0.0, 1.0) : vec2(0.0));
}

// How many pixels the bank lies from `at` (mask pixels) into the water,
// read where the bank's bend moves it: below 0 on the land side.
float bank_depth(vec2 at, vec2 bend) {
	return (texture(water_map, (at + bend) / map_pixels).r - 0.5) * CELL + BANK_OUT;
}

// A lily pad on still water, if one floats over `px` (plane pixels): its
// colour, alpha 1; alpha 0 if none. One may float in each patch of 17 by
// 14 pixels, well out from the bank, a notch cut in it, some flowering.
vec4 lily_pad(vec2 px, vec2 local_px, vec2 bend) {
	vec2 patch_size = vec2(17.0, 14.0);
	vec2 patch = floor(px / patch_size);
	if (hash(patch + 7.3) < 0.72) {
		return vec4(0.0);
	}
	vec2 centre = patch * patch_size + vec2(5.0) + floor(vec2(hash(patch + 1.9), hash(patch + 4.4)) * (patch_size - 10.0)) + 0.5;
	float radius = hash(patch + 2.6) > 0.5 ? 4.0 : 3.0;
	vec2 d = px - centre;
	if (dot(d / vec2(radius + 0.5, radius - 0.2), d / vec2(radius + 0.5, radius - 0.2)) > 1.0) {
		return vec4(0.0);
	}
	// The notch, toward a side of its own.
	float turn = hash(patch + 8.8) > 0.5 ? 1.0 : -1.0;
	if (d.x * turn > 0.5 && abs(d.y) <= abs(d.x) * 0.35) {
		return vec4(0.0);
	}
	// Only where the water is deep enough to float in.
	if (bank_depth(local_px + (centre - px), bend) < radius + 3.0) {
		return vec4(0.0);
	}
	if (hash(patch + 5.5) > 0.82 && abs(d.x + turn) < 1.0 && abs(d.y + 1.0) < 1.0) {
		return vec4(0.93, 0.66, 0.78, 1.0);
	}
	vec3 pad = vec3(0.38, 0.56, 0.23);
	if (d.x + d.y < -radius * 0.5) {
		pad = vec3(0.5, 0.68, 0.29);
	} else if (d.x + d.y > radius * 0.9) {
		pad = vec3(0.23, 0.37, 0.16);
	}
	return vec4(pad, 1.0);
}

// Reeds along a bank in the mire, if a stem stands over `px`: its colour,
// alpha 1; else alpha 0. A clump may root in each patch of 9 by 8 pixels
// where its root lies in the water by the bank: three stems rising up to 7
// pixels, the tallest with a brown head, leaning with the wind.
vec4 reeds(vec2 px, vec2 local_px, vec2 bend) {
	vec2 patch_size = vec2(9.0, 8.0);
	for (int below = 0; below < 2; below++) {
		vec2 patch = floor(px / patch_size) + vec2(0.0, float(below));
		if (hash(patch + 3.7) < 0.3) {
			continue;
		}
		vec2 root = patch * patch_size + floor(vec2(hash(patch + 6.1) * 5.0 + 2.0, hash(patch + 0.7) * 3.0 + 4.0)) + 0.5;
		float in_water = bank_depth(local_px + (root - px), bend);
		if (in_water < 0.5 || in_water > 6.0) {
			continue;
		}
		float lean = floor(world_wind * 0.8 * (0.5 + 0.5 * sin(world_time * 1.4 + root.x * 0.3)) + 0.5);
		for (int stem = 0; stem < 3; stem++) {
			float x = root.x + float(stem * 2 - 2) + floor(hash(patch + float(stem) * 1.7) * 2.0);
			float tall = 4.0 + floor(hash(patch + float(stem) * 3.1 + 9.0) * 5.0);
			float rise = root.y - px.y;
			if (rise < 0.0 || rise > tall) {
				continue;
			}
			// The top leans with the wind, a pixel at most.
			float bent = rise > tall * 0.6 ? lean : 0.0;
			if (abs(px.x - (x + bent)) < 0.5) {
				if (stem == 1 && rise > tall - 2.0) {
					return vec4(0.52, 0.33, 0.17, 1.0);
				}
				return vec4(stem == 0 ? vec3(0.3, 0.42, 0.18) : vec3(0.48, 0.6, 0.26), 1.0);
			}
		}
	}
	return vec4(0.0);
}

// Draws inland water and its bank over the ground's pixel at `at` (plane
// pixels), `base` its colour as shown; says what it made of it.
int inland_water(vec2 at, inout vec3 base, vec2 sheet_pixel) {
	vec2 px = floor(at) + 0.5;
	// Where the pixel lies in the mask (a texel a cell), as the sea's reads.
	vec2 local_px = px - map_origin - mask_origin;
	vec4 plain = texture(water_map, local_px / map_pixels);
	if (plain.a <= 0.0) {
		return INLAND_NONE;
	}
	ivec2 cell = ivec2(floor(local_px / CELL));
	int code = water_code_near(cell);
	int tone = code / 16;
	if (tone == 0) {
		return INLAND_NONE;
	}
	// The bank, bent off the grid; but where a bridge lands, straight and
	// in under its planks' ends.
	bool landing = (code / 8) % 2 == 1 && mask_texel(cell).r < 0.5;
	vec2 cells = floor(px) / CELL / BANK_BENDS;
	vec2 bend = clamp((vec2(value_noise(cells + 31.7), value_noise(cells + 47.1)) - 0.5) * 1.7, -0.5, 0.5) * 2.0 * BANK_WANDER;
	if (landing) {
		bend = vec2(0.0);
	}
	vec4 here = texture(water_map, (local_px + bend) / map_pixels);
	float in_water = (here.r - 0.5) * CELL + (landing ? LANDING_IN : BANK_OUT);
	float threshold = bayer_at(px);
	if (in_water < 0.0) {
		vec4 reed = tone == TONE_MIRE && in_water > -9.0 ? reeds(px, local_px, bend) : vec4(0.0);
		if (reed.a > 0.0) {
			base = reed.rgb;
			return INLAND_WATER;
		}
		if (in_water >= -1.0) {
			base = water_wet(tone);
			return INLAND_WATER;
		}
		if (in_water >= -2.0) {
			base = bank_rim(tone);
			return INLAND_BANK;
		}
		// The land's own ground where the bank draws back over Shade's water
		// and his rim.
		if ((plain.r - 0.5) * CELL >= -SHADE_BANK) {
			base = vec3(bank_land(local_px, px - map_origin, sheet_pixel), 0.0);
			return INLAND_LAND;
		}
		return INLAND_NONE;
	}
	// The water deepens from its banks, its deep channel wandering, in its
	// tone's colours dithered into each other.
	vec2 meander = (vec2(value_noise(floor(px) / DEPTH_BENDS + 13.1), value_noise(floor(px) / DEPTH_BENDS + 71.9)) - 0.5) * 2.0 * DEPTH_WANDER;
	float deep = clamp((texture(water_map, (local_px + meander) / map_pixels).b - DEPTH_FROM) / DEPTH_OVER, 0.0, 1.0);
	deep += (value_noise(floor(px) / 19.0 + 5.3) - 0.5) * 0.14;
	// Never darker than the shallows right by the bank.
	deep = min(deep, in_water / 6.0);
	int band = 0;
	for (int i = 0; i < 3; i++) {
		if (deep > BAND_AT[i] + (threshold - 0.5) * 2.0 * BAND_DITHER) {
			band = i + 1;
		}
	}
	vec3 water = water_colour(tone, band);
	bool still = code % 8 == 0;
	vec2 flow = flow_of(code);
	// The mire's murk: darker patches drifting over it, slowly.
	if (tone == TONE_MIRE) {
		float murk = value_noise(floor(px) / 17.0 + vec2(world_time * 0.05, 0.0));
		if (murk > 0.66 + threshold * 0.2) {
			water *= 0.9;
		}
	}
	// A slow swell of light rolling over it, gentler on still water.
	float swell = 0.6 * sin(world_time * (still ? 0.7 : 1.1) + px.x * 0.09 + px.y * 0.17)
		+ 0.4 * sin(world_time * (still ? 0.45 : 0.7) - px.x * 0.05 + px.y * 0.13);
	water *= 1.0 + (still ? 0.03 : 0.045) * swell;
	// The light lip at its edge, and a broken line of foam lapping a little
	// way out.
	if (in_water < 1.0) {
		water = water_lip(tone);
	} else {
		float lap = LAP_OUT + LAP_SWING * sin(world_time * (still ? 0.9 : 1.6) + (px.x + px.y) * 0.15);
		vec2 drift = flow * world_time * STREAK_SPEED * 0.5;
		float broken = sin((px.x + drift.x) * 0.35 - (px.y + drift.y) * 0.2 - world_time * 1.3)
			+ sin((px.x + drift.x) * 0.13 + (px.y + drift.y) * 0.31 + world_time * 0.7);
		if (abs(in_water - lap) < 0.5 && broken > (still ? 0.2 : -0.4)) {
			water = mix(water, water_foam(tone), still ? 0.35 : 0.55);
		}
	}
	// Where it meets a bridge's piles: on a river foam piled against them
	// upstream and churning, ripples lapping at them on still water.
	if (!span_at(cell)) {
		vec2 into = local_px - vec2(cell) * CELL;
		for (int side = 0; side < 4; side++) {
			ivec2 toward = side == 0 ? ivec2(-1, 0) : (side == 1 ? ivec2(1, 0) : (side == 2 ? ivec2(0, -1) : ivec2(0, 1)));
			if (!span_at(cell + toward)) {
				continue;
			}
			float edge = toward.x < 0 ? into.x : (toward.x > 0 ? CELL - into.x : (toward.y < 0 ? into.y : CELL - into.y));
			float churn = sin(world_time * 3.1 + (px.x + px.y) * 0.9) + sin(world_time * 1.7 - (px.x - px.y) * 0.5);
			if (still) {
				float ripple = 1.5 + 0.8 * sin(world_time * 1.1 + (px.x + px.y) * 0.2);
				if (abs(edge - ripple) < 0.5 && churn > 0.0) {
					water = mix(water, water_lip(tone), 0.5);
				}
			} else if (dot(vec2(toward), flow) > 0.5 && edge < 2.5 + 1.5 * sin(world_time * 2.3 + (px.x + px.y) * 0.4) && churn > -0.8) {
				water = mix(water, water_foam(tone), edge < 1.5 ? 0.8 : 0.55);
			}
		}
	}
	// A river's streaks drifting downstream, mid-stream, in lanes.
	if (!still && in_water > 4.0 && deep > 0.3) {
		// Each lane wavers a pixel either way along the stream, so a streak
		// reads as a current, not a fall of rain.
		vec2 across = vec2(-flow.y, flow.x);
		float lane_at = dot(floor(px), across);
		float lane = floor(lane_at / STREAK_LANE + 0.5);
		float waver = floor(0.9 * sin(dot(floor(px), flow) * 0.21 + hash(vec2(lane, 1.7)) * 6.28) + 0.5);
		if (lane_at == lane * STREAK_LANE + waver) {
			float speed = STREAK_SPEED * (0.8 + 0.5 * hash(vec2(lane, 3.3)));
			float along = dot(floor(px), flow) - world_time * speed + hash(vec2(lane, 9.1)) * 97.0;
			float dash = floor(along / STREAK_EVERY);
			float into_dash = along - dash * STREAK_EVERY;
			float dash_length = 2.0 + floor(hash(vec2(lane, dash)) * 5.0);
			if (hash(vec2(dash, lane) + 0.37) > 0.68 && into_dash < dash_length) {
				water = mix(water, water_foam(tone), into_dash > dash_length - 1.0 ? 0.4 : 0.22);
			}
		}
	}
	// Glints: a short streak catches the light for a moment, here and there
	// (dull in the murk, often on the cold water).
	float glinting = tone == TONE_MIRE ? 0.9992 : (tone == TONE_ICE ? 0.995 : 0.9965);
	vec2 streak = vec2(floor(px.x / 3.0), floor(px.y));
	float slot = floor(world_time * 1.8 + hash(streak) * 9.0);
	if (hash(streak + slot * 13.7) > glinting) {
		float middle = mod(floor(px.x), 3.0) == 1.0 ? 0.7 : 0.4;
		water = mix(water, vec3(0.9, 1.0, 1.0), middle);
	}
	// The mire's lily pads, duckweed in its shallows and reeds by its banks;
	// a leaf or two drifting on the Deepwood's lake.
	if (tone == TONE_MIRE) {
		vec4 pad = lily_pad(px, local_px, bend);
		if (pad.a > 0.0) {
			water = pad.rgb;
		} else if (in_water < 9.0 && hash(floor(px) + 0.31) > 0.975 - (9.0 - in_water) * 0.004) {
			water = mix(water, vec3(0.5, 0.62, 0.26), 0.8);
		}
		if (in_water < 7.0) {
			vec4 reed = reeds(px, local_px, bend);
			if (reed.a > 0.0) {
				water = reed.rgb;
			}
		}
	} else if (tone == TONE_DEEP && in_water > 6.0) {
		vec2 drifting = floor(px + vec2(world_time * 0.6, sin(world_time * 0.3) * 1.5));
		vec2 leaf = floor(drifting / 19.0);
		vec2 spot = leaf * 19.0 + floor(vec2(hash(leaf + 2.2), hash(leaf + 4.9)) * 15.0) + 2.0;
		if (hash(leaf + 0.9) > 0.86 && (drifting == spot || drifting == spot + vec2(1.0, 0.0))) {
			water = hash(leaf + 6.6) > 0.5 ? vec3(0.72, 0.52, 0.2) : vec3(0.45, 0.58, 0.22);
		}
	}
	base = water;
	return INLAND_WATER;
}
