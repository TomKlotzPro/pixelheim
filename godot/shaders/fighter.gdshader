shader_type canvas_item;
// A fighter's sprite (PIX-226): a hit flashes it pure white, a clean
// silhouette rather than a brightened tint; a death dissolves it pixel by
// pixel, the pixels about to go glowing like embers. Both by the sprite's own
// texels, so the art stays crisp. The fighter sets `flash` and `dissolve`
// (0..1) on its own copy of the material. On the desktop app's linear canvas
// (PIX-227) the flash fades as it does in the browser; `ember`, a colour,
// reaches it already linear.

#include "res://shaders/linear.gdshaderinc"

uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform float dissolve : hint_range(0.0, 1.0) = 0.0;
uniform vec3 ember : source_color = vec3(1.0, 0.55, 0.2);
// How wide the glowing rim of the dissolve is.
const float RIM = 0.14;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec4 c = COLOR;  // already the texel times the modulate
	c.rgb = to_canvas(mix(to_display(c.rgb), vec3(1.0), flash));
	if (dissolve > 0.0) {
		float h = hash(floor(UV / TEXTURE_PIXEL_SIZE));
		if (h < dissolve) {
			c.a = 0.0;
		} else if (h < dissolve + RIM) {
			c.rgb = ember;
		}
	}
	COLOR = c;
}
