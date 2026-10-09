class_name Upkeep
extends RefCounted
## The hero's body and kit (PIX-261, out of game_state.gd): hits, heals and
## what comes back at rest, what the pack can carry, what is worn and how the
## hero is drawn in it, dropping and using items, and the inn's bed, paid for
## or woken in after a fall. It holds nothing of its own: the hero and the
## pack are GameState's, reached through `owner`.

const GameStateScript := preload("res://scripts/state/game_state.gd")

## The GameState this works on, never the `GameState` autoload: tests build
## their own (GameStateScript.new()), and a module reaching the autoload
## would change the real game's state from inside one. Signals are its too.
var owner: GameStateScript


func _init(state: GameStateScript) -> void:
	owner = state


## A monster's blow lands on the hero; returns true when it was the last.
func hurt(amount: int) -> bool:
	owner.hero.hp = maxi(0, owner.hero.hp - amount)
	owner.mark_dirty()
	owner.hp_changed.emit(owner.hero.hp, int(owner.hero.stats["maxHp"]))
	return owner.hero.hp == 0


## A heal that lands, up to the cap; returns how much took.
func heal_hero(amount: int) -> int:
	var healed_by := mini(int(owner.hero.stats["maxHp"]), owner.hero.hp + amount) - owner.hero.hp
	owner.hero.hp += healed_by
	owner.mark_dirty()
	owner.healed.emit()
	owner.hp_changed.emit(owner.hero.hp, int(owner.hero.stats["maxHp"]))
	return healed_by


## Out of a fight every hero's mana or stamina trickles back (PIX-187): a
## twentieth of it each rest tick, at least one. Returns what came back.
func regen_resting() -> int:
	# Candles at home bring it back a point faster (PIX-179).
	var step := maxi(1, ceili(int(owner.hero.stats["maxMp"]) * 0.05)) + roundi(owner.household.home_buff("regen"))
	var back := mini(int(owner.hero.stats["maxMp"]), owner.hero.mp + step) - owner.hero.mp
	# Health trickles back too (PIX-206), slowly: a bed or a potion is quicker.
	var mended := 0
	if owner.hero.hp > 0:
		mended = mini(int(owner.hero.stats["maxHp"]), owner.hero.hp + rest_mend()) - owner.hero.hp
	if back > 0 or mended > 0:
		owner.hero.mp += back
		owner.hero.hp += mended
		owner.mark_dirty()
		owner.hp_changed.emit(owner.hero.hp, int(owner.hero.stats["maxHp"]))
	return back


## The health a quiet moment gives back (PIX-206): a hundredth, at least one.
func rest_mend() -> int:
	return maxi(1, floori(int(owner.hero.stats["maxHp"]) * 0.01))


## A fighter's stamina comes back each turn of a fight (staminaRegen, from
## monsterTurn); casters' mana does not. Returns what came back.
func regen_stamina() -> int:
	var back := mini(int(owner.hero.stats["maxMp"]), owner.hero.mp + Skills.stamina_regen(owner.hero)) - owner.hero.mp
	if back > 0:
		owner.hero.mp += back
		owner.mark_dirty()
		owner.hp_changed.emit(owner.hero.hp, int(owner.hero.stats["maxHp"]))
	return back


## The health a potion gives back (PIX-217): its own, or a share of the
## hero's whole health where it has one, whichever is more.
func hp_restore(item: Dictionary) -> int:
	return maxi(int(item.get("restoreHp", 0)), roundi(float(item.get("restoreHpShare", 0.0)) * int(owner.hero.stats["maxHp"])))


## 60 + 3 per point of strength (worn grants included) + carry passives.
func carry_capacity() -> int:
	var strength: int = owner.hero.stats.get("strength", 0) + owner.pack.granted_stat("strength")
	return 60 + strength * 3 + int(HeroRules.passives(owner.hero)["carryBonus"])


## The hero as drawn: the role's look in whatever is worn (PunyArt.dressed).
func hero_art() -> Dictionary:
	return PunyArt.dressed(owner.hero.role_id, owner.hero.look, owner.pack.worn_items())


## Puts on a gear piece (EQUIP): into its slot, a ring onto the empty finger
## (else the first). Whatever was there goes back to the pack.
func equip(uid: String) -> bool:
	var instance := owner.pack.gear_by_uid(uid)
	if instance.is_empty() or owner.pack.is_equipped(uid):
		return false
	var slot: String = Catalog.item(instance["itemId"]).get("slot", "")
	if slot == "":
		return false
	if slot == "ring":
		slot = "ring1" if not owner.pack.equipped.has("ring1") else ("ring2" if not owner.pack.equipped.has("ring2") else "ring1")
	owner.pack.equipped[slot] = uid
	owner.pack_changed()
	owner.hp_changed.emit(owner.hero.hp, int(owner.hero.stats["maxHp"]))
	# Sela's cap on (PIX-197): the night moves on to the fires.
	if owner.progression.prologue == Prologue.CAP and slot == "head":
		owner.questing.prologue_on()
		owner.message.emit(Prologue.objective(owner.progression.prologue, 0, owner.questing.first_skill_heals()))
	return true


