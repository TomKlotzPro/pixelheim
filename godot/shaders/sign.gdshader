shader_type canvas_item;
// A shop's hanging sign (PIX-553, ShopSign): its board, chains and painted
// icon swing from the bracket's arm in the world's wind, more in a storm's,
// still with Reduce motion (world_wind is then 0). Each sprite's origin is
// the hinge, so a vertex's own y is how far it hangs below the arm: the foot
// swings most, the chains' tops stay on their hooks. Each door swings on its
// own beat. In the dark the door's lantern rims the board's edge facing it
// (PIX-531, RELIEF_RIM); the icon painted on it is no edge (relief_rimmed
// off). A board is flat wood: no dome.

#include "res://shaders/wind.gdshaderinc"
#include "res://shaders/linear.gdshaderinc"
#define RELIEF_RIM
#include "res://shaders/relief.gdshaderinc"

uniform bool relief_rimmed = true;
// How far the foot swings, in art pixels for a lean of 1, and the longest
// sign's hang, in pixels.
const float SIGN_SWING = 1.5;
const float SIGN_HANG = 27.0;

void vertex() {
	vec2 hinge = MODEL_MATRIX[3].xy;
	// Each door its own beat, so the street's signs never swing together.
	float phase = hinge.x * 0.37 + hinge.y * 0.11;
	float gust = wind_lean(hinge, phase);
	// Pushed downwind by the gust, and swinging back and forth under it.
	float swing = 0.6 * gust + 0.5 * world_wind * (0.4 + abs(gust)) * sin(world_time * 2.3 + phase);
	VERTEX.x += SIGN_SWING * swing * max(VERTEX.y, 0.0) / SIGN_HANG;
}

void fragment() {
	NORMAL_MAP = RELIEF_FLAT;
	rim_open = relief_rimmed ? RIM_OPEN(0) : vec4(0.0);
	RIM_SKY;
}
