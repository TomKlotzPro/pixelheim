shader_type canvas_item;
// Reflections in the water (PIX-223): what stands on a bank - trees, houses,
// the hero, a lamp at night - mirrored upside down into the water below it,
// wavering, fading with the depth from the shore. A pass over the drawn world
// (its screen), between the world and the HUD: on each art pixel of water
// it finds the bank above (PunyTerrain.water_map's green: how many water
// cells lie above) and mixes in what the screen shows mirrored about it.
// Only water takes it: the screen's own colour must look like water, so a
// bridge's planks or the hero wading stay as they are. LightRig passes the
// view and the map: on the Reach's plane (One Reach, PIX-269, step 5) the
// view in the plane's pixels and the water of every map drawn round it,
// laid out from `mirror_origin` (the plane cell at its first texel), so a
// map beside the hero's mirrors its banks too and nothing jumps at a line.
// Inland (PIX-306) the mask's alpha holds the water's code: still pools and
// lakes mirror deeper and steadier than a running river, and the mire's
// murk, olive rather than blue, mirrors in its own tone.

#include "res://shaders/wind.gdshaderinc"
#include "res://shaders/linear.gdshaderinc"

uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform sampler2D water_map : filter_nearest, repeat_disable;
uniform vec2 map_cells = vec2(1.0);
uniform vec2 mirror_origin = vec2(0.0);
// The world under the screen: its top-left corner and size, in pixels.
uniform vec2 view_origin;
uniform vec2 view_size = vec2(320.0, 180.0);
// How deep a reflection reaches from the shore, in pixels, and how strongly
// it shows at the shore.
uniform float reach = 30.0;
uniform float strength = 0.38;

const float TILE = 16.0;
// Shade's water spills about this far past its cells, so a bank's waterline
// stands this far above the cells' edge.
const float SPILL = 4.0;

// Still water mirrors this much deeper and stronger, wavering less.
const float STILL_REACH = 1.5;
const float STILL_STRENGTH = 1.35;
// The mire's tone (PunyTerrain.WATER_MIRE) in the code's high bits.
const int TONE_MIRE = 2;

// Water as drawn, by day or darkened by the night: blue well over red; the
// mire's dark olive murk (a bridge's planks are redder, its lily pads
// lighter).
bool looks_like_water(vec3 c, int tone) {
	if (tone == TONE_MIRE) {
		return c.g >= c.r * 0.95 && c.g > c.b * 0.9 && dot(c, vec3(0.3, 0.6, 0.1)) < 0.4;
	}
	return c.b > 0.12 && c.b > c.r * 1.8 && c.b > c.g * 0.75;
}

void fragment() {
	// Screen UV per rect UV (the canvas may sit letterboxed in the window).
	vec2 per_uv = vec2(dFdx(SCREEN_UV.x) / dFdx(UV.x), dFdy(SCREEN_UV.y) / dFdy(UV.y));
	vec2 px = floor(view_origin + UV * view_size) + 0.5;
	vec2 cell = floor((px + vec2(0.0, SPILL)) / TILE);
	vec4 water = texture(water_map, (cell - mirror_origin + 0.5) / map_cells);
	vec3 seen = to_display(texture(screen, SCREEN_UV).rgb);
	int code = int(round(water.a * 255.0));
	int tone = code / 16;
	bool still = tone > 0 && code % 8 == 0;
	COLOR = vec4(0.0);
	if (water.r > 0.5 && looks_like_water(seen, tone)) {
		float shore = (cell.y - round(water.g * 255.0)) * TILE - SPILL;
		float depth = px.y - shore;
		float deepest = still ? reach * STILL_REACH : reach;
		if (depth < deepest) {
			// A whole-pixel waver, so the mirrored art stays crisp.
			float waver = floor(sin(px.y * 0.7 + world_time * 2.2) * (still ? 0.7 : 1.2) + 0.5);
			vec2 mirrored = vec2(px.x + waver, shore - depth);
			vec2 at = SCREEN_UV + ((mirrored - view_origin) / view_size - UV) * per_uv;
			vec3 image = to_display(texture(screen, at).rgb);
			if (at.y > 0.0 && !looks_like_water(image, tone)) {
				float fade = (1.0 - depth / deepest) * strength * (still ? STILL_STRENGTH : 1.0);
				vec3 tinted = image * (tone == TONE_MIRE ? vec3(0.62, 0.7, 0.55) : vec3(0.62, 0.86, 1.0));
				COLOR = vec4(to_canvas(mix(seen, tinted, fade)), 1.0);
			}
		}
	}
}
