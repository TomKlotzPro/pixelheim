// The ice's look, wherever it lies (PIX-255, PIX-398): shaders/frozen.gdshader
// draws it over the ice cave's floors, region_tint.gdshader over the ground
// in the open air (the Frostgate's lake). The mask has a texel a cell, white
// where the ice is, read smoothly so the shore runs between the cells, and a
// slow noise bends it off the grid as region_tint's edges are.
// The ice is pale and flat, what lies under it a ghost, bluer where it lies
// deep; thin cracks run between its plates here and there; a lip of deeper
// blue rims it, and frost creeps a little way out past it, thinning in the
// same 2px Bayer dither as the regions' edges. A few reflections lie on its
// polish, and now and then a glint catches the light and goes out. All of it
// in whole pixels of the art, so it reads as drawn, not smudged.
// The shader including it gives hash(vec2), value_noise(vec2) and world_time.

const float ICE_CELL = 16.0;
// How far the shore wanders off the grid, in pixels, and how wide its bends.
const float ICE_SHORE_WANDER = 7.0;
const float ICE_SHORE_BENDS = 1.3;
// The ice map reads 0.5 on the shore; frost reaches out past it to HALO,
// and the ice's lip runs in to LIP.
const float ICE_HALO = 0.36;
const float ICE_LIP = 0.56;
const vec3 ICE_PALE = vec3(0.8, 0.92, 1.0);
const vec3 ICE_DEEP = vec3(0.6, 0.78, 0.94);
const vec3 ICE_CRACK = vec3(0.55, 0.71, 0.88);
const vec3 ICE_LIP_TONE = vec3(0.68, 0.8, 0.94);
const vec3 ICE_FROST = vec3(0.9, 0.96, 1.0);
const vec3 ICE_SHEEN = vec3(0.97, 1.0, 1.0);
// The ice's plates, about this many pixels across, and how much of it is
// cracked between them.
const float ICE_PLATE = 30.0;
const float ICE_CRACKED = 0.36;
// A reflection: a few parallel dashes in one patch of this many pixels in
// so many.
const float ICE_PATCH = 26.0;
const float ICE_REFLECTED = 0.82;

// Sin-free (a fract-of-multiply hash): a sin hash lost precision on the GPU
// over the open lake's large coordinates and laid its cracks in long straight
// crosses (PIX-398's review).
vec2 ice_hash2(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

// How far `p` lies from the nearest edge between the plates (a Voronoi of
// one point a unit cell), in cells.
float ice_plate_edge(vec2 p) {
	vec2 n = floor(p);
	vec2 f = fract(p);
	vec2 nearest_cell = vec2(0.0);
	vec2 nearest = vec2(8.0);
	float best = 8.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 r = g + ice_hash2(n + g) * 0.8 + 0.1 - f;
			float d = dot(r, r);
			if (d < best) {
				best = d;
				nearest = r;
				nearest_cell = g;
			}
		}
	}
	float edge = 8.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = nearest_cell + vec2(float(i), float(j));
			vec2 r = g + ice_hash2(n + g) * 0.8 + 0.1 - f;
			if (dot(nearest - r, nearest - r) > 0.0001) {
				edge = min(edge, dot(0.5 * (nearest + r), normalize(r - nearest)));
			}
		}
	}
	return edge;
}

// Where the ice mask is read for the art pixel `px` (its centre): bent off
// the grid by a slow noise, so the shore wanders between the cells.
vec2 ice_shore_at(vec2 px) {
	vec2 cells = floor(px / 2.0) * 2.0 / ICE_CELL / ICE_SHORE_BENDS;
	vec2 bend = vec2(value_noise(cells), value_noise(cells + 17.3)) - 0.5;
	return px + bend * 2.0 * ICE_SHORE_WANDER;
}

// The ice over `base` (display colours) at the art pixel `px`, `reach` the
// mask read at ice_shore_at(px), `threshold` the pixel's Bayer step, its
// body toned by `tone` (the snow under the open air's is bright, its ghost
// all but white): the colour, its alpha 0 where neither the ice nor its
// frost lies.
vec4 ice_over(vec3 base, vec2 px, float reach, float threshold, vec3 tone) {
	if (reach < ICE_HALO) {
		return vec4(base, 0.0);
	}
	if (reach < 0.5) {
		// Frost by the shore, thinning out.
		float out_to = (reach - ICE_HALO) / (0.5 - ICE_HALO);
		if (out_to * out_to < threshold) {
			return vec4(base, 0.0);
		}
		return vec4(mix(base, ICE_FROST, 0.32), 1.0);
	}
	// Pale, flat ice, bluer where it lies deep (in 2px steps of the
	// dither), what lies under it only a ghost.
	float depth = smoothstep(0.4, 0.75, value_noise(px / 44.0 + 3.7));
	vec3 ice = depth > threshold ? mix(ICE_PALE, ICE_DEEP, 0.4) : ICE_PALE;
	float luma = dot(base, vec3(0.299, 0.587, 0.114));
	ice *= (0.86 + 0.28 * luma) * tone;
	// Thin cracks between its plates, across some of it, broken off along
	// their way.
	if (value_noise(px / 70.0 + 9.1) > 1.0 - ICE_CRACKED && value_noise(px / 11.0 + 5.3) > 0.3
			&& ice_plate_edge(px / ICE_PLATE) * ICE_PLATE < 0.7) {
		ice = ICE_CRACK;
	}
	if (reach < ICE_LIP) {
		ice *= ICE_LIP_TONE;
	}
	// A reflection on its polish, here and there: two or three short
	// parallel dashes rising to the right.
	vec2 patch = floor(px / ICE_PATCH);
	if (hash(patch + 3.1) > ICE_REFLECTED) {
		vec2 q = floor(px) - patch * ICE_PATCH - floor(vec2(hash(patch + 5.7) * 8.0 + 2.0, hash(patch + 9.2) * 6.0 + 16.0));
		float run = 4.0 + floor(hash(patch + 1.3) * 5.0);
		for (int line = 0; line < 3; line++) {
			float x = q.x - float(line) * 3.0;
			float along = run - float(line) * 2.0;
			if (along > 1.0 && x >= 0.0 && x < along && q.y == -x) {
				ice = mix(ice, ICE_SHEEN, 0.6);
			}
		}
	}
	// A glint: a small cross of light that catches and goes out.
	vec2 spot = floor(px / 7.0);
	float beat = floor(world_time * 0.7 + hash(spot) * 13.0);
	if (hash(spot + beat * 7.31) > 0.993) {
		vec2 at = mod(floor(px), 7.0) - 3.0;
		float off = abs(at.x) + abs(at.y);
		if ((at.x == 0.0 || at.y == 0.0) && off <= 2.0) {
			ice = mix(ice, vec3(1.0), off < 0.5 ? 0.9 : 0.5);
		}
	}
	return vec4(ice, 1.0);
}
