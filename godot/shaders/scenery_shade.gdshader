shader_type canvas_item;
render_mode unshaded, blend_mul;
// The scenery's shadows on the ground (PIX-449), a map's all at once: its
// CanvasGroup (ShadowsLayer) draws each shadow's coverage into its buffer
// (scenery_shadow.gdshader), so where two meet they are one shadow, not a
// darker one, and this multiplies the ground under them by the shade, as
// strongly as the sun says (global `sun`'s z, LightRig: full at noon,
// fainter low, none at night, under cloud or out of the sky). Multiplied in
// the screen's own colours, as the canopy's shade is (canopy_shade.gdshader):
// an alpha blend toward black lands weaker on the app's linear canvas by
// day and stronger at dusk (PIX-447); this darkens alike on both. Unshaded:
// the ground under it already took the night's dark and the lights.

#include "res://shaders/linear.gdshaderinc"

global uniform vec4 sun;
uniform sampler2D cast : hint_screen_texture, filter_nearest, repeat_disable;

// What the ground is multiplied by in the strongest shadow: soft, and a
// little blue, the sky's light in it.
const vec3 SHADE = vec3(0.66, 0.7, 0.82);

void fragment() {
	float cover = textureLod(cast, SCREEN_UV, 0.0).a;
	COLOR = vec4(to_canvas(mix(vec3(1.0), SHADE, cover * clamp(sun.z, 0.0, 1.0))), 1.0);
}
