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
	var inv := GameState.holdings.investments()
	var steps := GameState.holdings.steps_now()
	var lines: Array[String] = [Text.t("Savings")]
	var savings: Dictionary = inv.get("savings", {})
	var rate := Town.savings_rate(GameState.holdings.perk_grown("settler_mirelle")) * 100.0
	if savings.is_empty():
		lines.append(Text.t("Nothing deposited. %s%% a day on what's in, up to %d%% in all.") % [
			String.num(rate, 2), roundi(float(Town.bank("savingsCapShare")) * 100),
		])
	else:
		# What the pot has earned so far, and the most it can (PIX-177).
		var now := Town.savings_accrued(savings, steps, GameState.holdings.perk_grown("settler_mirelle"))
		lines.append(Text.t("%dg deposited, %dg earned so far (at most %dg).") % [
			now["principal"], now["earned"], Town.savings_cap(int(now["principal"])),
		])
	lines.append_array(["", Text.t("Caravan")])
	var venture: Dictionary = inv.get("venture", {})
	if venture.is_empty():
		lines.append(Text.t("No caravan on the road. Stake %dg: two roads in three come home heavy.") % Town.bank("ventureCost"))
	elif Town.venture_ready(venture["at"], steps):
		lines.append(Text.t("The caravan is back. Collect what it brought."))
	else:
		lines.append(Text.t("On the road: %dg staked, back in %d steps.") % [
			venture["stake"], int(Town.bank("ventureSteps")) - (steps - int(venture["at"])),
		])
	lines.append_array(["", Text.t("Expansions (+%d%% daily rent each)") % roundi(float(Town._data()["rent"]["expansionBoost"]) * 100)])
	if GameState.settlement.properties.is_empty():
		lines.append(Text.t("Own a business first: buy its deed from the keeper."))
	return "\n".join(lines)


func _rows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var inv := GameState.holdings.investments()
	for amount: int in DEPOSITS:
		out.append({
			"label": Text.t("Deposit %dg") % amount, "note": "", "enabled": GameState.pack.gold >= amount,
			"why": "Not enough gold.",
			"action": func() -> String: return Text.t("Deposited %dg.") % amount if GameState.holdings.bank_deposit(amount) else "",
		})
	var purse := GameState.pack.gold
	out.append({
		"label": "Deposit all", "note": Text.coins(purse), "enabled": purse > 0, "why": "Not a coin to deposit.",
		"action": func() -> String:
			var all := GameState.pack.gold
			return Text.t("Deposited %dg.") % all if GameState.holdings.bank_deposit(all) else "",
	})
	var savings: Dictionary = inv.get("savings", {})
	out.append({
		"label": "Withdraw all", "enabled": not savings.is_empty(), "why": "Nothing to withdraw.",
		"note": "" if savings.is_empty() else Text.coins(Town.savings_value(savings, GameState.holdings.steps_now(), GameState.holdings.perk_grown("settler_mirelle"))),
		"action": func() -> String: return Text.t("Withdrawn: %dg. Mirelle stamps the ledger.") % GameState.holdings.bank_withdraw(),
	})
	var venture: Dictionary = inv.get("venture", {})
	if venture.is_empty():
		var cost := int(Town.bank("ventureCost"))
		out.append({
			"label": "Send a caravan", "note": Text.coins(cost), "enabled": GameState.pack.gold >= cost,
			"why": Text.t("The caravan needs %dg.") % cost,
			"action": func() -> String: return "The caravan rolls out. Give it half a day on the road." if GameState.holdings.fund_venture() else "",
		})
	else:
		out.append({
			"label": "Collect the caravan", "note": "",
			"enabled": Town.venture_ready(venture["at"], GameState.holdings.steps_now()), "why": "It is still on the road.",
			"action": func() -> String:
				var outcome := GameState.holdings.collect_venture()
				if outcome.is_empty():
					return ""
				return Text.t("The caravan returns heavy! +%dg.") % outcome["payout"] if outcome["won"] else Text.t("Raiders hit the caravan. %dg salvaged from the wreck.") % outcome["payout"],
		})
	var expansions: Array = inv["expansions"]
	for map_id: String in GameState.settlement.properties:
		var deed: Dictionary = Town.deeds()[map_id]
		var done := map_id in expansions
		var cost := int(Town.bank("expansionCost"))
		out.append({
			"label": Text.t("Expand %s") % deed["name"], "note": Text.t("expanded") if done else Text.coins(cost),
			"enabled": not done and GameState.pack.gold >= cost,
			"why": "Already expanded." if done else Text.t("An expansion costs %dg.") % cost,
			"action": func() -> String: return "The expansion is funded: that business pays richer rent now." if GameState.holdings.expand_property(map_id) else "",
		})
	return out
