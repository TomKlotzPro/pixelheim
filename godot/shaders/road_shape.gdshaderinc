// A country road's ends and turns (PIX-404), for region_tint.gdshader: the
// road's cells, each by its weight in RoadShape's mask (`road_map`, a cell a
// texel from `road_origin`, a map pixel), smoothed into one field by a cubic
// B-spline a cell wide. Its edge rounds a turn's outside, fills its inside
// and narrows a road's last cells to a tip. Where the road meets open ground
// the tone follows it (`road_life`, every layer toned as the ground is), and
// near an end or a turn the ground layer (`road_ground`) draws Shade's dirt
// and grass again to it, in his own colours and his edge's dither.
//
// Included by region_tint.gdshader after its CELL and open_ground.gdshaderinc.

uniform sampler2D road_map : filter_nearest, repeat_disable;
uniform bool road_life = false;
uniform bool road_ground = false;
uniform vec2 road_origin = vec2(0.0);
uniform vec2 road_texels = vec2(1.0);
// The Reach's long straight roads bent gently off their cells (PIX-397:
// seen whole they were a ruler-drawn grid): the field read where a slow
// noise moves it, up to `road_bend` pixels (RoadShape.BENDS, 0 elsewhere)
// on bends ROAD_BENDS cells apart, easing to nothing over ROAD_STILL cells
// by the map's edges (the road runs on straight into the map beside) and
// round each of `road_still` (map pixels: a bridge, the town's gate), where
// it meets what's drawn straight. The grid, and where the hero walks, stay.
uniform float road_bend = 0.0;
uniform vec2 road_still[4];
uniform int road_stills = 0;
const float ROAD_BENDS = 6.0;
const float ROAD_STILL = 3.0;

// Where the field's edge falls: Shade's dirt meets his grass some 5.5 art
// pixels past a straight road's cells (the field's value there), and a
// region's tone changes on the cell's edge (one half).
const float ROAD_GROUND_EDGE = 0.2557;
const float ROAD_TONE_EDGE = 0.5;
// How far either side of the dirt's edge (art pixels) Shade's own pixels are
// kept where they agree with the field: inside it his dither is redrawn.
const float ROAD_KEEP = 2.5;
// Shade's grass, the greens and yellows of his dirt's edge from the grass
// in, and his dirt (display colours).
const vec3 ROAD_INKS[6] = vec3[6](
	vec3(0.522, 0.651, 0.263),
	vec3(0.616, 0.655, 0.278),
	vec3(0.722, 0.686, 0.286),
	vec3(0.718, 0.635, 0.282),
	vec3(0.753, 0.671, 0.290),
	vec3(0.769, 0.698, 0.325)
);

// The mask's texel for map cell `cell` (zero off it).
vec4 road_texel(ivec2 cell) {
	ivec2 at = cell + ivec2(round(-road_origin / CELL));
	if (at.x < 0 || at.y < 0 || at.x >= int(road_texels.x) || at.y >= int(road_texels.y)) {
		return vec4(0.0);
	}
	return texelFetch(road_map, at, 0);
}

// The cubic B-spline's four weights at `f` (0..1 past the second texel) and
// their slopes.
vec4 road_spline(float f) {
	float g = 1.0 - f;
	return vec4(g * g * g, 3.0 * f * f * f - 6.0 * f * f + 4.0, -3.0 * f * f * f + 3.0 * f * f + 3.0 * f + 1.0, f * f * f) / 6.0;
}

vec4 road_slope(float f) {
	return vec4(-(1.0 - f) * (1.0 - f) * 0.5, 1.5 * f * f - 2.0 * f, -1.5 * f * f + f + 0.5, f * f * 0.5);
}

