extends "res://scripts/ledger_screen.gd"
## Mirelle's bank (Bank.tsx), open once she has settled in town: a savings
## pot that grows by the day-wheel, one caravan at a time, and expansions on
## owned businesses. Everything resolves from world steps, like the web.

const DEPOSITS := [100, 500, 2000]


func _title() -> String:
	return "Mirelle's bank"


func _intro() -> String:
	return "Idle gold is lazy gold. Savings, a caravan, an expansion: put it to work."


func _info() -> String:
	var inv := GameState.investments()
	var steps := GameState.steps_now()
	var lines: Array[String] = ["Savings"]
	var savings: Dictionary = inv.get("savings", {})
	if savings.is_empty():
		lines.append("Nothing deposited. %d%% a day, up to %d days." % [
			roundi(float(Town.arc("mirelleRate") if GameState.perk_grown("settler_mirelle") else Town.bank("savingsRate")) * 100), Town.bank("savingsMaxDays"),
		])
	else:
		lines.append("%dg deposited, worth %dg now (%d of %d days)." % [
			savings["principal"], Town.savings_value(savings["principal"], savings["at"], steps, GameState.perk_grown("settler_mirelle")),
			Town.savings_days(savings["at"], steps), Town.bank("savingsMaxDays"),
		])
	lines.append_array(["", "Caravan"])
	var venture: Dictionary = inv.get("venture", {})
	if venture.is_empty():
		lines.append("No caravan on the road. Stake %dg: two roads in three come home heavy." % Town.bank("ventureCost"))
	elif Town.venture_ready(venture["at"], steps):
		lines.append("The caravan is back. Collect what it brought.")
	else:
		lines.append("On the road: %dg staked, back in %d steps." % [
			venture["stake"], int(Town.bank("ventureSteps")) - (steps - int(venture["at"])),
		])
	lines.append_array(["", "Expansions (+%dg rent per victory each)" % Town.bank("expansionRent")])
	if GameState.settlement.properties.is_empty():
		lines.append("Own a business first: buy its deed from the keeper.")
	return "\n".join(lines)


func _rows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var inv := GameState.investments()
	for amount: int in DEPOSITS:
		out.append({
			"label": "Deposit %dg" % amount, "note": "", "enabled": GameState.pack.gold >= amount,
			"why": "Not enough gold.",
			"action": func() -> String: return "Deposited %dg." % amount if GameState.bank_deposit(amount) else "",
		})
	var savings: Dictionary = inv.get("savings", {})
	out.append({
		"label": "Withdraw all", "enabled": not savings.is_empty(), "why": "Nothing to withdraw.",
		"note": "" if savings.is_empty() else "%dg" % Town.savings_value(savings["principal"], savings["at"], GameState.steps_now(), GameState.perk_grown("settler_mirelle")),
		"action": func() -> String: return "Withdrawn: %dg. Mirelle stamps the ledger." % GameState.bank_withdraw(),
	})
	var venture: Dictionary = inv.get("venture", {})
	if venture.is_empty():
		var cost := int(Town.bank("ventureCost"))
		out.append({
			"label": "Send a caravan", "note": "%dg" % cost, "enabled": GameState.pack.gold >= cost,
			"why": "The caravan needs %dg." % cost,
			"action": func() -> String: return "The caravan rolls out. Give it half a day on the road." if GameState.fund_venture() else "",
		})
	else:
		out.append({
			"label": "Collect the caravan", "note": "",
			"enabled": Town.venture_ready(venture["at"], GameState.steps_now()), "why": "It is still on the road.",
			"action": func() -> String:
				var outcome := GameState.collect_venture()
				if outcome.is_empty():
					return ""
				return "The caravan returns heavy! +%dg." % outcome["payout"] if outcome["won"] else "Raiders hit the caravan. %dg salvaged from the wreck." % outcome["payout"],
		})
	var expansions: Array = inv["expansions"]
	for map_id: String in GameState.settlement.properties:
		var deed: Dictionary = Town.deeds()[map_id]
		var done := map_id in expansions
		var cost := int(Town.bank("expansionCost"))
		out.append({
			"label": "Expand %s" % deed["name"], "note": "expanded" if done else "%dg" % cost,
			"enabled": not done and GameState.pack.gold >= cost,
			"why": "Already expanded." if done else "An expansion costs %dg." % cost,
			"action": func() -> String: return "The expansion is funded: that business pays richer rent now." if GameState.expand_property(map_id) else "",
		})
	return out
