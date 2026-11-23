shader_type canvas_item;
// Light relief on a plain piece (PIX-528, PIX-529, Relief.material()): a
// prop, a lamp post, a crate, a stall, a room's furniture domed from its
// outline; a tile layer (a square's great flags, stone walls, the rampart)
// carved from its stones' joints, where its sheet has stone
// there (relief.gdshaderinc). Its colour is the texel's, untouched.

#include "res://shaders/linear.gdshaderinc"
#include "res://shaders/relief.gdshaderinc"

// Relief.PLAIN, CARVED or DOMED, and whether it draws a tile layer.
uniform int relief_form = 1;
uniform bool relief_tiles = false;

void fragment() {
	if (relief > 0.0) {
		NORMAL_MAP = RELIEF_SHAPE(relief_form, relief_tiles);
	} else {
		NORMAL_MAP = RELIEF_FLAT;
	}
}
