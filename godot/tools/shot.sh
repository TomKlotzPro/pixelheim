#!/usr/bin/env bash
# A harness picture that stays out of Tom's way (PIX-407): one windowed
# --screenshot run, muted, that on macOS opens in the background (open -g)
# and so never takes the focus or comes in front of what he's working in.
# The report line prints as a plain godot run's would. Elsewhere (CI's
# Linux) it runs godot as is.
#
#   godot/tools/shot.sh [--res WxH] <harness args...> --shot <file>
#   godot/tools/shot.sh --res 1280x720 --lang fr --map town night --shot /tmp/town.png
#
# A relative --shot is taken from where it's run, as godot's own would be.
set -euo pipefail
here=$(cd "$(dirname "$0")/.." && pwd)
pre=()
if [[ "${1:-}" == "--res" ]]; then
	pre=(--resolution "$2")
	shift 2
fi
args=()
while (($#)); do
	if [[ "$1" == "--shot" && $# -gt 1 && "$2" != /* ]]; then
		args+=("$1" "$PWD/$2")
		shift 2
		continue
	fi
	args+=("$1")
	shift
done
if [[ "$(uname)" != Darwin ]]; then
	exec godot "${pre[@]+"${pre[@]}"}" --audio-driver Dummy --path "$here" -- --screenshot "${args[@]+"${args[@]}"}"
fi
# The app around the godot on the PATH (…/Godot.app/Contents/MacOS/Godot).
app=$(readlink -f "$(command -v godot)")
app=${app%/Contents/MacOS/*}
out=$(mktemp)
trap 'rm -f "$out"' EXIT
# -g: in the background, never in front; -n: a fresh instance each run; -W:
# wait for it to quit, so the picture is there when this returns.
open -g -n -W -a "$app" --stdout "$out" --stderr "$out" --args "${pre[@]+"${pre[@]}"}" --audio-driver Dummy --path "$here" -- --screenshot "${args[@]+"${args[@]}"}"
cat "$out"
