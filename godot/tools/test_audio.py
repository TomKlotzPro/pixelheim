"""Every sound the scripts ask for by name exists, and every audio file has
its level in audio.json's "levels" (the audio pass): Sound skips a name it
doesn't know in silence, so a typo would never be heard, and a file
without a level would be the one nobody measured. PIX-411: every event is
some moment's, and no family's loudest take, through its bus at the full
slider, passes 0 dBFS (the web has no limiter).

    python3 -m unittest discover -s godot/tools -p 'test_*.py'
"""
import glob
import json
import os
import re
import math
import unittest
import wave

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
    "play": (re.compile(r'Sound\.play(?:\.bind)?\((.*)'), set(DOC["events"])),
    "play_track": (re.compile(r'Sound\.play_track\((.*)'), set(DOC["tracks"])),
    "play_theme": (re.compile(r'Sound\.play_theme\((.*)'), set(DOC["themes"])),
    "a reveal's sound": (re.compile(r'"sound": ("\w+")'), set(DOC["events"])),
}


def scripts():
    for path in glob.glob(os.path.join(GODOT, "scripts", "**", "*.gd"), recursive=True):
        rel = os.path.relpath(path, GODOT)
        for number, line in enumerate(read(rel).splitlines(), 1):
            yield rel, number, line


class AudioTest(unittest.TestCase):
    def test_every_sound_named_in_the_scripts_exists(self):
        asked = 0
        named = set()
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
                    named.add(name)
        self.assertGreater(asked, 90, "the scan found the calls")
        # PIX-411: an event no moment asks for (by name, or through the
        # tables Sound chooses by) is one a typo orphaned.
        chosen = set(DOC["blows"].values()) | set(DOC["casts"].values()) | set(DOC["steps"].values())
        chosen |= {"hit_blade", "kill", "step_dirt", "cast"} | {e for e in DOC["events"] if e.startswith("kill_")}
        # PIX-413: a weapon's swing, a skill's impact, a foe's growl and voice,
        # a patch's, an animal's call, a place's bed.
        chosen |= set(DOC["swings"].values()) | set(DOC["gathers"].values()) | {"swing", "gather", "foe_bite"}
        chosen |= {e for e in DOC["events"] if e.startswith(("impact_", "foe_noticed_", "animal_"))}
        chosen |= {"%s_%s" % (kind, what) for kind in DOC["voices"].values() for what in ("attack", "hurt", "death")}
        chosen |= {place["bed"] for place in DOC["places"].values() if "bed" in place}
        self.assertEqual(sorted(set(DOC["events"]) - named - chosen), [], "events no moment asks for")

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
            # The packs' takes, installed: the prep levelled them (PIX-411).
            if rel.startswith("paid/"):
                continue
            # A variant's number goes: ambience/greenwood_1_3 is ambience/greenwood_1,
            # ambience/birds_2 is ambience/birds.
            key = re.sub(r"_\d+$", "", rel) if rel.startswith("ambience/") and not rel.startswith("ambience/bed_") else rel
            files.add(key)
            self.assertIn(key, levels, "%s.wav has no level in audio.json's levels" % rel)
        self.assertEqual(sorted(set(levels) - files), [], "levels for files that aren't there")
        for key, db in levels.items():
            self.assertTrue(-24 <= db <= 24, "%s: %s dB is past what a player takes" % (key, db))

    def test_no_familys_loudest_take_clips_at_the_full_slider(self):
        # PIX-411: a take's peak, its own level, its family's, the most a
        # stinger is varied by, then its bus at the full slider: under 0 dBFS,
        # as the web plays it (no limiter there). A pack's take is brought
        # under its family's peak by the prep (tools/sound_prep.py), and an
        # installed one is checked by the peak it was measured at.
        bus = const("LOUDNESS_DB")
        vary = const("VARY_DB")
        loudest = {}
        for event, entry in DOC["events"].items():
            family = DOC["families"][entry["family"]]
            varies = "feet" not in family
            for take in entry["takes"]:
                peak = take_peak(take) + DOC["levels"].get(take, 0)
                varied = vary if varies and take.startswith("sfx/") else 0
                loudest[take] = max(loudest.get(take, -99), peak + family["db"] + varied)
            pack = family["peak"] + family["db"] + (vary if varies else 0)
            loudest["the packs' " + entry["family"]] = pack
        for event, names in PAID.get("events", {}).items():
            family = DOC["families"][DOC["events"][event]["family"]]
            for name in names:
                # PIX-413: none over its family's peak, as the prep holds them.
                self.assertLessEqual(PAID["takes"][name]["peak"], family["peak"] + 0.1, "%s: over %s's peak" % (name, event))
                loudest["paid/" + name] = PAID["takes"][name]["peak"] + family["db"] + (vary if "feet" not in family else 0)
        self.assertGreater(len(loudest), 30)
        for take, peak in loudest.items():
            self.assertLess(peak + bus, 0.0, "%s peaks at %.1f dBFS through its bus" % (take, peak + bus))


def const(name):
    return float(re.search(r"^const %s := (-?[\d.]+)" % name, SOUND, re.M).group(1))


def take_peak(take):
    """A take's sample peak in dBFS: a rendered WAV's, or a blip's loudest."""
    if take.startswith("blip/"):
        block = SOUND[SOUND.index("const UI_SOUNDS"):SOUND.index("const UI_RATE")]
        line = re.search(r'^\t"%s": (\[\[.*\]\]),$' % take[len("blip/"):], block, re.M).group(1)
        return 20 * math.log10(max(float(v) for v in re.findall(r"(-?[\d.]+)\]", line)))
    with wave.open(os.path.join(GODOT, "assets", "audio", take + ".wav")) as f:
        assert f.getsampwidth() == 2, take
        frames = f.readframes(f.getnframes())
    samples = memoryview(frames).cast("h")
    return 20 * math.log10(max(max(samples), -min(samples)) / 32768)


PAID_LIST = os.path.join(GODOT, "assets", "audio", "paid", "takes.json")
PAID = json.loads(read("assets", "audio", "paid", "takes.json")) if os.path.exists(PAID_LIST) else {}


if __name__ == "__main__":
    unittest.main()
