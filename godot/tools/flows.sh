#!/usr/bin/env bash
# The flows a release must not break (PIX-129), each driven through the
# screenshot harness on a throwaway hero. The flows themselves are in
# tools/flows.txt, one a line under its own comment (PIX-273): its name, the
# harness's arguments, the report fields it expects and its tags. Every flow
# leaves its picture in godot/flows/<name>.png for a human to look at, and
# the harness's report line must show the fields the flow expects
# (tools/flows.py matches them by name) or the run fails.
#
#   godot/tools/flows.sh            # all of them, several at a time
#   godot/tools/flows.sh fight die  # just these
#   godot/tools/flows.sh --quiet    # no window, no sound, no pictures
#   godot/tools/flows.sh -j 1       # one at a time
#   godot/tools/flows.sh --shard 2/3   # every third flow from the second (CI's shares)
#   godot/tools/flows.sh --boot     # every map booted headless, by day and at night
#   godot/tools/flows.sh --list     # every flow, a line each (--boot --list: the boots)
#   FLOWS_EXTRA="--lang fr" godot/tools/flows.sh --quiet   # every flow in French (PIX-196)
#
# Each flow ends on its tags (PIX-272): the areas of the game it walks
# through, which godot/tools/check.sh quick matches against the files a
# branch changed (flows.txt says what each area is).
#
# --quiet runs every flow headless with the audio off: nothing opens on the
# screen or plays out loud, the report lines are still checked. The motion
# flow measures pixels, so it needs a window and is skipped. A windowed run
# is muted too: its window shows, nothing plays.
#
# The flows run side by side (PIX-270), -j at a time (the machine's cores
# less two by default); each prints, in the flows' order, as the ones before
# it are done, with its time, and the five slowest close the run. A flow is
# one Godot that boots and quits, so most of a lone run's time was the
# machine waiting on a single core. Each run keeps its picture, its output
# and its log in its own folder (godot/flows/runs/<name>/), so no two share a
# file: the harness saves its picture where `--shot` says, and Godot logs
# where `--log-file` says. A harness run reads the player's settings but
# never writes them (GameSettings.read_only) nor a save (slot 0), and only a
# windowed run uses Godot's shader cache, which once warm it only reads:
# there's nothing else they could race on. In a window, each window stands
# a little apart from the others: macOS stops drawing a window that another
# one covers.
#
# Every run is stepped (PIX-276): Godot's --fixed-fps 60 makes each frame a
# sixtieth of a second of the game's time however long the machine took to
# draw it, so a flow lives the same seconds headless on a fast core, in a
# slow software-rendered window, or beside twenty others; the game reads
# that time (GameClock, never the machine's clock) and the harness throws
# the same dice every run (GameState.HARNESS_SEED). A flow is the same run
# every time, and its report the same, window or not (but draws=). A flow
# may ask for another pace with the harness's --fps N (the motion flow: a
# fast screen's frames between the physics ticks). So no flow gets a second
# try: the motion flow (timed frame by frame), the festival's and the
# board's (timed by the clock) had one, and a second try only hid what made
# the first fail. The flake hunt (.github/workflows/flakes.yml, nightly)
# runs every flow round after round under load to keep it so.
#
# --boot boots every map the game can stand in (PIX-270): each map in
# assets/maps, the village at each of its ages, the house at each of its
# tiers, every floor of the dungeons and the Deep Hunt's first depths down
# to its first warden, each by day and at night, headless. GUT never loads
# the world's scripts, so a script that breaks only there fails here. Any
# run fails on a SCRIPT ERROR, a Parse Error or a SHADER ERROR in its output
# (headless Godot still compiles every shader it loads).
#
# Under GitHub Actions the results also go to the job's summary as a table,
# and each failure as an error on the run (PIX-271).
set -uo pipefail

cd "$(dirname "$0")/.."
mkdir -p flows

quiet=0
boot=0
list=0
jobs=""
only=""
shard=1/1
while [[ $# -gt 0 ]]; do
	case $1 in
		--quiet) quiet=1 ;;
		--boot) boot=1 quiet=1 ;;
		--list) list=1 ;;
		--shard) shard=${2:-} && shift ;;
		-j) jobs=${2:-} && shift ;;
		-j*) jobs=${1#-j} ;;
		*) only+=" $1" ;;
	esac
	shift
done
# --shard K/N: every Nth flow from the Kth, for N machines to share them.
if [[ ! $shard =~ ^([1-9][0-9]*)/([1-9][0-9]*)$ ]] || ((BASH_REMATCH[1] > BASH_REMATCH[2])); then
	echo "flows.sh: --shard takes K/N, the Kth of N shares (1/2)" >&2
	exit 2
fi
shard_k=${BASH_REMATCH[1]}
shard_n=${BASH_REMATCH[2]}
if [[ -z $jobs ]]; then
	cores=$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 3)
	jobs=$((cores > 3 ? cores - 2 : 1))
fi
case $jobs in
	"" | *[!0-9]* | 0)
		echo "flows.sh: -j takes a number of flows to run at once" >&2
		exit 2
		;;
