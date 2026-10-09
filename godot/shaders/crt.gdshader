shader_type canvas_item;
// The web's CRT option: a dark line every third screen pixel and a soft
// vignette, laid over everything without touching the art beneath.

#include "res://shaders/linear.gdshaderinc"

uniform float line_strength = 0.16;
uniform float vignette = 0.22;

void fragment() {
	float line = step(2.0, mod(FRAGCOORD.y, 3.0)) * line_strength;
	vec2 centered = SCREEN_UV - 0.5;
	float edge = smoothstep(0.35, 0.75, length(centered)) * vignette;
	COLOR = vec4(0.0, 0.0, 0.0, veil(clamp(line + edge, 0.0, 0.6)));
}
