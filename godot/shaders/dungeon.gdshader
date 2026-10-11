shader_type canvas_item;
// A dungeon's stone, as its place has worn it (PIX-310, DungeonLook): on its
// floor and walls (and the Medieval Age's floor laid over them), from a mask
// a texel a cell (`cells`: red what the cell is, rock, a wall's top, its
// face or open ground; green how deep the sea lies there; blue how near a
// wall, full in one). Every floor wears in slow patches and cracks between
// its slabs here and there, a lit lip under each crack. Then each look:
// 1 the sea cave: rock in place of cut brick, wet and greened at its foot,
//   drops running down it; damp flags by the walls; shallow pools of the
//   sea seeped in, their shore bent off the grid, stone under the shallows,
//   ripples and glints on them, foam at the edge, rings where drops fall;
// 2 the shafts: rock in its strata, veins of copper and iron in its faces
//   that glint now and then; soot and grit underfoot;
// 3 the cellars: damp and moss along the walls' feet, dust drifted by them;
// 4 the ice cave: rime on the walls' tops, icicles off their faces, frost
//   creeping out over the floor from every wall, a glint here and there;
// 5 the Kings' Vault: gold trim along the walls' faces and studs between,
//   the floor polished in long bands of light, a coin dropped by a wall.
// All in whole pixels of the art; a patch's edge thins in the 2px Bayer
// dither the sea and the ice use, over a narrow band, so it reads as drawn,
// never smudged nor a field of checks.

#include "res://shaders/linear.gdshaderinc"

global uniform float world_time;
uniform sampler2D cells : filter_nearest, repeat_disable;
uniform sampler2D cells_soft : filter_linear, repeat_disable;
uniform vec2 map_pixels;
uniform int look = 0;

varying vec2 world_pos;

const float CELL = 16.0;
const float BAYER[16] = float[16](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0
);
// The sea's shallows and its deeper water, its foam; ripples' light.
const vec3 SHALLOW = vec3(0.34, 0.62, 0.64);
const vec3 DEEP = vec3(0.14, 0.34, 0.44);
const vec3 FOAM = vec3(0.86, 0.95, 0.94);
const vec3 SHEEN = vec3(0.78, 0.94, 0.96);
// How far a pool's shore wanders off the grid, in pixels, and how wide its
// bends; where on the mask's 0..1 its water begins and its foam ends.
const float SHORE_WANDER = 6.0;
const float SHORE_BENDS = 1.2;
const float SHORE = 0.42;
const float FOAM_TO = 0.48;
// Ore in the mine's rock: copper and black iron.
const vec3 COPPER = vec3(0.8, 0.5, 0.26);
const vec3 IRON = vec3(0.44, 0.5, 0.62);
// Moss on the crypt's walls, its dust.
const vec3 MOSS = vec3(0.3, 0.42, 0.3);
const vec3 DUST = vec3(0.8, 0.78, 0.73);
// The ice cave's frost and ice.
const vec3 FROST = vec3(0.9, 0.96, 1.0);
const vec3 ICE = vec3(0.74, 0.88, 0.98);
// The Vault's gold, light, mid and dark.
const vec3 GOLD_LIGHT = vec3(0.98, 0.88, 0.54);
const vec3 GOLD = vec3(0.84, 0.65, 0.33);
const vec3 GOLD_DARK = vec3(0.59, 0.42, 0.23);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec2 hash2(vec2 p) {
	return vec2(hash(p), hash(p + 41.7));
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

// The nearest of a Voronoi's points to `p` (one a unit cell): its cell (x,
// y) and how far `p` lies from the edge with the next (z), in units.
vec3 voronoi(vec2 p) {
	vec2 n = floor(p);
	vec2 f = fract(p);
	vec2 nearest_cell = vec2(0.0);
	vec2 nearest = vec2(8.0);
	float best = 8.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 r = g + hash2(n + g) * 0.8 + 0.1 - f;
			float d = dot(r, r);
			if (d < best) {
				best = d;
				nearest = r;
				nearest_cell = g;
			}
		}
	}
	float edge = 8.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = nearest_cell + vec2(float(i), float(j));
			vec2 r = g + hash2(n + g) * 0.8 + 0.1 - f;
			if (dot(nearest - r, nearest - r) > 0.0001) {
				edge = min(edge, dot(0.5 * (nearest + r), normalize(r - nearest)));
			}
		}
	}
	return vec3(n + nearest_cell, edge);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

