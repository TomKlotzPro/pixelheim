// Light relief (PIX-528, PIX-529): the lamps and the lantern shape the art
// they light, its depth from the forms drawn, never from its pattern (a
// pixel's own light and dark turned the snow, the City's basket paving and
// a stall's stripes into grain). Three forms:
// - carved (RELIEF_CARVED): great flags, stone walls and the rampart, each
//   stone bevelled from its joints, rising from the joint to a flat top
//   within two pixels; a course's top and foot fade towards the stone's
//   ends, while an end bevels the stone's full height, only its corner pixel
//   at half (a stone's top its own, never a course's ruled line). A joint is a short run of pixels
//   a step darker than this one (the Medieval Age's stone sets' own step in
//   `relief_joints`, Relief.joints(): 0 there for a tile that is no stone;
//   RELIEF_OTHER_JOINT on any other sheet, none unless the shader asks); a
//   dark band wider than that (a wall's face, the dark beyond a room, the
//   air) is none. A stone five pixels or less across (a wall's thin
//   course) is a pillow instead. Only great stones carve: the cobbles and
//   every set's edge stones (a mottle: hatch strokes round a paving's rim)
//   and the 3-px brick rows (the basket, a room's floor: a corrugation)
//   lie flat (Relief.carved());
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
//
// The rim (PIX-531, a shader that defines RELIEF_RIM before its include: the
// characters, the domed props, the see-through ones): in the dark, each lamp,
// torch, fire or lantern adds a dim tone of its own colour to the edge
// texels of what stands, on its sides and top facing it, near it only. An
// edge texel is an opaque one with a neighbour under half alpha (RIM_OPEN,
// four taps on its piece, set in fragment() as `rim_open = RIM_OPEN(keep);`),
// so the rim is one whole art pixel thick and never outside the silhouette;
// it needs none of the relief's normals and shows with Light relief on or
// off. Nothing by day (the `light_rim` global, LightRig) or at a light's heart.
// Close to a light (PIX-545) the texel just inside the edge lights too,
// dimmer, so a figure by a fire looks lit by it: two art pixels there, one
// far off. Under a clear night's moon (the `sun` global's w) the top edge
// and the moon's side take a faint cool tone, written into COLOR in
// fragment() (`RIM_SKY;` after rim_open is set) and kept out of every
// light's share in light(), so a lamp never brightens it: the moon is the
// base, a lamp's warm rim takes over near the lamp. And a storm's lightning
// rims the top edge white-blue, the sides at half, for as long as its flash
// (the `rim_flash` global, Storm: none for the soft flash of Reduce motion).

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
// floors' more): the CC0 dungeons' stone's (dungeon.gdshader).
const float RELIEF_JOINT = 0.08;
// The joint step on a sheet with no step map (the CC0 sheets): none, so their
// tile layers lie flat (a ruin's and a CC0 room's thin bricks turned to a
// checker), unless the shader defines it before its include
// (dungeon.gdshader: the dungeons' stone reads clean).
#ifndef RELIEF_OTHER_JOINT
#define RELIEF_OTHER_JOINT 0.0
#endif
// How steep a stone's bevel is at its joint (half that a pixel further in):
// at 0.45 a lamp 20 px off moved 0.4% of the City's pixels, unseen; at 1.5
// with its courses whole they read as ruled lines.
const float RELIEF_CARVE = 1.2;
// A course's joint runs on across the paving: its bevels (a stone's top and
// foot) a third as steep as a stone's ends, or the courses read as stripes
// (0.7: a course's top +7 levels over half the City's square; 0.5: the gate
// road's one-stone strip under the lantern a ladder's rungs).
const float RELIEF_COURSE = 0.35;
// How steep a small stone's pillow is by its joints (a wall's thin course;
// the basket's and the floors' 3-px rows were a corrugation at 0.4, ruled
// stripes at 0.8: they lie flat).
const float RELIEF_PILLOW = 0.4;
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
// so a piece's cut is no outline) or, carved (2), clamped across (its
// tiles are laid at random, and at the paving's edge the column wrapped
// round drew a joint that isn't there) and wrapped down (its courses run
// on: a joint on its top row is the row under the tile above's too).
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
	return ivec2(vec2(clamp(texel.x + off.x, lo.x, lo.x + 15.0), lo.y + mod(texel.y + off.y - lo.y, 16.0)));
}

