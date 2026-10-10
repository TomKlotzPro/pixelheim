#!/usr/bin/env python3
"""The flake hunt's tally (PIX-276): every release flow run again and again,
side by side under load, and what came out of each run gathered here.

Three flows used to get a second try in flows.sh (motion, festival, board),
and under load others timed out: a flow that fails one run in thirty costs a
rerun of the whole job, and one that passes on its second try hides what made
it fail. .github/workflows/flakes.yml runs the suite several rounds on
several runners, headless and in a window, collects each round here, and
tallies them all in its summary: every flow that failed even once, why, and
the end of its output, and every flow whose report changed between runs
(every field but draws=, which only a window counts), which is how a flake
starts before any flow fails on it.

    python3 godot/tools/flakes.py collect TAG [RUNS]   # a round's results, as JSON lines
    python3 godot/tools/flakes.py tally FILE...        # the summary (markdown); exit 1 on a failure
    python3 godot/tools/flakes.py tally --strict FILE...  # and on a report that changed

TAG names the round (`headless 3.2`: the mode first, then which runner and
round); RUNS is flows.sh's folder of runs (godot/flows/runs).
"""
import json
import os
import re
import sys

from flows import REPORT_HEAD, report_fields

TOOLS = os.path.dirname(os.path.abspath(__file__))
RUNS = os.path.join(os.path.dirname(TOOLS), "flows", "runs")
# The fields a run may differ in without being unsteady: draw calls are the
# renderer's (0 headless).
IGNORED = {"draws"}
# How much of a failed run's output the summary keeps.
TAIL = 30
ANSI = re.compile(r"\x1b\[[0-9;]*m")


def collect(tag, runs=RUNS):
    """Each flow's result in `runs` (flows.sh's folder for each run: its
    `result` and `output.txt`) as a dict: what the tally reads."""
    out = []
    for name in sorted(os.listdir(runs)) if os.path.isdir(runs) else []:
        folder = os.path.join(runs, name)
        try:
            with open(os.path.join(folder, "result"), encoding="utf-8") as file:
                status, flow, seconds, line = file.read().rstrip("\n").split("|", 3)
        except (OSError, ValueError):
            continue
        output = ""
        try:
            with open(os.path.join(folder, "output.txt"), encoding="utf-8", errors="replace") as file:
                output = ANSI.sub("", file.read())
        except OSError:
            pass
        reports = [line for line in output.splitlines() if REPORT_HEAD in line]
        run = {
            "tag": tag,
            "mode": tag.split()[0] if tag.split() else "",
            "flow": flow,
            "status": status,
            "seconds": float(seconds or 0),
            "report": reports[-1][reports[-1].index(REPORT_HEAD) + len(REPORT_HEAD):].strip() if reports else "",
        }
        if status == "FAIL":
            run["why"] = line
            run["tail"] = output.splitlines()[-TAIL:]
        out.append(run)
    return out


def steady_part(report):
    """The report's fields a steady flow gives the same on every run."""
    return {name: value for name, value in report_fields(report).items() if name not in IGNORED}


def tally(runs, strict=False):
    """The summary of every run (markdown), and whether the hunt passes:
    no flow failed (and, `strict`, none changed its report)."""
    flows = {}
    for run in runs:
        if run["status"] == "skip":
            continue
        flows.setdefault(run["flow"], []).append(run)
    modes = sorted({run["mode"] for runs_of in flows.values() for run in runs_of})
    failed = {name: [run for run in of if run["status"] == "FAIL"] for name, of in flows.items()}
    failed = {name: of for name, of in failed.items() if of}
    changed = {}
    for name, of in flows.items():
        seen = [steady_part(run["report"]) for run in of if run["report"]]
        distinct = {json.dumps(fields, sort_keys=True) for fields in seen}
        if len(distinct) > 1:
            fields = sorted({key for one in seen for key in one if len({json.dumps(other.get(key)) for other in seen}) > 1})
            changed[name] = (len(distinct), fields)
    total = sum(len(of) for of in flows.values())
    passed = not failed and not (strict and changed)
    lines = ["### Steady flows: %s" % ("all steady" if not failed and not changed else
                                         "%d failed" % len(failed) if failed else
                                         "none failed, %d changed their report" % len(changed)), ""]
    per_mode = ", ".join("%s %s" % (mode, _runs_each([run for of in flows.values() for run in of if run["mode"] == mode], flows)) for mode in modes)
    lines += ["%d runs of %d flows (%s)." % (total, len(flows), per_mode), ""]
    if failed:
        lines += ["| Flow | Failed | Runs | Why (first) |", "|---|---|---|---|"]
        for name in sorted(failed, key=lambda flow: (-len(failed[flow]), flow)):
            by_mode = ", ".join("%s %d" % (mode, n) for mode, n in _count(failed[name]).items())
            lines.append("| %s | %d (%s) | %d | `%s` |" % (name, len(failed[name]), by_mode, len(flows[name]), _cell(failed[name][0].get("why", ""))))
        lines.append("")
    if changed:
        lines += ["Reports that changed between runs (every field but %s):" % ", ".join("%s=" % field for field in sorted(IGNORED)), "",
                  "| Flow | Reports | Fields that changed |", "|---|---|---|"]
        for name in sorted(changed):
            lines.append("| %s | %d | %s |" % (name, changed[name][0], ", ".join(changed[name][1])))
        lines.append("")
    slowest = sorted(((max(run["seconds"] for run in of), name) for name, of in flows.items()), reverse=True)[:5]
    if slowest:
        lines.append("Slowest runs: %s." % ", ".join("%s %.1f s" % (name, seconds) for seconds, name in slowest))
        lines.append("")
    for name in sorted(failed):
        lines += ["<details><summary>%s: %d of %d failed</summary>" % (name, len(failed[name]), len(flows[name])), ""]
        for run in failed[name]:
            lines += ["**%s** (%.1f s): %s" % (run["tag"], run["seconds"], _cell(run.get("why", ""))), "", "```"]
            lines += [line.replace("```", "'''") for line in run.get("tail", [])]
            lines += ["```", ""]
        lines += ["</details>", ""]
    return "\n".join(lines), passed


def _runs_each(runs, flows):
    """`5 runs each`, or `1 to 5 runs each` when the flows ran unevenly."""
    counts = {}
    for run in runs:
        counts[run["flow"]] = counts.get(run["flow"], 0) + 1
    if not counts:
        return "no runs"
    low, high = min(counts.values()), max(counts.values())
    return "%s run%s each%s" % (low if low == high else "%d to %d" % (low, high), "" if high == 1 else "s",
                                "" if len(counts) == len(flows) else " of %d flows" % len(counts))


def _count(runs):
    out = {}
    for run in runs:
        out[run["mode"]] = out.get(run["mode"], 0) + 1
    return out


def _cell(text):
    """Text that fits in a table's cell."""
    return text.replace("|", "\\|").replace("`", "'").replace("\n", " ")[:300]


def main(argv):
    if argv[:1] == ["collect"] and len(argv) in (2, 3):
        for run in collect(argv[1], *argv[2:]):
            print(json.dumps(run))
        return 0
    if argv[:1] == ["tally"]:
        strict = "--strict" in argv
        runs = []
        for path in [arg for arg in argv[1:] if arg != "--strict"]:
            with open(path, encoding="utf-8") as file:
                runs += [json.loads(line) for line in file if line.strip()]
        summary, passed = tally(runs, strict)
        print(summary)
        return 0 if passed else 1
    print(__doc__.split("\n\n")[-2], file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
