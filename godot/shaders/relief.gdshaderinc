// Light relief (PIX-528, PIX-529): the lamps and the lantern shape the art
// they light, its depth from the forms drawn, never from its pattern (a
// pixel's own light and dark turned the snow, the City's basket paving and
// a stall's stripes into grain). Three forms:
// - carved (RELIEF_CARVED): paving, floors and stone walls, each stone
//   bevelled from its joints, rising from the joint to a flat top within two
//   pixels. A joint is a short run of pixels a step darker than this one
//   (RELIEF_JOINT, or the Medieval Age's stone sets' own step in
//   `relief_joints`, Relief.joints(): 0 there for a tile that is no stone);
//   a dark band wider than that (a wall's face, the dark beyond a room, the
//   air) is none;
// - domed (RELIEF_DOMED): what stands (props, lamps, stalls, crates, trees),
//   rounded from its outline: low by an edge (a texel under half alpha
//   within six pixels), high in the middle;
// - plain (RELIEF_PLAIN): the open ground, water, ice, plaster and cloth,
//   a flat normal and no tap at all.
// Over the form, the art's own tone adds a little (RELIEF_TONE). A shader
// with the relief includes linear.gdshaderinc first, then this, and in its
// fragment() writes
//     NORMAL_MAP = <relief here> ? RELIEF_SHAPE(<form>, <a tile layer>) : RELIEF_FLAT;
// always, both ways: a NORMAL_MAP left unwritten decodes to a skewed normal.
// Writing NORMAL_MAP turns Godot's normal mapping on for good, so light()
// is ours: with the relief off it lights as Godot lights an item with no
// normal map, and every shader writing NORMAL_MAP has it. Its shadows take
// the art's colour (below), as on every floor (frozen, puddles, stair_frost).

// 0 with Light relief off, Lights.RELIEF on (LightRig).
global uniform float relief;
// Each Medieval Age tile's joint step, a texel a tile (Relief.joints()): set
// on the materials that carve its sheet, read only on that sheet.
uniform sampler2D relief_joints : filter_nearest;
// How steep one tone's step makes the surface.
const float RELIEF_K = 20.0;
// Steps of tone under this are the drawing's grain, not its shape: cored out.
const float RELIEF_GRAIN = 0.05;
// A step over the grain shapes up to RELIEF_STEP where it goes down into a
// dark (under RELIEF_DARK: an outline, a beam, a crate's frame), and no more
// than RELIEF_SOFT_STEP between two lit tones (a painted stripe, a speck).
const float RELIEF_STEP = 0.15;
const float RELIEF_SOFT_STEP = 0.02;
const float RELIEF_DARK = 0.10;
// The relief is whole where the light's own falloff (its texture's alpha, 1
// at its heart, 0 at its edge) is over this, and gone at its edge: each light
// by its own reach, the same at any window size.
const float RELIEF_FADE = 0.2;
const vec3 RELIEF_FLAT = vec3(0.5, 0.5, 1.0);
// The forms, as Relief.PLAIN, CARVED and DOMED say them.
const int RELIEF_PLAIN = 0;
const int RELIEF_CARVED = 1;
const int RELIEF_DOMED = 2;
// A tile's pitch in a TileSet's padded copy of its sheet: 16 pixels and a
// copy of its edge each side (use_texture_padding, test_relief).
const float RELIEF_PITCH = 18.0;
// A joint is this much darker than the stone by it (the sandstone's 10%, the
// floors' more), where no step map says otherwise (the CC0 sheets).
const float RELIEF_JOINT = 0.08;
// How steep a stone's bevel is at its joint (half that a pixel further in):
// at 0.45 a lamp 20 px off moved 0.4% of the City's pixels, unseen.
const float RELIEF_CARVE = 1.5;
// A stone no more than five pixels across (a floor brick's height) is too
// thin to carve along that axis: bright and dark rows else.
const float RELIEF_THIN = 0.0;
// How steep a prop's dome is at its outline: its outline is dark, so the
// slope shows a pixel or two inside it, a gentle roundness.
const float RELIEF_DOME = 2.0;
// How much of the old depth from the tone stays over the form.
const float RELIEF_TONE = 0.1;
// The least light a slope turned away keeps: a lamp grazing a bevel far off
// left it black, grain on the cobbles.
const float RELIEF_SHADE_MIN = 0.5;

// A pixel's height: its luminance in linear light, times its alpha.
float relief_h(vec4 c) {
	return dot(to_light(c.rgb), vec3(0.299, 0.587, 0.114)) * c.a;
}

