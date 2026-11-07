shader_type canvas_item;
// A prop drawn as it is, see-through round the hero while it stands over
// them (PIX-429, see_through.gdshaderinc): the roofed well and the other
// props of tiles, the mire's reeds. Its sprite's origin is its foot
// (MapLayer.see_through).

#include "res://shaders/see_through.gdshaderinc"

varying vec2 canvas_pos;
varying float foot;

void vertex() {
	canvas_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	foot = MODEL_MATRIX[3].y;
}

void fragment() {
	COLOR.a *= see_through(canvas_pos, foot);
}
