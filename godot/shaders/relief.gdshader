shader_type canvas_item;
// Light relief on a plain piece (PIX-528, PIX-529, Relief.material()): a
// prop, a lamp post, a crate, a stall, a room's furniture domed from its
// outline; a tile layer (a square's great flags, stone walls, the rampart)
// carved from its stones' joints, where its sheet has stone
// there (relief.gdshaderinc). Its colour is the texel's, untouched. In the
// dark a domed piece takes the lights' rim on its side facing them (PIX-531,
// RELIEF_RIM), relief on or off; a carved or plain one never does, nor a
// lamp's post (Relief.lamp_post()).

#include "res://shaders/linear.gdshaderinc"
#define RELIEF_RIM
#include "res://shaders/relief.gdshaderinc"

// Relief.PLAIN, CARVED or DOMED, and whether it draws a tile layer.
uniform int relief_form = 1;
uniform bool relief_tiles = false;
// Whether the lights rim it when domed (PIX-531).
uniform bool relief_rimmed = true;

void fragment() {
	if (relief > 0.0) {
		NORMAL_MAP = RELIEF_SHAPE(relief_form, relief_tiles);
	} else {
		NORMAL_MAP = RELIEF_FLAT;
	}
	rim_open = relief_form == RELIEF_DOMED && relief_rimmed ? RIM_OPEN(relief_tiles ? 1 : 0) : vec4(0.0);
}
