shader_type canvas_item;
// Each region's air over the drawn world (PIX-224), a pass between the world
// and the HUD: heat haze shivering the Ash a pixel at a time, low fog rolling
// over the Mire, frost creeping in from the edges of the view in the
// Frostgate, a sea mist on the coast, rain's grey veil, and last the colour
// mood (Weather.MOODS: a tint, saturation and contrast). Each air comes in
// by its weight, so crossing into a region fades it in. Fog and frost take
// the hour's light, so they darken at night. Art pixels stay whole: the
// frost's ragged rim is dithered in 2px blocks like the clouds', the fog is
// soft, in eight steps. The Atmosphere node sets it all; with reduced motion
// the haze stops and the fog stands still.

#include "res://shaders/wind.gdshaderinc"
#include "res://shaders/linear.gdshaderinc"

uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform sampler2D noise : filter_linear, repeat_enable;
// The world under the screen: its top-left corner and size, in pixels.
uniform vec2 view_origin;
uniform vec2 view_size = vec2(320.0, 180.0);
// How much of each air, and of the rain, 0..1; the hour's light.
uniform float ash = 0.0;
uniform float frost = 0.0;
uniform float mire = 0.0;
uniform float coast = 0.0;
uniform float rain = 0.0;
uniform vec3 light = vec3(1.0);
// The colour mood.
uniform vec3 tint = vec3(1.0);
uniform float saturation = 1.0;
uniform float contrast = 1.0;

const vec3 FOG = vec3(0.8, 0.88, 0.8);
const vec3 RIME = vec3(0.7, 0.83, 0.98);
const vec3 MIST = vec3(0.9, 0.95, 1.0);
const vec3 LUMA = vec3(0.299, 0.587, 0.114);
// How far frost reaches in from the edges, in pixels, at most.
const float FROST_REACH = 36.0;
// How strong a haze band must be to shift its row: most rows hold still.
const float HAZE = 0.72;

const float BAYER[16] = float[16](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0
);

// `amount` in four steps, dithered between them at `px`.
float stepped(float amount, vec2 px) {
	ivec2 block = ivec2(floor(px / 2.0)) & ivec2(3);
	float threshold = (BAYER[block.y * 4 + block.x] + 0.5) / 16.0;
	return floor(clamp(amount, 0.0, 1.0) * 4.0 + threshold) / 4.0;
}

void fragment() {
	// Screen UV per rect UV (the canvas may sit letterboxed in the window),
	// and per pixel of the world.
	vec2 per_uv = vec2(dFdx(SCREEN_UV.x) / dFdx(UV.x), dFdy(SCREEN_UV.y) / dFdy(UV.y));
	vec2 per_px = per_uv / view_size;
	vec2 px = floor(view_origin + UV * view_size);
	vec2 at = SCREEN_UV;
	// Heat haze: here and there a thin band of the world shivers a pixel
	// sideways, the bands rising.
	if (ash > 0.5 && world_wind > 0.0) {
		float band = sin(px.y * 0.35 + world_time * 3.0) * sin(px.y * 0.07 + world_time * 0.9 + px.x * 0.013);
		at.x += (band > HAZE ? 1.0 : (band < -HAZE ? -1.0 : 0.0)) * per_px.x;
	}
	vec3 c = to_display(texture(screen, at).rgb);
	// Low fog rolling over the Mire, longer than it is tall.
	if (mire > 0.0) {
		vec2 drift = vec2(world_time * 5.0, world_time * 1.2);
		float thick = texture(noise, (px + drift) / vec2(460.0, 200.0)).r;
		thick *= 0.7 + 0.3 * texture(noise, (px - drift * 0.6) / vec2(170.0, 110.0)).g;
		// Soft, in eight steps: a fog has no edge to dither.
		float fog = floor(smoothstep(0.3, 0.72, thick) * 8.0) / 8.0;
		c = mix(c, FOG * light, fog * 0.3 * mire);
	}
	// A sea mist off the coast.
	if (coast > 0.0) {
		c = mix(c, MIST * light, 0.07 * coast);
	}
	// Frost on the edges of the view, ragged and crystalline.
	if (frost > 0.0) {
		vec2 on_screen = floor(UV * view_size);
		float edge = min(min(on_screen.x, view_size.x - on_screen.x), min(on_screen.y, view_size.y - on_screen.y));
		float reach = FROST_REACH * (0.45 + 0.55 * texture(noise, on_screen / 90.0).r);
		float rim = 1.0 - edge / reach;
		rim *= 0.65 + 0.7 * texture(noise, on_screen / 13.0).g;
		c = mix(c, RIME * max(light, vec3(0.35)), stepped(rim, on_screen) * 0.8 * frost);
	}
	// Rain greys and cools everything.
	if (rain > 0.0) {
		c = mix(c, dot(c, LUMA) * vec3(0.84, 0.9, 1.0), 0.3 * rain);
	}
	// The colour mood.
	c = mix(vec3(dot(c, LUMA)), c, saturation);
	c = (c - 0.5) * contrast + 0.5;
	COLOR = vec4(to_canvas(c * tint), 1.0);
}
