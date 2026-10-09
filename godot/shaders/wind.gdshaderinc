// The wind (PIX-223): how far what grows leans at a spot of the world, on
// the world's own clock (LightRig sets both globals each frame: the clock
// stops while the game is paused, and with reduced motion the wind drops).
// A slow sway everywhere, and gusts rolling across the land from the west,
// so no two trees move in unison.

global uniform float world_time;
global uniform float world_wind;

// The lean at `world` (in pixels), roughly -0.4..1.4: mostly downwind in a
// gust, a small sway between them. It changes slowly across the land, so a
// quad's two top corners lean alike; `phase` gives a lone tree its own beat.
float wind_lean(vec2 world, float phase) {
	float gust = 0.5 + 0.5 * sin(world_time * 0.55 - world.x * 0.011 - world.y * 0.004);
	gust = gust * gust * gust;
	float sway = sin(world_time * 1.7 + world.x * 0.023 + world.y * 0.017 + phase);
	float flutter = sin(world_time * 4.3 + world.x * 0.029 - world.y * 0.021 + phase * 1.7);
	return world_wind * (gust * (0.7 + 0.3 * sway) + 0.25 * sway + 0.12 * gust * flutter);
}

// Whether a vertex is a top corner of its quad, so a tree's crown leans while
// its foot stays put. The renderers number a quad's corners differently: the
// browser's draws six (two triangles), the desktop's four.
bool top_corner(int id) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	int corner = id % 6;
	return corner == 0 || corner == 3 || corner == 4;
#else
	int corner = id % 4;
	return corner == 0 || corner == 3;
#endif
}