// How much darker a joint is by the pixel at `uv` on a sheet `sheet` texels
// wide: the Medieval Age's step for its tile on a tile layer (0: no stone),
// RELIEF_OTHER_JOINT on any other.
float relief_joint(ivec2 sheet, vec2 uv, vec2 px, bool tiles) {
	if (tiles && all(equal(sheet, textureSize(relief_joints, 0) * int(RELIEF_PITCH)))) {
		return texelFetch(relief_joints, ivec2(floor(floor(uv / px) / RELIEF_PITCH)), 0).r;
	}
	return RELIEF_OTHER_JOINT;
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
// lighter one: specks once). A stone no more than five pixels across either
// way (a brick's 3-px row) is a pillow: each pixel sloped from the nearest
// joint on each axis, whole, at RELIEF_PILLOW, but not across a stone of two
// pixels or less (carved as a big stone, only each brick's end showed, a
// mark; left flat, the bricks were; every pixel of a tiny stone sloped was
// grain). On a bigger stone an end's bevel runs the stone's whole height,
// only its corner pixel faded (faded two pixels in from each course, a
// 2-3 px pill was left mid-height: rows of rivets on the squares), and a
// course's fades towards the stone's ends, so its tops are each stone's,
// never one bright line.
vec3 relief_carved(float c, vec3 l, vec3 r, vec3 u, vec3 d, float joint, vec4 region) {
	vec2 form = vec2(0.0);
	if (max(max(l.x, r.x), max(u.x, d.x)) * (1.0 - joint) <= c) {
		vec2 rl = relief_ray(c, l, joint);
		vec2 rr = relief_ray(c, r, joint);
		vec2 ru = relief_ray(c, u, joint);
		vec2 rd = relief_ray(c, d, joint);
		vec2 bevel = vec2(rr.x - rl.x, ru.x - rd.x);
		if ((rl.y > 0.0 && rr.y > 0.0) || (ru.y > 0.0 && rd.y > 0.0)) {
			form = bevel * vec2(min(rl.x, rr.x) < 0.5 ? RELIEF_PILLOW : 0.0, min(ru.x, rd.x) < 0.5 ? RELIEF_PILLOW : 0.0);
		} else {
			form = bevel * vec2(max(ru.x, rd.x) < 1.0 ? 1.0 : 0.5, (1.0 - max(rl.x, rr.x)) * RELIEF_COURSE) * RELIEF_CARVE;
		}
	}
	return relief_slope(form + relief_tone(l.x, r.x, u.x, d.x), region);
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

#ifdef RELIEF_RIM
// 0 by day, Lights.RIM in the dark (LightRig.rim_strength). Not `rim`:
// relief_domed's local of that name then read the global, and the web's
// shader failed to compile.
global uniform float light_rim;
// Which sides of this texel lie open (1 where the neighbour left, right, up
// or down on the screen is under half alpha), from fragment() to light();
// light() lights no foot (below), but a piece flipped upside down needs it.
// 1 for the edge texel itself, 0.5 for the one just inside it (PIX-545).
varying vec4 rim_open;
// The moon (w) and the lightning's flash now (LightRig.flash_rim), and the
// moon's tone as fragment() added it to COLOR, for light() to leave out.
global uniform vec4 sun;
global uniform float rim_flash;
varying vec3 rim_sky;
// How bright the rim is, a share of the light's own colour and energy, and
// the most of the light's colour it adds on the screen: a dim tone of the
// light, never its glass (a forge's fires, stronger than a lamp, edged its
// furnaces in salmon).
const float RIM_GLOW = 2.0;
const float RIM_MOST = 0.45;
// How squarely an open side must face the light before it lights (0: a side
// lit as soon as the light is anywhere on its half; a sprite sparkled).
const float RIM_TURN = 0.25;
// The rim is whole where the light's falloff (its texture's alpha, 1 at its
// heart, 0 at its edge) is over RIM_NEAR and gone under RIM_FAR: near a
// light only (by the relief's whole reach, a prop between a window and a
// lamp across the square took a rim from each, a ruled outline).
const float RIM_FAR = 0.2;
const float RIM_NEAR = 0.5;
// No rim where the light's falloff is over this: at its heart, light from
// all round (a lamp's own glass, the hero's own lantern at their feet).
const float RIM_HEART = 0.85;
// The texel just inside the edge lights at RIM_INNER of the edge's, whole
// where the light's falloff is over RIM_INNER_NEAR and none under
// RIM_INNER_FAR: close to a lamp or a fire only.
const float RIM_INNER = 0.6;
const float RIM_INNER_FAR = 0.35;
const float RIM_INNER_NEAR = 0.55;
// The moon's tone (the roofs', roof_light) and how much of it the edge
// takes before the night's own light dims it; it falls from the upper left,
// as the roofs' moon does.
const vec3 RIM_MOON = vec3(0.7, 0.82, 1.0);
const float RIM_MOON_GLOW = 0.35;
// The lightning's share of its own colour on a top edge at the flash's height.
const float RIM_FLASH = 0.8;

// The open sides as the screen shows them: a flipped piece is mirrored on
// the screen, never in its UV (its region's size is negative).
vec4 rim_sides(vec4 a, vec4 a2, vec4 region) {
	vec4 open = step(a, vec4(0.5));
	open += 0.5 * (1.0 - open) * step(a2, vec4(0.5));
	if (region.z < 0.0) {
		open.xy = open.yx;
	}
	if (region.w < 0.0) {
		open.zw = open.wz;
	}
	return open;
}

// This texel's open sides (none for a texel under half alpha, or by day),
// its taps kept on its piece (`keep` as relief_texel's: a frame's or a
// piece's cut is no edge). So a side drawn flush with its piece's cut is
// never rimmed: read past the region as air, a boarded ruin's long straight
// side took a ruled line. TEXTURE is read inline, in fragment().
#define RIM_OPEN(keep) (light_rim > 0.0 && RELIEF_TAP(0.0, 0.0, keep).a >= 0.5 ? rim_sides(vec4(RELIEF_TAP(-1.0, 0.0, keep).a, RELIEF_TAP(1.0, 0.0, keep).a, RELIEF_TAP(0.0, -1.0, keep).a, RELIEF_TAP(0.0, 1.0, keep).a), vec4(RELIEF_TAP(-2.0, 0.0, keep).a, RELIEF_TAP(2.0, 0.0, keep).a, RELIEF_TAP(0.0, -2.0, keep).a, 1.0), REGION_RECT) : vec4(0.0))

// How dark a texel is shown: a dark edge (Shade's outline) takes a rim
// whole, a light one less.
float rim_dark(vec3 c) {
	return 1.0 - clamp(dot(to_display(c), vec3(0.299, 0.587, 0.114)), 0.0, 1.0);
}

// What the moon adds to the edge texel `c`: on its top and its left.
vec3 rim_moon(vec4 open, vec3 c) {
	float lit = max(step(0.75, open.x), step(0.75, open.z)) * light_rim * clamp(sun.w, 0.0, 1.0);
	return lit > 0.0 ? to_canvas(to_display(c) + RIM_MOON * RIM_MOON_GLOW * lit * rim_dark(c)) - c : vec3(0.0);
}

// In fragment(), once rim_open is set and COLOR is final.
#define RIM_SKY rim_sky = rim_moon(rim_open, COLOR.rgb); COLOR.rgb += rim_sky
#endif

// Off, or the lightning's flat sky: the light as Godot gives it with no
// normal map (a directional light's alpha is its energy again, as in
// puddles.gdshader). On, a lamp lights each pixel by its slope towards the
// lamp: more on a slope facing it, less on one turned away (never under
// RELIEF_SHADE_MIN), a slope across its light as a flat pixel, so the light
// shapes the art and never dims it as a whole; whole near the lamp and none
// at its light's edge.
void light() {
	float shade = 1.0;
	// Towards the light and up, whichever way Godot hands it over.
	vec3 to_light = LIGHT_DIRECTION * (LIGHT_DIRECTION.z < 0.0 ? -1.0 : 1.0);
	if (relief > 0.0 && !LIGHT_IS_DIRECTIONAL) {
		float lit = 1.0 + dot(NORMAL.xy, to_light.xy) / max(NORMAL.z * to_light.z, 0.05);
		float near = smoothstep(0.0, RELIEF_FADE, LIGHT_COLOR.a);
		shade = clamp(mix(1.0, lit, near * min(relief, 1.0)), RELIEF_SHADE_MIN, 2.0);
	}
#ifdef RELIEF_RIM
	// The art without the moon's tone: no light brightens that.
	vec3 art = COLOR.rgb - rim_sky;
#else
	vec3 art = COLOR.rgb;
#endif
	LIGHT = vec4(LIGHT_COLOR.rgb * art * LIGHT_ENERGY * shade, LIGHT_IS_DIRECTIONAL ? 1.0 : LIGHT_COLOR.a);
#ifdef RELIEF_RIM
	vec4 edge = step(vec4(0.75), rim_open);
	// The rim (PIX-531): an open side facing this light takes its colour,
	// by how squarely it faces it and the light's own falloff (LIGHT.a
	// again, as Godot blends it), none at the light's heart. Only the sides
	// and the top: a light lower on the screen stands in front, between us
	// and what it lights, and lights its face, no rim (rimmed, a lamp's own
	// lanterns took a ruled line along their feet from its pool below them).
	// A dark edge (the outline Shade draws round a figure) takes it whole, a
	// light one less: added whole, a forge's furnaces turned near white
	// where they faced each other's fire, and the glow bloomed it.
	if (light_rim > 0.0 && !LIGHT_IS_DIRECTIONAL) {
		vec2 way = to_light.xy / max(length(to_light.xy), 0.0001);
		float facing = max(max(-way.x * edge.x, way.x * edge.y), -way.y * edge.z);
		vec4 inner = step(vec4(0.25), rim_open) - edge;
		float within = max(max(-way.x * inner.x, way.x * inner.y), -way.y * inner.z);
		float turned = smoothstep(RIM_TURN, 1.0, facing) + RIM_INNER * smoothstep(RIM_INNER_FAR, RIM_INNER_NEAR, LIGHT_COLOR.a) * smoothstep(RIM_TURN, 1.0, within);
		float reach = smoothstep(RIM_FAR, RIM_NEAR, LIGHT_COLOR.a) * (1.0 - smoothstep(RIM_HEART - 0.1, RIM_HEART, LIGHT_COLOR.a));
		float dark_edge = rim_dark(art);
		// What it adds on the screen, where Godot multiplies it by LIGHT.a:
		// a tone of the light's shown colour, turned into the canvas's light
		// (exact over the dark outline; added raw on the desktop's linear
		// canvas, RIM_MOST showed about 0.7 of the light, not 0.45).
		float shown = min(LIGHT_ENERGY * RIM_GLOW * light_rim * turned * reach * LIGHT_COLOR.a, RIM_MOST);
		LIGHT.rgb += to_canvas(to_display(LIGHT_COLOR.rgb) * shown * dark_edge * COLOR.a) / max(LIGHT_COLOR.a, 0.001);
	}
	// The lightning (PIX-545): its sky lights every top edge, the sides at
	// half, as bright as the flash is now.
	if (LIGHT_IS_DIRECTIONAL && rim_flash > 0.0) {
		float top = max(edge.z, 0.5 * max(edge.x, edge.y));
		LIGHT.rgb += to_canvas(to_display(LIGHT_COLOR.rgb) * RIM_FLASH * rim_flash * top * rim_dark(art) * COLOR.a);
	}
#endif
	// A night shadow (PIX-528): Godot blends a shadowed pixel from this light
	// to the light's shadow colour, which never met the art's own colour, so
	// over ground darker than about 0.43 a shadow's soft edge came out
	// brighter than both the lit ground and the shadow, a light outline.
	// The art's colour carried into it, only the alpha falls across the edge:
	// a shadow is a share of the light on any ground (NightShadows.DEPTH).
	SHADOW_MODULATE.rgb = art * shade * max(LIGHT_ENERGY, 1.0);
}
