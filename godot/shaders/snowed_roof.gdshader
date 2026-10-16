// A roof under the Frostgate's snow (PIX-313): Shade's roof, whatever its
// colour, laid over with snow in his whites and cold blues by how light
// each of its pixels is, so its shingles and its outline still show as
// blue shadow under the white; the eave's bottom pixel row drips a little
// darker. Whole art pixels, as drawn: nothing blurs.
shader_type canvas_item;

#include "res://shaders/linear.gdshaderinc"

uniform vec3 snow : source_color = vec3(0.96, 0.98, 1.0);
uniform vec3 shadow : source_color = vec3(0.72, 0.8, 0.88);
uniform vec3 deep : source_color = vec3(0.45, 0.53, 0.66);

void fragment() {
	vec3 rgb = to_display(COLOR.rgb);
	float lum = dot(rgb, vec3(0.299, 0.587, 0.114));
	vec3 laid = mix(shadow, snow, smoothstep(0.18, 0.38, lum));
	laid = mix(deep, laid, smoothstep(0.06, 0.16, lum));
	COLOR = vec4(to_canvas(laid), COLOR.a);
}