// The texel `off` from the pixel at `uv`, kept on its piece: a sprite's on
// its region on the sheet (`keep` 0; the region snapped to whole texels, as
// the desktop renderer hands it over in half floats), a tile's on its tile of
// the TileSet's padded sheet, clamped (1: a tap past its edge reads the edge,
// so a piece's cut is no outline) or wrapped (2: a fill tiles with itself, so
// a joint on its top row is the row under the tile above's too).
ivec2 relief_texel(vec2 uv, vec2 px, vec4 region, vec2 off, int keep) {
	vec2 texel = floor(uv / px);
	if (keep == 0) {
		vec2 lo = round(region.xy / px);
		return ivec2(clamp(texel + off, lo, lo + round(abs(region.zw) / px) - 1.0));
	}
	vec2 lo = floor(texel / RELIEF_PITCH) * RELIEF_PITCH + 1.0;
	if (keep == 1) {
		return ivec2(clamp(texel + off, lo, lo + 15.0));
	}
	return ivec2(lo + mod(texel + off - lo, 16.0));
}

// How much darker a joint is by the pixel at `uv` on a sheet `sheet` texels
// wide: the Medieval Age's step for its tile on a tile layer (0: no stone),
// RELIEF_JOINT on any other.
float relief_joint(ivec2 sheet, vec2 uv, vec2 px, bool tiles) {
	if (tiles && all(equal(sheet, textureSize(relief_joints, 0) * int(RELIEF_PITCH)))) {
		return texelFetch(relief_joints, ivec2(floor(floor(uv / px) / RELIEF_PITCH)), 0).r;
	}
	return RELIEF_JOINT;
}

// The step from height `b` to `a`, its grain cored out and capped by how dark
// its darker side is.
float relief_step(float a, float b, float grain, float dark) {
	float d = a - b;
	float cap = mix(RELIEF_STEP, RELIEF_SOFT_STEP, smoothstep(0.5 * dark, dark, min(a, b)));
	return clamp(d - clamp(d, -grain, grain), -cap, cap);
}

// The little the tone adds, from the heights left, right, up and down.
vec2 relief_tone(float l, float r, float u, float d) {
	return vec2(relief_step(l, r, RELIEF_GRAIN, RELIEF_DARK), relief_step(d, u, RELIEF_GRAIN, RELIEF_DARK)) * RELIEF_K * RELIEF_TONE;
}

// The normal of a slope (a flipped piece is mirrored on the screen, never in
// its UV: its region's size is negative).
vec3 relief_slope(vec2 slope, vec4 region) {
	return normalize(vec3(slope * sign(region.zw) * relief, 1.0)) * 0.5 + 0.5;
}

// One way out from a pixel of height `c`, the heights 1, 2 and 3 pixels off:
// x how far it bevels down that way (1 by a joint, 0.5 a pixel in), y 1 when
// anything darker by `joint` lies within those 3. A joint is a run of one or
// two pixels darker by `joint` that ends; a longer one is a face or the air.
vec2 relief_ray(float c, vec3 q, float joint) {
	float under = c * (1.0 - joint);
	bool d1 = q.x < under;
	bool d2 = q.y < under;
	bool d3 = q.z < under;
	if (d1 && !(d2 && d3)) {
		return vec2(1.0, 1.0);
	}
	if (!d1 && d2 && !d3) {
		return vec2(0.5, 1.0);
	}
	return vec2(0.0, d1 || d2 || d3 ? 1.0 : 0.0);
}

// A stone's pixel, bevelled from its joints (the heights out left, right,
// up and down): only on a stone's top, never where a neighbour is lighter
// by a step (inside a joint, by its darker corner, on a darker stone by a
// lighter one: specks once), nor along an axis it is too thin on
// (RELIEF_THIN).
vec3 relief_carved(float c, vec3 l, vec3 r, vec3 u, vec3 d, float joint, vec4 region) {
	vec2 form = vec2(0.0);
	if (max(max(l.x, r.x), max(u.x, d.x)) * (1.0 - joint) <= c) {
		vec2 rl = relief_ray(c, l, joint);
		vec2 rr = relief_ray(c, r, joint);
		vec2 ru = relief_ray(c, u, joint);
		vec2 rd = relief_ray(c, d, joint);
		form = vec2((rr.x - rl.x) * (rl.y > 0.0 && rr.y > 0.0 ? RELIEF_THIN : 1.0), (ru.x - rd.x) * (ru.y > 0.0 && rd.y > 0.0 ? RELIEF_THIN : 1.0));
	}
	return relief_slope(form * RELIEF_CARVE + relief_tone(l.x, r.x, u.x, d.x), region);
}

// How low a prop lies by its outline one way: the alphas 1, 2, 4 and 6
// pixels off; the nearer the first one under half, the lower.
float relief_rim(float a1, float a2, float a4, float a6) {
	return a1 < 0.5 ? 6.0 / 7.0 : (a2 < 0.5 ? 5.0 / 7.0 : (a4 < 0.5 ? 3.0 / 7.0 : (a6 < 0.5 ? 1.0 / 7.0 : 0.0)));
}

