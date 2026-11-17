shader_type canvas_item;
// The smoke off a burning house (PIX-327, FireArt.air): puffs of it rising
// one after another from the house, swelling as they climb, leaning downwind
// and wavering, thinning to a dither and gone near the top; each a lumpy
// round in whole art pixels and Shade's greys, pale where it faces up and
// left, darker under. The youngest puff, nearest the fire, is in front. It
// moves in steps, as the flames do; lit as the world is (the night darkens
// it, the fire under it warms it), held still with the clock under Reduce
// motion. A chimney's thread is the same puffs, smaller (`swell`: they and
// their lean), a forge's darker (`soot`), both denser (`density`) and toned
// by the hour (`by_hour`, PIX-523): the side facing a low sun gold, all of
// it pale blue under the moon (global `sun`).

#include "res://shaders/linear.gdshaderinc"

global uniform float world_time;
global uniform float world_wind;
global uniform vec4 sun;
// The quad's size, where the smoke rises from in it (pixels), the house's
// half width, and a seed so no two houses smoke alike.
uniform vec2 size = vec2(208.0, 168.0);
uniform vec2 source = vec2(88.0, 124.0);
uniform float spread = 60.0;
uniform float seed = 0.0;
uniform float swell = 1.0;
uniform float soot = 0.0;
uniform float density = 1.0;
uniform bool by_hour = false;
// Pixels of the quad above the plume's top, so a puff's round top isn't cut
// flat by the quad's edge (a chimney's thread, PIX-523); the climb is
// source.y less this.
uniform float head = 0.0;
const int PUFFS = 14;
// Steps a second; how long a puff takes to climb the plume (seconds).
const float STEPS = 8.0;
const float CLIMB = 5.0;
const vec3 HIGH = vec3(0.608, 0.678, 0.718);
const vec3 BODY = vec3(0.518, 0.494, 0.529);
const vec3 SHADOW = vec3(0.349, 0.337, 0.322);
const vec3 GOLD = vec3(1.0, 0.8, 0.52);
const vec3 MOONLIT = vec3(0.74, 0.82, 0.96);

float hash(float n) {
	return fract(sin(n * 127.1 + seed * 311.7) * 43758.5453);
}

float lump(vec2 p) {
	return fract(sin(dot(floor(p), vec2(127.1, 311.7)) + seed * 17.13) * 43758.5453);
}

void fragment() {
	vec2 px = floor(UV * size) + 0.5;
	float t = floor(world_time * STEPS) / STEPS;
	float girth = clamp(spread / 56.0, 0.8, 1.6);
	float youngest = 2.0;
	vec4 smoke = vec4(0.0);
	for (int i = 0; i < PUFFS; i++) {
		float n = float(i);
		float span = CLIMB * (0.85 + 0.3 * hash(n + 0.3));
		float clock = t / span + n / float(PUFFS) + 0.3 * hash(n + 1.1);
		float life = fract(clock);
		float round_no = floor(clock);
		if (life >= youngest) {
			continue;
		}
		vec2 from = source + vec2((hash(n * 3.1 + round_no * 7.7) * 2.0 - 1.0) * spread * 0.6, 0.0);
		float lean = ((6.0 + 28.0 * world_wind) * life * life + sin(life * 4.0 + n) * 3.0) * swell;
		vec2 middle = from + vec2(lean, -(source.y - head) * 0.92 * life);
		float radius = (3.0 + 11.0 * life) * girth * swell;
		vec2 off = px - middle;
		float far = length(off * vec2(1.0, 1.2));
		// A lumpy rim, in 3-pixel lumps.
		float rim = radius * (0.85 + 0.3 * lump((off + vec2(n * 13.0)) / 3.0));
		if (far >= rim) {
			continue;
		}
		// Born out of the flames, gone near the top: thinning to a dither.
		float thick = smoothstep(0.0, 0.1, life) * (1.0 - smoothstep(0.5, 1.0, life));
		if (thick < 0.45 && mod(px.x + px.y, 2.0) < 1.0) {
			continue;
		}
		// Its fringe a dither, so it reads as air, not a stone on the ground.
		if (far > rim * 0.78 && mod(px.x + px.y, 2.0) < 1.0) {
			continue;
		}
		float side = dot(off / max(far, 0.001), vec2(0.6, 0.8)) * far / rim;
		vec3 tone = side < -0.35 ? HIGH : (side > 0.55 ? SHADOW : BODY);
		tone *= 1.0 - 0.55 * soot;
		if (by_hour) {
			float low = smoothstep(0.6, 1.4, length(sun.xy)) * step(0.001, sun.z);
			tone = mix(tone, tone * GOLD * 1.35, low * (side < -0.35 ? 0.9 : 0.35));
			tone = mix(tone, MOONLIT * 0.8 * dot(tone, vec3(1.0)) / dot(BODY, vec3(1.0)), 0.75 * clamp(sun.w, 0.0, 1.0));
		}
		smoke = vec4(tone, min(0.6 * max(thick, 0.6) * density, 0.9));
		youngest = life;
	}
	COLOR = vec4(to_canvas(smoke.rgb), smoke.a);
}