// Whether `v` has passed `at`, its edge thinned over a narrow band in the
// dither (`th`): patches whole inside, never a field of checks.
bool inside(float v, float at, float th) {
	return smoothstep(at - 0.035, at + 0.035, v) > th;
}

// Whether a crack runs through pixel `px` (the slabs' edges, in some stretches
// of floor, broken off along their way).
bool cracked(vec2 px) {
	if (value_noise(px / 60.0 + 5.0) < 0.64 || value_noise(px / 7.0 + 2.0) < 0.4) {
		return false;
	}
	return voronoi(px / 24.0).z * 24.0 < 0.7;
}

// Rough rock in place of cut brick: stones of about `size` pixels, each its
// own shade, dark between them.
vec3 rock(vec3 c, vec2 px, float size) {
	vec3 stone = voronoi(px / size);
	c *= mix(0.86, 1.08, hash(stone.xy + 3.3));
	if (stone.z * size < 0.65) {
		c *= 0.74;
	}
	return c;
}

// The sea seeped into a cave: `w` how deep it lies (the mask, read smoothly
// and bent off the grid). The colour of `c` (the stone) under it.
vec3 sea(vec3 c, vec2 px, float w, float th) {
	float luma = dot(c, vec3(0.299, 0.587, 0.114));
	if (w < FOAM_TO) {
		// A rim of foam at the edge, lapping: a pixel of it goes and comes.
		float lap = hash(floor(px) + floor(world_time * 1.4 + hash(floor(px / 3.0)) * 5.0) * 3.1);
		return lap > 0.22 ? FOAM : mix(c, SHALLOW, 0.55);
	}
	bool deep = smoothstep(0.66, 0.84, w) > th;
	vec3 water = deep ? mix(c * 0.45, DEEP, 0.8) : mix(c * 0.75, SHALLOW, 0.72);
	water *= 0.92 + 0.2 * luma;
	// The lip just inside the foam, lighter: the shallows.
	if (w < FOAM_TO + 0.05) {
		water = mix(water, SHALLOW * 1.15, 0.5);
	}
	// Ripples running over it.
	float swell = sin(dot(px, vec2(0.11, 0.29)) * 1.6 - world_time * 1.5 + value_noise(px / 13.0) * 5.0);
	if (swell > 0.9 && hash(floor(px / 2.0) + 7.7) > 0.25) {
		water = mix(water, SHEEN, 0.5);
	}
	// A drop from the roof: a ring spreading where it fell, then gone.
	vec2 spot = floor(px / 24.0);
	float beat = fract(world_time / 3.3 + hash(spot + 1.9));
	vec2 fell = spot * 24.0 + 4.0 + floor(hash2(spot + 5.1) * 16.0);
	float ring = abs(length(floor(px) - fell) - beat * 7.0);
	if (beat < 0.55 && ring < 0.5 && hash(spot + 9.9) > 0.45) {
		water = mix(water, SHEEN, 0.7 * (1.0 - beat / 0.55));
	}
	// A glint: a small cross of light that catches and goes out.
	vec2 at_spot = floor(px / 7.0);
	float flash = floor(world_time * 0.8 + hash(at_spot) * 13.0);
	if (hash(at_spot + flash * 7.31) > 0.99) {
		vec2 at = mod(floor(px), 7.0) - 3.0;
		float off = abs(at.x) + abs(at.y);
		if ((at.x == 0.0 || at.y == 0.0) && off <= 2.0) {
			water = mix(water, vec3(1.0), off < 0.5 ? 0.85 : 0.45);
		}
	}
	return water;
}

