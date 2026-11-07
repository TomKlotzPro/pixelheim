// What stands over the hero turns see-through round them (PIX-429, PIX-430:
// the hero walked under the well's roof and into the west garden's grove and
// was lost there). Trees, props of tiles (the roofed well, stalls) and the
// mire's reeds are y-sorted on their foot, so a hero north of a foot is
// drawn under all of it: there, and only there, an oval about the hero's
// body lets them show through, the art pixel a step, and the same about the
// nearest foe hunting them so a fight under the trees can be read. `foot` is the y the piece is sorted on, in the
// canvas: its sprite's own origin (MapLayer.see_through puts it there).
// world.gd sets `hero_at` each frame, world_foes.gd `foe_at` (their feet, as
// they are sorted); both lie far off when there is no one to see.

global uniform vec2 hero_at;
global uniform vec2 foe_at;

// What is left of the piece in the middle of the oval: little, as in a
// thicket two or three crowns stand over the hero at once.
const float SEE_THROUGH_LEFT = 0.1;
// The oval's half width and height, in art pixels, and how far its middle
// stands above the feet: the hero's figure (14 px square, its feet 2 px
// below their place) and a hand round it.
const vec2 SEE_THROUGH_REACH = vec2(13.0, 16.0);
const float SEE_THROUGH_RISE = 5.0;
// Over these few pixels below the feet a foot's piece comes to draw over them.
const float SEE_THROUGH_EASE = 4.0;

float see_through_round(vec2 pixel, float foot, vec2 who) {
	float over = clamp((foot - who.y) / SEE_THROUGH_EASE, 0.0, 1.0);
	vec2 off = (floor(pixel) + 0.5 - who + vec2(0.0, SEE_THROUGH_RISE)) / SEE_THROUGH_REACH;
	return over * (1.0 - smoothstep(0.55, 1.0, length(off)));
}

// The share of the piece's pixel at `pixel` (canvas pixels) left drawn.
float see_through(vec2 pixel, float foot) {
	float open = max(see_through_round(pixel, foot, hero_at), see_through_round(pixel, foot, foe_at));
	return 1.0 - open * (1.0 - SEE_THROUGH_LEFT);
}
