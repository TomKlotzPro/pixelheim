class_name Ailments
extends RefCounted
## Status effects on one combatant (combat.ts), in real time: a web turn lasts
## TURN_SECONDS. Poison and burn deal their power every turn; stun holds the
## combatant for its turns. A re-roll of the same kind refreshes it to the
## higher duration and power, never stacking (rollInfliction).

const TURN_SECONDS := 1.0
const VERBS := {"poison": "Poison", "burn": "The burn"}

## An ailment's name for the player, in their language (PIX-196): the
## kinds are ids.
static func label(kind: String) -> String:
	match kind:
		"poison":
			return Text.t("poison")
		"burn":
			return Text.t("burn")
		"stun":
			return Text.t("stun")
	return kind


## {kind, turnsLeft, power}
var effects: Array[Dictionary] = []
var _clock := 0.0
## Bosses and elites shake stuns off (PIX-186): for `stun_guard` seconds
## after a stun takes hold, the next is halved (a one-turn stun shrugged
## off); a calm that long and the count is forgotten. 0 for the rest.
var stun_guard := 0.0
var _stuns := 0
var _since_stun := 0.0


## Rolls an infliction (`{kind, chance, turns, power}` or null); resisted
## kinds never take (stunResist / poisonResist passives). True when applied.
func inflict(infliction: Variant, roll: Callable, passives := {}) -> bool:
	if not infliction is Dictionary:
		return false
	var kind: String = infliction["kind"]
	if (kind == "stun" and passives.get("stunResist", false)) or (kind == "poison" and passives.get("poisonResist", false)):
		return false
	if roll.call() >= float(infliction["chance"]):
		return false
	var turns := int(infliction["turns"])
	if kind == "stun" and stun_guard > 0:
		turns = turns >> _stuns
		if turns < 1:
			return false
		_stuns += 1
		_since_stun = 0.0
	var current := _find(kind)
	var refreshed := {
		"kind": kind,
		"turnsLeft": maxi(turns, int(current.get("turnsLeft", 0))),
		"power": maxi(int(infliction["power"]), int(current.get("power", 0))),
	}
	effects = effects.filter(func(effect: Dictionary) -> bool: return effect["kind"] != kind)
	effects.append(refreshed)
	return true


## Advances the clock; on each elapsed turn, damage ticks fire and every
## effect (stun included) spends a turn. Returns [{kind, damage}] ticks.
func tick(delta: float) -> Array[Dictionary]:
	var ticks: Array[Dictionary] = []
	_since_stun += delta
	if _since_stun >= stun_guard:
		_stuns = 0
	if effects.is_empty():
		_clock = 0.0
		return ticks
	_clock += delta
	while _clock >= TURN_SECONDS and not effects.is_empty():
		_clock -= TURN_SECONDS
		var remaining: Array[Dictionary] = []
		for effect in effects:
			if effect["kind"] != "stun":
				ticks.append({"kind": effect["kind"], "damage": effect["power"]})
			if effect["turnsLeft"] > 1:
				effect["turnsLeft"] -= 1
				remaining.append(effect)
		effects = remaining
	return ticks


func is_stunned() -> bool:
	return not _find("stun").is_empty()


func kinds() -> Array[String]:
	var out: Array[String] = []
	for effect in effects:
		out.append(effect["kind"])
	return out


## A remedy takes one ailment away (an antidote, a salve).
func cure(kind: String) -> bool:
	var before := effects.size()
	effects = effects.filter(func(effect: Dictionary) -> bool: return effect["kind"] != kind)
	return effects.size() < before


func clear() -> void:
	effects.clear()
	_clock = 0.0
	_stuns = 0


func _find(kind: String) -> Dictionary:
	for effect in effects:
		if effect["kind"] == kind:
			return effect
	return {}
