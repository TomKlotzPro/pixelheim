#!/usr/bin/env bash
# The check on the laptop (PIX-272). CI runs the whole suite on every pull
# request (.github/workflows/godot.yml): the import, GUT, the catalogue and
# release checks, the web export, every map booted and every flow. With four
# agents at once, each running all of it on the laptop slowed the others
# down; so the laptop runs what the branch's diff could break, in under a
# minute, and CI runs the rest.
#
#   godot/tools/check.sh quick          # what the diff could break, under a minute
#   godot/tools/check.sh quick --plan   # what quick would run and why; runs nothing
#   godot/tools/check.sh full           # everything CI runs, side by side
#   CHECK_BASE=origin/x godot/tools/check.sh quick     # the diff against another base
#   CHECK_FILES="godot/scripts/enemy.gd" godot/tools/check.sh quick --plan
#                                       # what a change to these files would run
#
# quick looks at the branch's diff against origin/main: its commits since the
# two parted, what isn't committed yet and new files. It runs
# - the release and catalogue checks (python, a second; the release script's
#   own tests too when godot/tools/*.py changed);
# - the import, only when the diff touches art, sound, fonts, scripts,
#   shaders, scenes or tests (the data's JSON is read as it is), or a pull
#   or a rebase changed some since check.sh last imported;
# - GUT headless, failed on a Parse Error too (GUT exits 0 when a test file
#   doesn't parse, and skips it);
# - beside GUT, the town booted headless by day and at night, with every map
#   the diff touches (GUT never loads world.gd nor its world_*.gd pieces, so
#   a script that breaks only there fails here), then the flows tagged with
#   the areas the diff touches: each flow's tags end its line in flows.txt,
#   and AREAS below says which areas each file touches. A changed map also
#   runs the flows that name it, a changed scripts/<x>.gd the flows whose
#   report shows open=<x>, and a changed flows.txt the flows it adds or changes.
#   A file no line of AREAS names, or whose areas no flow covers, runs every
#   flow, and quick says so; a flow without a tag AREAS knows runs every time.
# The windowed motion flow never runs here: quick says when the diff calls
# for it (player.gd, gait.gd, juice.gd, puny_art.gd, world_camera.gd), and
# CI's windowed jobs walk it in a window on every pull request (PIX-275,
# stepped since PIX-276: the same walk every time); flows.sh motion watches
# it here.
#
# full runs what CI runs: the release script's tests and its check, the
# catalogue check, the import, the web export, then GUT beside every map
# booted and every flow.
#
# Everything runs headless with the audio off (--audio-driver Dummy): no
# window opens, nothing plays. Each step's output stays in godot/flows/check/.
set -uo pipefail

cd "$(dirname "$0")/.."

