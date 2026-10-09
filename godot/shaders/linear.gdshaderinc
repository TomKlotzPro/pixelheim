// The desktop app's canvas (PIX-227, DesktopLook): there the world is drawn
// in HDR, in linear light, so the screen a pass reads, the texel times the
// modulate a material starts from, and what a shader writes back are all
// linear. Every pass here was written for the browser's canvas, where all of
// it is the screen's own sRGB: a pass turns what it reads into sRGB first
// (`to_display`) and what it writes back into the canvas's light
// (`to_canvas`), so its thresholds, tints and mixes come out the same on
// both. A pass that works in light itself reads with `to_light` and writes
// with `from_light`. LightRig sets `world_linear` (1 while the canvas is
// linear). In the browser's build the canvas is always sRGB.

vec3 srgb_to_light(vec3 c) {
	vec3 s = max(c, vec3(0.0));
	return mix(pow((s + 0.055) / 1.055, vec3(2.4)), s / 12.92, lessThan(s, vec3(0.04045)));
}

vec3 light_to_srgb(vec3 c) {
	vec3 l = max(c, vec3(0.0));
	return mix(1.055 * pow(l, vec3(1.0 / 2.4)) - 0.055, l * 12.92, lessThan(l, vec3(0.0031308)));
}

#if CURRENT_RENDERER == RENDERER_COMPATIBILITY

vec3 to_display(vec3 c) {
	return c;
}

vec3 to_canvas(vec3 c) {
	return c;
}

vec3 to_light(vec3 c) {
	return srgb_to_light(c);
}

vec3 from_light(vec3 c) {
	return light_to_srgb(c);
}

// What to add to `base` (shown) so it shows `base + add`.
vec3 lift(vec3 base, vec3 add) {
	return add;
}

// How opaque a dark veil must be to darken as much as `a` does in sRGB.
float veil(float a) {
	return a;
}

#else

global uniform float world_linear;

vec3 to_display(vec3 c) {
	return world_linear < 0.5 ? c : light_to_srgb(c);
}

vec3 to_canvas(vec3 c) {
	return world_linear < 0.5 ? c : srgb_to_light(c);
}

vec3 to_light(vec3 c) {
	return world_linear < 0.5 ? srgb_to_light(c) : c;
}

vec3 from_light(vec3 c) {
	return world_linear < 0.5 ? light_to_srgb(c) : c;
}

// An added glow lands in linear light: what to add to `base` (shown) there so
// it shows `base + add`, as the browser's canvas would.
vec3 lift(vec3 base, vec3 add) {
	if (world_linear < 0.5) {
		return add;
	}
	return srgb_to_light(base + add) - srgb_to_light(base);
}

// A dark veil blended in linear light darkens less: how opaque it must be
// there to darken as much as `a` does over sRGB.
float veil(float a) {
	if (world_linear < 0.5) {
		return a;
	}
	return 1.0 - pow(1.0 - clamp(a, 0.0, 1.0), 2.2);
}

#endif
