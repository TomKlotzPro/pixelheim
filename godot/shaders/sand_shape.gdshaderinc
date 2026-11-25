// Where Saltmere's sand meets its grass and its road (PIX-551), for
// region_tint.gdshader: the sand's cells in SandShape's mask (`sand_map`, a
// cell a texel from `sand_origin`, a map pixel), smoothed into one field by
// the road's cubic B-spline and read where a slow noise bends it, so the
// dunes' edge rounds its cells' stair and wanders off the grid. The ground
// layer (`sand_ground`) draws Shade's sand and grass again to it, in his own
// colours and his edge's dither, whole art pixels; the green strip his dual
// grid leaves between a road and the sand goes, and the road's own dirt edge
// is drawn again there to the road's field, bent off the grid by a slow
// noise (as the Reach's roads, PIX-397). His water and his waterline are
// never touched, and the grid, and where the hero walks, stay.
//
// Included by region_tint.gdshader after road_shape.gdshaderinc.

uniform sampler2D sand_map : filter_nearest, repeat_disable;
uniform bool sand_ground = false;
uniform vec2 sand_origin = vec2(0.0);
uniform vec2 sand_texels = vec2(1.0);

// Where the field's edge falls: Shade's sand meets his grass some 4.5 art
// pixels past a straight run of its cells (the field's value there), so an
// edge that doesn't wander lies where his does.
const float SAND_EDGE = 0.2965;
// How far the edge wanders either way (art pixels) and how far apart its
// bends are (cells); a smaller, quicker one over it, as his own edge frays.
const float SAND_WANDER = 6.0;
const float SAND_BENDS = 2.3;
const float SAND_FRAY = 1.5;
const float SAND_FRAYS = 0.45;
// Shade's grass, the two inks of his sand's edge from the grass in, and his
// sand (display colours); the two more his edge is flecked with.
const vec3 SAND_INKS[4] = vec3[4](
	vec3(0.522, 0.651, 0.263),
	vec3(0.616, 0.655, 0.278),
	vec3(0.722, 0.686, 0.286),
	vec3(0.788, 0.698, 0.400)
);
const vec3 SAND_FLECKS[2] = vec3[2](vec3(0.718, 0.635, 0.282), vec3(0.776, 0.678, 0.353));
// How far the road's dirt edge wanders out over the sand (art pixels; in, at
// most the road's ROAD_IN, clear of RoadWear's ruts), on bends as the sand's
// own: some 5.5 pixels past the road's cells, it stays inside the sand's.
// Where the mask's alpha is SandShape.WORN_IN (the sea a cell off) only in.
const float SAND_ROAD_OUT = 6.0;
// Shade's dirt and the last ink of its edge, told apart from his ring of wet
// sand at the waterline (3 % off the edge's ink).
const float SAND_DIRT_MATCH = 0.02;

// The mask's texel for map cell `cell` (zero off it).
vec4 sand_texel(ivec2 cell) {
	ivec2 at = cell + ivec2(round(-sand_origin / CELL));
	if (at.x < 0 || at.y < 0 || at.x >= int(sand_texels.x) || at.y >= int(sand_texels.y)) {
		return vec4(0.0);
	}
	return texelFetch(sand_map, at, 0);
}

// The mask at map pixel `p` read between the four cells round it: how far
// the sand's edge may wander there (blue), so it eases to Shade's own by
// rock, and the road's dirt edge (alpha), so it eases to his own where the
// road runs on between grass.
vec4 sand_between(vec2 p) {
	vec2 at = p / CELL - 0.5;
	ivec2 base = ivec2(floor(at));
	vec2 f = at - floor(at);
	vec4 top = mix(sand_texel(base), sand_texel(base + ivec2(1, 0)), f.x);
	vec4 bottom = mix(sand_texel(base + ivec2(0, 1)), sand_texel(base + ivec2(1, 1)), f.x);
	return mix(top, bottom, f.y);
}

