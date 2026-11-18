// Light relief (PIX-528): the lamps and the lantern shape the art they light.
// A pixel's height is its own light and dark (the outline sits low, the
// highlight high) times its alpha; its slope between its four neighbours is
// the normal (NORMAL_MAP) a light takes it by, in light() below. A shader
// with the relief includes linear.gdshaderinc first, then this, and in its
// fragment() writes
//     NORMAL_MAP = <relief here> ? RELIEF_NORMAL(<grain>, <dark>, <a sprite>) : RELIEF_FLAT;
// always, both ways: a NORMAL_MAP left unwritten decodes to a skewed normal.
// Writing NORMAL_MAP turns Godot's normal mapping on for good, so light()
// is ours: with the relief off it lights as Godot lights an item with no
// normal map, and every shader writing NORMAL_MAP has it. Its shadows take
// the art's colour (below), as on every floor (frozen, puddles, stair_frost).

// 0 with Light relief off, Lights.RELIEF on (LightRig).
global uniform float relief;
// How steep one tone's step makes the surface.
const float RELIEF_K = 20.0;
// Steps of tone under this are the drawing's grain, not its shape: cored out,
// so a prop's mottling doesn't turn to pebbles. The ground (snow, grass,
// cobbles, paving, a room's floor) and a wall's plaster, more.
const float RELIEF_GRAIN = 0.05;
const float RELIEF_SOFT_GRAIN = 0.07;
// A step over the grain shapes up to RELIEF_STEP where it goes down into a
// dark (an outline, a beam, a crate's frame, the joint between two stones,
// a sprite's own edge: the art's shape), and no more than RELIEF_SOFT_STEP
// between two lit tones (a stall's painted stripe, a speck on the snow, the
// plaster's mottling), which would split into a lit and a dark column. Dark
// is under RELIEF_DARK on a prop, a house or a dungeon, where a stall's red
// stripe is no shape; under RELIEF_GROUND_DARK on the ground, where the
// joints between cobbles are as light as that stripe and the snow's specks
// lighter still.
const float RELIEF_STEP = 0.15;
const float RELIEF_SOFT_STEP = 0.02;
const float RELIEF_DARK = 0.10;
const float RELIEF_GROUND_DARK = 0.25;
// The relief is whole where the light's own falloff (its texture's alpha, 1
// at its heart, 0 at its edge) is over this, and gone at its edge: each light
// by its own reach, the same at any window size.
const float RELIEF_FADE = 0.2;
const vec3 RELIEF_FLAT = vec3(0.5, 0.5, 1.0);

// A pixel's height: its luminance in linear light, times its alpha.
float relief_h(vec4 c) {
	return dot(to_light(c.rgb), vec3(0.299, 0.587, 0.114)) * c.a;
}

// A neighbour's UV. On a sprite (`cut`) kept inside the piece's own region
// on its sheet, or it would read the next piece; the region is snapped to
// whole texels, as the desktop renderer hands it over in half floats. Not on
// a tile layer: its TileSet pads each tile with copies of its edge, and on a
// wide sheet those half floats can miss a tile's edge by a texel, which would
// leave its edge column flat, a line along every tile.
vec2 relief_uv(vec2 uv, vec2 off, vec2 px, vec4 region, bool cut) {
	vec2 at = uv + off * px;
	if (!cut) {
		return at;
	}
	vec2 lo = round(region.xy / px) * px;
	vec2 hi = lo + round(abs(region.zw) / px) * px;
	return clamp(at, lo + 0.5 * px, hi - 0.5 * px);
}

// The step from height `b` to `a`, its grain cored out and capped by how dark
// its darker side is.
float relief_step(float a, float b, float grain, float dark) {
	float d = a - b;
	float cap = mix(RELIEF_STEP, RELIEF_SOFT_STEP, smoothstep(0.5 * dark, dark, min(a, b)));
	return clamp(d - clamp(d, -grain, grain), -cap, cap);
}

// The normal from the heights left, right, up and down. A flipped piece is
// mirrored on the screen, never in its UV (its region's size is negative).
vec3 relief_normal(float l, float r, float u, float d, float grain, float dark, vec4 region) {
	vec2 slope = vec2(relief_step(l, r, grain, dark), relief_step(d, u, grain, dark)) * sign(region.zw);
	return normalize(vec3(slope * RELIEF_K * relief, 1.0)) * 0.5 + 0.5;
}

// TEXTURE is read here, in the fragment() the macro is written in, never in a
// function of our own (art.md).
#define RELIEF_TAP(dx, dy, cut) relief_h(texture(TEXTURE, relief_uv(UV, vec2(dx, dy), TEXTURE_PIXEL_SIZE, REGION_RECT, cut)))
#define RELIEF_NORMAL(grain, dark, cut) relief_normal(RELIEF_TAP(-1.0, 0.0, cut), RELIEF_TAP(1.0, 0.0, cut), RELIEF_TAP(0.0, -1.0, cut), RELIEF_TAP(0.0, 1.0, cut), grain, dark, REGION_RECT)

// Off, or the lightning's flat sky: the light as Godot gives it with no
// normal map (a directional light's alpha is its energy again, as in
// puddles.gdshader). On, a lamp lights each pixel by its slope towards the
// lamp: more on a slope facing it, less on one turned away, a slope across
// its light as a flat pixel, so the light shapes the art and never dims it
// as a whole; whole near the lamp and none at its light's edge.
void light() {
	float shade = 1.0;
	if (relief > 0.0 && !LIGHT_IS_DIRECTIONAL) {
		// Towards the light and up, whichever way Godot hands it over.
		vec3 to_light = LIGHT_DIRECTION * (LIGHT_DIRECTION.z < 0.0 ? -1.0 : 1.0);
		float lit = 1.0 + dot(NORMAL.xy, to_light.xy) / max(NORMAL.z * to_light.z, 0.05);
		float near = smoothstep(0.0, RELIEF_FADE, LIGHT_COLOR.a);
		shade = clamp(mix(1.0, lit, near * min(relief, 1.0)), 0.0, 2.0);
	}
	LIGHT = vec4(LIGHT_COLOR.rgb * COLOR.rgb * LIGHT_ENERGY * shade, LIGHT_IS_DIRECTIONAL ? 1.0 : LIGHT_COLOR.a);
	// A night shadow (PIX-528): Godot blends a shadowed pixel from this light
	// to the light's shadow colour, which never met the art's own colour, so
	// over ground darker than about 0.43 a shadow's soft edge came out
	// brighter than both the lit ground and the shadow, a light outline.
	// The art's colour carried into it, only the alpha falls across the edge:
	// a shadow is a share of the light on any ground (NightShadows.DEPTH).
	SHADOW_MODULATE.rgb = COLOR.rgb * shade * max(LIGHT_ENERGY, 1.0);
}