# Which areas each file touches. A line is the areas, a colon, then the files
# (globs from godot/); a changed file takes the areas of the first line that
# names it. "all" runs every flow, "none" no flow (the checks, GUT and the
# town's boot still run). +name adds boots (a name from flows.sh --boot
# --list, or a glob of them) to the town's. all comes first: tools/flows.py
# is a tools/*.py, and it checks every flow.
AREAS='
all: project.godot scenes/* tools/flows.sh tools/flows.py scripts/world.gd scripts/game_clock.gd scripts/harness.gd scripts/harness_flags.gd scripts/harness_report.gd scripts/state/game_state.gd scripts/state/catalog.gd assets/data/catalog.json
none: README.md .gitignore .gutconfig.json export_presets.cfg addons/* test/unit/* test/hooks/* tools/*.py tools/check.sh tools/lookbook.sh tools/splash.sh scripts/lookbook.gd scripts/perf_probe.gd assets/puny/LICENSE.txt assets/fonts/*.txt
travel combat: scripts/world_camera.gd
combat field night: scripts/world_foes.gd
combat town: scripts/world_fx.gd scripts/state/gains.gd
combat story: scripts/world_messages.gd
town rooms trade story quest: scripts/world_interaction.gd
town field: scripts/world_soundscape.gd scripts/sound.gd scripts/desktop_look.gd assets/audio/* assets/data/audio.json assets/data/hints.json
story travel: scripts/world_stage.gd
town story: scripts/world_folk.gd scripts/npc.gd scripts/npcs.gd scripts/dialogue_box.gd scripts/reveal_screen.gd scripts/rebuild_rise.gd assets/data/npcs.json
town rooms travel +town-age*: scripts/world_tiles.gd scripts/map_view.gd scripts/map_data.gd scripts/kept_ground.gd scripts/puny_sheet.gd scripts/discovery.gd scripts/interactables.gd assets/maps/interactables.json
town +town-age*: scripts/puny_town.gd scripts/puny_props.gd scripts/shop_sign.gd scripts/state/town.gd
town rooms +town-age* +town_house*: assets/data/town.json scripts/state/settlement_state.gd scripts/state/holdings.gd scripts/state/household.gd
town: scripts/town_hall_screen.gd scripts/ledger_screen.gd scripts/bank_screen.gd scripts/ring_toss_screen.gd
rooms +town_house*: scripts/puny_interior.gd scripts/home_screen.gd assets/data/interiors.json
travel field: scripts/puny_terrain.gd scripts/scatter.gd scripts/skyline.gd assets/puny/world/*
travel: scripts/reach_plane.gd scripts/ways.gd scripts/waypoints.gd scripts/atlas.gd scripts/dissolve.gd scripts/place_title.gd scripts/map_screen.gd scripts/state/world_state.gd assets/data/plane.json
travel story +overworld*: scripts/state/gates.gd scripts/gate_art.gd assets/data/gates.json
quest travel: scripts/escort.gd
dungeon travel +seacave*: scripts/state/depths.gd assets/data/depths.json
dungeon +floor*: scripts/world_delve.gd scripts/puny_dungeon.gd scripts/dungeon_floor.gd scripts/dungeon_screen.gd scripts/state/dungeons.gd assets/puny/dungeon/*
combat dungeon: scripts/boss_brain.gd scripts/telegraph.gd scripts/boss_bar.gd
combat field dungeon gathering +floor*: assets/data/combat.json
combat field: scripts/enemy.gd scripts/elite_brain.gd scripts/firebolt.gd scripts/state/packs.gd
combat town title: scripts/player.gd scripts/gait.gd scripts/puny_art.gd assets/puny/characters/* assets/puny/beasts/* assets/puny/mini/*
combat screen: scripts/state/upkeep.gd
combat: scripts/juice.gd scripts/state/bestiary.gd scripts/state/spoils.gd scripts/state/ailments.gd
trade: scripts/shop_screen.gd scripts/state/economy.gd scripts/state/trade.gd assets/data/economy.json
trade screen: scripts/item_icons.gd scripts/state/inventory_state.gd assets/puny/icons.json assets/puny/icons/*
story: scripts/cutscene.gd scripts/dawn_screen.gd scripts/chapter_screen.gd scripts/throne_screen.gd scripts/state/story.gd scripts/state/letters.gd scripts/state/relics.gd assets/data/story.json
story night: scripts/state/prologue.gd
story quest rank: assets/data/progression.json
story quest: scripts/state/main_quest.gd scripts/state/quests.gd scripts/state/questing.gd
quest: scripts/journal_screen.gd scripts/bounty_screen.gd scripts/state/journal.gd scripts/state/bearing.gd
quest combat: scripts/state/hunts.gd
quest screen: scripts/state/deeds.gd
quest dungeon save: scripts/state/progression_state.gd
rank: scripts/rankup_screen.gd scripts/state/ranks.gd
rank screen: scripts/skills_screen.gd scripts/state/skills.gd scripts/state/training.gd
rank combat: scripts/state/hero_rules.gd
field night: scripts/day_night.gd scripts/lights.gd scripts/light_rig.gd
field: scripts/weather.gd scripts/atmosphere.gd
field rank: scripts/motes.gd
town field title: shaders/*
gathering: scripts/state/gathering.gd
save: test/fixtures/* scripts/saves_screen.gd scripts/state/save_codec.gd scripts/state/save_slots.gd scripts/state/web_import.gd scripts/state/hero_state.gd
title: scripts/title_scene.gd scripts/title_screen.gd scripts/create_screen.gd scripts/changelog_screen.gd assets/data/changelog.json assets/*.png
screen: scripts/world_hud.gd scripts/hud_dock.gd scripts/screen.gd scripts/ui_style.gd scripts/keycap.gd scripts/controls.gd scripts/touch.gd scripts/touch_controls.gd scripts/inventory_screen.gd scripts/stats_screen.gd scripts/codex_screen.gd scripts/options_screen.gd scripts/pause_screen.gd scripts/state/game_settings.gd
screen lang: assets/fonts/* scripts/ink.gd scripts/layout.gd
lang: locale/* scripts/state/text.gd
'
# The motion flow measures the walk in a window: quick asks for it after a
# change to these.
MOTION=" scripts/player.gd scripts/gait.gd scripts/juice.gd scripts/puny_art.gd scripts/world_camera.gd "

mode=${1:-}
[[ $# -gt 0 ]] && shift
plan=0
while [[ $# -gt 0 ]]; do
	case $1 in
		--plan) plan=1 ;;
		*)
			echo "check.sh: no option $1" >&2
			exit 2
			;;
	esac
	shift
done
if [[ $mode != quick && $mode != full ]] || [[ $mode == full && $plan == 1 ]]; then
	echo "usage: godot/tools/check.sh quick [--plan] | full" >&2
	exit 2
fi

root=$(git rev-parse --show-toplevel) || exit 2
out="$PWD/flows/check"
mkdir -p "$out"
GODOT=(godot --headless --audio-driver Dummy --path .)
cores=$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 4)
# Flows at once: flows.sh's cores less two, and one more for GUT beside them.
jobs=$((cores > 4 ? cores - 3 : 1))

# The time, and the seconds since one (to a tenth): bash 3.2 has no clock
# finer than a second.
now() { perl -MTime::HiRes=time -e 'printf "%.2f", time'; }
since() { perl -MTime::HiRes=time -e 'printf "%.1f", time - $ARGV[0]' "$1"; }
# Godot's output without its colours.
plain() { sed -e $'s/\x1b\\[[0-9;]*m//g' "$@"; }

failed=0
# A step's line: status, name, seconds, what it said.
say() {
	printf "%-5s %-7s %5ss  %s\n" "$1" "$2" "$3" "$4"
	[[ $1 == FAIL ]] && failed=1
	return 0
}

# step <name> <pattern> <command...>: runs it, its output in its own file;
# the line it prints is the first of the output matching the pattern, or the
# output's end when it fails.
step() {
	local name=$1 pattern=$2 start
	shift 2
	start=$(now)
	if "$@" >"$out/$name.txt" 2>&1; then
		say ok "$name" "$(since "$start")" "$(plain "$out/$name.txt" | grep -m1 -E "$pattern")"
	else
		say FAIL "$name" "$(since "$start")" "godot/flows/check/$name.txt:"
		plain "$out/$name.txt" | tail -15 | sed 's/^/      /'
		return 1
	fi
}

# When check.sh last imported: a pull or a rebase brings scripts and art the
# diff against main doesn't show, and they need importing too.
stamp=.godot/check-imported
import_now() {
	step import "." "${GODOT[@]}" --import && touch "$stamp"
}

# GUT, failed on a script that didn't parse or load as well as on a test
# (GUT skips a test file that doesn't load and still exits 0); the line it
# prints is its totals.
gut() {
	"${GODOT[@]}" -s res://addons/gut/gut_cmdln.gd >"$out/gut.txt" 2>&1
	local status=$? broken
	broken=$(grep -m1 -E "Parse Error|Failed to load script" "$out/gut.txt")
	if [[ -n $broken ]]; then
		echo "a script didn't load: $broken"
		return 1
	fi
	plain "$out/gut.txt" | grep -E "^(Tests|Passing Tests|Failing Tests) " | tr -s ' ' | paste -sd ',' - | sed 's/,/, /g'
	return $status
}

# A flows.sh run's line (its summary, or how it ended) and its failures.
ran() {
	local name=$1 file="$out/$1.txt" status=1 took=0 line
	[[ -f $out/$name.status ]] && read -r status took <"$out/$name.status"
	line=$(plain "$file" | grep -E "^(Release flows|Boot check): " | tail -1)
	[[ -z $line ]] && line=$(tail -1 "$file")
	say "$([[ $status == 0 ]] && echo ok || echo FAIL)" "$name" "$took" "$line"
	local fails
	fails=$(plain "$file" | grep -c "^FAIL ")
	plain "$file" | grep "^FAIL " | head -8 | sed 's/^/      /'
	[[ $fails -gt 8 ]] && echo "      ...and $((fails - 8)) more: godot/flows/check/$name.txt"
	return 0
}

# GUT beside the boots and then the flows: run_suite <boot names> <flow
# names>, each a space-separated list, "all" for every one or "" for none.
run_suite() {
	local boots=$1 flows=$2 start
	start=$(now)
	gut >"$out/gut.line" 2>&1 &
	local gut_pid=$!
	rm -f "$out/boot.status" "$out/flows.status"
	# flows.sh runs them all when it's given no names.
	[[ $boots == all ]] && boots=""
	(
		local t
		t=$(now)
		# shellcheck disable=SC2086 # the names are meant to split
		bash tools/flows.sh --boot -j "$jobs" $boots >"$out/boot.txt" 2>&1
		echo "$? $(since "$t")" >"$out/boot.status"
		if [[ -n $flows ]]; then
			[[ $flows == all ]] && flows=""
			t=$(now)
			# shellcheck disable=SC2086
			bash tools/flows.sh --quiet -j "$jobs" $flows >"$out/flows.txt" 2>&1
			echo "$? $(since "$t")" >"$out/flows.status"
		fi
	) &
	local lane=$!
	wait "$gut_pid"
	local status=$?
	say "$([[ $status == 0 ]] && echo ok || echo FAIL)" gut "$(since "$start")" "$(cat "$out/gut.line")"
	if [[ $status != 0 ]]; then
		# GUT's summary names each failed test and why, between its title and
		# its totals.
		{
			plain "$out/gut.txt" | grep -m3 -E "Parse Error|Failed to load script"
			plain "$out/gut.txt" | awk '/^= Run Summary/ { on = 1; next } /^Totals/ { on = 0 } on && !/^=+$/'
		} | head -25 | sed 's/^/      /'
	fi
	wait "$lane"
	ran boot
	if [[ -n $flows ]]; then
		ran flows
	else
		say ok flows 0 "none to run"
	fi
}

# --- full: what CI runs ------------------------------------------------------

if [[ $mode == full ]]; then
	started=$(now)
	step pytests "^Ran " python3 -m unittest discover -s tools -p 'test_*.py'
	step release "release check" python3 tools/release.py --check
	step i18n "current" python3 tools/i18n.py --check
	import_now
	# The export after the import and before the rest: it rewrites Godot's
	# class and uid caches, which every run beside it would read.
	version=$(godot --version | cut -d. -f1-3)
	templates=""
	for dir in "$HOME/Library/Application Support/Godot" "${XDG_DATA_HOME:-$HOME/.local/share}/godot"; do
		[[ -f "$dir/export_templates/$version.stable/web_nothreads_release.zip" ]] && templates=$dir
	done
	if [[ -n $templates ]]; then
		mkdir -p export/web
		step export "DONE.*savepack" "${GODOT[@]}" --export-release Web export/web/index.html
	else
		say skip export 0 "no web export templates for Godot $version here (CI exports)"
	fi
	echo "GUT beside every map booted, then every flow ($jobs at a time)..."
	run_suite all all
	echo "check.sh full: $([[ $failed == 1 ]] && echo FAILED || echo "all ok") in $(since "$started")s; the windowed walk is CI's windowed jobs (or godot/tools/flows.sh motion)"
	exit $failed
fi

# --- quick: what the diff could break ----------------------------------------

# No glob below expands: AREAS' patterns are matched, never listed.
set -f
started=$(now)
base=${CHECK_BASE:-origin/main}
if [[ -n ${CHECK_FILES:-} ]]; then
	changed=$(tr ' ' '\n' <<<"$CHECK_FILES" | sort -u)
	against="the files given"
else
	fork=$(git merge-base "$base" HEAD) || {
		echo "check.sh: no $base to compare with (git fetch origin?)" >&2
		exit 2
	}
	changed=$({
		git -C "$root" diff --name-only --no-renames "$fork"
		git -C "$root" ls-files --others --exclude-standard
	} | sort -u)
	against="$base (${fork:0:8}) and what isn't committed"
fi

# Every flow, as flows.sh lists it: its name, the words a map or a screen is
# found in, its tags.
names=() texts=() tags=()
while IFS="|" read -r name args expect tagged; do
	names+=("$name")
	texts+=("$args $expect")
	tags+=(" $tagged ")
done < <(bash tools/flows.sh --list)
boot_names=$(bash tools/flows.sh --boot --list | cut -d"|" -f1 | tr '\n' ' ')

# The areas AREAS names: a flow tagged with none of them could never be
# picked, so it runs every time.
known=" "
while IFS= read -r line; do
	[[ $line == *:* ]] || continue
	for word in ${line%%:*}; do
		[[ $word == +* || $known == *" $word "* ]] || known+="$word "
	done
done <<<"$AREAS"

picked=" "
everything=0
boot_picked=" town town-night "
import=""
python_tests=0
motion=""
why=""

# The boots a +pattern names, with the ones picked.
add_boots() {
	local b
	for b in $boot_names; do
		# shellcheck disable=SC2053 # the pattern is a glob
		[[ $b == $1 && $boot_picked != *" $b "* ]] && boot_picked+="$b "
	done
}

# Picks what one changed file calls for, and leaves why in $why.
pick() {
	local file=$1 areas="" label="" found="" own line pattern word i count=0 hit map="" id tier flow
	# A .uid or .import goes with its file.
	file=${file%.uid}
	file=${file%.import}
	if [[ $file != godot/* ]]; then
		why="outside the game: no flow"
		return
	fi
	file=${file#godot/}
	case $file in
		# Data the game reads as it is: nothing to import.
		assets/*.json | assets/*.txt | assets/*.tsx) ;;
		assets/* | scripts/* | shaders/* | scenes/* | addons/* | test/* | project.godot) import="the diff touches what Godot imports" ;;
	esac
	[[ $file == tools/*.py ]] && python_tests=1
	[[ $MOTION == *" $file "* ]] && motion+="${file#scripts/} "

	case $file in
		assets/maps/interactables.json) ;;
		assets/maps/*.json) map=${file#assets/maps/} map=${map%.json} ;;
		maps-src/*.txt) map=${file#maps-src/} map=${map%.txt} ;;
	esac
	if [[ $file == tools/flows.txt ]]; then
		# The flows (PIX-273): those whose lines the branch added or changed.
		# Given files, or a flows.txt git doesn't know yet, have no diff to
		# read: every flow.
		if [[ -z ${fork:-} ]] || ! git -C "$root" ls-files --error-unmatch godot/tools/flows.txt >/dev/null 2>&1; then
			everything=1
			why="the flows: every flow (no diff to read)"
			return
		fi
		for flow in $(git -C "$root" diff --no-renames -U0 "$fork" -- godot/tools/flows.txt | grep -E '^\+[a-z0-9]' | cut -d"|" -f1 | tr -d '+ '); do
			count=$((count + 1))
			[[ $picked == *" $flow "* ]] || picked+="$flow "
		done
		why="the flows: the $count it adds or changes"
		return
	fi
	if [[ -n $map ]]; then
		# A map: its boots by day and at night, and the flows that name it.
		id=${map%@*} tier=${map#"$id"}
		[[ -n $tier ]] && tier="-tier${tier#@}"
		add_boots "$id$tier"
		add_boots "$id$tier-night"
		found="(--map |map=)$id([^a-z0-9_]|$)"
		label="map $id"
	else
		while IFS= read -r line; do
			[[ $line == *:* ]] || continue
			for pattern in ${line#*:}; do
				# shellcheck disable=SC2053 # the pattern is a glob
				if [[ $file == $pattern ]]; then
					areas=${line%%:*}
					break 2
				fi
			done
		done <<<"$AREAS"
		for word in $areas; do
			[[ $word == +* ]] && add_boots "${word#+}"
		done
		areas=$(tr ' ' '\n' <<<"$areas" | grep -v '^+' | tr '\n' ' ')
		areas=${areas% }
		if [[ $areas == none ]]; then
			why="none: no flow"
			return
		elif [[ $areas == all ]]; then
			everything=1
			why="all: every flow"
			return
		elif [[ -z $areas ]]; then
			everything=1
			why="no line of AREAS names it: every flow (give it its areas in check.sh)"
			return
		fi
		# A script's own screen: the flows whose report shows it open.
		if [[ $file == scripts/*.gd ]]; then
			own=${file##*/}
			found="open=${own%.gd}([^a-z0-9_]|$)"
		fi
		label=$areas
	fi
	for i in "${!names[@]}"; do
		[[ ${names[i]} == motion ]] && continue
		hit=0
		for word in $areas; do
			[[ ${tags[i]} == *" $word "* ]] && hit=1
		done
		[[ $hit == 0 && -n $found && ${texts[i]} =~ $found ]] && hit=1
		if [[ $hit == 1 ]]; then
			count=$((count + 1))
			[[ $picked == *" ${names[i]} "* ]] || picked+="${names[i]} "
		fi
	done
	if [[ $count -gt 0 ]]; then
		why="$label: $count flows"
	elif [[ -n $map ]]; then
		why="$label: its boot (no flow names it)"
	else
		everything=1
		why="$label: no flow covers it, so every flow"
	fi
}

