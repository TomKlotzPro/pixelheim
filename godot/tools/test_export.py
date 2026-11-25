"""The game ships no tests (PIX-351): every export preset's exclude_filter
keeps test/ and addons/gut out of the pack, and nothing the game runs; and
its include_filter carries the files the game reads as they are, which
Godot doesn't import (PIX-356). The Web preset alone leaves the paid audio
out, for tools/audio_packs.gd's packs, fetched after the start (PIX-518).

    python3 -m unittest discover -s godot/tools -p 'test_*.py'
"""
import configparser
import fnmatch
import glob
import os
import re
import unittest

PRESETS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "export_presets.cfg")
LEFT_OUT = ["test/unit/test_story.gd", "test/fixtures/slots/slot_1.json", "addons/gut/gut_cmdln.gd"]
SHIPPED = ["scripts/world.gd", "scenes/main.tscn", "assets/data/catalog.json", "locale/fr.po"]
GODOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
# And every feature's rows beside its feature.gd (PIX-361): read as they
# are, so a feature's flags or fields left out would break the shipped game.
FEATURE_ROWS = sorted(os.path.relpath(path, GODOT) for path in glob.glob(os.path.join(GODOT, "scripts", "features", "*", "*"))
                      if not path.endswith((".gd", ".uid")))
NOT_IMPORTED = ["scripts/harness_flags.txt", "scripts/harness_report.txt", "scripts/lookbook_shots.jsonl"] + FEATURE_ROWS


def matched(path, export_filter):
    """Whether an export filter takes `path`: a comma-separated filter
    matched case-blind against the path with and without res://, `*`
    crossing folders (String.matchn)."""
    filters = [f.strip().lower() for f in export_filter.split(",") if f.strip()]
    paths = [path.lower(), "res://" + path.lower()]
    return any(fnmatch.fnmatchcase(p, f) for p in paths for f in filters)


class ExportTest(unittest.TestCase):
    def test_every_preset_leaves_the_tests_out(self):
        config = configparser.ConfigParser(interpolation=None)
        config.read(PRESETS)
        presets = [s for s in config.sections() if s.count(".") == 1]
        self.assertGreaterEqual(len(presets), 3, "the Web, macOS and Windows presets")
        self.assertIn("scripts/features/lamps/harness_flags.txt", FEATURE_ROWS, "the features' rows were found")
        for section in presets:
            preset = config[section]
            name = preset.get("name", section).strip('"')
            exclude_filter = preset.get("exclude_filter", '""').strip('"')
            include_filter = preset.get("include_filter", '""').strip('"')
            for path in LEFT_OUT:
                self.assertTrue(matched(path, exclude_filter), f"{name} would ship {path}")
            for path in SHIPPED + NOT_IMPORTED:
                self.assertFalse(matched(path, exclude_filter), f"{name} would leave out {path}")
            for path in NOT_IMPORTED:
                self.assertTrue(matched(path, include_filter), f"{name} would leave out {path}")

    def test_only_the_web_leaves_the_paid_audio_to_its_packs(self):
        """PIX-518: index.pck without the packs' takes and tracks but with
        their lists (how Sound knows there are packs to fetch); the desktop
        with everything; a pack for each kind left out, fetched by the name
        Sound has, and built by the deploy."""
        config = configparser.ConfigParser(interpolation=None)
        config.read(PRESETS)
        sounds = ["assets/audio/paid/hit_blade_1.wav", "assets/audio/paid/music_town.ogg"]
        for section in [s for s in config.sections() if s.count(".") == 1]:
            name = config[section].get("name").strip('"')
            exclude_filter = config[section].get("exclude_filter").strip('"')
            for path in sounds:
                self.assertEqual(matched(path, exclude_filter), name == "Web", f"{name}: {path}")
            for path in ["assets/audio/paid/takes.json", "assets/audio/paid/music.json", "assets/audio/sfx/hurt.wav"]:
                self.assertFalse(matched(path, exclude_filter), f"{name} would leave out {path}")
        tool = open(os.path.join(GODOT, "tools", "audio_packs.gd")).read()
        packs = dict(re.findall(r'"(\w+\.pck)": "(\w+)"', tool))
        self.assertEqual(sorted(set(packs.values())), ["ogg", "wav"], "a pack for each kind the Web preset leaves out")
        fetched = re.search(r"const PACKS: Array\[String\] = \[(.*)\]", open(os.path.join(GODOT, "scripts", "sound.gd")).read()).group(1)
        self.assertEqual(sorted(re.findall(r'"([^"]+)"', fetched)), sorted(packs), "Sound fetches the packs the tool writes")
        self.assertEqual(re.findall(r'"([^"]+)"', fetched)[0], "title.pck", "the title's track is fetched first (PIX-552)")
        self.assertIn('const TITLE := "music_title.ogg"', tool, "and its pack holds the title slot's track alone")
        deploy = open(os.path.join(GODOT, "..", ".github", "workflows", "deploy.yml")).read()
        self.assertIn("tools/audio_packs.gd", deploy, "the deploy builds the packs")
        for pack in packs:
            self.assertIn("export/web/" + pack, deploy, f"the deploy fails without {pack}")


if __name__ == "__main__":
    unittest.main()
