extends "res://scripts/ledger_screen.gd"
## The stat sheet (WorldHud's sheet + statInfo): who the hero is, the pools
## and defenses, and the five stats with what each point would buy, spent
## here with E. C or Esc closes it.


func _title() -> String:
	return "Stats"


func _intro() -> String:
	var points := GameState.hero.stat_points
	if points == 0:
		return Text.t("Every level brings %d stat points to spend.") % Bestiary._data()["statPointsPerLevel"]
	return Text.t("%d stat point%s to spend. Spending is permanent.") % [points, "" if points == 1 else "s"]


func _info() -> String:
	var hero := GameState.hero
	var pack := GameState.pack
	var path := HeroRules.walked(hero)
	var identity: String = HeroRules.path_node(path[-1])["name"] if not path.is_empty() else Catalog.role(hero.role_id)["name"]
	var resource := Skills.resource_label(hero.role_id)
	var lines: Array[String] = [
		"%s, %s" % [hero.hero_name, identity],
		Text.t("Lv %d %s") % [hero.level, Ranks.title(hero.role_id, hero.level)],
		"",
		Text.t("HP %d/%d    %s %d/%d") % [hero.hp, hero.stats["maxHp"], resource, hero.mp, hero.stats["maxMp"]],
		Text.t("DEF %d    Carry %d/%d") % [HeroRules.total_defense(hero, pack), pack.carried_weight(), Skills.carry_capacity(hero, pack)],
	]
	# Armour sets worn (PIX-166): what each gives at the pieces worn.
	var sets := pack.set_counts()
	for set_id: String in sets:
		lines.append(Catalog.set_line(set_id, int(sets[set_id])))
	if selected < Skills.STATS.size():
		var stat: String = Skills.STATS[selected]
		var info := Skills.info(stat, hero, pack)
		lines.append_array([
			"", "%s %d" % [Text.t(Skills.ABBR[stat]), hero.stats[stat]], String(info["blurb"]),
			Text.t("Now: %s") % info["now"], Text.t("With a point: %s") % info["next"],
		])
	return "\n".join(lines)


func _rows() -> Array[Dictionary]:
	var hero := GameState.hero
	var rows_out: Array[Dictionary] = []
	for stat: String in Skills.STATS:
		rows_out.append({
			"label": "%s  %d" % [Text.t(Skills.ABBR[stat]), hero.stats[stat]],
			"note": "+1" if hero.stat_points > 0 else "",
			"enabled": hero.stat_points > 0,
			"why": "No stat points to spend. Level up to earn more.",
			"action": _spend.bind(stat),
		})
	return rows_out


func _spend(stat: String) -> String:
	GameState.spend_stat_point(stat)
	Sound.play_ui("confirm")
	return Text.t("%s %d: %s") % [Text.t(Skills.ABBR[stat]), GameState.hero.stats[stat], Skills.readout(stat, GameState.hero, GameState.pack)]


func _open() -> void:
	closing_actions = [&"stats"]
	super()
