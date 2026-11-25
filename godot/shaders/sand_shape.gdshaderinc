// Where Saltmere's sand meets its grass and its road (PIX-551), for
// region_tint.gdshader: the sand's cells in SandShape's mask (`sand_map`, a
// cell a texel from `sand_origin`, a map pixel), smoothed into one field by
// the road's cubic B-spline and read where a slow noise bends it, so the
// dunes' edge rounds its cells' stair and wanders off the grid. The ground
// layer (`sand_ground`) draws Shade's sand and grass again to it, in his own
// colours and his edge's dither, whole art pixels; the green strip his dual
// grid leaves between a road and the sand goes. His dirt, his water and his
// waterline are never touched, and the grid, and where the hero walks, stay.
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

// The mask's texel for map cell `cell` (zero off it).
vec4 sand_texel(ivec2 cell) {
	ivec2 at = cell + ivec2(round(-sand_origin / CELL));
	if (at.x < 0 || at.y < 0 || at.x >= int(sand_texels.x) || at.y >= int(sand_texels.y)) {
		return vec4(0.0);
	}
	return texelFetch(sand_map, at, 0);
}

// How far the edge may wander at map pixel `p` (the mask's blue), read
// between the four cells round it, so it eases to Shade's own by rock.
float sand_free(vec2 p) {
	vec2 at = p / CELL - 0.5;
	ivec2 base = ivec2(floor(at));
	vec2 f = at - floor(at);
	float top = mix(sand_texel(base).b, sand_texel(base + ivec2(1, 0)).b, f.x);
	float bottom = mix(sand_texel(base + ivec2(0, 1)).b, sand_texel(base + ivec2(1, 1)).b, f.x);
	return mix(top, bottom, f.y);
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
// grass, sand or their edge (dirt, water, his waterline, rock) is left
// alone. By a road its own edge of dirt stays too, but in the sand, where it
// was the green strip.
vec3 sand_ground_at(vec3 ground, vec2 p) {
	vec4 here = sand_texel(ivec2(floor(p / CELL)));
	if (here.g < 0.25) {
		return ground;
	}
	bool grass = is_grass(ground);
	bool edging = !grass && (distance(ground, SAND_INKS[1]) < 0.03 || distance(ground, SAND_INKS[2]) < 0.03
		|| distance(ground, SAND_FLECKS[0]) < 0.03 || distance(ground, SAND_FLECKS[1]) < 0.03);
	if (!(grass || edging || distance(ground, SAND_INKS[3]) < 0.03)) {
		return ground;
	}
	// On the plane's pixels, so it would run on into a map beside.
	vec2 cells = (p + map_origin) / CELL;
	vec2 bend = (vec2(value_noise(cells / SAND_BENDS + 31.7), value_noise(cells / SAND_BENDS + 47.1)) - 0.5) * 2.0 * SAND_WANDER
		+ (vec2(value_noise(cells / SAND_FRAYS + 3.9), value_noise(cells / SAND_FRAYS + 12.3)) - 0.5) * 2.0 * SAND_FRAY;
	vec3 field = sand_field(p + bend * sand_free(p));
	float out_px = (SAND_EDGE - field.x) / max(length(field.yz), 0.002);
	float edge = out_px + (art_dither(p) - 0.5) * 1.5;
	int ink = edge > 2.0 ? 0 : edge > 1.0 ? 1 : edge > 0.0 ? 2 : 3;
	if ((grass && ink == 0) || (edging && here.g < 0.75 && ink != 3)) {
		return ground;
	}
	return SAND_INKS[ink];
}
