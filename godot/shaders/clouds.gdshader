shader_type canvas_item;
// Cloud shadows drifting over the open land by day (PIX-223): a seamless
// noise laid on the world (not the screen, so the shadows stay on the ground
// as the camera moves), drifting on the world's clock. Each art pixel is
// shaded whole, and a shadow's soft rim is dithered in 2px blocks like the
// regions' edges: retro, never a smudge. LightRig passes the view and the
// shadows' `depth`, none indoors, underground or at night.

#include "res://shaders/wind.gdshaderinc"

uniform sampler2D clouds : filter_linear, repeat_enable;
// The world under the screen: its top-left corner and size, in pixels.
uniform vec2 view_origin;
uniform vec2 view_size = vec2(320.0, 180.0);
// How big the clouds are (pixels of world per noise tile) and how fast and
// which way they drift (pixels per second of the world's clock).
uniform float scale = 760.0;
uniform vec2 drift = vec2(7.0, 2.5);
// The shadow's colour and how dark it is at its heart; the noise level it
// starts at and is full at.
uniform vec3 shade = vec3(0.08, 0.1, 0.22);
uniform float depth = 0.2;
uniform float edge_from = 0.57;
uniform float edge_to = 0.7;

const float BAYER[16] = float[16](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0
);

void fragment() {
	vec2 px = floor(view_origin + UV * view_size);
	float cover = texture(clouds, (px - drift * world_time) / scale).r;
	float shadow = smoothstep(edge_from, edge_to, cover);
	// The rim in four steps, dithered between them.
	ivec2 block = ivec2(floor(px / 2.0)) & ivec2(3);
	float threshold = (BAYER[block.y * 4 + block.x] + 0.5) / 16.0;
	float stepped = floor(shadow * 4.0 + threshold) / 4.0;
	COLOR = vec4(shade, stepped * depth);
}