echo "check.sh quick: against $against"
files=0
while IFS= read -r path; do
	[[ -z $path ]] && continue
	files=$((files + 1))
	pick "$path"
	printf "  %-48s %s\n" "$path" "$why"
done <<<"$changed"
[[ $files == 0 ]] && echo "  nothing changed"
if [[ -z $import ]]; then
	if [[ ! -d .godot/imported || ! -f $stamp ]]; then
		import="check.sh hasn't imported here yet"
	elif [[ -n $(find assets scripts shaders scenes addons test project.godot -newer "$stamp" -type f \
		! -name "*.json" ! -name "*.txt" ! -name "*.tsx" 2>/dev/null | head -1) ]]; then
		import="files changed since its last import (a pull or a rebase)"
	fi
fi

# A flow no area can pick runs every time.
untagged=""
for i in "${!names[@]}"; do
	[[ ${names[i]} == motion ]] && continue
	hit=0
	for word in ${tags[i]}; do
		[[ $known == *" $word "* ]] && hit=1
	done
	if [[ $hit == 0 ]]; then
		untagged+="${names[i]} "
		[[ $picked == *" ${names[i]} "* ]] || picked+="${names[i]} "
	fi
done

flows=""
total=0
for name in "${names[@]}"; do
	[[ $name == motion ]] && continue
	total=$((total + 1))
	[[ $everything == 1 || $picked == *" $name "* ]] && flows+="$name "
