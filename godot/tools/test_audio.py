"""Every sound the scripts ask for by name exists, and every audio file has
its level in audio.json's "levels" (the audio pass): Sound skips a name it
doesn't know in silence, so a typo would never be heard, and a file
without a level would be the one nobody measured.

    python3 -m unittest discover -s godot/tools -p 'test_*.py'
"""
import glob
import json
import os
import re
import unittest

GODOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")


def read(*parts):
    with open(os.path.join(GODOT, *parts)) as f:
        return f.read()


DOC = json.loads(read("assets", "data", "audio.json"))
SOUND = read("scripts", "sound.gd")
UI_SOUNDS = set(re.findall(r'^\t"(\w+)": \[\[', SOUND[SOUND.index("const UI_SOUNDS"):SOUND.index("const UI_RATE")], re.M))
# A call's name literals: "coin", or both of "coin" if landed else "bump";
# never a key, of a .get("sound", "coin") or a step["name"], around the name.
NAME = re.compile(r'(?<!get\()(?<!\[)"(\w+)"')
CALLS = {
    "play": (re.compile(r'Sound\.play\((.*)'), set(DOC["stingers"])),
    "play_ui": (re.compile(r'Sound\.play_ui(?:\.bind)?\((.*)'), UI_SOUNDS),
    "play_track": (re.compile(r'Sound\.play_track\((.*)'), set(DOC["tracks"])),
    "play_theme": (re.compile(r'Sound\.play_theme\((.*)'), set(DOC["themes"])),
    "a reveal's sound": (re.compile(r'"sound": ("\w+")'), set(DOC["stingers"])),
}


def scripts():
    for path in glob.glob(os.path.join(GODOT, "scripts", "**", "*.gd"), recursive=True):
        rel = os.path.relpath(path, GODOT)
        for number, line in enumerate(read(rel).splitlines(), 1):
            yield rel, number, line


class AudioTest(unittest.TestCase):
    def test_every_sound_named_in_the_scripts_exists(self):
        asked = 0
        for path, number, line in scripts():
            for kind, (call, known) in CALLS.items():
                match = call.search(line)
                if not match:
                    continue
                # The argument only: up to the call's closing paren.
                argument = match.group(1).split(")")[0]
                for name in NAME.findall(argument):
                    if name in ("false", "true"):
                        continue
                    asked += 1
                    self.assertIn(name, known, "%s:%d %s(\"%s\") names no sound" % (path, number, kind, name))
        self.assertGreater(asked, 90, "the scan found the calls")

    def test_every_theme_a_cutscene_plays_exists(self):
        story = json.loads(read("assets", "data", "story.json"))
        themes = [step["name"] for steps in story["scenes"].values() for step in steps if step.get("kind") == "theme"]
        self.assertTrue(themes)
        for name in themes:
            self.assertIn(name, DOC["themes"])

    def test_every_audio_file_has_its_level(self):
        levels = DOC["levels"]
        files = set()
        for path in glob.glob(os.path.join(GODOT, "assets", "audio", "*", "*.wav")):
            rel = os.path.relpath(path, os.path.join(GODOT, "assets", "audio"))[:-len(".wav")]
            # A variant's number goes: ambience/greenwood_1_3 is ambience/greenwood_1,
            # ambience/birds_2 is ambience/birds.
            key = re.sub(r"_\d+$", "", rel) if rel.startswith("ambience/") and not rel.startswith("ambience/bed_") else rel
            files.add(key)
            self.assertIn(key, levels, "%s.wav has no level in audio.json's levels" % rel)
        self.assertEqual(sorted(set(levels) - files), [], "levels for files that aren't there")
        for key, db in levels.items():
            self.assertTrue(-24 <= db <= 24, "%s: %s dB is past what a player takes" % (key, db))


if __name__ == "__main__":
    unittest.main()