// Where the road's field is read for map pixel `p`: bent off the grid
// (road_bend), on the plane's pixels, so the Reach drawn beside another map
// bends just as it does under the hero.
vec2 road_bent(vec2 p) {
	if (road_bend <= 0.0) {
		return p;
	}
	vec2 cells = (p + map_origin) / CELL / ROAD_BENDS;
	vec2 bend = vec2(value_noise(cells + 5.1), value_noise(cells + 83.7)) * 2.0 - 1.0;
	vec2 inside = min(p, map_pixels - p);
	float away = min(inside.x, inside.y);
	for (int i = 0; i < road_stills; i++) {
		away = min(away, max(distance(p, road_still[i]) - CELL, 0.0));
	}
	return p + bend * road_bend * smoothstep(0.0, ROAD_STILL * CELL, away);
}

// The road's field at map pixel `p`, and its slope per art pixel.
vec3 road_field(vec2 p) {
	p = road_bent(p);
	vec2 at = p / CELL - 0.5;
	vec2 base = floor(at);
	vec2 f = at - base;
	vec4 wx = road_spline(f.x);
	vec4 wy = road_spline(f.y);
	vec4 sx = road_slope(f.x);
	vec4 sy = road_slope(f.y);
	vec3 sum = vec3(0.0);
	for (int j = 0; j < 4; j++) {
		for (int i = 0; i < 4; i++) {
			float w = road_texel(ivec2(base) + ivec2(i - 1, j - 1)).r;
			sum += w * vec3(wx[i] * wy[j], sx[i] * wy[j], wx[i] * sy[j]);
		}
	}
	return vec3(sum.x, sum.yz / CELL);
}

// The cell whose tone the tint mask's texel `texel` (read at map pixel `p`)
// gives way to where the road's field says otherwise: the nearest cell of
// the road's, or of the open ground's, beside it; `texel` as it is where the
// road doesn't meet open ground there.
vec2 road_toned(vec2 texel, vec2 p) {
	if (!road_life) {
		return texel;
	}
	ivec2 cell = ivec2(floor(p / CELL));
	vec4 here = road_texel(cell);
	if (here.a < 0.5) {
		return texel;
	}
	bool road = road_field(p).x > ROAD_TONE_EDGE;
	if (road == (here.r > 0.0) || (road && here.g < 0.5)) {
		return texel;
	}
	float nearest = 1e9;
	vec2 picked = texel;
	for (int dy = -1; dy <= 1; dy++) {
		for (int dx = -1; dx <= 1; dx++) {
			ivec2 step = ivec2(dx, dy);
			vec4 next = road_texel(cell + step);
			if (road ? next.r <= 0.0 : (next.r > 0.0 || next.g < 0.5)) {
				continue;
			}
			vec2 corner = vec2(cell + step) * CELL;
			float away = distance(p, clamp(p, corner, corner + CELL));
			if (away < nearest) {
				nearest = away;
				picked = texel + vec2(step);
			}
		}
	}
	return picked;
}

// Shade's ground pixel `ground` at map pixel `p` drawn again to the road's
// field, near an end or a turn: dirt inside, grass outside, his edge's
// colours dithered across it. His own pixel stays where it agrees with the
// field away from its edge (his grass's tufts, his dirt), and
// anything not his dirt or grass (water, rock) is left alone. A cell of
// open ground the road doesn't turn round only loses dirt, so two roads a
// cell apart don't run together.
vec3 road_ground_at(vec3 ground, vec2 p) {
	vec4 here = road_texel(ivec2(floor(p / CELL)));
	bool grass = is_grass(ground);
	if (here.b < 0.25 || !(grass || is_dirt(ground))) {
		return ground;
	}
	vec3 field = road_field(p);
	float out_px = (ROAD_GROUND_EDGE - field.x) / max(length(field.yz), 0.002);
	if ((grass && out_px > ROAD_KEEP) || (out_px < -ROAD_KEEP && distance(ground, ROAD_INKS[5]) < 0.03)) {
		return ground;
	}
	if (here.r <= 0.0 && here.b < 0.75 && (grass || out_px < 0.0)) {
		return ground;
	}
	float edge = out_px + (art_dither(p) - 0.5) * 1.5;
	int ink = edge > 2.0 ? 0 : edge > 1.0 ? 1 : edge > 0.0 ? 2 : edge > -1.0 ? 3 : edge > -2.0 ? 4 : 5;
	return ROAD_INKS[ink];
}
