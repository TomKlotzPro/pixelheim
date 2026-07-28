shader_type canvas_item;
// Ground terrain blender: one quad under the whole map. Each fragment looks
// up its tile's terrain id, but the lookup position is warped by Voronoi
// noise, so borders between ground types meander instead of following the
// tile grid. A second, larger noise octave varies brightness so wide fields
// don't read as flat fills.

uniform sampler2D id_map : filter_nearest;
uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform sampler2D fill_grass : filter_nearest, repeat_enable;
uniform sampler2D fill_dirt : filter_nearest, repeat_enable;
uniform sampler2D fill_gravel : filter_nearest, repeat_enable;
uniform sampler2D fill_marsh : filter_nearest, repeat_enable;
uniform sampler2D fill_sand : filter_nearest, repeat_enable;
uniform vec2 map_size;            // in tiles
uniform float border_warp = 0.45; // tiles of boundary wobble
uniform float warp_scale = 0.11;  // noise uv per tile, border octave
uniform float shade_scale = 0.045; // noise uv per tile, brightness octave
uniform float shade_depth = 0.14;

vec4 fill_color(int id, vec2 tile_uv) {
	if (id == 1) {
		return texture(fill_dirt, tile_uv);
	} else if (id == 2) {
		return texture(fill_gravel, tile_uv);
	} else if (id == 3) {
		return texture(fill_marsh, tile_uv);
	} else if (id == 4) {
		return texture(fill_sand, tile_uv);
	}
	return texture(fill_grass, tile_uv);
}

void fragment() {
	vec2 tile_pos = UV * map_size;
	vec2 warp = vec2(
		texture(noise_tex, tile_pos * warp_scale).r,
		texture(noise_tex, tile_pos * warp_scale + vec2(0.37, 0.71)).r
	);
	vec2 lookup = tile_pos + (warp - 0.5) * 2.0 * border_warp;
	lookup = clamp(lookup, vec2(0.0), map_size - vec2(0.001));
	int id = int(texelFetch(id_map, ivec2(lookup), 0).r * 255.0 + 0.5);
	vec4 color = fill_color(id, fract(tile_pos));
	float shade = texture(noise_tex, tile_pos * shade_scale + vec2(0.13, 0.57)).r;
	color.rgb *= 1.0 - shade_depth * 0.5 + shade_depth * shade;
	COLOR = color;
}
