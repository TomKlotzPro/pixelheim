class_name Soundscape
extends Node
## What the hero hears (Solid Ground, PIX-260: moved out of world.gd as it
## was): the place's theme, the fight's or the boss's while something hunts
## the hero, a fallen boss's silence; the place's ambience, birds or
## crickets, the town's chatter, fire close by, wind or rain underneath
## (PIX-158, PIX-224); and coins, hurts and heals as they happen. The fight's
## clock it reads (and keeps) is Foes': hunted_at, hunted_by_boss.

var world: Node
## Sound's view of the hero: what changed is heard (coin, heal, hurt).
var heard_gold := 0
var heard_hp := 0
## Until when the music keeps quiet after a boss falls (PIX-210).
var hushed_until := 0.0
## Seconds until the soundscape is looked at again (PIX-158).
var soundscape_left := 0.0
## Open-air maps too high and cold for birdsong: wind instead (PIX-169).
const WINDY_MAPS := ["frostgate"]
## How hard it must rain before the rain is heard over the birds.
const RAIN_HEARD := 0.3


## Hears gold and health change from here on, starting from what they are.
func listen() -> void:
	heard_gold = GameState.pack.gold
	heard_hp = GameState.hero.hp
	GameState.gold_changed.connect(hear_gold)
	GameState.hp_changed.connect(hear_hp)
	GameState.loaded.connect(func() -> void:
		heard_gold = GameState.pack.gold
		heard_hp = GameState.hero.hp
	)


## Looks at the soundscape again at once (a new place).
func listen_again() -> void:
	soundscape_left = 0.0


## The music keeps quiet for `seconds` (a boss has fallen).
func hush(seconds: float) -> void:
	hushed_until = GameClock.seconds() + seconds


## Gold that grows rings (SFX.coin); health heard rising or falling.
func hear_gold(gold: int) -> void:
	if gold > heard_gold:
		Sound.play("coin")
	heard_gold = gold


func hear_hp(hp: int, _max_hp: int) -> void:
	if hp < heard_hp:
		Sound.play("hurt")
	# Health trickling back at rest (PIX-206) mends in silence.
	elif hp > heard_hp + GameState.upkeep.rest_mend():
		Sound.play("heal")
	heard_hp = hp


## The place's theme, or the fight's while anything hunts the hero (and a
## few seconds after), the boss's when a boss does; and the place's weather.
func refresh() -> void:
	if not GameState.title_seen and not HarnessFlags.given().has("--screenshot"):
		return  # the title plays its own
	var now := GameClock.seconds()
	for enemy in get_tree().get_nodes_in_group("mobs"):
		if enemy.hunting and not enemy.dying:
			world.foes.hunted_at = now
			world.foes.hunted_by_boss = world.foes.hunted_by_boss or world.foes.fights_like_boss(enemy)
			# A boss on the hunt has its bar across the top (PIX-210).
			if world.foes.fights_like_boss(enemy) and not world.hud.boss_bar.following():
				world.hud.boss_bar.follow(enemy)
	var fight := ""
	if now - world.foes.hunted_at < Foes.COMBAT_LINGER_S:
		fight = "boss" if world.foes.hunted_by_boss else "battle"
	else:
		world.foes.hunted_by_boss = false
	# A fallen boss's silence holds a moment before the place's music.
	if now >= hushed_until and (Sound.track != "victory" or fight != ""):
		Sound.play_track(Sound.track_for(world.map.id, world.map.floor_level, fight))
	Sound.set_ambience(Sound.ambience_for(world.map.id, world.map.floor_level))
	# The soundscape changes slowly: twice a second is plenty.
	soundscape_left -= get_process_delta_time()
	if soundscape_left <= 0.0:
		soundscape_left = 0.5
		Sound.set_extras(_soundscape())
		var windy: bool = world.map.floor_level > 0 or world.map.style == "cave" or world.map.id in WINDY_MAPS
		var bed := ("deepwind" if world.map.floor_level > 10 else "wind") if windy else ""
		Sound.set_bed("rain" if raining() else bed)


## What else the hero hears here (PIX-158): birds by day and crickets by
## night outdoors, the town talking by day once it has folk again, and fire
## close by - a camp's torch, the forge, the village burning on the Night of
## Ash.
func _soundscape() -> Array[String]:
	var out: Array[String] = []
	if world.map.floor_level > 0:
		return out
	# The roofs the Night of Bells' embers set alight burn too (PIX-253 step
	# 9), and the crickets keep quiet all that night.
	var bells: int = GameState.progression.bells if world.map.id == "town" else Bells.NONE
	var burning: bool = world.map.id == "town" and (GameState.progression.prologue != Prologue.DONE or bells == Bells.EMBERS)
	var outdoors: bool = world.map.id == "town" or (PunyTerrain.is_outdoor(world.map.grid) and not world.map.id.begins_with("town_"))
	# The birds keep quiet in the rain.
	if outdoors and not burning and bells == Bells.NONE and world.map.id not in WINDY_MAPS and not raining():
		out.append("crickets" if DayNight.is_night(GameState.world.steps) else "birds")
		if world.map.id == "town" and GameState.town_tier() >= 1 and not DayNight.is_night(GameState.world.steps):
			out.append("chatter")
	if burning or world.map.id == "town_smith" or _near_camp_fire():
		out.append("fire")
	return out


## A shower falling here now, enough to hear (PIX-224).
func raining() -> bool:
	return world.atmosphere != null and world.atmosphere.rain > RAIN_HEARD


## A camp's torch within a few tiles of the hero.
func _near_camp_fire() -> bool:
	for cell: Vector2i in world.view.camps:
		if world.view.camps[cell]["kind"] == "torch" and Vector2(cell).distance_to(Vector2(world.player_cell)) <= 4.0:
			return true
	return false
