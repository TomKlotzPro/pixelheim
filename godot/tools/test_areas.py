"""Tests for the areas check.sh quick picks flows by (PIX-353): every script
names its areas on an "## areas:" line under its class_name/extends,
tools/areas.txt names the other files' and no script's, and every area is a
tag some flow in flows.txt carries ("all", "none" and +boot names aside).

    python3 -m unittest discover -s godot/tools -p 'test_*.py'
"""
import glob
import os
import sys
import unittest

TOOLS = os.path.dirname(os.path.abspath(__file__))
GODOT = os.path.dirname(TOOLS)
sys.path.insert(0, TOOLS)
import flows  # noqa: E402

AREAS_TXT = os.path.join(TOOLS, "areas.txt")
HEAD = "## areas:"


def tags():
    return {tag for _, _, _, tagged in flows.read_flows() for tag in tagged.split()} | {"all", "none"}


def unknown(words, known):
    return [word for word in words if not word.startswith("+") and word not in known]


class AreasTest(unittest.TestCase):
    def test_every_script_names_its_areas_under_its_head(self):
        known = tags()
        scripts = sorted(glob.glob(os.path.join(GODOT, "scripts", "**", "*.gd"), recursive=True))
        self.assertTrue(scripts)
        for path in scripts:
            name = os.path.relpath(path, GODOT)
            with open(path, encoding="utf-8") as file:
                lines = file.read().splitlines()
            head = 0
            while head < len(lines) and lines[head].startswith(("class_name ", "extends ")):
                head += 1
            line = lines[head] if head < len(lines) else ""
            self.assertTrue(line.startswith(HEAD), "%s: its areas go on an '%s' line under its class_name/extends" % (name, HEAD))
            words = line[len(HEAD):].split()
            self.assertTrue(words, "%s: names no area" % name)
            self.assertEqual(unknown(words, known), [], "%s: areas no flow in flows.txt is tagged with" % name)

    def test_areas_txt_names_each_glob_once_and_no_script(self):
        known = tags()
        seen = {}
        with open(AREAS_TXT, encoding="utf-8") as file:
            for number, line in enumerate(file, 1):
                if not line.strip() or line.startswith("#"):
                    continue
                where = "areas.txt:%d" % number
                self.assertIn(":", line, "%s: a line is the areas, a colon, then the files" % where)
                areas, globs = line.split(":", 1)
                self.assertTrue(areas.split() and globs.split(), "%s: areas and files both" % where)
                self.assertEqual(unknown(areas.split(), known), [], "%s: areas no flow in flows.txt is tagged with" % where)
                for pattern in globs.split():
                    # A script's data beside it (PIX-356) has no head of its own.
                    script = pattern.startswith("scripts/") and not pattern.endswith((".txt", ".jsonl"))
                    self.assertFalse(script, "%s: %s names its areas on its own '%s' line" % (where, pattern, HEAD))
                    # What a union merge leaves of a line both branches changed.
                    self.assertFalse(pattern in seen, "%s: %s is on line %s already" % (where, pattern, seen.get(pattern)))
                    seen[pattern] = number


if __name__ == "__main__":
    unittest.main()
