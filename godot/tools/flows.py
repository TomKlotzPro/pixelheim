#!/usr/bin/env python3
"""The release flows' list and their check (PIX-273), for tools/flows.sh.

The flows live in tools/flows.txt, one a line (`name | harness arguments |
what the report must show | tags`), each under its own comment. They used
to be a bash array in flows.sh under one long sentence that named every
flow, and every branch that added a flow edited that sentence and the end
of the array: two branches at once always conflicted. A new flow is now an
added line and nothing else.

What the report must show is a list of fields, `field=pattern`, matched by
name against the harness's report line (scripts/harness_report.gd), never
by where they stand on it: a flow once anchored on the line's end
(`packs=...$`) broke when another field came after it. Each pattern is a
regular expression the field's whole value must match (`map=town` is the
town, not town_shop: say `map=town_.*` for any of its rooms). A field may
hold spaces (`cell=\\(79, 4\\)`, `card=The Mirefen`): the next field starts at
the next ` name=`. A field the report doesn't show fails the flow.

    python3 godot/tools/flows.py list            # every flow: name|args|expect|tags
    python3 godot/tools/flows.py list --boot     # every map booted, by day and at night
    python3 godot/tools/flows.py match EXPECT REPORT   # why REPORT fails EXPECT ("" if it doesn't)
"""
import glob
import json
import os
import re
import sys

TOOLS = os.path.dirname(os.path.abspath(__file__))
GODOT = os.path.dirname(TOOLS)
FLOWS = os.path.join(TOOLS, "flows.txt")

NAME = re.compile(r"[a-z0-9]+(?:-[a-z0-9]+)*")
# Where the next field starts: a space, then a field's name and its `=`.
FIELD_START = re.compile(r" +(?=[a-z_]+=)")
FIELD = re.compile(r"([a-z_]+)=(.*)", re.S)
REPORT_HEAD = "screenshot saved;"


class FlowError(Exception):
    """A line of flows.txt that isn't a flow: the message says where and why."""


def fields(text):
    """`a=1 b=two words c=(3, 4)` as [(name, value), ...], in order."""
    text = text.strip()
    if not text:
        return []
    out = []
    for part in FIELD_START.split(text):
        found = FIELD.fullmatch(part)
        if not found:
            raise FlowError("%r is not a field=value" % part)
        out.append((found.group(1), found.group(2)))
    return out


def report_fields(line):
    """The harness's report line (`screenshot saved; map=town cell=(40, 33) ...`)
    as field -> value."""
    line = line.strip()
    if line.startswith(REPORT_HEAD):
        line = line[len(REPORT_HEAD):]
    return dict(fields(line))


def expectation(text):
    """A flow's `field=pattern ...` as [(field, compiled pattern), ...]."""
    out = []
    seen = set()
    for name, pattern in fields(text):
        if name in seen:
            raise FlowError("%s= is expected twice" % name)
        seen.add(name)
        if pattern.endswith("$") and not pattern.endswith("\\$") or pattern.startswith("^"):
            raise FlowError("%s=%s: a pattern matches the field's whole value already, drop its ^ and $" % (name, pattern))
        try:
            out.append((name, re.compile(pattern)))
        except re.error as error:
            raise FlowError("%s=%s is not a regular expression: %s" % (name, pattern, error))
    if not out:
        raise FlowError("it expects nothing: name at least one field (map=town)")
    return out


def mismatch(expect, report):
    """Why the report line fails the flow's expectation, or "" when it passes."""
    lines = [line for line in report.splitlines() if REPORT_HEAD in line]
    if not lines:
        return "no report"
    shown = report_fields(lines[-1][lines[-1].index(REPORT_HEAD):])
    wrong = []
    for name, pattern in expectation(expect):
        if name not in shown:
            wrong.append("no %s=" % name)
        elif not pattern.fullmatch(shown[name]):
            wrong.append("%s=%s, not /%s/" % (name, shown[name], pattern.pattern))
    return "; ".join(wrong)


