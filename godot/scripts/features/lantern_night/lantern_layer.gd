class_name LanternLayer
extends MapLayer
## areas: travel field night +overworld*
## The Reach's lamps on Lantern Night (PIX-362): until Fafnyr's pass they
## wait dark after dusk, their embers, halos and light pools out; his pass
## lights them as any night does (`light`). Draws nothing of its own: the
## lamps are SettlementsLayer's (view.ember_lamps).


func set_night(view: MapView, night: bool) -> void:
	var waits := LanternNight.waits(GameState.progression, GameState.settlement, Gathering.day_of(GameState.world.steps))
	for place: String in view.ember_lamps:
		light(view, place, night and not waits, not waits)


## The lamp of `place` alight (`glow`: its ember and halo) or not, and its
## pool of light on the ground (`pool`) left to the hour or out.
static func light(view: MapView, place: String, glow: bool, pool := true) -> void:
	# Variants: a freed node can't be held in a typed one.
	var ember: Variant = view.ember_lamps.get(place)
	if not is_instance_valid(ember):
		return
	ember.visible = glow
	var halo: Variant = ember.get_meta("halo") if ember.has_meta("halo") else null
	if not is_instance_valid(halo):
		return
	halo.visible = glow
	# A lamp sharing a near one's light has none of its own (Lamps.lit_among).
	var lamp_light: Variant = halo.get_meta("light") if halo.has_meta("light") else null
	if is_instance_valid(lamp_light):
		lamp_light.visible = pool
