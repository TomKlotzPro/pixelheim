#!/usr/bin/env bash
# The flows a release must not break (PIX-129), each driven through the
# screenshot harness on a throwaway hero: spawn, portal, chest, shop, craft,
# quest, rank-up, fight, death and the inn, saves, and leaving a conversation
# with real key presses (PIX-131), walking without the camera shake
# (PIX-135), a named monster's bounty and board (PIX-156), the choice at
# Morvax's throne (PIX-157), a festival's ring toss (PIX-159), the road to
# Saltmere (PIX-164), its sea cave (PIX-165), the Blackiron mines (PIX-167),
# Greyhold with its cellars (PIX-168) and the Frostgate pass with its ice cave
# (PIX-169), the mountain's gate barred to a new hero (PIX-170) and a depth
# of the Deep Hunt cleared (PIX-161). Every flow leaves its picture in
# godot/flows/<name>.png for a human to look at, and the harness's report line
# must match what the flow promises or the run fails.
#
#   godot/tools/flows.sh            # all of them
#   godot/tools/flows.sh fight die  # just these
set -uo pipefail

cd "$(dirname "$0")/.."
mkdir -p flows

# name | harness arguments | what the report line must show
FLOWS=(
	"spawn|--map town|map=town cell"
	"portal|--map town portal|map=town_"
	"chest|--map town chest|map=town cell=\(61, 18\) .*gold=90"
	"shop|--map town_shop shop|map=town_shop"
	"craft|--map town_alchemist shop --tab 2|map=town_alchemist"
	"quest|--map town quest|map=town cell"
	"rankup|rankup|screenshot saved"
	"fight|fight kill|screenshot saved"
	"die|die|map=town_inn cell=\(2, 3\)"
	"saves|saves|screenshot saved"
	"talk|--map town talk --keys e,e,e,e|open=none"
	"leave|--map town talk --keys e,esc|open=none"
	"mimic|--map mirefen mimic --wait 0.75|map=mirefen cell=\(42, 13\) hp=42"
	"mayor|--map town_hall talk --keys e,e,e|open=town_hall_screen"
	"board|--map town --at 31,12 --keys w,e|open=town_hall_screen"
	"stall|--map town --town-tier 0 --at 24,14 --keys a,e|open=shop_screen"
	"road|--prologue 1|map=overworld cell=\(48, 34\)"
	"dodge|--map town --keys shift --wait 0.4|map=town cell=\(28, 33\)"
	"hunt|--map overworld --at 70,40 fight slay --foe greymaw --wait 0.3|map=overworld .*gold=160"
	"bounty|--map town --at 32,12 --cleared 4 --keys w,e|open=bounty_screen"
	"throne|--map town --cleared 15 --seen maren_confession throne --keys s,e --wait 0.5|open=reveal_screen"
	"festival|--map town --town-tier 2 --at 34,16 festival --keys w,e,e,e|open=ring_toss_screen"
	"coast|--map overworld --at 16,61 --walk d,d,d --wait 0.4|map=saltmere"
	"seacave|--map saltmere --at 7,23 --walk l --wait 0.4|map=seacave"
	"mines|--map overworld --at 2,20 --walk l,l,l --wait 0.4|map=blackiron"
	"shafts|--map blackiron --at 26,5 --walk u --wait 0.4|map=shafts"
	"castle|--map overworld --at 93,15 --walk r,r,r --wait 0.4|map=greyhold"
	"cellars|--map greyhold --at 37,13 --walk u --wait 0.4|map=cellars"
	"pass|--map overworld --at 68,2 --walk u,u,u --wait 0.4|map=frostgate"
	"icecave|--map frostgate --at 27,7 --walk u --wait 0.4|map=icecave"
	"gate|--map overworld --at 48,8 --walk u,u --wait 0.3|map=overworld cell=\\(48, 7\\).*open=none"
	"deep|--floor 16 clear --wait 0.3|map=floor_16"
	"dawn|--map town --prologue 5 --at 29,17 --keys w,e,e,e,e,e --wait 1.5|open=reveal_screen"
	"motion|--map town motion|backsteps=[01]$"
)

failed=0
for flow in "${FLOWS[@]}"; do
	IFS="|" read -r name args expect <<<"$flow"
	if [[ $# -gt 0 && ! " $* " == *" $name "* ]]; then
		continue
	fi
	rm -f screenshot.png
	# shellcheck disable=SC2086 # the arguments are meant to split
	# A watchdog: a run that never quits fails instead of stalling the rest.
	output=$(perl -e 'alarm 60; exec @ARGV' godot --path . -- --screenshot $args 2>&1)
	report=$(grep "screenshot saved" <<<"$output")
	# Smooth walking is timed frame by frame, and a long run's load can
	# hitch one: it gets a second try, so only a real regression fails.
	if [[ $name == motion ]] && ! grep -qE "$expect" <<<"$report"; then
		rm -f screenshot.png
		# shellcheck disable=SC2086
		output=$(perl -e 'alarm 60; exec @ARGV' godot --path . -- --screenshot $args 2>&1)
		report=$(grep "screenshot saved" <<<"$output")
	fi
	# A script error fails the flow even when the report looks right: a broken
	# map build once logged errors on every map but the town while the report
	# line stayed clean.
	errors=$(grep -m1 "SCRIPT ERROR" <<<"$output")
	if [[ -n "$errors" ]]; then
		failed=1
		printf "FAIL  %-7s %s\n" "$name" "$errors"
	elif [[ -f screenshot.png ]] && grep -qE "$expect" <<<"$report"; then
		mv screenshot.png "flows/$name.png"
		printf "ok    %-7s %s\n" "$name" "${report#screenshot saved; }"
	else
		failed=1
		printf "FAIL  %-7s expected /%s/, got: %s\n" "$name" "$expect" "${report:-no report}"
	fi
done
exit $failed