done
flows=${flows% }
boot_picked=${boot_picked# }
echo "import:  ${import:+yes: }${import:-no (no art, script, shader, scene or test changed)}"
echo "boot:    ${boot_picked% }"
if [[ $everything == 1 ]]; then
	echo "flows:   every one ($total; motion needs a window)"
	flows=all
else
	echo "flows:   $(wc -w <<<"$flows" | tr -d ' ') of $total: ${flows:-none}"
fi
if [[ -n $untagged ]]; then
	echo "note:    no tag AREAS knows on ${untagged% }, so they run every time (tag them in flows.txt)"
fi
if [[ -n $motion ]]; then
	echo "motion:  the diff touches ${motion% }: CI's windowed jobs walk it in a window on the PR (or watch it here: godot/tools/flows.sh motion)"
fi
[[ $plan == 1 ]] && exit 0
echo

if [[ $python_tests == 1 ]]; then
	step pytests "^Ran " python3 -m unittest discover -s tools -p 'test_*.py'
fi
step release "release check" python3 tools/release.py --check
step i18n "current" python3 tools/i18n.py --check
if [[ -n $import ]]; then
	import_now
fi
run_suite "$boot_picked" "$flows"
echo "check.sh quick: $([[ $failed == 1 ]] && echo FAILED || echo "all ok") in $(since "$started")s; CI runs the rest"
[[ -n $motion ]] && echo "the windowed walk: CI's windowed jobs, on the PR (or godot/tools/flows.sh motion)"
exit $failed