// A prop's pixel `c`, domed from its outline: its neighbours `l`, `r`, `u`,
// `d`, and the alphas 2, 4 and 6 pixels out each way.
vec3 relief_domed(vec4 c, vec4 l, vec4 r, vec4 u, vec4 d, vec3 la, vec3 ra, vec3 ua, vec3 da, vec4 region) {
	if (c.a < 0.5) {
		return RELIEF_FLAT;
	}
	vec2 rim = vec2(relief_rim(r.a, ra.x, ra.y, ra.z) - relief_rim(l.a, la.x, la.y, la.z), relief_rim(u.a, ua.x, ua.y, ua.z) - relief_rim(d.a, da.x, da.y, da.z));
	return relief_slope(rim * RELIEF_DOME + relief_tone(relief_h(l), relief_h(r), relief_h(u), relief_h(d)), region);
}

// TEXTURE is read here, in the fragment() the macro is written in, never in a
// function of our own (art.md). `keep` as relief_texel's.
#define RELIEF_TAP(dx, dy, keep) texelFetch(TEXTURE, relief_texel(UV, TEXTURE_PIXEL_SIZE, REGION_RECT, vec2(dx, dy), keep), 0)
#define RELIEF_H(dx, dy, keep) relief_h(RELIEF_TAP(dx, dy, keep))
#define RELIEF_RUN(dx, dy, keep) vec3(RELIEF_H(dx, dy, keep), RELIEF_H(2.0 * (dx), 2.0 * (dy), keep), RELIEF_H(3.0 * (dx), 3.0 * (dy), keep))
#define RELIEF_ALPHAS(dx, dy, keep) vec3(RELIEF_TAP(2.0 * (dx), 2.0 * (dy), keep).a, RELIEF_TAP(4.0 * (dx), 4.0 * (dy), keep).a, RELIEF_TAP(6.0 * (dx), 6.0 * (dy), keep).a)
#define RELIEF_JOINT_HERE(tiles) relief_joint(textureSize(TEXTURE, 0), UV, TEXTURE_PIXEL_SIZE, tiles)
#define RELIEF_CARVE_NORMAL(tiles) relief_carved(RELIEF_H(0.0, 0.0, (tiles) ? 2 : 0), RELIEF_RUN(-1.0, 0.0, (tiles) ? 2 : 0), RELIEF_RUN(1.0, 0.0, (tiles) ? 2 : 0), RELIEF_RUN(0.0, -1.0, (tiles) ? 2 : 0), RELIEF_RUN(0.0, 1.0, (tiles) ? 2 : 0), RELIEF_JOINT_HERE(tiles), REGION_RECT)
#define RELIEF_DOME_NORMAL(tiles) relief_domed(RELIEF_TAP(0.0, 0.0, (tiles) ? 1 : 0), RELIEF_TAP(-1.0, 0.0, (tiles) ? 1 : 0), RELIEF_TAP(1.0, 0.0, (tiles) ? 1 : 0), RELIEF_TAP(0.0, -1.0, (tiles) ? 1 : 0), RELIEF_TAP(0.0, 1.0, (tiles) ? 1 : 0), RELIEF_ALPHAS(-1.0, 0.0, (tiles) ? 1 : 0), RELIEF_ALPHAS(1.0, 0.0, (tiles) ? 1 : 0), RELIEF_ALPHAS(0.0, -1.0, (tiles) ? 1 : 0), RELIEF_ALPHAS(0.0, 1.0, (tiles) ? 1 : 0), REGION_RECT)
// The normal for `form` (`tiles`: a tile layer), carved only where the sheet
// has a joint step there; only the branch taken is read.
#define RELIEF_SHAPE(form, tiles) ((form) == RELIEF_DOMED ? RELIEF_DOME_NORMAL(tiles) : ((form) == RELIEF_CARVED && RELIEF_JOINT_HERE(tiles) > 0.0 ? RELIEF_CARVE_NORMAL(tiles) : RELIEF_FLAT))

// Off, or the lightning's flat sky: the light as Godot gives it with no
// normal map (a directional light's alpha is its energy again, as in
// puddles.gdshader). On, a lamp lights each pixel by its slope towards the
// lamp: more on a slope facing it, less on one turned away (never under
// RELIEF_SHADE_MIN), a slope across its light as a flat pixel, so the light
// shapes the art and never dims it as a whole; whole near the lamp and none
// at its light's edge.
void light() {
	float shade = 1.0;
	if (relief > 0.0 && !LIGHT_IS_DIRECTIONAL) {
		// Towards the light and up, whichever way Godot hands it over.
		vec3 to_light = LIGHT_DIRECTION * (LIGHT_DIRECTION.z < 0.0 ? -1.0 : 1.0);
		float lit = 1.0 + dot(NORMAL.xy, to_light.xy) / max(NORMAL.z * to_light.z, 0.05);
		float near = smoothstep(0.0, RELIEF_FADE, LIGHT_COLOR.a);
		shade = clamp(mix(1.0, lit, near * min(relief, 1.0)), RELIEF_SHADE_MIN, 2.0);
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
