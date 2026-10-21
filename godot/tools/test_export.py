"""The game ships no tests (PIX-351): every export preset's exclude_filter
keeps test/ and addons/gut out of the pack, and nothing the game runs.

    python3 -m unittest discover -s godot/tools -p 'test_*.py'
"""
import configparser
import fnmatch
import os
import unittest

PRESETS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "export_presets.cfg")
LEFT_OUT = ["test/unit/test_story.gd", "test/fixtures/slots/slot_1.json", "addons/gut/gut_cmdln.gd"]
SHIPPED = ["scripts/world.gd", "scenes/main.tscn", "assets/data/catalog.json", "locale/fr.po"]


def excluded(path, exclude_filter):
    """Whether Godot's export leaves `path` out: a comma-separated filter
    matched case-blind against the path with and without res://, `*`
    crossing folders (String.matchn)."""
    filters = [f.strip().lower() for f in exclude_filter.split(",") if f.strip()]
    paths = [path.lower(), "res://" + path.lower()]
    return any(fnmatch.fnmatchcase(p, f) for p in paths for f in filters)


class ExportTest(unittest.TestCase):
    def test_every_preset_leaves_the_tests_out(self):
        config = configparser.ConfigParser(interpolation=None)
        config.read(PRESETS)
        presets = [s for s in config.sections() if s.count(".") == 1]
        self.assertGreaterEqual(len(presets), 3, "the Web, macOS and Windows presets")
        for section in presets:
            preset = config[section]
            name = preset.get("name", section).strip('"')
            exclude_filter = preset.get("exclude_filter", '""').strip('"')
            for path in LEFT_OUT:
                self.assertTrue(excluded(path, exclude_filter), f"{name} would ship {path}")
            for path in SHIPPED:
                self.assertFalse(excluded(path, exclude_filter), f"{name} would leave out {path}")


if __name__ == "__main__":
    unittest.main()