def read_flows(path=FLOWS):
    """Every flow in flows.txt as (name, args, expect, tags), in order. Refuses
    a line that isn't one, a name given twice and a flow without its comment."""
    flows = []
    seen = {}
    before = ""
    with open(path, encoding="utf-8") as file:
        for number, raw in enumerate(file, 1):
            line = raw.rstrip("\n")
            where = "%s:%d" % (os.path.relpath(path, GODOT), number)
            stripped = line.strip()
            if not stripped or stripped.startswith("#"):
                before = stripped
                continue
            parts = [part.strip() for part in line.split("|")]
            if len(parts) != 4:
                raise FlowError("%s: a flow is name | harness arguments | expected | tags, %d fields here" % (where, len(parts)))
            name, args, expect, tags = parts
            if not NAME.fullmatch(name):
                raise FlowError("%s: %r is not a flow's name (lowercase words joined by -)" % (where, name))
            if name in seen:
                raise FlowError("%s: %s is already the flow on line %d" % (where, name, seen[name]))
            if before == "":
                raise FlowError("%s: %s has no comment: put a line above it saying what it walks through (PIX-...)" % (where, name))
            try:
                expectation(expect)
            except FlowError as error:
                raise FlowError("%s: %s: %s" % (where, name, error))
            seen[name] = number
            flows.append((name, " ".join(args.split()), expect, " ".join(tags.split())))
            before = stripped
    return flows


def boot_flows():
    """Every map the game can stand in (--boot), from the game's own data, so
    a new map is checked without a line in flows.txt: each map file (a house
    tier is its map's @n variant), the village at each age, a region
    dungeon's planned floors (PIX-255), the Undermountain's floors, and the
    Deep Hunt's depths down to its first warden (its twists, its elites, the
    warden). Each one by day and at night; the report must name the map it
    booted on."""
    out = []

    def boot(name, args, map_id):
        out.append((name, args, "map=" + map_id, ""))
        out.append((name + "-night", args + " night", "map=" + map_id, ""))

    for path in sorted(glob.glob(os.path.join(GODOT, "assets", "maps", "*.json"))):
        with open(path, encoding="utf-8") as file:
            if "tiles" not in json.load(file):
                continue  # interactables.json: what stands on the maps
        map_id, _, tier = os.path.basename(path)[: -len(".json")].partition("@")
        if tier:
            boot("%s-tier%s" % (map_id, tier), "--map %s --house-tier %s" % (map_id, tier), map_id)
        else:
            boot(map_id, "--map " + map_id, map_id)
    with open(os.path.join(GODOT, "assets", "data", "town.json"), encoding="utf-8") as file:
        for age in range(len(json.load(file)["tiers"])):
            boot("town-age%d" % age, "--map town --town-tier %d" % age, "town")
    # A dungeon's planned floors (PIX-255; the Kings' Vault's, PIX-257) are
    # laid out, not files. The old mountain's numbered floors and the Deep
    # Hunt's depths left play with PIX-257.
    with open(os.path.join(GODOT, "assets", "data", "depths.json"), encoding="utf-8") as file:
        for dungeon in json.load(file)["dungeons"].values():
            for floor in dungeon["floors"]:
                if "plan" in floor:
                    boot(floor["mapId"], "--map " + floor["mapId"], floor["mapId"])
    return out


def main(argv):
    try:
        if argv[:1] == ["list"] and argv[1:] in ([], ["--boot"]):
            for flow in (boot_flows() if argv[1:] else read_flows()):
                print("|".join(flow))
            return 0
        if argv[:1] == ["match"] and len(argv) == 3:
            why = mismatch(argv[1], argv[2])
            if why:
                print(why)
                return 1
            return 0
    except FlowError as error:
        print("flows: %s" % error, file=sys.stderr)
        return 2
    print(__doc__.split("\n\n")[-1], file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
