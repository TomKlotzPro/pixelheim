shader_type canvas_item;
render_mode unshaded;
// A rank's rim of light (PIX-244, RankLook): drawn on a copy of the hero's
// frame behind the sprite, a pixel of the class's light just outside the
// figure wherever the figure is below it or beside it - its top and sides,
// as if lit from above, never a line under the feet. By the sprite's own
// texels, so it's the art's whole pixels at any size. Unshaded: it shows at
// night, where the glow pass blooms it. `rim` is a colour, so on the desktop
// app's linear canvas (PIX-227) it reaches the shader already linear; the
// sprite's fading (a roll's blur, a fall) carries over through its modulate.

#include "res://shaders/linear.gdshaderinc"

uniform vec4 rim : source_color = vec4(1.0, 1.0, 1.0, 0.85);

varying vec4 tint;

void vertex() {
	// The modulate the rim inherits from the sprite, and its own breath.
	tint = COLOR;
}

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	float here = texture(TEXTURE, UV).a;
	float below = texture(TEXTURE, UV + vec2(0.0, px.y)).a;
	float left = texture(TEXTURE, UV - vec2(px.x, 0.0)).a;
	float right = texture(TEXTURE, UV + vec2(px.x, 0.0)).a;
	float lit = here < 0.5 && max(below, max(left, right)) > 0.5 ? 1.0 : 0.0;
	COLOR = vec4(rim.rgb, lit * rim.a * tint.a);
}