// How near a wall pixel `px` lies, read smoothly off the mask (1 in a
// wall, falling away over a cell or so) and bent off the grid.
float nearness(vec2 px) {
	vec2 bend = vec2(value_noise(px / 11.0), value_noise(px / 11.0 + 17.3)) - 0.5;
	return texture(cells_soft, (px + bend * 8.0) / map_pixels).b;
}

vec3 floor_of(vec3 c, vec2 px, float th, vec4 m) {
	// Wear: slow patches trodden darker, others lighter.
	float wear = value_noise(px / 34.0 + 11.0);
	if (inside(wear, 0.7, th)) {
		c *= 0.9;
	} else if (inside(1.0 - wear, 0.76, th)) {
		c *= 1.05;
	}
	// A crack, and the lit lip under it.
	if (cracked(px)) {
		c *= 0.7;
	} else if (cracked(px - vec2(0.0, 1.0))) {
		c *= 1.08;
	}
	if (look == 1) {
		// Damp by the walls, darker and greener.
		if (inside(nearness(px) + value_noise(px / 18.0) * 0.4, 0.78, th)) {
			c *= vec3(0.8, 0.9, 0.92);
		}
		vec2 cells_at = floor(px / 2.0) * 2.0 / CELL / SHORE_BENDS;
		vec2 bend = vec2(value_noise(cells_at), value_noise(cells_at + 17.3)) - 0.5;
		float w = texture(cells_soft, (px + bend * 2.0 * SHORE_WANDER) / map_pixels).g;
		if (w > SHORE) {
			c = sea(c, px, w, th);
		}
	} else if (look == 2) {
		// Soot, and grit.
		if (inside(value_noise(px / 26.0 + 3.0), 0.66, th)) {
			c *= vec3(0.76, 0.72, 0.7);
		}
		if (hash(floor(px)) > 0.975) {
			c *= 0.74;
		}
	} else if (look == 3) {
		// Dust drifted along the walls.
		if (inside(nearness(px) + value_noise(px / 12.0 + 8.0) * 0.4, 0.8, th)) {
			c = mix(c, DUST * dot(c, vec3(0.3, 0.6, 0.1)) * 1.5, 0.3);
		}
	} else if (look == 4) {
		// Frost creeping out from the walls, flecked at its edge.
		float reach = nearness(px) + value_noise(px / 9.0 + 4.0) * 0.45;
		if (inside(reach, 0.78, th)) {
			c = mix(c, FROST, 0.42);
		} else if (inside(reach, 0.66, th) && hash(floor(px)) > 0.6) {
			c = mix(c, FROST, 0.3);
		}
		if (hash(floor(px) + 0.7) > 0.992) {
			c = mix(c, FROST, 0.7);
		}
	} else if (look == 5) {
		// Polish: long bands of light across the slabs.
		float band = fract((px.x - px.y * 0.5) / 96.0);
		if (band < 0.07 && hash(floor(px / 2.0) + 2.2) > 0.25) {
			c *= 1.1;
		}
		// A coin dropped by a wall, glinting now and then.
		if (m.b > 0.4 && hash(floor(px / 3.0) + 6.6) > 0.985 && hash(floor(px)) > 0.5) {
			c = sin(world_time * 2.0 + hash(floor(px / 3.0)) * 30.0) > 0.85 ? GOLD_LIGHT : GOLD;
		}
	}
	return c;
}