esac
# A run that never quits is killed after this many seconds (a watchdog).
watchdog=${FLOWS_WATCHDOG:-60}

# name|harness arguments|expected report fields|tags, a line each, from
# flows.txt (or, with --boot, every map the game can stand in: flows.py
# reads them from the game's own data, so a new map is checked without a
# line anywhere).
FLOWS=()
listed=$(python3 tools/flows.py list $([[ $boot == 1 ]] && echo --boot)) || exit 2
while IFS= read -r flow; do
	FLOWS+=("$flow")
done <<<"$listed"
if [[ $boot == 1 && ${#FLOWS[@]} -lt 40 ]]; then
	echo "flows.sh: the maps weren't found in the data" >&2
	exit 2
fi
# --list: the flows as they are written, for check.sh to choose from.
if [[ $list == 1 ]]; then
	printf "%s\n" "${FLOWS[@]}"
	exit 0
fi

# Measures pixels: a quiet run has none to measure, and skips it.
windowed=" motion "

# Each run's own folder: its picture, its output, its log and its result
# (the boot check's apart: its maps share names with flows).
runs="$PWD/flows/$([[ $boot == 1 ]] && echo boot || echo runs)"

# The time, and the seconds since one (to a tenth): bash 3.2 has no clock
# finer than a second.
now() { perl -MTime::HiRes=time -e 'printf "%.2f", time'; }
since() { perl -MTime::HiRes=time -e 'printf "%.1f", time - $ARGV[0]' "$1"; }

# One Godot run of a flow, in job slot $3, its output in its folder's
# output.txt. A watchdog: a run that never quits fails instead of stalling
# the rest.
run_godot() {
	local dir=$1 args=$2 slot=$3 godot watcher ran fps=60 pace=' --fps ([0-9]+) '
	local window=(--headless)
	if [[ $quiet == 0 ]]; then
		# Each slot's window a little down and right of the one before:
		# all of them on top, none of them covered whole.
		window=(--position "$((40 + slot * 48)),$((60 + slot * 36))")
	fi
	# Stepped: 60 frames a second of the game's time, or the flow's --fps.
	[[ " $args " =~ $pace ]] && fps=${BASH_REMATCH[1]}
	# shellcheck disable=SC2086 # the arguments are meant to split
	perl -e "alarm $watchdog; exec @ARGV" godot "${window[@]}" --fixed-fps "$fps" --audio-driver Dummy --log-file "$dir/godot.log" --path . -- --screenshot $args --shot "$dir/shot.png" ${FLOWS_EXTRA:-} >"$dir/output.txt" 2>&1 &
	godot=$!
	# A script that doesn't parse leaves Godot on an empty scene until the
	# watchdog: every run would wait out its minute. It has failed, so it
	# stops as soon as it says so.
	while sleep 0.5; do
		grep -q "Parse Error" "$dir/output.txt" && kill -9 "$godot"
	done >/dev/null 2>&1 &
	watcher=$!
	wait "$godot" 2>/dev/null
	ran=$?
	kill "$watcher" 2>/dev/null
	wait "$watcher" 2>/dev/null
	return $ran
}

# Whether report line $2 shows the fields flow expectation $1 asks for
# (tools/flows.py matches them by name); why not, in $why.
shows() {
	why=$(python3 tools/flows.py match "$1" "$2")
}

# Runs flow $1 (its index in FLOWS) in job slot $2 and leaves its result in
# its folder: status|name|seconds|line, written whole as its last act.
run_flow() {
	local name args expect tags
	IFS="|" read -r name args expect tags <<<"${FLOWS[$1]}"
	local dir="$runs/$name" status=ok line start ran output report errors why=""
	mkdir -p "$dir"
	start=$(now)
	run_godot "$dir" "$args" "$2"
	ran=$?
	output=$(<"$dir/output.txt")
	report=$(grep "screenshot saved" <<<"$output")
	# 128 + SIGALRM: the watchdog's.
	if [[ $ran == 142 && -z $report ]]; then
		report="none: the watchdog stopped it after ${watchdog}s"
	fi
	# A script error fails the flow even when the report looks right: a broken
	# map build once logged errors on every map but the town while the report
	# line stayed clean. So does a shader that doesn't compile: the run goes
	# on without it.
	errors=$(grep -m1 -E "SCRIPT ERROR|Parse Error|SHADER ERROR" <<<"$output")
	if [[ -n $errors ]]; then
		status=FAIL
		line=$errors
	elif shows "$expect" "$report" && [[ ($quiet == 1 || -f $dir/shot.png) ]]; then
		[[ -f $dir/shot.png ]] && mv "$dir/shot.png" "flows/$name.png"
		line=${report#screenshot saved; }
	else
		status=FAIL
		line="expected $expect (${why:-but no picture}), got: ${report:-no report}"
	fi
	printf "%s|%s|%s|%s\n" "$status" "$name" "$(since "$start")" "$line" >"$dir/result.part"
	mv "$dir/result.part" "$dir/result"
}

# The flows asked for, by index (all of them when none is named).
picked=()
for word in $only; do
	known=0
	for flow in "${FLOWS[@]}"; do
		[[ ${flow%%|*} == "$word" ]] && known=1
	done
	if [[ $known == 0 ]]; then
		echo "flows.sh: no flow is called $word" >&2
		exit 2
	fi
done
for i in "${!FLOWS[@]}"; do
	if [[ -z $only || "$only " == *" ${FLOWS[i]%%|*} "* ]] && ((i % shard_n == shard_k - 1)); then
		picked+=("$i")
	fi
done
count=${#picked[@]}
# The last run's results go first: a result in a flow's folder is this run's.
for i in ${picked[@]+"${picked[@]}"}; do
	rm -rf "${runs:?}/${FLOWS[i]%%|*}"
done

failed=0
printed=0
times=()
started=$(now)
rows=""
pid_of=()
slot_pid=()

# Prints the results that are in, in the flows' order: each waits for the
# ones before it.
flush() {
	local k name dir status took line
	while [[ $printed -lt $count ]]; do
		k=$printed
		name=${FLOWS[${picked[k]}]%%|*}
		dir="$runs/$name"
		if [[ ! -f $dir/result ]]; then
			# Still running, or never got to say: a run killed outright.
			if [[ -z ${pid_of[k]:-} ]] || kill -0 "${pid_of[k]}" 2>/dev/null || [[ -f $dir/result ]]; then
				return
			fi
			mkdir -p "$dir"
			printf "FAIL|%s|0|the run ended without a result\n" "$name" >"$dir/result"
		fi
		IFS="|" read -r status name took line <"$dir/result"
		printed=$((printed + 1))
		if [[ $status == skip ]]; then
			printf "skip  %-7s %s\n" "$name" "$line"
			continue
		fi
		printf "%-5s %-7s %5ss  %s\n" "$status" "$name" "$took" "$line"
		times+=("$took $name")
		rows+="| $status | $name | $took s | \`${line//|/\\|}\` |"$'\n'
		if [[ $status == FAIL ]]; then
			failed=1
			if [[ -n ${GITHUB_ACTIONS:-} ]]; then
				echo "::error title=flow $name failed::$line"
			fi
		fi
	done
}

# The first free job slot, in $slot, printing what finished while it waits.
free_slot() {
	local s
	while :; do
		for ((s = 0; s < jobs; s++)); do
			if [[ -z ${slot_pid[s]:-} ]] || ! kill -0 "${slot_pid[s]}" 2>/dev/null; then
				slot=$s
				return
			fi
		done
		flush
		sleep 0.1
	done
}

# Waits for every flow running, printing them as they finish.
drain() {
	local s busy=1
	while [[ $busy == 1 ]]; do
		flush
		busy=0
		for ((s = 0; s < jobs; s++)); do
			if [[ -n ${slot_pid[s]:-} ]] && kill -0 "${slot_pid[s]}" 2>/dev/null; then
				busy=1
			fi
		done
		[[ $busy == 1 ]] && sleep 0.1
	done
	wait
	flush
}

# Starts the flow at position $1 of the picked ones in a free slot.
launch() {
	local slot
	free_slot
	run_flow "${picked[$1]}" "$slot" &
	slot_pid[slot]=$!
	pid_of[$1]=$!
}

for ((k = 0; k < count; k++)); do
	name=${FLOWS[${picked[k]}]%%|*}
	if [[ $quiet == 1 && $windowed == *" $name "* ]]; then
		mkdir -p "$runs/$name"
		printf "skip|%s|0|needs a window\n" "$name" >"$runs/$name/result"
		continue
	fi
	launch "$k"
done
drain

took=$(since "$started")
title=$([[ $boot == 1 ]] && echo "Boot check" || echo "Release flows")
verdict=$([[ $failed == 1 ]] && echo "FAILED" || echo "all ok")
echo "$title: ${#times[@]} in ${took}s, $jobs at a time: $verdict"
if [[ ${#times[@]} -gt 0 ]]; then
	echo "slowest:"
	printf "%s\n" "${times[@]}" | LC_ALL=C sort -rn | head -5 | while read -r seconds name; do
		printf "  %6ss  %s\n" "$seconds" "$name"
	done
fi
if [[ -n ${GITHUB_STEP_SUMMARY:-} ]]; then
	{
		echo "### $title: $verdict"
		echo
		echo "${#times[@]} runs in ${took} s, $jobs at a time."
		echo
		failures=$(grep "^| FAIL " <<<"$rows")
		if [[ -n $failures ]]; then
			echo "| | Failed | Time | Why |"
			echo "|---|---|---|---|"
			echo "$failures"
			echo
		fi
		echo "<details><summary>Every run</summary>"
		echo
		echo "| | Run | Time | Report |"
		echo "|---|---|---|---|"
		printf "%s" "$rows"
		echo
		echo "</details>"
		echo
	} >>"$GITHUB_STEP_SUMMARY"
fi
exit $failed