// How far past the road's dirt edge map pixel `p` lies, in art pixels (less
// than 0, on the dirt): the road's field read up its slope or down it as a
// slow noise on the plane's pixels goes, a small fray over it, so the edge
// bends out over the sand and a little in (road_worn's way, PIX-397).
float sand_road_out(vec2 p) {
	vec3 field = road_cells_field(p);
	float free = sand_between(p).a;
	if (free > 0.0 && dot(field.yz, field.yz) > 1e-8) {
		vec2 cells = (p + map_origin) / CELL;
		// The fray inside the bend's reach, so it never lies flat on a limit.
		float bend = mix(SAND_FRAY - ROAD_IN, SAND_ROAD_OUT - SAND_FRAY, value_noise(cells / SAND_BENDS + 19.3))
			+ (value_noise(cells / SAND_FRAYS + 7.7) - 0.5) * 2.0 * SAND_FRAY;
		bend = clamp(bend, -ROAD_IN * min(free * 2.0, 1.0), SAND_ROAD_OUT * max(free * 2.0 - 1.0, 0.0));
		field = road_cells_field(p + normalize(field.yz) * bend);
	}
	return (ROAD_GROUND_EDGE - field.x) / max(length(field.yz), 0.002);
}

// The sand's field at map pixel `p`, and its slope per art pixel.
vec3 sand_field(vec2 p) {
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
			float w = sand_texel(ivec2(base) + ivec2(i - 1, j - 1)).r;
			sum += w * vec3(wx[i] * wy[j], sx[i] * wy[j], wx[i] * sy[j]);
		}
	}
	return vec3(sum.x, sum.yz / CELL);
}

// Shade's ground pixel `ground` at map pixel `p` drawn again to the sand's
// field: sand inside, grass outside, his edge's inks dithered across it. His
// grass stays where the field agrees (its tufts), and anything not his
// grass, sand or their edge (water, his waterline, rock) is left alone. On
// sand beside a road the road's dirt is drawn again to its own wandering
// edge first (his dirt kept where it agrees); on grass beside one his dirt
// and its edge stay; in a road's own cell only its green is drawn again.
vec3 sand_ground_at(vec3 ground, vec2 p) {
	vec4 here = sand_texel(ivec2(floor(p / CELL)));
	if (here.g < 0.125) {
		return ground;
	}
	bool grass = is_grass(ground);
	bool edging = !grass && (distance(ground, SAND_INKS[1]) < 0.03 || distance(ground, SAND_INKS[2]) < 0.03
		|| distance(ground, SAND_FLECKS[0]) < 0.03 || distance(ground, SAND_FLECKS[1]) < 0.03);
	bool sand = distance(ground, SAND_INKS[3]) < 0.03;
	bool by_road = here.g < 0.75 && here.r > 0.0;
	// A road's own cell (SandShape.ROADSIDE): its green alone.
	if (here.g < 0.375) {
		if (!grass) {
			return ground;
		}
	} else if (by_road && (grass || edging || sand || distance(ground, ROAD_INKS[4]) < SAND_DIRT_MATCH
			|| distance(ground, ROAD_INKS[5]) < SAND_DIRT_MATCH)) {
		float road = sand_road_out(p) + (art_dither(p) - 0.5) * 1.5;
		if (road < -1.0) {
			return distance(ground, ROAD_INKS[5]) < SAND_DIRT_MATCH ? ground : ROAD_INKS[5];
		}
		if (road < 0.0) {
			return ROAD_INKS[4];
		}
	} else if (!(grass || edging || sand)) {
		return ground;
	}
	// On the plane's pixels, so it would run on into a map beside.
	vec2 cells = (p + map_origin) / CELL;
	vec2 bend = (vec2(value_noise(cells / SAND_BENDS + 31.7), value_noise(cells / SAND_BENDS + 47.1)) - 0.5) * 2.0 * SAND_WANDER
		+ (vec2(value_noise(cells / SAND_FRAYS + 3.9), value_noise(cells / SAND_FRAYS + 12.3)) - 0.5) * 2.0 * SAND_FRAY;
	vec3 field = sand_field(p + bend * sand_between(p).b);
	float out_px = (SAND_EDGE - field.x) / max(length(field.yz), 0.002);
	float edge = out_px + (art_dither(p) - 0.5) * 1.5;
	int ink = edge > 2.0 ? 0 : edge > 1.0 ? 1 : edge > 0.0 ? 2 : 3;
	if ((grass && ink == 0) || (edging && here.g < 0.75 && !by_road && ink != 3)) {
		return ground;
	}
	return SAND_INKS[ink];
}
