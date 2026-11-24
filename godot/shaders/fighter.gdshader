shader_type canvas_item;
// A fighter's sprite (PIX-226): a hit flashes it pure white, a clean
// silhouette rather than a brightened tint; a death dissolves it pixel by
// pixel, the pixels about to go glowing like embers. Both by the sprite's own
// texels, so the art stays crisp. The fighter sets `flash` and `dissolve`
// (0..1) on its own copy of the material; the villagers share one, never
// flashed (Npc). On the desktop app's linear canvas (PIX-227) the flash fades
// as it does in the browser; `ember`, a colour, reaches it already linear.
// In the dark the lights rim its edge on the side facing them (PIX-531,
// relief.gdshaderinc's RELIEF_RIM); its normal stays flat, so the Light
// relief never shapes a face.

#include "res://shaders/linear.gdshaderinc"
#define RELIEF_RIM
#include "res://shaders/relief.gdshaderinc"

// Whether the lights rim it: not a floor tile wearing it (StairRise).
uniform bool relief_rimmed = true;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
// Texels darker than this keep their colour through a flash (PIX-497: the
// hero's outline, so they read under a bite's spark); 0 flashes all.
uniform float keep : hint_range(0.0, 1.0) = 0.0;
uniform float dissolve : hint_range(0.0, 1.0) = 0.0;
uniform vec3 ember : source_color = vec3(1.0, 0.55, 0.2);
// How wide the glowing rim of the dissolve is.
const float RIM = 0.14;
// Wading (PIX-548, Wading): drawn `wade` pixels of its art lower, its rows
// under the waterline gone and the row at it the water's lip, drawn on the
// row under where its soles stood: `wade_foot`, that row in the sprite's
// own pixels from its middle.
uniform float wade = 0.0;
uniform float wade_foot = 0.0;
uniform vec3 wade_lip : source_color = vec3(0.66, 0.7, 0.5);
varying float sprite_y;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void vertex() {
	sprite_y = VERTEX.y;
	VERTEX.y += wade;
}

void fragment() {
	vec4 c = COLOR;  // already the texel times the modulate
	// Unflashed, untouched: on the linear canvas the round trip isn't exact.
	if (flash > 0.0) {
		vec3 shown = to_display(c.rgb);
		c.rgb = to_canvas(mix(shown, vec3(1.0), flash * step(keep, max(shown.r, max(shown.g, shown.b)))));
	}
	if (dissolve > 0.0) {
		float h = hash(floor(UV / TEXTURE_PIXEL_SIZE));
		if (h < dissolve) {
			c.a = 0.0;
		} else if (h < dissolve + RIM) {
			c.rgb = ember;
		}
	}
	if (wade > 0.0) {
		float under = floor(sprite_y) - (wade_foot - wade);
		if (under >= 1.0) {
			c.a = 0.0;
		} else if (under >= 0.0 && c.a > 0.5) {
			c.rgb = wade_lip;
		}
	}
	COLOR = c;
	NORMAL_MAP = RELIEF_FLAT;
	rim_open = relief_rimmed ? RIM_OPEN(0) : vec4(0.0);
	RIM_SKY;
}
