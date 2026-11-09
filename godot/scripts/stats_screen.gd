extends "res://scripts/ledger_screen.gd"
## areas: screen
## The stat sheet (WorldHud's sheet + statInfo): who the hero is, the pools
## and defenses, and the five stats with what each point would buy, spent
## here with E. C or Esc closes it.


func _title() -> String:
	return "Stats"


func _intro() -> String:
	var points := GameState.hero.stat_points
	if Skills.beyond_open(GameState.hero):
		return Text.t("Your tree is whole: %d skill point%s to spend beyond it, below.") % [GameState.hero.skill_points, "" if GameState.hero.skill_points == 1 else "s"]
	if points == 0:
		return Text.t("Every level brings %d stat points to spend.") % Bestiary.stat_points_per_level()
	# Only the shrine's keeper takes them back (PIX-331), for a price.
	return Text.t("%d stat point%s to spend. %s at the shrine can undo it, for a price.") % [points, "" if points == 1 else "s", Npcs.by_id(Skills.FORGETTER, [])["name"]]


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
		var about: Array[String] = [
			"%s %d" % [Text.t(Skills.ABBR[stat]), hero.stats[stat]], String(info["blurb"]),
			Text.t("Now: %s") % info["now"], Text.t("With a point: %s") % info["next"],
		]
		# Large text keeps one line of who the hero is over the chosen stat's
		# words (PIX-442): with the whole sheet they ran under the keys.
		if GameState.settings.large_text:
			return "\n".join(["%s, %s" % [hero.hero_name, Text.t("Lv %d") % hero.level]] + about)
		lines.append("")
		lines.append_array(about)
	return "\n".join(lines)


## Its own key closes it too, and says so (PIX-388), as the pack's does.
func _footer() -> String:
	return Text.t("{key:move_up}/{key:move_down}  choose      {key:interact}  %s      {key:stats} / Esc  close") % _verb()


func _rows() -> Array[Dictionary]:
	var hero := GameState.hero
	var rows_out: Array[Dictionary] = []
	# The stat the weapon in hand scales with is tagged; bare hands have none.
	var held := HeroRules.weapon_stat(GameState.pack) if not HeroRules.weapon(GameState.pack).is_empty() else ""
	for stat: String in Skills.STATS:
		rows_out.append({
			"icon": ItemIcons.stat(stat),
			"tag": Text.t("Weapon") if stat == held else "",
			"label": "%s  %d" % [Text.t(Skills.ABBR[stat]), hero.stats[stat]],
			"note": "+1" if hero.stat_points > 0 else "",
			"enabled": hero.stat_points > 0,
			"why": "No stat points to spend. Level up to earn more.",
			"action": _spend.bind(stat),
		})
	# Beyond a whole tree (PIX-217): its spare skill points buy ranks here.
	if Skills.tree_whole(hero):
		for track: Dictionary in Skills.beyond_tracks():
			var rank := int(hero.beyond.get(track["id"], 0))
			rows_out.append({
				"label": Text.t("Beyond the tree: %s") % Text.t(track["name"]),
				"note": "%d/%d" % [rank, int(track["cap"])],
				"enabled": Skills.can_buy_beyond(hero, track),
				"why": Text.t("Mastered.") if rank >= int(track["cap"]) else Text.t("No skill points to spend."),
				"action": _beyond.bind(track),
			})
	return rows_out


func _beyond(track: Dictionary) -> String:
	GameState.training.buy_beyond(track["id"])
	Sound.play("stat_point")
	return Text.t("%s: %s. %d/%d.") % [Text.t(track["name"]), Text.t(track["line"]), int(GameState.hero.beyond[track["id"]]), int(track["cap"])]


func _spend(stat: String) -> String:
	GameState.training.spend_stat_point(stat)
	Sound.play("stat_point")
	return Text.t("%s %d: %s") % [Text.t(Skills.ABBR[stat]), GameState.hero.stats[stat], Skills.readout(stat, GameState.hero, GameState.pack)]


func _open() -> void:
	closing_actions = [&"stats"]
	# On the stat the weapon asks for, whatever the role (PIX-442).
	selected = maxi(0, Skills.STATS.find(HeroRules.weapon_stat(GameState.pack)))
	super()
