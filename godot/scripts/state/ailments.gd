class_name Ailments
extends RefCounted
## Status effects on one combatant (combat.ts), in real time: a web turn lasts
## TURN_SECONDS. Poison and burn deal their power every turn; stun holds the
## combatant for its turns. A re-roll of the same kind refreshes it to the
## higher duration and power, never stacking (rollInfliction).

const TURN_SECONDS := 1.0
const VERBS := {"poison": "Poison", "burn": "The burn"}

## {kind, turnsLeft, power}
var effects: Array[Dictionary] = []
var _clock := 0.0


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
	var current := _find(kind)
	var refreshed := {
		"kind": kind,
		"turnsLeft": maxi(int(infliction["turns"]), int(current.get("turnsLeft", 0))),
		"power": maxi(int(infliction["power"]), int(current.get("power", 0))),
	}
	effects = effects.filter(func(effect: Dictionary) -> bool: return effect["kind"] != kind)
	effects.append(refreshed)
	return true


## Advances the clock; on each elapsed turn, damage ticks fire and every
## effect (stun included) spends a turn. Returns [{kind, damage}] ticks.
func tick(delta: float) -> Array[Dictionary]:
	var ticks: Array[Dictionary] = []
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


func clear() -> void:
	effects.clear()
	_clock = 0.0


func _find(kind: String) -> Dictionary:
	for effect in effects:
		if effect["kind"] == kind:
			return effect
	return {}