vec3 wall_of(vec3 c, vec2 px, vec2 in_cell, bool face, float th) {
	if (look == 1) {
		c = rock(c, px, 5.0);
		c = mix(c, c * vec3(0.84, 0.98, 1.02), 0.6);
		if (face) {
			// Greened and wet at its foot.
			if (in_cell.y > 10.0 && inside(value_noise(px / 6.0), 0.5, th)) {
				c = mix(c, MOSS * 1.1, 0.4);
			}
			// Wet streaks down it, and a drop sliding down one now and then.
			if (value_noise(vec2(px.x / 2.5, px.y / 30.0)) > 0.66) {
				c *= vec3(0.8, 0.9, 0.95);
				float column = floor(px.x);
				float slide = fract(world_time * 0.3 + hash(vec2(column, 3.0)));
				if (hash(vec2(column, 8.0)) > 0.8 && floor(in_cell.y) == floor(slide * CELL)) {
					c = mix(c, SHEEN, 0.6);
				}
			}
		}
	} else if (look == 2) {
		c = rock(c, px, 6.0);
		// The rock's strata, band over band.
		c *= mix(0.92, 1.06, value_noise(vec2(px.x / 70.0, px.y / 5.0)));
		c *= vec3(1.03, 0.98, 0.92);
		// Veins of ore in its faces, and a glint off one.
		if (face && value_noise(px / 9.0 + 40.0) > 0.78 && hash(floor(px)) > 0.62) {
			c = value_noise(px / 30.0) > 0.5 ? COPPER : IRON;
			vec2 nugget = floor(px / 3.0);
			if (hash(nugget) > 0.9 && sin(world_time * 2.3 + hash(nugget + 4.0) * 40.0) > 0.93) {
				c = vec3(1.0, 0.96, 0.84);
			}
		}
	} else if (look == 3) {
		if (face && in_cell.y > 9.0 && inside(value_noise(px / 8.0 + 1.0), 0.58, th)) {
			c = mix(c, MOSS, 0.45);
		}
	} else if (look == 4) {
		c = mix(c, c * vec3(0.9, 0.97, 1.08), 0.6);
		if (!face && inside(value_noise(px / 9.0), 0.6, th)) {
			c = mix(c, FROST, 0.36);
		}
		if (face) {
			// Icicles off the top of the face, each its own length.
			float column = floor(px.x);
			float cell_row = floor(px.y / CELL);
			float hangs = hash(vec2(column, cell_row)) > 0.4 ? floor(hash(vec2(column + 0.5, cell_row)) * 7.0) : 0.0;
			if (in_cell.y < hangs) {
				bool lit = hash(vec2(column - 1.0, cell_row)) <= 0.4 || in_cell.y < 1.0;
				c = floor(in_cell.y) == hangs - 1.0 ? FROST : (lit ? FROST * 0.95 : ICE);
			} else if (in_cell.y < 2.0) {
				c = mix(c, FROST, 0.5);
			}
		}
	} else if (look == 5) {
		c *= vec3(1.04, 1.0, 0.94);
		if (face) {
			// The trim: gold along the face's top and over its plinth, studs
			// between.
			float row = floor(in_cell.y);
			if (row == 1.0 || row == 9.0) {
				c = mod(floor(px.x), 6.0) == 0.0 ? GOLD_LIGHT : GOLD;
			} else if (row == 2.0 || row == 10.0) {
				c = GOLD_DARK;
			} else if (row == 5.0 && mod(floor(px.x) + 4.0, 8.0) == 0.0) {
				c = GOLD;
			}
		}
	}
	return c;
}

void fragment() {
	vec4 base = COLOR;  // already the texel times the modulate
	vec3 c = to_display(base.rgb);
	vec2 px = floor(world_pos) + 0.5;
	ivec2 cell = ivec2(floor(px / CELL));
	vec4 m = texelFetch(cells, cell, 0);
	vec2 in_cell = px - vec2(cell) * CELL - 0.5;
	ivec2 block = ivec2(floor(world_pos / 2.0)) & ivec2(3);
	float th = (BAYER[block.y * 4 + block.x] + 0.5) / 16.0;
	if (look > 0) {
		if (m.r > 0.9) {
			c = floor_of(c, px, th, m);
		} else if (m.r > 0.2) {
			c = wall_of(c, px, in_cell, m.r > 0.5, th);
		}
	}
	COLOR = vec4(to_canvas(c), base.a);
}