## Takes off whatever fills a slot (UNEQUIP).
func unequip(slot: String) -> bool:
	if not owner.pack.equipped.has(slot):
		return false
	owner.pack.equipped.erase(slot)
	owner.pack_changed()
	return true


## Leaves items on the road (DROP): one, or `count` of them.
func drop_item(item_id: String, count := 1) -> bool:
	if owner.pack.items.get(item_id, 0) <= 0:
		return false
	owner.pack.remove_item(item_id, count)
	owner.pack_changed()
	return true


## Leaves a gear piece behind (DROP_GEAR); never one being worn.
func drop_gear(uid: String) -> bool:
	if owner.pack.is_equipped(uid) or owner.pack.gear_by_uid(uid).is_empty():
		return false
	owner.pack.gear.assign(owner.pack.gear.filter(func(piece: Dictionary) -> bool: return piece["uid"] != uid))
	owner.pack_changed()
	return true


## Drinks or eats something (USE_ITEM): health and mana up to their caps.
## The cure, if any, is for the world to apply to the hero's live ailments.
## Returns {used, text, cures}.
func use_item(item_id: String) -> Dictionary:
	var item := Catalog.item(item_id)
	if owner.pack.items.get(item_id, 0) <= 0 or not (item.has("restoreHp") or item.has("restoreMp") or item.has("cures")):
		return {"used": false, "text": "", "cures": ""}
	owner.pack.remove_item(item_id)
	var parts: Array[String] = []
	# The Healers' Hall makes every potion stronger (PIX-180).
	var potency := 1.0 + owner.holdings.commission_buff("potion") + owner.household.home_buff("potion")
	if item.has("restoreHp"):
		var healed := mini(int(owner.hero.stats["maxHp"]), owner.hero.hp + roundi(hp_restore(item) * potency)) - owner.hero.hp
		owner.hero.hp += healed
		parts.append(Text.t("%d HP") % healed)
	if item.has("restoreMp"):
		var restored := mini(int(owner.hero.stats["maxMp"]), owner.hero.mp + roundi(int(item["restoreMp"]) * potency)) - owner.hero.mp
		owner.hero.mp += restored
		parts.append("%d %s" % [restored, Skills.resource_label(owner.hero.role_id)])
	owner.pack_changed()
	owner.healed.emit()
	owner.hp_changed.emit(owner.hero.hp, int(owner.hero.stats["maxHp"]))
	var text := Text.t("You use %s.") % item["name"]
	if not parts.is_empty():
		text += Text.t(" Restored %s.") % ", ".join(parts)
	return {"used": true, "text": text, "cures": item.get("cures", "")}


## The inn: a bed for coin, half price in a town (restAtInn). Returns the
## innkeeper's line.
func rest_at_inn() -> String:
	var cost := Town.rest_cost_for(owner.town_tier())
	var whole: bool = owner.hero.hp == owner.hero.stats.get("maxHp", owner.hero.hp) and owner.hero.mp == owner.hero.stats.get("maxMp", owner.hero.mp)
	if whole:
		return Text.t("The innkeeper nods. You are already well rested.")
	if owner.pack.gold < cost:
		return Text.t("No coin, no bed: a night costs %d gold.") % cost
	owner.pack.gold -= cost
	owner.make_whole()
	owner.spoils.wake_the_wilds()
	# The inn rebuilt (PIX-206): a real bed leaves the hero rested a while.
	var line := Text.t("You rest at the inn and wake fully restored. -%d gold.") % cost
	if owner.holdings.project_built("the_inn"):
		var fights := int(Town._data()["rested"]["innFights"])
		owner.settlement.house["rested"] = maxi(int(owner.settlement.house.get("rested", 0)), fights)
		line += " " + Text.t("Well rested, too: more XP for your next %d fights.") % fights
	owner.pack_changed()
	return line


## Defeat is forgiving (RETURN_TO_WORLD after a loss): wake at the village
## inn, healed, purse intact. Returns where to wake.
func wake_at_inn() -> Dictionary:
	owner.settlement.bard_song = false
	var inn: Dictionary = Catalog._data()["innRest"]
	# With the inn still rubble, Sela's tent on the square takes them in.
	var tent := Town.ashes_tent(Town.done_projects(owner.settlement))
	if tent.x >= 0:
		inn = {"mapId": "town", "x": tent.x, "y": tent.y + 1, "facing": "down"}
	owner.make_whole()
	# A fall doesn't wake the wilds (PIX-206): what was cleared stays cleared,
	# and what was not is still out there. A night's rest wakes them.
	# It costs a tenth of the gold carried (PIX-192), never what's banked;
	# the night of the fire is a lesson, not a toll.
	var lost := owner.spoils.death_toll()
	owner.pack.gold -= lost
	owner.pack_changed()
	owner.save_now()
	if lost > 0:
		owner.message.emit(Text.t("You wake at the inn, %d gold lighter. What isn't banked is a fallen hero's to lose.") % lost)
	else:
		owner.message.emit(Text.t("You wake at the inn. The innkeeper says nothing. Kind of her."))
	return inn
