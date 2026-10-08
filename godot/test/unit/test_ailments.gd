extends GutTest
## Status effects in real time (combat.ts rollInfliction / tickDamageEffects /
## consumeStun): one web turn per Ailments.TURN_SECONDS.

const POISON := {"kind": "poison", "chance": 0.4, "turns": 3, "power": 5}
const STUN := {"kind": "stun", "chance": 0.3, "turns": 1, "power": 0}

var always := func() -> float: return 0.0
var never := func() -> float: return 0.99


func test_inflictions_roll_their_chance() -> void:
	var ail := Ailments.new()
	assert_false(ail.inflict(POISON, never))
	assert_true(ail.inflict(POISON, always))
	assert_eq(ail.kinds(), ["poison"])
	assert_false(ail.inflict(null, always), "an attacker without an ailment")


func test_resist_passives_shrug_off_their_kind() -> void:
	var ail := Ailments.new()
	assert_false(ail.inflict(POISON, always, {"poisonResist": true}))
	assert_false(ail.inflict(STUN, always, {"stunResist": true}))
	assert_true(ail.inflict(STUN, always, {"poisonResist": true}))


func test_a_reroll_refreshes_to_the_higher_values_never_stacking() -> void:
	var ail := Ailments.new()
	ail.inflict({"kind": "poison", "chance": 1.0, "turns": 2, "power": 9}, always)
	ail.inflict(POISON, always)
	assert_eq(ail.effects, [{"kind": "poison", "turnsLeft": 3, "power": 9}])


func test_damage_ticks_once_per_turn_until_it_wears_off() -> void:
	var ail := Ailments.new()
	ail.inflict(POISON, always)
	assert_eq(ail.tick(0.5), [], "half a turn: nothing yet")
	assert_eq(ail.tick(0.5), [{"kind": "poison", "damage": 5}])
	assert_eq(ail.tick(2.0).size(), 2, "two turns at once")
	assert_eq(ail.kinds(), [], "three turns, then gone")
	assert_eq(ail.tick(5.0), [])


func test_stun_holds_for_its_turns_and_deals_nothing() -> void:
	var ail := Ailments.new()
	ail.inflict(STUN, always)
	assert_true(ail.is_stunned())
	assert_eq(ail.tick(1.0), [])
	assert_false(ail.is_stunned())


func test_clear_wipes_everything() -> void:
	var ail := Ailments.new()
	ail.inflict(POISON, always)
	ail.inflict(STUN, always)
	ail.clear()
	assert_eq(ail.kinds(), [])


## PIX-186: a boss or an elite shrugs off a second stun while the first is
## remembered, and takes one again after a calm.
func test_a_guarded_monster_shrugs_off_stuns_for_a_while() -> void:
	var guarded := Ailments.new()
	guarded.stun_guard = 6.0
	var stun := {"kind": "stun", "chance": 1.0, "turns": 1, "power": 0}
	var sure := func() -> float: return 0.0
	assert_true(guarded.inflict(stun, sure), "the first stun holds")
	guarded.tick(1.0)
	assert_false(guarded.is_stunned())
	assert_false(guarded.inflict(stun, sure), "a second, soon after, is shrugged off")
	guarded.tick(5.5)
	assert_true(guarded.inflict(stun, sure), "after a calm, it can be stunned again")
	var plain := Ailments.new()
	assert_true(plain.inflict(stun, sure))
	plain.tick(1.0)
	assert_true(plain.inflict(stun, sure), "an ordinary monster has no guard")
