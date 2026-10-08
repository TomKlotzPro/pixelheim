#!/usr/bin/env bash
# The flows a release must not break (PIX-129), each driven through the
# screenshot harness on a throwaway hero: spawn, portal, chest, shop, craft,
# quest, rank-up, fight, death and the inn, saves, and leaving a conversation
# with real key presses (PIX-131), and walking without the camera shake
# (PIX-135). Every flow leaves its
# picture in godot/flows/<name>.png for a human to look at, and the harness's
# report line must match what the flow promises or the run fails.
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
	"talk|--map town talk --keys e,e,e|open=none"
	"leave|--map town talk --keys e,esc|open=none"
	"mimic|--map mirefen mimic --wait 0.75|map=mirefen cell=\(42, 13\) hp=42"
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
	report=$(perl -e 'alarm 60; exec @ARGV' godot --path . -- --screenshot $args 2>&1 | grep "screenshot saved")
	if [[ -f screenshot.png ]] && grep -qE "$expect" <<<"$report"; then
		mv screenshot.png "flows/$name.png"
		printf "ok    %-7s %s\n" "$name" "${report#screenshot saved; }"
	else
		failed=1
		printf "FAIL  %-7s expected /%s/, got: %s\n" "$name" "$expect" "${report:-no report}"
	fi
done
exit $failed
