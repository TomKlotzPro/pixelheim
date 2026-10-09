shader_type canvas_item;
// Reflections in the water (PIX-223): what stands on a bank - trees, houses,
// the hero, a lamp at night - mirrored upside down into the water below it,
// wavering, fading with the depth from the shore. A pass over the drawn world
// (its screen), between the world and the HUD: on each art pixel of water
// it finds the bank above (PunyTerrain.water_map's green: how many water
// cells lie above) and mixes in what the screen shows mirrored about it.
// Only water takes it: the screen's own colour must look like water, so a
// bridge's planks or the hero wading stay as they are. LightRig passes the
// view and the map.

#include "res://shaders/wind.gdshaderinc"
#include "res://shaders/linear.gdshaderinc"

uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform sampler2D water_map : filter_nearest, repeat_disable;
uniform vec2 map_cells = vec2(1.0);
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

// Water as drawn, by day or darkened by the night: blue well over red.
bool looks_like_water(vec3 c) {
	return c.b > 0.12 && c.b > c.r * 1.8 && c.b > c.g * 0.75;
}

void fragment() {
	// Screen UV per rect UV (the canvas may sit letterboxed in the window).
	vec2 per_uv = vec2(dFdx(SCREEN_UV.x) / dFdx(UV.x), dFdy(SCREEN_UV.y) / dFdy(UV.y));
	vec2 px = floor(view_origin + UV * view_size) + 0.5;
	vec2 cell = floor((px + vec2(0.0, SPILL)) / TILE);
	vec4 water = texture(water_map, (cell + 0.5) / map_cells);
	vec3 seen = to_display(texture(screen, SCREEN_UV).rgb);
	COLOR = vec4(0.0);
	if (water.r > 0.5 && looks_like_water(seen)) {
		float shore = (cell.y - round(water.g * 255.0)) * TILE - SPILL;
		float depth = px.y - shore;
		if (depth < reach) {
			// A whole-pixel waver, so the mirrored art stays crisp.
			float waver = floor(sin(px.y * 0.7 + world_time * 2.2) * 1.2 + 0.5);
			vec2 mirrored = vec2(px.x + waver, shore - depth);
			vec2 at = SCREEN_UV + ((mirrored - view_origin) / view_size - UV) * per_uv;
			vec3 image = to_display(texture(screen, at).rgb);
			if (at.y > 0.0 && !looks_like_water(image)) {
				float fade = (1.0 - depth / reach) * strength;
				COLOR = vec4(to_canvas(mix(seen, image * vec3(0.62, 0.86, 1.0), fade)), 1.0);
			}
		}
	}
}
