shader_type canvas_item;
render_mode unshaded, blend_disabled;
// A hurt's red at the screen's edges (PIX-447, hurt_edge.gd) on the desktop
// app's linear canvas. Blended there in light, its faint red came out about
// twice as strong over the night as in the browser it was tuned in, and
// weaker by day: light adds the same red to a dark pixel as to a bright one,
// and the eye sees far more of it on the dark (no one factor on its alpha
// fits both). So it mixes into the screen in the screen's own
// colours, as the browser's canvas does, and looks the same on both, by day,
// at night and in the Ash. The browser's build draws it without this.

#include "res://shaders/linear.gdshaderinc"

uniform sampler2D screen : hint_screen_texture, filter_nearest;

void fragment() {
	// The gradient's texel times the modulate: the red, and in its alpha how
	// much of it shows here.
	vec4 red = COLOR;
	if (red.a <= 0.0) {
		discard;
	}
	vec3 under = to_display(texture(screen, SCREEN_UV).rgb);
	COLOR = vec4(to_canvas(mix(under, to_display(red.rgb), red.a)), 1.0);
}
