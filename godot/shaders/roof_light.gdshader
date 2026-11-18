// The houses' roofs take the light (PIX-523, PunyTown.roof_light): each
// pixel of a roof piece lies on a slope (PunyTown.roof_slopes, a texel per
// tile of the atlas in `slopes`; a ridge piece's two halves on the two
// slopes), and the slope facing the sun (global `sun`, DayNight.sun) is
// lifted and warmed as the sun goes low while the other falls into a cool
// shade; under the moon (`sun.w`, LightRig) the slope facing it takes a
// cool light. No line is drawn along a ridge or an edge: a ruled stripe
// read as paint, not light (Tom, 2026-11-17). Walls,
// windows and doors are no roof pieces and stay as drawn, and so does what
// a roof's colour copies share (a gable's plaster and beam under its eave).
// Nothing is darkened by the night here: the night's dark is the
// LightRig's (PIX-330). Whole art pixels, as drawn.
shader_type canvas_item;

#include "res://shaders/linear.gdshaderinc"
#include "res://shaders/relief.gdshaderinc"

global uniform vec4 sun;
// Per atlas tile: r its slope (PunyTown.SLOPE_*, + EDGE_TOP), g how many
// rows down its copy in another roof colour lies (+128).
uniform sampler2D slopes : filter_nearest;
uniform float columns = 220.0;

const float TILE = 16.0;
// Where a ridge piece's ridge runs, from its tile's top left.
const float RIDGE = 8.0;
// The moon stands where the sun does (Shade's light, upper left), when
// there is no sun to say so.
const vec2 MOON_FROM = vec2(-0.94, -0.34);
// What the sunny slope gains (the other loses) with the sun high, and low.
const float SLOPE_HIGH = 0.1;
const float SLOPE_LOW = 0.24;
const vec3 GOLD = vec3(1.0, 0.82, 0.55);
const vec3 MOON = vec3(0.7, 0.82, 1.0);
const float SLOPE_MOON = 0.12;

void fragment() {
	vec2 sheet = 1.0 / TEXTURE_PIXEL_SIZE;
	// 16 pixels a tile, or 18 in the TileSet's padded copy of the sheet.
	float pitch = floor(sheet.x / columns + 0.5);
	vec2 texel = floor(UV * sheet);
	vec2 tile = floor(texel / pitch);
	vec2 at = texel - tile * pitch - (pitch - TILE) * 0.5;
	vec2 code = floor(texelFetch(slopes, ivec2(tile), 0).rg * 255.0 + 0.5);
	int kind = int(code.x);
	bool roof = false;
	if (kind > 0 && COLOR.a > 0.0) {
		vec4 copy = texelFetch(TEXTURE, ivec2(texel + vec2(0.0, (code.y - 128.0) * pitch)), 0);
		roof = any(notEqual(texelFetch(TEXTURE, ivec2(texel), 0), copy));
		if (roof) {
			kind = kind % 8;
			// The slope this pixel lies on, as it faces in the plane.
			vec2 face = kind == 1 ? vec2(-1.0, 0.0) : (kind == 2 ? vec2(1.0, 0.0) : (kind == 3 ? vec2(0.0, -1.0) : vec2(0.0, 1.0)));
			if (kind == 5) {
				face = vec2(at.x < RIDGE ? -1.0 : 1.0, 0.0);
			} else if (kind == 6) {
				face = vec2(0.0, at.y < RIDGE ? -1.0 : 1.0);
			}
			vec3 rgb = to_display(COLOR.rgb);
			float day = clamp(sun.z, 0.0, 1.0);
			float reach = length(sun.xy);
			float low = smoothstep(0.4, 1.4, reach);
			vec2 from = reach > 0.0 ? -sun.xy / reach : MOON_FROM;
			float facing = dot(face, from);
			float slope = facing * mix(SLOPE_HIGH, SLOPE_LOW, low) * day;
			vec3 warm = mix(vec3(1.0), GOLD, low);
			// The shaded slope loses less blue than red and green: a cool shade.
			rgb *= 1.0 + slope * (slope > 0.0 ? warm : vec3(1.0, 1.0, 0.85));
			float moon = clamp(sun.w, 0.0, 1.0);
			rgb *= 1.0 + MOON * max(facing, 0.0) * SLOPE_MOON * moon;
			COLOR.rgb = to_canvas(rgb);
		}
	}
	// Light relief (PIX-528): a wall's plaster grain cored out more than a
	// roof's, so it reads plastered, its beams, frames and stones shaped.
	if (relief > 0.0) {
		NORMAL_MAP = RELIEF_NORMAL(roof ? RELIEF_GRAIN : RELIEF_WALL_GRAIN);
	} else {
		NORMAL_MAP = RELIEF_FLAT;
	}
}
