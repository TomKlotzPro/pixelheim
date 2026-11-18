shader_type canvas_item;
// Light relief on a plain piece (PIX-528, Relief.material()): a prop, a lamp
// post, a crate, a stall, a room's furniture, drawn as it is, its normal from
// its own light and dark for the lamps and the lantern (relief.gdshaderinc).
// Its colour is the texel's, untouched. A tile layer's material says it is
// no sprite cut from a sheet (`cut`: relief.gdshaderinc's relief_uv).

#include "res://shaders/linear.gdshaderinc"
#include "res://shaders/relief.gdshaderinc"

uniform bool cut = true;

void fragment() {
	if (relief > 0.0) {
		NORMAL_MAP = RELIEF_NORMAL(RELIEF_GRAIN, cut);
	} else {
		NORMAL_MAP = RELIEF_FLAT;
	}
}
