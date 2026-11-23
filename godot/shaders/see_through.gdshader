shader_type canvas_item;
// A prop drawn as it is, see-through round the hero while it stands over
// them (PIX-429, see_through.gdshaderinc): the roofed well and the other
// props of tiles, the mire's reeds. Its sprite's origin is its foot
// (MapLayer.see_through). The lamps and the lantern shape it, domed from its
// outline (Light relief, PIX-528, PIX-529, relief.gdshaderinc), and in the
// dark rim its side facing them (PIX-531, RELIEF_RIM).

#include "res://shaders/linear.gdshaderinc"
#include "res://shaders/see_through.gdshaderinc"
#define RELIEF_RIM
#include "res://shaders/relief.gdshaderinc"

varying vec2 canvas_pos;
varying float foot;

void vertex() {
	canvas_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	foot = MODEL_MATRIX[3].y;
}

void fragment() {
	COLOR.a *= see_through(canvas_pos, foot);
	if (relief > 0.0) {
		NORMAL_MAP = RELIEF_SHAPE(RELIEF_DOMED, false);
	} else {
		NORMAL_MAP = RELIEF_FLAT;
	}
	rim_open = RIM_OPEN(0);
}
